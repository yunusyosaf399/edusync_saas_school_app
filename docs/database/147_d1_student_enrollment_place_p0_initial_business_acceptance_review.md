# D1 Student Enrollment Place P0 INITIAL + Roll — business acceptance review #61

Date: 2026-10-15. **Verdict: candidate accepted in disposable local runtime; PR merge/freeze pending final exact-head checks.** Full D1 remains OPEN. Migration 10 remains inactive `.sql.draft`.

## Baseline, candidate and exact-head test evidence

- Frozen `main` before this work: `a2e98aac2d249d8db13a8a13b30037c9c3149e98`, **60/60 D1 business suites, 2,751/2,751 assertions**, **27 of 35** distinct protected operations with dedicated acceptance.
- [PR #61](https://github.com/yunusyosaf399/edusync_saas_school_app/pull/61) tested head `ec77886a80e9412c35f1c60223d39c8fc8216d75`: [D1 local runtime #587](https://github.com/yunusyosaf399/edusync_saas_school_app/actions/runs/38691589374) **PASS**, [Foundation #705](https://github.com/yunusyosaf399/edusync_saas_school_app/actions/runs/38691589480) **PASS**, [D1 static #207](https://github.com/yunusyosaf399/edusync_saas_school_app/actions/runs/38691589486) **PASS**.
- D1 runtime log explicitly reports **61/61 suites, 2,769/2,769 business pgTAP assertions**, #61 **18/18**, **69/69 D1 Python tests**, **220/220 Foundation SQL** regression after domain migration, and all **19 existing true observed-lock concurrency cases**. Foundation independently passed **225 Python tests** and **220/220 Foundation SQL assertions**.
- **222 draft SQL fragments** assembled locally in a disposable database, with **34/34 D1 relations FORCE RLS**, 542 final functions / 524 SECURITY DEFINER / 157 `app` / 385 `app_private`. No authenticated, anon, or service-role EXECUTE on `app_private` final functions; no new authenticated D1 base-table DML. `main` remained at the exact frozen parent while the PR was tested.
- This is a reviewed candidate with new comments/documentation after the verified head; rerun the exact *final* HEAD's runtime, static, and Foundation before merge. A green older SHA cannot certify later changes.

## Tested P0 protected operation: `student.enrollment.place`

The new rollback-only `supabase/tests/domain/61_student_enrollment_place_p0_initial_roll.sql` contains **18 pgTAP assertions**. It uses a synthetic active, verified, bound INDIVIDUAL requester with one current complete `student.enrollment.place` grant and ALL/DIRECT scope, an enabled operation contract, an ACTIVE Student and initial retained status transition. It supplies matching same-school Campus, Academic Year, Academic Class, Class Offering and Section Offering, and contemporaneous Class and Section capacity revisions. The initial roll policy is `PERSISTENT_STUDENT`, with a school-wide allocator at numeric next value 12001. **Crucially, no enrollment or roll allocation is pre-seeded**: the first accepted rows must be created by the protected RPC, not privileged test inserts.

- Authenticated `SELECT * FROM app_private.enrollments` returns 42501, confirming no raw private Enrollment table read.
- Calling the P0 standalone RPC with `PROMOTION` is rejected: **PROMOTION/REPEAT and cross-section/campus/class movements are owned by Effect 26 atomic MOVE**, not Effect25 standalone placement.
- A stale Student expected version is rejected before producing any accepted placement.
- The genuine authenticated `app.d1_place_student_enrollment(..., 'INITIAL', ...)` succeeds, returns non-null Enrollment and Roll UUIDs, uses mode `PERSISTENT_STUDENT` and numeric value **12001**, keeps current status ACTIVE, and reports no capacity override.
- Same-key exact intent replay returns the same original Enrollment and Roll UUIDs, without new mutation. Changing the intent while reusing that key is rejected.
- Post-command owner-visible fixture assertions prove one ACTIVE PRIMARY INITIAL Enrollment, exactly one linked Roll allocation, exactly one `enrollment.created` outbox event, one unchanged initial Student status event, and zero capacity-override rows.
- `SET CONSTRAINTS ALL IMMEDIATE` checks commit-time Enrollment, roll and ancestry integrity. `ROLLBACK` discards all synthetic fixture data.

**What this does not prove**: REENROLLMENT reactivation, full Class or Section capacity/override route, cross-Campus/CLASS/SECTION unauthorized scope denial, concurrent competing initial admissions/roll allocations, stale permission or policy replacements, persistent roll lineage across several historical policies, or comprehensive allocation races. Those require dedicated follow-up tests; the existing 19 observed-lock races are cross-domain regressions, **not an operation-specific P0 Enrollment race test**. It does not implement `student.create`, which still requires the trusted Admissions handoff.

## Review of append-only inactive SQL fixes

**Effect35_15** `enrollment_place_allocator_server_version.sql.draft`: the frozen Effect25_23 final allocator tried to directly update `roll_allocator_states.row_version` and `updated_at` for both `PERSISTENT_STUDENT` and `ACADEMIC_CONTEXT`. This conflicts with the M-row `d1_guard_record` contract and limited executor `UPDATE(next_value)` ceiling. The continuation redefines only that same owner/signature SECURITY DEFINER function and removes those two server-owned columns from the two UPDATE statements. It retains the exact school/policy/allocator and Student lock order, server-selected policy namespace, future-allocation and cross-Student collision guards, latest unsuperseded persistent lineage, and original allocation/evidence shape. `zz_d1_version` still advances version/timestamp. No table grants are added.

**Effect35_16** `enrollment_place_academic_path_execution.sql.draft`: runtime [#583](https://github.com/yunusyosaf399/edusync_saas_school_app/actions/runs/38690109603) proved a real permission defect at the first valid placement. Effect25_16 moved Section ancestry discovery and lock to a fixed academic-executor-owned SECURITY DEFINER helper, **revoked** direct `schoolos_student_executor` EXECUTE on the schema-owner `app_private.d1_lock_academic_path(uuid,uuid,uuid)`, but failed to grant the trusted **`schoolos_academic_executor`** helper the invocation right. The continuation adds exactly one function-level EXECUTE grant to that internal Academic owner, not to Student, clients, or other roles. All academic table locking remains under the original SQL helper and no owner membership or RLS bypass is introduced. Post-fix runtime #587 completes all 18 assertions.

The package remains source-only `.sql.draft`; none of the nine frozen Foundation migrations or the frozen Effect25 files were edited. `tools/supabase/tests/test_domain_acceptance_ci.py` independently pins the 60-suite frozen prefix, new 18-assertion suite, synthetic fixture boundaries, absence of pre-seeded Enrollment/Roll, scoped academic execution edge, and no broad grants. `tools/supabase/domain_business_ci.py` adds only the #61 registration.

## Acceptance decision / next gate

If the **final** branch head earns D1 runtime PASS with #61 **18/18**, totals **2,769/2,769**, Foundation PASS, static PASS and no new security findings, the next frozen checkpoint will be **61 suites / 2,769 assertions, 28/35 protected operations accepted**, leaving **7 without dedicated accepted business suites**. Until PR #61 merges, `main` is still **60/2,751 and 27/35**. D1 as a whole remains OPEN, and Migration 10 is **not** deployment-approved.
