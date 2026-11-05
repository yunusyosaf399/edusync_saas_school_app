# DB03 P40 — bind approved Section to its Class Offering

**5 November 2026. Inactive database proposal; no production migration.**

## Problem

P37 can check that Ahmad's intended Grade 1-A section belongs to his Grade 1 Class Offering, but the P38/P39 stored handoff only has separate Section and Class existence foreign keys. Future code could accidentally pair Ahmad's Grade 1 Class Offering with a valid Grade 2 section.

## This increment

- Add a narrow composite Section candidate key, `section_offerings(id,class_offering_id)`, in the **inactive** DB03 proposal stack. D1's existing Section PK and Campus ancestry FK are untouched.
- Add a composite handoff FK `(section_offering_id,class_offering_id)` referencing exactly that key. An existing Section from a different Grade/Class cannot satisfy the new relationship.
- Keep the P39 same-application identity, fee disposition, Grade destination bindings, P38 one-handoff-per-application, forced RLS and absolute deny-all handoff mutation trigger.
- Add 15 rollback-only pgTAP checks. CI first injects a failed P40 installation and verifies both constraints disappear, then installs P40 in a disposable database and tests it. Existing signed-Auth Admissions and D1 source tests must also remain green.

This is a cross-package **schema relationship only**. It neither reserves a seat nor proves the Section is currently OPEN, has room, belongs to an active year or has a valid roll policy. The final Principal APPROVE/Student create transaction still must lock and revalidate School, Campus, Year, Class, Section, the latest identity/documents/fee declaration, live authority and capacity/roll rules after lock waits.

## Owner policy reconciliation required for the positive command

The owner's later decision allows the administrator to record admission fee SKIPPED, MARKED_PAID or UNPAID, and **UNPAID may still be forwarded and approved**. The older S10 denial-only Finance clearance boundary and D1 SC-03 readiness prose must not accidentally turn an UNPAID administrative declaration into a final-approval blocker. This P40 change does not modify either guard or count MARKED_PAID as an official bank payment. Before positive APPROVE, reconcile the Finance distinction and the trusted D1 single-use transaction under a separately reviewed contract.

## Remaining release gates

Implement Principal-only authenticated APPROVE and D1 Student creation as one atomic effect with server-numbered Student and Admissions IDs, initial status, PRIMARY enrollment, Section capacity/roll, one-time handoff consumption, receipt/audit/outbox, exact replay, concurrency and rollback tests. Preserve the dual D1 create/place permission checks; no client-facing approval grants or production activation here.
