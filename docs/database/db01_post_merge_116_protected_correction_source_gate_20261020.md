# DB-01 — Post-#116 integration reconciliation and protected source-lock readiness

**Date:** 2026-10-20. **Owner:** DB-01 `student.roll.correct` workstream. **Status:** shared inactive prerequisites MERGED; DB-01 source-lock SQL proposed on **[draft PR #117](https://github.com/yunusyosaf399/edusync_saas_school_app/pull/117)**; protected correction RPCs **NOT IMPLEMENTED or enabled**. The product-owner approved DB-01 RC-01…08 in [the owner contract](db01_student_roll_correct_owner_approved_contract_20261019.md). This dated record **updates integration status**, not the prior approval's semantics.

## 1. What is actually merged and verified

At the 2026-10-20 check, `main` is **`df1c98d5c2d19424946986fc6ba7615202b0a443`**, the merge of [PR #116](https://github.com/yunusyosaf399/edusync_saas_school_app/pull/116) (PR head `a3cbeac9e9118a897a9c067e062b7097d4291474`). GitHub checks were **all green on that exact PR head**: D1 draft static, Foundation local stack, D1 local runtime, [D1 run 39386318464](https://github.com/yunusyosaf399/edusync_saas_school_app/actions/runs/39386318464). PR review states its independent AI technical reviewer identified and then verified the repaired P2 Student result-version binding; it expressly does not claim human GitHub account signoff or release approval. Existing issues #108/#110/#112 and the old stacked PR #107/#109/#111/#113 were **closed** after incorporation rather than individually merged; **do not merge those older stacks again**.

The composed inactive baseline contains **243 `.sql.draft` fragments**, frozen runtime **546 total functions / 528 definers / 157 public / 389 private**, all **34 D1 relations FORCE RLS**, zero authenticated-private/anon/service-role EXECUTE, 80 D1 suites **3,258 business assertions** and **22 actual observed two-backend lock waits**, according to merged PR's final test evidence. Foundation migrations 1–9 remain unchanged. No hosted deployment and no `student.roll.correct` or `student.roll_policy.change` activation.

| Former blocker | Integrated source | Current status and remaining limitation |
|---|---|---|
| Permanent persistent numeric ownership / source END lock-order | Effect37_01/02; #75/#76 | **Merged and tested**, source School→stored policy→source allocator before Student. Correction high-water and new-number collision are **still unimplemented**. |
| MOVE source+destination allocator union / APPROVAL/replay | Effect39_01–06; Enrollment local two-session fixtures | **Merged and tested**, including real protected MOVE, selected source/destination namespace lock ordering, independent reviewer and replay. Does **not** prove a future CORRECT-vs-MOVE race or authorize CORRECT itself. |
| Owner's School-local today-only cutovers | [Owner choices and dependency resolution](20261020_owner_choices_and_dependency_resolution.md) plus Effect40_01/02 | **Selected and partial shared resolver implemented.** Existing current policy reader, REENROLLMENT and END current-source checks call trusted `app_private.d1_roll_business_date(school uuid)`; date captured after the relevant lock waits. Explicit historical/future MOVE and PLACE dates continue their existing contracts; this is not a policy-change RPC. |
| DB-01 immutable result/receipt/approved application proof | Effect38_01–04 plus Effect40_03 | **Merged and tested** with #77–79: exact 12/14-key results, DIRECT receipt/audit/outbox binding, APPROVAL old/requested/receipt/source proof and exact predecessor Student/request versions. These are *private evidence verifiers and trigger*, **not protected mutations**. |
| DB-02 RP-01…07 product selections | [2026-10-20 owner-choice record](20261020_owner_choices_and_dependency_resolution.md) | The owner selected **today-only School-local** policy changes, retained historic numbers and school-wide DIRECT/independent APPROVAL. RP-06 literal result/event names `D1_STUDENT_ROLL_POLICY` / `student.roll_policy_changed` are **engineering selections delegated by the instruction to complete blocking work**, not personally spoken codes. DB-02 #101 remains a separate draft policy-command implementation workstream. |
| Review of integrated draft privileges | #116 independent AI technical review + CI | **Narrow technical review accepted** for the inactive package; additional privileged Roll CORRECT commands and client grants still need their **own** independent security approval and exact runtime acceptance. |

## 2. The next DB-01-owned implementation increment

**[PR #117](https://github.com/yunusyosaf399/edusync_saas_school_app/pull/117)** targets current `main` only and introduces a **non-activating, private**, Student-owned `SECURITY DEFINER`:

```sql
app_private.d1_roll_correct_lock_source(
  student uuid, expected_student_version bigint, enrollment uuid,
  section uuid, enrollment_from date, roll uuid, roll_from date,
  stored_policy uuid, old_numeric bigint
)
RETURNS TABLE(student_version bigint,school_id uuid,campus_id uuid,
 class_offering_id uuid,policy_mode text,allocator_id uuid,
 business_date date,error_code text)
```

The helper **does not itself authorize any actor**, read private history for a client, issue receipt or outbox evidence, increment counters, update/insert a Roll, or enable a command. It is a future **post-authentication/policy-route** transaction building block only, and returns fixed status codes rather than untrusted identifier values in errors.

**Lock-order and validation contract:**

1. Read source Section ancestry without locks; acquire the verified School anchor first; re-read ancestry, reject School/Class/Campus drift.
2. Acquire exactly the caller-stored source policy UUID under the same School, then the server-derived persistent-global or academic-Class Offering allocator row, **before Student**. Reject missing/ambiguous allocator rows and invalid policy mode. The source policy can be historically retained; do **not** silently switch to a new policy revision.
3. Compute trusted **School-local DATE** using the merged `d1_roll_business_date` after upstream waits, with no client date/timezone and no implicit UTC fallback.
4. Lock Student and verify current `ACTIVE` status and exact `row_version`, then lock academics, source Enrollment and source Roll. Require latest ACTIVE PRIMARY Enrollment in exactly the supplied Section/date, one open unsuperseded Roll under supplied stored policy/date/old number, source date strictly **earlier** than School-local date, and the stored policy still effective on that day.
5. This is a P1 source preflight only. Future wrapper must separately verify current individual Principal, live `student.roll.correct` permission/ACS, exactly one P1 DIRECT/APPROVAL policy and independent approved actors; valid new numeric/collisions/high-water, canonical receipt+event+audit and historical disclosure/replay are **NOT** proved by this helper.

**ACL:** owner `schoolos_student_executor`; private EXECUTE for named Student/Workflow internal executors only. No direct `PUBLIC`, `anon`, `authenticated` or `service_role` execute. Strict catalog delta to **547 functions / 529 definers / 157 public / 390 private**, all previous zero-privilege, table/index/RLS counters unchanged. No new table/role/membership.

**Acceptance:** new rollback-only local suite `81_db01_roll_correct_source_prelock.sql` supplies a real protected P0 Enrollment/Roll seed and checks **20** exact source, School/mode/pool/day, stale/malformed input, client-denial and no-mutation assertions. This is not CORRECT acceptance; observe the final *exact-head* CI and independent reviewer before claiming any runtime pass. Review School/policy/pool/Student wait ordering with genuine two-backend lock probes before enabling the future mutation.

## 3. Remaining hard engineering gates for actual `student.roll.correct`

**Not yet delivered:** typed public `app.d1_correct_student_roll`, `app.d1_submit_student_roll_correction`, `app.d1_review_student_roll_correction`, `app.d1_apply_student_roll_correction`, checked `app.d1_read_student_roll_correction_request`; exact P1 policy and current authorization, stable SHA-256 canonical intent/receipt creation, School-local Date in actual effect, transactional counter high-water/collision checks, append-only R0→R1, source request+application, stale invalidation and replay, privacy-safe outbox, historical disclosure after MOVE/END, genuine two-backend opposing CORRECT/MOVE/END races and multi-real-business-day acceptance. The DB-02 `student.roll_policy.change` command is a separate workstream and is still disabled.

The **correct next action** after PR #117 source-prelock review is to implement the **private authorized DIRECT correction effect with permanent-number/allocator high-water reservation in one transaction**, gated by a separate exact-function/ACL increment, and to test collision/overflow/rollback/concurrency before adding the public RPC. Do not bypass Foundation P1 or grant client access to private effect SQL.

**Release gate:** all Migration 10 fragments remain non-executable `.sql.draft`; do not merge PR #117 or enable/deploy CORRECT merely because local tests pass. Independent security/authorization and real concurrency evidence are required. Historical database information is not exposed until an exact checked reader is implemented.
