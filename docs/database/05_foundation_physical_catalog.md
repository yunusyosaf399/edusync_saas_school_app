# 05 - Foundation Physical Table and Column Catalog

**Status: REVIEWED FOR SQL DRAFT, 2026-09-23. No SQL, migrations, deployment, or production schema.**

The [physical review](../decisions/FOUNDATION_PHYSICAL_DESIGN_REVIEW.md) selects 33 of the 34 catalog candidates; F28 is deferred.

Authority: [AGENTS.md](../../AGENTS.md), [specification](../requirements/School_OS_SaaS_Master_Specification_v0.2.md), [conceptual map](02_foundation_entity_map.md), [conventions](01_database_conventions.md), [identity](../security/01_identity_auth_model.md), [RBAC](../security/02_rbac_permission_scope_model.md), [approval design](../workflows/01_approval_engine_design.md), and [ADR-001](../decisions/ADR-001-foundation-database-principles.md).
Read with the [ERDs](04_foundation_erd.md), [constraint matrix](06_foundation_constraint_matrix.md), [RLS matrix](../security/03_foundation_rls_matrix.md), and [TBD gate](../decisions/FOUNDATION_TBD_GATE.md).

## 1. Scope and proposal conventions

CONFIRMED requirements: one school per Supabase project; multiple campuses; separate Person, Principal and Auth identity; bounded role/action/scope/assignment/workflow authorization; Parent/Guardian-only shared family principal; preserved history and approval/audit controls. Physical decisions are selected in the review without changing product invariants. There are **34 reviewed candidates covering F01-F28: 33 initial Foundation SQL tables and one deferred F28 table**. No student, enrollment, employee, attendance, finance, marks, device, biometric, provider endpoint, automation-rule or control-plane operational-copy tables are introduced.

Proposed namespaces are app (five explicitly allowlisted read tables) and app_private (all other application tables). T02 selects PostgreSQL 15+ compatibility and these namespaces; app_private must not be an exposed API schema. All writes are protected commands; app is not a blanket schema grant. Narrow checked read projections expose selected private data where needed; their ownership and column privileges are selected in [execution security](../security/04_foundation_execution_security.md). Supabase-managed auth.users remains an external dependency. Object-storage provider internals are outside the relational catalog and are not assumed to be Supabase-managed; see [ADR-003](../decisions/ADR-003-provider-neutral-object-storage.md).

Every table has an explicit UUID id PK below. UUID v4 generation is server-side; selected generator is pg_catalog.gen_random_uuid(), with no required extension. Type spellings are PostgreSQL types. A dash default means no default: caller must supply a value through the protected command. Server transaction time means a trusted server timestamp, not client time. Nullable optional values default to NULL. created_at is recording time, distinct from business/event time. created_by is the stable executing principal; where an initiating actor differs it has an explicit field. No credentials or personal identity data are packed into created_by.

Mutability legend: **I** immutable from insertion; **C** controlled command update; **F** draft-editable, frozen on policy activation or request submission; **E** one-way completion/end marker set by a protected transition; **V** server monotonic version. E fields are set together as an outcome, not individually by clients. Terminal command outcomes are immutable, including nullable result fields. Every mutable table uses expected row_version and increments it on accepted changes; updated_at is server maintained. Versioned draft terms cannot be unfrozen by toggling state. Triggers/privileges and protected commands must enforce these rules: a type or CHECK alone does not.

**Global FK/delete rule:** every actual application FK, including actor FKs, is ON DELETE RESTRICT and ON UPDATE RESTRICT. The sole exception is the live principal_auth_bindings.auth_user_id FK to managed auth.users.id: ON DELETE SET NULL, ON UPDATE RESTRICT. Snapshot UUIDs and explicitly deferred typed descriptors are not claimed as FKs. No cascade erases history. All ordinary client DELETE is denied, including draft and delivery tables; future retention cleanup needs a reviewed purpose-bound routine and T10 decision. PKs and unique constraints supply indexes; partial unique indexes are called out explicitly. Authorization intervals use serialized non-overlap instead of unrevoked-row uniqueness. Global technical input/JSON bounds and canonicalization from review R06 apply to the relevant columns in addition to per-table CHECKs. No duplicate index is intended where an existing leading key supports the query.

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

F08 is retained with the reviewed ASCII alias policy. F28 is excluded entirely from the first SQL draft, including columns/FKs/indexes/policies; its catalog section is deferred design history. Introduce it only with a later verified typed endpoint ownership model.

## 3. Table catalog

### school_profiles — F01

**Proposed name:** app_private.school_profiles. **Status:** REVIEWED FOR SQL DRAFT; implementation pending.
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

- **UNIQUE:** singleton; no redundant code index on the singleton
- **CHECK:** singleton=true; nonblank code/name/timezone/locale; currency_code is three uppercase letters; contact_details object; state SETUP/ACTIVE/INACTIVE; row_version > 0.
- **Additional indexes / purpose:** None beyond PK/UNIQUE; no speculative secondary index.
- **Protected validation, history and audit:** Validate timezone/currency/locale against supported catalogs; validate branding upload and default-year school; audit configuration changes. Composite FK (default_academic_year_id,id) -> academic_years(id,school_id), optional MATCH SIMPLE with non-null singleton id, prevents selecting a year outside the singleton school.
- **Archive/delete:** No normal hard deletion. Preserve referenced identity/history; controlled lifecycle or retained terminal rows as applicable. Global RESTRICT/retention rules apply; no cascade.
- **RLS / exposure:** school.view / school.configure; ALL school scope. No direct client table access; checked projection/command where authorized. See per-table matrix.
- **Offline:** Selected non-sensitive branding/configuration may be cached; version checks.

