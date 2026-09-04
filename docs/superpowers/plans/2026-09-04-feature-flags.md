# Feature flags implementation plan

**Goal:** Add Postgres-backed feature flags (global + per-user override, keys declared in a small
code registry, hand-rolled not Flipper) with an admin-only DaisyUI UI, per
`docs/superpowers/specs/2026-09-04-feature-flags-design.md`.

**Architecture:** Two new models (`FeatureFlag`, `FeatureFlagAssignment`), one check service
(`FeatureFlagCheck`), a boolean `User#admin` column, and an `Admin::` controller namespace gated by
it. No screen is gated behind a flag in this plan — see the spec's "Decisions" section for why.

**Tech Stack:** Rails 8.1.3, PostgreSQL, Minitest — no new gems.

## Global Constraints

- Ruby 3.4, Rails 8.1.3 — existing app conventions, not new ones. Double-quoted string literals
  (`bin/rubocop` enforces this).
- `Current.user`, not `current_user` — no such method exists in this app.
- Every admin action gates through `Current.user&.admin?`, `head :not_found` for a no. No
  admin/cross-user access path existed before this plan — this introduces the first one.
- Tests are Minitest (`ActiveSupport::TestCase` for models/services, `ActionDispatch::IntegrationTest`
  for controllers), matching every existing test file. `users(:one)`/`users(:two)` fixtures for
  `User`; everything else created inline via `.create!`/`.build` — don't add new fixture files.
- Run `bin/rubocop` after every task; run the full `bin/rails test` before the final commit.

---

### Task 1: `User#admin` column

