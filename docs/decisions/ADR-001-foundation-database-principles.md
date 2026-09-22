# ADR-001: Foundation Database Principles

- **Status:** PROPOSED technical architecture. Existing CONFIRMED product decisions are restated below and are not reopened by this ADR.
- **Date:** 2026-09-22
- **Owners:** product owner and architecture/security reviewers; named approvers and acceptance date TBD.
- **Requirement references:** [AGENTS.md](../../AGENTS.md), [project context](../../CODEX_PROJECT_CONTEXT.md), [master specification v0.2](../requirements/School_OS_SaaS_Master_Specification_v0.2.md), [invariants](DECISIONS_AND_INVARIANTS.md), [security rules](../security/SECURITY_WORKFLOW_AND_AUDIT.md).
- **Supersedes:** none. This is a proposed first technical baseline, not an accepted schema or authorization to deploy.
- **Scope:** design documentation only. No SQL, migrations, Supabase changes, Flutter changes or dependencies.

## 1. Context and status interpretation

School OS needs shared identity, access, school/academic anchors, approval, audit and event contracts before business schemas. Without those contracts, unrelated CRUD designs would duplicate security rules and overwrite protected history.

CONFIRMED below means required by the existing product baseline or explicit task constraints. PROPOSED marks a recommendation that still needs review. TBD identifies a choice not made. Entity labels are not frozen physical table names. The implementation must not treat an unresolved context proof, approval rule or storage policy as already working.

## 2. Confirmed decisions preserved

Each row records context, decision, rationale, consequences, alternative and status.

| ID / context | Decision | Why | Consequences | Alternatives considered | Status |
|---|---|---|---|---|---|
| C01 Customer isolation | One customer school = one Supabase project; control plane keeps routing/commercial/deployment metadata only | School operational data remains isolated | Reproduce deployment per school; no cross-project operational FKs or central student/finance copy | Shared multi-school operational database is superseded by the product decision | CONFIRMED; specification 3-4, 75 |
| C02 Multiple campuses | Campuses are scopes inside a school; no tenant_id/organization_id on every record solely for SaaS tenancy | A campus is not another SaaS customer | Campus authorization is still required; school profile is a business anchor | Treating every campus as a tenant or every table as multi-school | CONFIRMED; AGENTS.md, specification 6 |
| C03 Human/account identity | Person and authentication account are distinct; a human/account context can have multiple roles | People may exist without login and act in several capacities | Credentials cannot be the sole business/history identity | One Auth user row as complete student/employee/family identity | CONFIRMED; specification 10-16, database guardrails |
| C04 Effective authorization | Role + action permission + scope + contextual assignment + workflow state determines access | Role title or viewing a campus does not grant operational authority | Explicit action-specific checks, teacher assignments and protected states across all access paths | Role-only checks or global account scope union | CONFIRMED; specification 16-17 |
| C05 Shared family access | Keep one shared family login for linked children; it does not inherit staff rights from a related Person | Preserve parent model without staff privilege leakage | Attribute family actions to the account; protect staff context separately | Separate mandatory father/mother logins would change the baseline; sharing staff authority is unacceptable | CONFIRMED requirement; context proof PROPOSED/TBD |
| C06 Protected history | Preserve academic/enrollment/status/attendance history; no destructive financial deletion; published results and finalized payroll use controlled correction | Earlier business facts must remain reconstructable | Revision/reversal and effective-history design per domain | Overwriting current class/mark/salary or hard-deleting transactions | CONFIRMED; specification 9, 12, 27, 35, 40, 55-56 |
| C07 Sensitive changes | Reusable approvals govern sensitive correction, salary, leave and financial operations | Visibility is not permission to apply protected changes | Domain validation remains necessary after approval | Unrestricted UPDATE or separate incompatible engines for each module | CONFIRMED; specification 17, 72 |
| C08 Privileged accountability | Audit important actions including Super Admin; normal users cannot erase audit history | Broad permissions must remain attributable | Restricted evidence access, actor preservation and controlled retention | Exempt administrator activity or editable audit history | CONFIRMED; specification 55-56 |
| C09 Documents | Normally generate PDFs on demand from persistent facts/identifiers; upload source files privately with current <=1 MB target | Separate durable business facts from rendered copies and private evidence | Metadata/access validation; no default storage of every invoice/result PDF | Public document buckets or automatic persistence of every PDF | CONFIRMED; specification 32, 48-49 |
| C10 Attendance extensibility | Canonical attendance is independent from capture method; manual/QR now, hardware via future adapters | Preserve one attendance truth and avoid vendor-driven redesign | Validate adapter observations before canonical writes; biometric/media/protocol design deferred | Separate attendance truth per vendor or automatic biometric columns | CONFIRMED; specification 22.1 |
| C11 AI and offline | AI uses normal permissions; sensitive offline cache is encrypted and critical conflicts detected | Alternate interfaces cannot bypass authorization or overwrite history | Reauthorize AI actions and offline replay; per-domain sync rules remain needed | Service-key AI access or critical last-write-wins | CONFIRMED; specification 57-58 |
| C12 Five engines | Data, Permission, Workflow, Automation and AI remain distinct collaborating engines | School OS is a coordinated operating system | Shared contracts for audit, events, storage, notifications and versioning | Independent CRUD pages with only UI security | CONFIRMED; specification 5 |
| C13 Reproducible schema | Version schema/setup changes through migrations and repeatable provisioning; no undocumented dashboard-only schema | Every school deployment must be reproducible and upgradeable | Per-school schema version, upgrade/rebuild and recovery evidence | Manually configuring every school without versioned setup | CONFIRMED; specification 64-65 |

