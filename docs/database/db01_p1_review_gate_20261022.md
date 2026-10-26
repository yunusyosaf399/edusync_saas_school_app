# DB-01 — Independent P1 APPROVE/REJECT review acceptance (candidate)

**Date:** 2026-10-22. **Status:** DB-01 stacked draft, pending exact-HEAD CI and independent review. Parent: green [PR #136](https://github.com/yunusyosaf399/edusync_saas_school_app/pull/136).

## Contract

P1 APPROVAL SUBMIT creates a verified `PENDING` request with an independently eligible, different-**Person** reviewer. `app.d1_review_student_roll_correction(request_id uuid, decision text, expected_request_version bigint, reason text, idempotency_key text)` implements the approved *separate* authenticated review operation only; `decision` must be `APPROVE` or `REJECT`. No application, correction, Student version increment, allocator movement or `enrollment.roll_corrected` event occurs on REVIEW.

The handler authenticates a **current real Principal** and serializes Foundation/idempotency authority, locks the target request and the exact OPEN step/assignment, verifies original School/Campus P1 APPROVAL policy, one eligible live `student.roll.approve` permission/role/Section grant via the existing `d1_roll_correct_reviewer_candidates` helper and same-Person exclusion, and rechecks authority and policy after contention. Stale expected request versions or a cancelled/rejected/approved request reject any *new* review key.

REJECT marks current step and request `REJECTED` and cancels waiting steps. APPROVE closes one step; if a later configured step exists, it becomes OPEN with reselected live independent candidates, and request remains PENDING with next request version; after the final step it becomes **APPROVED but unapplied**. Exactly one private typed `request.review` receipt and minimally disclosed audit track the successful step decision. An exact same-key replay returns original recorded review state/version after current reviewer eligibility revalidation; changed intent or key cannot alter past review.

## Candidate changes and verification

- `supabase/migrations/20260928000000_domain_package_01_effect41_09_db01_roll_correct_review.sql.draft`: independent protected review RPC and narrow evidence-writer helper. The latter has no public/private authenticated EXECUTE grant and only writes minimal receipt/audit fields.
- `supabase/tests/domain/90_db01_roll_correct_p1_review.sql`: rollback-only authenticated genuine P0+SUBMIT fixture followed by self-review denial, revoked current reviewer permission, genuine REJECT/APPROVE decision handling, idempotent identical replay and changed-intent/stale terminal denial, separate restricted review evidence, absence of Roll/counter/Student mutation, and client ACL.
- Tooling manifests expect **562 functions / 544 SECURITY DEFINER / 160 app / 402 private / 160 authenticated app EXECUTEs / 34 FORCE RLS / zero private client EXECUTEs** after this candidate. Exact-head CI must confirm all numbers.

## Boundaries

This does **not** implement `app.d1_apply_student_roll_correction`, verify a later live source/number/correction date at APPLY, participant checked reading, or independently sign off identity/authorization. The frozen P1 Roll operation remains disabled and Migration 10 remains `.sql.draft`. No production SQL execution or merge is approved.
