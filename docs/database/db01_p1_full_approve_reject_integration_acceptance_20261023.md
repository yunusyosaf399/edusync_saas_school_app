# DB01-09 — Genuine P1 SUBMIT/APPROVE/APPLY and REJECT integration acceptance

**Result:** PASS in *disposable local PostgreSQL engineering acceptance* only, verified 2026-10-23.

**Exact tested code HEAD:** `55e0422e4098894150a4c16e625dcd56591249bc`, [draft PR #141](https://github.com/yunusyosaf399/edusync_saas_school_app/pull/141). No merge, live database change, protected operation activation, release permission grant or SQL migration approval.

## Contract and owner decisions confirmed

EduSync's approved initial Roll rule is **Option A — server-generated automatically at successful initial Enrollment placement**. School staff do not enter a manual first Roll number. Authorized staff may later propose a numeric correction through the separate checked `student.roll.correct` route. For P1 APPROVAL, a genuinely independent, currently authorized reviewer must act through configured steps. An approved request is not itself permission to modify the Student Roll; the authorized original requester must separately invoke APPLY. A reviewer decision of REJECT is terminal and has no Roll effect.

This acceptance **does not change** frozen RC-01…RC-08, the existing DB02 Roll policy choices, DB03 Admissions/Enrollment ownership, DB04 curriculum tables, or any Migration 10 SQL.

## Test provenance and execution

`tools/supabase/domain_db01_p1_complete_integration_ci.py` uses three separate synthetic Student/Campus/reviewer-policy namespaces from the already-proven `db01_p1_review_two_backend_setup.sql` fixture. It executes real protected application RPCs as authenticated, bound Principals: `app.d1_place_student_enrollment` (via fixture), `app.d1_submit_student_roll_correction` (via fixture), `app.d1_review_student_roll_correction` and `app.d1_apply_student_roll_correction`. Approvals, rejections, Roll allocations, Student version updates, command receipts and audit/outbox evidence are **not** fabricated by the test; only schema-owner test configuration uses fixture authority. Results are committed in an isolated disposable Supabase database, verified from a separate PostgreSQL connection, then discarded with the local stack.

## Genuine end-to-end outcomes

| Case | Sequence | Required and observed result |
| --- | --- | --- |
| Accepted correction | P0/R0 → SUBMIT → first APPROVE → second APPROVE → APPLY | New R1, Student version 2, old R0 retained and linked; exact two approved steps/reviews, only one application/apply receipt/audit/correction outbox. Repeating APPLY with the exact same key returns the original result without effects |
| Rejected at first step | P0/R0 → SUBMIT → first REJECT | Request `REJECTED`; step 1 `REJECTED`, step 2 `CANCELLED`. Independent reviewer receipt and minimal REVIEW audit retained. Original Roll, Student version 1 and Enrollment unchanged. No approval application, apply receipt or Roll-corrected outbox |
| Rejected at second step | P0/R0 → SUBMIT → first APPROVE → second REJECT | Stage one remains recorded `APPROVED`, second step `REJECTED`, request terminal `REJECTED`. Original R0, Student and Enrollment unchanged. No application, APPLY receipt or correction outbox; partial prior approval is not enough |

Both rejection paths further verify the reviewer’s **exact same-key replay**, and reject conflicting changed-payload reuse, new APPROVE after terminal REJECT, and authenticated APPLY after REJECT. The full test compares immutable review rows and receipts, private-person reviewer identities, minimized review audit details, and the unchanged original Roll/Student/Enrollment evidence *after* attempted invalid operations.

The accepted path verifies the genuinely authenticated original requester remains the separate APPLY actor and preserves R1→R0 `supersedes_id` linkage plus exact inherited `origin_allocation_id`, including a nullable original P0 origin; it does **not** invent a replacement origin ID.

## Exact-commit workflow evidence

| Gate | Result |
| --- | --- |
| [D1 static #39942086561](https://github.com/yunusyosaf399/edusync_saas_school_app/actions/runs/39942086561) | **SUCCESS** |
| [Foundation local PostgreSQL #39942086355](https://github.com/yunusyosaf399/edusync_saas_school_app/actions/runs/39942086355) | **SUCCESS** |
| [Full D1 disposable PostgreSQL #39942086313](https://github.com/yunusyosaf399/edusync_saas_school_app/actions/runs/39942086313) | **SUCCESS** |
| `92_db01_roll_correct_p1_apply.sql` | 113/113 |
| All D1 domain assertions | 3,686 |
| Foundation regression assertions | 220/220 |
| D1 runtime catalog | 34/34 RLS, 569 functions, 551 definers, 162 app, 407 private, `auth_private=0 anon=0 service_role=0` |
| Full runtime | `D1C2A_PASS`; 257 draft fragments applied only in disposable test database |

Required exact log markers: `D1_DB01_P1_FULL_SUBMIT_APPROVE_APPLY_INTEGRATION_PASS`, `D1_DB01_P1_FULL_SUBMIT_REJECT_STAGE1_INTEGRATION_PASS`, `D1_DB01_P1_FULL_SUBMIT_APPROVE_REJECT_STAGE2_INTEGRATION_PASS`, and `D1C2A_PASS`.

## Remain open

**DB01-10:** full downstream DB02 namespace/policy, DB03 Enrollment/Admissions and DB04 integration/stacked PR merge order. **DB01-11:** independent non-author security and integration review. **DB01-12:** merge and controlled production activation *only if explicitly authorized* and all earlier gates accepted. Do not infer that an earlier green disposable SQL run or this document enables any production operation.

**Evidence binding:** The above three successful workflows correspond to tested code commit `55e0422...`; future documentation-only commits have their own workflow state and do not replace this proof.
