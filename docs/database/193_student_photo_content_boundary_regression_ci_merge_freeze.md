# Student Profile photo — additional decoded-content boundary tests, CI/merge freeze

Date: 2026-10-17. **Verdict: isolated local regression tests PASS; PR #87 MERGED; freeze is for test evidence only.** No operational Student photo upload or positive photo SET acceptance is authorized.

## Provenance

- Frozen prior main baseline: `75c3fa816b544f71d45fac5d0f6b7f9d592f6c08` (post-PR86 documentation freeze).
- [PR #87](https://github.com/yunusyosaf399/edusync_saas_school_app/pull/87) tested exact head `aed0ac90ce543acbc6c54bb6961a0414a9f6cc03`, then merged through commit `6ebae89ad3fae35291103ad0ccadd062043aa73c`.
- Verified exact PR diff: only `tools/photo_validation/tests/test_student_photo_content_validation_candidate.py` (+44 lines) and `docs/database/192_student_photo_content_boundary_regression_candidate.md` (+23 lines). No active migration, D1/SQL draft, validator implementation, backend endpoint, permission, public RPC, or hosted database change.

## Exact-head CI results

Four `pull_request` workflows on head `aed0ac90ce543acbc6c54bb6961a0414a9f6cc03` completed successfully:

1. [Decoded Student photo candidate #39035404213](https://github.com/yunusyosaf399/edusync_saas_school_app/actions/runs/39035404213): **PASS — 11 unit tests**; the three new tests verify EXIF orientation (13x7 to 7x13), privacy metadata removal and sanitized hash, PNG alpha preservation, and refusal of a compressed image exceeding the *provisional* decoded-pixel ceiling. Marker: `D1_STUDENT_PHOTO_CONTENT_CANDIDATE_PASS`.
2. [D1 Migration 10 draft static #39035404203](https://github.com/yunusyosaf399/edusync_saas_school_app/actions/runs/39035404203): **PASS** — 228 draft fragments; 34 D1 relations; 97 permissions, 322 scope alternatives, 36 operation contracts; `D1_FUNCTION_FINAL_PASS`, Foundation source/config and staging-validation static markers.
3. [D1 Migration 10 local runtime #39035404215](https://github.com/yunusyosaf399/edusync_saas_school_app/actions/runs/39035404215): **PASS** — `D1_BUSINESS_PASS 3124 assertions`, `D1C2A_PASS` and existing rollback-only Student photo provenance, typed DIRECT/APPROVAL and concurrency trial markers. This is disposable local validation, **not active Migration 10 or production runtime**.
4. [Foundation local database #39035404297](https://github.com/yunusyosaf399/edusync_saas_school_app/actions/runs/39035404297): **PASS — 220/220** frozen assertions with local reset/lint and five Auth fixtures.

## Independent review and continued hard stops

The new tests exercise the existing candidate sanitizer without modifying its implementation. The input images are in-memory synthetic fixtures. EXIF tag stripping, sanitized-byte digest consistency and alpha are covered; the decoded-pixel ceiling is an *implementation trial guard*, not an approved production product limit. Full CI success does not prove the separate trusted file issuance/finalization service, Student ownership binding, effective signed subscription/entitlement snapshot and multi-instance revocation fencing, purpose-registry activation, provider-side storage of exact sanitized bytes, production decoder sandboxing/dependency governance, retention/forensic controls, or two-session upload/finalization/photo APPLY races.

**Status remains unchanged:** Student Profile photo SET defaults to DENY; Issue #67 remains OPEN; **31/35 protected change operations accepted**; 34 D1 base relations, 228 Migration 10 `.sql.draft` fragments, 97 permissions, 322 scope alternatives and 36 contracts are frozen. No hosted Supabase migration or file-service deployment is authorized.

**Simple example:** A real JPEG with rotation EXIF and hidden private text is oriented and sanitized; a tiny compressed PNG larger than the decoded-pixel safety budget is rejected. Neither can become a Student's profile photo without separate valid Student identity, upload entitlement, verified file ownership and current protected-link authorization.