**Files:**
- Create: `db/migrate/<timestamp>_add_admin_to_users.rb`
- Test: `test/models/user_test.rb` (create if it doesn't exist yet — check first)

**Interfaces:**
- Produces: `User#admin?` / `User#admin=` (Rails' auto-generated boolean accessor/predicate — no
  code needed beyond the column).

- [ ] **Step 1: Check for an existing `user_test.rb`**

  Run: `ls test/models/user_test.rb`. If it exists, you'll add to it in Step 4; if not, you'll
  create it there.

- [ ] **Step 2: Generate and write the migration**

  Run: `bin/rails generate migration AddAdminToUsers`

  Replace the generated file's contents:

  ```ruby
  class AddAdminToUsers < ActiveRecord::Migration[8.1]
    def change
      add_column :users, :admin, :boolean, null: false, default: false
    end
  end
  ```

- [ ] **Step 3: Run the migration**

  Run: `bin/rails db:migrate`
  Expected: `== AddAdminToUsers: migrated` with no errors. Confirm `db/schema.rb` now has an
  `"admin"` boolean column on `users`.

- [ ] **Step 4: Test default value**

  In `test/models/user_test.rb` (creating the file with `require "test_helper"` and a bare
  `class UserTest < ActiveSupport::TestCase` wrapper if it didn't already exist), add:

  ```ruby
  test "admin defaults to false" do
    assert_not users(:one).admin?
  end
  ```

  Run: `bin/rails test test/models/user_test.rb`
  Expected: passes (fixtures don't set `admin`, so the column default applies).

- [ ] **Step 5: Rubocop + commit**

  Run: `bin/rubocop db/migrate test/models/user_test.rb`

  ```bash
  git add db/migrate db/schema.rb test/models/user_test.rb
  git commit -m "Add admin column to users"
  ```

---

### Task 2: `FeatureFlag` and `FeatureFlagAssignment` models

**Files:**
- Create: `db/migrate/<timestamp>_create_feature_flags.rb`
- Create: `db/migrate/<timestamp>_create_feature_flag_assignments.rb`
- Create: `app/models/feature_flag.rb`
- Create: `app/models/feature_flag_assignment.rb`
- Test: `test/models/feature_flag_test.rb`
- Test: `test/models/feature_flag_assignment_test.rb`

**Interfaces:**
- Produces: `FeatureFlag::REGISTRY`, `FeatureFlag#globally_enabled?`,
  `feature_flag.feature_flag_assignments`, `feature_flag.users`, `FeatureFlagAssignment
  belongs_to :feature_flag, :user`.
- Later tasks (Task 3) consume: all of the above, plus `FeatureFlag.find_by(key:)`.

- [ ] **Step 1: Generate the migrations**

  ```bash
  bin/rails generate migration CreateFeatureFlags
  bin/rails generate migration CreateFeatureFlagAssignments
  ```

- [ ] **Step 2: Write the FeatureFlags migration**

  ```ruby
  class CreateFeatureFlags < ActiveRecord::Migration[8.1]
    def change
      create_table :feature_flags do |t|
        t.string :key, null: false
        t.boolean :globally_enabled, null: false, default: false

        t.timestamps
      end
      add_index :feature_flags, :key, unique: true
    end
  end
  ```

- [ ] **Step 3: Write the FeatureFlagAssignments migration**

  ```ruby
  class CreateFeatureFlagAssignments < ActiveRecord::Migration[8.1]
    def change
      create_table :feature_flag_assignments do |t|
        t.references :feature_flag, null: false, foreign_key: true
        t.references :user, null: false, foreign_key: true

        t.timestamps
      end
      add_index :feature_flag_assignments, [ :feature_flag_id, :user_id ], unique: true,
        name: "index_feature_flag_assignments_on_flag_and_user"
    end
  end
  ```

- [ ] **Step 4: Run the migrations**

  Run: `bin/rails db:migrate`
  Expected: both migrate cleanly. Confirm `db/schema.rb` has `feature_flags` and
  `feature_flag_assignments` tables with the foreign keys and unique indexes above.

- [ ] **Step 5: Write the failing model tests**

  Create `test/models/feature_flag_test.rb`:

  ```ruby
  require "test_helper"

  class FeatureFlagTest < ActiveSupport::TestCase
    test "valid with a registered key" do
      flag = FeatureFlag.new(key: FeatureFlag::REGISTRY.first)
      assert flag.valid?
    end

    test "invalid without a key" do
      flag = FeatureFlag.new(key: nil)
      assert_not flag.valid?
      assert_includes flag.errors[:key], "can't be blank"
    end

    test "invalid with a key outside the registry" do
      flag = FeatureFlag.new(key: "not_a_real_flag")
      assert_not flag.valid?
      assert_includes flag.errors[:key], "is not included in the list"
    end

    test "invalid with a duplicate key" do
      FeatureFlag.create!(key: FeatureFlag::REGISTRY.first)
      duplicate = FeatureFlag.new(key: FeatureFlag::REGISTRY.first)

      assert_not duplicate.valid?
      assert_includes duplicate.errors[:key], "has already been taken"
    end

    test "defaults to not globally enabled" do
      flag = FeatureFlag.create!(key: FeatureFlag::REGISTRY.first)
      assert_not flag.globally_enabled?
    end

    test "destroying a flag destroys its assignments" do
      flag = FeatureFlag.create!(key: FeatureFlag::REGISTRY.first)
      flag.feature_flag_assignments.create!(user: users(:one))

      assert_difference -> { FeatureFlagAssignment.count }, -1 do
        flag.destroy
      end
    end
  end
  ```

  Create `test/models/feature_flag_assignment_test.rb`:

  ```ruby
  require "test_helper"

  class FeatureFlagAssignmentTest < ActiveSupport::TestCase
    setup { @flag = FeatureFlag.create!(key: FeatureFlag::REGISTRY.first) }

    test "valid with a flag and a user" do
      assignment = @flag.feature_flag_assignments.build(user: users(:one))
      assert assignment.valid?
    end

    test "invalid with a duplicate user for the same flag" do
      @flag.feature_flag_assignments.create!(user: users(:one))
      duplicate = @flag.feature_flag_assignments.build(user: users(:one))

      assert_not duplicate.valid?
      assert_includes duplicate.errors[:user_id], "has already been taken"
    end

    test "the same user can be assigned to a different flag" do
      other_key = FeatureFlag::REGISTRY.second || raise("REGISTRY needs 2+ keys for this test")
      other_flag = FeatureFlag.create!(key: other_key)
      @flag.feature_flag_assignments.create!(user: users(:one))

      assignment = other_flag.feature_flag_assignments.build(user: users(:one))
      assert assignment.valid?
    end
  end
  ```

- [ ] **Step 6: Run the tests to verify they fail**

  Run: `bin/rails test test/models/feature_flag_test.rb test/models/feature_flag_assignment_test.rb`
  Expected: FAIL — `NameError: uninitialized constant FeatureFlag`.

- [ ] **Step 7: Write the models**

  Create `app/models/feature_flag.rb`:

  ```ruby
  class FeatureFlag < ApplicationRecord
    # Placeholders for the upcoming dashboard/budgets work (see docs/repo-review-2026-08-29.md) —
    # add a key here before creating a FeatureFlag row with it.
    REGISTRY = %w[budgets dashboard].freeze

    has_many :feature_flag_assignments, dependent: :destroy
    has_many :users, through: :feature_flag_assignments

    validates :key, presence: true, uniqueness: true, inclusion: { in: REGISTRY }

    def self.enabled?(key, user: nil)
      FeatureFlagCheck.new(key, user: user).call
    end
  end
  ```

  Create `app/models/feature_flag_assignment.rb`:

  ```ruby
  class FeatureFlagAssignment < ApplicationRecord
    belongs_to :feature_flag
    belongs_to :user

    validates :user_id, uniqueness: { scope: :feature_flag_id }
  end
  ```

  Note `FeatureFlag.enabled?` references `FeatureFlagCheck`, written in Task 3 — the model tests in
  this task don't call `.enabled?`, so this is fine to land now.

- [ ] **Step 8: Run the tests to verify they pass**

  Run: `bin/rails test test/models/feature_flag_test.rb test/models/feature_flag_assignment_test.rb`
  Expected: `12 runs, ... 0 failures, 0 errors`

- [ ] **Step 9: Rubocop + commit**

  Run: `bin/rubocop db/migrate app/models/feature_flag.rb app/models/feature_flag_assignment.rb test/models/feature_flag_test.rb test/models/feature_flag_assignment_test.rb`

  ```bash
  git add db/migrate db/schema.rb app/models/feature_flag.rb app/models/feature_flag_assignment.rb test/models/feature_flag_test.rb test/models/feature_flag_assignment_test.rb
  git commit -m "Add FeatureFlag and FeatureFlagAssignment models"
  ```

---

### Task 3: `FeatureFlagCheck` service

**Files:**
- Create: `app/services/feature_flag_check.rb`
- Test: `test/services/feature_flag_check_test.rb`

**Interfaces:**
- Consumes (from Task 2): `FeatureFlag.find_by(key:)`, `flag.globally_enabled?`,
  `flag.feature_flag_assignments`.
- Produces: `FeatureFlagCheck.new(key, user:).call` → `true`/`false`, and (via Task 2's
  `FeatureFlag.enabled?`) the ergonomic call-site API any future controller/view will use.

- [ ] **Step 1: Write the failing test**

  Create `test/services/feature_flag_check_test.rb`:

  ```ruby
  require "test_helper"

  class FeatureFlagCheckTest < ActiveSupport::TestCase
    setup { @key = FeatureFlag::REGISTRY.first }

    test "false when no flag row exists for the key" do
      assert_not FeatureFlagCheck.new(@key, user: users(:one)).call
    end

    test "true when globally enabled, regardless of user" do
      FeatureFlag.create!(key: @key, globally_enabled: true)

      assert FeatureFlagCheck.new(@key, user: users(:one)).call
      assert FeatureFlagCheck.new(@key, user: nil).call
    end

    test "true when not globally enabled but the user has an assignment" do
      flag = FeatureFlag.create!(key: @key, globally_enabled: false)
      flag.feature_flag_assignments.create!(user: users(:one))

      assert FeatureFlagCheck.new(@key, user: users(:one)).call
    end

    test "false when not globally enabled and the user has no assignment" do
      FeatureFlag.create!(key: @key, globally_enabled: false)

      assert_not FeatureFlagCheck.new(@key, user: users(:one)).call
    end

    test "false when not globally enabled and there is no user" do
      FeatureFlag.create!(key: @key, globally_enabled: false)

      assert_not FeatureFlagCheck.new(@key, user: nil).call
    end

    test "accepts the key as a symbol" do
      FeatureFlag.create!(key: @key, globally_enabled: true)

      assert FeatureFlagCheck.new(@key.to_sym, user: nil).call
    end
  end
  ```

- [ ] **Step 2: Run the test to verify it fails**

  Run: `bin/rails test test/services/feature_flag_check_test.rb`
  Expected: FAIL — `NameError: uninitialized constant FeatureFlagCheck`.

- [ ] **Step 3: Write the service**

  Create `app/services/feature_flag_check.rb`:

  ```ruby
  class FeatureFlagCheck
    def initialize(key, user: nil)
      @key = key.to_s
      @user = user
    end

    def call
      flag = FeatureFlag.find_by(key: @key)
      return false unless flag
      return true if flag.globally_enabled?
      return false unless @user

      flag.feature_flag_assignments.exists?(user_id: @user.id)
    end
  end
  ```

- [ ] **Step 4: Run the test to verify it passes**

  Run: `bin/rails test test/services/feature_flag_check_test.rb`
  Expected: `6 runs, ... 0 failures, 0 errors`

- [ ] **Step 5: Rubocop + commit**

  Run: `bin/rubocop app/services/feature_flag_check.rb test/services/feature_flag_check_test.rb`

  ```bash
  git add app/services/feature_flag_check.rb test/services/feature_flag_check_test.rb
  git commit -m "Add FeatureFlagCheck service"
  ```

---

### Task 4: Admin authorization concern

**Files:**
- Create: `app/controllers/concerns/admin_authorization.rb`
- Create: `app/controllers/admin/base_controller.rb`
- Test: covered by Task 5's controller tests (this concern has no behavior worth unit-testing in
  isolation — it's one `before_action`)

**Interfaces:**
- Produces: `AdminAuthorization` concern (`before_action :require_admin`), `Admin::BaseController`
  for every admin controller to inherit from.
- Later tasks (Task 5) consume: `Admin::BaseController`.

- [ ] **Step 1: Write the concern**

  Create `app/controllers/concerns/admin_authorization.rb`:

  ```ruby
  module AdminAuthorization
    extend ActiveSupport::Concern

    included do
      before_action :require_admin
    end

    private
      def require_admin
        head :not_found unless Current.user&.admin?
      end
  end
  ```

- [ ] **Step 2: Write the base controller**

  Create `app/controllers/admin/base_controller.rb`:

  ```ruby
  module Admin
    class BaseController < ApplicationController
      include AdminAuthorization
    end
  end
  ```

- [ ] **Step 3: Rubocop + commit**

  Run: `bin/rubocop app/controllers/concerns/admin_authorization.rb app/controllers/admin/base_controller.rb`

  ```bash
  git add app/controllers/concerns/admin_authorization.rb app/controllers/admin/base_controller.rb
  git commit -m "Add admin authorization concern and base controller"
  ```

---

### Task 5: Admin feature flags UI

**Files:**
- Modify: `config/routes.rb`
- Create: `app/controllers/admin/feature_flags_controller.rb`
- Create: `app/controllers/admin/feature_flag_assignments_controller.rb`
- Create: `app/views/admin/feature_flags/index.html.erb`
- Modify: `app/views/layouts/application.html.erb`
- Test: `test/controllers/admin/feature_flags_controller_test.rb`
- Test: `test/controllers/admin/feature_flag_assignments_controller_test.rb`

**Interfaces:**
- Consumes (from Tasks 1-4): `User#admin?`, `FeatureFlag`/`FeatureFlagAssignment` models,
  `Admin::BaseController`.
- Produces: routes `admin_feature_flags_path`, `admin_feature_flag_path(flag)`,
  `admin_feature_flag_assignments_path(flag)`, `admin_feature_flag_assignment_path(flag,
  assignment)`; an "Admin" navbar link visible only to admins.

- [ ] **Step 1: Add the routes**

  In `config/routes.rb`, add inside `Rails.application.routes.draw do ... end` (after the existing
  `resources :transfers` line):

  ```ruby
  namespace :admin do
    resources :feature_flags, only: %i[ index update ] do
      resources :feature_flag_assignments, only: %i[ create destroy ], as: :assignments
    end
  end
  ```

- [ ] **Step 2: Write the failing controller tests**

  Create `test/controllers/admin/feature_flags_controller_test.rb`:

  ```ruby
  require "test_helper"

  class Admin::FeatureFlagsControllerTest < ActionDispatch::IntegrationTest
    setup do
      @admin = users(:one)
      @admin.update!(admin: true)
      @non_admin = users(:two)
    end

    test "index is not found when signed out" do
      get admin_feature_flags_path
      assert_response :not_found
    end

    test "index is not found for a signed-in non-admin" do
      sign_in_as @non_admin
      get admin_feature_flags_path
      assert_response :not_found
    end

    test "index lists every registered flag for an admin, creating rows as needed" do
      sign_in_as @admin

      assert_difference -> { FeatureFlag.count }, FeatureFlag::REGISTRY.size do
        get admin_feature_flags_path
      end

      assert_response :success
      FeatureFlag::REGISTRY.each { |key| assert_includes response.body, key }
    end

    test "update toggles globally_enabled" do
      sign_in_as @admin
      flag = FeatureFlag.create!(key: FeatureFlag::REGISTRY.first)

      patch admin_feature_flag_path(flag)
      assert_redirected_to admin_feature_flags_path
      assert flag.reload.globally_enabled?

      patch admin_feature_flag_path(flag)
      assert_not flag.reload.globally_enabled?
    end

    test "update is not found for a signed-in non-admin" do
      sign_in_as @non_admin
      flag = FeatureFlag.create!(key: FeatureFlag::REGISTRY.first)

      patch admin_feature_flag_path(flag)

      assert_response :not_found
      assert_not flag.reload.globally_enabled?
    end
  end
  ```

  Create `test/controllers/admin/feature_flag_assignments_controller_test.rb`:

  ```ruby
  require "test_helper"

  class Admin::FeatureFlagAssignmentsControllerTest < ActionDispatch::IntegrationTest
    setup do
      @admin = users(:one)
      @admin.update!(admin: true)
      @target_user = users(:two)
      @flag = FeatureFlag.create!(key: FeatureFlag::REGISTRY.first)
      sign_in_as @admin
    end

    test "create grants the flag to a user found by email" do
      assert_difference -> { @flag.feature_flag_assignments.count }, 1 do
        post admin_feature_flag_assignments_path(@flag), params: { email_address: @target_user.email_address }
      end

      assert_redirected_to admin_feature_flags_path
      assert @flag.users.include?(@target_user)
    end

    test "create with an unknown email does not create an assignment" do
      assert_no_difference -> { FeatureFlagAssignment.count } do
        post admin_feature_flag_assignments_path(@flag), params: { email_address: "nobody@example.com" }
      end

      assert_redirected_to admin_feature_flags_path
    end

    test "destroy revokes the assignment" do
      assignment = @flag.feature_flag_assignments.create!(user: @target_user)

      assert_difference -> { FeatureFlagAssignment.count }, -1 do
        delete admin_feature_flag_assignment_path(@flag, assignment)
      end

      assert_redirected_to admin_feature_flags_path
    end

    test "create is not found for a signed-in non-admin" do
      sign_out
      sign_in_as @target_user

      assert_no_difference -> { FeatureFlagAssignment.count } do
        post admin_feature_flag_assignments_path(@flag), params: { email_address: @target_user.email_address }
      end

      assert_response :not_found
    end
  end
  ```

- [ ] **Step 3: Run the tests to verify they fail**

  Run: `bin/rails test test/controllers/admin/`
  Expected: FAIL — routing errors, since the routes/controllers don't exist as real endpoints yet.

- [ ] **Step 4: Write the controllers**

  Create `app/controllers/admin/feature_flags_controller.rb`:

  ```ruby
  module Admin
    class FeatureFlagsController < Admin::BaseController
      def index
        FeatureFlag::REGISTRY.each { |key| FeatureFlag.find_or_create_by!(key: key) }
        @feature_flags = FeatureFlag.includes(:users).order(:key)
      end

      def update
        feature_flag = FeatureFlag.find(params[:id])
        feature_flag.update!(globally_enabled: !feature_flag.globally_enabled?)

        redirect_to admin_feature_flags_path,
          notice: "#{feature_flag.key.titleize} #{feature_flag.globally_enabled? ? "enabled" : "disabled"} globally."
      end
    end
  end
  ```

  Create `app/controllers/admin/feature_flag_assignments_controller.rb`:

  ```ruby
  module Admin
    class FeatureFlagAssignmentsController < Admin::BaseController
      before_action :set_feature_flag

      def create
        user = User.find_by(email_address: params[:email_address].to_s.strip.downcase)

        if user.nil?
          redirect_to admin_feature_flags_path, alert: "No user with that email address."
          return
        end

        @feature_flag.feature_flag_assignments.find_or_create_by!(user: user)
        redirect_to admin_feature_flags_path, notice: "#{user.email_address} enabled for #{@feature_flag.key.titleize}."
      end

      def destroy
        @feature_flag.feature_flag_assignments.find(params[:id]).destroy
        redirect_to admin_feature_flags_path, notice: "Override removed.", status: :see_other
      end

      private
        def set_feature_flag
          @feature_flag = FeatureFlag.find(params[:feature_flag_id])
        end
    end
  end
  ```

- [ ] **Step 5: Write the view**

  Create `app/views/admin/feature_flags/index.html.erb`:

  ```erb
  <div class="w-full">
    <h1 class="text-4xl font-bold mb-6">Feature flags</h1>

    <div class="overflow-x-auto">
      <table class="table">
        <thead>
          <tr>
            <th>Key</th>
            <th>Global</th>
            <th>Per-user overrides</th>
            <th>Grant to</th>
          </tr>
        </thead>
        <tbody>
          <% @feature_flags.each do |flag| %>
            <tr>
              <td class="font-mono"><%= flag.key %></td>
              <td>
                <%= button_to (flag.globally_enabled? ? "On" : "Off"), admin_feature_flag_path(flag),
                      method: :patch, class: "btn btn-sm #{flag.globally_enabled? ? "btn-success" : "btn-ghost"}" %>
              </td>
              <td>
                <ul class="flex flex-col gap-1">
                  <% flag.users.each do |user| %>
                    <li class="flex items-center gap-2">
                      <%= user.email_address %>
                      <%= button_to "Revoke",
                            admin_feature_flag_assignment_path(flag, flag.feature_flag_assignments.find_by(user: user)),
                            method: :delete, class: "btn btn-xs btn-ghost text-error" %>
                    </li>
                  <% end %>
                </ul>
              </td>
              <td>
                <%= form_with url: admin_feature_flag_assignments_path(flag), class: "flex gap-2" do |form| %>
                  <%= form.email_field :email_address, placeholder: "user@example.com", required: true, class: "input input-bordered input-sm" %>
                  <%= form.submit "Grant", class: "btn btn-sm" %>
                <% end %>
              </td>
            </tr>
          <% end %>
        </tbody>
      </table>
    </div>
  </div>
  ```

- [ ] **Step 6: Add the navbar link**

  In `app/views/layouts/application.html.erb`, inside the `<% if authenticated? %>` navbar block,
  after the existing `Transactions` link:

  ```erb
  <% if Current.user&.admin? %>
    <%= link_to "Admin", admin_feature_flags_path, class: "btn btn-ghost" %>
  <% end %>
  ```

- [ ] **Step 7: Run the tests to verify they pass**

  Run: `bin/rails test test/controllers/admin/`
  Expected: all passing.

- [ ] **Step 8: Rubocop**

  Run: `bin/rubocop config/routes.rb app/controllers/admin app/views/layouts/application.html.erb test/controllers/admin`
  Expected: `no offenses detected`.

- [ ] **Step 9: Manual browser check**

  ```bash
  bin/rails tailwindcss:build
  bin/dev
  ```

  In the Rails console (separate terminal): `User.find_by(email_address: "one@example.com").update!(admin: true)`
  (or whichever seeded user you're signed in as). In the browser: sign in, confirm the "Admin" link
  appears in the navbar, visit it, toggle a flag's global switch, grant it to the other seeded
  user's email, revoke it. Sign in as a non-admin user (or sign out) and confirm `/admin/feature_flags`
  404s. Stop `bin/dev` with Ctrl+C when done.

- [ ] **Step 10: Full test suite + commit**

  Run: `bin/rails test`
  Expected: all tests pass, including every pre-existing test file.

  ```bash
  git add config/routes.rb app/controllers/admin app/views/admin app/views/layouts/application.html.erb test/controllers/admin
  git commit -m "Add admin feature flags UI"
  ```

---

### Task 6: Update CLAUDE.md

**Files:**
- Modify: `CLAUDE.md`

- [ ] **Step 1: Add a Conventions bullet**

  In `CLAUDE.md`'s **Conventions** section, add (after the DaisyUI/icons bullet):

  ```markdown
  - **Feature flags** are Postgres-backed via a hand-rolled `FeatureFlag`/`FeatureFlagAssignment`
    model pair (no Flipper, no Redis) — see
    `docs/superpowers/specs/2026-09-04-feature-flags-design.md` for why. Check one with
    `FeatureFlag.enabled?(:key, user: Current.user)` (logic lives in
    `app/services/feature_flag_check.rb`; global enablement always wins over a per-user override).
    To add a new flag: add its key to `FeatureFlag::REGISTRY` in `app/models/feature_flag.rb`, then
    either toggle it at `/admin/feature_flags` (creates its row automatically) or in Rails console
    (`FeatureFlag.create!(key: "...")`) — takes effect immediately, no deploy. The admin UI itself
    is gated by `User#admin` (boolean column, no self-serve grant path — promote via console:
    `User.find_by(email_address: "...").update!(admin: true)`).
  ```

- [ ] **Step 2: Commit**

  ```bash
  git add CLAUDE.md
  git commit -m "Document feature flag usage in CLAUDE.md"
  ```

---

### Task 7: Push and open the PR

- [ ] **Step 1: Push**

  ```bash
  git push -u origin claude/feature-flags-rails-nmpqah
  ```

- [ ] **Step 2: Open a PR against `staging`**, not `main`, per `docs/agentic-development-lifecycle.md`.
