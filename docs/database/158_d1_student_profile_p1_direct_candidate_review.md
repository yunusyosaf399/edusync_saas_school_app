# D1 Student Profile P1 DIRECT — candidate authenticated business acceptance (#66)

Date: 2026-10-16. **Status: CANDIDATE, NOT ACCEPTED UNTIL EXACT PR-HEAD RUNTIME/PYTHON/FOUNDATION/STATIC PASS AND INDEPENDENT SOURCE AUDIT.**

## Scope and baseline

PR #66 readiness was merged to `main` at `71b9d519a6c4e1c9b7427bc65dae68c35663dbfa`; its documentation-only freeze tip is `ad3f2391d964d93a98750d5bc03be05d20b831fb`. It preserves 65/65 business suites, 2,906/2,906 assertions and 31/35 accepted distinct protected changes. This branch addresses **only** `student.profile.update` P1 DIRECT candidate acceptance and does not alter Admissions, roll correction, roll policy change or the other 31 protected operation contracts.

## Source audit: an old executable draft path did exist

The original non-executable `20260928000000_domain_package_01.sql.draft` already contains the typed `app.d1_change_student_profile` API and `d1_profile_direct`/authorization/effect helpers, plus P1 request/review/apply components. These had not earned independent authenticated Student Profile business acceptance, so they must not be counted or enabled by their mere presence. Independent review discovered `d1_profile_authorized` checks `section_offerings.state='ACTIVE'` and `class_offerings.state='ACTIVE'` while their frozen state vocabulary is `PLANNED/OPEN/CLOSED/ARCHIVED`. An accepted, usable current Section/Class Offering is `OPEN`: the old branch of this helper therefore rejected genuine Student PRIMARY placement context.

The new append-only inactive Effect35_19 changes **only** those two offering-state predicates to `OPEN` inside the existing fixed private authorization helper. It retains the Student `ACTIVE` state and placement `ACTIVE` guards, exact ALL/CAMPUS/CLASS/SECTION authorization, current Principal and reviewer checks. The function stays owned by `schoolos_authz_reader`; DDL CREATE privilege is temporary and explicitly revoked again. The source does not alter the Employee authorization branch, permission/operation catalog flags, or any deployed migration.

## Dedicated authenticated test

`supabase/tests/domain/66_student_profile_p1_direct_history_authorization.sql` is a new rollback-isolated 33-assertion candidate. It uses the verified command actor fixture and accepted P0 `app.d1_place_student_enrollment` to produce a real enrolled Student and allocated Roll before attempting Profile changes. The test only **within its disposable transaction** activates `student.profile.update`, its ALL/DIRECT permission alternative and a valid explicit DIRECT policy. It then exercises an authenticated successful allowlisted `previous_school` mutation, exact Student version bump, replay, changed-intent/stale-version denial, wrong Student/campus denial, revoked grant-scope denial on replay, minimized audit/outbox counts, immutable Student/Admissions identifiers, no Identity/Special mutation and raw private DML refusal. Two accepted profile mutations must yield precisely two receipts, audits and events, including historical idempotent replay.

A separate static guard preserves suite #65 **unchanged as a 38-assertion fail-closed baseline** and checks the new #66 test and the narrow Effect35_19 fix. Suite #65 correctly proves that operations are disabled by **default**; #66 deliberately authorizes its exact Student Profile command **only inside the rollback fixture**. A default-disabled operation can earn separately tested D1 draft behavior without activating a hosted project. Prior 65 suites/2,906 assertions stay a frozen prefix. Proposed candidate total: **66 suites / 2,939 assertions** (not yet independently verified).

## Explicit limitations and release boundary

This is **P1 DIRECT route only**. It does not separately accept Student Profile APPROVAL submit/review/apply or every proposed PROFILE field/photo clearing policy in readiness #152. Do not infer 32/35 accepted or change `runnable_accepted` in blocker register #156 until this exact candidate passes runtime and independent review; never count a static proof as accepted business execution. If CI finds a runtime defect, correct only the specified missing executable behavior and retest the **final** source SHA.

The other **three** pending protected operations (`student.roll.correct`, `student.roll_policy.change`, `student.create`) remain blocked, with Admissions final handoff externally dependent. No schema activation, hosted Supabase execution, direct authenticated table grants, extra permission or role grant, change of Foundation migrations/tests or Flutter work is authorized. Migration 10 stays `.sql.draft`.
