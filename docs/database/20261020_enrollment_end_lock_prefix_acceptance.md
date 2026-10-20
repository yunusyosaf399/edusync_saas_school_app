# Enrollment END lock-prefix regression

## Problem and scope

Student Enrollment END could acquire Student before the School/roll-policy/allocator locks subsequently required by Roll integrity checks. Concurrent roll allocation takes the School prefix first, creating an inversion. PR #106 supplies the append-only `.sql.draft` fix: lock School, retained source policy IDs and allocator IDs, then Student and the existing validated source history. Its allocator fix also preserves persistent numbers owned by other Students across supersession history.

PR #114 completes the missing two-session acceptance for END. Requirements remain master specification §§11–12 (distinct identifiers and retained enrollment/roll history), existing P1 authority and immutable command receipt/audit/outbox contracts. It changes no product policy, Foundation migration, catalog count, executor ownership, permission grant or runtime operation activation.

## Local runtime proof

The harness runs **after** the existing D1 business/concurrency/photo suites, only against `supabase_db_saas_OS_school_app` and the existing loopback test connection. A fresh Student/academic ancestry and fresh role assignment use the existing real synthetic staff Auth binding. Actual protected `app.d1_place_student_enrollment` creates Enrollment and Roll; neither is inserted directly.

After P0, an owner-only synthetic policy cutover expires the source persistent revision and supplies an academic-context successor **without an allocator**. This tests stored-source locking; it is not a successful `student.roll_policy.change` command.

| Case | Required observation and outcome |
|---|---|
| School held, blocker commits / rolls back | Two exact-backend tuple/transaction waits; Student remains NOWAIT-lockable before blocker release |
| Retained source policy held, blocker commits / rolls back | Two waits on the expired source namespace, with Student still free |
| Retained source allocator held, blocker commits / rolls back | Two waits on the stored allocator, with Student still free |
| Protected END arrives first | Each exact School/policy/allocator row independently rejects competing NOWAIT with SQLSTATE 55P03 |
| Worker rollback in each blocked case | Exactly original Enrollment/Roll remain, no closed history or successful END receipt/outbox |
| END commit then identical replay | Same Enrollment/Roll/version; exactly one closure, one successful receipt and one correlated outbox event |

An eight-second observer deadline and fifteen-second worker statement timeout bound failures. `pg_stat_clear_snapshot` refreshes each activity observation. A worker finishing before a genuine wait fails the test. Blockers release in `finally` before the worker thread joins. No arbitrary timing sleep counts as lock proof.

Eight unit tests check the local target boundary, completed/missing wait failures, exact backend-ID binding, parameterized row locks, missing rows and genuine protected fixture wiring. These are harness tests; PostgreSQL acceptance requires the runtime PASS marker.

## Validation and integration

Local tooling: 324 tests passed, including 164 D1 CI tests. D1 draft and final function/ACL guards passed with 230 fragments, 34 forced-RLS relations and 542 functions; client-private EXECUTE remains zero. Git diff whitespace validation passed.

At submission, GitHub PostgreSQL validation was pending; see PR #114 for the latest tested head and run evidence. The first run exposed a fixture UUID collision with the earlier provider-recovery suite; the fixture now uses a disjoint namespace with an explicit non-overlap check. Acceptance requires all three workflows (D1 static, Foundation local stack and D1 local runtime) on that head, with `D1_ENROLLMENT_END_LOCK_PREFIX_PASS` in the runtime job log. Do not substitute unit/static success for that evidence.

This is scoped END concurrency acceptance. Roll CORRECT, Roll Policy Change, Admissions creation, Enrollment MOVE source/destination lock-union, independent security review, populated upgrades and overall D1/database completion remain separate work. The PR stack remains reviewable and unmerged; Migration 10 remains non-executable and no hosted deployment is performed.
