# DB-03 P27 — Principal review input preflight (inactive, 2026-11-01)

**Status: private read-only candidate; final Principal approval is NOT implemented.** This increment sits on DB03 #203 (`fabaaeb871874107db28346ef4db688eb34e837e`), without touching its five changed files or D1/DB01/DB02 PR #168. DB03 #203 has already passed the disposable Forward-readiness checks, but those checks explicitly report `Principal_decision_unavailable=true`.

## What P27 provides

`app_private.db03_principal_review_preflight(application)` is an **internal schema-owner-only** JSON source that combines the existing, private `db03_principal_final_source_snapshot` (identity and reviewed document evidence) and `db03_forward_details_current` (current recorded destination plus explicit admin admission-fee disposition). It also reports whether a Forward record exists. NULL or unknown/non-DRAFT applications return SQL NULL. It does not read or expose private certificate bytes or any applicant contact information to an application caller.

The result exposes source-observation indicators: `identity_source_current`, `document_source_current`, `destination_and_fee_sources_current`, `forward_record_present`, and `review_inputs_observed`. **These are not final approval eligibility or authorized command results.** In particular, `forward_record_present` is deliberately **not** asserted to be the current reviewed Forward snapshot or its exact document hash, and `review_inputs_observed` is not an access decision. No authenticated client, Finance executor, Foundation workflow executor or document worker can execute this function.

It always returns `principal_final_decision_recorded=false`, `single_use_handoff_available=false`, `student_create_enabled=false`, `can_issue_final_decision=false`, `can_create_student=false`, and `status=CROSS_DOMAIN_HANDOFF_PENDING`. This is an explicit **NO-GO**, not a placeholder command masquerading as a successful Principal approval.

## Owner requirements retained

- Administrators may save incomplete DRAFT applications; required birth/leaving or transfer certificates must be present under the current published document policy before Forward. A Principal, independently authorized and distinct from the certificate uploader, alone reviews originals, identity and final admission decision.
- Latest recorded admission fee **SKIPPED**, **MARKED_PAID** and **UNPAID** must be current and receipt-backed. UNPAID by itself does not forbid forwarding or Principal approval; MARKED_PAID is an administrative declaration, not a Finance bank settlement.
- A FAILED assessment cannot be bypassed. An administration test-skip requires separate Foundation independent approval and current policy. P27 does not assert these later source gates are fulfilled.
- A real Principal APPROVE, RETURN or REJECT, including any final Student creation on APPROVE, must be performed through an authenticated protected operation that revalidates current authority and all original sources **after locks**. Approval and accepted single-consumption handoff must be atomic with D1 Student/ID/admission number/Enrollment/Roll/document lineage and receipt/audit/outbox. Any failure rolls back everything; same-key replay cannot produce a second Student.
- DB03 #191's legacy `can_finalize=false`, the deny-only Finance S10 guard, and D1 #65's disabled `student.create` remain unchanged. This private preflight is not an authoritative final decision and does not authorize disabling these guards.

## Acceptance in this increment

1. Exactly one new inactive `.sql.draft` private function, no new table, public RPC, role seed, insert/update/delete, grant to any application/worker role or executable migration.
2. Exact registration in DB03 disposable source runner after #26; injected install failure must roll back the preflight function completely before successful install.
3. 18 rollback-only pgTAP assertions: privilege scope, SECURITY INVOKER, missing application denial, current source composition, explicit nonauthorization and absence of fabricated `admission_handoffs`.
4. Retain all S1–S26 tests, Auth service/race tests and DB01/DB02 tests unchanged. Exact-head DB03 source CI and disposable runtime required before merge.

## Next actual engineering task

Implement the **Principal final REVIEW→APPROVE/RETURN/REJECT contract and protected action** against current Forward snapshot and independently reviewed certificate/Person/assessment evidence; agree a joint DB03+D1 atomic creation contract **before** enabling final APPROVE. Until then a positive Principal decision and D1 Student creation remain incomplete. The next owner must coordinate with DB01/DB02 for School→policy→pool locking, DB04 for placement consumers and Finance for separate payment authority. Do not directly merge DB03 SQL fragments into PR #168 without a composed acceptance rehearsal.

No hosted Supabase change, production permission, client activation, merger to `main` or security/release waiver is made by this PR.
