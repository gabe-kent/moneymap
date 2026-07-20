# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project state

Moneymap is a Rails 8.1 application currently at the bootstrap stage: `rails new` plus the
built-in authentication generator (`bin/rails generate authentication`). Beyond
sign-up/sign-in/password-reset, there is no product-specific domain logic, so don't assume
budgeting/finance features exist yet — check `app/models` and `config/routes.rb` before
referencing "existing" functionality.

`docs/financial-literacy-platform-plan.md` and `docs/environment-setup-runbook.md` capture the
longer-range plan (target data model, phased build-out, hosting/cost decisions) and the
Windows/WSL2 setup history. They describe an aspirational end state and a past setup session,
not the current repo — treat them as background context, not as a source of truth for what
exists today. The **Conventions** below are the subset of that plan already adopted for this repo.

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

**Deployment** is via Kamal (`config/deploy.yml`, `.kamal/`) into Docker (`Dockerfile`), fronted by Thruster.

## Conventions

- **Money** is stored as integer cents via `money-rails` (initializer at
  `config/initializers/money.rb`) — never floats. Format for display only in views.
- **Business logic** belongs in `app/services/`, one public `#call` method per service — not in
  fat models or controllers.
- **Scoping:** every controller action authorizes `current_user` (via the `Authentication`
  concern) and scopes queries to them; there is no admin/cross-user access path yet.
- **No React/Vue or JS build framework** — Hotwire (Turbo + Stimulus) only, via importmaps.
- **No Redis** — Solid Queue / Solid Cache / Solid Cable cover jobs, cache, and cable on Postgres.
- `strong_migrations` guards against unsafe migrations; `chartkick` + `groupdate` are available
  for future charting needs. `letter_opener` previews mail in the browser in development
  (`config/environments/development.rb`) instead of attempting delivery.
