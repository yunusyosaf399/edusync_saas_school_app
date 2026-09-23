# 05 - Foundation Physical Table and Column Catalog

**Status: PROPOSED for human physical-design review, 2026-09-23. No SQL, migrations, deployment, or production schema.**

Authority: [AGENTS.md](../../AGENTS.md), [specification](../requirements/School_OS_SaaS_Master_Specification_v0.2.md), [conceptual map](02_foundation_entity_map.md), [conventions](01_database_conventions.md), [identity](../security/01_identity_auth_model.md), [RBAC](../security/02_rbac_permission_scope_model.md), [approval design](../workflows/01_approval_engine_design.md), and [ADR-001](../decisions/ADR-001-foundation-database-principles.md).
Read with the [ERDs](04_foundation_erd.md), [constraint matrix](06_foundation_constraint_matrix.md), [RLS matrix](../security/03_foundation_rls_matrix.md), and [TBD gate](../decisions/FOUNDATION_TBD_GATE.md).

## 1. Scope and proposal conventions

CONFIRMED requirements: one school per Supabase project; multiple campuses; separate Person, Principal and Auth identity; bounded role/action/scope/assignment/workflow authorization; Parent/Guardian-only shared family principal; preserved history and approval/audit controls. All table names, columns, types, states, indexes and enforcement decompositions below are PROPOSED, not newly approved requirements. There are **34 proposed application tables** covering F01-F28. No student, enrollment, employee, attendance, finance, marks, device, biometric, provider endpoint, automation-rule or control-plane operational-copy tables are introduced.

Proposed namespaces are app (five explicitly allowlisted read tables) and app_private (all other application tables). T02 must approve namespace/exposure/runtime choices; app_private must not be an exposed API schema. All writes are protected commands; app is not a blanket schema grant. Narrow checked read projections expose selected private data where needed; their ownership and column privileges remain T04. Supabase-managed auth.users and Storage internals are external dependencies, not catalog entries.

Every table has an explicit UUID id PK below. UUID v4 generation is server-side; exact supported generator is T02. Type spellings are PostgreSQL types. A dash default means no default: caller must supply a value through the protected command. Server transaction time means a trusted server timestamp, not client time. Nullable optional values default to NULL. created_at is recording time, distinct from business/event time. created_by is the stable executing principal; where an initiating actor differs it has an explicit field. No credentials or personal identity data are packed into created_by.

Mutability legend: **I** immutable from insertion; **C** controlled command update; **F** draft-editable, frozen on policy activation or request submission; **E** one-way completion/end marker set by a protected transition; **V** server monotonic version. E fields are set together as an outcome, not individually by clients. Terminal command outcomes are immutable, including nullable result fields. Every mutable table uses expected row_version and increments it on accepted changes; updated_at is server maintained. Versioned draft terms cannot be unfrozen by toggling state. Triggers/privileges and protected commands must enforce these rules: a type or CHECK alone does not.

**Global FK/delete rule:** every actual application FK, including actor FKs, is ON DELETE RESTRICT and ON UPDATE RESTRICT. The sole exception is the live principal_auth_bindings.auth_user_id FK to managed auth.users.id: ON DELETE SET NULL, ON UPDATE RESTRICT. Snapshot UUIDs and explicitly deferred typed descriptors are not claimed as FKs. No cascade erases history. All ordinary client DELETE is denied, including draft and delivery tables; future retention cleanup needs a reviewed purpose-bound routine and T10 decision. PKs and unique constraints supply indexes; partial unique indexes are called out explicitly. No duplicate index is intended where an existing leading key supports the query.

Mutable authoritative records retain meaningful change evidence through synchronous audit; immutable records append evidence. All sensitive command effects, audit, durable receipt and outbox fact commit together when applicable. Recording an audit event does not recursively emit another audit event. Delivery polling/read flags do not produce a full business audit on every poll, but privileged replay, cancellation, sensitive dispatch/download and configuration changes do. No duration, automatic TTL or destructive purge is assumed. Raw audit/event/grant/auth data is not an offline cache.

## 2. Concept-to-table mapping

| Concept | Physical table(s) |
|---|---|
| F01 | school_profiles |
| F02 | campuses |
| F03 | rooms |
| F04 | academic_years |
| F05 | people |
| F06 | principals, principal_auth_bindings |
| F07 | principal_binding_events |
| F08 | login_aliases |
| F09 | roles |
| F10 | permissions, permission_scope_contracts |
| F11 | role_permission_grants |
| F12 | principal_role_assignments |
| F13 | permission_scope_contracts, assignment_permission_scopes |
| F14 | operation_contracts, approval_policy_versions |
| F15 | approval_step_templates |
| F16 | operation_contracts, approval_requests, approval_request_files |
| F17 | approval_request_steps, approval_step_reviewers |
| F18 | approval_reviews |
| F19 | audit_events |
| F20 | outbox_events |
| F21 | event_consumer_deliveries |
| F22 | notifications |
| F23 | approval_request_files, file_objects |
| F24 | setting_revisions |
| F25 | operation_contracts, approval_applications, command_receipts |
| F26 | approval_transitions, approval_applications |
| F27 | notification_preferences |
| F28 | notification_channel_deliveries |

F06 splits durable principals from replaceable live Auth binding slots so deleting credentials cannot delete historical actors. F10/F13 gain a permission-specific deployment allowlist, not a generic scope target registry. F14/F16/F25 share operation_contracts because submission and execution must resolve the same versioned typed contract. F16/F23 share the normalized request/file junction; file ownership and authorization remain separate. F17 splits step instances from candidate assignments to retain reassignment history without JSON reviewer arrays. F26 separates transition evidence from unique successful application evidence; F25 participates in the latter's durable result contract. F24 uses one revision relation; stable singleton settings remain F01. Other F concepts retain their separate physical responsibilities.

F08 is conditional on T03's username strategy. F28's endpoint relation is deliberately not invented: channel-delivery rows and sending remain disabled until a later reviewed typed endpoint FK is supplied. This unresolved link is an approval-gate decision about deferral, not a usable polymorphic ownership relationship.

## 3. Table catalog

### school_profiles — F01

**Proposed name:** app_private.school_profiles. **Status:** PROPOSED; detailed enforcement TBD before SQL.
**Purpose:** Singleton school identity and stable configuration. **Authority:** Authoritative. **PK:** id.

| Column | PostgreSQL type | Nullable | Default | Mutability | FK / reference |
|---|---|---|---|---|---|
| id | uuid | NO | server UUID v4 | I | — |
| singleton | boolean | NO | true | I | — |
| code | text | NO | — | I | — |
| name | text | NO | — | C | — |
| timezone | text | NO | — | C | — |
| currency_code | text | NO | — | C | — |
| locale | text | NO | — | C | — |
| contact_details | jsonb | NO | empty object | C | — |
| state | text | NO | SETUP | C | — |
| default_academic_year_id | uuid | YES | NULL | C | academic_years.id |
| logo_file_id | uuid | YES | NULL | C | file_objects.id |
| created_at | timestamptz | NO | server transaction time | I | — |
| created_by | uuid | NO | verified actor | I | principals.id |
| row_version | bigint | NO | 1 | V | — |
| updated_at | timestamptz | NO | server transaction time | C | — |

- **UNIQUE:** singleton; code
- **CHECK:** singleton=true; nonblank code/name/timezone/locale; currency_code is three uppercase letters; contact_details object; state SETUP/ACTIVE/INACTIVE; row_version > 0.
- **Additional indexes / purpose:** None beyond PK/UNIQUE; no speculative secondary index.
- **Protected validation, history and audit:** Validate timezone/currency/locale against supported catalogs; validate branding upload and default-year school; audit configuration changes. Composite FK (default_academic_year_id,id) -> academic_years(id,school_id), optional MATCH SIMPLE with non-null singleton id, prevents selecting a year outside the singleton school.
- **Archive/delete:** No normal hard deletion. Preserve referenced identity/history; controlled lifecycle or retained terminal rows as applicable. Global RESTRICT/retention rules apply; no cascade.
- **RLS / exposure:** school.view / school.configure; ALL school scope. No direct client table access; checked projection/command where authorized. See per-table matrix.
- **Offline:** Selected non-sensitive branding/configuration may be cached; version checks.

### campuses — F02

**Proposed name:** app.campuses. **Status:** PROPOSED; detailed enforcement TBD before SQL.
**Purpose:** Locations inside this school; never tenants. **Authority:** Authoritative. **PK:** id.

| Column | PostgreSQL type | Nullable | Default | Mutability | FK / reference |
|---|---|---|---|---|---|
| id | uuid | NO | server UUID v4 | I | — |
| school_id | uuid | NO | — | I | school_profiles.id |
| code | text | NO | — | I | — |
| name | text | NO | — | C | — |
| address | text | YES | NULL | C | — |
| state | text | NO | PLANNED | C | — |
| created_at | timestamptz | NO | server transaction time | I | — |
| created_by | uuid | NO | verified actor | I | principals.id |
| row_version | bigint | NO | 1 | V | — |
| updated_at | timestamptz | NO | server transaction time | C | — |

- **UNIQUE:** school_id,code
- **CHECK:** nonblank code/name; state PLANNED/ACTIVE/ARCHIVED; row_version > 0.
- **Additional indexes / purpose:** school_id,state — school campus listing
- **Protected validation, history and audit:** Audit label/address/state changes; archive referenced campus; no routine reparenting.
- **Archive/delete:** No normal hard deletion. Preserve referenced identity/history; controlled lifecycle or retained terminal rows as applicable. Global RESTRICT/retention rules apply; no cascade.
- **RLS / exposure:** campus.view / campus.manage; ALL or matching CAMPUS. Allowlisted authenticated row-filtered reads only. See per-table matrix.
- **Offline:** Authorized directory subset; archival invalidates eligibility.

### rooms — F03

**Proposed name:** app.rooms. **Status:** PROPOSED; detailed enforcement TBD before SQL.
**Purpose:** Room anchors without timetable/bed allocation. **Authority:** Authoritative. **PK:** id.

