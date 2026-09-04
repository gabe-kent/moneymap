# Moneymap

[![CI](https://github.com/gabe-kent/moneymap/actions/workflows/ci.yml/badge.svg)](https://github.com/gabe-kent/moneymap/actions/workflows/ci.yml)

Two things in one, for individual users: **a personal finance app** (accounts, spending
categories, budgeting) and **a financial literacy aid** (education alongside the numbers, not
just a ledger). Explicitly financial education, not personalized investment/securities advice —
see `docs/financial-literacy-platform-plan.md` for the full product plan, scope boundaries, and
target data model.

**Status:** bootstrap stage. Authentication, DaisyUI styling, and CI are in place; the core
product (Accounts → Categories → Transactions → Budget → Goals → Education) is being built
incrementally — see `docs/repo-review-2026-08-29.md` for the latest snapshot of what exists vs.
what's still open.

## New here and non-technical?

Start with **[`docs/getting-started.md`](docs/getting-started.md)** — a plain-English walkthrough
of how to make your first change using Claude Code's cloud workflow, no install or terminal
required.

## Stack

- **Rails 8.1**, Ruby (see `.ruby-version`), PostgreSQL
- **Hotwire** (Turbo + Stimulus) via importmaps — no npm/Node, no JS bundler
- **DaisyUI + Lucide icons** for UI, installed without npm (see `CLAUDE.md` → Conventions)
- **Solid Queue / Solid Cache / Solid Cable** — background jobs, cache, and Action Cable all on
  Postgres, no Redis
- **Render** for hosting (`git push` → auto-deploy), via a `Dockerfile` + `render.yaml` Blueprint

## Local development

```bash
bin/setup     # install gems, prepare the dev database, boot the server
bin/dev       # run the app (Puma + Tailwind watcher)
bin/ci        # full local CI: rubocop, bundler-audit, importmap audit, brakeman, tests
```

Needs a running PostgreSQL server (`config/database.yml`). Full setup instructions, including
Windows/WSL2-specific steps and every issue hit along the way, are in
`docs/environment-setup-runbook.md`.

## How development actually works here

Changes flow through a **`staging` → `main` promotion pipeline**, not straight to production, and
day-to-day work is expected to happen through Claude Code (locally or in the cloud) rather than
hand-editing files — see:

- `docs/getting-started.md` — start here if you're new or non-technical
- `docs/agentic-development-lifecycle.md` — the full PR → staging → production pipeline, and how
  bugs/features are tracked (GitHub Issues)
- `docs/environment-setup-runbook.md` — local dev setup, plus Claude Code cloud session bootstrap
- `CLAUDE.md` — conventions Claude Code follows in this repo (money handling, service objects,
  scoping, UI kit)

## More docs

`docs/` has a lot more detail than fits here — design decisions, framework/tooling comparisons,
and setup runbooks accumulated as the project grew. `docs/financial-literacy-platform-plan.md`
and `docs/repo-review-2026-08-29.md` are the best starting points for "what is this and where is
it at," beyond the getting-started guide above.
