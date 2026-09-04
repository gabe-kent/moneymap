## Summary

<!-- What changed and why. -->

## QA

**Automated:** <!-- e.g. "bin/ci passed" (rubocop, bundler-audit, importmap audit, brakeman,
rails test, seed smoke test), or name the specific commands you ran if you didn't run the
whole suite. -->

**Manual QA before merging** (staging is currently paused — see
`docs/agentic-development-lifecycle.md` — so merging this deploys straight to production;
QA it locally, e.g. via `bin/dev`, not on a staging deploy. Skip this section only for a
doc/test-only PR with no runtime behavior to check):

<!-- Concrete, PR-specific steps you actually ran locally — not a generic checklist. Write
these as things you clicked through and checked, e.g.:
- [ ] Signed in, opened the dashboard, confirmed the new KPI card shows the right numbers
- [ ] Toggled the new feature flag off and confirmed the old behavior is unchanged
-->

## Related issue

<!-- Fixes #123 / Closes #123, if this closes a tracked issue. While staging is paused, GitHub
fires the auto-close on this PR's own merge to `main` — once staging resumes, it instead fires
on the later `main` promotion, not the initial PR into `staging`. -->
