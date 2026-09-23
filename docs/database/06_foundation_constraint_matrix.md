# 06 - Foundation Constraint and Index Matrix

**Status: REVIEWED FOR SQL DRAFT, 2026-09-23. No SQL.**

[Physical review](../decisions/FOUNDATION_PHYSICAL_DESIGN_REVIEW.md) selects 33 tables; the retained F28 row is deferred design history and must not be drafted. [Execution security](../security/04_foundation_execution_security.md) fixes ownership, locks, cutoff and trigger contracts. Global input/JSON size bounds in review R06 apply in addition to the row checks below. Companion to the [catalog](05_foundation_physical_catalog.md), [ERDs](04_foundation_erd.md), [RLS matrix](../security/03_foundation_rls_matrix.md), and [TBD gate](../decisions/FOUNDATION_TBD_GATE.md).

## 1. Enforcement boundaries

PK, NOT NULL, UNIQUE, row-local CHECK and FK constraints are database-enforceable. Composite referenced tuples below have explicit non-partial candidate UNIQUE keys in the catalog. Partial unique indexes only enforce the stated active/unrevoked subset; they are not FK targets. Composite authorization columns are all NOT NULL so a missing value cannot bypass matching. Optional default-year and receipt/request composites deliberately use MATCH SIMPLE semantics; their optionality must be validated by the owning command.

