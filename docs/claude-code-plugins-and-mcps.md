# Claude Code Plugins & MCP Servers — Recommended Setup

This documents the Claude Code plugins and MCP servers configured while building moneymap, as
a reference for setting up a new machine or a new project the same way.

**Scope note:** unlike the rest of this repo's docs, this config isn't project-specific —
plugins live in `~/.claude/settings.json` (`enabledPlugins`) and apply to *every* project you
open Claude Code in, not just moneymap. It's recorded here because this project is where it was
assembled, as a companion to `environment-setup-runbook.md` (which covers the Render MCP server
specifically, in Phase 2 Step 8, since that one's more naturally tied to the deploy story).

---

## MCP servers

| Server | Transport | Scope | Purpose |
|---|---|---|---|
| `render` | HTTP (`https://mcp.render.com/mcp`) | local (this project only) | Query the Render account from chat — services, deploys, logs, env vars — without SSH. See runbook Phase 2 Step 8 for the exact setup command; the free plan has no SSH/console access, so this is the practical substitute. |

Two plugins below (`playwright`, `github`) also bundle their own MCP servers — see the table
below. `claude mcp list` shows everything currently connected regardless of whether it came from
a plugin or a manual `claude mcp add`.

---

## Plugins

All installed from the `claude-plugins-official` marketplace unless noted. Grouped by what
they're for, not alphabetically.

### Core workflow
| Plugin | What it does |
|---|---|
| `superpowers` | Planning, TDD, and debugging methodology as invocable skills (brainstorming, systematic-debugging, writing-plans, etc.) — the skill set this session's workflow is built on. |
| `feature-dev` | End-to-end feature workflow: codebase exploration → architecture design → implementation → review, via specialized subagents. |
| `claude-md-management` | Audits and updates CLAUDE.md files — quality checks, capturing session learnings, keeping project memory current. |

### Code quality
| Plugin | What it does |
|---|---|
| `code-review` | Multi-agent PR/diff review with confidence-based filtering (`/code-review`, and the "ultra" cloud-fleet variant). |
| `code-simplifier` | Simplifies recently-changed code for clarity/consistency without changing behavior. |

### Docs & research
| Plugin | What it does |
|---|---|
| `context7` | Live, version-specific library/framework docs (Rails, DaisyUI, etc.) pulled into context instead of relying on training-data recall. Hosted MCP server, no local Node/npx needed. |

### Browser & GitHub integration (MCP-backed)
| Plugin | What it does |
|---|---|
| `playwright` | Microsoft's browser-automation MCP — screenshots, form fills, clicks, end-to-end test flows. Useful for the "test UI changes in a real browser" step this project's CLAUDE.md calls for. |
| `github` | Official GitHub MCP — issues, PRs, code review, repo search against the full GitHub API from chat. |

### Meta / tooling
| Plugin | What it does |
|---|---|
| `skill-creator` | Scaffolds, edits, and evals custom skills. |
| `ralph-loop` | Runs Claude in a loop against the same prompt until a task completes (the "Ralph Wiggum technique"). |
| `claude-mem` | Persists context/observations across sessions into a local memory database (separate system from this repo's `memory/` directory, which is this harness's own memory feature). |
| `frontend-design` | Aesthetic/UX guidance for building or reshaping UI so it doesn't read as generic defaults. |

### Style (optional)
| Plugin | What it does |
|---|---|
| `caveman` | Ultra-compressed "caveman mode" responses (`/cs:caveman`) — cuts filler for terse output when token budget matters more than prose. Personal preference, not a dev-workflow necessity. |

⚠️ **Known duplication to clean up:** `superpowers` and `caveman` are each installed **twice**
from two different marketplaces (`superpowers@superpowers-dev` + `superpowers@claude-plugins-official`;
`caveman@claude-code-skills` + `caveman@caveman`) — visible in `~/.claude/settings.json`'s
`enabledPlugins`. Harmless (same skills, redundant registration) but worth trimming with
`claude plugin uninstall <name>@<marketplace>` next time you're in there, keeping the
`claude-plugins-official` / newer copy.

---

## Replicating this on a new machine

```bash
# Marketplaces used above, beyond the built-in claude-plugins-official
claude plugin marketplace add https://github.com/obra/superpowers.git        # superpowers-dev
claude plugin marketplace add https://github.com/thedotmack/claude-mem.git   # thedotmack

# Install (official marketplace plugins resolve without adding a marketplace first)
claude plugin install superpowers@claude-plugins-official
claude plugin install frontend-design@claude-plugins-official
claude plugin install context7@claude-plugins-official
claude plugin install code-review@claude-plugins-official
claude plugin install code-simplifier@claude-plugins-official
claude plugin install feature-dev@claude-plugins-official
claude plugin install claude-md-management@claude-plugins-official
claude plugin install skill-creator@claude-plugins-official
claude plugin install ralph-loop@claude-plugins-official
claude plugin install playwright@claude-plugins-official
claude plugin install github@claude-plugins-official
claude plugin install claude-mem@thedotmack

# Render MCP server — see environment-setup-runbook.md Phase 2 Step 8
claude mcp add --transport http render https://mcp.render.com/mcp \
  --header "Authorization: Bearer <RENDER_API_KEY>"
```

Skip `caveman` unless you specifically want the compressed-output style — it's not part of the
core dev workflow above.

*Living document — update when a plugin gets added, removed, or replaced.*
