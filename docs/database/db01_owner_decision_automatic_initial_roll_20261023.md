# DB01-ROLL-INITIAL-01 — Automatic initial Roll allocation

**Product owner decision:** APPROVED — Option A, 2026-10-23.

**Decision:** EduSync automatically allocates the initial Roll number when an authorized enrollment/initial placement succeeds. The application must not offer manually typed first-Roll numbers as an enrollment input or a standard override. Staff may initiate a separately authorized **Roll correction** after allocation, supplying the proposed corrected number and a reason. A correction must pass the existing scoped `student.roll.correct` DIRECT or APPROVAL route and all live policy, duplicate, source-version, date, authorization and immutable-evidence checks; no correction is implicit in Student creation or initial placement.

## Plain example

With the applicable school Roll policy beginning at 1001 and no previously reserved values in the namespace:

1. First successfully enrolled student receives Roll 1001 from the server-owned allocator.
2. Second successfully enrolled student receives Roll 1002; staff do not type 1002 into an initial Roll field.
3. If 1002 is incorrect, authorized staff may request correction to 1050. EduSync validates current authorization, active source allocation, policy namespace, number collision and route; when accepted, the prior Roll remains in retained history while 1050 becomes current. No other student's Roll is silently renumbered.

The sequence is illustrative. The actual next available value and namespace depend on the school's **existing** Roll policy, retained reservations/allocator state and effective date.

## Scope of this approval

- **Initial Roll:** server-assigned by existing `student.enrollment.place` / allocator path, never by manual first-Roll entry. Keep the Roll field read-only/display-only (or omit it from the initial enrollment form), show the value after successful allocation, and use the returned server value as canonical.
- **Authorized correction:** separate action following initial assignment. The correction operator supplies the *proposed new numeric value* only through the reviewed `student.roll.correct` workflow. The correction is not an initial enrollment shortcut and is not an arbitrary UPDATE of retained `roll_allocations`.
- **Existing policy modes retained:** `PERSISTENT_STUDENT` (persistent Student number) versus `ACADEMIC_CONTEXT` (number allocated within configured Class/Academic context). This choice does not select a mode for every school, modify the start value, or resolve the separate DB02 Roll-policy-change contract.
- **Uniqueness/concurrency/history:** preserve checked allocator locks, namespace collision/retained reservations, Student/Enrollment source, old `effective_until` / new `supersedes_id` and origin lineage; replay of initial placement or correction must not allocate a duplicate number or duplicate evidence.
- **Admissions integration:** the applicant may become a Student before or as part of enrollment depending on the separately approved Admissions handoff. Automatic Roll assignment occurs at the **accepted initial enrollment/placement** command, not merely upon submitting an application and not from `student.create` alone.
- **No second choice created:** This owner decision approves **automatic-only initial assignment**, not optional manual first-entry, not forced numbering at admission, not arbitrary number resetting, and not a new permission or authorization bypass.

## Engineering/product acceptance implications

1. Initial Enrollment UI does **not** include a user-editable numeric Roll input or `manual_initial_roll` override.
2. Authorized P0 enrollment response supplies the automatically allocated canonical number and retained Roll allocation identifier; same-key retry returns that same allocation.
3. Staff can find the Student's currently effective Roll through existing authorized views; initial allocation and later correction remain independently auditable.
4. Correction UI is separate from Enrollment UI and is restricted to users authorized for `student.roll.correct`; if P1 approval is configured, an independent authorized reviewer must approve before APPLY.
5. Collision, wrong Campus/Section namespace, no-op correction, stale source, invalid School-local date, concurrent placement/correction, unauthorized correction, and duplicate APPLY all fail closed without renumbering unrelated Students.
6. Future implementation or review of initial admission/enrollment screens should verify the **absence** of a manual initial-number field.

## Boundary and cross-workstream ownership

Existing [P0 Roll test #61](../../supabase/tests/domain/61_student_enrollment_place_p0_initial_roll.sql) proves a protected enrollment received its first number from the allocator without a pre-seeded Roll. DB01-01 through DB01-07 have separate draft acceptance evidence for authorized correction and concurrent effects. These are **not** proof the production UI is implemented or production-enabled.

Record this as a **DB01 product-owner workflow requirement** and communicate the input constraint to the Admissions/Enrollment UI owner and DB02 for compatibility. **Do not** change DB02 policy, modes, start values, allocation namespaces, approvals, SQL or migrations in this documentation task. Existing DB02/DB03/DB04 contracts require their own owners' integration and review.

All SQL remains `.sql.draft`; PR #141 remains draft and unmerged. This decision does not authorize schema activation, Supabase deployment, merging or production release.
