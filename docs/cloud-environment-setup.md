# Claude Code cloud environment setup

Configures a Claude Code cloud environment (web sessions, `claude --cloud`, and
Routines all share this) with the exact Ruby/Postgres versions Moneymap needs.
Cloud sessions do **not** read `.devcontainer/devcontainer.json` — this is a known
gap ([anthropics/claude-code#47856](https://github.com/anthropics/claude-code/issues/47856))
— so this has to be configured directly in the cloud environment's settings at
[code.claude.com](https://code.claude.com) instead.

## Setup script

Paste this into the cloud environment's **setup script** field. It runs as root on
a fresh Ubuntu 24.04 VM at the start of every session and must finish within 5
minutes.

```bash
#!/bin/bash
set -e

# Ruby: the VM ships 3.1/3.2/3.3 by default; Moneymap needs 3.4.10 (.ruby-version).
rbenv install -s 3.4.10
rbenv global 3.4.10
gem install bundler

# Postgres, configured to match this repo's existing CI (.github/workflows/ci.yml)
# rather than the default socket-auth database.yml expects — same DATABASE_URL
# override pattern already proven there.
sudo service postgresql start
sudo -u postgres psql -c "ALTER USER postgres PASSWORD 'postgres';" || true

bundle install
```

## Environment variables

| Name | Value | Why |
|---|---|---|
| `DATABASE_URL` | `postgres://postgres:postgres@localhost:5432` | No trailing database name — Rails appends `moneymap_development` or `moneymap_test` itself based on `RAILS_ENV`, exactly like the CI job already does. Setting a full URL with a fixed database name here would make `bin/rails test` silently run against the dev database instead of the test one. |

`RAILS_MASTER_KEY` isn't needed for this — nothing in `bin/rails test` or normal
development touches encrypted credentials yet. Add it later only if that changes.

## After the setup script runs

The repo is cloned fresh each session, so `db:prepare`/`db:test:prepare` still need
to run per-session rather than baked into the setup script (a stale schema baked in
would drift from migrations over time):

```bash
bin/rails db:prepare
bin/rails db:test:prepare
```

## Verifying it worked

```bash
ruby -v        # should print 3.4.10
bin/rails test # should run against a real Postgres, not fail on missing gems
```

If `bundle install` is close to timing out on a cold cache, that's a real risk of
the 5-minute setup-script limit — worth checking the environment's build logs the
first time and trimming the script (e.g. skip `bundler` reinstall if already
present) if it's cutting it close.
