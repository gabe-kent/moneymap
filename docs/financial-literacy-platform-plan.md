# Financial Literacy Platform — Build & Launch Plan

An explicit, step-by-step plan for building a custom budgeting / financial-literacy
platform as a solo software engineer, using AI tooling, on a Windows machine.
Every phase is meant to be executable, not theoretical.

Scope note: this plan assumes **financial education and budgeting** (not personalized
securities/investment advice), which keeps you out of investment-adviser registration
territory. Transactions start as **manual entry**, with **Plaid bank aggregation added later**
(Phase 8). If the product ever shifts toward recommending specific investments, revisit the
compliance question with a securities attorney first.

---

## Executive summary

**What this is:** a plan to build a custom budgeting + financial-literacy platform (manual transaction
entry first, bank sync later), buildable two ways — as a **developer** on Ruby on Rails, or as a
**non-developer** using an AI app builder (Lovable).

**Realistic effort:**
- *Developer path (Rails):* a basic working app in days to ~2 weeks; a polished, user-ready product in roughly **2–4 months** of solo part-time work, with AI doing most of the coding.
- *Non-developer path (Lovable):* a working prototype in hours to days; a polished product in **weeks to a couple of months** — the time goes into learning to direct the AI, iterating, and handling security/legal rather than writing code.

**Realistic costs:**
- *Running the live app:* **~$40–65/mo** (Rails) or **~$50–75/mo** (Lovable + Supabase), before payment fees.
- *AI coding spend for the whole build (dev path):* **~$500–1,200** typical, spread across the project (mostly a subscription plus occasional overflow).
- *Optional one-time:* starter kit ~$249 or a premium UI kit — both skippable ($0 with free options).
- *Later:* Plaid (usage-based) and a lawyer review of the legal pages, given the financial-data angle.

**Dev vs non-dev tradeoff:**

| | Developer (Rails) | Non-developer (Lovable) |
|---|---|---|
| Starting floor | Higher — setup + coding skill | Much lower — describe in plain English |
| Time to first app | Days–weeks | Hours–days |
| Control & customization | Full | Good, with a ceiling on very custom logic |
| Running cost | Lower, predictable | Slightly higher, less predictable (credits) |
| Cost at scale | Cheaper | Grows with usage |
| Lock-in | None | Low — real code, exports to GitHub |
| Best when | You'll code and want control/scale | You want speed and the lowest skill floor |

**Key point:** the paths aren't mutually exclusive. Lovable outputs real code to GitHub, so you can
start non-dev and graduate to the developer path (or hand off to a developer) without a rewrite.

## Which path should you follow?

- **Comfortable coding (Ruby/JS)** → Developer path — the main plan, Phases 0–8.
- **Not a developer but willing to learn** → Non-developer path — Appendix C (Lovable + Supabase).
- **Want maximum control, lowest long-term cost, or plan to scale large** → Developer path.
- **Want the fastest time-to-live and least setup** → Non-developer path.
- **Want to start easy but keep options open** → Non-developer path (migrate later, no rewrite).

---

## Decisions locked in

| Area | Choice | Why |
|---|---|---|
| Language / framework | **Ruby on Rails 8.1** | Matches your Ruby comfort; convention-over-configuration is ideal for AI-assisted coding |
| Frontend | **Hotwire + Tailwind v4 + DaisyUI (or RailsUI) + Chartkick** | Modern, professional UI with minimal JS; one language, one deploy |
| Database | **PostgreSQL** | Standard, well-documented, supported everywhere |
| Transaction data | **Manual entry first; Plaid later (Phase 8)** | Lean + private to start; automated import once there's traction |
| Money storage | **Integer cents via `money-rails`** | Never use floats for money |
| Dev OS setup | **WSL2 (Ubuntu) on Windows** | Recommended path for Rails on Windows; dev matches production |
| Version manager | **mise** | One tool for Ruby + Node |
| Starter kit | **Bullet Train** (free) or **Jumpstart Pro** ($249/yr) | Skips auth/billing/admin boilerplate |
| Hosting | **Render** (managed PaaS) | Lowest maintenance that still scales |
| Background jobs | **Solid Queue** (built into Rails 8) | No Redis needed; runs as a Render worker |
| Deploy model | **Git push → auto-deploy**, zero-downtime | Ships continuously |
| AI tooling | **Claude Code** + **Cursor** (or VS Code / RubyMine) | Pair with a repo `CLAUDE.md` (Appendix B) |

