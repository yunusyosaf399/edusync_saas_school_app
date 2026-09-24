# Foundation Physical Design Review

**Status: review decisions SELECTED FOR SQL DRAFT, 2026-09-23. Documentation only.**
This is the requested architecture/security/database review of the existing 34-table proposal. Decisions below explicitly ACCEPT, ACCEPT WITH CHANGE, DEFER or REJECT the significant proposals, using the user's preferred architecture where consistent with repository authority. This is not a claim of human deployment sign-off, tested SQL or implemented security.

Authority: [AGENTS.md](../../AGENTS.md), [project context](../../CODEX_PROJECT_CONTEXT.md), [specification](../requirements/School_OS_SaaS_Master_Specification_v0.2.md), [invariants](DECISIONS_AND_INVARIANTS.md), [feature catalog](../requirements/FEATURE_CATALOG_AND_STATUS.md), [ADR-001](ADR-001-foundation-database-principles.md). Reviewed the complete Foundation conventions/entity/dependency/ERD/catalog/constraint, identity/RBAC/RLS, workflow/audit and test documents. Where conceptual alternatives differ, the explicit review decisions below supersede those alternatives for the files-only SQL draft; confirmed product invariants remain unchanged.

Affected engines: Data, Permission and Workflow foundations; audit, event/inbox, storage and deployment concerns. Automation/AI remain downstream permission-bound consumers; business-domain schemas and hardware remain absent. One school per project, campus scope, immutable historical actors, complete grants, protected corrections, on-demand PDFs and encrypted/conflict-aware future offline behavior remain invariants.

## 1. Decision register

