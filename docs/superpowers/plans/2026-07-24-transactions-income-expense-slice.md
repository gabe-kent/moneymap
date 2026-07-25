# Income/Expense Transactions Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add `Transaction` (income or expense, tied to one account and one category) with full CRUD, a unified cross-account feed, and update the already-shipped Accounts index to show a real computed balance — per `docs/superpowers/specs/2026-07-24-transactions-income-expense-slice-design.md`.

**Architecture:** Same shape as Accounts/Categories for the CRUD parts. New this time: a model referencing two other user-owned resources by foreign key (requiring new ownership-validation patterns), a self-correcting sign convention, and a necessary safety change to the already-shipped `Account`/`Category` models (`dependent: :destroy` → `dependent: :restrict_with_error`) now that something references them.

**Tech Stack:** Rails 8.1.3, PostgreSQL, money-rails, DaisyUI, Minitest.

## Global Constraints

- Ruby 3.4, Rails 8.1.3 — existing app, follow its conventions exactly.
- **String literals: double-quoted** (Rubocop Omakase — `bin/rubocop` enforces this; run before every commit). Note: `bin/rubocop` chokes if given an `.erb` file path directly (it tries to parse it as raw Ruby and produces nonsense `Lint/Syntax` errors) — always run plain `bin/rubocop` with no arguments, or scope to non-erb files only, never `bin/rubocop app/views/some_file.html.erb`.
- **No `current_user` controller method exists.** The accessor is `Current.user`. Every controller action scopes through `Current.user.transactions` / `Current.user.accounts` / `Current.user.categories`, never `current_user`.
- **Every controller action scopes to the signed-in user.** Cross-user lookups 404 via `ActiveRecord::RecordNotFound` (already converted to a real 404 in tests by `config/environments/test.rb`'s `show_exceptions = :rescuable`).
- **`resources :transactions, except: :show`** — not bare `resources :transactions` (same lesson applied in the Accounts and Categories slices).
- **Money fields use money-rails' virtual dollar accessor in forms/params, never the raw `_cents` column.** `Transaction#amount` (virtual, from `monetize :amount_cents`) is what the form field and `transaction_params` use — matches `Account#starting_balance`'s existing pattern exactly.
- **The sign convention is enforced in the model, not the controller.** `before_validation :apply_sign_convention` forces `amount_cents` positive for income / negative for expense regardless of what was submitted. Never add sign-flipping logic to `TransactionsController` — the model is the single source of truth.
- Tests are Minitest, not RSpec. `ActiveSupport::TestCase` for models, `ActionDispatch::IntegrationTest` for controllers.
- **No fixture files for `accounts`/`categories`/`transactions`.** Create everything inline via `.create!`/`.build` on `users(:one)`/`users(:two)`, matching every prior slice.
- Run `bin/rubocop` after every task. Run the **full** `bin/rails test` suite before the final commit of the last task, and after Task 2 specifically (the `restrict_with_error` change touches already-shipped `Account`/`Category` destroy behavior — confirm no pre-existing test broke).

---

### Task 1: Transaction model

**Files:**
- Create: `db/migrate/<timestamp>_create_transactions.rb`
- Create: `app/models/transaction.rb`
- Modify: `app/models/user.rb`
- Test: `test/models/transaction_test.rb`

**Interfaces:**
- Produces: `Transaction` model with `belongs_to :user, :account, :category` (all required), `enum :txn_type` (`income`/`expense`), `monetize :amount_cents` (giving `#amount`/`#amount=` as a `Money` object, USD), a `before_validation` sign-convention callback, and validations: presence of `occurred_on`/`txn_type`/`amount_cents`, `account` must belong to the transaction's `user`, `category` must belong to the transaction's `user`, `category.kind` must equal `txn_type`.
- Produces: `User#transactions` (`has_many`, `dependent: :destroy` — this is a full account wipe on user deletion, different from the `restrict_with_error` Task 2 adds to `Account`/`Category`'s own associations).
- Later tasks consume: `Current.user.transactions` (build/find/order/count), `Transaction.txn_types` (enum-generated class method), `transaction.amount`.

- [ ] **Step 1: Generate the migration**

  Run: `bin/rails generate migration CreateTransactions`

  Note the actual filename it prints — you'll edit that exact file next.

- [ ] **Step 2: Write the migration**

  Replace the generated file's contents with:

  ```ruby
  class CreateTransactions < ActiveRecord::Migration[8.1]
    def change
      create_table :transactions do |t|
        t.references :user, null: false, foreign_key: true
        t.references :account, null: false, foreign_key: true
        t.references :category, null: false, foreign_key: true
        t.integer :amount_cents, null: false
        t.string :description
        t.date :occurred_on, null: false
        t.string :txn_type, null: false

        t.timestamps
      end

      add_index :transactions, [ :user_id, :occurred_on ]
    end
  end
  ```

- [ ] **Step 3: Run the migration**

  Run: `bin/rails db:migrate`
  Expected: `== CreateTransactions: migrating ... == CreateTransactions: migrated` with no errors. Confirm `db/schema.rb` has a `create_table "transactions"` block with foreign keys to `users`, `accounts`, and `categories`.

- [ ] **Step 4: Write the failing model test**

  Create `test/models/transaction_test.rb`:

  ```ruby
  require "test_helper"

  class TransactionTest < ActiveSupport::TestCase
    setup do
      @user = users(:one)
      @account = @user.accounts.create!(name: "Checking", kind: "checking")
      @category = @user.categories.create!(name: "Groceries", kind: "expense", color: "orange")
      @income_category = @user.categories.create!(name: "Salary", kind: "income", color: "green")
    end

    test "valid with account, category, amount, occurred_on, and txn_type" do
      transaction = @user.transactions.build(account: @account, category: @category, amount_cents: 4500, occurred_on: Date.current, txn_type: "expense")
      assert transaction.valid?
    end

    test "invalid without occurred_on" do
      transaction = @user.transactions.build(account: @account, category: @category, amount_cents: 4500, txn_type: "expense")
      assert_not transaction.valid?
      assert_includes transaction.errors[:occurred_on], "can't be blank"
    end

    test "invalid without txn_type" do
      transaction = @user.transactions.build(account: @account, category: @category, amount_cents: 4500, occurred_on: Date.current)
      assert_not transaction.valid?
      assert_includes transaction.errors[:txn_type], "can't be blank"
    end

    test "raises on a txn_type outside the fixed list" do
      transaction = @user.transactions.build(account: @account, category: @category, amount_cents: 4500, occurred_on: Date.current)
      assert_raises(ArgumentError) { transaction.txn_type = "transfer" }
    end

    test "forces a positive amount for income regardless of submitted sign" do
      transaction = @user.transactions.create!(account: @account, category: @income_category, amount_cents: -5000, occurred_on: Date.current, txn_type: "income")
      assert_equal 5000, transaction.amount_cents
    end

    test "forces a negative amount for expense regardless of submitted sign" do
      transaction = @user.transactions.create!(account: @account, category: @category, amount_cents: 4500, occurred_on: Date.current, txn_type: "expense")
      assert_equal(-4500, transaction.amount_cents)
    end

    test "amount is monetized in USD" do
      transaction = @user.transactions.create!(account: @account, category: @category, amount_cents: 4500, occurred_on: Date.current, txn_type: "expense")
      assert_equal Money.new(-4500, "USD"), transaction.amount
    end

    test "invalid with an account belonging to another user" do
      other_account = users(:two).accounts.create!(name: "Their Checking", kind: "checking")
      transaction = @user.transactions.build(account: other_account, category: @category, amount_cents: 4500, occurred_on: Date.current, txn_type: "expense")

      assert_not transaction.valid?
      assert_includes transaction.errors[:account], "must belong to you"
    end

    test "invalid with a category belonging to another user" do
      other_category = users(:two).categories.create!(name: "Their Groceries", kind: "expense", color: "orange")
      transaction = @user.transactions.build(account: @account, category: other_category, amount_cents: 4500, occurred_on: Date.current, txn_type: "expense")

      assert_not transaction.valid?
      assert_includes transaction.errors[:category], "must belong to you"
    end

    test "invalid when category kind does not match txn_type" do
      transaction = @user.transactions.build(account: @account, category: @income_category, amount_cents: 4500, occurred_on: Date.current, txn_type: "expense")

      assert_not transaction.valid?
      assert_includes transaction.errors[:category], "kind must match transaction type"
    end

    test "requires a user" do
      transaction = Transaction.new(account: @account, category: @category, amount_cents: 4500, occurred_on: Date.current, txn_type: "expense")
      assert_not transaction.valid?
      assert_includes transaction.errors[:user], "must exist"
    end

    test "destroying a user destroys their transactions" do
      transaction = @user.transactions.create!(account: @account, category: @category, amount_cents: 4500, occurred_on: Date.current, txn_type: "expense")
      assert_difference -> { Transaction.count }, -1 do
        @user.destroy
      end
      assert_not Transaction.exists?(transaction.id)
    end
  end
  ```

- [ ] **Step 5: Run the test to verify it fails**

  Run: `bin/rails test test/models/transaction_test.rb`
  Expected: FAIL — `NameError: uninitialized constant TransactionTest::Transaction` (the model doesn't exist yet).

- [ ] **Step 6: Write the Transaction model**

  Create `app/models/transaction.rb`:

  ```ruby
  class Transaction < ApplicationRecord
    belongs_to :user
    belongs_to :account
    belongs_to :category

    monetize :amount_cents

    enum :txn_type, {
      income: "income",
      expense: "expense"
    }

    before_validation :apply_sign_convention

    validates :occurred_on, presence: true
    validates :txn_type, presence: true
    validates :amount_cents, presence: true
    validate :account_belongs_to_user
    validate :category_belongs_to_user
    validate :category_kind_matches_txn_type

    private
      def apply_sign_convention
        return if amount_cents.blank?
        self.amount_cents = income? ? amount_cents.abs : -amount_cents.abs
      end

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
  end
  ```

- [ ] **Step 7: Add the association to User**

  In `app/models/user.rb`, add `has_many :transactions, dependent: :destroy` alongside the existing associations:

  ```ruby
  class User < ApplicationRecord
    has_secure_password
    has_many :sessions, dependent: :destroy
    has_many :accounts, dependent: :destroy
    has_many :categories, dependent: :destroy
    has_many :transactions, dependent: :destroy

    normalizes :email_address, with: ->(e) { e.strip.downcase }

    after_create :seed_default_categories

    private
      def seed_default_categories
        SeedDefaultCategories.new(self).call
      end
  end
  ```

- [ ] **Step 8: Run the test to verify it passes**

  Run: `bin/rails test test/models/transaction_test.rb`
  Expected: `12 runs, ... 0 failures, 0 errors`

- [ ] **Step 9: Rubocop**

  Run: `bin/rubocop app/models/transaction.rb app/models/user.rb test/models/transaction_test.rb`
  Expected: `no offenses detected`.

- [ ] **Step 10: Commit**

  ```bash
  git add db/migrate app/models/transaction.rb app/models/user.rb test/models/transaction_test.rb db/schema.rb
  git commit -m "Add Transaction model, scoped to user"
  ```

---

### Task 2: Protect Account and Category from cascade-delete

**Files:**
- Modify: `app/models/account.rb`
- Modify: `app/models/category.rb`
- Modify: `app/controllers/accounts_controller.rb`
- Modify: `app/controllers/categories_controller.rb`
- Test: Modify `test/models/account_test.rb`
- Test: Modify `test/models/category_test.rb`
- Test: Modify `test/controllers/accounts_controller_test.rb`
- Test: Modify `test/controllers/categories_controller_test.rb`

**Interfaces:**
- Consumes (from Task 1): `Transaction`, `account.transactions` / `category.transactions` (from the `belongs_to :account` / `belongs_to :category` on Transaction, Rails auto-generates the inverse — this task adds the explicit `has_many :transactions` on both sides).
- Produces: `Account#destroy` and `Category#destroy` now return `false` (not raise, not silently succeed) when the record has transactions. `AccountsController#destroy` / `CategoriesController#destroy` now check the result and redirect with an `alert` instead of a `notice` on failure.

This task's correctness is proven by BOTH a new "cannot destroy with transactions" test AND the EXISTING "destroy removes the account/category" tests continuing to pass unmodified — those tests create records with no transactions, so `restrict_with_error` must not interfere with them.

- [ ] **Step 1: Confirm the regression baseline**

  Run: `bin/rails test test/models/account_test.rb test/models/category_test.rb test/controllers/accounts_controller_test.rb test/controllers/categories_controller_test.rb`
  Expected: all passing, before you change anything.

- [ ] **Step 2: Change the associations**

  In `app/models/account.rb`, add `has_many :transactions, dependent: :restrict_with_error` right after `belongs_to :user`:

  ```ruby
  class Account < ApplicationRecord
    belongs_to :user
    has_many :transactions, dependent: :restrict_with_error

    monetize :starting_balance_cents

    enum :kind, {
      checking: "checking",
      savings: "savings",
      cash: "cash",
      credit: "credit",
      investment: "investment"
    }

    validates :name, presence: true
    validates :kind, presence: true
    validates :starting_balance_cents, presence: true
  end
  ```

  In `app/models/category.rb`, same pattern:

  ```ruby
  class Category < ApplicationRecord
    belongs_to :user
    has_many :transactions, dependent: :restrict_with_error

    enum :kind, {
      income: "income",
      expense: "expense"
    }

    enum :color, {
      red: "red",
      orange: "orange",
      yellow: "yellow",
      green: "green",
      teal: "teal",
      blue: "blue",
      purple: "purple",
      pink: "pink"
    }

    validates :name, presence: true, uniqueness: { scope: :user_id, case_sensitive: false }
    validates :kind, presence: true
    validates :color, presence: true
  end
  ```

- [ ] **Step 3: Write the failing model tests**

  In `test/models/account_test.rb`, add two tests (keep every existing test unchanged):

  ```ruby
  test "cannot be destroyed while it has transactions" do
    category = @user.categories.create!(name: "Groceries", kind: "expense", color: "orange")
    account = @user.accounts.create!(name: "Checking", kind: "checking")
    account.transactions.create!(user: @user, category: category, amount_cents: 4500, occurred_on: Date.current, txn_type: "expense")

    assert_not account.destroy
    assert Account.exists?(account.id)
  end

  test "can still be destroyed when it has no transactions" do
    account = @user.accounts.create!(name: "Checking", kind: "checking")
    assert account.destroy
    assert_not Account.exists?(account.id)
  end
  ```

  In `test/models/category_test.rb`, add two tests (keep every existing test unchanged):

  ```ruby
  test "cannot be destroyed while it has transactions" do
    account = @user.accounts.create!(name: "Checking", kind: "checking")
    category = @user.categories.create!(name: "Groceries", kind: "expense", color: "orange")
    category.transactions.create!(user: @user, account: account, amount_cents: 4500, occurred_on: Date.current, txn_type: "expense")

    assert_not category.destroy
    assert Category.exists?(category.id)
  end

  test "can still be destroyed when it has no transactions" do
    category = @user.categories.create!(name: "Groceries", kind: "expense", color: "orange")
    assert category.destroy
    assert_not Category.exists?(category.id)
  end
  ```

- [ ] **Step 4: Run the tests to verify they pass**

  Run: `bin/rails test test/models/account_test.rb test/models/category_test.rb`
  Expected: all four new tests PASS, plus every pre-existing test in both files. This task doesn't
  follow a strict TDD red-then-green cycle for the association change itself — Step 2 already
  added `has_many :transactions, dependent: :restrict_with_error` before these tests were written,
  so there's no RED step to observe here. If any of the four new tests fail, the association from
  Step 2 isn't wired up correctly — double check it's actually present in both model files.

- [ ] **Step 5: Write the controller changes**

  In `app/controllers/accounts_controller.rb`, change the `destroy` action:

  ```ruby
  def destroy
    if @account.destroy
      redirect_to accounts_path, notice: "Account deleted.", status: :see_other
    else
      redirect_to accounts_path, alert: "Cannot delete #{@account.name}: it has transactions.", status: :see_other
    end
  end
  ```

  In `app/controllers/categories_controller.rb`, same pattern:

  ```ruby
  def destroy
    if @category.destroy
      redirect_to categories_path, notice: "Category deleted.", status: :see_other
    else
      redirect_to categories_path, alert: "Cannot delete #{@category.name}: it has transactions.", status: :see_other
    end
  end
  ```

  Note: the message uses "Cannot" rather than a "Can't" contraction deliberately — an apostrophe gets HTML-escaped (`&#39;`) when rendered through the flash partial, which would make an exact-string test assertion fragile. "Cannot" sidesteps that entirely.

- [ ] **Step 6: Write the failing controller tests**

  In `test/controllers/accounts_controller_test.rb`, add one test (keep every existing test unchanged):

  ```ruby
  test "destroy fails and shows an error when the account has transactions" do
    category = @user.categories.create!(name: "Groceries", kind: "expense", color: "orange")
    @account.transactions.create!(user: @user, category: category, amount_cents: 4500, occurred_on: Date.current, txn_type: "expense")

    assert_no_difference -> { Account.count } do
      delete account_path(@account)
    end

    assert_redirected_to accounts_path
    follow_redirect!
    assert_includes response.body, "Cannot delete"
  end
  ```

  In `test/controllers/categories_controller_test.rb`, add one test (keep every existing test unchanged):

  ```ruby
  test "destroy fails and shows an error when the category has transactions" do
    account = @user.accounts.create!(name: "Checking", kind: "checking")
    @category.transactions.create!(user: @user, account: account, amount_cents: 4500, occurred_on: Date.current, txn_type: "expense")

    assert_no_difference -> { Category.count } do
      delete category_path(@category)
    end

    assert_redirected_to categories_path
    follow_redirect!
    assert_includes response.body, "Cannot delete"
  end
  ```

- [ ] **Step 7: Run all four test files**

  Run: `bin/rails test test/models/account_test.rb test/models/category_test.rb test/controllers/accounts_controller_test.rb test/controllers/categories_controller_test.rb`
  Expected: all passing, including every pre-existing test (the "destroy removes the account"/"destroy removes the category" tests from the Accounts/Categories slices must still pass unmodified — they destroy records with zero transactions, so `restrict_with_error` doesn't affect them).

- [ ] **Step 8: Run the full suite**

  Run: `bin/rails test`
  Expected: all tests pass, including Task 1's `transaction_test.rb`.

- [ ] **Step 9: Rubocop**

  Run: `bin/rubocop app/models/account.rb app/models/category.rb app/controllers/accounts_controller.rb app/controllers/categories_controller.rb test/models/account_test.rb test/models/category_test.rb test/controllers/accounts_controller_test.rb test/controllers/categories_controller_test.rb`
  Expected: `no offenses detected`.

- [ ] **Step 10: Commit**

  ```bash
  git add app/models/account.rb app/models/category.rb app/controllers/accounts_controller.rb app/controllers/categories_controller.rb test/models/account_test.rb test/models/category_test.rb test/controllers/accounts_controller_test.rb test/controllers/categories_controller_test.rb
  git commit -m "Protect Account and Category from cascade-delete now that Transaction references them"
  ```

---

### Task 3: Transactions routes, controller, and views

**Files:**
- Modify: `config/routes.rb`
- Create: `app/controllers/transactions_controller.rb`
- Create: `app/views/transactions/index.html.erb`
- Create: `app/views/transactions/_form.html.erb`
- Create: `app/views/transactions/new.html.erb`
- Create: `app/views/transactions/edit.html.erb`
- Test: `test/controllers/transactions_controller_test.rb`

**Interfaces:**
- Consumes (from Task 1): `Current.user.transactions` (`.build`, `.find`, `.order`, `.count`, `.includes`), `Transaction.txn_types`, `transaction.amount`.
- Consumes: `Current.user.accounts`, `Current.user.categories` (for the form's select options).
- Produces: routes `transactions_path` (GET/POST), `new_transaction_path` (GET), `edit_transaction_path(transaction)` (GET), `transaction_path(transaction)` (PATCH/PUT, DELETE).

- [ ] **Step 1: Add the route**

  In `config/routes.rb`, add `resources :transactions, except: :show` after `resources :categories, except: :show`:

  ```ruby
  Rails.application.routes.draw do
    mount RailsIcons::Engine, at: "/rails_icons"
    get "home/index"
    resource :session
    resources :passwords, param: :token
    resources :accounts, except: :show
    resources :categories, except: :show
    resources :transactions, except: :show
    # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

    # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
    # Can be used by load balancers and uptime monitors to verify that the app is live.
    get "up" => "rails/health#show", as: :rails_health_check

    # Render dynamic PWA files from app/views/pwa/* (remember to link manifest in application.html.erb)
    # get "manifest" => "rails/pwa#manifest", as: :pwa_manifest
    # get "service-worker" => "rails/pwa#service_worker", as: :pwa_service_worker

    # Defines the root path route ("/")
    root "home#index"
  end
  ```

- [ ] **Step 2: Write the failing controller test**

  Create `test/controllers/transactions_controller_test.rb`:

  ```ruby
  require "test_helper"

  class TransactionsControllerTest < ActionDispatch::IntegrationTest
    setup do
      @user = users(:one)
      @other_user = users(:two)
      @account = @user.accounts.create!(name: "Checking", kind: "checking")
      @category = @user.categories.create!(name: "Groceries", kind: "expense", color: "orange")
      @income_category = @user.categories.create!(name: "Salary", kind: "income", color: "green")
      @transaction = @user.transactions.create!(account: @account, category: @category, amount_cents: 4500, occurred_on: Date.current, txn_type: "expense")
      sign_in_as @user
    end

    test "index lists only the current user's transactions" do
      other_account = @other_user.accounts.create!(name: "Their Checking", kind: "checking")
      other_category = @other_user.categories.create!(name: "Their Groceries", kind: "expense", color: "orange")
      @other_user.transactions.create!(account: other_account, category: other_category, amount_cents: 1000, occurred_on: Date.current, txn_type: "expense")

      get transactions_path

      assert_response :success
      assert_includes response.body, @account.name
      assert_not_includes response.body, other_account.name
    end

    test "new renders the form" do
      get new_transaction_path
      assert_response :success
    end

    test "create with valid params applies the sign convention" do
      assert_difference -> { @user.transactions.count }, 1 do
        post transactions_path, params: { transaction: { account_id: @account.id, category_id: @category.id, amount: "45.00", occurred_on: Date.current, txn_type: "expense" } }
      end

      assert_redirected_to transactions_path
      assert_equal(-4500, @user.transactions.order(:created_at).last.amount_cents)
    end

    test "create with invalid params re-renders the form" do
      assert_no_difference -> { Transaction.count } do
        post transactions_path, params: { transaction: { account_id: @account.id, category_id: @category.id, amount: "45.00", txn_type: "expense" } }
      end

      assert_response :unprocessable_entity
    end

    test "create with another user's account re-renders the form" do
      other_account = @other_user.accounts.create!(name: "Their Checking", kind: "checking")

      assert_no_difference -> { Transaction.count } do
        post transactions_path, params: { transaction: { account_id: other_account.id, category_id: @category.id, amount: "45.00", occurred_on: Date.current, txn_type: "expense" } }
      end

      assert_response :unprocessable_entity
    end

    test "create with a mismatched category kind re-renders the form" do
      assert_no_difference -> { Transaction.count } do
        post transactions_path, params: { transaction: { account_id: @account.id, category_id: @income_category.id, amount: "45.00", occurred_on: Date.current, txn_type: "expense" } }
      end

      assert_response :unprocessable_entity
    end

    test "edit renders the form for the current user's transaction" do
      get edit_transaction_path(@transaction)
      assert_response :success
    end

    test "edit on another user's transaction is not found" do
      other_account = @other_user.accounts.create!(name: "Their Checking", kind: "checking")
      other_category = @other_user.categories.create!(name: "Their Groceries", kind: "expense", color: "orange")
      other_transaction = @other_user.transactions.create!(account: other_account, category: other_category, amount_cents: 1000, occurred_on: Date.current, txn_type: "expense")

      get edit_transaction_path(other_transaction)

      assert_response :not_found
    end

    test "update with valid params" do
      patch transaction_path(@transaction), params: { transaction: { description: "Updated" } }

      assert_redirected_to transactions_path
      assert_equal "Updated", @transaction.reload.description
    end

    test "update on another user's transaction is not found" do
      other_account = @other_user.accounts.create!(name: "Their Checking", kind: "checking")
      other_category = @other_user.categories.create!(name: "Their Groceries", kind: "expense", color: "orange")
      other_transaction = @other_user.transactions.create!(account: other_account, category: other_category, amount_cents: 1000, occurred_on: Date.current, txn_type: "expense")

      patch transaction_path(other_transaction), params: { transaction: { description: "Hijacked" } }

      assert_response :not_found
      assert_not_equal "Hijacked", other_transaction.reload.description
    end

    test "destroy removes the transaction" do
      assert_difference -> { Transaction.count }, -1 do
        delete transaction_path(@transaction)
      end

      assert_redirected_to transactions_path
    end

    test "destroy on another user's transaction is not found" do
      other_account = @other_user.accounts.create!(name: "Their Checking", kind: "checking")
      other_category = @other_user.categories.create!(name: "Their Groceries", kind: "expense", color: "orange")
      other_transaction = @other_user.transactions.create!(account: other_account, category: other_category, amount_cents: 1000, occurred_on: Date.current, txn_type: "expense")

      assert_no_difference -> { Transaction.count } do
        delete transaction_path(other_transaction)
      end

      assert_response :not_found
    end
  end
  ```

- [ ] **Step 3: Run the tests to verify they fail**

  Run: `bin/rails test test/controllers/transactions_controller_test.rb`
  Expected: FAIL — `uninitialized constant TransactionsController` (route exists from Step 1, controller doesn't).

- [ ] **Step 4: Write the controller**

  Create `app/controllers/transactions_controller.rb`:

  ```ruby
  class TransactionsController < ApplicationController
    before_action :set_transaction, only: %i[ edit update destroy ]

    def index
      @transactions = Current.user.transactions.includes(:account, :category).order(occurred_on: :desc, created_at: :desc)
    end

    def new
      @transaction = Current.user.transactions.build(occurred_on: Date.current)
    end

    def create
      @transaction = Current.user.transactions.build(transaction_params)

      if @transaction.save
        redirect_to transactions_path, notice: "Transaction created."
      else
        render :new, status: :unprocessable_entity
      end
    end

    def edit
    end

    def update
      if @transaction.update(transaction_params)
        redirect_to transactions_path, notice: "Transaction updated."
      else
        render :edit, status: :unprocessable_entity
      end
    end

    def destroy
      @transaction.destroy
      redirect_to transactions_path, notice: "Transaction deleted.", status: :see_other
    end

    private
      def set_transaction
        @transaction = Current.user.transactions.find(params[:id])
      end

      def transaction_params
        params.expect(transaction: [ :account_id, :category_id, :amount, :occurred_on, :txn_type, :description ])
      end
  end
  ```

  Note `transaction_params` permits `:amount` (the money-rails virtual dollar accessor from Task 1), **not** `:amount_cents` — same pattern as `Account#starting_balance` / `AccountsController#account_params`.

- [ ] **Step 5: Write the shared form partial**

  Create `app/views/transactions/_form.html.erb`:

  ```erb
  <%= form_with model: transaction, class: "w-full max-w-md" do |form| %>
    <% if transaction.errors.any? %>
      <div class="alert alert-error mb-5">
        <ul>
          <% transaction.errors.each do |error| %>
            <li><%= error.full_message %></li>
          <% end %>
        </ul>
      </div>
    <% end %>

    <div class="mb-4">
      <%= form.label :txn_type, "Type", class: "label" %>
      <%= form.select :txn_type, Transaction.txn_types.keys.map { |k| [ k.titleize, k ] }, { prompt: "Select a type" }, { required: true, class: "select select-bordered w-full" } %>
    </div>

    <div class="mb-4">
      <%= form.label :account_id, "Account", class: "label" %>
      <%= form.select :account_id, Current.user.accounts.order(:name).map { |a| [ a.name, a.id ] }, { prompt: "Select an account" }, { required: true, class: "select select-bordered w-full" } %>
    </div>

    <div class="mb-4">
      <%= form.label :category_id, "Category", class: "label" %>
      <%= form.select :category_id, Current.user.categories.order(:name).map { |c| [ "#{c.name} (#{c.kind.titleize})", c.id ] }, { prompt: "Select a category" }, { required: true, class: "select select-bordered w-full" } %>
    </div>

    <div class="mb-4">
      <%= form.label :amount, class: "label" %>
      <%= form.number_field :amount, step: "0.01", min: "0", class: "input input-bordered w-full" %>
    </div>

    <div class="mb-4">
      <%= form.label :occurred_on, "Date", class: "label" %>
      <%= form.date_field :occurred_on, required: true, class: "input input-bordered w-full" %>
    </div>

    <div class="mb-6">
      <%= form.label :description, class: "label" %>
      <%= form.text_field :description, class: "input input-bordered w-full" %>
    </div>

    <%= form.submit class: "btn btn-primary" %>
  <% end %>
  ```

  The category select shows each option as "Name (Kind)" (e.g. "Groceries (Expense)") so it's visually clear which categories are income vs expense without needing JavaScript to filter the list — the server-side `category_kind_matches_txn_type` validation (Task 1) is the actual guarantee against a mismatch; this labeling is just a helpful hint, not the enforcement mechanism.

- [ ] **Step 6: Write the index, new, and edit views**

  Create `app/views/transactions/index.html.erb`:

  ```erb
  <div class="w-full">
    <div class="flex justify-between items-center mb-6">
      <h1 class="text-4xl font-bold">Transactions</h1>
      <%= link_to "New Transaction", new_transaction_path, class: "btn btn-primary" %>
    </div>

    <div class="overflow-x-auto">
      <table class="table">
        <thead>
          <tr>
            <th>Date</th>
            <th>Account</th>
            <th>Category</th>
            <th>Description</th>
            <th>Amount</th>
            <th></th>
          </tr>
        </thead>
        <tbody>
          <% @transactions.each do |transaction| %>
            <tr>
              <td><%= transaction.occurred_on.to_fs(:long) %></td>
              <td><%= transaction.account.name %></td>
              <td><%= transaction.category.name %></td>
              <td><%= transaction.description %></td>
              <td><%= humanized_money_with_symbol transaction.amount %></td>
              <td class="text-right">
                <%= link_to "Edit", edit_transaction_path(transaction), class: "btn btn-sm btn-ghost" %>
                <%= button_to "Delete", transaction_path(transaction), method: :delete, data: { turbo_confirm: "Delete this transaction?" }, class: "btn btn-sm btn-ghost text-error" %>
              </td>
            </tr>
          <% end %>
        </tbody>
      </table>
    </div>
  </div>
  ```

  Create `app/views/transactions/new.html.erb`:

  ```erb
  <div class="w-full">
    <h1 class="text-4xl font-bold mb-6">New Transaction</h1>
    <%= render "form", transaction: @transaction %>
  </div>
  ```

  Create `app/views/transactions/edit.html.erb`:

  ```erb
  <div class="w-full">
    <h1 class="text-4xl font-bold mb-6">Edit Transaction</h1>
    <%= render "form", transaction: @transaction %>
  </div>
  ```

- [ ] **Step 7: Run the tests to verify they pass**

  Run: `bin/rails test test/controllers/transactions_controller_test.rb`
  Expected: `12 runs, ... 0 failures, 0 errors`

- [ ] **Step 8: Rubocop**

  Run: `bin/rubocop config/routes.rb app/controllers/transactions_controller.rb test/controllers/transactions_controller_test.rb`
  Expected: `no offenses detected`. Remember: do not run rubocop directly against the `.erb` files (see Global Constraints).

- [ ] **Step 9: Manual verification**

  Boot the app (or use the real-HTTP-request substitute if no browser tooling is available, as used throughout this project — cookies, CSRF, real POST/PATCH/DELETE against `bin/rails server`):

  ```bash
  bin/rails tailwindcss:build
  bin/dev
  ```

  Sign in, visit `/transactions`, create an expense and an income transaction, confirm the amount displays with the correct sign (negative for expense, positive for income) and the category shows "(Expense)"/"(Income)" correctly in the form. Try submitting an expense with an income category selected — confirm it's rejected with a clear error, not silently accepted. Edit one, delete one. Stop `bin/dev` with Ctrl+C when done.

- [ ] **Step 10: Run the full suite**

  Run: `bin/rails test`
  Expected: all tests pass — Tasks 1, 2, and 3 together, plus every pre-existing test.

- [ ] **Step 11: Commit**

  ```bash
  git add config/routes.rb app/controllers/transactions_controller.rb app/views/transactions test/controllers/transactions_controller_test.rb
  git commit -m "Add Transactions CRUD, scoped to the current user"
  ```

---

### Task 4: Account current balance

**Files:**
- Modify: `app/models/account.rb`
- Modify: `app/views/accounts/index.html.erb`
- Test: Modify `test/models/account_test.rb`
- Test: Modify `test/controllers/accounts_controller_test.rb`

**Interfaces:**
- Consumes (from Task 1): `account.transactions.sum(:amount_cents)`.
- Produces: `Account#current_balance`, returning a `Money` object — `starting_balance_cents + sum of this account's transactions' amount_cents`.

This is the task where Transactions actually becomes visible from outside its own CRUD screen — until now, the Accounts index only ever showed the static `starting_balance`.

- [ ] **Step 1: Write the failing model tests**

  In `test/models/account_test.rb`, add three tests (keep every existing test unchanged):

  ```ruby
  test "current_balance is the starting balance when there are no transactions" do
    account = @user.accounts.create!(name: "Checking", kind: "checking", starting_balance_cents: 10_000)
    assert_equal Money.new(10_000, "USD"), account.current_balance
  end

  test "current_balance reflects the sum of its transactions" do
    category = @user.categories.create!(name: "Groceries", kind: "expense", color: "orange")
    account = @user.accounts.create!(name: "Checking", kind: "checking", starting_balance_cents: 10_000)
    account.transactions.create!(user: @user, category: category, amount_cents: 4500, occurred_on: Date.current, txn_type: "expense")

    assert_equal Money.new(5_500, "USD"), account.current_balance
  end

  test "current_balance is unaffected by other accounts' transactions" do
    category = @user.categories.create!(name: "Groceries", kind: "expense", color: "orange")
    account = @user.accounts.create!(name: "Checking", kind: "checking", starting_balance_cents: 10_000)
    other_account = @user.accounts.create!(name: "Savings", kind: "savings", starting_balance_cents: 20_000)
    other_account.transactions.create!(user: @user, category: category, amount_cents: 4500, occurred_on: Date.current, txn_type: "expense")

    assert_equal Money.new(10_000, "USD"), account.current_balance
  end
  ```

- [ ] **Step 2: Run the tests to verify they fail**

  Run: `bin/rails test test/models/account_test.rb`
  Expected: FAIL — `NoMethodError: undefined method 'current_balance' for an instance of Account`.

- [ ] **Step 3: Add the method**

  In `app/models/account.rb`, add `current_balance` as a public method (after the `monetize`/`enum` declarations, alongside the existing validations is fine — Ruby doesn't care about method-vs-macro ordering here):

  ```ruby
  class Account < ApplicationRecord
    belongs_to :user
    has_many :transactions, dependent: :restrict_with_error

    monetize :starting_balance_cents

    enum :kind, {
      checking: "checking",
      savings: "savings",
      cash: "cash",
      credit: "credit",
      investment: "investment"
    }

    validates :name, presence: true
    validates :kind, presence: true
    validates :starting_balance_cents, presence: true

    def current_balance
      Money.new(starting_balance_cents + transactions.sum(:amount_cents), "USD")
    end
  end
  ```

- [ ] **Step 4: Run the tests to verify they pass**

  Run: `bin/rails test test/models/account_test.rb`
  Expected: all passing (the pre-existing tests plus the three new ones).

- [ ] **Step 5: Update the Accounts index view**

  In `app/views/accounts/index.html.erb`, change the "Starting balance" column header to "Balance" and display `current_balance` instead of `starting_balance`:

  ```erb
  <div class="w-full">
    <div class="flex justify-between items-center mb-6">
      <h1 class="text-4xl font-bold">Accounts</h1>
      <%= link_to "New Account", new_account_path, class: "btn btn-primary" %>
    </div>

    <div class="overflow-x-auto">
      <table class="table">
        <thead>
          <tr>
            <th>Name</th>
            <th>Kind</th>
            <th>Balance</th>
            <th></th>
          </tr>
        </thead>
        <tbody>
          <% @accounts.each do |account| %>
            <tr>
              <td><%= account.name %></td>
              <td><%= account.kind.titleize %></td>
              <td><%= humanized_money_with_symbol account.current_balance %></td>
              <td class="text-right">
                <%= link_to "Edit", edit_account_path(account), class: "btn btn-sm btn-ghost" %>
                <%= button_to "Delete", account_path(account), method: :delete, data: { turbo_confirm: "Delete #{account.name}?" }, class: "btn btn-sm btn-ghost text-error" %>
              </td>
            </tr>
          <% end %>
        </tbody>
      </table>
    </div>
  </div>
  ```

- [ ] **Step 6: Write the failing controller test**

  In `test/controllers/accounts_controller_test.rb`, add one test (keep every existing test unchanged):

  ```ruby
  test "index shows the account's current balance including transactions" do
    category = @user.categories.create!(name: "Groceries", kind: "expense", color: "orange")
    account = @user.accounts.create!(name: "Checking", kind: "checking", starting_balance_cents: 10_000)
    account.transactions.create!(user: @user, category: category, amount_cents: 4500, occurred_on: Date.current, txn_type: "expense")

    get accounts_path

    assert_response :success
    assert_includes response.body, "$55.00"
  end
  ```

- [ ] **Step 7: Run the tests to verify they pass**

  Run: `bin/rails test test/controllers/accounts_controller_test.rb`
  Expected: all passing.

- [ ] **Step 8: Rubocop**

  Run: `bin/rubocop app/models/account.rb test/models/account_test.rb test/controllers/accounts_controller_test.rb`
  Expected: `no offenses detected`.

- [ ] **Step 9: Manual verification**

  ```bash
  bin/rails tailwindcss:build
  bin/dev
  ```

  Visit `/accounts` — confirm the "Balance" column reflects starting balance plus any transactions on that account, not just the static starting balance. Create a transaction against an account from `/transactions/new`, then revisit `/accounts` and confirm the balance updated. Stop `bin/dev` with Ctrl+C when done.

- [ ] **Step 10: Run the full suite one more time**

  Run: `bin/rails test`
  Expected: all tests pass — every task in this plan, plus every pre-existing test in the app.

- [ ] **Step 11: Commit**

  ```bash
  git add app/models/account.rb app/views/accounts/index.html.erb test/models/account_test.rb test/controllers/accounts_controller_test.rb
  git commit -m "Show computed current balance on the Accounts index"
  ```

- [ ] **Step 12: Push**

  ```bash
  git push
  ```

  This triggers a Render auto-deploy. Check `render deploys list srv-d9eu93rrjlhs73d4usp0 --output json` (or the Render dashboard) for `live` status, and spot-check `https://moneymap-1rbv.onrender.com/transactions` and `https://moneymap-1rbv.onrender.com/accounts` after signing in.
