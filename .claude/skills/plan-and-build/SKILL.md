---
name: plan-and-build
description: Use when the user wants to plan a change end-to-end and then build it — brainstorm requirements, write a plan, then execute it (fresh session with checkpoints, or parallel subagents now), finishing with a Rails-specific review pass. Trigger on "/plan-and-build", "let's plan and build X", "plan this out then implement it", or similar requests that bundle planning and execution together.
---

# Plan and build

This project has two overlapping planning/execution frameworks installed — `superpowers` and
`compound-engineering`. Running both end-to-end on the same change is redundant, not
complementary. This skill picks `superpowers` as the spine (brainstorm → plan → execute) and
pulls in `compound-engineering`'s Rails-specific reviewers only for the review step, where they
add something `superpowers` doesn't have.

If the user explicitly asks for `compound-engineering`'s own planning chain instead
(`ce-brainstorm` → `ce-plan` → `ce-work` → `ce-review`), follow that instead of this skill — don't
run both.

## Steps

1. **Brainstorm.** Invoke `superpowers:brainstorming` to pin down intent, requirements, and
   constraints before anything else. Don't skip this even for a request that sounds
   fully-specified — that's what the skill is for.

2. **Write the plan.** Invoke `superpowers:writing-plans` to turn the brainstorm output into a
   written implementation plan. Follow this repo's `CLAUDE.md` conventions in the plan itself
   (Hotwire only, DaisyUI classes, money as integer cents via `money-rails`, business logic in
   `app/services/`, no Redis, tests before considering anything done).

3. **Confirm execution mode.** Ask the user how to proceed — don't assume:
   - **Fresh session, review checkpoints** (`superpowers:executing-plans`) — best for larger or
     riskier changes where you want to review each step before the next one starts.
   - **Parallel subagents now, in this session** (`superpowers:subagent-driven-development`) —
     best when the plan has genuinely independent tasks and speed matters more than
     step-by-step review.
   - **Just leave the plan** — the user will execute it themselves or hand it off later. Stop
     here if so.

4. **Execute** using whichever mode was chosen.

5. **Rails review pass.** Before considering the work done, run it past this repo's
   Rails-specific reviewers via the `Agent` tool: `compound-engineering:review:dhh-rails-reviewer`
   and `compound-engineering:review:kieran-rails-reviewer` at minimum. Add
   `compound-engineering:review:data-integrity-guardian` if the change touches migrations or
   persisted data, and `compound-engineering:review:architecture-strategist` if it adds a new
   service or reshapes existing structure. Address or explicitly note anything they flag.

6. **Finish the branch.** Invoke `superpowers:finishing-a-development-branch` to decide how to
   integrate — this repo's convention (see `check-specs`) is a new branch and an open PR, not a
   direct commit to `main`, and not a self-merge. Per
   `docs/agentic-development-lifecycle.md`, open the PR against `staging`, not `main`, unless
   this is a sanctioned hotfix for a live production bug or the user explicitly says otherwise.
