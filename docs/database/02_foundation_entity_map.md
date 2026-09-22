# 02 - Foundation Entity Map

**Status:** PROPOSED conceptual entities, 2026-09-22. No physical tables or SQL are defined.
**Sources:** [AGENTS.md](../../AGENTS.md), [master specification](../requirements/School_OS_SaaS_Master_Specification_v0.2.md) sections 3-17, 49-58 and 64-78, [conventions](01_database_conventions.md), [identity](../security/01_identity_auth_model.md), [RBAC](../security/02_rbac_permission_scope_model.md).

## 1. Reading this map

The underlying product requirements are CONFIRMED. Every entity below, its attributes, lifecycle and constraints are **PROPOSED**; physical decomposition, types/nullability and enforcement mechanisms remain **TBD** until the next design task. F01-F28 are stable design references, not migration names. Some concepts may become multiple related records, but no generic table is assumed to replace typed domain relationships.

All entities belong to one school's project; there is no school-operational tenant discriminator. Every independently referenced record has a UUID primary identifier unless noted. Apply server timestamps/actors and versions from the conventions to mutable records; immutable records retain creation/effective/event information rather than fictitious updates.

“Foundation now” means define the contract now and consider it for a later foundation migration, not create it today. Active business-domain handlers and policy resolvers remain disabled until their domains exist.

## 2. Identity and effective access relationships

~~~mermaid
flowchart LR
  Person["Person F05"] -. "administrative association; not a permission grant" .-> Principal["Principal/account profile F06"]
  Auth["Supabase Auth account"] -->|"unique live binding"| Principal
  Principal --> Assignment["Role assignment F12 with verified context"]
  Assignment --> Role["Role F09"]
  Role --> Grant["Role-permission grant F11"]
  Grant --> Permission["Permission F10"]
  Assignment --> Scope["Assignment-permission scope binding F13"]
  Grant --> Scope
  Scope --> Campus["Campus F02 when applicable"]
  Scope -. "later typed resolvers" .-> Domain["Academic / teaching / family relationships"]
~~~

A person may have many roles through account/context assignments; Person itself never authorizes a request. The managed Auth account supplies authentication, F06 supplies a stable accountable actor, F12/F11 supply a candidate permission, and F13 supplies scope for that same permission and assignment. Context, domain assignment and workflow state further restrict access. No binding means no permission, not school-wide permission.

**Shared family boundary:** F06 distinguishes individual ACCOUNT principals from separate shared-family ACCOUNT principals. Each account has a distinct live Auth binding. F12 records the allowed context and must reject staff/admin role assignment to a shared-family principal. Ahmed's individual principal may have Teacher and Parent roles; a separate family principal gives his wife/guardian only Parent/Guardian access to approved linked children. A Person association, shared contact detail or account switch cannot transfer grants between them. Exact authentication UX and recovery remain T01; family-child relationships are designed later without requiring separate father/mother accounts.

Scope definitions are application-owned supported kinds and resolvers, not free-form school data: F10 specifies allowed kinds for each permission, and F13 binds a kind/typed target to the precise F12/F11 pair. The later catalog may use checked codes or a lookup representation (T02); no extra generic scope registry is assumed. Delegated administration is a separately permissioned command with a grant ceiling, not an implicit consequence of possessing the permission being granted.

## 3. School and academic anchors

### F01 - School profile

- **Purpose / identity / attributes:** one school's business identity; UUID, name/code, contact/branding references, locale, currency/timezone, state, version. The default-year reference is added after F04; logo metadata after F23.
- **Relationships / scope:** singleton inside this school project; F02/F04/F24 may reference it. No control-plane FK or tenant filtering.
- **Lifecycle / history / archive:** setup -> active -> inactive; mutable profile with meaningful audited changes and versioned settings. Never soft-delete the singleton to erase school history.
- **Security / constraints / indexes:** configuration administration writes; filtered branding reads. Enforce one school profile per project, recognized timezone/currency, unique local school code. PK/singleton lookup; no broad contact-data export.
- **Placement / status:** Foundation now, PROPOSED representation of CONFIRMED school configuration.

### F02 - Campus