| ID | Disposition | Proposal | Selected decision | Reason / consequence |
|---|---|---|---|---|
| R01 | ACCEPT WITH CHANGE | Identity and family boundary / T01,T03 | Keep Person != Principal != managed Auth. One non-retired INDIVIDUAL per Person; retain retired principals. FAMILY and SYSTEM cannot acquire staff/interactive authority. Add binding token cutoff and historical Auth UUID non-reassignment. | Physical family flag/composite FK chain prevents accidental mixing; current-state checks, recovery and trusted registry semantics remain necessary. No person merge. |
| R02 | ACCEPT | Physical conventions / T02 | PostgreSQL 15+ compatibility subset; app allowlisted reads/RPCs, app_private internal tables; UUID v4 server defaults; TEXT CHECK states; timestamptz instants, date business dates, IANA school timezone, UTC session convention. | No required extension, ENUM proliferation or UUID novelty. Business identifiers remain separate. Finance precision stays in its domain; existing conceptual NUMERIC suggestions are not finalized. |
| R03 | ACCEPT WITH CHANGE | Login aliases / T03 | Keep login_aliases. ASCII lowercase 3..32 restricted characters, exact C-collation uniqueness across retained aliases, no reuse; normalization and gateway restrictions below. | Supports email and school username login without password storage or anonymous mapping disclosure; Unicode alias expansion needs a later decision. |
| R04 | ACCEPT WITH CHANGE | RBAC, complete grants and intervals / T04 | Keep all six RBAC relations and matching composite keys. Replace unrevoked-row partial uniqueness on grants/assignments/scopes with serialized effective-interval non-overlap; add scheduled end to role-permission grants. | Natural expiry preserves revoked_at=NULL. Future cancellation and adjacent replacement work without false revocation. Database row constraints alone do not prove non-overlap; protected write protocol is mandatory. |
| R05 | ACCEPT WITH CHANGE | Approval baseline / T06 | Sequential, one effective decision per stage, no parallel/quorum/delegation/self-approval or Super Admin bypass. Freeze active policies and submitted intent. Replace ambiguous FAILED request state with explicit INVALIDATED for irrecoverable revalidation conflict. | APPROVED is not EXECUTED. Transient execution failures leave approved intent intact after rollback; deterministic lost-authority/stale-target invalidation requires a new request. |
| R06 | ACCEPT WITH CHANGE | Command and application / T07 | Terminal-only immutable SUCCEEDED/REJECTED receipts; no persisted ACCEPTED. Add command_kind to distinguish operation phases in canonical intent. Preserve unique request/application and request/receipt/operation FK matching. | No asynchronous stranded receipt state or mutable receipt row_version. Advisory serialization plus UNIQUE handles retries; no globally exactly-once claim. |
| R07 | ACCEPT | Immutable event and mutable consumer state / T08 | Keep outbox_events, event_consumer_deliveries and in-app notifications. At-least-once, fenced leases and idempotent consumers; no external calls inside effect transaction. | Consumer state is not audit or event truth; 60-second leases and bounded retries are explicit initial technical defaults. |
| R08 | DEFER | External channels / T08 | Exclude notification_channel_deliveries from first SQL draft. IN_APP preferences only initially; quiet_hours must be NULL. Later verified endpoint ownership and email/push channels are designed together. | 33 of the original 34 tables remain. This defers implementation of confirmed email/push product features; it does not cancel them or select a provider. |
| R09 | ACCEPT WITH CHANGE | Audit/retention / T10 | Retain protected history, immutable minimum actor/executor/context/outcome/version/correlation evidence, bounded redacted JSON; no ordinary delete/soft-delete or TTL. | No legal periods invented; no cryptographic tamper-proof claim against infrastructure owners. Archive/privacy operations require a separate reviewed process. |
| R10 | ACCEPT WITH CHANGE | Files / T11 | Private immutable object references and measured SHA-256/type/size, quarantine and replacement lineage. Exact limit 1 MiB = 1,048,576 bytes inclusive. | Master specification says approximately 1 MB, not a mandatory decimal byte count. Choose the user's preferred binary interpretation; SQL metadata constraints do not replace future adapter access controls. |
| R11 | ACCEPT | Bootstrap and school customization / T12 | Versioned deployment-owned permission/scope/operation manifest, purpose-bound SYSTEM actors, seed-once role templates and explicit school setup; deterministic insert/no-op/error behavior. | Do not overwrite customized roles/settings, restore revoked grants or seed business data. No secrets or human passwords in seeds. |
| R12 | ACCEPT WITH CHANGE | Exact FK graph and indexes / T02 | Select 33-table physical order and three named late FKs; retain justified indexes, remove revoke-only uniqueness and covered duplicate index proposals. | People/actor and school/year/logo cycles are real; receipt/request and audit/workflow cycles are not present in current FK graph. All required FKs validate before activation. |
| R13 | ACCEPT | Execution security / T04 | Separate NOLOGIN table owner/evaluator/command/evidence roles, FORCE RLS, exact EXECUTE/column grants, safe search_path, read-only non-recursive evaluators and shared/exclusive revoke serialization. | Definers are explicit bounded privilege transitions; no owner/service-key shortcut to user permissions. Actual privilege/managed service tests precede activation. |
| R14 | ACCEPT | Offline preparation / T09 | Retain UUID identities, expected row versions, terminal receipts and live reauthorization on replay; retain dedupe evidence without TTL. | Full sync cursors, tombstones, device registry, eligibility and encrypted cache implementation remain deferred; no critical last-write-wins default. |
| R15 | ACCEPT | Execution/test plan / T15 | Disposable rebuild, reviewed bootstrap, constraints, real non-owner RLS, commands, race/retry and version-N-to-N+1 history/customization tests. | No test tooling installed now. SQL-file readiness is not tested deployment readiness. |
| R16 | REJECT | Unsafe alternatives | Reject FAMILY staff conversion, client-authoritative IDs/claims, cross-combined scopes, fabricated revocation, arbitrary JSON/table mutation, ambiguous FAILED state, independently persisted ACCEPTED receipts and unvalidated endpoint ownership. | These are intentionally rejected paths, not open defaults. Future requirements must go through a new reviewed design. |

## 2. All 34 original tables reviewed

KEEP IN FOUNDATION SQL means inclusion in the next files-only draft, not permission to deploy or seed production. No table is merged solely to reduce count. MERGE / SIMPLIFY and REQUIRES DECISION were considered; no table requires an unresolved inclusion decision, and none should merge responsibilities. command_receipts is simplified in place.

