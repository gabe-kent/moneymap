# Agentic development lifecycle

How changes get from an idea to production in moneymap, written for a non-technical
collaborator to follow end-to-end. Two entry points, one shared path from there on.

## The two entry points

**1. Design first (Claude Design).** Start in Claude Design, build out webpage mocks, and plan
functionality directly on the page — no code yet. When the design is ready, export/send it to a
cloud-enabled Claude Code session to turn into a real, working change.

**2. Talk it through (Claude Code cloud + `/plan-and-build`).** Start a Claude Code cloud
session and run `/plan-and-build` (see `.claude/skills/plan-and-build/SKILL.md`). It walks you
through describing what you want (brainstorming), turns that into a written plan you can react
to before anything is built, then builds it.

Either way, you end up with a **pull request** — a proposed change, not yet live, that's easy to
look at and comment on before it ships.

## Everything after that is the same

```
                          PR opened
                              |
                              v
                   Merge into `staging` branch
                              |
                              v
              Auto-deploys to moneymap-staging (Render)
                              |
                              v
                    You QA it on staging
                              |
                    looks good?  no -> new PR / fix, back to the top
                              |
                             yes
                              v
              Merge `staging` into `main` (a "promotion")
                              |
                              v
                Auto-deploys to production (moneymap)
```

**PRs target `staging` by default, not `main`.** That's the one habit this whole lifecycle
depends on — see `docs/staging-environment-setup.md` for how staging is set up, and why it isn't
a fully separate database yet. If you're an agent picking a base branch for a PR in this repo and
nothing says otherwise, it's `staging`.

**Promoting `staging` to `main` is a separate, deliberate step** — not automatic, and not
something a PR merge does by itself. It's a manual `staging` -> `main` merge (fast-forward when
possible) once whatever's on staging has been QA'd and is ready for real users. Do this
regularly — letting `staging` drift weeks ahead of `main` with unpromoted changes defeats the
point of having the two.

**A promotion PR is kept open for you automatically.** `.github/workflows/promote-staging.yml`
runs on every push to `staging` and, whenever `staging` has commits `main` doesn't, makes sure a
`staging -> main` PR is open — creating one if none exists, leaving an existing one alone (GitHub
keeps its diff live as `staging` keeps moving), and closing it if the branches end up back in
sync some other way (e.g. a direct fast-forward). It's plain `git`/`gh` bookkeeping with no
tests, build, or AI calls — a few seconds of Actions time, nothing more — so promoting is always
"review this standing PR and merge it," never "remember to go create one." Merge it as a plain
merge, not squash, so `main`'s history matches what `staging` was actually running.

### Exception: hotfixes

A bug actively breaking production shouldn't wait for a staging round-trip. For that case only:
PR straight against `main`, merge, deploy, then immediately back-merge (or cherry-pick) the fix
into `staging` so the two don't diverge. This is the only sanctioned path that skips staging —
everything else goes through it.

## Every PR summarizes its own QA

`.github/pull_request_template.md` gives every new PR a **QA** section with two parts, so the
person QA-ing the staging deploy knows what's already been checked versus what still needs a
human to click through it:

- **Automated** — what ran and passed (typically `bin/ci`, or specific commands if the full
  suite wasn't run). This is a fact, not a plan — only fill it in with things that actually ran.
- **Manual QA on staging** — a short, concrete, PR-specific checklist of what to click through
  once the PR is live on moneymap-staging. Not a generic "test the app" — call out exactly what
  changed and how to see it (e.g. "confirm the new KPI card shows the right numbers," not "check
  the dashboard"). A doc/test-only PR skips this section entirely, since it targets `main`
  directly and there's no staging deploy to check.

This turns "you QA it" in the diagram above from an open-ended request into a checklist someone
can actually follow — including whoever wrote the PR, if they want to self-check before asking
for a look.

## Reporting bugs, feature requests, and deferred items

**GitHub Issues**, directly — no separate system. Reporting something only needs a free GitHub
account and a browser; no git or coding knowledge required, which is the bar this whole doc is
written to. Clicking **New issue** offers two plain-language forms —
`.github/ISSUE_TEMPLATE/bug_report.yml` and `feature_request.yml` — that ask a couple of
questions and apply the right label automatically; a deferred item, or anything that doesn't fit
either form, can still be filed as a blank issue with the `deferred` label added by hand. The
labels in use:

| Label | For |
|---|---|
| `bug` | Something is broken or behaving wrong. |
| `enhancement` | A new feature or capability request. |
| `deferred` | Known, agreed-on, and intentionally not being worked right now — a way to write something down and stop thinking about it without losing it. |

An agent picking up a task from an issue should reference it in the PR description (`Fixes #123`
/ `Closes #123` for bugs and enhancements — GitHub auto-closes the issue when that PR merges to
the issue-tracking repo's default branch; note that with the staging-first flow above, that
auto-close fires on the `main` merge, i.e. the promotion, not the initial PR into `staging`).
Leave `deferred` issues open indefinitely; they're a backlog, not something expected to
auto-close.

If a future collaborator genuinely can't get a GitHub account, the fallback is a shared
Google Form -> Google Sheet as an intake point, with someone periodically triaging new rows into
GitHub Issues — but that's not needed today, so it isn't set up.

## For agents working in this repo

- Default PR base branch is `staging`, not `main`, unless you're doing a sanctioned hotfix (see
  above) or the user explicitly says otherwise.
- Fill in the PR template's QA section with a real, PR-specific manual-QA checklist — not a
  placeholder or a generic "test the app" line. If you ran `bin/ci` (or equivalent) yourself,
  say so under **Automated**.
- `.claude/skills/plan-and-build/SKILL.md`'s "finish the branch" step follows this doc.
- The `check-specs` command doesn't currently specify a base branch, so `gh pr create` without
  `--base` there defaults to this repo's actual default branch (`main`). Until that command is
  updated, override it manually: `gh pr create --base staging ...`.
- Don't merge your own PRs, and don't promote `staging` to `main` yourself unless asked to —
  that's the "you QA it" checkpoint above, and it's a human decision.