| Column | PostgreSQL type | Nullable | Default | Mutability | FK / reference |
|---|---|---|---|---|---|
| id | uuid | NO | server UUID v4 | I | — |
| campus_id | uuid | NO | — | I | campuses.id |
| code | text | NO | — | I | — |
| name | text | NO | — | C | — |
| kind_code | text | NO | — | C | — |
| capacity | integer | YES | NULL | C | — |
| state | text | NO | ACTIVE | C | — |
| created_at | timestamptz | NO | server transaction time | I | — |
| created_by | uuid | NO | verified actor | I | principals.id |
| row_version | bigint | NO | 1 | V | — |
| updated_at | timestamptz | NO | server transaction time | C | — |

- **UNIQUE:** campus_id,code
- **CHECK:** nonblank code/name/kind_code; capacity > 0 when present; state ACTIVE/UNAVAILABLE/ARCHIVED; row_version > 0.
- **Additional indexes / purpose:** campus_id,state — scoped room directory
- **Protected validation, history and audit:** Allowlisted kind catalog is deployment validated, not a new domain table; audit capacity/state; moving campus creates a reviewed replacement anchor.
- **Archive/delete:** No normal hard deletion. Preserve referenced identity/history; controlled lifecycle or retained terminal rows as applicable. Global RESTRICT/retention rules apply; no cascade.
- **RLS / exposure:** room.view / room.manage; parent CAMPUS or ALL. Allowlisted authenticated row-filtered reads only. See per-table matrix.
- **Offline:** Scoped reference cache; no offline authoritative reassignment.

### academic_years — F04

**Proposed name:** app.academic_years. **Status:** PROPOSED; detailed enforcement TBD before SQL.
**Purpose:** School-wide dated academic history. **Authority:** Authoritative. **PK:** id.

| Column | PostgreSQL type | Nullable | Default | Mutability | FK / reference |
|---|---|---|---|---|---|
| id | uuid | NO | server UUID v4 | I | — |
| school_id | uuid | NO | — | I | school_profiles.id |
| code | text | NO | — | I | — |
| label | text | NO | — | C | — |
| starts_on | date | NO | — | C | — |
| ends_on | date | NO | — | C | — |
| state | text | NO | PLANNED | C | — |
| created_at | timestamptz | NO | server transaction time | I | — |
| created_by | uuid | NO | verified actor | I | principals.id |
| row_version | bigint | NO | 1 | V | — |
| updated_at | timestamptz | NO | server transaction time | C | — |

- **UNIQUE:** school_id,code; id,school_id
- **CHECK:** starts_on <= ends_on; nonblank code/label; state PLANNED/ACTIVE/CLOSED/ARCHIVED; row_version > 0.
- **Additional indexes / purpose:** school_id,state,starts_on — year selector/history
- **Protected validation, history and audit:** Date corrections must preserve consuming-domain history; no assumed non-overlap or unique ACTIVE year (T05). Add composite school default-year FK after both tables exist.
- **Archive/delete:** No normal hard deletion. Preserve referenced identity/history; controlled lifecycle or retained terminal rows as applicable. Global RESTRICT/retention rules apply; no cascade.
- **RLS / exposure:** academic_year.view / academic_year.manage; school ALL. Allowlisted authenticated row-filtered reads only. See per-table matrix.
- **Offline:** Past years remain accessible within authorization.

### people — F05

**Proposed name:** app_private.people. **Status:** PROPOSED; detailed enforcement TBD before SQL.
**Purpose:** Human identity independent of credentials and business profiles. **Authority:** Authoritative. **PK:** id.

| Column | PostgreSQL type | Nullable | Default | Mutability | FK / reference |
|---|---|---|---|---|---|
| id | uuid | NO | server UUID v4 | I | — |
| display_name | text | NO | — | C | — |
| state | text | NO | ACTIVE | C | — |
| created_at | timestamptz | NO | server transaction time | I | — |
| created_by | uuid | NO | verified actor | I | principals.id |
| row_version | bigint | NO | 1 | V | — |
| updated_at | timestamptz | NO | server transaction time | C | — |

- **UNIQUE:** None beyond PK.
- **CHECK:** nonblank display_name; state ACTIVE/INACTIVE/ARCHIVED; row_version > 0.
- **Additional indexes / purpose:** None beyond PK/UNIQUE; no speculative secondary index.
- **Protected validation, history and audit:** Minimal identity only; no student/employee/medical attributes. Person merge/cardinality is T03; prohibit merge until approved; audit meaningful edits.
- **Archive/delete:** No normal hard deletion. Preserve referenced identity/history; controlled lifecycle or retained terminal rows as applicable. Global RESTRICT/retention rules apply; no cascade.
- **RLS / exposure:** person.view / person.manage; OWN or explicit authorized resolver; no guessed campus. No direct client table access; checked projection/command where authorized. See per-table matrix.
- **Offline:** Minimized authorized identity cache only; no raw person directory offline.

### principals — F06

**Proposed name:** app_private.principals. **Status:** PROPOSED; detailed enforcement TBD before SQL.
**Purpose:** Durable accountable actors; flatten ACCOUNT subtype into INDIVIDUAL/FAMILY, retain SYSTEM. **Authority:** Authoritative. **PK:** id.

| Column | PostgreSQL type | Nullable | Default | Mutability | FK / reference |
|---|---|---|---|---|---|
| id | uuid | NO | server UUID v4 | I | — |
| kind | text | NO | — | I | — |
| person_id | uuid | YES | NULL | I | people.id |
| label | text | NO | — | C | — |
| system_purpose | text | YES | NULL | I | — |
| state | text | NO | PENDING | C | — |
| created_at | timestamptz | NO | server transaction time | I | — |
| created_by | uuid | NO | verified actor | I | principals.id |
| row_version | bigint | NO | 1 | V | — |
| updated_at | timestamptz | NO | server transaction time | C | — |

- **UNIQUE:** id,kind; person_id — partial unique when kind INDIVIDUAL and state is not RETIRED
- **CHECK:** kind INDIVIDUAL/FAMILY/SYSTEM; INDIVIDUAL iff person_id present; SYSTEM iff system_purpose present; nonblank label; state PENDING/ACTIVE/SUSPENDED/RETIRED; row_version > 0.
- **Additional indexes / purpose:** person_id — non-retired lookup covered by partial unique; historical account search may use bounded identity service until measured
- **Protected validation, history and audit:** Proposed maximum one non-retired individual principal per Person; multiple retired historical principals retained (T03 approval blocker). FAMILY has no single person owner FK; later household links do not grant staff. SYSTEM cannot bind Auth. Bootstrap SYSTEM actor uses self-reference created_by in the insertion transaction, thereafter immutable; no anonymous placeholder actor. Audit lifecycle and preserve principal forever while referenced.
- **Archive/delete:** No normal hard deletion. Preserve referenced identity/history; controlled lifecycle or retained terminal rows as applicable. Global RESTRICT/retention rules apply; no cascade.
- **RLS / exposure:** principal.self / identity.manage; self safe projection or authorized administration. No direct client table access; checked projection/command where authorized. See per-table matrix.
- **Offline:** No grant decisions from cached principal; school/principal cache namespaces.

### principal_auth_bindings — F06

**Proposed name:** app_private.principal_auth_bindings. **Status:** PROPOSED; detailed enforcement TBD before SQL.
**Purpose:** One durable live-link slot per non-system principal to external managed Auth. **Authority:** Authoritative. **PK:** id.

| Column | PostgreSQL type | Nullable | Default | Mutability | FK / reference |
|---|---|---|---|---|---|
| id | uuid | NO | server UUID v4 | I | — |
| principal_id | uuid | NO | — | I | principals.id |
| principal_kind | text | NO | — | I | principals.kind via composite FK |
| auth_user_id | uuid | YES | NULL | C | external auth.users.id; ON DELETE SET NULL |
| binding_version | bigint | NO | 1 | V | — |
| bound_at | timestamptz | YES | NULL | C | — |
| created_at | timestamptz | NO | server transaction time | I | — |
| created_by | uuid | NO | verified actor | I | principals.id |
| row_version | bigint | NO | 1 | V | — |
| updated_at | timestamptz | NO | server transaction time | C | — |

- **UNIQUE:** principal_id; auth_user_id — nullable unique; id,principal_id
- **CHECK:** principal_kind INDIVIDUAL/FAMILY; binding_version > 0; auth_user_id present implies bound_at present; row_version > 0.
- **Additional indexes / purpose:** principal_id,principal_kind — covered by principal_id unique lookup
- **Protected validation, history and audit:** Composite FK (principal_id,principal_kind) -> principals(id,kind). Auth deletion nulls only live UUID, never actor IDs. NULL denies login; do not reuse old token identity. Protected relink validates credential ownership, increments binding_version, invalidates previous sessions and appends binding event. External Auth mutation reconciliation remains T01/T03/T04.
- **Archive/delete:** No normal hard deletion. Preserve referenced identity/history; controlled lifecycle or retained terminal rows as applicable. Global RESTRICT/retention rules apply; no cascade.
- **RLS / exposure:** SERVER ONLY; identity binding service; no client base SELECT. No direct client table access; checked projection/command where authorized. See per-table matrix.
- **Offline:** Never cached or exported.

### principal_binding_events — F07

**Proposed name:** app_private.principal_binding_events. **Status:** PROPOSED; detailed enforcement TBD before SQL.
**Purpose:** Immutable evidence for bind/unbind/recovery/relink operations. **Authority:** Authoritative evidence. **PK:** id.

| Column | PostgreSQL type | Nullable | Default | Mutability | FK / reference |
|---|---|---|---|---|---|
| id | uuid | NO | server UUID v4 | I | — |
| principal_id | uuid | NO | — | I | principals.id |
| binding_id | uuid | NO | — | I | principal_auth_bindings.id |
| event_kind | text | NO | — | I | — |
| old_auth_user_id | uuid | YES | NULL | I | snapshot only, not FK |
| new_auth_user_id | uuid | YES | NULL | I | snapshot only, not FK |
| binding_version | bigint | NO | — | I | — |
| reason | text | NO | — | I | — |
| created_at | timestamptz | NO | server transaction time | I | — |
| created_by | uuid | NO | verified actor | I | principals.id |