---

## Legend

- 🆓 **Free, no account** — just install and use
- 👤 **Account required** — sign-up needed, free to start
- 💳 **Credit card** — required at some point (to start, or to pass the free tier)

---

## Frontend / UI stack

**Hotwire (Turbo + Stimulus) + Tailwind CSS v4 + a component kit + Chartkick.** Low maintenance
(no separate JS build pipeline), still modern and professional. HEY and Basecamp are built this way.

### Foundation (mostly included by Rails 8 / your starter kit)
- **Tailwind CSS v4** — styling foundation. 🆓 https://tailwindcss.com
- **Lucide** — icon set. 🆓 https://lucide.dev

### Pick ONE component kit as your base

| Kit | Cost | Notes | Link |
|---|---|---|---|
| **DaisyUI** | 🆓 Free (MIT) | Semantic Tailwind classes, themes, no JS framework. Max control. | https://daisyui.com |
| **RailsUI** | Free tier + paid license | Plug-and-play gem; 200+ components, full pages, themes. Fastest to polished. | https://railsui.com |
| **Flowbite** | 🆓 Free core; paid Pro | Officially supports Rails. | https://flowbite.com |
| **Tailwind Plus** | 💳 ~$299 one-time | Official premium components/templates. | https://tailwindcss.com/plus |
| **Rails Designer** | 💳 ~$49–$99 one-time | ViewComponent + Tailwind + Hotwire, from production SaaS. | https://railsdesigner.com |

> **Recommendation:** DaisyUI (free, full control) or RailsUI (fastest). No paid kit needed to look modern.

### Charts (budgeting side)
- **Chartkick** (+ **Groupdate**) — interactive charts from Rails in ~one line. 🆓 https://chartkick.com

### What makes it feel modern
Turbo Drive (SPA-speed navigation), Turbo Frames (partial updates), Turbo Streams (live updates
over WebSockets — e.g. a budget total updating instantly), Stimulus (small interactive touches).

---

## Phase 0 — Development environment (Windows)

**Goal:** a working Rails + Postgres environment inside WSL2, confirmed by booting a test app.

1. **Install WSL2 + Ubuntu** — admin PowerShell: `wsl --install`, reboot, set a Linux username/password.
   - 🆓 https://learn.microsoft.com/windows/wsl/install
2. **⚠️ Critical:** keep projects *inside* the Linux filesystem (`~/code/myapp`), **never** on `/mnt/c/...` (slow I/O + git warnings).
3. **Install `git` + configure it:** `sudo apt install git`, then `git config --global user.name/user.email`. Create an **SSH key** (`ssh-keygen -t ed25519`) and add it to GitHub, or install the **GitHub CLI** (`gh auth login`).
4. **Install `mise`**, then Ruby 3.4.x and Node. 🆓 https://mise.jdx.dev
5. **Install Rails** (`gem install rails`, Rails 8.1) and **PostgreSQL** (`sudo apt install postgresql postgresql-contrib libpq-dev`). Connect over sockets.
   - 🆓 https://rubyonrails.org · https://guides.rubyonrails.org · https://www.postgresql.org
6. **Confirm:** `rails new testapp && cd testapp && bin/rails server`, open `http://localhost:3000`. Don't proceed until it loads.

### Editors (connect to WSL)
- **VS Code** — 🆓 https://code.visualstudio.com — WSL extension, "Connect to WSL".
- **Cursor** — 👤💳 https://cursor.com — VS Code fork, same WSL flow. Free tier; Pro ~$20/mo.
- **Claude Code** — 👤💳 https://www.anthropic.com/claude-code — run in the WSL terminal at project root.
- **RubyMine** — 👤💳 https://www.jetbrains.com/ruby/ — WSL interpreter. Paid; 30-day trial.

> Alternative to steps 4–5: Rails 8's pre-configured `.devcontainer` spins up Ruby + Postgres in Docker automatically.

---

## Phase 1 — Scaffold the real project

