# DB03 P45 — same-application policy snapshot to permanent Admission number handoff

**6 November 2026 — inactive database-only source proposal; no hosted migration.**

## Problem

P44 retains which published Admissions policy and its two numbering profiles belong to a specific application, School and Academic Year. P41–P42 retain a number series/allocation and a handoff. Yet without more foreign keys, a future handoff could refer to a valid policy snapshot for Ahmad while using an **ADMISSION number allocated from a different policy's profile or a different academic year**. The independent records all exist but are not yet related strongly enough.

## Added

- Required `policy_snapshot_id`, `admission_number_series_id`, `admission_numbering_profile_id` and `academic_year_id` on the currently empty, deny-all `admission_student_handoffs` table.
- Three composite source keys and three composite foreign keys join:
  1. Handoff to the same **Application, Application version, Stage epoch, Admission profile and year** as the selected P44 policy snapshot.
  2. Handoff number allocation to the exact **Application and Series** of the allocated permanent Admission number.
  3. Handoff Series to the exact **ADMISSION profile and Academic Year** selected by the policy snapshot.
- Through P44's earlier School/Year/Policy/Profile FKs, the combination fails closed against cross-School, cross-Year, wrong-policy, wrong-profile, stale application-version and stale stage-epoch handoff lineage.
- 21 rollback-only pgTAP assertions plus injected-install rollback and full DB03 regression tests. No existing denial trigger, RLS policy, permission or D1 source is changed.

## Example

Ahmad applies in School A, 2026. P44 snapshot S records Policy A's ADMISSION numbering profile `CHAR-2026`. The final handoff must reference S, the matching version and stage epoch, and a number allocation from a Series using **that exact profile and year**. If another valid series belongs to 2027 or to a different profile, its FK chain rejects the handoff.

## Limits and next dependency

**P45 is structural binding, not an active policy-selection command.** The P44 snapshot row and P41 number rows cannot currently be written, even by owner test fixtures, and the P38 handoff writer is also disabled. The S3/S5 application policy projection remains NULL. No Student, roll, number, payment or admission is created.

The next separately reviewed P46 policy-selection writer must reconcile the S3/S5 NULL projection, use a fixed authorized School-scoped actor and current published/effective policy, lock/recheck the exact version, stage epoch and latest policy revision, and commit snapshot/receipt/audit/outbox atomically with robust idempotency and race/rollback tests. Later Principal APPROVE/D1 Student create must use the verified binding and its selected number series in one transaction, accounting for the owner's administrative UNPAID/SKIPPED/MARKED_PAID decision. Never infer policy from the newest unreviewed row, and never trust client-supplied profile IDs.

Parent remains draft PR #102, no `main` merge, no hosted Supabase write or production activation.