### campuses — F02

**Proposed name:** app.campuses. **Status:** REVIEWED FOR SQL DRAFT; implementation pending.
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

**Proposed name:** app.rooms. **Status:** REVIEWED FOR SQL DRAFT; implementation pending.
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

**Proposed name:** app.academic_years. **Status:** REVIEWED FOR SQL DRAFT; implementation pending.
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

**Proposed name:** app_private.people. **Status:** REVIEWED FOR SQL DRAFT; implementation pending.
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

**Proposed name:** app_private.principals. **Status:** REVIEWED FOR SQL DRAFT; implementation pending.
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
- **Protected validation, history and audit:** Accepted maximum one non-retired individual principal per Person; multiple retired historical principals retained (accepted review R01). FAMILY has no single person owner FK; later household links do not grant staff. SYSTEM cannot bind Auth. Bootstrap SYSTEM actor uses self-reference created_by in the insertion transaction, thereafter immutable; no anonymous placeholder actor. Audit lifecycle and preserve principal forever while referenced.
- **Archive/delete:** No normal hard deletion. Preserve referenced identity/history; controlled lifecycle or retained terminal rows as applicable. Global RESTRICT/retention rules apply; no cascade.
- **RLS / exposure:** principal.self / identity.manage; self safe projection or authorized administration. No direct client table access; checked projection/command where authorized. See per-table matrix.
- **Offline:** No grant decisions from cached principal; school/principal cache namespaces.

### principal_auth_bindings — F06

**Proposed name:** app_private.principal_auth_bindings. **Status:** REVIEWED FOR SQL DRAFT; implementation pending.
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
| tokens_valid_from | timestamptz | NO | next whole UTC second at binding/recovery | C | — |
| created_by | uuid | NO | verified actor | I | principals.id |
| row_version | bigint | NO | 1 | V | — |
| updated_at | timestamptz | NO | server transaction time | C | — |

- **UNIQUE:** principal_id; auth_user_id — nullable unique; id,principal_id
- **CHECK:** principal_kind INDIVIDUAL/FAMILY; binding_version > 0; auth_user_id present implies bound_at present; row_version > 0; tokens_valid_from is a finite whole-second instant.
- **Additional indexes / purpose:** principal_id,principal_kind — covered by principal_id unique lookup
- **Protected validation, history and audit:** Composite FK (principal_id,principal_kind) -> principals(id,kind). One live binding per principal/Auth UUID. Verified JWT subject must match current live UUID; principal ACTIVE, current Auth account exists, and signed iat >= tokens_valid_from. Controlled bind/recovery increments binding_version and advances the cutoff. Never reassign an Auth UUID to a different principal, including historical bindings. Auth deletion SET NULL trigger advances version/cutoff and appends SYSTEM binding/audit evidence; it never deletes actor history. [Execution security](../security/04_foundation_execution_security.md) defines the exact trust, lock and ownership rules.
- **Archive/delete:** No normal hard deletion. Preserve referenced identity/history; controlled lifecycle or retained terminal rows as applicable. Global RESTRICT/retention rules apply; no cascade.
- **RLS / exposure:** SERVER ONLY; identity binding service; no client base SELECT. No direct client table access; checked projection/command where authorized. See per-table matrix.
- **Offline:** Never cached or exported.

### principal_binding_events — F07

**Proposed name:** app_private.principal_binding_events. **Status:** REVIEWED FOR SQL DRAFT; implementation pending.
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
- **Additional indexes / purpose:** principal_id,created_at — binding investigation; new_auth_user_id,principal_id — detect historical cross-principal Auth UUID reuse
- **Protected validation, history and audit:** Composite FK (binding_id,principal_id) -> principal_auth_bindings(id,principal_id). Validate binding belongs to principal under lock; snapshots deliberately survive Auth deletion. Auth-side deletion may require reconciliation evidence and must not be falsely described as atomically audited by app alone.
- **Archive/delete:** Append-only; retain evidence and references. No normal deletion or rewrite. Global RESTRICT/retention rules apply; no cascade.
- **RLS / exposure:** SERVER ONLY; identity audit projection with identity.audit permission. No direct client table access; checked projection/command where authorized. See per-table matrix.
- **Offline:** Never offline.

### login_aliases — F08

**Proposed name:** app_private.login_aliases. **Status:** REVIEWED FOR SQL DRAFT; implementation pending.
**Purpose:** Retained school-local username lookup through a protected gateway. **Authority:** Authoritative. **PK:** id.

| Column | PostgreSQL type | Nullable | Default | Mutability | FK / reference |
|---|---|---|---|---|---|
| id | uuid | NO | server UUID v4 | I | — |
| principal_id | uuid | NO | — | I | principals.id |
| normalized_alias | text COLLATE C | NO | — | I | — |
| state | text | NO | RESERVED | C | — |
| created_at | timestamptz | NO | server transaction time | I | — |
| created_by | uuid | NO | verified actor | I | principals.id |
| row_version | bigint | NO | 1 | V | — |
| updated_at | timestamptz | NO | server transaction time | C | — |

