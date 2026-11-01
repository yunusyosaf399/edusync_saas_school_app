# Section 01 - Architecture, decisions and requirements

Version 1.0, 1 November 2026. Source backlog: *EduSync / Ilmora Complete Database Backlog & Remaining Tasks*, detailed checklist 01, DB-001 through DB-011 (page 4). This is the detailed workstream, not the report's introductory executive-status section.

**Progress: 7 of 11 architecture tasks verified/documented; 4 remain open. Section 01 is not complete. Section 02 has not started under this assignment.** Counts describe this architecture checklist, not database implementation, merge or deployment completion. Existing accepted decisions are consolidated; none is newly approved by this report.

Baseline inspected: main `df1c98d5c2d19424946986fc6ba7615202b0a443`. The [branch snapshot](section01_branch_snapshot_20261101.json) pins all 78 open PRs returned by the API (one page, limit 100). A PR head records source identity, not passing tests, approval, merge compatibility or hosted state. Recheck it before integration.

## 1. Acceptance ledger

| Task | Status | Evidence and remaining boundary |
|---|---|---|
| DB-001 One customer school per project | VERIFIED / DOCUMENTED | AGENTS.md SaaS model; master specification sections 3 and 6; boundary below. Campus is not a customer tenant. |
| DB-002 Separate control plane | VERIFIED / DOCUMENTED | Master sections 3-4; approved invariants; control plane holds routing/subscription/deployment/version facts only. |
| DB-003 Global and campus/assignment/child scope | VERIFIED / DOCUMENTED | Scope matrix below; existing security resolver and permission catalogs. Role name alone never grants global scope. |
| DB-004 Feature-to-requirement/package/migration/test trace | IN PROGRESS | [Feature trace](section01_feature_trace_20261101.csv) inventories every current catalog row. Unimplemented migration/test links stay explicitly MISSING. Close only when exact per-feature artifacts and acceptance evidence exist. |
| DB-005 Preserve years, progression and profile history | VERIFIED / DOCUMENTED | Master sections 9-13; approved invariants; authoritative history contract below. Implementation acceptance remains with each owning package. |
| DB-006 Configurable currency/timezone/calendar/levels | VERIFIED / DOCUMENTED | Master sections 7-9; Foundation school_profiles currency_code/timezone; D1 academic catalogs. Contract below records configurability without inventing customer values or an implemented term calendar. |
| DB-007 Remaining owner decisions | OPEN | CUR-07 product options remain unapproved; physical/consumer and activation choices remain visible in the decision register below. Existing admissions and finance instructions take precedence over old generic stages. |
| DB-008 Final ERDs/catalogs/lifecycles/dependencies | IN PROGRESS | Versioned artifact register below identifies Foundation/D1 catalogs and proposed later designs. No final whole-school ERD or accepted cross-domain lifecycle exists yet. |
| DB-009 Parallel draft reconciliation | IN PROGRESS | Exact branch inventory and conflict evidence below; DB01/02 composition exists only in drafts. DB03/DB04/Finance are not one accepted source. No merge performed. |
| DB-010 Receipt-only boundary | VERIFIED / DOCUMENTED | Owner's 1 November instruction, PR #195 scope and #196 byte validation. Private upload and manual review; PR #190 bank signing and purchase/gateway integration deferred. |
| DB-011 Module class and release responsibility | VERIFIED / DOCUMENTED | Feature trace classifies CORE, OPTIONAL or FUTURE DATA DESIGN. Product/release decision owner: Younas Khan (`yunusyosaf399`); package/domain responsibility is separate from approval evidence. |

VERIFIED / DOCUMENTED here closes a requirement-definition task using existing authority. It does not mean the related operational database feature is deployed or fully tested.

## 2. School and control-plane boundary (DB-001/002)

One customer school has one operational Supabase project and may have Main, Girls, Junior or other campuses. Another customer school uses another project. A Supabase organization is the provider's project/billing container, not an operational tenant key. Do not add organization_id to all operational records as a substitute for this isolation boundary.

The control plane may keep customer routing, subscription/capability revisions, deployment/schema versions and service notices. It must not copy student, family, marks, fee, payroll, attendance or medical details into a central school-data store. School metadata and private uploaded bytes must retain the same school isolation boundary even when storage is externally provided. No cross-project FK is assumed.