| Original table | F mapping | Inclusion classification | Review disposition / reason |
|---|---|---|---|
| school_profiles | F01 | KEEP IN FOUNDATION SQL | ACCEPT; Singleton school identity and stable configuration. |
| campuses | F02 | KEEP IN FOUNDATION SQL | ACCEPT; Locations inside this school; never tenants. |
| rooms | F03 | KEEP IN FOUNDATION SQL | ACCEPT; Room anchors without timetable/bed allocation. |
| academic_years | F04 | KEEP IN FOUNDATION SQL | ACCEPT; School-wide dated academic history. |
| people | F05 | KEEP IN FOUNDATION SQL | ACCEPT; Human identity independent of credentials and business profiles. |
| principals | F06 | KEEP IN FOUNDATION SQL | ACCEPT WITH CHANGE; Durable accountable actors; flatten ACCOUNT subtype into INDIVIDUAL/FAMILY, retain SYSTEM. |
| principal_auth_bindings | F06 | KEEP IN FOUNDATION SQL | ACCEPT WITH CHANGE; One durable live-link slot per non-system principal to external managed Auth. |
| principal_binding_events | F07 | KEEP IN FOUNDATION SQL | ACCEPT WITH CHANGE; Immutable evidence for bind/unbind/recovery/relink operations. |
| login_aliases | F08 | KEEP IN FOUNDATION SQL | ACCEPT WITH CHANGE; Retained school-local username lookup through a protected gateway. |
| roles | F09 | KEEP IN FOUNDATION SQL | ACCEPT; Configurable roles with immutable family capability classification. |
| permissions | F10 | KEEP IN FOUNDATION SQL | ACCEPT; Deployment-owned action catalog, not editable action strings supplied by school clients. |
| role_permission_grants | F11 | KEEP IN FOUNDATION SQL | ACCEPT WITH CHANGE; Role-to-action grants with declarative family ceiling. |
| principal_role_assignments | F12 | KEEP IN FOUNDATION SQL | ACCEPT WITH CHANGE; Principal-bound role assignment and account context. |
| permission_scope_contracts | F10/F13 | KEEP IN FOUNDATION SQL | ACCEPT; Permission-specific allowlist of supported scope/resolver contracts. |
| assignment_permission_scopes | F13 | KEEP IN FOUNDATION SQL | ACCEPT WITH CHANGE; Complete role-assignment/action/scope chain, never a free scope UUID. |
| operation_contracts | F14/F16/F25 | KEEP IN FOUNDATION SQL | ACCEPT; Deployment-owned typed command registry shared by approval and receipt contracts. |
| approval_policy_versions | F14 | KEEP IN FOUNDATION SQL | ACCEPT WITH CHANGE; Immutable activated school/campus policy revision. |
| approval_step_templates | F15 | KEEP IN FOUNDATION SQL | ACCEPT WITH CHANGE; Ordered stages belonging to a policy version. |
| approval_requests | F16 | KEEP IN FOUNDATION SQL | ACCEPT WITH CHANGE; Frozen submitted intent; mutable controlled lifecycle projection. |
| approval_request_files | F16/F23 | KEEP IN FOUNDATION SQL | ACCEPT; Normalized frozen supporting evidence links. |
| approval_request_steps | F17 | KEEP IN FOUNDATION SQL | ACCEPT WITH CHANGE; Frozen instantiated stages with controlled current state. |
| approval_step_reviewers | F17 | KEEP IN FOUNDATION SQL | ACCEPT; Normalized reviewer candidates and eligibility history. |
| approval_reviews | F18 | KEEP IN FOUNDATION SQL | ACCEPT WITH CHANGE; Immutable signed-in reviewer decisions. |
| approval_transitions | F26 | KEEP IN FOUNDATION SQL | ACCEPT; Append-only request state transitions. |
| approval_applications | F26/F25 | KEEP IN FOUNDATION SQL | ACCEPT; Permanent one-successful-application evidence, separate from retries/transitions. |
| command_receipts | F25 | KEEP IN FOUNDATION SQL | ACCEPT WITH CHANGE; Durable deduplication and authorized replay of protected commands. |
| audit_events | F19 | KEEP IN FOUNDATION SQL | ACCEPT WITH CHANGE; Immutable security/business evidence, never queue state. |
| outbox_events | F20 | KEEP IN FOUNDATION SQL | ACCEPT; Immutable domain-event envelope committed with effect. |
| event_consumer_deliveries | F21 | KEEP IN FOUNDATION SQL | ACCEPT WITH CHANGE; Per-consumer retry/lease state separate from immutable event. |
| notifications | F22 | KEEP IN FOUNDATION SQL | ACCEPT; Principal-specific inbox projection with distinct account context. |
| notification_preferences | F27 | KEEP IN FOUNDATION SQL | ACCEPT WITH CHANGE; Versioned current preference row by principal/category/channel. |
| notification_channel_deliveries | F28 | DEFER TO LATER | DEFER R08; no verified endpoint FK. |
| file_objects | F23 | KEEP IN FOUNDATION SQL | ACCEPT WITH CHANGE; Provider-neutral uploaded-file metadata; bytes are externally managed. |
| setting_revisions | F24 | KEEP IN FOUNDATION SQL | ACCEPT; Append-only versioned non-secret configuration per school or campus. |

