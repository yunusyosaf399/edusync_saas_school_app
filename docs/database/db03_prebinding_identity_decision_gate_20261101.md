# DB03 pre-binding identity gate

Status: owner resolved the initial-draft question on 1 November 2026. The administrator may save an incomplete DRAFT without extensive verification or an initial identity identifier. See [owner workflow decision](db03_owner_draft_forward_principal_fee_status_20261101.md). This is product direction, not an executable migration.

## Current source and invariant

P2-D01 permits `person_id NULL` in DRAFT. `app.create_admission_draft(campus_id,academic_year_id,key)` has no child identifier; two distinct opaque creates cannot be proven to concern the same child. A name or spelling heuristic cannot be a unique identity constraint. The owner accepts that unresolved drafts can coexist until Principal review. Reuse the existing draft and exact idempotency key for one administrator's repeated save, retain history, and show missing items in a checked private queue. Staff should search authorized pending work before starting another draft, but UI search is not a guarantee.

At forward/review, the Principal inspects the complete application, original/certificate evidence and potential matches. A verified canonical Person is bound or created before final acceptance. PR #199 enforces one nonterminal application per bound Person across the school; a second draft trying to bind the same Person receives a generic conflict. A Person already attached to a Student cannot produce a duplicate new Student. Different children proceed independently. No client name-only auto-merge or raw identity disclosure.

## Acceptance and later extension

Test two opaque drafts resolving to the same Person, across campuses and years, while preserving both records and allowing only one final Student. Verify correction/withdrawal/reapplication and Principal authority. If the owner later requires absolute duplicate prevention at the first opaque Save, a reliable private identity source and its retention/correction policy must first be approved; such a source cannot be inferred from missing certificates or display names. The former claim/reservation design is therefore deferred.
