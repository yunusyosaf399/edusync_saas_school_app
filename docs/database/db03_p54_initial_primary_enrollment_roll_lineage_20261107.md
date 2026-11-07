# DB03 P54 — mandatory exact initial PRIMARY Enrollment and roll

Status: **INACTIVE draft prerequisite**, based on parent PR #102 `84d3ae8ef75af8faeb454c3b09fdfe1b9ee664be`. No Principal APPROVE, Student create, placement, roll-allocator or production write is exposed.

## Why
P38/P50 require a consumed Admissions→D1 Student handoff for final Principal approval, and P53 matches the exact Student, Person and permanent Admission number. But the handoff did not retain the actual D1 initial **PRIMARY Enrollment** and the roll allocation. A future writer could otherwise select the right Section while recording an unrelated Student's Enrollment or Roll.

## Invariants
- Add immutable referenced composite key on D1 `enrollments(id,student_id,section_offering_id,placement_kind,entry_kind)`, and D1 `roll_allocations(id,enrollment_id,student_id)`.
- Add handoff `result_enrollment_id`, `result_roll_allocation_id`, and immutable enforced `PRIMARY` / `INITIAL` identity indicators.
- READY state cannot claim a created Enrollment or roll; CONSUMED must have both. P38 already requires the Student ID in CONSUMED.
- Deferred composite FKs require the initial Enrollment to match the handoff's **same Student and Section**, and the roll allocation to belong to that **same Enrollment and Student** at COMMIT. Unique IDs prevent using a historical Enrollment or roll as the origin of two admissions.
- Do **not** foreign-key to mutable `placement_state` or `effective_until`, because a future legitimate promotion or transfer closes the initial placement and may close/supersede roll records.

## Still required
The future protected D1 runtime must actually lock/check capacity and roll policy, allocate a school Student ID, create Student and first status, place INITIAL PRIMARY Enrollment, allocate a roll, and consume the exact handoff **in one transaction**. A real approved success path, idempotency, concurrency and rollback tests remain blocked until that writer is implemented. Do not treat catalog/denial assertions as proof of an enabled writer.

## Tests
34 rollback-only pgTAP assertions with a disposable DB installation plus injected failed-install rollback. No hosted Supabase, no `main` merge, no new grants or policy bypass.
