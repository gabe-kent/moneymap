# Production launch: TBD costs and hardening

Everything currently running (Render free web + free Postgres, a public GitHub repo, Claude Code
on whatever plan you're on today) works because there's no real user base yet. This doc collects
what's still open before that changes: actual dollar costs at that point, and security/auth gaps
worth closing before real people put real financial data into this app.

**Not a to-do list to execute now** — pricing shifts, and closing every gap below before there's
a single real user would be solving problems that don't exist yet. Re-verify prices at the vendor
before budgeting off this doc; it's dated 2026-09-04.

See also `docs/repo-review-2026-08-29.md` for a broader, code-level review (dashboard UI,
performance, some of the same hardening items) — this doc focuses on cost and the security/auth
gaps that review didn't cover. `CLAUDE.md`'s **Conventions → Security** section turns several of
the findings below into standing rules for new code (encrypt new sensitive columns by default,
throttle new sensitive endpoints, etc.) — this doc is the current backlog those rules exist to
stop from growing.

## Costs that are currently $0 but won't stay that way

| Item | Free today because... | Cost once that changes |
|---|---|---|
| **GitHub repo** | This repo is currently **public** (`gh repo view` confirms it) — public repos get unlimited Actions minutes and no branch-protection restrictions. | Private repos are still free to create (unlimited private repos on GitHub Free), but Actions minutes drop to **2,000/month**, and — the less obvious one — **required PR reviewers, required status checks, and CODEOWNERS enforcement on a private repo need a paid plan** (historically GitHub Pro; GitHub's current pricing page no longer lists a separate Pro tier, so verify at [github.com/pricing](https://github.com/pricing) which tier now covers this for a single-owner private repo — **GitHub Team is $4/user/month, 3,000 Actions min/month** if Pro really is gone). This matters here specifically: `.github/workflows/promote-staging.yml` and the whole staging→main promotion flow assume PRs are reviewable/mergeable through normal GitHub UI, but nothing today *enforces* review — going private without checking this could silently remove the ability to require it. |
| **Render web service** | Free plan: spins down after 15 min idle, ~1 min cold start, no persistent disk, no SSH/shell access. | **Starter: ~$7/month** for an always-on instance (512MB/0.5 CPU) — the natural first upgrade once cold-start latency or spin-down actually annoys a real user. |
| **Render Postgres** | Free plan: 1GB storage, **expires 30 days after creation** (the recreation cycle already documented in `environment-setup-runbook.md`), no backups. | **Basic-256mb: ~$6/month** minimum for a paid instance — no more 30-day expiry, and backups become available. Point-in-time-recovery window is set by *workspace* billing tier, not database size: a Hobby workspace caps at 3-day PITR regardless of database plan; extending to 7-day PITR needs a **Pro workspace at $25/user/month**. Budget roughly **$13/month** (Starter web + Basic Postgres) as the realistic floor for "actually production, actually backed up, actually always-on," before the PITR upgrade. |
| **Claude Code cloud sessions** | Free/whatever plan you're on covers local CLI use; cloud sessions (web sessions, `claude --cloud`, Routines — everything `docs/cloud-environment-setup.md` covers) are in research preview and gated to paid plans. | **Pro: $20/month** ($17/month billed annually) is the minimum plan that unlocks Claude Code cloud sessions at all — confirmed against [claude.com/pricing](https://claude.com/pricing). No extra per-session compute charge beyond the plan itself. **Max ($100+/month)** buys more usage headroom, not new capability, if Pro's usage caps become the actual bottleneck. |

**Not yet accounted for anywhere, worth budgeting when they come up:**
- **Outgoing email** — `config/environments/production.rb`'s SMTP settings are still commented
  out (see `repo-review-2026-08-29.md`); password-reset emails don't actually send yet. Resend
  and Postmark both have usable free tiers (low-thousands of emails/month) that likely cover this
  app's volume for a long time, but pick one and set it up before real users need password resets.
- **Error monitoring** — also flagged as not-yet-wired in the existing review. Sentry's and
  Honeybadger's free tiers are generous enough that this may never actually cost money at this
  app's scale, but it's a signup + setup step, not a $0 non-issue.
- **A custom domain** — currently on the Render-assigned `moneymap-1rbv.onrender.com`. A domain
  is typically $10-15/year regardless of registrar; Render doesn't charge extra to point one at a
  service.

## Security and auth hardening

Checked directly against this repo's current code (`app/controllers`, `config/initializers`,
`config/environments/production.rb`) on 2026-09-04, not from memory — some of this overlaps
`repo-review-2026-08-29.md`; only what's new or unresolved is listed here.

**Already solid, no action needed:** `force_ssl`, rack-attack rate-limiting on login/password-reset
(by IP and by email address, so a distributed attack against one account is still slowed), Rails
8's own `rate_limit` on the same endpoints, enumeration-safe password-reset messaging, session
destruction on password change, `bcrypt` via `has_secure_password`, the admin namespace properly
gated on `current_user.admin?` (not just "logged in"), `filter_parameters` already covering
`ssn`/`cvv`/`token`/etc. in logs, and Brakeman + bundler-audit already running in CI.

**Gaps found, roughly ordered by how soon they'd matter:**

- **No self-serve sign-up exists.** There's no `RegistrationsController` or sign-up route —
  accounts are created via `db/seeds.rb` / `SEED_ADMIN_EMAIL` only. This is presumably deliberate
  while there's no real user base, but it means "add a real user" today means editing seeds or a
  Rails console, not a form. Worth a deliberate decision (build sign-up, or stay invite-only) before
  this is "launched" in any real sense — closing every other item below is moot if the only way
  to get an account is a console session.
- **No password length/complexity requirement.** `has_secure_password` validates presence and
  confirmation match, but nothing enforces a minimum length — a one-character password is
  currently accepted. A `validates :password, length: { minimum: 8 }, allow_nil: true` on `User`
  (skip when nil so updates without changing password still work) is a small, safe addition.
- **Content-Security-Policy is present but fully commented out** (`config/initializers/content_security_policy.rb`
  is the untouched Rails default template). Worth enabling once the DaisyUI/Turbo/Stimulus asset
  setup is stable enough that a real CSP won't immediately break something — start with
  `content_security_policy_report_only` to see what it would have blocked before enforcing it.
- **`config.hosts` isn't set** (commented out in `production.rb`) — Rails' DNS-rebinding/Host-header
  protection is effectively off. Render's default `*.onrender.com` host plus any custom domain
  should be explicitly allowlisted here once a custom domain exists; low urgency while the app is
  only reachable at the one Render-assigned hostname, but easy to forget once a domain is added.
- **No 2FA.** Not unusual for a pre-launch app, but worth flagging explicitly given this handles
  financial data — a `rotp`-based TOTP second factor is the standard low-effort Rails addition
  when this becomes a priority.
- **No account lockout after repeated failed logins** — only rate-limiting (which slows, but
  doesn't stop, a sustained attack against one account). A lockout after N failed attempts,
  reset on successful login or after a cooldown, is a natural pairing with the existing
  rack-attack throttles rather than a replacement for them.
- **No field-level encryption on financial data yet** (Rails' built-in `encrypts`) — already
  flagged in `repo-review-2026-08-29.md` as "less urgent while entry is manual-only," but worth
  restating here: this becomes materially more important once Plaid-linked bank data is stored,
  not just manually-entered transactions.
- **No Postgres backups** — a direct consequence of being on Render's free Postgres plan (see
  cost table above); there is currently no way to recover from an accidental `DELETE` or a bad
  migration in production beyond whatever's still in Postgres's own WAL. This is a cost item and
  a hardening item at once — it's the main reason the "Basic-256mb, ~$6/month" upgrade above
  matters more than the dollar amount suggests.
- **No Privacy Policy or Terms of Service** — already flagged in `repo-review-2026-08-29.md`;
  restated here because it's as much a legal/compliance gap as a security one, and matters more
  than usual for an app whose whole purpose is handling someone's financial data.

## Suggested sequence

Roughly in order of "blocks everything else" to "matters once there's real usage":

1. Decide the sign-up story (build it, or confirm invite-only is intentional) — everything else
   is moot if there's no real way to get a real user into the app.
2. Move off free Postgres (backups) before real financial data exists, not after something is
   lost.
3. Wire up real outgoing email (password reset is currently non-functional in production) and
   error monitoring — both cheap/free at this scale, both currently just unconfigured, not hard.
4. Password length validation, `config.hosts`, and a CSP in report-only mode — small, low-risk,
   no reason to wait.
5. Account lockout, 2FA, field-level encryption, private repo + branch protection, and the
   Render/Claude Code paid-plan upgrades — bigger or costlier changes, sequence these against
   actual user growth rather than doing them all at once pre-emptively.