- **UNIQUE:** binding_id,binding_version
- **CHECK:** event_kind BOUND/UNBOUND/RELINKED/RECOVERED/RECONCILED; binding_version > 0; nonblank reason.
- **Additional indexes / purpose:** principal_id,created_at — binding investigation
- **Protected validation, history and audit:** Composite FK (binding_id,principal_id) -> principal_auth_bindings(id,principal_id). Validate binding belongs to principal under lock; snapshots deliberately survive Auth deletion. Auth-side deletion may require reconciliation evidence and must not be falsely described as atomically audited by app alone.
- **Archive/delete:** Append-only; retain evidence and references. No normal deletion or rewrite. Global RESTRICT/retention rules apply; no cascade.
- **RLS / exposure:** SERVER ONLY; identity audit projection with identity.audit permission. No direct client table access; checked projection/command where authorized. See per-table matrix.
- **Offline:** Never offline.

### login_aliases — F08

**Proposed name:** app_private.login_aliases. **Status:** PROPOSED / conditional T03.
**Purpose:** Conditional username lookup, retained only if username gateway is approved. **Authority:** Authoritative. **PK:** id.

| Column | PostgreSQL type | Nullable | Default | Mutability | FK / reference |
|---|---|---|---|---|---|
| id | uuid | NO | server UUID v4 | I | — |
| principal_id | uuid | NO | — | I | principals.id |
| normalized_alias | text | NO | — | I | — |
| state | text | NO | RESERVED | C | — |
| created_at | timestamptz | NO | server transaction time | I | — |
| created_by | uuid | NO | verified actor | I | principals.id |
| row_version | bigint | NO | 1 | V | — |
| updated_at | timestamptz | NO | server transaction time | C | — |

- **UNIQUE:** normalized_alias
- **CHECK:** nonblank normalized_alias; state RESERVED/ACTIVE/RETIRED; row_version > 0.
- **Additional indexes / purpose:** principal_id — revoke/account alias lookup
- **Protected validation, history and audit:** T03 must approve normalization/length/reuse and enumeration-safe lookup before drafting this optional table. Proposed no alias reuse; no password or recovery token here; only INDIVIDUAL/FAMILY; disable until Auth mapping approved; audit lifecycle.
- **Archive/delete:** No normal hard deletion. Preserve referenced identity/history; controlled lifecycle or retained terminal rows as applicable. Global RESTRICT/retention rules apply; no cascade.
- **RLS / exposure:** SERVER ONLY; narrow rate-limited username resolver, no anonymous table query. No direct client table access; checked projection/command where authorized. See per-table matrix.
- **Offline:** Never offline.

### roles — F09

**Proposed name:** app_private.roles. **Status:** PROPOSED; detailed enforcement TBD before SQL.
**Purpose:** Configurable roles with immutable family capability classification. **Authority:** Authoritative. **PK:** id.

| Column | PostgreSQL type | Nullable | Default | Mutability | FK / reference |
|---|---|---|---|---|---|
| id | uuid | NO | server UUID v4 | I | — |
| code | text | NO | — | I | — |
| label | text | NO | — | C | — |
| family_only | boolean | NO | false | I | — |
| state | text | NO | DRAFT | C | — |
| created_at | timestamptz | NO | server transaction time | I | — |
| created_by | uuid | NO | verified actor | I | principals.id |
| row_version | bigint | NO | 1 | V | — |
| updated_at | timestamptz | NO | server transaction time | C | — |

- **UNIQUE:** code; id,family_only
- **CHECK:** nonblank code/label; state DRAFT/ACTIVE/RETIRED; row_version > 0.
- **Additional indexes / purpose:** None beyond PK/UNIQUE; no speculative secondary index.
- **Protected validation, history and audit:** Only reviewed Parent/Guardian roles may be family_only; never relabel a staff role as family-safe. Changes require security administration, escalation ceiling and audit.
- **Archive/delete:** No normal hard deletion. Preserve referenced identity/history; controlled lifecycle or retained terminal rows as applicable. Global RESTRICT/retention rules apply; no cascade.
- **RLS / exposure:** SERVER ONLY; security.role.view / security.role.manage through restricted projection. No direct client table access; checked projection/command where authorized. See per-table matrix.
- **Offline:** No authoritative role cache.

### permissions — F10

**Proposed name:** app_private.permissions. **Status:** PROPOSED; detailed enforcement TBD before SQL.
**Purpose:** Deployment-owned action catalog, not editable action strings supplied by school clients. **Authority:** Authoritative. **PK:** id.

| Column | PostgreSQL type | Nullable | Default | Mutability | FK / reference |
|---|---|---|---|---|---|
| id | uuid | NO | server UUID v4 | I | — |
| code | text | NO | — | I | — |
| family_safe | boolean | NO | false | I | — |
| state | text | NO | DISABLED | C | — |
| created_at | timestamptz | NO | server transaction time | I | — |
| created_by | uuid | NO | verified actor | I | principals.id |
| row_version | bigint | NO | 1 | V | — |
| updated_at | timestamptz | NO | server transaction time | C | — |

- **UNIQUE:** code; id,family_safe
- **CHECK:** nonblank code; state ENABLED/DISABLED/RETIRED; row_version > 0.
- **Additional indexes / purpose:** None beyond PK/UNIQUE; no speculative secondary index.
- **Protected validation, history and audit:** Deployment allowlist defines real handler semantics and permitted Parent/Guardian capabilities. family_safe cannot be toggled to bypass family restriction. Audit catalog activation.
- **Archive/delete:** No normal hard deletion. Preserve referenced identity/history; controlled lifecycle or retained terminal rows as applicable. Global RESTRICT/retention rules apply; no cascade.
- **RLS / exposure:** SERVER ONLY; deployment owner; security.permission.view via safe projection. No direct client table access; checked projection/command where authorized. See per-table matrix.
- **Offline:** Client labels only; never authority.

### role_permission_grants — F11

**Proposed name:** app_private.role_permission_grants. **Status:** PROPOSED; detailed enforcement TBD before SQL.
**Purpose:** Role-to-action grants with declarative family ceiling. **Authority:** Authoritative. **PK:** id.

| Column | PostgreSQL type | Nullable | Default | Mutability | FK / reference |
|---|---|---|---|---|---|
| id | uuid | NO | server UUID v4 | I | — |
| role_id | uuid | NO | — | I | roles.id |
| role_family_only | boolean | NO | — | I | roles.family_only via composite FK |
| permission_id | uuid | NO | — | I | permissions.id |
| permission_family_safe | boolean | NO | — | I | permissions.family_safe via composite FK |
| valid_from | timestamptz | NO | server transaction time | I | — |
| revoked_at | timestamptz | YES | NULL | E | — |
| created_at | timestamptz | NO | server transaction time | I | — |
| created_by | uuid | NO | verified actor | I | principals.id |
| row_version | bigint | NO | 1 | V | — |
| updated_at | timestamptz | NO | server transaction time | C | — |

- **UNIQUE:** id,role_id,permission_id; role_id,permission_id — partial unique while revoked_at absent
- **CHECK:** role_family_only implies permission_family_safe; revoked_at >= valid_from if present; row_version > 0.
- **Additional indexes / purpose:** permission_id — permission retirement/dependency lookup
- **Protected validation, history and audit:** Composite FKs (role_id,role_family_only) -> roles(id,family_only), (permission_id,permission_family_safe) -> permissions(id,family_safe). Revoke once then insert new grant; no editing role/action/classification. Audit grant/revoke; grant ceiling enforced by command.
- **Archive/delete:** No normal hard deletion. Preserve referenced identity/history; controlled lifecycle or retained terminal rows as applicable. Global RESTRICT/retention rules apply; no cascade.
- **RLS / exposure:** SERVER ONLY; security.grant.manage; permitted delegation ceiling. No direct client table access; checked projection/command where authorized. See per-table matrix.
- **Offline:** No offline granting.

### principal_role_assignments — F12

**Proposed name:** app_private.principal_role_assignments. **Status:** PROPOSED; detailed enforcement TBD before SQL.
**Purpose:** Principal-bound role assignment and account context. **Authority:** Authoritative. **PK:** id.

| Column | PostgreSQL type | Nullable | Default | Mutability | FK / reference |
|---|---|---|---|---|---|
| id | uuid | NO | server UUID v4 | I | — |
| principal_id | uuid | NO | — | I | principals.id |
| principal_kind | text | NO | — | I | principals.kind via composite FK |
| role_id | uuid | NO | — | I | roles.id |
| role_family_only | boolean | NO | — | I | roles.family_only via composite FK |
| context_kind | text | NO | — | I | — |
| valid_from | timestamptz | NO | server transaction time | I | — |
| valid_until | timestamptz | YES | NULL | I | — |
| revoked_at | timestamptz | YES | NULL | E | — |
| created_at | timestamptz | NO | server transaction time | I | — |
| created_by | uuid | NO | verified actor | I | principals.id |
| row_version | bigint | NO | 1 | V | — |
| updated_at | timestamptz | NO | server transaction time | C | — |

- **UNIQUE:** id,role_id; principal_id,role_id,context_kind — partial unique while revoked_at absent
- **CHECK:** context_kind equals principal_kind; FAMILY implies role_family_only; valid_until > valid_from if present; revoked_at >= valid_from if present; row_version > 0.
- **Additional indexes / purpose:** principal_id,revoked_at,valid_from — live authorization assignment lookup; role_id — role retirement/review
- **Protected validation, history and audit:** Composite FKs (principal_id,principal_kind) -> principals(id,kind), (role_id,role_family_only) -> roles(id,family_only). SYSTEM assignments restricted to reviewed worker purpose. Expired rows must be explicitly revoked before replacement under conservative partial unique proposal. Audit all assignment/revoke operations.
- **Archive/delete:** No normal hard deletion. Preserve referenced identity/history; controlled lifecycle or retained terminal rows as applicable. Global RESTRICT/retention rules apply; no cascade.
- **RLS / exposure:** SERVER ONLY; security.assignment.manage; delegation ceiling and verified actor context. No direct client table access; checked projection/command where authorized. See per-table matrix.
- **Offline:** No offline role editing; cached claims cannot authorize.

