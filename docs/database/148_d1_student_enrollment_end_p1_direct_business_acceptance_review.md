# D1 Student Enrollment END P1 DIRECT — business acceptance review #62

Date: 2026-10-15. **Status: candidate accepted on a disposable local runtime; final exact-head documentation CI and PR merge still required.** Full D1 remains OPEN and Migration 10 remains non-executable `.sql.draft`.

## Verified pre-documentation checkpoint

- [PR #62](https://github.com/yunusyosaf399/edusync_saas_school_app/pull/62) was based on frozen `main` at `2bd4cb0698177bdba52da45d3ed260e27b844188`, after merging suite #61. Baseline: **61 business suites, 2,769 assertions, 28/35 distinct protected operations**.
- Exact audited implementation head: `b193cf5b92875c7d18fe1d970a67a9cf23fa3d2e`. [D1 local runtime #600](https://github.com/yunusyosaf399/edusync_saas_school_app/actions/runs/38731326568), [Foundation #716](https://github.com/yunusyosaf399/edusync_saas_school_app/actions/runs/38731326584), and [D1 draft static #214](https://github.com/yunusyosaf399/edusync_saas_school_app/actions/runs/38731326593) all **PASS** at this exact head.
- D1 local log: **62/62 suites, 2,797/2,797 pgTAP assertions**; new #62 **28/28**; 70 Python D1 tests; all existing **19 true observed-lock races**; local D1 apply and post-apply Foundation regression 220/220. Independent Foundation CI: 226 Python tests and 220/220 SQL pgTAP.
- D1 disposable-runtime catalog: **223 inactive SQL fragments**, **34/34 FORCE RLS tables**, **542 final functions (524 SECURITY DEFINER, app 157, app_private 385)**; authenticated/anon/service-role app_private function EXECUTE **0**. Draft-static reports 97 permissions, 322 scope alternatives, 36 registered operation codes, 0 signature-shape drift and no unknown final owners.
- No live database migration, hosted Supabase deployment or direct D1 client-table DML. The prior 61 suites / 2,769 assertions remain registered and green. The full 19-race regression does **not** assert Enrollment END-specific concurrency.

## Scope: actual authenticated Student Enrollment END operation

`supabase/tests/domain/62_student_enrollment_end_p1_direct_history.sql` includes **28 pgTAP assertions** in a single transaction, executed on a disposable local stack with the frozen five-auth-fixture setup. Initial School, bound active INDIVIDUAL principal, role assignment, ALL/DIRECT permission scopes, active Student and retained initial status, current Academic Class → Campus → Academic Year → Class Offering → Section Offering and capacity history, plus one persistent Student roll policy and allocator are synthetic privileged fixtures. Unlike seeding privileged Enrollment history, a real `authenticated` RPC `app.d1_place_student_enrollment(...,'INITIAL',...)` first creates the actual protected PRIMARY Enrollment and Roll; only then is the exact source passed to the P1 `app.d1_end_student_enrollment(...)` API. No direct Enrollment or Roll inserts in this suite.

**Negative checks:**

- `authenticated` cannot `SELECT` the private `roll_allocations` table.
- An `student.enrollment.end` grant without exactly one unambiguous effective P1 policy does **not** authorize DIRECT mutation. The test then provisions one valid school-fallback DIRECT policy and live permission chain.
- Wrong Student expected version, wrong current source effective-from, whitespace-only end reason, changed intent for reused idempotency key, and distinct new end after source is already closed are all denied with no accepted duplicate application.

**Positive and evidence checks:**

- Authenticated P0 precursor creates the actual source Enrollment/Roll once.
- P1 DIRECT returns **the same** source Enrollment and Roll UUIDs, unchanged Student version, and the requested matching exclusive end date.
- The source Enrollment remains retained with `placement_state='ENDED'`, `effective_until=CURRENT_DATE`, retained nonblank end reason and server actor/timestamp. Source Roll independently has the **identical** exclusive `effective_until`, end actor and timestamp.
- Identical idempotency-key replay proves the existing durable Enrollment and Roll and returns both original UUIDs with no new mutation.
- Student remains `ACTIVE` with its sole existing status-transition event. No destination Enrollment, new Roll allocation, capacity override or extra accepted source is fabricated.
- Exactly one successful `student.enrollment.end` typed receipt, and one `enrollment.ended` outbox event, while `SET CONSTRAINTS ALL IMMEDIATE` asserts deferred history / roll integrity. `ROLLBACK` discards test fixtures.

This is acceptance of the **DIRECT P1 route only**. Not tested in #62: request/independent review/apply path, rejected/invalidation replay, changed/current reviewer grants, school/Campus policy precedence under conflicting policies, CAMPUS/CLASS/SECTION cross-context denial, simultaneous competing END calls or stale scope races, terminal replay after revocation, re-enrollment, capacity override, or unrelated Student status changes. These must not be inferred from green prior suites. `student.create` still awaits the Admissions handoff.

## Real runtime failure and narrowly scoped security correction

Before repair, [D1 runtime #596](https://github.com/yunusyosaf399/edusync_saas_school_app/actions/runs/38727970709) stopped at the successful P1 END after 11 of the planned 28 assertions. PostgreSQL error: **`permission denied for table class_offerings`**, arising in the Student-executor-owned `app_private.d1_enrollment_end_result_rows_match_exact` (final frozen Effect27_07) while validating the enrollment receipt. It attempted direct JOINs on Academic executor-owned `section_offerings` and `class_offerings`.

The append-only inactive `supabase/migrations/20260928000000_domain_package_01_effect35_17_enrollment_end_result_academic_projection.sql.draft` redefines only that same-signature verifier, as the **same Student executor owner**, and replaces only those unprivileged Academic table JOINs with the already present *Academic executor-owned typed SECURITY DEFINER projection* `app_private.d1_enrollment_place_destination(p_section)` from Effect25_16. The result still independently verifies all eight durable summary fields (Student version, Enrollment, Roll, Section, Class Offering, Campus, Academic Year, end date), the retained source Enrollment state/reason/actor/end date, the closed Roll, and the exact source Student/Section identity. It fails closed for missing/mismatched ancestry and invalid typed summary. No new direct Academic table SELECT, broad function grant, client-visible function or schema exposure was added; source guards in `tools/supabase/tests/test_domain_acceptance_ci.py` pin these invariants. All frozen Effect27 and preceding fragments are left unchanged.

## Readiness decision

The exact implementation head above passed all local acceptance, static and Foundation checks. This review and its progress-record update will advance the branch HEAD, so **do not merge solely on the cited older green SHA**; require *fresh exact-final-head* green workflows and a final review/branch gate. On merger and verification, freeze **62 suites, 2,797/2,797 assertions, 29/35 distinct protected operations (6 remain)**. Until then the latest verified merged `main` remains **61/2,769 and 28/35**. Full D1 still **OPEN**; Migration 10 **inactive `.sql.draft`**; no staging/hosted Supabase execution is approved.
