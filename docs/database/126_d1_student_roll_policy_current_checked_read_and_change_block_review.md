# D1 roll-policy current checked read and unimplemented CHANGE gate — incremental acceptance review

Date: 2026-10-13
Verdict: **PASS — checked current READ and fail-closed missing CHANGE handler only. The P1 `student.roll_policy.change` business operation remains BLOCKED / NOT ACCEPTED. Full D1 remains OPEN.**

## Exact immutable source and independent CI

- Previous frozen `main`: `56bc4a463cc9fe0ac835b5810f68667e78003d21` (**36 business suites / 1,918/1,918 pgTAP business assertions; 19/19 observed-lock races; 12 distinct accepted change operations**).
- [PR #47](https://github.com/yunusyosaf399/edusync_saas_school_app/pull/47) **MERGED** from independently tested exact head `653a4a30700037b5a1acea3a3d61ca6fb953fff6` to merge commit `3a59d22cac37bebe18eb3ac14bed438a734ad671`. Parent verification on GitHub showed precisely `56bc4a463cc9fe0ac835b5810f68667e78003d21` and `653a4a30700037b5a1acea3a3d61ca6fb953fff6`; `main` matched merge before this documentation freeze. The candidate-vs-base diff contains **exactly three acceptance-only paths**.
- [D1 Migration 10 PR run #38376604602](https://github.com/yunusyosaf399/edusync_saas_school_app/actions/runs/38376604602) **PASS** on exact head: new `37_student_roll_policy_current_checked_read_authorization.sql` **35/35**; **37/37** business suites **1,953/1,953** assertions; **54/54 D1 Python tooling tests**; unchanged **19/19** real two-session observed-lock race cases (not roll-policy change races); **220/220 post-D1 Foundation SQL regression assertions**; both lint severities; `D1C2A_PASS`.
- [Foundation database PR run #38376604607](https://github.com/yunusyosaf399/edusync_saas_school_app/actions/runs/38376604607) **PASS** on exact head: **210/210 Foundation Python tooling tests**, **220/220** SQL assertions across nine frozen test files, local database reset, fixtures and both lint severities. Matching exact-head push runs [D1 #38376492369](https://github.com/yunusyosaf399/edusync_saas_school_app/actions/runs/38376492369) and [Foundation #38376492379](https://github.com/yunusyosaf399/edusync_saas_school_app/actions/runs/38376492379) both **PASS**.
- Source/catalog checks: `D1C2A_SOURCE_PASS 202 fragments; 34 relations; final_functions=540`; `D1C2A_APPLY_PASS 202 draft fragments parsed/applied locally`; `D1C2A_CATALOG_PASS tables=34 rls=34/34 functions=540 definers=522 app=157 private=383 auth_private=0 anon=0 service_role=0`. This **does not** activate Migration 10: its assembled 202 `.sql.draft` fragments ran only in disposable local PostgreSQL, not hosted Supabase.

## Frozen source contract and safe scope

The domain draft registers `student.roll_policy.change` under the `student.roll_policy.change` permission, with P1 reviewer permission `student.roll_policy.approve`, but its operation row is `enabled=false` and there is **no implemented protected public roll-policy-change mutator or P1 submit/review/apply workflow**. This is a substantive missing implementation, not permission to invent a compatible endpoint or count the operation as accepted. The security matrix specifies a reviewed effective-interval replacement that never rewrites previous roll allocations, but no runnable protected implementation exists in the frozen SQL. The acceptance suite therefore **does not call** the unimplemented change and **does not assert any accepted roll-policy-change receipts**.

The implemented endpoint is the separate **checked current read** `app.d1_read_roll_policy(uuid)`, guarded by `app_private.d1_authorized('student.roll_policy.view','SCHOOL',school_id)`; it returns `policy_id`, `mode`, `start_value`, and `effective_from` from policy revisions whose half-open interval includes `CURRENT_DATE`. The staff actor must have a matching live `student.roll_policy.view` role grant and permission assignment scope; having another permission or a disabled grant does not authorize the read.

## New 35/35 rollback-only pgTAP evidence

The synthetic schema-owner fixture seeds three numbered retained `app_private.roll_policy_revisions` within the test school, with contiguous date intervals: earlier revision 1 `PERSISTENT_STUDENT` ended five days ago, revision 2 `ACADEMIC_CONTEXT` currently effective through tomorrow's exclusive boundary, and revision 3 `PERSISTENT_STUDENT` scheduled for tomorrow. The three policies have correct retained revision increments, predecessor/supersession pointers, `ended_at/ended_by` metadata on bounded rows, and an open future end. These **are test-owned historical fixtures, not successful protected policy-change commands**.

The suite verifies:

1. An authenticated staff actor without the separate `student.roll_policy.view` permission sees **zero** current-policy rows; unknown school IDs return none. Direct authenticated private roll-policy SELECT/DELETE is denied.
2. A live non-FAMILY staff role-permission grant and matching `ALL/DIRECT` assignment scope authorizes **exactly the currently effective policy**. The endpoint returns its ID, `ACADEMIC_CONTEXT` mode, start value 20,000 and retained effective date, not the preceding or not-yet-effective policy. The prior and future versions remain intact on private owner inspection.
3. Separate SAVEPOINT tests revoke the live scope and role grant, disable the view permission, and disable the scope contract. Each independently cuts off the checked read; the rollback restores authorized visibility. Anonymous invocation of the protected read RPC is denied.
4. The frozen operation `student.roll_policy.change` is asserted `enabled=false` at runtime, and a catalog probe confirms the implemented read endpoint is present while no public `d1_%roll%policy%` mutator is registered. No `student.roll_policy.change` command receipts or roll-policy change outbox events are emitted. A Python static guard also fails closed if an unsupported change RPC appears in the frozen draft without a new deliberate review.
5. The three synthetic history rows and restored grants remain consistent through explicit `SET CONSTRAINTS ALL IMMEDIATE`, pgTAP `finish()`, then a **full transaction `ROLLBACK`**. No test state persists.

## Exactly three acceptance-only paths

1. `supabase/tests/domain/37_student_roll_policy_current_checked_read_authorization.sql`: new **35-assertion**, rollback-only checked-current disclosure suite.
2. `tools/supabase/domain_business_ci.py`: append suite #37, moving **1,918 → 1,953** business assertions without changing any earlier suite.
3. `tools/supabase/tests/test_domain_acceptance_ci.py`: append static guard for read-only safety, missing change handler and disabled operation, while preserving previously frozen **36-suite / 1,918 assertion manifest prefix**.

## Frozen checkpoint and what is NOT accepted

**Incremental D1C2A acceptance after PR #47: 37 suites / 1,953/1,953 business assertions; 19/19 existing two-session observed-lock races; 54/54 D1 Python; 210/210 Foundation Python; 220/220 Foundation SQL; 34/34 RLS.** This is a **read-only breadth increment, not a thirteenth change-operation suite**: the project still has **12 of 35 drafted change operations with dedicated accepted suites, 23 without**. `student.roll_policy.change` specifically remains one of the **23** unaccepted operations and is **BLOCKED** until its exact P1 approval, authorization, immutable policy lineage and allocation preservation are implemented and independently tested.

Not covered: changing policies, request/approval/apply, allocation conservation under policy replacement, new school sequence contention, roll-number correction, roll-policy change receipts/events, existing student allocations, Admissions/Finance integration, production migration, or hosted activation. `student.create` remains disabled until Admissions. **Full D1 remains OPEN; Migration 10 remains inactive `.sql.draft`; no hosted Supabase deployment or live school-data changes occurred.**

**Recommended next implementation review:** confirm the frozen P1 roll-policy change contract and required command/approval state machine before designing its protected handler. Alternatively continue remaining already-implemented P0/P1 accepted-operation breadth without misrepresenting the blocked change operation.

**Checkpoint:** `D1_ROLL_POLICY_CURRENT_CHECKED_READ_PASS_CHANGE_BLOCKED — 37 SUITES — 1953/1953 BUSINESS — 19/19 OBSERVED-LOCK RACES — 220/220 FOUNDATION SQL — 54/54 D1 PYTHON — 210/210 FOUNDATION PYTHON — 12 CHANGE OPERATIONS ACCEPTED — FULL D1 OPEN`.
