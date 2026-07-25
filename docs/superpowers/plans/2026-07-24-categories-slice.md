# Categories Slice Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add `Category` — the second budgeting-domain model — with full CRUD scoped to the signed-in user, plus an automatic 8-category starter set for newly created users, per `docs/superpowers/specs/2026-07-24-categories-slice-design.md`.

**Architecture:** Same shape as the Accounts slice (already shipped): one model, one controller scoped through `Current.user.categories`, DaisyUI views. New this time: a `color` enum requiring careful literal-string Tailwind class handling, and this app's first service object (`app/services/`), wired to `User` via an `after_create` callback.

**Tech Stack:** Rails 8.1.3, PostgreSQL, DaisyUI (already vendored), Minitest.

## Global Constraints

- Ruby 3.4, Rails 8.1.3 — existing app, follow its conventions exactly.
- **String literals: double-quoted** (Rubocop Omakase — `bin/rubocop` enforces this; run it before every commit).
- **No `current_user` controller method exists.** The accessor is `Current.user`. Every controller action scopes through `Current.user.categories`, not `current_user`.
- **Every controller action scopes to the signed-in user.** Cross-user lookups 404 via `ActiveRecord::RecordNotFound` (already converted to a real 404 in tests by `config/environments/test.rb`'s `show_exceptions = :rescuable` — no `rescue_from` needed).
- **`resources :categories, except: :show`** — not bare `resources :categories`. The Accounts slice's final review found that a bare `resources` generates an unbuilt `show` route that 500s instead of 404ing; apply that lesson from the start this time.
- **Tailwind only sees literal class strings.** Never build a class name via string interpolation (`"bg-#{color}-500"`) — Tailwind's compiler cannot see through interpolation and will silently omit the class from the compiled CSS even though the ERB source looks correct. The color-to-class mapping MUST be a `case`/`when` with one fully-literal string per branch (see Task 3).
- **Business logic belongs in `app/services/`, one public `#call` method per service** (CLAUDE.md convention) — this is the first service in this app; there is no existing example to follow, Task 2 establishes the pattern.
- Tests are Minitest, not RSpec. `ActiveSupport::TestCase` for models/services, `ActionDispatch::IntegrationTest` for controllers.
- **No fixture file for categories.** `test/fixtures/users.yml` is loaded via direct SQL, which bypasses ActiveRecord callbacks entirely — fixture users (`users(:one)`, `users(:two)`) will NOT have the after-create default categories, and that's fine/expected; it means tests can create categories on fixture users without colliding with auto-seeded ones. Create everything inline via `.create!`/`.build`, matching the Accounts slice.
- Run `bin/rubocop` after every task. Run the **full** `bin/rails test` suite before the final commit of the last task.

---

### Task 1: Category model

**Files:**
- Create: `db/migrate/<timestamp>_create_categories.rb`
- Create: `app/models/category.rb`
- Modify: `app/models/user.rb`
- Test: `test/models/category_test.rb`

**Interfaces:**
- Produces: `Category` model with `belongs_to :user`, `enum :kind` (`income`/`expense`), `enum :color` (`red`/`orange`/`yellow`/`green`/`teal`/`blue`/`purple`/`pink`), validates presence of `name`/`kind`/`color`, validates `name` uniqueness scoped to `user_id` (case-insensitive).
- Produces: `User#categories` (`has_many`, `dependent: :destroy`).
- Later tasks consume: `Current.user.categories` (build/find/order/count/create!), `Category.kinds`, `Category.colors` (enum-generated class methods, each returning a hash in definition order).

- [ ] **Step 1: Generate the migration**

  Run: `bin/rails generate migration CreateCategories`

  Note the actual filename it prints — you'll edit that exact file next.

- [ ] **Step 2: Write the migration**

  Replace the generated file's contents with:

  ```ruby
  class CreateCategories < ActiveRecord::Migration[8.1]
    def change
      create_table :categories do |t|
        t.references :user, null: false, foreign_key: true
        t.string :name, null: false
        t.string :kind, null: false
        t.string :color, null: false

        t.timestamps
      end

      add_index :categories, "user_id, lower(name)", unique: true, name: "index_categories_on_user_id_and_lower_name"
    end
  end
  ```

  The `add_index` call is a Postgres expression index — it enforces case-insensitive uniqueness of `name` per user at the database layer (not just in a Rails validation, which alone can't prevent a race condition creating two case-variant duplicates).

- [ ] **Step 3: Run the migration**

  Run: `bin/rails db:migrate`
  Expected: `== CreateCategories: migrating ... == CreateCategories: migrated` with no errors. Confirm `db/schema.rb` has a `create_table "categories"` block and the `index_categories_on_user_id_and_lower_name` index (schema.rb renders expression indexes as a raw `execute` block below the table definitions, or inline depending on Rails version — either is fine, just confirm the index name appears somewhere in schema.rb).

- [ ] **Step 4: Write the failing model test**

  Create `test/models/category_test.rb`:

  ```ruby
  require "test_helper"

  class CategoryTest < ActiveSupport::TestCase
    setup { @user = users(:one) }

    test "valid with name, kind, color, and user" do
      category = @user.categories.build(name: "Groceries", kind: "expense", color: "orange")
      assert category.valid?
    end

    test "invalid without a name" do
      category = @user.categories.build(kind: "expense", color: "orange")
      assert_not category.valid?
      assert_includes category.errors[:name], "can't be blank"
    end

    test "invalid without a kind" do
      category = @user.categories.build(name: "Groceries", color: "orange")
      assert_not category.valid?
      assert_includes category.errors[:kind], "can't be blank"
    end

    test "invalid without a color" do
      category = @user.categories.build(name: "Groceries", kind: "expense")
      assert_not category.valid?
      assert_includes category.errors[:color], "can't be blank"
    end

    test "raises on a kind outside the fixed list" do
      category = @user.categories.build(name: "Groceries", color: "orange")
      assert_raises(ArgumentError) { category.kind = "bogus" }
    end

    test "raises on a color outside the fixed list" do
      category = @user.categories.build(name: "Groceries", kind: "expense")
      assert_raises(ArgumentError) { category.color = "chartreuse" }
    end

    test "invalid with a duplicate name for the same user" do
      @user.categories.create!(name: "Groceries", kind: "expense", color: "orange")
      duplicate = @user.categories.build(name: "Groceries", kind: "expense", color: "blue")

      assert_not duplicate.valid?
      assert_includes duplicate.errors[:name], "has already been taken"
    end

    test "invalid with a case-insensitive duplicate name for the same user" do
      @user.categories.create!(name: "Groceries", kind: "expense", color: "orange")
      duplicate = @user.categories.build(name: "GROCERIES", kind: "expense", color: "blue")

      assert_not duplicate.valid?
      assert_includes duplicate.errors[:name], "has already been taken"
    end

    test "allows the same name for different users" do
      @user.categories.create!(name: "Groceries", kind: "expense", color: "orange")
      other_user = users(:two)

      category = other_user.categories.build(name: "Groceries", kind: "expense", color: "blue")

      assert category.valid?
    end

    test "requires a user" do
      category = Category.new(name: "Groceries", kind: "expense", color: "orange")
      assert_not category.valid?
      assert_includes category.errors[:user], "must exist"
    end

    test "destroying a user destroys their categories" do
      category = @user.categories.create!(name: "Groceries", kind: "expense", color: "orange")
      assert_difference -> { Category.count }, -1 do
        @user.destroy
      end
      assert_not Category.exists?(category.id)
    end
  end
  ```

- [ ] **Step 5: Run the test to verify it fails**

  Run: `bin/rails test test/models/category_test.rb`
  Expected: FAIL — `NameError: uninitialized constant CategoryTest::Category` (the model doesn't exist yet).

- [ ] **Step 6: Write the Category model**

  Create `app/models/category.rb`:

  ```ruby
  class Category < ApplicationRecord
    belongs_to :user

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

- [ ] **Step 7: Add the association to User**

  In `app/models/user.rb`, add `has_many :categories, dependent: :destroy` alongside the existing associations:

  ```ruby
  class User < ApplicationRecord
    has_secure_password
    has_many :sessions, dependent: :destroy
    has_many :accounts, dependent: :destroy
    has_many :categories, dependent: :destroy

    normalizes :email_address, with: ->(e) { e.strip.downcase }
  end
  ```

- [ ] **Step 8: Run the test to verify it passes**

  Run: `bin/rails test test/models/category_test.rb`
  Expected: `11 runs, ... 0 failures, 0 errors`

- [ ] **Step 9: Rubocop**

  Run: `bin/rubocop app/models/category.rb app/models/user.rb test/models/category_test.rb`
  Expected: `no offenses detected`.

- [ ] **Step 10: Commit**

  ```bash
  git add db/migrate app/models/category.rb app/models/user.rb test/models/category_test.rb db/schema.rb
  git commit -m "Add Category model, scoped to user"
  ```

---

### Task 2: Default category seeding

**Files:**
- Create: `app/services/seed_default_categories.rb`
- Modify: `app/models/user.rb`
- Test: `test/services/seed_default_categories_test.rb`
- Test: Modify `test/models/user_test.rb`

**Interfaces:**
- Consumes (from Task 1): `user.categories.create!`.
- Produces: `SeedDefaultCategories.new(user).call` — creates 8 categories on the given user. No return value is relied upon by callers; it's called for its side effect.
- Produces: `User` now creates its default categories automatically on `User.create!`/`User.new(...).save`. This does NOT apply to fixture-loaded users (see Global Constraints) or to already-existing users in any environment — it only fires going forward, for genuinely new records.

- [ ] **Step 1: Write the failing service test**

  Create `test/services/seed_default_categories_test.rb`:

  ```ruby
  require "test_helper"

  class SeedDefaultCategoriesTest < ActiveSupport::TestCase
    test "creates the 8 default categories for the user" do
      user = users(:one)

      assert_difference -> { user.categories.count }, 8 do
        SeedDefaultCategories.new(user).call
      end
    end

    test "creates categories with the correct name, kind, and color" do
      user = users(:one)
      SeedDefaultCategories.new(user).call

      expected = {
        "Salary" => %w[income green],
        "Other Income" => %w[income teal],
        "Groceries" => %w[expense orange],
        "Rent" => %w[expense red],
        "Utilities" => %w[expense blue],
        "Transportation" => %w[expense purple],
        "Entertainment" => %w[expense pink],
        "Dining Out" => %w[expense yellow]
      }

      expected.each do |name, (kind, color)|
        category = user.categories.find_by(name: name)
        assert category, "expected a category named #{name.inspect}"
        assert_equal kind, category.kind
        assert_equal color, category.color
      end
    end
  end
  ```

- [ ] **Step 2: Run the test to verify it fails**

  Run: `bin/rails test test/services/seed_default_categories_test.rb`
  Expected: FAIL — `NameError: uninitialized constant SeedDefaultCategoriesTest::SeedDefaultCategories` (the service doesn't exist yet; the `test/services/` directory doesn't exist yet either — Rails' test loader picks up any `*_test.rb` under `test/`, so no extra configuration is needed to make this discoverable, it just needs the directory and file created).

- [ ] **Step 3: Write the service**

  Create `app/services/seed_default_categories.rb`:

  ```ruby
  class SeedDefaultCategories
    DEFAULTS = [
      { name: "Salary", kind: "income", color: "green" },
      { name: "Other Income", kind: "income", color: "teal" },
      { name: "Groceries", kind: "expense", color: "orange" },
      { name: "Rent", kind: "expense", color: "red" },
      { name: "Utilities", kind: "expense", color: "blue" },
      { name: "Transportation", kind: "expense", color: "purple" },
      { name: "Entertainment", kind: "expense", color: "pink" },
      { name: "Dining Out", kind: "expense", color: "yellow" }
    ].freeze

    def initialize(user)
      @user = user
    end

    def call
      DEFAULTS.each do |attributes|
        @user.categories.create!(attributes)
      end
    end
  end
  ```

- [ ] **Step 4: Run the test to verify it passes**

  Run: `bin/rails test test/services/seed_default_categories_test.rb`
  Expected: `2 runs, ... 0 failures, 0 errors`

- [ ] **Step 5: Write the failing User integration test**

  In `test/models/user_test.rb`, add a new test alongside the existing one:

  ```ruby
  require "test_helper"

  class UserTest < ActiveSupport::TestCase
    test "downcases and strips email_address" do
      user = User.new(email_address: " DOWNCASED@EXAMPLE.COM ")
      assert_equal("downcased@example.com", user.email_address)
    end

    test "seeds default categories after creation" do
      user = User.create!(email_address: "new-user@example.com", password: "password")
      assert_equal 8, user.categories.count
    end
  end
  ```

- [ ] **Step 6: Run the test to verify it fails**

  Run: `bin/rails test test/models/user_test.rb`
  Expected: FAIL on the new test — `expected: 8, actual: 0` (the callback isn't wired up yet; the service already exists from Step 3 but nothing calls it).

- [ ] **Step 7: Wire the callback into User**

  In `app/models/user.rb`, add the callback and a private method:

  ```ruby
  class User < ApplicationRecord
    has_secure_password
    has_many :sessions, dependent: :destroy
    has_many :accounts, dependent: :destroy
    has_many :categories, dependent: :destroy

    normalizes :email_address, with: ->(e) { e.strip.downcase }

    after_create :seed_default_categories

    private
      def seed_default_categories
        SeedDefaultCategories.new(self).call
      end
  end
  ```

  Use `after_create`, **not** `after_create_commit`. `SeedDefaultCategories` only writes to this app's own database (no external system, no job enqueue) — running it inside the same transaction as the user's creation means a failure while seeding categories rolls back the user too, so you never end up with a persisted user stuck with zero categories. `after_create_commit` exists for side effects that must happen only once the transaction is durable (emails, external API calls, enqueuing jobs); using it here would needlessly give up that atomicity for no benefit.

- [ ] **Step 8: Run the tests to verify they pass**

  Run: `bin/rails test test/models/user_test.rb test/services/seed_default_categories_test.rb`
  Expected: `4 runs, ... 0 failures, 0 errors`

- [ ] **Step 9: Run the full suite**

  Run: `bin/rails test`
  Expected: all tests pass, including Task 1's `category_test.rb` and every pre-existing test (in particular, confirm no controller test that creates a `User` via `.create!` broke — check by reading the full output, not just the summary line, if anything unexpected shows up).

- [ ] **Step 10: Rubocop**

  Run: `bin/rubocop app/services/seed_default_categories.rb app/models/user.rb test/services/seed_default_categories_test.rb test/models/user_test.rb`
  Expected: `no offenses detected`.

- [ ] **Step 11: Commit**

  ```bash
  git add app/services test/services app/models/user.rb test/models/user_test.rb
  git commit -m "Seed 8 default categories when a user is created"
  ```

---

### Task 3: Categories routes, controller, and views

**Files:**
- Modify: `config/routes.rb`
- Create: `app/controllers/categories_controller.rb`
- Create: `app/helpers/categories_helper.rb`
- Create: `app/views/categories/index.html.erb`
- Create: `app/views/categories/_form.html.erb`
- Create: `app/views/categories/new.html.erb`
- Create: `app/views/categories/edit.html.erb`
- Test: `test/controllers/categories_controller_test.rb`

**Interfaces:**
- Consumes (from Task 1): `Current.user.categories` (`.build`, `.find`, `.order`, `.count`), `Category.kinds`, `Category.colors`.
- Produces: routes `categories_path` (GET/POST), `new_category_path` (GET), `edit_category_path(category)` (GET), `category_path(category)` (PATCH/PUT, DELETE).
- Produces: `category_color_classes(color)` view helper — a `case`/`when` mapping each of the 8 enum color values to a literal Tailwind background class. This must be called with a literal argument path traceable back to `Category.colors.keys` (i.e. only ever invoked with one of the 8 known strings) — it has no `else` branch, so an unrecognized color returns `nil`, which is fine since the enum itself prevents any other value from ever being stored.

- [ ] **Step 1: Add the route**

  In `config/routes.rb`, add `resources :categories, except: :show` after the existing `resources :accounts, except: :show` line:

  ```ruby
  Rails.application.routes.draw do
    mount RailsIcons::Engine, at: "/rails_icons"
    get "home/index"
    resource :session
    resources :passwords, param: :token
    resources :accounts, except: :show
    resources :categories, except: :show
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

  Create `test/controllers/categories_controller_test.rb`:

  ```ruby
  require "test_helper"

  class CategoriesControllerTest < ActionDispatch::IntegrationTest
    setup do
      @user = users(:one)
      @other_user = users(:two)
      @category = @user.categories.create!(name: "Groceries", kind: "expense", color: "orange")
      sign_in_as @user
    end

    test "index lists only the current user's categories" do
      other_category = @other_user.categories.create!(name: "Their Rent", kind: "expense", color: "red")

      get categories_path

      assert_response :success
      assert_includes response.body, @category.name
      assert_not_includes response.body, other_category.name
    end

    test "index renders the category's color as a literal Tailwind class" do
      get categories_path

      assert_response :success
      assert_includes response.body, "bg-orange-500"
    end

    test "new renders the form" do
      get new_category_path
      assert_response :success
    end

    test "create with valid params" do
      assert_difference -> { @user.categories.count }, 1 do
        post categories_path, params: { category: { name: "Salary", kind: "income", color: "green" } }
      end

      assert_redirected_to categories_path
    end

    test "create with invalid params re-renders the form" do
      assert_no_difference -> { Category.count } do
        post categories_path, params: { category: { name: "", kind: "income", color: "green" } }
      end

      assert_response :unprocessable_entity
    end

    test "create with a duplicate name re-renders the form" do
      assert_no_difference -> { Category.count } do
        post categories_path, params: { category: { name: "Groceries", kind: "expense", color: "blue" } }
      end

      assert_response :unprocessable_entity
    end

    test "edit renders the form for the current user's category" do
      get edit_category_path(@category)
      assert_response :success
    end

    test "edit on another user's category is not found" do
      other_category = @other_user.categories.create!(name: "Their Rent", kind: "expense", color: "red")

      get edit_category_path(other_category)

      assert_response :not_found
    end

    test "update with valid params" do
      patch category_path(@category), params: { category: { name: "Updated Name" } }

      assert_redirected_to categories_path
      assert_equal "Updated Name", @category.reload.name
    end

    test "update on another user's category is not found" do
      other_category = @other_user.categories.create!(name: "Their Rent", kind: "expense", color: "red")

      patch category_path(other_category), params: { category: { name: "Hijacked" } }

      assert_response :not_found
      assert_not_equal "Hijacked", other_category.reload.name
    end

    test "destroy removes the category" do
      assert_difference -> { Category.count }, -1 do
        delete category_path(@category)
      end

      assert_redirected_to categories_path
    end

    test "destroy on another user's category is not found" do
      other_category = @other_user.categories.create!(name: "Their Rent", kind: "expense", color: "red")

      assert_no_difference -> { Category.count } do
        delete category_path(other_category)
      end

      assert_response :not_found
    end
  end
  ```

- [ ] **Step 3: Run the tests to verify they fail**

  Run: `bin/rails test test/controllers/categories_controller_test.rb`
  Expected: FAIL — `uninitialized constant CategoriesController` (route exists from Step 1, controller doesn't).

- [ ] **Step 4: Write the controller**

  Create `app/controllers/categories_controller.rb`:

  ```ruby
  class CategoriesController < ApplicationController
    before_action :set_category, only: %i[ edit update destroy ]

    def index
      @categories = Current.user.categories.order(:name)
    end

    def new
      @category = Current.user.categories.build
    end

    def create
      @category = Current.user.categories.build(category_params)

      if @category.save
        redirect_to categories_path, notice: "Category created."
      else
        render :new, status: :unprocessable_entity
      end
    end

    def edit
    end

    def update
      if @category.update(category_params)
        redirect_to categories_path, notice: "Category updated."
      else
        render :edit, status: :unprocessable_entity
      end
    end

    def destroy
      @category.destroy
      redirect_to categories_path, notice: "Category deleted.", status: :see_other
    end

    private
      def set_category
        @category = Current.user.categories.find(params[:id])
      end

      def category_params
        params.expect(category: [ :name, :kind, :color ])
      end
  end
  ```

- [ ] **Step 5: Write the color helper**

  Create `app/helpers/categories_helper.rb`:

  ```ruby
  module CategoriesHelper
    def category_color_classes(color)
      case color
      when "red" then "bg-red-500"
      when "orange" then "bg-orange-500"
      when "yellow" then "bg-yellow-500"
      when "green" then "bg-green-500"
      when "teal" then "bg-teal-500"
      when "blue" then "bg-blue-500"
      when "purple" then "bg-purple-500"
      when "pink" then "bg-pink-500"
      end
    end
  end
  ```

- [ ] **Step 6: Write the shared form partial**

  Create `app/views/categories/_form.html.erb`:

  ```erb
  <%= form_with model: category, class: "w-full max-w-md" do |form| %>
    <% if category.errors.any? %>
      <div class="alert alert-error mb-5">
        <ul>
          <% category.errors.each do |error| %>
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
      <%= form.select :kind, Category.kinds.keys.map { |k| [ k.titleize, k ] }, { prompt: "Select a kind" }, { required: true, class: "select select-bordered w-full" } %>
    </div>

    <div class="mb-6">
      <%= form.label :color, class: "label" %>
      <%= form.select :color, Category.colors.keys.map { |c| [ c.titleize, c ] }, { prompt: "Select a color" }, { required: true, class: "select select-bordered w-full" } %>
    </div>

    <%= form.submit class: "btn btn-primary" %>
  <% end %>
  ```

- [ ] **Step 7: Write the index, new, and edit views**

  Create `app/views/categories/index.html.erb`:

  ```erb
  <div class="w-full">
    <div class="flex justify-between items-center mb-6">
      <h1 class="text-4xl font-bold">Categories</h1>
      <%= link_to "New Category", new_category_path, class: "btn btn-primary" %>
    </div>

    <div class="overflow-x-auto">
      <table class="table">
        <thead>
          <tr>
            <th></th>
            <th>Name</th>
            <th>Kind</th>
            <th></th>
          </tr>
        </thead>
        <tbody>
          <% @categories.each do |category| %>
            <tr>
              <td><span class="inline-block size-4 rounded-full <%= category_color_classes(category.color) %>"></span></td>
              <td><%= category.name %></td>
              <td><%= category.kind.titleize %></td>
              <td class="text-right">
                <%= link_to "Edit", edit_category_path(category), class: "btn btn-sm btn-ghost" %>
                <%= button_to "Delete", category_path(category), method: :delete, data: { turbo_confirm: "Delete #{category.name}?" }, class: "btn btn-sm btn-ghost text-error" %>
              </td>
            </tr>
          <% end %>
        </tbody>
      </table>
    </div>
  </div>
  ```

  Create `app/views/categories/new.html.erb`:

  ```erb
  <div class="w-full">
    <h1 class="text-4xl font-bold mb-6">New Category</h1>
    <%= render "form", category: @category %>
  </div>
  ```

  Create `app/views/categories/edit.html.erb`:

  ```erb
  <div class="w-full">
    <h1 class="text-4xl font-bold mb-6">Edit Category</h1>
    <%= render "form", category: @category %>
  </div>
  ```

- [ ] **Step 8: Run the tests to verify they pass**

  Run: `bin/rails test test/controllers/categories_controller_test.rb`
  Expected: `12 runs, ... 0 failures, 0 errors`

- [ ] **Step 9: Verify all 8 color classes actually compile**

  This is the step that catches the interpolation trap described in Global Constraints — don't skip it even though the code "looks right":

  ```bash
  bin/rails tailwindcss:build
  for color in red orange yellow green teal blue purple pink; do
    grep -q "bg-${color}-500" app/assets/builds/tailwind.css && echo "OK: bg-${color}-500" || echo "MISSING: bg-${color}-500"
  done
  ```

  Expected: `OK: bg-<color>-500` printed for all 8 colors, no `MISSING` lines. If any are missing, the `case`/`when` helper in Step 5 has a typo, or something upstream (unlikely, but check) is stripping the class before it reaches the compiled CSS — do not proceed until all 8 print `OK`.

- [ ] **Step 10: Rubocop**

  Run: `bin/rubocop config/routes.rb app/controllers/categories_controller.rb app/helpers/categories_helper.rb test/controllers/categories_controller_test.rb`
  Expected: `no offenses detected`.

- [ ] **Step 11: Manual verification**

  Boot the app (or use the real-HTTP-request substitute if no browser tooling is available in your environment, as used earlier in this project's Accounts slice — cookies, CSRF, real POST/PATCH/DELETE against `bin/rails server`):

  ```bash
  bin/rails tailwindcss:build
  bin/dev
  ```

  Sign in, visit `/categories`, create a category with each of a few different colors, confirm the colored dot actually renders with the right color in the index table (not a blank/missing swatch), edit one, delete one. Confirm the duplicate-name validation error renders correctly if you try to create two categories with the same name (case-insensitive — try one exact duplicate and one differently-cased duplicate). Stop `bin/dev` with Ctrl+C when done.

- [ ] **Step 12: Run the full suite one more time**

  Run: `bin/rails test`
  Expected: all tests pass — Task 1, Task 2, and Task 3's tests together, plus every pre-existing test in the app.

- [ ] **Step 13: Commit**

  ```bash
  git add config/routes.rb app/controllers/categories_controller.rb app/helpers/categories_helper.rb app/views/categories test/controllers/categories_controller_test.rb
  git commit -m "Add Categories CRUD, scoped to the current user"
  ```

- [ ] **Step 14: Push**

  ```bash
  git push
  ```

  This triggers a Render auto-deploy. Check `render deploys list srv-d9eu93rrjlhs73d4usp0 --output json` (or the Render dashboard) for `live` status, and spot-check `https://moneymap-1rbv.onrender.com/categories` after signing in — including confirming the color dots render correctly in production, not just locally (production runs its own `tailwindcss:build` during the Docker build, so this is a real, independent verification of Step 9, not a redundant check).
