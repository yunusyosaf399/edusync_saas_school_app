# Student Profile typed tri-state + atomic restricted history — rollback-only trial

Date: 2026-10-17. **Status: private algorithm trial, not protected-operation acceptance or executable migration.** Owner-approved SP-01…SP-08 and ADR-005 apply; follow merged physical-candidate PR #79 and CI freeze #177.

## What this engineering slice implements

- New isolated `supabase/proposals/student_profile_typed_atomic_trial.sql.draft` with strict fixed-six-field `UNCHANGED / SET / CLEAR` normalization, canonical intent outputs, value type and blank validation, normalized no-op rejection, and explicit field allowlisting. SQL performs trim normalization on SET and accepts only canonical YYYY-MM-DD dates and UUID-shaped photo identifiers.
- The private `SECURITY INVOKER` trial writer captures the full Student before-image under row lock, rejects stale expected version, verifies an individual Principal and a matching **successful pre-issued** Student Profile command receipt, updates exactly the six allowed PROFILE fields, and writes one typed before/after immutable revision **in the same PostgreSQL transaction**. It cannot be called by any authenticated or app executor. It never touches Employee Profile.
- New disposable local PostgreSQL smoke uses a synthetic local fixture to exercise a successful previous-school change, untouched contact/gender, history old/new snapshot and reason, duplicate/stale attempt rejection, CLEAR versus UNCHANGED, invalid date, null SET, whitespace-only SET, all-unchanged no-op, and unknown field. SQL executes after the PR #79 history-table candidate, inside a single rollback-only transaction, then verifies the trial function and history relation no longer exist.
- The existing D1 34-table Migration 10, 74 business suites, all frozen Foundation migrations/tests and live grants remain unchanged. The static workflow includes fail-closed source unit checks. A source-level CI pass does **not** establish the actual public DIRECT/APPROVAL contract.

## Unimplemented high-risk release gates

- **No public Student Profile RPC is replaced or activated**, and no new authenticated entry point is created. The old Student positional RPC still cannot preserve UNCHANGED vs CLEAR, and DIRECT still lacks the mandatory private reason; neither is accepted.
- The trial operates only under the schema-owner role in a throwaway local transaction, deliberately **not** as a production SECURITY DEFINER executor. A live design needs a purpose-scoped no-login history writer, current operation/scope/policy and Principal verification, canonical receipt hash binding, exact request/reviewer/approval participant binding, no-photo-SET without validated Student ownership/entitlement, and a transactional guarantee that every successful DIRECT/APPLY produces history.
- No hosted database migration, deployment, update/insert/delete/SELECT grants to user-facing roles, retention/legal-erasure decision or history forensic read API is authorized by this test.
- Independent physical/security/retention review, authenticated full-path DIRECT+SUBMIT+REVIEW+APPLY per-field tests, real two-session races, and exact-head three-workflow green result remain required before operation acceptance. Count stays **31/35**. No issue closure or change to issue #67.

**Example:** a local trial changing Previous School from Old School to Other School preserves General Contact `1234`; the immutable history records both school names and the reason. A real school profile command cannot use this code until the remaining release protections are implemented and approved.