- **Purpose / identity / attributes:** operational location/scope; UUID, school reference, stable code, label/address, state, row version.
- **Relationships / scope:** FK to F01; rooms and later academic/operational records refer to it. Campus is not a tenant.
- **Lifecycle / history / archive:** planned -> active -> archived. Retain referenced campuses; preserve meaningful changes. Moving a room/record between campuses requires a reviewed domain operation, not casual reparenting.
- **Security / constraints / indexes:** scoped campus reads, authorized administration writes; code unique within school, nonempty label. Index school/status and code; retired codes retained by default.
- **Placement / status:** Foundation now, PROPOSED.

### F03 - Room

- **Purpose / identity / attributes:** physical room anchor; UUID, campus, code/name, room kind, capacity and state. No timetable, bed or seat allocation yet.
- **Relationships / scope:** FK F02; later academic/scheduling records consume it. Campus derives from the parent.
- **Lifecycle / history / archive:** active -> unavailable/archived; mutable capacity/labels with audit. Retain former assignments in their owning domains; archive instead of deleting referenced rooms.
- **Security / constraints / indexes:** campus-scoped access; unique campus/code, positive capacity when specified, controlled room kinds. Index campus/state; no globally unique room name.
- **Placement / status:** Foundation anchor now, PROPOSED. Building/floor/bed hierarchies postponed.

### F04 - Academic year

- **Purpose / identity / attributes:** historical academic period; UUID, school, configured label, start/end dates, lifecycle/version.
- **Relationships / scope:** FK F01; school's optional default-year pointer refers here. PROPOSED school-wide year identity; campus-specific calendars remain T05.
- **Lifecycle / history / archive:** planned -> open -> closed; closed years remain readable. Date corrections require reason/history once referenced. Changing the default year does not rewrite previous records.
- **Security / constraints / indexes:** academic administration writes, scoped historical reads; start <= end, unique school/year label as proposal. Index school/start date/state. Do not forbid all overlapping dates without deciding campus/calendar rules.
- **Placement / status:** Foundation now, PROPOSED; levels/classes/sections/subjects postponed.

## 4. People, accounts and permission foundations

### F05 - Person

- **Purpose / identity / attributes:** minimal human anchor; independent UUID, preferred/legal name as justified, state/version. Detailed student, employee, medical and family fields remain outside this foundation.
- **Relationships / scope:** optional association from F06; later student/employee/guardian roles reference Person. Not campus-owned: campus eligibility comes from authorized relationships.
- **Lifecycle / history / archive:** active -> archived; meaningful corrections audited. Duplicate/merge process TBD T03; no automatic merge by name/email. Never erase referenced business history.
- **Security / constraints / indexes:** least-privilege identity administration; owning person sees only permitted fields. No global person-directory access from a school role. Nonempty required name; names not unique; authorized search index strategy TBD.
- **Placement / status:** Foundation now, PROPOSED.

### F06 - Principal / account profile

- **Purpose / identity / attributes:** permanent actor UUID; ACCOUNT or SYSTEM kind, account_type INDIVIDUAL or SHARED_FAMILY for accounts, distinct live Auth user UUID, Person association for an individual, activation state, version, system-purpose code.
- **Relationships / scope:** live FK to auth.users primary key for ACCOUNT; optional F05 link; grants, requests and audit reference F06. Parent-child linkage arrives later. School-project authority only; no default campus.
- **Lifecycle / history / archive:** pending -> active -> suspended -> retired. Clear a removed live Auth reference without deleting the actor; log F07. Retired anchors remain for history; no normal hard delete.
- **Security / constraints / indexes:** server-controlled account type and binding; unique live Auth subject, unique system-purpose identity; SYSTEM has no interactive Auth binding. Shared-family accounts cannot bind staff grants or automatically convert into individual accounts. Family membership is not a proven actor Person. Index Auth subject/status, account type and individual Person association.
- **Placement / status:** Foundation now, PROPOSED; isolated account UX/recovery T01 and Auth lifecycle T03/T04 require resolution before activation.

### F07 - Principal binding history