### permission_scope_contracts — F10/F13

**Proposed name:** app_private.permission_scope_contracts. **Status:** PROPOSED; detailed enforcement TBD before SQL.
**Purpose:** Permission-specific allowlist of supported scope/resolver contracts. **Authority:** Authoritative. **PK:** id.

| Column | PostgreSQL type | Nullable | Default | Mutability | FK / reference |
|---|---|---|---|---|---|
| id | uuid | NO | server UUID v4 | I | — |
| permission_id | uuid | NO | — | I | permissions.id |
| scope_kind | text | NO | — | I | — |
| resolver_key | text | NO | — | I | — |
| contract_version | integer | NO | 1 | I | — |
| enabled | boolean | NO | false | C | — |
| created_at | timestamptz | NO | server transaction time | I | — |
| created_by | uuid | NO | verified actor | I | principals.id |
| row_version | bigint | NO | 1 | V | — |
| updated_at | timestamptz | NO | server transaction time | C | — |

- **UNIQUE:** permission_id,scope_kind,resolver_key,contract_version; id,permission_id,scope_kind,resolver_key
- **CHECK:** scope_kind ALL/CAMPUS/OWN/ASSIGNED; contract_version > 0; nonblank resolver_key; ALL/CAMPUS require DIRECT; OWN/ASSIGNED forbid DIRECT; row_version > 0.
- **Additional indexes / purpose:** None beyond PK/UNIQUE; no speculative secondary index.
- **Protected validation, history and audit:** Deployment-owned resolver dispatch, not dynamic SQL/function execution from strings. Unknown, absent, disabled or unsupported version denies. Domain OWN/ASSIGNED contract stays disabled until typed relationships exist; audit activation.
- **Archive/delete:** No normal hard deletion. Preserve referenced identity/history; controlled lifecycle or retained terminal rows as applicable. Global RESTRICT/retention rules apply; no cascade.
- **RLS / exposure:** SERVER ONLY; deployment owner; security.scope.view safe projection. No direct client table access; checked projection/command where authorized. See per-table matrix.
- **Offline:** No resolver evaluation from local client claims.

### assignment_permission_scopes — F13

**Proposed name:** app_private.assignment_permission_scopes. **Status:** PROPOSED; detailed enforcement TBD before SQL.
**Purpose:** Complete role-assignment/action/scope chain, never a free scope UUID. **Authority:** Authoritative. **PK:** id.

| Column | PostgreSQL type | Nullable | Default | Mutability | FK / reference |
|---|---|---|---|---|---|
| id | uuid | NO | server UUID v4 | I | — |
| assignment_id | uuid | NO | — | I | principal_role_assignments.id |
| grant_id | uuid | NO | — | I | role_permission_grants.id |
| role_id | uuid | NO | — | I | matching composite parent keys |
| permission_id | uuid | NO | — | I | matching grant and contract keys |
| scope_contract_id | uuid | NO | — | I | permission_scope_contracts.id |
| scope_kind | text | NO | — | I | permission_scope_contracts.scope_kind via composite FK |
| resolver_key | text | NO | — | I | permission_scope_contracts.resolver_key via composite FK |
| campus_id | uuid | YES | NULL | I | campuses.id |
| valid_from | timestamptz | NO | server transaction time | I | — |
| valid_until | timestamptz | YES | NULL | I | — |
| revoked_at | timestamptz | YES | NULL | E | — |
| created_at | timestamptz | NO | server transaction time | I | — |
| created_by | uuid | NO | verified actor | I | principals.id |
| row_version | bigint | NO | 1 | V | — |
| updated_at | timestamptz | NO | server transaction time | C | — |

- **UNIQUE:** assignment_id,grant_id,scope_contract_id,campus_id — partial unique unrevoked CAMPUS rows; assignment_id,grant_id,scope_contract_id — partial unique unrevoked non-CAMPUS rows
- **CHECK:** scope_kind ALL/CAMPUS/OWN/ASSIGNED; campus_id present iff CAMPUS; valid_until > valid_from if present; revoked_at >= valid_from if present; row_version > 0.
- **Additional indexes / purpose:** assignment_id,permission_id,revoked_at — complete grant lookup; grant_id,role_id,permission_id — grant revocation joins; scope_contract_id — resolver deactivation lookup; campus_id — scoped lookup/dependency
- **Protected validation, history and audit:** Composite FK (assignment_id,role_id) -> principal_role_assignments(id,role_id); (grant_id,role_id,permission_id) -> role_permission_grants(id,role_id,permission_id); (scope_contract_id,permission_id,scope_kind,resolver_key) -> permission_scope_contracts(id,permission_id,scope_kind,resolver_key). Every component NOT NULL. Audit binding/revoke, require live intersection and contextual assignment, never merge scope from another permission.
- **Archive/delete:** No normal hard deletion. Preserve referenced identity/history; controlled lifecycle or retained terminal rows as applicable. Global RESTRICT/retention rules apply; no cascade.
- **RLS / exposure:** SERVER ONLY; security.scope.manage; exact permission/grant ceiling. No direct client table access; checked projection/command where authorized. See per-table matrix.
- **Offline:** No offline grants; all replay reauthorized.

### operation_contracts — F14/F16/F25

**Proposed name:** app_private.operation_contracts. **Status:** PROPOSED; detailed enforcement TBD before SQL.
**Purpose:** Deployment-owned typed command registry shared by approval and receipt contracts. **Authority:** Authoritative. **PK:** id.

| Column | PostgreSQL type | Nullable | Default | Mutability | FK / reference |
|---|---|---|---|---|---|
| id | uuid | NO | server UUID v4 | I | — |
| code | text | NO | — | I | — |
| contract_version | integer | NO | 1 | I | — |
| handler_key | text | NO | — | I | — |
| request_permission_id | uuid | NO | — | I | permissions.id |
| review_permission_id | uuid | YES | NULL | I | permissions.id |
| payload_schema_version | integer | NO | 1 | I | — |
| requires_approval | boolean | NO | false | I | — |
| enabled | boolean | NO | false | C | — |
| created_at | timestamptz | NO | server transaction time | I | — |
| created_by | uuid | NO | verified actor | I | principals.id |
| row_version | bigint | NO | 1 | V | — |
| updated_at | timestamptz | NO | server transaction time | C | — |

- **UNIQUE:** code,contract_version; id,payload_schema_version
- **CHECK:** nonblank code/handler_key; positive versions; requires_approval implies review_permission_id present; row_version > 0.
- **Additional indexes / purpose:** request_permission_id — permission dependency; review_permission_id — review permission dependency
- **Protected validation, history and audit:** Code allowlist binds exact parser, typed target validator, authorize/apply and typed result validator; never execute a client handler name, SQL expression or arbitrary JSON patch. Targetless creation commands are possible only when declared by code. Audit enable/disable; new version for contract changes.
- **Archive/delete:** No normal hard deletion. Preserve referenced identity/history; controlled lifecycle or retained terminal rows as applicable. Global RESTRICT/retention rules apply; no cascade.
- **RLS / exposure:** SERVER ONLY; deployment owner; no user-editable handler registry. No direct client table access; checked projection/command where authorized. See per-table matrix.
- **Offline:** Client may cache descriptions, never executable authority.

### approval_policy_versions — F14

**Proposed name:** app_private.approval_policy_versions. **Status:** PROPOSED; detailed enforcement TBD before SQL.
**Purpose:** Immutable activated school/campus policy revision. **Authority:** Authoritative. **PK:** id.

| Column | PostgreSQL type | Nullable | Default | Mutability | FK / reference |
|---|---|---|---|---|---|
| id | uuid | NO | server UUID v4 | I | — |
| policy_key | text | NO | — | I | — |
| version | integer | NO | — | I | — |
| operation_id | uuid | NO | — | I | operation_contracts.id |
| campus_id | uuid | YES | NULL | I | campuses.id |
| state | text | NO | DRAFT | C | — |
| effective_from | timestamptz | YES | NULL | F | — |
| effective_until | timestamptz | YES | NULL | F | — |
| activated_at | timestamptz | YES | NULL | E | — |
| created_at | timestamptz | NO | server transaction time | I | — |
| created_by | uuid | NO | verified actor | I | principals.id |
| row_version | bigint | NO | 1 | V | — |
| updated_at | timestamptz | NO | server transaction time | C | — |

- **UNIQUE:** policy_key,version; id,operation_id
- **CHECK:** nonblank policy_key; version > 0; state DRAFT/ACTIVE/RETIRED; activated_at present implies effective_from present; effective_until > effective_from if both present; row_version > 0.
- **Additional indexes / purpose:** operation_id,campus_id,effective_from — policy selection
- **Protected validation, history and audit:** Terms including interval frozen at activation. Separate lifecycle state may retire policy with audited command. Lock operation row to serialize activation; reject ambiguous overlapping effective policies for same operation+scope; deterministic campus-over-school precedence. No EXCLUDE proposed until interval/extension choice T02/T06; command checks overlap under common lock.
- **Archive/delete:** No normal hard deletion. Preserve referenced identity/history; controlled lifecycle or retained terminal rows as applicable. Global RESTRICT/retention rules apply; no cascade.
- **RLS / exposure:** approval.policy.view / approval.policy.manage; ALL or matching CAMPUS. No direct client table access; checked projection/command where authorized. See per-table matrix.
- **Offline:** Versioned policy labels may cache; submission resolves server policy.

### approval_step_templates — F15

**Proposed name:** app_private.approval_step_templates. **Status:** PROPOSED; detailed enforcement TBD before SQL.
**Purpose:** Ordered stages belonging to a policy version. **Authority:** Authoritative. **PK:** id.