Example: a Main-to-Girls campus move stays in the same school's project and retains both enrollments. Moving a customer school to another backend is a separately controlled migration, not a campus UPDATE.

## 3. Action and scope contract (DB-003)

All access requires a current verified principal, action permission, supported scope, required relationship/assignment, field disclosure and workflow state. All-campus visibility is still inside one school project. NULL campus is never an implicit ALL grant. Historical queries require a current historical-read permission; an old assignment cannot revive revoked access. Recheck at command application and offline retry.

| Actor | Permitted scope when explicitly granted | Required restrictions |
|---|---|---|
| Super Admin / Owner / Principal / Vice Principal | School-wide or selected campuses per action | No automatic medical/payroll disclosure, history deletion, entitlement bypass or cross-customer authority. Only Principal gives final admissions approval. |
| Administrator / campus administrator / Coordinator | Assigned campus/class/section or explicitly granted wider action | Administrator prepares admissions and forwards eligible cases; cannot give final Principal admission approval. |
| Teacher / class teacher / subject teacher | Effective assignment to exact class/section/subject and relevant campus/year | Separate class-teacher and subject-teacher relationships; campus visibility or employee affiliation does not grant attendance/marks authority. |
| Accountant / HR / Exam Controller | Explicit finance/HR/exam action and scoped targets | Separate private fields and independent business review rules; viewing a student does not permit a financial reversal or result publication. |
| Librarian / Transport Manager / Driver / Nurse / Security / Maintenance | Assigned module/campus/route/own records | Only necessary fields. Nurse data is restricted; driver access does not imply family or fee visibility. |
| FAMILY shared parent/guardian principal | Currently authorized linked children, possibly in different campuses | Requires current membership, child access, relationship basis and family-safe permission. Emergency-contact identity alone grants no portal access. Shared credential actions are attributed to FAMILY principal. |
| Student | Own permitted academic/profile records | No peers, family-wide access or private staff histories. |
| IT/support or externally operated service | Explicit approved action and narrow service context only | No new school IT role is introduced: current master role catalog omits it. Control-plane operator is not school Super Admin. Additional roles require explicit requirement/permission registration. |

Example: a teacher who is also a parent uses teaching permission for assigned class work and FAMILY child access for their children. Neither context expands the other.

Authority: [resolver matrix](../security/07_domain_authorization_resolver_matrix.md), [permission/disclosure catalog](../security/08_domain_permission_disclosure_catalog.md), [checked reads/commands](../security/09_domain_checked_reads_and_commands.md), [identity model](../security/01_identity_auth_model.md).

## 4. History, configuration and money contract (DB-005/006)

| Concern | Authoritative contract | Example |
|---|---|---|
| Academic year | Custom label, start/end dates and default year; keep all ended years. An active-year access policy is not deletion. | Selecting 2027 does not remove attendance/results from 2026. |
| Progression | Retain effective enrollment/campus/class/section/roll and correction lineage. Current summaries are projections. | Ahmad moves Junior Grade 4 to Main Grade 5; the Grade 4 enrollment remains queryable. |
| Profile/relationships | Retain relevant identity, status, family relationship and teacher assignment histories with actor/reason/effective dates. | Changing guardian does not rewrite the former guardian's historical provenance or preserve revoked current access. |
| Finance | Exact decimal arithmetic; round displayed/assessed agreed amounts to two decimals. Posted facts use adjustment/reversal, never hard deletion. | 1,000 SAR tuition with 50% tuition-only scholarship becomes 500.00; 200 SAR transport stays 200.00. |
| School configuration | School-owned currency_code and timezone; server derives operational local dates. No hard-coded SAR, UTC or Riyadh for every customer. | A Pakistani school may configure PKR and Asia/Karachi independently of a Saudi school. |
| Calendar/grade structure | Configurable academic year dates and levels, including schools without Play Group. Terms, holidays, periods and schedules belong to their later calendar/timetable package. | A school starts at Nursery; omitted Play Group is not a broken foreign key. |
| Generated documents | Store identity, version and source facts; generate invoice/result/certificate PDFs on demand. Original bank slips are retained private uploads. | Downloading an invoice twice does not create two obligations or require two bucket objects. |