- **Purpose / identity / attributes:** immutable UUID evidence of binding/unbinding, person association and account-mode changes; old/new minimal identifiers, effective/recorded times, reason, actor.
- **Relationships / scope:** FKs to affected F06 and acting F06; optional F05 references. Historic Auth subject is a snapshot, not a cascading dependency on a deleted credential.
- **Lifecycle / history / archive:** append-only; correction adds a successor event. No ordinary soft delete; controlled retention T10.
- **Security / constraints / indexes:** identity/security administrators only; unique principal/change sequence or idempotency key, valid change kind, reason for relink. Index principal/time and actor/time.
- **Placement / status:** Foundation now, PROPOSED. Separate history is preferred over silently replacing an Auth UUID.

### F08 - Login alias

- **Purpose / identity / attributes:** school-local username resolution; UUID, normalized alias, principal, state, validity and normalization version. Stores no passwords.
- **Relationships / scope:** FK F06; uniqueness is within this school project, not every school.
- **Lifecycle / history / archive:** reserve -> active -> retired; changes retain assignment history. Alias reuse and reservation policy TBD T03.
- **Security / constraints / indexes:** protected resolver/admin only; no public list or email-discovery API. Unique active normalized alias with explicit reuse semantics; alias lookup and principal indexes.
- **Placement / status:** Conditional Foundation, PROPOSED/TBD T03. Omit or redesign if the chosen username flow does not need this entity.

### F09 - Role

- **Purpose / identity / attributes:** configurable permission grouping; UUID, stable code, display name, administrative category, status/version.
- **Relationships / scope:** F11 maps permissions; F12 assigns to principals. Role definition is school-level, not itself ALL scope.
- **Lifecycle / history / archive:** draft -> active -> retired; changes versioned/audited, historical assignments preserved. Retirement prevents new grants.
- **Security / constraints / indexes:** delegated administration only; protected role category cannot elevate Teacher/Parent/Student into administrator. Unique role code; index code/state.
- **Placement / status:** Foundation now, PROPOSED; approved default role contents remain T12.

### F10 - Permission

- **Purpose / identity / attributes:** UUID with resource/action code, handler semantic version, allowed contexts/scope kinds, sensitivity and lifecycle.
- **Relationships / scope:** F11 and F15 reference it; application-owned semantics, school-local catalog deployment.
- **Lifecycle / history / archive:** introduced -> active -> deprecated; never repurpose a code to mean a different action. Preserve references; no ordinary delete.
- **Security / constraints / indexes:** controlled deployment writes, filtered administration reads. Unique resource/action code; supported action/context checks. Index code.
- **Placement / status:** Foundation now, PROPOSED. Domain actions listed as examples are not activated or seeded yet.

### F11 - Role-permission grant

- **Purpose / identity / attributes:** UUID, role, permission, validity, grant/revoke actor/reason and allowed ceiling.
- **Relationships / scope:** FKs F09/F10; F13 references this exact grant. No principal-global permission bag.
- **Lifecycle / history / archive:** active -> ended/revoked; substantive changes replace/version the grant. Retain ended records; no silent delete.
- **Security / constraints / indexes:** bounded role administration; unique active role/permission pairing, valid intervals. Index role/active and permission; old grants cannot become valid via a new assignment accidentally.
- **Placement / status:** Foundation now, PROPOSED.

### F12 - Principal role assignment

- **Purpose / identity / attributes:** UUID, principal, role, required access context, effective dates, assigning actor/reason, state.
- **Relationships / scope:** FKs F06/F09; F13 narrows each permission. Associated staff Person is verified through identity context, not inherited from family membership.
- **Lifecycle / history / archive:** scheduled -> active -> ended/revoked; immutable grant terms except recorded closure, with change audit. No ordinary delete.
- **Security / constraints / indexes:** delegated grant administration; duplicate overlapping principal/role/context assignment prevention as proposed. Reject staff roles on SHARED_FAMILY principals, including through later role-definition changes. Index principal/context/validity and role; no role-assignment-only authorization.
- **Placement / status:** Foundation now, PROPOSED.

### F13 - Assignment-permission scope binding

