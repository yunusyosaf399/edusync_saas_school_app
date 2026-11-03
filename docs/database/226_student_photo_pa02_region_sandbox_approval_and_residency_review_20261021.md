# Student Photo PA-02 — Residency, project selection and sandbox authorization decision record

**Prepared:** 2026-10-21  
**State:** **PA-02-R1 OWNER GEOGRAPHIC PREFERENCE RECORDED / R2..R6 OPEN / NO PROJECT CREATED / NO STORAGE ACTIVATION**  
**Branch:** PR #120 (Student Photo provider/service only).  
**Predecessors:** [#222 decision register](222_student_photo_pa01_pa08_owner_security_decision_packet_20261020.md), [#223 acceptance matrix](223_student_photo_provider_activation_dependency_and_test_matrix_20261020.md), [#224 Supabase-first provider evaluation](224_student_photo_pa01_provider_selection_evidence_and_sandbox_gate_20261020.md), [#225 private sandbox isolation model](225_student_photo_supabase_storage_sandbox_isolation_contract_20261021.md).  
**Binding architecture:** ADR-003 (provider neutral), ADR-004 (signed entitlements), F23 `file_objects`, migration 10 inactive.

## 1. Decision boundary — what is actually approved

The product owner has selected **Supabase Storage as the first sandbox candidate**, and on **2026-10-21** accepted **any Supabase-supported country, with the United States preferred** for hosting geography. These select a preferred evaluation vendor and a permitted geographic candidate class; they are **not** production provider selection, country-specific legal compliance validation, a particular Supabase project, deployment authorization, a bucket, an SDK, IAM policy or live Student upload. PA-02-R1 is recorded **as the owner's regional preference only**, and all infrastructure, real-data processing, legal/compliance and independent security approval gates remain open. Do not infer them from PR merge, an account's geographic location, available projects, or successful mock tests.

**No existing school/database project may be relabeled or reused as a sandbox solely because it appears in an account's projects list.** Selection must use explicit owner approval and evidence that it is disposable, synthetic-only and isolated from customer data. Project identifiers, API keys, account details and bucket names are intentionally not recorded in this public source document.

## 1A. Subsequent product-owner regional preference — 2026-10-21

**Exact decision conveyed by the owner:** “Any country that available in supabase us is prefered.” Interpreted narrowly as **any provider-supported hosting country is acceptable as a candidate; prefer the United States when available**. The owner's message resolves the previously unknown *product geographic preference*, not whether each actual School customer's legal/data-protection obligations allow international transfer.

**Preferred specific-region shortlist (provider documentation verified 2026-10-21):**

| Rank | Specific U.S. region | Disposition |
|---|---|---|
| 1 | `us-east-1` — US East, Northern Virginia | **Engineering recommendation**, subject to account availability, owner acceptance of exact project choice, security and actual operational suitability |
| 2 | `us-east-2` — US East, Ohio | Engineering fallback if preferred region not available or unsuitable; same gates |
| 3 | `us-west-2` — US West, Oregon | Alternative U.S. region; same gates |
| 4 | `us-west-1` — US West, Northern California | Alternative U.S. region; same gates |
| Other | Any specific Supabase-supported non-U.S. region | Permissible candidate if U.S. option is not suitable, but requires documented reason and matching security/compliance review |

The **recommended code `us-east-1` is not itself an owner selection of a deployable project**. Do not choose the regional *Americas* grouping in place of an exact region; confirm the code in the project creation interface when authorized.

**Gate update:** PA-02-R1 geographic preference is **OWNER POLICY RECORDED**, eliminating the former *missing owner preference* blocker. Strict Pakistan/Saudi in-country residency must **not** be inferred from the old example matrix; if a particular School's laws, contracts or privacy obligations impose such rules, perform a separate jurisdiction review before handling that School's personal data. No real Student images are authorized in any foreign or U.S. region by this product preference; first sandbox trials remain strictly synthetic-only.

## 2. Current Supabase region behavior — source verified 2026-10-21

- Supabase documents that each project has one primary region, hosting primary PostgreSQL, Auth and Storage objects. Primary location does **not** alone prove complete cross-service data residency: backups, logs, exports, external processing, Edge Functions and subprocessors also need review. See [Supabase regions](https://supabase.com/docs/guides/platform/regions), [GDPR/data residency](https://supabase.com/docs/guides/security/gdpr-compliance).
- A **specific** AWS region can be selected; a **general** grouping may route to an eligible location in that wider area. When jurisdiction matters, prefer *specific region*; do not substitute a broad geographical label for proof of the actual hosting jurisdiction.
- Supabase documents that changing an existing project's primary region requires **a new project and migration**, not an in-place region switch. See [Change Project Region](https://supabase.com/docs/guides/troubleshooting/change-project-region-eWJo5Z).
- The current published specific-region list includes (examples) `ap-south-1` (Mumbai, India), `ap-southeast-1` (Singapore), `ap-southeast-2` (Sydney, Australia), and `eu-central-1` (Frankfurt, Germany). **As of the source review there is no Pakistan- or Saudi-Arabia-specific region on that list**. This is a published-catalog observation, *not* a legal compliance determination or a guarantee of future availability.
- If a customer requires primary data physically **inside Pakistan or Saudi Arabia**, do **not** silently choose India, Singapore, Australia or another country as an equivalent. That strict in-country requirement is a **BLOCK** against the presently listed hosted options until compliance counsel/security and provider evidence establish a permissible architecture.
- The external-provider sandbox can still be considered with **nonpersonal synthetic fixtures only**, subject to owner-designated jurisdiction, acceptable cross-border transfer/processing conditions, account controls and security review. Sandbox region selection is **not** automatic production region selection. Each future School deployment still needs its own separate region/risk decision.
- Confirm the above again immediately before provisioning. The [Supabase changelog](https://supabase.com/changelog?types=breaking-change) lists an HTTP TLS cipher change scheduled from 2026-11-10; check the chosen test client/SDK TLS compatibility if the trial runs near or after that date. The 2026 Data API exposure-default change also means no assumption that newly created tables automatically have API grants; **this PA-02 package creates no tables**.

### Region disposition matrix

| Owner-confirmed requirement | Candidate disposition | Gate |
|---|---|---|
| Pakistan in-country primary-data residency strictly required | No PK-specific region in the verified published list; investigate compliant alternative architecture/hosting and legal guidance | **BLOCK**, no selected hosted region |
| Saudi Arabia in-country primary-data residency strictly required | No SA-specific region in the verified published list; investigate compliant alternative architecture/hosting and legal guidance | **BLOCK**, no selected hosted region |
| Specific approved foreign jurisdiction permitted | Choose one **exact published region code** matching approved legal, privacy and operational constraints; document backup/log/egress factors | **PENDING OWNER + SECURITY** |
| Sandbox synthetic-only and cross-border fixture processing explicitly permitted | Choose a dedicated disposable nonproduction project in a supported **specific** region, separately approved by authorized owner | **PENDING OWNER + SECURITY** |
| Product geographic preference for synthetic-only PA-02 evaluation | Owner permits any Supabase-supported country and prefers U.S.; recommend specific `us-east-1` subject to confirmation | **OWNER PREFERENCE RECORDED — infrastructure/security gates remain** |

This matrix is a checklist, not a proposed legal opinion. It does not assert that a region is commercially available to a given account/plan until confirmed at creation time.

## 3. Proposed sandbox identification and approval protocol

**Candidate name (not provisioned):** `edusync-photo-pa02-disposable`. The name does not identify an actual project or constitute permission to create one.

Before provisioning, record *outside this public repository*:

1. Authorized product owner's organization and budget approval, and jurisdiction for synthetic-only trials.
2. Independent security owner's assignment, approved account/organization, required second reviewer and emergency disable/teardown permissions.
3. Selected specific `region_code`, effective documentation date, School customer-residency assumptions and region/egress exception rationale.
4. Dedicated project ID **in restricted operations evidence only**; prove not reused from any real School deployment and no real Student/person records or existing production buckets.
5. Separation of admin/provisioner, staging-only writer, verifier/sealer, reader/reconciler and teardown principal permissions; document any unavoidable privileged Storage-key exception with compensating controls.
6. Approved private stage/final bucket design or independently proven equivalent, deployment-owned mapping version, synthetic fixtures, short-lived credential policy, secret-manager reference and scrubbed audit-log retention.
7. Explicit cost ceiling, expiration date, rollback/kill switch and approved treatment of ambiguous remote writes and retained evidence.
8. Exact vendor/SDK/API versions, supported upload/write-once APIs and test harness commit/SHA without leaking keys.
9. Independent signoff authorizing **SANDBOX EVALUATION ONLY**; keep public uploads, production purpose `STUDENT_PROFILE_PHOTO`, F23 AVAILABLE and `student.photo.set` disabled.

Do not store plaintext service keys, signing tokens, full Storage object keys, provider access URLs, raw student imagery or real project/account identifiers in PR comments, public documentation, logs or test artifacts.

## 4. Required no-write review before creating the project

The reviewer should verify **without mutation** that:

- Public code changes are limited to PA documentation and do not alter DB-01/02/03/04, Enrollment locks, Foundation SQL, Flutter or D1 activation.
- Owner's chosen *specific* region exists in the live provider region selector, not only in an old documentation snapshot.
- The chosen account supports a wholly separate nonproduction project and budget/time-limited operation.
- No selected project presently contains School operations data, user accounts, sensitive Storage objects, or active integrations; an existing project is never repurposed without explicit independent evidence and approval.
- All operator identities are verified separately from the School's authenticated Principal; service keys never reach the client.
- No-upsert and Storage RLS do **not** substitute for an immutable sealed-object guarantee; test UPDATE, delete/recreate, copy/move and privileged-worker paths as in PA-02 [#225](225_student_photo_supabase_storage_sandbox_isolation_contract_20261021.md).
- Project-selection and image handling are bounded to dummy data; do not use real parent, employee, Student or health data.
- No remote database migration, public RLS grant, production capability entitlement or `student.photo.set` is activated by the trial.

## 5. Post-approval sandbox test sequence (NOT executed)

| Stage | Conditional activity once an explicit sandbox-use approval exists | Required acceptance |
|---|---|---|
| S00 | Validate region, project identity, pricing, isolation and credential custody under reviewer observation | Match R1/R2/R4 owner record, no live School project |
| S01 | Create/configure privately isolated bucket layout; deny anonymous, cross-school and unauthorized signed-token access | P02-01..03, P02-09, P02-13 |
| S02 | Execute real concurrent CREATE, overwrite, DELETE/recreate, COPY/MOVE, stale credential and privileged-key attacks | P01-01..06; P02-04..08 |
| S03 | Independently read stored synthetic final bytes and compare measured SHA-256/size after injected corruption | P01-07..09; P02-10..11 |
| S04 | Simulate crash, lost acknowledgement and staged revocation WITHOUT production Student integration | P01-09..12; P02-11..12, P02-15 |
| S05 | Audit secret redaction, quarantine, evidence holds, worker permissions and teardown | P02-14, P02-16; STP-026..035 applicable |
| S06 | Archive redacted immutable evidence, pass exact-head CI and obtain independent security verdict | **PA-01/PA-02 SANDBOX PASS only**, not PA-03..08 or activation |

Tests may legitimately reveal that the chosen Supabase Storage setup cannot satisfy hard byte immutability under every effective privileged path. That is a fail-closed **STOP**, not approval to weaken the architecture or overwrite final bytes.

## 6. Owner/security signoff template (BLANK — do not autofill)

| Field | Status/value |
|---|---|
| PA-02-R1 Product geographic preference | **OWNER RECORDED 2026-10-21 — any Supabase-supported country, U.S. preferred; legal/customer-specific compliance review remains open** |
| PA-02-R2 Approved disposable nonproduction project/account and budget | **OPEN — Product Owner + infra** |
| PA-02-R3 Specific region code / stage+seal bucket architecture | **OPEN — `us-east-1` recommended, not provisioned/approved; Product Owner + Security** |
| PA-02-R4 IAM/secrets owner, independent reviewer, compensating exceptions | **OPEN — Security** |
| PA-02-R5 Verified SDK + sealed-byte replacement guarantees | **OPEN — Real-provider evidence** |
| PA-02-R6 Expiry, cost ceiling, stop and teardown/retention authorization | **OPEN — Product + security** |
| Product signoff (actor/date/version) | **UNSIGNED** |
| Independent security signoff (actor/date/version) | **UNSIGNED** |
| Exact approved test commit/run/evidence | **NONE** |
| Permitted release state | **DESIGN ONLY** |

## 7. Workstream noncollision and continuation decision

This is a single **documentation-only** step in PR #120; do not merge or reactivate DB-01 (#100/stacked), DB-02 (#101/#122), DB-03 (#102) or DB-04 (#103). `main` remains frozen at its current verified head; a future photo provider implementation needs new review against whatever protected Enrollment/DB-01 locks exist at that time, including real Student PRIMARY/Campus revocation and two-session race evidence.

**Completed now:** independent region/provider documentation review, explicit block for unsupported in-country assumptions, reproducible preauthorization/test checklist and owner/security decision ledger.  
**Not completed/authorized:** exact sandbox/project provisioning, region availability and compliance validation for any actual School's data, live IAM, actual Supabase project or buckets, real provider bytes, exact-head real-provider CI, any PA-xx security signoff, migration activation and photo SET. These require *distinct* explicit owner and security gates before action.
