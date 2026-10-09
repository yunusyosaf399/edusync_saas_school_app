# D1 Effect 31 — P1 policy ambiguity and independent two-step review acceptance

Date: 2026-10-09  
Verdict: **PASS — exact-source incremental D1C2A disposable local acceptance; hosted deployment not approved.**  
PR: [#15](https://github.com/yunusyosaf399/edusync_saas_school_app/pull/15)

## Tested SHA and evidence

- Baseline main: `4a3be18deccf6051de61e770a1ea6c5d668d41cb`. Tested PR tip: `1fb3828b07668e95b2dcf4bd0773378f98bf4d30`, merged as **second parent** of `98f694136d13291041d5e1fef30b5c3c4875afaa`.
- [D1 local runtime #161](https://github.com/yunusyosaf399/edusync_saas_school_app/actions/runs/37964584012): **PASS** — `16_family_membership_p1_policy_multistep.sql` **63/63**, **682/682** D1 business assertions in **16** suites, **220/220** post-D1 Foundation tests, **21/21** Python runner unit tests and six real two-session races with observed lock waits (Employee 3, Family membership P1 ADD, END and CORRECT 3). Local lint error and warning gates both PASS.
- [Foundation local #360](https://github.com/yunusyosaf399/edusync_saas_school_app/actions/runs/37964583967): **PASS**, nine frozen migrations and 220/220 Foundation tests.
- [D1 static #105](https://github.com/yunusyosaf399/edusync_saas_school_app/actions/runs/37964583943): **PASS**, 199 non-executable Migration 10 draft fragments, 34 domain relations, 97 permissions, 322 alternatives, 36 operations, 540 final functions (522 SECURITY DEFINER), zero signature-shape drift, zero authenticated/anon/service-role private helper EXECUTE. Local runtime separately confirms **34/34 forced RLS** relations and local assembly/application of the 199 fragments.

## Frozen contract upheld

`family.principal_membership.change` is non-family-safe and ALL-only. A currently effective route resolves only when there is exactly **one compatible school-wide policy**. Absence, additional effective policies or an incompatible campus-specific policy fail closed. Explicit DIRECT must not bypass an APPROVAL policy. A valid APPROVAL policy has ordered one-review-per-step templates referencing ACTIVE reviewer roles with `D1_REVIEWER_ROLE_SCOPE`. The requester is distinct from reviewers, each reviewer must be actually selected and currently granted `family.access.approve` through the configured role and ALL/DIRECT authorization, and REVIEW never silently APPLYs.

Suite16 sets up one separately verified Auth-bound INDIVIDUAL reviewer, distinct Person/Principal and a separate configured reviewer role, live permission grant, assignment and ALL scope from the stage1 reviewer. All synthetic mutations are rolled back, no managed Auth users are created.

The **63 checks** cover:

- One school-wide APPROVAL policy with exactly two valid ordered one-review steps and independent configured reviewer roles; missing/retired school-wide policy denies real SUBMIT without a request, mixed ACTIVE school-wide DIRECT and APPROVAL denies both SUBMIT and DIRECT, and an otherwise valid campus-specific policy makes the ALL-only operation ambiguous. Savepoints restore original policy after each negative test.
- After request SUBMIT, step1 is OPEN and assigned while step2 remains WAITING without reviewer assignment or participant-only request-read access. Stage2 cannot approve step1. The first independent APPROVE closes step1 but leaves request PENDING and increments expected request version 3→4 **via Foundation version trigger**, while step2 then opens/assigns only its eligible reviewer. A first-stage replay is idempotent. Premature APPLY and first-reviewer attempt to satisfy stage2 are denied with no membership/application/event.
- Before stage2 APPROVE, a live second reviewer grant revocation denies both review and protected request read; after rollback restoration, second reviewer APPROVEs 4→5, producing two retained independent approval reviews but no domain mutation.
- If an incompatible second school-wide policy becomes ACTIVE *after* full approval, explicit APPLY returns typed INVALIDATED and `D1_FAMILY_PRINCIPAL_MEMBERSHIP_POLICY_STALE`, persists no application/membership, and replays its terminal result. After savepoint restoration to the one legitimate policy, explicit APPLY succeeds 5→6, creates exactly one membership/application/domain event, replay stays stable, and no Student child entitlement appears.

## Defect discovered and SQL correction

[Initial runtime #155](https://github.com/yunusyosaf399/edusync_saas_school_app/actions/runs/37954975317) stopped with 0/62 executed assertions due to the new test looking up a Foundation Auth fixture while running as a restricted schema owner; moved fixture lookup to the test owner. [Runtime #157](https://github.com/yunusyosaf399/edusync_saas_school_app/actions/runs/37961274310) reached 25 green checks, then the first intermediate APPROVE failed on `approval_requests` privilege. The original Effect31 review function tried `UPDATE approval_requests SET row_version=row_version+1,updated_at=...` on the PENDING→PENDING branch. Foundation reserves those columns to `advance_row_version`, and this branch was not exercised by earlier one-step acceptance.

The append-only `supabase/migrations/20260928000000_domain_package_01_effect31_19_membership_pending_multistep_review.sql.draft` replaces the original owned review RPC body (same signature, owner, security-definer search_path, grants and authorization checks) but changes only that intermediate statement to `UPDATE app_private.approval_requests SET state=approval_requests.state WHERE ... RETURNING row_version`. The existing Foundation `zz_approval_requests_version` trigger advances version to 4 and sets updated_at once; PENDING→PENDING is an explicitly permitted state transition. **No broader table grant, client ACL or RLS policy is introduced.** [Runtime #159](https://github.com/yunusyosaf399/edusync_saas_school_app/actions/runs/37963935265) then reached 27 green assertions before the new test itself tried to read raw private `approval_requests` as authenticated. This was corrected by querying the same version through the already-accepted participant-only typed read RPC. [Final #161](https://github.com/yunusyosaf399/edusync_saas_school_app/actions/runs/37964584012) accepts all 63 and the entire baseline; earlier failed runs are not counted as acceptance.

## Files, release boundary and remaining gates

Exactly three files changed: one new append-only draft SQL continuation (Effect31 fragment19), one rollback-only 63-assertion pgTAP suite, and the suite-runner count registration. Frozen Foundation migrations 1–9, client-facing privileges, Flutter apps, managed Supabase database and production workers are unchanged. Migration 10 remains **199 `.sql.draft` fragments**, non-executable on hosted environments.

This closes the tested single conflicting-policy and two-independent-step Effect31 gap only. Other policy permutations, stage-specific authority combinations, requester/reviewer contention and cross-campus security beyond the tested configurations; Effect30 primary replacement/multi-basis acceptance; Family portal checked reads; Admissions/Finance; populated upgrades and the remaining D1 operations are **OPEN**.

**Checkpoint: `D1_EFFECT31_P1_POLICY_MULTISTEP_PASS — 682/682 BUSINESS — 220/220 FOUNDATION — 6/6 RACES — STATIC PASS — FULL D1 OPEN`.**
