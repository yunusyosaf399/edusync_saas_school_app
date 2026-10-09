# D1 Effect 31 P1 END/CORRECT two-session race — independent acceptance review

Date: 2026-10-09  
Verdict: **PASS — incremental D1C2A local-only concurrency acceptance. Full D1 release remains OPEN.**

## Exact source and validation

- Trusted base: `0cc16ac46ed7bce59bff0f0459df7b522b1b26ba`.
- [PR #13](https://github.com/yunusyosaf399/edusync_saas_school_app/pull/13) exact tested commit `93f8f873b01551cb11434f479c874c8ec0dd99a0`; merged as `e0dc657fe2e687ffab29f17b1fbc031d643d810f` with the tested commit as the second parent.
- [D1 disposable local runtime #141](https://github.com/yunusyosaf399/edusync_saas_school_app/actions/runs/37937397870): **PASS**, **570/570 D1 business assertions** across fourteen suites, **220/220 Foundation regressions**, **21/21** runner unit tests, **3/3 Employee races** plus **3/3 Family P1 ADD, END, CORRECT races**, six total two-session observed-lock races. Both `D1_FAMILY_MEMBERSHIP_END_RACE_PASS` and `D1_FAMILY_MEMBERSHIP_CORRECT_RACE_PASS` and the combined `D1_FAMILY_MEMBERSHIP_LINEAGE_RACES_PASS` appear in the exact commit's logs.
- [Foundation local #345](https://github.com/yunusyosaf399/edusync_saas_school_app/actions/runs/37937397503): **PASS**.
- 197 Migration 10 `.sql.draft` fragments assembled/applied **only to disposable local PostgreSQL** for this gate, 34/34 forced-RLS tables, 540 final functions (522 SECURITY DEFINER), no authenticated/anon/service_role private helper EXECUTE; warning and error lint gates PASS; local stack stopped.
- The standalone D1 draft static workflow is path-filtered and did **not** run on this two-file harness-only PR. No SQL source changed from accepted [static #95](https://github.com/yunusyosaf399/edusync_saas_school_app/actions/runs/37928235911), and current runtime source/catalog/RLS/ACL probes PASS. Do not misstate this as a fresh static workflow PASS.

## Frozen Family P1 semantics tested

The operation is `family.principal_membership.change`, non-family-safe and ALL-only. Independent verified INDIVIDUAL requester and separate independent reviewer (with exact configured role and `family.access.approve` chain) submit and approve an intent. Review does not mutate the domain. Explicit APPLY must recheck the retained membership source under the frozen lock hierarchy. END closes an open selected membership at an exclusive end date. CORRECT repairs premature closure by appending a successor under `supersedes_id` with the **same Family and Principal** at that exact historical boundary; it does not replace the login or rewrite the predecessor.

Both new races use separate authenticated PostgreSQL sessions with two separately submitted and approved same-target requests and **observed lock waiting**, not two sequential calls:

1. **Competing P1 END:** On the already accepted P1 ADD fixture, independently submit and approve two END intents targeting the same open source with the same exclusive date `CURRENT_DATE-3`. The first APPLY succeeds and closes that original membership, the competing APPLY becomes INVALIDATED, and neither attempt creates a duplicate history row. The original Family, Principal, `supersedes_id IS NULL`, source effective date and exact `effective_until`, `ended_at` and `ended_by` remain provable. Cumulative workflow evidence: **two EXECUTED and two INVALIDATED** requests counting the prior ADD race, **two** successful applications/events, **12** typed P1 command receipts, one retained membership row.
2. **Competing P1 CORRECT:** Independently submit and approve two CORRECT intents targeting that same *closed* original history row at its exclusive end boundary. One APPLY succeeds and appends a new successor row at `CURRENT_DATE-3` with the exact original Family/Principal and `supersedes_id` pointing at the retained predecessor. The other becomes INVALIDATED with no successor or success evidence. The predecessor stays closed and immutable. Cumulative result: **three EXECUTED / three INVALIDATED** requests, **three** successful applications/events, **18** typed P1 command receipts, **two** retained membership history rows: original predecessor + one open successor. Independent Family relationship history persists; Student child-access remains zero.

For both races the first transaction is intentionally held while the second visibly waits for a database lock. The harness fails if a worker exits early, locks are not observed, outcome is reversed, receipt/application/event counts differ, or identity/ancestry/boundary validation fails.

## Reviewed tested diff

- `tools/supabase/domain_concurrency_ci.py`: extend the previously accepted real ADD race runner with two subsequent independently reviewed P1 END/CORRECT races; constrain actions and source UUIDs; assert exact typed results, lock waits and retained workflow/domain evidence.
- `tools/supabase/tests/test_domain_acceptance_ci.py`: two additional deterministic unit tests for the race SQL builders, verified authenticated role and valid test-bound actions/IDs, and fail-closed mismatched intent keys.

**No migration SQL, frozen Foundation file, RLS policy, operational grant, Flutter code, remote Supabase environment or release activation was changed.**

## Open acceptance and deployment gates

These tests establish one concrete competing END and CORRECT shape on an identical membership lineage, not all possible multi-actor/P1 policies, requester/reviewer revocation races, alternative actor/scopes, Family portal checked reads, nor Effect30 concurrency or primary/multi-basis logic. The other unaccepted D1 operations, populated upgrade, Admissions/Finance and managed production rollout remain **OPEN**. Migration 10 remains **197 non-executable .sql.draft fragments**.

**Checkpoint: `D1_EFFECT31_P1_END_CORRECT_RACES_PASS — 570/570 BUSINESS — 220/220 FOUNDATION — 6/6 TWO-SESSION RACES — FULL D1 OPEN`.**
