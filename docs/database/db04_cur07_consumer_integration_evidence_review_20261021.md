# DB-04 — CUR-07 Consumer Integration Evidence and Signoff Review

> **2026-10-21 P01A/P02A PRODUCT APPROVED:** [Exact accepted whole-set T7 generation and one effective head](db04_cur08_p01a_p02a_approved_selection_set_head_20261021.md) are approved provider semantics. Consumers' freeze points and data minimization remain **CUR-07 A1–G1 unapproved** and require independent domain signatures. Preserve the original T7 source at consumer capture, not just a current/latest Revision resolver.

> **2026-10-21 CUR-01 UPDATE:** The owner explicitly [approved first effective date and mid-year cutover T1+M1+S1+F1+H1](db04_cur01_approved_effective_dates_midyear_cutover_20261021.md). Earlier CUR-01 timing-pending notes below are superseded. CUR-07 A1–G1 and downstream consumer/permission signoffs **remain unapproved**; CUR-01 approval must not be read as authorization to freeze Exams/Learning/Timetable evidence contracts.

**2026-10-21 | DOCUMENTATION-ONLY | CUR-07 NOT APPROVED | PR #103**

This independent handoff review supplements [CUR-07 A1–G1 candidate gate](db04_cur07_exams_learning_timetable_eligibility_snapshot_owner_gate_20261021.md). It does **not** approve CUR-07, freeze physical SQL, represent Exams/Learning/Timetable consent, record a runtime PASS, install permissions, or authorize hosted deployment.

## Decision baseline and scope

- **Approved:** CUR-01 rejects overlapping School-wide/Campus applicability without implicit precedence and explicitly approves T1/M1/S1/F1/H1 effective-date/cutover safeguards; CUR-02 derived COMPULSORY and explicitly accepted OPTIONAL/ELECTIVE; CUR-03 atomic group election, BF-1 T7 finalized set and T8 members, B-M1 strict maximum; CUR-04 staff-only accepted write and scoped checked SELF/FAMILY reads; CUR-05 P0/P1/P2 and independent review; CUR-06 no transfer carry-forward, archived new-use denial, immutable old published consumer basis and stale APPLY rejection.
- **Unapproved:** CUR-07 A1–G1; CUR-08 eight-entity physical fields, SQL, registrations and test plan approval.
- **Authority boundary:** DB-04 decides effective Curriculum/Subject/selection eligibility; D1 owns accepted Enrollment and Subject/Offering lifecycle; Exams owns assessment/result publication and revisions; Learning owns assignment/audience/submission history; Timetable owns schedules and collisions; Foundation owns authentication, permissions, scoped executors, receipts, approval integration and auditing. A proposed DB-04 read is never a grant.

## Required owner decision and independent signatures

| Gate | Recommended product choice (not approved) | Required independent acceptance evidence | Open clarification / stop condition |
|---|---|---|---|
| A1 — fixed source resolver | fixed-purpose typed Student+Enrollment+Section Subject Offering resolver, exact `valid_at` and `observed_at`, revision/digest and BF-1 references | D1 confirms exact IDs/current vs historical semantics; Foundation signs executor authorization; Exams/Learning sign compatible source identity | No unbounded generic join, mutable `latest revision` or implicit School-wide fallback |
| B1 — Exams | immutable eligibility basis captured before publication and preserved on publication; mismatch revalidated/routed to Exams workflow | Exams owner specifies **exact first capture checkpoint** (e.g. admission to assessment or marks lock), publication recheck, and revision behavior | B1 does not authorize DB-04 to correct grades, marks or published results |
| C1 — Learning | frozen recipient/subject basis at assignment publication with retained submission/feedback history | Learning owner signs cohort cardinality, historical read, late submission, after-MOVE access and opt-in backfill policy | Do not infer backfill or retrospective recipient deletion |
| D1 — Timetable | Section Subject Offering availability only, no Student elective roster | Timetable owner signs Section date/revision feed and published schedule source, plus independent teacher/room/period conflict validation | Per-Student timetable remains separate new product/security decision |
| E1 — observation | source validity date + exact observed capture, immutable digest, original T7/T8 and D1 IDs where applicable | Each consumer signs minimal persisted field set and preservation/revision retention semantics | Historical reconstruction from today's Enrollment or latest Revision is forbidden |
| F1 — disclosure | distinct purpose-bound Exam, Learning and Timetable grants / executors | Foundation security signs fixed operation codes, School/Campus/Section scope, no `purpose` parameter and denial shape | Caller-chosen consumer purpose, broad table SELECT and arbitrary peer Student IDs rejected |
| G1 — fail closed | deny missing/ambiguous/archived-new-use/stale/revoked eligibility for **new** protected actions | All consumers sign safe error mappings plus historical access to already-published basis | Do not invalidate previously published facts just because a current check now fails |

