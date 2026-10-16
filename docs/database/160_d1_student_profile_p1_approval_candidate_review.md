# D1 Student Profile P1 APPROVAL — authenticated candidate acceptance review

Date: 2026-10-16. **Status: UNVERIFIED CORRECTED CANDIDATE, first CI runtime failed; not activated, not owner-approved.** Operation: `student.profile.update`; review permission: `student.profile.approve`. This is incremental disposable-local acceptance testing of a draft implementation already present, **not** a new production operation or an owner decision.

## Frozen preconditions

- Previous `main` exact SHA: `875fbfc731b6a268606f29edf4aab8c82fa80fd5`. PR #71 merge approved only the narrower Student Profile DIRECT tested slice; review #159 explicitly retains all eight `SP-01`–`SP-08` decisions.
- The draft `app.d1_submit_student_profile_update`, `app.d1_review_profile_request`, `app.d1_read_profile_request`, `app.d1_apply_profile_request` and fixed workflow/evidence helpers preexist in the large inactive `.sql.draft`. This PR changes no executable migration, RLS, runtime role grant, production catalog default or schema. **After the first CI run** exposed an unsafe unassigned `employee_row` RECORD dereference during Student submission, an append-only draft file `20260928000000_domain_package_01_effect35_20_student_profile_p1_submit_record_guard.sql.draft` now replaces exactly that shared function with separate Student/Employee row checks, retaining its restricted owner and all other logic. The previous CI run is **FAILED** and must not be used as acceptance evidence.
- The approval policy configured in this suite is synthetic, **only inside an explicit ROLLBACK transaction**; the real default remains registered-and-disabled. Foundation migrations 1–9 immutable; hosted Supabase is not touched.

## Proposed new test `67_student_profile_p1_approval_review_apply.sql`

The suite reuses the accepted Student P0 real authenticated INITIAL placement and roll fixture; it creates its own synthetic individually authenticated requester and independently authenticated reviewer, roles, CURRENT Student Profile grants, an unambiguous active P1 APPROVAL route, a one-step reviewer template, and explicit ALL/DIRECT review scope.

The new **41 planned pgTAP assertions**, only once CI actually passes, will test:

1. A real protected Student initial placement/roll, and denial of the DIRECT RPC while APPROVAL is selected.
2. Denial if no authorized independent reviewer is available; after explicitly granting a reviewer **in the test only**, creation of one pending typed immutable request, changed-intent key denial and replay.
3. Prohibition of self-approval and premature apply, and checked request reads restricted to an authorized requester/reviewer.
4. A genuinely distinct authenticated reviewer approves and replays once; the domain Student row remains unchanged until a **separate authenticated apply**.
5. Revoking reviewer permission between review and apply returns `INVALIDATED` and causes no profile change; the savepoint restores the synthetic approval only for the positive branch.
6. Approved apply transitions to `EXECUTED`, advances the Student version exactly once, keeps original admission/Student identifiers and Identity/Special details untouched, emits exactly one redacted event and one successful apply receipt, and respects idempotent replay.
7. Direct authenticated private SELECT/UPDATE is denied; no PRIMARY Enrollment is rewritten.

The test uses only the typed `previous_school` illustrative field to establish the workflow execution path. This **does not approve** `previous_school` or the remaining five candidate columns as final writable production fields, nor does it decide partial/null semantics or secure value-history retention. These require SP-01, SP-02 and SP-08 owner decisions. Review #152 includes further photo reference, route, reviewer, receipt, and evidence decisions SP-03 through SP-07.

## Required merge gate

- A NEW exact-commit CI run must confirm D1 runtime **67/67 suites, 2,980/2,980 business assertions** (2,939 frozen predecessor assertions plus 41 candidate), 220/220 Foundation regression, D1 static, no unexpected new grants/operation enablement, and an independently reviewed exact PR head.
- The new suite is an **unaccepted candidate until CI**, regardless of local source validation.
- Even if green, the tested Student Profile workflow slice is only partial evidence: full `student.profile.update` stays outside the protected 31/35 operation completion count pending owner contract freeze, rejected review/campus/current-grant/target-drift/policy-replacement paths, observed two-session races and other remaining SP acceptance cases.
- The three other separate operations `student.roll.correct`, `student.roll_policy.change`, and `student.create` remain blocked (Student Create also requires a single-use completed Admissions handoff).

**Example:** An authorized administrator asks to update a Student's prior school. An independent reviewer must approve; no information is changed by submission or approval alone. If the reviewer's permission was revoked before application, the request invalidates instead of editing the Student. Neither of these cases is enabled in a school deployment by this test.

## Second CI runtime: reviewer-offering-state defect and scoped correction

Exact head `5be8a36aaefcc028173d4caadaf8aad36f803619` passed Foundation and static but **FAILED** D1 runtime https://github.com/yunusyosaf399/edusync_saas_school_app/actions/runs/38873526010. The record guard correction successfully eliminated the prior `employee_row` exception. The new failure was `D1 profile approval step has no eligible reviewer` after the synthetic independent reviewer was granted the exact live review permission, role and ALL/DIRECT scope.

Root-cause inspection of the frozen draft `app_private.d1_review_candidates` found a second impossible `so.state='ACTIVE' AND co.state='ACTIVE'` offering predicate. Real Class/Section Offering states are PLANNED/OPEN/CLOSED/ARCHIVED, and the accepted Student Profile current-target authz fix #19 requires `OPEN`. The new append-only owner-preserving draft `20260928000000_domain_package_01_effect35_21_student_profile_approval_candidate_open_offerings.sql.draft` replaces the candidate function using **OPEN only for `student.profile.update`**, preserving its previous `student.status.change` behavior and all candidate identity, policy, scope, no-self-review, current-effective permission and role predicates. No production permission or operation is enabled. This second failed CI run also cannot be used as acceptance evidence. A THIRD exact-head runtime CI pass is now required before merge.

## Third CI runtime: historical P1 submission-receipt replay

Exact head `dfa532fab23a66e8477c5c56ea4d2c956b5c4e42` passed static and independent Foundation checks but **FAILED** the D1 runtime in suite #67 at test 27: https://github.com/yunusyosaf399/edusync_saas_school_app/actions/runs/38886542850. The first 26 Student Profile P1 assertions passed, proving that the reviewer-candidate OPEN-offering correction worked and independent submission, review, revoked-reviewer invalidation and separate approved application executed. The next statement replayed the original immutable submit idempotency key **after** approved application had incremented the Student version. The shared submit function incorrectly applied the obsolete original expected-version lock check before recognizing its accepted receipt.

The append-only, inactive `20260928000000_domain_package_01_effect35_22_profile_p1_historical_submission_receipt_lock.sql.draft` corrects only the existing Student/Employee Profile submission handler: **new commands** continue requiring an exactly matching versioned target lock; **previously accepted same-key receipts** still acquire their typed target row lock but can proceed past obsolete version to the existing live requester, operation-permission/placement, participant and immutable-receipt validations. Unaccepted, changed-key and changed-intent requests do not benefit. No new operation/scope grant, RLS change, migration activation or hosted deployment. This third failure is not acceptance evidence; a **fourth** exact-commit CI run must pass 67/67 suites and 2,980/2,980 assertions before any merge.