**Goal:** a real repo on a starter kit, with the AI foundation and core gems in place.

1. **Clone your starter kit:**
   - **Bullet Train** — 🆓👤 (MIT; needs GitHub) — https://bullettrain.co
   - **Jumpstart Pro** — 👤💳 ($249/yr; Rails 8.1, Devise, Administrate) — https://jumpstartrails.com
   - Or `rails new` from scratch.
2. **Create the GitHub repo** and push. 👤 https://github.com
3. **Confirm `.gitignore` excludes secrets** — `config/master.key`, `.env`, `/config/credentials/*.key` must never be committed.
4. **Set up secrets management now:** use **Rails credentials** (`bin/rails credentials:edit`, which creates `config/master.key`) for API keys. Keep `master.key` out of git; you'll paste it into Render in Phase 2.
5. **Write your `CLAUDE.md`** at the repo root — start from **Appendix B**. Keep it under ~150 lines.
6. **(Optional) Install ClaudeOnRails** for Rails-aware agents + docs MCP. 🆓 https://github.com/obie/claude-on-rails
7. **Add core gems:**
   - `strong_migrations` — catches unsafe DB changes. 🆓 https://github.com/ankane/strong_migrations
   - `money-rails` — store money as integer cents. 🆓 https://github.com/RubyMoney/money-rails
   - `letter_opener` (dev) — preview emails in the browser instead of sending. 🆓
   - `chartkick` + `groupdate` — charts. 🆓
8. **Install your UI kit** (DaisyUI or RailsUI) + Lucide icons, so every feature inherits a consistent look.
9. **Add `db/seeds.rb`** with sample accounts, categories, transactions, and a couple of lessons, so dev and demos aren't empty. Run `bin/rails db:seed`.

---

## Phase 2 — Deploy an (almost) empty app early

**Goal:** a live URL + working auto-deploy *before* building features.

1. **Create a Render account** (sign in with GitHub). 👤 https://render.com — free tier needs no card to start.
2. **Connect your GitHub repo**; Render detects Rails and builds it.
3. **Provision managed PostgreSQL**; wire it via `DATABASE_URL`.
4. **Set environment variables in Render:** add `RAILS_MASTER_KEY` (contents of your local `config/master.key`) and any other secrets. Without this, the app won't boot in production.
5. **Add a release command** so migrations run on every deploy: `bin/rails db:migrate` (Render → service → Settings → Deploy → Pre-Deploy/Release command).
6. **Enable automated database backups** (paid Postgres tiers include them) and note how to restore.
7. **Confirm** a `git push` to `main` auto-deploys and the URL updates.

> **Render cost reality:** free tier is free to start, but free web services **sleep after 15 min** and free Postgres is **deleted after ~30 days**. A real app needs paid — **Starter web service $7/mo** + **persistent Postgres from $7/mo** — which requires a card. 💳

---

## Phase 3 — Add CI guardrails

**Goal:** automated checks on every push.

1. **GitHub Actions workflow** running: unit/model tests, **system tests (Capybara)**, RuboCop (lint), Brakeman (security).
   - 🆓 https://docs.github.com/actions · https://rubocop.org · https://brakemanscanner.org
2. **Test types to cover per slice:** model tests (validations, money math, business logic in services) and system tests (a user can sign up, add a transaction, see it in a budget).
3. Have the AI run these locally too, so it self-corrects before pushing.

---

## Phase 4 — Build the product (data model + slices)

**Goal:** the budgeting + education features, built in small continuously-deployed slices.

### Data model (manual entry first)

| Model | Key fields | Relationships |
|---|---|---|
| **User** | (from starter kit) email, name | has_many everything below |
| **Account** | name, kind (checking/savings/cash/credit), starting_balance_cents, currency | belongs_to user; has_many transactions |
| **Category** | name, kind (income/expense), color | belongs_to user; has_many transactions |
| **Transaction** | amount_cents, currency, description, occurred_on, txn_type (income/expense/transfer) | belongs_to user, account, category |
| **Budget** | name, period (monthly), starts_on | belongs_to user; has_many budget_lines |
| **BudgetLine** | planned_amount_cents | belongs_to budget, category (actual = sum of transactions) |
| **Course** | title, description, position, published | has_many lessons |
| **Lesson** | title, body (Action Text), position, published | belongs_to course; has_many lesson_progresses |
| **LessonProgress** | completed_at | belongs_to user, lesson |
| **Goal** | name, target_amount_cents, target_date, current_amount_cents | belongs_to user |

