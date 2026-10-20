# DB-02 — Fixed School-wide P1 policy-version selector: security and acceptance

**Status:** Non-activating implementation candidate, external security sign-off required. Date: 2026-10-20. Owned by DB-02 in draft [PR #101](https://github.com/yunusyosaf399/edusync_saas_school_app/pull/101), separate from DB-01 [PR #117](https://github.com/yunusyosaf399/edusync_saas_school_app/pull/117).

## Owner-approved decision versus engineering implementation

[20 October owner choices](20261020_owner_choices_and_dependency_resolution.md) support School-wide DIRECT or independent APPROVAL, today-only policy INIT/REPLACE, deferred END/scheduling, and retaining every historical persistent number. RP-04 requires binding the **exact selected Foundation approval_policy_versions.id**. Existing frozen `app_private.d1_p1_route(text,uuid)` returns only route text, so a later same-route replacement is otherwise invisible to a policy-change request.

This new helper is **not** a caller authorization verdict, policy mutation, active command, reviewer approval, or business receipt. Future protected commands must verify the live individual requester and School ALL/DIRECT `student.roll_policy.change` permission, take Foundation SHARED auth and canonical receipt locks, lock the School and exact policy source, and reselect the global P1 version UUID at submit/review/apply. Current date and School existence are confirmed separately by the accepted `d1_roll_policy_change_preflight` under School lock. A historical approval with UUID V1 may not apply under UUID V2, even if both return APPROVAL.

## Implemented fragment and narrow execution surface

- `supabase/migrations/20260928000000_domain_package_01_effect44_01_db02_roll_policy_p1_version_selector.sql.draft`
- Adds one `app_private.d1_roll_policy_p1_version(p_school uuid)` function, `RETURNS TABLE(school_id uuid,policy_version_id uuid,route_mode text,error_code text)`.
- Owned by existing `schoolos_authz_reader`, `SECURITY DEFINER`, fixed `search_path=pg_catalog,pg_temp`; it uses only already-approved internal Foundation route/step/role SELECT privileges. No global School table grant, app RPC, role, policy, table, event, result code, migration activation or client-facing privilege is added. Only `schoolos_student_executor` and `schoolos_workflow_executor` have fixed internal EXECUTE; PUBLIC/anon/authenticated/service_role are revoked.
- **No policy UUID can be selected while the operation is disabled.** Requires operation code `student.roll_policy.change`, contract_version 1, enabled and not mandatory-approval; exactly one currently ACTIVE/effective global policy with `campus_id IS NULL` and active half-open timestamp interval. A Campus-specific policy is never considered or inferred from the School UUID.
- DIRECT returns exact UUID and DIRECT only if the original `d1_p1_route('student.roll_policy.change',NULL)` still equals DIRECT.
- APPROVAL requires at least one contiguous step 1..N, each with active reviewer role, `required_reviews=1` and resolver `D1_REVIEWER_ROLE_SCOPE`, and the existing P1 route must still return APPROVAL. If policy selection is absent, ambiguous, invalid or drifting, returns one fixed fail-closed error row and **no UUID**.
- Private error categories (`D1_ROLL_POLICY_P1_SCHOOL_REQUIRED`, `..._UNAVAILABLE`, `..._AMBIGUOUS`, `..._ROUTE_STALE`, `..._INVALID_STEPS_OR_ROUTE`) are not public errors, audit/event codes or receipt kinds.
- It captures its own server clock. The future protected effect **must** serialize under Foundation/School locks and reselect exact policy version after waits; using this helper alone is neither a lock nor safe authorization. It also does not independently query the School table to assert a real School; `effect43_01` supplies the source-locked School anchor.

## Acceptance and proof boundary

`supabase/tests/domain/84_db02_roll_policy_p1_version_selector.sql` is a rollback-only **20-assertion** pgTAP synthetic fixture. It proves owner/definer/path and client EXECUTE denial, internal Student and Workflow EXECUTE, disabled route denial, missing School UUID, exact DIRECT selected UUID/route, ambiguity on two current global policies, exact APPROVAL UUID with valid configured review step, agreement with original P1 route and no policy/roll mutation. Temporary operation and policy fixture activation is transaction-scoped, **not deployment**.

Registered in `tools/supabase/domain_business_ci.py` after DB-02 reviewer #82 (10 tests) and source preflight #83 (18 tests). `tools/supabase/tests/test_domain_acceptance_ci.py` verifies manifest presence and fixture test plan. The exact expected local catalog is updated only for the **one additional private definer function**: 548 total functions / 530 definers / 391 private, versus 547/529/390 after effect43_01; the app/client, RLS and table DML baselines must stay unchanged. Existing suite #1–80 is retained; DB-01 #81 is **unmerged on a different branch** and must not be counted as accepted.

**Not proven by this test:** all inactive/expired policy permutations; campus-only policy fixture when Campus is absent from the seeded test; true transaction-adversarial policy turnover across an APPLY; ability to prevent a later stale approved request from using an earlier UUID; the complete protected submit/review/apply protocol; external sign-off.

## Independent security and integration hold

Security reviewer must independently inspect exact-head ACL/ownership, full Foundation route predicate parity, request versus review/apply policy UUID comparisons, School/ALL authority, same-Person reviewer exclusion from effect42_01 and inherited workflow, date/source locks from effect43_01, and #82/#83/#84 execution. No external approval exists at authoring time. No direct main commit, branch force push, DB-01/03/04 modification, enabled protected operation, registered broad event or hosted Supabase deployment is permitted.

The **next logical DB-02 implementation** after independent approval is the protected typed DIRECT/SUBMIT request phase with stable receipt/intent and Foundation current-authority checks, preserving the existing School lock graph. Approval application and actual policy/pool writes must be reviewed separately with two-session concurrency evidence.