**Result: 33 kept, one deferred, zero merges, zero unresolved table-inclusion decisions.** In particular: aliases are needed for the confirmed username direction; consumer deliveries isolate mutable retry state; settings revisions preserve policy history; reviewer candidates preserve eligibility/reassignment separately from immutable decisions; applications give permanent successful-request uniqueness; binding history survives credential loss; scope contracts allowlist permission-specific semantics rather than provide generic polymorphic targets.

## 3. Identity, alias and live authentication detail

INDIVIDUAL requires one Person; FAMILY/SYSTEM have no individual person_id. A human record can exist without a principal. One non-retired INDIVIDUAL per Person includes PENDING/ACTIVE/SUSPENDED so parallel provisioning/recovery cannot create another live actor; RETIRED histories remain attributable. A separate individual's Teacher+Parent roles are compatible; no transfer to related family credentials. No legitimate confirmed requirement contradicts this cardinality.

Family safety is a complete invariant, not a boolean trusted from Flutter: assignment principal kind matches principal via FK, role family classification matches role via FK, FAMILY requires family-only role, role/action grant matches permission family-safe classification, and command semantics are deployment-owned. Immutable classifications cannot be relabeled to promote a family account. Missing typed family/teaching relationships deny. Staff/system reviewer authority is never inferred from a linked Person.

Username normalization: trim ASCII space U+0020 at ends, lowercase ASCII A-Z, require [a-z][a-z0-9._-]{2,31}; all other whitespace/non-ASCII reject. This does not restrict Unicode display names. A C-collation unique normalized alias is reserved forever within the project, including retired rows. Email input is handled by managed Auth; username input goes through a rate-limited generic-response gateway that never returns the mapped email/Auth UUID. It may forward supplied credentials to managed Auth transiently but never stores/logs them. Provisioned Auth identity and verified recovery ownership remain required; an alias alone never grants a session. Complete authentication UI/provider recovery code is deferred implementation, not a missing alias schema decision.

The binding adds tokens_valid_from to reject pre-recovery/relink JWTs, uses live ACTIVE principal checks, and refuses historical reassignment of an Auth UUID to another principal. Exact role/trigger/cutoff mechanics are selected in [execution security](../security/04_foundation_execution_security.md).

## 4. Adversarial role/action/scope and interval review

The repeated role_id/permission_id/kind/classification fields are intentional checked redundancy: their non-null composite FKs enforce agreement between independently identified parents. Candidate UNIQUE tuples that include id are required FK targets, not claims of new business uniqueness. No nullable component can skip the role/action/contract checks. CAMPUS's nullable target is coupled to scope_kind; OWN/ASSIGNED has no unchecked generic scope UUID. Unknown/disabled resolver denies.

Logical non-overlap keys are role_permission_grants(role_id,permission_id), principal_role_assignments(principal_id,role_id,context_kind), and assignment_permission_scopes(assignment_id,grant_id,scope_contract_id,campus_id with NULL compared explicitly). All use immutable planned [valid_from,valid_until), narrowed by a genuine server-time revoked_at if present. For a not-yet-effective cancelled grant, the effective interval is empty. All permission checks also intersect parents' live intervals; creating a new scope cannot revive an expired parent.

Remove the old partial UNIQUE while revoked_at is NULL from these three tables. It falsely forced natural expiration to be recorded as revocation and prohibited legitimate future scheduling. Add valid_until to role-permission grants for consistent semantics. Non-overlap is now a protected serialized command invariant with defensive triggers, not a false database CHECK claim. Index the logical key/start for overlap searches. Adjacent intervals pass; concurrent overlap yields one success and one conflict. Changing a current grant genuinely revokes/ends it now and inserts the next interval; scheduled expiry alone does not modify history.

