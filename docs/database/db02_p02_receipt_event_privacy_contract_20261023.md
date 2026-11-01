# DB-02 P02 — Roll Policy receipt result, event and privacy contract

**Date:** 2026-10-23  
**Scope/status:** Completed P02 **engineering contract selection and field-level design**, NOT SQL implementation, runtime acceptance, external security approval, event registration or activation.  
**Owner:** DB-02. This branch is stacked on P01 draft PR #138; the shared evidence-writer PR #122 and other workstreams are unchanged.  
**Trackers:** DB-02 issue #69 (P02 complete as a *documented contract*; I06/I08–I11/T02–T03/T08/G03–G06 remain open); issue #131 (independent shared security review outstanding).

## 1. Authority and evidence, not retroactive owner quotation

The product owner selected School-wide, School-local **today-only INIT/REPLACE** and either DIRECT or independently reviewed APPROVAL, with old persistent Rolls retained. END, scheduling and retroactive changes are not first-release actions. The 2026-10-20 owner-choices document explicitly identifies the two proposed evidence strings below as **engineering selections made under a completion instruction**, NOT literal names spoken by the owner.

P02 fixes the engineering contract as:
- **Successful Roll Policy effect receipt result_kind:** D1_STUDENT_ROLL_POLICY
- **Successful policy-change outbox event_type:** student.roll_policy_changed (schema_version=1)
- **Private security/business audit event_type:** student.roll_policy.change (the operation discriminator; distinct from the outbox event)
- **Successful SUBMIT receipt result_kind:** D1_STUDENT_ROLL_POLICY_REQUEST
- **Successful REVIEW receipt result_kind:** D1_STUDENT_ROLL_POLICY_REVIEW

The last two phase-specific codes are new **P02 engineering choices**, modeled on the existing family relationship REQUEST/REVIEW and enrollment MOVE REQUEST/REVIEW receipts. They are not already registered or proven in SQL. DIRECT and a separately authorized APPLY both use D1_STUDENT_ROLL_POLICY *only if* the policy change actually commits. An APPLY also inserts exactly one Foundation approval_applications row for the approved request, linked to its successful receipt.

The two other-phase codes are receipt result kinds, **not new outbox events**. SUBMIT/REVIEW/APPROVED, rejected intent, stale invalidation, replay, failed preflight and read-only queries must never emit student.roll_policy_changed. Any future event schema v2 or alternative event code requires a separately versioned change decision; do not infer a name from older physical catalog illustrations.

**Boundary:** The codes and shapes here are an implementation-ready draft contract. The actual command/result writer, event allowlist/registration, exact approval-shape receipt allowlist and integrated tests are still missing. Product-direction authorization to document/select codes does not waive independent security review or release approval.

## 2. Source alignment and immutable receipt identity

Source precedent:
- docs/database/20261020_owner_choices_and_dependency_resolution.md (actual user choice vs engineering literal distinction).
- docs/database/db02_shared_receipt_integration_candidate_20261020.md and PR #122 (exact 12-slot DIRECT/SUBMIT typed receipt intent, existing verified actor, JCS/SHA-256, idempotency, **no REVIEW/APPLY allowlist**).
- docs/database/05_foundation_physical_catalog.md, command_receipts F25, audit_events F19, outbox_events F20 and approval_applications F26/F25 (immutable terminal receipt, evidence fields and private exposure).
- effect26_04_enrollment_move_evidence.sql.draft and effect30_06_family_relationship_evidence.sql.draft (existing protected receipt, private audit and minimized event shapes); effect30_10_family_relationship_submit.sql.draft and effect30_12_family_relationship_review.sql.draft (separate request/review result kinds).
- db02_p01_academic_allocator_offerings_future_commitments_20261022.md (cutover/future-commitment rules) and existing effect43_01 source preflight (locks before effects).

