# Foundation TBD Gate

**Status: OPEN review gate, 2026-09-23. No decision is silently approved by this document.**

The [ADR-001 T01-T16 register](ADR-001-foundation-database-principles.md) remains the source decision history. This gate classifies work needed to review the [physical catalog](../database/05_foundation_physical_catalog.md), [ERD](../database/04_foundation_erd.md), [constraints](../database/06_foundation_constraint_matrix.md), and [RLS matrix](../security/03_foundation_rls_matrix.md). It does not close ADR items or authorize implementation.

## 1. Gate meanings

- **A — must resolve before physical schema approval.** A reviewer must accept/amend the proposed structure, or explicitly approve a disabled/deferred subset. Merely documenting a proposal does not close the gate.
- **B — must resolve before SQL migration draft.** Concrete enforcement/runtime contracts must be selected before generating SQL that would otherwise guess behavior.
- **C — deferred until the relevant domain/platform implementation.** Foundation reserves a safe interface and keeps missing handlers/resolvers disabled.
- **D — future only.** No implementation or speculative schema in this phase.

Each ADR item has one primary earliest gate. Mixed items list later subdecisions separately so an A label does not require designing every future feature now. Every A and B entry below is **OPEN**. Review may accept the recommended proposal or record a different decision with affected catalog changes.

## 2. Complete classification

