# D1 Student Profile P1 APPROVAL — authenticated candidate acceptance review

Date: 2026-10-16. **Status: UNVERIFIED CANDIDATE, not activated, not owner-approved.** Operation: `student.profile.update`; review permission: `student.profile.approve`. This is incremental disposable-local acceptance testing of a draft implementation already present, **not** a new production operation or an owner decision.

## Frozen preconditions

- Previous `main` exact SHA: `875fbfc731b6a268606f29edf4aab8c82fa80fd5`. PR #71 merge approved only the narrower Student Profile DIRECT tested slice; review #159 explicitly retains all eight `SP-01`–`SP-08` decisions.
- The draft `app.d1_submit_student_profile_update`, `app.d1_review_profile_request`, `app.d1_read_profile_request`, `app.d1_apply_profile_request` and fixed workflow/evidence helpers preexist in the large inactive `.sql.draft`. This PR changes **no** SQL or function, RLS, grants, migrations, production catalog defaults or schema.
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

- CI must confirm D1 runtime **67/67 suites, 2,980/2,980 business assertions** (2,939 frozen predecessor assertions plus 41 candidate), 220/220 Foundation regression, D1 static, no unexpected new grants/operation enablement, and an independently reviewed exact PR head.
- The new suite is an **unaccepted candidate until CI**, regardless of local source validation.
- Even if green, the tested Student Profile workflow slice is only partial evidence: full `student.profile.update` stays outside the protected 31/35 operation completion count pending owner contract freeze, rejected review/campus/current-grant/target-drift/policy-replacement paths, observed two-session races and other remaining SP acceptance cases.
- The three other separate operations `student.roll.correct`, `student.roll_policy.change`, and `student.create` remain blocked (Student Create also requires a single-use completed Admissions handoff).

**Example:** An authorized administrator asks to update a Student's prior school. An independent reviewer must approve; no information is changed by submission or approval alone. If the reviewer's permission was revoked before application, the request invalidates instead of editing the Student. Neither of these cases is enabled in a school deployment by this test.
