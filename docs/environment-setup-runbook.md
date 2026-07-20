# Environment Setup Runbook — Windows + WSL2 + Rails

The real, working, battle-tested setup sequence — with the specific issues we hit and
the fixes that worked. Treat it as a living document; update it whenever something bites you.

**Companion to:** the main *Build & Launch Plan* (Phases 0–1 are covered here).

**Conventions:**
- Commands run inside the **Ubuntu (WSL2)** shell unless a step says *(PowerShell)*.
- ⚠️ marks a real issue we hit. ✅ marks the fix that worked.
- Keep all project files in the **Linux filesystem** (`~/code/...`), never `/mnt/c/...`
  (slow I/O, git "unsafe repository" warnings).

---

## Two shells — know which one you're in

This distinction caused real confusion and is worth locking in up front:

| Shell | Prompt looks like | Used for |
|---|---|---|
| **PowerShell (Windows)** | `PS C:\Users\...>` | `wsl`, `dism.exe`, `winver`, WSL management |
| **Ubuntu (WSL)** | `gkent@DESKTOP-...:~$` | `git`, `ruby`, `rails`, `bundle`, `npm`, `sudo apt` |

**Rule:** if a command isn't found in Ubuntu, it's probably a Windows command — open
PowerShell. If something needs elevation, right-click PowerShell → **Run as administrator**.
Never run `sudo apt install wsl` — that's a different, unrelated package.

---

## Phase 0 — Environment setup

### Step 0 — WSL2 + Ubuntu  *(elevated PowerShell)*

```
wsl --install
```

- ⚠️ **Issue:** bare `wsl --install` printed help text instead of installing.
- ✅ **Fix:** run PowerShell **as Administrator**; use `wsl --install -d Ubuntu` explicitly;
  confirm Windows build is **19041+** (check with `winver`).
- **Verify:** `wsl -l -v` shows Ubuntu at **VERSION 2**. If it shows VERSION 1, see
  *"Upgrading WSL 1 → WSL 2"* below.
- First Ubuntu launch prompts for a Linux username + password.
- **Optional shortcut:** pin Ubuntu to the taskbar, and/or set Windows Terminal's
  default profile to Ubuntu (Settings → Startup).

### ⚠️ Upgrading WSL 1 → WSL 2  *(elevated PowerShell — if needed)*

Claude Code and some other tools **require WSL 2**. If `wsl -l -v` shows VERSION 1,
work through the following in order. All commands run in **elevated PowerShell**
(Windows key → PowerShell → right-click → Run as administrator).

- ⚠️ **Issue:** running `dism.exe` or `wsl --set-version` inside Ubuntu fails with
  "command not found" — these are Windows commands, not Linux ones. Never run
  `sudo apt install wsl` — that's a different, unrelated package.

**Step A — Enable Virtual Machine Platform and reboot:**
```
dism.exe /online /enable-feature /featurename:VirtualMachinePlatform /all /norestart
dism.exe /online /enable-feature /featurename:Microsoft-Windows-Subsystem-Linux /all /norestart
```
**Reboot Windows** — required for the kernel-level change to take effect.

**Step B — After rebooting, update WSL and attempt conversion:**
```
wsl --update
wsl --set-version Ubuntu 2
wsl --set-default-version 2
wsl -l -v
```

**If conversion fails with `HCS_E_SERVICE_NOT_AVAILABLE`**, virtualisation is
disabled in firmware. Diagnose with:
```
Get-WmiObject -Class Win32_Processor | Select-Object Name, VirtualizationFirmwareEnabled
```

- ⚠️ **Issue we hit:** `VirtualizationFirmwareEnabled: False` on an
  **MSI B450/X570 board (MS-7C37) with AMD Ryzen** — AMD-V (SVM Mode) was off
  in BIOS. Nothing in Windows can override this.
