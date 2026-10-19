# DB-02 — Policy transition and allocator integrity: implementation-readiness contract

**Status: DESIGN COMPLETE FOR OWNER REVIEW; RP-01–RP-07 NOT ALL FROZEN; NO SQL/ACTIVATION AUTHORIZED.**  
Date: 2026-10-19. Domain-only continuation of [DB-02 integrity gate](db02_allocator_namespace_integrity_gate_20261019.md), [original design](db02_student_roll_policy_design_20261019.md), [review/tests](db02_student_roll_policy_review_20261019.md), and source reviews [#127](127_d1_roll_policy_p1_implementation_readiness_and_invariant_review.md), [#154](154_d1_student_roll_policy_change_p1_contract_readiness.md). Verified branch prior HEAD: d4737c632b3c86454f8ca06cd3464d457c2b6e0a; inspected main at f38c087b989328f0c871b8ec5707e46ba12a856f. DB-01 [PR #100](https://github.com/yunusyosaf399/edusync_saas_school_app/pull/100) and DB-03 [PR #102](https://github.com/yunusyosaf399/edusync_saas_school_app/pull/102) were consulted **read-only**.

This record resolves engineering interpretation where the frozen D1 source is clear; it does **not** assert product-owner approval, a successfully executed SQL acceptance test, or completion of an integrated runtime lock-graph proof. DB-02 owns only roll-policy decisions and narrow future command effects, not changes to enrollment/create/correction SQL.

## 1. Final inspected SQL definitions and confidence

All SQL paths below are under supabase/migrations; Migration 10 is still non-executable .sql.draft. The term **final** identifies the latest relevant CREATE OR REPLACE from the inspected ordered fragments, not a hosted Supabase installation.

| Object / effective source | Exact observed behavior | Consequence |
|---|---|---|
| app_private.d1_enrollment_place_allocate_roll(uuid,uuid,uuid,uuid,uuid,date), effect25_23 then final effect35_15_enrollment_place_allocator_server_version.sql.draft | School policy at **requested placement effective date**; latest unsuperseded same-Student persistent origin; other-Student persistent candidate scan excludes rows having any superseding allocation; academic scan is same policy revision + Offering interval; UPDATE next_value only, server M-row version trigger owns version/timestamp. | Real *candidate-selection mismatch* with permanent historical ownership. No source-level roll-number change is authorized here. |
| app_private.d1_guard_crossrow(), final effect30_32_crossrow_campus_local_rename.sql.draft, roll_allocations arm approximately lines 130–205 | Persistent collision scan checks **all** other-Student allocations of same numeric across **all persistent revisions of School**, with **no superseded/end filter** (approximately 189–193); raises D1 roll namespace collision. Academic scan uses revision + Offering and interval overlap. | Insert defense enforces historical persistent reservation if this final trigger definition is deployed; a skipped candidate causes failed placement, not established committed duplicate. |
| ac_d1_ancestry on roll_allocations, master 20260928000000_domain_package_01.sql.draft | BEFORE INSERT OR UPDATE invokes app_private.d1_guard_crossrow(). | The protective scan is actually attached to roll-allocation insertion, not merely documentation. Still needs integrated local pgTAP proof of execution. |
| app_private.d1_enrollment_place_prelock_roll(uuid,date), effect25_19_enrollment_place_school_anchor.sql.draft | Locks School through d1_enrollment_place_lock_school, rediscovers ancestry after wait, requires exactly one as-of policy, then locks policy and existing NULL-persistent or Offering-specific academic allocator; reports missing pool. | Policy INIT/REPLACE without allocator provisioning would make placement fail closed. |
| app.d1_place_student_enrollment command final effect25_22_enrollment_place_entry_kind_hardening.sql.draft | Calls prelock **before** Student-oriented lock_context and effect; verifies matching School/Offering and policy result. | Documented full PLACE entry-path lock order is School/policy/allocator before Student. |
| app.d1_move_student_enrollment DIRECT/SUBMIT effect26_05 and APPROVAL apply final effect26_09_enrollment_move_apply_hardening.sql.draft | Calls same destination prelock before d1_enrollment_move_lock_context; verifies policy result. Effect26_03 closes old allocation/enrollment, creates successor and invokes allocator. | Earlier suspected unconditional MOVE Student→allocator inversion is **not confirmed** from these entry paths; a genuinely observed two-session test is still needed. |
| app_private.d1_p1_route(text,uuid), base master draft | Filters enabled operation, one effective ACTIVE approval_policy_versions row, and (policy campus_id IS NULL OR equals supplied campus); DIRECT or valid configured APPROVAL steps. | Passing **NULL** campus selects only global NULL-Campus version, never an arbitrary campus route; operation currently disabled so call returns no route. Resolver returns text route, **not policy version identity**. |
| app_private.roll_policy_revisions, roll_allocator_states, roll_allocations; physical #27 / constraints #30 / concurrency #31 | HE policy revisions and HE allocation history, M allocator with UNIQUE (policy_id,NULL) or (policy_id,Offering); School-wide historical persistent ownership; academic per policy + Class Offering. | History and policy source UUIDs are immutable; no policy row_version or command_receipt_id; new revision requires new namespace pool. |
| Suites #37, #38, #61, #62, #63, #65 | Current read, owner-only synthetic policy history, PLACE/END/MOVE and disabled operations respectively. | Existing accepted suite evidence is **not** P1 roll-policy-change acceptance. |

**Assembly boundary:** inspected base master trigger attachment, effect30_32 cross-row final override, final effect35_15 allocator override, and relevant PLACE/MOVE wrappers. No local SQL assembler, disposable PostgreSQL or CI workflow was executed for this documentation task. A future SQL change must compare exact ordered assembled function catalog and search for post-commit overrides again before tests. Do not describe a theoretical duplicate as already committed.

## 2. Confirmed defect, protection, and exact required allocator correction

### 2.1 The case 1001 → 1002 → 1001

1. Student A receives persistent **1001** under School S / revision R1, allocation A1.
2. In a *hypothetical future approved DB-01 correction*, A1 is one-way closed and A2 is appended with numeric **1002** and supersedes_id=A1.id. No correction command is currently enabled.
3. A subsequent School policy revision R2 is persistent, its distinct allocator state has next_value=1001. Student B has no earlier persistent origin.
4. In effect35_15, B's candidate 1001 sees A1 but ignores it because another allocation superseded it. A2 is numeric 1002. The WHILE loop **does not advance** candidate; it attempts 1001 for B.
5. In effect30_32, the roll_allocations BEFORE INSERT cross-row guard finds A1 because its persistent check does **not** filter superseded allocations, and raises D1 roll namespace collision. With correct installed trigger and atomic placement, B's command rolls back: **no committed duplicate**, but potentially a repeatable placement failure whenever the allocator starts at historically used numbers.

**Confirmed source defect:** candidate selection is inconsistent with the retained ownership guard and can choose a forbidden number. **Existing defensive guarantee:** the inspected trigger rejects the attempted historic cross-Student collision. **Not demonstrated:** running-test proof of rollback or a committed collision. **Separate product decision:** whether historical persistent claims can ever be released is not silently decided by this engineering fix; however, *current frozen #31 and deployed guard already prescribe permanent School-wide ownership*. Changing that semantics would require an explicit ADR and coordinated DB-01 review.

### 2.2 Exact candidate and lineage predicates for a later owner-approved integration change

Do **not** delete the supersession filter in the same-Student origin query: it is needed to carry forward the latest corrected **current** persistent number, not an obsolete one. Keep effective_from <= placement effective date, reject future conflicting retained persistent allocations, order by effective_from DESC, created_at DESC, ID DESC and derive policy School through the policy FK.

The different-Student exclusion **must** conceptually be:

~~~sql
-- PROPOSED PREDICATE ONLY. Not executable DB-02 migration code.
EXISTS (
  SELECT 1
  FROM app_private.roll_allocations a
  JOIN app_private.roll_policy_revisions p ON p.id = a.policy_revision_id
  WHERE p.school_id = target_school_id
    AND p.mode = 'PERSISTENT_STUDENT'
    AND a.numeric_value = candidate_value
    AND a.student_id <> target_student_id
)
~~~

**No** a.effective_until, no supersedes_id, no current-policy-revision-only constraint, no Offering and no time-overlap qualification in this persistent other-Student ownership check. In academic mode preserve exact policy revision+Class Offering and half-open interval-overlap check; distinct contexts can reuse numeric components.

**Counter initialization proposal:** when creating a persistent revision, under Foundation SHARED authorization, School FOR UPDATE and ordered policy anchors, ensure one (new_revision,NULL) allocator (partial unique PU01). Seed next_value at least new start_value and at least prior persistent allocator **high-water next_value** for the School, checking bigint bounds. This is reading the prior **counter state**, not a client-side MAX(allocation)+1 allocation shortcut; it is only an efficiency/high-water floor, not proof of availability. Correctness always comes from the complete historical ownership predicate under School serialization and final defensive trigger. If existing committed historical allocations exceed old next_value (manual correction or migration history), collision-skipping still rejects them; a separate owner-approved counter reconciliation may advance the high-water without reassigning anyone.

At allocation time (under School→policy→exact allocator FOR UPDATE), candidate = GREATEST(current next_value, policy start_value), advance monotonically while retained other-Student persistent ownership exists, and reject rather than overflow at bigint max / candidate+1. Update only next_value; leave row_version/updated_at to the server trigger. The new-state insert and revision close/append must be one atomic transaction, protected by PU01/PU02 and defensive guards. A rollback leaves prior counters and policy untouched. A future chosen policy allowing number reuse requires a *different explicitly approved invariant* and corresponding trigger/lookup/history contracts; changing only the WHILE loop is not sufficient.

**Permanent number ownership is not the same as one number per Student for life:** after correction A can own *historically* both 1001 and 1002; the same-Student **currently carried** value is 1002. Unowned academic-context 1001 is a separate namespace and may be assigned to another Student under approved contextual collision rules.

## 3. Typed lifecycle, dates, stale expected source and unfinished product choices

### 3.1 Immutable request envelope candidate (NOT a deployed API)

~~~text
operation_code: existing student.roll_policy.change
school_id: uuid, matched to stored School and authorized ALL context
action: INIT | REPLACE | END                  (proposal; END activation pending)
source_policy_id?: uuid                    (required for REPLACE/END)
expected_revision?: positive int           (required for REPLACE/END)
expected_mode?: enum                       (required for REPLACE/END)
expected_start_value?: bigint              (required for REPLACE/END)
expected_effective_from?: date             (required for REPLACE/END)
expected_effective_until?: date|null       (must match exact stored state)
new_mode?: PERSISTENT_STUDENT|ACADEMIC_CONTEXT (INIT/REPLACE only)
new_start_value?: bigint >= 0              (INIT/REPLACE only)
private_reason: trimmed nonblank text
idempotency_key: validated opaque operation-bound key
proposed_effective_date: server CURRENT_DATE only under proposed RP-02
caller never supplies principal, role, campus, allocator ID, revision number or event code
~~~

Bind canonical intent/hash to operation contract, School, action, exact old snapshot, new values, effective-date rule, private reason digest and approved route identity/version. Snapshots use HE ID+revision+fields because **no roll_policy_revisions row_version exists**. Do not mistake checked four-field current read for write authorization.

### 3.2 Lifecycle candidate and exact preconditions

| Action | Typed preconditions | Atomic effect | Stale/invalid behavior |
|---|---|---|---|
| INIT | School locked; **zero** retained policy rows; no preexisting policy allocations; new mode/start valid. | Append revision=1 with supersedes_id NULL effective today; provision correct mode pool(s). | Any retained history, duplicate INIT, missing route or pool capacity conflict: deny. INIT does not silently reopen previously ended School. |
| REPLACE | School locked; exactly one intended **open current head** with expected ID/revision/mode/start/from/until, current date inside it, no existing successor, source.from < today; requested effective date within allowed boundary. | Close source once at t, then append sequential revision n+1 with supersedes_id=source.id and effective_from=t; initialize successor allocator(s) before commit; preserve allocations. | After lock/recheck if source has ended/changed/successor, target row missing or date mismatch, mark reviewed apply stale or reject DIRECT. |
| END | Same exact open-head snapshot, source.from < today, no conflicting future placement; no requested new mode. | One-way close source at t; no successor, all old pools retained. | **Owner-gated:** no automatic restart path exists under INIT-only empty-history rule; recommend END **not enabled in first release** until policy-gap/resumption semantics and future placements are decided. |

**Temporal behavior:** old [a,t), new [t,∞) contiguous half-open revision; t exactly belongs to new. A source created **today** cannot be ended/replaced today without a zero-length history interval; deny rather than overwrite or delete. A second REPLACE on the same day must therefore fail. An open policy gap has no fallback to last revision: existing prelock returns no unique policy and placement denies. Existing accepted Enrollment/Roll starting **before** boundary t may continue with retained historical policy; policy replacement does not auto-split or renumber it. A **future-dated** accepted placement whose roll start >= t still points to old revision R if booked before policy change: recommended REPLACE/END must detect and deny the incompatible future commitment, rather than leave a now-invalid as-of policy allocation. The exact allowed scheduling and multi-preplanned-successor operation remain RP-02 questions; do not implement them by inventing retroactive history mutations.

**Reopening after END:** zero policy history is not the same as no *currently effective* policy. INIT restricted to zero history makes END terminal unless a separately approved RESUME/RESTART/late successor contract is added. This is a **real unresolved lifecycle completeness gap**; recommend initial release support INIT/REPLACE only, and retain END as fail-closed until resumption and availability rules are approved. Any later RESUME must use new revision n+1 (never a second revision 1), exact old ended predecessor identity, and explicit gap and placement policies.

**Optimistic concurrency:** School FOR UPDATE serializes competing actions. Check source immutable fields and exact effective_until NULL under lock, plus exact existing successor count and revision sequence. A competitor with the same source but another key does not silently rebase: one successor commits, the other is stale. Existing identical successful receipt may replay even after later legitimate revisions, but only via current participant authorization and immutable result verification. Infrastructure errors roll back; they are not business INVALIDATED.

## 4. Ten transition cases / allocator and date matrix

All entries are proposals to be frozen; old allocations are **never rewritten**.

| Transition | Revision and pool | Ownership, collision and future placement |
|---|---|---|
| No policy → persistent | INIT r1, one (r1,NULL) pool, floor start_value; reject INIT if *any* historical policy exists. | New Student gets unowned school-wide value; same-Student legitimate existing persistent origin only if any retained history is actually permissible. |
| No policy → academic | INIT r1, one (r1,Offering) pool per eligible Offering under an explicit eager-provision policy. | Current prelock REQUIRES existing pool; lazy insertion would need separately approved placement-owner change. |
| Persistent → persistent | Close rN / append rN+1; new persistent NULL pool with prior persistent high-water floor. | Carry latest unsuperseded same-Student valid numeric; reject *all retained* different-Student claims across r1..rN+1, even corrected-away values. |
| Persistent → academic | Close rN / append AC rN+1; eager Offering-specific counters at new start_value. | PS history remains PS; academic numeric may overlap PS historical values because policy/Offering namespace differs. |
| Academic → persistent | Close AC / append PS; one new persistent NULL pool seeded from School persistent high-water. | Latest legitimate historical PS same-Student origin reused under current source behavior; choice to mandate reentry as product promise is RP-03 sign-off. |
| Academic → academic | Close old AC / append new AC revision; separate new (revision,Offering) counters. | A numeric may repeat across *distinct* revisions/Offerings; collisions only within exact revision+Offering with overlapping intervals. |
| END | One-way close, no successor and no new allocator; preserve old pools. | Future placement inside gap rejects; recommend no first-release END without resumption/future commitment semantics. |
| REPLACE vs new placement | Both contend on School first; winner releases before loser re-reads policy and namespace. | Placement winning first binds immutable as-of policy; later REPLACE denied if it invalidates that future-start roll. Policy winning first provisions pool before later placement. |
| Persistent→academic→persistent | Retain r1,r2,r3, new r3 persistent pool (not reactivating r1 allocator). | Historical PS claims remain reserved; current allocator's same-Student origin searches PS history across intervening academic revision. |
| Future Enrollment crossing t | Keep committed Enrollment/roll historical policy identity, no automatic split. | If roll starts before t it remains historically assigned; if starts >=t under an old revision, candidate REPLACE/END denied until an explicitly reviewed coordination strategy exists. |

## 5. School-wide P1 and typed immutable evidence readiness

The current master draft defines app_private.d1_p1_route(text,uuid) as a **text-only** route selector. Passing campus_id=NULL excludes campus-specific approval_policy_versions; this is a sound School-global selection candidate, and cannot bypass the disabled operation. **Existing ALL/DIRECT school permission scope** refers to Foundation assignment scope, whereas **P1 DIRECT route mode** is a distinct concept; a School Owner role name or view permission does not imply either.

Proposed DIRECT path: verified INDIVIDUAL Principal, current complete student.roll_policy.change grant and exact School ALL scope; shared Foundation auth lock, receipt advisory lock, School and relevant revision/allocator locks; one active global route policy bound by **policy version UUID** with mode DIRECT, source snapshot recheck, one atomic policy effect/receipt/audit/event once RP-06 event is frozen.

Proposed APPROVAL path: immutable typed submit (requester needs current change grant), independent reviewer *different Person* (including alternate Principals), live student.roll_policy.approve and exact ALL scope + active configured reviewer role and D1_REVIEWER_ROLE_SCOPE step; APPROVED alone changes no policy. A separate request.apply rechecks requester and reviewer current permissions, selected global policy version ID, current School/source history, future commitments and numeric namespace. If deterministic changes invalidate the intent, request moves to INVALIDATED with narrow rejected apply receipt and **no successful application, revision, allocator modification, or selected outbox event**. Infrastructure failure rolls back, remains retryable. An authenticated historical receipt replay requires current participant/School disclosure and returns original immutable policy IDs/versions/dates, never reapplies a new revision or depends on old head still being current.

**Missing integration detail:** d1_p1_route returns only DIRECT/APPROVAL text, not chosen approval_policy_versions.id. A future DB-02 fixed selector must **reconstruct exactly one policy version UUID under the same live predicates** or obtain a reviewed narrow Foundation API that returns it. Do not merely hash route text: policy version could change while remaining DIRECT. No invented Campus ID, new Foundation policy table, configurable admin bypass or generalized JSON patch.

**Evidence shape, NOT codes:** success receipt binds command/request + immutable School, action, old policy ID/revision (nullable INIT), new ID/revision (nullable END), effective interval, canonical intent hash, selected P1 policy version ID and approved result summary. Immutable policy row has no receipt FK; result verification joins/compares receipt bound identity to actual retained policy revision(s) and Foundation approval application as appropriate. Broad audit/outbox allowlist is operation code, School ID, immutable revision IDs, action, timestamp, correlation/receipt ID and approved public interval/mode identifiers only. Private reason stays in restricted domain/history/request read, not broad outbox. **Result_kind literal and selected broad event name remain RP-06 explicit owner decisions**. The old physical draft suggestion does not register an event.

## 6. Owner-decision register — frozen facts versus signatures required

| RP | Recommended specific decision | Alternative, implications, acceptance | Sign-off |
|---|---|---|---|
| RP-01 | INIT once for empty School; REPLACE exact current head+immutable snapshot; END remains unsupported initially. | Bootstrap INIT or broader historical scheduling requires explicit alternate source/version and revised tests. Assert INIT twice denies; two REPLACE same head one winner. | PENDING |
| RP-02 | CURRENT_DATE-only, contiguous replace; same-day zero-length closure denied; reject future commitments that would be invalidated. Hold END until resumption/gap semantics frozen. | Future scheduling/gap/resume demands new typed actions and future policy precedence; risk stranded enrollments. Test t-1/t, no gap fallback, future placement first. | PENDING |
| RP-03 | **Preserve already-frozen #31 historical cross-revision persistent ownership** (not a new permission to reuse); fix selection loop to match guard, maintain counter floor across persistent revisions, eager academic pool provisioning, same-Student current origin. | New *reusable* number policy would overturn #31/defensive guard and need ADR, DB-01 RC-02/05 and DB-03 agreement. Tests A1001→1002/B1001, PS→AC→PS, overflow, rollback. | PENDING for counter/reentry/reuse policy changes; core no-reuse already supported |
| RP-04 | School-wide ALL scope; global NULL-Campus approval policy; exact version UUID binding + recheck. | New Foundation selector if global policy scope unsuitable; danger wrong Campus authority. Test NULL scope, two global rows, policy swapped same route mode. | PENDING |
| RP-05 | DIRECT or independent submit→review→explicit apply, different Person, live ALL grant+configured reviewer role/step at review and apply; fail-closed stale source. | Alternative participants/checked views require disclosure review; test revoked requester and reviewer, policy drift and self-review. | PENDING |
| RP-06 | Owner explicitly chooses stable result_kind and outbox event, binds retained result without HE receipt FK, minimizes broad audit. | No event/no type => do not activate; inventing old catalog example breaks contract. Test typed success/rejected evidence, private reason non-disclosure, duplicate replay. | PENDING |
| RP-07 | Global auth SHARED→receipt→School→policy→allocator→Student/Academic if touched→child; exact recheck after waits, retained receipt replay after later changes. | Unordered locks/replay could deadlock or duplicate revisions. Test REPLACE/REPLACE, REPLACE/PLACE, grant-revoke, rollback and lost response in two independent PostgreSQL sessions. | PENDING |

The table is a **review proposal, not seven owner approvals**. Existing frozen conditions include HE immutability, interval nonoverlap, revision sequence, School-wide persistent ownership, two mode namespaces, distinct view/change/review permissions and disabled operation state.

## 7. Read-only DB-01 and DB-03 handoff

**DB-01 PR #100:** RC-02/RC-05 and RC-04/RC-08 must retain original and corrected persistent ownership, distinguish supersedes correction history from same-Student origin, maintain allocator high-water on manual corrections, avoid changing historical policy IDs, and serialize with School/policy/allocator before Student. The corrected-away number remains reserved under current #31 and guard. DB-02 does **not** implement correction or freeze DB-01 RC-01..RC-08.

**DB-03 PR #102:** SC-04/SC-06 must obtain the new Student's initial Primary placement **effective date**, Section→Offering→School ancestry, exact mode-specific server allocator and approved School prelock in one authorized atomic D1 handoff; Admissions application/admission number is separate from roll and permanent school_student_id. Abort on missing policy or missing academic pool, capacity denial, or conflicting future policy; never invent a roll. Same-key durable replay must not allocate again. Joint Foundation/Admissions/Finance/School counter lock DAG needs separate implementation-owner approval. DB-02 never edits Admissions or Student Creation.

**Existing enrollment interfaces:** final PLACE effect25_22 and MOVE effect26_05/effect26_09 have prelock before Student; END effect27_02 closes current Enrollment/Roll, not issuing a new roll; still validate full integrated locks in observed-lock races. DB-02 policy REPLACE must never silently rewrite current/closed Enrollment, roll allocation, correction lineage, or Admissions handoff, nor update DB-01/DB-03 files.

## 8. Ordered implementation and test work packages after decisions

1. **Evidence freeze:** owner signs RP-01..RP-07 (including END deferral, School global P1 mapping, explicit event and result literal); DB-01 and DB-03 sign interface expectations; integrator checks exact final assembled functions/trigger and all SQL override ordering. No activation yet.
2. **Cross-domain allocator dependency:** DB-03/D1 placement SQL owner, not this design branch, corrects the persistent **other-Student candidate loop** to match guard; explicitly preserves same-Student latest unsuperseded origin; confirms counter floor/overflow and existing wrapper prelocks. Add its own rollback-only authenticated placement + structural guard tests, observed-lock races and regressions.
3. **DB-02 additive physical draft (separately authorized SQL slot):** fixed typed School policy intent validation; exact global version selection and authority; owner-limited INIT/REPLACE/END effect; ensure requested state/eligible mode and pool existence/atomic provisioning; no edit to D1 central assembled migration by DB-02. Preserve immutable revision history and current check-read.
4. **DIRECT P1 candidate:** typed canonical key, receipt phase and checked School ALL permission, School/policy/allocator locks; write source close + next revision/pool + approved typed result/audit/outbox in one transaction; validate expected source after wait.
5. **APPROVAL P1 candidate:** submit immutable request+approved old/new snapshot; separate independent reviewer and check-read; explicit apply with policy version+source/rights recheck, deterministic INVALIDATED vs infrastructure rollback, application/receipt linkage.
6. **Runtime evidence:** rollback-only authenticated pgTAP for cases below, no fixture-faked command successes; forced deferred constraints immediate; run baseline suites #37/#38/#61/#62/#63/#65 *until independent activation* and frozen Foundation 220 SQL. Verify FORCE RLS/column ACL for School/policy/allocations and fail-closed unauthenticated direct DML.
7. **Two-session race CI (integrator-owned):** observe real conflicting PostgreSQL locks (no sleep-only claim), same-source competing REPLACE/END, placement at exact boundary t, older history correction vs new Student candidate, P1 apply vs exclusive grant revoke, simultaneous policy/counter provisioning, rollback/lost ACK and replay. Assert winner count, prior high-water, invariant state, audit/outbox cardinality and terminal invalidation.
8. **Independent security/acceptance review:** exact head and green relevant CI, no overlapping implementation merges, adopted freeze ADR, SQL diff isolation and explicit separate activation/manifest/integration ownership. Keep command disabled and Migration 10 inactive here.

### Acceptance case identifiers to implement later

| Cases | Mandatory assertions |
|---|---|
| DB02-OWN-01..04 | A1001→1002 then B candidate1001: selected candidate skips (not just trigger denial); guard rejects synthetic conflicting raw insert; persistent r1→academic r2→persistent r3 same-Student reuse / other-Student reservation; high-water rollback/overflow. |
| DB02-POL-01..08 | Both INIT modes; current-date REPLACE; two same-day replacements denied; exact stale source; END unavailable; future placement-before-REPLACE denied; retained historical ID and no renumber. |
| DB02-P1-01..08 | Global NULL-Campus route, ALL grants; DIRECT/APPROVAL; same-Person reviewer denied; policy version changed but route mode same invalidates; requester/reviewer revoke; typed success/rejected receipt and no private reason disclosure. |
| DB02-RACE-01..06 | Two-session INIT/INIT, REPLACE/REPLACE, REPLACE/placement both orders, REPLACE vs MOVE, apply vs grant revoke, rollback/replay after later revision. |

**No tests or SQL executed in this documentation phase.** Every RP decision not already frozen remains owner-gated. Final status: **PRODUCT DECISION REQUIRED — IMPLEMENTATION-READINESS CONTRACT PREPARED, NO OPERATION ACTIVATED.**