| ADR item | Primary gate | Decision needed at that gate | Recommendation / owner | Explicitly later or conditional work |
|---|---|---|---|---|
| T01 | A | Approve separate principal/Auth cardinality and account-kind isolation across recovery/relink, inbox and caches; no shared-to-staff activation path. | Retain distinct INDIVIDUAL/FAMILY bindings and no staff grants on FAMILY. Review ownership/recovery invariants with identity/security and product owner. | Detailed sign-in UI and assurance/session protocol can continue under B/C, but no unsafe recovery shortcut is assumed. |
| T02 | A | Approve namespaces/exposure, checked-text state vocabulary, keys and no-required-extension proposal; all affect physical contract. | Accept/amend app/app_private split, server UUID v4 and table/constraint conventions. Database/platform reviewer owns approval. | B: choose supported runtime, UUID function, migration filename/checksum/applied-version evidence and verify platform compatibility before SQL. No Supabase connection in this task. |
| T03 | A | Approve one non-retired individual principal per Person, historical principals, one live binding per principal/Auth UUID, conditional username storage and alias reuse semantics. | Retain historical retired principals and immutable actor FKs; do not implement person merges. Decide alias strategy or explicitly defer login_aliases from the first SQL draft. | B: normalization/length/confusable policy, provision/relink validation and reconciliation; C: rich duplicate-person merge workflow if identity remains immutable until designed. |
| T04 | B | Fix concrete RLS/helper/view/function roles, exposure grants, verified context, revocation locks, external Auth deletion/version reconciliation and audit path before SQL. | Security/platform reviewer supplies execution ownership and non-recursive authorization design; no direct client writes; no service-key user proxy. | C: operational session UX detail can follow only after isolation/revocation contracts are testable. No claim that JWT deletion alone revokes access. |
| T05 | A | Accept school-wide academic years and explicit no-assumed-non-overlap; validate that future campus calendars can attach without changing year identity. | Academic/product reviewer confirms anchor shape. Foundation only supports ALL/CAMPUS plus disabled OWN/ASSIGNED contract slots where domains are missing. | C: class/section/subject/teaching/family ancestry, historical responsibility, field visibility and campus calendars. Unknown resolver denies until typed domain design. |
| T06 | A | Accept policy freeze, request states, sequential one-effective-decision stages, version selection, conflict handling and successful application split; unresolved review policy can alter structure. | Product/security reviewers decide self/same-person/family-interest conflicts, supersession, eligibility loss and whether sequential baseline suffices. Do not silently add quorum/parallel or assume one of several levels suffices. | B: exact legal transition/expiry/cancellation/locking checks. C: per-domain approver chains/thresholds. Unsupported delegation/parallel/quorum remain disabled, not default policy. |
| T07 | A | Accept typed operation/target/result extension pattern, receipt namespace/hash/version contract, request/receipt matching and one application per request. | Database/domain reviewers confirm disabled targetful contracts until real typed FKs and validators exist; no executable JSON patch. Review transactional ACCEPTED-to-terminal receipt design. | B: exact canonicalization format and byte/JSON bounds, lock order, retry/error taxonomy, deferred trigger placement. C: each later domain's concrete target/result relation and handler. |
| T08 | A | Decide whether external delivery metadata with unresolved endpoint_ref is accepted as disabled design placeholder, or defer that table from first SQL draft pending typed endpoint design. | Keep immutable events, consumer state, inbox, preferences and channel attempts separate. Require an actual verified endpoint FK and account ownership contract before channel row creation/dispatch; choose no provider now. | B: consumer registry, lease/fencing protocol, retry/ordering and category policy needed by drafted functions. C: providers, endpoint schema implementation, quiet hours, delivery limits; no channel activation until reviewed. |
| T09 | B | Specify receipt/dedupe preservation across offline replay and any cleanup; confirm immutable IDs/expected versions needed by future sync. | Keep permanent application uniqueness and durable receipt key/hash evidence; no TTL. Mark offline writes as proposals and reauthorize at server. | C: sync cursors/tombstones, eligible operations, maximum offline period, cache encryption/key lifecycle/purge and conflict UX. No sync/device tables yet. |
| T10 | A | Approve retention/immutability and historical UUID snapshots versus privacy/redaction obligations; these choices affect whether evidence can ever be rewritten. | Product/security/operations must accept retain-by-default/no-cleanup for this draft or specify a scoped evidence-preserving design. No legal duration or legal-hold schema invented. | B: redactable fields/payload size bounds and approved diagnostic exposure before SQL. C: durations, archive infrastructure, hold/cleanup workflows and tamper-evidence tooling before production retention work. |
| T11 | A | Accept immutable private file lineage, typed ownership/evidence and pending-upload lifecycle; decide whether these fields support the intended upload/recovery flow. | Security/documents reviewers confirm no public file path grants and no automatic stored PDFs. Select exact max-1-MB byte interpretation and input bounds as B before SQL CHECKs. | B: bucket/key policy, content validation/quarantine and metadata/Storage reconciliation; C: signed-link lifetimes, download UX and provider-independent upload implementation before activation. |
| T12 | B | Approve deterministic bootstrap SYSTEM origin, initial role/permission/scope catalogs, schema-version evidence and activation controls before SQL/seed draft. | Platform/product/security reviewers prevent seeded broad grants, preserve school customizations and ensure app cannot edit its deployment version. | C: control-plane routing/operator provisioning automation; operational data remains per-school. No central operational replica. |
| T13 | C | No business-domain tables/commands are designed now. | Leave monetary precision/rounding, numbering, attendance windows, finance reversals, salary/leave rules and sensitive field classifications to owning domain design. | No Foundation blocker while domain handlers remain disabled; do not seed guessed policies. |
| T14 | D | Future device/biometric/camera/RFID protocols, raw media/templates and vendors are outside this phase. | Preserve capture adapter -> validated source event -> canonical attendance command; do not create device/provider/biometric tables. | Only revisit when explicitly scheduled and approved; no current Foundation SQL blocker. |
| T15 | B | Choose validation strategy and feasible isolated test/upgrade/restore tooling before writing migration drafts intended for implementation. | Engineering/operations define non-owner RLS, constraint/race, new-project rebuild and upgrade evidence. Documentation checks do not substitute for backend tests. | C: production performance budgets and operational backup schedules may follow, but required application/deployment verification must precede activation. |
| T16 | C | Additional ADR item included for completeness: later platform implementation choices. | Keep AI permission-aware and automation purpose-bound; no AI provider/retrieval, scheduler/rule tables, subscription pricing or reporting projections selected. | D: future roadmap integrations; C: relevant scheduled platform packages. Neither is implied by an outbox interface. |

## 3. What this proposal settles for review, without declaring approval

The catalog specifies 34 application table candidates and every column, including composite candidate keys for matching role/action/scope and principal/role family classification. It separates stable actors from live external Auth links and preserves multiple retired historical individual principals. It also specifies frozen policy/request terms, normalized reviewer candidates, unique successful application evidence, durable command receipts, separate audit/event/delivery/inbox/preferences, and typed non-secret settings/file metadata.

Two catalog entries are explicitly conditional. login_aliases may be excluded if T03 selects a different safe username strategy. notification_channel_deliveries is disabled pending a typed verified endpoint relation; its bare endpoint_ref is **not** an approved production ownership model. T08 must accept this staged boundary or defer the whole relation from the first SQL draft. The review can therefore approve a documented subset without inventing provider-specific tables.

No product policy was invented to close a TBD. Checked-text states, one non-retired individual principal, code-owned family classifications, server UUID v4, conservative unrevoked-grant uniqueness, namespace exposure and sequential one-decision stages are proposals. Exact retention, identity recovery, conflict-of-interest rules, review delegation/quorum, upload bytes and offline protocol remain open as classified.

## 4. Consistency findings and review risks

