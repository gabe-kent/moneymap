# Claude surfaces: which tool for what, and how work hands off between them

Three different Claude surfaces, three different jobs — where planning happens,
where a UI actually gets designed, and where it turns into real code in this repo,
plus exactly how work moves between them.

Claude Design launched in research preview in 2026 and is still evolving quickly —
re-check the export flow if it's been a while since you last used it, since Anthropic
has already revised the handoff mechanics once.

```
Cowork  →  Claude Design  →  Claude Code
(plan)     (design)          (build)
```

Specs & research → a real, clickable prototype → working code in this repo, tested
and deployed.

## Which tool for what

All three are separate Claude surfaces with separate jobs — none of them substitute
for each other.

**1. Planning & research — Cowork.** File access, a sandboxed shell, and the ability
to research and write things down — specs, comparisons, reviews (like
`docs/repo-review-2026-08-29.md` and `docs/framework-comparison.md`). This is where
you figure out *what* to build and *why*, before anything visual exists.

**2. Visual prototyping — Claude Design.** Its own standalone product at
`claude.ai/design` — not a mode inside Chat or Claude Code. Describe a UI in plain
English and get back a real, clickable prototype (actual HTML/CSS/JS, not a static
image), which you then refine with more description or direct edits. Built
specifically for people without a design background.

**3. Real implementation — Claude Code.** Works directly in the actual repository —
edits code, runs the test suite, commits, opens pull requests. This is the only one
of the three that touches the real codebase.

## The handoff, step by step

Once a prototype in Claude Design looks right, it hands off to Claude Code directly —
no screenshot, no describing it over again from scratch.

1. **Finish the prototype in Claude Design.** Iterate by description or direct edit
   until the UI looks and behaves the way you want.
2. **Click Export → "Hand off to Claude Code."** This bundles the design files, the
   full chat history, and a README that tells a coding agent how to interpret the
   bundle.
3. **Copy the prompt it gives you.** It includes a link to the bundle, pre-written to
   hand to a coding agent.
4. **Paste it into a Claude Code session** pointed at the actual repo. Claude Code
   reads the bundle and implements it preserving the real component choices and
   structure, not reinterpreting a picture.

**Also works the other way:** from inside a Claude Code terminal, the `/design`
command creates, edits, and syncs a design project without leaving Claude Code at
all — useful once a project has design and code changing together rather than one
big upfront handoff.

## For Moneymap

This maps directly onto the open UI work from `docs/repo-review-2026-08-29.md`.
Rather than describing the home dashboard and the auth-view look to Claude Code in
words and hoping the result matches what you picture, design it visually first:

1. **Prototype the dashboard in Claude Design.** Total balance, spending by category,
   recent transactions — get the layout and look right as a clickable mockup before
   any Rails code exists.
2. **Hand it off to Claude Code.** Point that Claude Code session at the Moneymap
   repo so it translates the prototype into real Hotwire views styled with the app's
   existing DaisyUI classes, rather than a generic React/JS implementation.
3. **Keep Cowork for the parts that aren't visual.** Config and code changes like a
   mailer host fix, `rack-attack`, and `force_ssl` never needed a design pass — those
   are still best done directly in a Claude Code/Cowork session.