| Column | PostgreSQL type | Nullable | Default | Mutability | FK / reference |
|---|---|---|---|---|---|
| id | uuid | NO | server UUID v4 | I | — |
| policy_id | uuid | NO | — | F | approval_policy_versions.id |
| step_number | integer | NO | — | F | — |
| reviewer_role_id | uuid | NO | — | F | roles.id |
| required_reviews | integer | NO | 1 | F | — |
| selection_resolver_key | text | NO | — | F | — |
| created_at | timestamptz | NO | server transaction time | I | — |
| created_by | uuid | NO | verified actor | I | principals.id |
| row_version | bigint | NO | 1 | V | — |
| updated_at | timestamptz | NO | server transaction time | C | — |

- **UNIQUE:** policy_id,step_number; id,policy_id
- **CHECK:** step_number > 0; required_reviews = 1 (initial sequential baseline); nonblank selection_resolver_key; row_version > 0.
- **Additional indexes / purpose:** reviewer_role_id — reviewer role dependency
- **Protected validation, history and audit:** Freeze with activated parent; role is candidate filter, never sufficient approval authority. Sequential stages with one effective decision; multiple candidates may be listed, but parallel/quorum/delegation support is not activated. Changes beyond this baseline remain T06. Resolver must be allowlisted and enabled.
- **Archive/delete:** No normal hard deletion. Preserve referenced identity/history; controlled lifecycle or retained terminal rows as applicable. Global RESTRICT/retention rules apply; no cascade.
- **RLS / exposure:** approval.policy.view / approval.policy.manage; inherit policy scope. No direct client table access; checked projection/command where authorized. See per-table matrix.
- **Offline:** No offline policy authoring.

### approval_requests — F16

**Proposed name:** app_private.approval_requests. **Status:** PROPOSED; detailed enforcement TBD before SQL.
**Purpose:** Frozen submitted intent; mutable controlled lifecycle projection. **Authority:** Authoritative. **PK:** id.

| Column | PostgreSQL type | Nullable | Default | Mutability | FK / reference |
|---|---|---|---|---|---|
| id | uuid | NO | server UUID v4 | I | — |
| operation_id | uuid | NO | — | F | operation_contracts.id |
| payload_schema_version | integer | NO | — | F | operation_contracts.payload_schema_version via composite FK |
| policy_id | uuid | NO | — | F | approval_policy_versions.id |
| requester_id | uuid | NO | verified actor | I | principals.id |
| campus_id | uuid | YES | NULL | F | campuses.id |
| target_ref | uuid | YES | NULL | F | descriptor only; typed extension required |
| expected_target_version | bigint | YES | NULL | F | — |
| reason | text | NO | — | F | — |
| old_snapshot | jsonb | NO | empty object | F | — |
| requested_payload | jsonb | NO | — | F | — |
| state | text | NO | DRAFT | C | — |
| submitted_at | timestamptz | YES | NULL | E | — |
| created_at | timestamptz | NO | server transaction time | I | — |
| created_by | uuid | NO | verified actor | I | principals.id |
| row_version | bigint | NO | 1 | V | — |
| updated_at | timestamptz | NO | server transaction time | C | — |

- **UNIQUE:** id,policy_id; id,operation_id
- **CHECK:** nonblank reason; JSON objects; payload_schema_version > 0; expected_target_version > 0 if present; state DRAFT/SUBMITTED/PENDING/APPROVED/REJECTED/CANCELLED/EXPIRED/EXECUTED/FAILED; state outside DRAFT/CANCELLED implies submitted_at present; row_version > 0.
- **Additional indexes / purpose:** requester_id,created_at — own request history; campus_id,state — scoped request administration; policy_id,operation_id — policy/request dependency
- **Protected validation, history and audit:** Composite FKs (policy_id,operation_id) -> approval_policy_versions(id,operation_id), (operation_id,payload_schema_version) -> operation_contracts(id,payload_schema_version). Freeze intent, target, policy, requester and evidence at submission; server captures minimized old snapshot. Server validates exactly one typed target extension when required and expected target version, authorizes target and records transition. No generic target FK claim; future domain operations disabled until integration. Lifecycle follows the conceptual document: stale/authorization conflicts use FAILED with transition reason and require a new review path, never blind retry. Draft cancellation may have no submitted_at.
- **Archive/delete:** No normal hard deletion. Preserve referenced identity/history; controlled lifecycle or retained terminal rows as applicable. Global RESTRICT/retention rules apply; no cascade.
- **RLS / exposure:** approval.request.view / operation request permission; requester, assigned reviewer or scoped administrator; domain field filtering. No direct client table access; checked projection/command where authorized. See per-table matrix.
- **Offline:** Draft preparation only if T09 permits; submission/review/application online and version checked.

### approval_request_files — F16/F23

**Proposed name:** app_private.approval_request_files. **Status:** PROPOSED; detailed enforcement TBD before SQL.
**Purpose:** Normalized frozen supporting evidence links. **Authority:** Authoritative. **PK:** id.

| Column | PostgreSQL type | Nullable | Default | Mutability | FK / reference |
|---|---|---|---|---|---|
| id | uuid | NO | server UUID v4 | I | — |
| request_id | uuid | NO | — | I | approval_requests.id |
| file_id | uuid | NO | — | I | file_objects.id |
| purpose | text | NO | — | I | — |
| created_at | timestamptz | NO | server transaction time | I | — |
| created_by | uuid | NO | verified actor | I | principals.id |

- **UNIQUE:** request_id,file_id
- **CHECK:** nonblank purpose.
- **Additional indexes / purpose:** file_id — evidence retention/reference lookup
- **Protected validation, history and audit:** Add only while request DRAFT; no edits after submission. File must be validated, owned/visible to submitting context and retention-compatible; command enforces evidence authorization, not merely existence.
- **Archive/delete:** No normal hard deletion. Preserve referenced identity/history; controlled lifecycle or retained terminal rows as applicable. Global RESTRICT/retention rules apply; no cascade.
- **RLS / exposure:** approval.request.view / operation request permission; intersection of request and file visibility. No direct client table access; checked projection/command where authorized. See per-table matrix.
- **Offline:** Evidence download only under T09/T11 policy.

### approval_request_steps — F17

**Proposed name:** app_private.approval_request_steps. **Status:** PROPOSED; detailed enforcement TBD before SQL.
**Purpose:** Frozen instantiated stages with controlled current state. **Authority:** Authoritative. **PK:** id.

| Column | PostgreSQL type | Nullable | Default | Mutability | FK / reference |
|---|---|---|---|---|---|
| id | uuid | NO | server UUID v4 | I | — |
| request_id | uuid | NO | — | I | approval_requests.id |
| policy_id | uuid | NO | — | I | matching request/template keys |
| template_id | uuid | NO | — | I | approval_step_templates.id |
| step_number | integer | NO | — | I | — |
| required_reviews | integer | NO | — | I | — |
| state | text | NO | WAITING | C | — |
| opened_at | timestamptz | YES | NULL | E | — |
| closed_at | timestamptz | YES | NULL | E | — |
| created_at | timestamptz | NO | server transaction time | I | — |
| created_by | uuid | NO | verified actor | I | principals.id |
| row_version | bigint | NO | 1 | V | — |
| updated_at | timestamptz | NO | server transaction time | C | — |

- **UNIQUE:** request_id,step_number; id,request_id
- **CHECK:** step_number > 0; required_reviews = 1 (initial sequential baseline); state WAITING/OPEN/APPROVED/REJECTED/CANCELLED/EXPIRED; closed_at >= opened_at when both present; row_version > 0.
- **Additional indexes / purpose:** template_id,policy_id — template dependency
- **Protected validation, history and audit:** Composite FKs (request_id,policy_id) -> approval_requests(id,policy_id), (template_id,policy_id) -> approval_step_templates(id,policy_id). Command copies template terms at submission; no current-policy rewrite. One effective decision per stage selected under step/request locks; a second candidate racing the first cannot record a second effective review.
- **Archive/delete:** No normal hard deletion. Preserve referenced identity/history; controlled lifecycle or retained terminal rows as applicable. Global RESTRICT/retention rules apply; no cascade.
- **RLS / exposure:** approval.request.view / operation review permission; authorized participant in request scope. No direct client table access; checked projection/command where authorized. See per-table matrix.
- **Offline:** No offline reviewer state authority.

### approval_step_reviewers — F17

**Proposed name:** app_private.approval_step_reviewers. **Status:** PROPOSED; detailed enforcement TBD before SQL.
**Purpose:** Normalized reviewer candidates and eligibility history. **Authority:** Authoritative. **PK:** id.

| Column | PostgreSQL type | Nullable | Default | Mutability | FK / reference |
|---|---|---|---|---|---|
| id | uuid | NO | server UUID v4 | I | — |
| step_id | uuid | NO | — | I | approval_request_steps.id |
| reviewer_id | uuid | NO | — | I | principals.id |
| assigned_at | timestamptz | NO | server transaction time | I | — |
| withdrawn_at | timestamptz | YES | NULL | E | — |
| assignment_reason | text | NO | — | I | — |
| created_at | timestamptz | NO | server transaction time | I | — |
| created_by | uuid | NO | verified actor | I | principals.id |
| row_version | bigint | NO | 1 | V | — |
| updated_at | timestamptz | NO | server transaction time | C | — |

- **UNIQUE:** id,step_id,reviewer_id; step_id,reviewer_id — partial unique while withdrawn_at absent
- **CHECK:** withdrawn_at >= assigned_at when present; nonblank assignment_reason; row_version > 0.
- **Additional indexes / purpose:** reviewer_id,withdrawn_at,step_id — pending reviewer worklist
- **Protected validation, history and audit:** Candidates do not grant permission. Recheck live complete grants, conflict/self/family-interest rules and state at decision and final application as policy requires. Reassignment appends new row and withdraws old, auditing both; no raw JSON reviewer arrays.
- **Archive/delete:** No normal hard deletion. Preserve referenced identity/history; controlled lifecycle or retained terminal rows as applicable. Global RESTRICT/retention rules apply; no cascade.
- **RLS / exposure:** approval.request.view / operation review permission; same principal reviewer or scoped workflow administrator. No direct client table access; checked projection/command where authorized. See per-table matrix.
- **Offline:** No offline review; no shared-family/individual inbox mixing.

### approval_reviews — F18

