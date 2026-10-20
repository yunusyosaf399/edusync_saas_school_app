# DB-01 — Private atomic Roll correction effect and allocator high-water gate

**20 October 2026.** DB-01-owned SQL implementation: [draft PR #118](https://github.com/yunusyosaf399/edusync_saas_school_app/pull/118), stacked on reviewed but unmerged [private source-prelock PR #117](https://github.com/yunusyosaf399/edusync_saas_school_app/pull/117), based on `main df1c98d5c2d19424946986fc6ba7615202b0a443`. This document belongs only to DB-01 contract [PR #100](https://github.com/yunusyosaf399/edusync_saas_school_app/pull/100); it does **not** approve DB-02 policy command implementation, other workstreams, activation, deployment or the final protected API.

## 1. Approved contract and restricted scope

Owner-approved RC-01/02/03/04/05/08 require exact present ACTIVE PRIMARY Enrollment and unsuperseded Roll; retained historical School-wide persistent numeric ownership; half-open DATE overlap for academic Class Offering; trusted server School-local DATE; School→policy→allocator→Student→academic history locking; append-only R0→R1, supersedes independent of persistent origin, and no same-day zero-length correction. PR #116 merged the historic collision and MOVE/END shared locking/date prerequisites, and PR #117 passed 20/20 local source-prelock assertions at `e1bc75ef80f25fa6c1d0ad5b36fea45f950c3f96`.

**New #118 SQL:** `effect41_02_db01_correct_effect.sql.draft` defines **one** private `app_private.d1_roll_correct_effect(actor,student,expected_student_version,enrollment,section,enrollment_from,roll,roll_from,stored_policy,old_numeric,new_numeric,reason)`. It is a **Student-executor-owned SECURITY DEFINER** with pinned `pg_catalog,pg_temp` search path, named Student and Workflow internal invocation only, and no PUBLIC/authenticated/anon/service_role EXECUTE.

Its preconditions require the authenticated actor to match `current_principal_id()`, 64-bit proposed numeric below overflow of allocator successor and no-op, nonempty bounded reason without silently normalizing exact reason bytes, and successful #117 locked source validation. Post-lock it:
- checks retained School-wide persistent numbers against every other Student's historical persistent allocation across revision boundaries (even superseded and closed rows), or academic overlapping DATE segments for the exact stored policy and Class Offering across all Sections;
- raises a high-water reservation of `next_value = selected + 1` only if the chosen number is not already below the allocator's next value; server triggers own M-row `row_version` and `updated_at`;
- closes R0's date/actor end boundary and inserts a distinct R1 for the same Student, Enrollment and policy, **with `supersedes_id=R0` but the original `origin_allocation_id` preserved separately**, exact restricted correction_reason and School-local new `effective_from`;
- uses the frozen server-owned Student M version trigger for one optimistic Student version increment. Any constraint, collision or effect error aborts and rolls back the entire transaction. No receipt or event is fabricated.

**Critical restriction:** The private effect **does NOT** check whether `student.roll.correct` is enabled or which P1 route currently authorizes the actor. This is deliberate: the future protected DIRECT/APPROVAL wrapper must independently require live ACS/role/Section scope, current P1 policy binding, approved reviewer/apply chain, canonical receipt/replay, School-local date alignment and historical disclosure *before calling the internal effect*. A trusted internal function call is not itself an authenticated authorized protected correction. It is never exposed as an `app` RPC. No candidate status changes an approved product rule.

## 2. Proposed exact function-inventory gate

| Measure | #117 composed baseline | #118 proposed |
|---|---:|---:|
| Total functions | 547 | **548** |
| SECURITY DEFINER functions | 529 | **530** |
| Private functions | 390 | **391** |
| Public `app` functions | 157 | **157** |
| Authenticated `app` EXECUTE | 157 | **157** |
| Authenticated private / anon / service_role EXECUTE | 0 / 0 / 0 | **0 / 0 / 0** |
| D1 FORCE RLS relations | 34 | **34** |

No table, schema, role, public function, Foundation migration, DB-02, Admissions, Curriculum or Finance edit. `student.roll.correct` remains disabled. Migration 10 remains non-executable `.sql.draft`. The strict static and runtime metrics are deliberately raised by **exactly one** private definer, not suppressed.

## 3. Acceptance and limitations

`supabase/tests/domain/82_db01_private_correct_effect.sql` has **21 rollback-only structural assertions**. Starting from actual authenticated P0 Student placement (not privileged forged Enrollment), it places a second Student under the same persistent namespace, tests rejected other-Student retained collision, no-op, below-policy, overflow, stale optimistic token, blank reason and mismatched Student; proves rejected attempts do not advance the allocator or append history. It then invokes the private effect as the trusted internal Student executor to check one appended Roll successor, unchanged `supersedes` vs origin lineage, School-local date, Student version increment, high-water reservation, restricted reason retention, no newly enabled operation and actual client EXECUTE denial. This is **not a positive authorized `student.roll.correct` RPC**.

**SQL PR #118 first submitted head:** `9d3d09354f06f00ef3321d134800acf7af7ed309`. Its D1 static, Foundation local and PostgreSQL runtime workflows were triggered at submission; **do not claim suite #82 passed until verifying all exact-head jobs and actual D1 #82 output.** The private function additionally needs an independent security code review, genuine two-PostgreSQL-backend CORRECT-vs-P0 allocator/MOVE/END races, academic-mode fixture, expired-policy source and permanent other-Student revised-policy cases, attempted rollback after late constraints, high-water overflow boundary, same-day second correction and multi-real-School-day acceptance. Existing #116 Enrollment wait proofs and #117 prelock tests do not replace these.

## 4. Further DB-01-owned sequence

Once #118 has genuine runtime acceptance, prioritize expanded mode/rollback/two-session collision tests. Then implement the protected P1 DIRECT wrapper and SUBMIT→REVIEW→APPLY and checked reader in independently gated stages, including Foundation receipts/audit/outbox, unauthorized denials, stale request invalidation, current display permission, single result/event and exact durable replay. Never enable an inactive domain operation, merge stacked PRs, or deploy from green local SQL alone.