## 3. Technical proposals made by this package

| ID / context | Proposed decision | Why | Consequences | Alternatives considered | Status |
|---|---|---|---|---|---|
| P01 Stable references | UUID v4 internal identities, explicit FKs/uniqueness and separate business numbering | Supports independent business identity and eligible offline creates | UUID possession grants no access; validate offline collisions and business number scopes | Sequential internal IDs; UUIDv7 after runtime validation | PROPOSED; T02/T13 |
| P02 Time, values and versions | Server instants/actors, business DATE fields, IANA zones, exact decimal quantities and expected-version concurrency | Avoid timezone, rounding and silent overwrite errors | Currency scale, historical intervals and conflict policies need domain decisions | Floating money; client-clock conflict resolution; arbitrary JSON-only records | PROPOSED; T02/T09/T13 |
| P03 Identity and scope records | Stable principals survive credentials; scope bindings reference one role assignment and one matching permission grant | Preserves history and prevents mixing unrelated grants/scopes | Effective authorization requires a complete currently valid chain | Person=Auth; role assignment implies ALL; global scope bag | PROPOSED; T03-T05 |
| P04 Family/staff context isolation | Shared FAMILY context exposes only Parent/Guardian capabilities; staff context requires independent person-bound proof | A shared password must not confer a teacher's salary/approval rights | Block shared-credential staff activation until proof, recovery and every data path are validated | UI role switch; shared factor; mandatory separate adult logins | PROPOSED safeguard; T01 |
| P05 Typed approval core | Versioned definitions/steps and frozen requests; domain-owned target/payload validator and execution | Enables reusable approval without a universal arbitrary updater | Stale targets/authority block application; reviews and revisions remain | Unrestricted JSON patches; approval flag directly authorizes field writes | PROPOSED; T06/T07 |
| P06 Four distinct concerns | Audit evidence, domain facts, recipient notifications and automation commands have separate contracts/lifecycles | Access, retention and retry semantics differ | Audit is not a queue; notification delivery is not business truth | One catch-all activity/event table | PROPOSED physical decomposition meeting required distinction; T08/T10 |
| P07 Private metadata and recipient state | File metadata tracks private content lifecycle; notifications split inbox, preference and delivery responsibilities | Allows access control, reconciliation and independent recipient state | Revalidate target/context, minimize payloads, acknowledge signed-link limitations | Permanent signed URLs; public files; one shared read flag | PROPOSED; T08/T11 |
| P08 Atomic effects and outbox | Commit protected mutation/history, audit, receipt and domain event together; separate at-least-once delivery | Avoid missing audit/events and duplicate effects after failures | Durable idempotency, consumer leases, recovery and dead-letter handling | Emit before commit; assume exactly-once external delivery | PROPOSED; T07-T09 |
| P09 Staged deny-first deployment | Create restricted structures in dependency order; policies evolve with dependencies; activate only after reviewed bootstrap/testing | Prevent incomplete foundations from exposing records | Separate migration, seed, test and activation steps; forward repair after real data | RLS added after rollout; destructive rollback of history | PROPOSED; T02/T04/T12/T15 |
| P10 Foundation boundary | Define F01-F28 concepts only; postpone student/business schemas and device/provider/AI implementations | Avoid prematurely locking domain assumptions | Typed domain links and resolvers remain unavailable until designed | Generate every module or generic device registry now | PROPOSED; T05/T13/T14 |