No normal client can edit these tables. The exclusive school authorization lock precedes overlap checks and security mutations. The [execution-security lock contract](../security/04_foundation_execution_security.md) prevents stale grant/revoke races without btree_gist. Schema creation order places parent candidate keys before scope FKs.

## 5. Approval and failure meaning

Selected request states: DRAFT, SUBMITTED, PENDING, APPROVED, REJECTED, CANCELLED, EXECUTED, INVALIDATED. FAILED is removed; timer-driven EXPIRED is deferred until actual deadline policy exists. A draft may be cancelled without submission. Submission freezes validated intent/evidence/policy and enters SUBMITTED, then PENDING only after all sequential stages/candidates are prepared; preparation and transition are synchronous in initial commands, with no incomplete request review authority. One effective review per stage remains relationally unique.

Sequential review advances PENDING to APPROVED only when every required stage approves; any required rejection produces REJECTED. No self-review, same proven Person through another account, FAMILY-as-staff reviewer, delegation, parallel quorum or Super Admin bypass. A family-originated operation requiring relationship conflict checks stays disabled until the domain resolver proves eligibility; unknown family interest cannot be guessed away. The same reviewer may serve multiple stages only if the explicitly configured chain and conflict checks permit it; all stages still need their own effective decision.

Policy activation freezes template/terms; request submission pins a version. Campus policy override precedes school-level policy; reject ambiguous overlaps. Retirement prevents new selection but does not silently reinterpret pinned requests. Security withdrawal disables execution and records invalidation when needed. Changed submitted intent means a new request, never resetting the old one to editable DRAFT. Initial cancellation is allowed for the requester or separately authorized workflow administrator before execution, with reason, same lock/version and no business reversal; after EXECUTED it requires a new domain reversal/correction operation.

Execution rechecks current principal, requester and required reviewers' authority, typed target, workflow, expected versions and domain invariants. Transient infrastructure error rolls back everything: request remains APPROVED, no success/application/terminal receipt persists. A deterministic stale target or lost required approval authority records INVALIDATED with a precise transition reason and a REJECTED receipt without changing domain truth; new request/review required. A merely stale client expected_request_version rejects that command without necessarily invalidating the valid request. APPROVED -> EXECUTED and one successful application occur only in the domain-effect transaction.

Application rows are successful evidence only; never insert failed applications. Reasons and terminal command outcomes carry execution-failure diagnostics; audit records attempts distinctly. No persistent EXECUTING/ACCEPTED queue or ambiguous request FAILED state is required.

## 6. Idempotency and canonical contract

The key namespace is school project + stable principal + operation_contracts version identity + idempotency_key. Add command_kind as a registered operation phase (for example request.submit, request.review, request.apply) inside canonical intent; it is not a caller-selected executable handler. Reusing a key for a different phase/payload conflicts. A receipt from review cannot satisfy application success merely by referencing the same request; the application command requires request.apply and SUCCEEDED in addition to the triple FK.

Canonicalization version 1: construct a server-validated envelope with operation code/version, command_kind, typed target/request UUIDs, expected target/request versions and payload normalized only by that operation's schema. UUIDs use lowercase canonical text; bigint versions and exact future decimals use schema-validated decimal strings, never lossy client floats. Absent optional fields are normalized to explicit null only where the operation declares that equivalence; arrays preserve order; strings are not silently trimmed/Unicode-normalized. Canonical JSON is UTF-8 RFC 8785 JCS, hashed with SHA-256 to 32 bytes. Permit only safe-integer JSON numeric literals in the initial Foundation schemas; reject nonfinite/unsafe numeric input and invalid Unicode, and reject duplicate input keys at the gateway before JSONB conversion. The database independently validates the resulting typed envelope and recomputes the hash; a client hash is never authority. [RFC 8785](https://www.rfc-editor.org/rfc/rfc8785).

Old retries use the receipt's stored canonicalization version and original operation contract, not a newly changed normalizer. New algorithm/semantic versions are explicit; unknown versions deny. JCS implementation and test vectors belong to the SQL/command implementation task; no package is installed or mandated here.