- **Purpose / identity / attributes:** UUID, role assignment, role-permission grant, scope kind, typed campus reference when applicable, validity and reason.
- **Relationships / scope:** FKs F12/F11 and optional F02; enforce F12.role = F11.role through consistent relational constraints. OWN/ASSIGNED use registered resolvers; later class/section/subject bindings use actual domain FKs.
- **Lifecycle / history / archive:** active -> ended/revoked; preserve prior bindings. Changes issue a new bounded grant; no ordinary deletion.
- **Security / constraints / indexes:** scopes cannot outlive their grants or exceed delegated authority. ALL has no campus target; CAMPUS requires one; unresolved resolver denies. Unique assignment/grant/scope/target/version with explicit null handling; index assignment/grant and campus.
- **Placement / status:** Foundation now for supported predicates; PROPOSED. Academic/family resolvers postponed. Avoid a generic unchecked scope_type/scope_id registry or cross-role scope mixing.

## 5. Approval and evidence foundations

### F14 - Approval definition version

- **Purpose / identity / attributes:** UUID per version, stable policy key, operation kind, schema version, effective interval, state and activating actor.
- **Relationships / scope:** school-wide or typed campus override (F02); F15 steps and F16 requests refer to the exact version. Registered operation validators remain code-owned.
- **Lifecycle / history / archive:** draft editable -> active immutable -> superseded/retired. Preserve versions used by requests; do not delete their history.
- **Security / constraints / indexes:** policy administration is privileged and audited; unique policy key/scope/version, deterministic active-version selection and nonoverlapping applicability. Index operation/scope/effective dates.
- **Placement / status:** Foundation core now, PROPOSED; exact chain rules T06.

### F15 - Approval step template

- **Purpose / identity / attributes:** UUID, definition version, level/order, required permission/context, reviewer selection rule and review mode.
- **Relationships / scope:** FKs F14/F10; typed role candidate reference F09 where used. Candidate eligibility is derived from the request's trusted scope.
- **Lifecycle / history / archive:** mutable only with draft policy; frozen with active definition. Retain with policy.
- **Security / constraints / indexes:** policy administration only; unique definition/order, positive order and supported resolver/mode. Index definition/order. No executable scripts or arbitrary SQL rules.
- **Placement / status:** Foundation sequential core now, PROPOSED; parallel/quorum variants deferred T06.

### F16 - Approval request

- **Purpose / identity / attributes:** UUID, requesting principal/context, operation kind/domain, typed target link when domain exists, old/proposed validated values, target version, reason, policy version, state/version, timestamps and optional expiry.
- **Relationships / scope:** FKs F06/F14 and optional trusted F02; evidence associates F23 using an explicit request-file relationship. Domain target FKs/extensions are added with the owning module; target descriptors alone never authorize execution.
- **Lifecycle / history / archive:** draft editable, submitted intent frozen; proposed states in the workflow document. F26 retains transitions. No normal deletion of submitted evidence; drafts have separate retention TBD T10.
- **Security / constraints / indexes:** requestor/eligible reviewer see only permitted fields; require reason, supported operation, valid policy and expected target version. Index requester/time, campus/state and typed target/state.
- **Placement / status:** Core now, PROPOSED; actual student/finance/attendance payload schemas postponed.

### F17 - Request step instance

- **Purpose / identity / attributes:** UUID, request, source step template, order, resolved eligibility snapshot, state/version and open/close timestamps.
- **Relationships / scope:** FKs F16/F15; reviewer candidates refer to F06 through controlled assignments, with resolved campus/context. Do not store authorization solely as an unvalidated JSON reviewer list.
- **Lifecycle / history / archive:** waiting -> pending -> decided/skipped-by-explicit-policy; retain reassignment history through F26. No ordinary deletion.
- **Security / constraints / indexes:** trusted workflow service writes; assigned currently eligible reviewers read. Unique request/order and one active decision state; index eligible reviewer/pending via the chosen normalized assignment representation.
- **Placement / status:** Foundation now, PROPOSED; reviewer resolution T06.

### F18 - Approval review