| Finding | Treatment |
|---|---|
| Requested .gitignore hardening is already in the current repository | Verify behavior and leave the file unchanged; do not add duplicate lines or create secrets. Existing Flutter rules remain. |
| Conceptual docs say no physical tables are defined and next task is ERD/catalog | Their conceptual status remains accurate for their own scope. Change only relevant next-task wording to point to this review package. |
| Conceptual F06 uses ACCOUNT plus individual/shared-family type | Proposed physical kind flattens that pair into INDIVIDUAL/FAMILY and retains SYSTEM. This is a documented representation change, not changed access policy. |
| Identity permits historical account associations and proposes one active individual account | Partial unique proposed for one non-retired individual principal, with multiple retired histories. T03 must accept this stronger provisioning/suspension rule or change the predicate before approval. |
| Conceptual workflow already proposes sequential levels and one effective decision | Preserve PENDING/EXECUTED/FAILED lifecycle vocabulary and required_reviews=1. Do not implement quorum/parallel/delegation merely because candidate rows can represent several people. |
| F13 calls for typed scopes, not a universal scope registry | permission_scope_contracts is a deployment-owned permission-specific allowlist; actual CAMPUS targets have real FKs. Future CLASS/SECTION/SUBJECT links remain absent; unknown resolvers deny. |
| F28 calls for verified endpoint ownership while provider tables are postponed | Explicit unresolved typed endpoint FK and disabled channel writes. Human review must accept deferral or require the endpoint design first. |
| Physical FKs introduce receipt/request/audit and default-year/logo cycles beyond conceptual batch labels | Late FK addition/validation before exposure is required. operation_contracts must exist before command_receipts; refine the exact physical creation graph during the approved SQL draft. No conceptual batch is treated as executable SQL. |
| RLS alone cannot prevent privileged worker abuse or hide individual columns | Separate privileges, narrow projections, protected commands, worker purpose and field restrictions; T04 before SQL. No claim of deployed enforcement. |
| Full source specification still has historical versions/platform ordering described in ADR-001 | Retain AGENTS.md precedence: Windows primary, Foundation before domain tables, latest Markdown authoritative. No unrelated requirements rewrite. |

No unresolved contradiction was found in the confirmed one-project-per-school model, multiple campus support, five-engine boundaries, distinct family/individual access, history preservation or future attendance adapter flow. The rows above are explicit proposal differences and unresolved enforcement choices, not evidence that the schema is ready to apply.

## 5. Review checklist and exit

Human physical review should record accept/amend/defer outcomes for each A gate and each conditional relation, approve the complete-grant/family FK chains, verify all immutable/history/delete rules, and agree on which B items must be resolved in a follow-up design clarification. Record resulting decisions in an ADR with catalog/matrix updates; do not automatically change ADR-001 to Accepted.

Before SQL draft: A outcomes recorded; B choices documented; no unresolved FK pretending to be usable; concrete field/JSON bounds and typed handler contracts for the enabled subset; exact role/exposure plan; bootstrap and non-owner validation strategy. Domain/future C/D work remains disabled and does not justify speculative Foundation tables.

Sequence:

1. **FOUNDATION ERD + PHYSICAL TABLE/COLUMN CATALOG** — this documentation package.
2. **FOUNDATION PHYSICAL DESIGN REVIEW** — next task; ready for human review, with open gates.
3. **FOUNDATION SQL MIGRATION DRAFT** — only after approval and A/B gate closure; not started.

**Ready for human review: YES. Ready for physical approval or SQL generation without resolving gates: NO.** No Flutter application changes, dependencies, Supabase connection, migration files or production schema accompany this package.

## 6. Documentation verification performed

- All 34 proposed tables and 401 explicit column rows are present; all F01-F28 concepts have mappings, and every table appears in the constraint and RLS matrices.
- The 21 proposed composite FKs reference existing modeled columns and declared candidate keys. This is a structural documentation check, not an executed database constraint test.
- Seven Mermaid ER blocks and one dependency flow block have balanced fences; Markdown table shapes and 76 local documentation links were checked. Mermaid rendering and backend policy execution were not run.
- T01-T15 and the additional ADR T16 have explicit gate classifications; no item was marked resolved merely by drafting the proposal.
- Fifteen ignore-rule cases passed without creating test/secret files, including ignored environment/key material and retained .env.example, Flutter source and pubspec.yaml visibility. Existing .gitignore needed no edit.
- A SHA-256 comparison against the 96-file initial repository inventory showed only the five new design documents and three next-task wording changes. No existing files were removed; Flutter, dependency and Supabase files were unchanged. No SQL files were found. Git whitespace checks passed for the tracked edits.
