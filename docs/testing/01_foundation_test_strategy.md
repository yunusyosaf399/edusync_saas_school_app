# 01 - Foundation Test Strategy

**Status:** PROPOSED tests and acceptance criteria, 2026-09-22. This document contains no executable tests or synthetic production tables.
**Authority:** [AGENTS.md](../../AGENTS.md), [development process](../workflows/DEVELOPMENT_AND_CHANGE_PROCESS.md), [master specification](../requirements/School_OS_SaaS_Master_Specification_v0.2.md) sections 66, 72 and 77-78.

## 1. Test layers and evidence

Design assertions now, implement them after the corresponding model/command exists. Foundation invariants can later run as database and API tests; future business scenarios below are contracts to realize with their domain package. Do not invent Attendance/Finance/Student schemas just to run this plan.

| Layer | What it verifies | Evidence |
|---|---|---|
| Document/contract review now | Requirement traceability, status labels, dependency order, complete scope/approval contracts, no premature implementation | Review notes and linked TBD decisions |
| Isolated database tests later | FKs, uniqueness, checks, historical restrictions, RLS and transaction semantics | Repeatable test results, schema version and synthetic fixture description |
| Auth/API/storage integration later | Real authenticated and unauthenticated contexts, command bypass attempts, token revocation, private objects and approved function/view paths | Request/outcome plus relevant sanitized audit/result IDs |
| Concurrency/failure tests later | Parallel sessions, crashes, retries, stale versions, worker leases and external delivery failures | Reproducible interleavings and count/invariant assertions |
| Rebuild/upgrade/recovery later | Installation, prior release upgrade, school customization preservation, archive/replay correctness | Version/checksum logs and restoration evidence |

Testing framework, runner and disposable environment tooling remain T15. No dependency is installed. Direct database owner/service connections are useful setup tools but cannot stand in for user RLS tests.

## 2. Synthetic fixture design

Use two **separate school projects** S1 and S2 for future cross-school isolation tests, not two tenant IDs in one database. S1 has Campus A and B, two academic years and rooms with repeated names across campuses.

Later domain fixtures: Grade 8 sections A/B, Mathematics/Science, teacher T assigned to Campus A / Grade 8-A / Mathematics, a second teacher, family F linked to children C1/C2 but not C3, and a student account for C1. Ahmed's individual principal has Teacher and Parent grants; his family's separate shared principal has only Parent/Guardian grants and a distinct Auth binding. Include separate sessions, recovery paths and encrypted caches for both principals. No family credential can step up into Ahmed's staff principal.

Create explicit bounded grant fixtures for Super Admin, Principal, Campus Admin A, Accountant A, Nurse A and Exam Controller A. None is authorized merely by its display name. Include inactive accounts, expired assignments, revoked grants, old JWTs, unavailable resolvers, retired campuses and locked domain states. Use synthetic files and fake identifiers only.

## 3. Concrete actor scenarios

Each scenario asserts both the response and absence/presence of domain mutation, history, audit and notification side effects.

| ID / actor | Positive case | Negative case / invariant |
|---|---|---|
| AUTH-01 Super Admin | Explicit permitted configuration operation in both campuses succeeds and creates audit evidence | Deleting audit/protected finance history or editing locked results directly fails; S2 token/data cannot be used in S1 |
| AUTH-02 Principal | Scoped cross-campus VIEW and eligible approval succeed | VIEW cannot mutate; principal cannot bypass required Exam Controller review or apply a stale correction |
| AUTH-03 Campus Admin A | Permitted A-campus edit succeeds | B-campus read/edit is denied unless separately granted; changing a record's campus checks both source and destination |
| AUTH-04 Teacher | T can modify assigned Grade 8-A Mathematics marks and assigned official attendance session | Grade 8-B, Science, unrelated B-campus attendance, finance and other employee payroll are denied; broader VIEW never widens UPDATE |
| AUTH-05 Accountant | Authorized finance review and approved reversal command succeed | Taking attendance, reading medical records and directly deleting a payment fail |
| AUTH-06 Parent/Family | FAMILY context reads permitted C1/C2 information and submits linked-child leave/evidence | C3, unrelated search/export/files and staff permissions are denied, including when the account is associated with teacher T |
| AUTH-07 Student | C1 reads own permitted result and submits own work | C2's records and own published-mark edits fail; fee access fails when not granted |
| AUTH-08 Nurse | Explicitly authorized medical access for A-campus pupils succeeds with required evidence | B-campus records without scope, finance/payroll and unrestricted student export fail |
| AUTH-09 Exam Controller | Eligible review and scoped PUBLISH after required checks succeed | Missing review, pending correction, B-campus publication and unrestricted finance access fail |
| AUTH-10 Individual Teacher who is also Parent | Ahmed's individual principal uses assigned Teacher permissions and separately authorized Parent permissions for his linked children | Parent OWN does not become teacher UPDATE on unassigned children; his wife's session on the distinct shared-family principal cannot access his teaching, salary, reviews, staff inbox or files, even if email/contact/Person relationships overlap |

