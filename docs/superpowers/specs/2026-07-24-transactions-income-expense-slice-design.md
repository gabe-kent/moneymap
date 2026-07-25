# Income/Expense Transactions slice — design

**Date:** 2026-07-24
**Status:** approved, ready for implementation plan

## Context

Third slice of Phase 4's data model. `Account` and `Category` already exist (shipped this
session). This is the core loop the whole data model has been building toward: recording money
moving in and out of an account, tagged with a category.

Split out of a broader "Transactions" idea during brainstorming: transfers between the user's own
accounts need a genuinely different mechanism (two linked rows created/edited/deleted together,
per the core-loop research already captured in the Accounts spec) versus income/expense (a single
row). Keeping them separate keeps each slice tightly scoped, matching every prior slice this
session. Transfers get their own spec as a follow-up.

## Scope

In scope: a `Transaction` model (income or expense, tied to one account and one category) with
full CRUD, a unified cross-account feed, and — because this is the point where Transactions
becomes visible — updating the already-shipped Accounts index to show a real computed balance
instead of just the static starting balance.

Out of scope (deferred to a follow-up slice): transfers between accounts (and therefore
`category` staying non-nullable here — the nullable case only exists for transfers), Budget/
BudgetLine, Goals, Education.

## Data model

```ruby
# db/migrate/..._create_transactions.rb
create_table :transactions do |t|
  t.references :user, null: false, foreign_key: true
  t.references :account, null: false, foreign_key: true
  t.references :category, null: false, foreign_key: true
  t.integer :amount_cents, null: false
  t.string :description
  t.date :occurred_on, null: false
  t.string :txn_type, null: false  # income, expense

  t.timestamps
end
add_index :transactions, [ :user_id, :occurred_on ]
```

- `Transaction belongs_to :user, :account, :category` (all required in this slice).
- `enum :txn_type` over `income`/`expense` only. `transfer` is deferred — adding it later is just
  a new key in the Ruby enum hash, no migration, since this is a plain string column.
- `amount_cents` is monetized (`monetize :amount_cents`, USD, matching Account/Category's
  established money-rails pattern) and **signed**: positive for income, negative for expense.
- The `[user_id, occurred_on]` index supports the unified feed's default sort (newest first,
  scoped to the user).

## Sign convention — self-correcting, not trusted from input

The form always shows a plain "Amount" field — you type a positive number and pick Income or
Expense from a dropdown; you never type a minus sign. A `before_validation` callback forces the
correct sign based on `txn_type` regardless of what was actually submitted:

```ruby
before_validation :apply_sign_convention

private
  def apply_sign_convention
    return if amount_cents.blank?
    self.amount_cents = income? ? amount_cents.abs : -amount_cents.abs
  end
```

This is idempotent on the sign of the input — a stray negative number submitted for an expense
still ends up correctly negative, not double-negated. This eliminates sign math from the
controller entirely; the model is the single source of truth for "what does this number mean."

## Two validations new to this model

`Transaction` is the first model in this app that references *other user-owned resources* by
foreign key from client-submitted params (`account_id`, `category_id`). Neither `Account` nor
`Category` needed this — they don't reference other user-owned records.

```ruby
validate :account_belongs_to_user
validate :category_belongs_to_user
validate :category_kind_matches_txn_type

private
  def account_belongs_to_user
    errors.add(:account, "must belong to you") if account && account.user_id != user_id
  end

  def category_belongs_to_user
    errors.add(:category, "must belong to you") if category && category.user_id != user_id
  end

  def category_kind_matches_txn_type
    return if category.blank? || txn_type.blank?
    errors.add(:category, "kind must match transaction type") if category.kind != txn_type
  end
```

- **Ownership**: defense against a crafted request submitting another user's `account_id`/
  `category_id` — the controller only ever *offers* the current user's own accounts/categories in
  the form, but a raw POST could submit anything, so the model itself must refuse it.
- **Kind match**: an expense transaction can't be tagged with an income category (e.g. "Salary")
  and vice versa. Real data-integrity, not just a UI nicety — without this, category-based
  spending reports (a later slice) would be silently wrong for any miscategorized transaction.

## Necessary follow-up to the already-shipped Account and Category models

Both currently use `dependent: :destroy` for their other associations (`Account`/`Category`
themselves are destroyed when their `User` is destroyed). Now that `Transaction` references them,
deleting an `Account` or `Category` that still has transaction history must **not** silently
cascade-delete that history — a user who deletes a "Groceries" category after months of spending
data shouldn't lose those transactions without being told.

Change both to `has_many :transactions, dependent: :restrict_with_error`. This makes `.destroy`
return `false` (not raise) and populate `errors` on the record when transactions exist.
`AccountsController#destroy` and `CategoriesController#destroy` currently assume `.destroy`
always succeeds (`@account.destroy; redirect_to ..., notice: "Account deleted."`) — both need to
check the result and show an error instead when restricted:

```ruby
def destroy
  if @account.destroy
    redirect_to accounts_path, notice: "Account deleted.", status: :see_other
  else
    redirect_to accounts_path, alert: "Can't delete #{@account.name}: it has transactions.", status: :see_other
  end
end
```

(Same shape for `CategoriesController#destroy`.) This is in scope for this slice because the
change is triggered by `Transaction` existing at all — Account/Category's original hard-delete
design was correct when nothing referenced them yet (per both of their own specs' explicit
reasoning), and this is that reasoning's natural continuation, not scope creep.

## Account balance becomes real

`Account` gets a `current_balance` method:

```ruby
def current_balance
  Money.new(starting_balance_cents + transactions.sum(:amount_cents), "USD")
end
```

Returns a `Money` object, matching how `starting_balance` already works. The Accounts index (`app/views/accounts/index.html.erb`)
switches from displaying the static `starting_balance` to this computed `current_balance` — this
is the moment Transactions actually becomes visible/useful from the Accounts page, not just its
own isolated CRUD screen.

## Controller, routes, views

- `resources :transactions, except: :show` (same lesson as Accounts/Categories).
- `TransactionsController`: `index`, `new`, `create`, `edit`, `update`, `destroy`, every action
  scoped through `Current.user.transactions`.
- `index` is a **unified feed** — all the user's transactions across every account, newest
  `occurred_on` first, each row showing which account and category it belongs to. Matches the
  stated use case ("track spending across different accounts").
- Form fields: Type (Income/Expense select), Account (select, from `Current.user.accounts`),
  Category (select, from `Current.user.categories` — ideally filtered/grouped by the selected
  type client-side so an income transaction only offers income categories, but the server-side
  `category_kind_matches_txn_type` validation is the actual guarantee regardless of what the
  client does), Amount, Date (`occurred_on`, defaults to today), Description (optional).

## Testing

- Model test: sign-convention callback (both directions, including a deliberately-wrong-signed
  input to prove it self-corrects), the two new validations (cross-user account, cross-user
  category, kind mismatch), presence validations, associations.
- Controller/integration test: full CRUD as a signed-in user, cross-user 404 on edit/update/
  destroy (same shape as Accounts/Categories), and specifically a test that an expense saved via
  a positive-amount form submission ends up negative in the database.
- Regression tests for the Account/Category `restrict_with_error` change: destroying an account/
  category *with* transactions fails and shows the error message; destroying one *without*
  transactions still works exactly as before (protects the existing, already-shipped destroy
  tests from silently changing behavior).
- Account balance test: `current_balance` reflects starting balance plus the sum of that
  account's transactions, and is unaffected by other accounts' or other users' transactions.
- No system test — manual/HTTP-walkthrough verification, same as every prior slice.
