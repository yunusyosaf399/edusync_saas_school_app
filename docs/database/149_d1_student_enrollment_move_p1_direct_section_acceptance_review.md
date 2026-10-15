# D1 Student Enrollment MOVE P1 DIRECT Section A → B — business acceptance review #63

Date: 2026-10-15. **Candidate accepted by disposable local runtime; final exact-head CI / PR freeze still pending.** Full D1 remains **OPEN**; Migration 10 is inactive `.sql.draft` and must not be run against hosted Supabase.

## Trust baseline and verified source-head evidence

- PR [#63](https://github.com/yunusyosaf399/edusync_saas_school_app/pull/63) began from the exact frozen `main` at `15180774c7a9948aaafa4787a616f56fc2f74dd9`: **62/62 suites, 2,797/2,797 assertions, 29/35 distinct protected operations**.
- On implementation commit `8b5099c251b4bc531f1a5bb4b397d386b4013aec`, [D1 local runtime #607](https://github.com/yunusyosaf399/edusync_saas_school_app/actions/runs/38747799969) and [Foundation local #722](https://github.com/yunusyosaf399/edusync_saas_school_app/actions/runs/38747799407) both **PASSED**.
- D1 runtime log explicitly reports **63/63 business suites, 2,831/2,831 pgTAP assertions**, new **#63 34/34**, 71 D1 Python tests, 220/220 post-D1 Foundation SQL assertions, and all **19 prior observed-lock concurrency** regressions. The independent Foundation CI passed **227 Python tests** and 220/220 Foundation SQL tests.
- Local source and final catalog: **223 draft fragments**, 34 D1 relations with **34/34 FORCE RLS**, **542 final functions / 524 SECURITY DEFINER, 157 app and 385 app_private**, and **zero authenticated, anon or service_role EXECUTE over private app_private functions**. No schema or security weakening in the new test suite. The frozen Effect26 SQL and every existing Migration 10 fragment are unchanged.
- **Static-workflow trigger gap**: there was no static run on the implementation SHA because `.github/workflows/domain-draft-static.yml` watched only draft migration/guard files, not acceptance suites or their registry. The PR now adds these three path selectors to *both* push and pull_request static workflow triggers: `supabase/tests/domain/**`, `tools/supabase/domain_business_ci.py`, `tools/supabase/tests/test_domain_acceptance_ci.py`. The underlying static guard jobs/commands are unchanged. Thus future acceptance-only changes must also earn the normal third exact-head source-security gate. Review and workflow edits require a **new exact final-head triple PASS**, rather than relying on older #607/#722 alone.

## Frozen Effect26 behavior exercised in suite #63

`supabase/tests/domain/63_student_enrollment_move_p1_direct_section_history.sql` creates a rollback-only fixture with one verified authenticated INDIVIDUAL staff principal, enabled distinct `student.enrollment.place` and `student.enrollment.move` scopes with ALL/DIRECT authority, one ACTIVE Student/initial status transition, Class/Campus/Year/Offering and Section A, matching Class/Section capacity revisions, and an effective `PERSISTENT_STUDENT` roll policy and server-owned allocator. A second open Section B is configured inside the **same Class Offering, Campus and Academic Year** with its own capacity revision. Test row fabrication is deliberately limited to synthetic bootstrap and policy/scope data.

Critically, **there are no privileged direct inserts into `app_private.enrollments` or `app_private.roll_allocations`**. The source PRIMARY Enrollment and initial retained Roll **12001** are created by the real *authenticated* `app.d1_place_student_enrollment(...,'INITIAL',...)` P0 RPC. A new school-wide effective `DIRECT` P1 route is explicitly activated; then the real authenticated `app.d1_move_student_enrollment(...,'SECTION_CHANGE', CURRENT_DATE,...)` command moves that source from A to B. The test asserts:

- Raw private Enrollment SELECT is refused with SQLSTATE 42501; current permission without any P1 routing policy does not bypass required policy selection.
- Stale Student version and inconsistent source Enrollment start are denied. Same-Academic-Year `PROMOTION` and same-Campus `CAMPUS_TRANSFER` are semantically invalid; an override reason supplied while the destination is not full is rejected.
- Successful authenticated `SECTION_CHANGE` creates a distinct successor PRIMARY Enrollment and Roll allocation. The predecessor Enrollment and Roll both close on the exact **exclusive** boundary date `CURRENT_DATE`; successor starts that date in Section B and retains the predecessor UUID as immutable history.
- `PERSISTENT_STUDENT` preserves the original numeric roll **12001** while creating a distinct successor allocation and `origin_allocation_id` referring to the original roll.
- Student stays ACTIVE with its original status event and unchanged version; no capacity override is recorded.
- Same-key identical command replay returns exactly the same Enrollment/Roll UUIDs; changed-intent same-key replay and a new-key second move against the already-ended source are denied.
- Exactly two retained Enrollment records, two retained Roll records, one successful `student.enrollment.move` command receipt, and one `enrollment.moved` outbox event. No direct delete, duplicate, authorization-bypass, or new Student lifecycle event is accepted. Deferred constraints are forced `IMMEDIATE` before test transaction ROLLBACK.

`tools/supabase/domain_business_ci.py` registers the 63rd suite with **34 pgTAP assertions**. `tools/supabase/tests/test_domain_acceptance_ci.py` pins the first **62 suites and 2,797 assertions**, checks exact new registration and **2,831** candidate total, prevents fabricated Enrollment/Roll history, and pins source markers and role boundaries.

## Security and acceptance limitations

- This is only **DIRECT P1 same-school, same-year and same-Class Section change**, with school-wide ALL scope and adequate capacity. It is **not** proof of CAMPUS_TRANSFER, PROMOTION, REPEAT, CLASS_CHANGE, or their more complex ancestry/date/roll preconditions.
- Does **not** exercise multi-step APPROVAL submit/review/apply, independent reviewer roles, affected source-and-destination CAMPUS/SECTION partial scopes, campus-policy convergence, override authority or full-capacity evidence, stale policy/grant reevaluation, future-effective moves, concurrent competing move transactions, or an operation-specific observed-lock race.
- All 19 real races reported by #607 are previously established regression tests from *other operations*; they do not establish a new move-specific concurrency scenario.
- There is no `student.create` implementation bypass; it still depends on the unresolved Admissions handoff. The registered `student.roll_policy.change` is separately disabled and unimplemented; neither is silently counted as accepted.
- Migration 10 remains source-only inactive `.sql.draft`. No staging, hosted Supabase or production application was performed.

## Acceptance decision and gate

Only after the final PR HEAD passes **D1 local runtime (63/63, 2,831/2,831; #63 34/34)**, Foundation and D1 draft static, with no outstanding security finding, may PR #63 merge and freeze the next checkpoint: **63/63 business suites, 2,831 assertions, 30/35 distinct protected operations**, leaving **5 without dedicated accepted suites**. Until merge, `main` remains **62/2,797 and 29/35**. D1 stays OPEN.