- ✅ **Fix — enable SVM Mode in BIOS:**
  1. Restart and press **Delete** to enter MSI BIOS
  2. Press **F7** for Advanced Mode
  3. Go to **OC → CPU Features → SVM Mode** (or **Settings → Advanced →
     CPU Configuration → SVM Mode**)
  4. Change from **Disabled** to **Enabled**
  5. Press **F10** to save and exit
  6. Back in Windows, verify: `Get-WmiObject -Class Win32_Processor | Select-Object VirtualizationFirmwareEnabled` should show `True`
  7. Then retry: `wsl --set-version Ubuntu 2`

- For **Intel machines** the equivalent setting is **Intel VT-x** or
  **Intel Virtualization Technology** in BIOS.
- For other motherboard brands the BIOS key is usually F2 or F10 (not Delete).

**Step C — If you have multiple Ubuntu distros**, convert each:
```
wsl --set-version Ubuntu 2
wsl --set-version Ubuntu-18.04 2
wsl --set-default Ubuntu          # make plain Ubuntu (24.04) the default
```

Note: Ubuntu-18.04 reached end-of-life in 2023 — do all work in plain **Ubuntu**.
Your project lives there.

**Verify and reopen:**
```
wsl -l -v       # both distros should show VERSION 2
```

After converting, reopen Ubuntu and start Postgres (`sudo service postgresql start`)
— the conversion restarts the distro.

---

### Step 1 — Git identity + SSH key  *(Ubuntu)*

```
git config --global user.name "Gabe Kent"
git config --global user.email "your-github-email@example.com"
git config --global --list      # verify
```

- `user.name` is the commit label (use your real name) — **not** your GitHub username.
- GitHub links commits by **email**, so match your GitHub account email (or use
  `…@users.noreply.github.com` for privacy).

**SSH key:**

```
ssh-keygen -t ed25519 -C "your@email.com"
cat ~/.ssh/id_ed25519.pub       # copy this into GitHub
ssh -T git@github.com           # expect: "Hi gabe-kent! You've successfully authenticated…"
```

- `-C` is just a label, not a seed — the key is OS-random. Accept the default path;
  set a passphrase.
- Add the `.pub` key to GitHub → Settings → SSH and GPG keys.
- ⚠️ **`gh` CLI not found:** `apt install gh` fails — it's not in Ubuntu's default repos.
  You don't need it if you're using the SSH key above.
