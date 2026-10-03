# D1C1B Effect 25/36 — Student Enrollment Place SQL review

**Status: IMPLEMENTATION CANDIDATE REVIEWED — exact-SHA CI PASS; freeze record follows.**

Trusted runtime candidate: `09bd4be80d14d97fd5ddff151b72ba7e13685ef5`.

Effect 25 implements `student.enrollment.place` as the frozen P0 accepted-PRIMARY-placement operation. It does not implement a provisional seat, waitlist, application or Admissions workflow.

## Reviewed behavior

- Public command is `app.d1_place_student_enrollment(...)`; authenticated receives EXECUTE only on that fixed entry point. No authenticated direct base-table DML is added.
- Standalone Effect 25 entry kinds are **INITIAL** and **REENROLLMENT** only. Frozen atomic source→destination movement owns PROMOTION, REPEAT, CLASS_CHANGE, SECTION_CHANGE and CAMPUS_TRANSFER and remains Effect 26 work.
- INITIAL requires Student status ACTIVE, no prior PRIMARY placement and no predecessor.
- REENROLLMENT requires current Student status WITHDRAWN or TRANSFERRED, the latest retained bounded PRIMARY predecessor, no overlapping PRIMARY interval, and a non-future re-enrollment date. It creates a new placement and never reopens the predecessor.
- REENROLLMENT atomically appends the reserved `WITHDRAWN|TRANSFERRED → ACTIVE` Student status transition and synchronizes `students.current_status`; arbitrary reason text remains retained only in protected domain history, not broad evidence.
- Destination authority is current `student.enrollment.place` through the complete ALL/CAMPUS/CLASS/SECTION chain against stored destination ancestry. Placement existence grants nothing.
- The command obtains the Foundation SHARED authorization lock through its fixed receipt context, then follows the frozen roll/enrollment serialization order: School anchor → effective roll policy → mode-specific allocator → Student → Academic Class/Campus/Year/Class Offering/Section path. Destination ancestry/state is re-read after waits.
- Academic ancestry discovery/locking remains owned by `schoolos_academic_executor`; Student-owned functions call fixed typed SECURITY DEFINER helpers and do not receive academic-executor membership.
- PRIMARY interval overlap checks include retained future intervals. INITIAL/REENROLLMENT create one open accepted PRIMARY placement only after predecessor/status checks.
- Class and Section capacity are checked independently at the candidate start and retained interval breakpoints. Either limit exceeding capacity requires current `student.capacity_override`, a nonblank override reason and exactly one immutable `enrollment_capacity_overrides` row. Within-cap placement rejects override evidence.
- Capacity override bypasses only the capacity limit; it never bypasses destination ancestry, status eligibility, predecessor, overlap, roll or authority checks.
- Roll allocation uses the effective school policy. ACADEMIC_CONTEXT allocates from the exact `(policy_revision, class_offering)` namespace; PERSISTENT_STUDENT serializes through the School anchor and persistent allocator namespace.
- Persistent Student roll reuses the numeric value from the latest retained unsuperseded same-Student persistent allocation and stores that exact prior allocation as `origin_allocation_id`. A backdated placement ahead of a retained future persistent allocation fails closed. New persistent allocation scans authoritative cross-Student collisions across persistent policy revisions. No `MAX()+1` path exists.
- The fixed Effect-25 command context canonicalizes the eight-slot typed intent, takes the Foundation SHARED authorization advisory lock plus per-key advisory lock, and binds idempotency to the exact operation/principal/intent/key. The shared command-receipt allowlist is not widened.
- Terminal replay happens before mutation preflight. It rechecks current placement authority and, when used, current capacity-override authority; proves the exact immutable Enrollment, Roll, optional capacity-override UUID and REENROLLMENT status transition; and returns the durable result without duplicate mutation/audit/outbox evidence.
- Durable result summary has an exact 16-key shape including the exact optional `capacity_override_id`.
- Outbox aggregates are domain-correct: `enrollment.created` uses `ENROLLMENT` / new Enrollment UUID / version 1; `enrollment.capacity_overridden` uses `ENROLLMENT_CAPACITY_OVERRIDE` / immutable override UUID / version 1; REENROLLMENT `student.status_changed` uses the Student UUID and resulting Student row version.
- Broad audit/outbox excludes placement reason and capacity-override reason text.

## Independent audit corrections

The implementation was corrected before freeze for:

1. roll lock ordering (policy/allocator was initially after Student/academic locks);
2. restoration of the School serialization anchor across persistent roll policy revisions;
3. academic-executor ownership of academic ancestry reads/locks instead of widening Student executor table privileges;
4. persistent roll lineage selecting the latest authoritative allocation, not the earliest/root allocation;
5. rejection of backdated persistent placement ahead of retained future allocation;
6. terminal replay rechecking conditional `student.capacity_override` authority and proving immutable result rows;
7. a placement-specific fixed command receipt context instead of assuming the shared allowlist accepted the operation;
8. exact durable-result shape/type validation and exact capacity-override UUID binding;
9. immutable outbox aggregate identities instead of reusing unchanged Student aggregate versions for ordinary placement;
10. correction of `CURRENT_DATE` SQL syntax and retention of the actual re-enrollment reason in protected status history;
11. restoring frozen atomic-move ownership of PROMOTION/REPEAT to Effect 26.

## Package

Effect 25 is an ordered set of 23 non-executable `.sql.draft` continuations under `supabase/migrations/20260928000000_domain_package_01_effect25_*`.

Migration 10 remains non-executable `.sql.draft`. This review authorizes no PostgreSQL application, D1C2 execution, remote deployment, worker activation or staging execution.