- **UNIQUE:** normalized_alias
- **CHECK:** normalized_alias matches ASCII [a-z][a-z0-9._-]{2,31}; state RESERVED/ACTIVE/RETIRED; row_version > 0.
- **Additional indexes / purpose:** principal_id — revoke/account alias lookup
- **Protected validation, history and audit:** KEEP in Foundation. Normalize by trimming ASCII U+0020 space at ends and folding A-Z to a-z, then require 3..32 ASCII characters matching the CHECK; reject all other whitespace/non-ASCII rather than normalize confusables. Exact bytewise school-local uniqueness includes retired aliases; no reuse. Only non-SYSTEM principals. Passwords, recovery tokens and Auth destination identifiers are never returned by a public lookup. A rate-limited login gateway resolves internally to the live binding and managed Auth identity, with generic failures; no anonymous enumeration API. Protected provisioning and audited retirement; person merging remains deferred.
- **Archive/delete:** No normal hard deletion. Preserve referenced identity/history; controlled lifecycle or retained terminal rows as applicable. Global RESTRICT/retention rules apply; no cascade.
- **RLS / exposure:** SERVER ONLY; narrow rate-limited username resolver, no anonymous table query. No direct client table access; checked projection/command where authorized. See per-table matrix.
- **Offline:** Never offline.

### roles — F09

**Proposed name:** app_private.roles. **Status:** REVIEWED FOR SQL DRAFT; implementation pending.
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

**Proposed name:** app_private.permissions. **Status:** REVIEWED FOR SQL DRAFT; implementation pending.
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

**Proposed name:** app_private.role_permission_grants. **Status:** REVIEWED FOR SQL DRAFT; implementation pending.
**Purpose:** Role-to-action grants with declarative family ceiling. **Authority:** Authoritative. **PK:** id.

| Column | PostgreSQL type | Nullable | Default | Mutability | FK / reference |
|---|---|---|---|---|---|
| id | uuid | NO | server UUID v4 | I | — |
| role_id | uuid | NO | — | I | roles.id |
| role_family_only | boolean | NO | — | I | roles.family_only via composite FK |
| permission_id | uuid | NO | — | I | permissions.id |
| permission_family_safe | boolean | NO | — | I | permissions.family_safe via composite FK |
| valid_from | timestamptz | NO | server wall-clock time after authorization lock | I | — |
| valid_until | timestamptz | YES | NULL | I | — |
| revoked_at | timestamptz | YES | NULL | E | — |
| created_at | timestamptz | NO | server transaction time | I | — |
| created_by | uuid | NO | verified actor | I | principals.id |
| row_version | bigint | NO | 1 | V | — |
| updated_at | timestamptz | NO | server transaction time | C | — |

- **UNIQUE:** id,role_id,permission_id
- **CHECK:** role_family_only implies permission_family_safe; revoked_at >= created_at if present; finite validity instants; row_version > 0; valid_until > valid_from if present.
- **Additional indexes / purpose:** permission_id — permission retirement/dependency lookup; role_id,permission_id,valid_from — logical grant overlap/replacement lookup
- **Protected validation, history and audit:** Composite FKs (role_id,role_family_only) -> roles(id,family_only), (permission_id,permission_family_safe) -> permissions(id,family_safe). Preserve scheduled expiry or record a genuine revocation, then insert a non-overlapping replacement; no editing role/action/classification. Audit grant/revoke; grant ceiling enforced by command. Effective interval is [valid_from, min(valid_until, revoked_at)), missing end is infinity; revocation before a scheduled start means empty interval. No overlap for the same logical assignment/grant/scope key. Naturally expired rows retain NULL revoked_at and allow non-overlapping replacement. Protected security commands acquire the school authorization exclusive transaction lock before checking overlap and writing; defensive triggers recheck, direct DML is forbidden. No time-dependent partial index or unapproved range extension. See review R04 and execution security.
- **Archive/delete:** No normal hard deletion. Preserve referenced identity/history; controlled lifecycle or retained terminal rows as applicable. Global RESTRICT/retention rules apply; no cascade.
- **RLS / exposure:** SERVER ONLY; security.grant.manage; permitted delegation ceiling. No direct client table access; checked projection/command where authorized. See per-table matrix.
- **Offline:** No offline granting.

### principal_role_assignments — F12

**Proposed name:** app_private.principal_role_assignments. **Status:** REVIEWED FOR SQL DRAFT; implementation pending.
**Purpose:** Principal-bound role assignment and account context. **Authority:** Authoritative. **PK:** id.

| Column | PostgreSQL type | Nullable | Default | Mutability | FK / reference |
|---|---|---|---|---|---|
| id | uuid | NO | server UUID v4 | I | — |
| principal_id | uuid | NO | — | I | principals.id |
| principal_kind | text | NO | — | I | principals.kind via composite FK |
| role_id | uuid | NO | — | I | roles.id |
| role_family_only | boolean | NO | — | I | roles.family_only via composite FK |
| context_kind | text | NO | — | I | — |
| valid_from | timestamptz | NO | server wall-clock time after authorization lock | I | — |
| valid_until | timestamptz | YES | NULL | I | — |
| revoked_at | timestamptz | YES | NULL | E | — |
| created_at | timestamptz | NO | server transaction time | I | — |
| created_by | uuid | NO | verified actor | I | principals.id |
| row_version | bigint | NO | 1 | V | — |
| updated_at | timestamptz | NO | server transaction time | C | — |

