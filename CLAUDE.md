# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

@AGENTS.md

Claude Code only reads `CLAUDE.md`, never `AGENTS.md`, in either local or cloud sessions
(confirmed against [code.claude.com/docs/en/memory.md](https://code.claude.com/docs/en/memory.md)) —
the import above is what actually makes `AGENTS.md`'s content (currently: the caveman style rule)
reach Claude Code at all. See `docs/claude-code-plugins-and-mcps.md`'s caveman section for how
`AGENTS.md` was generated and kept in sync with the other IDE-agent rule files.

## What Moneymap is

Two things in one, for individual users, not businesses or advisors:

1. **A personal finance app** — track accounts, categorize spending, and budget, starting with
   manual transaction entry (Plaid bank sync is later-phase, see the plan doc below).
2. **A financial literacy aid** — the numbers come with context and education, not just a
   ledger. This is explicitly financial *education*, not personalized investment/securities
   advice — see the Scope note at the top of `docs/financial-literacy-platform-plan.md` for why
   that boundary matters.

Keep both pillars in mind when a feature is ambiguous: e.g. a spending-by-category chart is
pillar 1, but pairing it with "here's why this matters and what to do about it" copy is pillar 2
— both are in scope, generic bookkeeping/accounting-firm features are not.

## Project state

Moneymap is a Rails 8.1 application currently at the bootstrap stage: `rails new` plus the
built-in authentication generator (`bin/rails generate authentication`). Beyond
sign-up/sign-in/password-reset, there is no product-specific domain logic yet, so don't assume
the two pillars above are *implemented* — check `app/models` and `config/routes.rb` before
referencing "existing" functionality. The pillars describe what this repo is *for*, not what's
built so far.

`docs/financial-literacy-platform-plan.md` and `docs/environment-setup-runbook.md` capture the
longer-range plan (target data model, phased build-out, hosting/cost decisions) and the
Windows/WSL2 setup history. They describe an aspirational end state and a past setup session,
not the current repo — treat them as background context, not as a source of truth for what
exists today. The **Conventions** below are the subset of that plan already adopted for this repo.

### Next steps (as of the Kamal→Render migration)

- **Render deploy is confirmed live** (verified 2026-07-20): `moneymap-1rbv.onrender.com` boots
  and serves 200s on `/` and `/up`. Getting here took four fixes, the last of which is a real
  footgun worth knowing about — see `db:prepare_solid_schemas` in **Architecture → Deployment**
  below before touching `config/database.yml` or the production schema files.
- **Phase 1 is complete** (as of 2026-07-24): DaisyUI + Lucide icons are installed (see
  **Conventions** below for how, since there's no npm/Node in this repo), and `db/seeds.rb` seeds
  two sample users. Phase 1's remaining scope is now genuine product work — the target data model
  (Accounts → Categories → Transactions → Budget → Goals → Education) in
  `docs/financial-literacy-platform-plan.md`.
- Free-tier Postgres expires 2026-08-19 (created 2026-07-20) — upgrade or recreate before then.
  Recreating will hit the same "queue/cache/cable schemas don't load" issue on first boot;
  `db:prepare_solid_schemas` handles it automatically, no manual action needed.
- **Staging environment is scaffolded but not yet live**: `render.staging.yaml` + a `staging`
  branch exist for a `moneymap-staging` Render service, sharing production's free Postgres
  instance via a separate database rather than a second (paid) instance. The dashboard-side
  Blueprint creation and secret setup are manual steps not yet done — see
  `docs/staging-environment-setup.md` for the full walkthrough. Don't assume a staging URL exists
  until this note is updated to say it's live.
- **`docs/production-launch-tbd.md`** collects the costs and security/auth hardening still open
  before this is a real product with real users — a private GitHub repo, paid Render plans, a
  Claude Code plan that covers cloud sessions, no sign-up flow yet, no 2FA, no CSP, no Postgres
  backups, and more. Not a to-do list to execute now — a reference for when "real users" stops
  being hypothetical.

## Development workflow

⏸️ **Staging is paused as of 2026-09-04 — open PRs against `main` directly, not `staging`.**
Full details (including how to resume) are in `docs/agentic-development-lifecycle.md`'s
"Staging is currently paused" section; the short version is that build velocity comes first
while the product is still young, and merging a PR now deploys straight to production (there is
no pre-prod check in between). Compensate by testing locally before merging — `bin/ci`, plus a
manual click-through of the actual change — since there's no staging deploy to verify against
instead. Bugs, feature requests, and deferred work are still tracked as GitHub Issues (`bug` /
`enhancement` / `deferred` labels) — see the lifecycle doc for that convention, which is
unaffected by the pause.

## Commands

Database is PostgreSQL; you need a running Postgres server (`config/database.yml`,
databases named `moneymap_development` / `moneymap_test`).

- `bin/setup` — install gems, prepare the dev database, clear logs/tmp, then boot the server. Add `--skip-server` to stop after setup, `--reset` to reset the DB.
- `bin/dev` — run the app (Puma + Tailwind watcher, via `Procfile.dev`).
- `bin/rails test` — run the full test suite (unit/controller/model tests; parallelized across CPUs).
- `bin/rails test test/models/user_test.rb` — run a single test file.
- `bin/rails test test/models/user_test.rb:12` — run a single test by line number.
- `bin/rails test:system` — run system tests (Capybara/Selenium); not part of `bin/ci` by default.
- `bin/rubocop` — lint (Omakase Rails style, see `.rubocop.yml`).
- `bin/brakeman --no-pager` — static security analysis.
- `bin/bundler-audit` — audit gems for known CVEs.
- `bin/importmap audit` — audit JS dependencies pinned in `config/importmap.rb`.
- `bin/ci` — runs the full local CI pipeline in order (setup, rubocop, bundler-audit, importmap audit, brakeman, `rails test`, then reseeds the test DB as a smoke test). Mirrors `.github/workflows/ci.yml`; run this before considering a change done.

There is no build step for JS/CSS beyond the Tailwind watcher — JS is served via importmaps (no bundler/webpack), so adding a JS dependency means pinning it in `config/importmap.rb`, not editing a package.json.

## Architecture

Standard Rails MVC (no API-only mode, no `app/javascript` framework beyond Stimulus/Turbo).

**Authentication** is cookie/session based, not Devise:
- `Session` (DB-backed, `app/models/session.rb`) belongs to `User`; the signed, permanent `session_id` cookie stores the session's id.
- `Current` (`app/models/current.rb`, an `ActiveSupport::CurrentAttributes`) holds the request-local `session`/`user`.
- `Authentication` concern (`app/controllers/concerns/authentication.rb`), included by `ApplicationController`, enforces login on every action via a `before_action`. Controllers/actions that should be reachable while logged out must opt out explicitly with `allow_unauthenticated_access` (see `SessionsController`, `PasswordsController`).
- Password reset uses signed tokens (`User#find_by_password_reset_token!` from `has_secure_password`) rather than a stored reset column; `PasswordsMailer` delivers the reset link.
- In tests, use `sign_in_as(user)` / `sign_out` from `test/test_helpers/session_test_helper.rb` (auto-included into integration tests) rather than hitting the sessions controller.

**Background jobs / cache / cable** all run on Postgres via Solid Queue / Solid Cache / Solid Cable (no Redis) — each has its own schema file in `db/` (`queue_schema.rb`, `cache_schema.rb`, `cable_schema.rb`) and its own migration path in production (`config/database.yml`). Recurring jobs are declared in `config/recurring.yml`, not cron.

**Deployment** is via Render, using the `Dockerfile` for the web service (`render.yaml` is a
Render Blueprint). `RAILS_MASTER_KEY` is set as a Render secret env var (`sync: false` in
`render.yaml`), not committed. Migrations run via `bin/docker-entrypoint`'s `db:prepare` call,
which fires on every container boot (Rails 8's default `Dockerfile`/`CMD` behavior) — there's no
`preDeployCommand` in `render.yaml` because Render's free plan doesn't support it. Kamal is not
used, despite being Rails 8's default scaffold — it was removed in favor of Render's managed PaaS
(git push → auto-deploy, no server ops).

`bin/docker-entrypoint` also runs `db:prepare_solid_schemas` (`lib/tasks/solid_schema.rake`) right
after `db:prepare`. This exists because `config/database.yml`'s `primary`/`cache`/`queue`/`cable`
roles all point at the same `DATABASE_URL` (one free-tier Postgres, no separate physical
databases). `db:prepare` alone doesn't handle that: by the time it gets to the `cache`/`queue`/
`cable` roles the database already exists (`primary` created it), so Rails takes the "run pending
migrations" path instead of "create + load schema" — and since `db/queue_migrate`, `db/cache_migrate`,
and `db/cable_migrate` don't exist (only the `db/*_schema.rb` snapshots do), it finds nothing
pending and silently never loads those schemas. Without the fix, Solid Queue's in-Puma supervisor
crashes on boot (`solid_queue_recurring_tasks does not exist`) and takes Puma down with it —
deploy shows `update_failed` even though the app briefly serves a request first. The task checks
each role's marker table (`solid_queue_jobs`, `solid_cache_entries`, `solid_cable_messages`) and
loads that role's schema only if missing, so it's a no-op on every normal boot but self-heals the
next time the Postgres instance gets recreated (see free-tier expiry note above).

Currently running on Render's **free** plan (web + Postgres) while there's no product to serve
yet — free Postgres expires 30 days after creation, and there's no separate worker service since
background workers aren't free-plan eligible; Solid Queue runs in-process in the web dyno instead
(`SOLID_QUEUE_IN_PUMA=true`). Before real users/data: move to paid plans, consider switching
migrations to an explicit `preDeployCommand` (now supported off the free plan), and split Solid
Queue back into its own `type: worker` service in `render.yaml`.

## Conventions

- **Money** is stored as integer cents via `money-rails` (initializer at
  `config/initializers/money.rb`) — never floats. Format for display only in views.
- **Business logic** belongs in `app/services/`, one public `#call` method per service — not in
  fat models or controllers.
- **Scoping:** every controller action authorizes `current_user` (via the `Authentication`
  concern) and scopes queries to them. The one exception is the `Admin::` controller namespace
  (currently just feature flags — see below), gated by the boolean `User#admin` column via the
  `AdminAuthorization` concern; there's still no other cross-user access path.
- **No React/Vue or JS build framework** — Hotwire (Turbo + Stimulus) only, via importmaps.
- **No Redis** — Solid Queue / Solid Cache / Solid Cable cover jobs, cache, and cable on Postgres.
- **UI kit is DaisyUI + Lucide, installed without npm/Node** (this repo has neither): DaisyUI's
  bundled single-file plugin (`app/assets/tailwind/vendor/daisyui.js` +
  `daisyui-theme.js`, downloaded from DaisyUI's GitHub release assets, not the npm package) is
  loaded via `@plugin` in `app/assets/tailwind/application.css` — the Tailwind v4 standalone CLI
  (`tailwindcss-rails`/`tailwindcss-ruby`) can execute local JS plugin files without Node. To
  upgrade DaisyUI, re-download those two files from a newer
  `github.com/saadeghi/daisyui/releases/<tag>` and re-run `bin/rails tailwindcss:build`. Icons use
  the `rails_icons` gem (pure Ruby, `icon("name")` helper) with the Lucide set vendored as SVGs
  under `app/assets/svg/icons/lucide` — `bin/rails generate rails_icons:sync --library=lucide`
  re-syncs them; browse available names at lucide.dev.
- `strong_migrations` guards against unsafe migrations; `chartkick` + `groupdate` are available
  for future charting needs. `letter_opener` previews mail in the browser in development
  (`config/environments/development.rb`) instead of attempting delivery.
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
