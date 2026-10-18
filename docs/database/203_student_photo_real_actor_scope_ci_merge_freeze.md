# Student Photo — authenticated PRIMARY placement and current Campus grant: CI/merge freeze

Date: 2026-10-18. **Verdict: PR #92 exact-head CI PASS, MERGED, rollback-only private resolver candidate accepted for local security evidence ONLY.** No actual photo upload, entitlement service integration, photo SET, or hosted Supabase change is authorized.

## Provenance and reviewed diff

- Previous frozen `main`: `ae299e730ecc87c115af4aa9ce4452ffa12e20bc` (PR #91 freeze).
- [PR #92](https://github.com/yunusyosaf399/edusync_saas_school_app/pull/92) exact **successful** tested head: `55daebc811a3be2e452798047bccf077ce5d8218`.
- Confirmed merge commit: `5244124959a3e31869639acc4961cb6329520ecf`; PR closed and merged, prior `main` was unchanged before merge.
- Exactly six reviewed paths relative to the frozen baseline: `.github/workflows/student-photo-content-candidate.yml` (+5); `docs/database/202_student_photo_real_principal_primary_scope_candidate.md` (+28); `supabase/proposals/student_photo_private_actor_scope_resolver_acceptance.sql.draft` (+154); `supabase/proposals/student_photo_private_actor_scope_resolver_trial.sql.draft` (+67); `tools/supabase/domain_profile_history_candidate_ci.py` (+86); `tools/supabase/tests/test_student_photo_real_actor_resolver_ci.py` (+95). No frozen Migration 10 fragments, executable migrations, public RPC, production upload code or hosted SQL changed.

## Exact-head CI evidence: 4/4 PASS

1. [Student photo local candidate #39097241062](https://github.com/yunusyosaf399/edusync_saas_school_app/actions/runs/39097241062): **53/53 tests PASS** — 11 JPEG/PNG decoded/sanitized content, 9 synthetic intent, 11 real signed entitlement, 7 atomic FINALIZE race, 11 signed opaque ledger, and 4 new source/quarantine guard tests. Marker `D1_STUDENT_PHOTO_CONTENT_CANDIDATE_PASS`; upload remains disabled.
2. [D1 draft static #39097241121](https://github.com/yunusyosaf399/edusync_saas_school_app/actions/runs/39097241121): **PASS** `D1_DRAFT_STATIC_PASS`, `D1_FUNCTION_FINAL_PASS`; 228 draft fragments, 34 relations, 97 permissions, 322 scope alternatives, 36 operations unchanged.
3. [Foundation local #39097241055](https://github.com/yunusyosaf399/edusync_saas_school_app/actions/runs/39097241055): **PASS** `FOUNDATION_LOCAL_CI_PASS` 9 files, 220/220 planned local assertions (264 Python unit tests also passed).
4. [D1 local runtime #39097241054](https://github.com/yunusyosaf399/edusync_saas_school_app/actions/runs/39097241054): **PASS** `D1_BUSINESS_PASS 3124 assertions`, **`D1_STUDENT_PHOTO_REAL_ACTOR_SCOPE_RESOLVER_PASS`** (verified PostgreSQL Principal, one current PRIMARY Student placement, real Campus scope/photo+profile grants, revocation, private-only execution and rollback), `D1C2A_PASS`; disposable local runtime only, Migration 10 stays `.sql.draft`.

## Prior failure and correct resolution

Previous PR head `3065f4e1b8954b1ec9f865a47d00a0abb343e384`, runtime [#39094688254](https://github.com/yunusyosaf399/edusync_saas_school_app/actions/runs/39094688254), **FAILED** on PostgreSQL `42501: permission denied for table section_offerings`. The trial attempted to read `so.state`/ `co.state` as the Student executor. We did **not** broaden Student-executor table SELECT grants or change frozen D1 contracts. The corrected trial resolves PRIMARY Student placement and Campus through existing narrow fields, then delegates OPEN Offering state and ACTIVE Student eligibility to the existing private `app_private.d1_profile_authorized` function, owned by the approved authentication reader. New source-guard tests assert this owner-bound delegation. All **four workflows were rerun and passed on the exact corrected head**; the earlier failed head was not merged.

## Accepted bounded conclusion and hard stop

The SQL-only rollback candidate reuses **genuine local authenticated suite #66**, verified current individual Principal, real Student P0 accepted ACTIVE PRIMARY placement and Campus ancestry, current `student.profile.update` and independently current `student.photo.submit` grant chains. It introduces an owner-bound *private Boolean eligibility predicate*, inaccessible to ordinary `authenticated`, `anon`, `service_role` and PUBLIC callers. Local test savepoints show that Campus B-only photo permission does not authorize a Student in Campus A; photo grant revocation, profile grant revocation, caller-supplied wrong Campus and unplaced Students also deny. The trial function and permission/fixture changes are rolled back; cleanup confirms no private resolver or prior companion trial helper remains installed. These tests do **not** mean photo intent issuance or file finalization is operational.

This candidate is NOT connected to PR #91's test-only Ed25519 signed opaque intent ledger, does **not** establish a genuine production principal-to-service authenticated handoff, never trusts any simulated `principal_verified=true` claims, and does not enforce the real file service's `file.upload` and signed `storage.student_photo.upload` subscription entitlement in one distributed transaction. File provider persistence, exact sanitized object proof, immutable Student owner, actual `PENDING→VALIDATED→AVAILABLE` transition, cross-host revocation and Student Profile DIRECT/P1 photo SET remain unimplemented and DENIED by default.

**Protected operations accepted: 31/35, unchanged.** Issue #67 OPEN; 228 Migration 10 fragments all `.sql.draft`; 34 relations, 97 permissions, 322 scope alternatives, 36 operation contracts unchanged; hosted Supabase untouched.

**Simple example:** A staff Principal has a valid Campus A photo-submit grant and Student A's actual current PRIMARY enrollment is in Campus A, so the local private resolver may return true. Swap the Principal's photo grant to Campus B, and the same Student A fails—even if a separately signed synthetic request insists it is authorized.

## Next recommended isolated integration gate

Design and test a **trustworthy server-to-PostgreSQL Principal context and permission/Student placement proof handoff into the existing private signed opaque intent ledger**, rechecking current revision, independently authenticated role/scope/Student membership and replay/race results. No real file issuance, provider AVAILABLE or photo SET activation without distributed durable revision coordination and a reviewed production worker.
