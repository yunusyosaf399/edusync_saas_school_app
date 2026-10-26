# DB01-08 — Successive Roll correction history and School-local policy boundaries

**Disposition: DISPOSABLE ENGINEERING PASS, 2026-10-23** on exact code commit `9f77ed4425d9a55a244daebcddb6db0a0dcca1a3`, draft [PR #141](https://github.com/yunusyosaf399/edusync_saas_school_app/pull/141), which remains **unmerged**. No database migration was applied to hosted Supabase, and no Roll operation/permission is enabled in production.

## Owner choice observed

[DB01 automatic initial Roll decision](db01_owner_decision_automatic_initial_roll_20261023.md) selects Option A. Real P0 Enrollment allocates the initial number from the server, with no user-entered initial Roll. Authenticated correction is a later independent operation and does not rewrite old allocations.

## Tested sequence

1. The disposable School fixture initializes genuine authenticated `student.enrollment.place` P0 to obtain retained source R0. School-local date begins at UTC.
2. The original authorized requester submits an exact typed R0 source and proposed R1 number. Two configured independent reviews are accepted. Authenticated APPLY creates R1 on UTC School-local business date, Student version 2, receipt/audit/outbox once.
3. The same requester tries another correction of current R1 **on the same School-local calendar date** with correct Student token and source. The server rejects it; zero-length history is not created.
4. Test-only School stored timezone advances to `Pacific/Kiritimati`; the server reports the following date. Despite caller session timezone `Etc/GMT+12`, a new genuine P1 SUBMIT→two independent REVIEWs→APPLY against R1 creates R2 on the advanced School date, Student version 3, without using a caller-supplied effective date.
5. Three retained Roll rows are verified: R0 closes at R1 date; R1 starts at R1 date and closes at R2 date; R2 starts at R2 date, remains open, and points to R1, which points to R0. `origin_allocation_id` and policy revision remain fixed; precisely one row is current. Number high-water reserves the manually proposed R2 value. Both approved request ledgers have precisely one application, APPLY success receipt, audit and minimized outbox event.
6. Replay of the original R1 APPLY after R2 returns its *original* result; no new Roll, receipt, application, audit/outbox or Student version is created.
7. An R1 source used after R2 is rejected **with the current Student version**, isolating the stale Roll-head constraint from optimistic concurrency.
8. A mismatched foreign-School policy reference is rejected. The Foundation School profile is singleton; the test does **not** manufacture simultaneous Schools in one tenant. A test-only backward School timezone then places the business date before current R2 start, and a new correction is denied; restoring the timezone leaves R2 and its original evidence intact.

## Policy cutoff and multi-School limitation

The protected `d1_roll_correct_lock_source` checks the *stored* School of Student, policy revision, current effective policy interval, current Roll identity and School date under lock. A forged foreign policy UUID cannot be substituted.

Physical policy ambiguity/expiry and mode boundaries are also covered by existing independent D1 suites: [#38 retained policy revision invariants](../../supabase/tests/domain/38_student_roll_policy_retained_history_defensive_invariants.sql) (reject overlap/skipped/invalid revisions), [#80 School-local Roll date](../../supabase/tests/domain/80_school_local_roll_business_date.sql), [#83 academic cross-Section collision](../../supabase/tests/domain/83_db01_academic_cross_section_correct_effect.sql), and [#84 persistent cross-revision collision](../../supabase/tests/domain/84_db01_persistent_cross_revision_roll_correction.sql).

**What is not claimed:** This test does not exercise two concurrently live Schools in one Foundation tenant (the School profile is singleton); it does not prove the DB02 protected Roll-policy change workflow is implemented, the future policy-mode handoff is accepted, or that a production tenant was modified. These remain separate integration/release prerequisites.

## Exact-head GitHub Actions evidence

| CI gate | Result |
| --- | --- |
| [D1 static #39938118851](https://github.com/yunusyosaf399/edusync_saas_school_app/actions/runs/39938118851) | SUCCESS |
| [Foundation local stack #39938118958](https://github.com/yunusyosaf399/edusync_saas_school_app/actions/runs/39938118958) | SUCCESS |
| [Full D1 local PostgreSQL #39938118893](https://github.com/yunusyosaf399/edusync_saas_school_app/actions/runs/39938118893) | SUCCESS |
| P1 Roll pgTAP | `113/113` |
| All D1 domain assertions | `3,686` |
| Foundation post-D1 regression | `220/220` |
| FORCE RLS | `34/34` D1 tables |
| Unauthorized private function EXECUTE | `auth_private=0 anon=0 service_role=0` |
| Runtime result | `D1C2A_PASS`; 257 Migration 10 fragments remain `.sql.draft` |

## Remaining engineering gates

DB01-09 full approval/rejection integration, DB01-10 downstream DB02/03/04 reconciliation and merge topology, DB01-11 independent non-author security review and DB01-12 explicitly authorized production release. The approved initial Roll Option A remains recorded and unchanged.