Receipt contract for all phases:
1. Operation code exactly student.roll_policy.change, contract_version 1; command kinds exactly student.roll_policy.change (DIRECT), request.submit, request.review, request.apply as separately authorized and individually typed. A successful RECEIPT is never a synonym for a successful policy mutation.
2. Nonblank opaque idempotency_key length 1..200; current verified INDIVIDUAL Principal, operation ID and key identify a terminal receipt. Version 1 server-canonical SHA-256/JCS intent includes phase, exact School, action, frozen source, proposed mode/start, **private reason**, and server-derived global Foundation P1 policy version UUID. Never trust a caller-supplied UUID as current policy-selection authority. DIRECT and SUBMIT have the reviewed fixed 12-slot shape from PR #122. REVIEW/APPLY require **new, exact reviewed intent shapes** in I11, not a permissive fallback in receipt lookup.
3. READ COMMITTED, Foundation SHARED auth lock, receipt/idempotency lock, verified current actor, School/source/allocator locks and selected-policy recheck precede any effect. A reused key with different canonical hash conflicts. Identical terminal replays recheck live authority and historical result proof before returning a retained result; no revision/pool/application/audit/outbox duplication.
4. Terminal states are SUCCEEDED or deterministic REJECTED. No success-kind/result_ref for a rejected business command; error_code present, no success event. Infrastructure SQL error rolls back the whole attempt (no fictitious durable rejection). No invented row_version or command_receipt_id column on roll_policy_revisions.
5. The response and immutable receipt must be anchored to actual persisted UUIDs, not a supplied target name or a variable display/roll number.

### Phase-to-result matrix

| Phase | When SUCCEEDED | result_kind | result_ref | Business effect / outbox |
|---|---|---|---|---|
| DIRECT | Full locked INIT/REPLACE + new policy and required pools committed with receipt/audit | D1_STUDENT_ROLL_POLICY | New policy revision UUID | One event (see §4), atomic |
| SUBMIT | Foundation request reached PENDING with approved configured independent reviewers | D1_STUDENT_ROLL_POLICY_REQUEST | Foundation approval request UUID | **None**, no new policy or pools |
| REVIEW | Valid independent reviewer decision was retained through workflow transition | D1_STUDENT_ROLL_POLICY_REVIEW | Foundation approval request UUID | **None**, no new policy or pools |
| APPLY | Approved request reauthorized against exact original source/P1 UUID and real effect completed | D1_STUDENT_ROLL_POLICY | New policy revision UUID | One event; one unique approval_application |
| REJECTED / INVALIDATED | Deterministically refused/stale command, with the allowed Foundation terminal semantics | NULL (no success kind) | NULL | No policy/pool mutation or success event |

**Submit/review summary** restricted to the exact keys request_version (positive bigint) and state (one legally attained Foundation request state). Do not put old/new free-text reason, names, roll values or arbitrary request payload into receipt summaries. REVIEW must bind current assigned reviewer and the request's expected pre-review version in its canonical intent. APPLY receipt must bind request ID + expected request version and resolve the originally frozen P1/source intent from the authorized stored request, not trust fresh caller-selected source values.

## 3. Exact successful policy-change result proof

For DIRECT and APPLY, immutable command_receipts.result_kind **D1_STUDENT_ROLL_POLICY**, result_ref **new revision ID**, and result_summary is exactly one JSON object with these **14** fixed keys (no other keys):

| Key | Type | Binding / why |
|---|---|---|
| school_id | UUID string | Exact locked School |
| action | INIT or REPLACE | Validated change |
| source_policy_id | UUID string or JSON null | Null for INIT; exact old revision for REPLACE |
| source_revision | positive integer or JSON null | Null for INIT |
| source_mode | enum or JSON null | Null for INIT |
| source_start_value | nonnegative integer or JSON null | Null for INIT |
| source_effective_from | ISO date or JSON null | Null for INIT |
| policy_revision_id | UUID string | Equals result_ref and actual new HE revision id |
| revision | positive integer | INIT = 1; REPLACE = source revision + 1 |
| mode | PERSISTENT_STUDENT or ACADEMIC_CONTEXT | Exact new policy mode |
| start_value | nonnegative integer | Actual new minimum, not Student numeric allocation |
| effective_from | ISO School-local date | Actual cutover date |
| selected_p1_version_id | UUID string | Exact server-selected global Foundation policy version used at execution |
| allocator_pool_count | nonnegative integer | Equals actual set of newly provisioned distinct (revision,Offering/null) pools |

For REPLACE, prove old policy effective_until equals new effective_from, supersedes_id of new policy is the locked exact old source, and historical rows remain unmodified except the one permitted source closure. For INIT prove School has no retained previous policy and source fields are JSON null. Validate persisted School, source policy immutable identity/mode/start/effective_from, sequential revision, and the **exact newly provisioned allocator key set**, not just pool count. A replay after later valid revisions must validate the *original historical effect*, not require it to be today's active head. There is no free-form summary or broad JSON result.