All money fields are integer cents via `money-rails`; format for display only in views.
Every query is scoped to `current_user`.

### Suggested slice order (each ships live within minutes)
1. Accounts (create/list/edit).
2. Categories.
3. Transactions with manual entry (the core loop).
4. Monthly budget view: BudgetLine (planned) vs actual (summed from transactions), with a Chartkick breakdown.
5. Goals + progress.
6. Education: Courses → Lessons (Action Text) → mark-complete progress.
7. Engagement: tie a lesson to the user's own budget data (e.g. "set your first savings goal").

### Workflow per slice
`bin/rails g` → write a model + system test → CI green → merge → auto-deploy.

> **Plaid is deferred to Phase 8.** Build the manual `Transaction` model cleanly now; Plaid will later sync *into* the same table.

---

## Phase 5 — Production polish

**Goal:** the supporting pieces a real app needs.

1. **Background worker (required for email/async):** add a **Render Background Worker** service running Solid Queue (`bin/jobs`). Email and recurring summaries won't work reliably without it.
2. **Transactional email:**
   - **Resend** — 👤 free tier; 💳 paid — https://resend.com
   - **Postmark** — 👤 trial then paid; 💳 — https://postmarkapp.com
   - Wire confirmation + password-reset emails (test locally with `letter_opener`).
3. **Error monitoring:** **Sentry** — 👤 free tier — https://sentry.io
4. **Payments (if charging):** **Stripe** — 👤💳 needs business + bank + identity verification; 2.9% + 30¢/txn — https://stripe.com. Consider **Stripe Tax** for sales tax on subscriptions.
5. **Custom domain + DNS:** buy a domain (**Cloudflare** / **Namecheap**, 👤💳 ~$12/yr), then add the DNS records Render gives you and wait for SSL to provision.

---

## Phase 6 — Pre-launch hardening & legal

**Goal:** don't hand real financial data to users on an unhardened app.

1. **Security:** `rack-attack` (rate-limit login/signup), secure headers, `config.force_ssl = true`, and confirm no secrets were ever committed (scan git history).
2. **Financial-data privacy:** encrypt sensitive columns with Rails `encrypts`, and build a real **account/data-deletion** path.
3. **Performance:** add the `bullet` gem to catch N+1 queries before users do.
4. **Legal pages:** publish a **Privacy Policy** and **Terms of Service** (generators like Termly/iubenda exist; for financial data, a lawyer review is worth it). Stripe requires them.
5. **Product analytics:** privacy-friendly (**Plausible** or **PostHog**) — 👤 free tier — to see what users actually do.
6. **Uptime monitoring:** an external health-check ping so you're alerted if the site goes down.
7. **Beta test:** invite 5–10 real users, gather feedback, fix, then open up.

---

## Phase 7 — Launch & scale

1. Invite users publicly.
2. **Watch the database first** — it feels scaling pressure before the app does.
3. Scale on Render: bigger instance, more instances, or a **Postgres read replica**. Managed PaaS carries you to tens of thousands of users.
4. Only move to your own cloud at genuine scale, deliberately, once revenue justifies it.

---

## Phase 8 — Later: bank aggregation via Plaid

Add automated transaction import once you have traction.

- **How it works:** Plaid Link connects a user's bank; you store an encrypted access token; a webhook syncs transactions *into your existing `Transaction` table* (add a `plaid_item` + `plaid_account_id`).
- **Cost:** free **Trial plan** (US/Canada, real data, capped at ~10 connected Items) to build/test; then **Pay-as-you-go** priced per connected account/request (revealed in the Production access flow); Custom/Scale starts ~$500/mo. Usage-based costs can spike with sudden growth — model them before launching it. 👤💳 https://plaid.com/pricing
- **Raises the security bar:** you're now handling bank tokens and richer financial data — tighten encryption, access controls, and your privacy policy accordingly.

---

