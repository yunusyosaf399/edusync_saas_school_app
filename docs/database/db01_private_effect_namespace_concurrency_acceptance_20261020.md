# DB-01 — Post-effect namespace and genuine two-session race acceptance

**Date:** 2026-10-20. **DB-01 only, non-activating test integration.** SQL effect [draft PR #118](https://github.com/yunusyosaf399/edusync_saas_school_app/pull/118), source prelock [draft PR #117](https://github.com/yunusyosaf399/edusync_saas_school_app/pull/117). This acceptance extension is [stacked draft PR #119](https://github.com/yunusyosaf399/edusync_saas_school_app/pull/119). No DB-02, Admissions, Curriculum, Finance or Foundation modifications; no SQL schema or function inventory delta; `student.roll.correct` disabled and Migration 10 non-executable.

## 1. Prior validated baseline

PR #118 at `9d3d09354f06f00ef3321d134800acf7af7ed309` passed three workflows on [D1 runtime #39395373321](https://github.com/yunusyosaf399/edusync_saas_school_app/actions/runs/39395373321): suite #81 **20/20**, suite #82 **21/21**, **3,299 total D1 business assertions**, exact 245 draft SQL fragments, 548 D1 functions, 530 SECURITY DEFINER, 157 public, 391 private, zero authenticated-private/anon/service-role execute. This is an INTERNAL SQL rehearsal and does not prove authorized `student.roll.correct`.

## 2. PR #119 testing additions (no function catalog or permissions changed)

**Observed real two-backend races:** `tools/supabase/domain_db01_roll_correct_race_ci.py` is run by `tools/supabase/domain_local_ci.py` after the existing domain suites. A protected authenticated `app.d1_place_student_enrollment` creates the actual source Enrollment/Roll. Every private Roll correction uses a trusted internal `schoolos_student_executor` connection with the frozen verified test actor, not a public CORRECT command. Independent PostgreSQL connections exercise:

- School, **stored** Policy and Allocator rows locked separately by a privileged test blocker, each with both COMMIT and ROLLBACK holder releases. Six actual waits must be observed with `pg_stat_activity`, `pg_blocking_pids` and an unresolved tuple/transactionid lock; before upstream release another connection must NOWAIT-lock the Student row successfully. No sleep-only inferred blocking.
- In reverse arrival, an uncommitted private effect must hold exactly School, Policy, Pool and Student rows against NOWAIT opponents. Its ROLLBACK must leave a single original Roll, original Student version, original allocator highwater and zero CORRECT receipts.
- A committed successful internal effect on 12001→12009 races a second stale attempt to select 12010. The second connection must **actually wait** for the first transaction, then fail on stale source/version after commit. Exactly one successor, preserved original, Student version 2, high-water 12010 and zero fabricated CORRECT receipts are required. This is 7 observed waits plus 4 reverse NOWAIT conflicts, not authenticated P1 CORRECT acceptance.

**Academic namespace fixture:** `83_db01_academic_cross_section_correct_effect.sql` (22 rollback-only assertions) uses genuine P0 placements for separate Students in distinct Sections of one Class Offering under `ACADEMIC_CONTEXT`. It rejects a correction into the other Section's overlapping number, retains source/history on denials, and verifies the allowed number/highwater/Student version under the academic Class Offering namespace.

**Retained permanent history across revisions:** `84_db01_persistent_cross_revision_roll_correction.sql` (12 rollback-only assertions) uses an old retained 12001 owned by Student A under revision 1, a test-owned current revision 2 with a different allocator and Student B's genuine P0 number 13001. Student B's attempt to select retired-policy Student A's permanent 12001 must be rejected even if below the new allocator high-water. A permitted 13009 corrects B, advances **only** revision 2 high-water, retains original old A number and its revision-1 allocator, and never enables the command.

## 2.1 Runtime fixture correction before any acceptance claim

The first #119 runtime attempted to inline the shared `fixtures/command_actor.sql` again after prior domain concurrency tests had already **committed the same Foundation Principal IDs** into the disposable stack; PostgreSQL raised `23505 duplicate key principals_pkey` during **test setup**, before any DB-01 new lock proof ran. That run is explicitly **FAIL**, not an effect/lock-order failure and not proof of a pass. The real race runner now reuses the already committed shared Principal/Role, initializes only the per-transaction JWT via `settings_sql()`, and seeds fresh DB-01 Student/Enrollment/Roll rows through the genuine authenticated P0 command. The correction is commit `53e58176886c13e26a3b647852a6969ce0e66465`. A fresh exact-head D1 runtime must prove all wait/collision assertions independently before claiming acceptance.

## 2.2 Test-schema isolation correction

After the preceding failure was repaired, the race setup encountered another already-committed test UUID (`role_permission_grants_pkey`). This is **not** an application collision; the D1 disposable runtime intentionally runs prior concurrent fixtures that commit shared Foundation records. The final race setup therefore reuses the existing JWT Principal and test Role **without re-inserting them**, but rewrites **all** DB-01 test fixture object IDs (Student, campus, year, class, Section, policy, pool, scoped grant and evidence fixture UUIDs) into the dedicated `db190000` namespace. It also creates a fresh test-owned School Profile `db190000-0000-4000-8000-0000000000ee`, isolating Roll policy date ranges from previous committed Enrollment race fixtures. This test-only change is commit `c9d18807ce1ee3773d282a1a0b7fdc7257e783bd`.

The failed prior run is **not accepted**. The isolated setup must still prove genuine protected P0 placement before any unprotected internal Roll correction race is attempted. No source/effect SQL, Foundation grants, client permissions or D1 catalog counts were changed.

## 3. Truthful acceptance boundary

**Initial SQL CI state:** the baseline PR #118 is GREEN; new #119 source/test diffs trigger fresh static, Foundation and D1 local runtime jobs on each exact HEAD. **Do not claim any #83/#84 or 7-wait result until the corresponding exact-head logs demonstrate it.** The test suite and real-race runner must be maintained together; any failure requires a code/fixture correction and a new exact-head run.

**Not covered:** genuine current privileged user-facing P1 `DIRECT/SUBMIT/REVIEW/APPLY` with durable receipts/audit/outbox, CORRECT-vs-authenticated protected MOVE or END, CORRECT-vs-concurrent automatic P0 in another Student's same namespace, live re-authorization and historical disclosure/replay, real School-local midnight crossings with differing timezones, SQL effect collision injected after later DML and rollback. Those are independently required future acceptance. In particular, **existing #116 Enrollment waits** and private-effect waits do not establish protected CORRECT operation safety or review approval.

**Release gate:** PRs #117/#118/#119 remain draft/unmerged, independent SQL security/concurrency code review required, operation disabled, no hosted migration or database deployment.