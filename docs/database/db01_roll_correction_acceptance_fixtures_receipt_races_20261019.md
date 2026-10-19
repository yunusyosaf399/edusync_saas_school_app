# DB-01 — Acceptance fixtures, receipt-provenance predicates and two-session PostgreSQL race gate

**2026-10-19. STATUS: DESIGN ONLY / RC AND RP OWNER DECISIONS PENDING.** Workstream: `student.roll.correct`, PR [#100](https://github.com/yunusyosaf399/edusync_saas_school_app/pull/100), branch `db/db-01-student-roll-correction-design`. Audited `main f38c087b989328f0c871b8ec5707e46ba12a856f`; starting DB-01 branch `5205e087187efb7607b25489cf5959fe55849997`. DB-02 external PR #101 latest inspected head `e71b2f3778811be2fa2aa6668158199cbd764c12`; its new policy-transition readiness document is **not** product approval.

**Purpose:** provide future SQL implementers/test owners with *reproducible fixture contracts, forensic SELECT assertions, negative and concurrency expected outcomes, and precise observation/evidence gates*. **None of these tests have been run; this is not a SQL suite, runnable Migration 10 fragment, authorization to enable an operation, or CI success report.** Keep DB-02/03/04, shared allocator, Foundation, existing tests and CI untouched. All RC-01…RC-08 and relevant RP-02/03/07 decisions are **not approved**.

## 1. Exact sources and boundary of authority

Read [AGENTS.md](../../AGENTS.md), master v0.2, approved decisions, [readiness #153](153_d1_student_roll_correct_p1_contract_readiness.md), [physical #27](27_domain_package_01_physical_catalog.md), [locking #31](31_domain_package_01_concurrency_and_locking.md), [indexes #32](32_domain_package_01_index_review.md), [privacy/command #09](../security/09_domain_checked_reads_and_commands.md), DB-01 [API/receipt gate](db01_roll_correction_p1_api_receipt_stale_apply_gate_20261019.md), [transaction gate](db01_roll_correction_transaction_readiness_20261019.md), [compatibility gate](db01_roll_correction_compatibility_gate_20261019.md). The DB-02 [allocator integrity](https://github.com/yunusyosaf399/edusync_saas_school_app/blob/db/db-02-roll-policy-design/docs/database/db02_allocator_namespace_integrity_gate_20261019.md) and current policy-transition review are dependencies only.

**Actual test precedent:**
- `supabase/tests/domain/fixtures/command_actor.sql`: synthetic Principal/Person/School, verified JWT subject, roles, bootstrap catalog; School's fixture timezone is UTC.
- `supabase/tests/domain/61_student_enrollment_place_p0_initial_roll.sql`: 18 documented pgTAP assertions, transaction-rollback fixture; genuine `app.d1_place_student_enrollment` creates PRIMARY Enrollment/Roll.
- `supabase/tests/domain/62_student_enrollment_end_p1_direct_history.sql`: 28 planned assertions, performs authenticated P0 placement followed by protected P1 END, rollback-only.
- `supabase/tests/domain/63_student_enrollment_move_p1_direct_section_history.sql`: genuine P0-created #12001 source and authenticated Section A→B MOVE; no owner-fixture direct successful Roll insertion; published review [#149](149_d1_student_enrollment_move_p1_direct_section_acceptance_review.md) is historical acceptance for **MOVE**, not correction.
- `supabase/tests/domain/65_remaining_student_commands_fail_closed.sql`: 38 documented fail-closed assertions including disabled `student.roll.correct`; protect its correction-specific assertions until an *independently approved* activation gate. Other operations' evolving status must be rechecked against latest main rather than blindly assuming this old suite is still the release definition.
- `tools/supabase/domain_concurrency_ci.py`: local-only two-process `psql` worker precedent; it observes lock waits and captures committed outcomes. Use independent verified backend PIDs, not a single session or sleep-only pseudo-races.

**Exact table/source evidence:**
- Base inactive `supabase/migrations/20260928000000_domain_package_01.sql.draft` defines `app_private.roll_policy_revisions`, `roll_allocator_states`, `roll_allocations`, `students`, `enrollments`, and registers non-family-safe ACS permissions and disabled correction.
- Frozen Foundation `supabase/migrations/20260924122446_foundation_rbac_workflow.sql` defines `approval_requests` (`id,operation_id,payload_schema_version,policy_id,requester_id,campus_id,target_ref,expected_target_version,reason,old_snapshot,requested_payload,state,row_version`), `approval_request_steps`, `approval_step_reviewers`, `approval_reviews`. `approval_reviews.step_id` is unique; review assignments are immutable for a committed decision.
- Frozen Foundation `supabase/migrations/20260924122448_foundation_receipts_events_settings.sql`: `command_receipts` uniqueness **(principal_id,operation_id,idempotency_key)**, `canonical_payload_hash`, `command_kind`, `result_kind`, `result_ref`, `result_summary`, `expected_target_version`, `request_id`, `state`; `approval_applications` uniqueness **(request_id)** and **(command_receipt_id)**, and compound receipt chain FK; `approval_transitions` uniqueness `(request_id,sequence_number)`; `outbox_events` uniqueness **(command_receipt_id,event_ordinal)**; `audit_events.command_receipt_id` and `outbox_events.command_receipt_id` link evidence. These are *storage facts*, not proof by themselves that an arbitrary correction result matches its approved proposal.
- The final auto-placement Roll allocator is `effect35_15_enrollment_place_allocator_server_version.sql.draft::app_private.d1_enrollment_place_allocate_roll`; it excludes superseded cross-Student persistent historical rows in **candidate selection**, unlike final `effect30_32_crossrow_campus_local_rename.sql.draft::app_private.d1_guard_crossrow`, which checks all historic School persistent allocations. **No committed duplicate has been demonstrated**; candidate/guard disagreement is a real source-level risk.
- Final `effect30_33_qualification_experience_lineage_guard.sql.draft::app_private.d1_guard_effective_history` BEFORE Roll INSERT/UPDATE requires School→source policy→source allocator→Student. Final MOVE DIRECT/APPLY (`effect26_05`, `effect26_09`) prelock destination but not proven historical **source** allocator; final END (`effect27_07`, `effect27_02`) locks Student before Roll trigger requests source locks. **Not declared deadlock-free** pending integration repair and witnessed tests.
- `effect27_02_enrollment_end_context_effect`, `effect27_03_enrollment_end_evidence`, `effect27_05_enrollment_end_review`, final `effect27_07_enrollment_end_hardening` establish the accepted P1 typed canonical-receipt/approval/checked-read/application guard pattern for END. DB-01 may copy its domain-specific *contract*, not edit Foundation or assume END's success tests prove correction.

## 2. Reproducible fixture taxonomy (no invented authenticated success)

Every fixture is created under a **disposable local PostgreSQL database**, by a privileged setup role only for **School, policies, Student, identity, roles, grants and class/capacity scaffolding**. Actual Enrollment/Roll *success* comes from existing authenticated `app.d1_place_student_enrollment`; after owner approval, corrected allocations must come **only** from the new protected DB-01 RPC. An owner INSERT into `roll_allocations` may be used to check isolated structural defenses, but **cannot** be called a successful DIRECT/APPROVAL acceptance case.

| Fixture | Exactly required state and setup | Test contract |
|---|---|---|
| **F00 Actor/auth** | Reuse `fixtures/command_actor.sql` for isolated single-transaction tests, with active INDIVIDUAL verified Principal P1 and Person X, role assignment, valid JWT; add independent P2/Person Y and P3/Person X (separate Principal same Person) to prove self-review rejection. | No FAMILY or SYSTEM shortcut, no spoofed `actor_id`. Current-role authenticated RPC only; forensic SELECT by *separate trusted observer/harness connection*, never client privilege. |
| **F01 School/source** | School S in UTC for fixture; Campus A, Academic Year Y, Academic Class C, Class Offering O1, Section A1 and second Section A2, both valid capacities and effective rules. Student A unique Person/admission identity and ACTIVE status; P0 placement creates E1/R0 with `placement_kind=PRIMARY`, `placement_state=ACTIVE`, `effective_from = CURRENT_DATE-20`, source Roll `numeric_value=12001`. | R0/E1 persisted from genuine authenticated P0, not raw SQL. Campus/Section path checked, source `effective_from <` candidate correction date. |
| **F02 Different Student** | Student B distinct Person, same School; eligible Section A2 and P0 success Eb/Rb with B's own roll. Use a fresh candidate 12009/12077 unowned initially. | Cross-Student persistent School-wide ownership and academic same-Offering overlap. |
| **F03 Persistent revision** | r1 `mode=PERSISTENT_STUDENT`, `start_value <= 12001`, effective before E1 and expected correction day; allocator row `(r1,NULL)` exists, server-owned `next_value` after P0. Retained policy other than r1 optional for RP tests. | Correction uses source r1; compare high-water before/after and existing other-Student owner set. |
| **F04 Academic mode** | Separate isolated fixture rAC `mode=ACADEMIC_CONTEXT` and two Class Offerings O1 and O2 with unique `(rAC,O*)` allocator rows and distinct Sections. | Same numeric may coexist across distinct Offering/revision per frozen physical namespace; same Offering/overlapping effective intervals denies. Do not invent a permanent academic reuse promise. |
| **F05 DIRECT route** | Transaction-local enable of **only needed** correction operation/permission/supported ACS grants **after contract approval**, exactly one effective P1 DIRECT policy for source Campus; no second effective conflicting School policy. Verified individual actor has relevant ALL, CAMPUS, CLASS or SECTION grant. | Under today's repository implementation the operation is disabled and this fixture cannot produce a correction; therefore all future positive steps are **planned**, not runnable/passing today. |
| **F06 APPROVAL route** | Exactly one active P1 APPROVAL policy, one or more configured step templates (each `required_reviews=1`), reviewer assignment reason `D1_REVIEWER_ROLE_SCOPE`, P2 Person Y with `student.roll.approve` and live Section-aligned reviewer role; P3 same Person X as requester but different Principal for negative case. | Submit no effect, REVIEW APPROVE no effect, explicit APPLY effects once; wrong route/role/step/same-Person fails. |
| **F07 Policy replacement** | r1 closed by later r2 at a date after E1/R0 start, School still has E1/R0 open; successor R1 retaining r1 would start outside r1 interval. | Under proposed RC-03 `D1_ROLL_CORRECT_POLICY_OUT_OF_INTERVAL` deny; RP-02/03 policy ownership and cutover must be approved before a runnable policy-replacement race. |
| **F08 Historic corrected source** | R0→R1 successful on day D1, later R1→R2 on D2 and R2→R3 on D3; legitimate MOVE on D4 closes E1/R3, creates E2/R4 carrying latest corrected persistent numeric and `origin_allocation_id=R3`. | Requires **separate real server business days or an explicitly approved trusted test-clock facility**. A single-day CI suite cannot produce all three using current-date-only DATE intervals without unsafe backdating or fabricated successful mutations. |
| **F09 Revoked authority** | Valid APPROVED request originally reviewed by P2, then authenticated Foundation grant/role/scope revocation commits before APPLY; separate actor-revocation and reviewer-revocation fixtures. | New apply deterministic INVALIDATED only if the caller is still a valid participant who may perform apply; unauthorized caller denied, not allowed to invalidate another person's request. |
| **F10 Replay after close** | Original successful DIRECT or approved APPLY receipt for R0→R1; then later legal CORRECT, MOVE or END; keep original receipt/result and R0/R1 retained. | One historical acknowledgement, no second correction/receipt/event; disclosure checked against current eligible participant and approved original/current Student context. |
| **F11 Two-pool MOVE** | E1/R0 uses historical policy r1 / allocator A1; destination E2 will use r2 / allocator A2 or distinct Offering. | Source+destination policy/allocator union sorted before Student; current MOVE prelock only destination may be insufficient. Do **not** claim race PASS until integration owner fixes/verifies shared prelock graph. |

**Setup/test separation:** Single-session pgTAP can use `BEGIN; ... \set ... SET ROLE authenticated; ... SET CONSTRAINTS ALL IMMEDIATE; ROLLBACK;` in an isolated test DB. For **two-backend races**, separate sessions must be able to see each other's committed fixture rows; use a disposable test DB with fixture setup **COMMITTED** and a deterministic cleanup/reset after tests, not a never-committed setup transaction invisible to Sessions A and B. Test artifacts must not escape to hosted environments. Any deliberate `SET ROLE schoolos_schema_owner` is a *fixture/observer activity*, never proof of client authorization.

## 3. Explicit response/evidence model and immutable proof variables

Use API gate's proposed DIRECT signature, P1 review/submit/apply/read names, and its **12-key exact successful base result** pending RC-07. For examples bind:
`S` School, `A` Student A UUID, `E1` Enrollment UUID, `R0` source Roll UUID, `R1` corrected Roll UUID, `P` exact source roll policy UUID, `X` verified requesting Principal, `V` source Student row_version, `D0` source Roll start, `DC` server actual correction date, `N0` old numeric, `N1` corrected numeric, `C` command receipt UUID, `O` operation UUID, `Q` approval request UUID, `AC` apply receipt UUID, `EV` correction outbox UUID.

Expected evidence is **one** successful `command_receipts` row per accepted DIRECT or reviewed APPLY with `state=SUCCEEDED`, `result_kind=D1_STUDENT_ROLL_CORRECT` (candidate), and `result_ref=R1`. DIRECT has `request_id IS NULL`; APPLY has `request_id=Q`. At most one accepted correction outbox `event_type='enrollment.roll_corrected'` at `(C, event_ordinal=1)`, one allowlisted correction success audit, and for APPLY exactly one `approval_applications` binding Q/C/R1/Student version. **The exact audit event type/aggregate kind/return disclosure are proposed, not frozen.** No number or free-text reason in broadly consumed correction outbox/audit `details`.

### 3.1 Forensic SQL predicates — templates only, never authenticated direct reads

The snippets below are **observer-only parameterized assertion shapes**, not `app` RPCs, not migrations, and not SQL to run against customer data. Replace `:'...'::uuid` and `:'...'::bigint` psql bindings with actual test outputs; do not infer IDs from displayed roll numbers. Observer must have explicit fixture/forensics authorization; `SET ROLE authenticated` must *fail* to query these `app_private` relations.

**A. Named source/Enrollment/successor equality (the immutable historical proof):**
```sql
SELECT count(*) AS exact_pair_count
FROM app_private.roll_allocations src
JOIN app_private.roll_allocations dst
  ON dst.supersedes_id=src.id
 AND dst.enrollment_id=src.enrollment_id
 AND dst.student_id=src.student_id
 AND dst.policy_revision_id=src.policy_revision_id
JOIN app_private.enrollments e
  ON e.id=src.enrollment_id AND e.student_id=src.student_id
WHERE src.id=:'r0'::uuid AND dst.id=:'r1'::uuid
  AND e.id=:'e1'::uuid AND src.student_id=:'student'::uuid
  AND e.section_offering_id=:'source_section'::uuid
  AND e.effective_from=:'enrollment_start'::date
  AND e.placement_kind='PRIMARY'
  AND src.policy_revision_id=:'policy'::uuid
  AND src.numeric_value=:'old_number'::bigint
  AND dst.numeric_value=:'new_number'::bigint
  AND dst.numeric_value<>src.numeric_value
  AND src.effective_from=:'source_start'::date
  AND src.effective_until=:'correction_date'::date
  AND dst.effective_from=src.effective_until
  AND src.ended_at IS NOT NULL AND src.ended_by IS NOT NULL
  AND dst.correction_reason IS NOT NULL
  AND length(btrim(dst.correction_reason))>0
  AND dst.origin_allocation_id IS NOT DISTINCT FROM src.origin_allocation_id;
-- Proposed expected = 1, pending RC-04.
-- Deliberately no assertion e.placement_state='ACTIVE', e.effective_until IS NULL,
-- dst.effective_until IS NULL, or dst has no later superseding row.
```

**B. No fork, exactly one new row; historic data retained:**
```sql
SELECT count(*) AS source_successors
FROM app_private.roll_allocations
WHERE supersedes_id=:'r0'::uuid;
-- expected = 1 after successful correction; = 0 after any denied/rolled-back attempt
SELECT count(*) AS enrollment_roll_rows
FROM app_private.roll_allocations
WHERE enrollment_id=:'e1'::uuid AND student_id=:'student'::uuid;
-- expected = 2 for one correction prior to MOVE, increment 1 per later correction
SELECT count(*) AS same_student_across_source
FROM app_private.roll_allocations r
WHERE r.id IN (:'r0'::uuid,:'r1'::uuid) AND r.student_id=:'student'::uuid;
-- expected = 2
```
The complete before/after forensic snapshot must assert **unchanged** `src.id,student_id,enrollment_id,policy_revision_id,numeric_value,effective_from,origin_allocation_id,supersedes_id,created_by,created_at` and exactly one allowed source close `effective_until,ended_at,ended_by`. Snapshot `roll_allocator_states.next_value,row_version,updated_at` separately to prove counter monotonicity and trigger-owned version.

**C. One exact successful receipt bound to the new Roll; strict 12-key summary:**
```sql
SELECT count(*) AS receipt_provenance_count
FROM app_private.command_receipts c
JOIN app_private.operation_contracts op ON op.id=c.operation_id
JOIN app_private.roll_allocations dst ON dst.id=c.result_ref
WHERE c.id=:'receipt'::uuid AND op.code='student.roll.correct'
  AND c.principal_id=:'actor'::uuid
  AND c.idempotency_key=:'key'
  AND c.state='SUCCEEDED'
  AND c.result_kind='D1_STUDENT_ROLL_CORRECT'  -- candidate RC-07
  AND c.result_ref=:'r1'::uuid
  AND c.canonicalization_version=1
  AND octet_length(c.canonical_payload_hash)=32
  AND c.result_summary IS NOT NULL
  AND jsonb_typeof(c.result_summary)='object'
  AND (SELECT count(*) FROM jsonb_object_keys(c.result_summary))=12
  AND c.result_summary ?& ARRAY[
    'student_id','enrollment_id','source_roll_allocation_id',
    'corrected_roll_allocation_id','source_policy_revision_id',
    'old_numeric_value','new_numeric_value','source_roll_effective_from',
    'correction_effective_from','student_version','section_offering_id',
    'source_enrollment_effective_from']
  AND (c.result_summary->>'student_id')=:'student'
  AND (c.result_summary->>'source_roll_allocation_id')=:'r0'
  AND (c.result_summary->>'corrected_roll_allocation_id')=:'r1'
  AND (c.result_summary->>'source_policy_revision_id')=:'policy'
  AND (c.result_summary->>'old_numeric_value')=:'old_number'
  AND (c.result_summary->>'new_numeric_value')=:'new_number'
  AND (c.result_summary->>'correction_effective_from')=:'correction_date';
-- expected = 1; typed parse and remaining fields are checked by the
-- private d1_roll_correct_result_rows_match_exact helper after approval.
-- 'receipt exists' alone is INSUFFICIENT provenance proof.
```
The hash verifier must recompute the **exact 11-slot caller-intent array** using the stored/caller typed values plus the operation/principal/key envelope, and compare to `canonical_payload_hash` using the existing `d1_jcs_typed` function, not merely require a nonempty 32-byte field. The restricted `dst.correction_reason` must equal the original DIRECT intent reason or approved `approval_requests.reason` under a signed normalization rule; this is **not** copied into broad result/audit/outbox. The D1 helper and schema-owner application trigger need an independent receipt/result ownership check: unique receipt key does *not* prove a Result UUID is used by only one distinct success receipt.

**D. Audit/outbox once, no broad numeric/private reason:**
```sql
SELECT count(*) FROM app_private.outbox_events ev
WHERE ev.command_receipt_id=:'receipt'::uuid
 AND ev.event_ordinal=1 AND ev.event_type='enrollment.roll_corrected';
-- expected = 1 on success; 0 on DIRECT denial, INVALIDATED apply, rollback
SELECT count(*) FROM app_private.audit_events a
WHERE a.command_receipt_id=:'receipt'::uuid
 AND a.actor_id=:'actor'::uuid
 AND a.outcome='SUCCEEDED';
-- expected = 1 on accepted correction; audit event_type/phase literal pending RC-07.
SELECT count(*) FROM app_private.outbox_events ev
WHERE ev.command_receipt_id=:'receipt'::uuid
 AND (ev.payload ?| ARRAY[
   'old_numeric_value','new_numeric_value','numeric_value','correction_reason',
   'reason','requested_payload','old_snapshot']);
-- expected = 0
SELECT count(*) FROM app_private.audit_events a
WHERE a.command_receipt_id=:'receipt'::uuid
 AND (a.details ?| ARRAY[
   'old_numeric_value','new_numeric_value','numeric_value','correction_reason',
   'reason','requested_payload','old_snapshot']);
-- expected = 0; independently audit nested payload minimization if fields evolve.
```

**E. Approved apply chain and rejected stale chain:**
```sql
SELECT count(*) AS applied_once
FROM app_private.approval_applications x
JOIN app_private.approval_requests q
 ON q.id=x.request_id AND q.operation_id=x.operation_id
JOIN app_private.command_receipts r
 ON r.id=x.command_receipt_id AND r.operation_id=x.operation_id
 AND r.request_id=q.id
WHERE q.id=:'request'::uuid AND q.state='EXECUTED'
 AND q.target_ref=:'student'::uuid
 AND x.applied_target_version=q.expected_target_version
 AND r.command_kind='request.apply' AND r.state='SUCCEEDED'
 AND r.result_ref=x.result_ref AND x.result_ref=:'r1'::uuid
 AND r.result_kind='D1_STUDENT_ROLL_CORRECT'
 AND r.result_summary->>'state'='EXECUTED'
 AND (r.result_summary->>'request_version')::bigint=q.row_version;
-- expected = 1; ALSO check exact approved source snapshot/number/reason
-- against retained R0/R1 and 12-key base summary. Without this, misbinding possible.

SELECT count(*) AS invalidations
FROM app_private.approval_transitions t
JOIN app_private.command_receipts c ON c.id=t.command_receipt_id
WHERE t.request_id=:'request'::uuid
 AND t.from_state='APPROVED' AND t.to_state='INVALIDATED'
 AND c.command_kind='request.apply' AND c.state='REJECTED'
 AND c.result_ref IS NULL AND c.error_code IS NOT NULL
 AND c.result_summary->>'state'='INVALIDATED';
-- expected = 1 for deterministic stale, = 0 for committed success or SQL rollback
SELECT count(*) FROM app_private.approval_applications
WHERE request_id=:'request'::uuid;
-- expected = 0 for INVALIDATED; = 1 for EXECUTED
```

**F. Persistent historical owner predicate (forensic, no supersession filter):**
```sql
SELECT count(DISTINCT r.student_id) AS distinct_owners
FROM app_private.roll_allocations r
JOIN app_private.roll_policy_revisions p ON p.id=r.policy_revision_id
WHERE p.school_id=:'school'::uuid
 AND p.mode='PERSISTENT_STUDENT'
 AND r.numeric_value=:'historic_number'::bigint;
-- Recommended invariant: all retained claims for any persistent numeric in one
-- School have at most ONE Student owner. Do not filter r.supersedes_id,
-- r.effective_until or latest-current descendant; signed RP-03/RC-02 required.
```
For A 12001→12009, B's automatic allocator after a revision reset must **skip 12001** rather than pass candidate 12001 to an eventually rejecting guard. The final `effect35_15` is not yet aligned: this is **red/blocked coverage** until integration owner changes it.

## 4. Exact test-case matrix (proposed assertions, not executed)

| ID | Fixture and protected action | Result/evidence obligation |
|---|---|---|
| **A01** | F01+F03+F05, DIRECT change R0 #12001→#12009 | New R1 UUID, same E1/Student/policy; R0 exclusive close, R1 starts today; one receipt/audit/outbox, no Enrollment or Student row mutation; exact A–D forensic predicates. |
| **A02** | Same key + exact intent twice, second call after first committed | Same R1/result; no extra Roll/counter version/receipt/outbox/audit; receipt hash is recomputed and matches, different key may only perform a *new* permitted correction. |
| **A03** | Same key, changed proposed number, source Roll ID, reason, Student expected version, or command kind | Idempotency conflict, original immutable result unaffected; no new receipt/event. |
| **A04** | Wrong Roll source, Enrollment, Student, source Section/date, policy revision, old number or version | Typed stale denial; no domain/evidence success and no unintended information disclosure. |
| **A05** | No-op requested equals source numeric; negative, fractional transport, overflow, too-short key or blank reason | Deny; `bigint` transport validation and exact canonical array length/field count. |
| **A06** | Manual requested #12009 beyond allocator `next_value`; then authenticated P0 issue | Reserve `next_value>=12010` atomically, P0 does not reissue #12009, M-row version trigger owns version. Rollback of failed correction restores counter. |
| **A07** | B requests R0's corrected-away #12001 after A's success; r1→r2 persistent revision | B denied; B P0 allocator *skips* retained historic number; no signed owner re-use. **Integration/DB-02 dependent; not runnable now.** |
| **A08** | Academic F04: two Sections of same Offering, overlapping same number; different Offering/revision | Same namespace overlap denied; distinct physical namespace coexistence permitted by current guard, subject to RC-02 owner decision. |
| **A09** | F07 stored source r1 expired before apply date; source Roll still open | No implicit r2 rewrite. Proposed policy-out-of-interval DIRECT deny / APPROVED apply INVALIDATED, pending RC-03 + RP-02. |
| **A10** | SOURCE Roll `effective_from=CURRENT_DATE`; try same-day correction | Deny zero-length DATE interval; do not silently switch to timestamp or backdate. |
| **A11** | Correct R0→R1 then legitimate Section MOVE of E1→E2/R2 on later valid date | E1/R0/R1 retained, R1 closed, E2 new Roll origin=R1 latest persistent head; replay original returns R1 without touching E2. |
| **A12** | Correct R0→R1 then END E1 on later valid date | END closes latest R1/E1; R0/R1 receipt still proves historical correction; original replay permitted only under signed current disclosure. |
| **A13** | F08 three successive corrections across three actual business dates then MOVE | R0→R1→R2→R3 exact linear `supersedes`, next MOVE R4 `origin=R3`; no same-day artificial success. **Requires approved clock/multi-day integration solution.** |
| **A14** | F06 SUBMIT APPROVAL | PENDING request with immutable old snapshot, requested numeric, separate restricted reason, initial OPEN step and one submit receipt; zero Roll/counter/application/correction outbox changes. |
| **A15** | Different Person P2 REVIEW APPROVE | Exactly one reviewed step and decision record; APPROVED terminal request only after final step; still zero Roll/correction outbox until apply. |
| **A16** | Same-Person P3 despite different Principal, wrong configured role/step, revoked grant or wrong Section scope | REVIEW denied; cannot spoof final approval or record an accepted decision. |
| **A17** | Explicit approved APPLY by eligible actor while E1/R0 fresh | One R1, `EXECUTED`, apply SUCCEEDED receipt (14-key result), one unique application and APPROVED→EXECUTED transition, one corrected outbox. Receipt proof matches approved source/number/reason exactly. |
| **A18** | APPROVED request then independent CORRECT/MOVE/END, change policy, occupy candidate or revoke original requester/reviewer grant | Authorized apply deterministically INVALIDATED, rejected receipt and transition exactly once; no domain change, no application or success outbox; wrong apply actor denial does **not** authorize invalidation. |
| **A19** | Inject real PostgreSQL infrastructure error or deadlock during APPLY | Whole SQL transaction rolls back, request remains APPROVED/retryable, no rejected "business invalidation" receipt. |
| **A20** | Retry successful DIRECT and APPLY after later CORRECT/MOVE/END; stored old result no longer current | Same original receipt/result/UUID; strict historical proof, not R1-current test; one correction event *per original success only*. |
| **A21** | Retry original key at next server date (including midnight boundary) | Intent hash stable because current date excluded; proof reads stored `correction_effective_from`. Changed-intent same key still denied. |
| **A22** | Accepted earlier request, later current permission revoked, Student transferred out of actor's Campus | Current display/replay denies sensitive numbers absent approved permission; original receipt/history not erased. RC-07/08 disclosure details pending. |
| **A23** | Authenticated/anon/FAMILY direct SELECT and DML on private Roll, policy, receipt, approvals, outbox | 42501 or equivalently frozen deny, no broad raw data access; legitimate checked read returns only approved typed columns, no reason/payload leak. |
| **A24** | Privileged observer attempts malformed forged `approval_applications` linkage, wrong receipt/request/result/number/route/actor | DB-01 schema-owned application guard rejects; no orphan application; use owner setup only for *negative trigger* tests, never as protected success. |
| **A25** | Regression vs P0 place, P1 MOVE/END, policy current read/structural history, Foundation 220 and current fail-closed correction assertions | No new privilege, schema scope or existing behavior loss; prospective activation requires separate approved suite update, never stealth-disable #65. |

Count **25 proposed scenario families**, **not** an accepted pgTAP assertion count; the actual SQL suite should break these into individual assertions with explicit expected SQLSTATE/error-code after RC-07 freeze.

## 5. Genuine two-session harness contract

**Execution conditions:** *after approved implementation*, start a clean disposable local School DB, COMMIT synthetic fixture setup, run separate real authenticated PostgreSQL client connections A and B (each begins own `READ COMMITTED` transaction, captures `pg_backend_pid()`, sets verified JWT and `SET ROLE authenticated`, invokes the protected RPC with fixed idempotency key), plus a separate trusted observer connection O. Hold A's transaction open after its **completed protected statement** but before COMMIT so School/allocator/Student row locks persist; start B's protected statement; O observes genuine waiting. Then COMMIT A (or ROLLBACK in reversed/abort variant), await B terminal result with bounded timeout. A lock held *solely* by an artificial privileged `SELECT FOR UPDATE` is useful diagnostic evidence but does **not** replace an authenticated end-to-end race proving actual command lock order.

Capture O's observation (adapt explicit PIDs and statement correlation):
```sql
SELECT a.pid, a.state, a.wait_event_type, a.wait_event,
       pg_catalog.pg_blocking_pids(a.pid) AS blockers,
       a.query_start, left(a.query,160) AS query_prefix
FROM pg_catalog.pg_stat_activity a
WHERE a.pid IN (:'backend_a'::integer,:'backend_b'::integer);
-- Required while B is genuinely blocked:
-- B.wait_event_type='Lock' AND :backend_a = ANY(pg_blocking_pids(B.pid)).
-- Wait may be advisory, transactionid, or tuple; do not insist on tuple
-- because PostgreSQL row-lock waits commonly present as transactionid.
SELECT l.pid,l.locktype,l.mode,l.granted,l.classid,l.objid,l.transactionid
FROM pg_catalog.pg_locks l
WHERE l.pid IN (:'backend_a'::integer,:'backend_b'::integer)
ORDER BY l.pid,l.granted,l.locktype,l.mode;
```
Observer query text may contain parameters/sensitive values: retain only redacted query-prefix evidence in test logs. Fail the harness if B exits before a wait was observed, if `pg_blocking_pids` is empty/wrong, or if a worker hangs until timeout. **A timeout/deadlock is a failure of the expected command race**, not a desired business denial. Collect command result, SQLSTATE and final immutable row/receipt/audit/outbox/counter counts. For row-update after waiting, begin a *new SQL statement* to reread current state at `READ COMMITTED`, not a stale pre-wait snapshot. All scenarios also run **reverse winner** (B obtains anchors first), **A rollback** (B reselects clean unchanged state), and **committed A with lost client reply** (idempotent retry).

### 5.1 Eight precise lock races, fixtures and outcomes

In all cases Foundation command prefix is **SHARED auth advisory (71001,1) → 71002 per-key idempotency advisory → current Principal/operation/request/step** as relevant; then shared D1 global lock order is **School → policy rows sorted UUID → allocator rows sorted UUID → Student sorted UUID → Academic Class → Campus → Academic Year → Class Offering → Section Offering → Enrollment/Roll**. Actual lock graph including BEFORE triggers must match. Independent authorizer revocation takes Foundation's **EXCLUSIVE** auth advisory; it must never be attempted while D1 upgrades from SHARED to EXCLUSIVE.

| Race | Initial committed fixture | A action / held target; B action | Winner/loser, immutable history and evidence |
|---|---|---|---|
| **C01 CORRECT × CORRECT** | F01/F03/F05, same open E1/R0 12001, distinct keys and free 12009 vs 12010 | A DIRECT R0→12009, holds School/source allocator/Student, B DIRECT **same exact R0**→12010 | B waits on School/allocator; after A COMMIT B sees R0 closed/superseded and **denies stale**; exactly R0+R1 and one correction receipt/outbox. Reverse B wins instead. With B an approved APPLY, B becomes **INVALIDATED** with one rejected apply receipt and no success event. |
| **C02 CORRECT × MOVE** | F11 same Student E1/R0, source policy/allocator and destination policy/allocator may differ | A DIRECT correct R0, B authenticated MOVE E1→E2 with same pre-correction source view; alternate B MOVE first | **Must have integration-owned union source+destination prelock first**. A first: MOVE either stale-denies exact source snapshot or reselects **latest R1** if its approved command contract allows, creating E2/R2 with corrected numeric and `origin=R1` (persistent). B first: correction denies source no longer active. No old numeric replay into new Enrollment; event counts exactly one per committed successful operation. Current source prelock proof missing → gate BLOCKED until fixed/tested. |
| **C03 CORRECT × END** | F01 E1/R0, valid END expected old source Roll | A DIRECT correct R0, B authenticated END E1; inverse order and APPROVED APPLY variant | END must prelock source policy/allocator **before Student**. END first: E1/R0 close, correction stale-denies. CORRECT first: END binds/revalidates current R1 or stale-denies old R0 depending exact END snapshot; no dangling open R1, no double-close. Correction and END event count only accepted effects. Current END path Student-first → potential deadlock; BLOCKED pending integration patch. |
| **C04 CORRECT × POLICY REPLACE** | F07 r1 current/open, proposed replace at the same trusted boundary by a future approved DB-02 P1 command | A correct R0 under r1, B approved policy r1→r2 REPLACE; reversed order | Both take School/policy/allocator before Student. A first: policy REPLACE evaluates committed allocations/future commitments; may succeed only under signed RP-02, without rewriting R1. B first: source r1 expires; A denies source-policy-out-of-interval (or APPLY INVALIDATED). No autonomous DB-01 policy change. **NOT EXECUTABLE until DB-02 RP and mutator approved**. |
| **C05 CORRECT × AUTO ISSUE** | F01/F02/F03, same persistent School or same exact academic R+Offering allocator; candidate high 12009 not yet assigned | A correct R0→12009, holds allocator; B authenticated P0 place for Student B using allocator after A | Under School/allocator lock B waits, sees counter advanced ≥12010 and gets nonconflicting number. Reverse B first: if candidate already issued to B, A collision-denies. Check allocator `next_value`, server-managed `row_version`, unique owners, one receipt/event per accepted operation. |
| **C06 CORRECT × AUTH REVOKE** | F06 APPROVED or F05 DIRECT with P1 scope; live grant G | A authenticated APPLY/DIRECT holds Foundation SHARED lock; B Foundation grant revocation obtains EXCLUSIVE; reverse by revoking first | A first may commit correction, then revoke; revoke-first forces request authority stale → APPROVED may INVALIDATE only for currently authorized apply participant; DIRECT denies. No post-revocation success. Count one event only for accepted A; revocation audit separate. |
| **C07 TWO STUDENTS SAME NUMBER** | F01/F02 both open, requested 12077 unowned | A correct Student A R0→12077; B correct B Rb→12077 under same PS School or same AC R+Offering | School/allocator serialization: exactly one accepted new owner and success event, other collision-denied/approved apply INVALIDATED. For AC *distinct Offering/revision* same number may be allowed under separate namespace, subject to signed RC-02. |
| **C08 REPLAY AFTER CORRECT/MOVE/END** | F10 original successful receipt R0→R1 committed, later independent legal R1→R2 or MOVE/END committed | A performs later legitimate protected correction/MOVE/END holding corresponding locks; B retries exact *original* actor/key/canonical intent, optionally waits on Foundation receipt key or domain history | Once original receipt exists, B's replay **never changes current Roll/Enrollment**; after A COMMIT return historical R1 if current disclosure still permits. Original correction receipt/event/counter unchanged; distinct later operation has its own evidence. If original B had lost reply, same-key replay before/after A commit returns same original result. Test revoked actor denies disclosure without erasing receipt. |

**Blocker-specific diagnostic:** to demonstrate old Student→source allocator inversion, use independent session-level lock acquisition with actual END and CORRECT entry points and observer PIDs; if reproduction needs instrumented mid-function barriers, introduce a *test-only* hook solely through reviewed local CI integration instrumentation, never a privileged production bypass or a false positive attributed to production commands. The definitive acceptance is **no deadlock and observed correct blocking** after the integration owner supplies a shared source+destination prelock contract. Do not suppress trigger or weaken row checks to make the test green.

## 6. Time-boundary, provenance and rollback testability gates

1. **Current-date-only DATE conflict:** three successive authenticated corrections of one open Roll in a single calendar day would force zero-length closed intervals; cannot be a valid pgTAP happy path. The simple R0→R1 protected correction *is* testable with P0 source `CURRENT_DATE-20`; two/three correction chains need **actual days**, a reviewed trusted server-clock seam limited to disposable local tests, or owner-chosen different date semantics. Merely modifying a fixture Roll date **after a successful correction** or changing the client's timezone is *not* accepted proof. RC-03 owner and integration/test owner must pick and verify one method before claim A13 PASS.
2. **Policy cutover:** under final crossrow guard, correction successor retaining r1 cannot start after r1's exclusive `effective_until`; the proposed first release denies that case. A broader migration/handoff is a DB-02 RP-02/RP-03 decision.
3. **Provenance:** fixed 12-key success result refers to corrected Roll R1 (not Enrollment E1), includes source R0/policy/old and new numeric and trusted effect date; original validated reason remains restricted. On APPLY the `approval_applications` trigger additionally proves the approved requested numeric and exact old_snapshot match R0/R1. Never assume a receipt's mere `result_ref` and existence proves authorized content.
4. **Rollback:** A failure before receipt, after source close, after new Roll insert, after allocator increment, after new `approval_applications`, or during evidence insert must leave **no partial corrected state**, no high-water advancement, no accepted receipt, no corrected outbox and no fake INVALIDATED. Use controlled local test-only fault injection and current authentic RPC; no generic catch that converts unexpected SQL exception to business stale.
5. **Result replay:** recheck *current allowed disclosure* separately from immutable historical pair proof. Following MOVE/END the source Enrollment may be ENDED and R1 may be closed, but its exact before/after correction date remains legitimate and unchanged. Whether a Campus-scoped former requester can see historical old/new values after transfer is a **pending explicit RC-07/08 owner decision**.
6. **Security:** verify directly that `anon`, `authenticated`, FAMILY and `service_role` do not gain raw SELECT/DML/EXECUTE on private helpers; only fixed reviewed public RPCs with current Principal/ACS and approved separate workflow can access history. All 34 D1 relations remain FORCE RLS and Foundation immutable. Don't use `SECURITY DEFINER` as a generic permission bypass.
7. **Near-BIGINT edge:** if `next_value` or candidate is \(2^{63}-1\), increment overflow must produce a *typed denial or whole rollback* per owner decision; do not wrap, reuse or write a rolled-over counter. `MAX()+1` is forbidden. A fixed policy minimum and manual negative/same-number validation happen before mutation.

## 7. Acceptance sequence and owner handoff

**Gate G0 — source and product:** RC-01…RC-08 signed individually; RP-02/RP-03/RP-07 approved in DB-02; integration owner explicitly accepts full-history allocator candidate predicate and source+destination prelock patches. Freeze exact error literals, corrected outbox aggregate/event fields, result/receipt disclosure, current-date authority and multi-day test seam. **No SQL implementation until this gate.**

**Gate G1 — integration physical compatibility:** separate integrator/DB-03 branch fixes final allocator candidate history scan and MOVE/END source prelock; verify final ordered `effect35_15`, `effect30_32`, `effect30_33` plus public entry point overrides, complete lock graph and unchanged RLS/ACL. DB-01 does **not** edit shared definitions.

**Gate G2 — DB-01 narrowly owned implementation:** add reviewed DB-01 new SQL draft fragments for typed RPCs, source validator, effects, replay/result helper, receipt/audit/outbox, P1 independent review and application guard; use same Foundation tables and existing D1 roles; do not enable operation or apply Migration 10. Exact function owners/EXECUTE grants tested.

**Gate G3 — single-session acceptance:** authenticated pgTAP A01–A25 where feasible, fixture isolation, no synthetic success, force `SET CONSTRAINTS ALL IMMEDIATE` before ROLLBACK; historical multi-day test only via approved method; regression #61/#62/#63 and current #65 correction fail-closed gates until activation accepted.

**Gate G4 — observed-lock integration:** C01–C08 both lock-arrival orders, rollback/lost-ACK variants in disposable local two-backend harness with collected `pg_blocking_pids` and `pg_locks`, no unobserved pseudo races. Integration dependencies red until their own reviewed PR is accepted.

**Gate G5 — independent security and release review:** privilege/FORCE RLS, no raw sensitive reason/number leakage, current replay disclosure, total receipts/events cardinality, immutable chain/School ownership, exact source SHA and CI. Only an independently authorized later integration/release checkpoint can update disabled operation/suite #65 and consider Migration 10 activation. This document does **not** claim rollout or readiness for merge.

| Stage | Present finding |
|---|---|
| RC/RP product contract frozen | **NO — PENDING PRODUCT DECISIONS** |
| Shared historical allocator guard/candidate aligned | **NO — INTEGRATION DEPENDENCY** |
| Shared MOVE/END source lock graph accepted | **NO — INTEGRATION DEPENDENCY** |
| DB-01 SQL implementation authorized/executed | **NO** |
| DIRECT and independent APPROVAL authenticated pgTAP accepted | **NO** |
| Historical replay and observed two-session races accepted | **NO** |
| Independent security review passed | **NO** |
| PR #100 integration-ready/merged | **NO — DRAFT, UNMERGED** |

**Safe next DB-01 task, if still unsigned:** prepare a **single DB-01 owner decision register/ADR recommendation packet** tying RC-01…RC-08 to exact DB-02 dependency outcomes and to the proposed five RPC signatures, approved receipt event/body, historical disclosure and date/test-clock choices, without marking anything approved. If product owner signs the decisions and cross-domain integration owner provides the prerequisite fixes, move instead to separately authorized DB-01-only SQL implementation and acceptance tests.