- **UNIQUE:** id,role_id
- **CHECK:** context_kind equals principal_kind; FAMILY implies role_family_only; valid_until > valid_from if present; revoked_at >= created_at if present; finite validity instants; row_version > 0.
- **Additional indexes / purpose:** principal_id,role_id,context_kind,valid_from — live assignment and logical interval overlap lookup; role_id — role retirement/review
- **Protected validation, history and audit:** Composite FKs (principal_id,principal_kind) -> principals(id,kind), (role_id,role_family_only) -> roles(id,family_only). SYSTEM assignments restricted to reviewed worker purpose. Audit all assignment/revoke operations. Effective interval is [valid_from, min(valid_until, revoked_at)), missing end is infinity; revocation before a scheduled start means empty interval. No overlap for the same logical assignment/grant/scope key. Naturally expired rows retain NULL revoked_at and allow non-overlapping replacement. Protected security commands acquire the school authorization exclusive transaction lock before checking overlap and writing; defensive triggers recheck, direct DML is forbidden. No time-dependent partial index or unapproved range extension. See review R04 and execution security.
- **Archive/delete:** No normal hard deletion. Preserve referenced identity/history; controlled lifecycle or retained terminal rows as applicable. Global RESTRICT/retention rules apply; no cascade.
- **RLS / exposure:** SERVER ONLY; security.assignment.manage; delegation ceiling and verified actor context. No direct client table access; checked projection/command where authorized. See per-table matrix.
- **Offline:** No offline role editing; cached claims cannot authorize.

### permission_scope_contracts — F10/F13

**Proposed name:** app_private.permission_scope_contracts. **Status:** REVIEWED FOR SQL DRAFT; implementation pending.
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

**Proposed name:** app_private.assignment_permission_scopes. **Status:** REVIEWED FOR SQL DRAFT; implementation pending.
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
| valid_from | timestamptz | NO | server wall-clock time after authorization lock | I | — |
| valid_until | timestamptz | YES | NULL | I | — |
| revoked_at | timestamptz | YES | NULL | E | — |
| created_at | timestamptz | NO | server transaction time | I | — |
| created_by | uuid | NO | verified actor | I | principals.id |
| row_version | bigint | NO | 1 | V | — |
| updated_at | timestamptz | NO | server transaction time | C | — |

- **UNIQUE:** None beyond PK.
- **CHECK:** scope_kind ALL/CAMPUS/OWN/ASSIGNED; campus_id present iff CAMPUS; valid_until > valid_from if present; revoked_at >= created_at if present; finite validity instants; row_version > 0.
- **Additional indexes / purpose:** assignment_id,permission_id,revoked_at — complete grant lookup; grant_id,role_id,permission_id — grant revocation joins; scope_contract_id — resolver deactivation lookup; campus_id — scoped lookup/dependency; assignment_id,grant_id,scope_contract_id,campus_id,valid_from — logical scope interval overlap including NULL campus
- **Protected validation, history and audit:** Composite FK (assignment_id,role_id) -> principal_role_assignments(id,role_id); (grant_id,role_id,permission_id) -> role_permission_grants(id,role_id,permission_id); (scope_contract_id,permission_id,scope_kind,resolver_key) -> permission_scope_contracts(id,permission_id,scope_kind,resolver_key). Every component NOT NULL. Audit binding/revoke, require live intersection and contextual assignment, never merge scope from another permission. Effective interval is [valid_from, min(valid_until, revoked_at)), missing end is infinity; revocation before a scheduled start means empty interval. No overlap for the same logical assignment/grant/scope key. Naturally expired rows retain NULL revoked_at and allow non-overlapping replacement. Protected security commands acquire the school authorization exclusive transaction lock before checking overlap and writing; defensive triggers recheck, direct DML is forbidden. No time-dependent partial index or unapproved range extension. See review R04 and execution security.
- **Archive/delete:** No normal hard deletion. Preserve referenced identity/history; controlled lifecycle or retained terminal rows as applicable. Global RESTRICT/retention rules apply; no cascade.
- **RLS / exposure:** SERVER ONLY; security.scope.manage; exact permission/grant ceiling. No direct client table access; checked projection/command where authorized. See per-table matrix.
- **Offline:** No offline grants; all replay reauthorized.

### operation_contracts — F14/F16/F25

**Proposed name:** app_private.operation_contracts. **Status:** REVIEWED FOR SQL DRAFT; implementation pending.
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

**Proposed name:** app_private.approval_policy_versions. **Status:** REVIEWED FOR SQL DRAFT; implementation pending.
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
- **Protected validation, history and audit:** Terms including interval frozen at activation. Separate lifecycle state may retire policy with audited command. Lock operation row to serialize activation; reject ambiguous overlapping effective policies for same operation+scope; deterministic campus-over-school precedence. No EXCLUDE extension required: the authorization-exclusive lock and operation row serialize activation. Campus override precedes school policy; ambiguous matches reject. Retirement stops new selection, not the pinned existing version; explicit security invalidation blocks affected requests.
- **Archive/delete:** No normal hard deletion. Preserve referenced identity/history; controlled lifecycle or retained terminal rows as applicable. Global RESTRICT/retention rules apply; no cascade.
- **RLS / exposure:** approval.policy.view / approval.policy.manage; ALL or matching CAMPUS. No direct client table access; checked projection/command where authorized. See per-table matrix.
- **Offline:** Versioned policy labels may cache; submission resolves server policy.

