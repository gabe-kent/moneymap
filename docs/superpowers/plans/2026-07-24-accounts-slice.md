# Accounts Slice Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add the first budgeting-domain model — `Account` — with full CRUD (create/list/edit/delete), scoped to the signed-in user, per `docs/superpowers/specs/2026-07-24-accounts-slice-design.md`.

**Architecture:** Standard Rails MVC, matching the existing app's patterns exactly (see Global Constraints). One model (`Account`, `belongs_to :user`), one controller (`AccountsController`) scoped through `Current.user.accounts`, DaisyUI-styled views, flash rendering centralized in the shared layout as part of this work (currently duplicated three times).

**Tech Stack:** Rails 8.1.3, PostgreSQL, money-rails (monetized `starting_balance_cents`, USD-only), DaisyUI (already vendored), Minitest.

## Global Constraints

- Ruby 3.4, Rails 8.1.3 — this is an existing app, not a new one. Follow its conventions exactly, don't introduce new ones.
- **String literals: double-quoted** (Rubocop Omakase style — `bin/rubocop` enforces this; run it before every commit in this plan).
- **Money is integer cents via money-rails, never floats.** `starting_balance_cents` is the real DB column; `starting_balance` is money-rails' generated virtual accessor (a `Money` object) — forms and view display use the virtual accessor, never the raw cents column directly.
- **No `current_user` controller method exists in this app.** The accessor is `Current.user` (see `app/models/current.rb`). Every controller action in this plan scopes through `Current.user.accounts`, not `current_user`.
- **Every controller action scopes to the signed-in user.** There is no cross-user access path. Looking up another user's record must 404 (via `ActiveRecord::RecordNotFound`, which `config/environments/test.rb`'s `show_exceptions = :rescuable` already converts to a real 404 response in tests — no explicit `rescue_from` needed), not silently succeed or 403.
- Tests are Minitest, not RSpec. `ActiveSupport::TestCase` for models, `ActionDispatch::IntegrationTest` for controllers — matches every existing test file in `test/`.
- No fixture file for accounts. Existing tests use `test/fixtures/users.yml` (fixture) for `User` but create everything else inline via `.create!`/`.build` — match that; don't add `test/fixtures/accounts.yml`.
- Run `bin/rubocop` and the relevant test file after every task. Run the **full** `bin/rails test` suite before the final commit of the last task, to catch any regression in existing tests (particularly `test/controllers/passwords_controller_test.rb` and `test/controllers/sessions_controller_test.rb`, which assert on flash content that Task 3 relocates).

---

### Task 1: Account model

**Files:**
- Create: `db/migrate/<timestamp>_create_accounts.rb` (timestamp comes from the generator — see Step 1)
- Create: `app/models/account.rb`
- Modify: `app/models/user.rb`
- Modify: `config/initializers/money.rb`
- Test: `test/models/account_test.rb`

**Interfaces:**
- Produces: `Account` model with `belongs_to :user`, `monetize :starting_balance_cents` (giving `#starting_balance` / `#starting_balance=` as a `Money` object, USD), `enum :kind` over `checking`/`savings`/`cash`/`credit`/`investment`, validates presence of `name`, `kind`, `starting_balance_cents`.
- Produces: `User#accounts` (`has_many`, `dependent: :destroy`).
- Later tasks (Task 2) consume: `Current.user.accounts` (build/find/order/count), `Account.kinds` (enum-generated class method returning `{"checking"=>"checking", ...}` in definition order), `account.starting_balance` / `account.starting_balance=`.

- [ ] **Step 1: Generate the migration**

  Run: `bin/rails generate migration CreateAccounts`

  This creates `db/migrate/<timestamp>_create_accounts.rb` with an empty `change` method. Note the actual filename it prints — you'll edit that exact file next.

- [ ] **Step 2: Write the migration**

  Replace the generated file's contents with:

  ```ruby
  class CreateAccounts < ActiveRecord::Migration[8.1]
    def change
      create_table :accounts do |t|
        t.references :user, null: false, foreign_key: true
        t.string :name, null: false
        t.string :kind, null: false
        t.integer :starting_balance_cents, null: false, default: 0

        t.timestamps
      end
    end
  end
  ```

- [ ] **Step 3: Run the migration**

  Run: `bin/rails db:migrate`
  Expected: `== CreateAccounts: migrating ... == CreateAccounts: migrated` with no errors. Confirm `db/schema.rb` now has a `create_table "accounts"` block with a foreign key to `users`.