- **Purpose / identity / attributes:** immutable UUID, step, reviewer/context, decision, comment/reason, authority evidence/version, timestamp, idempotency reference.
- **Relationships / scope:** FKs F17/F06/F25; campus inherits the request.
- **Lifecycle / history / archive:** append-only recorded decision; invalidate via a new transition, never edit the original review. No normal soft delete.
- **Security / constraints / indexes:** reviewer can decide only a pending eligible step; forbid self-review under proposed policy. Unique effective decision per step/reviewer/review round; index step/time and reviewer/time.
- **Placement / status:** Foundation now, PROPOSED.

### F19 - Audit event

- **Purpose / identity / attributes:** UUID, actor/executor, proven person if any, Auth/context snapshot, action/outcome, target descriptor, minimized old/new, reason, occurred/recorded times, correlation, source and request/session/device metadata.
- **Relationships / scope:** stable F06 actors, optional F02; optional F16 reference is added after workflow exists. Historical target descriptors are evidence, not permission-bearing FKs to every future domain.
- **Lifecycle / history / archive:** append-only; no normal update/delete/soft delete. Controlled archival/legal retention remains T10; exported archives retain access controls.
- **Security / constraints / indexes:** restricted writer and audit-reader permissions; nonempty action/outcome, actor provenance, dedupe command/action/event sequence. Index target/time, actor/time, campus/time, approval/correlation.
- **Placement / status:** Foundation now, PROPOSED model for CONFIRMED privileged audit.

### F26 - Approval transition / application record

- **Purpose / identity / attributes:** immutable UUID, request sequence, from/to state, actor/reason, review/command references, execution outcome and domain-result reference.
- **Relationships / scope:** FKs F16/F06, optional F18/F25; inherits target scope. Typed result link arrives with its domain.
- **Lifecycle / history / archive:** append-only lifecycle evidence; no normal deletion. Successful execution is permanent; a later business reversal is a new request.
- **Security / constraints / indexes:** workflow/domain writers only; unique request/transition sequence and at most one successful application per request. Index request/sequence and command receipt.
- **Placement / status:** Foundation now, PROPOSED. This and F25 supply approval application idempotency; they are not the domain ledger.

## 6. Events, notifications, files and settings

### F20 - Domain event / transactional outbox envelope

- **Purpose / identity / attributes:** immutable event UUID, registered event type/schema version, aggregate descriptor/version, occurred/recorded times, minimized payload, correlation/causation and originating command.
- **Relationships / scope:** optional F06/F02/F25 references; event fact is committed with the domain transaction. F21 controls delivery; payload has no mutable delivery fields.
- **Lifecycle / history / archive:** committed immutable -> later controlled archival; not the audit log or permanent source of domain truth. Retention/replay window T08/T10.
- **Security / constraints / indexes:** producer/consumer services only; unique aggregate/version/event-type/ordinal where appropriate and command event identity; index aggregate/version, time and correlation.
- **Placement / status:** Foundation now, PROPOSED transactional outbox option. A separate event store is unnecessary for this baseline; event sourcing is not selected.

### F21 - Event consumer delivery

- **Purpose / identity / attributes:** UUID, event, consumer code/version, status, attempt count, lease/fencing token, next attempt, last sanitized error and acknowledgement time.
- **Relationships / scope:** FK F20; optional SYSTEM actor F06. Inherits event's classification/scope, not user-readable by default.
- **Lifecycle / history / archive:** pending -> leased -> delivered or retry/dead-letter; bounded mutable delivery state with operational attempt evidence. Archive after defined replay/dedupe window.
- **Security / constraints / indexes:** designated worker only; unique event/consumer, lease ownership and bounded attempts. Index pending/next-attempt and expired lease.
- **Placement / status:** Foundation now, PROPOSED; broker/worker mechanism T08.

### F22 - Notification

- **Purpose / identity / attributes:** UUID, recipient principal and required access context, event/category, minimal template parameters, safe target descriptor, created/read/dismissed times and lifecycle.
- **Relationships / scope:** FKs F06 recipient and optional F20/F02. Recheck target access separately; F28 holds external channel delivery.
- **Lifecycle / history / archive:** generated -> unread/read -> dismissed/archived. User may change own read/dismiss state, not author/recipient/content. Retention T10; dismissal is not audit deletion.
- **Security / constraints / indexes:** recipient-and-context visibility, controlled notifier writes; unique event/recipient/context/category for dedupe. Index recipient/context/read-state/time. No fee/health detail in generic push/email preview; staff notifications addressed to an individual principal are unavailable to a related shared-family principal.
- **Placement / status:** Foundation now, PROPOSED.