## 4. Unresolved technical decisions: complete register

This register consolidates TBD references across all ten documents. Resolving a choice may require a dedicated ADR; none is silently accepted here.

| ID | Open decisions | Needed before / proposed owner |
|---|---|---|
| T01 Shared-family/staff assurance | Account mode representation; independent person-bound proof, enrollment/recovery, session binding, expiry/replay protection; staff inbox/file isolation across every API path | Before staff grants on any shared credential; identity/security + product owner |
| T02 Database/platform baseline | Supported PostgreSQL/Supabase version; namespaces/exposed schemas; needed extensions (none assumed); physical naming/key/UUID and status/check/enum details; migration naming/version convention | Foundation ERD/SQL draft; database/platform reviewer |
| T03 Account and alias lifecycle | Username mapping strategy/normalization/reuse; signup/provisioning policy; recovery/relinking; duplicate Person/merge rules and active account cardinality | Identity schema/auth implementation; identity/security |
| T04 Enforcement and revocation | RLS/helper/function/view ownership; verified context transport; recursion avoidance; immediate application revocation with outstanding tokens; concurrent revoke/write ordering; session/key lifecycle and external Auth audit ingestion | Exposed policies and privileged commands; security/platform |
| T05 Scope and academic ancestry | Class/section/subject/assignment/family resolvers; historical vs current responsibility; campus/year calendar variation; typed parent consistency and field-level disclosure | Domain scope activation; academic/student/security design |
| T06 Approval policy | Exact states, self-review/delegation, reviewer reassignment, sequential/parallel/quorum, expiry/cancellation, required assurance, policy supersession and authority loss after approval | Workflow physical design and handler activation; product/domain/security |
| T07 Domain execution contracts | Payload versions, typed target/result/evidence links, validation placement, transaction/locking strategy, failed/retry classification, immutable application evidence and permanent uniqueness | Protected command implementation; domain/database |
| T08 Events and notifications | Outbox worker/transport, ordering and lease protocol, retry/backoff/dead-letter/replay limits; push/email provider and endpoint verification; category rules/preferences/mandatory notices/quiet hours; context-safe delivery and idempotency horizons | Event/notification implementation; platform/product/security |
| T09 Offline protocol | Eligible offline writes, conflict rules, authoritative cursor, tombstones, maximum offline period, encrypted cache/key handling, scope invalidation and command receipt horizon | Offline implementation; client/domain/security |
| T10 Retention and evidence | Per-class duration, protected-history limits, legal holds, archival integrity/access, audit redaction, failure-log collection/rate limits, administrator tamper evidence and privacy/anonymization | Production data/cleanup policy; product/security/operations with appropriate policy review |
| T11 File handling | Bucket/path and ownership rules, exact byte interpretation of 1 MB, type/content verification, quarantine, upload reconciliation, signed-link lifetime/revocation limits and sensitive downloads | Storage configuration/upload implementation; security/documents |
| T12 Bootstrap and deployment | Approved role/permission/settings defaults; per-school activation, reproducible seed updates without clobbering customization; routing trust, operator boundaries, schema-version tracking and provisioning automation | First school bootstrap; platform/product/security |
| T13 Business-domain detail | Final monetary/percentage precision and rounding; permanent numbering; attendance edit windows; finance/reversal thresholds, salary retroactivity, leave rules, sensitive field classification; generated-document rendering technology | Relevant domain package, not invented in Foundation; domain/product owners |
| T14 Future adapters | Device registry necessity, protocols/vendor SDKs, source identity/replay/confidence, biometric template/media location, consent/privacy, anti-spoofing and retention | Only when future hardware/integration work is authorized |
| T15 Test and recovery tooling | Test framework/runner, isolated project provisioning, baseline fixtures, performance targets, CI evidence, backup/restore and upgrade/rebuild procedures | Before migration application or deployment; engineering/operations |