### approval_step_templates — F15

**Proposed name:** app_private.approval_step_templates. **Status:** REVIEWED FOR SQL DRAFT; implementation pending.
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
- **Protected validation, history and audit:** Freeze with activated parent; role is candidate filter, never sufficient approval authority. Sequential stages with one effective decision; multiple candidates may be listed, but parallel/quorum/delegation support is not activated. Parallel/quorum/delegation are deferred. No self-approval or same-Person alternate-account approval; family conflict proof is domain-owned and missing proof denies. Resolver must be allowlisted and enabled.
- **Archive/delete:** No normal hard deletion. Preserve referenced identity/history; controlled lifecycle or retained terminal rows as applicable. Global RESTRICT/retention rules apply; no cascade.
- **RLS / exposure:** approval.policy.view / approval.policy.manage; inherit policy scope. No direct client table access; checked projection/command where authorized. See per-table matrix.
- **Offline:** No offline policy authoring.

### approval_requests — F16

**Proposed name:** app_private.approval_requests. **Status:** REVIEWED FOR SQL DRAFT; implementation pending.
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
- **CHECK:** nonblank reason; JSON objects; payload_schema_version > 0; expected_target_version > 0 if present; state DRAFT/SUBMITTED/PENDING/APPROVED/REJECTED/CANCELLED/EXECUTED/INVALIDATED; state outside DRAFT/CANCELLED implies submitted_at present; row_version > 0.
- **Additional indexes / purpose:** requester_id,created_at — own request history; campus_id,state — scoped request administration; policy_id,operation_id — policy/request dependency
- **Protected validation, history and audit:** Composite FKs (policy_id,operation_id) -> approval_policy_versions(id,operation_id), (operation_id,payload_schema_version) -> operation_contracts(id,payload_schema_version). Freeze intent, target, policy, requester and evidence at submission; server captures minimized old snapshot. Server validates exactly one typed target extension when required and expected target version, authorizes target and records transition. No generic target FK claim; future domain operations disabled until integration. Reviewed lifecycle R05: APPROVED does not mean EXECUTED. No FAILED request state. Transient execution errors roll back and retain APPROVED; deterministic stale-target/lost-authority conditions can record INVALIDATED with reason and rejection receipt, requiring a new request. Expiry timers are deferred. Draft cancellation may have no submitted_at.
- **Archive/delete:** No normal hard deletion. Preserve referenced identity/history; controlled lifecycle or retained terminal rows as applicable. Global RESTRICT/retention rules apply; no cascade.
- **RLS / exposure:** approval.request.view / operation request permission; requester, assigned reviewer or scoped administrator; domain field filtering. No direct client table access; checked projection/command where authorized. See per-table matrix.
- **Offline:** Draft preparation only if T09 permits; submission/review/application online and version checked.

### approval_request_files — F16/F23

**Proposed name:** app_private.approval_request_files. **Status:** REVIEWED FOR SQL DRAFT; implementation pending.
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

**Proposed name:** app_private.approval_request_steps. **Status:** REVIEWED FOR SQL DRAFT; implementation pending.
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
- **CHECK:** step_number > 0; required_reviews = 1 (initial sequential baseline); state WAITING/OPEN/APPROVED/REJECTED/CANCELLED; closed_at >= opened_at when both present; row_version > 0.
- **Additional indexes / purpose:** template_id,policy_id — template dependency
- **Protected validation, history and audit:** Composite FKs (request_id,policy_id) -> approval_requests(id,policy_id), (template_id,policy_id) -> approval_step_templates(id,policy_id). Command copies template terms at submission; no current-policy rewrite. One effective decision per stage selected under step/request locks; a second candidate racing the first cannot record a second effective review.
- **Archive/delete:** No normal hard deletion. Preserve referenced identity/history; controlled lifecycle or retained terminal rows as applicable. Global RESTRICT/retention rules apply; no cascade.
- **RLS / exposure:** approval.request.view / operation review permission; authorized participant in request scope. No direct client table access; checked projection/command where authorized. See per-table matrix.
- **Offline:** No offline reviewer state authority.

### approval_step_reviewers — F17

**Proposed name:** app_private.approval_step_reviewers. **Status:** REVIEWED FOR SQL DRAFT; implementation pending.
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

**Proposed name:** app_private.approval_reviews. **Status:** REVIEWED FOR SQL DRAFT; implementation pending.
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
- **Additional indexes / purpose:** step_id UNIQUE reused for one effective decision/history; no duplicate secondary index
- **Protected validation, history and audit:** Composite FK (reviewer_assignment_id,step_id,reviewer_id) -> approval_step_reviewers(id,step_id,reviewer_id). Protected command requires created_by=reviewer_id, unwithdrawn candidate and eligibility; one effective decision per stage; no self/same-Person approval and no Super Admin bypass. Existing review never overwritten. Request/step version checks prevent races; reassignment before a decision may replace candidates, but never replace a recorded decision.
- **Archive/delete:** Append-only; retain evidence and references. No normal deletion or rewrite. Global RESTRICT/retention rules apply; no cascade.
- **RLS / exposure:** approval.request.view / operation review permission; filtered request participants. No direct client table access; checked projection/command where authorized. See per-table matrix.
- **Offline:** No offline authoritative decision.

### approval_transitions — F26

**Proposed name:** app_private.approval_transitions. **Status:** REVIEWED FOR SQL DRAFT; implementation pending.
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

