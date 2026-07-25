# Accounts slice — design

**Date:** 2026-07-24
**Status:** approved, ready for implementation plan

## Context

Phase 4 of `docs/financial-literacy-platform-plan.md` calls for a full budgeting + education data
model (Accounts → Categories → Transactions → Budget → Goals → Education). That's multiple
independent subsystems, too large for one spec — this document scopes only the first slice,
**Accounts**, per the plan's own suggested build order (everything else, starting with
Transactions, depends on Account existing first).

Only `User` exists as a domain model today (see CLAUDE.md). This slice adds the first
budgeting-domain model.

## Scope

In scope: an `Account` model (financial accounts a user tracks — checking, savings, etc.) with
full CRUD (create/list/edit/delete), scoped to `current_user`.

Out of scope (deferred to later slices): Transactions, any notion of a "current balance" beyond
the stored starting balance, multi-currency, archiving/soft-delete, an account `show` page.

## Data model

```ruby
# db/migrate/..._create_accounts.rb
create_table :accounts do |t|
  t.references :user, null: false, foreign_key: true
  t.string :name, null: false
  t.string :kind, null: false  # checking, savings, cash, credit, investment
  t.integer :starting_balance_cents, null: false, default: 0
  t.timestamps
end
```

- `Account belongs_to :user`; `User has_many :accounts, dependent: :destroy`
- `starting_balance_cents` monetized via `money-rails` (`monetize :starting_balance_cents`) —
  **USD only**, no `currency` column. money-rails defaults every monetized column to USD; add a
  currency column later only if multi-currency is actually needed.
- `kind` is a Rails `enum` over a fixed list: `checking`, `savings`, `cash`, `credit`,
  `investment`. Gives `account.checking?`, `Account.checking`, etc. for free, and the enum itself
  is the validation against invalid values.
- **Delete is a hard delete.** No transactions exist yet in this slice, so there's nothing to
  orphan. Revisit archiving (soft delete) once Transactions ships and destroying an account could
  mean losing real transaction history.

## Validations

- `name`: presence
- `kind`: presence (the `enum` mechanism itself rejects any value outside the fixed list —
  assigning an invalid string raises `ArgumentError`, and the form only ever offers valid options)
- `starting_balance_cents`: presence (defaults to `0` via the migration default; this mainly
  guards against an explicit `nil` being assigned)

## Controller, routes, views

- `resources :accounts` in `config/routes.rb` — flat, not nested under `/users/:id`, matching how
  `sessions`/`passwords` are already routed. Scoping happens in the controller, not the URL.
- `AccountsController` actions: `index`, `new`, `create`, `edit`, `update`, `destroy`. No `show`
  — matches the plan's explicit "create/list/edit" scope for this slice.
- Every action resolves the record through `current_user.accounts.find(...)` (or
  `current_user.accounts.build` for `new`/`create`), so requesting another user's account 404s
  rather than authorizing across users. Matches the existing "every controller action scopes to
  current_user" convention (CLAUDE.md).
- Views: `index` — DaisyUI table listing each account's name, kind, and formatted starting
  balance, with edit/delete actions per row. Shared `_form` partial for `new`/`edit`, styled with
  DaisyUI form-control classes (`daisyui.js` is already vendored and wired up from the earlier UI
  kit work).
- **Included cleanup:** flash message rendering (`flash[:alert]`/`flash[:notice]`) is currently
  duplicated in `sessions/new.html.erb` and `passwords/new.html.erb`. Since every new Accounts
  view needs the same thing, move it once into `application.html.erb` (already touched for the
  navbar) and delete the two duplicates. Same behavior, one shared place going forward.

## Testing

- Model test (`test/models/account_test.rb`): validations (name/kind/starting_balance_cents
  presence), the `user` association, enum values round-trip correctly.
- Controller/integration test (`test/controllers/accounts_controller_test.rb`): full CRUD happy
  path as a signed-in user (via `sign_in_as`), plus a cross-user scoping test — User A requesting
  User B's account (`show`... N/A here; `edit`/`update`/`destroy`) gets a 404, not a 403, so
  existence isn't leaked. Matches the existing test/controllers pattern in the repo.
- No system test for this slice — matches CLAUDE.md ("system tests aren't part of `bin/ci` by
  default"). Manual browser verification against a real dev server instead, same as the UI kit
  work earlier this session (boot `bin/dev`, sign in, exercise create/edit/delete once by hand).

## Open items for later slices (explicitly not this spec)

- Categories, Transactions, Budget/BudgetLine, Goals, Education (Course/Lesson/LessonProgress) —
  each gets its own spec when we get there, per the plan's suggested slice order.
- Whether Account needs archiving once Transactions exists and hard-deleting would lose real
  transaction history.

### Core-loop note (for the Transaction slice, decided now to avoid relitigating later)

Researched two open-source reference implementations before settling this:

- **Firefly III** uses full double-entry bookkeeping — every transaction is a "journal" with at
  least two linked legs (debit + credit), and categories aren't a separate concept at all;
  "categories" are really just special expense/revenue *accounts*. Powerful, but heavier
  machinery than a personal budgeting app needs.
- **Actual Budget** (YNAB-style) keeps accounts and categories as genuinely separate concepts.
  Transactions have a **signed `amount`** (positive = in, negative = out). A transfer between the
  user's own accounts is just **two linked transaction rows** — one negative in the source
  account, one positive in the destination — connected by a `transfer_id`. Transfers don't count
  against a category, since they're not real spending.

**Decision: follow Actual Budget's pattern**, not Firefly's. It matches this plan's Account and
(planned) Category/Transaction shape almost exactly — the one refinement over the original
plan-doc sketch is **signed `amount_cents`** instead of unsigned-amount-plus-type-only, so
"sum by category = total spend" is trivial arithmetic with no type-interpretation needed. Keep
`txn_type` (income/expense/transfer) as an enum for filtering/UI, but let the amount's sign do
the arithmetic. Transfers get a self-referential link (e.g. `transfer_pair_id`) between the two
transaction rows they create, and `category` is nullable/blank for transfer-type transactions.

This doesn't change anything about the Account model above — it's forward-looking context for
whenever the Transaction slice gets its own spec.
