# DB01-07 — Real PostgreSQL P1 APPLY concurrency acceptance

**Engineering gate:** PASSED in disposable Supabase D1 on 2026-10-23.

**Exact tested source HEAD:** `3f7bfe1017c34009a3aa4dcdce9443fe990ef1ee`. Draft [PR #141](https://github.com/yunusyosaf399/edusync_saas_school_app/pull/141) remains unmerged, stacked on DB01-02 PR #139. All Migration 10 SQL remains `.sql.draft`; the protected Roll operation/permission stays disabled outside the ephemeral acceptance database. This is neither an independent security signoff nor release authorization.

## Why the race tests are genuine

The two Python drivers `tools/supabase/domain_db01_p1_apply_race_ci.py` and `tools/supabase/domain_db01_p1_apply_move_end_ci.py` use separate PostgreSQL backend connections and genuine `app.d1_submit_student_roll_correction`, `app.d1_review_student_roll_correction`, `app.d1_apply_student_roll_correction`, `app.d1_move_student_enrollment`, `app.d1_end_student_enrollment` and P0 placement commands. They use distinct bound authenticated database Principals and separate synthetic Student/policy identifiers. A waiter is considered proven blocked only when `pg_stat_activity`, `pg_blocking_pids` and `pg_locks` observe the actual winning backend before it commits. A fast failure or unobserved block fails the test. No fabricated review approval, private Roll effect call, or mock SQL output is counted as a pass.

## Contention matrix

| Winner / protected contender | Observed result | Proof marker |
| --- | --- | --- |
| REVIEW stage 1 / stale REVIEW | REVIEW contender waits, is rejected; one retained review receipt and audit | `D1_DB01_P1_REVIEW_REVIEW_REAL_PG_RACE_PASS` |
| Reviewer-grant revocation / REVIEW | Reviewer waits on Foundation shared/exclusive auth lock, grant revoked, read/review fails closed | `D1_DB01_P1_REVIEW_AUTH_REVOCATION_REAL_PG_RACE_PASS` |
| Final REVIEW / APPLY | Requester waits on pending review transaction, then approved APPLY creates one corrected Roll | `D1_DB01_P1_REVIEW_APPLY_REAL_PG_RACE_PASS` |
| APPLY / stale REVIEW | Reviewer waits on APPLY request-row lock and fails; no extra review evidence | `D1_DB01_P1_APPLY_REVIEW_REAL_PG_RACE_PASS` |
| APPLY / exact-key APPLY replay | Retry waits and returns same request version, Roll UUID, Student version and date; no duplicate application/receipt/audit/outbox | `D1_DB01_P1_APPLY_APPLY_REAL_PG_RACE_PASS` |
| APPLY / protected MOVE | MOVE waits, then fails stale; single R1/apply receipt/outbox | `D1_DB01_P1_APPLY_AM_REAL_PG_RACE_PASS` |
| Protected MOVE / APPLY | APPLY waits, then persists `INVALIDATED` with one rejected receipt/audit and no corrected Roll/application/outbox | `D1_DB01_P1_APPLY_MA_REAL_PG_RACE_PASS` |
| APPLY / protected END | END waits, then fails stale; one corrected R1/application | `D1_DB01_P1_APPLY_AE_REAL_PG_RACE_PASS` |
| Protected END / APPLY | APPLY waits, then persists terminal `INVALIDATED` with no Roll correction effect | `D1_DB01_P1_APPLY_EA_REAL_PG_RACE_PASS` |

**Separate route-denial proof:** `D1_DB01_P1_DIRECT_CORRECT_ROUTE_DENIED_PASS` verifies a Campus configured for APPROVAL cannot invoke protected DIRECT CORRECT. This is a *policy refusal*, not a DIRECT CORRECT lock contention. Competing P1 correction is instead validated as real APPLY/APPLY contention.

## Exact-head CI and safety

| Check | Result |
| --- | --- |
| [D1 Migration 10 static #39917904155](https://github.com/yunusyosaf399/edusync_saas_school_app/actions/runs/39917904155) | SUCCESS |
| [Foundation local-stack #39917904165](https://github.com/yunusyosaf399/edusync_saas_school_app/actions/runs/39917904165) | SUCCESS |
| [D1 full PostgreSQL #39917904195](https://github.com/yunusyosaf399/edusync_saas_school_app/actions/runs/39917904195) | SUCCESS |
| Genuine P1 SQL assertion suite | `113/113` |
| Domain SQL assertions | `3,686` |
| Foundation PostgreSQL assertions | `220/220` |
| Catalog integrity | `34/34` FORCE RLS; `569` D1 functions, `551` security definers; zero client private EXECUTE |
| Runtime finish marker | `D1C2A_PASS` |

## Residual gates

DB01-08 later corrected heads and policy/School business-date edges; DB01-09 complete accept/reject integration; DB01-10 downstream DB02/DB03/DB04 review; DB01-11 independent security evaluation; DB01-12 controlled merge/activation **only after explicit user production authorization**. No external hosted Supabase mutation, production enablement or merge is implied.