## 4. Foundation constraint and migration cases

| ID | Setup / action | Expected result |
|---|---|---|
| DB-01 Fresh installation | Later apply the proposed sequence to an empty school project, then approved bootstrap material | All constraints/helpers/policies exist; no unexpected public access; deterministic required defaults; no domain tables introduced by Foundation |
| DB-02 Upgrade | Upgrade the previous accepted draft/release with realistic historical grants, requests and customized settings | IDs/history/customizations retained; revoked access not restored; no dropped protected evidence |
| DB-03 Referential integrity | Orphan room/campus, grant/permission, request/policy or review/step | Reject; account removal does not cascade into person/audit/business history |
| DB-04 Uniqueness | Duplicate campus code, room code within campus, live Auth binding, normalized alias, role/action pair and scope binding | Reject within intended scope; identical room codes in different campuses allowed; null-scope duplicates blocked |
| DB-05 Local checks | End date before start, invalid status transition, zero/negative room capacity when set, malformed scope target combination | Reject consistently through database and API |
| DB-06 Historical state | Retire campus/year/account or switch default year | Existing authorized history remains intact; old IDs not reassigned to new subjects |
| DB-07 Exact quantities | Later numeric contract checks at boundaries, excess scale, NaN and rounding edges | Reject or explicitly round per approved policy, never silently accept undefined money behavior; Finance-specific rules await that package |
| DB-08 Bootstrap/rebuild | Interrupt each structural/provisioning stage, then resume | Fail closed, avoid duplicate actors/defaults, retain deployment evidence and reconcile partial Auth/Storage operations |

## 5. Security, grants and shared-family isolation

- **SEC-01:** call every read/write surface as unauthenticated, unprovisioned, suspended and retired principal; deny private data even with a still-valid token.
- **SEC-02:** combine ALL/VIEW from one grant and ASSIGNED/UPDATE from another; UPDATE outside assignment must fail. Mismatched F12/F11 role references must be impossible.
- **SEC-03:** forge role, campus, Person, context or grant fields in client metadata/payload; reject. Test current and expired assignment dates and unknown scope resolvers.
- **SEC-04:** test the individual Teacher+Parent principal and the separate shared-family principal. Family credentials cannot mint the individual token, switch into staff identity, obtain staff grants through recovery/relinking, or inherit them when a role definition changes. Direct staff assignment to SHARED_FAMILY fails. A shared family session cannot see staff inbox, salary/files or approve as teacher. T01 credential mechanics remain pending; the separation invariant does not.
- **SEC-05:** revoke a grant while a command is authorizing. Use the chosen T04 locking/version boundary to show a defined order: the command commits before revocation or is denied; no post-revocation command authorizes on stale cached grants.
- **SEC-06:** test grant administration ceilings, self-grant attempts, protected role category edits and scope widening.
- **SEC-07:** repeat allow/deny tests through views, functions, search, reports, exports, AI retrieval and background workers, not only direct row access.
- **SEC-08:** verify fields: permission to read a student row does not expose medical/payroll columns. Error responses and row counts must not leak unrelated identities.
- **SEC-09:** exercise username enumeration, alias normalization/collision, signup without reviewed provisioning, recovery/relink attempts and school switching. No cross-school tokens/cache mix.

## 6. Approval, audit and transaction cases

