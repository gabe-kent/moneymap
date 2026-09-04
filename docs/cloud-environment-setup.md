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
RUBY_VERSION=3.4.10
if ! rbenv versions --bare | grep -qx "$RUBY_VERSION"; then
  # The image's bundled ruby-build definitions can lag behind actual Ruby
  # releases and not know about a brand-new patch version yet ("ruby-build:
  # definition not found") -- pull the latest definitions first rather than
  # assuming the image is current.
  for d in /opt/rbenv/plugins/ruby-build "$(rbenv root)/plugins/ruby-build"; do
    [ -d "$d" ] && git -C "$d" pull -q
  done
  # Preferred: build from source via ruby-build. Falls back to a prebuilt
  # binary from ruby/ruby-builder (the same GitHub-hosted releases the
  # `ruby/setup-ruby` GitHub Action uses) if that fails -- both
  # cache.ruby-lang.org and ftp.ruby-lang.org have returned a bare 403 to this
  # cloud sandbox's shared egress IP range, which is a domain-level block, not
  # a single CDN's bot protection, so switching ruby-lang.org subdomains
  # doesn't help. GitHub is already reachable (this repo was just cloned from
  # there), so its release CDN is a genuinely different network path.
  if ! rbenv install -s "$RUBY_VERSION"; then
    echo "ruby-build failed (ruby-lang.org appears blocked from this sandbox) -- falling back to a prebuilt binary from GitHub" >&2
    version_dir="$(rbenv root)/versions/$RUBY_VERSION"
    mkdir -p "$version_dir"
    curl -fsSL "https://github.com/ruby/ruby-builder/releases/download/ruby-${RUBY_VERSION}/ruby-${RUBY_VERSION}-ubuntu-24.04-x64.tar.gz" \
      | tar -xz --strip-components=1 -C "$version_dir"
  fi
fi
rbenv global "$RUBY_VERSION"
rbenv rehash
gem install bundler

# Postgres, configured to match this repo's existing CI (.github/workflows/ci.yml)
# rather than the default socket-auth database.yml expects — same DATABASE_URL
# override pattern already proven there.
sudo service postgresql start
sudo -u postgres psql -c "ALTER USER postgres PASSWORD 'postgres';" || true

bundle install

# rtk (Rust Token Killer) — a Claude Code PreToolUse hook that transparently
# compresses Bash tool output before it reaches the model (60-90% token savings
# on common dev commands). Already configured on the local machine this repo was
# built on; added here so cloud sessions get the same savings instead of running
# uncompressed. `rtk init -g` installs its hook into `~/.claude/settings.json` for
# whichever user runs it — since this script runs as root, verify after the fact
# (see below) that the cloud session's Claude Code process is reading that same
# settings file; if the session runs as a different user, this step needs to run
# as that user instead.
curl -fsSL https://raw.githubusercontent.com/rtk-ai/rtk/refs/heads/master/install.sh | sh
rtk init -g
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
rtk gain       # should report command history, not "no commands recorded" —
               # if it's empty, the hook isn't reaching this session's actual
               # Claude Code process (see the rtk note in the setup script above)
```

If `bundle install` is close to timing out on a cold cache, that's a real risk of
the 5-minute setup-script limit — worth checking the environment's build logs the
first time and trimming the script (e.g. skip `bundler` reinstall if already
present) if it's cutting it close.
