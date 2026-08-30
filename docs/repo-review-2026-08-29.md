# Repo review — gabe-kent/moneymap, 2026-08-29

A read of Moneymap's actual code against the stack decisions from
`docs/framework-comparison.md` and `docs/design-system-options.md`, plus what's still
open from the project's own build plan (`docs/financial-literacy-platform-plan.md`) —
with everything found sorted by how soon it matters.

Based on the `main` branch as of this review — re-check anything time-sensitive (the
Postgres expiry in particular) against the live Render dashboard, since the repo's own
docs can lag reality.

## Snapshot

| Layer | What's actually running |
|---|---|
| Framework | Rails 8.1, Ruby 3.4.10, Puma + Thruster |
| Database | PostgreSQL 16, ActiveRecord |
| Background jobs / cache / cable | Solid Queue / Solid Cache / Solid Cable — no Redis; jobs run in-Puma on the free plan |
| Frontend | Hotwire (Turbo + Stimulus) via importmaps — no npm/Node, no JS bundler |
| UI kit | DaisyUI + Lucide icons, vendored without npm |
| Deployment | Render (Docker), git push → auto-deploy; migrated off Kamal |
| CI | GitHub Actions — Brakeman, bundler-audit, importmap audit, RuboCop, tests + system tests against a live Postgres container |

## What's working well

- The stack matches the project's own build plan almost exactly — Rails 8.1, Postgres,
  a Hotwire-only frontend, Solid Queue/Cache/Cable instead of Redis, DaisyUI, and
  Render with git-push auto-deploy are all called for in
  `docs/financial-literacy-platform-plan.md` and all actually in place.
- The domain models are genuinely careful, not scaffold defaults: `Transaction`
  enforces its own sign convention in a `before_validation` (income stored positive,
  expense negative), and validates that its account and category both belong to the
  same user and that the category's kind matches the transaction type.
- CI is more thorough than the plan even asked for at this stage — security scanning
  (Brakeman, bundler-audit, importmap audit), style (RuboCop), and both unit and
  system tests running against a real Postgres service container on every push and
  pull request.
- Two deliberate, sensible departures from the original plan: skipping the paid
  Bullet Train/Jumpstart Pro starter kit for Rails 8's own lighter auth generator, and
  skipping a premium UI kit for free DaisyUI — both match the plan's own "no paid kit
  needed to look modern" call.

## Findings

Sorted by how soon each one matters, not by how big a change it is.

### Do now

- **Infra — free-tier Postgres has likely already expired.** `CLAUDE.md` notes it was
  created 2026-07-20 and expires ~2026-08-19 — nine days before this review. Render
  auto-suspends it on expiry; `db:prepare_solid_schemas` self-heals the queue/cache/
  cable schemas once a database exists again, but recreating or upgrading the
  instance itself is a manual step in the dashboard.

### Before real users

- **Mailer — password-reset links would point to `example.com` in production.**
  ~~`config/environments/production.rb` still has the default
  `config.action_mailer.default_url_options = { host: "example.com" }`~~ — fixed in
  commit `d312844` (2026-08-30), which points it at the live Render host. SMTP
  delivery is still commented out, so there's no way to actually send the email yet —
  this needs a real provider (Resend or Postmark, per Phase 5).
- **Security — `force_ssl` and rate limiting.** ~~`config.force_ssl = true` is
  commented out in production, and `rack-attack` isn't in the Gemfile~~ — both landed
  in commit `d312844` (2026-08-30): `force_ssl` is on, and `rack-attack` throttles the
  login and password-reset endpoints.
- **Ops — background jobs run inside the web process, not a separate worker.**
  `SOLID_QUEUE_IN_PUMA=true` in `render.yaml` — a reasonable, self-documented
  compromise while background workers aren't available on Render's free plan, but the
  project's own plan flags splitting this into a dedicated worker once there's real
  job volume or you're off free.
- **Visibility — no error monitoring yet.** Sentry (or similar) is a Phase 5 item in
  the plan and isn't wired in — right now a production error is only visible in
  Render's own logs.
- **Legal — no Privacy Policy or Terms of Service pages.** A Phase 6 item that matters
  more than usual here given the app handles financial data, even manual-entry-only
  before Plaid.
- **UI — auth views.** ~~`sessions/new.html.erb` still uses the raw Tailwind classes
  from the Rails auth generator~~ — reskinned onto DaisyUI (`card`/`input-bordered`/
  `btn`) in commit `d312844` (2026-08-30).
- **UI — no dashboard.** The home page is a static welcome card; `chartkick` and
  `groupdate` are already in the Gemfile for exactly this and currently unused
  anywhere.

### Nice to have

- **Performance — `Account#current_balance` runs a separate query per row.** It sums
  `transactions.amount_cents` live, so an accounts index with several accounts issues
  one extra query per row — fine at today's data volume, worth a counter-cache or the
  `bullet` gem once real usage grows.
- **Security — no field-level encryption yet** (Rails `encrypts`) on sensitive
  columns — a Phase 6 item that matters more once Plaid brings in bank-linked data,
  less urgent while entry is manual-only.
- **UI — navigation, icons, and empty states are still minimal** — plain-text nav
  links with no active state or mobile collapse, table actions as text instead of
  icon buttons despite Lucide already being vendored, and no color-coding on balances
  or categories.
- **Docs — the `Dockerfile`'s header comment still mentions Kamal** as a deploy
  option, even though `CLAUDE.md` confirms it was dropped for Render. Harmless, just
  a stale comment worth a one-line fix.

## Suggested sequence

1. **Confirm the database.** Check Render's dashboard for the Postgres instance's
   status and recreate or upgrade it if it's suspended — everything else depends on
   this.
2. ~~Fix the mailer host and turn on `force_ssl`/`rack-attack`.~~ Done in commit
   `d312844` (2026-08-30). Still need to wire up real mail delivery (Resend or
   Postmark).
3. ~~Reskin the auth views onto DaisyUI.~~ Done in commit `d312844` (2026-08-30).
4. **Build the home dashboard.** Use `chartkick` to show total balance, recent
   transactions, and spending by category.
5. **Add Sentry, then legal pages.** Do this before inviting anyone beyond yourself
   to use it with real data.