## Non-code logistics (easy to forget)

- **The curriculum itself.** Building the platform ≠ having lessons. Schedule the content-writing workstream separately.
- **A support channel** — at minimum a monitored support email.
- **Sales tax** on digital subscriptions — Stripe Tax handles registration/collection.

---

## Accounts & credit-card summary

| Tool | Account? | Credit card? | Notes |
|---|---|---|---|
| WSL2 / Ubuntu / mise / Ruby / Rails / PostgreSQL | No | No | Open source |
| VS Code | Optional | No | Free |
| Cursor | Yes | For Pro | Free tier; Pro ~$20/mo |
| Claude Code | Yes | Yes | Claude subscription (~$20/mo) or API |
| RubyMine | Yes | Yes | Paid; 30-day trial |
| GitHub | Yes | No | Free tier |
| Bullet Train | Yes (GitHub) | No | Free |
| Jumpstart Pro | Yes | Yes | $249/yr |
| Gems (strong_migrations, money-rails, chartkick, rack-attack, bullet, etc.) | No | No | Free |
| Tailwind / DaisyUI / Lucide | No | No | Free |
| RailsUI / Tailwind Plus / Rails Designer | Yes | For paid | Optional premium UI |
| Render (hosting) | Yes | Free: No / Paid: Yes | Real app ~$14/mo app+db |
| Resend / Postmark (email) | Yes | For paid | Free tier to start |
| Sentry (errors) | Yes | For paid | Free tier |
| Plausible / PostHog (analytics) | Yes | For paid | Free tier |
| Stripe (payments) | Yes | Yes | Bank + ID verification; 2.9%+30¢ |
| Domain (Cloudflare / Namecheap) | Yes | Yes | ~$12/yr |
| Plaid (Phase 8) | Yes | Yes (paid tiers) | Free Trial ~10 items, then pay-as-you-go |

---

## Cost summary

**To start building (minimum):**
- Hosting: **$0** on Render free tier while developing
- Phases 0–4 tooling: **$0** except your AI tool
- AI coding tool: **~$20/mo** (Claude Pro and/or Cursor Pro)
- Optional starter kit: **$249/yr** (Jumpstart) or **$0** (Bullet Train)
- UI kit: **$0** (DaisyUI) or optional premium one-time

**To run a real, always-on platform:**

| Item | Cost |
|---|---|
| Render web service (Starter) | ~$7/mo |
| Render PostgreSQL (persistent) | ~$7/mo |
| Render background worker | ~$7/mo |
| Domain | ~$12/yr |
| Transactional email | $0 to start, ~$10–15/mo later |
| Error monitoring / analytics | $0 to start |
| AI coding tool (subscription) | ~$20–200/mo — see *AI coding costs* |
| Payments (if charging) | 2.9% + 30¢ per transaction |
| Plaid (Phase 8, later) | Free trial, then pay-as-you-go |
| **Typical running total** | **~$40–65/mo** + optional extras |

---

## AI coding costs (usage / API based)

Rough estimate of what the AI itself costs from first commit to a polished app. Order-of-magnitude only.

### Claude API rates (per 1M tokens, mid-2026)

| Model | Input | Output | Role |
|---|---|---|---|
| Haiku 4.5 | $1 | $5 | Cheap, simple tasks |
| Sonnet 5 | $3 ($2 intro thru Aug 31 2026) | $15 ($10 intro) | Coding workhorse |
| Opus 4.8 | $5 | $25 | Best coder; hard problems |
| Fable 5 | $10 | $50 | Top tier |

Prompt caching cuts cached input up to 90% (automatic in Claude Code). Output costs 5× input; input (context) dominates.

### Cursor rates (mid-2026)

| Plan | Price | What you get |
|---|---|---|
| Hobby | $0 (no card) | Limited Agent + Tab |
| Pro | $20/mo | Unlimited Tab + Auto mode; ~$20 frontier-model pool |
| Pro+ | $60/mo | ~3× Pro |
| Ultra | $200/mo | ~20× Pro |
| Teams | $40/user (Standard), $120 (Premium) | Org features, SSO |

Annual billing = 20% off. Overflow: Auto mode is unmetered; premium-model use draws from your pool, then bills on-demand — set a cap in **Settings → Billing**. https://cursor.com/pricing

