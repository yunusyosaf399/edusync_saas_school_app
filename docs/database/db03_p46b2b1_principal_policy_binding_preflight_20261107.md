# DB03 P46B-2B1 — Principal-authorized policy binding preflight

**7 November 2026 — inactive draft candidate; no policy-binding writer.**

## Why this is separate from APPROVE

The owner decided: Administrator creates a DRAFT and prepares/forwards completed documents; **only the Principal** can ultimately approve, which must atomically create the Student, Student ID, admission number and first enrollment. P44 snapshot writes remain disabled until that all-or-nothing final operation exists. A separate pre-approval policy binding command would risk a successful binding with a failed Student handoff.

P46A already derives the original policy from a live Forward and its exact Intake, P46B-1 enforces cross-record provenance, and P46B-2A prevents skipped revisions and duplicate Forward bindings. P46B-2B1 adds a **private authorization and lock preflight**, not a new policy selector or a writable binding.

## Added

- `app_private.db03_principal_policy_binding_preflight(application_uuid,expected_application_version,forward_uuid,expected_prior_revision)`, owned by NOLOGIN `schoolos_workflow_executor`, SECURITY DEFINER with fixed search_path, no external EXECUTE grants or public `app.*` endpoint.
- Reuses the exact **Principal** operation/role-scope authority `db03_principal_final_actor`; this requires a current INDIVIDUAL actor, valid JWT expiration and the separately activated `admission.final.decide` contract/grant. Nothing is seeded or enabled here. Actor and proof are checked twice after locks.
- Locks Foundation authorization fence, scoped actor advisory key, School, Campus, Academic Year, and Application in the existing order. Revalidates current DRAFT, matching version/epoch and still-NULL `admission_applications.policy_version_id` (S5).
- Reads last Forward and linked Intake, delegates to the P46A published-at-Forward candidate source, compares the exact source IDs, and checks latest prior binding revision and replay uniqueness. Returns privately scoped source values with `policy_binding_committed=false`, `can_bind=false`, `can_approve=false`, `can_create_student=false`.
- Allows the workflow executor **read-only** SELECT access to P44 policy snapshots and EXECUTE to P46A source so it can validate revision history; direct INSERT/UPDATE/DELETE remain denied by grants, forced RLS and the P44 mutation trigger. No client access is introduced.

## Test boundary

24 pgTAP structural/security assertions validate function definition/owner, denied actor roles, the restricted workflow read path, unchanged P44 mutation guard and S5 NULL projection, and typed-intent fail-closed rejection. CI uses injected failed-install transaction rollback and tests the committed candidate on a disposable Supabase database after all preceding DB03 candidates. No real Principal authorization fixture is seeded, so **an authorized positive-binding transaction has NOT been demonstrated**. No snapshot, receipt, audit, or outbox record is written.

## Later work

A future **single protected final APPROVE operation** must call this preflight **inside the transaction**, recheck authority and version under the same locks, write the exact P44 policy snapshot plus receipt/audit/outbox, reconcile S5 NULL projection without permitting stale edits, enforce fee status distinct from verified settlement, allocate D1 Student/Enrollment/admission number, and roll all effects back on any failure. Until it exists, no `admission.final.decide` activation or production migration is authorized.

**Safety:** draft .sql.draft only, parent PR #102 remains draft; no `main` merge, hosted Supabase changes, migration activation, or Student creation.
