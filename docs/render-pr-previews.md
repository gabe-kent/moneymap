# Render Pull Request Previews

Render's own per-PR preview feature, distinct from both this repo's (currently paused) `staging`
environment and from Render's separate **Preview Environments** product. Documented here because
the Render dashboard surfaced it on the `moneymap` service's **Previews** tab:

> Spin up temporary instances to test pull requests opened against the main branch of
> gabe-kent/moneymap. Choose Automatic to preview all PRs, or Manual for only PRs with
> `[render preview]` in their title. Pull Request Previews create a new instance for just this
> service. Use Preview Environments to clone a group of services for every PR.

This doc is about that first option — **Pull Request Previews** (Render's docs also call this
**Service Previews**) — not Preview Environments. Not enabled yet; this is groundwork for
deciding whether to, given a real safety gotcha below.

## What it actually is

- A **free-plan-compatible** feature ([Render docs](https://render.com/docs/free)) — unlike
  Preview Environments, which [require a Pro plan or higher](https://render.com/docs/preview-environments).
  Confirmed separately from the dashboard's own wording above ("Pull Request Previews create a
  new instance for just this service" vs. "Preview Environments... clone a group of services").
- Per-service, not per-repo: each service (here, just `moneymap`) has its own **Previews** tab
  and its own on/off setting.
- **Automatic** mode previews every PR opened against the service's tracked branch (currently
  `main`); opt a specific PR out with a `render-preview-skip` label or `[skip preview]` in its
  title. **Manual** mode previews nothing by default — add the `render-preview` label or put
  `[render preview]` in the PR title to opt one in.
- Each preview gets its own temporary `onrender.com` URL, deployed from that PR's branch.
  Render deletes the preview instance automatically when the PR merges or closes — no standing
  resource, unlike `moneymap-staging`'s continuously-running service.
- Version-controllable: the Blueprint spec supports a `previews.generation: automatic|manual`
  field per service in `render.yaml`, so this can be declared there instead of only toggled in
  the dashboard.

## The gotcha that matters here: database sharing

**Preview instances copy their parent service's environment variables when created — including
`DATABASE_URL`.** Render's own docs warn: "change environment variables on your preview instance
if you want it to use a staging or test database." Left unchanged, enabling this on the `moneymap`
service means every PR preview boots against the **live production Postgres**, running whatever
code is in that PR.

This repo has no spare database to hand previews instead: the one free Postgres instance
(`moneymap-db`) is already shared between production and (when unpaused) `moneymap-staging`'s
separate `moneymap_staging` database — see `staging-environment-setup.md`. A preview instance
could point at that same `moneymap_staging` database, but previews are far more numerous and
transient than one persistent staging service; two PR previews open at once would both migrate
and write against the same database simultaneously, which is a worse collision risk than staging
sharing an instance with production ever was (staging only ever has one thing running against it
at a time). There isn't a clean free-tier answer here yet — either accept that a preview only
proves "does it boot and respond on `/up`" without touching real data (impractical, since normal
use immediately hits the database), or budget for previews to get their own database, which
reopens the "second Postgres costs money" tradeoff from the staging decision.

**Do not enable this on `moneymap` without first setting an override `DATABASE_URL`** (and
`RAILS_MASTER_KEY`, same as staging needed) on the Previews tab's environment-variable settings —
otherwise every preview is a live write path into production data.

## How this relates to `staging`

Genuinely different tools, not competing ones:

- `staging` (`docs/staging-environment-setup.md`, currently paused) is one persistent,
  hand-promoted environment for a deliberate pre-prod QA step.
- PR Previews are many small, automatic, ephemeral, per-PR instances — closer to "does this
  boot" smoke-testing than a QA environment, given the database-sharing constraint above.

They could complement each other once staging resumes (a preview as a fast sanity check before a
PR even reaches `staging`), or serve as a lighter stand-in while staging is paused — but only
once the database question above has an actual answer, not left defaulting to production.
