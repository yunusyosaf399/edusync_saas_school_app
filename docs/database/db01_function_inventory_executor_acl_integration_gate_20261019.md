# DB-01 — D1 function-catalog expansion and executor-ACL integration approval gate

**Prepared:** 2026-10-19. **Status: EXACT INTEGRATION REQUEST COMPLETE; SHARED TOOLING CHANGE NOT YET APPROVED / APPLIED.**  
**Owner:** DB-01 `student.roll.correct` documentation, [PR #100](https://github.com/yunusyosaf399/edusync_saas_school_app/pull/100). Protected SQL is in stacked draft [PR #107](https://github.com/yunusyosaf399/edusync_saas_school_app/pull/107) on [PR #106](https://github.com/yunusyosaf399/edusync_saas_school_app/pull/106). DB-01 RC-01…RC-08 and T-B School-local date are [product approved](db01_student_roll_correct_owner_approved_contract_20261019.md); DB-02 RP-02/03/07 and shared Enrollment MOVE/date coordination remain separate pending work.

This document **requests** the D1 runtime-inventory and security/tooling owner to authorize a precisely scoped inventory expansion. It does **not** modify `tools/supabase/**`, change any shared regression acceptance expectation, authorize a public RPC, enable `student.roll.correct`, deploy Migration 10, or treat the request itself as an integration sign-off.

## 1. Verified exact-head evidence and regression root cause

On SQL branch [PR #107](https://github.com/yunusyosaf399/edusync_saas_school_app/pull/107), a temporary DB-01-owned private retained-correction result verifier `app_private.d1_roll_correct_result_rows_match_exact(uuid,uuid,uuid,uuid,jsonb)` was appended in `effect38_02_db01_roll_correct_result_pair.sql.draft`. Static D1 and Foundation CI passed; disposable local PostgreSQL parsed/applied **232 draft fragments**. The D1 runtime probe **rejected** its additional `app_private` `SECURITY DEFINER` function:

```text
D1C2A_FAIL RUNTIME_CATALOG_DRIFT {
  'functions': (542, 543),
  'security_definers': (524, 525),
  'private_functions': (385, 386)
}
```

The helper was deleted at SQL commit `03a8d48b937c7660f47216a5e93d11abacc71fee`; PR #107's effective diff again has only `effect38_01_db01_roll_lineage_nonself.sql.draft`. **The exact post-revert commit's three workflows passed**: D1 Migration 10 draft static, Foundation local stack and D1 Migration 10 local runtime. The attempted helper is **not** implemented or accepted.

**Confirmed source guard location:** `tools/supabase/domain_local_ci.py` lines 49–80 defines exact `EXPECTED_RUNTIME_METRICS`, and lines 194–310 builds the *database catalog* query and fails when any value differs. `tools/supabase/tests/test_domain_local_ci.py` lines 54–68 asserts the exact counts and access ceilings. The independent `tools/supabase/domain_function_final_guard.py` inspects the *lexically final* definitions for owner, definer, repeated declarations, signature/rename drift, final ACLs, existing approval trigger columns, dangerous-role EXECUTE and explicit trigger-creator EXECUTE. It has **no equivalent blanket permission to expand public/privileged surface** and must remain intact.

### 1.1 Exact frozen baseline (final compiled D1, before any new corrected-roll function)

| `domain_local_ci.EXPECTED_RUNTIME_METRICS` key | Frozen value | Required acceptance |
|---|---:|---|
| `functions` | **542** | Every added counted function needs exact reviewed name and delta |
| `security_definers` | **524** | New SECURITY DEFINER must have fixed owner/search path, no owner drift |
| `app_functions` | **157** | Public API growth is a **separate** reviewed step |
| `private_functions` | **385** | Internal helpers cannot gain authenticated access |
| `authenticated_app_execute` | **157** | Do not raise on merely creating disabled/ungranted wrappers |
| `authenticated_private_execute` | **0** | Always 0 |
| `anon_execute` / `service_role_execute` | **0 / 0** | Always 0 |
| `unknown_function_owners` / `app_schema_owner_functions` | **0 / 0** | Always 0 |
| `d1_tables`, `d1_table_owner`, `rls_enabled`, `rls_forced` | **34 / 34 / 34 / 34** | Unchanged for DB-01-only function packages |
| `primary_indexes`, `full_unique_indexes`, `partial_unique_indexes`, `nonunique_indexes` | **34 / 21 / 3 / 47** | Unchanged; a correction-lineage unique index requires its *own* catalog/physical contract |
| `executor_roles` / `executor_memberships` | **5 / 5** | Unchanged, reuse existing roles |
| `authenticated_table_dml` / `anon_table_dml` / `service_role_table_dml` | **0 / 0 / 0** | Always 0 |
| `student_create_rpc`, `permission_rows`, `scope_contract_rows`, `operation_contract_rows`, `role_rows`, `system_principals` | **0** each | No new School/role/permission/operation seed from schema migration |

**Critical query rule:** the D1 runtime probe counts `pg_proc` rows in schemas `app` and `app_private` whose name begins `d1_`, plus exactly two extended Foundation private trigger helpers. It uses `pg_catalog.has_function_privilege` for actual inherited/effective client privileges, not text-only GRANT scans. Avoid assuming every SQL helper outside this prefix is counted. Overloaded signatures count individually; therefore never claim a new function is an existing replacement until the final resolved signature and OID are reviewed.

## 2. Minimal first increment: exactly one private result verifier

**Immediate requested integration approval:** authorize **one** new private, non-client-executable SECURITY DEFINER function with **the specific signature below**, by approving the exact corresponding catalog delta *and related tests in the integration-owned branch*:

```sql
app_private.d1_roll_correct_result_rows_match_exact(
  p_student uuid, p_enrollment uuid, p_source_roll uuid,
  p_successor_roll uuid, p_summary jsonb
) RETURNS boolean
```

| Metric | Before | Expected after exactly this one function |
|---|---:|---:|
| `functions` | 542 | **543** |
| `security_definers` | 524 | **525** |
| `private_functions` | 385 | **386** |
| `app_functions` | 157 | **157** |
| `authenticated_app_execute` | 157 | **157** |
| `authenticated_private_execute`, `anon_execute`, `service_role_execute` | 0 | **0** |

All other `EXPECTED_RUNTIME_METRICS` values must remain identical.

**Fixed owner:** `schoolos_student_executor`; SQL `SECURITY DEFINER SET search_path=pg_catalog,pg_temp`; all relations/functions schema-qualified; `REVOKE ALL ... FROM PUBLIC,anon,authenticated,service_role`; only `schoolos_student_executor,schoolos_workflow_executor` receive internal EXECUTE. A future schema-owned `approval_applications` guard needs a separately audited *narrow* owner/execute path if it calls this helper (e.g. explicit schema-owner EXECUTE), never broader public access.

**Behavior boundary:** strict 12-key `result_summary`, typed IDs/numbers/dates, original R0 and corrected successor R1 matching Student, Enrollment, source stored policy and effective boundary, exactly one matching `supersedes_id`, inherited origin, nonblank restricted correction reason, and retained historic proof even after later CORRECT/MOVE/END. This function proves only domain rows; it must NOT serve as public receipt replay, authorize numbers to a caller, create a Roll, issue a receipt, grant permissions or require R1 still be current. Final receipt/approved-payload/reason equality and caller history-view permission are separate authenticated commands.

**Approval scope:** authorize this one function and the precise metrics **as an integration security review**, not blanket permission for 19 future names, not approval to mutate history. Restore implementation on SQL PR #107 **only after** the integration owner commits/reviews the corresponding exact guard/test change or offers a reviewed, stacked integration contract that composes with it.

## 3. Complete first-release DB-01 function roster — for staged future integration approval only

The prior [DB-01 exact P1 API/receipt gate](db01_roll_correction_p1_api_receipt_stale_apply_gate_20261019.md) proposes **5 public RPCs + 14 private helpers**. Below are **19 candidate function identities**, not installed objects; precise input/output arity and any helper consolidation are frozen only in an accepted implementation design, so **do not prematurely change the catalog to these totals**.

### 3.1 Five public `app` wrappers

| Proposed function | Owner | Client EXECUTE policy |
|---|---|---|
| `app.d1_correct_student_roll` | `schoolos_student_executor` | Authenticated **only with full live operation/ACS DIRECT checks**, separate activation approval |
| `app.d1_submit_student_roll_correction` | `schoolos_workflow_executor` | Authenticated with live APPROVAL route, no effect on SUBMIT |
| `app.d1_review_student_roll_correction` | `schoolos_workflow_executor` | Authenticated, different Person and live step/role/scope |
| `app.d1_apply_student_roll_correction` | `schoolos_workflow_executor` | Authenticated, approved fresh request and separate actual effect |
| `app.d1_read_student_roll_correction_request` | `schoolos_read_executor` | Authenticated, request participant **AND live** `student.roll_history.view` where numeric details disclosed; denies former-Campus access |

Existing DB-01 contract freezes the typed input/return signatures for these wrappers. On SQL creation **do not automatically grant** `authenticated` while command activation remains separately gated; security-invoker/definer choices must match frozen D1 executor pattern, never an open table/view.

### 3.2 Fourteen `app_private` candidate helpers

| Function suffix `d1_roll_correct_...` | Proposed owner | Only explicit internal callers; no general access |
|---|---|---|
| `command_context` | `schoolos_evidence_writer` | student/workflow executors; typed canonical hash+per-key command receipt |
| `authorized` | `schoolos_authz_reader` | student/workflow/read executors |
| `policy` | `schoolos_authz_reader` | student/workflow/read executors, exact source-Campus route |
| `prelock` | `schoolos_student_executor` | student/workflow executors, School/policy/allocator/Student order |
| `source_context` | `schoolos_student_executor` | student/workflow executors, typed latest source |
| `effect` | `schoolos_student_executor` | student/workflow executors, only after authorized handler and T-B coordination |
| `receipt` | `schoolos_evidence_writer` | student/workflow executors |
| `result_rows_match_exact` | `schoolos_student_executor` | student/workflow, reviewed narrow schema-owner callback for application guard |
| `result_matches` | `schoolos_student_executor` | student/workflow, verified actor and disclosure only |
| `reviews_live` | `schoolos_authz_reader` | workflow/read executors, independently configured reviewers |
| `candidates` | `schoolos_authz_reader` | workflow/read executors, no candidate enumeration to client |
| `application_receipt_guard` | `schoolos_schema_owner` | trigger only; must be operation-specific on existing Foundation `approval_applications` |
| `audit` | `schoolos_evidence_writer` | student/workflow executors, minimal private audit |
| `event` | `schoolos_evidence_writer` | student/workflow executors, one `enrollment.roll_corrected` outbox per success |

**Planner-only arithmetic** if and only if all **19** are new final functions and every one is a SECURITY DEFINER:

| Metric | Current baseline | All 14 private only | All 14 private + 5 public, ungranted | Later separately approved five public grants |
|---|---:|---:|---:|---:|
| `functions` | 542 | **556** | **561** | 561 |
| `security_definers` | 524 | **538** | **543** | 543 |
| `private_functions` | 385 | **399** | 399 | 399 |
| `app_functions` | 157 | 157 | **162** | 162 |
| `authenticated_app_execute` | 157 | 157 | 157 | **162** |

**DO NOT copy these planned totals into shared CI yet.** The physical implementation might reuse/consolidate approved helpers, turn a helper into a safe SQL-invoker, or already include some names after another PR; compute **fresh from exact final `pg_proc`**, the final-function source guard and the reviewed function manifest at each incremental addition. In particular, no public RPC count, definer count or client EXECUTE increase may be accepted solely because a broader project target is 19 functions.

## 4. Explicit integration-owned guard/test patch review (NOT applied here)

**Files that require D1 integration/tooling owner review, not DB-01 unilateral edits:**

1. `tools/supabase/domain_local_ci.py`: bump only the three verified metrics for first function (`functions=543`, `security_definers=525`, `private_functions=386`), with a comment referencing **one exact registered signature and owner**. Preserve all zero-permission ceilings and 34 RLS/table/index values. Keep `validate_runtime_probe()` strict equality, unchanged except for reviewed expected values.
2. `tools/supabase/tests/test_domain_local_ci.py`: corresponding exact test assertions for those three values; preserve assertions for unchanged `app_functions=157`, `authenticated_app_execute=157`, all zero private/public unauthorized privileges, and stale/drift negative tests.
3. `tools/supabase/domain_function_final_guard.py` and `tools/supabase/tests/test_domain_function_final_guard.py`: retain or strengthen the final owner/grants/signature/trigger graph audit. No blanket count exemptions and **no** special-case ignoring `d1_roll_correct_` names. Verify final SQL `SET ROLE`/RESET ROLE, named RPC signatures, no dynamic caller identity, no private authenticated grant. Existing `pg_catalog.coalesce/nullif/greatest/least` conditional-qualification source guard must continue to apply; use SQL `NULLIF` not `pg_catalog.NULLIF`.
4. GitHub Actions and local runner: do not weaken or skip D1 Migration 10 draft static, Foundation local stack or D1 local runtime. Keep Migration 10 fragments `.sql.draft`; no hosted database action. On composed branch that includes approved inventory update and DB-01 SQL, require **all three workflows green at the same exact HEAD** and a runtime catalog printout matching the amended baseline.

### 4.1 Required security/negative acceptance for a first helper

- `pg_proc` count grows by **exactly one** and only the nominated `app_private.d1_roll_correct_result_rows_match_exact(uuid,uuid,uuid,uuid,jsonb)`; `prosecdef=true`, `proowner=schoolos_student_executor`, safe `proconfig.search_path`.
- `pg_catalog.has_function_privilege` must return **FALSE** for `anon`, `authenticated`, `service_role` and PUBLIC effective EXECUTE (PUBLIC revocation must be effective). Only intended student/workflow executor roles may EXECUTE; implicit owner privileges acceptable only for trusted owner.
- All domain RLS/FORCE RLS, private table DML, public function count/grants and other catalog metrics unchanged. Verify `schoolos_student_executor` remains NOLOGIN/NOBYPASSRLS and no unapproved role memberships.
- Malformed/missing/extra summary keys, wrong IDs/policy/number/date, altered source close, two successors, wrong inherited `origin` and invalid correction reason **fail closed**, not exception-as-success; function cannot mutate. A retained row R1 that is later closed by lawful MOVE/END must still verify the **original** correction.
- Source-trigger and integration concurrency safety remains **NOT ACCEPTED** solely from a helper passing this test. Full receipt idempotency/approval application invariants need separate test and catalog additions after owner-approved implementation.

**Observer-only catalog query sketch** (adapt actual DB role permissions and schema; query is not a deployment instruction):

```sql
SELECT n.nspname, p.proname,
       pg_catalog.pg_get_function_identity_arguments(p.oid) AS signature,
       r.rolname AS owner, p.prosecdef,
       pg_catalog.has_function_privilege('authenticated',p.oid,'EXECUTE') AS auth_exec,
       pg_catalog.has_function_privilege('anon',p.oid,'EXECUTE') AS anon_exec,
       pg_catalog.has_function_privilege('service_role',p.oid,'EXECUTE') AS service_exec,
       p.proconfig
FROM pg_catalog.pg_proc p
JOIN pg_catalog.pg_namespace n ON n.oid=p.pronamespace
JOIN pg_catalog.pg_roles r ON r.oid=p.proowner
WHERE n.nspname='app_private' AND p.proname='d1_roll_correct_result_rows_match_exact';
-- EXACTLY 1 ROW with approved signature/owner/definer and all client flags false.
```

## 5. Conditional integration approvals and downstream scope

**Required single narrow integration-owner signoff:**

> Authorize the DB-01-owned `app_private.d1_roll_correct_result_rows_match_exact(uuid,uuid,uuid,uuid,jsonb)` private SECURITY DEFINER under `schoolos_student_executor`, with named internal EXECUTE grants only, and update the D1 exact runtime catalog and its tests by exactly +1 functions, +1 security_definers, +1 private_functions, preserving ALL other metrics and FINAL owner/ACL checks. This authorizes **local non-activating source integration** for that one helper, not a general DB-01 API, shared schema change, operation activation, migration deployment or merge.

**Other signatures remain blocked by separate integration reviews.** Approval of the narrow inventory delta does **not** approve DB-02 RP-02/03/07 School-local policy dates, MOVE source+destination prelock, physical one-successor uniqueness, future D1 function counts, CLI baseline replacement, or user exposure. Cross-domain [handoff](db01_school_local_roll_policy_lock_compatibility_handoff_20261019.md) owns their readiness state.

## 6. Evidence ledger and next task

| Stage | Finding |
|---|---|
| Exact frozen catalog root cause and post-revert CI | **VERIFIED** (3 workflows green on rollback commit) |
| One-function exact runtime delta and owner/EXECUTE design | **COMPLETE AS REVIEW REQUEST** |
| Five public / fourteen private candidate inventory | **DOCUMENTED, NOT IMPLEMENTED / NOT APPROVED** |
| Shared tooling expected-count edit and tests | **NOT PERFORMED; INTEGRATION-OWNED** |
| Independent security evaluation of new helper in a composed SQL + guard branch | **NOT RUN / NOT ACCEPTED** |
| DB-01 operation activation, hosted deployment or merge | **NOT AUTHORIZED** |

**Next execution step after integration approval:** compose the precise reviewed D1 guard/test update with DB-01 SQL helper on a controlled integration branch, execute current static/foundation/local runtime and full negative ACL/receipt-proof acceptance; commit and leave PR #107 draft until successful independent review. If approval is not given, continue source/design review only and do not raise expected counts by fiat. **DB-01 remains incomplete until actual protected DIRECT/APPROVAL and replay are implemented and accepted.**
