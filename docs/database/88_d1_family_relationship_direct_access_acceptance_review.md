# D1 Family relationship DIRECT authorization and child-access closure — independent acceptance review

Date: 2026-10-09  
Verdict: **PASS — incremental D1 business acceptance, not complete D1 release acceptance.**

## Exact source and CI provenance

- [PR #8](https://github.com/yunusyosaf399/edusync_saas_school_app/pull/8) branch: `database/d1-family-relationship-direct-access-acceptance`.
- Base `main` commit: `731e92b33d57ed391833dfb10a6a14a40c0abe79`.
- Trusted **exact tested source**: `96a588ccee8b9f9e98d5b576801edb5365781cb1`; merged via `6c50a44b545cf7a3a44843b75529dc94abab11e2`. The tested source is merge commit's second parent, with first parent the verified base.
- [D1 runtime pull-request #107](https://github.com/yunusyosaf399/edusync_saas_school_app/actions/runs/37902870509) **PASS**, and [D1 runtime push #106](https://github.com/yunusyosaf399/edusync_saas_school_app/actions/runs/37902866172) **PASS**, both for the same source: 197 non-executable Migration 10 draft fragments locally applied, catalog/RLS/ACL checks with 34/34 D1 relations forced RLS, zero authenticated/anon/service_role private-function execution exposures, error/warning lint passes, **220/220 frozen Foundation regressions**, **344/344 incremental D1 business assertions** across **ten suites**, and **3/3 observed-lock Employee-creation races**.
- [Foundation local #314](https://github.com/yunusyosaf399/edusync_saas_school_app/actions/runs/37902870577) **PASS**: nine Foundation SQL migration/test files, 175 Python tooling tests, **220/220** Foundation assertions.
- [D1 draft static #81](https://github.com/yunusyosaf399/edusync_saas_school_app/actions/runs/37902870696) **PASS**: 197 fragments, 34 relations, 97 permissions, 322 scope alternatives and 36 operation contracts.
- All evidence is **disposable local CI only**; no managed school/staging/production Supabase database was changed.

## Exactly reviewed PR source changes

Five files changed; no Foundation migration, RLS-policy relaxation, authenticated/client-grant change, worker or Flutter modification:

1. `supabase/tests/domain/10_family_relationship_direct_access.sql` — new **52/52** passing rollback-isolated business pgTAP assertions; uses synthetic Student and Family fixture rows, existing trusted staff Auth fixture and a shared FAMILY credential for dependent child-access verification.
2. `tools/supabase/domain_business_ci.py` — registers tenth test suite: previously **292** passing assertions plus **52**, for **344/344** passing D1 business assertions.
3. `supabase/migrations/20260928000000_domain_package_01.sql.draft` — only canonical `family.relationship.change` typed receipt operation shapes: DIRECT **13**, `request.submit` **13**, `request.review` **4**, `request.apply` **2** JSON-array fields. Registration does not itself approve the P1 workflow branches.
4. `supabase/migrations/20260928000000_domain_package_01_effect30_22_family_relationship_dependent_lock_order.sql.draft` — uses no-op Student and Family parent-row updates instead of assigning `updated_at` directly; pre-existing `zz_d1_version` server-managed triggers advance the expected row versions. No Foundation trigger changes.
5. `supabase/migrations/20260928000000_domain_package_01_effect30_24_family_relationship_interval_scope.sql.draft` — internal-only **column-level SELECT grant for `operation_contracts.handler_key` to `schoolos_authz_reader`**, the SECURITY DEFINER owner of the final Family relationship policy resolver. This repairs an internal policy metadata access error under existing forced RLS. It grants no table data to authenticated/anon/service_role and makes no client-grant change.

## Verified DIRECT-route outcomes

- Authenticated users cannot enumerate raw private Family relationship rows.
- The exact `family.relationship.change` DIRECT authorization is required. Invalid facts are rejected without history changes. An enabled FAMILY shared-credential membership alone creates neither a Student–Family relationship nor child portal access.
- **ADD** creates a retained Student–Family relationship with a reviewed effective date and increments Student/Family versions. Same-key replay returns identical accepted identity/version; a duplicate overlapping relationship or changed-intent reuse is rejected.
- A separate, explicit **child-access ADD** for Student A requires its actual relationship and advances aggregate versions; unrelated Student B is not granted access.
- **CORRECT** closes the prior relationship, appends a successor with `supersedes_id` lineage, advances versions, and retains continuous coverage for the existing child-access entitlement. Original and corrected receipts remain replayable.
- Revoking staff's live relationship-change grant denies an END even with the known successor UUID; the source remains unchanged. The fixture restores that permission with a savepoint.
- **END** of the last relationship basis closes the existing child-access interval at the first uncovered date, retaining relationship predecessors/successor, child-access row, end actor/time, and the independent FAMILY Principal membership. The return reports one dependent access closure.
- Accepted ADD/CORRECT/END generate exactly three typed successful command receipts and three `family.relationship_changed` events; replay does not add duplicates. The separate child-access ADD generated one `family.child_access_changed` event, and implicit closure does not counterfeit an additional direct child-access command. Anonymous access to the relationship command is denied.

## CI failure history (preserved, not ignored)

- Original [push D1 runtime #102](https://github.com/yunusyosaf399/edusync_saas_school_app/actions/runs/37901470152) and [PR runtime #103](https://github.com/yunusyosaf399/edusync_saas_school_app/actions/runs/37901569261) **FAILED** on source `b115f7638967f244581327e2886ff598954be71c` at the new suite's second assertion. SQLSTATE **42501** occurred when the final internal Family policy resolver read `operation_contracts.handler_key` without the relevant column privilege. All previously accepted **292/292** D1 business tests and **220/220** Foundation regressions passed.
- The internal-only `handler_key` metadata grant was added, and the suite's rollback-only policy fixture enabled the required `family.access.approve` permission state (without granting approval authority or modifying deployed data).
- The corrected exact commit `96a588ccee8b9f9e98d5b576801edb5365781cb1` passed both new D1 runtime runs #106 and #107 plus Foundation #314 and static #81. Previously failed source runs are not presented as passes.

## Explicit open acceptance gates

- **Effect 30 P1 independent APPROVAL** submit/review/REJECT/approve/apply/invalidate and comprehensive cross-person authority checks are still open.
- Explicit primary-family replacement, multiple independent relationship bases and alternative-basis child access survival, cross-campus/CLASS/SECTION scoped disclosure, concurrency races for Family relationship operations, and end-before-future-access interval cases remain separate tests.
- Family/student checked-read profile RPCs and sensitive-field disclosure remain unaccepted by this DIRECT command suite.
- `student.create` remains disabled pending Admissions/Finance handoff; synthetic Student fixtures are not approved intake.
- Populated migration/upgrade and full D1 operation coverage, later domain packages and Flutter remain open. **Migration 10 stays 197 `.sql.draft` fragments and is not authorized for hosted application**.

**Result: `D1_FAMILY_RELATIONSHIP_DIRECT_PASS — 52/52 NEW — 344/344 D1 BUSINESS — 220/220 FOUNDATION — 3/3 EMPLOYEE RACES — D1_FULL_ACCEPTANCE_OPEN`.**
