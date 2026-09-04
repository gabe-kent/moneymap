# Claude Code permission modes: gotchas and recommendations

Claude Code prompts for permission before file edits, shell commands, and other
tool calls by default — useful, but it adds up fast across a long session. Several
modes exist to cut that down, with very different safety tradeoffs. This doc exists
so nobody reaches for the most aggressive one (`bypassPermissions`) without knowing
what it actually gives up, and so cloud sessions don't waste time on a setting that
silently doesn't apply to them.

## The modes, least to most permissive

| Mode | What it does | Where it's set |
|---|---|---|
| **default** | Prompts for anything not already allowlisted. | Out of the box. |
| **acceptEdits** | Auto-approves file edits and common filesystem commands; still prompts for anything riskier. | `/permissions`, Shift+Tab cycle, or `defaultMode` in settings. |
| **auto** | A safety classifier reviews actions in the background and auto-approves what it judges safe, still catching suspicious patterns. **Recommended default** for cutting prompt fatigue without giving up the safety net — it's already the default on Pro/Max/Team plans. | Same as above. |
| **dontAsk** | Only tools/commands that match an explicit `permissions.allow` rule run at all; everything else is refused rather than prompted. Good for CI or routines with a known, fixed set of needed commands. | `permissions.allow` rules + `defaultMode: "dontAsk"` in settings. |
| **bypassPermissions** | Skips essentially all permission prompts. See gotchas below before reaching for this one. | `--dangerously-skip-permissions` (CLI flag), or `defaultMode: "bypassPermissions"` in settings. Not available in cloud sessions at all (see below). |

For most day-to-day work in this repo, **`auto` mode is the right default** — it's
already what you get on a Pro/Max/Team plan without changing anything. Reach for
`dontAsk` with an explicit allowlist for something narrow and repeatable (a routine,
a CI-like task), not `bypassPermissions`, which the rest of this doc is about.

## Gotchas with `bypassPermissions` / `--dangerously-skip-permissions`

⚠️ **Not available in Claude Code cloud sessions at all.** Cloud sessions
(code.claude.com) only offer Accept Edits, Plan, and Auto — `bypassPermissions`
isn't one of the options in the mode dropdown, and setting
`"defaultMode": "bypassPermissions"` in a settings file that a cloud session reads
is **silently ignored** there, not an error. Since this repo's primary workflow is
Claude Code cloud sessions (see `docs/getting-started.md`), this mode mostly matters
for local sessions only.

⚠️ **It doesn't actually skip everything.** These stay enforced even in bypass mode:
- Explicit `permissions.ask` rules
- Critical-path protections — `rm`/`rmdir` on `/`, your home directory, or the
  current working directory still prompts, as a circuit breaker against a model
  mistake
- MCP tools marked `requiresUserInteraction`
- The approval Claude Code asks before messaging another session/machine
  (`isolatePeerMachines`)

⚠️ **It refuses to run as root/sudo** on Linux/macOS, specifically for the
scenario where a mistake could do real damage — unless it detects it's inside a
recognized sandbox (Docker, a dev container), where that check is auto-bypassed.

⚠️ **First use requires accepting a one-time responsibility dialog** in an
interactive session. A background session (`--bg`) started before that dialog has
ever been accepted is refused, even with the flag set.

⚠️ **No protection against prompt injection.** This is explicit in Claude Code's own
docs: bypass mode doesn't distinguish a legitimate instruction from one smuggled in
through a file, web page, or tool output — it just stops asking either way. Auto
mode's background safety checks are the thing actually defending against that, and
bypass mode has none of them.

⚠️ **Never check `"defaultMode": "bypassPermissions"` into a shared/committed
settings file.** It won't do anything in a cloud session (silently ignored), but it
will in a terminal session for anyone who clones this repo and runs Claude Code
locally — a footgun for a collaborator who didn't ask for it. If you want it for
your own local sessions, put it in `.claude/settings.local.json`, which is
gitignored (see below), never in `.claude/settings.json`.

## When it's actually appropriate

Official guidance: **only in an isolated environment — a container or VM without
internet access, where Claude Code can't damage anything you'd care about losing.**
Not your primary development machine, not a machine with real credentials or
production access, not a long-running terminal session you might forget is still in
bypass mode.

- ✅ A disposable container/VM with no real secrets or network access
- ❌ Your laptop, or any machine with SSH keys, cloud credentials, or access to
  this repo's production secrets
- ❌ A Claude Code cloud session — moot anyway, since it isn't offered there

## What to use instead, day to day

- **`auto` mode** for normal interactive work — already the default on paid plans,
  cuts prompt volume with the safety classifier still running.
- **`permissions.allow` rules** to pre-approve specific, known-safe commands
  without a blanket bypass — e.g. `Bash(bin/rails test *)` or `Bash(git commit *)`
  in `.claude/settings.json` (shared, safe to commit) or
  `.claude/settings.local.json` (personal, gitignored).
- **`dontAsk` mode with an explicit allowlist** for something narrow and repeatable,
  like a Routine's fixed task — refuses anything outside the allowlist rather than
  prompting or silently allowing it.

`.claude/settings.local.json` is gitignored in this repo (see `.gitignore`) for
exactly this — personal permission tweaks that shouldn't apply to every
collaborator who clones the repo.
