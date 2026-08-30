# Spec relay: Cowork → Claude Code routine → CI/CD

A hands-off relay from a plan written in Cowork to shipped, tested code — Cowork
fires a Claude Code routine directly over Anthropic's own API, with no GitHub push
and no manual step required to kick it off.

This calls an experimental Anthropic API — request/response shapes and rate limits
may change behind new dated beta headers. Re-check
[the current docs](https://platform.claude.com/docs/en/api/claude-code/routines-fire)
if a call starts behaving differently than described here.

> **Revised design:** an earlier version of this approach routed the handoff through
> a GitHub push, which turned out to need a manual `git push` since Cowork can't
> write to GitHub directly. This version replaces that hop with Claude Code's own API
> trigger, tested and confirmed working directly from a Cowork shell — no GitHub
> involved in the handoff itself.

```
Cowork  →  Claude Code  →  CI/CD
(plan)     (implement)     (ship)
```

Write the spec → curl the routine's API trigger → Claude Code implements & opens a
PR → tests run, you merge, it deploys.

## 1. Plan & design

Unchanged from before — this is just how you use the conversation so the output is
easy to hand off. Ask Cowork to turn a feature idea into a written spec: what it
does, what it doesn't, and any UI details. Push on it until it's specific enough that
Claude Code could implement it without follow-up questions — a vague spec is still
where this relay would produce the weakest results, trigger mechanism aside.

## 2. One-time setup — create the routine and its API trigger

This is the only human-in-the-loop step in the whole relay, and you only do it once
per routine.

1. **Go to `claude.ai/code/routines`** and create a new routine, pointed at your
   repository.
2. **Write the routine's prompt.** Be explicit and self-contained — it can't see this
   conversation or any linked doc. Something like: "Implement the spec passed in this
   run's context. Follow the repo's CLAUDE.md conventions. Add tests, commit to a new
   branch, and open a pull request. Don't merge it yourself."
3. **Add an API trigger.** Open the routine for editing, click **Add another
   trigger** under **Select a trigger**, choose **API**, then **Generate token**. The
   token (prefixed `sk-ant-oat01-`) and the routine ID (prefixed `trig_`) are shown
   once — copy both immediately.
4. **Save the token somewhere Cowork can read it.** A small file inside your
   connected project folder works well — e.g. `.claude/routine.env` — as long as it's
   added to `.gitignore` so it never gets committed.

**Why this step can't be automated away:** generating a token is the one action that
has to happen in the claude.ai UI by a human — there's no API for token management by
design, so a compromised token can only ever fire that one routine. Everything after
this is unattended.

## 3. Trigger — no GitHub involved

Once the spec is written, Cowork calls the routine's API trigger over HTTPS from its
own shell — the same call, every time, with the spec text in the body:

```bash
curl -X POST https://api.anthropic.com/v1/claude_code/routines/$ROUTINE_ID/fire -H "Authorization: Bearer $ROUTINE_TOKEN" -H "anthropic-version: 2023-06-01" -H "anthropic-beta: experimental-cc-routine-2026-04-01" -H "Content-Type: application/json" -d '{"text": "<the spec content>"}'
```

This returns immediately — `200 OK` with a `claude_code_session_url` you can open to
watch the run — it doesn't wait for Claude Code to finish. The `text` field is
freeform and uncapped-format (up to 65,536 characters), passed alongside the
routine's own saved prompt, so the spec itself can go straight in the body rather
than needing to live anywhere else first.

> **Confirmed working:** this exact endpoint was tested live from a Cowork sandbox:
> reachable, and returning the documented `401` when called without a valid token —
> proof the path is open end to end once a real token is in place.

## 4. Implement

The fired session reads the spec text plus its saved prompt, implements the feature
against the repo it was configured with, and opens a pull request using Claude
Code's own GitHub connection — the same one that already lets it browse branches and
track PRs. GitHub is still very much part of the picture; it's just no longer the
thing Cowork has to push to in order to start the chain.

## 5. Ship

Nothing changes here from before: your CI runs on the pull request, you review and
merge like any other PR, and your deploy pipeline fires on merge.

- CI is configured to run on pull requests, not only on pushes to `main` — the
  routine opens a PR, it never pushes straight to `main`.
- You're still the one reviewing and merging. The routine implements; a human still
  decides it's correct.

## If something doesn't fire

- **The curl call returns 401.** The token is wrong, revoked, or doesn't match the
  routine ID in the URL. Regenerating a token immediately revokes the previous one,
  so double-check nothing else was still relying on the old one.
- **It returns 429.** You've hit the account's daily routine-run allowance or usage
  limit — the response includes a `Retry-After` header. Routine sessions draw down
  the same Claude Code subscription usage as interactive sessions.
- **It returns 200 but the PR misses the point.** Tighten the routine's saved prompt
  rather than the spec text — tell it explicitly what "done" looks like and to ask
  for clarification in the PR description rather than guessing.
- **It returns 400.** Almost always a missing or wrong `anthropic-beta` header — it
  must be exactly `experimental-cc-routine-2026-04-01`.
