# 08 - Foundation Exact Dependency Graph

**SELECTED FOR SQL DRAFT, 2026-09-23. Creation plan only; no SQL or migration files.**
This refines and supersedes the old conceptual batch order where physical dependencies differ. See [review](../decisions/FOUNDATION_PHYSICAL_DESIGN_REVIEW.md), [catalog](05_foundation_physical_catalog.md), [constraints](06_foundation_constraint_matrix.md), [bootstrap](07_foundation_bootstrap_plan.md).

## 1. Object-level order

First create private/application namespaces, deployment-controlled roles/default privileges, and only side-effect-free scalar helpers needed by CHECK/defaults. Tables begin restricted and RLS-enabled; application entry points are unavailable throughout structural creation. Supabase auth.users is an existing external dependency, never created/redefined here. No F28 table is part of this order.

Create each table with PK, candidate UNIQUE keys and all backward/self FKs immediately; omit only the three precisely listed late FKs in section 2. Columns for those FKs exist with their final nullability from the start; delaying the constraint does not require weakening NOT NULL created_by.

| Order | Relation | Parent prerequisites / construction note |
|---|---|---|
| 01 | people | ; see named late FK(s) |
| 02 | principals | people, self FK permitted inline |
| 03 | principal_auth_bindings | principals; external managed auth.users.id |
| 04 | principal_binding_events | principal_auth_bindings, principals |
| 05 | login_aliases | principals |
| 06 | school_profiles | principals; see named late FK(s) |
| 07 | campuses | school_profiles, principals |
| 08 | rooms | campuses, principals |
| 09 | academic_years | school_profiles, principals |
| 10 | file_objects | principals, campuses, self FK permitted inline |
| 11 | roles | principals |
| 12 | permissions | principals |
| 13 | role_permission_grants | roles, permissions, principals |
| 14 | principal_role_assignments | principals, roles |
| 15 | permission_scope_contracts | permissions, principals |
| 16 | assignment_permission_scopes | principal_role_assignments, role_permission_grants, permission_scope_contracts, campuses, principals |
| 17 | operation_contracts | permissions, principals |
| 18 | approval_policy_versions | operation_contracts, campuses, principals |
| 19 | approval_step_templates | approval_policy_versions, roles, principals |
| 20 | approval_requests | approval_policy_versions, operation_contracts, principals, campuses |
| 21 | approval_request_files | approval_requests, file_objects, principals |
| 22 | approval_request_steps | approval_requests, approval_step_templates, principals |
| 23 | approval_step_reviewers | approval_request_steps, principals |
| 24 | approval_reviews | approval_step_reviewers, principals |
| 25 | command_receipts | approval_requests, principals |
| 26 | approval_transitions | approval_requests, command_receipts, principals |
| 27 | approval_applications | approval_requests, command_receipts, principals |
| 28 | audit_events | principals, campuses, command_receipts, approval_requests |
| 29 | outbox_events | self FK permitted inline, command_receipts, principals |
| 30 | event_consumer_deliveries | outbox_events, principals |
| 31 | notifications | principals, outbox_events |
| 32 | notification_preferences | principals |
| 33 | setting_revisions | campuses, self FK permitted inline, principals |

After all tables and candidate keys exist, add/validate the named late FKs, create the reviewed secondary/partial indexes, then install immutable/history/version/overlap triggers and execution functions/policies with exact privilege revocations. No normal entry point or worker activates before every required FK and policy is in place and tested.

## 2. Exhaustive FK cycles and selected cuts

| Cycle / strongly connected group | Why it exists | Exact solution |
|---|---|---|
| people ↔ principals | people.created_by -> principals.id; principals.person_id -> people.id; many other actors ultimately reference principals | Create people with required created_by column but without its FK; create principals with its Person FK and self creator FK; then add and validate people(created_by) -> principals(id). Tables are empty until validated bootstrap. |
| school_profiles ↔ academic_years | academic_years.school_id -> school_profiles.id; school_profiles(default_academic_year_id,id) -> academic_years(id,school_id) | Create school without the composite default-year FK, then years; add/validate the composite FK. Default-year value may remain NULL during setup; it is not an indefinitely unvalidated constraint. |
| school_profiles → file_objects → campuses → school_profiles | Optional logo -> file metadata; optional file campus -> campus; campus -> school | Create school without logo FK, create campus and file metadata, then add/validate school_profiles(logo_file_id) -> file_objects(id). Optional NULL logo remains valid when no branding upload exists. |
| principals.created_by self-reference | Bootstrap durable SYSTEM actor must have a trusted creator | Inline self FK; seed first SYSTEM with preassigned id=created_by in one insertion, under deployment-only bootstrap origin. Never nullable actor. |
| file_objects.replaces_file_id self-reference | File version lineage | Inline nullable self FK plus id != replaces_file_id CHECK; command ensures allowed immutable earlier lineage. |
| setting_revisions.supersedes_id self-reference | Configuration history | Inline nullable self FK and self-inequality CHECK; protected command ensures same key/scope and advancing revision/time. |
| outbox_events.causation_event_id self-reference | Event causation | Inline nullable self FK and self-inequality CHECK; committed earlier source event only, no invented causal loop. |