CHECK does not enforce another row's mutable truth. Active principal/grant validity, allowed workflow edges, interval overlap, candidate conflicts, domain ancestry, external Storage existence and unknown-resolver denial need protected command logic, correctly locked transactions and where appropriate restricted triggers. Immutability compares old/new rows and needs triggers/privilege boundaries; it is not a row CHECK. Foreign keys do not automatically create child-side indexes. These distinctions follow [PostgreSQL's constraint documentation](https://www.postgresql.org/docs/18/ddl-constraints.html); the deployed runtime version remains T02, and this proposal does not require a version-18-only feature.

All application FKs use **ON DELETE RESTRICT / ON UPDATE RESTRICT**, including self/actor/lineage FKs. The only exception is the managed Auth live UUID FK: **ON DELETE SET NULL**. Snapshot UUIDs and disabled future target/result/endpoint descriptors are not FKs. Index-backed UNIQUE clauses with nullable components are deliberately split into school/non-school or campus/non-campus partial keys; no assumed NULL-equality behavior or unapproved extension is needed.

## 2. Per-table key and relationship matrix

The fully qualified namespace is listed in the catalog. Every PK is immutable UUID id. Common created_by references are included. Composite rows replace the component-column shorthand in the catalog: they are the actual proposed FK shapes.

| Table / F concept | PK | FKs (all RESTRICT except explicit Auth exception) | UNIQUE / partial unique |
|---|---|---|---|
| school_profiles / F01 | id | (default_academic_year_id,id) → academic_years(id,school_id); logo_file_id → file_objects.id; created_by → principals.id | singleton; omit redundant code uniqueness |
| campuses / F02 | id | school_id → school_profiles.id; created_by → principals.id | school_id,code |
| rooms / F03 | id | campus_id → campuses.id; created_by → principals.id | campus_id,code |
| academic_years / F04 | id | school_id → school_profiles.id; created_by → principals.id | school_id,code; id,school_id |
| people / F05 | id | created_by → principals.id | PK only |
| principals / F06 | id | person_id → people.id; created_by → principals.id | id,kind; person_id — partial unique when kind INDIVIDUAL and state is not RETIRED |
| principal_auth_bindings / F06 | id | (principal_id,principal_kind) → principals(id,kind); auth_user_id → external auth.users.id; ON DELETE SET NULL; created_by → principals.id | principal_id; auth_user_id — nullable unique; id,principal_id |
| principal_binding_events / F07 | id | (binding_id,principal_id) → principal_auth_bindings(id,principal_id); created_by → principals.id | binding_id,binding_version |
| login_aliases / F08 | id | principal_id → principals.id; created_by → principals.id | normalized_alias |
| roles / F09 | id | created_by → principals.id | code; id,family_only |
| permissions / F10 | id | created_by → principals.id | code; id,family_safe |
| role_permission_grants / F11 | id | (role_id,role_family_only) → roles(id,family_only); (permission_id,permission_family_safe) → permissions(id,family_safe); created_by → principals.id | id,role_id,permission_id |
| principal_role_assignments / F12 | id | (principal_id,principal_kind) → principals(id,kind); (role_id,role_family_only) → roles(id,family_only); created_by → principals.id | id,role_id |
| permission_scope_contracts / F10/F13 | id | permission_id → permissions.id; created_by → principals.id | permission_id,scope_kind,resolver_key,contract_version; id,permission_id,scope_kind,resolver_key |
| assignment_permission_scopes / F13 | id | (assignment_id,role_id) → principal_role_assignments(id,role_id); (grant_id,role_id,permission_id) → role_permission_grants(id,role_id,permission_id); (scope_contract_id,permission_id,scope_kind,resolver_key) → permission_scope_contracts(id,permission_id,scope_kind,resolver_key); campus_id → campuses.id; created_by → principals.id | PK only |
| operation_contracts / F14/F16/F25 | id | request_permission_id → permissions.id; review_permission_id → permissions.id; created_by → principals.id | code,contract_version; id,payload_schema_version |
| approval_policy_versions / F14 | id | operation_id → operation_contracts.id; campus_id → campuses.id; created_by → principals.id | policy_key,version; id,operation_id |
| approval_step_templates / F15 | id | policy_id → approval_policy_versions.id; reviewer_role_id → roles.id; created_by → principals.id | policy_id,step_number; id,policy_id |
| approval_requests / F16 | id | (policy_id,operation_id) → approval_policy_versions(id,operation_id); (operation_id,payload_schema_version) → operation_contracts(id,payload_schema_version); requester_id → principals.id; campus_id → campuses.id; created_by → principals.id | id,policy_id; id,operation_id |
| approval_request_files / F16/F23 | id | request_id → approval_requests.id; file_id → file_objects.id; created_by → principals.id | request_id,file_id |
| approval_request_steps / F17 | id | (request_id,policy_id) → approval_requests(id,policy_id); (template_id,policy_id) → approval_step_templates(id,policy_id); created_by → principals.id | request_id,step_number; id,request_id |
| approval_step_reviewers / F17 | id | step_id → approval_request_steps.id; reviewer_id → principals.id; created_by → principals.id | id,step_id,reviewer_id; step_id,reviewer_id — partial unique while withdrawn_at absent |
| approval_reviews / F18 | id | (reviewer_assignment_id,step_id,reviewer_id) → approval_step_reviewers(id,step_id,reviewer_id); created_by → principals.id | reviewer_assignment_id; step_id — one effective decision for initial sequential baseline |
| approval_transitions / F26 | id | request_id → approval_requests.id; command_receipt_id → command_receipts.id; created_by → principals.id | request_id,sequence_number |
| approval_applications / F26/F25 | id | (request_id,operation_id) → approval_requests(id,operation_id); (command_receipt_id,operation_id,request_id) → command_receipts(id,operation_id,request_id); created_by → principals.id | request_id; command_receipt_id |
| command_receipts / F25 | id | (request_id,operation_id) → approval_requests(id,operation_id); principal_id → principals.id; created_by → principals.id | principal_id,operation_id,idempotency_key; id,operation_id; id,operation_id,request_id |
| audit_events / F19 | id | (actor_id,actor_kind) → principals(id,kind); campus_id → campuses.id; command_receipt_id → command_receipts.id; approval_request_id → approval_requests.id; created_by → principals.id | PK only |
| outbox_events / F20 | id | causation_event_id → outbox_events.id; command_receipt_id → command_receipts.id; created_by → principals.id | command_receipt_id,event_ordinal |
| event_consumer_deliveries / F21 | id | event_id → outbox_events.id; created_by → principals.id | event_id,consumer_key |
| notifications / F22 | id | (recipient_id,recipient_kind) → principals(id,kind); event_id → outbox_events.id; created_by → principals.id | event_id,recipient_id,context_key,category_code; id,recipient_id |
| notification_preferences / F27 | id | principal_id → principals.id; created_by → principals.id | principal_id,category_code,channel_code |
| notification_channel_deliveries / F28 | id | (notification_id,recipient_id) → notifications(id,recipient_id); created_by → principals.id | notification_id,channel_code,endpoint_ref,endpoint_version |
| file_objects / F23 | id | owner_principal_id → principals.id; campus_id → campuses.id; replaces_file_id → file_objects.id; created_by → principals.id | bucket_code,object_key |
| setting_revisions / F24 | id | campus_id → campuses.id; supersedes_id → setting_revisions.id; created_by → principals.id | setting_key,revision — partial school-level campus_id absent; setting_key,campus_id,revision — partial campus_id present; setting_key,effective_from — partial school-level; setting_key,campus_id,effective_from — partial campus_id present |

## 3. Per-table CHECK, exclusion, immutability and concurrency matrix

I/F/E/V have the catalog's exact meanings. All PK/created_at/created_by fields are immutable. No exclusion constraints are proposed in this pass: no btree_gist or other extension is implicitly selected. The protected rules following this matrix state where overlap checks need serialization.

| Table | Row-local CHECK candidates | Exclusion / overlap | Immutable or frozen fields beyond common identity | Version / concurrency |
|---|---|---|---|---|
| school_profiles | singleton=true; nonblank code/name/timezone/locale; currency_code is three uppercase letters; contact_details object; state SETUP/ACTIVE/INACTIVE; row_version > 0 | None; protected rules apply | singleton (I), code (I) | row_version expected value; server increments |
| campuses | nonblank code/name; state PLANNED/ACTIVE/ARCHIVED; row_version > 0 | None; protected rules apply | school_id (I), code (I) | row_version expected value; server increments |
| rooms | nonblank code/name/kind_code; capacity > 0 when present; state ACTIVE/UNAVAILABLE/ARCHIVED; row_version > 0 | None; protected rules apply | campus_id (I), code (I) | row_version expected value; server increments |
| academic_years | starts_on <= ends_on; nonblank code/label; state PLANNED/ACTIVE/CLOSED/ARCHIVED; row_version > 0 | None; overlapping years permitted | school_id (I), code (I) | row_version expected value; server increments |
| people | nonblank display_name; state ACTIVE/INACTIVE/ARCHIVED; row_version > 0 | None; protected rules apply |  | row_version expected value; server increments |
| principals | kind INDIVIDUAL/FAMILY/SYSTEM; INDIVIDUAL iff person_id present; SYSTEM iff system_purpose present; nonblank label; state PENDING/ACTIVE/SUSPENDED/RETIRED; row_version > 0 | None; protected rules apply | kind (I), person_id (I), system_purpose (I) | row_version expected value; server increments |
| principal_auth_bindings | principal_kind INDIVIDUAL/FAMILY; binding_version > 0; auth_user_id present implies bound_at present; row_version > 0; tokens_valid_from is a finite whole-second instant | None; protected rules apply | principal_id (I), principal_kind (I) | row_version + binding_version + token cutoff; exclusive relink |
| principal_binding_events | event_kind BOUND/UNBOUND/RELINKED/RECOVERED/RECONCILED; binding_version > 0; nonblank reason | None; protected rules apply | principal_id (I), binding_id (I), event_kind (I), old_auth_user_id (I), new_auth_user_id (I), binding_version (I), reason (I) | Append-only; UNIQUE identity/sequence and parent lock |
| login_aliases | normalized_alias matches ASCII [a-z][a-z0-9._-]{2,31}; state RESERVED/ACTIVE/RETIRED; row_version > 0 | None; protected rules apply | principal_id (I), normalized_alias (I) | row_version expected value; server increments |
| roles | nonblank code/label; state DRAFT/ACTIVE/RETIRED; row_version > 0 | None; protected rules apply | code (I), family_only (I) | row_version expected value; server increments |
| permissions | nonblank code; state ENABLED/DISABLED/RETIRED; row_version > 0 | None; protected rules apply | code (I), family_safe (I) | row_version expected value; server increments |
| role_permission_grants | role_family_only implies permission_family_safe; revoked_at >= created_at if present; finite validity instants; row_version > 0; valid_until > valid_from if present | No EXCLUDE; exclusive-lock serialized effective interval non-overlap | role_id (I), role_family_only (I), permission_id (I), permission_family_safe (I), valid_from (I), valid_until (I), revoked_at (E) | row_version expected value; server increments |
| principal_role_assignments | context_kind equals principal_kind; FAMILY implies role_family_only; valid_until > valid_from if present; revoked_at >= created_at if present; finite validity instants; row_version > 0 | No EXCLUDE; exclusive-lock serialized effective interval non-overlap | principal_id (I), principal_kind (I), role_id (I), role_family_only (I), context_kind (I), valid_from (I), valid_until (I), revoked_at (E) | row_version expected value; server increments |
| permission_scope_contracts | scope_kind ALL/CAMPUS/OWN/ASSIGNED; contract_version > 0; nonblank resolver_key; ALL/CAMPUS require DIRECT; OWN/ASSIGNED forbid DIRECT; row_version > 0 | None; protected rules apply | permission_id (I), scope_kind (I), resolver_key (I), contract_version (I) | row_version expected value; server increments |
| assignment_permission_scopes | scope_kind ALL/CAMPUS/OWN/ASSIGNED; campus_id present iff CAMPUS; valid_until > valid_from if present; revoked_at >= created_at if present; finite validity instants; row_version > 0 | No EXCLUDE; exclusive-lock serialized effective interval non-overlap | assignment_id (I), grant_id (I), role_id (I), permission_id (I), scope_contract_id (I), scope_kind (I), resolver_key (I), campus_id (I), valid_from (I), valid_until (I), revoked_at (E) | row_version expected value; server increments |
| operation_contracts | nonblank code/handler_key; positive versions; requires_approval implies review_permission_id present; row_version > 0 | None; protected rules apply | code (I), contract_version (I), handler_key (I), request_permission_id (I), review_permission_id (I), payload_schema_version (I), requires_approval (I) | row_version expected value; server increments |
| approval_policy_versions | nonblank policy_key; version > 0; state DRAFT/ACTIVE/RETIRED; activated_at present implies effective_from present; effective_until > effective_from if both present; row_version > 0 | No EXCLUDE; serialized activation overlap check | policy_key (I), version (I), operation_id (I), campus_id (I), effective_from (F), effective_until (F), activated_at (E) | row_version expected value; server increments |
| approval_step_templates | step_number > 0; required_reviews = 1 (initial sequential baseline); nonblank selection_resolver_key; row_version > 0 | None; protected rules apply | policy_id (F), step_number (F), reviewer_role_id (F), required_reviews (F), selection_resolver_key (F) | row_version expected value; server increments |
| approval_requests | nonblank reason; JSON objects; payload_schema_version > 0; expected_target_version > 0 if present; state DRAFT/SUBMITTED/PENDING/APPROVED/REJECTED/CANCELLED/EXECUTED/INVALIDATED; state outside DRAFT/CANCELLED implies submitted_at present; row_version > 0 | None; protected rules apply | operation_id (F), payload_schema_version (F), policy_id (F), requester_id (I), campus_id (F), target_ref (F), expected_target_version (F), reason (F), old_snapshot (F), requested_payload (F), submitted_at (E) | row_version + expected_target_version; request/target locks |
| approval_request_files | nonblank purpose | None; protected rules apply | request_id (I), file_id (I), purpose (I) | Append-only; UNIQUE identity/sequence and parent lock |
| approval_request_steps | step_number > 0; required_reviews = 1 (initial sequential baseline); state WAITING/OPEN/APPROVED/REJECTED/CANCELLED; closed_at >= opened_at when both present; row_version > 0 | None; protected rules apply | request_id (I), policy_id (I), template_id (I), step_number (I), required_reviews (I), opened_at (E), closed_at (E) | row_version expected value; server increments |
| approval_step_reviewers | withdrawn_at >= assigned_at when present; nonblank assignment_reason; row_version > 0 | None; protected rules apply | step_id (I), reviewer_id (I), assigned_at (I), withdrawn_at (E), assignment_reason (I) | row_version expected value; server increments |
| approval_reviews | decision APPROVE/REJECT; nonblank reason; expected_request_version > 0 | None; protected rules apply | reviewer_assignment_id (I), step_id (I), reviewer_id (I), decision (I), reason (I), expected_request_version (I) | Append-only; UNIQUE identity/sequence and parent lock |
| approval_transitions | sequence_number > 0; states from request vocabulary; from_state NULL only sequence_number=1; nonblank reason | None; protected rules apply | request_id (I), sequence_number (I), from_state (I), to_state (I), reason (I), command_receipt_id (I) | Append-only; UNIQUE identity/sequence and parent lock |
| approval_applications | applied_target_version > 0 if present | None; protected rules apply | request_id (I), command_receipt_id (I), operation_id (I), applied_target_version (I), result_ref (I) | Append-only; UNIQUE identity/sequence and parent lock |
| command_receipts | idempotency_key length 1..200; hash exactly 32 bytes; positive canonicalization_version and optional expected versions; state SUCCEEDED/REJECTED; completed_at >= created_at; SUCCEEDED implies result_kind present and error_code absent; REJECTED implies error_code present and result_ref absent; result_summary object if present; command_kind is a nonblank registered code of at most 64 ASCII characters | None; protected rules apply | principal_id (I), operation_id (I), command_kind (I), idempotency_key (I), canonical_payload_hash (I), canonicalization_version (I), expected_target_version (I), request_id (I), expected_request_version (I), state (I), result_kind (I), result_ref (I), result_summary (I), error_code (I), completed_at (I) | Immutable terminal outcome; idempotency advisory lock + UNIQUE |
| audit_events | nonblank event_type/target_kind; source_kind API/WORKER/AUTH_RECONCILIATION/DEPLOYMENT; details object; actor_kind INDIVIDUAL/FAMILY/SYSTEM; nonblank outcome; authority_evidence object; target_version > 0 if present | None; protected rules apply | actor_id (I), actor_kind (I), auth_subject_snapshot (I), outcome (I), reason (I), authority_evidence (I), target_version (I), event_type (I), target_kind (I), target_ref (I), campus_id (I), command_receipt_id (I), approval_request_id (I), source_kind (I), correlation_id (I), occurred_at (I), details (I) | Append-only; UNIQUE identity/sequence and parent lock |
| outbox_events | positive schema_version/aggregate_version/event_ordinal; nonblank event_type/aggregate_kind; payload object; causation_event_id differs from id | None; protected rules apply | event_type (I), schema_version (I), aggregate_kind (I), causation_event_id (I), aggregate_ref (I), aggregate_version (I), command_receipt_id (I), event_ordinal (I), correlation_id (I), occurred_at (I), payload (I) | Append-only; UNIQUE identity/sequence and parent lock |
| event_consumer_deliveries | nonblank consumer_key; attempt_count >= 0; state PENDING/LEASED/RETRY/DELIVERED/DEAD; lease_token and lease_until both present iff LEASED; DELIVERED iff delivered_at present; row_version > 0 | None; protected rules apply | event_id (I), consumer_key (I), delivered_at (E) | row_version + lease_token fencing |
| notifications | recipient_kind INDIVIDUAL/FAMILY; nonblank category_code/context_key; summary object; row_version > 0 | None; protected rules apply | recipient_id (I), recipient_kind (I), event_id (I), category_code (I), context_key (I), summary (I), read_at (E), archived_at (E) | row_version expected value; server increments |
| notification_preferences | nonblank category_code; channel_code IN_APP (initial Foundation); quiet_hours object if present; row_version > 0; quiet_hours is NULL in initial Foundation | None; protected rules apply | principal_id (I), category_code (I), channel_code (I) | row_version expected value; server increments |
| notification_channel_deliveries | channel_code EMAIL/PUSH; endpoint_version > 0; attempt_count >= 0; state PENDING/LEASED/RETRY/SENT/CANCELLED/DEAD; lease fields both present iff LEASED; SENT iff sent_at present; row_version > 0 | None; protected rules apply | notification_id (I), recipient_id (I), channel_code (I), endpoint_ref (I), endpoint_version (I), sent_at (E) | DEFERRED; no initial SQL |
| file_objects | byte_size between 1 and 1048576 inclusive; hash exactly 32 bytes; nonblank bucket_code/object_key/content_type/classification; state PENDING/VALIDATED/AVAILABLE/QUARANTINED/ARCHIVED/PURGED; AVAILABLE implies validated_at present; replaces_file_id differs from id; row_version > 0 | None; protected rules apply | owner_principal_id (I), campus_id (I), bucket_code (I), object_key (I), content_type (I), byte_size (I), content_hash (I), classification (I), validated_at (E), replaces_file_id (I) | row_version expected value; server increments |
| setting_revisions | nonblank setting_key; positive revision/value_schema_version; value JSON object; supersedes_id differs from id | No EXCLUDE; unique effective point and locked revision chain | setting_key (I), campus_id (I), revision (I), value_schema_version (I), value (I), effective_from (I), supersedes_id (I) | Append-only; UNIQUE identity/sequence and parent lock |

## 4. Index plan

Each PK and every UNIQUE in section 2 supplies an index for identity lookup, the named uniqueness invariant, and matching FK parents. Do not duplicate those indexes. An index stated as covered below is a reuse note, not another index. Secondary proposals follow actual authorization, operational or history queries; validate with realistic EXPLAIN plans during implementation. No speculative payload JSON index, universal created_by index, or partition scheme is proposed.

| Table | Additional index / concrete query |
|---|---|
| school_profiles | None beyond PK/UNIQUE |
| campuses | school_id,state — school campus listing |
| rooms | campus_id,state — scoped room directory |
| academic_years | school_id,state,starts_on — year selector/history |
| people | None beyond PK/UNIQUE |
| principals | person_id — non-retired lookup covered by partial unique; historical account search may use bounded identity service until measured |
| principal_auth_bindings | principal_id,principal_kind — covered by principal_id unique lookup |
| principal_binding_events | principal_id,created_at — binding investigation; new_auth_user_id,principal_id — detect historical cross-principal Auth UUID reuse |
| login_aliases | principal_id — revoke/account alias lookup |
| roles | None beyond PK/UNIQUE |
| permissions | None beyond PK/UNIQUE |
| role_permission_grants | permission_id — permission retirement/dependency lookup; role_id,permission_id,valid_from — logical grant overlap/replacement lookup |
| principal_role_assignments | principal_id,role_id,context_kind,valid_from — live assignment and logical interval overlap lookup; role_id — role retirement/review |
| permission_scope_contracts | None beyond PK/UNIQUE |
| assignment_permission_scopes | assignment_id,permission_id,revoked_at — complete grant lookup; grant_id,role_id,permission_id — grant revocation joins; scope_contract_id — resolver deactivation lookup; campus_id — scoped lookup/dependency; assignment_id,grant_id,scope_contract_id,campus_id,valid_from — logical scope interval overlap including NULL campus |
| operation_contracts | request_permission_id — permission dependency; review_permission_id — review permission dependency |
| approval_policy_versions | operation_id,campus_id,effective_from — policy selection |
| approval_step_templates | reviewer_role_id — reviewer role dependency |
| approval_requests | requester_id,created_at — own request history; campus_id,state — scoped request administration; policy_id,operation_id — policy/request dependency |
| approval_request_files | file_id — evidence retention/reference lookup |
| approval_request_steps | template_id,policy_id — template dependency |
| approval_step_reviewers | reviewer_id,withdrawn_at,step_id — pending reviewer worklist |
| approval_reviews | step_id UNIQUE reused for one effective decision/history; no duplicate secondary index |
| approval_transitions | command_receipt_id — command evidence lookup |
| approval_applications | operation_id — operation usage/dependency |
| command_receipts | request_id — request command/retry history; operation_id — registry dependency/operation receipt history |
| audit_events | target_kind,target_ref,occurred_at — target audit timeline; actor_id,occurred_at — actor investigation; campus_id,occurred_at — scoped audit review; command_receipt_id — transaction evidence; approval_request_id — workflow evidence |
| outbox_events | aggregate_kind,aggregate_ref,aggregate_version — ordered aggregate replay; causation_event_id — event-chain investigation |
| event_consumer_deliveries | consumer_key,next_attempt_at — partial PENDING/RETRY work queue; consumer_key,lease_until — partial LEASED expiry recovery |
| notifications | recipient_id,created_at — partial read_at/archived_at absent for unread inbox |
| notification_preferences | None beyond PK/UNIQUE |
| notification_channel_deliveries | DEFER ALL with table |
| file_objects | owner_principal_id,state — own upload reconciliation; campus_id,state — scoped document administration; replaces_file_id — version lineage lookup |
| setting_revisions | supersedes_id — revision lineage lookup |

Long-lived parents are not routinely deleted; absence of a child-FK index here is deliberate unless a shown lookup needs it. Revisit large referencing tables before any approved retention maintenance, rather than inventing all FK indexes now. Reviewer worklists join approval_step_reviewers(reviewer_id, withdrawn_at, step_id) to step state. Scope lookup starts with the principal assignment index, then assignment_permission_scopes(assignment_id, permission_id, revoked_at), matching the same grant and resolver. Receipt uniqueness arbitrates concurrent retries. Unread notification and due-delivery partial indexes must use stored state/null predicates, not a volatile current-time expression.

## 5. Protected enforcement contracts

### K01 - Live identity and family barrier

Resolve the verified Auth UUID to exactly one live binding and ACTIVE principal. An unknown/missing/deleted binding denies; principal ID supplied by a client is not trusted. SYSTEM cannot have a live Auth binding. Principal kind/person identity are immutable under normal commands; proposed merge/relink requires a later T03 protocol. Common creator self-reference is allowed only for the deployment bootstrap SYSTEM principal with a preassigned UUID; subsequent creation uses an existing verified actor.

The following database chain is mandatory: principal assignment copies kind through a composite FK and checks FAMILY implies role_family_only; role_family_only itself matches roles via FK. Role-permission grants copy permission_family_safe through a composite FK and check family-only role implies family-safe permission. The flag semantics require a deployment-reviewed Parent/Guardian catalog; a CHECK cannot determine what a handler actually does. Flags are immutable and catalog activation is not a school-client privilege. Even a family-safe permission must evaluate the shared principal's own approved child links, never the teacher Person's assignments. Ahmed's INDIVIDUAL Teacher+Parent grants remain separate.

### K02 - Complete grant and scope

Reject any role mismatch at FK insertion, not only in the UI. Assignment scope copies the exact action via grant composite FK, then matches a contract for that action. Thus VIEW+ALL and UPDATE+ASSIGNED remain distinct rows; a combined UPDATE+ALL row has no matching permission/contract grant unless explicitly and validly granted. No nullable role/permission/contract component can escape the constraint.

Current principal, role, permission, grant, assignment, scope interval and resolver must all be enabled/valid in the same verified context. ALL never bypasses domain assignment/workflow/field restrictions. Campus comes from the stored target, not the request body. OWN/ASSIGNED uses an allowlisted compiled resolver and contract version; absent/unknown implementation denies. Later CLASS/SECTION/SUBJECT needs typed domain relations and ancestry checks, not scope_type plus unvalidated scope_id.

Role/grant/scope revocation commands and sensitive execution must lock/fence a common authorization anchor in a documented order (T04); a pre-write read under ordinary isolation alone does not prove race-safe revocation. No unrevoked-only UNIQUE remains on grants, assignments or scope bindings. Natural expiry leaves revoked_at NULL. Under the exclusive school authorization lock, reject overlapping nonempty effective intervals for the same logical key; adjacent future replacement is legal. Revocation before scheduled start cancels an unused interval without fabricating expiry. Do not add current time to a partial index predicate.

### K03 - Policy and request freeze

Activation validates at least one ordered stage, candidate resolver availability and supported sequence. Serialize on operation_contracts to exclude ambiguous active effective policies for the same operation and school/campus scope. A matching campus policy overrides school policy; multiple matching policies at the same scope reject. Freeze terms/templates at activation; retirement changes lifecycle only and does not reinterpret submitted requests. No policy DELETE or state reset to DRAFT.

Submission pins matching operation/policy/payload version; verifies target and evidence; captures old state; fills expected versions; freezes intent and files; instantiates stages and candidate assignments. Request campus and typed target ancestry must agree with the operation and policy selection. Parent FKs alone cannot enforce exactly one typed target child; a protected command plus appropriately deferred consistency trigger is required before enabling each domain operation.

The proposed sequential baseline has required_reviews=1 and one effective review per step. Review R05 prohibits self/same-Person approval and delegation/quorum/parallel review. Required family-interest proof remains domain-owned; unknown proof denies. Lost required approval authority invalidates the request at execution. Timer expiry is deferred. Step/template composite FKs enforce policy ownership; command copies stage number/count and rechecks current reviewer eligibility. Frozen snapshots do not grant permanent authority.

### K04 - Application, transaction and receipt uniqueness

Serialize request, target and authorization under a reviewed global lock order; compare target/request versions; prohibit bypass of published/finalized history. One application per request and one per receipt are durable unique invariants. The application receipt/request/operation composite FK prevents a successful record borrowing a receipt from another request. Typed result links and success state still require the handler. Append transition, domain history, audit, result receipt and outbox in the same commit. A failed audit write rolls the effect back.

Hash canonical, versioned command intent, including expected versions and target/request IDs. Database uniqueness arbitrates same-principal/same-command-version/same-key races. A mismatched hash conflicts; matching hash replays the stored result only after read authorization. Review R06 removes ACCEPTED entirely: serialize the idempotency tuple before work and insert only immutable terminal SUCCEEDED or deterministic REJECTED receipts in the same transaction. command_kind is part of canonical intent and application requires request.apply; same key with a different phase conflicts. Crash before commit permits the same attempt; crash after commit returns the prior receipt. A rejected terminal receipt requires a new command key for changed intent or a new authorized attempt; transient infrastructure rollback does not persist a false success. Review R06 selects version-1 canonicalization, failure classes and typed-result extension rules; execution security fixes lock order. Future domain result FKs are introduced before enabling those domain handlers.

Keep permanent dedupe evidence/application uniqueness even if transient response summaries are later redacted or archived. No cleanup horizon is selected. External send/upload is outside the transaction, may repeat, and needs its own bounded provider semantics.

### K05 - Event, inbox and delivery separation

Outbox payload and audit rows are immutable; workers only update delivery state. Registered consumers use event identity plus purpose for dedupe. Lease claims increment attempt count/version; lease completion requires the current token and valid expected state. Expired workers cannot overwrite a later lease. Serialize/handle per-aggregate ordering where required; no global ordering guarantee.

Notification insertion validates current recipient relationships and safe minimized content. Exact principal is the isolation key; matching a Person, address or family link never merges inboxes. Channel composite FK locks notification and recipient together, but F28 is excluded from the first SQL entirely; no channel rows, indexes, policy or dispatcher are drafted until a later verified typed endpoint relation is reviewed. No provider-specific endpoint table is invented here. Preferences affect authorized delivery only; T08 must define category mandates. Sent email/push cannot be recalled by RLS.

### K06 - File and configuration integrity

File metadata must describe measured immutable bytes; validation/quarantine/availability and Storage authorization are separate from metadata FK existence. Use managed Storage APIs, private access and typed owner links. Enforce measured byte_size between 1 and 1,048,576 inclusive; validate MIME/content, replacement ancestry and sensitive download authority. Preserve evidence references through retention/holds. Normally generate PDFs from stored facts/identifiers; do not store every generated invoice/receipt.

Setting keys and versioned JSON schemas are deployment allowlisted and cannot contain secrets or executable expressions. Serialize revision creation on school/campus anchor, verify same-key/scope predecessor and strictly advancing revision/effective time; no forks or retroactive silent reinterpretation. Stable school fields stay in the singleton. No general legal-hold table, automatic retention duration or cleanup worker is selected; until T10, protected data is retained.

## 6. Verification required before implementation approval

Later executable tests must reject mismatched role/grant/permission/contract FKs; missing nullable-bypass components; FAMILY staff grants; cloned Auth bindings; cross-request receipts; cross-policy stages; cross-recipient channel jobs; stale writes; duplicate effective reviews/applications; receipt hash reuse; mutable submitted intent; stale lease acknowledgements; and direct client writes. Positive tests prove permitted scoped reads/reviews, valid account relink preserving actor history, safe same-key replay, and a complete atomic application. These are planned tests, not executed backend tests.

The physical review and updated gate select the technical design. Next task: **FOUNDATION SQL MIGRATION DRAFT — FILES ONLY, NO SUPABASE EXECUTION.** No SQL or migration has been produced here.