**Proposed name:** app_private.approval_applications. **Status:** REVIEWED FOR SQL DRAFT; implementation pending.
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

**Proposed name:** app_private.command_receipts. **Status:** REVIEWED FOR SQL DRAFT; implementation pending.
**Purpose:** Durable deduplication and authorized replay of protected commands. **Authority:** Authoritative. **PK:** id.

| Column | PostgreSQL type | Nullable | Default | Mutability | FK / reference |
|---|---|---|---|---|---|
| id | uuid | NO | server UUID v4 | I | — |
| principal_id | uuid | NO | verified actor | I | principals.id |
| operation_id | uuid | NO | — | I | operation_contracts.id |
| command_kind | text | NO | registered phase/action | I | operation-contract code allowlist; not arbitrary handler |
| idempotency_key | text | NO | — | I | — |
| canonical_payload_hash | bytea | NO | — | I | — |
| canonicalization_version | integer | NO | 1 | I | — |
| expected_target_version | bigint | YES | NULL | I | — |
| request_id | uuid | YES | NULL | I | approval_requests.id |
| expected_request_version | bigint | YES | NULL | I | — |
| state | text | NO | — | I | — |
| result_kind | text | YES | NULL | I | — |
| result_ref | uuid | YES | NULL | I | typed descriptor; extension required |
| result_summary | jsonb | YES | NULL | I | — |
| error_code | text | YES | NULL | I | — |
| completed_at | timestamptz | NO | server completion time | I | — |
| created_at | timestamptz | NO | server transaction time | I | — |
| created_by | uuid | NO | verified actor | I | principals.id |

- **UNIQUE:** principal_id,operation_id,idempotency_key; id,operation_id; id,operation_id,request_id
- **CHECK:** idempotency_key length 1..200; hash exactly 32 bytes; positive canonicalization_version and optional expected versions; state SUCCEEDED/REJECTED; completed_at >= created_at; SUCCEEDED implies result_kind present and error_code absent; REJECTED implies error_code present and result_ref absent; result_summary object if present; command_kind is a nonblank registered code of at most 64 ASCII characters.
- **Additional indexes / purpose:** request_id — request command/retry history; operation_id — registry dependency/operation receipt history
- **Protected validation, history and audit:** Terminal-only V1: no ACCEPTED row/state. After the school authorization lock, acquire a transaction advisory lock for principal+operation-version+key; look up existing receipt, compare server-canonicalized SHA-256 intent and replay only under current read authorization. A hash mismatch conflicts without changing the existing receipt. Execute within the same transaction; insert SUCCEEDED or deterministic REJECTED receipt before dependent evidence rows, then commit all effects/evidence together. Transient infrastructure errors roll back without a receipt. Same rejected attempt/key replays rejection; a new deliberate attempt uses a new key. Canonicalization v1 and lock/failure contract are review R06; terminal fields immutable, permanent key/hash/result evidence retained. Composite FK (request_id,operation_id) -> approval_requests(id,operation_id); optional request allowed only by registered non-request command. Typed results remain domain-owned, not generic JSON patches. No exactly-once external delivery. command_kind distinguishes submit/review/apply and other registered phases of a versioned operation; it is included in canonical intent. The key namespace remains principal+operation_id+idempotency_key, so changing phase with the same key conflicts. Successful approval application requires command_kind=request.apply and SUCCEEDED; a review receipt cannot be borrowed as an application receipt.
- **Archive/delete:** Immutable terminal evidence; no normal hard deletion. Preserve referenced identity/history; controlled lifecycle or retained terminal rows as applicable. Global RESTRICT/retention rules apply; no cascade.
- **RLS / exposure:** SERVER ONLY; command actor reads redacted own receipt via checked endpoint; purpose-bound command worker. No direct client table access; checked projection/command where authorized. See per-table matrix.
- **Offline:** Essential offline replay contract; no local authoritative receipt.

### audit_events — F19

**Proposed name:** app_private.audit_events. **Status:** REVIEWED FOR SQL DRAFT; implementation pending.
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
- **Protected validation, history and audit:** Composite FK (actor_id,actor_kind) -> principals(id,kind). actor_id is initiator; created_by is verified executor (including SYSTEM). authority_evidence holds allowlisted grant/policy/version snapshots, never secrets or an authorization source. Allowlisted redacted details, not unrestricted before/after secrets. target_ref is non-authoritative historical search descriptor; access requires event classification/scope and field filtering, never trusting a supplied target string. Protected writes append only; retention/legal hold T10; no routine DELETE, even super-admin. Platform admins still bypass application controls, so no tamper-proof claim. Review R09 selects minimized evidence <= 8 KiB per JSON field and no legal TTL. Evidence snapshots retain code/version context; they are not reusable authority. Normal audit updates, soft delete, hard delete and TRUNCATE are forbidden.
- **Archive/delete:** Append-only; retain evidence and references. No normal deletion or rewrite. Global RESTRICT/retention rules apply; no cascade.
- **RLS / exposure:** SERVER ONLY; audit.view / audit.export restricted projection, explicit event scope; own actor is not automatic read right. No direct client table access; checked projection/command where authorized. See per-table matrix.
- **Offline:** No general offline audit cache.

### outbox_events — F20

**Proposed name:** app_private.outbox_events. **Status:** REVIEWED FOR SQL DRAFT; implementation pending.
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