The full nontrivial strongly connected groups are {people, principals} and {school_profiles, campuses, academic_years, file_objects}. Other child actor references do not create reverse edges from principals back into those children.

**There is no command_receipts ↔ approval_requests FK cycle in the reviewed model.** Receipts reference requests; requests do not reference receipts. Create operation_contracts and requests before receipts, then transitions/applications. Applications reference both request and matching receipt through composite keys. This dependency restructure replaces the old conceptual "receipts before workflow core" order; no extra nullable bridge is needed.

**There is no audit ↔ workflow FK cycle either.** audit_events references request/receipt, but those tables have no audit_event FK. Create the audit relation after its structural parents and before bootstrap/runtime mutations. Deployment DDL has deployment evidence; business commands remain disabled until audit is available. Never add an unreviewed reverse pointer merely to mirror a UI relationship.

## 3. Complete application FK dependency inventory

Every line includes actor and composite relationships, not only the selected ERD edges. All are RESTRICT for delete/update unless the explicit external Auth exception below applies.

| Child | Columns | Parent | Referenced key | Creation |
|---|---|---|---|---|
| school_profiles | default_academic_year_id,id | academic_years | id,school_id | Named late FK; validate before bootstrap |
| school_profiles | logo_file_id | file_objects | id | Named late FK; validate before bootstrap |
| school_profiles | created_by | principals | id | Inline; parent already created |
| campuses | school_id | school_profiles | id | Inline; parent already created |
| campuses | created_by | principals | id | Inline; parent already created |
| rooms | campus_id | campuses | id | Inline; parent already created |
| rooms | created_by | principals | id | Inline; parent already created |
| academic_years | school_id | school_profiles | id | Inline; parent already created |
| academic_years | created_by | principals | id | Inline; parent already created |
| people | created_by | principals | id | Named late FK; validate before bootstrap |
| principals | person_id | people | id | Inline; parent already created |
| principals | created_by | principals | id | Inline self FK |
| principal_auth_bindings | principal_id,principal_kind | principals | id,kind | Inline; parent already created |
| principal_auth_bindings | created_by | principals | id | Inline; parent already created |
| principal_binding_events | binding_id,principal_id | principal_auth_bindings | id,principal_id | Inline; parent already created |
| principal_binding_events | created_by | principals | id | Inline; parent already created |
| login_aliases | principal_id | principals | id | Inline; parent already created |
| login_aliases | created_by | principals | id | Inline; parent already created |
| roles | created_by | principals | id | Inline; parent already created |
| permissions | created_by | principals | id | Inline; parent already created |
| role_permission_grants | role_id,role_family_only | roles | id,family_only | Inline; parent already created |
| role_permission_grants | permission_id,permission_family_safe | permissions | id,family_safe | Inline; parent already created |
| role_permission_grants | created_by | principals | id | Inline; parent already created |
| principal_role_assignments | principal_id,principal_kind | principals | id,kind | Inline; parent already created |
| principal_role_assignments | role_id,role_family_only | roles | id,family_only | Inline; parent already created |
| principal_role_assignments | created_by | principals | id | Inline; parent already created |
| permission_scope_contracts | permission_id | permissions | id | Inline; parent already created |
| permission_scope_contracts | created_by | principals | id | Inline; parent already created |
| assignment_permission_scopes | assignment_id,role_id | principal_role_assignments | id,role_id | Inline; parent already created |
| assignment_permission_scopes | grant_id,role_id,permission_id | role_permission_grants | id,role_id,permission_id | Inline; parent already created |
| assignment_permission_scopes | scope_contract_id,permission_id,scope_kind,resolver_key | permission_scope_contracts | id,permission_id,scope_kind,resolver_key | Inline; parent already created |
| assignment_permission_scopes | campus_id | campuses | id | Inline; parent already created |
| assignment_permission_scopes | created_by | principals | id | Inline; parent already created |
| operation_contracts | request_permission_id | permissions | id | Inline; parent already created |
| operation_contracts | review_permission_id | permissions | id | Inline; parent already created |
| operation_contracts | created_by | principals | id | Inline; parent already created |
| approval_policy_versions | operation_id | operation_contracts | id | Inline; parent already created |
| approval_policy_versions | campus_id | campuses | id | Inline; parent already created |
| approval_policy_versions | created_by | principals | id | Inline; parent already created |
| approval_step_templates | policy_id | approval_policy_versions | id | Inline; parent already created |
| approval_step_templates | reviewer_role_id | roles | id | Inline; parent already created |
| approval_step_templates | created_by | principals | id | Inline; parent already created |
| approval_requests | policy_id,operation_id | approval_policy_versions | id,operation_id | Inline; parent already created |
| approval_requests | operation_id,payload_schema_version | operation_contracts | id,payload_schema_version | Inline; parent already created |
| approval_requests | requester_id | principals | id | Inline; parent already created |
| approval_requests | campus_id | campuses | id | Inline; parent already created |
| approval_requests | created_by | principals | id | Inline; parent already created |
| approval_request_files | request_id | approval_requests | id | Inline; parent already created |
| approval_request_files | file_id | file_objects | id | Inline; parent already created |
| approval_request_files | created_by | principals | id | Inline; parent already created |
| approval_request_steps | request_id,policy_id | approval_requests | id,policy_id | Inline; parent already created |
| approval_request_steps | template_id,policy_id | approval_step_templates | id,policy_id | Inline; parent already created |
| approval_request_steps | created_by | principals | id | Inline; parent already created |
| approval_step_reviewers | step_id | approval_request_steps | id | Inline; parent already created |
| approval_step_reviewers | reviewer_id | principals | id | Inline; parent already created |
| approval_step_reviewers | created_by | principals | id | Inline; parent already created |
| approval_reviews | reviewer_assignment_id,step_id,reviewer_id | approval_step_reviewers | id,step_id,reviewer_id | Inline; parent already created |
| approval_reviews | created_by | principals | id | Inline; parent already created |
| approval_transitions | request_id | approval_requests | id | Inline; parent already created |
| approval_transitions | command_receipt_id | command_receipts | id | Inline; parent already created |
| approval_transitions | created_by | principals | id | Inline; parent already created |
| approval_applications | request_id,operation_id | approval_requests | id,operation_id | Inline; parent already created |
| approval_applications | command_receipt_id,operation_id,request_id | command_receipts | id,operation_id,request_id | Inline; parent already created |
| approval_applications | created_by | principals | id | Inline; parent already created |
| command_receipts | request_id,operation_id | approval_requests | id,operation_id | Inline; parent already created |
| command_receipts | principal_id | principals | id | Inline; parent already created |
| command_receipts | created_by | principals | id | Inline; parent already created |
| audit_events | actor_id,actor_kind | principals | id,kind | Inline; parent already created |
| audit_events | campus_id | campuses | id | Inline; parent already created |
| audit_events | command_receipt_id | command_receipts | id | Inline; parent already created |
| audit_events | approval_request_id | approval_requests | id | Inline; parent already created |
| audit_events | created_by | principals | id | Inline; parent already created |
| outbox_events | causation_event_id | outbox_events | id | Inline self FK |
| outbox_events | command_receipt_id | command_receipts | id | Inline; parent already created |
| outbox_events | created_by | principals | id | Inline; parent already created |
| event_consumer_deliveries | event_id | outbox_events | id | Inline; parent already created |
| event_consumer_deliveries | created_by | principals | id | Inline; parent already created |
| notifications | recipient_id,recipient_kind | principals | id,kind | Inline; parent already created |
| notifications | event_id | outbox_events | id | Inline; parent already created |
| notifications | created_by | principals | id | Inline; parent already created |
| notification_preferences | principal_id | principals | id | Inline; parent already created |
| notification_preferences | created_by | principals | id | Inline; parent already created |
| file_objects | owner_principal_id | principals | id | Inline; parent already created |
| file_objects | campus_id | campuses | id | Inline; parent already created |
| file_objects | replaces_file_id | file_objects | id | Inline self FK |
| file_objects | created_by | principals | id | Inline; parent already created |
| setting_revisions | campus_id | campuses | id | Inline; parent already created |
| setting_revisions | supersedes_id | setting_revisions | id | Inline self FK |
| setting_revisions | created_by | principals | id | Inline; parent already created |
| principal_auth_bindings | auth_user_id | EXTERNAL auth.users | id | Inline, DELETE SET NULL / UPDATE RESTRICT; null live binding denies login |

UUID snapshots in binding/audit evidence and typed descriptors are not missing edges: they are deliberately not FKs. Any targetful domain operation stays disabled until a future typed attachment adds real domain FKs and a required-child consistency check. F28/endpoint_ref has no active edge because the whole table is deferred.

## 4. Function, bootstrap and activation dependencies

Pure scalar CHECK/default helpers precede table creation. Authorization functions follow all RBAC and identity relations. Checked reads/mutations follow every table they use and the evidence writer. Managed Auth-unbind trigger installation is tested after bootstrap SYSTEM identities exist but before accepting live bindings. Deployment controls prevent an unbound intermediate installation from serving users.

Then apply the versioned bootstrap manifest, provision the first verified individual administrator through the restricted deployment path, and run the [execution test plan](../testing/02_foundation_database_execution_plan.md). All FK validations must succeed; activation must query constraint metadata and fail if any required constraint remains NOT VALID, missing or disabled. No constraint is left disabled to make the deployment succeed.

No schema-version app table, operational tenant discriminator, speculative domain or device table is added to break a cycle. The exact plan contains **33 Foundation tables**, **three late application FKs**, and the separately managed Auth UUID dependency.
