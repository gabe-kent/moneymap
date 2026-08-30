# Component library options, by framework

A working comparison of the tools that generate a design system's tokens, and the
component libraries that turn those tokens into a sleek, modern-looking website or
app — organized by which framework each one actually fits. Complements
`docs/design-system-options.md`, which covers Blueprint and OpenDesign (the two token
generators) in more depth; this doc adds the broader landscape of component
libraries by ecosystem.

Component libraries and their underlying primitives move fast — shadcn/ui alone
changed its primitive layer once in the past year. Treat the ecosystem groupings here
as current as of this writing, not permanent.

## Two different jobs

Everything below falls into one of two categories, and mixing them up is the most
common way this research goes sideways.

- **Token & theme generators** — take a brand color, logo, or reference site and
  output a color scale, type scale, and spacing/shadow system — as CSS variables,
  Figma, or both. They don't render any UI themselves; you feed the output into
  whatever you're already using.
- **Component libraries** — ready-made buttons, forms, dialogs, nav bars — the actual
  UI you assemble a page from. Each one is tied to an ecosystem (React, Vue, Svelte,
  or plain server-rendered HTML), which is the part worth matching to your framework
  before you fall in love with a look.

## Token & theme generators

| Tool | How you use it | Output | Best for |
|---|---|---|---|
| Blueprint | Browser tool, no install — give it one brand color or a logo | Color/type/spacing/shadow scales as CSS, Figma, or an AI-ready text format | Fast, dependency-free starting tokens for one project |
| Radix Colors | Pick from pre-built, accessibility-vetted 12-step scales | CSS custom properties | Replacing an auto-derived scale with one that's already been contrast-checked |
| TweakCN | Browser editor with live preview — tune color, radius, shadow, type together | CSS variables matching shadcn/ui's token shape | Anyone already using or adapting the shadcn token structure |
| OpenDesign | Local agent platform (desktop app or Docker) that drives coding agents from a shared brand file | A `DESIGN.md` spec plus compiled `tokens.css`, from 151 bundled systems or an extracted brand | Projects generating many branded artifacts — decks, prototypes, dashboards — not just one app's theme |

**How they compose:** all four just produce CSS custom properties (or a Figma file) —
none of them lock you into a framework. Whatever comes out gets hand-mapped into your
actual component library's theme layer, whether that's a Tailwind `@theme` block, a
DaisyUI theme object, or a shadcn `globals.css`.

## Component libraries, by ecosystem

This is the half that actually determines what you can use — a library built for
React doesn't run in a server-rendered Rails or Django view, no matter how good its
theme looks.

**React / Next.js**

| Library | Aesthetic & notes |
|---|---|
| shadcn/ui | Sets the current bar for "sleek modern" — copy-paste components you own outright, not an installed package. Switched its underlying primitives from Radix to Base UI in mid-2026. |
| Mantine | Larger, more traditional full-featured library — less trend-forward, very complete out of the box. |
| HeroUI | Tailwind + React Aria, a close shadcn alternative with more built-in styling decisions made for you. |
| Untitled UI (React) | Premium, extremely polished design system with a matching Figma kit — paid, but among the most refined available. |

**Vue / Nuxt**

| Library | Aesthetic & notes |
|---|---|
| PrimeVue | The long-standing, broad, mature Vue component set. |
| Naive UI | Cleaner, more modern-looking, TypeScript-first alternative. |

**Svelte / SvelteKit**

| Library | Aesthetic & notes |
|---|---|
| shadcn-svelte | Community port of shadcn's exact look and component set to Svelte. |
| Skeleton | Native Svelte + Tailwind system with its own theming approach. |

**Server-rendered / no JS framework (Rails, Django, Laravel, plain HTML)**

| Library | Aesthetic & notes |
|---|---|
| DaisyUI | Fast, opinionated, ships 30+ built-in themes as pure CSS classes — what Moneymap already uses. |
| Basecoat UI | Rebuilds shadcn/ui's exact aesthetic and components as plain Tailwind classes plus minimal vanilla JS — the most direct route to "the" current sleek look without React. |
| Franken UI | Similar HTML-first goal to Basecoat, built on top of UIkit's JS. |
| Preline UI | 800+ prebuilt blocks and page patterns, plain Tailwind + optional light JS — good for assembling full pages fast. |
| Tailwind Plus (HTML kit) | The Tailwind team's own premium library — paid, but arguably the single most polished option, and ships a plain-HTML variant alongside its React/Vue ones. |

## Plain website vs. web app

These two call for different priorities, not just different templates.

- **Marketing / content site — motion and visual flourish earn their keep.**
  Aceternity UI and Magic UI (both React + Framer Motion) currently set the bar for
  animated, scroll-triggered landing pages, but they're React-only. On a
  server-rendered stack, Tailwind Plus's marketing blocks or Preline's landing
  templates are the closest practical equivalent — start from those and add motion by
  hand with CSS.
- **Web app / product UI — consistency and accessibility beat flash.** This is
  exactly what shadcn/ui and Basecoat optimize for — forms, dialogs, dropdowns, and
  tables that behave correctly by default, styled to match your brand rather than
  designed from scratch each time. Save the motion budget for a handful of deliberate
  moments, not the whole interface.

## For Moneymap specifically

- Keep the existing plan: run a brand color through Blueprint or TweakCN, and
  hand-map the exported tokens onto the current DaisyUI theme — no new dependency, no
  npm.
- Try Basecoat UI for new components going forward, alongside DaisyUI rather than
  instead of it. Both are pure Tailwind classes, so they can sit side by side while
  you compare the look before committing either way.
- Skip OpenDesign for now — it earns its complexity once there are multiple branded
  artifacts to generate (decks, marketing pages), not for one app's internal theme.

**Bottom line:** nothing here requires touching the "no Node/npm" constraint — every
option that fits Moneymap ships as plain CSS and, at most, vendored vanilla JS, the
same way DaisyUI is already installed.
