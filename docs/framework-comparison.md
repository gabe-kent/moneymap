# Framework comparison: Next.js, Rails, Django, Reflex, SvelteKit

Five web frameworks, weighed for one specific situation: a non-developer building and
shipping entirely through Claude Code, with a GitHub repo, CI, and auto-deploy already
in place. Written as background/validation for the stack Moneymap already runs on
(Rails 8.1 — see `docs/financial-literacy-platform-plan.md`), not as an open decision.

Rankings here reflect each framework's ecosystem as of this writing — component
libraries and defaults (like Rails 8's Solid Queue) shift fast enough to double-check
before committing on a long-lived project.

## Context & criteria

Since the person driving the project won't be reading or debugging the generated code
line by line, the criteria here weigh differently than they would for an engineering
team choosing a stack for themselves.

- **Claude Code fit** — how much reliable, idiomatic code Claude can produce, based on
  how well-represented the framework is in what it's learned from.
- **Design ecosystem** — how rich the supply of modern, pre-built UI patterns is,
  since "sleek and modern" is easier to reach by assembling existing components than
  generating novel CSS.
- **Database story** — how much assembly is required to get a working,
  production-grade data layer.
- **Background job support** — how the framework handles work that happens outside a
  request: scheduled tasks, queues, delayed jobs.
- **Deployment fit** — how naturally the framework matches a typical GitHub CI +
  auto-deploy pipeline.

## At a glance

| Framework | Database | Background jobs | UI / design ecosystem | Deployment | Claude Code fit |
|---|---|---|---|---|---|
| Next.js (JS/TS) | None built in — pair with Supabase/Postgres + Prisma or Drizzle | None built in — Trigger.dev, Inngest, or Vercel Cron | Largest — Tailwind + shadcn/ui + Radix | Serverless-first (Vercel, Netlify) — push-to-deploy | Excellent — deepest training coverage of any option here |
| Ruby on Rails | Built in — ActiveRecord ORM + migrations | Built in — ActiveJob; Solid Queue (DB-backed) by default in Rails 8 | Moderate — Tailwind + Hotwire/Turbo; few prebuilt kits | Persistent server (Render, Fly.io, Kamal) | Very good — strong conventions keep AI output consistent |
| Django (Python) | Built in — Django ORM + migrations | Std-lib task API (Django 6+) for simple cases; Celery + Redis for scale | Moderate — Tailwind + server templates, not component-driven | Persistent server (Render, Railway) | Very good — large, mature corpus |
| Reflex (Python) | Built in — SQLAlchemy-based | Basic background events; thin ecosystem for robust queues | Small — Radix-based components, few prebuilt kits | Needs a Python + WebSocket host, or Reflex Cloud | Weaker — small corpus, evolving API, harder for a non-dev to catch mistakes |
| SvelteKit (JS/TS) | None built in — pair with Postgres/Supabase or Cloudflare D1 | None built in — BullMQ + Redis or an external queue service | Growing — Tailwind; smaller component-library pool than React | Flexible adapters — Vercel, Cloudflare, Node, static | Good — solid, but well behind React/Next.js in volume |

## Framework profiles

### Next.js (React)

**Strengths**
- By far the deepest well of training data and real-world examples for Claude Code to
  draw from — fewer hallucinated APIs, more reliable output.
- Unmatched design ecosystem — Tailwind CSS plus shadcn/ui and Radix give Claude a
  huge supply of polished, modern patterns to assemble rather than invent.
- Serverless deployment (Vercel, Netlify) matches a push-to-deploy CI pipeline almost
  exactly, with minimal configuration.

**Weaknesses**
- No database or background-job support built in — every project assembles these
  from separate services, meaning more pieces to wire together and more places for
  something to be misconfigured.
- Serverless functions have execution time limits, so anything long-running needs an
  external job service.
- Framework flexibility means there's rarely one "correct" way to do something, which
  can produce inconsistency across a codebase built up over many separate Claude Code
  sessions.

**Best for:** projects where visual polish is the top priority, and a Vercel-style
deploy pipeline is already the target.

### Ruby on Rails

**Strengths**
- Batteries-included: a built-in ORM (ActiveRecord), background jobs (ActiveJob,
  backed by the database-native Solid Queue as of Rails 8), file storage, and email
  are all part of the framework rather than separate services to assemble.
- Two decades of "convention over configuration" give Claude a strong, consistent
  pattern to follow, producing more predictable output than a framework with many
  valid architectures.
- Rails 8's Solid Queue and Solid Cache remove the Redis dependency entirely for most
  apps — background jobs work on nothing more than the existing database.

**Weaknesses**
- No serverless deployment story — Rails expects a persistent server (Render,
  Fly.io, Kamal), a mismatch if an existing pipeline is built around static or
  serverless hosting.
- The design ecosystem is thinner than React's — Tailwind and Hotwire/Turbo produce
  clean, modern-looking apps, but without React's dense supply of drop-in components.

**Best for:** projects where a reliable database and background jobs matter as much
as the frontend, and the deployment target can be a persistent server.

### Django (Python)

**Strengths**
- Same batteries-included philosophy as Rails — a mature built-in ORM, migrations,
  and (as of Django 6) a standard-library background task API for simple cases.
- Celery, paired with Redis, is the long-standing, extremely well-documented answer
  for more demanding background work.
- One of the most heavily used web frameworks in existence, giving Claude Code a
  large, stable body of patterns to draw from.

**Weaknesses**
- More configuration surface than Rails — often more than one reasonable way to
  structure something, introducing slightly more room for inconsistency across
  sessions.
- Server-rendered templates rather than a component model, so a "very modern, sleek"
  look takes more manual styling than pulling from a component library.
- Like Rails, expects a persistent server rather than a serverless deploy target.

**Best for:** a Python-based alternative to Rails with the same batteries-included
appeal — mainly if there's an existing reason to prefer Python.

### Reflex (Python)

**Strengths**
- The entire app — frontend and backend — is written in one language, appealing in
  principle even though Claude is the one writing it either way.
- Ships with a built-in SQLAlchemy-based database layer and a real component system
  built on Radix, rather than raw HTML templates.
- Genuinely capable of a clean, modern look, since its components share a foundation
  with the same Radix primitives that power much of the React design ecosystem.

**Weaknesses**
- Far smaller adoption than the other four options — Claude Code has seen much less
  Reflex code, so expect more inconsistent output and a higher chance of subtly
  incorrect API usage a non-developer can't easily catch.
- Background job and queueing support is thin — nothing close to ActiveJob, Celery,
  or the Node job-queue ecosystem.
- Deployment requires a Python- and WebSocket-capable host, unlikely to match an
  existing CI/deploy pipeline built for a typical JS or static site.

**Best for:** teams intrigued by the single-language pitch who accept more rough
edges in exchange — riskier when no one on the project can independently debug the
generated code.

### SvelteKit

**Strengths**
- A lighter, less boilerplate-heavy alternative to Next.js with a similar shape —
  file-based routing, server-only functions, single-command deploys to Vercel,
  Cloudflare, Netlify, or plain Node.
- Strong end-to-end type safety between server and component code.
- Flexible deployment adapters make it easy to match almost any existing CI/deploy
  pipeline.

**Weaknesses**
- No database or background-job support built in, same as Next.js — expect to pair
  it with Postgres/Supabase and an external queue service like BullMQ.
- Much smaller design-component ecosystem than React's.
- Considerably less training data than React/Next.js, so Claude Code's fluency, while
  solid, is a step behind.

**Best for:** a leaner alternative to Next.js for someone comfortable with a smaller
design-component supply in exchange for less framework overhead.

## Tradeoffs to weigh

The five options split into two real philosophies rather than a single ranked list.
Next.js and SvelteKit "assemble best-of-breed pieces" — more services to wire
together, but access to the richest design ecosystem in existence. Rails and Django
are "batteries-included" — a database and background jobs that work with almost no
assembly, at the cost of a smaller design-component supply and a deployment model
that doesn't match serverless-style CI pipelines as naturally. Reflex stands alone as
a single-language, smaller-ecosystem option trading a rich Python/JS split for a much
thinner well of Claude Code training data.

**Recommendation:** if sleek, modern design is the top priority, Next.js (or
SvelteKit) with Tailwind and a component library gives Claude the deepest supply of
polished patterns. If a reliable database and background jobs matter just as much,
Rails is the strongest all-in-one answer, Django close behind as its Python
equivalent. If the existing CI/deploy pipeline is serverless, Next.js or SvelteKit
fit directly; Rails and Django need a persistent-server target instead.
