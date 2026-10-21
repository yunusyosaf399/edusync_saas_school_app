# DB-01 + DB-02 disposable composition rehearsal (not an integration approval)

**2026-10-21.** Integration-preview branch `integration/db01-db02-roll-composition-preview`, stacked on exact shared receipt candidate PR #122 head `df8caf9162d41d4eb4868b42abc582d042ec8441`. DB-02 PR #101 and DB-01 PR #117 are **unchanged**.

## Purpose

Prove the previously reported three-path D1 CI/test-manifest collision can be resolved without losing acceptance test #81 or DB-02 suites #82–#86. This is an **isolated test composition** and must not be merged into any owner branch, `main`, or deployed without each owner and independent security approval. Nothing activates the protected Roll Policy operation.

## Exact composition

- Imported **unchanged from DB-01 PR #117**:
  - `supabase/migrations/20260928000000_domain_package_01_effect41_01_db01_correct_source_prelock.sql.draft`;
  - `supabase/tests/domain/81_db01_roll_correct_source_prelock.sql`.
- Kept all DB-02 PR #101 preflight helpers #42–#45 and stacked PR #122 shared receipt-only helper #46 and suite #86 intact.
- Reconciled `tools/supabase/domain_business_ci.py` by adding suite #81 (20 assertions) immediately before #82 (10), #83 (18), #84 (20), #85 (19), #86 (27). Did not delete or renumber any earlier suites.
- Reconciled `tools/supabase/domain_local_ci.py` and corresponding `tests/test_domain_local_ci.py` expected catalog by **one** private Student-owned definer: prior DB-02 metrics `549 functions/531 definers/392 private` become `550/532/393`, leaving `157` public app functions, `34` RLS relations, and **zero** unauthorized client private EXECUTE unchanged.
- No changes to DB-01 SQL, fixtures or expected assertions, and no changes to Roll Policy shared receipt SQL. The composed business total **should be 3,372** (= 3,352 previous passing + 20 DB-01 #81), **only if disposable CI actually passes**.

## Readiness gates

1. Inspect exact integration-preview SHA and confirm D1 static, D1 runtime, Foundation PASS with suite #81 **20/20** and #86 **27/27**, total **3,372/3,372**.
2. The preview is **not** an integration/merge approval or a substitute for non-author security review on PR #122 at its exact tested SHA.
3. DB-01 may independently advance #117/#118/#119; a later integration must recompose with their current actual heads rather than blindly merge this snapshot.
4. On an approved integration, downstream owners must deliberately transfer the exact #81 manifest/counters to the actual owner branch, then verify current protected operations, receipt/code owners and baseline before main merge.
5. No hosted database connection, production migration, public Roll Policy RPC, event or operation activation.

**State:** Local CI results are to be filled after GitHub checks; do not imply success from source inspection.
