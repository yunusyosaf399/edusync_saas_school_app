# Cross-workstream disposable test composition: current DB-01 protected DIRECT + DB-02 receipt

**Snapshot (2026-10-21):** Parent DB-01/DB-02 preview [PR #129](https://github.com/yunusyosaf399/edusync_saas_school_app/pull/129) at `0097686ca5351dcdb30a16c58b17a160038e9150`; current latest DB-01 [PR #132](https://github.com/yunusyosaf399/edusync_saas_school_app/pull/132) at `e3717e3a42a590b189c701fb8e770a0ee9557068`. This is a **separate non-activating draft regression candidate**. Nothing is merged to owner branches or `main`.

## Composition delta
- Imported unchanged from latest DB-01 head: 25 new files (8 docs, 6 SQL .draft fragments, 7 rollback pgTAP suites #82–88, and 4 real PostgreSQL race/replay harnesses). Existing imported DB-01 #81 and source prelock are retained unchanged.
- Kept all DB-02 PR #101 private helpers, PR #122 evidence-writer receipt allowlist, and 5 DB-02 rollback suites #82–86 untouched.
- The numeric suite labels **82–86 overlap across workstreams**, but **full filenames differ** (`82_db01_*` versus `82_db02_*`). The acceptance runner registers every full path with its exact assertion count; no suite was dropped. Resolve durable cross-owner suite number allocation separately before production integration; do not unilaterally renumber either workstream.
- Reconciled shared tooling from latest DB-01 (including its genuine concurrency runners) and appended DB-02 acceptance list.
- Expected combined catalog: **557 total functions / 539 security definers / 158 app functions / 399 private**, with 158 authenticated app EXECUTEs, 34/34 forced RLS relations, zero authenticated/anon/service-role private EXECUTE. DB-01 original 554/536/396 plus DB-02 +3 private functions.
- Expected combined pgTAP manifest count: **3550** assertions; this is calculated from source manifest, **not evidence of a passed run**.

## Exact-head acceptance and hard stops
Demand three distinct GitHub checks PASS: D1 static, Foundation, disposable D1 runtime (including DB-01's authenticated DIRECT, two-backend revocation/races and DB-02 suite #86). Match observed counts to this manifest; failures require new candidate commit and exact-head rerun.
- No SQL activation: all migration changes remain .sql.draft. DB-02 operation `student.roll_policy.change` stays disabled and cannot be externally called.
- No hosted Supabase deploy or main merge, no change to DB-01/03/04 owner branches, and no bypass of security/owner decisions. Non-author shared receipt signoff remains missing, tracked by [issue #131](https://github.com/yunusyosaf399/edusync_saas_school_app/issues/131). The owner has no independent GitHub reviewer available, so the disposition is recorded as a review limitation, not fabricated approval.
- This snapshot excludes any later commits after the pinned DB-01 head. At actual integration, audit final heads and revalidate all outstanding cross-workstream compatibility.
