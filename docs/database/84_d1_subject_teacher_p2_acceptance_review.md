# D1 Subject Teacher P2 retroactive CORRECT acceptance — independent review

Date: 2026-10-09  
Verdict: **PASS — incremental D1 business acceptance only; complete D1 package remains OPEN.**

## Trusted source and merge evidence

- Source PR: [#4](https://github.com/yunusyosaf399/edusync_saas_school_app/pull/4)
- Exact runtime-tested SHA: `d7a03bcc68658d0fc5a725ee1f6eabadac964d7b`
- Merge commit: `e1daafdfe623e3731a0dc79dd282cc24d86c5c83` (tested PR head is its second parent; no unreviewed source edits were made during merge)
- [D1 local runtime #82](https://github.com/yunusyosaf399/edusync_saas_school_app/actions/runs/37826893299) **PASS**: 197 non-executable Migration 10 fragments loaded only on disposable local Postgres; catalog 34 D1 relations / 34 forced RLS, 540 final functions with 522 SECURITY DEFINER functions, 0 authenticated private function access, both lint gates, 5 Auth fixtures, 220/220 Foundation assertions, **183/183 D1 business assertions**, three observed-lock employee-creation races. This includes **32/32** Subject Teacher retroactive P2 assertions.
- [Foundation local #294](https://github.com/yunusyosaf399/edusync_saas_school_app/actions/runs/37826893302) **PASS**: 175 Python tests, nine frozen Foundation migrations and tests, 220/220 pgTAP assertions.
- [D1 draft static #66](https://github.com/yunusyosaf399/edusync_saas_school_app/actions/runs/37826893310) **PASS**: 197 fragments, 34 relations, 97 permissions, 322 supported scope alternatives, 36 operation contracts, 540 final functions, zero unknown owners or authenticated private EXECUTE.

## Exact source delta

1. `supabase/tests/domain/06_subject_teacher_retroactive_p2.sql`: new transaction-isolated 32-assertion pgTAP suite.
2. `tools/supabase/domain_business_ci.py`: sixth suite registration; 37 + 25 + 22 + 42 + 25 + 32 = **183** assertions.
3. `supabase/migrations/20260928000000_domain_package_01_effect17_08_subject_assignment.sql.draft`: two narrowly scoped `GRANT EXECUTE` statements to `schoolos_schema_owner`. The privileges are for `app_private.d1_teaching_subject_assignment_request_payload_valid(jsonb,jsonb)` and the nested `app_private.d1_teaching_subject_assignment_payload_valid(jsonb)` only; their owning role `schoolos_teaching_executor` performs the grant. No new PUBLIC/anon/authenticated/service_role access or table DML exposure.

## Business behavior verified

- A past-dated Subject Teacher `CORRECT` cannot use the P0 direct RPC; it requires P2 review.
- The submitted correction opens a versioned request, records the original source snapshot and selects the configured independent role-and-scope reviewer. Submission has no assignment effect.
- Requester self-review and apply-before-approval are denied. Independent current-scope reviewer approval moves the request to `APPROVED`.
- If the reviewer permission grant is revoked before apply, the command returns `INVALIDATED`, records a rejected command receipt and does not close the predecessor or create an approval application.
- After restoring the grant inside the synthetic test savepoint, successful apply closes the original history interval, appends exactly one successor referencing `supersedes_id`, executes the approved employee/kind/date change and records one approval application and one outbox business event.
- Replayed submit/review/apply intents return retained original versions and create no duplicate review, apply receipt or successor.
- Four extra assertions prove both validator functions are executable by the internal trigger owner and **not** by `authenticated`.

## Failure traced and corrected

The initial PR candidate `6ed8758c610ea193ddeeb75ee1f6eabadac964d7b` failed D1 runtime [#80](https://github.com/yunusyosaf399/edusync_saas_school_app/actions/runs/37825988716) after 14 passing tests, reporting `permission denied for function d1_teaching_subject_assignment_request_payload_valid` inside `d1_teaching_subject_assignment_application_receipt_guard`. That trigger is a `SECURITY DEFINER` owned by `schoolos_schema_owner`, but calls two `SECURITY INVOKER` validation helpers created by `schoolos_teaching_executor`. The tested correction adds only those internal EXECUTE grants; the test now passes 32/32 at #82.

## Deliberately unclosed gates

- This advances **incremental** D1 operation-path acceptance, not all implemented D1 effects or all approval variants. Broader cross-operation races, student/family permission boundaries, field-level reads, rejection/cancellation paths and populated installation/upgrade tests remain open.
- `student.create` remains disabled until Admissions provides approved verifiable final handoff and any required Finance clearance.
- Migration 10 still consists of 197 `.sql.draft` fragments and is **not** authorized for hosted Supabase, staging, customer or production application. No Flutter, worker activation or deployment authorization is implied.
- The previous D1C2A frozen local baseline remains a historical checkpoint; this is a later increment that requires its own exact-source CI.

**Result: `D1_SUBJECT_TEACHER_P2_ACCEPTANCE_PASS — 183/183 BUSINESS / 220/220 FOUNDATION / 3 RACES — FULL D1 OPEN`.**
