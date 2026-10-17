# D1 Student PROFILE restricted history — additive physical candidate

Date: 2026-10-17. **Status: UNVERIFIED SQL/CI CANDIDATE; NOT A MIGRATION OR RELEASE.** Owner product contract: #173; privacy retention decision: ADR-005; frozen PR #78 checkpoint: #175. This gate is a reviewed physical starting point, not authorization to install a 35th D1 relation.

## SQL candidate (not assembled with Migration 10)

The proposed app_private.student_profile_revisions relation is kept at supabase/proposals/student_profile_history_v1.sql.draft. It has one immutable UUID primary key, immutable Student FK, unique (student_id, new_row_version) and receipt FK, optional approval-request FK, individual actor composite FK, and old/new photo metadata FKs. Six **typed nullable old/new pairs** record DOB, gender, nationality, general contact, previous school and photo ID, with no Identity/Special or unstructured Student table JSON. A CHECK demands new_row_version = old_row_version + 1 and a real old/new change. The private reason is nonblank. Index (student_id,new_row_version DESC,occurred_at DESC) supports a future purpose-checked historical chronology.

PostgreSQL security: ENABLE and FORCE RLS, exactly one schema-owner maintenance policy, no authenticated/anon/service_role/executor table grants, no public history read/insert helper. An immutable trigger denies UPDATE and DELETE for ordinary DML. No D1 base relation, operation contract, permission, live grant or hosted school is changed. Foundation 9 and frozen Migration 10 remain as they were. Do not copy private values into broad outbox/receipts.

## Reproducible rollback-only CI

The new tools/supabase/domain_profile_history_candidate_ci.py script is called by the disposable local D1 harness after its existing 74 suites and real-lock checks; only when the exact verified local Docker container is running. It executes candidate DDL under BEGIN/ROLLBACK, checks forced RLS, unique and FK counts, immutability trigger and absence of table privileges for ordinary callers, then checks an impossible row-version transition is rejected. A separate connection confirms that the candidate table no longer exists. Unit source guards refuse COMMIT, RLS removal, migration-path drift or client GRANT. D1 draft-static workflow includes these guards. **Results remain unverified until exact-head GitHub Actions completes.**

## Still blocked before installation

- The final additive migration version, transactional deployment/upgrade plan, legal retention/purge policy and checked forensic-read authorization require independent approval. No delete/read policy is decided in this candidate.
- Actual DIRECT and APPROVAL APPLY have not been wired to a restricted history writer. They must capture an authentic locked preimage and postimage, enforce receipt operation/source/version and current individual authority, validate photo entitlement and require exactly one history row in the same transaction. An accepted mutation must not commit without matching history.
- The existing Student Profile positional RPC overwrites omitted fields with NULL and DIRECT lacks a reason, violating frozen SP-02/SP-04. Replace through separately tested typed tri-state fixed Student commands, preserving unrelated Employee RPC.
- No accepted-operation count is increased: **31/35**. Issue #67, Roll Correction #68, Roll Policy #69, Student Creation #70 remain open. D1 release and Migration 10 remain inactive.

**Simple scenario:** correction of previous school from School A to School B must eventually retain an old/new pair with the Student's two row versions and the private reason, while broad event consumers learn only that a profile version changed. This proposal validates just the table security/shape—not that end-to-end operation yet.