| ID | Stimulus | Expected result |
|---|---|---|
| FLOW-01 | Attempt direct protected UPDATE, fabricated APPROVED state, unsupported operation or arbitrary JSON fields | Denied; only registered typed command can apply a change |
| FLOW-02 | Change submitted payload, skip a review, self-approve by switching roles, forge reviewer | Denied; frozen intent and complete eligible chain required |
| FLOW-03 | Change target after approval but before execution | Version conflict; no overwrite; existing review preserved, new review/action required |
| FLOW-04 | Two reviewers/workers act concurrently; cancellation races execution | At most one effective step decision/application; either cancellation wins before mutation or executed fact persists |
| FLOW-05 | Revoke reviewer/scope or supersede policy before execution | Follow accepted revalidation policy; proposed conservative path blocks invalid authority and records the conflict |
| FLOW-06 | Fail required audit insert or outbox insert during business transaction | Entire protected mutation/application rolls back; no success audit/event; separate failed-attempt evidence |
| FLOW-07 | Crash before commit, then after commit before acknowledgement | Before: no effect. After: retry returns existing authorized result; one domain effect, revision, application receipt and event set |
| FLOW-08 | Retry same idempotency key with different payload, or replay another principal's key | Conflict/denial; no duplicate effect or result leakage |
| FLOW-09 | Execute each of eight example operations | Domain-specific checks run; financial reversal preserves original, marks correction preserves published version, leave checks linked/self scope, and high-risk administration checks account type and grant ceilings |
| FLOW-10 | Submit without request permission/assignment, or execute a REJECTED/CANCELLED/EXPIRED request | Deny; state/history remains intact and no domain effect/outbox success is produced |
| FLOW-11 | APPROVED request fails current domain validation, such as a changed target invariant | Record sanitized failure/conflict after rollback; no domain mutation, successful application or business event; new review is required when intent/state changes |
| FLOW-12 | Approved high-risk role/scope/account-binding change exceeds the reviewer's grant ceiling or assigns staff authority to a shared-family principal | Typed Identity/Access executor rejects it despite approval; preserve attempt/decision evidence and existing principal/grant state |
| AUD-01 | Protected operation by Super Admin/system worker | Correct initiator/executor/context, reason and approval linkage recorded |
| AUD-02 | Normal/admin client attempts audit edit/delete or fabricated audit insert | Denied; actor retirement leaves evidence accessible to authorized audit readers |
| AUD-03 | Submit secrets/private payload or forged device/person details | Secrets excluded; only allowed differences recorded; client claims labelled; shared-family actor not misattributed to teacher |
| AUD-04 | Failed login/denied command/rollback | Classified attempt evidence via designed separate path, never a successful business event |

## 7. Notifications, storage, offline and future adapters

- **EVT-01:** deliver one event twice to several consumers; one logical inbox item/recipient/purpose and one domain effect, separate consumer progress.
- **EVT-02:** expire a worker lease; stale worker acknowledgement fails; retry/dead-letter/replay retains the original event identity.
- **EVT-03:** fail notification creation/delivery after the business transaction and outbox commit; the committed business fact, audit and application receipt remain successful, while delivery retries independently.
- **NOT-01:** inspect another recipient/context's inbox, change recipient/content or read a staff notification from FAMILY context; deny.
- **NOT-02:** revoke a family-child link or permission between scheduling and delivery; suppress protected content and deny target access. Verify preferences cannot grant access or disable policy-required categories.
- **NOT-03:** simulate provider success followed by network timeout; retry using provider idempotency when available and document possible duplicate delivery. Do not claim exactly-once email/push.
- **FILE-01:** guess bucket/key, change owner/campus, forge type/size or exceed the current 1 MB target; deny/quarantine; no public access via metadata.
- **FILE-02:** metadata transaction succeeds while upload fails and vice versa; pending/orphan reconciliation does not expose incomplete evidence or delete protected referenced files.
- **FILE-03:** permission revoked after signed URL issuance; test the chosen expiry/revocation limitation rather than asserting immediate recall.
- **SYNC-01:** replay stale expected_version, duplicate offline operation and future/old client clock; conflict or dedupe, not critical last-write-wins.
- **SYNC-02:** stale authorization, school/account switch, tombstone retention and missed/out-of-order cursor records; no cross-scope replay or silent resurrection. Protocol details remain T09.
- **SYNC-03:** revoke a grant while the device is offline, then replay duplicate operations and conflicting expected versions; deny lost authority, deduplicate authorized retries and surface critical version conflicts without last-write-wins.
- **DEV-01:** contract-test forged source identity, duplicate vendor/source event, wrong campus/person, low-confidence/malformed capture, replay and oversized payload. Reject before canonical attendance mutation. No hardware integration or biometric storage is created.
- **DEV-02:** manual and QR inputs follow the same canonical attendance command; future adapters must not create a second attendance truth.
- **RET-01:** later archive/recovery rehearsal verifies protected evidence completeness, access restrictions and link resolution; no normal purge of finance/audit/academic history.

