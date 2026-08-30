# Design system options

Notes on tools for generating a design system (color scales, type scale, spacing,
components), and how each would fit this repo. Written against the two tools the
user pointed at:

- Blueprint — https://designsystem-generator-bbs.vercel.app/ (canonical: blueprint.design)
- OpenDesign — https://github.com/nexu-io/open-design

Current state for context: this repo already has a UI kit — **DaisyUI + Lucide**,
installed without npm/Node (see CLAUDE.md → Conventions). Any design-system tool
either needs to produce output compatible with that (CSS variables / Tailwind
theme values it can feed into `app/assets/tailwind/application.css`), or would be
a candidate for *replacing* DaisyUI's theme layer rather than sitting alongside it.

## Option 1: Blueprint (designsystem-generator-bbs.vercel.app)

A free single-page web app. No signup, no local install — you use it in the browser.

**What it does:** turns one brand color (or an uploaded image) into a starter
design system:
- Accessible color scales (brand + neutrals + semantic colors, e.g. success/error)
- A complete type scale
- Spacing and shadow scales
- Production-ready components, built "variables-first" so changing a token
  updates every component that references it

**Output formats:** Figma, CSS, and "AI-ready" formats (i.e. text/markdown meant
to be pasted into an AI coding agent's context).

**Steps to use it:**
1. Open https://designsystem-generator-bbs.vercel.app/
2. Provide a brand color (hex) or upload a logo/image to derive one
3. Review the generated color scale, type scale, spacing, and shadow tokens
4. Export as CSS (or Figma, if using Figma) or copy the AI-ready format
5. Translate the exported CSS custom properties into this repo's Tailwind v4
   theme, either:
   - as `@theme` tokens in `app/assets/tailwind/application.css`, or
   - as a DaisyUI custom theme (DaisyUI themes are just a set of CSS variables —
     see `daisyui-theme.js` already vendored in this repo)
6. Re-run `bin/rails tailwindcss:build` to pick up the changes

**Fit for this repo:** good — it's just a browser tool producing CSS, no
Node/npm dependency, so it doesn't conflict with the "no build step" constraint.
It's a *token generator*, not a competing framework — it slots in as an input to
the existing DaisyUI theme rather than replacing it.

**Caveats:** it's a small, single-author project (per its own metadata) with no
visible source repo linked from the page — treat generated output as a starting
point to hand-tune, not a maintained dependency you'd track for updates.

## Option 2: OpenDesign (github.com/nexu-io/open-design)

A much larger, actively developed (Apache-2.0) open-source project — "the
open-source Claude Design alternative." This is not a design-token generator;
it's a local-first **agent platform** that drives coding-agent CLIs (Claude
Code, Cursor, Codex, and 20+ others) to generate whole artifacts — prototypes,
dashboards, decks, mobile UI, video — using a design system as the shared brand
contract.

**What it does, relevant to "generate our own design system":**
- Ships 151 existing brand-grade design-system packages, each centered on a
  portable `DESIGN.md` file (+ compiled `tokens.css`, components, assets)
- Can *extract* a design system from an existing brand by importing a
  screenshot or a URL — the agent codifies the visual language into a reusable
  `DESIGN.md` + token set
- Switching design systems re-applies tokens to the next render automatically

**Tech stack:** Next.js/React/TypeScript frontend, Node/Express/SQLite backend,
Electron desktop shell. Runs locally (desktop app, Docker, or built from
source); no cloud requirement, though there's a paid "OpenDesign Cloud" option
for hosted models.

**Steps to use it:**
1. Install: desktop app from open-design.ai (zero-config, auto-detects local
   CLIs), or `docker compose up -d` from a clone, or build from source
   (`pnpm install && pnpm tools-dev run web`)
2. `od mcp install claude` to wire it into Claude Code as an MCP server (or use
   the desktop app directly)
3. From Home, submit a design-system brief: paste a brand color/URL/screenshot,
   or pick one of the 151 bundled packages as a starting point
4. Iterate in the Design System studio view until the token set / component
   previews look right
5. Export the resulting `DESIGN.md` + `tokens.css` and adapt the CSS variables
   into this repo's Tailwind theme, same as Option 1 step 5

**Fit for this repo:** heavier than what's needed here. It's built around
Node/npm tooling and a whole agent-orchestration workflow, which is a mismatch
for a repo that deliberately has no npm/Node toolchain and no product-specific
design work yet (per CLAUDE.md, still bootstrap stage). It would be worth
revisiting if/when this project needs to generate multiple polished artifact
types (marketing decks, multiple themed prototypes) rather than one consistent
app UI.

## Recommendation

For where this repo actually is — one Rails app, DaisyUI already chosen,
explicitly no Node/npm — **Blueprint is the better fit**: pick a brand color,
export CSS tokens, hand-adapt them into a DaisyUI custom theme. OpenDesign is
worth a look later only if the project grows into needing generated
marketing/prototype artifacts beyond the app's own UI, at which point it'd
compete with DaisyUI rather than feed it.

## Steps to generate a design system for Moneymap, concretely

1. Pick a brand/primary color (something distinct from DaisyUI's stock themes)
2. Generate scales in Blueprint from that color; export CSS
3. Map the exported tokens onto a new DaisyUI theme object (see
   `app/assets/tailwind/vendor/daisyui-theme.js` for the existing theme shape —
   `primary`, `secondary`, `accent`, `neutral`, `base-100/200/300`,
   `success`/`warning`/`error`/`info`, plus radius/size/border tokens)
4. Add the new theme via `@plugin "daisyui/theme" { ... }` in
   `app/assets/tailwind/application.css` (same mechanism already used to load
   DaisyUI itself)
5. Run `bin/rails tailwindcss:build` and spot-check components (buttons, forms,
   alerts) in the browser against the new theme
6. Commit the generated tokens file alongside the theme change so the source
   values (not just the derived CSS) are tracked
