# Transfers slice — design

**Date:** 2026-07-24
**Status:** approved, ready for implementation plan

## Context

Deferred piece of the Transactions work: moving money between the user's own accounts (e.g.
Checking → Savings). Split out from the start because transfers need a genuinely different
mechanism than income/expense — two linked rows created/edited/deleted together, not one row —
and every prior slice this session stayed tightly scoped by keeping mechanisms like this separate.

`Account`, `Category`, and `Transaction` (income/expense only, no `transfer_id` column yet) all
already exist and are live in production.

## Scope

In scope: recording a transfer as two linked `Transaction` rows (one negative in the source
account, one positive in the destination), full create/edit/delete for transfers, integrated into
the existing "smart form" on `/transactions/new` via a Type selector.

Out of scope: Budget, Goals, Education (next slices per the plan's build order, unaffected by
this one).

## Data model

```ruby
# db/migrate/..._add_transfer_support_to_transactions.rb
change_column_null :transactions, :category_id, true
add_column :transactions, :transfer_id, :string
add_index :transactions, :transfer_id
```

- `category_id` becomes nullable — the nullable case (deferred when the original Transaction slice
  shipped) only exists for transfers.
- `transfer_id` is a plain string column holding a UUID (`SecureRandom.uuid`), **shared by both
  legs** of one transfer — not a self-referential foreign key. A shared UUID lets both rows be
  created in a single pass with no "create row A, then update it to point at row B" step; finding
  a leg's pair is just `Transaction.where(transfer_id: ...)`.
- `Transaction`'s `enum :txn_type` gains `transfer: "transfer"` — no migration needed for the enum
  itself, since it's a plain string column; this is purely a new key in the existing Ruby hash.
- `belongs_to :category` becomes `belongs_to :category, optional: true`. The existing
  `category_kind_matches_txn_type` validation already no-ops correctly for transfers (it already
  guards `return if category.blank?`).
- **`Account#current_balance` needs no changes.** It already sums *all* of an account's
  transactions regardless of `txn_type`, so transfer legs get included automatically the moment
  they exist as rows.
- No new cross-leg validation belongs on `Transaction` itself. Each leg's existing
  `account_belongs_to_user` already covers ownership independently per row — the one genuinely
  new invariant, "from account ≠ to account," lives in `TransferForm` (below), not the model,
  since a single `Transaction` row has no knowledge of its pair.

## A correctness fix to the already-shipped Transaction model

The existing sign-convention callback,

```ruby
def apply_sign_convention
  return if amount_cents.blank?
  self.amount_cents = income? ? amount_cents.abs : -amount_cents.abs
end
```

treats "not income" as "must be negative" — correct for expense, but would silently force a
transfer's *incoming* leg negative too, since `income?` is false for a transfer-type row. Fix:

```ruby
def apply_sign_convention
  return if amount_cents.blank? || transfer?
  self.amount_cents = income? ? amount_cents.abs : -amount_cents.abs
end
```

Transfers set both legs' signs explicitly (via `TransferForm`, below) — the callback should only
ever touch income/expense. This is a necessary follow-up to already-shipped code, in scope for
this slice because the bug is only reachable once `transfer_id` and the `transfer` enum value
exist at all.

## The `Transfers` resource

`resources :transfers, only: %i[ new create edit update destroy ]` — deliberately no `index`/
`show`. A transfer is never viewed as its own page; it's only ever seen via the unified
Transactions feed, as its two ordinary-looking legs.

**`TransferForm`** (`app/models/transfer_form.rb` — a plain Ruby object using `ActiveModel::Model`,
*not* an `ActiveRecord` model; there is no `transfers` table) wraps both legs of one transfer.
It lives in `app/models/`, not `app/services/`, because it has several public methods
(`.find`/`.save`/`.destroy`) rather than the single `#call` CLAUDE.md's services convention
expects — this is the standard Rails "Form Object" pattern, which convention places alongside
real models since it uses the same `ActiveModel::Model` validation/errors machinery they do:

- `.find(user, transfer_id)` loads both legs (ordered by `amount_cents` ascending, so the negative
  "from" leg sorts first) and populates `from_account_id`/`to_account_id`/`amount`/`occurred_on`/
  `description` for editing. Raises `ActiveRecord::RecordNotFound` if the transfer doesn't belong
  to `user` or doesn't resolve to exactly two rows — converted to a 404 by the same
  `show_exceptions = :rescuable` mechanism already used everywhere else in this app, no new
  `rescue_from` needed.
- `.save(user)` creates (on a new transfer) or destroys-then-recreates (on edit) both legs
  atomically in one DB transaction, sharing the `transfer_id`. Recreating rather than updating in
  place is a deliberate simplification — the `transfer_id` stays stable across an edit; only the
  underlying row ids change, and nothing else in this app references a `Transaction`'s id by
  foreign key from outside itself.
- Validates `from_account_id != to_account_id`, and that `amount` parses (via `Monetize.parse`,
  the same parser money-rails itself uses internally) to a positive value.
- Does **not** duplicate ownership checking. When each leg is actually created via
  `user.transactions.create!(...)`, `Transaction`'s existing `account_belongs_to_user` validation
  fires — a crafted request with another user's account id surfaces as a real validation failure
  (caught and re-added onto `TransferForm`'s own `errors`), not a silent bypass and not a second,
  redundant ownership check.

**`TransactionsController` changes:**
- `edit`: if `@transaction.transfer?`, redirect to `edit_transfer_path(@transaction.transfer_id)`
  instead of rendering — an existing transfer leg is never edited through the Transactions form.
- `destroy`: if `@transaction.transfer?`, destroy both legs via `TransferForm` (no redirect
  needed — this works inline, directly from either leg's Delete button in the unified feed).
- `update` is **intentionally left unchanged**. It's unreachable for a transfer through any real
  UI path, since `edit` always redirects first — guarding it further would mean defending against
  a request nothing in the app ever actually sends. Documented here as an accepted, known gap
  rather than a silent one: a hand-crafted `PATCH /transactions/:id` for a transfer leg's id would
  update that one leg's fields directly, breaking pair-sync. Low severity for a personal
  single-user app; revisit if this app ever gains multi-user or API surface.

## The smart form

`/transactions/new` renders **two independent `<form>` elements**: the existing Transaction form
(unchanged) and a new Transfer form, bound to a `TransferForm.new`. A small Stimulus controller
shows exactly one, based on the Type select (`expense`/`income`/`transfer`) — each form is
properly bound to its own real object and posts to its own resource (`/transactions` or
`/transfers`). This avoids the "one object serving two different save paths" complexity a shared
form object would introduce, while still presenting one smart, single-page form to the user.

`TransactionsController#new` additionally builds `@transfer = TransferForm.new(occurred_on:
Date.current)` so the (initially hidden) transfer fields have something to bind to.

## Feed display

Per the plan's decision, a transfer shows as **two separate rows** in the unified feed — a
negative row under the source account, a positive row under the destination — exactly like any
other transaction. This requires **no changes** to `app/views/transactions/index.html.erb`: each
leg is a real `Transaction` record already rendered by the existing loop, with its existing
Edit/Delete links (which now correctly redirect/pair-destroy per the `TransactionsController`
changes above).

## Testing

- `Transaction` model: a regression test proving a transfer-type row's amount is *not* touched by
  the sign-convention callback (create one with an explicit negative and one with an explicit
  positive amount_cents, confirm both persist exactly as submitted, unlike income/expense).
- `TransferForm`: `from_account_id == to_account_id` rejected; non-positive amount rejected;
  `.save` creates exactly two rows with correct opposite signs sharing one `transfer_id`; `.find`
  correctly identifies which leg is from/to; `.destroy` removes both legs; a crafted cross-user
  account id surfaces as a `TransferForm` validation error, not a raw unhandled exception.
- `TransfersController`: full new/create/edit/update/destroy cycle; cross-user 404 on `edit`.
- `TransactionsController`: `edit` redirects to the Transfers equivalent for a transfer-type row;
  `destroy` on either leg removes both.
- No system test — manual/HTTP-walkthrough verification, same as every prior slice: create a
  transfer, confirm both accounts' balances update correctly, edit it, confirm both legs change
  together, delete it, confirm both gone.