### Real-world benchmarks
Anthropic's Claude Code figures: ~**$13 / active coding day**, **$150–250 / month** typical, **$500–2,000 / month** heavy. 90% of active days under $30.

### Rough cost per typical task

| Task type | Rough tokens (cumulative) | Sonnet 5 | Opus 4.8 |
|---|---|---|---|
| Small fix / tweak | ~50–150K in, ~5–15K out | ~$0.25–0.75 | ~$0.50–1.50 |
| Single feature slice | ~300–800K in, ~20–60K out | ~$1–4 | ~$2–8 |
| Complex feature (billing, auth) | ~1–2M in, ~50–120K out | ~$4–10 | ~$8–20 |
| Tricky debugging session | ~0.5–1.5M in, ~15–40K out | ~$2–6 | ~$4–12 |
| Full active coding day | — | ~$10–15 | higher |
| A steady month of building | — | ~$150–250 | higher |

### Rough total for the whole build (start → polished)

| Profile | What it looks like | Rough total |
|---|---|---|
| **Lean** | Sonnet workhorse, caching on, tight context | **~$150–400** |
| **Typical** | Sonnet + Opus for hard problems, normal iteration | **~$500–1,200** |
| **Heavy** | Opus-heavy, lots of trial-and-error | **~$1,500–3,000+** |

### Recommended structure
Subscription as primary (Claude Max $100–200/mo or Cursor Pro/Pro+), usage/API as overflow past the
limit (set a cap), pay-as-you-go only if building is sporadic. Keep Sonnet as workhorse, context tight,
caching on. **Middle-case budget: ~$500–1,200 total for the full build.**

---

## Appendix A — Notes
- **Money:** every amount is integer cents + `money-rails`. Never floats.
- **Auth:** provided by the starter kit; email confirmation + reset need the background worker + email (Phase 5).
- **Scoping:** every controller action authorizes `current_user` and scopes queries to them.

---

## Appendix B — Starter CLAUDE.md

```
# <AppName>

## Stack
- Ruby 3.4.x, Rails 8.1, PostgreSQL 16
- Frontend: Hotwire (Turbo + Stimulus), Tailwind CSS v4, DaisyUI, Chartkick
- Money: money-rails (store amounts as integer cents; NEVER floats)
- Auth: <from starter kit>
- Background jobs: Solid Queue (bin/jobs)
- Tests: Minitest + Capybara. Run `bin/rails test` and `bin/rails test:system`.
- Lint: `bundle exec rubocop -A`. Security: `bin/brakeman`.

## Conventions
- Business logic in app/services/, one public #call method per service.
- Never write raw SQL in models; use scopes/Arel.
- Prefer `bin/rails g` generators, then edit.
- All money stored in cents; format for display only in views.
- Every controller action authorizes current_user and scopes queries to current_user.

## Do NOT
- Do not use React/Vue or add a JS build framework — Hotwire only.
- Do not add Redis — use Solid Queue / Solid Cache.
- Do not edit db/schema.rb by hand; change via migrations.
- Do not commit secrets; use Rails credentials / ENV.

## Commands
- Dev: `bin/dev`   Migrate: `bin/rails db:migrate`   Console: `bin/rails console`
```

---

## Appendix C — Non-developer path (Lovable + Supabase)

For a non-developer willing to learn. Uses **Lovable**, an AI app builder that turns plain-English
prompts into a working full-stack app and generates **real React/TypeScript + Supabase** code synced
to GitHub — so you're not locked in and can hand off to a developer (or graduate to the Rails path)
later. You trade some control and cost predictability for a much lower starting floor.

### How the phases change