**Proposed name:** app_private.event_consumer_deliveries. **Status:** REVIEWED FOR SQL DRAFT; implementation pending.
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
- **Protected validation, history and audit:** Consumer code allowlist; fenced lease token and row_version compare-and-swap; stale worker cannot acknowledge a newer lease. Consumers dedupe effects by event+consumer. External side effect before crash may repeat. Audit manual replay/dead-letter intervention, operational attempts stay here; cleanup T08/T10. V1 worker contract: 60-second fenced lease, maximum 10 attempts, retry delays min(30*2^(attempt-1),3600) seconds; DEAD thereafter. Replay requires authorized audited command; no automatic TTL. These are technical initial defaults, configurable only through reviewed deployment changes.
- **Archive/delete:** No normal hard deletion. Preserve referenced identity/history; controlled lifecycle or retained terminal rows as applicable. Global RESTRICT/retention rules apply; no cascade.
- **RLS / exposure:** SERVER ONLY; purpose-bound event worker; no generic service-wide read mandate. No direct client table access; checked projection/command where authorized. See per-table matrix.
- **Offline:** No client offline copy.

### notifications — F22

**Proposed name:** app.notifications. **Status:** REVIEWED FOR SQL DRAFT; implementation pending.
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

**Proposed name:** app.notification_preferences. **Status:** REVIEWED FOR SQL DRAFT; implementation pending.
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
- **CHECK:** nonblank category_code; channel_code IN_APP (initial Foundation); quiet_hours object if present; row_version > 0; quiet_hours is NULL in initial Foundation.
- **Additional indexes / purpose:** None beyond PK/UNIQUE; no speculative secondary index.
- **Protected validation, history and audit:** Only IN_APP category preferences in first Foundation; EMAIL/PUSH and quiet-hours interpretation remain deferred with F28. quiet_hours must be NULL initially. Seed no guessed mandatory category. Deployment registry classifies categories and safe payloads; no registered category means deny creation. Own preference changes audited/versioned; SYSTEM preferences prohibited.
- **Archive/delete:** No normal hard deletion. Preserve referenced identity/history; controlled lifecycle or retained terminal rows as applicable. Global RESTRICT/retention rules apply; no cascade.
- **RLS / exposure:** notification.preference.own; exact principal; preference command only. Allowlisted authenticated row-filtered reads only. See per-table matrix.
- **Offline:** Own preference snapshot; updates require version/reauthorization.

### notification_channel_deliveries — F28

**Proposed name:** app_private.notification_channel_deliveries. **Status:** DEFERRED SAFELY; excluded from first Foundation SQL draft.
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
- **Protected validation, history and audit:** DEFER TO LATER: do not create this table, its indexes/FKs/policies or any dispatcher in the first Foundation SQL draft. Retain this candidate description only as F28 design history. Later provider-neutral verified endpoint ownership and recipient binding must be designed together before inclusion. No endpoint_ref without real referential integrity is accepted for production.
- **Archive/delete:** No normal hard deletion. Preserve referenced identity/history; controlled lifecycle or retained terminal rows as applicable. Global RESTRICT/retention rules apply; no cascade.
- **RLS / exposure:** DEFERRED; no initial SQL table or policy. Historical proposal: SERVER ONLY; purpose-bound notification worker; owner-safe delivery status through inbox projection. No direct client table access; checked projection/command where authorized. See per-table matrix.
- **Offline:** No endpoint/token/provider state in offline client.

### file_objects — F23

**Proposed name:** app_private.file_objects. **Status:** REVIEWED FOR SQL DRAFT; implementation pending.
**Purpose:** Provider-neutral uploaded-file metadata, private by default; bytes are externally managed through a server adapter. **Authority:** Authoritative. **PK:** id.

| Column | PostgreSQL type | Nullable | Default | Mutability | FK / reference |
|---|---|---|---|---|---|
| id | uuid | NO | server UUID v4 | I | — |
| owner_principal_id | uuid | NO | — | I | principals.id |
| campus_id | uuid | YES | NULL | I | campuses.id |
| storage_location_key | text | NO | — | I | — |
| purpose_code | text | NO | No default | I | deployment-owned registry; no FK |
| object_key | text | NO | — | I | — |
| content_type | text | NO | — | I | — |
| byte_size | bigint | NO | — | I | — |
| content_hash | bytea | NO | — | I | — |
| classification | text | NO | PRIVATE | I | No FK |
| state | text | NO | PENDING | C | — |
| validated_at | timestamptz | YES | NULL | E | — |
| replaces_file_id | uuid | YES | NULL | I | file_objects.id |
| created_at | timestamptz | NO | server transaction time | I | — |
| created_by | uuid | NO | verified actor | I | principals.id |
| row_version | bigint | NO | 1 | V | — |
| updated_at | timestamptz | NO | server transaction time | C | — |