Deferred AI provider/retrieval implementation, subscription pricing, full automation scheduler/rule storage and other roadmap integrations remain outside this Foundation decision set; none is selected by an event interface or control-plane boundary.

## 5. Consequences and risks

| Risk | Consequence | Mitigation / remaining decision |
|---|---|---|
| Shared credentials and staff identity | Family members could inherit staff access or be misidentified in audit | Context-specific grants and fail-closed activation; T01 is an implementation blocker |
| Combining permission/scope fragments | Broad read scope could incorrectly widen write authority | Bind complete grant chains; test cross-role and cross-context mixing |
| Stale tokens/grants or concurrent revocation | A revoked user may retain effective access | Live principal/grant checks plus defined transaction ordering; T04 |
| Over-generic workflow or unchecked target IDs | Approved JSON could bypass domain invariants | Typed handlers, real domain links and immutable request intent; T07 |
| Shared registries becoming premature platform code | Foundation complexity grows without a business requirement | Treat F labels as conceptual; review physical splits, defer devices/business schemas |
| Secrets or sensitive values copied into audit/events | Wider retention/disclosure than the original record | Minimized allowlisted payloads, restricted evidence references, T10 |
| Database owner/service privilege | RLS or append-only application rules can be bypassed by infrastructure authority | Separate least privilege and operational evidence; do not claim tamper-proof logs |
| Outbox or provider duplicate/reordered delivery | Duplicate notification or business action | At-least-once model, dedupe/version checks, durable command uniqueness |
| Auth/Storage cross-service partial failure | Orphans, incomplete identity or unavailable evidence | Pending states and idempotent reconciliation; no assumed distributed transaction |
| Signed downloads and delivered messages | Information may remain available after access revocation | Short controlled delivery, minimal content, documented expiry limitation; T11 |
| Offline scope/clock/version drift | Silent overwrites, resurrected archives or cross-account cache access | Explicit conflict/version checks and school/context cache separation; T09 |
| Per-school project operations | Upgrade drift and inconsistent defaults | Rebuild/upgrade tests, version inventory and non-destructive seed updates; T12/T15 |
| Unresolved domain policy | Invented finance/leave/attendance semantics could be mistaken for requirements | Mark examples illustrative; defer specifics to T06/T13 |

Migration impact: conceptual records need physical FK/constraint and index design before drafting SQL. No existing data migration is implied. Security impact: extra context and per-grant checks increase policy complexity but make authorization reviewable. Offline impact: server receipts/versions support later sync but do not define a full sync protocol. Future extensibility: canonical attendance and domain events accommodate adapters without prebuilding vendor schemas.