The summary may contain policy **start_value** because command_receipts is SERVER ONLY and its authorized response is a purpose-bound typed projection; the broad outbox/audit allowlist below deliberately excludes start_value. Numeric Student Roll assignments, student/person names and private reason never appear in this summary.

### Receipt ↔ row verifier (required I06 implementation)

A dedicated private, fixed-signature verifier must join:
- receipt id + operation_id/version + verified original Principal; phase DIRECT or request.apply; terminal SUCCEEDED, exact kind and ref, typed 14-key summary;
- for APPLY, matching approved Foundation request, exact request/version predecessor, one unique approval_applications binding receipt and request and result_ref;
- new roll_policy_revisions record with matching School/action/date/revision/mode/start/source predecessor; source closure exactly once for REPLACE; actual mode-specific allocator rows and their School/Offering ancestry;
- exactly **one** private successful audit and exactly **one** policy_changed outbox event for this receipt, fixed event ordinal 1, common correlation ID, correct target/version/payload.
- no second SUCCEEDED policy effect receipt claiming the same new policy UUID.

Do **not** use merely the count of inserted policy rows, an unscoped UUID, a text event name or a receipt hash as sufficient proof. Define narrow SQL privileges, fixed search_path, current Principal/authorization and transaction ownership independently in implementation.

## 4. Business event registration contract

One new outbox event **only when a policy effect commits**:

| Envelope field | Fixed value / rule |
|---|---|
| event_type | student.roll_policy_changed |
| schema_version | 1 |
| aggregate_kind | ROLL_POLICY |
| aggregate_ref | New policy revision UUID |
| aggregate_version | New positive policy revision number |
| command_receipt_id | Same immutable SUCCEEDED DIRECT/APPLY receipt |
| event_ordinal | 1; UNIQUE (receipt, ordinal) |
| correlation_id | Same as matching private successful audit |
| created_by | Current verified INDIVIDUAL actor |
| payload | Exactly the six safe keys below; JSON object |
| occurred_at | Foundation server timestamp (not a client clock) |

**Exactly six payload keys:** school_id (UUID string), action (INIT/REPLACE), source_policy_id (UUID or JSON null), policy_revision_id (new UUID), revision (positive integer), effective_from (trusted School-local ISO date). No alternate property aliases, arbitrary nested blobs or raw approval payload. No per-allocator, per-Student or per-Offering event: the event is about the School's policy revision, not allocation notifications.

Register the event literal only in the reviewed domain evidence writer / typed allowlist and any reviewed event-consumer mapping that actually applies; do not invent a new Foundation table, widen a generic public event registration or enable live publication merely because the contract is written. Raw outbox stays SERVER ONLY; a future consumer must independently authorize projections. Future changes to schema or fields require a new schema_version and explicit compatibility tests.

## 5. Private audit and reason confidentiality

For every protected phase, private audit_events.event_type is **student.roll_policy.change** (not the outbox string); actor_id and created_by are the real current Principal, actor_kind INDIVIDUAL, source_kind API, target_kind SCHOOL and target_ref the School UUID. A successful DIRECT/APPLY audit uses target_version = new policy revision number; SUBMIT/REVIEW/REJECTED use nullable target_version if no domain policy revision changed. Correlate request_id and receipt_id via the existing columns (approval_request_id is NULL for DIRECT). **Do not claim APPROVED is an effect.**

- Audit authority_evidence contains only allowlisted operation, phase and selected global P1 version UUID; it is retained evidence, **not** permission to reauthorize replay. 
- Audit details contains only action, source_policy_id, policy_revision_id when one exists, revision when one exists, effective_from when the effect actually occurred and a narrow error_code on rejected attempts. Do not store the original 12-element intent array, raw reason, source/new start values, employee/user identifiers, School timezone, academic pool counters or Student identifiers in this broad security evidence.
- **Private business reason is required and nonblank** in the immutable roll_policy_revisions.reason of the created policy, and stored through Foundation approval_requests.reason only when the separately authorized request is submitted. It participates in the canonical intent hash, but is never copied to audit_events.reason, authority_evidence/details, outbox_events.payload, command_receipts.result_summary, notification/email/logs or unrestricted participant reads.
- Private role/permission-controlled request read may disclose a *separately approved minimal reason projection* to the actual request participants only; no unconditional requester-as-reader permission and no generic free-text JSON passthrough. No broad Roll Policy view right implies historical reason disclosure. Only purpose-authorized admin/audit paths may read the full retained history.
- **Never publish** Student ID, Person/Family identity, numeric or display Roll numbers, per-Student allocation IDs, correction_reason, historical row snapshots, full old/new policy JSON, idempotency key, canonical hash, actor grants, policy approval payload, arbitrary error messages or private reason. Outbox/audit are append-only and not public event streams.
- The code enforcing these fields must compare exact JSON key sets, type-check nullable source keys according to INIT/REPLACE, ensure no information leaks in errors or replay, and explicitly revoke public/anon/authenticated/service_role EXECUTE of new private helpers. Use the existing least-privilege Student/Workflow/evidence-writer ownership split.