- **UNIQUE:** storage_location_key,object_key
- **CHECK:** byte_size between 1 and 1048576 inclusive; hash exactly 32 bytes; nonblank storage_location_key/object_key/content_type/classification; purpose_code matches ^[A-Z][A-Z0-9_]{0,63}$; state PENDING/VALIDATED/AVAILABLE/QUARANTINED/ARCHIVED/PURGED; AVAILABLE implies validated_at present; replaces_file_id differs from id; row_version > 0.
- **Additional indexes / purpose:** owner_principal_id,state — own upload reconciliation; campus_id,state — scoped document administration; replaces_file_id — version lineage lookup
- **Protected validation, history and audit:** [ADR-003](../decisions/ADR-003-provider-neutral-object-storage.md) selects deployment-allowlisted immutable storage_location_key and object_key; UNIQUE is per logical location in this school. No provider table, provider fields, URL/token or secret columns. Location mapping is outside business data; unknown/client-substituted locations deny. Classification defaults PRIVATE; explicit authorized public branding must use a compatible publication path, never a private evidence URL.
- **Upload lifecycle:** Server allocates file UUID/key/location and purpose-bound upload intent before upload; no row claims measured metadata yet. After inspecting actual sealed bytes, insert PENDING with measured content_type, byte_size and SHA-256; retain NOT NULL and immutable measured fields. Remaining validation sets validated_at and advances VALIDATED then AVAILABLE. Failed or missing objects stay unavailable; pre-row failures reconcile through the server intent/provider process. Replay and overwrite after verification must be prevented by staging/finalization or equivalent adapter guarantees before activation.
- **Integrity/history:** Enforce 1..1,048,576 measured bytes inclusive; a client digest or compression is not verification. No global hash deduplication. Validate content, typed domain authorization, retention and replacement ancestry. V1 relocation creates a verified new row/location with replaces_file_id; preserve old mappings/evidence, never silently retarget references. Audit upload/quarantine/download/purge using IDs/outcomes, not signed URLs. Metadata survives authorized physical purge; PDFs normally remain on demand.
- **Storage boundary:** Provider IAM supplements protected file-service checks; metadata visibility or object existence does not authorize download. AVAILABLE plus current actor/permission/scope/domain/classification checks precedes bounded temporary access. Logical location codes use the existing 64-character ASCII code bound; keys retain the 512-character bound. No provider credential in PostgreSQL settings or Flutter.
- **Archive/delete:** No normal hard deletion. Preserve referenced identity/history; controlled lifecycle or retained terminal rows as applicable. Global RESTRICT/retention rules apply; no cascade.
- **RLS / exposure:** file.view / file.upload / file.manage; owner is insufficient without live context and typed domain authorization; return safe metadata projection. No direct client table access; checked projection/command where authorized. See per-table matrix.
- **Offline:** Sensitive content only if T09/T11 permits encrypted cache.

### setting_revisions — F24

**Proposed name:** app_private.setting_revisions. **Status:** REVIEWED FOR SQL DRAFT; implementation pending.
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

auth.users is managed by Supabase; this package neither defines it nor assumes its other internal columns. The live UUID binds one non-system principal and is globally unique within this school project. A NULL live binding or inactive principal denies authentication-to-application resolution. Deleting Auth nulls the live UUID only; all business/audit created_by, reviewer, requester and actor references remain attached to the durable principal. The binding slot and immutable binding events survive. Controlled unbind/relink deactivates old authority before external Auth work; a SET NULL caused by external deletion cannot be falsely described as already atomically audited. Execution security specifies the unbind trigger, version/cutoff updates, evidence and managed-service retry boundary. [Supabase's managed user-data boundary](https://supabase.com/docs/guides/auth/managing-user-data).

The review accepts one non-retired individual principal per Person, permanent ASCII aliases and flattening ACCOUNT+account_type into INDIVIDUAL/FAMILY (T01/T03). FAMILY has its own Auth UUID, assignments, inbox, endpoints and caches. An individual Teacher+Parent principal keeps both roles; linked people/contact details do not transfer either role to a shared account. No UI switch or step-up can turn FAMILY into INDIVIDUAL.

Future approval target attachments are domain-owned, typed child relations with a unique request FK, a real FK to that domain target, and an operation discriminator checked against the request. A protected submission command and deferred consistency trigger must require exactly one correct typed target attachment for targetful operations; parent FKs alone cannot prove a child exists. The same pattern applies to typed result/evidence links and file ownership. Domain introduction adds constraints, handler validation and tests together before enabling that operation. target_ref, result_ref, endpoint_ref and event/audit descriptors are explicitly not universal referential integrity. No arbitrary target table name or JSON patch is executable.

No school_operational tenant_id or organization_id is needed. school_id appears only where it expresses a real singleton parent relationship. Schema deployment versions remain in deployment-controlled migration history plus checked source version/checksum; this proposal does not invent an application-editable schema-version table.

## 5. Next review

Next task, not started: **FOUNDATION SQL MIGRATION DRAFT — FILES ONLY, NO SUPABASE EXECUTION.** The review selects the 33-table subset; implementation/activation checks remain. No SQL is created here.

## F23 entitlement amendment - ADR-004

[ADR-004](../decisions/ADR-004-storage-plan-entitlements.md) adds immutable purpose_code TEXT NOT NULL, no default, lexical CHECK and deployment-owned semantic registry validation. It identifies purpose independently of plan. No plan_id, purpose/provider/entitlement table or extra index. Existing FKs/indexes remain.

Upload/finalization requires a current trusted server entitlement snapshot, enabled module and normal domain/permission checks. These mutations are private file-worker entry points behind the server gate, not direct authenticated bypass RPCs. Trusted snapshot/intent evidence supplies origin and audit revision, never client commercial claims. Unknown/unimplemented purposes deny. Existing reads survive downgrade under domain authorization; replacement uploads need current capability. See [taxonomy and snapshot contract](../architecture/05_storage_entitlements_and_document_purposes.md).