- [ ] **Step 4: Write the failing model test**

  Create `test/models/account_test.rb`:

  ```ruby
  require "test_helper"

  class AccountTest < ActiveSupport::TestCase
    setup { @user = users(:one) }

    test "valid with name, kind, and user" do
      account = @user.accounts.build(name: "Checking", kind: "checking")
      assert account.valid?
    end

    test "invalid without a name" do
      account = @user.accounts.build(kind: "checking")
      assert_not account.valid?
      assert_includes account.errors[:name], "can't be blank"
    end

    test "invalid without a kind" do
      account = @user.accounts.build(name: "Checking")
      assert_not account.valid?
      assert_includes account.errors[:kind], "can't be blank"
    end

    test "raises on a kind outside the fixed list" do
      account = @user.accounts.build(name: "Checking")
      assert_raises(ArgumentError) { account.kind = "bitcoin" }
    end

    test "defaults starting_balance_cents to zero" do
      account = @user.accounts.create!(name: "Checking", kind: "checking")
      assert_equal 0, account.starting_balance_cents
    end

    test "invalid with an explicit nil starting_balance_cents" do
      account = @user.accounts.build(name: "Checking", kind: "checking", starting_balance_cents: nil)
      assert_not account.valid?
      assert_includes account.errors[:starting_balance_cents], "can't be blank"
    end

    test "starting_balance is monetized in USD" do
      account = @user.accounts.create!(name: "Checking", kind: "checking", starting_balance_cents: 15_000)
      assert_equal Money.new(15_000, "USD"), account.starting_balance
    end

    test "requires a user" do
      account = Account.new(name: "Checking", kind: "checking")
      assert_not account.valid?
      assert_includes account.errors[:user], "must exist"
    end

    test "destroying a user destroys their accounts" do
      account = @user.accounts.create!(name: "Checking", kind: "checking")
      assert_difference -> { Account.count }, -1 do
        @user.destroy
      end
      assert_not Account.exists?(account.id)
    end
  end
  ```

