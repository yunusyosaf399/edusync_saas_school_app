# D1 Family relationship P1 approval and terminal invalidation replay — independent acceptance review

Date: 2026-10-09  
Verdict: **PASS — incremental D1C2A acceptance only; full D1 business/release acceptance remains OPEN.**

## Provenance and exact-SHA runtime gates

- [PR #9](https://github.com/yunusyosaf399/edusync_saas_school_app/pull/9) started from `8ee61ae5165ca6a80b449202a2e03373f7c82e4c` and was merged by `ad3edc1a718c8fd8e5139d7ee9f024efb66ddef6`. The merge's second parent is the exact tested head `e48b7b17dfdc6008d7f4f3d8c389e746fdd54d56`.
- [D1 local runtime #118](https://github.com/yunusyosaf399/edusync_saas_school_app/actions/runs/37918049992) **PASS** on exact head: **66/66** new Family relationship P1 assertions, **410/410** total D1 business across 11 suites, **220/220** frozen Foundation behavior assertions, all three Employee-create two-session races with observed lock waiting, local catalog and function ACL/RLS probes, and both lint levels.
- Runtime constructed a **disposable local** Postgres instance: 197 non-executable D1 `.sql.draft` fragments applied locally only; 34/34 D1 RLS relations; 540 final functions, 522 SECURITY DEFINER functions; no authenticated/anon/service_role private-function EXECUTE exposures in the catalog probe.
- [D1 static #90](https://github.com/yunusyosaf399/edusync_saas_school_app/actions/runs/37918049980) **PASS**: 197 fragments, 34 relations, 97 permissions, 322 supported scope alternatives, 36 operations, no final-signature shape drift or unknown owners, Foundation source and local config checks.
- [Foundation local #325](https://github.com/yunusyosaf399/edusync_saas_school_app/actions/runs/37918049999) **PASS**: nine frozen migrations/tests, five Auth fixtures and 220/220 Foundation assertions; no hosted/staging/prod SQL applied. Node.js action deprecation warnings were nonblocking.

## Reviewed five-file delta

1. `supabase/migrations/20260928000000_domain_package_01_effect30_08_family_relationship_candidates.sql.draft`: replace `q.*` and `t.*` selects with only the workflow columns granted to `schoolos_authz_reader`.
2. `supabase/migrations/20260928000000_domain_package_01_effect30_11_family_relationship_reviews_live.sql.draft`: narrow request projection and grant `d1_final_approver_role(uuid,uuid)` EXECUTE **only** to trusted NOLOGIN workflow/read executors; no client access.
3. `supabase/migrations/20260928000000_domain_package_01_effect30_13_family_relationship_apply.sql.draft`: allow `schoolos_workflow_executor` to read only approved application-binding columns, with an operation-specific `family.relationship.change` SELECT RLS policy. For immutable SUCCEEDED replay, require current requester authority and live review evidence. For an already REJECTED/INVALIDATED receipt, return the durable terminal outcome under current caller authorization without imposing a newly revoked requester's authority a second time; new apply still rechecks stale requester authority and invalidates rather than mutating.
4. `supabase/tests/domain/11_family_relationship_p1_approval.sql`: 66 new rollback-isolated pgTAP assertions spanning independent staff requester/reviewer, approval policy selection, denial of premature/direct/self application, revoked reviewer scope, approval-only transaction boundary, separately applied success, same-key replay, rejection and invalidation, and client/private data denials.
5. `tools/supabase/domain_business_ci.py`: register eleventh domain business suite; planned total 410.

No Foundation source/test bytes, Flutter, workers, deployed schema or generic client permission chain changed.

## Failure-and-repair history

- Runtime #110 at first valid SUBMIT: SQLSTATE 42501 on `approval_requests` caused by unrestricted `SELECT q.*` in a column-limited authz-reader function. Fixed exact projections.
- Runtime #112 at APPLY: SQLSTATE 42501 on `d1_final_approver_role`. Fixed NOLOGIN-only EXECUTE for the two callers.
- Runtime #114 at successful APPLY receipt replay: SQLSTATE 42501 on `approval_applications`. Added operation-only RLS plus five-column internal SELECT; tests explicitly prove client denial.
- Runtime #116 / push #115 on `9316619730858f074d295a3e9616266ff649c0d2` reached 55/66 P1 assertions without mismatches but stopped on **replaying a previously INVALIDATED apply** after the requester permission had been revoked. Source `e48b7b17...` limits the extra requester check to the SUCCEEDED replay branch and passed all exact-SHA gates above. Earlier failures are not reclassified as passes.

## Scope that is **not** accepted by this increment

- Other Effect 30 request shapes, explicit primary-family replacement, multiple alternate relationship bases, cross-campus/CLASS/SECTION reviewer scope coverage and relationship-operation concurrency races.
- Effect 31 membership P1 approval, Family portal checked reads, sensitive Student/Family disclosure, complete operation acceptance, populated upgrade, and Admissions/Finance final intake.
- `student.create` remains disabled. No Migration 10 hosted/staging/production apply, Flutter activation or full D1 release is authorized.

**Result: `D1_FAMILY_RELATIONSHIP_P1_PASS — 66/66 NEW — 410/410 D1 BUSINESS — 220/220 FOUNDATION — 3/3 EMPLOYEE RACES — D1_FULL_ACCEPTANCE_OPEN`.**
