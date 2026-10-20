# DB-01 — Owner approval review after prerequisite SQL PRs #106 and #107

**Review performed:** 2026-10-19. **Outcome: technical recommendation completed; PRODUCT-OWNER SIGNATURE REQUIRED.**
**Owner:** DB-01 `student.roll.correct` design/review, draft [PR #100](https://github.com/yunusyosaf399/edusync_saas_school_app/pull/100). **No RC or RP decision is approved by this document.** No SQL, shared migration, Foundation, tests or CI changed here.

## 1. Evidence checked before recommending approval

- Latest inspected `main` at review: `d82cd678fc3e1c03ed832b5b1be5897ffc48642a`. `AGENTS.md` controls read order and prohibits inventing product/authorization/history decisions.
- DB-01 original readiness [#153](153_d1_student_roll_correct_p1_contract_readiness.md), [seven-document RC packet](db01_rc01_rc08_owner_decision_packet_20261019.md), [typed P1 API/receipt gate](db01_roll_correction_p1_api_receipt_stale_apply_gate_20261019.md), [acceptance/race gate](db01_roll_correction_acceptance_fixtures_receipt_races_20261019.md), physical D1 catalog [#27](27_domain_package_01_physical_catalog.md), locking [#31](31_domain_package_01_concurrency_and_locking.md).
- DB-02 [PR #101](https://github.com/yunusyosaf399/edusync_saas_school_app/pull/101) head `4c23c9a8301a5efc44cb008e5b00f166884669c5`: [RP owner-decision packet](https://github.com/yunusyosaf399/edusync_saas_school_app/blob/db/db-02-roll-policy-design/docs/database/db02_rp01_rp07_owner_decision_packet_20261019.md). RP-01…RP-07 stated **PENDING**, not approved.
- GitHub [Issue #69](https://github.com/yunusyosaf399/edusync_saas_school_app/issues/69) remains **open**, identifies RP-01…RP-07 as unresolved, and returned **zero comments** at review; PRs #100, #101 and #107 likewise returned no formal review comments. [Non-authorizing D1 register #156](156_d1_four_student_operation_decision_register.json) lists `student.roll.correct` and `student.roll_policy.change` as not runnable and the RC/RP gates open.
- [PR #106](https://github.com/yunusyosaf399/edusync_saas_school_app/pull/106) head `03f9303244ee9c3c9bf4b33f40e91749ce2dcaeb`, **draft/open**, installs *append-only draft overrides* for full-retained-persistent candidate selection and source stored-policy/allocator prelock in Enrollment END. Verified existing exact-head GitHub workflows succeeded: D1 static, Foundation local and D1 runtime; authenticated rollback-only suites #75 **12/12** and #76 **30/30**, total D1 business **3,166**. **No witnessed two-backend END lock race or correction command success** is implied.
- [PR #107](https://github.com/yunusyosaf399/edusync_saas_school_app/pull/107) head `24312582fc85478a90a433a6d3706c4b5b3ff221`, **draft/open**, stacked on #106, adds *only* `effect38_01_db01_roll_lineage_nonself.sql.draft` CHECK prohibiting self `supersedes_id` and self `origin_allocation_id`. Its final diff has **no new correction RPC, new test, audit implementation or unique-supersession index**. Three current-head workflows passed, D1 runtime again **3,166** business assertions. The attempted unique index was removed after fixed index-inventory CI check failed; catalog/index gate is still an open technical decision.
- **No relevant owner approval, activation, migration or integration-ready state was found.** Green CI for these prerequisites is **not** evidence of RC/RP product sign-off.

## 2. Completed independent RC recommendation review — every row awaits signature

The recommended package below deliberately implements the existing conservative, append-only design rather than authorizing general edits to historical roll numbers. See [full decision packet](db01_rc01_rc08_owner_decision_packet_20261019.md) for alternatives and source-grounded tradeoffs.

| Decision | Recommended exact product choice for owner's APPROVE/REVISE/REJECT | Approvals and technical readiness |
|---|---|---|
| **RC-01 — immutable source identity** | Require Student UUID + positive expected Student `row_version`, exact current ACTIVE PRIMARY Enrollment UUID, Section and `effective_from`, exact open latest Roll UUID/old bigint/start/policy. Server derives School/mode/actor and rechecks after locks. Wrong/stale source **denies**. | **PENDING owner**; applicable existing Enrollment identities reviewed, no correction handler exists. |
| **RC-02 — value and namespace** | Verified authorized staff proposes bigint ≥ applicable policy `start_value`; one School-wide persistent historical owner per numeric across all policy revisions/superseded rows; academic collision is exact revision + Class Offering + overlapping intervals (not unconditional lifetime hold). Reserve manual high-water atomically, reject overflow, retain same-Student latest-head carry-forward. | **PENDING owner** and **DB-02 RP-03**; #106 fixes auto candidate/guard mismatch in its draft branch, not yet integrated. |
| **RC-03 — trusted date** | First release uses **server-controlled apply business date** only, exclusive DATE boundaries and source start strictly earlier than correction date; no backdating, future scheduling or second same-day correction; source Roll's policy must still cover apply date or reject/INVALIDATE without retagging. **Owner must additionally select date policy T-A or T-B below.** | **PENDING owner**, **DB-02 RP-02/03**, and synchronized School/server date integration. |
| **RC-04 — exact historical lineage** | Close the source Roll once without changing its ID/numeric/start; append a new UUID with `supersedes_id=source.id`, same Student/Enrollment/policy, inherit source's *distinct* existing persistent `origin_allocation_id` (including NULL); later MOVE carries forward latest valid corrected Roll as new Enrollment's origin, not as a supersession. | **PENDING owner** and RP-03; #107 only forbids self-links, **does not** prove one successor per predecessor or source authorization. |
| **RC-05 — collision/no-op** | Reject unchanged numeric, previously owned School persistent value held by *another* Student, active academic namespace interval collision, and impossible high-water. No cascade renumber or recycled superseded School persistent roll. All checks under shared allocator/School locks. | **PENDING owner** / RP-03; #106 helps auto allocator selection, but does not implement authenticated manual correction. |
| **RC-06 — P1 authorization** | Use existing Foundation one effective source-Campus DIRECT or APPROVAL route; live scoped staff `student.roll.correct`, independent other-**Person** `student.roll.approve` plus configured role/step/scope, review without mutation; explicit APPLY rechecks original requester and all reviewers; typed DIRECT, SUBMIT, REVIEW, APPLY and participant READ RPCs per existing DB-01 API gate. | **PENDING owner**; signer must also approve exact APPLY actors and historical checked-read participants. No correction RPC presently exists. |
| **RC-07 — receipt/event/privacy** | Stable canonical typed request hash with **no volatile apply date**; fixed candidate result kind `D1_STUDENT_ROLL_CORRECT`, `result_ref` = new Roll UUID, strict immutable 12-key predecessor/successor summary (14-key reviewed APPLY), authorized receipt-to-domain and approved-payload binding, one minimized audit and one selected `enrollment.roll_corrected` success outbox. Never broadly expose old/new numbers, free-text reason or raw request. | **PENDING owner** for literal result/event and payload allowlist, restricted reason normalization, historical disclosure and evidence uniqueness. |
| **RC-08 — competing operations and replay** | Accept only current open latest PRIMARY Roll; canonical School→policy→allocator→Student→ancestry→Roll locking with fresh rechecks. AUTHORIZED APPROVED APPLY that became stale → `INVALIDATED` + rejected receipt/no Roll effect; unauthorized caller cannot invalidate someone else's request; unexpected SQL error rolls back. Successful original result replays after later CORRECT/MOVE/END from retained pair, **subject to current authorization**. | **PENDING owner**, DB-02 RP-07, and integration MOVE source+destination prelock; actual correction races not run. |

**All eight remain PENDING.** No user instruction other than an explicit itemized approval of these terms, or an approved repository decision containing them, will be recorded as owner authorization.

## 3. Five necessary subordinate product choices (do not hide inside general RC signoff)

**D1 — Business day T-A versus T-B:** Two coherent options:
- **T-A (least invasive release):** trusted UTC-pinned database `CURRENT_DATE` for policy replacement, placement, MOVE/END and correction, with documented midnight UTC behavior for Schools elsewhere. Must prove executor/session TZ cannot be manipulated by callers. Most compatible with DB-02 RP-02 existing `CURRENT_DATE` proposal, but **may differ from actual School-local day**.
- **T-B (stronger School UX):** derive one server-trusted **School-local** date from verified School timezone; DB-02/integration must make policy replacement, placement, MOVE/END and correction compare exactly the **same** date consistently. **DB-01 recommends T-B only if this cross-domain synchrony is explicitly accepted.** Otherwise choose T-A deliberately. No hybrid policy/correction date implementation.
- Under either DATE option, proposed first release **rejects a second distinct correction on the same business day**. Existing successful same-key idempotent replay remains permitted without a new correction. Three-correction test chain requires real distinct days or a separately signed trusted disposable local clock seam.

**D2 — Academic historic reuse:** Recommend existing interval-based `(revision,Class Offering)` ownership with no overlapping cross-Student allocation; *do not promise* permanent AC reservation. If owner wants permanent AC ownership, integration must revise guard, allocator and history/reentry behavior.

**D3 — APPLY/READ actor and disclosure:** Recommend only verified original requester or final configured approver may perform APPLY when independently eligible, requester and reviewers still authorized; checked request readers may be actual requester/open assigned reviewer/decided reviewer/final approver **with live exact source/Student scope**. Historical numeric replay after MOVE/END should require a distinct approved historical disclosure predicate that works for an ended Enrollment but **does not automatically empower former-Campus staff**. The existing `student.roll_history.view` permission may serve as an additional gating permission if owner selects it. Keep correction free-text reason out of broad reads.

**D4 — Evidence and privacy literals:** Request owner sign-off on `D1_STUDENT_ROLL_CORRECT` and selected `enrollment.roll_corrected` event, the 12/14-key result schemas, event aggregate reference/payload allowlist, stable caller-intent canonicalization, and whether reason is hashed exact-as-stored or normalized consistently. No success event is emitted without a frozen event contract.

**D5 — Test clock:** Default is authenticated successful corrections on separate actual server business days in a dedicated disposable local integration DB. A deterministic synthetic `clock` is an alternative **only if** independent integration/security owner approves a harness-only nonproduction seam. Do not fabricate successful three-day correction by privileged row rewriting.

**Owner instruction to resolve all five:** explicitly select T-A **or** T-B; retain or change interval-only AC reuse; select exact APPLY/view participants and numeric disclosure predicate; approve or alter result/event literals and private reason rule; select real multi-day test or authorized local clock seam. The preceding recommendations are not a recorded selection.

## 4. DB-02 RP dependency sign-off — separate owner is required

| RP item | Existing DB-02 recommendation, explicitly **NOT APPROVED** | Exact effect on DB-01 |
|---|---|---|
| **RP-02:** source policy cutovers | Current trusted business date; contiguous replacement; no zero-length/scheduled/backdated changes; reject incompatible future commitments. | Must match RC-03's date/timezone. If source policy already expired, DB-01 correction fails rather than retags it to r2. |
| **RP-03:** historical number and handoff | Cross-revision, cross-supersession School permanent persistent ownership; same-Student current head carry; new revision floor and academic pool provisioning. | Makes RC-02/04/05 ownership/counter/reentry coherent. #106 improves automatic allocator, but its CI does not approve RP-03 product decisions. |
| **RP-07:** locking/replay | Foundation SHARED auth and receipt before School, ordered School→policy→allocator→Student→history, refreshed authority and exact-head policy after waits. | Needed for correction vs REPLACE, auto issuance, MOVE/END and grant revocation races. Two-backend proof still absent. |
| **RP-01, RP-04/05, RP-06** | DB-02 recommends INIT+REPLACE/defer END, School-wide ALL and NULL-Campus P1 approval, distinct Person-reviewed workflow; policy-change result/event literal still unselected. | Not to be decided in DB-01; correction P1 uses its actual source Enrollment Campus and separate event vocabulary. Any active-policy gap blocks usable correction. |

**No DB-02 design file is owned or modified by DB-01.** DB-02 must record its own explicit RP-01…RP-07 approvals or revisions, including its RP-06 event/result literal selection, before DB-01 declares policy-change/race interoperability accepted.

## 5. Technical readiness and integration ownership after #106/#107

| Component | Verified progress | Remaining exact blocker / responsible owner |
|---|---|---|
| Automatic persistent allocator respects retained cross-Student history | **PR #106 D1 runtime PASS**, #75 12/12 in rollback-only fixture | Pending PR integration, policy reentry/high-water/overflow and genuine allocator races; D1 Enrollment integration + DB-02 RP-03 |
| END locks stored source policy/allocator before Student | **PR #106 D1 runtime PASS**, #76 30/30 | Genuine two-session END vs allocator/permission races, final lock-order acceptance; Enrollment integration |
| Correction self-reference prevention | **PR #107 D1 runtime PASS**, SQL-only CHECK; draft stacked on #106 | Distinct successor uniqueness/provenance/concurrency still need independent safe catalog/integration review; CHECK does not implement roll correction |
| MOVE source and destination policy/allocator union | **NOT VERIFIED AS FIXED** | Existing MOVE prelocks destination; integration owner must supply ordered source+destination union before Student, with two-session test |
| Correction DIRECT, independent APPROVAL, participant READ, receipt application guard | **NO IMPLEMENTATION** in #106/#107 | Await signed RC-01…RC-08 and compatible RP/clock/race contracts; only DB-01-owned new SQL after approval |
| Protected correction acceptance | **NO CORRECTION POSITIVE SUITES** | Authenticated DIRECT/P1 submit/review/apply/replay, two-server-date lineage, live revocation and SQLSTATE/outbox/ACL proof |
| Actual deployment / operation enablement | **DISABLED / NOT AUTHORIZED** | Independently reviewed exact-head CI, security signoff, activation owner and separate migration/deployment authority |

**Current PR statuses at this review:** #100, #101, #106, #107 each **open, draft, unmerged**. No new DB-01 SQL changes in this document task. No hosted Supabase action.

## 6. Owner-signature template and exact effect of approval

A complete **DB-01** owner signature can explicitly state:

> `I approve RC-01 through RC-08 exactly as recommended in docs/database/db01_rc_approval_review_pr106_pr107_20261019.md, including T-A [or T-B], the stated AC reuse option, APPLY/read participants and numeric-history disclosure, evidence/result/event literal and reason normalization, and real multi-day testing [or separately signed trusted clock]. I understand this is product-contract approval, not operation activation, migration deployment or merge approval.`

**Do not use the text above as an actual approval.** If owner changes any row, record the full change and check dependent APIs/test predicates before implementation. DB-02 owner must separately record RP decisions; DB-01 cannot approve on its behalf.

**Decision disposition at end of this review:** **Owner recommendation COMPLETE; formal DB-01 RC approval PENDING; external RP approvals PENDING; SQL implementation/activation remains blocked.**

**Next self-managed task:** after owner signoff, write a DB-01-only *approved* decision freeze/ADR with exact source, then coordinate narrow new typed SQL functionality and independently accepted runtime tests. While approval remains pending, conduct the promised read-only preimplementation RPC/ACL/receipt provenance security audit and document any engineering gaps, without touching Codex's SQL implementation branch.
