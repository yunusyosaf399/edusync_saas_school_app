# D1 Student Profile P1 APPROVAL — independently verified merge freeze

Date: 2026-10-16. **Verdict: P1 APPROVAL rollback-only candidate acceptance PASS; whole `student.profile.update` NOT YET FROZEN or enabled.**

## Exact trusted source and independent CI gate

- Merged PR: https://github.com/yunusyosaf399/edusync_saas_school_app/pull/72
- Exact CI-tested PR head: `c6b1da6fd9ab4c7ad099f60df9187c336d85a281`.
- Exact-head disposable D1 local runtime: **SUCCESS**, https://github.com/yunusyosaf399/edusync_saas_school_app/actions/runs/38887302318.
- Exact-head independently scheduled Foundation database: **SUCCESS**, https://github.com/yunusyosaf399/edusync_saas_school_app/actions/runs/38887302297.
- Exact-head D1 draft static and final-function/ownership checks: **SUCCESS**, https://github.com/yunusyosaf399/edusync_saas_school_app/actions/runs/38887302288.
- SHA-guarded PR #72 merge commit: `6ab9b968f612578af3164622665f0d09dbfc169e`.
- Previous independently frozen main: `875fbfc731b6a268606f29edf4aab8c82fa80fd5`.
- Readback of GitHub `main` after the merge confirmed `6ab9b968f612578af3164622665f0d09dbfc169e`; PR #72 is merged and closed.

## Independently inspected runtime results

- `D1C2A_APPLY_PASS 228 draft fragments parsed/applied locally` (not hosted).
- `D1C2A_CATALOG_PASS`: all 34 private relations have forced RLS, 542 final functions, and no authenticated access to the private schema.
- `D1_BUSINESS_TEST_PASS 65_remaining_student_commands_fail_closed.sql 38/38`: remaining unaccepted Student operations remain disabled by default.
- `D1_BUSINESS_TEST_PASS 66_student_profile_p1_direct_history_authorization.sql 33/33`: previous Student Profile DIRECT slice unchanged.
- `D1_BUSINESS_TEST_PASS 67_student_profile_p1_approval_review_apply.sql 41/41`: newly authenticated P1 APPROVAL submission, distinct independent reviewer, checked requester/reviewer read, self-review denial, no premature apply, immutable same-key replay, live reviewer-grant revocation returning INVALIDATED, separate authorized apply, exactly-once result/version/evidence, absence of private direct DML, no Identity/Special or Enrollment mutation.
- `D1_BUSINESS_PASS 2980 assertions` across **67** isolated, rolled-back SQL business suites.
- `D1C2A_FOUNDATION_REGRESSION_PASS ... 220/220` and independent `FOUNDATION_LOCAL_CI_PASS 9 files / 220 planned / 220 passed`.
- Existing independent concurrency/race suites also passed; **no Student Profile P1 two-session race is claimed**.
- Static `D1_DRAFT_STATIC_PASS 228 fragments; 34 relations; 97 permissions; 322 scope alternatives; 36 operations`, `D1_FUNCTION_FINAL_PASS ... unknown_owners=0 ... signature_shape_drift=0`.

## Reviewed exact seven-file PR diff

Only these changed relative to frozen main:
1. `docs/database/160_d1_student_profile_p1_approval_candidate_review.md` (candidate design/failed-run and correction audit).
2. `supabase/migrations/20260928000000_domain_package_01_effect35_20_student_profile_p1_submit_record_guard.sql.draft` — fixes reading uninitialized Employee RECORD when submitting a Student Profile request; preserves existing Student/Employee field, policy and version gates.
3. `supabase/migrations/20260928000000_domain_package_01_effect35_21_student_profile_approval_candidate_open_offerings.sql.draft` — replaces typed reviewer-candidate helper to use valid `OPEN` Class/Section Offering state for Student Profile only while preserving other candidate behavior and exact reviewer permission/scope logic.
4. `supabase/migrations/20260928000000_domain_package_01_effect35_22_profile_p1_historical_submission_receipt_lock.sql.draft` — preserves target row lock, current permission/participant/intent checks and strict version for new submissions; a formerly accepted identical receipt can replay after subsequent approved application.
5. `supabase/tests/domain/67_student_profile_p1_approval_review_apply.sql` — 41 assertion disposable-transaction SQL acceptance test (ends with `ROLLBACK`).
6. `tools/supabase/domain_business_ci.py` — appends suite #67 and retains exact 66-suite / 2,939-assertion predecessor prefix.
7. `tools/supabase/tests/test_domain_acceptance_ci.py` — static tests for new suite, restricted SQL-owner replacements, current authorization, matching new/old submit locks, and operation-activation denial.

Three new SQL files are append-only **non-executable** `.sql.draft` fragments. The replacements are temporarily created by their existing NOLOGIN `schoolos_workflow_executor` / `schoolos_authz_reader` function owners and CREATE is revoked afterward. There are **no executable migrations, RLS changes, new public/private grants, catalog activations or hosted database writes**. The nine frozen Foundation migrations remain intact.

## Unaccepted work remains

This merge establishes only the exact tested Student Profile P1 APPROVAL/DIRECT slices; the full `student.profile.update` operation **remains blocked** by owner decisions `SP-01`–`SP-08` documented in `docs/database/152_d1_student_profile_update_p1_contract_readiness.md`: final allowlist, null/patch semantics, photo provenance, exact approval policy and context, independent-reviewer drift, protected receipts/privacy-safe old/new history, and race/dependency analysis. The approved-operation count stays **31/35**, not 32/35.

Further Student Profile rejection, target-drift, campus/scope, route-policy replacement/retirement, concurrent two-session, final private-history retention and file entitlement cases need separately supported acceptance coverage before declaring whole-operation readiness. The other three blocked operations remain `student.roll.correct` (`RC-01`–`RC-08`), `student.roll_policy.change` (`RP-01`–`RP-07`), and `student.create` (`SC-01`–`SC-07`, Admissions final atomic single-use consumption). No speculative contract choice or admissions bypass was introduced.

**Simple example:** A staff requester proposes to change a Student's previous-school field. An independently authorized reviewer approves it; only the later separate apply may change the Student. If the reviewer's grant is revoked before applying, the pending approved request invalidates without any Student mutation. Historical replay returns the already accepted receipt rather than writing twice. All of this is only confirmed within a disposable local test transaction; it does not switch on a school deployment.
