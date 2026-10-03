# D1C1B Effect 24/36 — Student Status Correction SQL review

**Status: IMPLEMENTATION CANDIDATE — EXACT-SHA CI PASSED; FREEZE PENDING DOCUMENTATION.**

Trusted runtime candidate SHA: `a699016cef97449686cb3c0184b078c76cb06175`.

Effect 24 implements `student.status.correct` as the mandatory-P2 factual correction path for retained Student lifecycle history. It does not perform an ordinary transition and does not mutate retained Enrollment/Roll history.

## Approved behavior

- Mandatory P2 only: submit → review → apply using `student.status.approve`; no DIRECT route.
- Correction targets one exact still-authoritative status transition. An already-superseded source cannot be corrected again as though current.
- Source history is immutable and retained. Success appends one new numbered `student_status_transitions` row with `supersedes_id=source_transition_id`.
- Client supplies corrected `new_status` and `effective_on`; `previous_status` is derived from the resulting authoritative chain, not client supplied.
- Factual no-op is rejected. Reason-only change never creates another status event.
- The entire resulting non-superseded status chain is rebuilt in `(effective_on, sequence_number)` order. Every event's prior-state continuity and chronology are revalidated; incompatible downstream events cause rejection rather than silent rewrite.
- `students.current_status` and Student row version are atomically synchronized to the latest authoritative resulting status.
- Status correction does not rewrite, reopen, close or otherwise mutate Enrollment/Roll history. Any corrected status fact that would contradict retained PRIMARY placement history is rejected.
- Historical ACS scope is resolved from the relevant source/corrected business dates. Where no trustworthy placement scope exists, only ALL authority can satisfy the operation.
- Requester and reviewers require current complete grant/scope authority. Reviewer Person must differ from requester Person and match the configured reviewer role.
- Approved apply rechecks current requester authority, completed reviewer authority, policy, expected Student version, source transition authority, corrected chain and Enrollment-history consistency.
- Deterministic stale conditions invalidate APPROVED requests with rejected `request.apply` evidence and no domain mutation/application/success event. Malformed protected request state raises and rolls back.
- Terminal replay occurs before mutation preflight and returns the durable result without duplicate correction, application, lifecycle, audit or outbox evidence.
- Broad audit/outbox excludes arbitrary reason text. Event vocabulary remains `student.status_changed` with correction/source identifiers and minimized status/effective-date/version evidence.
- Successful application is bound to request, operation, receipt, resulting correction transition and resulting Student version.

## Package

Ordered `.sql.draft` continuations:

1. `effect24_01_student_status_correct_core.sql.draft`
2. `effect24_01a_student_status_correct_shape_scope.sql.draft`
3. `effect24_02_student_status_correct_effect.sql.draft`
4. `effect24_03a_student_status_correct_receipt.sql.draft`
5. `effect24_03b_student_status_correct_audit_event.sql.draft`
6. `effect24_04_student_status_correct_submit.sql.draft`
7. `effect24_05_student_status_correct_review_helpers.sql.draft`
8. `effect24_06_student_status_correct_review.sql.draft`
9. `effect24_07_student_status_correct_apply_read.sql.draft`
10. `effect24_08_student_status_correct_apply_hardening.sql.draft`
11. `effect24_09_student_status_correct_application_guard.sql.draft`
12. `effect24_10_student_status_correct_review_hardening.sql.draft`
13. `effect24_11_student_status_correct_apply_lifecycle.sql.draft`

Independent source audit corrected candidate defects before freeze: immutable status history is no longer backfilled with a receipt after insert; review replay rechecks current exact reviewer authority; canonical submit intent/scope validation was hardened; approval terminal transition evidence was completed; apply lifecycle binding was tightened.

Exact-SHA GitHub Actions run #83 (`37115605215`) checked out `a699016cef97449686cb3c0184b078c76cb06175` and passed 121/121 tooling tests and 220/220 Foundation pgTAP assertions with Supabase CLI 2.98.2. Migration 10 remains non-executable `.sql.draft`; this review authorizes no PostgreSQL application, D1C2 execution, remote deployment or staging action.