- **Save your passphrase each session** (so you aren't prompted on every push):

```
eval "$(ssh-agent -s)"
ssh-add ~/.ssh/id_ed25519
```

**First push gotcha:**
- ⚠️ `ERROR: Repository not found` — the repo must exist on github.com first (create it
  empty: no README/gitignore/license), and the remote URL must match exactly. Check with
  `git remote -v`; fix with `git remote set-url origin git@github.com:gabe-kent/moneymap.git`.

---

### Step 2 — Build tools  *(Ubuntu — BEFORE Ruby)*

```
sudo apt update
sudo apt install -y build-essential libssl-dev libyaml-dev libreadline-dev \
  zlib1g-dev libffi-dev libgmp-dev libpq-dev
```

- ⚠️ **This must happen before Ruby and before any `bundle install`.** Precompiled Ruby
  does **not** bring a C compiler or `make`. Native-extension gems (bigdecimal, erb,
  io-console, date, websocket-driver, bcrypt_pbkdf, …) all fail without it.
- ✅ **Verify before continuing:**

```
which make gcc          # both must print a path (e.g. /usr/bin/make)
make --version
```

- **Error this prevents:** `The compiler failed to generate an executable file` /
  `You have to install development tools first` / `make failed: No such file or directory`
  during `bundle install`. If you see those → install `build-essential`, confirm
  `make --version`, re-run `bundle install`.
- **If apt fails:** check WSL networking with `ping -c2 archive.ubuntu.com`; if that
  fails, run `wsl --shutdown` in PowerShell, reopen Ubuntu, retry.

---

### Step 3 — mise (version manager)  *(Ubuntu)*

```
curl https://mise.run | sh
echo 'eval "$(~/.local/bin/mise activate bash)"' >> ~/.bashrc
source ~/.bashrc
mise --version
```

---

### Step 4 — Ruby  *(Ubuntu — the key gotcha)*

- ⚠️ **Issue:** `mise use -g ruby@3.4` failed with `BUILD FAILED` compiling
  OpenSSL/Ruby from source on Ubuntu 24.04.
- ✅ **Fix — use precompiled binaries:**

```
mise settings ruby.compile=false
mise use -g ruby@3.4
ruby -v          # -> ruby 3.4.10
```

- Precompiled becomes mise's default in 2026.8.0 anyway.
- Precompiled skips compilation — which is exactly why **section 2 (build tools) must
  come first**, or native gem builds fail later.

---

### Step 5 — Node + Rails  *(Ubuntu)*

```
mise use -g node@lts
gem install rails -v 8.1.3
rails -v         # -> Rails 8.1.3
```

- Rails **8.1.3** is current stable (Mar 2026).
- Stay on Ruby **3.4** — Ruby 4.0 exists but its ZJIT compiler is experimental;
  3.4 has the best gem compatibility.

---

### Step 6 — PostgreSQL  *(Ubuntu)*

```
sudo apt install -y postgresql postgresql-contrib libpq-dev
sudo service postgresql start
sudo -u postgres createuser -s $(whoami)
```

- ⚠️ **WSL does not auto-start Postgres.** Run `sudo service postgresql start` at the
  start of every session. Or enable systemd to auto-start it:

```
sudo nano /etc/wsl.conf
```

Add:
```
[boot]
systemd=true
```

Then from PowerShell: `wsl --shutdown`, reopen Ubuntu, then:
`sudo systemctl enable --now postgresql`

- ⚠️ **`createuser` must run after Postgres is started.** The `createuser -s $(whoami)`
  creates a Postgres role matching your Linux username so Rails connects without a
  password. **This is a one-time step** — only needed on first setup.
- ⚠️ **Issue we hit:** `FATAL: role "gkent" does not exist` when starting the app —
  because `createuser` hadn't been run yet. Fix: `sudo -u postgres createuser -s gkent`
  (use your actual Linux username).

---

### Step 7 — Verify the whole stack  *(Ubuntu)*

Sanity-check the toolchain first:

```
which make gcc          # both must print a path
```

Then:

```
mkdir -p ~/code && cd ~/code
rails new testapp -d postgresql
cd testapp
bundle install
bin/rails db:create
bin/rails db:migrate
bin/dev                 # open http://localhost:3000 (use bin/dev, not bin/rails server)
```

- ✅ Success = Rails welcome page at **http://localhost:3000**.
- ⚠️ `bundle install` fails with native/`make` errors → build tools missing (step 2).
- ⚠️ `db:create` can't connect → Postgres not running: `sudo service postgresql start`.
- ⚠️ `FATAL: role "gkent" does not exist` → `sudo -u postgres createuser -s gkent`.
- Stop with **Ctrl+C**; clean up with `cd ~/code && rm -rf testapp`.

---

### Step 8 — Editors  *(Ubuntu)*

```
code .          # opens VS Code or Cursor connected to WSL; installs WSL server on first run
```

Claude Code: see Phase 1, Step 7 below.

---

### Session-start checklist (every time you sit down)

1. Open Ubuntu (or Windows Terminal → Ubuntu profile)
2. `sudo service postgresql start` (unless systemd is enabled)
3. `cd ~/code/moneymap`
4. `bin/dev` in one terminal
5. `claude` in a second terminal (once Claude Code is installed)

---

## Phase 1 — Scaffolding the real app

### Step 1 — Create the app  *(Ubuntu)*

```
cd ~/code
rails new moneymap -d postgresql --css tailwind
cd moneymap
```

Scaffolds Rails 8.1 with PostgreSQL and Tailwind, runs `bundle install`, and
initialises a git repo. Hotwire, Solid Queue/Cache, and Kamal are included by default.

### Step 2 — Boot it

```
sudo service postgresql start   # if not already running
bin/rails db:create
bin/dev                         # http://localhost:3000
```

- Use `bin/dev` (not `bin/rails server`) — it runs the web server AND the Tailwind
  CSS watcher together.
- ⚠️ `ActiveRecord::ConnectionNotEstablished` → Postgres isn't running:
  `sudo service postgresql start`
- ⚠️ `FATAL: role "gkent" does not exist` → `sudo -u postgres createuser -s gkent`

### Step 3 — Push to GitHub

Create an **empty** repo on github.com (no README/gitignore/license — those conflict).
Then:

```
git add -A
git commit -m "Initial Rails 8 app"
git branch -M main
git remote add origin git@github.com:gabe-kent/moneymap.git
git push -u origin main
```

- ⚠️ `ERROR: Repository not found` → the GitHub repo doesn't exist yet, or the URL
  doesn't match. Create the empty repo on github.com first; check URL with
  `git remote -v`.

### Step 4 — Verify master.key is gitignored

```
grep master.key .gitignore      # should print /config/master.key
```

**Copy `config/master.key` to your password manager now.** It's gitignored and
unrecoverable if lost. You'll paste it into Render as `RAILS_MASTER_KEY` in Phase 2.

### Step 5 — Generate authentication (Rails 8 built-in)

```
bin/rails generate authentication
bundle install
bin/rails db:migrate
```

Generates `User` + `Session` models, sign-in/out, and password reset.
Create a test user to verify:

```
bin/rails console
```
```ruby
User.create!(email_address: "you@example.com", password: "password123")
exit
```

Then `bin/dev` → visit **http://localhost:3000/session/new** → log in.

- ⚠️ **Issue we hit:** after successful login, got `NameError: undefined local variable
  or method 'root_url'` — auth worked fine (session row was created) but the app had
  no root route to redirect to.
- ✅ **Fix — add a home controller and root route:**

```
bin/rails generate controller Home index
```

In `config/routes.rb`, inside `Rails.application.routes.draw do`:

```ruby
root "home#index"
```

- ℹ️ `Unpermitted parameters: :authenticity_token, :commit` in the logs is **normal
  noise** — not an error.
- ℹ️ `No route matches [GET] "/favicon.ico"` is cosmetic — add a favicon later.

### Step 6 — Add core gems

```
bundle add strong_migrations money-rails chartkick groupdate
bundle add letter_opener --group development
```

Add to `config/environments/development.rb` inside the `configure` block:

```ruby
config.action_mailer.delivery_method = :letter_opener
config.action_mailer.perform_deliveries = true
```

This makes password-reset and other emails open in the browser during development
instead of attempting to send.

Commit progress:

```
git add -A && git commit -m "Add authentication, home page, and core gems"
```

### Step 7 — Install Claude Code  *(Ubuntu — requires WSL 2)*

- ⚠️ **Issue we hit:** `npm install -g @anthropic-ai/claude-code` failed with
  `WSL 1 is not supported`. Claude Code requires **WSL 2** — upgrade first
  (see *"Upgrading WSL 1 → WSL 2"* in Phase 0 above).
- ⚠️ **Root cause in our case:** AMD-V (SVM Mode) was disabled in BIOS on the
  MSI board, blocking WSL 2 entirely. Required a BIOS change before WSL 2 would
  work. See the upgrade section for the full fix.

Once on WSL 2:

```
npm install -g @anthropic-ai/claude-code
claude --version
```

If npm throws a permissions error:

```
mkdir -p ~/.npm-global
npm config set prefix ~/.npm-global
echo 'export PATH=~/.npm-global/bin:$PATH' >> ~/.bashrc
source ~/.bashrc
npm install -g @anthropic-ai/claude-code
```

**Launch and authenticate:**

```
cd ~/code/moneymap
claude
```

First run opens a browser to log in — use your Claude subscription (Pro or Max)
to avoid per-token charges.

**Generate a starter CLAUDE.md:**

```
/init
```

Scans the repo and generates a starter `CLAUDE.md`. Refine it with the stack
rules from Appendix B of the Build & Launch Plan (Hotwire only, money in cents,
business logic in `app/services/`, etc.).

**Workflow:** run `bin/dev` in one terminal, `claude` in a second terminal so
Claude Code edits files while you watch them live-reload in the browser.

---

## Phase 2 — Deploy to Render

**Goal:** replace the Rails 8 default Kamal scaffold with a Render Blueprint and get a live URL.

### Step 1 — Drop Kamal, add a Render Blueprint

Rails 8's `rails new` scaffolds Kamal by default (`gem "kamal"`, `config/deploy.yml`, `.kamal/`).
If you're deploying to Render instead (git-push managed PaaS, no server ops), remove it rather
than leaving it dormant — it's dead weight and confusing to future-you:

```
bundle remove kamal
rm -f config/deploy.yml
rm -rf .kamal
```

Add `render.yaml` at the repo root (a **Blueprint** — Render reads this automatically when you
connect the repo via **New → Blueprint**, and provisions everything it describes in one shot).

### Step 2 — Postgres plan name

- ⚠️ **Issue we hit:** Blueprint validation failed with
  `databases[0].plan — Legacy Postgres plans, including 'starter', are no longer supported for
  new databases.`
- ✅ **Fix:** Render repriced/renamed Postgres plans; the old `starter`/`standard`/`pro` names
  are legacy and only valid for *existing* databases. New databases need the current size-based
  names: `free`, `basic-256mb`, `basic-1gb`, `basic-4gb`, `pro-4gb`, … See
  https://render.com/docs/blueprint-spec for the full list.
- **Web/worker services are unaffected** — `starter`/`standard`/`pro` are still valid `plan`
  values for `type: web` / `type: worker` entries. Only the *database* plan naming changed.

### Step 3 — Cost surprise on paid Postgres

- ⚠️ **Issue we hit:** `moneymap-db` on `basic-256mb` showed **$24.50/mo** in the Render
  dashboard, not the ~$7/mo the build plan assumed (that figure was the old legacy `starter`
  price). Current breakdown: **$20/mo compute + $4.50/mo storage** (default 15 GB disk ×
  $0.30/GB/mo, via the `diskSizeGB` field — must be `1` or a multiple of `5`).
- ✅ **If there's no product built yet, use free tier instead** — no need to pay before there's
  anything to serve:
  - `plan: free` on both the database and the web service.
  - **Background workers are not available on the free plan.** Drop the separate
    `type: worker` service and run Solid Queue in-process in the web dyno instead
    (`SOLID_QUEUE_IN_PUMA: "true"` env var — the same trick the default Kamal config used for
    single-server setups).
  - Trade-offs to accept while on free: web service spins down after 15 min idle (~1 min cold
    start on next request); **free Postgres is deleted 30 days after creation** (14-day grace
    period to upgrade before that) — put a reminder somewhere.

### Step 4 — `preDeployCommand` not supported on free plan

- ⚠️ **Issue we hit:** `services[0] — pre-deploy command is not supported for free tier
  services.` (We'd set `preDeployCommand: bin/rails db:migrate` on the web service.)
- ✅ **Fix:** just remove it — it was redundant anyway. Rails 8's default
  `bin/docker-entrypoint` already runs `./bin/rails db:prepare` (create + migrate) on **every**
  container boot, whenever the `CMD` ends in `./bin/rails server`:

  ```sh
  # bin/docker-entrypoint
  if [ "${@: -2:1}" == "./bin/rails" ] && [ "${@: -1:1}" == "server" ]; then
    ./bin/rails db:prepare
  fi
  ```

  The default `Dockerfile` `CMD` is `["./bin/thrust", "./bin/rails", "server"]` — the last two
  args still match, so this fires regardless of Thruster wrapping the command. Migrations run on
  every deploy without needing a paid-only `preDeployCommand`.

### Step 5 — `ActiveRecord::ConnectionNotEstablished` on boot

- ⚠️ **Issue we hit:** deploy succeeded but the app crashed on boot with
  `ActiveRecord::ConnectionNotEstablished: connection to server on socket
  "/var/run/postgresql/.s.PGSQL.5432" failed: No such file or directory` (tried three different
  socket paths, all failed).
- **Root cause:** Rails 8's default `config/database.yml` production block is written for
  Kamal, not Render — it expects a local Unix socket (`database: moneymap_production`,
  `username: moneymap`, `password: ENV["MONEYMAP_DATABASE_PASSWORD"]`), plus **three more
  separate physical databases** for Solid Cache/Queue/Cable
  (`moneymap_production_cache`/`_queue`/`_cable`). Render gives you exactly **one** Postgres
  database, reachable over TCP via a single `DATABASE_URL` env var — nothing in that default
  config ever looks at `DATABASE_URL`, so it fell through to socket defaults that don't exist on
  Render.
- ✅ **Fix — collapse primary/cache/queue/cable onto the same `DATABASE_URL`:**

  ```yaml
  production:
    primary: &primary_production
      <<: *default
      url: <%= ENV["DATABASE_URL"] %>
    cache:
      <<: *primary_production
      migrations_paths: db/cache_migrate
    queue:
      <<: *primary_production
      migrations_paths: db/queue_migrate
    cable:
      <<: *primary_production
      migrations_paths: db/cable_migrate
  ```

  All four connections resolve to the identical physical database, differing only in which
  `migrations_paths` gets applied to it — the Solid Cache/Queue/Cable tables just coexist
  alongside the app's own tables. This is the standard pattern for hosts (Render, Fly free tier,
  etc.) that only provision a single Postgres database; only worth splitting back into separate
  databases at real scale.
- **Sanity-check this locally before pushing**, since you won't have a Render Postgres to test
  against: `RAILS_ENV=production DATABASE_URL=postgres://user@localhost/somedb?host=/var/run/postgresql
  bin/rails runner 'ActiveRecord::Base.configurations.configs_for(env_name: "production").each { |c| puts [c.name, c.database].inspect }'`
  should print all four config names resolving to the same database — confirms the YAML/ERB is
  wired correctly without needing a live remote database.

### `render.yaml` reference (free-tier, current state)

```yaml
databases:
  - name: moneymap-db
    plan: free
    postgresMajorVersion: "16"

services:
  - type: web
    name: moneymap
    runtime: docker
    dockerfilePath: ./Dockerfile
    plan: free
    healthCheckPath: /up
    envVars:
      - key: RAILS_ENV
        value: production
      - key: RAILS_MASTER_KEY
        sync: false
      - key: DATABASE_URL
        fromDatabase:
          name: moneymap-db
          property: connectionString
      - key: SOLID_QUEUE_IN_PUMA
        value: "true"
```

`RAILS_MASTER_KEY` (`sync: false`) still has to be pasted into the Render dashboard manually —
Blueprints don't let you commit secret values, by design.

---

## Next: Phase 2 continued *(to be filled in)*

- Confirm live Render URL boots cleanly end-to-end (first real deploy)
- CLAUDE.md finalised
- DaisyUI UI kit + Lucide icons
- money-rails initialiser + conventions
- Seed data (`db/seeds.rb`)
- Before real users/data: move off free plan, split Solid Queue back into its own
  `type: worker` service, reconsider `preDeployCommand` for migrations

*Record any new issues + fixes here the same way.*