Take the school authorization lock, then a transaction advisory lock in namespace 71002 derived from the full idempotency tuple (a deterministic SHA-256-based signed 32-bit resource key). Collisions only serialize unrelated keys; compare full stored tuple afterward. No receipt means validate/execute, then insert terminal SUCCEEDED or deterministic REJECTED in the same transaction before dependent audit/outbox/application rows. A failed transaction leaves neither effect nor receipt. UNIQUE(principal_id,operation_id,idempotency_key) remains the final collision guard. Same successful/rejected receipt replays only the authorized safe result; changed intent requires a new key. Retain key/hash/permanent outcome identity, no TTL. External delivery can duplicate and is not exactly once.

Initial technical payload bounds: code/handler/category/resolver keys <=64 ASCII characters; display labels/names <=256 characters; reasons <=2000 characters; idempotency key 1..200 characters; storage object key <=512 characters. Validated JSON objects: each audit details/authority field <=8 KiB, notification summary <=2 KiB, school contact details <=8 KiB, request old/proposed/result/config payloads <=16 KiB each, measured as UTF-8 canonical JSON bytes. Reject excess before insertion, never truncate silently. Sensitive summaries remain allowlisted regardless of size. Domain-specific future precision/ranges are deferred; these technical ceilings are not finance policy.

## 7. Events, files and retention

Keep separate immutable audit/outbox, mutable per-consumer delivery and principal-owned inbox/preferences. The initial consumer is the registered in-app projector; it writes authorized deduplicated inbox rows and marks its event delivery complete in the same database transaction. Generic external consumers/senders are not enabled. Consumer lease is 60 seconds, fenced token and row version checked on claim/ack/renewal; expired/stale acknowledgement denies. Retry max 10 attempts with delay min(30*2^(attempt-1),3600) seconds, then DEAD; explicit audited replay required. These are technical defaults, not a new SLA or product retention requirement.

Defer the entire channel-delivery table rather than keeping an unverifiable endpoint_ref in the first SQL. Later email/push must provide typed verified ownership and reauthorization; no provider selected. IN_APP preference categories must be registered; unknown categories deny and no mandatory category is invented. quiet_hours stays NULL until its semantics are designed.

Audit captures initiator and executor, verified principal kind, outcome/reason, minimal target/version, command/request/correlation references and bounded authority evidence. Keep snapshots only when needed to explain the action, not whole student/finance records. No audit soft delete, normal delete or retention period; infrastructure owners remain technically privileged. Denied external Auth attempts use the operational evidence path, not invented business events.

Accept file metadata with measured size 1..1,048,576 bytes, SHA-256, validated type, immutable object key, private access and typed evidence/branding links. After upload, metadata begins PENDING until server content validation; claimed client length/hash is not sufficient. Failed uploads/orphans remain inaccessible and require reconciliation; no automatic byte deletion of retained evidence. Complete provider-neutral adapter/access implementation is a later activation gate. Generated PDFs remain normally on demand.

## 8. Non-PK index review

Every existing non-PK unique/index proposal was reviewed. Candidate-key indexes are retained for the documented matching FK, logical uniqueness or dedupe reason unless explicitly removed below. No generic JSON GIN, universal creator index, partition scheme or speculative name search index is selected. Index names in SQL should follow pk/fk/uq/ck/ix plus shortened relation/purpose (<=63 bytes), with a stable manifest suffix if needed to avoid collision.