**Provenance:** The choices above restate the existing CUR-07 proposal; the signature checklist and test mapping below are DB-04 engineering recommendations, not approved product policy or proof of external consultation.

## Exact source-identity acceptance matrix

| Situation | New protected Exam/Learning Student-specific action (candidate) | Published historical fact | Privacy boundary |
|---|---|---|---|
| COMPULSORY effective and valid | derive Rule+Section entitlement; **no synthetic T8 row** | retain consumed revision/digest/Section basis | return minimum allowed data |
| OPTIONAL/ELECTIVE unfinalized | cannot manufacture an accepted T7/T8 member; deny elective eligibility | keep old published captured fact unchanged | do not reveal peer choices |
| BF-1 finalized-empty | valid finalized-set evidence; individual unchosen elective is not eligible | keep captured empty state if actually used | do not equate empty with absent T7 |
| Source Enrollment MOVE/END | destination requires independently valid new Enrollment selection; never carry T7/T8 | source-Enrollment snapshots remain as observed | no broad cross-Enrollment lookup |
| Archived Subject | deny **new use**; retain permitted historical evidence | archived Subject source remains legible to authorized historical consumer | no public historical enumeration |
| P2 correction after Exam publish | prospective resolver reflects reviewed corrected source without rewriting old publication | only Exams' own approved revision can restate Exam published facts | correction detail restricted |
| Revision overlap or stale hash | fail closed; no latest/default fallback | previously captured basis remains immutable | non-enumerating safe denial |
| Student/FAMILY/teacher attempts consumer endpoint | no implicit consumer executor permission | history requires independent explicit checked grant | assignment/family context alone gives no resolver escalation |
| Section timetable query | may obtain Section-level published availability | preserve schedule publication version | **no Student ID, T7 or T8 in Timetable payload** |

## Proposed acceptance allocation (NOT EXECUTED)

Reuse the parent gate's **SN-01–SN-16** and **SNR-01–SNR-06** catalogue rather than inventing new passing results. Before a test can be marked PASS, the integration owner must attach: frozen tested commit and released dependency SHA; exact expected-actor grants and negative actor; original + corrected source identity; consumer-owned persisted snapshot; database transaction observations for opposing-session races; observed audit/receipt and denial evidence.

The two-connection race harness must test both arrival orders for: D1 MOVE/END versus Student eligibility; archive versus new action; revision publication versus consumer capture; P2 correction versus existing published snapshot; source permission revocation versus resolver request; and selection change versus Learning/Exams capture. Record `pg_stat_activity` and `pg_blocking_pids()` if lock behavior is asserted, then read committed data using a third independent connection. Do not claim such lock waits or safe publication outcomes without an executed test.

## Signoff ledger (none received)

| Signer | Concrete request | Current state |
|---|---|---|
| School product owner | Explicit CUR-07 A1+B1+C1+D1+E1+F1+G1 choice (or revisions) | **PENDING** |
| Exams domain | B1 exact checkpoint, eligibility/marks boundary, source snapshot fields and reviewed result-correction behavior | **PENDING** |
| Learning domain | C1 publish-time cohort, access after MOVE, late submissions, backfill and retained feedback semantics | **PENDING** |
| Timetable domain | D1 Section-only feed, schedule publication basis and independent conflict checks | **PENDING** |
| Foundation/security | A1/F1/G1 least privilege, fixed executors, grant scopes, redaction, audit and reviewer independence | **PENDING** |
| D1 Student/Academic owners | exact released Enrollment/Subject/Offering FK and School-first lock compatibility, real concurrency evidence | **PENDING** |
| DB-04 physical/release reviewer | CUR-08 eight-entity T7/T8 FK shape, bitemporal reconstruction and separate post-D1 migration | **PENDING** |

## Freeze rule and recommended next task

**DO NOT IMPLEMENT:** no DB-04 SQL, global permission catalogue, action registration, D1 Migration 10 patch, upstream-owner files, workflow/CI changes or hosted Supabase writes based on this review. Keep PR #103 a draft. After explicit CUR-07 product approval, collect the independent consumer signatures and verify the now-approved CUR-01 cutover constraints before any CUR-08 physical/installation freeze. If signatures disagree with a candidate field or freeze checkpoint, document that incompatibility and request a narrow owner decision rather than implementing an inferred behavior.

**Next DB-04 task:** prepare CUR-08 eight-entity physical freeze checklist and the still-pending CUR-01 timing decision alternatives, without implementing SQL or changing other domains.
