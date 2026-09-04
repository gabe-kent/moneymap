---
name: work-issue
description: Use when given a GitHub issue number, "#N", or issue URL and asked to work it — fix it, build it, or otherwise act on it. Fetches the issue, plans and builds from it via plan-and-build, and links the resulting PR back to the issue. Trigger on "/work-issue <ref>", "work on issue #45", "fix https://github.com/.../issues/45", or similar.
---

# Work issue

Takes a GitHub issue as the starting point instead of a from-scratch request, then hands off to
`plan-and-build` (`.claude/skills/plan-and-build/SKILL.md`) for everything after that. This skill
only covers fetching the issue and closing the loop back to it — it doesn't duplicate
`plan-and-build`'s planning/execution/review steps.

## Steps

1. **Resolve the reference.** Accept a bare number (`45`), `#45`, or a full
   `github.com/.../issues/45` URL. A bare number or `#N` means an issue in this repo
   (`gabe-kent/moneymap`); a URL may point elsewhere — if it does, say so explicitly before
   proceeding, since this repo's conventions (CLAUDE.md, staging-first PRs) may not apply there.

2. **Fetch it.** `gh issue view <ref> --json number,title,body,labels,state,url,comments`. If the
   issue is already closed, stop and confirm with the user before doing anything — don't
   silently reopen or redo closed work.

3. **Brief the user.** Summarize the issue back in a sentence or two (title, what it's asking
   for, its label) so there's a shared starting point before planning begins.

4. **Hand off to `plan-and-build`**, seeded with the issue instead of starting blank:
   - Its brainstorming step should treat the issue's title/body/comments as the starting
     material — the goal is filling genuine gaps the issue leaves open, not re-deriving
     requirements the issue already states clearly.
   - Follow the rest of `plan-and-build`'s steps as written (plan, confirm execution mode,
     execute, Rails review, finish the branch).

5. **Link the PR to the issue.** In step 6 of `plan-and-build` ("finish the branch"), include
   `Fixes #<number>` or `Closes #<number>` in the PR body for a `bug` or `enhancement` issue (not
   for `deferred` — those aren't meant to auto-close). Per
   `docs/agentic-development-lifecycle.md`, the PR targets `staging`, so the issue won't actually
   auto-close until `staging` is promoted into `main` — say this explicitly rather than implying
   the issue closes immediately on merge.
