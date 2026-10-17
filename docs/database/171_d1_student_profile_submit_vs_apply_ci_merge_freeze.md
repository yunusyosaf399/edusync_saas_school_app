# D1 Student Profile P1 SUBMIT versus approved APPLY — exact-head CI merge freeze

Date: 2026-10-17. **Verdict: local-only concurrency regression ACCEPTED / FROZEN for PR #77.** This is a test checkpoint, **not** activation or end-to-end acceptance of `student.profile.update`. Accepted protected operations remain **31/35**; four Student commands retain the disabled contract gates in reviews #152–#156. Full D1 remains OPEN.

## Verified immutable provenance

- [PR #77](https://github.com/yunusyosaf399/edusync_saas_school_app/pull/77) merged, independently rechecked `merged=true`.
- Previous frozen `main`: `541fa067e110236583f96aed0431c2a4fd40a1f2` (PR #76 freeze).
- Exact successfully tested PR HEAD: `4a5563af593f6e6e57affdd83cc7b90048412079`.
- SHA-guarded merge commit: `2f25cc088fcc018872c12649aef9dd1e51178155`; post-merge main independently matched this exact SHA.
- Exact-head pull-request [D1 local runtime #38996110178](https://github.com/yunusyosaf399/edusync_saas_school_app/actions/runs/38996110178), [Foundation #38996110350](https://github.com/yunusyosaf399/edusync_saas_school_app/actions/runs/38996110350), and [D1 draft static #38996110379](https://github.com/yunusyosaf399/edusync_saas_school_app/actions/runs/38996110379) all completed **SUCCESS**. Corresponding push-triggered runs also all succeeded at the same exact SHA.

## Observed independently authenticated concurrency

- `D1_STUDENT_PROFILE_SUBMIT_APPLY_FIRST_RACE_PASS`: the independently authorized reviewer applies a previously approved profile change while holding the Student row lock; the requester attempting a stale `SUBMIT` is blocked on an observed PostgreSQL `pg_blocking_pids` tuple/transactionid dependency, then rejected after the Student version advances. No stale request or submit receipt, no duplicate application, event, or profile effect.
- `D1_STUDENT_PROFILE_SUBMIT_SUBMIT_FIRST_RACE_PASS`: a genuine authenticated requester submits a fresh PENDING request while holding the same Student row lock; the independently authorized reviewer's already-approved `APPLY` waits on actual observed blocking, then applies once. The new request remains PENDING and pinned to its original target version. Neither action silently overwrites the other; both original intent keys have durable replay.
- Both orders check exact Student version, approved/pending/request state, receipts, applications, audit/outbox counts and payload minimization, with zero Student restricted Identity or Special writes. Neither competing protected operation uses privileged direct application-table mutation.
- D1 runtime log: **74/74 rollback-only SQL business suites / 3,124/3,124 pgTAP assertions**, Foundation post-D1 **220/220**, both new Student Profile race markers, `D1C2A_PASS`.
- Independent Foundation run: 9 frozen migrations, 9 Foundation tests, **220/220**, with local reset, authentication fixtures and lint passing. Draft-static: **228 inactive D1 draft fragments**, 34 D1 relations, 97 permissions, 322 scope alternatives, 36 operation contracts; 542 final SQL functions, no authenticated `app_private` function EXECUTE, no owner/signature drift.

## Precisely scoped merged diff and exclusions

Against the preceding frozen `main`, the merge introduces exactly:

1. `docs/database/170_d1_student_profile_p1_submit_vs_approved_apply_race_candidate.md`
2. `tools/supabase/domain_student_profile_submit_vs_apply_race_ci.py`
3. `tools/supabase/domain_concurrency_ci.py`
4. `tools/supabase/tests/test_domain_acceptance_ci.py`

No Foundation migration/test, executable migration, D1 SQL fragment, production role/grant/RLS, event contract, deployed Supabase project or student/customer data changed. The locally assembled Migration 10 stays **inactive `.sql.draft`** and deployment remains unauthorized.

## Protected operations still gated

Despite these successful *test-only* runs, the contract/activation gates are not silently satisfied:

- `student.profile.update` — decisions SP-01…SP-08 / reviewed activation still open; local typed path tests do not replace product sign-off.
- `student.roll.correct` — RC-01…RC-08 need frozen source/allocator/collision/history/approval/race semantics.
- `student.roll_policy.change` — RP-01…RP-07 need school-level temporal, allocator, authorization, evidence and event selections.
- `student.create` — SC-01…SC-07 and a separately installed/frozen Admissions final unused handoff are required.

Authoritative readiness package: `docs/database/152_d1_student_profile_update_p1_contract_readiness.md` through `155_d1_student_create_admissions_handoff_contract_readiness.md`, plus decision register `156_d1_four_student_operation_decision_register.json`. **No count beyond 31/35 may be claimed from this race-only PR.**

**Example:** An approved correction changes the Student version while another requester is preparing a new request. Only the application which obtained its lock in valid state may update the Student; a stale late submit is rejected, whereas an already committed pending proposal remains reviewable but is not silently applied.
