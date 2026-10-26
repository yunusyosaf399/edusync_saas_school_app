# DB02 G05 — accepted development contract freeze

Frozen 26 October 2026 for `student.roll_policy.change`. This is final **inactive development-source acceptance**. G06 remains the separate executable Migration 10, staged upgrade/rollback, operation enablement and production authorization gate. DB01 release and installed DB03/DB04 handoffs remain separate.

## Source and acceptance identity

| Evidence | Frozen identity |
|---|---|
| Owner-accepted implementation | PR #168, `f472f2abf3303ffef10d4744a4dd6af5735acc5e` |
| Acceptance mechanism | ADR-006; `db02_solo_maintainer_review_record_20261026.json`; owner `yunusyosaf399` explicitly replied “Yes” |
| Final tested candidate | PR #172, `64ce0e6afe2915a6e899a1402217d0d87e66ebaa` |
| Actual G04 successor merge | `5ba526123ff83b0cb3cd90eac06b12e244e51f01`, branch `integration/db02-reviewed-successor-20261026` |
| Identical candidate/merge tree | `a722a4ef83ea133d181cc2a4cc37d1dff2f0ac9c` |
| Static | [40266399670 — SUCCESS](https://github.com/yunusyosaf399/edusync_saas_school_app/actions/runs/40266399670) |
| Frozen Foundation | [40266399560 — SUCCESS](https://github.com/yunusyosaf399/edusync_saas_school_app/actions/runs/40266399560), 220/220 assertions |
| Disposable D1 runtime | [40266399667 — SUCCESS](https://github.com/yunusyosaf399/edusync_saas_school_app/actions/runs/40266399667), 112 suites / 4,292 assertions |

The three runs attach to the exact candidate SHA, not directly to the later merge SHA. GitHub merge parents and identical tree establish the merge's source equivalence. PR #171's failed date fixture is retained in G04's report; the final candidate repairs the fixture without changing business SQL. All 396 tooling tests pass. This documentation freeze changes no executable source, SQL suite, runtime harness, workflow or catalog; it reuses that exact-source proof rather than claiming new runtime execution on a documentation commit.

The companion [source inventory](db02_g05_contract_inventory_20261026.json) records final definitions for all 32 DB02 routines, signatures, owners, EXECUTE edges, literal exceptions, internal calls, typed code vocabulary, file hashes and the existing G02 composition manifest. Definitions are resolved in the complete lexically ordered draft chain; superseded I09/I10 “replay reserved for I11” bodies are not the final contract. Its literal exception inventory covers these DB02 routines, not every transitive Foundation/Academic/Student dependency or PostgreSQL integrity exception. The complete draft digest binds those dependencies.

## Business and API contract

One school owns its Supabase project; campuses do not define policy namespaces. The command requires a currently verified INDIVIDUAL Principal, enabled operation and permission, current School ALL/DIRECT authority and exactly one applicable global NULL-Campus Foundation P1 policy version UUID. Family identities, role names and historic grants confer no shortcut. The existing `app.d1_read_roll_policy(uuid)` remains a separate current-only permission-checked read.

DIRECT and SUBMIT take these exact ordered typed inputs:

```sql
p_school_id uuid, p_action text, p_source_policy_id uuid,
p_expected_source_revision integer, p_expected_source_mode text,
p_expected_source_start_value bigint, p_expected_source_effective_from date,
p_new_mode text, p_new_start_value bigint, p_reason text,
p_idempotency_key text
```

| Authenticated entry | Inputs | Output |
|---|---|---|
| `app.d1_change_student_roll_policy` | The 11 inputs above; DIRECT route only | Resulting policy revision UUID |
| `app.d1_submit_student_roll_policy_change` | The 11 inputs above; APPROVAL route only | `request_id uuid, request_version bigint` |
| `app.d1_read_student_roll_policy_request` | `p_request_id uuid` | Eleven typed fields listed below; unauthorized/malformed target returns zero rows |
| `app.d1_review_student_roll_policy_change` | `p_request_id uuid, p_decision text, p_expected_request_version bigint, p_reason text, p_idempotency_key text` | `request_id uuid, request_version bigint, request_state text` |
| `app.d1_apply_student_roll_policy_change` | `p_request_id uuid, p_expected_request_version bigint, p_idempotency_key text` | `request_id uuid, request_version bigint, request_state text, policy_revision_id uuid` |

The checked request projection is exactly `request_id`, `request_version`, `request_state`, `school_id`, `action`, `source_policy_id`, `source_revision`, `new_mode`, `new_start_value`, `trusted_business_date`, `participant_kind`. Access requires the currently authorized requester or currently assigned, OPEN and independently eligible reviewer. A previous reviewer assignment alone is insufficient.

INIT requires no policy history and all expected-source fields NULL; the server assigns revision 1. REPLACE requires the exact currently open source ID/revision/mode/start/effective-from, closes it once and appends its exact successor with revision +1. Its source effective date must precede the trusted School-local current date. There is no client cutover date or expected-until input; the private gate requires an open source. Only `PERSISTENT_STUDENT` and `ACADEMIC_CONTEXT` are accepted, with nonnegative bigint starts below the maximum bigint. Nonblank private reasons and bounded idempotency keys are required. END, RESUME, scheduling, backdating, campus-specific policy and empty same-day replacement intervals are deferred.

The server derives the business day from stored School timezone and real server time under the School lock. APPROVAL binds the trusted submission date; a later-day APPLY invalidates instead of rebasing. Current/future accepted Enrollment/Roll commitments that the cutover would reinterpret reject the change. No policy change renumbers, deletes, reparents or rewrites existing Roll history.

## Workflow, codes and atomic evidence

SUBMIT freezes the global P1 UUID, exact source, proposal, School-local date and requester; transitions DRAFT → SUBMITTED → PENDING and assigns live different-Person reviewers. REVIEW accepts APPROVE/REJECT at the exact PENDING version; intermediate steps open sequentially and final approval creates APPROVED, without policy effects. Rejection creates REJECTED. APPLY requires exact APPROVED version, current requester and reviewer authority, unchanged route/source/date and compatible allocators. Its caller must be the live requester or an actual approving reviewer with current approval authority.

| Phase | Receipt command / result kind | Committed outcome |
|---|---|---|
| DIRECT | `student.roll_policy.change` / `D1_STUDENT_ROLL_POLICY` | New revision, exact pools, one SUCCEEDED receipt, minimized audit, one changed event |
| SUBMIT | `request.submit` / `D1_STUDENT_ROLL_POLICY_REQUEST` | Request and frozen steps/reviewer assignments/transitions; one receipt/audit; no revision/pool/changed event |
| REVIEW | `request.review` / `D1_STUDENT_ROLL_POLICY_REVIEW` | Immutable decision, step/request transitions, one receipt/audit; no revision/pool/changed event |
| Successful APPLY | `request.apply` / `D1_STUDENT_ROLL_POLICY` | EXECUTED, revision/pools, one SUCCEEDED receipt, one application, audit, transition, one changed event |
| Stale APPLY | `request.apply`, no success result kind | INVALIDATED, one REJECTED receipt/audit/transition; no revision/pool/application/changed event |

The registered engineering-selected outbox code is exactly **`student.roll_policy_changed`**, aggregate `ROLL_POLICY`, schema version 1, ordinal 1. The audit discriminator is **`student.roll_policy.change`**. These codes are implementation selections accepted with the reviewed source, not literal codes spoken by the owner. Successful DIRECT/APPLY result summaries contain exactly these 14 keys:

```text
school_id, action, source_policy_id, source_revision, source_mode,
source_start_value, source_effective_from, policy_revision_id, revision,
mode, start_value, effective_from, selected_p1_version_id, allocator_pool_count
```

The outbox payload contains only `school_id`, `action`, `source_policy_id`, `policy_revision_id`, `revision`, `effective_from`. SUBMIT/REVIEW and invalidated APPLY summaries contain only `request_version` and `state`. The private reason remains in protected request/review/policy history as applicable and contributes to the canonical hash; it is absent from public returns, receipt summaries, broad audit and outbox. No schema field `command_receipt_id` is invented on policy history.

The final APPLY entry emits `DB02_APPLY_P1_STALE`, `DB02_APPLY_REQUESTER_REVOKED`, `DB02_APPLY_REVIEWER_REVOKED`, `DB02_APPLY_SOURCE_STALE` or `DB02_APPLY_DATE_STALE` for recognized stale conditions. `DB02_APPLY_ALLOCATOR_STALE` is allowlisted by evidence/replay helpers but is not currently assigned by that entry; do not promise it as an emitted public result. The inventory records exact private preflight/P1 codes and exceptions, including INIT history/source conflicts, missing/stale/same-day/successor/future-commitment/pool conflicts. Literal exception text is not a new structured public error API. Malformed input, unauthorized participants and unexpected SQL/integrity/deadlock/infrastructure errors raise and roll back; they are not silently converted into durable business invalidations.

Canonical JCS version 1 / SHA-256 receipt identity binds actor, operation, key and immutable intent. Shared phase shapes remain exactly DIRECT/SUBMIT 12 slots, REVIEW four and APPLY two. Changed intent conflicts. Matching terminal replay requires current authority and retained row-by-row request/decision/application/receipt/audit/transition proof; successful effects additionally verify the historical revision, pools and event. Later legal revisions do not rerun old effects. Restored authority can permit the same retained response; there is never a second receipt, revision, allocation, application or event.

## Allocator, ACL and lock invariants

Persistent pools use `(policy_revision_id, NULL)`; academic pools use `(policy_revision_id, class_offering_id)` across all Sections. New revision pools are provisioned atomically before use. All School-owned persistent numbers remain reserved across revisions, including corrected-away retained history; new persistent high-water honors start and historic ownership with overflow checks. Existing Students retain their persistent lineage. Academic numbers may repeat in distinct Offering namespaces. New eligible OPEN Offerings get their current academic pool through the accepted Academic lifecycle hook; existing counters are never reset by updates, archive or replay. Invalid OPEN ancestry fails closed. DB01 correction remains bound to the allocation's immutable policy; both correction/REPLACE and Offering/REPLACE winner orders are accepted by observed-lock tests.

The lock graph is Foundation `(71001,1)` SHARED → current Principal / receipt-idempotency prefix → School → relevant policy revisions and allocator pools in stable order → Student/academic parents → child histories/evidence. APPLY discovers immutable School identity before locking the approval request and locks School before that request or domain effect. Academic parents follow Campus → Academic Year → Class → Offering after School/policy/existing pool locks. Foundation administration uses the corresponding EXCLUSIVE fence. Recheck grants, global route UUID, source and effective date after waits. The inventory's function edges supplement, rather than replace, this lock-order contract.

All 32 DB02 routines are SECURITY DEFINER with pinned `pg_catalog,pg_temp`, reviewed NOLOGIN owners, no implicit PUBLIC/anon/service-role EXECUTE and no authenticated private EXECUTE. Only five fixed DB02 `app` entries are authenticated-callable; DIRECT is Student-owned and the four workflow/read entries Workflow-owned. Evidence writer owns shared receipt/evidence routines; schema owner owns the private application guard. Final receipt lookup retains only six named internal executor edges: Academic, Employee, Family, Student, Teaching and Workflow. No executor gains schema-owner membership or a broad privileged generic dispatcher.

All 34 D1 relations retain FORCE RLS; client raw private table reads/DML remain denied. T08 explicitly audits the 32 DB02 routines and nine relevant policy/allocator/Roll/approval/evidence relations. Full runtime's filtered aggregate is 599 functions / 581 definers / 167 app / 432 private, zero forbidden private client EXECUTE. Unfiltered static totals are 600 / 582 / 433 private: runtime's name filter excludes `app_private.db02_guard_roll_policy_approval_application`, which T08 explicitly covers. These are different documented inventories, not missing guard coverage.

## Disabled operation and remaining release gate

Suite `65_remaining_student_commands_fail_closed.sql` remains registered unchanged at 38 assertions, checks `student.roll_policy.change` operation/permission disabled, zero successful blocked-command receipts and raw policy/Roll DML denial. It passed in the final 112-suite runtime. Suite 95 additionally executes a disabled authenticated DIRECT denial before transaction-local enablement; suites 96–98 pin disabled defaults before approval fixtures. Positive suites and real races enable only disposable fixtures and roll back or discard their database. No disabled regression was removed, so restoration is unnecessary. Earlier suite comments calling these commands unimplemented are historical wording, not the current development implementation status.

G05 freezes the previously accepted source; it supplies no new owner response, independent reviewer, or deployment approval. ADR-006 applies only to DB02 P03/G03; business reviewers must still be different Persons. G06 must prepare and obtain separate authorization for executable migration order, populated upgrade/rollback and permission acceptance, staged authenticated operation enablement, and separately any production deployment. Migration 10 stays `.sql.draft`. Main and hosted Foundation migrations 1–9 are unchanged.