### F27 - Notification preference

- **Purpose / identity / attributes:** UUID, principal/context, supported category/channel, opt setting, quiet-time zone/schedule where later supported, version.
- **Relationships / scope:** FK F06; optional school policy in F24. Recipient preference is not a campus access grant.
- **Lifecycle / history / archive:** mutable with audit of material changes; disable on retirement, retain necessary history. No silent opt-out of a mandatory category.
- **Security / constraints / indexes:** self-managed allowed preferences plus scoped administrative policy; unique principal/context/category/channel and valid supported values. Index principal/category.
- **Placement / status:** Foundation concept now, PROPOSED. Mandatory categories, quiet hours and consent/channel rules TBD T08; do not invent them.

### F28 - Notification channel delivery

- **Purpose / identity / attributes:** UUID, notification, channel, verified context-bound endpoint reference, delivery key, state, attempts, next-attempt time, provider reference and sanitized outcome times.
- **Relationships / scope:** FK F22; verified recipient endpoint/profile source is TBD T08, never a freely supplied address. No credential or message-body duplication.
- **Lifecycle / history / archive:** queued -> sent/failed/retry/suppressed; delivery attempts recorded, state mutable. Controlled operational retention; historical inbox fact remains separate.
- **Security / constraints / indexes:** notifier only; unique notification/channel/delivery purpose, provider idempotency key where supported. Index pending/next-attempt and notification.
- **Placement / status:** Foundation contract now, PROPOSED; provider-specific endpoint/token registries postponed.

### F23 - Private file metadata

- **Purpose / identity / attributes:** UUID, bucket/object key, uploader, purpose/classification, validated type/bytes/hash, lifecycle/version and created time.
- **Relationships / scope:** FK F06 and optional F02; owning-domain typed links and F16 evidence links govern access. A null campus means scope must be resolved, not public access.
- **Lifecycle / history / archive:** pending upload -> validated/available -> quarantined/archived -> controlled purge if permitted. Replace immutable content with a new version/key; preserve evidence references. Storage cleanup is a reconciled operation.
- **Security / constraints / indexes:** private policies follow owning record; unique bucket/object key, positive bytes and current <=1 MB target after validation, allowlisted type. Index owning link, uploader/state, pending age.
- **Placement / status:** Foundation metadata now, PROPOSED; generated PDF persistence and domain document schemas postponed.

### F24 - Application setting revision

- **Purpose / identity / attributes:** UUID per immutable effective revision; stable setting key, scope, schema version, validated value, effective dates, changed-by/reason.
- **Relationships / scope:** F01 school, optional F02 campus, F06 actor. Application-owned key registry defines permitted types and override behavior.
- **Lifecycle / history / archive:** editable draft -> active immutable -> superseded/retired; preserve settings used in historical decisions. Retire keys without erasing old revisions.
- **Security / constraints / indexes:** per-key administration, filtered reads; no secrets. Unique key/scope/version, nonoverlapping active validity and explicit school-null uniqueness. Index key/scope/effective dates.
- **Placement / status:** Foundation now, PROPOSED. Prefer typed columns for stable core settings; bounded validated JSON only for variable configuration.

### F25 - Command receipt / idempotency record

- **Purpose / identity / attributes:** UUID, initiating principal, command kind, operation key, canonical payload hash, request/target version, state and protected result reference.
- **Relationships / scope:** FK F06; optional F16 link added after requests exist. Scope is the authorized command's scope, not an independent permission.
- **Lifecycle / history / archive:** executing -> committed or recorded failure; durable result identity for irreversible operations. Transient retry records may expire only after T08/T09 retention analysis; permanent uniqueness survives.
- **Security / constraints / indexes:** trusted command service; authorized replay only. Unique principal/command/key within the school project; same key with different input conflicts. Index key and unresolved state.
- **Placement / status:** Foundation now, PROPOSED; coordinates F26 and domain effects without claiming exactly-once external delivery.

