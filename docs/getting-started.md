# Getting started (for a non-technical collaborator)

Moneymap is two things in one: **a personal finance app** (accounts, spending, budgeting) and
**a financial literacy aid** (education alongside the numbers) — see the README for the fuller
one-line version. This doc isn't about the product, though; it's everything you need to make
your first *change* to it using Claude Code's **cloud** workflow — no local install, no
terminal, just a browser. If you already know what a "cloud session" is and just want the
PR→production pipeline, skip straight to `docs/agentic-development-lifecycle.md`; this doc is
the layer before that — how to actually open a session and kick off work in the first place.

## What "cloud" means here

A **cloud session** is a Claude Code session that runs entirely on Anthropic's servers, not on
your computer — you open it at [code.claude.com](https://code.claude.com) in a browser, point it
at this repo, and start typing. There's nothing to install, no Ruby or Postgres to set up
yourself; the cloud environment already has this repo's exact versions configured (see
`docs/cloud-environment-setup.md` if you're curious what that involves — you don't need to touch
it).

This is different from running `claude` in a terminal on your own machine, which is what
`docs/environment-setup-runbook.md` walks through — that's the path for local development, not
needed for the workflow this doc covers.

## One-time setup (already done, listed for reference)

Someone with admin access to the GitHub repo already did these once, so you shouldn't need to —
listed here only so you know why things work, and as a checklist if a cloud session ever reports
a permissions error:

- **Claude's GitHub App is installed** for this repo, so a cloud session can push branches and
  open pull requests directly. See "Claude Code cloud session bootstrap" in
  `docs/environment-setup-runbook.md` if this ever needs re-doing.
- **The cloud environment's setup script is configured** with this repo's Ruby version and a
  working Postgres, so `bin/rails test` and friends work inside a session without extra steps.
  See `docs/cloud-environment-setup.md`.

## Starting a session

1. Go to [code.claude.com](https://code.claude.com) and sign in.
2. Start a new session pointed at the `moneymap` repository.
3. Pick one of the two ways to kick off work below.

## Two ways to kick off work

**If you want to see the UI before anything is built — start in Claude Design.** Go to
[claude.ai/design](https://claude.ai/design), describe the screen or feature in plain English,
and iterate until it looks right — a real clickable prototype, not just a picture. When you're
happy with it, use its **Export → "Hand off to Claude Code"** button, copy the prompt it gives
you, and paste that into a new Claude Code cloud session pointed at this repo. Full detail on
this handoff (and why it's worth doing before writing anything to the repo) is in
`docs/claude-surfaces-handoff.md`.

**If you'd rather just describe what you want and talk it through — use `/plan-and-build`.**
In a Claude Code cloud session pointed at this repo, type:

```
/plan-and-build <describe what you want, in plain English>
```

This walks you through a brainstorm (Claude asks clarifying questions before assuming anything),
turns that into a written plan you get to react to and adjust, and only then builds it. You
don't need to know Rails, git, or anything about this codebase to use it — that's the point.

Either path ends the same way: a **pull request** — a proposed change you can look at, comment
on, and approve before anything reaches real users.

## What happens after you kick off work

This is where `docs/agentic-development-lifecycle.md` picks up: the PR gets merged into a
`staging` branch, which auto-deploys to a staging copy of the app for you to click through and
confirm before it reaches production. Read that doc for the full picture — including how bugs
and feature ideas get tracked (plain GitHub Issues, no separate system, no coding knowledge
needed to file one).

## If something goes wrong

- **A cloud session says it can't push or open a PR** — see "GitHub App install for push/PR
  access" in `docs/environment-setup-runbook.md`'s cloud session bootstrap section.
- **The constant "may I do X?" prompts are annoying** — don't reach for a "skip all permissions"
  setting to make them stop; it has real gotchas and isn't even available in cloud sessions. See
  `docs/claude-code-permission-modes.md` for what to use instead.
- **You're not sure what a term in one of these docs means** — ask the Claude Code session
  itself; explaining its own workflow is exactly the kind of thing it's good at.
- **Anything else** — file a GitHub Issue (see `docs/agentic-development-lifecycle.md` →
  "Reporting bugs, feature requests, and deferred items") so it doesn't get lost.
