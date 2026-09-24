# 03 - Foundation RLS Design Matrix

**Status: REVIEWED FOR SQL DRAFT, 2026-09-23. No policies or SQL created.**

[Execution security](04_foundation_execution_security.md) now defines exact owners, column grants, function classes, search_path, EXECUTE, FORCE RLS, worker identities and revocation locks. The [physical review](../decisions/FOUNDATION_PHYSICAL_DESIGN_REVIEW.md) retains 33 tables; F28 rows below are deferred history, not SQL policy targets.
Sources: [AGENTS.md](../../AGENTS.md), [security rules](SECURITY_WORKFLOW_AND_AUDIT.md), [identity](01_identity_auth_model.md), [RBAC](02_rbac_permission_scope_model.md), and [physical catalog](../database/05_foundation_physical_catalog.md).
Read the [constraint matrix](../database/06_foundation_constraint_matrix.md) and [TBD gate](../decisions/FOUNDATION_TBD_GATE.md) with this proposal.

## 1. Exposure and enforcement model

All 33 included application tables begin with RLS enabled and no allow policy, no client write grants, and no blanket schema grants. The proposed app schema allows explicit authenticated reads on campuses, rooms, academic_years, notifications and notification_preferences only. app_private is not API-exposed; its base tables deny all client SELECT/INSERT/UPDATE/DELETE. Authenticated users obtain authorized projections through narrow server interfaces where specified. A checked interface is not permission to expose the entire underlying table. Anonymous base-table access is denied everywhere; any future login/branding discovery returns an explicitly approved minimal projection, not a public school/principal directory.

Every normal authenticated direct INSERT, UPDATE and DELETE is **DENY**, including own inbox/preference updates. Client-facing commands may exist, but must derive the actor from a validated Auth session, enforce the complete grant/context/state rules and issue only the permitted mutation. Ownership alone is never permission to change protected fields. SYSTEM workers have explicit purpose, no shared client credential, and do not inherit arbitrary user authority.

RLS filters rows; column privileges and checked projections must separately prevent disclosure of contacts, snapshots, recovery identifiers, authorization evidence, object keys or sensitive request fields. Views must not accidentally bypass underlying policies; helper/function ownership, non-recursive evaluators, exact EXECUTE, safe search_path and verified context transport are selected in execution security. No owner-rights view is introduced. Do not use mutable user metadata, UI-selected principal IDs or stale JWT role arrays as authority. Live auth.uid()-to-binding-to-principal resolution, current grants and context must be checked.