- [ ] **Step 5: Run the test to verify it fails**

  Run: `bin/rails test test/models/account_test.rb`
  Expected: FAIL — `NameError: uninitialized constant AccountTest::Account` (or similar; the model doesn't exist yet).

- [ ] **Step 6: Set the default money-rails currency to USD**

  `Money.default_currency` is `nil` in this app as of money-rails 3.0.0 / money 7.0.2 — this
  gem version pairing does **not** auto-default to USD the way older versions did (confirmed by
  running `bin/rails runner 'puts Money.default_currency.inspect'` — prints `nil`). Without
  this step, `monetize :starting_balance_cents` raises `Money::Currency::NoCurrency: must
  provide a currency` on every `Account.new`/`.build`. This activates the design's already-
  approved USD-only intent (see the spec's "Data model" section); it doesn't change it.

  In `config/initializers/money.rb`, find the commented-out line:

  ```ruby
  # config.default_currency = :usd
  ```

  Uncomment it (remove the leading `# `):

  ```ruby
  config.default_currency = :usd
  ```

- [ ] **Step 7: Write the Account model**

  Create `app/models/account.rb`:

  ```ruby
  class Account < ApplicationRecord
    belongs_to :user

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

- [ ] **Step 8: Add the association to User**

  In `app/models/user.rb`, add `has_many :accounts, dependent: :destroy` alongside the existing `has_many :sessions, dependent: :destroy`:

  ```ruby
  class User < ApplicationRecord
    has_secure_password
    has_many :sessions, dependent: :destroy
    has_many :accounts, dependent: :destroy

    normalizes :email_address, with: ->(e) { e.strip.downcase }
  end
  ```

- [ ] **Step 9: Run the test to verify it passes**

  Run: `bin/rails test test/models/account_test.rb`
  Expected: `9 runs, ... 0 failures, 0 errors`

- [ ] **Step 10: Rubocop**

  Run: `bin/rubocop app/models/account.rb app/models/user.rb config/initializers/money.rb test/models/account_test.rb`
  Expected: `no offenses detected`. Fix anything it flags before continuing.

- [ ] **Step 11: Commit**

  ```bash
  git add db/migrate app/models/account.rb app/models/user.rb config/initializers/money.rb test/models/account_test.rb db/schema.rb
  git commit -m "Add Account model, scoped to user"
  ```

---

### Task 2: Accounts routes, controller, and views

**Files:**
- Modify: `config/routes.rb`
- Create: `app/controllers/accounts_controller.rb`
- Create: `app/views/accounts/index.html.erb`
- Create: `app/views/accounts/_form.html.erb`
- Create: `app/views/accounts/new.html.erb`
- Create: `app/views/accounts/edit.html.erb`
- Test: `test/controllers/accounts_controller_test.rb`

**Interfaces:**
- Consumes (from Task 1): `Current.user.accounts` (`.build`, `.find`, `.order`, `.count`), `Account.kinds`, `account.starting_balance`.
- Produces: routes `accounts_path` (GET/POST), `new_account_path` (GET), `edit_account_path(account)` (GET), `account_path(account)` (PATCH/PUT, DELETE).
- Produces (for Task 3 to consume): the routes above are what Task 3's navbar link points to. Task 3 also relies on `AccountsController`'s `create`/`update`/`destroy` setting `flash[:notice]`, which Task 3's centralized layout partial renders — but this task's own tests assert on redirects and database state only, not flash content, so it doesn't depend on Task 3 having happened first.

- [ ] **Step 1: Add the route**

  In `config/routes.rb`, add `resources :accounts` after the existing `resources :passwords, param: :token` line:

  ```ruby
  Rails.application.routes.draw do
    mount RailsIcons::Engine, at: "/rails_icons"
    get "home/index"
    resource :session
    resources :passwords, param: :token
    resources :accounts
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

  Create `test/controllers/accounts_controller_test.rb`:

  ```ruby
  require "test_helper"

  class AccountsControllerTest < ActionDispatch::IntegrationTest
    setup do
      @user = users(:one)
      @other_user = users(:two)
      @account = @user.accounts.create!(name: "Checking", kind: "checking", starting_balance_cents: 10_000)
      sign_in_as @user
    end

    test "index lists only the current user's accounts" do
      other_account = @other_user.accounts.create!(name: "Their Savings", kind: "savings")

      get accounts_path

      assert_response :success
      assert_includes response.body, @account.name
      assert_not_includes response.body, other_account.name
    end

    test "new renders the form" do
      get new_account_path
      assert_response :success
    end

    test "create with valid params" do
      assert_difference -> { @user.accounts.count }, 1 do
        post accounts_path, params: { account: { name: "Savings", kind: "savings", starting_balance: "5.00" } }
      end

      assert_redirected_to accounts_path
      assert_equal 500, @user.accounts.order(:created_at).last.starting_balance_cents
    end

    test "create with invalid params re-renders the form" do
      assert_no_difference -> { Account.count } do
        post accounts_path, params: { account: { name: "", kind: "savings" } }
      end

      assert_response :unprocessable_entity
    end

    test "edit renders the form for the current user's account" do
      get edit_account_path(@account)
      assert_response :success
    end

    test "edit on another user's account is not found" do
      other_account = @other_user.accounts.create!(name: "Their Checking", kind: "checking")

      get edit_account_path(other_account)

      assert_response :not_found
    end

    test "update with valid params" do
      patch account_path(@account), params: { account: { name: "Updated Name" } }

      assert_redirected_to accounts_path
      assert_equal "Updated Name", @account.reload.name
    end

    test "update on another user's account is not found" do
      other_account = @other_user.accounts.create!(name: "Their Checking", kind: "checking")

      patch account_path(other_account), params: { account: { name: "Hijacked" } }

      assert_response :not_found
      assert_not_equal "Hijacked", other_account.reload.name
    end

    test "destroy removes the account" do
      assert_difference -> { Account.count }, -1 do
        delete account_path(@account)
      end

      assert_redirected_to accounts_path
    end

    test "destroy on another user's account is not found" do
      other_account = @other_user.accounts.create!(name: "Their Checking", kind: "checking")

      assert_no_difference -> { Account.count } do
        delete account_path(other_account)
      end

      assert_response :not_found
    end
  end
  ```

- [ ] **Step 3: Run the tests to verify they fail**

  Run: `bin/rails test test/controllers/accounts_controller_test.rb`
  Expected: FAIL — routing error (`uninitialized constant AccountsController` or `No route matches`), since neither the controller nor routes exist as real endpoints yet... actually the route was added in Step 1, so the failure here should be `AbstractController::ActionNotFound` / `uninitialized constant AccountsController`. Confirm it fails for that reason, not something else.

- [ ] **Step 4: Write the controller**

  Create `app/controllers/accounts_controller.rb`:

  ```ruby
  class AccountsController < ApplicationController
    before_action :set_account, only: %i[ edit update destroy ]

    def index
      @accounts = Current.user.accounts.order(:name)
    end

    def new
      @account = Current.user.accounts.build
    end

    def create
      @account = Current.user.accounts.build(account_params)

      if @account.save
        redirect_to accounts_path, notice: "Account created."
      else
        render :new, status: :unprocessable_entity
      end
    end

    def edit
    end

    def update
      if @account.update(account_params)
        redirect_to accounts_path, notice: "Account updated."
      else
        render :edit, status: :unprocessable_entity
      end
    end

    def destroy
      @account.destroy
      redirect_to accounts_path, notice: "Account deleted.", status: :see_other
    end

    private
      def set_account
        @account = Current.user.accounts.find(params[:id])
      end

      def account_params
        params.expect(account: [ :name, :kind, :starting_balance ])
      end
  end
  ```

  Note `account_params` permits `:starting_balance` (the money-rails virtual dollar-denominated accessor from Task 1), **not** `:starting_balance_cents`. The form in Step 6 posts `account[starting_balance]`; money-rails' generated `starting_balance=` setter converts that to the real `starting_balance_cents` column internally.

- [ ] **Step 5: Write the shared form partial**

  Create `app/views/accounts/_form.html.erb`:

  ```erb
  <%= form_with model: account, class: "w-full max-w-md" do |form| %>
    <% if account.errors.any? %>
      <div class="alert alert-error mb-5">
        <ul>
          <% account.errors.each do |error| %>
            <li><%= error.full_message %></li>
          <% end %>
        </ul>
      </div>
    <% end %>

    <div class="mb-4">
      <%= form.label :name, class: "label" %>
      <%= form.text_field :name, required: true, autofocus: true, class: "input input-bordered w-full" %>
    </div>

    <div class="mb-4">
      <%= form.label :kind, class: "label" %>
      <%= form.select :kind, Account.kinds.keys.map { |k| [ k.titleize, k ] }, { prompt: "Select a kind" }, { required: true, class: "select select-bordered w-full" } %>
    </div>

    <div class="mb-6">
      <%= form.label :starting_balance, "Starting balance", class: "label" %>
      <%= form.number_field :starting_balance, step: "0.01", class: "input input-bordered w-full" %>
    </div>

    <%= form.submit class: "btn btn-primary" %>
  <% end %>
  ```

- [ ] **Step 6: Write the index, new, and edit views**

  Create `app/views/accounts/index.html.erb`:

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
            <th>Starting balance</th>
            <th></th>
          </tr>
        </thead>
        <tbody>
          <% @accounts.each do |account| %>
            <tr>
              <td><%= account.name %></td>
              <td><%= account.kind.titleize %></td>
              <td><%= humanized_money_with_symbol account.starting_balance %></td>
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

  Create `app/views/accounts/new.html.erb`:

  ```erb
  <div class="w-full">
    <h1 class="text-4xl font-bold mb-6">New Account</h1>
    <%= render "form", account: @account %>
  </div>
  ```

  Create `app/views/accounts/edit.html.erb`:

  ```erb
  <div class="w-full">
    <h1 class="text-4xl font-bold mb-6">Edit Account</h1>
    <%= render "form", account: @account %>
  </div>
  ```

- [ ] **Step 7: Run the tests to verify they pass**

  Run: `bin/rails test test/controllers/accounts_controller_test.rb`
  Expected: `9 runs, ... 0 failures, 0 errors`

- [ ] **Step 8: Rubocop**

  Run: `bin/rubocop config/routes.rb app/controllers/accounts_controller.rb test/controllers/accounts_controller_test.rb`
  Expected: `no offenses detected`.

- [ ] **Step 9: Manual browser check**

  Per CLAUDE.md, this app doesn't run system tests as part of `bin/ci` — verify by hand instead:

  ```bash
  bin/rails tailwindcss:build
  bin/dev
  ```

  In a browser: sign in, visit `/accounts`, create an account, edit it, delete it. Confirm the DaisyUI table/form/buttons render correctly (not unstyled HTML) and the delete confirmation dialog appears. Stop `bin/dev` with Ctrl+C when done.

- [ ] **Step 10: Commit**

  ```bash
  git add config/routes.rb app/controllers/accounts_controller.rb app/views/accounts test/controllers/accounts_controller_test.rb
  git commit -m "Add Accounts CRUD, scoped to the current user"
  ```

---

### Task 3: Centralize flash rendering and link Accounts from the navbar

**Files:**
- Modify: `app/views/layouts/application.html.erb`
- Modify: `app/views/sessions/new.html.erb`
- Modify: `app/views/passwords/new.html.erb`
- Modify: `app/views/passwords/edit.html.erb`

**Interfaces:**
- Consumes (from Task 2): `accounts_path` (for the navbar link).
- Consumes: `authenticated?` (helper method from the `Authentication` concern, already used in `app/views/home/index.html.erb`).
- No new interfaces produced — this task is a refactor + one small addition (nav link), not new functionality.

This task's correctness is verified primarily by **existing tests continuing to pass**:
`test/controllers/passwords_controller_test.rb` and any other test asserting flash content must
still pass after the relocation, without modifying those test files.

- [ ] **Step 1: Confirm the regression baseline**

  Run: `bin/rails test test/controllers/passwords_controller_test.rb test/controllers/sessions_controller_test.rb`
  Expected: all passing, before you change anything. This is what must still be true after Step 2.

- [ ] **Step 2: Move flash rendering into the layout, add the Accounts nav link**

  Replace the `<body>` block in `app/views/layouts/application.html.erb`:

  ```erb
  <body>
    <div class="navbar bg-base-100 shadow-sm px-5">
      <div class="flex-1">
        <%= link_to root_path, class: "btn btn-ghost text-xl gap-2" do %>
          <%= icon "landmark", class: "size-5" %>
          Moneymap
        <% end %>
      </div>
      <% if authenticated? %>
        <div class="flex-none">
          <%= link_to "Accounts", accounts_path, class: "btn btn-ghost" %>
        </div>
      <% end %>
    </div>

    <main class="container mx-auto mt-12 px-5 flex flex-col gap-5">
      <% if alert = flash[:alert] %>
        <div class="alert alert-error" id="alert"><%= alert %></div>
      <% end %>

      <% if notice = flash[:notice] %>
        <div class="alert alert-success" id="notice"><%= notice %></div>
      <% end %>

      <%= yield %>
    </main>
  </body>
  ```

- [ ] **Step 3: Remove the duplicated flash blocks**

  In `app/views/sessions/new.html.erb`, delete the `alert` and `notice` blocks at the top so the file starts with:

  ```erb
  <div class="mx-auto md:w-2/3 w-full">
    <h1 class="font-bold text-4xl">Sign in</h1>

    <%= form_with url: session_url, class: "contents" do |form| %>
  ```

  (Keep everything from `<%= form_with %>` onward unchanged.)

  In `app/views/passwords/new.html.erb`, delete the `alert` block at the top so the file starts with:

  ```erb
  <div class="mx-auto md:w-2/3 w-full">
    <h1 class="font-bold text-4xl">Forgot your password?</h1>

    <%= form_with url: passwords_path, class: "contents" do |form| %>
  ```

  In `app/views/passwords/edit.html.erb`, delete the `alert` block at the top so the file starts with:

  ```erb
  <div class="mx-auto md:w-2/3 w-full">
    <h1 class="font-bold text-4xl">Update your password</h1>

    <%= form_with url: password_path(params[:token]), method: :put, class: "contents" do |form| %>
  ```

- [ ] **Step 4: Run the regression tests again**

  Run: `bin/rails test test/controllers/passwords_controller_test.rb test/controllers/sessions_controller_test.rb`
  Expected: same result as Step 1 — all passing, unmodified. If `assert_select "div", /.../` assertions in `passwords_controller_test.rb` fail, the new flash `<div>` isn't rendering with the expected text; check `flash[:notice]`/`flash[:alert]` keys match what the controllers set (they do — `PasswordsController` and `SessionsController` already use `notice:`/`alert:` redirect options, unchanged by this task).

- [ ] **Step 5: Run the full suite**

  Run: `bin/rails test`
  Expected: all tests pass — this is the first point in the plan where every test file has run together (Task 1's and Task 2's new tests, plus every pre-existing test).

- [ ] **Step 6: Rubocop**

  Run: `bin/rubocop`
  Expected: `no offenses detected` across the whole app.

- [ ] **Step 7: Manual browser check**

  ```bash
  bin/rails tailwindcss:build
  bin/dev
  ```

  In a browser: sign out, visit `/session/new`, submit an invalid login — confirm the red alert renders at the top of `<main>`, above the form, styled as a DaisyUI alert (not the old raw red box). Sign in — confirm the "Accounts" link appears in the navbar and the home page's "Signed in as ..." link disappears from the navbar area (it wasn't there before; just confirm the navbar looks right). Visit `/accounts`, create an account — confirm the green "Account created." alert renders the same way. Stop `bin/dev` with Ctrl+C when done.

- [ ] **Step 8: Commit**

  ```bash
  git add app/views/layouts/application.html.erb app/views/sessions/new.html.erb app/views/passwords/new.html.erb app/views/passwords/edit.html.erb
  git commit -m "Centralize flash rendering in the layout, link Accounts from the navbar"
  ```

- [ ] **Step 9: Push**

  ```bash
  git push
  ```

  This triggers a Render auto-deploy. Check `render deploys list srv-d9eu93rrjlhs73d4usp0 --output json` (or the Render dashboard) for `live` status, and spot-check `https://moneymap-1rbv.onrender.com/accounts` after signing in with your seeded production login.
