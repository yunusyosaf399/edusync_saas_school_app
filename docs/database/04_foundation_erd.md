# 04 - Foundation ERD

**Status: REVIEWED FOR SQL DRAFT, 2026-09-23. Documentation only.**

The [physical review](../decisions/FOUNDATION_PHYSICAL_DESIGN_REVIEW.md) selects 33 Foundation tables and defers F28. The [exact dependency graph](08_foundation_exact_dependency_graph.md) inventories every FK and the three late constraints.

Read the [physical catalog](05_foundation_physical_catalog.md) for every column and F01-F28 mapping, [constraint matrix](06_foundation_constraint_matrix.md) for enforcement, [RLS matrix](../security/03_foundation_rls_matrix.md) for exposure, and [TBD gate](../decisions/FOUNDATION_TBD_GATE.md) for unresolved decisions. These diagrams refine the [conceptual map](02_foundation_entity_map.md); they do not approve or implement it.

## Legend and boundaries

- **CONFIRMED requirement:** one customer school = one Supabase project. Campuses are scopes inside it. Person, principal and credentials are separate; history and authorization must survive account changes.
- Every named application entity below is a **PROPOSED physical table**. CamelCase diagram IDs map to snake_case catalog names. An entity appearing in multiple areas is the same table.
- **EXTERNAL MANAGED:** authUsers means Supabase auth.users; only its managed UUID key is referenced. It is not a proposed application table.
- **POSTPONED domain entity:** student/family/teaching/attendance/finance/marks/HR relationships are shown only as future boundaries in the final diagram. They have no proposed tables here.
- ER crow's feet show selected actual FK relationships: each child has one parent unless its parent end is optional. Omitted actor FKs, cross-area FKs and immutable snapshots are detailed in the catalog/matrix. Diagram PKs are abbreviated; diagrams are not complete column definitions. A 1:1 end means at most one referencing row under the proposed unique key, not that every parent must have a child.
- Optional UUID descriptors for future targets/results/endpoints are deliberately **not** drawn as enforceable FKs. Disabled contracts cannot authorize operations against absent domains.

## A. School / Campus / Academic Anchors

