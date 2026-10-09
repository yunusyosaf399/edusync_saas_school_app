# D1 FAMILY Principal membership DIRECT authorization — independent acceptance review

Date: 2026-10-09  
Verdict: **PASS — incremental D1 business acceptance only; complete D1 package remains OPEN.**

## Exact source, merge and CI provenance

- Source PR: [#7](https://github.com/yunusyosaf399/edusync_saas_school_app/pull/7), branch `database/d1-family-membership-authority-acceptance`.
- Baseline `main`: `230862d00085bf03ae5fcb5b640758cb0af9ead5`.
- **Exact tested source SHA:** `1f2c5869560420cb94f4c3a17372f53712e8e2e1`; merge commit `cd69c08e32e5b256153ff6a8b5c23760172f1f04`. The verified merge has that tested SHA as its second parent and no unreviewed integration changes.
- [D1 disposable runtime #99](https://github.com/yunusyosaf399/edusync_saas_school_app/actions/runs/37895744474) **PASS**: all 197 non-executable Migration 10 fragments applied solely to disposable Postgres; 34/34 D1 relations forced RLS; 540 final functions, 522 SECURITY DEFINER, zero authenticated/anon/service_role private-function execution exposure in catalog probe; lint at error and warning levels; **220/220 Foundation regressions**; **292/292 D1 business assertions across nine suites**; three observed-lock employee-creation concurrency races.
- [Foundation #308](https://github.com/yunusyosaf399/edusync_saas_school_app/actions/runs/37895744742) **PASS**: nine frozen Foundation migration/test files, 175 Python tooling tests, 220/220 Foundation pgTAP.
- [D1 draft static #75](https://github.com/yunusyosaf399/edusync_saas_school_app/actions/runs/37895744435) **PASS**: 197 fragments, 34 relations, 97 permissions, 322 supported scope alternatives and 36 operation contracts.
- No hosted/staging/production database migration or worker activation was performed.

## Exact accepted source delta

1. `supabase/migrations/20260928000000_domain_package_01.sql.draft`: seven added lines register `family.principal_membership.change` in the closed, typed D1 receipt allowlist with **DIRECT 8**, `request.submit` **8**, `request.review` **4**, `request.apply` **2** JSON-array fields. The latter three phases are only type registrations here, **not independent approval-path business acceptance**. Existing actor verification, authorization and RLS policies remain in force. No grants change.
2. `supabase/tests/domain/09_family_principal_membership_authorization.sql`: new rollback-isolated **38/38 passing** pgTAP assertions with synthetic Family/Student records and Auth FAMILY Principal/role/permission/scope chain.
3. `tools/supabase/domain_business_ci.py`: nine suites, aggregate **254 + 38 = 292** planned/passing business assertions.
4. Frozen Foundation SQL/tests, D1 catalog counts, deployment settings and hosted Supabase environments remain unchanged.

## Business and security behaviors proven

- The authenticated role cannot query the private `family_principal_memberships` table.
- Without a usable shared FAMILY credential, authorized staff cannot ADD FAMILY Principal membership. A Family/Student relationship remains independent of FAMILY shared login membership.
- A valid, bound FAMILY-only Principal with enabled, family-safe `OWN / D1_FAMILY_CHILD` scope is a prerequisite for a new effective membership. This credential/relationship chain alone does not grant child portal access.
- A currently authorized staff actor can ADD a retained membership with correct Family/Principal identity, effective start and versions. A new overlapping ADD, changed intent with reused idempotency key, and replay-created duplicates are denied.
- Removing the staff actor's current `family.principal_membership.change` permission prevents an END command; the original interval remains open.
- Suspending the FAMILY Principal advances its server-managed version and blocks a fresh ADD, **but valid staff END remains permitted to reduce access**. It closes the existing historical interval and writes `ended_at`/`ended_by`; it does not delete the relationship or create/erase Student child-access entitlements.
- Identical ADD/END replays retain accepted original identities and receipts even after later status/interval changes. Two accepted mutation intents produce two typed successful receipts and exactly two `family.principal_link_changed` outbox events. The anonymous role cannot call the protected command.

## Failures diagnosed and corrected before successful qualification

- Initial [D1 runtime #95](https://github.com/yunusyosaf399/edusync_saas_school_app/actions/runs/37894959810) stopped after 4/38 new assertions with a **duplicate synthetic FAMILY Principal fixture key**. Removed the duplicate INSERT; no database access changes.
- Next [D1 runtime #97](https://github.com/yunusyosaf399/edusync_saas_school_app/actions/runs/37895082608) passed 8/38 new assertions before `permission denied for table family_principal_memberships`: the test was still running with `SET ROLE authenticated` while reading a private history table. This was a **correct access denial**. Moved that single history assertion to the privileged synthetic fixture section and repaired a later dollar-quoted UUID substitution used for a denied END check. The assertions and security constraints were not weakened.
- Corrected exact-head [runtime #99](https://github.com/yunusyosaf399/edusync_saas_school_app/actions/runs/37895744474) passed **38/38 new**, **292/292 total**, and all accompanying gates.

## Explicitly open gates

- **Effect 31 P1 approval** submit/review/approve/reject/invalidate/apply and concurrent membership operations are not fully accepted by this DIRECT-route suite.
- **Effect 30 Family relationship-change** ADD/END/CORRECT and dependent child-access closure require independent authorized operation-path acceptance; fixture relationship retention does not prove the full operation.
- Family portal Student-profile checked reads, field-level disclosure, school/campus/section scopes and cross-Family read boundaries remain open.
- Admissions/`student.create` remains disabled pending approved final handoff and any necessary Finance clearance; synthetic Student fixtures are not a production intake claim.
- Broader D1 business coverage, populated upgrade/backfill, later domain packages and Flutter remain open. Migration 10 remains **197 `.sql.draft` fragments, not authorized for hosted or production execution**.

**Result: `D1_FAMILY_MEMBERSHIP_DIRECT_ACCEPTANCE_PASS — 38/38 NEW / 292/292 BUSINESS / 220/220 FOUNDATION / 3/3 EMPLOYEE RACES — FULL D1 OPEN`.**