**Proposed name:** app_private.approval_reviews. **Status:** PROPOSED; detailed enforcement TBD before SQL.
**Purpose:** Immutable signed-in reviewer decisions. **Authority:** Authoritative evidence. **PK:** id.

| Column | PostgreSQL type | Nullable | Default | Mutability | FK / reference |
|---|---|---|---|---|---|
| id | uuid | NO | server UUID v4 | I | — |
| reviewer_assignment_id | uuid | NO | — | I | approval_step_reviewers.id |
| step_id | uuid | NO | — | I | approval_request_steps.id |
| reviewer_id | uuid | NO | verified actor | I | principals.id |
| decision | text | NO | — | I | — |
| reason | text | NO | — | I | — |
| expected_request_version | bigint | NO | — | I | — |
| created_at | timestamptz | NO | server transaction time | I | — |
| created_by | uuid | NO | verified actor | I | principals.id |

- **UNIQUE:** reviewer_assignment_id; step_id — one effective decision for initial sequential baseline
- **CHECK:** decision APPROVE/REJECT; nonblank reason; expected_request_version > 0.
- **Additional indexes / purpose:** step_id — quorum and decision history
- **Protected validation, history and audit:** Composite FK (reviewer_assignment_id,step_id,reviewer_id) -> approval_step_reviewers(id,step_id,reviewer_id). Protected command requires created_by=reviewer_id, unwithdrawn candidate and eligibility; count distinct eligible principals, not duplicate assignment rows. Existing review never overwritten. Request/step version checks prevent races; reassignment before a decision may replace candidates, but never replace a recorded decision.
- **Archive/delete:** Append-only; retain evidence and references. No normal deletion or rewrite. Global RESTRICT/retention rules apply; no cascade.
- **RLS / exposure:** approval.request.view / operation review permission; filtered request participants. No direct client table access; checked projection/command where authorized. See per-table matrix.
- **Offline:** No offline authoritative decision.

### approval_transitions — F26

**Proposed name:** app_private.approval_transitions. **Status:** PROPOSED; detailed enforcement TBD before SQL.
**Purpose:** Append-only request state transitions. **Authority:** Authoritative evidence. **PK:** id.

| Column | PostgreSQL type | Nullable | Default | Mutability | FK / reference |
|---|---|---|---|---|---|
| id | uuid | NO | server UUID v4 | I | — |
| request_id | uuid | NO | — | I | approval_requests.id |
| sequence_number | bigint | NO | — | I | — |
| from_state | text | YES | NULL | I | — |
| to_state | text | NO | — | I | — |
| reason | text | NO | — | I | — |
| command_receipt_id | uuid | NO | — | I | command_receipts.id |
| created_at | timestamptz | NO | server transaction time | I | — |
| created_by | uuid | NO | verified actor | I | principals.id |

- **UNIQUE:** request_id,sequence_number
- **CHECK:** sequence_number > 0; states from request vocabulary; from_state NULL only sequence_number=1; nonblank reason.
- **Additional indexes / purpose:** command_receipt_id — command evidence lookup
- **Protected validation, history and audit:** Lock request; append contiguous transition and update projection in same transaction. CHECK cannot prove prior transition or legal edge; protected state machine and append-only enforcement must. Record conflict/expiry/application without editing previous history.
- **Archive/delete:** Append-only; retain evidence and references. No normal deletion or rewrite. Global RESTRICT/retention rules apply; no cascade.
- **RLS / exposure:** approval.request.view; inherit request visibility; writes only workflow command. No direct client table access; checked projection/command where authorized. See per-table matrix.
- **Offline:** History projection may be read online.

### approval_applications — F26/F25

**Proposed name:** app_private.approval_applications. **Status:** PROPOSED; detailed enforcement TBD before SQL.
**Purpose:** Permanent one-successful-application evidence, separate from retries/transitions. **Authority:** Authoritative evidence. **PK:** id.

| Column | PostgreSQL type | Nullable | Default | Mutability | FK / reference |
|---|---|---|---|---|---|
| id | uuid | NO | server UUID v4 | I | — |
| request_id | uuid | NO | — | I | approval_requests.id |
| command_receipt_id | uuid | NO | — | I | command_receipts.id |
| operation_id | uuid | NO | — | I | operation_contracts.id |
| applied_target_version | bigint | YES | NULL | I | — |
| result_ref | uuid | YES | NULL | I | typed result descriptor; domain extension required |
| created_at | timestamptz | NO | server transaction time | I | — |
| created_by | uuid | NO | verified actor | I | principals.id |

- **UNIQUE:** request_id; command_receipt_id
- **CHECK:** applied_target_version > 0 if present.
- **Additional indexes / purpose:** operation_id — operation usage/dependency
- **Protected validation, history and audit:** Composite FKs (request_id,operation_id) -> approval_requests(id,operation_id), (command_receipt_id,operation_id,request_id) -> command_receipts(id,operation_id,request_id). All child columns are NOT NULL, so a receipt for another request cannot satisfy the application FK. Application command still validates target/result extension and receipt success. Insert in same transaction as domain effect, receipt, audit and outbox; uniqueness persists after transport retries.
- **Archive/delete:** Append-only; retain evidence and references. No normal deletion or rewrite. Global RESTRICT/retention rules apply; no cascade.
- **RLS / exposure:** approval.request.view; inherit request visibility; application handler only. No direct client table access; checked projection/command where authorized. See per-table matrix.
- **Offline:** Replay resolves same durable outcome under current read authorization.

### command_receipts — F25

**Proposed name:** app_private.command_receipts. **Status:** PROPOSED; detailed enforcement TBD before SQL.
**Purpose:** Durable deduplication and authorized replay of protected commands. **Authority:** Authoritative. **PK:** id.

| Column | PostgreSQL type | Nullable | Default | Mutability | FK / reference |
|---|---|---|---|---|---|
| id | uuid | NO | server UUID v4 | I | — |
| principal_id | uuid | NO | verified actor | I | principals.id |
| operation_id | uuid | NO | — | I | operation_contracts.id |
| idempotency_key | text | NO | — | I | — |
| canonical_payload_hash | bytea | NO | — | I | — |
| canonicalization_version | integer | NO | 1 | I | — |
| expected_target_version | bigint | YES | NULL | I | — |
| request_id | uuid | YES | NULL | I | approval_requests.id |
| expected_request_version | bigint | YES | NULL | I | — |
| state | text | NO | ACCEPTED | C | — |
| result_kind | text | YES | NULL | E | — |
| result_ref | uuid | YES | NULL | E | typed descriptor; extension required |
| result_summary | jsonb | YES | NULL | E | — |
| error_code | text | YES | NULL | E | — |
| completed_at | timestamptz | YES | NULL | E | — |
| created_at | timestamptz | NO | server transaction time | I | — |
| created_by | uuid | NO | verified actor | I | principals.id |
| row_version | bigint | NO | 1 | V | — |
| updated_at | timestamptz | NO | server transaction time | C | — |

- **UNIQUE:** principal_id,operation_id,idempotency_key; id,operation_id; id,operation_id,request_id
- **CHECK:** idempotency_key length 1..200; hash exactly 32 bytes; positive canonicalization_version and optional expected versions; state ACCEPTED/SUCCEEDED/REJECTED; terminal iff completed_at present; SUCCEEDED implies result_kind present and error_code absent; REJECTED implies error_code present; result_summary object if present; row_version > 0.
- **Additional indexes / purpose:** request_id — request command/retry history
- **Protected validation, history and audit:** SHA-256 proposed, canonical bytes include operation contract version, typed target, expected versions, request and normalized payload; key namespace includes immutable operation version. Same namespace/key/different hash conflicts; same hash replays only after current authorization. Serialize unique-key race; ACCEPTED must not commit alone in initial transactional design. Failed business transactions roll back effects; deterministic rejection may commit separate receipt with no effect. Terminal fields frozen; no external exactly-once promise. Audit acceptance/outcome without secret payload; preserve dedupe tombstone and permanent result identity (T09/T10). Composite FK (request_id,operation_id) -> approval_requests(id,operation_id); nullable request_id is allowed only for registered non-request commands, validated by the handler.
- **Archive/delete:** No normal hard deletion. Preserve referenced identity/history; controlled lifecycle or retained terminal rows as applicable. Global RESTRICT/retention rules apply; no cascade.
- **RLS / exposure:** SERVER ONLY; command actor reads redacted own receipt via checked endpoint; purpose-bound command worker. No direct client table access; checked projection/command where authorized. See per-table matrix.
- **Offline:** Essential offline replay contract; no local authoritative receipt.

### audit_events — F19

**Proposed name:** app_private.audit_events. **Status:** PROPOSED; detailed enforcement TBD before SQL.
**Purpose:** Immutable security/business evidence, never queue state. **Authority:** Authoritative evidence. **PK:** id.

| Column | PostgreSQL type | Nullable | Default | Mutability | FK / reference |
|---|---|---|---|---|---|
| id | uuid | NO | server UUID v4 | I | — |
| actor_id | uuid | NO | verified actor | I | principals.id |
| actor_kind | text | NO | verified actor kind | I | principals.kind via composite FK |
| auth_subject_snapshot | uuid | YES | NULL | I | historical external Auth UUID; not FK |
| outcome | text | NO | — | I | — |
| reason | text | YES | NULL | I | — |
| authority_evidence | jsonb | NO | empty object | I | — |
| target_version | bigint | YES | NULL | I | — |
| event_type | text | NO | — | I | — |
| target_kind | text | NO | — | I | — |
| target_ref | uuid | YES | NULL | I | historical descriptor, intentionally not FK |
| campus_id | uuid | YES | NULL | I | campuses.id |
| command_receipt_id | uuid | YES | NULL | I | command_receipts.id |
| approval_request_id | uuid | YES | NULL | I | approval_requests.id |
| source_kind | text | NO | — | I | — |
| correlation_id | uuid | NO | server UUID v4 | I | — |
| occurred_at | timestamptz | NO | server transaction time | I | — |
| details | jsonb | NO | empty object | I | — |
| created_at | timestamptz | NO | server transaction time | I | — |
| created_by | uuid | NO | verified actor | I | principals.id |

