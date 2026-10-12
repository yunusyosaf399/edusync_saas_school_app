# D1 two-Family shared-Student cross-operation two-session race — acceptance review

Date: 2026-10-12
Verdict: **PASS — exact-source disposable-local PostgreSQL concurrency acceptance only. Full D1 remains OPEN.**

## Source, merge and independent CI

- Previously accepted and documented `main`: `80b49e1efa6208f6a7ebcfed109e961066b1647f`.
- [PR #38](https://github.com/yunusyosaf399/edusync_saas_school_app/pull/38) **MERGED** at `496dbe301a52f7ec66f30c4fc89ae3c48472d083` from verified head `d9e1f56db3d3f4f6658ebad7e2c72663d2cb226e`. Both green workflows checked out the **exact test-merge ref** `7fef129bf5c770d3e7e5f7e4a775db255bb3e077`, merging this exact head into the accepted previous base.
- [D1 Migration 10 disposable runtime #297](https://github.com/yunusyosaf399/edusync_saas_school_app/actions/runs/38233685590) **PASS** with `D1C2A_PASS`: unchanged **1,594/1,594** business pgTAP assertions across **31** suites, **220/220** post-D1 Foundation regressions, **45/45** D1 Python tooling tests, and **14/14** genuine observed-lock two-session cases (3 Employee create, 3 Family Principal Membership, 7 Family Relationship, **1 new cross-Family REVOKE vs END**). The log contains the new exact `D1_CROSS_FAMILY_OPERATION_RACE_PASS` marker after the original thirteen accepted markers. Catalog and error/warning SQL lint PASS.
- [Foundation local stack #466](https://github.com/yunusyosaf399/edusync_saas_school_app/actions/runs/38233685711) **PASS**: nine frozen Foundation migrations and SQL suites, **201/201** Python tooling tests, **220/220** Foundation pgTAP assertions, clean local reset and both SQL lint passes.
- D1 CI assembled/applied **202 otherwise non-executable Migration 10 `.sql.draft` fragments only to disposable local PostgreSQL**, verified **34/34** forced-RLS relations, **540** functions (**522** SECURITY DEFINER), and no client-role private helper EXECUTE. No production SQL, active migration, hosted Supabase database, application code or real school data changed.

## Independent race and current portal-read invariants

The frozen direct Effect32 child-access and Effect30 relationship commands lock the **same Student** even when Family A and Family B are independent. The test distinguishes **shared-Student serialization** from an accidentally shared actor lock by using **different verified INDIVIDUAL staff Auth users/principals** (`foundation-rbac-001@example.invalid` for A, `foundation-test-001@example.invalid` for B) and two independent verified FAMILY Auth users (`foundation-family-001@example.invalid` for A and `foundation-own-002@example.invalid` for B). FAMILY current reads require independently live group membership, same-Family relationship basis, child entitlement and exact family-safe `OWN/D1_FAMILY_CHILD` summary/current/history grants.

The disposable race fixture and Python runner:
1. Create a fresh Student with an active Guardian relationship and independent current child entitlement for Family A, plus a Mother relationship and separate active child entitlement for Family B. Both FAMILY Principals have distinct real Auth bindings, membership, roles and independently scoped summary/current relationship/historical relationship grants. These **initial test-only records** are seeded by the schema owner; no test fixture creation is misreported as a protected public ADD command. Legitimate authenticated staff grants for the two different change operations have separate `ALL/DIRECT` scopes. Retire only local previously ACTIVE relationship/child-access P1 policy routes and activate distinct new synthetic DIRECT policies, preserving existing P1 evidence.
2. Confirm **both** independently authenticated FAMILY Principals have exactly one visible authorized Family summary, one current relationship and one historical relationship for the same Student. These initial checked reads establish real independent portal authorization before concurrency starts.
3. Spawn separate `docker exec -i psql` **PostgreSQL transactions**. Staff A executes a genuine protected `app.d1_change_family_child_access(..., 'REVOKE', ...)` on Family A, deliberately keeps the transaction open after effect execution. Staff B starts a genuine `app.d1_change_family_relationship(..., 'END', ...)` for Family B using the **same pre-race expected Student version** but Family B's independent Family version.
4. The runner requires that the first transaction is still active and that **B's exact backend is blocked by A's exact backend** under `pg_blocking_pids`, with an ungranted `transactionid` or `tuple` lock. This is positive measured contention, not `pg_sleep` by itself, unrelated stack traffic or a generic advisory-lock observation.
5. A succeeds and commits its Family A-only entitlement REVOKE. B's original END fails with the exact optimistic error **`D1 Family relationship target version changed`** and **zero successful receipt or relationship/child-entitlement effect**. The test verifies A's history is retained closed, while Family B's relationship and entitlement remain live. Authenticated Family A summary/current/history immediately return **zero**; independently authenticated Family B still sees **one** of each.
6. Refresh the actual persisted Student and Family B versions, then retry B's END under a new idempotency key through the same authenticated staff change API. This final B relationship closes successfully with an access-closure count of exactly one. B's own dependent child entitlement ends, and now **both** Family accounts have zero current summary, relationship and history reads.
7. Evidence checks require exactly **two successful new command receipts** (A REVOKE, B refreshed END), no receipt for the stale B attempt, only **one new explicit child-access event** and **one new relationship event**, both original relationship rows preserved, and both family-specific historical child-entitlement intervals preserved closed. The implicit B closure does not forge an explicit child-access REVOKE event or cross-Family change.

The new fixture is **committed only inside disposable local CI** to make two separate transaction workers possible, unlike a single `BEGIN/ROLLBACK` pgTAP suite. The local stack is disposable; no hosted or real-school fixture is changed. The existing 31 rollback-only business suites and their 1,594 assertions remain unmodified.

## Exact test-only source change and remaining gates

Only four acceptance harness/source paths changed:
- `supabase/tests/domain/fixtures/family_cross_operation_race_setup.sql` — new synthetic isolated two-Family, one-Student fixture with distinct current Auth/permission chains;
- `tools/supabase/domain_cross_family_race_ci.py` — new exact-backend observed-blocking lock probe, authenticated two-worker commands, stale-version/no-effect assertions, separate portal reads and refreshed retry;
- `tools/supabase/domain_concurrency_ci.py` — append new race **after** the thirteen existing accepted cases;
- `tools/supabase/tests/test_domain_acceptance_ci.py` — one static fixture, actor/locking, and integration regression guard.

**Accepted/frozen:** unchanged **31 suites, 1,594/1,594 business assertions**, and an expanded **14/14 true two-session observed-lock races**, supported by **45/45 D1** and **201/201 Foundation Python tests**, **220/220 Foundation SQL**. This is **incremental local acceptance**, not evidence of full D1 business coverage, production deployment, hosted migration, or populated school upgrade readiness. Migration 10 retains **202 inactive `.sql.draft` fragments**.

**Still OPEN:** additional inter-Family same-Student timing and reversal-order races, adversarial current authorization/reviewer/scope permutations, other D1 operations, populated upgrade/reconciliation, Admissions/Finance, and hosted Migration 10 activation.

**Checkpoint marker:** `D1_CROSS_FAMILY_REVOKE_VS_END_RACE_PASS — 1594/1594 BUSINESS — 14/14 TRUE OBSERVED-LOCK RACES — 220/220 FOUNDATION — 45/45 D1 UNIT — 202 DRAFT FRAGMENTS — FULL D1 OPEN`.