## 8. Acceptance gates

Every protected command needs paired allow/deny assertions, a version/race scenario, expected audit evidence and domain invariant checks. Each policy needs real non-owner execution tests. Any unexplained sensitive-data exposure, approval bypass, duplicate financial effect, history loss or missing required audit is a release blocker.

The current deliverable is a reviewed test strategy, not a claim that backend tests pass. Only documentation integrity can be checked now. Follow [dependency order](../database/03_foundation_dependency_order.md); track open choices in [ADR-001](../decisions/ADR-001-foundation-database-principles.md).

**Next task: FOUNDATION SQL MIGRATION DRAFT — FILES ONLY, NO SUPABASE EXECUTION.** The [database execution plan](02_foundation_database_execution_plan.md) adds exact interval/revocation, terminal-receipt, INVALIDATED request, real-role/RLS and rebuild/upgrade tests selected by the physical review. No SQL or database test execution is performed in this documentation task.

## 9. Future multiplatform client acceptance

[ADR-002](../decisions/ADR-002-flutter-multiplatform-client-architecture.md) confirms Android, Windows and Web from one Flutter codebase. These are planned tests, not executable tests added or run by the documentation update.

| Area | Future acceptance expectation |
|---|---|
| Shared business behavior | Run identical domain/application scenarios on each target; validation, workflow and reporting outcomes agree |
| Authorization parity | Same actor, permission, campus/assignment, target and workflow state yields identical allow/deny results on all targets; test revoked access, direct API bypass, AI, exports and private storage |
| Responsive presentation | Exercise Compact/Medium/Expanded/Large widths, resizing, preserved feature state and touch/pointer/keyboard interaction; exact breakpoint values await UI design |
| Adapter contracts | Shared file/export, device and storage contracts handle success, unsupported capability, denied permission and failures consistently |
| Build isolation | Web compilation does not depend on native filesystem/device APIs; Windows integrations do not break Web; Android-only APIs remain isolated from Web/Windows builds |
| Offline security | Verify encrypted sensitive persistence, account/school cache isolation, versions, idempotent replay and live reauthorization on each supported implementation; no silent critical last-write-wins or unencrypted fallback |
| Browser sessions/routes | Validate URL navigation and browser session behavior against shared authentication/routing contracts without weaker backend security |

UI widgets, packages, breakpoint values and per-platform offline technologies remain TBD. No Flutter test code, dependency or build configuration is changed here.

## Future storage adapter and entitlement contract tests

Documentation-only acceptance cases for [ADR-003](../decisions/ADR-003-provider-neutral-object-storage.md) and [ADR-004](../decisions/ADR-004-storage-plan-entitlements.md); no tests implemented/run now. Run the same contract against each selected isolated adapter, using fake/synthetic files, not production accounts.

