# DB-01 — Private Roll CORRECT current authority and P1 route gate

**Date:** 2026-10-20. **Status:** CANDIDATE / CI AND INDEPENDENT SECURITY REVIEW PENDING. **Non-activating DB-01 increment.**

## Exact stack and intent

- Parent: DB-01 tested, unmerged [draft PR #121](https://github.com/yunusyosaf399/edusync_saas_school_app/pull/121), head `ee4909a4ca2c30d98e47b7af10bdbd0538a97147`. It proves genuine authenticated P0 versus **private** correction collision only.
- This stacked branch: `db/db-01-roll-correct-p1-private-auth-gate`.
- Approved source: `docs/database/db01_student_roll_correct_owner_approved_contract_20261019.md`, RC-06 plus existing D1 P1 Foundation, Section ancestry and reviewer role/scope contract.
- New **draft-only** SQL: `20260928000000_domain_package_01_effect41_03_db01_roll_correct_private_authority_p1.sql.draft`. Do not rename, deploy or independently execute it.
- Two private, `schoolos_authz_reader`-owned SECURITY DEFINER functions:
  1. `d1_roll_correct_authorized(principal uuid,permission text,section uuid,reviewer_role uuid DEFAULT NULL)`: refuses missing/disabled operation, inactive/non-individual/unbound Principal, disabled permission/scope, incomplete grant chain or invalid Section ancestry. Change permission is `student.roll.correct`; review permission is `student.roll.approve` and requires an explicit, currently held configured reviewer Role. Grant path is exact ALL/CAMPUS/CLASS/SECTION, resolved from the named Section with matching supported typed targets.
  2. `d1_roll_correct_policy(section uuid)`: under operation enablement, fail-closed effective Campus-specific or School-fallback P1 policy. Reject zero/multiple/invalid active policies and invalid approval templates; return the **actual target Campus** even on School fallback.
- Both functions deny direct EXECUTE to PUBLIC, anon, authenticated, service_role. Only Student, Workflow and Checked-read executors may invoke them. They do not derive caller identity, create receipts, apply effects or grant authority by themselves; future protected RPCs must verify the server Principal, acquire Foundation SHARED auth lock *before* domain locks, pin the reviewed policy/version, check exact actor/participant, and reauthorize after waits.
- **Crucial separation:** `authorized(...,'student.roll.approve', ...,reviewer_role)` checks complete reviewer Role+grant/scope, **not** independently assigned OPEN reviewer step, different Person, or approval application. Those remain strict workflow-only gates, not general-purpose authorization shortcuts.

## Scope and exact catalog impact

- Added exactly two private functions: expected runtime catalog **550 functions / 532 definers / 157 public / 393 private**, zero authenticated-private/anon/service-role execution; 34 FORCE RLS tables unchanged.
- **97 permissions / 322 permission-scope alternatives / 36 operations remain unchanged.** No new role, scope, permission, operation, audit/outbox, table or migration activation.
- `student.roll.correct` and its change permission remain **disabled** in the installed draft catalog; the SQL does not activate them.
- No changes to Roll Policy (DB-02), Admissions (DB-03), Curriculum (DB-04), Enrollment MOVE/END implementation, Foundation migrations/tests, deployment or hosted Supabase.

## Test evidence and acceptance gate

New rollback-only `85_db01_roll_correct_private_authority_p1.sql`, **22 proposed assertions**. Uses the existing verified synthetic Principal and School/Section ancestry; tests missing/disabled operation, complete current staff role/grant/scope, unknown Principal or Section, wrong permission, reviewer-role requirements, disabled permission/scope, School fallback DIRECT policy, actual campus ID, narrow client EXECUTE denial, kill-switch and no created Roll. Synthetic activation and policy insertion occur **inside a transaction rolled back by the suite**; they do not enable any project deployment.

Business manifest, strict runtime function inventory and a Python static helper-security test were updated. Require exact-HEAD static, Foundation and D1 local PostgreSQL CI before marking this gate PASS. Do not conflate the 22 proposed pgTAP checks with a confirmed pass until the run logs prove it.

## Remaining DB-01 release gates

1. Independently audit this authority/policy function package, especially RLS inputs, Foundation SHARED authorization serialization and P1 reviewer step separation.
2. Implement the approved typed `DIRECT/SUBMIT/REVIEW/APPLY` and bounded request-read entry points with current live ACS, verified Principal, fixed receipt/idempotency, separate approval application, invalidation on deterministic staleness, and restricted disclosure.
3. Preserve retained R0→R1 result provenance and idempotent replay after later CORRECT/MOVE/END. Register only the fixed `enrollment.roll_corrected` evidence and result code `D1_STUDENT_ROLL_CORRECT` through approved integration.
4. Prove genuine **authenticated protected** CORRECT versus P0, MOVE, END and policy-revision contention in independent PostgreSQL sessions, including School-local cutover and two-real-date history behavior.
5. Obtain independent integration/security approval and explicit migration/release authorization before any merge or activation.

**No partial helper or successful test grants permission to enable a public `student.roll.correct` operation.**