Existing executable anchor: `supabase/migrations/20260924122445_foundation_identity_school_files.sql` defines school_profiles.currency_code/timezone. D1's server-date helper uses validated school timezone; a client-supplied date/timezone cannot authorize a roll-policy cutover. Full calendar and financial arithmetic acceptance remain downstream tasks.

## 5. Current decisions and unresolved gates (DB-007)

Later explicit owner decisions narrow the original v0.2 generic optional-admissions text. Retain old source history; do not implement its document-skip possibility as a bypass of the required certificates.

| Topic | Current evidence | Remaining work |
|---|---|---|
| Required documents / final approval | Owner requires birth and leaving certificate, PDF supported; missing documents pending for no more than two months; Administrator prepares, Principal alone final-approves | Tested live gate and atomic Student/enrollment/roll integration remain Admissions-owned. |
| Test skip | DB03 decision record selects independently reviewed pending/unassessed test skip; committed FAILED cannot become SKIPPED | Do not broaden this automatically to failed-test overrides or arbitrary interview skips. Reconcile latest evaluator and optional-stage policy. |
| Finance clearance | DB03 21 October record requires Finance-authorizer clearance in every final case, including approved fee waivers | Earlier “clearance OR waiver” wording is historical. Receipt upload alone does not clear admission. |
| Scholarship | Fixed amount or percentage for selected applicant/student and selected categories; monthly/time-limited rules and two decimals | Final approved scholarship-to-Student handoff and assessed charge acceptance still open. |
| CUR-01 through CUR-06 | PR #103 includes actual recorded product approvals, including CUR-01 timing and CUR-03 BF-1/B-M1 | Do not ask the owner to approve these again. Physical SQL, registered permissions and consumer acceptance remain separate. |
| CUR-08 | P01A/P02A whole-revision accepted generation and unique effective head approved | P03-P08 physical constraints, lock/ACL/install and consumer proof remain open. |
| CUR-07 | A1-G1 are prepared, NOT approved | Owner choice remains: trusted eligibility resolver, early Exam snapshot, fixed published homework audience, Section-only timetable, retained old snapshots, purpose-scoped access, fail-closed unsafe new use. Exact checkpoints and cross-domain contracts also remain open. |
| DB02 development review | PR #170 ADR-006 records solo-maintainer policy and owner acceptance of PR #168 at f472f2ab | Do not call it independent review or reopen G03 for another contributor. It does not approve other domains, merge or hosted activation. |
| Storage | Private school storage for current bank-slip evidence; existing server validation, entitlement and domain controls retained | No new bank-signature/cryptography, wallet/gateway intake or purchase linkage. Existing stored-byte SHA checks describe file integrity, not bank authentication. Provider activation/retention choices still need evidence. |

Pinned decision sources are in PR #102 (`76f62c29f9178eddfd21aa49f753da8bf8b2b303`), #103 (`98a2453e7314ee443dd09bb320cc474ef3fed168`), #170 (`9dd47dcdcf2843c59f8d162e9991c66dad08f1e7`), #195 and #196. Use the full SHA in the branch snapshot, not a mutable branch label, when reproducing the review.

## 6. Artifact versions and dependency path (DB-008)

| Package | Versioned design artifacts on inspected main | Current acceptance boundary |
|---|---|---|
| Foundation | 04_foundation_erd.md; 05_foundation_physical_catalog.md; 08_foundation_exact_dependency_graph.md; 06_foundation_constraint_matrix.md | Nine executable migrations and frozen tests; preserve exact bytes. |
| D1 | 27_domain_package_01_physical_catalog.md; 28_domain_package_01_exact_dependency_graph.md; 29_domain_package_01_physical_erd.md; 31_domain_package_01_concurrency_and_locking.md | Draft relation/operation definitions; source and historical acceptance evidence do not release Migration 10. |
| Admissions | PR #102 current physical-schema plan and P1-P7 lifecycle; newer #191-194 sources | Inactive draft; final protected evaluator, Principal decision and actual Student effect remain open. |
| Curriculum | PR #103 eight-entity BF-1/T7/T8 design and CUR decision records | Product-approved portions are not a final installed physical schema. |
| Finance | PR #102 DB08 draft slices, plus receipt-scope #195 and stored-byte fix #196 | Separate siblings; neither receipt branch includes the other solely because both target #102. |
| Other packages | DATABASE_COMPLETION_MATRIX.md and master sections referenced in feature trace | Requirements/design coverage; missing exact migrations/tests cannot be replaced with a diagram. |