PostgreSQL table owners and BYPASSRLS roles may bypass ordinary policies, and Supabase service credentials require special care. Worker safety therefore also depends on role/grant/function ownership, deployment controls and protected command validation; a matrix cell cannot turn a bypass role into a least-privilege role. Never place those credentials in Flutter. [Supabase RLS documentation](https://supabase.com/docs/guides/database/postgres/row-level-security). Exact database roles and FORCE RLS are selected in execution security; no service-role user proxy is permitted. These remain unimplemented protections.

Permission names below are proposed review vocabulary, not seeded codes or a final permission catalog. Self operations are explicitly permitted capabilities, not broad role-name privileges. For workers, deployment/system purpose substitutes for a human business action only within the command's allowlisted contract; initiating user authority is still checked where required.

## 2. Direct authenticated/anonymous table access

This matrix includes even unexposed tables so none has an implicit exemption. DENY means no normal client table privilege/policy. SELECT cells for app are candidate row-policy predicates and must also pass live principal/context checks.

| Table | API namespace | Anonymous (all) | Authenticated SELECT | INSERT | UPDATE | DELETE | Direct writes completely forbidden? |
|---|---|---|---|---|---|---|---|
| school_profiles | app_private | DENY | DENY; narrow checked interface only | DENY | DENY | DENY | YES |
| campuses | app | DENY | campus.view; allowed ALL/CAMPUS target | DENY | DENY | DENY | YES |
| rooms | app | DENY | room.view; stored parent campus matches allowed scope | DENY | DENY | DENY | YES |
| academic_years | app | DENY | academic_year.view; authorized school context, history included | DENY | DENY | DENY | YES |
| people | app_private | DENY | DENY; narrow checked interface only | DENY | DENY | DENY | YES |
| principals | app_private | DENY | DENY; narrow checked interface only | DENY | DENY | DENY | YES |
| principal_auth_bindings | app_private | DENY | DENY; narrow checked interface only | DENY | DENY | DENY | YES |
| principal_binding_events | app_private | DENY | DENY; narrow checked interface only | DENY | DENY | DENY | YES |
| login_aliases | app_private | DENY | DENY; narrow checked interface only | DENY | DENY | DENY | YES |
| roles | app_private | DENY | DENY; narrow checked interface only | DENY | DENY | DENY | YES |
| permissions | app_private | DENY | DENY; narrow checked interface only | DENY | DENY | DENY | YES |
| role_permission_grants | app_private | DENY | DENY; narrow checked interface only | DENY | DENY | DENY | YES |
| principal_role_assignments | app_private | DENY | DENY; narrow checked interface only | DENY | DENY | DENY | YES |
| permission_scope_contracts | app_private | DENY | DENY; narrow checked interface only | DENY | DENY | DENY | YES |
| assignment_permission_scopes | app_private | DENY | DENY; narrow checked interface only | DENY | DENY | DENY | YES |
| operation_contracts | app_private | DENY | DENY; narrow checked interface only | DENY | DENY | DENY | YES |
| approval_policy_versions | app_private | DENY | DENY; narrow checked interface only | DENY | DENY | DENY | YES |
| approval_step_templates | app_private | DENY | DENY; narrow checked interface only | DENY | DENY | DENY | YES |
| approval_requests | app_private | DENY | DENY; narrow checked interface only | DENY | DENY | DENY | YES |
| approval_request_files | app_private | DENY | DENY; narrow checked interface only | DENY | DENY | DENY | YES |
| approval_request_steps | app_private | DENY | DENY; narrow checked interface only | DENY | DENY | DENY | YES |
| approval_step_reviewers | app_private | DENY | DENY; narrow checked interface only | DENY | DENY | DENY | YES |
| approval_reviews | app_private | DENY | DENY; narrow checked interface only | DENY | DENY | DENY | YES |
| approval_transitions | app_private | DENY | DENY; narrow checked interface only | DENY | DENY | DENY | YES |
| approval_applications | app_private | DENY | DENY; narrow checked interface only | DENY | DENY | DENY | YES |
| command_receipts | app_private | DENY | DENY; narrow checked interface only | DENY | DENY | DENY | YES |
| audit_events | app_private | DENY | DENY; narrow checked interface only | DENY | DENY | DENY | YES |
| outbox_events | app_private | DENY | DENY; narrow checked interface only | DENY | DENY | DENY | YES |
| event_consumer_deliveries | app_private | DENY | DENY; narrow checked interface only | DENY | DENY | DENY | YES |
| notifications | app | DENY | Exact live recipient principal; safe summary, same account context | DENY | DENY | DENY | YES |
| notification_preferences | app | DENY | Exact live principal; own permitted preference | DENY | DENY | DENY | YES |
| notification_channel_deliveries | app_private | DENY | DENY; narrow checked interface only | DENY | DENY | DENY | YES |
| file_objects | app_private | DENY | DENY; narrow checked interface only | DENY | DENY | DENY | YES |
| setting_revisions | app_private | DENY | DENY; narrow checked interface only | DENY | DENY | DENY | YES |

## 3. Checked interfaces, permission/scope and worker access

A private table's interface may SELECT a bounded projection even though direct table SELECT above is denied. Server interfaces still enforce equivalent row restrictions. Table row access is never enough to authorize a domain change.

| Table | Required action / scope / context and read interface | Command-only writes | Service/system worker boundary |
|---|---|---|---|
| school_profiles | school.view / school.configure; ALL school scope | Owning protected command; exact field whitelist + expected row_version | Bootstrap/configuration command executor; scoped school administration. No blanket client-selected actor or unrestricted data proxy. |
| campuses | campus.view / campus.manage; ALL or matching CAMPUS | Owning protected command; exact field whitelist + expected row_version | Bootstrap/configuration command executor; scoped school administration. No blanket client-selected actor or unrestricted data proxy. |
| rooms | room.view / room.manage; parent CAMPUS or ALL | Owning protected command; exact field whitelist + expected row_version | Bootstrap/configuration command executor; scoped school administration. No blanket client-selected actor or unrestricted data proxy. |
| academic_years | academic_year.view / academic_year.manage; school ALL | Owning protected command; exact field whitelist + expected row_version | Bootstrap/configuration command executor; scoped school administration. No blanket client-selected actor or unrestricted data proxy. |
| people | person.view / person.manage; OWN or explicit authorized resolver; no guessed campus | Owning protected command; exact field whitelist + expected row_version | Identity provisioning/relink service; no generic profile proxy. No blanket client-selected actor or unrestricted data proxy. |
| principals | principal.self / identity.manage; self safe projection or authorized administration | Owning protected command; exact field whitelist + expected row_version | Identity provisioning/relink service; no generic profile proxy. No blanket client-selected actor or unrestricted data proxy. |
| principal_auth_bindings | SERVER ONLY; identity binding service; no client base SELECT | Owning protected command; exact field whitelist + expected row_version | Identity provisioning/relink service; no generic profile proxy. No blanket client-selected actor or unrestricted data proxy. |
| principal_binding_events | SERVER ONLY; identity audit projection with identity.audit permission | Append only through owning command; no normal update/delete | Identity provisioning/relink service; no generic profile proxy. No blanket client-selected actor or unrestricted data proxy. |
| login_aliases | SERVER ONLY; narrow rate-limited username resolver, no anonymous table query | KEEP; reviewed ASCII uniqueness, verified identity provisioner | Identity provisioning/relink service; no generic profile proxy. No blanket client-selected actor or unrestricted data proxy. |
| roles | SERVER ONLY; security.role.view / security.role.manage through restricted projection | Owning protected command; exact field whitelist + expected row_version | Deployment catalog owner and protected security-administration commands. No blanket client-selected actor or unrestricted data proxy. |
| permissions | SERVER ONLY; deployment owner; security.permission.view via safe projection | Reviewed deployment catalog changes/activation only | Deployment catalog owner and protected security-administration commands. No blanket client-selected actor or unrestricted data proxy. |
| role_permission_grants | SERVER ONLY; security.grant.manage; permitted delegation ceiling | Owning protected command; exact field whitelist + expected row_version | Deployment catalog owner and protected security-administration commands. No blanket client-selected actor or unrestricted data proxy. |
| principal_role_assignments | SERVER ONLY; security.assignment.manage; delegation ceiling and verified actor context | Owning protected command; exact field whitelist + expected row_version | Deployment catalog owner and protected security-administration commands. No blanket client-selected actor or unrestricted data proxy. |
| permission_scope_contracts | SERVER ONLY; deployment owner; security.scope.view safe projection | Reviewed deployment catalog changes/activation only | Deployment catalog owner and protected security-administration commands. No blanket client-selected actor or unrestricted data proxy. |
| assignment_permission_scopes | SERVER ONLY; security.scope.manage; exact permission/grant ceiling | Owning protected command; exact field whitelist + expected row_version | Deployment catalog owner and protected security-administration commands. No blanket client-selected actor or unrestricted data proxy. |
| operation_contracts | SERVER ONLY; deployment owner; no user-editable handler registry | Reviewed deployment catalog changes/activation only | Workflow/typed-command executor; no arbitrary target mutation. No blanket client-selected actor or unrestricted data proxy. |
| approval_policy_versions | approval.policy.view / approval.policy.manage; ALL or matching CAMPUS | Owning protected command; exact field whitelist + expected row_version | Workflow/typed-command executor; no arbitrary target mutation. No blanket client-selected actor or unrestricted data proxy. |
| approval_step_templates | approval.policy.view / approval.policy.manage; inherit policy scope | Owning protected command; exact field whitelist + expected row_version | Workflow/typed-command executor; no arbitrary target mutation. No blanket client-selected actor or unrestricted data proxy. |
| approval_requests | approval.request.view / operation request permission; requester, assigned reviewer or scoped administrator; domain field filtering | Owning protected command; exact field whitelist + expected row_version | Workflow/typed-command executor; no arbitrary target mutation. No blanket client-selected actor or unrestricted data proxy. |
| approval_request_files | approval.request.view / operation request permission; intersection of request and file visibility | Append only through owning command; no normal update/delete | Workflow/typed-command executor; no arbitrary target mutation. No blanket client-selected actor or unrestricted data proxy. |
| approval_request_steps | approval.request.view / operation review permission; authorized participant in request scope | Owning protected command; exact field whitelist + expected row_version | Workflow/typed-command executor; no arbitrary target mutation. No blanket client-selected actor or unrestricted data proxy. |
| approval_step_reviewers | approval.request.view / operation review permission; same principal reviewer or scoped workflow administrator | Owning protected command; exact field whitelist + expected row_version | Workflow/typed-command executor; no arbitrary target mutation. No blanket client-selected actor or unrestricted data proxy. |
| approval_reviews | approval.request.view / operation review permission; filtered request participants | Append only through owning command; no normal update/delete | Workflow/typed-command executor; no arbitrary target mutation. No blanket client-selected actor or unrestricted data proxy. |
| approval_transitions | approval.request.view; inherit request visibility; writes only workflow command | Append only through owning command; no normal update/delete | Workflow/typed-command executor; no arbitrary target mutation. No blanket client-selected actor or unrestricted data proxy. |
| approval_applications | approval.request.view; inherit request visibility; application handler only | Append only through owning command; no normal update/delete | Workflow/typed-command executor; no arbitrary target mutation. No blanket client-selected actor or unrestricted data proxy. |
| command_receipts | SERVER ONLY; command actor reads redacted own receipt via checked endpoint; purpose-bound command worker | Protected command serializes key then inserts terminal-only immutable receipt; no ACCEPTED or UPDATE | Typed command/audit writer or registered event worker, limited by table purpose. No blanket client-selected actor or unrestricted data proxy. |
| audit_events | SERVER ONLY; audit.view / audit.export restricted projection, explicit event scope; own actor is not automatic read right | Append only through owning command; no normal update/delete | Typed command/audit writer or registered event worker, limited by table purpose. Append writer separate from restricted evidence reader; no normal erase. |
| outbox_events | SERVER ONLY; registered event workers; no client stream of raw events | Append only through owning command; no normal update/delete | Typed command/audit writer or registered event worker, limited by table purpose. Read immutable minimal envelopes; only producer inserts. |
| event_consumer_deliveries | SERVER ONLY; purpose-bound event worker; no generic service-wide read mandate | Owning protected command; exact field whitelist + expected row_version | Typed command/audit writer or registered event worker, limited by table purpose. Claim/complete own registered consumer rows with fencing. |
| notifications | notification.own; exact authenticated principal, live binding, same account kind/context | Owning protected command; exact field whitelist + expected row_version | Inbox builder/notification dispatcher and owner-state commands. No blanket client-selected actor or unrestricted data proxy. |
| notification_preferences | notification.preference.own; exact principal; preference command only | Owning protected command; exact field whitelist + expected row_version | Inbox builder/notification dispatcher and owner-state commands. No blanket client-selected actor or unrestricted data proxy. |
| notification_channel_deliveries | SERVER ONLY; purpose-bound notification worker; owner-safe delivery status through inbox projection | DEFERRED from first SQL; later typed verified endpoint design required | Inbox builder/notification dispatcher and owner-state commands. Verified endpoint and recipient/context rechecked before each send. |
| file_objects | file.view / file.upload / file.manage; typed domain authorization; upload also needs school entitlement/module/purpose policy | Upload allocation/finalization/availability via private file-worker commands only; exact fields + expected row_version; no direct authenticated upload RPC | Validated file service or configuration-revision command. No blanket client-selected actor or unrestricted data proxy. |
| setting_revisions | setting.view / setting.manage; ALL or matching CAMPUS; safe key/field projection | Append only through owning command; no normal update/delete | Validated file service or configuration-revision command. No blanket client-selected actor or unrestricted data proxy. |

## 4. Sensitive paths

**Identity:** Principal self projection excludes live Auth IDs, aliases and binding history. Administrative identity reads require separate identity permissions and justified disclosure; being the named Person is not automatically a grant. Login alias resolution is server-only, enumeration-resistant and rate-limited, not anonymous SELECT. External Auth deletion/relink must leave historic actor FKs intact and immediately remove old application resolution. Managed auth.users policies are outside this application-table matrix; it is not an app-exposed table.

**Complete grants:** Policy helper must find one valid assignment + matching role/action grant + compatible permission scope binding. Do not independently collect all permitted actions and all available scopes and cross-join them. CAMPUS uses the target's stored campus, and OWN/ASSIGNED uses a known resolver; unresolved ancestry or unknown resolver denies. Shared FAMILY principal accepts only the constrained Parent/Guardian catalog and its own linked children. A related person's staff grants or account switch cannot change its kind.

**Approval visibility:** Requester, assigned reviewer and scoped workflow administrator may receive distinct purpose-limited projections. A role or candidate row alone is insufficient: require current request/review permission, complete scope, stage state and domain clearance. A reviewer does not gain unrestricted medical/fee/payroll file access. Reviews and applications recheck eligibility/versions/conflicts, rather than relying on SELECT permission or a prior approval decision. All future domain handlers remain disabled until typed target/result and disclosure contracts exist.

**History and audit:** History remains readable only under explicit current/historical policy; a current teacher assignment does not automatically authorize every historical student record. Audit queries require audit.view; export requires separate audit.export and filtered delivery. Being the actor does not imply entitlement to every audit detail. No ordinary principal, including Super Admin, has audit rewrite/delete permission.

**Inbox/preferences/channels:** Resolve exact principal identity. An INDIVIDUAL Teacher+Parent inbox and a separate FAMILY inbox never merge by email, Person or linked child. A recipient can mark read/archive through a checked owner command; cannot rewrite recipient, category or message. Preferences cannot authorize delivery or disable a mandatory notice unless policy permits. Endpoint_ref is not yet a safe generic owner relationship: external-channel work remains disabled pending T08. Minimal provider payload, reauthorization at dispatch, and deep-link authorization limit later disclosure; sent messages cannot be recalled.

**Files/settings:** Typed business/domain relationships determine document ownership and access context; uploaded_by_principal_id records provenance only, never an ownership or access shortcut. Evidence must satisfy request visibility and classified file access. Raw object paths, byte metadata and signing operations stay behind narrow interfaces. RLS on app metadata does not by itself enforce Storage object access: provider-neutral adapter access controls and protected file-service authorization require T11; safe metadata visibility is not permission to fetch raw bytes. Settings expose only approved safe keys and fields, never secrets.

**Workers and offline:** Worker APIs accept allowlisted operation/consumer purposes, not table names, user-selected database roles or arbitrary SQL. Event worker access is not audit export access. Queue claims/delivery updates use stored lease ownership. Offline replay rechecks current authority and versions; encrypted cached grants never authorize a server command. SQL tests must use realistic non-owner authenticated and worker contexts so bypass credentials cannot conceal missing policy checks.

## 5. Acceptance gate

Before SQL, T04 is selected by execution security: database roles, exposed-schema allowlist, helper ownership, exact execution grants, recursion-safe live-principal resolution, fresh-read shared/exclusive revocation ordering and field-safe projections. Each interface needs allow/deny tests including cross-school credentials, cross-campus target, wrong principal/family context, stale token/grant, unknown resolver, cross-role scope mixing, reviewer conflict, direct write attempts, raw private-table access and service-proxy abuse. The [test strategy](../testing/01_foundation_test_strategy.md) is the conceptual starting point; these backend tests are planned, not run.

Next task, not started: **FOUNDATION SQL MIGRATION DRAFT — FILES ONLY, NO SUPABASE EXECUTION.**

## Provider-neutral files and entitlement gate - ADR-003 / ADR-004

PostgreSQL RLS protects file metadata/business access; raw object access is separately enforced by the protected server file service. Derive principal server-side; require current permission/scope, typed owning-domain relationship, purpose/classification/state. Uploader provenance is not domain ownership and never independently authorizes access. Approval, medical and payroll evidence keep their stronger domain restrictions. AVAILABLE is necessary but not sufficient for private download.

Resolve immutable storage_location_key/object_key from trusted metadata and deployment allowlist. Never accept client provider credentials, endpoints or arbitrary buckets/containers. Isolated server provider credentials/signing secrets remain outside application settings and Flutter. Issue bounded temporary private access after current authorization; signed URLs are bearer capabilities until expiry, never persistent database/log/audit evidence. A new issuance reauthorizes. Explicit public branding is a separately authorized classification, not a private-file bypass.

New upload/replacement/finalization additionally requires current verified school entitlement, enabled module and deployment-controlled purpose policy. Client plan/capability claims and user-editable JWT metadata are ignored. Super Admin has no subscription bypass. Unknown purpose, PDF masquerading as photo, parent employee-document access and unentitled payment uploads deny. Generic approval/attachment categories must also satisfy underlying domain capability; semantic image contents cannot be perfectly inferred by a MIME check.

Keep allocation/finalization/availability mutation entry points private to the existing purpose-bound file worker. No authenticated direct RPC can bypass the server entitlement gate, no broad service-role write and no client-supplied acting principal. Trusted server intent records bind verified actor, school, domain, purpose, location/key and revision; protected commands validate this origin and normal authorization. Existing role ownership, RLS, lock ordering and evidence transactions remain otherwise unchanged.

Verify signed snapshot issuer/audience/revision/effective time/expiry; invalid or stale state blocks new use. Recheck at finalization with multi-instance revision fencing and audit evidence. Outstanding upload capabilities may accept private bytes after downgrade, but those cannot become AVAILABLE without current entitlement. Preserve existing valid files/authorized reads on downgrade. Suspension blocks new use without deletion; read/export policy is a separate activation decision. See [snapshot contract](../architecture/05_storage_entitlements_and_document_purposes.md).

Storage/network effects are not atomic with database transactions. Seal verified bytes against overwrite, verify measured 1..1,048,576 bytes/type/SHA-256, and reconcile failures/quarantine/replay. Provider IAM supplements application authorization. Actual adapter/snapshot enforcement is an activation gate, not implemented by this documentation.

## F23 provenance and actor derivation

uploaded_by_principal_id is immutable NOT NULL upload provenance, not domain ownership. The server derives it from the authenticated/verified initiating operation context; reject/ignore client-supplied uploader identity as authority. A purpose-bound SYSTEM initiator is valid only for an explicit system operation. created_by is the trusted metadata-row insertion executor, which may be the file worker; preserve the original initiator. Later finalization records its executor in audit without rewriting created_by.

Derive current principal, target business context, purpose, permission/scope, effective entitlement, enabled module and typed domain relationship server-side. Access also checks classification/state and workflow restrictions. Uploader equality is never sufficient; this cleanup grants no uploader-self capability. An uploader can lose access without invalidating the evidence, and another authorized domain actor can access it without uploading it. FAMILY attribution grants no staff authority. The reconciliation index only supports a separately protected operational lookup.
