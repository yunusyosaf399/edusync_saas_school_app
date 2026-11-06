# DB03 P41 — private admission number counter and allocation storage

**6 November 2026. Inactive SQL proposal and disposable tests only.**

## Problem

D1 owns the future permanent School Student ID and roll allocators. Admissions must separately issue an immutable school-facing admission number and numeric serial before an accepted application becomes a Student. S1 already defines format inputs (prefix, separator, session year, digit width and start value), but the DB03 draft did not yet implement a counter and retained allocation ledger.

Example format: CHAR-2026-0001. This is illustrative only, not an issued number or chosen default.

## Added

- A private admission_number_series counter per existing numbering profile and academic year, tied by composite FKs to the same School and number Kind.
- A private admission_number_allocations history, tied to the exact School/application and Series/Kind/Session.
- Defensive uniqueness: one Profile/Year Series; one numeric value per Series; one rendered identifier per School/Kind; one allocation per Application/Kind even if canceled.
- Cancellation never deletes or frees a number for reuse; paired cancellation metadata is required.
- Both tables have forced RLS, owner-only policies, revoked client/worker writes and unconditional mutation/TRUNCATE denial triggers.
- Source checks, 20 rollback-only pgTAP assertions, injected failed-install rollback and existing DB03 acceptance.

## Explicit boundaries

**Nothing allocates a number in P41.** No counter advances, no user can issue a number and no Student is created.

The later authorized issuer must lock a Series, validate a PUBLISHED profile, active Academic Year, format/session and overflow against configured digits, then allocate a permanent number with a command receipt in the same atomic Principal APPROVE → D1 Student creation transaction. Never use MAX()+1, client-selected numbering or number recycling.

D1's school_student_id and Section roll remain separate namespaces, allocated only by trusted Student-domain logic.

The owner's newer admission-fee rule still applies: SKIPPED, MARKED_PAID and UNPAID are administrative declarations; UNPAID does not itself block Principal approval, and MARKED_PAID is not official payment evidence. The older S10 Finance gate and D1 SC-03 wording require explicit reconciliation before actual APPROVE is enabled; this P41 storage change does not alter those guards.

## Remaining gates

Bind the future permanent admission allocation to the P38–P40 handoff; implement the protected Principal/D1 one-transaction issuer and consumer; verify current permissions, original documents, identity, Grade/Section, capacity, roll and both ID allocators; test real authentication, exact replay, competing approvals and rollback. No hosted Supabase change, main merge or release.
