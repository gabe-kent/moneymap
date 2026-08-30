# Transfers Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add transfers between the user's own accounts — two linked `Transaction` rows, created/edited/deleted together — integrated into the existing "New Transaction" page, per `docs/superpowers/specs/2026-07-24-transfers-slice-design.md`.

**Architecture:** A `transfer_id` column shared by both legs (not a self-referential foreign key), a `TransferForm` (`app/models/`, plain `ActiveModel::Model`, not an AR model) that wraps both legs behind one bindable object, a separate `TransfersController`/`resources :transfers` with no index/show, and a small Stimulus controller toggling between two independent `<form>` elements on `/transactions/new`.

**Tech Stack:** Rails 8.1.3, PostgreSQL, money-rails, Stimulus (via importmaps — this app has no npm/Node), Minitest.

## Global Constraints

- Ruby 3.4, Rails 8.1.3 — existing app, follow its conventions exactly.
- **String literals: double-quoted** (Rubocop Omakase — `bin/rubocop` enforces this). **Never run `bin/rubocop` directly against an `.erb` file path** — this app's rubocop config parses it as raw Ruby and produces nonsense `Lint/Syntax` errors. Run plain `bin/rubocop` (no args) or scope to `.rb`/`.js` files only.
- **No `current_user` controller method exists.** The accessor is `Current.user`.
- **Every controller action scopes to the signed-in user.** Cross-user lookups 404 via `ActiveRecord::RecordNotFound` (already converted to a real 404 in tests by `config/environments/test.rb`'s `show_exceptions = :rescuable`).
- **`resources :transfers, only: %i[ new create edit update destroy ]`** — deliberately no `index`/`show`. Transfers are only ever viewed via the unified Transactions feed, as their two ordinary-looking legs.
- **`TransferForm` lives in `app/models/transfer_form.rb`, not `app/services/`.** It has several public methods (`.find`/`.save`/`.destroy`), not the single `#call` CLAUDE.md's services convention expects — this is a Form Object, which Rails convention places alongside real models since it uses the same `ActiveModel::Model` machinery.
- **`Monetize.parse` does NOT raise on invalid input.** Verified directly (`bin/rails runner`): `Monetize.parse("not a number", "USD")` and `Monetize.parse(nil, "USD")` both return `Money.new(0)`, not an exception. Validate the *result* (`.cents <= 0`), never write a `rescue Monetize::ParseError` — that branch is dead code that will never execute.
- **The sign convention lives in the model, never the controller.** `Transaction#apply_sign_convention` must exempt `transfer?` rows entirely — `TransferForm` sets both legs' signs explicitly.
- Tests are Minitest, not RSpec. `ActiveSupport::TestCase` for models, `ActionDispatch::IntegrationTest` for controllers.
- No fixture files for accounts/categories/transactions — create everything inline via `.create!`/`.build`.
- Stimulus controllers auto-register — `app/javascript/controllers/index.js` already calls `eagerLoadControllersFrom("controllers", application)`, and `config/importmap.rb` already has `pin_all_from "app/javascript/controllers", under: "controllers"`. A new file in that directory needs no additional wiring.
- Run `bin/rubocop` after every task. Run the **full** `bin/rails test` suite before the final commit of the last task.

---

### Task 1: Migration and Transaction model updates

**Files:**
- Create: `db/migrate/<timestamp>_add_transfer_support_to_transactions.rb`
- Modify: `app/models/transaction.rb`
- Test: Modify `test/models/transaction_test.rb`

**Interfaces:**
- Produces: `transactions.category_id` is now nullable; `transactions.transfer_id` (string, indexed) exists. `Transaction.txn_types` now includes `"transfer"`. `Transaction#apply_sign_convention` no longer touches transfer-type rows.
- Later tasks consume: the `transfer_id` column and `transfer?` predicate (from the enum), and the fact that `category` is now `optional: true`.

- [ ] **Step 1: Generate the migration**

  Run: `bin/rails generate migration AddTransferSupportToTransactions`

  Note the actual filename it prints — you'll edit that exact file next.

- [ ] **Step 2: Write the migration**

  Replace the generated file's contents with:

  ```ruby
  class AddTransferSupportToTransactions < ActiveRecord::Migration[8.1]
    def change
      change_column_null :transactions, :category_id, true
      add_column :transactions, :transfer_id, :string
      safety_assured { add_index :transactions, :transfer_id }
    end
  end
  ```

  `strong_migrations` (this app's gem for catching unsafe migrations) flags a plain
  `add_index` on an existing table as unsafe by default — a non-concurrent index build
  locks the table against writes for its duration. Its own suggested fix is
  `algorithm: :concurrently` + `disable_ddl_transaction!`, but that splits this migration's
  atomicity (the column changes above could no longer roll back together with the index if
  something failed partway through) to solve a production-scale concern this app doesn't have
  yet — `transactions` currently holds a handful of rows, not enough for a blocking index build
  to matter in practice. `safety_assured { ... }` is strong_migrations' own escape hatch for
  exactly this judgment call: keep the migration atomic and simple now, reconsider
  `:concurrently` if this table ever grows large enough for it to matter.

- [ ] **Step 3: Run the migration**

  Run: `bin/rails db:migrate`
  Expected: migrates with no errors. Confirm `db/schema.rb` shows `category_id` without `null: false`, and a new `transfer_id` string column with an index on the `transactions` table.

- [ ] **Step 4: Write the failing test for the sign-convention fix**

  In `test/models/transaction_test.rb`, add two tests (keep every existing test unchanged):

  ```ruby
  test "does not apply the sign convention to a transfer with a negative amount" do
    transaction = @user.transactions.create!(account: @account, amount_cents: -5000, occurred_on: Date.current, txn_type: "transfer")
    assert_equal(-5000, transaction.amount_cents)
  end

  test "does not apply the sign convention to a transfer with a positive amount" do
    transaction = @user.transactions.create!(account: @account, amount_cents: 5000, occurred_on: Date.current, txn_type: "transfer")
    assert_equal 5000, transaction.amount_cents
  end
  ```

- [ ] **Step 5: Run the tests to verify they fail**

  Run: `bin/rails test test/models/transaction_test.rb`
  Expected: FAIL — `ArgumentError` on `txn_type: "transfer"` (not yet a valid enum value), or a `NotNullViolation` on `category_id` if the enum error is worked around first. Either way, this confirms the model doesn't support transfers yet.

- [ ] **Step 6: Update the Transaction model**

  Replace `app/models/transaction.rb` with:

  ```ruby
  class Transaction < ApplicationRecord
    belongs_to :user
    belongs_to :account
    belongs_to :category, optional: true

    monetize :amount_cents

    enum :txn_type, {
      income: "income",
      expense: "expense",
      transfer: "transfer"
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
        return if amount_cents.blank? || transfer?
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

  The only changes from the current file: `belongs_to :category, optional: true` (was required), `transfer: "transfer"` added to the enum, and `|| transfer?` added to `apply_sign_convention`'s guard clause. Every validation and the two `belongs_to :account`/`user_id` checks are unchanged — they already work correctly for transfers with no modification (a transfer leg still belongs to a real account and a real user; it just has no category).

- [ ] **Step 7: Run the tests to verify they pass**

  Run: `bin/rails test test/models/transaction_test.rb`
  Expected: all passing — the 2 new tests plus every pre-existing test in the file (in particular, confirm `"raises on a txn_type outside the fixed list"` still passes — it uses `"bitcoin"`, not `"transfer"`, so it's unaffected by the enum addition).

- [ ] **Step 8: Rubocop**

  Run: `bin/rubocop app/models/transaction.rb test/models/transaction_test.rb`
  Expected: `no offenses detected`.

- [ ] **Step 9: Commit**

  ```bash
  git add db/migrate app/models/transaction.rb test/models/transaction_test.rb db/schema.rb
  git commit -m "Add transfer support to the Transaction model"
  ```

---

### Task 2: TransferForm

**Files:**
- Create: `app/models/transfer_form.rb`
- Test: `test/models/transfer_form_test.rb`

**Interfaces:**
- Consumes (from Task 1): `user.transactions.where(transfer_id: ...)`, `user.transactions.create!(account_id:, amount_cents:, txn_type: "transfer", transfer_id:, occurred_on:, description:)`.
- Produces: `TransferForm.new(attributes)`, `TransferForm.find(user, transfer_id)` (raises `ActiveRecord::RecordNotFound` if it doesn't resolve to exactly two of the user's own transactions), `#save(user)` (returns `true`/`false`, populates `#errors` on failure), `#destroy(user)`, `#persisted?`, `#id`, `#from_account_id`, `#to_account_id`, `#amount`, `#occurred_on`, `#description`.
- Later tasks consume: this exact interface from `TransfersController`.

- [ ] **Step 1: Write the failing tests**

  Create `test/models/transfer_form_test.rb`:

  ```ruby
  require "test_helper"

  class TransferFormTest < ActiveSupport::TestCase
    setup do
      @user = users(:one)
      @checking = @user.accounts.create!(name: "Checking", kind: "checking")
      @savings = @user.accounts.create!(name: "Savings", kind: "savings")
    end

    test "invalid when from and to accounts are the same" do
      form = TransferForm.new(from_account_id: @checking.id, to_account_id: @checking.id, amount: "50.00", occurred_on: Date.current)

      assert_not form.valid?
      assert_includes form.errors[:to_account_id], "must be different from the from account"
    end

    test "invalid with a zero amount" do
      form = TransferForm.new(from_account_id: @checking.id, to_account_id: @savings.id, amount: "0", occurred_on: Date.current)

      assert_not form.valid?
      assert_includes form.errors[:amount], "must be greater than zero"
    end

    test "invalid with a non-numeric amount" do
      form = TransferForm.new(from_account_id: @checking.id, to_account_id: @savings.id, amount: "not a number", occurred_on: Date.current)

      assert_not form.valid?
      assert_includes form.errors[:amount], "must be greater than zero"
    end

    test "invalid without required fields" do
      form = TransferForm.new

      assert_not form.valid?
      assert_includes form.errors[:from_account_id], "can't be blank"
      assert_includes form.errors[:to_account_id], "can't be blank"
      assert_includes form.errors[:amount], "can't be blank"
      assert_includes form.errors[:occurred_on], "can't be blank"
    end

    test "save creates two linked transactions with opposite signs" do
      form = TransferForm.new(from_account_id: @checking.id, to_account_id: @savings.id, amount: "50.00", occurred_on: Date.current, description: "Moving money")

      assert_difference -> { Transaction.count }, 2 do
        assert form.save(@user)
      end

      outgoing = @checking.transactions.last
      incoming = @savings.transactions.last

      assert_equal(-5000, outgoing.amount_cents)
      assert_equal 5000, incoming.amount_cents
      assert_equal "transfer", outgoing.txn_type
      assert_equal "transfer", incoming.txn_type
      assert_nil outgoing.category_id
      assert_nil incoming.category_id
      assert_equal outgoing.transfer_id, incoming.transfer_id
      assert form.persisted?
    end

    test "save with an account belonging to another user fails and surfaces an error" do
      other_account = users(:two).accounts.create!(name: "Their Checking", kind: "checking")
      form = TransferForm.new(from_account_id: @checking.id, to_account_id: other_account.id, amount: "50.00", occurred_on: Date.current)

      assert_no_difference -> { Transaction.count } do
        assert_not form.save(@user)
      end

      assert form.errors[:base].any?
    end

    test "find loads both legs of an existing transfer" do
      form = TransferForm.new(from_account_id: @checking.id, to_account_id: @savings.id, amount: "50.00", occurred_on: Date.current, description: "Moving money")
      form.save(@user)

      loaded = TransferForm.find(@user, form.id)

      assert_equal @checking.id, loaded.from_account_id
      assert_equal @savings.id, loaded.to_account_id
      assert_equal "50.00", loaded.amount
      assert_equal "Moving money", loaded.description
    end

    test "find raises for a transfer_id that does not belong to the user" do
      other_user = users(:two)
      other_checking = other_user.accounts.create!(name: "Their Checking", kind: "checking")
      other_savings = other_user.accounts.create!(name: "Their Savings", kind: "savings")
      form = TransferForm.new(from_account_id: other_checking.id, to_account_id: other_savings.id, amount: "50.00", occurred_on: Date.current)
      form.save(other_user)

      assert_raises(ActiveRecord::RecordNotFound) { TransferForm.find(@user, form.id) }
    end

    test "save on an existing transfer replaces both legs" do
      form = TransferForm.new(from_account_id: @checking.id, to_account_id: @savings.id, amount: "50.00", occurred_on: Date.current)
      form.save(@user)
      original_transfer_id = form.id

      loaded = TransferForm.find(@user, original_transfer_id)
      loaded.amount = "75.00"

      assert_no_difference -> { Transaction.count } do
        assert loaded.save(@user)
      end

      assert_equal original_transfer_id, loaded.id
      assert_equal(-7500, @checking.transactions.last.amount_cents)
      assert_equal 7500, @savings.transactions.last.amount_cents
    end

    test "destroy removes both legs" do
      form = TransferForm.new(from_account_id: @checking.id, to_account_id: @savings.id, amount: "50.00", occurred_on: Date.current)
      form.save(@user)

      assert_difference -> { Transaction.count }, -2 do
        form.destroy(@user)
      end
    end
  end
  ```

- [ ] **Step 2: Run the tests to verify they fail**

  Run: `bin/rails test test/models/transfer_form_test.rb`
  Expected: FAIL — `NameError: uninitialized constant TransferFormTest::TransferForm` (the class doesn't exist yet).

- [ ] **Step 3: Write TransferForm**

  Create `app/models/transfer_form.rb`:

  ```ruby
  class TransferForm
    include ActiveModel::Model

    attr_accessor :id, :from_account_id, :to_account_id, :amount, :occurred_on, :description

    validates :from_account_id, presence: true
    validates :to_account_id, presence: true
    validates :amount, presence: true
    validates :occurred_on, presence: true
    validate :accounts_are_different
    validate :amount_is_positive

    def self.find(user, transfer_id)
      legs = user.transactions.where(transfer_id: transfer_id).order(:amount_cents)
      raise ActiveRecord::RecordNotFound, "Couldn't find Transfer" unless legs.size == 2

      outgoing, incoming = legs.first, legs.second
      new(
        id: transfer_id,
        from_account_id: outgoing.account_id,
        to_account_id: incoming.account_id,
        amount: incoming.amount.to_s,
        occurred_on: incoming.occurred_on,
        description: incoming.description
      )
    end

    def persisted?
      id.present?
    end

    def save(user)
      return false unless valid?

      begin
        ActiveRecord::Base.transaction do
          user.transactions.where(transfer_id: id).destroy_all if persisted?

          new_id = id || SecureRandom.uuid
          cents = Monetize.parse(amount, "USD").cents

          user.transactions.create!(account_id: from_account_id, amount_cents: -cents, txn_type: "transfer", transfer_id: new_id, occurred_on: occurred_on, description: description)
          user.transactions.create!(account_id: to_account_id, amount_cents: cents, txn_type: "transfer", transfer_id: new_id, occurred_on: occurred_on, description: description)

          self.id = new_id
        end
      rescue ActiveRecord::RecordInvalid => e
        errors.add(:base, e.record.errors.full_messages.to_sentence)
        return false
      end

      true
    end

    def destroy(user)
      user.transactions.where(transfer_id: id).destroy_all
    end

    private
      def accounts_are_different
        return if from_account_id.blank? || to_account_id.blank?
        errors.add(:to_account_id, "must be different from the from account") if from_account_id == to_account_id
      end

      def amount_is_positive
        return if amount.blank?
        errors.add(:amount, "must be greater than zero") if Monetize.parse(amount, "USD").cents <= 0
      end
  end
  ```

- [ ] **Step 4: Run the tests to verify they pass**

  Run: `bin/rails test test/models/transfer_form_test.rb`
  Expected: `10 runs, ... 0 failures, 0 errors`

- [ ] **Step 5: Rubocop**

  Run: `bin/rubocop app/models/transfer_form.rb test/models/transfer_form_test.rb`
  Expected: `no offenses detected`.

- [ ] **Step 6: Commit**

  ```bash
  git add app/models/transfer_form.rb test/models/transfer_form_test.rb
  git commit -m "Add TransferForm to create/edit/destroy linked transfer transactions"
  ```

---

### Task 3: Transfers routes, controller, and views

**Files:**
- Modify: `config/routes.rb`
- Create: `app/controllers/transfers_controller.rb`
- Create: `app/views/transfers/_form.html.erb`
- Create: `app/views/transfers/new.html.erb`
- Create: `app/views/transfers/edit.html.erb`
- Test: `test/controllers/transfers_controller_test.rb`

**Interfaces:**
- Consumes (from Task 2): `TransferForm.new`, `TransferForm.find(user, id)`, `#save(user)`, `#destroy(user)`.
- Produces: routes `transfers_path` (POST), `new_transfer_path` (GET), `edit_transfer_path(id)` (GET), `transfer_path(id)` (PATCH, DELETE). Later tasks (Task 4) consume `edit_transfer_path` as a redirect target.

- [ ] **Step 1: Add the route**

  In `config/routes.rb`, add `resources :transfers, only: %i[ new create edit update destroy ]` after `resources :transactions, except: :show`:

  ```ruby
  Rails.application.routes.draw do
    mount RailsIcons::Engine, at: "/rails_icons"
    get "home/index"
    resource :session
    resources :passwords, param: :token
    resources :accounts, except: :show
    resources :categories, except: :show
    resources :transactions, except: :show
    resources :transfers, only: %i[ new create edit update destroy ]
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

  Create `test/controllers/transfers_controller_test.rb`:

  ```ruby
  require "test_helper"

  class TransfersControllerTest < ActionDispatch::IntegrationTest
    setup do
      @user = users(:one)
      @other_user = users(:two)
      @checking = @user.accounts.create!(name: "Checking", kind: "checking")
      @savings = @user.accounts.create!(name: "Savings", kind: "savings")
      sign_in_as @user
    end

    test "new renders the form" do
      get new_transfer_path
      assert_response :success
    end

    test "create with valid params creates two linked transactions" do
      assert_difference -> { @user.transactions.count }, 2 do
        post transfers_path, params: { transfer: { from_account_id: @checking.id, to_account_id: @savings.id, amount: "50.00", occurred_on: Date.current } }
      end

      assert_redirected_to transactions_path
      assert_equal(-5000, @checking.transactions.last.amount_cents)
      assert_equal 5000, @savings.transactions.last.amount_cents
    end

    test "create with the same from and to account re-renders the form" do
      assert_no_difference -> { Transaction.count } do
        post transfers_path, params: { transfer: { from_account_id: @checking.id, to_account_id: @checking.id, amount: "50.00", occurred_on: Date.current } }
      end

      assert_response :unprocessable_entity
    end

    test "create with another user's account re-renders the form" do
      other_account = @other_user.accounts.create!(name: "Their Checking", kind: "checking")

      assert_no_difference -> { Transaction.count } do
        post transfers_path, params: { transfer: { from_account_id: @checking.id, to_account_id: other_account.id, amount: "50.00", occurred_on: Date.current } }
      end

      assert_response :unprocessable_entity
    end

    test "edit renders the form for the current user's transfer" do
      form = TransferForm.new(from_account_id: @checking.id, to_account_id: @savings.id, amount: "50.00", occurred_on: Date.current)
      form.save(@user)

      get edit_transfer_path(form.id)
      assert_response :success
    end

    test "edit on another user's transfer is not found" do
      other_checking = @other_user.accounts.create!(name: "Their Checking", kind: "checking")
      other_savings = @other_user.accounts.create!(name: "Their Savings", kind: "savings")
      other_form = TransferForm.new(from_account_id: other_checking.id, to_account_id: other_savings.id, amount: "50.00", occurred_on: Date.current)
      other_form.save(@other_user)

      get edit_transfer_path(other_form.id)

      assert_response :not_found
    end

    test "update replaces both legs" do
      form = TransferForm.new(from_account_id: @checking.id, to_account_id: @savings.id, amount: "50.00", occurred_on: Date.current)
      form.save(@user)

      patch transfer_path(form.id), params: { transfer: { from_account_id: @checking.id, to_account_id: @savings.id, amount: "75.00", occurred_on: Date.current } }

      assert_redirected_to transactions_path
      assert_equal(-7500, @checking.transactions.last.amount_cents)
      assert_equal 7500, @savings.transactions.last.amount_cents
    end

    test "update on another user's transfer is not found" do
      other_checking = @other_user.accounts.create!(name: "Their Checking", kind: "checking")
      other_savings = @other_user.accounts.create!(name: "Their Savings", kind: "savings")
      other_form = TransferForm.new(from_account_id: other_checking.id, to_account_id: other_savings.id, amount: "50.00", occurred_on: Date.current)
      other_form.save(@other_user)

      patch transfer_path(other_form.id), params: { transfer: { from_account_id: other_checking.id, to_account_id: other_savings.id, amount: "999.00", occurred_on: Date.current } }

      assert_response :not_found
    end

    test "destroy removes both legs" do
      form = TransferForm.new(from_account_id: @checking.id, to_account_id: @savings.id, amount: "50.00", occurred_on: Date.current)
      form.save(@user)

      assert_difference -> { Transaction.count }, -2 do
        delete transfer_path(form.id)
      end

      assert_redirected_to transactions_path
    end

    test "destroy on another user's transfer is not found" do
      other_checking = @other_user.accounts.create!(name: "Their Checking", kind: "checking")
      other_savings = @other_user.accounts.create!(name: "Their Savings", kind: "savings")
      other_form = TransferForm.new(from_account_id: other_checking.id, to_account_id: other_savings.id, amount: "50.00", occurred_on: Date.current)
      other_form.save(@other_user)

      assert_no_difference -> { Transaction.count } do
        delete transfer_path(other_form.id)
      end

      assert_response :not_found
    end
  end
  ```

- [ ] **Step 3: Run the tests to verify they fail**

  Run: `bin/rails test test/controllers/transfers_controller_test.rb`
  Expected: FAIL — `uninitialized constant TransfersController` (route exists from Step 1, controller doesn't).

- [ ] **Step 4: Write the controller**

  Create `app/controllers/transfers_controller.rb`:

  ```ruby
  class TransfersController < ApplicationController
    before_action :set_transfer, only: %i[ edit update destroy ]

    def new
      @transfer = TransferForm.new(occurred_on: Date.current)
    end

    def create
      @transfer = TransferForm.new(transfer_params)

      if @transfer.save(Current.user)
        redirect_to transactions_path, notice: "Transfer created."
      else
        render :new, status: :unprocessable_entity
      end
    end

    def edit
    end

    def update
      @transfer.assign_attributes(transfer_params)

      if @transfer.save(Current.user)
        redirect_to transactions_path, notice: "Transfer updated."
      else
        render :edit, status: :unprocessable_entity
      end
    end

    def destroy
      @transfer.destroy(Current.user)
      redirect_to transactions_path, notice: "Transfer deleted.", status: :see_other
    end

    private
      def set_transfer
        @transfer = TransferForm.find(Current.user, params[:id])
      end

      def transfer_params
        params.expect(transfer: [ :from_account_id, :to_account_id, :amount, :occurred_on, :description ])
      end
  end
  ```

- [ ] **Step 5: Write the form partial**

  Create `app/views/transfers/_form.html.erb`:

  ```erb
  <%= form_with model: transfer, url: transfer.persisted? ? transfer_path(transfer.id) : transfers_path, method: transfer.persisted? ? :patch : :post, class: "w-full max-w-md" do |form| %>
    <% if transfer.errors.any? %>
      <div class="alert alert-error mb-5">
        <ul>
          <% transfer.errors.each do |error| %>
            <li><%= error.full_message %></li>
          <% end %>
        </ul>
      </div>
    <% end %>

    <div class="mb-4">
      <%= form.label :from_account_id, "From account", class: "label" %>
      <%= form.select :from_account_id, Current.user.accounts.order(:name).map { |a| [ a.name, a.id ] }, { prompt: "Select an account" }, { required: true, class: "select select-bordered w-full" } %>
    </div>

    <div class="mb-4">
      <%= form.label :to_account_id, "To account", class: "label" %>
      <%= form.select :to_account_id, Current.user.accounts.order(:name).map { |a| [ a.name, a.id ] }, { prompt: "Select an account" }, { required: true, class: "select select-bordered w-full" } %>
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

  The URL/method is passed explicitly (`transfer.persisted? ? transfer_path(...) : transfers_path`) rather than relying on `form_with model:`'s automatic route inference. `TransferForm` does support that inference (`ActiveModel::Model` includes `ActiveModel::Conversion`, confirmed directly), but being explicit here removes any doubt.

- [ ] **Step 6: Write the new and edit views**

  Create `app/views/transfers/new.html.erb`:

  ```erb
  <div class="w-full">
    <h1 class="text-4xl font-bold mb-6">New Transfer</h1>
    <%= render "form", transfer: @transfer %>
  </div>
  ```

  Create `app/views/transfers/edit.html.erb`:

  ```erb
  <div class="w-full">
    <h1 class="text-4xl font-bold mb-6">Edit Transfer</h1>
    <%= render "form", transfer: @transfer %>
  </div>
  ```

- [ ] **Step 7: Run the tests to verify they pass**

  Run: `bin/rails test test/controllers/transfers_controller_test.rb`
  Expected: `10 runs, ... 0 failures, 0 errors`

- [ ] **Step 8: Rubocop**

  Run: `bin/rubocop config/routes.rb app/controllers/transfers_controller.rb test/controllers/transfers_controller_test.rb`
  Expected: `no offenses detected`. Do not run rubocop directly against the `.erb` files.

- [ ] **Step 9: Commit**

  ```bash
  git add config/routes.rb app/controllers/transfers_controller.rb app/views/transfers test/controllers/transfers_controller_test.rb
  git commit -m "Add Transfers CRUD, scoped to the current user"
  ```

---

### Task 4: Wire transfers into the Transactions flow

**Files:**
- Modify: `app/controllers/transactions_controller.rb`
- Modify: `app/views/transactions/_form.html.erb`
- Modify: `app/views/transactions/new.html.erb`
- Create: `app/javascript/controllers/transaction_type_toggle_controller.js`
- Test: Modify `test/controllers/transactions_controller_test.rb`

**Interfaces:**
- Consumes (from Task 3): `TransferForm`, `edit_transfer_path`, `transfers/form` partial.
- Produces: `/transactions/new` shows a Type selector (Income/Expense vs Transfer) toggling between the existing Transaction form and the Transfer form. Editing or deleting an existing transfer-type `Transaction` row correctly redirects/pair-deletes.

- [ ] **Step 1: Confirm the regression baseline**

  Run: `bin/rails test test/controllers/transactions_controller_test.rb`
  Expected: all passing, before you change anything.

- [ ] **Step 2: Write the failing tests**

  In `test/controllers/transactions_controller_test.rb`, add three tests (keep every existing test unchanged):

  ```ruby
  test "new also builds a transfer form for the page's toggle" do
    get new_transaction_path
    assert_response :success
    assert_includes response.body, "From account"
  end

  test "edit on a transfer redirects to the transfer's edit page" do
    checking = @user.accounts.create!(name: "Checking 2", kind: "checking")
    savings = @user.accounts.create!(name: "Savings", kind: "savings")
    form = TransferForm.new(from_account_id: checking.id, to_account_id: savings.id, amount: "50.00", occurred_on: Date.current)
    form.save(@user)
    transfer_leg = checking.transactions.last

    get edit_transaction_path(transfer_leg)

    assert_redirected_to edit_transfer_path(transfer_leg.transfer_id)
  end

  test "destroy on a transfer leg removes both legs" do
    checking = @user.accounts.create!(name: "Checking 2", kind: "checking")
    savings = @user.accounts.create!(name: "Savings", kind: "savings")
    form = TransferForm.new(from_account_id: checking.id, to_account_id: savings.id, amount: "50.00", occurred_on: Date.current)
    form.save(@user)
    transfer_leg = checking.transactions.last

    assert_difference -> { Transaction.count }, -2 do
      delete transaction_path(transfer_leg)
    end

    assert_redirected_to transactions_path
  end
  ```

- [ ] **Step 3: Run the tests to verify they fail**

  Run: `bin/rails test test/controllers/transactions_controller_test.rb`
  Expected: FAIL — the first new test fails because `@transfer` is `nil` in the `new` view (`NoMethodError` or similar rendering error, since `TransactionsController#new` doesn't build it yet); the second fails because `edit` doesn't know about `transfer?` yet (renders the normal edit form instead of redirecting); the third fails because `destroy` doesn't know about `transfer?` yet (destroys only the one leg clicked, so the count only drops by 1, not 2).

- [ ] **Step 4: Restrict the Transaction form's own Type select to income/expense**

  In `app/views/transactions/_form.html.erb`, find this line:

  ```erb
  <%= form.select :txn_type, Transaction.txn_types.keys.map { |k| [ k.titleize, k ] }, { prompt: "Select a type" }, { required: true, class: "select select-bordered w-full" } %>
  ```

  Replace it with:

  ```erb
  <%= form.select :txn_type, %w[income expense].map { |k| [ k.titleize, k ] }, { prompt: "Select a type" }, { required: true, class: "select select-bordered w-full" } %>
  ```

  `Transaction.txn_types.keys` now includes `"transfer"` (from Task 1) — this form must never offer it, since selecting "Transfer" here and submitting would hit `category_kind_matches_txn_type`'s validation in a confusing way (a transfer with a category attached is never valid). Editing an existing income/expense transaction should only ever let you pick income or expense; editing an existing transfer is handled entirely by the redirect added in Step 6 below, never by this form.

- [ ] **Step 5: Write the Stimulus controller**

  Create `app/javascript/controllers/transaction_type_toggle_controller.js`:

  ```js
  import { Controller } from "@hotwired/stimulus"

  export default class extends Controller {
    static targets = ["transactionFields", "transferFields"]

    toggle(event) {
      const isTransfer = event.target.value === "transfer"
      this.transactionFieldsTarget.hidden = isTransfer
      this.transferFieldsTarget.hidden = !isTransfer
    }
  }
  ```

  No changes needed to `app/javascript/controllers/index.js` or `config/importmap.rb` — both already auto-discover every file in `app/javascript/controllers/`.

- [ ] **Step 6: Update TransactionsController**

  Replace `app/controllers/transactions_controller.rb` with:

  ```ruby
  class TransactionsController < ApplicationController
    before_action :set_transaction, only: %i[ edit update destroy ]

    def index
      @transactions = Current.user.transactions.includes(:account, :category).order(occurred_on: :desc, created_at: :desc)
    end

    def new
      @transaction = Current.user.transactions.build(occurred_on: Date.current)
      @transfer = TransferForm.new(occurred_on: Date.current)
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
      redirect_to edit_transfer_path(@transaction.transfer_id) if @transaction.transfer?
    end

    def update
      if @transaction.update(transaction_params)
        redirect_to transactions_path, notice: "Transaction updated."
      else
        render :edit, status: :unprocessable_entity
      end
    end

    def destroy
      if @transaction.transfer?
        TransferForm.find(Current.user, @transaction.transfer_id).destroy(Current.user)
        redirect_to transactions_path, notice: "Transfer deleted.", status: :see_other
      else
        @transaction.destroy
        redirect_to transactions_path, notice: "Transaction deleted.", status: :see_other
      end
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

  Two changes from the current file: `new` also builds `@transfer` (so the initially-hidden transfer fields on the same page have something to bind to), `edit` redirects for a transfer-type row, and `destroy` branches to pair-aware deletion via `TransferForm` for transfer-type rows. `create` and `update` are unchanged — `update` is intentionally left as-is per the spec (unreachable for a transfer since `edit` always redirects first).

- [ ] **Step 7: Update the New Transaction page**

  Replace `app/views/transactions/new.html.erb` with:

  ```erb
  <div class="w-full" data-controller="transaction-type-toggle">
    <h1 class="text-4xl font-bold mb-6">New Transaction</h1>

    <div class="mb-4">
      <%= label_tag :entry_type, "Type", class: "label" %>
      <%= select_tag :entry_type, options_for_select([ [ "Income / Expense", "transaction" ], [ "Transfer", "transfer" ] ]), data: { action: "change->transaction-type-toggle#toggle" }, class: "select select-bordered w-full" %>
    </div>

    <div data-transaction-type-toggle-target="transactionFields">
      <%= render "form", transaction: @transaction %>
    </div>

    <div data-transaction-type-toggle-target="transferFields" hidden>
      <%= render "transfers/form", transfer: @transfer %>
    </div>
  </div>
  ```

  This top-level "Type" selector (`entry_type`, not tied to either underlying model — it's purely a UI toggle, never submitted anywhere) only ever has two options: "Income / Expense" (shows the existing Transaction form, which has its own income/expense selector inside it, from Step 4) and "Transfer" (shows the Transfer form). This avoids a confusing three-way duplicate selector.

- [ ] **Step 8: Run the tests to verify they pass**

  Run: `bin/rails test test/controllers/transactions_controller_test.rb`
  Expected: all passing, including the 3 new tests plus every pre-existing test in the file (in particular, re-check `"edit renders the form for the current user's transaction"` and `"edit pre-fills an expense's amount as positive..."` still pass — they operate on an income/expense transaction, untouched by the transfer redirect logic).

- [ ] **Step 9: Rubocop**

  Run: `bin/rubocop app/controllers/transactions_controller.rb app/javascript/controllers/transaction_type_toggle_controller.js test/controllers/transactions_controller_test.rb`
  Expected: `no offenses detected`. (Rubocop only lints Ruby; the `.js` file won't be flagged by it either way, but there's no harm listing it — do not pass any `.erb` file to this command.)

- [ ] **Step 10: Manual verification**

  Boot the app (or use the real-HTTP-request substitute if no browser tooling is available, as used throughout this project):

  ```bash
  bin/rails tailwindcss:build
  bin/dev
  ```

  Sign in, visit `/transactions/new`. Confirm the page loads with the Income/Expense form visible by default. Switch the top Type selector to "Transfer" — confirm the Transfer form appears and the Transaction form hides (JS toggle actually works, not just present in the DOM). Create a transfer between two accounts — confirm both legs appear as separate rows in `/transactions`, and both accounts' balances on `/accounts` reflect it correctly. Click Edit on either leg — confirm it lands on the Transfer edit page (not a broken/wrong page) with both accounts pre-filled correctly. Change the amount and save — confirm both legs update. Delete one leg from the feed — confirm both disappear and both balances revert. Stop `bin/dev` with Ctrl+C when done.

- [ ] **Step 11: Run the full suite**

  Run: `bin/rails test`
  Expected: all tests pass — every task in this plan, plus every pre-existing test in the app.

- [ ] **Step 12: Commit**

  ```bash
  git add app/controllers/transactions_controller.rb app/views/transactions app/javascript/controllers/transaction_type_toggle_controller.js test/controllers/transactions_controller_test.rb
  git commit -m "Wire Transfers into the Transactions new-entry flow"
  ```

- [ ] **Step 13: Push**

  ```bash
  git push
  ```

  This triggers a Render auto-deploy. Check `render deploys list srv-d9eu93rrjlhs73d4usp0 --output json` (or the Render dashboard) for `live` status, and spot-check `https://moneymap-1rbv.onrender.com/transactions/new` after signing in — including actually toggling to Transfer and confirming the JS works in production (a JS bug wouldn't show up in the Minitest suite at all, since it never executes JavaScript).
