# DB-01 — Exact P1 API, immutable receipt verifier and stale-apply contract gate

**Review date:** 2026-10-19. **Status: IMPLEMENTATION-READY SPECIFICATION CANDIDATE / PRODUCT DECISION REQUIRED — no runnable SQL authorization.**
**DB-01 owner:** `student.roll.correct`; [draft PR #100](https://github.com/yunusyosaf399/edusync_saas_school_app/pull/100), dedicated branch `db/db-01-student-roll-correction-design`.
**Reviewed exact source:** `main f38c087b989328f0c871b8ec5707e46ba12a856f`; DB-01 prior HEAD `4fb7221a8d3d0e1c15220cf5f439591b6d600ceb`; DB-02 PR #101 `d4737c632b3c86454f8ca06cd3464d457c2b6e0a` (RP decisions not approved).
**This artifact:** One DB-01-owned document. It does not alter existing migrations, executable functions, central CI, test suites, Foundation, DB-02/03/04, permissions, operation activation, hosted database or PR merge.

## 0. Frozen source versus proposed interface

**Frozen/evidenced:** `AGENTS.md`; master v0.2, decisions/invariants, SaaS guardrails and security workflow; [readiness #153](153_d1_student_roll_correct_p1_contract_readiness.md); [physical #27](27_domain_package_01_physical_catalog.md), [constraints #30](30_domain_package_01_constraint_matrix.md), [locks #31](31_domain_package_01_concurrency_and_locking.md), [indexes #32](32_domain_package_01_index_review.md); [security command #09](../security/09_domain_checked_reads_and_commands.md); existing [DB-01 contract](db01_student_roll_correct_design_20261019.md), [review](db01_student_roll_correct_review_20261019.md), [compatibility gate](db01_roll_correction_compatibility_gate_20261019.md), and [transaction gate](db01_roll_correction_transaction_readiness_20261019.md). `student.roll.correct` is registered **disabled**; `student.roll.approve` exists but does not authorize an enabled correction. Its selected broad event is `enrollment.roll_corrected`. `app_private.roll_allocations` is retained effective history with UUID source/successor, `supersedes_id`, distinct `origin_allocation_id`, policy ID, numeric, end markers and restricted `correction_reason`, **no HE row_version or receipt FK**. Existing Student M `row_version` is the supported optimistic token. Protected Foundation P1 offers DIRECT or independent APPROVAL when an enabled operation and unambiguous effective policy are present.

**Read-only implementation references (ordered `supabase/migrations/20260928000000_domain_package_01_*.sql.draft` fragments, later overrides are authoritative):**
- `effect27_02_enrollment_end_context_effect`: `app_private.d1_enrollment_end_command_context(text,text,jsonb)` uses `d1_jcs_typed`, SHA-256 canonical payload, Foundation SHARED advisory `(71001,1)`, per-principal/operation/idempotency-key advisory `(71002,<derived int>)`, `command_receipts` terminal lookup and collision detection.
- `effect27_03_enrollment_end_evidence`: `d1_enrollment_end_receipt` inserts `command_receipts`, fixed result kinds and command phases; `d1_enrollment_end_audit`, `d1_enrollment_end_event`; result proof helper.
- `effect27_04_enrollment_end_direct_submit`: DIRECT/submit typed signatures, private `approval_requests.old_snapshot` and `requested_payload`, independent request version/step initialization, no submit effect.
- `effect27_05_enrollment_end_review`: `d1_enrollment_end_reviews_live`, `app.d1_review_student_enrollment_end`, configured `D1_REVIEWER_ROLE_SCOPE` selection, different-Person review, one receipt per review transition.
- **Final** `effect27_07_enrollment_end_hardening`: `app.d1_apply_student_enrollment_end`, participant checked read, strict result summary, `d1_enrollment_end_application_receipt_guard()` that independently verifies exact successful receipt and retained domain rows for `approval_applications`.
- `effect27_01_enrollment_end_core`: `d1_enrollment_end_authorized` verifies active individual Principal, active role/grant/scope and source Section's ALL/CAMPUS/CLASS/SECTION ancestry; `d1_enrollment_end_policy` resolves School fallback versus Campus policy. These are *patterns*, **not helpers usable for the roll.correct permission code without a DB-01-owned implementation**.
- `effect35_15_enrollment_place_allocator_server_version` final auto allocator; `effect30_32_crossrow_campus_local_rename` final `d1_guard_crossrow`; **final** `effect30_33_qualification_experience_lineage_guard` overrides history trigger; public MOVE destination prelock and END source prelock gaps described in DB-01 transaction gate. The existing `app_private.d1_p1_route(text,uuid)` in base Migration 10 names roll correction but **returns no usable route while operation disabled**.
- DB-02 [allocator namespace integrity gate](https://github.com/yunusyosaf399/edusync_saas_school_app/blob/db/db-02-roll-policy-design/docs/database/db02_allocator_namespace_integrity_gate_20261019.md) recommends **permanent** persistent School-wide numeric ownership, but RP-02/RP-03/RP-07 are still open.

**Status of everything below:** fixed *recommended signatures and semantics* for future review. The names, return fields, reason disclosure, error literals and action/date policy are **NOT frozen by owner**, even when presented exactly enough for implementation estimation.

## 1. Proposed exact public typed SQL signatures — NOT CREATE statements

New public RPCs would live in existing `app` schema and be callable only by `authenticated` through reviewed executor-owned SECURITY DEFINER wrappers with fixed search_path, no direct private-table SQL. These signatures are **candidate owner choices**; retain existing one-purpose handler operation `student.roll.correct`, contract version 1 (not a new operation). All UUID/positive versions/required reason and fixed length/type validations are server-side.

```sql
-- P1 DIRECT: mutation only when reviewed source-Campus policy route is DIRECT
app.d1_correct_student_roll(
  p_student_id uuid,
  p_expected_student_version bigint,
  p_source_enrollment_id uuid,
  p_expected_source_section_id uuid,
  p_expected_enrollment_effective_from date,
  p_source_roll_allocation_id uuid,
  p_expected_source_roll_effective_from date,
  p_expected_source_policy_revision_id uuid,
  p_expected_old_numeric_value bigint,
  p_requested_numeric_value bigint,
  p_reason text,
  p_idempotency_key text
) RETURNS TABLE (
  student_id uuid, enrollment_id uuid, source_roll_allocation_id uuid,
  corrected_roll_allocation_id uuid, corrected_numeric_value bigint,
  correction_effective_from date, student_version bigint
);

-- P1 submit under APPROVAL: no Roll or counter effect
app.d1_submit_student_roll_correction(
  p_student_id uuid,
  p_expected_student_version bigint,
  p_source_enrollment_id uuid,
  p_expected_source_section_id uuid,
  p_expected_enrollment_effective_from date,
  p_source_roll_allocation_id uuid,
  p_expected_source_roll_effective_from date,
  p_expected_source_policy_revision_id uuid,
  p_expected_old_numeric_value bigint,
  p_requested_numeric_value bigint,
  p_reason text,
  p_idempotency_key text
) RETURNS TABLE(request_id uuid, request_version bigint);

-- Reviewer can APPROVE or REJECT the current configured step; no Roll effect
app.d1_review_student_roll_correction(
  p_request_id uuid, p_decision text, p_expected_request_version bigint,
  p_reason text, p_idempotency_key text
) RETURNS TABLE(request_id uuid,request_version bigint,request_state text);

-- Explicit separate reviewed APPLY
app.d1_apply_student_roll_correction(
  p_request_id uuid,p_expected_request_version bigint,p_idempotency_key text
) RETURNS TABLE(
  request_id uuid,request_version bigint,request_state text,
  corrected_roll_allocation_id uuid
);

-- Narrow participant checked read: absence of authorization yields no row.
app.d1_read_student_roll_correction_request(
  p_request_id uuid
) RETURNS TABLE(
  request_id uuid,request_version bigint,request_state text,
  student_id uuid,source_enrollment_id uuid,source_section_offering_id uuid,
  source_roll_allocation_id uuid,source_roll_effective_from date,
  source_policy_revision_id uuid,old_numeric_value bigint,
  proposed_numeric_value bigint,participant_kind text
);
```

**Why not a generic JSON RPC:** no client-supplied role, campus, School, allocator identity, policy route, Person, correction effective date, receipt ID, origin link, predecessor link, workflow step or event payload is accepted. Numeric values are BIGINT, not a float or UI formatted roll string. The same direct+submit inputs prevent approving an opaque or under-specified request. `source_roll_allocation_id` is the explicit target, never a `numeric_value` lookup. The internal command context alone may use a fixed typed JSON array.

**Transport and privacy:** return old/current numeric values only on the authorized DIRECT result or reviewed authorized participant read. If a participant lacks permission for number history after transfer, suppress/reject rather than expose a broad receipt. Whether participant read includes `p_reason` is **deliberately omitted**, pending RC-07 reason disclosure approval; requester/reviewer text still exists in restricted `approval_requests.reason` and `roll_allocations.correction_reason`. The checked read never returns arbitrary `old_snapshot`, `requested_payload`, `result_summary`, reviewer assignments or private raw JSON. Unreviewed request records, missing actor or stale permission produce **no row**, not a detailed existence oracle.

## 2. Exact internal interface, authority and privilege candidate

| Proposed DB-01-owned internal helper | Signature/contract | Owner/ACL (proposed) |
|---|---|---|
| `app_private.d1_roll_correct_command_context` | `(p_command_kind text,p_key text,p_intent jsonb) RETURNS TABLE(actor_id uuid,operation_id uuid,receipt_id uuid,result_ref uuid,result_summary jsonb,receipt_state text,intent_hash bytea)`; kind is exactly `student.roll.correct`, `request.submit`, `request.review`, `request.apply` | evidence writer function; EXECUTE only `schoolos_student_executor` and `schoolos_workflow_executor`; deny PUBLIC/anon/authenticated/service_role |
| `app_private.d1_roll_correct_authorized` | `(p_actor uuid,p_permission_code text,p_source_section uuid,p_reviewer_role uuid DEFAULT NULL) RETURNS boolean`; codes restricted to `student.roll.correct` and `student.roll.approve`, existing ACS scope, active real INDIVIDUAL and correct role/assignment | `schoolos_authz_reader`; narrow student/workflow/read executor EXECUTE only |
| `app_private.d1_roll_correct_policy` | `(p_source_section uuid) RETURNS TABLE(policy_id uuid,route_mode text,campus_id uuid)`; exactly one effective policy, source Campus from immutable Enrollment path; DIRECT and APPROVAL each unambiguous | authz reader, no client invocation |
| `app_private.d1_roll_correct_prelock` | exact source School+policy+allocator+Student prelock based on typed source IDs, ordered with broader D1 integrations (NOT by trusting caller mode); returns typed context with reselect-after-wait | student/workflow executor; integration must approve complete source/MOVE/END shared lock graph first |
| `app_private.d1_roll_correct_source_context` | validated named Student/Enrollment/Roll source, immutable Section/Enrollment date, Roll start/policy/old numeric, open active PRIMARY, version; current business date/source-policy valid under RC-03 | student/workflow executor |
| `app_private.d1_roll_correct_effect` | protected typed source close+successor insert+allocator high-water reservation in one transaction; output original/new UUIDs, date, versions/ancestry; forbidden unless authorized handler context active | student/workflow executor ONLY; no public DML |
| `app_private.d1_roll_correct_receipt` | `(kind text,actor uuid,operation uuid,key text,hash bytea,expected_target_version bigint,request_id uuid,expected_request_version bigint,state text,result_kind text,result_ref uuid,summary jsonb,error_code text) RETURNS uuid`; 13-argument analogue of END evidence writer | evidence writer; execute student/workflow executors, no public |
| `app_private.d1_roll_correct_result_rows_match_exact` | `(p_student uuid,p_enrollment uuid,p_source_roll uuid,p_successor_roll uuid,p_summary jsonb) RETURNS boolean`, strict immutable relational proof below; **no active-head test** | domain executor + minimal schema-owner EXECUTE for application guard |
| `app_private.d1_roll_correct_result_matches` | above proof + current actor/target disclosure (do not trust result JSON alone); may have separate source-context args to avoid reading arbitrary historical data | student/workflow executor only |
| `app_private.d1_roll_correct_reviews_live`, `d1_roll_correct_candidates` | exact request/step and configured `D1_REVIEWER_ROLE_SCOPE`, reviewer permission `student.roll.approve`, Person separation, current grants | authz reader/workflow/read roles as reviewed |
| `app_private.d1_roll_correct_application_receipt_guard` | BEFORE INSERT on existing `approval_applications`, only for operation `student.roll.correct`, validates typed request/apply receipt/result and retained Roll proof | schema owner; no public EXECUTE; no generic Foundation trigger alteration |
| `app_private.d1_roll_correct_audit`, `d1_roll_correct_event` | narrow allowlisted audit and one selected `enrollment.roll_corrected` outbox on accepted effect; no broad reason/old/new values | evidence writer; narrow student/workflow EXECUTE |

These names are **intended package-local additions**, not permission to replace shared `d1_p1_route`, `d1_guard_crossrow`, `d1_enrollment_place_allocate_roll`, existing Foundation workflow functions or trigger. Future executor/definer grants must be independently reviewed against final ordered D1 SQL; SECURITY DEFINER + dynamic permissions **must not** inherit schema-owner privileges accidentally. Public wrappers use exactly `REVOKE ALL ... FROM PUBLIC,anon,service_role` and `GRANT EXECUTE ... TO authenticated` only after operation approval, with existing current-principal binding. No invocation while operation disabled.

## 3. Canonical idempotency and immutable approval snapshots

The existing `d1_enrollment_end_command_context` proves the accepted pattern: typed `d1_jcs_typed(jsonb_build_object(...))`, `sha256(convert_to(...,'UTF8'))`, `command_receipts` namespace `(principal_id,operation_id,idempotency_key)`; Foundation SHARED auth lock `(71001,1)`, derived `(71002,resource)` advisory and receipt lookup. **Recommend reusing this same pattern, not the endpoint's network retry timestamp or a new table.**

**Fixed caller-intent canonical positional array** for DIRECT/submit, using validated typed SQL values in this exact order:

```text
[student_id,expected_student_version::text,source_enrollment_id,
 expected_source_section_id,expected_enrollment_effective_from,
 source_roll_allocation_id,expected_source_roll_effective_from,
 expected_source_policy_revision_id,expected_old_numeric_value::text,
 requested_numeric_value::text,reason]
```

11 elements (the **idempotency_key** is bound separately in hash envelope, not repeated in array); all typed positions required, no floating numeric serialization. `reason` is nonblank restricted text and is hashed exactly as stored after whatever normalization the owner approves; default recommendation is **validate nonblank but do not silently trim or canonicalize away meaningful reason differences**. `NULL`, wrong-length array, unknown kind, missing/blank idempotency key and unsupported version fail before receipts. The envelope is `{canonicalization_version:1,operation_code:'student.roll.correct',operation_contract_version:'1',operation_id:<UUID>,command_kind,principal_id:<UUID>,intent:<fixed array>,idempotency_key}`. Hash with existing `d1_jcs_typed` encoding and SHA-256.

**No volatile current date in caller-input hash.** The actual effect date is server-derived *at apply* under the locked business-date rule; on next-day exact-key retry, it is read from retained receipt and corrected row instead of recomputing equality against today's date. Submit never silently commits the correction date.

**REVIEW intent:** fixed four elements `[request_id,decision,expected_request_version::text,review_reason]`; decision in `APPROVE|REJECT`. **APPLY intent:** exactly two `[request_id,expected_request_version::text]`. Those calls use their own actor+operation+key receipt namespace (not requester key) and existing Foundation request lock.

**APPROVAL old_snapshot** (fixed exact JSON keys; values server-verified at submission; types validated again at review/apply):
`student_id,source_enrollment_id,source_section_offering_id,source_enrollment_effective_from,source_roll_allocation_id,source_roll_effective_from,source_policy_revision_id,source_old_numeric_value,source_roll_origin_allocation_id` (nullable origin stored explicitly), plus immutably bound Student target/version and Campus in `approval_requests` typed columns; do **not** invent HE Roll row version.
**requested_payload:** exact one key `proposed_numeric_value` with BIGINT-safe canonical storage (`::text` strongly recommended in JSON payload); actual `reason` in dedicated restricted `approval_requests.reason`, not payload. Source-roll `effective_until=NULL`, Enrollment ACTIVE/PRIMARY and open head are **apply-time predicates**, not mutable `old_snapshot` fields to rewrite.
**Request state:** submit → `PENDING`; review sequence `PENDING` with intermediate steps → `APPROVED` or `REJECTED`; explicit apply → `EXECUTED` or deterministic `INVALIDATED`; no Roll effect for any pre-apply state.

**Replay precedence:** under verified actor/key/receipt lock validate *typed hash + command_kind* first. If a matching terminal receipt exists, decide outcome from **persisted immutable evidence** and current disclosure authority, not from today's source open state, Student version, live policy mode or new number availability. An unrelated later School policy replacement must not rewrite a successful receipt. If same key changes any typed field/reason/kind → hard conflict, never new domain mutation. All receipt lookups are by current authenticated Principal; do not accept arbitrary receipt UUIDs from clients.

## 4. EXACT proposed successful DIRECT receipt and verifier

**Recommended fixed result kind:** `D1_STUDENT_ROLL_CORRECT` — **candidate pending RC-07**, not a registered enabled code. **result_ref** = *new corrected Roll allocation UUID*, **not** Enrollment UUID or source Roll UUID. This distinguishes one correction from a later one on the same Enrollment. `command_kind='student.roll.correct'`, `state='SUCCEEDED'`, expected target version = request Student version, request ID NULL, and `result_summary` has **exactly these 12 keys**, no additional broad request JSON:

```json
{
  "student_id": "<uuid>",
  "enrollment_id": "<uuid>",
  "source_roll_allocation_id": "<uuid>",
  "corrected_roll_allocation_id": "<uuid>",
  "source_policy_revision_id": "<uuid>",
  "old_numeric_value": "12001",
  "new_numeric_value": "12009",
  "source_roll_effective_from": "2026-10-01",
  "correction_effective_from": "2026-10-19",
  "student_version": "9",
  "section_offering_id": "<uuid>",
  "source_enrollment_effective_from": "2026-10-01"
}
```

The values are **illustrative types only**; UUIDs are placeholders, not live payload. Numeric and version fields stored as decimal strings avoid JSON double-precision ambiguity. `p_reason` is excluded from this summary, broad outbox and audit details, but exact reason is retained in the restricted Roll successor and original input digest/request.

**Verifier `d1_roll_correct_result_rows_match_exact` (strict, failure → FALSE, never rewrite)**:
1. `summary` object with exactly 12 allowlisted keys; strict parse and limits, no extra values, stable case; typed expected Student/Enrollment/source/successor IDs must match args, `receipt.result_ref = corrected_roll_allocation_id`, `result_kind` fixed, `command_kind` and receipt state matched by caller. Reject malformed bigint, date, UUID as `false` (catch only designated parse exceptions, not lock/DB infrastructure).
2. Stored immutable source R0 exists, `R0.id=summary.source_roll_allocation_id`, `student_id`, `enrollment_id`, `policy_revision_id`, `numeric_value=old`, `effective_from=expected_source_start`, **`R0.effective_until=summary.correction_effective_from`** and `ended_at/ended_by` non-null. Earlier source can itself be a corrected successor; it may later have a descendant, but its committed correction close boundary remains immutable.
3. Stored immutable correction successor R1 exists, `R1.id=summary.corrected_roll_allocation_id`, `R1.student_id=R0.student_id`, `R1.enrollment_id=R0.enrollment_id`, `R1.policy_revision_id=R0.policy_revision_id`, `R1.supersedes_id=R0.id`, `R1.numeric_value=new`, `R1.effective_from=R0.effective_until`, **`R1.origin_allocation_id IS NOT DISTINCT FROM R0.origin_allocation_id` only if RC-04 approved**, `R1.correction_reason` nonblank **and exactly equals the typed original caller reason (DIRECT), or `approval_requests.reason` (approved APPLY), after the expressly approved normalization rule**. This equality must be checked privately, not exposed in result summary. `new<>old`. Ensure no second source successor and no conflicting numeric ownership by reviewing accepted commit invariant; do not recompute future *current* collision at replay.
4. Retained named Enrollment E1 exists with original Student/Section/start matching summary; its `placement_kind='PRIMARY'` and original School/policy ancestry match; **do not require E1 ACTIVE, E1.effective_until IS NULL, R1.effective_until IS NULL, R1 unsuperseded or Student's current row_version=old Student version**. Those may change legally via later CORRECT/MOVE/END. Do not demand original source policy still active.
5. Link the actor/key/operation/hash to one SUCCEEDED receipt, verify `created_by`/evidence ownership under approved fixed writer semantics, and—where result-proof visibility permits—exactly one selected outbox entry with receipt ID and ordinal 1. Never return receipt details to raw authenticated caller; wrapper separately applies current authority policy. Where needed, the schema-owner `approval_applications` guard calls **only the narrow private row-verifier**, not a check that requires current actor identity (a trigger's actor can be different from the reviewed user).
6. **Important pending decision:** proposed immutable witness doesn't store immutable command-receipt FK on R1. Correlate through existing receipt-to-result reference + typed row proof and audit/outbox `command_receipt_id` (not untrusted JSON alone). Confirm explicit uniqueness and secure receipt/result provenance enforcement exists before activation; immutable row identity plus a receipt result pointer alone does not prove authenticated command origin against privileged misbinding; if they do not, require an integrator-owned exact uniqueness/evidence plan rather than adding a hidden new HE column.

**Required durable replay:** R0→R1 at date D1; next day R1→R2 at D2; later MOVE E1→E2 carries latest R2; later END closes E2. Every earlier original receipt still verifies its own Rn/Rn+1 pair using retained boundary Dn and immutable summary, with zero additional UPDATE, INSERT, counter advance, audit or event. **Separate current authorization/disclosure check** gates whether caller may receive the bounded old-number result at replay after transfer or revocation; approval to expose historic values is RC-07/08 pending, and a missing current placement does not grant fallback access.

## 5. APPROVAL receipt/evidence shapes and application guard

| Phase | `command_kind` / result_kind candidate | `result_ref` and exact summary | Durable rule |
|---|---|---|---|
| SUBMIT | `request.submit` / `D1_STUDENT_ROLL_CORRECT_REQUEST` | request UUID, `{request_version:<decimal-string>,state:'PENDING'}` | Submitted receipt remains replayable even when request later APPROVED/EXECUTED; verify original request and submission transition/immutable payload, **do not demand current PENDING** |
| REVIEW | `request.review` / `D1_STUDENT_ROLL_CORRECT_REVIEW` | request UUID, `{request_version:<decimal-string>,state:<'PENDING'|'APPROVED'|'REJECTED'>}` | Verify exact actor's stored review decision/expected version/reviewer assignment and original review receipt. Later APPLY does not alter review success |
| APPLY success | `request.apply` / `D1_STUDENT_ROLL_CORRECT` | corrected Roll UUID, **12-key base summary** plus exactly `request_version:<string>`, `state:'EXECUTED'` (14 total) | `approval_requests.state='EXECUTED'`; one `approval_applications` row binds request, operation, command receipt, Student expected version, corrected Roll result_ref. Strict application-guard checks both receipt and original approved source/requested value and `result_rows_match_exact` |
| APPLY deterministic stale | `request.apply` / NULL (REJECTED) | result_ref NULL; `{request_version:<string>,state:'INVALIDATED'}`, fixed typed `error_code` | Exactly one `APPROVED→INVALIDATED` transition and rejected apply receipt; no domain application, correction event or counter update. Rejected terminal apply receipt can replay without reattempting mutation |

**Review authorization:** requester = active authenticated individual with current `student.roll.correct` scope on exact source; reviewer = distinct **Person** with active `student.roll.approve` scope AND configured active role and exact OPEN step assignment reason `D1_REVIEWER_ROLE_SCOPE`. `APPROVE` only advances workflow; it never calls `d1_roll_correct_effect`. `request.apply` permits requester or explicitly qualified final approver per frozen Foundation contract, but it **must** prove requester remains currently authorized and all prior reviewers remain live and separated. Exact authorized apply actor choices require **RC-06 approval**; do not assume every administrator can apply.

**Read-only request-view participants:** REQUESTER, OPEN_REVIEWER, DECIDED_REVIEWER, FINAL_APPROVER, each independently revalidated for exact source Section, reviewed policy role, request participation and current scope. Returned old/new numeric values disclose personal Student data; require source-context scope and, if the School chooses, a separate existing `student.roll_history.view` for replaying historical values. Which party can view the free-text request reason is a pending privacy choice; default is **not in this RPC**. Different campus transfer or ceased Student enrollment must **not** silently widen historic viewing rights.

**Application receipt guard pseudo-contract** (no executable trigger):
```text
IF NEW.operation_id refers to student.roll.correct:
  req := approved request by NEW.request_id
  rec := command receipt by NEW.command_receipt_id
  REQUIRE req.operation_id = NEW.operation_id
  REQUIRE req.state = EXECUTED AND rec.command_kind = request.apply
  REQUIRE rec.state = SUCCEEDED AND rec.result_kind = approved correction kind
  REQUIRE rec.request_id = req.id AND rec.operation_id = NEW.operation_id
  REQUIRE rec.result_ref = NEW.result_ref = retained corrected Roll UUID
  REQUIRE NEW.applied_target_version = req.expected_target_version
  REQUIRE rec.expected_target_version = req.expected_target_version
  REQUIRE rec.result_summary keys = (12 keys + request_version + state)
  REQUIRE rec.result_summary.state = EXECUTED
  REQUIRE rec.result_summary.request_version = req.row_version
  REQUIRE stripped 12-key summary matches *both* immutable approved request source/payload
          AND d1_roll_correct_result_rows_match_exact(...)
  REQUIRE no other application/result duplication for this approved request
  FAIL CLOSED otherwise; no arbitrary input or schema-owner raw JSON disclosure
```
**Check original decision evidence:** the verifier should prove the immutable `source_roll_allocation_id`, expected source policy/number and `requested_payload.proposed_numeric_value` in the exact approved `approval_requests`; just matching Roll pair without the original approved proposal would allow result-ref misbinding.

## 6. DIRECT, SUBMIT, REVIEW and APPLY exact command schedule

| Entry point | Atomic lock/authority and effect sequence | Terminal write / refusal |
|---|---|---|
| DIRECT `app.d1_correct_student_roll` | typed validation → verified actor/operation + canonical intent + Foundation SHARED auth/idempotency receipt prefix → current Section ACS grant and **DIRECT** policy → if terminal receipt, verify history/current replay disclosure → integration-approved **School→source policy→source allocator→Student→academic ancestors→Enrollment→Roll** union prelock → fresh source/route/grant/date/collision check → one-way close R0 / append R1 / optional high-water advancement | One `SUCCEEDED` correction receipt, one audit and `enrollment.roll_corrected` outbox with minimal IDs; other contexts deny. No BEGIN/COMMIT inside function; caller statement transaction atomic. |
| SUBMIT `app.d1_submit_student_roll_correction` | identical typed source/number auth, policy **APPROVAL**, full prelock/revalidation → create reviewed immutable old_snapshot+requested_payload/restricted reason and exact step list/candidates in Foundation workflow | Request PENDING, submit receipt/audit; **no correction, counter, application or corrected event**. |
| REVIEW `app.d1_review_student_roll_correction` | command prefix, request/version + effective stored source Campus policy, live exact reviewer role/grant/step, different Person; record APPROVE or REJECT. Rechecks reason validity and typed snapshot structure | Review receipt/audit, state PENDING/APPROVED/REJECTED; no Roll effect. If terminal same-key review replay, validate exact retained decision, not current OPEN step. |
| APPLY `app.d1_apply_student_roll_correction` | command prefix, request/version/participant check. **Terminal receipt handled before fresh effect validation** (with current disclosure). For new approved apply recheck original requester/role policy/reviewer grants; acquire full source prelock before Student; revalidate immutable approved source and apply-time server date; check numeric namespace/counter and source's policy effective interval | Valid: append Roll/advance counter/EXECUTED transition + receipt/application/audit/event **in one transaction**. Deterministic stale: INVALIDATED + rejected receipt/transition/audit only. Unexpected SQL error: **rollback** and leave APPROVED retryable. |

**NO approval-as-mutation:** reviewer `APPROVE` cannot change `roll_allocations`; approved request still requires separate command and correct fresh approval version.

## 7. Proposed deterministic stale / denial decision table (literal codes NOT frozen)

| Source/event at fresh locked attempt | DIRECT / SUBMIT | New APPROVED APPLY | Exact-key terminal replay |
|---|---|---|---|
| No verified actor, disabled operation/permission, insufficient actor scope | DENY (no domain receipt on auth failure) | Usually deny caller access; if actor is authorized to operate the reviewed apply but **requester** grant is stale, `INVALIDATED` with fixed code | Fail closed disclosure, do not erase receipt |
| Current route missing/ambiguous/wrong DIRECT/APPROVAL, stored policy retired | DENY `D1_ROLL_CORRECT_ROUTE_STALE` | `INVALIDATED`: `D1_ROLL_CORRECT_ROUTE_STALE` | Do not require old policy currently active to prove historic result; current permission/disclosure still required |
| Student expected row_version drift | DENY `D1_ROLL_CORRECT_STUDENT_VERSION_STALE` | `INVALIDATED` same code | Ignore current Student version for historical fact |
| Enrollment not latest ACTIVE PRIMARY / wrong Section, start or School | DENY `D1_ROLL_CORRECT_SOURCE_STALE` | `INVALIDATED` same code | Retained Enrollment may now be ENDED; verify original facts |
| Source Roll now ended, superseded, wrong policy or old numeric | DENY `D1_ROLL_CORRECT_SOURCE_ROLL_STALE` | `INVALIDATED` same code | Source was originally closed by correction as expected; not a failure |
| Source roll `effective_from` same as apply date (zero-length), candidate no-op | DENY `D1_ROLL_CORRECT_ZERO_LENGTH` or `D1_ROLL_CORRECT_SAME_VALUE` | `INVALIDATED` corresponding code | Actual committed correction effective date is immutable receipt fact |
| Source policy revision ended before apply date, or replacement makes r1 successor illegal | DENY `D1_ROLL_CORRECT_POLICY_OUT_OF_INTERVAL` | `INVALIDATED` same code | Historical r1 need not remain effective today |
| Numeric already owned by another Student (PS) or overlaps other Student in same AC R+Offering | DENY `D1_ROLL_CORRECT_NUMERIC_OWNED` | `INVALIDATED` same code | Do not re-run a later mutable availability predicate |
| Reviewer assignment/grant revoked, policy step/reviewer Person changed | SUBMIT/REVIEW deny current review; no effect | `INVALIDATED`: `D1_ROLL_CORRECT_REVIEW_AUTHORITY_STALE` if original apply actor may legally invalidate | Historical review proof stays retained; disclosure separately gated |
| Competing CORRECT/MOVE/END closes source first | DENY `D1_ROLL_CORRECT_SOURCE_ROLL_STALE` | `INVALIDATED` same code | Original receipt proof remains valid across later MOVE/END |
| Malformed approved request, corrupted receipt/application evidence, unexpected unique/FK/ACL failure, deadlock, timeout | RAISE; rollback; never blind repair | **ROLLBACK / remain APPROVED**, not INVALIDATED on generic `WHEN OTHERS` | Fail closed on malformed retained result (do not mutate or forge success) |

**Precise fail-closed difference:** product stale changes discovered through expected typed predicates may persist **INVALIDATED** only when authorized apply actor and workflow state are valid; a caller failing its *own* access check generally receives a denial, not a power to invalidate someone else's request. An unexpected database error is never mapped into a successful/rejected apply receipt. No uncontrolled SQL exception catch for classification.

## 8. Integration compatibility, test inventory and independent audit gate

**Required integration-owned changes (DB-01 does not edit):**
1. DB-03/D1 Enrollment allocator owner: align final `d1_enrollment_place_allocate_roll` *different-Student persistent* candidate scan with **all retained historic School-wide persistent numbers**, if RP-03/RC-02 approve permanent ownership, while preserving same-Student unsuperseded head lookup; retain M version trigger semantics. Old A 12001→12009, B's new placement must skip A's old 12001 rather than fail downstream guard.
2. D1 integration owner with DB-03: final MOVE source+destination union prelock sorted policy UUID/allocator UUID **before Student**; END source allocator prelock before Student; FINAL `d1_guard_effective_history` on Roll update reacquires exact School/policy/allocator. The existing MOVE **destination** prelock alone does not prove **source** consistency; END currently lacks it. Require two independent PostgreSQL backend lock waits and `pg_blocking_pids` evidence, not sleep-only simulations.
3. DB-02 PR #101 owner: RP-02/03/07 effective policy/correction after policy cutover, PS→AC→PS historic owner carry, counters, academic reuse, and policy replacement races; no silent adoption of its unsigned recommendations.

**Minimum future acceptance and fault injections (all **unexecuted**):**
- API-01 every RPC signature/canonical array exact arity, valid bigint-as-string, absence of client Campus/School/mode/origin/effective date, invalid null/blank/negative/overflow, same key with changed reason.
- AUTH-01 DIRECT under APPROVAL and submit under DIRECT fail; ALL/CAMPUS/CLASS/SECTION correct ancestry, wrong-campus and FAMILY deny; active configured Person separation, reviewer role/step and live permission recheck; participant checked read returns only reviewed columns.
- HIST-01 genuine P0 Student→R0, DIRECT R0→R1, second-day R1→R2 and third-day R2→R3; same Enrollment; MOVED R3→R4 origin; END; old Roll numeric and `supersedes` never rewritten. Constraints IMMEDIATE.
- REC-01 exact 12-key immutable base/result_ref proof; terminal DIRECT and apply replays after later correction/MOVE/END, after server midnight, after revocation; missing outbox/app receipt or wrong result_ref rejects. Same-key replay does not change receipt count, counter, histories or outbox.
- WF-01 SUBMIT no effect, REVIEW no effect, valid reviewed APPLY one effect; no-op and duplicate provisional roll, rejection and stale approved application; distinct review receipt remains replayable after EXECUTED.
- ERR-01 deterministic INVALIDATED uses one `APPROVED→INVALIDATED` transition/rejected receipt/no correction event; forced infra error rolls back leaving APPROVED; spoofed actor/approval payload/application link fails.
- CON-01 two-backend CORRECT/CORRECT, CORRECT/MOVE, CORRECT/END, CORRECT/allocator-ISSUE, CORRECT/policy-REPLACE, CORRECT/grant-revocation, same-number two Students, authenticated terminal replay; reverse arrival order; `pg_stat_activity.wait_event_type`, `pg_blocking_pids` and true row/advisory locks + post-commit invariant audit.
- REG-01 unchanged suite #65 fail-closed until separately approved activation; #61/#62/#63 placement/MOVE/END, #37/#38 policy, frozen Foundation 220 assertions, all D1 FORCE RLS and exact-head static owner/ACL guard. No hosted database, no Migration 10 application.

**Independent design self-review:** (a) success result identifies a *new Roll row*, not overloaded Enrollment; (b) old numeric/source ID/policy explicit; (c) source effective_from and correction date separated; (d) receipt hash stable across midnight; (e) strong strict 12-key row proof remains valid after a later close/supersession; (f) request application guard binds approved source and proposed value, not only current rows; (g) denial cannot invalidate on caller's lost authorization; (h) broad outbox excludes numeric/reason; (i) no live SQL, fake PASS, or new operation rights.

## 9. Owner approval and safe next DB-01 task

| Pending decision | Explicit signoff necessary before runnable implementation |
|---|---|
| **RC-01** | Approve 12-field DIRECT/submit named source snapshot, positive Student expected version, exact Section, policy, old numeric and no inference from display; changes to public arity/response must be deliberate. |
| **RC-02/RC-05** | Approve manual bigint, School-wide **permanent** PS historical ownership vs explicit reuse ADR, AC exact revision+Offering overlap and allocator high-water, and shared candidate/guard repair ownership. |
| **RC-03** | Approve server-controlled current *apply* business date, exact School time-zone rule, strict positive date intervals, denial if stored source policy expired, and no backdated/same-day retry effect. |
| **RC-04** | Approve `supersedes=source`, inherited persistent `origin` and normal later MOVE's latest-head carry, preserving old rows. |
| **RC-06** | Approve proposed five public RPCs, DIRECT/APPROVAL source Campus policy, current ACS and Person-separated reviewer, authorized apply actor/checked read participants. |
| **RC-07** | Approve immutable `d1_jcs_typed` 11-slot source array, stable no-date hash, `D1_STUDENT_ROLL_CORRECT` result kind, exact summary keys, strict verifier, selected event and private reason/disclosure policy. |
| **RC-08** | Approve historical terminal receipt replay after new CORRECT/MOVE/END, separate live disclosure, precise deterministic INVALIDATED behavior and shared prelock resolution. |
| **RP-02/RP-03/RP-07** | DB-02 owner signs policy date/namespace/reuse/reentry and locking before correction SQL activation. |
| **Integration source/allocator patches** | D1/DB-03 owner accepts revised shared full-history candidate scan and complete source+destination prelock. |

**Stage ledger:** Product contract **PENDING**; physical allocator/lock compatibility **BLOCKED by integration + DB-02**; DB-01 runnable SQL **NOT AUTHORIZED**; P1 authorization acceptance **NOT STARTED**; durable replay/concurrency tests **NOT STARTED**; security review **NOT STARTED**; PR #100 **DRAFT / NOT INTEGRATION READY**.

**Next safe task after this exact API gate:** prepare a **DB-01-only, source-controlled, non-executable test and verifier specification** that can be handed to the eventual implementation owner, including fixed fixture taxonomy, actual SELECT predicates to prove receipt/result history, deterministic replay outcomes after MOVE/END and independently witnessed PostgreSQL lock schedules. If owner explicitly approves RC-01…RC-08 and the RP/integration dependencies, the next task can instead be a narrow implementation branch assigned solely to DB-01-owned new SQL fragments. **No SQL enabling or merge is implied by merely saying "Continue".**