- **Phase 0 (environment) — mostly eliminated.** No WSL, Ruby, Postgres, or local setup; you work in the browser at lovable.dev. Keep a GitHub account (Lovable syncs there).
- **Phase 1 (scaffold) — describe, don't clone.** Instead of a starter kit + `CLAUDE.md`, write a clear prompt describing the app; Lovable generates the initial full-stack app with auth + database (Supabase). Feed it the data model below as your spec.
- **Phase 2 (deploy) — built in.** Lovable hosts and deploys automatically; publish to a live URL in a click, connect a custom domain on Pro.
- **Phase 3 (CI) — lighter.** Lovable handles builds; testing is mostly click-through. Once you've exported to GitHub you can add CI later.
- **Phase 4 (build) — same data model, different method.** The model (Accounts, Categories, Transactions, Budgets, Lessons, Progress, Goals) is identical — give it to Lovable as your spec and iterate feature-by-feature via chat. Still tell it explicitly to store money as integer cents.
- **Phase 5 (polish) — Supabase + integrations.** Auth and DB come from Supabase; email via Resend; payments via Stripe (verify payment wiring carefully — it's security-sensitive).
- **Phase 6 (hardening & legal) — still yours, and more important here.** Configure **Supabase Row Level Security (RLS)** so each user sees only their own financial data — this is critical. Privacy Policy + ToS, encryption, beta test all still required.
- **Phase 7 (launch & scale) — watch Supabase.** Scale by upgrading the Supabase tier; cost grows with usage.
- **Phase 8 (Plaid) — still an option**, wired through the generated code / Supabase functions, with the same elevated security bar.

### Key things to understand

- **Real, portable code:** output is React/TypeScript + Supabase on GitHub — not locked in.
- **Credit-based, less predictable:** each AI action burns credits; heavy debugging/iteration costs more (some report $100–200 on tough projects). A CRUD-with-auth build alone can burn 30–60 credits.
- **The 70–80% pattern:** a common workflow is to prototype in Lovable, export to GitHub, then finish/harden in Cursor — a natural on-ramp into real development.
- **RLS is non-negotiable** for a financial app — it's how you guarantee data isolation between users.

### Cost breakdown (non-dev path)

**To build / prototype:**
- Lovable Free ($0, ~5 credits/day) or Pro (~$25/mo) + Supabase Free ($0) = **$0–25/mo**

**To run a real app:**

| Item | Cost |
|---|---|
| Lovable Pro | ~$25/mo (some tiers ~$20; annual ~20% off) |
| Supabase Pro (production DB, daily backups) | ~$25/mo + usage |
| Domain | ~$12/yr |
| Email (Resend) | $0 to start |
| Payments (Stripe, if charging) | 2.9% + 30¢ per txn |
| **Typical running total** | **~$50–75/mo** (heavy-iteration months can spike on credit overages) |

Comparable to the Rails path (~$40–65/mo), slightly higher — you're paying a bit more to skip almost
all the setup and the language learning curve.

### When to reconsider
Deeply custom logic, tight cost control at scale, or heavy compliance can create friction on the
generated-code path. Because it's real code on GitHub, you can graduate to the developer/Rails path or
hand off to a developer without starting over.

---

## Quick-start checklist

- [ ] WSL2 + Ubuntu installed; project in Linux filesystem (not /mnt/c)
- [ ] git configured; SSH key or gh auth set up
- [ ] mise + Ruby 3.4.x + Node; Rails 8.1 + PostgreSQL; test app boots
- [ ] Editor connected to WSL; Claude Code runs in WSL terminal
- [ ] Starter kit cloned; GitHub repo created; .gitignore excludes secrets
- [ ] Rails credentials / master.key set up
- [ ] CLAUDE.md written (Appendix B)
- [ ] Core gems added (strong_migrations, money-rails, letter_opener, chartkick)
- [ ] UI kit + Lucide installed; seed data added
- [ ] Render: empty app deployed; RAILS_MASTER_KEY + ENV set; release migrate command; backups on
- [ ] CI green (tests + system tests + RuboCop + Brakeman)
- [ ] Data model built (Accounts → Categories → Transactions → Budget → Goals → Education)
- [ ] Background worker running; email working; error monitoring on
- [ ] Payments + Stripe Tax (if charging); domain + DNS + SSL
- [ ] Hardening: rack-attack, force_ssl, encrypts, bullet, data-deletion path
- [ ] Legal: Privacy Policy + Terms published
- [ ] Analytics + uptime monitoring
- [ ] Beta tested with 5–10 users → public launch
- [ ] (Later) Plaid integration for auto-import

---

*Prices and free-tier terms change — verify current details on each provider's site before committing.*