## 7. Authority, audit and offline implications for every entity

This matrix completes each F01-F28 profile above; it is part of the same PROPOSED entity definition. "Authoritative" describes the fact this entity owns, not authority to bypass permissions. Online-only writes are the proposed Foundation default. Any later offline draft/replay must still pass current server authorization, version and domain checks; cached grants never authorize a server command.

| Entity | Authoritative or derived | Audit implications | Offline implications |
|---|---|---|---|
| F01 School profile | Authoritative school identity/configuration | Audit meaningful identity/branding/configuration changes | Cache only permitted display/settings fields; no offline administration |
| F02 Campus | Authoritative campus identity/lifecycle | Audit creation, changes and retirement | Scoped reference cache; revoked/retired campus cannot authorize replay |
| F03 Room | Authoritative physical-room anchor | Audit capacity/status/campus changes | Scoped reference reads; offline scheduling is outside Foundation |
| F04 Academic year | Authoritative period identity/dates/state | Audit closure/date/default-context changes without replacing old history | Authorized historical reference cache; year switching does not rewrite prior facts |
| F05 Person | Authoritative minimal identity anchor | Audit meaningful corrections and controlled merges with minimized differences | Only explicitly permitted identity fields in encrypted cache; no offline merge/relink |
| F06 Principal/account profile | Authoritative application actor/type/state; Auth owns credentials | Audit binding, activation, suspension and account-type attempts | No offline account switching/elevation; purge/separate caches by principal and school |
| F07 Binding history | Authoritative account-binding change evidence | Protected append path and audit correlation; no recursive audit of each append | Never client-written or a cached credential authority |
| F08 Login alias | Authoritative accepted alias mapping if selected | Audit issue/rename/retirement; never record credentials | Online protected resolution only; no alias directory downloaded |
| F09 Role | Authoritative role grouping/configuration | Audit edits and retirement; verify affected family-principal grants cannot become staff grants | Optional display labels only; no offline role administration |
| F10 Permission | Authoritative deployed action registry; code owns semantics | Audit catalog/version deployment | Cached descriptions are informational, not authorization |
| F11 Role-permission grant | Authoritative grant validity/history | Audit issuance, ceiling change and revocation | Recheck current state on every replay; never edit offline |
| F12 Principal role assignment | Authoritative principal/context assignment history | Audit grant/revoke/delegation; reject shared-family staff assignment | Cached role selection cannot reestablish expired/revoked authority |
| F13 Assignment-permission scope | Authoritative bounded scope grant | Audit target/validity/ceiling changes | Server resolves current typed scope; unknown or stale scope denies |
| F14 Approval definition version | Authoritative published policy version | Audit publication/supersession and its review | Offline drafts may cite a version but submission validates current applicability |
| F15 Step template | Authoritative steps within a policy version | Audit through the versioned policy change | Read-only context if needed; no offline policy editing |
| F16 Approval request | Authoritative frozen intent; current state supported by F26 history | Audit submission, withdrawal, conflict and execution | Local drafts possible later; never offline approval/execution |
| F17 Request step | Materialized reviewer routing/state; authoritative assignment evidence retained with transitions | Audit reassignment, skipped/closed step and eligibility changes | Review requires current server eligibility, not cached reviewer list |
| F18 Approval review | Authoritative immutable decision evidence | Record reviewer/authority and sanitized reason; no mutable decision overwrite | Online only; queued UI intent has no approval authority |
| F19 Audit event | Authoritative evidence of the recorded outcome, not the domain ledger | Restricted append/read, controlled archive and nonrecursive failure logging | Server writes; offline client events are untrusted claims until validated |
| F20 Domain event/outbox | Derived committed business fact envelope; durable publication evidence | Link command/audit/causation; audit privileged replay | Server-generated only; raw device/offline capture is not this committed fact |
| F21 Event delivery | Derived operational delivery progress | Sanitized retry diagnostics and authorized replay evidence | Server worker only; no client synchronization |
| F22 Notification/inbox | Derived recipient content; authoritative recipient read/dismiss state | Audit sensitive creation/admin access where policy requires; avoid logging whole messages | Minimal permitted inbox cache; idempotent read-state sync may be considered later |
| F23 Private file metadata | Authoritative ownership/purpose/validation metadata; bytes live in Storage | Audit sensitive upload/access/replace/purge and reference changes | Encrypted authorized downloads only; pending local upload is not available evidence |
| F24 Setting revision | Authoritative versioned configuration | Audit activation/effective change and actor/reason | Allowlisted nonsecret cached settings are versioned; no offline policy change |
| F25 Command receipt | Authoritative dedupe/result identity; domain owns business outcome | Correlate committed/failed command evidence; restrict replay-result reads | Stable operation ID + payload hash for later replay; never trusts client result |
| F26 Approval transition/application | Authoritative lifecycle/application evidence | Preserve state/review/result provenance; no recursive audit loop | Server-only execution history; replay returns authorized existing result |
| F27 Notification preference | Authoritative allowed recipient preference | Audit policy overrides and material preference changes | Later version-checked preference intent only; cannot grant access or bypass required notice |
| F28 Channel delivery | Derived operational delivery status | Record sanitized provider outcome and controlled retry | Server-only; delivery failure cannot undo business truth |