| Table | UNIQUE / partial unique decision | Secondary index decision and purpose |
|---|---|---|
| school_profiles | KEEP singleton; REMOVE redundant code uniqueness on a singleton | No secondary index justified |
| campuses | KEEP: school_id,code | KEEP: school_id,state — school campus listing |
| rooms | KEEP: campus_id,code | KEEP: campus_id,state — scoped room directory |
| academic_years | KEEP: school_id,code; id,school_id | KEEP: school_id,state,starts_on — year selector/history |
| people | None beyond PK | No secondary index justified |
| principals | KEEP: id,kind; person_id — partial unique when kind INDIVIDUAL and state is not RETIRED | REUSE existing index: person_id — non-retired lookup covered by partial unique; historical account search may use bounded identity service until measured |
| principal_auth_bindings | KEEP: principal_id; auth_user_id — nullable unique; id,principal_id | REUSE existing index: principal_id,principal_kind — covered by principal_id unique lookup |
| principal_binding_events | KEEP: binding_id,binding_version | KEEP: principal_id,created_at — binding investigation; KEEP: new_auth_user_id,principal_id — detect historical cross-principal Auth UUID reuse |
| login_aliases | KEEP: normalized_alias | KEEP: principal_id — revoke/account alias lookup |
| roles | KEEP: code; id,family_only | No secondary index justified |
| permissions | KEEP: code; id,family_safe | No secondary index justified |
| role_permission_grants | KEEP: id,role_id,permission_id; REMOVE old unrevoked-only uniqueness; serialized overlap replaces it | KEEP: permission_id — permission retirement/dependency lookup; KEEP: role_id,permission_id,valid_from — logical grant overlap/replacement lookup |
| principal_role_assignments | KEEP: id,role_id; REMOVE old unrevoked-only uniqueness; serialized overlap replaces it | KEEP: principal_id,role_id,context_kind,valid_from — live assignment and logical interval overlap lookup; KEEP: role_id — role retirement/review |
| permission_scope_contracts | KEEP: permission_id,scope_kind,resolver_key,contract_version; id,permission_id,scope_kind,resolver_key | No secondary index justified |
| assignment_permission_scopes | None beyond PK; REMOVE old unrevoked-only uniqueness; serialized overlap replaces it | KEEP: assignment_id,permission_id,revoked_at — complete grant lookup; KEEP: grant_id,role_id,permission_id — grant revocation joins; KEEP: scope_contract_id — resolver deactivation lookup; KEEP: campus_id — scoped lookup/dependency; KEEP: assignment_id,grant_id,scope_contract_id,campus_id,valid_from — logical scope interval overlap including NULL campus |
| operation_contracts | KEEP: code,contract_version; id,payload_schema_version | KEEP: request_permission_id — permission dependency; KEEP: review_permission_id — review permission dependency |
| approval_policy_versions | KEEP: policy_key,version; id,operation_id | KEEP: operation_id,campus_id,effective_from — policy selection |
| approval_step_templates | KEEP: policy_id,step_number; id,policy_id | KEEP: reviewer_role_id — reviewer role dependency |
| approval_requests | KEEP: id,policy_id; id,operation_id | KEEP: requester_id,created_at — own request history; KEEP: campus_id,state — scoped request administration; KEEP: policy_id,operation_id — policy/request dependency |
| approval_request_files | KEEP: request_id,file_id | KEEP: file_id — evidence retention/reference lookup |
| approval_request_steps | KEEP: request_id,step_number; id,request_id | KEEP: template_id,policy_id — template dependency |
| approval_step_reviewers | KEEP: id,step_id,reviewer_id; step_id,reviewer_id — partial unique while withdrawn_at absent | KEEP: reviewer_id,withdrawn_at,step_id — pending reviewer worklist |
| approval_reviews | KEEP: reviewer_assignment_id; step_id — one effective decision for initial sequential baseline | REUSE: step_id UNIQUE reused for one effective decision/history; no duplicate secondary index |
| approval_transitions | KEEP: request_id,sequence_number | KEEP: command_receipt_id — command evidence lookup |
| approval_applications | KEEP: request_id; command_receipt_id | KEEP: operation_id — operation usage/dependency |
| command_receipts | KEEP: principal_id,operation_id,idempotency_key; id,operation_id; id,operation_id,request_id | KEEP: request_id — request command/retry history; KEEP: operation_id — registry dependency/operation receipt history |
| audit_events | None beyond PK | KEEP: target_kind,target_ref,occurred_at — target audit timeline; KEEP: actor_id,occurred_at — actor investigation; KEEP: campus_id,occurred_at — scoped audit review; KEEP: command_receipt_id — transaction evidence; KEEP: approval_request_id — workflow evidence |
| outbox_events | KEEP: command_receipt_id,event_ordinal | KEEP: aggregate_kind,aggregate_ref,aggregate_version — ordered aggregate replay; KEEP: causation_event_id — event-chain investigation |
| event_consumer_deliveries | KEEP: event_id,consumer_key | KEEP: consumer_key,next_attempt_at — partial PENDING/RETRY work queue; KEEP: consumer_key,lease_until — partial LEASED expiry recovery |
| notifications | KEEP: event_id,recipient_id,context_key,category_code; id,recipient_id | KEEP: recipient_id,created_at — partial read_at/archived_at absent for unread inbox |
| notification_preferences | KEEP: principal_id,category_code,channel_code | No secondary index justified |
| notification_channel_deliveries | DEFER ALL with table | DEFER ALL |
| file_objects | KEEP: storage_location_key,object_key | KEEP: owner_principal_id,state — own upload reconciliation; KEEP: campus_id,state — scoped document administration; KEEP: replaces_file_id — version lineage lookup |
| setting_revisions | KEEP: setting_key,revision — partial school-level campus_id absent; setting_key,campus_id,revision — partial campus_id present; setting_key,effective_from — partial school-level; setting_key,campus_id,effective_from — partial campus_id present | KEEP: supersedes_id — revision lineage lookup |