~~~mermaid
erDiagram
  schoolProfiles {
    uuid id PK
  }
  campuses {
    uuid id PK
  }
  rooms {
    uuid id PK
  }
  academicYears {
    uuid id PK
  }
  schoolProfiles ||--o{ campuses : "school_id"
  schoolProfiles ||--o{ academicYears : "school_id"
  campuses ||--o{ rooms : "campus_id"
  academicYears o|--o| schoolProfiles : "default_academic_year_id"
~~~

School singleton CHECK+UNIQUE prevents multiple school roots. School default year and logo are late-added FKs. Academic-year intervals are not assumed non-overlapping. Room campus ownership is stable.

## B. Identity / Principal / Auth

~~~mermaid
erDiagram
  people {
    uuid id PK
  }
  principals {
    uuid id PK
  }
  principalAuthBindings {
    uuid id PK
  }
  principalBindingEvents {
    uuid id PK
  }
  loginAliases {
    uuid id PK
  }
  authUsers {
    uuid id PK
  }
  people o|--o{ principals : "person_id"
  principals ||--o| principalAuthBindings : "principal_id"
  authUsers o|--o| principalAuthBindings : "live_auth_user_id"
  principals ||--o{ principalBindingEvents : "principal_id"
  principalAuthBindings ||--o{ principalBindingEvents : "binding_id"
  principals ||--o{ loginAliases : "principal_id"
~~~

principals.kind is INDIVIDUAL, FAMILY or SYSTEM. The review accepts one non-retired individual principal per Person with multiple historical retired principals. A FAMILY has its own live Auth UUID and no inherited Person grants. Auth deletion nulls only the live credential link; historical principal and binding-event snapshots remain. loginAliases is retained with ASCII normalization, permanent bytewise uniqueness and a non-enumerating gateway.

## C. RBAC / Permission / Scope

~~~mermaid
erDiagram
  roles {
    uuid id PK
  }
  permissions {
    uuid id PK
  }
  rolePermissionGrants {
    uuid id PK
  }
  principalRoleAssignments {
    uuid id PK
  }
  permissionScopeContracts {
    uuid id PK
  }
  assignmentPermissionScopes {
    uuid id PK
  }
  principals {
    uuid id PK
  }
  campuses {
    uuid id PK
  }
  principals ||--o{ principalRoleAssignments : "principal_id_and_kind"
  roles ||--o{ principalRoleAssignments : "role_id_and_family_only"
  roles ||--o{ rolePermissionGrants : "role_id_and_family_only"
  permissions ||--o{ rolePermissionGrants : "permission_id_and_family_safe"
  permissions ||--o{ permissionScopeContracts : "permission_id"
  principalRoleAssignments ||--o{ assignmentPermissionScopes : "assignment_id_and_role"
  rolePermissionGrants ||--o{ assignmentPermissionScopes : "grant_role_permission"
  permissionScopeContracts ||--o{ assignmentPermissionScopes : "contract_permission_kind_resolver"
  campuses o|--o{ assignmentPermissionScopes : "campus_id"
~~~

The three composite references into assignmentPermissionScopes enforce the same assignment role, grant role/action and permission scope contract. ALL has no campus target; CAMPUS requires a real campus FK; OWN/ASSIGNED call versioned allowlisted resolvers. Unknown/disabled resolver denies. roles.family_only and permissions.family_safe are immutable deployment classifications joined through composite FKs; FAMILY assignments require the Parent/Guardian ceiling.

Authorization intervals now use immutable scheduled starts/ends and genuine revocation times with serialized non-overlap. Natural expiry requires no revocation flag. Receipt rows are terminal-only; typed command_kind prevents phase confusion. These changes do not alter the drawn parent FK relationships.

## D. Approval / Workflow

~~~mermaid
erDiagram
  operationContracts {
    uuid id PK
  }
  approvalPolicyVersions {
    uuid id PK
  }
  approvalStepTemplates {
    uuid id PK
  }
  approvalRequests {
    uuid id PK
  }
  approvalRequestFiles {
    uuid id PK
  }
  approvalRequestSteps {
    uuid id PK
  }
  approvalStepReviewers {
    uuid id PK
  }
  approvalReviews {
    uuid id PK
  }
  approvalTransitions {
    uuid id PK
  }
  approvalApplications {
    uuid id PK
  }
  principals {
    uuid id PK
  }
  fileObjects {
    uuid id PK
  }
  commandReceipts {
    uuid id PK
  }
  operationContracts ||--o{ approvalPolicyVersions : "operation_id"
  approvalPolicyVersions ||--o{ approvalStepTemplates : "policy_id"
  approvalPolicyVersions ||--o{ approvalRequests : "policy_and_operation"
  operationContracts ||--o{ approvalRequests : "operation_and_payload_version"
  principals ||--o{ approvalRequests : "requester_id"
  approvalRequests ||--o{ approvalRequestFiles : "request_id"
  fileObjects ||--o{ approvalRequestFiles : "file_id"
  approvalRequests ||--o{ approvalRequestSteps : "request_and_policy"
  approvalStepTemplates ||--o{ approvalRequestSteps : "template_and_policy"
  approvalRequestSteps ||--o{ approvalStepReviewers : "step_id"
  principals ||--o{ approvalStepReviewers : "reviewer_id"
  approvalStepReviewers ||--o| approvalReviews : "assignment_step_reviewer"
  approvalRequestSteps ||--o| approvalReviews : "step_id"
  approvalRequests ||--o{ approvalTransitions : "request_id"
  approvalRequests ||--o| approvalApplications : "request_and_operation"
  commandReceipts ||--o| approvalApplications : "receipt_request_operation"
~~~

Policies and submitted intent freeze at activation/submission. Step candidates are normalized. The reviewed V1 retains sequential one-decision stages and defers quorum/parallel/delegation. FAILED/EXPIRED are absent from request V1; INVALIDATED denotes deterministic revalidation failure, while transient execution rollback leaves APPROVED. Each application has a unique request and receipt. Typed domain target/result child links must be added before domain contract activation; JSON payloads are data validated by an allowlisted handler, never patches to arbitrary tables. Request-policy and step-template composites preserve version consistency.

## E. Audit / Command / Event Outbox

~~~mermaid
erDiagram
  commandReceipts {
    uuid id PK
  }
  auditEvents {
    uuid id PK
  }
  outboxEvents {
    uuid id PK
  }
  eventConsumerDeliveries {
    uuid id PK
  }
  principals {
    uuid id PK
  }
  operationContracts {
    uuid id PK
  }
  approvalRequests {
    uuid id PK
  }
  principals ||--o{ commandReceipts : "principal_id"
  operationContracts ||--o{ commandReceipts : "command_contract"
  approvalRequests o|--o{ commandReceipts : "request_id"
  principals ||--o{ auditEvents : "actor_and_kind"
  commandReceipts o|--o{ auditEvents : "command_receipt_id"
  approvalRequests o|--o{ auditEvents : "approval_request_id"
  commandReceipts ||--o{ outboxEvents : "command_receipt_id"
  outboxEvents ||--o{ eventConsumerDeliveries : "event_id"
~~~

created_by (omitted from drawing) identifies executor; audit.actor_id identifies initiator. Receipt keys are unique per principal and versioned command contract; payload hash rejects key reuse with different intent. Event payload is immutable and delivery leases mutate only eventConsumerDeliveries. Audit target descriptors serve historical search, not generic authorization. External delivery is at least once.

## F. Notifications

~~~mermaid
erDiagram
  notifications {
    uuid id PK
  }
  notificationPreferences {
    uuid id PK
  }
  principals {
    uuid id PK
  }
  outboxEvents {
    uuid id PK
  }
  principals ||--o{ notifications : "recipient_and_kind"
  outboxEvents ||--o{ notifications : "event_id"
  principals ||--o{ notificationPreferences : "principal_id"
~~~

Recipient is a principal, not an email address or Person relationship. F28 is deferred entirely from the first SQL, so no channel entity or endpoint edge appears here. Later channel design must provide verified typed endpoint/recipient ownership. Preferences cannot grant access or override required category policy.

## G. Files / Configuration

~~~mermaid
erDiagram
  fileObjects {
    uuid id PK
  }
  settingRevisions {
    uuid id PK
  }
  principals {
    uuid id PK
  }
  campuses {
    uuid id PK
  }
  schoolProfiles {
    uuid id PK
  }
  principals ||--o{ fileObjects : "owner_principal_id"
  campuses o|--o{ fileObjects : "campus_id"
  fileObjects o|--o{ fileObjects : "replaces_file_id"
  fileObjects o|--o{ schoolProfiles : "logo_file_id"
  campuses o|--o{ settingRevisions : "campus_id"
  settingRevisions o|--o{ settingRevisions : "supersedes_id"
~~~

File bytes use provider-neutral adapters; fileObjects holds authoritative metadata and lineage, default PRIVATE, with immutable storage_location_key/object_key and no permanent private/signed URLs. [ADR-003](../decisions/ADR-003-provider-neutral-object-storage.md) adds no provider relation or FK; school_profiles.logo_file_id remains valid. Pending uploads need reconciliation. Stable configuration belongs to schoolProfiles; settingRevisions records typed, non-secret effective revisions with school/campus scope. Generated PDFs remain on demand.

## Combined dependency and activation view

~~~mermaid
flowchart TD
  boundary["CONFIRMED: one school project, many campuses"]
  managedAuth["EXTERNAL MANAGED: auth.users"]
  identity["PROPOSED: people, principals, live bindings and binding history"]
  anchors["PROPOSED: school, campus, room and academic year"]
  grants["PROPOSED: roles, permissions and complete scope chains"]
  contracts["PROPOSED: typed operation contracts and command receipts"]
  workflow["PROPOSED: policies, requests, steps, reviews and application evidence"]
  evidence["PROPOSED: immutable audit and outbox facts"]
  delivery["REVIEWED: consumer leases, inbox and IN_APP preferences"]
  files["PROPOSED: private file metadata and setting revisions"]
  domains["POSTPONED: academic, family, staff, attendance, finance and marks entities"]
  adapters["FUTURE: biometric, camera and RFID adapters"]
  boundary --> anchors
  managedAuth --> identity
  identity --> grants
  anchors --> grants
  grants --> contracts
  contracts --> workflow
  workflow --> evidence
  contracts --> evidence
  evidence --> delivery
  identity --> delivery
  anchors --> files
  files --> workflow
  domains -. "later typed targets, scope resolvers and file ownership" .-> workflow
  domains -. "later actual assignment checks" .-> grants
  adapters -. "source event, identity validation, canonical attendance command" .-> domains
~~~

Arrows express dependency/flow, not a ready-to-run migration order. Common actor FKs mean the bootstrap SYSTEM principal precedes actor-bearing records. The real cycles are Person/creator and school/year/logo: add the three named late FKs and validate them before bootstrap/activation. The [exact graph](08_foundation_exact_dependency_graph.md) cuts the three real cycles. Requests precede receipts, then transitions/applications and audit; there is no receipt/request or audit/workflow FK cycle in the selected structure.

No control-plane data replica, provider-specific device schema or business-domain truth table is part of this diagram. Future attendance adapters still feed the one canonical attendance domain.

Next task, not started: **FOUNDATION SQL MIGRATION DRAFT — FILES ONLY, NO SUPABASE EXECUTION.**

F23 also includes immutable purpose_code (TEXT, NOT NULL, deployment registry) under [ADR-004](../decisions/ADR-004-storage-plan-entitlements.md). No purpose/provider/entitlement relation is added; diagram relationships and the 33-table topology remain unchanged.
