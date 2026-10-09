# D1 Subject Teacher P2 REJECT and stale-requester acceptance — independent review

Date: 2026-10-09  
Status: **PASS — incremental business acceptance checkpoint**, not full D1 acceptance.

## Exact branch, merge, and CI provenance

- PR: [#5](https://github.com/yunusyosaf399/edusync_saas_school_app/pull/5), `database/d1-subject-p2-reject-requester-stale`.
- Trusted exact tested source: `e9a41df526da4abf036ca3f5f4639dc6efee156a`; merged into main by `ffe7eb227c9a3dead22b49d4354919d4aeaca35f`.
- [D1 disposable local runtime #85](https://github.com/yunusyosaf399/edusync_saas_school_app/actions/runs/37889455840): PASS on that exact source — 197 non-executable Migration 10 draft fragments loaded, 34/34 D1 relations forced RLS, catalog/ACL/lint checks, 220/220 Foundation regressions, **220/220 incremental D1 business assertions**, three observed-lock employee-creation concurrency races and local stack teardown.
- [Foundation local #297](https://github.com/yunusyosaf399/edusync_saas_school_app/actions/runs/37889455843): PASS on the same tested source — nine original migrations and regression files, 175 tooling tests, 220/220 Foundation pgTAP assertions.
- No new D1 static workflow was triggered for the test-only PR: the previous SQL/source static baseline remains applicable because no SQL draft, contract, permission definition, migration or static guard file was changed. Do not describe #85 or #297 as an independently rerun D1 draft static job.

## Source delta and verification

Exactly **two** files changed:

1. `supabase/tests/domain/07_subject_teacher_p2_reject_requester_stale.sql` — new rollback-isolated 37-assertion pgTAP suite using five synthetic Foundation Auth fixtures and the existing P2 Subject Teacher policy/teacher setup.
2. `tools/supabase/domain_business_ci.py` — the seventh suite registered with exact expected count 37; overall 37 + 25 + 22 + 42 + 25 + 32 + 37 = **220**.

The PR is a clean fast-forward in source semantics (one source commit, no drift against base). It does not change Foundation migrations/tests, the D1 SQL draft, production/staging configurations, deployment activation, client code, or worker code.

## Observed behavior — two separate cases

**A. Explicit independent reviewer REJECT**

- A historical Subject Teacher CORRECT is submitted with pending request version 3.
- Current independently authorized reviewer rejects, moving it to terminal `REJECTED` version 4.
- Replaying identical review and submit keys preserves original receipt/version/identity; applying the rejected request is denied.
- Source remains open, no successor is inserted, no approval application or assignment success event exists; there is exactly one rejection decision/transition/review receipt.

**B. Approved request with requester grant revoked before apply**

- Fresh request is submitted after the unrelated rejected request. Independent reviewer approves it, request version 4.
- After the requester's `teaching.subject_assignment.change` role grant is revoked, that requester is refused apply as a participant.
- The still-currently-authorized final reviewer invokes apply to record terminal `INVALIDATED` version 5, with one rejected apply receipt/transition.
- Replaying the same apply retains the terminal version and result. The original assignment is unchanged, with no successor or approval application and no assignment success event.

The distinction between **denying a revoked requester** and **allowing a valid final approver to invalidate stale authority** is intentional and covered.

## Scope and remaining gates

- This increases incremental accepted D1 business coverage **183 → 220** across seven suites. It does **not** imply that every operation among the 35 implemented effects or all positive/negative branches is accepted.
- New tests are single-session P2 acceptance. Only the prior three employee-creation race scenarios cover concurrency; cross-operation races and other domain concurrency remain open.
- Student/Family private reads, child-access and scope denial, additional academic/employee/teaching commands, populated upgrade, Admissions student creation/fee handoff, and later domain packages remain open.
- `student.create` remains disabled; Migration 10 remains `.sql.draft` with no authorization for hosted/staging/production application, worker activation or Flutter rollout.

**Result: `D1_SUBJECT_P2_REJECT_STALE_ACCEPTANCE_PASS — BUSINESS 220/220 — FOUNDATION 220/220 — EMPLOYEE_RACES 3/3 — D1_FULL_ACCEPTANCE_OPEN`.**