- **UNIQUE:** None beyond PK.
- **CHECK:** nonblank event_type/target_kind; source_kind API/WORKER/AUTH_RECONCILIATION/DEPLOYMENT; details object; actor_kind INDIVIDUAL/FAMILY/SYSTEM; nonblank outcome; authority_evidence object; target_version > 0 if present.
- **Additional indexes / purpose:** target_kind,target_ref,occurred_at — target audit timeline; actor_id,occurred_at — actor investigation; campus_id,occurred_at — scoped audit review; command_receipt_id — transaction evidence; approval_request_id — workflow evidence
- **Protected validation, history and audit:** Composite FK (actor_id,actor_kind) -> principals(id,kind). actor_id is initiator; created_by is verified executor (including SYSTEM). authority_evidence holds allowlisted grant/policy/version snapshots, never secrets or an authorization source. Allowlisted redacted details, not unrestricted before/after secrets. target_ref is non-authoritative historical search descriptor; access requires event classification/scope and field filtering, never trusting a supplied target string. Protected writes append only; retention/legal hold T10; no routine DELETE, even super-admin. Platform admins still bypass application controls, so no tamper-proof claim.
- **Archive/delete:** Append-only; retain evidence and references. No normal deletion or rewrite. Global RESTRICT/retention rules apply; no cascade.
- **RLS / exposure:** SERVER ONLY; audit.view / audit.export restricted projection, explicit event scope; own actor is not automatic read right. No direct client table access; checked projection/command where authorized. See per-table matrix.
- **Offline:** No general offline audit cache.

### outbox_events — F20

**Proposed name:** app_private.outbox_events. **Status:** PROPOSED; detailed enforcement TBD before SQL.
**Purpose:** Immutable domain-event envelope committed with effect. **Authority:** Authoritative event evidence. **PK:** id.

| Column | PostgreSQL type | Nullable | Default | Mutability | FK / reference |
|---|---|---|---|---|---|
| id | uuid | NO | server UUID v4 | I | — |
| event_type | text | NO | — | I | — |
| schema_version | integer | NO | 1 | I | — |
| aggregate_kind | text | NO | — | I | — |
| causation_event_id | uuid | YES | NULL | I | outbox_events.id |
| aggregate_ref | uuid | NO | — | I | typed domain descriptor, not FK |
| aggregate_version | bigint | NO | — | I | — |
| command_receipt_id | uuid | NO | — | I | command_receipts.id |
| event_ordinal | integer | NO | — | I | — |
| correlation_id | uuid | NO | — | I | — |
| occurred_at | timestamptz | NO | server transaction time | I | — |
| payload | jsonb | NO | — | I | — |
| created_at | timestamptz | NO | server transaction time | I | — |
| created_by | uuid | NO | verified actor | I | principals.id |

- **UNIQUE:** command_receipt_id,event_ordinal
- **CHECK:** positive schema_version/aggregate_version/event_ordinal; nonblank event_type/aggregate_kind; payload object; causation_event_id differs from id.
- **Additional indexes / purpose:** aggregate_kind,aggregate_ref,aggregate_version — ordered aggregate replay; causation_event_id — event-chain investigation
- **Protected validation, history and audit:** Handler validates typed source and minimal versioned payload; publish after transaction commit only. No mutable retry/delivery columns. Immutable envelope can feed automation later but creates no automation rule tables. Retention coordinated with delivery/dedupe T08/T10.
- **Archive/delete:** Append-only; retain evidence and references. No normal deletion or rewrite. Global RESTRICT/retention rules apply; no cascade.
- **RLS / exposure:** SERVER ONLY; registered event workers; no client stream of raw events. No direct client table access; checked projection/command where authorized. See per-table matrix.
- **Offline:** Future sync may consume approved projections, not raw outbox.

### event_consumer_deliveries — F21

**Proposed name:** app_private.event_consumer_deliveries. **Status:** PROPOSED; detailed enforcement TBD before SQL.
**Purpose:** Per-consumer retry/lease state separate from immutable event. **Authority:** Derived operational state. **PK:** id.

| Column | PostgreSQL type | Nullable | Default | Mutability | FK / reference |
|---|---|---|---|---|---|
| id | uuid | NO | server UUID v4 | I | — |
| event_id | uuid | NO | — | I | outbox_events.id |
| consumer_key | text | NO | — | I | — |
| state | text | NO | PENDING | C | — |
| attempt_count | integer | NO | 0 | C | — |
| next_attempt_at | timestamptz | NO | server transaction time | C | — |
| lease_token | uuid | YES | NULL | C | — |
| lease_until | timestamptz | YES | NULL | C | — |
| last_error_code | text | YES | NULL | C | — |
| delivered_at | timestamptz | YES | NULL | E | — |
| created_at | timestamptz | NO | server transaction time | I | — |
| created_by | uuid | NO | verified actor | I | principals.id |
| row_version | bigint | NO | 1 | V | — |
| updated_at | timestamptz | NO | server transaction time | C | — |

- **UNIQUE:** event_id,consumer_key
- **CHECK:** nonblank consumer_key; attempt_count >= 0; state PENDING/LEASED/RETRY/DELIVERED/DEAD; lease_token and lease_until both present iff LEASED; DELIVERED iff delivered_at present; row_version > 0.
- **Additional indexes / purpose:** consumer_key,next_attempt_at — partial PENDING/RETRY work queue; consumer_key,lease_until — partial LEASED expiry recovery
- **Protected validation, history and audit:** Consumer code allowlist; fenced lease token and row_version compare-and-swap; stale worker cannot acknowledge a newer lease. Consumers dedupe effects by event+consumer. External side effect before crash may repeat. Audit manual replay/dead-letter intervention, operational attempts stay here; cleanup T08/T10.
- **Archive/delete:** No normal hard deletion. Preserve referenced identity/history; controlled lifecycle or retained terminal rows as applicable. Global RESTRICT/retention rules apply; no cascade.
- **RLS / exposure:** SERVER ONLY; purpose-bound event worker; no generic service-wide read mandate. No direct client table access; checked projection/command where authorized. See per-table matrix.
- **Offline:** No client offline copy.

### notifications — F22

**Proposed name:** app.notifications. **Status:** PROPOSED; detailed enforcement TBD before SQL.
**Purpose:** Principal-specific inbox projection with distinct account context. **Authority:** Derived inbox projection. **PK:** id.

| Column | PostgreSQL type | Nullable | Default | Mutability | FK / reference |
|---|---|---|---|---|---|
| id | uuid | NO | server UUID v4 | I | — |
| recipient_id | uuid | NO | — | I | principals.id |
| recipient_kind | text | NO | — | I | principals.kind via composite FK |
| event_id | uuid | NO | — | I | outbox_events.id |
| category_code | text | NO | — | I | — |
| context_key | text | NO | — | I | — |
| summary | jsonb | NO | — | I | — |
| read_at | timestamptz | YES | NULL | E | — |
| archived_at | timestamptz | YES | NULL | E | — |
| created_at | timestamptz | NO | server transaction time | I | — |
| created_by | uuid | NO | verified actor | I | principals.id |
| row_version | bigint | NO | 1 | V | — |
| updated_at | timestamptz | NO | server transaction time | C | — |

- **UNIQUE:** event_id,recipient_id,context_key,category_code; id,recipient_id
- **CHECK:** recipient_kind INDIVIDUAL/FAMILY; nonblank category_code/context_key; summary object; row_version > 0.
- **Additional indexes / purpose:** recipient_id,created_at — partial read_at/archived_at absent for unread inbox
- **Protected validation, history and audit:** Composite FK (recipient_id,recipient_kind) -> principals(id,kind). Context key is non-authorizing dedupe descriptor; validate using source handler and current disclosure policy. Safe summaries only; reauthorize deep-link target at read. Read/archive commands only, no client arbitrary summary update. Family inbox never automatically copied to individual account; sensitive deliveries audited.
- **Archive/delete:** No normal hard deletion. Preserve referenced identity/history; controlled lifecycle or retained terminal rows as applicable. Global RESTRICT/retention rules apply; no cascade.
- **RLS / exposure:** notification.own; exact authenticated principal, live binding, same account kind/context. Allowlisted authenticated row-filtered reads only. See per-table matrix.
- **Offline:** Encrypted own inbox subset only if T09 approves; purge on switch/revocation.

### notification_preferences — F27

**Proposed name:** app.notification_preferences. **Status:** PROPOSED; detailed enforcement TBD before SQL.
**Purpose:** Versioned current preference row by principal/category/channel. **Authority:** Authoritative. **PK:** id.

| Column | PostgreSQL type | Nullable | Default | Mutability | FK / reference |
|---|---|---|---|---|---|
| id | uuid | NO | server UUID v4 | I | — |
| principal_id | uuid | NO | — | I | principals.id |
| category_code | text | NO | — | I | — |
| channel_code | text | NO | — | I | — |
| enabled | boolean | NO | true | C | — |
| quiet_hours | jsonb | YES | NULL | C | — |
| created_at | timestamptz | NO | server transaction time | I | — |
| created_by | uuid | NO | verified actor | I | principals.id |
| row_version | bigint | NO | 1 | V | — |
| updated_at | timestamptz | NO | server transaction time | C | — |

- **UNIQUE:** principal_id,category_code,channel_code
- **CHECK:** nonblank category_code; channel_code IN_APP/EMAIL/PUSH; quiet_hours object if present; row_version > 0.
- **Additional indexes / purpose:** None beyond PK/UNIQUE; no speculative secondary index.
- **Protected validation, history and audit:** Validate registered category, timezone and mandatory-notice override before applying preference; no invented mandatory categories. SYSTEM preferences prohibited. Audit preference changes with prior values; T08 category/provider rules remain open.
- **Archive/delete:** No normal hard deletion. Preserve referenced identity/history; controlled lifecycle or retained terminal rows as applicable. Global RESTRICT/retention rules apply; no cascade.
- **RLS / exposure:** notification.preference.own; exact principal; preference command only. Allowlisted authenticated row-filtered reads only. See per-table matrix.
- **Offline:** Own preference snapshot; updates require version/reauthorization.

