# DB03 P36 — private Principal APPROVE source-binding increment

**5 November 2026 — inactive candidate only.** Base: draft parent PR #102 at `fad6ab52b19e00ef2e7a132c5889a848049aa8ce`. This increment introduces an internal **read-only source projection**, not a Principal APPROVE operation, final handoff, migration, permission seed, Student, Enrollment or Roll creation.

## Product rule reconciled

The [1 November owner decision](db03_owner_draft_forward_principal_fee_status_20261101.md) supersedes older unconditional admission-fee clearance assumptions. Administrator dispositions `UNPAID`, `SKIPPED` and `MARKED_PAID` are all explicit, versioned declarations; `UNPAID` **may be forwarded and approved**. The liability remains due. `MARKED_PAID` must **never** be treated as verified bank settlement. The separately authorized Finance ledger continues to govern any real obligation, receipt, allocation, adjustment or reversal.

Only the Principal may make final admission decisions. Admin creates and forwards completed applications with actual private certificates and current review evidence; final APPROVE must one day create the canonical Person/Student, permanent School Student ID, initial Enrollment and Roll **atomically** and exactly once. A client flag must never create a Student. This candidate does not claim that effect.

## Added internal source

`app_private.db03_principal_approve_input_source(application_id,expected_version,forward_id)` is fixed-owner, SECURITY INVOKER and unavailable to `PUBLIC`, `authenticated`, `anon`, `service_role`, file worker, workflow executor and other private executors.

It reads **existing authoritative sources** without allocating or updating anything: application state/version, latest actual Forward and live snapshot, current original-inspection Person resolution, independently reviewed document clearance, current typed D1 class offering/destination intent, and latest School administrator admission-fee disposition with receipt checks performed by the existing forward-details source. It distinguishes each missing/obsolete source and exposes only an internal diagnostic. The current `UNPAID` disposition remains a legitimate observation, never a Finance payment assertion.

Every result explicitly fixes `principal_approve_authorized=false`, `atomic_student_handoff_available=false`, `can_approve=false`, and `can_create_student=false`. Even a source-complete review remains `ATOMIC_D1_STUDENT_HANDOFF_NOT_IMPLEMENTED`. There is no separate unchecked helper that can issue READY, claim clearance or call `student.create`.

## Acceptance and next actual implementation

- Static CI restricts the source to **one private read-only function**, no tables, actor grants, data mutations or public commands; verifies fail-closed status.
- Exactly **18 rollback-only pgTAP assertions** check owner, SECURITY INVOKER, safe search path, client/worker/private-executor privilege denial, invalid/stale/no-input denial and absence of public APPROVE.
- Existing signed-auth P35B positive runtime uploads an actual private PDF, records explicit `UNPAID`, binds a typed D1 grade, forwards the real evidence and checks the P36 source against that exact application, current version and Forward. A changed expected version must be rejected while positive APPROVE remains unavailable.
- CI also injects a failed installation and proves P36 source absence before successful disposable installation. No hosted Supabase data is modified.

**Still blocked:** Principal APPROVE's actual final authority authorization after locks; independent review and canonical Person/identity source; School/Campus/Year/Grade/Section and capacity; D1 `student.create` + `student.enrollment.place` live grants; DB01/DB02 roll policy/allocator ordering; permanent Student ID; private original-file-to-Student lineage; typed single-use Admission→D1 handoff; final Student/Enrollment/Roll allocation and success receipt/audit/outbox in **one transaction**; observed concurrent competing approval, replay and simulated rollback. None of these may be simulated by test-only flags or an ad hoc privileged Student INSERT.

Keep this PR draft until exact-head DB03 source, rollback/runtime and real-Auth integration tests pass. Parent #102, `main`, migrations and real permissions remain untouched.
