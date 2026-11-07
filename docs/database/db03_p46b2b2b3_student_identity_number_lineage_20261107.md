# DB03 P46B-2B2B3: exact D1 Student / Person / Admission number lineage

**Status:** inactive draft proposal, parent PR #102 at `d8910c5c8d0cc48348bf90cd33d6e419725365ba`. Not a final APPROVE command.

## Problem
P38, P42, P45 and P50 secure approval, Person lineage, number allocation and a consumed handoff, but a plain `result_student_id` FK does not ensure that the Student row contains the same Person or the same immutable rendered Admission number.

## Change
P53 adds an immutable handoff `admission_number_text`, a composite FK to the exact allocation `(id,rendered_number)`, and a deferred composite FK to actual D1 `students(id,person_id,admission_number)`. P38 requires a Student ID for CONSUMED, and P50 requires a consumed handoff for final approval. Consequently the Student, Person, and Admission number must match together **at COMMIT**, not just exist separately. READY remains possible before a Student exists. A future writer must server-derive the number from the allocation; it must not accept a client-selected value.

## Safety and remaining work
This is structural integrity only. Forced RLS, P38/P41/P44/P50 deny-all triggers, existing Principal authority, D1 student.create disabled operation, and all old FKs remain. The final atomic writer still needs trusted Student ID and numbering, Student + initial ACTIVE status, PRIMARY Enrollment and capacity/roll, single consumed handoff, idempotent receipt, audit and outbox. The independent D1 admission_serial contract and student creation effect must be reviewed explicitly, rather than equating distinct identifiers without evidence. No owner-bypass fake positive test.

## Acceptance
28 pgTAP catalog/security checks plus failed-install rollback probe in a disposable PostgreSQL/Supabase CI stack. No hosted migration, client grant or main merge.
