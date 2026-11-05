# DB03 P39 — handoff must bind the same application, Person, fee and Grade

**5 November 2026 — inactive SQL draft only.** Based on P38 private deny-only Student handoff storage merged into draft PR #102. No Principal APPROVE command, no D1 Student creation and no production database change.

## Why this additional safeguard is needed

P38 records a final application's Forward, identity resolution, Person, declared fee status, destination Grade/Section, approval receipt and a later Student result. Its individual foreign keys prove that the referenced rows *exist*, but by themselves cannot prove that they all belong to **the same application**.

**Example:** Ahmad's Grade 1 admission must never be able to reuse an original identity resolution, administrative fee declaration or Grade destination that was recorded for Fatima. Checking only whether each UUID exists is insufficient. If the future Principal APPROVE writer were to confuse references, a wrongly combined handoff might be saved.

## What P39 enforces at the database level

- `identity_resolution_id + application_id + person_id` must resolve to **the same original identity proof**.
- `fee_disposition_id + application_id` must match a fee declaration for **that same application**.
- A new required `destination_intent_id` binds `application_id + class_offering_id` to the **same recorded Grade destination**.
- Each source gains a narrow composite unique parent key (the existing source records are unchanged). The handoff uses three composite foreign keys to these keys.
- P38's composite `forward_id + application_id` foreign key, one-handoff-per-application uniqueness, forced row-level security and absolute write-denial triggers remain unchanged.

This is database integrity, **not** proof that the referenced records are the latest approved revisions. The future authorized Principal approval must lock and verify the latest Forward, review, identity, fee and Grade head, with P37 verified Section, then confirm live authority, active year, full capacity, roll policy and D1 dual permissions.

## Acceptance

- 17 rollback-only pgTAP tests inspect exact composite reference shapes, required destination, existing one-application uniqueness, private role denials, denied INSERT, forced RLS and no public APPROVE.
- CI deliberately fails a P39 installation to prove that all six constraints and the destination column roll back completely, before installing and testing P39 in a **disposable** database.
- The prior real PDF-backed signed-Auth Principal RETURN/REJECT/P36/P37 integration tests must continue to pass.

**Blocked next step:** a jointly reviewed and tested Principal-only APPROVE and real D1 `student.create` function that issues and consumes the single-use handoff in the same transaction as permanent Student ID, status, PRIMARY Section Enrollment, roll, verified file lineage, receipt/audit/outbox. Current `app_private.admission_student_handoffs` is deliberately **unwritable** and does not authorize an approved school admission.

Do not merge `main`, release migrations or enable student.create on this source-only evidence.
