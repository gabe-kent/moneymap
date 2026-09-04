# Claude Code permission modes: gotchas and recommendations

Claude Code prompts for permission before file edits, shell commands, and other
tool calls by default — useful, but it adds up fast across a long session. Several
modes exist to cut that down, with different tradeoffs. This doc exists so the
tradeoffs are known, not to talk anyone out of any particular mode — the user's own
practice for local sessions on this repo is `bypassPermissions`, and the gotchas
below are "know this" context for using it well, not warnings against using it.

## The modes, least to most permissive

| Mode | What it does | Where it's set |
|---|---|---|
| **default** | Prompts for anything not already allowlisted. | Out of the box. |
| **acceptEdits** | Auto-approves file edits and common filesystem commands; still prompts for anything riskier. | `/permissions`, Shift+Tab cycle, or `defaultMode` in settings. |
| **auto** | A safety classifier reviews actions in the background and auto-approves what it judges safe, still catching suspicious patterns. The default on Pro/Max/Team plans. | Same as above. |
| **dontAsk** | Only tools/commands that match an explicit `permissions.allow` rule run at all; everything else is refused rather than prompted. Good for CI or routines with a known, fixed set of needed commands. | `permissions.allow` rules + `defaultMode: "dontAsk"` in settings. |
| **bypassPermissions** | Skips essentially all permission prompts. **The user's preferred local default for this repo** — see the gotchas below for what it's actually trading away. | `--dangerously-skip-permissions` (CLI flag), or `defaultMode: "bypassPermissions"` in settings. Not available in cloud sessions at all (see below). |

`.claude/settings.local.json` (gitignored — personal, not shared with other
collaborators or cloud sessions) is where this is configured for local sessions on
this repo:

```json
{
  "permissions": {
    "defaultMode": "bypassPermissions"
  }
}
```

This doesn't apply to Claude Code cloud sessions, which don't offer the mode at
all (see below) — `auto` is the practical default there, not a fallback choice.

## Things worth knowing about `bypassPermissions`

**Not available in Claude Code cloud sessions at all.** Cloud sessions
(code.claude.com) only offer Accept Edits, Plan, and Auto — `bypassPermissions`
isn't one of the options in the mode dropdown, and setting
`"defaultMode": "bypassPermissions"` in a settings file that a cloud session reads
is **silently ignored** there, not an error. Worth knowing so nobody wonders why
it's "not working" in a cloud session — it's simply not offered, not broken.

**It doesn't actually skip everything.** These stay enforced even in bypass mode:
- Explicit `permissions.ask` rules
- Critical-path protections — `rm`/`rmdir` on `/`, your home directory, or the
  current working directory still prompts, as a circuit breaker against a model
  mistake
- MCP tools marked `requiresUserInteraction`
- The approval Claude Code asks before messaging another session/machine
  (`isolatePeerMachines`)

**Refuses to run as root/sudo** on Linux/macOS — unless it detects it's inside a
recognized sandbox (Docker, a dev container), where that check is auto-bypassed.

**First use requires accepting a one-time responsibility dialog** in an
interactive session. A background session (`--bg`) started before that dialog has
ever been accepted is refused, even with the flag set.

**No protection against prompt injection.** Explicit in Claude Code's own docs:
bypass mode doesn't distinguish a legitimate instruction from one smuggled in
through a file, web page, or tool output — it just stops asking either way. Auto
mode's background safety checks are the thing that actually defends against that;
bypass mode has none of them. Worth being a little more deliberate about what
untrusted content (web pages, third-party files) a bypass-mode session is exposed
to, since there's no second layer catching an injected instruction.

**Keep it in `.claude/settings.local.json`, not the shared `.claude/settings.json`.**
Not because bypass mode itself is discouraged — because a shared, committed
settings file applies to every collaborator who clones the repo, and this is a
personal preference, not a repo-wide one. It's also a no-op in cloud sessions
either way (see above), so there's no upside to putting it in the shared file.

## Official guidance, for context

Anthropic's own docs recommend restricting `bypassPermissions` to an isolated
container or VM without internet access. That's a conservative, general-audience
default — for local dev on this repo specifically (a personal project, no
production secrets or real user data on the dev machine), the user's own call is
that the tradeoffs above are acceptable for day-to-day local sessions. The one
thing worth actually avoiding regardless: a machine that also holds unrelated
production credentials, or a long-running bypass-mode session pointed at untrusted
input (see the prompt-injection note above).
