# D1C2A PR #2 independent runtime/source review

Date: 2026-10-08  
Decision: **PASS — D1C2A disposable local baseline only**. This is not D1 overall acceptance, migration activation, Admissions approval, or hosted deployment authorization.

## Exact review boundary

- Repository: `yunusyosaf399/edusync_saas_school_app`
- PR: [#2](https://github.com/yunusyosaf399/edusync_saas_school_app/pull/2), `database/fix-d1-runtime-and-completion-baseline`
- Base: `c78fffc6be2c431f1057a8de606edf5e07266c04`
- **Trusted SQL/runtime source:** `ff4b612eefa77f25e1fe1220eeff5ab0ff8f25ad`
- Compare: 30 ahead, 0 behind; 99 changed paths; no Foundation migration 1–9 or Foundation database test 01–09 changes.
- Relevant changed sources include 77 D1 SQL draft files, six new domain-test/fixture files, eight tooling/test files and the local runtime workflow. Review/freeze documentation built after this source SHA must remain documentation only.
- Every Migration 10 fragment remains named `.sql.draft`. No executable D1 migration, remote/staging Supabase mutation, worker activation or client deployment is authorized.

## Exact-commit CI evidence

1. [Foundation database #284 — `37793587873`](https://github.com/yunusyosaf399/edusync_saas_school_app/actions/runs/37793587873): **success**, 175/175 Python tooling tests, clean local nine-Foundation-migration reset, 5/5 Auth fixtures, both lint gates, **220/220 Foundation pgTAP**.
2. [D1 draft static #62 — `37793587525`](https://github.com/yunusyosaf399/edusync_saas_school_app/actions/runs/37793587525): **success**, 9/9 draft-guard tests, 26/26 final-function-state tests; source counts **197 fragments, 34 relations, 97 permissions, 322 scope alternatives, 36 operation contracts**. Reconstructed **540 final functions, 522 SECURITY DEFINER**, 0 unknown owners, 0 unresolved collisions, 0 authenticated private-function EXECUTE, 0 schema-owner public RPCs.
3. [D1 local runtime #70 — `37793587538`](https://github.com/yunusyosaf399/edusync_saas_school_app/actions/runs/37793587538): **success**. Docker disposable stack, CLI 2.98.2 and Postgres image 17.6.1.113. **All 197 drafts applied**. Catalog confirms **34/34 D1 relations forced RLS**, 540 functions (157 `app`, 383 `app_private`), 0 anonymous/service-role function surface, 0 authenticated private function surface. Local lint errors/warnings pass, Auth fixtures 5/5, Foundation regression 220/220, D1 business assertions **135/135 across five suites**, three two-session race cases with observed lock waits, then local stack stopped.

## Source-level review

- Final diff checked across all changed-file groups. Foundation frozen migration/test files, bootstrap manifest, Supabase hosted target and Flutter files are outside the PR delta.
- Identified high-risk SQL corrections: Student status P2 application guard no longer reads nonexistent `approval_applications.result_kind`; it filters by exact operation and checks the linked command receipt's `result_kind='D1_STUDENT_STATUS_CORRECT_APPLY'`. Student and Employee P1/P2 approval paths retain split submit/review/apply behavior and version/receipt checks.
- Subject assignment adds narrowly targeted EXECUTE edges to Teaching/Workflow executors for receipt lookup, Principal lock and capability-interval helpers. There are no newly granted PUBLIC/anon/authenticated/service-role private D1 helper executes in the reviewed patch and final runtime ACL report.
- A temporary schema-owner EXECUTE privilege is added solely while creating the Student Status application trigger, then explicitly revoked. Ownership packaging changes use reviewed executor owner boundaries. Family executor gets `USAGE` on public `app` schema required for its RPC ownership, not arbitrary table DML.
- SQL parser/name-resolution repairs include unqualifying PostgreSQL syntax expressions (`COALESCE`, `GREATEST`, `CURRENT_DATE`), qualifying ambiguous UPDATE targets, normalizing idempotency intent shape for Subject Teacher changes and avoiding generic row-field access that broke on non-temporal trigger records.
- The source guard is strengthened with checks for unavailable columns on the final `approval_applications` trigger definitions, trigger creator EXECUTE, temporary privilege revocation, owner-transfer packaging and invalid SQL conditional syntax.
- The D1 runtime harness is local-only, uses a pinned Postgres image with restored transient CLI cache, and runs exact unit, database, rejection, replay, audit, event, capacity, policy, Auth, ACL, RLS and concurrency assertions included in the five current business suites. No managed school data is involved.

## Deliberately open

- The five business suites cover **selected paths in four D1 operation families**, not all 35 implemented effects or every P1/P2 branch. The three races are employee-creation races, not all domain concurrency.
- Non-owner negative testing and RLS are present in the current suites/catalog probes but comprehensive field-level disclosure, request cancellation/rejection, multi-campus/Family, all history correction, cross-operation concurrency and offline/reconnect matrix coverage remain open.
- Populated upgrades, installation/activation sequencing, deployment-owned registration replay, student intake/Admissions integration and later database packages remain open.
- `student.create` remains disabled. The separate Admissions physical design document is proposed only.
- Runtime source is the PR HEAD above. Any subsequent SQL/config/CI changes require a new exact-SHA local gate. Documentation-only closeout must not be mistaken for untested runtime changes.

**Verdict:** `D1C2A LOCAL RUNTIME + FOUNDATION + STATIC BASELINE PASS — TRUSTED SOURCE ff4b612eefa77f25e1fe1220eeff5ab0ff8f25ad — FULL D1 BUSINESS ACCEPTANCE OPEN — MIGRATION 10 STILL .sql.draft`