| Case | Required result |
|---|---|
| Unauthorized download; wrong campus/domain; leaked object key | Deny despite metadata visibility or key knowledge; medical/payroll/approval clearance still required |
| Temporary download expiry | New requests after expiry deny; new issuance reauthorizes; no promise of recalling prior downloads/in-flight transfers |
| Location/key substitution | Client arbitrary container/location or another file key denies; wrong school mapping denies |
| Size/type/hash | Accept valid 1 and 1,048,576 bytes; reject/quarantine zero/oversize, declared/measured mismatch, unverified or mismatched SHA-256, disallowed MIME/signature |
| Pending/orphan/failed upload | Object exists but PENDING denies; metadata with missing bytes denies; failed validation remains quarantined/unavailable |
| Upload intent replay and overwrite | Repeated finalization cannot create a second identity; upload URL cannot mutate bytes after verification; crashes reconcile without exposure |
| Replacement and relocation | New row preserves lineage/old evidence and mapping; immutable key/location/purpose edits reject |
| Secrets and URLs | Provider credentials never returned; signed URLs/tokens absent from database, audit, logs and receipts |
| Classification | Default PRIVATE; authorized public branding only after validation; private evidence cannot be publicly exposed |
| Photo-only school | Authorized student photo succeeds once its handler exists; payment evidence, employee contract, birth/medical/certificate uploads deny |
| Selected-document school | Only explicit certificate/payment/photo mappings allow; absent employee-photo/branding grants deny; no implicit other documents |
| Full-document school | Supported/enabled photo/payment succeeds with normal authorization; medical needs medical clearance; unknown/future purpose denies |
| Client forgery | PREMIUM plan claim, forged capability Boolean or editable JWT metadata cannot elevate; parent employee-document upload and unrelated Teacher payment evidence deny |
| Purpose laundering | PDF labeled photo rejects; generic/approval evidence cannot bypass underlying medical/payment capability; typed relationship mismatch denies |
| Super Admin | Unentitled upload denies; only audited control-plane entitlement change can enable it |
| Upgrade | New purpose allows only after verified revision effective time; existing objects do not move |
| Downgrade | Existing medical file remains readable by authorized actor; new medical upload/replacement denies; no deletion |
| Suspension/expiry/cancellation | No new uploads/finalization; existing bytes/metadata preserved; read/export policy tested separately when defined |
| Snapshot validity | Wrong issuer/signature/audience/type, rollback revision, future-effective or expired/stale state cannot enable uploads; durable high-water mark survives restart |
| Outage/refresh | Valid snapshot works only within finite configured freshness; stale state denies new use without revoking normal historical reads |
| Concurrent revision/finalization | Downgrade ordered first rejects finalization; accepted finalization first remains historical; all instances use current revision fencing; outstanding uploaded bytes stay unavailable if now disallowed |
| Direct-call bypass | Authenticated caller cannot invoke private upload/finalization/availability worker entry points; forged intent/principal/revision denies; no service-role fallback |
| Audit/module/registry | Failed activation audit keeps new use closed; disabled module or unknown purpose denies; old definitions preserve historical reads |
| Generated artifacts/quotas | Generated PDFs stay on demand; no implicit archiving or invented GB cap; future usage distinguishes stored/archived/quarantined/purged and pre-row orphan bytes |

Provider choice, TTL/refresh/clock-skew settings, content allowlists, trusted intent persistence and snapshot transport/fencing must be selected and tested before upload activation. Metadata/SQL readiness is not adapter or commercial enforcement deployment readiness.

## F23 upload provenance acceptance cases

Planned tests only; no executable tests introduced. Upload entitlement/module/purpose and existing domain rules remain prerequisites.

| Case | Required result |
|---|---|
| Parent submits child's birth certificate | uploaded_by_principal_id is Parent; typed child/student relationship owns document context; access follows current family/student authorization, not uploader equality |
| HR submits employee contract | HR remains uploader, not employee subject/business owner; HR/domain authorization governs access |
| Accountant submits payment evidence | Accountant attribution does not replace Finance/payment relationship authorization |
| File worker creates metadata for human upload | uploaded_by_principal_id preserves verified human initiator; created_by is purpose-bound SYSTEM insertion executor; later finalization of an existing row preserves created_by and audits finalizer |
| Uploader loses permission | File remains valid evidence; former uploader cannot access it solely through upload provenance |
| Other authorized actor | Access through typed owning-domain permission succeeds even though actor did not upload file |
| Forged uploaded_by_principal_id | Client claim rejected/ignored; persisted initiator comes from verified operation context, never attacker-selected Principal |
| FAMILY upload | Family-authorized evidence may be submitted; file relation never grants staff authority |
| SYSTEM/null attribution | Explicit purpose-bound server operation can be SYSTEM initiator; unknown/NULL uploader and generic SYSTEM substitution reject |
| Attribution integrity / reconciliation | Initiator/creator remain immutable and principal deletion/update is restricted; protected initiating-principal/state reconciliation works without exposing arbitrary uploader-only reads |