The change to policy mode or minimum does not mutate or renumber a Student Roll, and neither audit nor event grants authority to perform subsequent Enrollment operations.

## 6. Acceptance matrix for I06 / I07–I11 / T01–T03 / T08

| Case | Expected verified outcome |
|---|---|
| P02-E01 DIRECT INIT | Exactly one revision + correct allocator pool(s) + one D1_STUDENT_ROLL_POLICY receipt + one successful audit + one student.roll_policy_changed event |
| P02-E02 DIRECT REPLACE | Exact old closure/new revision and 14-key summary; no historical allocation rewrite |
| P02-E03 APPROVAL SUBMIT | PENDING request; D1_STUDENT_ROLL_POLICY_REQUEST receipt; **zero** change event or new pool |
| P02-E04 REVIEW approves or rejects | D1_STUDENT_ROLL_POLICY_REVIEW receipt; no policy effect/event, reviewer independent Person |
| P02-E05 APPLY authorized | One new revision/pools; D1_STUDENT_ROLL_POLICY receipt; unique approval_application; exactly one event |
| P02-E06 stale/denied phase | REJECTED receipt only for deterministic allowed failures; no successful event, partial revision, allocator or application |
| P02-E07 lost response same key/hash | Return historical original effect after current authority and exact 14-key row verifier; no second event |
| P02-E08 same key different intent/reason | Hash conflict; cannot claim prior result or write second effect |
| P02-E09 later legitimate replacement then old replay | Original receipt/effect still verifiable via immutable ancestry, not today's current head |
| P02-E10 reason/Student number canary | Their raw text/value absent from audit details/reason, outbox, public read, summary, logs; only explicitly authorized private policy/request reason |
| P02-E11 type/shape integrity | Reject unexpected/missing/null/extra summary or event keys and wrong aggregate/ordinal/correlation |
| P02-E12 SQL rollback midway through evidence write | No policy, pool, receipt, successful audit, outbox or application row commits |
| P02-E13 raw ACL checks | anon/authenticated/service_role/PUBLIC cannot directly execute private evidence helpers or select raw private tables |
| P02-E14 unsupported phase | PR #122 still denies REVIEW/APPLY until separately reviewed exact intent shapes; no generic wildcard |
| P02-E15 policy-version mismatch at APPLY/replay | Current UUID/route and authority rechecked; no unauthorized replay or effect |
| P02-E16 receipt-forgery | Cross-actor/revision/School/result_ref, duplicate receipt/event, invalid source closure or wrong allocator set denied |

**Tests NOT run by P02 documentation-only work.** All cases require disposable PostgreSQL fixtures, ACL verification and true two-backend races where relevant, in their separately tracked implementation/test tasks.

## 7. Remaining dependencies and release stop

- I06 must implement and register the fixed result and event under the existing private evidence-writer boundary, with narrow definer grants and exact row proof; I08/I09/I10 implement the distinct Foundation workflow phases. I11 must separately add/approve REVIEW/APPLY shared receipt shapes; PR #122 currently accepts **DIRECT and SUBMIT only**.
- T01–T03/T08 must prove real behavior, private read/scope and replay; G02 must recompose latest DB-01/DB-02 and all other shared-owner overrides.
- Independent non-author shared-security reviewer signoff remains **unavailable/pending** on issue #131. No self-review may be recorded as external approval.
- Do not activate student.roll_policy.change, permission grants, hosted Supabase migrations, public RPC or outbox consumer based on this document. Migration 10 remains .sql.draft; no deployment, merge or change to DB-01/DB-03/DB-04 in P02.

**P02 completion definition:** exact selected literals, phase/result matrix, 14-key success receipt summary, six-key event payload and privacy/row-verifier/acceptance contract are recorded. Their **implementation and independent acceptance remain pending**, honestly tracked in I06/I08–I11/T03/T08/G03–G06.
