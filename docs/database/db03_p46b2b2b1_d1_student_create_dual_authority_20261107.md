# DB03 P46B-2B2B1 — D1 Student-create dual authority prerequisite

**7 November 2026 · inactive draft SQL; Student creation remains explicitly blocked.**

## Cross-package blocker identified in the frozen D1 contract

D1 Effect 36 and [Student creation contract readiness](155_d1_student_create_admissions_handoff_contract_readiness.md) require a **trusted final, single-use Admissions handoff** and separate current permission/scope checks for **both** `student.create` and `student.enrollment.place`. The `student.create` operation remains intentionally disabled. No legitimate final Student/roll/receipt writer exists yet; activating an APPROVE command would violate this contract.

P46B-2B2A already guarantees a Principal approval source cannot commit without the matching CONSUMED single-use handoff. This increment closes the missing **D1 authorization source**, without weakening any deny-all storage or activating operations.

## New SQL proposal

`supabase/proposals/db03/51_01_student_create_dual_authority.sql.draft`

- `app_private.db03_student_create_dual_authority(actor, campus, class_offering, section_offering)` is a private `SECURITY DEFINER` function owned by NOLOGIN `schoolos_authz_reader`, with fixed `pg_catalog,pg_temp` search path. It exposes only an opaque 32-byte authorization fingerprint or NULL.
- Requires READ COMMITTED, real non-expired JWT, current authenticated **INDIVIDUAL** Principal, matching actor UUID, active Principal.
- Resolves exact D1 Section → Class → Campus ancestry; Class and Section must both be OPEN.
- Requires **enabled** and correctly typed operation contracts and permissions for `student.create` **and** `student.enrollment.place`. It never seeds or enables either.
- Delegates current placement permission/scope to D1's existing `d1_enrollment_place_authorized`; independently verifies the live `student.create` grant over the exact ALL/CAMPUS/CLASS/SECTION ancestry with active role, live role-assignment/grant/scope windows, and DIRECT resolver.
- Hashes the current actor/version, exact destination, operation IDs/versions and `student.create` grant revisions. The eventual final approval command must repeat this proof **after its locks** and compare the result to reject revocations or stale authorization. Placement grant must be rechecked for itself on repeat.
- `schoolos_workflow_executor` alone may EXECUTE the private function for future composition with P49 Principal policy preflight. No client, file, D1 Student or evidence worker role can execute it. Authorization-reader SELECT/RLS is restricted to the exact Class/Section/operation metadata needed.

## Verification and boundary

31 pgTAP assertions check owner, fixed search path, denied public/worker execution, D1 read permissions, still-forced RLS, unchanged P44/P38/P41/P50 write-deny triggers, and NULL returns for malformed/forged actor intents. CI tests injected-install failure and complete transaction rollback before committed candidate tests in disposable PostgreSQL.

**This is not yet the atomic Principal APPROVE/D1 write operation.** No Student, admission number, receipt/audit/outbox or Enrollment is written; no `student.create` entrypoint is enabled. It cannot pass positive authorized creation acceptance until the separately approved D1 implementation exists.

## Next positive implementation

Build the trusted, typed D1 Student-create effect with permanent `school_student_id` allocation, status, PRIMARY Enrollment, roll and capacity under the frozen D1 transaction contract; compose it with P49 policy preflight, P50 approval/consumed-handoff cyclic FKs, command idempotency and audit/outbox; prove two-session races and rollback before **any** production release.

**Release:** Child PR only targets draft #102. No Foundation migration, `main`, production Supabase, or `student.create` activation.
