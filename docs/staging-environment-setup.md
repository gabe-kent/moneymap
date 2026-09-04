# Staging environment setup (Render)

A second, `staging`-branch Render deployment for verifying changes before they reach
production. Production (`main` -> `moneymap` service, `render.yaml`) is untouched by any of
this — this doc only covers the new `staging` -> `moneymap-staging` side.

## Why this looks the way it does

Render only allows **one free Postgres database per workspace**
([docs](https://render.com/docs/free)), and production's `moneymap-db` already uses it. Rather
than pay for a second Postgres instance before this app has real users, staging shares
production's existing free Postgres *instance* but gets its own *database* on it
(`moneymap_staging`, separate from production's database) — so staging and production data
never mix, but both still live on the one free instance.

The real tradeoff: that free instance's existing 30-day expiry / manual-recreation cycle (see
`environment-setup-runbook.md`) now affects staging too — recreating the instance means
recreating staging's database as well, and the two share the instance's 1GB storage cap. That's
an acceptable stopgap for a pre-product app; revisit with a dedicated paid staging Postgres once
there's real usage (see `CLAUDE.md`'s "before real users/data" note).

Render also doesn't support turning one `render.yaml` into two named environments — resource
names must be unique within a single Blueprint file, and one Blueprint instance syncs from one
branch. Hence the separate `render.staging.yaml`, set up as its own Blueprint in the dashboard.

## One-time setup

### 1. Create the `moneymap_staging` database on the existing Postgres instance

In the Render dashboard, open `moneymap-db` -> **Connect** -> copy the **External Database URL**
(needed for `psql` from your machine; the *Internal* one only resolves inside Render's network).
It looks like:

```
postgres://moneymap_db_user:<password>@<host>.render.com/moneymap_db
```

Connect to the server (not a particular database matters here — any DB on that instance works
for issuing `CREATE DATABASE`) and create the staging database:

```bash
psql "<external-database-url>" -c "CREATE DATABASE moneymap_staging;"
```

### 2. Build staging's `DATABASE_URL`

Take the **Internal Database URL** from that same Connect panel (same host/user/password as
production, since it's the same instance — internal is preferred for the app's own env var since
it's free and same-region) and swap the trailing database name for `moneymap_staging`:

```
postgres://moneymap_db_user:<password>@<internal-host>/moneymap_staging
```

Keep this value somewhere safe for step 4 — don't commit it.

### 3. Create the staging Blueprint

Render dashboard -> **New** -> **Blueprint** -> select this repo -> branch **`staging`** ->
Blueprint file path **`render.staging.yaml`**. This provisions the `moneymap-staging` web
service only (no database — see above). The first deploy will fail health checks until step 4
sets the required secrets.

### 4. Set the manual secrets

On the `moneymap-staging` service -> **Environment**, set:

- `RAILS_MASTER_KEY` — same value as production's (same `config/credentials.yml.enc`; there's no
  staging-specific credentials file in this repo).
- `DATABASE_URL` — the value built in step 2.
- Optionally `SEED_ADMIN_EMAIL` / `SEED_ADMIN_PASSWORD` to seed a login on staging, same as
  production (see `db/seeds.rb`).

Trigger a manual deploy after setting these. `bin/docker-entrypoint`'s `db:prepare` +
`db:prepare_solid_schemas` calls run exactly as they do in production, against
`moneymap_staging` instead — no app-code changes needed for any of this.

## Day-to-day workflow

```
feature branch -> PR -> merge into `staging` -> auto-deploys to moneymap-staging -> verify
                                              -> merge/fast-forward `staging` into `main` -> auto-deploys to production
```

`staging` and `main` should generally stay in sync in that direction — don't let `staging` drift
permanently ahead without periodically promoting it, or the two environments stop meaning
anything.
