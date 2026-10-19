# Student Photo — reverse lock winner and genuine Campus Transfer races

Date: 2026-10-19. **Candidate only, subject to real D1 CI; no production upload activation.**

## Source and boundary

Continue from frozen `main` `30d7cf940f5533e6ffac32f68829532f453055d3`, [PR #96 freeze](211_student_photo_protected_enrollment_end_intent_race_ci_merge_freeze.md). Prior PR #96 proved Enrollment END first: the genuine protected P1 END held a Student row lock, two native PostgreSQL photo intent operations queued, both denied after the END committed, and token states remained unchanged. That did **not** prove the reverse winner or a cross-Campus transfer.

The new tests run only inside the disposable `supabase_db_saas_OS_school_app` D1 local CI stack after all earlier frozen business suites and the PR #94–96 photo trials. They create two *new synthetic Students* with Person and initial status, then establish a real PRIMARY Enrollment and Roll for each using the public authenticated **`app.d1_place_student_enrollment` P0 command**; no base Enrollment or Roll rows are fabricated.

The test creates a second OPEN Section and Class Offering in another ACTIVE Campus B of the **same singleton School**, sharing the existing active Academic Year/Class as permitted by the frozen local fixtures and adding Class/Section capacity revisions. The existing school-wide effective persistent Roll policy/allocator stays authoritative. It enables the existing `student.enrollment.move` permission/operation/ALL-DIRECT scope and inserts a distinct current test role grant and effective school-wide DIRECT P1 policy. No new production function, permission, SQL migration or public grant is introduced.

## Test A: photo transition wins, then genuine protected END

- For the first newly placed Student, issue and consume a native PostgreSQL photo-intent token at Campus A.
- Start `FINALIZE_TRIAL` on the native PG ledger, holding the Student lock and a valid consumed token row update uncommitted at a **test-only precommit pause seam**. No file, image byte, or Photo SET is affected.
- Run the genuine public authenticated `app.d1_end_student_enrollment` P1 DIRECT operation concurrently. A separate observer must identify a real pending tuple/transaction-ID lock on that named worker blocked by the photo transaction's precise PostgreSQL backend PID.
- Release the photo worker, demand successful FINALIZED_TRIAL commit **before** genuine Enrollment END completes, and then demand protected END commit as well. Verify the Student has no current PRIMARY, and fresh photo ISSUE/finalize is denied. This tests serializability of permission at the photo transaction's lock-winner point; it does **not** prove production file finalization.

## Test B: protected Campus A → Campus B transfer wins

- For the second new Student, issue one still-ISSUED token and one already-CONSUMED token, both scoped to Campus A.
- Invoke the genuine public authenticated `app.d1_move_student_enrollment(...,'CAMPUS_TRANSFER',CURRENT_DATE,...)` P1 DIRECT RPC for source Campus A Section and destination Campus B Section. Hold its transaction open with the Student lock.
- Two independent Student executor sessions attempt CONSUME and FINALIZE_TRIAL, respectively. A third session observes **two real blocked PostgreSQL PIDs** and their complete direct/soft-blocking dependency paths to the P1 MOVE holder before the move transaction commits.
- On commit, verify one effective PRIMARY in Campus B, the stale Campus A tokens left unchanged, and fresh attempts to ISSUE/CONSUME/FINALIZE_TRIAL through old Campus A denied by the existing live Principal+PRIMARY Campus-scope resolver.

The test is fail-closed: it does not accept a missing blocked lock, a direct Enrollment/Roll bypass, a fake Campus B, or a stale photo token advancing after transfer.

## Acceptance contract

The exact PR head must pass Foundation database `220/220`, D1 business `3124/3124`, earlier `D1_STUDENT_PHOTO_NATIVE_PG_INTENT_PASS`, `D1_STUDENT_PHOTO_REAL_PG_HANDOFF_PASS`, `D1_STUDENT_PHOTO_PROTECTED_END_INTENT_RACE_PASS`, and new **`D1_STUDENT_PHOTO_REVERSE_END_CAMPUS_TRANSFER_RACES_PASS`**, followed by `D1C2A_PASS`. No merge if any of these are absent or any workflow fails.

## Nonactivation boundaries

All identities and photo grants are synthetic and injected by the privileged local test fixture, not a production identity or authorizing service. This does not implement signed service-to-service issuance, persistent provider-neutral media objects, actual `file.upload` entitlement, subscription/module/purpose verification, image sanitation-to-File hash binding, File `AVAILABLE`, Student Profile P1 Photo SET or hosted Supabase activation. The precommit pause hook exists only on the test-side Python method and is not an API. The reverse test proves photo-first on `FINALIZE_TRIAL` but does not cover every possible photo-first CONSUME case or a MOVE → revised-scope ISSUE. Multi-host retries, crash recovery and production lock throughput still need separate tests.

**School example:** A staff member starts completing a test photo intent for a Campus A Student. The genuine Enrollment END must wait for that existing valid operation to commit, and only then can END close the placement. For another Student, an administrator moves their real protected Enrollment from Campus A to Campus B first; earlier Campus A photo tokens cannot be used after the move. **No actual photograph is uploaded.**

**Project status:** 31/35 protected operations accepted, #67 photo SET remains DENY, #68–70 not accepted. Migration 10 remains non-executable `.sql.draft`.