Paths in the first two rows are relative to `docs/database/`. ERDs are abbreviated views; physical catalogs and actual SQL are the column/FK source. Section 01 cannot freeze a final whole-school graph until cross-domain handoffs are accepted. Preserve historical design labels rather than relabeling every earlier artifact as deployed.

Dependency order: frozen Foundation -> assembled D1 + DB01/DB02 -> Admissions/Finance clearance and curriculum handoffs -> atomic admitted Student/placement/scholarship -> academic operations and remaining domains -> full install/upgrade/security/restore gate -> Flutter/services/launch. Designs may be prepared before executable prerequisites; activation may not skip them.

## 7. Branch reconciliation and receipt boundary (DB-009/010)

The JSON snapshot is an inventory, not an integrated release manifest. Main has 9 executable SQL migrations and 243 .sql.draft files at the pinned SHA. Do not compare counts from another stack as if it were main. The [stack conflict analysis](section01_stack_conflicts_20261101.md) compares 21 pairs of current tips and lists shared paths whose final Git blobs differ; these require review, not automatic overwriting.

| Stack | Candidate head | Disposition |
|---|---|---|
| DB01/DB02 final composition | #168 f472f2ab; review policy #170 9dd47dcd | Development acceptance recorded for exact #168 source; merge/final freeze/hosted upgrade remain separate. |
| Admissions base and Finance | #102 76f62c29 | Base for multiple descendants; not merged into main. |
| Admissions final-review/assessment | #189 -> #191 -> #192 -> #193 -> #194 39e15e8c | New #194 body records rollback/static/12 pgTAP source assertions PASS. The PDF's “tests pending” is stale. Protected stage evaluator and final admission still absent. |
| Curriculum | #103 98a2453e | Design only; partial approvals preserved; CUR-07 and physical gate open. |
| Bank-slip scope | #195 c4bcc749 | Receipt-only policy overlay, sibling of #196. |
| Bank-slip stored bytes | #196 1d62f781 | Targeted service validation candidate; no claim of joint integration with #195 or installed storage. |
| Deferred signed bank settlement | #190 148fdf4f | EXCLUDE from current receipt-only release. Retain source/history; no deletion or activation. |

Before DB-009 closes, choose exact accepted per-domain sources, compose on a separate branch, resolve shared migration/suite/receipt/permission registries, verify frozen hashes, and run exact-source domain authorization/replay/race, fresh install and populated upgrade checks. The successor integration manifest must record commit/tree/digests, dependency order, selected/excluded sources, test evidence and actual acceptance. No main/owner branch was overwritten by this documentation task.

Example: merging #196 would validate stored bytes in its candidate service but would not import #195's policy document, #194's assessment source or #168's DB02 composition. Every required slice must be deliberately assembled and retested.

## 8. Release ownership and exit conditions (DB-011)

The [feature trace](section01_feature_trace_20261101.csv) gives every current catalog row a classification, requirement sections, responsible package, release decision owner and current migration/test evidence. Optional modules still require database coverage before the final database gate when applicable; FUTURE DATA DESIGN does not authorize implementing hardware/vendors. Cross-cutting engines are CORE. Android/Windows/Web implementation remains after database acceptance.

Younas Khan (`yunusyosaf399`) is the product/release decision owner. Domain owner labels indicate engineering responsibility, not a second named approver, a signature or production access. The assistant prepares source and verification; it does not fabricate product choices, independent approval or deployment authorization.

To complete Section 01:

1. DB-007: obtain remaining actual product decisions, starting with CUR-07; settle affected technical contracts and record explicit deferrals only where authorized.
2. DB-009: complete the accepted source composition, with exact tests and no deferred #190 activation.
3. DB-008: freeze final affected catalogs, ERDs, lifecycles and dependency contracts against that source.
4. DB-004: replace every applicable MISSING migration/test entry with accepted exact artifacts/evidence, or record an explicitly accepted phase deferral. The feature CSV is a starting inventory, not proof that every feature is implemented.

Stop at Section 01 until those tasks close. A new update must state task counts, changes, a plain-language example and remaining blockers; never report an implementation percentage derived from document counts.
