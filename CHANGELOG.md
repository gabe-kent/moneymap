# Changelog

User-facing changes to Moneymap, newest first. One line per pull request that changes what a
user can see or do — skip pure refactors, internal tooling, and docs-only PRs. There's no
version numbering yet since nothing has shipped as a numbered release; entries are grouped by
date instead.

## 2026-09-04

- Redesigned the app around a persistent sidebar and added three new pages — a Dashboard
  (net worth, monthly income and spending, generated insights, account balances, spending by
  category, recent activity), Budgets (a monthly target per category, tracked against real
  spending), and Reports (net worth trend, income vs. expenses, category breakdown, top
  spending sources). Transactions gained search and type/category filters. All three new pages
  are behind the `dashboard`, `budgets` and `reports` feature flags, so they're off until
  enabled at `/admin/feature_flags`. (PR #25)
- Added a logout button and an account settings page: change your password, see every device
  currently signed in, and sign out of one or all of them. (PR #44)
