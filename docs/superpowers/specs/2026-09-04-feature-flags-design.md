# Feature flags — design

**Date:** 2026-09-04
**Status:** approved, ready for implementation plan

## Context

Moneymap needs to merge and deploy in-progress product work (starting with the dashboard/budgets
work flagged in `docs/repo-review-2026-08-29.md`) without exposing it to users before it's ready.
Today there's no way to do that — a merge to `staging` and a `staging`→`main` promotion (see
`docs/agentic-development-lifecycle.md`) makes a feature live for everyone. Feature flags
complement that QA flow, they don't replace it: staging still verifies a feature works, flags
control who sees it once it's in production.

## Decisions (from brainstorm)

- **Scope: global + per-user override.** A flag can be off for everyone but explicitly granted to
  specific users — e.g. to dogfood a feature on the founder's own account before a wider rollout.
  Global takes precedence: if a flag is globally enabled, per-user assignments are moot.
- **Definition: small code registry.** Flag keys are declared in `FeatureFlag::REGISTRY`, a plain
  array constant. A `FeatureFlag` row's `key` is validated against it, so a typo in a check
  (`FeatureFlag.enabled?(:dahsboard, ...)`) can't silently create a phantom always-off flag — it
  just never finds a matching row (returns `false`), and the mistake is visible by reading one
  small array in `app/models/feature_flag.rb`.
- **Implementation: hand-rolled, not Flipper.** Flipper (`flipper` + `flipper-active_record`) was
  the natural-seeming Postgres-backed, no-Redis option, but the actual need here is narrow enough
  (global toggle, per-user override, an internal admin UI) that hand-rolling doesn't cost more
  than integrating Flipper would — and it avoids a real gap: `flipper-ui` ships its own styling,
  not DaisyUI, and Flipper has no built-in auth, so gating its mounted engine to admins-only would
  still be custom code on top of a gem. Hand-rolling keeps everything DaisyUI-styled, Minitest-
  tested, and consistent with the rest of the app, for two migrations and a handful of small files.
- **Admin concept is new.** `CLAUDE.md` is explicit that no admin/cross-user access path exists
  yet. This work introduces the first one: a boolean `User#admin` column (no self-serve grant UI —
  promoted via Rails console only, `User.find_by(email_address: "...").update!(admin: true)`) and
  an `Admin::` controller namespace gated by it.
- **No screen is gated as part of this work.** The dashboard/budgets work this is meant to protect
  doesn't exist yet (confirmed against `docs/repo-review-2026-08-29.md` — the home page is still a
  static welcome card), so there's nothing real to wire a flag to today. This ships the flag
  system itself, proven by its own admin UI and full test coverage, ready for the first real
  feature to call `FeatureFlag.enabled?(...)` when that work starts. `FeatureFlag::REGISTRY`
  pre-declares `budgets` and `dashboard` as placeholders for that upcoming work.

## Data model

```ruby
# db/migrate/..._add_admin_to_users.rb
add_column :users, :admin, :boolean, null: false, default: false

# db/migrate/..._create_feature_flags.rb
create_table :feature_flags do |t|
  t.string :key, null: false
  t.boolean :globally_enabled, null: false, default: false
  t.timestamps
end
add_index :feature_flags, :key, unique: true

# db/migrate/..._create_feature_flag_assignments.rb
create_table :feature_flag_assignments do |t|
  t.references :feature_flag, null: false, foreign_key: true
  t.references :user, null: false, foreign_key: true
  t.timestamps
end
add_index :feature_flag_assignments, [ :feature_flag_id, :user_id ], unique: true, name: "index_feature_flag_assignments_on_flag_and_user"
```

- `FeatureFlag belongs_to` nothing; `has_many :feature_flag_assignments, dependent: :destroy` and
  `has_many :users, through: :feature_flag_assignments` (for admin-UI display).
- `FeatureFlagAssignment belongs_to :feature_flag`, `belongs_to :user` — a row's mere existence is
  the grant; no boolean column on it.
- `key` validated present, unique, and `inclusion: { in: FeatureFlag::REGISTRY }`.

## Check API

Business logic (global-vs-override precedence) lives in a service, per CLAUDE.md's "business
logic belongs in app/services, one public `#call` method" convention — not inlined into the model
or scattered across call sites:

```ruby
# app/services/feature_flag_check.rb
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

`FeatureFlag.enabled?(key, user: nil)` is a one-line class method delegating to the service, so
call sites read naturally: `FeatureFlag.enabled?(:budgets, user: Current.user)`.

## Admin UI

- `app/controllers/concerns/admin_authorization.rb` — `before_action :require_admin`, `head
  :not_found` for non-admins (same 404-not-403 philosophy the app already uses for cross-user
  record access: don't reveal that an admin-only resource exists).
- `Admin::BaseController < ApplicationController`, includes `AdminAuthorization`.
- `Admin::FeatureFlagsController` — `index` (lists every registry key, auto-creating any row that
  doesn't exist yet via `find_or_create_by!` so there's nothing to set up in console first) and
  `update` (flips `globally_enabled`).
- `Admin::FeatureFlagAssignmentsController` — `create` (grants a user by email address) and
  `destroy` (revokes) under `resources :feature_flags do resources :feature_flag_assignments end`.
- One DaisyUI view (`admin/feature_flags/index.html.erb`): a table of flags, each row with a
  global-toggle button and its list of per-user overrides (email + revoke), plus an inline "grant
  to email" form per flag.
- Navbar shows an "Admin" link only when `Current.user&.admin?`.

## Testing

- `test/models/feature_flag_test.rb`, `test/models/feature_flag_assignment_test.rb` — validations,
  associations, the uniqueness scope on assignments.
- `test/services/feature_flag_check_test.rb` — no flag → false; globally enabled → true regardless
  of user (including no user); not globally enabled + assigned user → true; not globally enabled +
  unassigned/nil user → false.
- `test/controllers/admin/feature_flags_controller_test.rb`,
  `test/controllers/admin/feature_flag_assignments_controller_test.rb` — admin-only (404 for a
  signed-in non-admin and for a signed-out request), toggle/grant/revoke happy paths.
- No system test — matches CLAUDE.md (system tests aren't part of `bin/ci` by default). Manual
  `bin/dev` check of the admin page instead.

## Open items for later

- Wiring `FeatureFlag.enabled?` into an actual controller/view once the dashboard or budgets work
  starts — this spec deliberately stops short of that (see Decisions above).
- A self-serve way to grant the `admin` flag itself, if more than one admin is ever needed.