## 8. Schema/version metadata and representation choices

CONFIRMED: each deployed school needs schema/migration version tracking. PROPOSED: use the selected migration tool's deployment-controlled applied-history evidence as the local source for applied versions, reconciled with source-controlled migration identities/checksums and deployment records. Exact ledger/access mechanism is T02/T12; do not invent a second application-writable schema-version table in Foundation.

A compatibility/status view, if later needed, is derived from verified deployment evidence. Its identity is the school project plus migration/release identifier, not an operational tenant_id. Candidate attributes are applied version, release, checksum, application time and deployment outcome; no cross-school FK or student data belongs in it. Only deployment tooling updates authoritative evidence; school clients receive at most a safe read-only compatibility result. Keep upgrade history, audit operator changes, index version/time only if the selected representation requires it, and do not accept offline edits or client-reported migration success. Retention/rebuild policy is T12/T15.

No new entity is committed for this managed metadata. F22 already represents a per-recipient inbox; a separate reusable message/template entity is unnecessary until a concrete sharing need is designed. F23 purpose/type is an application-owned vocabulary with per-purpose validation, not a new generic document table. Auth live binding is part of F06 with F07 history; a separate binding relation can be evaluated in the physical catalog if cardinality justifies it.

## 9. Alternatives and explicit postponements

| Area | Preferred proposal | Alternative / reason not selected now |
|---|---|---|
| Person/account | Independent stable person and principal with live managed Auth binding | Auth UUID as all business identity would couple credential deletion to history and shared-family attribution |
| Scope | Per-assignment/per-permission typed binding | Global account scope bag permits privilege mixing; generic type/UUID targets lack integrity |
| Workflow | Versioned common core plus domain-owned payload/target validators | Universal JSON patch runner cannot enforce balances, enrollment history or publication constraints |
| Configuration | Typed stable settings plus schema-validated revisions | Unlimited key/value store hides invariants and encourages secrets in data |
| Events | Immutable fact/outbox plus separate consumer delivery | Treating audit as a message queue couples retention, access and retries incorrectly |
| Notifications | Inbox, preferences and delivery have separate responsibilities | A single mutable event/notification row loses independent recipient states and audit evidence |

**Postpone:** classes/sections/subjects and assignment schemas; student/family/enrollment/admission records; financial/payroll/marks/attendance schemas; domain payload/detail/link structures; full automation rules, delivery endpoint providers, AI conversation schema; sync/device inventory; integration/vendor registries; biometric templates, face images/embeddings, consent/media handling and device protocols.

A generic device registry has no required Foundation behavior today. Session ID, client operation ID, claimed device ID, source and verified provenance can be bounded audit/command attributes. They are not device authentication. Manual/QR and future adapters must enter the same canonical attendance domain after validation; an adapter event alone is not approved attendance.

[Dependency order](03_foundation_dependency_order.md) resolves forward references and activation gates. [ADR-001](../decisions/ADR-001-foundation-database-principles.md) registers every open decision; [test strategy](../testing/01_foundation_test_strategy.md) defines verification.