Covered principal_id/kind lookup on principal_auth_bindings does not create an additional index; its principal_id UNIQUE suffices. Person non-retired lookup reuses the accepted partial UNIQUE. Actor-FK child indexes are not automatically required where parents cannot be normally deleted and no query uses them; add only with measured investigation/maintenance need. Conversely historical new_auth_user_id lookup is added for non-reassignment, and operation_id on receipts supports its FK/registry usage. Planned interval lookup indexes are required for the newly selected non-overlap command. Actual query plans will be checked during implementation, not claimed here.

## 9. FK cycles, consistency and outcome

The [exact graph](../database/08_foundation_exact_dependency_graph.md) inventories every application FK and selects three late additions: people.created_by, school's composite default-year link and school's logo link. Four self-reference families remain inline. Requests precede receipts, then transitions/applications; audit follows all its parents. No disabled/unvalidated FK survives activation. [Bootstrap](../database/07_foundation_bootstrap_plan.md) separates technical manifest from school setup and preserves customization. [Test execution](../testing/02_foundation_database_execution_plan.md) specifies rebuild/upgrade and non-owner/concurrency evidence.

This review corrects unsafe or ambiguous physical proposals rather than treating their existence as approval. It finds no contradiction requiring a product-owner decision in the selected Foundation subset. Remaining product/domain/provider/recovery-UI/retention/sync implementation choices are safely deferred with disabled entry points where necessary. The [updated TBD gate](FOUNDATION_TBD_GATE.md) records each item's exact resolution scope.

**FOUNDATION PHYSICAL DESIGN IS READY FOR SQL MIGRATION DRAFT.** This means files-only design readiness, not production readiness or permission to execute. Next task, not started: **FOUNDATION SQL MIGRATION DRAFT — FILES ONLY, NO SUPABASE EXECUTION.**

## Accepted storage amendments - 2026-09-24

[ADR-003](ADR-003-provider-neutral-object-storage.md) selects provider-neutral file bytes and deployment location mapping: rename bucket_code to storage_location_key, retain unique location/key, default classification PRIVATE, preserve measured SHA-256/1 MiB and lineage. [ADR-004](ADR-004-storage-plan-entitlements.md) adds immutable NOT NULL purpose_code with lexical CHECK and deployment registry; server-enforced entitlement snapshot plus normal domain authorization gates new uploads. No provider/purpose/entitlement table, plan_id or unrelated physical change.

T11 remains **RESOLVED FOR SQL DRAFT**. There are **zero storage SQL-design blockers**. Provider selection, secure upload-intent/byte sealing, signed snapshot distribution/freshness/revision fencing, expiry settings and adapter tests are implementation/activation gates. Other SQL gates stay resolved/deferred as reviewed. The 33-table count, all FKs and three late cuts remain unchanged.

Downgrade preserves files and normal authorized reads; removed-purpose uploads/replacements deny. Suspension preserves data and denies new use; read/export/retention policy remains TBD. Commercial names/prices, exact package membership and total quotas remain TBD, not schema blockers. Generated PDFs stay on demand.

Ready for **FOUNDATION SQL MIGRATION DRAFT - FILES ONLY, NO SUPABASE EXECUTION**. No SQL has been started.
