# DB-04 — CUR-07 Purpose-Bound Consumer Capture, Privacy and Denial Handoff

**2026-10-22 | CANDIDATE CONTRACT / NO CUR-07 APPROVAL OR CONSUMER SIGNATURE | DOCUMENTATION ONLY**

This technical acceptance handoff refines the [CUR-07 option gate](db04_cur07_exams_learning_timetable_eligibility_snapshot_owner_gate_20261021.md) without replacing its proposed A1–G1 choices, [SN-01–SN-16 and SNR-01–SNR-06](db04_cur07_exams_learning_timetable_eligibility_snapshot_owner_gate_20261021.md#6-acceptance-matrix-and-independent-signatures-not-executed), or the existing [consumer integration review](db04_cur07_consumer_integration_evidence_review_20261021.md). The owner-approved [CUR-08 P01A/P02A](db04_cur08_p01a_p02a_approved_selection_set_head_20261021.md) informs source identity but is **not** CUR-07 approval.

## 1. Source of truth and consumer-owned facts

**DB-04 owns**: published Curriculum Revision/Applicability, Rule/category and Section Subject Offering validity; independently accepted, complete whole-Revision T7 selection-set generations and exact linked T8 selected members for OPTIONAL/ELECTIVE; source validity and recorded correction provenance. **D1 owns**: Student, accepted PRIMARY Enrollment, School/Class/Campus/Academic Year ancestry, Section Offering and Subject archival lifecycle.

**Consumers own**: Exam marks, components, published result and reviewed result correction (**Exams**); assignment, original audience, submissions and teacher feedback (**Learning**); schedule/teacher/room/period conflicts and published timetable (**Timetable**). DB-04 does not modify any of those facts or accept unbounded cross-domain reads. No direct consumer table SELECT, arbitrary `purpose` argument, teacher-role inference or raw T7/T8 client DML.

The Master Specification §19 supports varying subject choices; §23 requires timetable data/conflict checks; §24 requires applicable assignment visibility and submissions/feedback; §§26–29 require configurable assessment and reviewed publish→lock of results. **It does not choose this proposed eligibility resolver's SQL, precise Exam pre-publication capture stage, Learning later-backfill policy or Student-level timetable expansion.** Such decisions stay **open**.

## 2. Candidate least-privilege interface envelope (A1/E1/F1 proposals only)

| Envelope aspect | Candidate provider or consumer condition | Must not be assumed/returned |
|---|---|---|
| Trust & purpose | Verified **server-derived** current service principal and a **fixed registered operation** per Exams, Learning or Timetable executor. Verify full School/Campus/Section and resource-specific scope. | No caller-chosen `purpose`, no client-side role name acting as permission, no service-role key embedded in app. |
| Student-specific identity (Exams/Learning only) | Exact Student ID + D1 accepted PRIMARY Enrollment ID + real Section Offering, Section Subject Offering, School/Year/Class ancestry, Subject Rule and `valid_at`. Server verifies the relationship; request may carry an expected source version/digest for revalidation. | No querying peers by display name, arbitrary Student list or old Enrollment as if current; no invented D1 Enrollment row version. |
| Published source | Original Revision ID, Applicability ID, Rule ID/obligation, Section offering, applicable bounded validity and publication content digest at source observation. | No selection of newest Revision, Campus override, hidden School-wide fallback or dynamic reconstruction from today's row. |
| Accepted optional/elective proof | At applicable source `valid_at` and captured `observed_at`, identify exact P01A whole-set **T7 ID**, and T8 selected member ID for the queried OPTIONAL/ELECTIVE Subject. `FINALIZED_EMPTY` and `NOT_SUBMITTED` are distinct and do not grant an unchosen elective. | No synthetic T8 member for COMPULSORY; no inferred submission from zero rows, cross-Enrollment carry-forward or self-invented head tie-break. |
| Historical capture | Consumer preserves `valid_at`, `observed_at`, exact accepted source identities, immutable digest/decision and its own controlled publication or revision linkage, choosing only minimally required fields under owner signoff. | No assumed PostgreSQL transaction timestamp as perfect commit ordering; no broad receipt payload, reviewer identity, Family membership or marks in DB-04 resolver output. |
| Error | Non-enumerating deny for **new** sensitive use when grant missing, source ambiguous/stale, wrong Year/Section/Enrollment, archived new use or absent accepted OPTIONAL/ELECTIVE. | Denial must not reveal whether an unrelated Student or private election exists. |
| Historical access | Consumer's own separately checked, bounded historical read path preserves captured publication basis, including after a later P2 DB-04 correction. | Current eligibility denial is **not** automatic deletion of already published consumer facts; old snapshots are not universally accessible. |

**Physical storage warning:** The fields above are *candidate minimal evidence categories*. Neither precise SQL column names and nullability nor a shared JSON envelope, retention duration, response code set or original capture timestamp have been approved for installation.

## 3. Consumer-by-consumer capture and signer matrix

| Domain | Candidate event that freezes source | Captured basis owned by consumer | Follow-on action needing explicit local policy | Responsible approval |
|---|---|---|---|---|
| **Exams (B1 candidate)** | An **Exams-chosen and signed** assessment/marks-lock event **before** result publication; optional publish-time fresh authorization/digest check. | Exact subject eligibility decision/source, T7/T8 only for chosen OPTIONAL/ELECTIVE, original Revision+Applicability/digest, D1 enrollment, `valid_at`, `observed_at`, controlled Exam assessment/marks record linkage. | Stale source between mark capture and publish; already published grade/result revision; Student MOVE/archive after publication. A DB-04 P2 correction never revises Exam marks itself. | **Exams owner — NOT SIGNED** |
| **Learning (C1 candidate)** | **Assignment publication**, with exact recipient cohort and source identity for each actually targeted Student. | Assignment/recipient, original Student/Enrollment/Subject eligibility and captured T7/T8 where relevant, original date/digest/source, existing submissions/feedback. | Late submission after MOVE/END, current access to old feedback, backfill to future-selected pupils, new teacher permissions. **No automatic backfill is authorized.** | **Learning owner — NOT SIGNED** |
| **Timetable (D1 candidate)** | **Published timetable** captures effective **Section-level** offering/revision/digest and its schedule version. | Section Offering, Section Subject Offering, bounded date, revision/digest, published timetable source identity; Timetable itself checks room/teacher/Section collisions. | Individual-elective timetable requires new privacy/permission policy and is **out of scope** of D1 candidate. | **Timetable owner — NOT SIGNED** |
| **Security/registrar (F1/G1)** | Registration/authorization at invocation and fresh-check on restricted historical reads. | Fixed operation and resource scope, minimal safe output/audit reference and redacted error classification. | Revocation between selection resolution and consumer commit, replay, separate Student SELF/FAMILY permissions. | **Foundation owner — NOT SIGNED** |
| **Source runtime (A1/E1)** | Deterministic serialized source response anchored to exact D1 and DB-04 IDs and business/observation points. | No ambiguous effective head, consistent whole-set T7/T8 and immutable published Revision as-observed evidence. | Actual D1 School-first END/MOVE FK/trigger lock compatibility, canonical head exclusion under concurrency and populated upgrade proof. | **D1 + DB-04 physical owners — NOT SIGNED** |

## 4. Planned negative tests and real races — not executed

**Reuse existing IDs rather than count duplicate passing tests.**

- **SN-01–03:** COMPULSORY derived with no T8; OPTIONAL unchosen denied; valid finalized-empty not mistaken for missing T7.
- **SN-04–05, 11–12:** published Exam retains original source after MOVE/ARCHIVE/P2 correction; as-observed differs from later as-known; Exam Controller controls result revision.
- **SN-06–07:** Learning publication cohort preserved; no silent retrospective assignment recipient changes; old submissions kept under authorized historic reads.
- **SN-08, 15:** Timetable Section-only visibility; publication source rechecked against changed Revision/Section Offering, no Student IDs/T7/T8.
- **SN-09–10, 13–14:** teacher/FAMILY/student cannot call unrelated private consumer executor; no overlap fallback; wrong scope/year/Enrollment non-enumerating deny.
- **SN-16:** duplicate consumer capture attempt is deterministic or explicitly rejects mismatched source version; no silent replacement of original basis.
- **SNR-01–06:** correction vs Exam capture, D1 MOVE vs eligibility, Revision replace vs Learning publication, Section close vs Timetable publication, permission revocation vs resolver, and competing old/new BF-1 head vs Exam capture. Use **two distinct PostgreSQL connections**, both arrival orders and third-session durable post-commit verification; record observed `pg_stat_activity` and `pg_blocking_pids()` if claiming waits.

**Exact evidence required to mark PASS later:** pinned DB-04/D1/Foundation SQL source/version, controlled principal/grants, effective/observed source ID and digest, consumer-owned frozen record, receipt/audit/outbox and safe denial outcomes, race barriers/backend PIDs/blocked waits where applicable, both winner orders, and independent signoff. **No tests, RPCs, concurrency experiments, hosted access or signatures performed here.**

## 5. Decision ledger and release stop conditions

| Item | Current status |
|---|---|
| CUR-01–06 and CUR-08 P01A/P02A product rules | **APPROVED**; no corresponding DB-04 runtime acceptance claimed |
| CUR-07 A1+B1+C1+D1+E1+F1+G1 | **PENDING explicit product owner response**; [short owner brief](db04_cur07_owner_decision_brief_20261022.md) |
| Exact first Exams eligibility checkpoint/publish reconciliation | **PENDING Exams owner** |
| Learning after-MOVE, late submission, feedback and backfill | **PENDING Learning owner** |
| Timetable Section-only published source fields | **PENDING Timetable owner** |
| Registered service permission, scope, revocation and disclosure ceiling | **PENDING Foundation/security owner** |
| D1 released FK keys/School-first implicit-lock proof | **PENDING D1 integration owner** |
| CUR-08 P03–P08 complete physical/installer/readiness and populated upgrade | **PENDING specialist signoff** |
| DB-04 SQL/migration/runtime deployment | **NOT AUTHORIZED / NOT EXECUTED** |

**Stop at documentation** until owner explicitly selects CUR-07 and the independent domain signers verify their frozen-source contracts. Maintain PR #103 as a design draft. No Foundation/D1/DB-01/02/03/Exams/Learning/Timetable edits, global registrars/CI modifications, SQL execution, hosted Supabase writes or PR merge.