### notification_channel_deliveries — F28

**Proposed name:** app_private.notification_channel_deliveries. **Status:** PROPOSED / endpoint FK TBD; disabled.
**Purpose:** Context-bound external channel attempts distinct from inbox. **Authority:** Derived operational state. **PK:** id.

| Column | PostgreSQL type | Nullable | Default | Mutability | FK / reference |
|---|---|---|---|---|---|
| id | uuid | NO | server UUID v4 | I | — |
| notification_id | uuid | NO | — | I | notifications.id |
| recipient_id | uuid | NO | — | I | principals.id |
| channel_code | text | NO | — | I | — |
| endpoint_ref | uuid | NO | — | I | deferred verified endpoint typed FK; activation blocked |
| endpoint_version | bigint | NO | — | I | — |
| state | text | NO | PENDING | C | — |
| attempt_count | integer | NO | 0 | C | — |
| next_attempt_at | timestamptz | NO | server transaction time | C | — |
| lease_token | uuid | YES | NULL | C | — |
| lease_until | timestamptz | YES | NULL | C | — |
| provider_reference | text | YES | NULL | C | — |
| last_error_code | text | YES | NULL | C | — |
| sent_at | timestamptz | YES | NULL | E | — |
| created_at | timestamptz | NO | server transaction time | I | — |
| created_by | uuid | NO | verified actor | I | principals.id |
| row_version | bigint | NO | 1 | V | — |
| updated_at | timestamptz | NO | server transaction time | C | — |

- **UNIQUE:** notification_id,channel_code,endpoint_ref,endpoint_version
- **CHECK:** channel_code EMAIL/PUSH; endpoint_version > 0; attempt_count >= 0; state PENDING/LEASED/RETRY/SENT/CANCELLED/DEAD; lease fields both present iff LEASED; SENT iff sent_at present; row_version > 0.
- **Additional indexes / purpose:** channel_code,next_attempt_at — partial PENDING/RETRY dispatch; channel_code,lease_until — partial LEASED recovery; recipient_id — cancellation on revocation/account change
- **Protected validation, history and audit:** Composite FK (notification_id,recipient_id) -> notifications(id,recipient_id). endpoint_ref is explicitly unresolved, not a UUID pretending to guarantee ownership. No external-channel activation or row creation before T08 chooses verified typed endpoint relation/FK and account-bound ownership validation. Fenced retry, live permission/preferences/endpoint-version checks before send; at-least-once provider semantics; audit sensitive dispatch/cancel and manual replay.
- **Archive/delete:** No normal hard deletion. Preserve referenced identity/history; controlled lifecycle or retained terminal rows as applicable. Global RESTRICT/retention rules apply; no cascade.
- **RLS / exposure:** SERVER ONLY; purpose-bound notification worker; owner-safe delivery status through inbox projection. No direct client table access; checked projection/command where authorized. See per-table matrix.
- **Offline:** No endpoint/token/provider state in offline client.

### file_objects — F23

**Proposed name:** app_private.file_objects. **Status:** PROPOSED; detailed enforcement TBD before SQL.
**Purpose:** Private uploaded-file metadata; Storage object is externally managed. **Authority:** Authoritative. **PK:** id.

| Column | PostgreSQL type | Nullable | Default | Mutability | FK / reference |
|---|---|---|---|---|---|
| id | uuid | NO | server UUID v4 | I | — |
| owner_principal_id | uuid | NO | — | I | principals.id |
| campus_id | uuid | YES | NULL | I | campuses.id |
| bucket_code | text | NO | — | I | — |
| object_key | text | NO | — | I | — |
| content_type | text | NO | — | I | — |
| byte_size | bigint | NO | — | I | — |
| content_hash | bytea | NO | — | I | — |
| classification | text | NO | — | I | — |
| state | text | NO | PENDING | C | — |
| validated_at | timestamptz | YES | NULL | E | — |
| replaces_file_id | uuid | YES | NULL | I | file_objects.id |
| created_at | timestamptz | NO | server transaction time | I | — |
| created_by | uuid | NO | verified actor | I | principals.id |
| row_version | bigint | NO | 1 | V | — |
| updated_at | timestamptz | NO | server transaction time | C | — |

- **UNIQUE:** bucket_code,object_key
- **CHECK:** byte_size > 0; hash exactly 32 bytes; nonblank bucket_code/object_key/content_type/classification; state PENDING/VALIDATED/AVAILABLE/QUARANTINED/ARCHIVED/PURGED; AVAILABLE implies validated_at present; replaces_file_id differs from id; row_version > 0.
- **Additional indexes / purpose:** owner_principal_id,state — own upload reconciliation; campus_id,state — scoped document administration; replaces_file_id — version lineage lookup
- **Protected validation, history and audit:** Server allocates structured immutable object key; no signed URLs/secrets stored. Proposal allows pending row only after measured upload/checksum; pre-upload authorization uses short-lived server session, not metadata claim of validation. Exact max byte CHECK awaits T11 (product target max 1 MB after compression). Validate content, authorized typed owner link, retention and replacement chain; no direct edits to Storage metadata. Audit upload/quarantine/download/purge authorization. Metadata retained after approved physical object purge; PDFs generated on demand, exceptional stored document explicit only.
- **Archive/delete:** No normal hard deletion. Preserve referenced identity/history; controlled lifecycle or retained terminal rows as applicable. Global RESTRICT/retention rules apply; no cascade.
- **RLS / exposure:** file.view / file.upload / file.manage; owner is insufficient without live context and typed domain authorization; return safe metadata projection. No direct client table access; checked projection/command where authorized. See per-table matrix.
- **Offline:** Sensitive content only if T09/T11 permits encrypted cache.

### setting_revisions — F24

**Proposed name:** app_private.setting_revisions. **Status:** PROPOSED; detailed enforcement TBD before SQL.
**Purpose:** Append-only versioned non-secret configuration per school or campus. **Authority:** Authoritative. **PK:** id.

| Column | PostgreSQL type | Nullable | Default | Mutability | FK / reference |
|---|---|---|---|---|---|
| id | uuid | NO | server UUID v4 | I | — |
| setting_key | text | NO | — | I | — |
| campus_id | uuid | YES | NULL | I | campuses.id |
| revision | integer | NO | — | I | — |
| value_schema_version | integer | NO | 1 | I | — |
| value | jsonb | NO | — | I | — |
| effective_from | timestamptz | NO | — | I | — |
| supersedes_id | uuid | YES | NULL | I | setting_revisions.id |
| created_at | timestamptz | NO | server transaction time | I | — |
| created_by | uuid | NO | verified actor | I | principals.id |

- **UNIQUE:** setting_key,revision — partial school-level campus_id absent; setting_key,campus_id,revision — partial campus_id present; setting_key,effective_from — partial school-level; setting_key,campus_id,effective_from — partial campus_id present
- **CHECK:** nonblank setting_key; positive revision/value_schema_version; value JSON object; supersedes_id differs from id.
- **Additional indexes / purpose:** supersedes_id — revision lineage lookup
- **Protected validation, history and audit:** Deployment-owned typed key/schema allowlist; bounded JSON for justified configuration only, no secret/provider credential/settings-as-arbitrary-code. Serialize on school/campus anchor to allocate revisions; validate supersedes same key/scope and lower revision, effective-time ordering, no forks; choose latest effective revision at server time with explicit campus-over-school fallback. New revision for every change. Audit changes; stable timezone/currency/default year remain school_profiles.
- **Archive/delete:** Append-only; retain evidence and references. No normal deletion or rewrite. Global RESTRICT/retention rules apply; no cascade.
- **RLS / exposure:** setting.view / setting.manage; ALL or matching CAMPUS; safe key/field projection. No direct client table access; checked projection/command where authorized. See per-table matrix.
- **Offline:** Cache safe effective revisions only; server validates command-effective version.

## 4. Identity and typed extension boundaries

auth.users is managed by Supabase; this package neither defines it nor assumes its other internal columns. The live UUID binds one non-system principal and is globally unique within this school project. A NULL live binding or inactive principal denies authentication-to-application resolution. Deleting Auth nulls the live UUID only; all business/audit created_by, reviewer, requester and actor references remain attached to the durable principal. The binding slot and immutable binding events survive. Controlled unbind/relink deactivates old authority before external Auth work; a SET NULL caused by external deletion cannot be falsely described as already atomically audited. T04 must specify trigger/reconciliation, binding-version updates and external Auth failure evidence. [Supabase's managed user-data boundary](https://supabase.com/docs/guides/auth/managing-user-data).

The proposed partial unique people-to-non-retired-individual account rule, permanent aliases and flattening ACCOUNT+account_type into INDIVIDUAL/FAMILY are reviewable choices (T01/T03). FAMILY has its own Auth UUID, assignments, inbox, endpoints and caches. An individual Teacher+Parent principal keeps both roles; linked people/contact details do not transfer either role to a shared account. No UI switch or step-up can turn FAMILY into INDIVIDUAL.

Future approval target attachments are domain-owned, typed child relations with a unique request FK, a real FK to that domain target, and an operation discriminator checked against the request. A protected submission command and deferred consistency trigger must require exactly one correct typed target attachment for targetful operations; parent FKs alone cannot prove a child exists. The same pattern applies to typed result/evidence links and file ownership. Domain introduction adds constraints, handler validation and tests together before enabling that operation. target_ref, result_ref, endpoint_ref and event/audit descriptors are explicitly not universal referential integrity. No arbitrary target table name or JSON patch is executable.

No school_operational tenant_id or organization_id is needed. school_id appears only where it expresses a real singleton parent relationship. Schema deployment versions remain in deployment-controlled migration history plus checked source version/checksum; this proposal does not invent an application-editable schema-version table.

## 5. Next review

Next task: **FOUNDATION PHYSICAL DESIGN REVIEW**. Review the A gates, approve or amend the proposed catalog and resolve the B gates before **FOUNDATION SQL MIGRATION DRAFT**. This document does not authorize SQL generation or deployment.