## 6. Existing-document consistency review

The four existing design documents were reviewed against AGENTS.md, CODEX_PROJECT_CONTEXT.md, the requirements baseline and the supporting guardrails. They retain one school per project, campus scope, all five engines, separate person/Auth concepts, isolated family context, bounded role/permission scopes and the canonical attendance adapter contract. **No change to those four documents was necessary for this continuation.**

The baseline has the following differences/ambiguities; none authorizes a silent product change:

| Observation | Resolution used in this package |
|---|---|
| Specification section 59 mentions mobile/Android development alongside Windows; AGENTS.md explicitly identifies Flutter Windows .exe as the current primary client | Follow AGENTS.md for priority; retain future/additional client boundaries. No Flutter changes or platform removal |
| Specification section 69's proposed ordering lists workflow/audit late; AGENTS.md and DATABASE_DESIGN_NEXT_PHASE.md establish their foundations before business domains | Follow the governing foundation-first order; later domain integration is distinct from creating the shared core |
| Shared-family credentials coexist with one-person/multiple-role requirements | Requirements are retained; staff assurance is unresolved T01, not solved by silently replacing family login |
| Master specification has historical layout/version wording, including an old v0.1 ending despite its v0.2 heading, and a forward-looking version example | Treat v0.2 Markdown plus current repository guidance as authoritative; no bulk rewrite of historical text |
| docs/testing/ was absent in the continuation checkout | Created it for the requested strategy document; no unrelated skeleton recreation |

No unresolved contradiction in school isolation or the five-engine model was found. The distinctions above are documented precedence choices or open security mechanics, not newly confirmed implementation requirements.

## 7. Validation and file register

The [test strategy](../testing/01_foundation_test_strategy.md) defines positive/negative authorization, role/context isolation, approval bypass, audit immutability, transaction/race, outbox/delivery, file and future adapter cases. Backend tests are planned, not executed, because this task creates no implementation.

| Document | Role in this design set | Continuation action |
|---|---|---|
| [01_domain_boundaries](../architecture/01_domain_boundaries.md) | Domain ownership, five engines and dependencies | Reviewed; unchanged |
| [01_database_conventions](../database/01_database_conventions.md) | Identifier/time/value/history/transaction conventions | Reviewed; unchanged |
| [01_identity_auth_model](../security/01_identity_auth_model.md) | Person, principal, Auth and shared-family context | Reviewed; unchanged |
| [02_rbac_permission_scope_model](../security/02_rbac_permission_scope_model.md) | Complete grant/scope evaluation and nine role examples | Reviewed; unchanged |
| [02_foundation_entity_map](../database/02_foundation_entity_map.md) | F01-F28 conceptual entities, relationships, lifecycle and security | Created |
| [01_approval_engine_design](../workflows/01_approval_engine_design.md) | Typed reusable approval lifecycle and seven domain contracts | Created |
| [02_audit_event_notification_foundations](../architecture/02_audit_event_notification_foundations.md) | Evidence/events/delivery/automation and future adapter boundary | Created |
| [03_foundation_dependency_order](../database/03_foundation_dependency_order.md) | Proposed migration batches, activation gates and recovery | Created |
| [01_foundation_test_strategy](../testing/01_foundation_test_strategy.md) | Concrete design verification and later executable-test plan | Created |
| ADR-001-foundation-database-principles.md | Confirmed/proposed decisions, alternatives, complete TBD and risk register | Created |

## 8. Recommended next task

**"Foundation ERD and SQL Migration Draft"**

Use this proposal to produce a reviewable Foundation ERD and draft migration design, resolving blocking TBDs and mapping each conceptual relationship to concrete constraints and policies. SQL drafting in that future task does not imply deployment approval. Do not apply anything to Supabase automatically.

This next task has **not** been started. Student/academic/employee and other business-domain packages follow the accepted Foundation design.
