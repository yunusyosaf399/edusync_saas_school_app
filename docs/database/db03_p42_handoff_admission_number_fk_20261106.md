# DB03 P42 — bind permanent Admission number to the single-use D1 handoff

**6 November 2026. Inactive source-only schema proposal.**

## Problem

P38–P40 guarantee that a future approved application hands off the same Person, Grade, Section, Fee declaration and latest reviewed Forward to D1. P41 independently stores unique permanent Admission numbers with a School/Application/Kind ledger. No database key yet ties the number to that exact handoff.

A mismatched or canceled number must not be able to accompany a valid application into Student creation.

## Added

- A composite referenced key on the P41 immutable number ledger: allocation ID + application ID + Kind + allocation state.
- A required number-allocation reference on each P38 single-use handoff, linked through all four fields.
- Handoff Kind is constrained to **ADMISSION**; its linked allocation state must be **ALLOCATED**. An **APPLICATION** number, an allocation from a different application or a **CANCELED** number cannot satisfy the FK.
- A unique number-to-handoff link and strict RESTRICT behavior preserve lineage.
- 20 rollback-only pgTAP assertions, source-only safety guard, injected failure/rollback probe and combined DB03 regression.

## Example

Application A uses permanent Admission number CHAR-2026-0001. Even if an administrator tried to attach this number to Application B's approved Student handoff, the database FK would reject it. Application A's earlier APPLICATION number and a canceled Admission number are also invalid as permanent Student intake evidence.

## Boundaries and next steps

This is **not an APPROVE command** and does not allocate numbers. The P38 and P41 unconditional write/DELETE/TRUNCATE denial triggers, forced RLS, and client/worker grant restrictions remain in place. School Student ID and roll allocation are still D1 concerns.

Next implement the single authenticated, atomic Principal APPROVE and D1 Student creation command: lock the current application/Forward/Person/Grade/Section, verify the Principal's live authority, original document reviews and School/Year/seat capacity, choose an active published numbering profile, lock and increment the right Series, write an ALLOCATED ADMISSION record, bind the handoff, create D1 Student + initial status + PRIMARY enrollment and roll, record decision/receipts/audit/outbox, then consume handoff. On any failure, rollback every part. Exact replay must not duplicate IDs or Student rows.

Owner's latest fee rule: UNPAID must not automatically bar approval; MARKED_PAID is an administrative declaration, not a verified Finance payment. The historical S10/SC-03 wording must be reconciled before positive APPROVE is enabled.

No live Supabase write, hosted deployment, `main` merge or Student creation.
