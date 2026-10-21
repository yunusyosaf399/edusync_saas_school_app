# DB-04 — CUR-06 Enrollment Transfers, Subject Archiving, Curriculum Replacement and Historical Selection Owner Gate

**Status: CUR-06 PRODUCT DECISION REQUIRED — NOT APPROVED.** Prepared 2026-10-21 on draft DB-04 PR #103. This is a read-only design/acceptance package. No new SQL, permission/operation registrations, Foundation/D1/Exams/Learning/Timetable changes, hosted deployment or executable tests are authorized. The owner approved [CUR-05 workflow classes and independent review](db04_cur05_approved_workflow_reviewer_policy_20261021.md); that approval **does not authorize the business circumstances** under which a Curriculum or elective may be transferred, grandfathered, replaced or corrected.

## 1. Existing authority and hard invariants

- **D1 authoritative placement:** D1-07 freezes at most one normal accepted effective PRIMARY Enrollment. A Section/Campus/Class/Year move **ends the old enrollment and creates a new one**. `app_private.enrollments` remains D1-owned (and has **no `row_version`**). DB-04 Student choice-set T7 and selected-member T8 histories bind **Student + exact accepted Enrollment ID + revision/applicability/Section offering + effective interval**, not display labels or a mutable “current section.”
- **D1 academic/Subject authority:** D1's `academic_classes`, `subjects` (stable school Subject, active/archive lifecycle), `class_offerings` and `section_offerings` own the effective ancestry. DB-04 cannot archive a D1 Subject, close a D1 Section, promote a Student, allocate a roll or override another domain's state machine.
- **CUR-01 owner approval:** a published School-wide and matching Campus-specific Curriculum **cannot overlap** for the same Class Offering/date; no implicit precedence. Initial effective-date rule and mid-year cutover permissibility/conditions **remain undecided**, and CUR-06 must not invent either.
- **CUR-02 owner approval:** COMPULSORY obligation derived, OPTIONAL independently accepted and ELECTIVE exactly group-governed, with separate Practical/Extra-curricular/Custom classification. Previously accepted choice identity must not be overwritten by new-year catalog labels.
- **CUR-03 owner approval:** one immutable revision-specific group per ELECTIVE Rule, atomic final election set with **BF-1 Student selection-set history (including finalized-empty)** and strict **B-M1 max ≤ distinct Section actually offered members** at every relevant effective segment. No prerequisite, elective seat allocator or automatic deadlines.
- **CUR-04 owner approval:** only staff with a live separate grant can accept or change choices; Student SELF/FAMILY CHILD may receive bounded current checked reads **only with their own registered live permissions**; teacher assignment or Family relationship grants no mutation.
- **CUR-05 owner approval:** P0 protected draft; P1 configured DIRECT/REVIEWED selection/Section availability; P2 independent reviewed Curriculum PUBLISH/REPLACE/RETIRE and historical corrections; same-Person requester cannot review; APPROVED is not APPLY. A P2-approved attempt still fails if business-policy CUR-01/CUR-06 denies it.
- **Historical consumers:** published Exams cannot silently change after a Student moves, a Subject is archived, a choice-set is corrected, or a Curriculum revision is superseded. Exams/Learning/Timetable consumer-owned frozen `valid_at` and `observed_at` evidence and read interfaces are **CUR-07, not yet approved**.

## 2. CUR-06 owner choices — six distinct proposed decisions

| Decision | Recommended v1 policy | Alternative requiring separate owner text | Implementation impact |
|---|---|---|---|
| **CUR-06-A1: Enrollment MOVE and Year progression** | **No automatic copy or reparent** of any old Student's BF-1 selection set or elected member rows when D1 ends/moves Enrollment to a new Section/Campus/Class/Year. Preserve old sets as historic evidence on original Enrollment. A newly eligible destination needs a **new, independently accepted validated set**, including FINALIZED_EMPTY where permitted. COMPULSORY destination obligation derives anew. | **A2:** explicitly mapped elective carry-forward subject to typed School policy, consent/protected staff APPLY, new destination BF-1 set and an original-to-successor link. Never reuse the same enrollment_id. | A2 requires documented lineage and post-move atomics, cross-class eligibility and possibly added mapping metadata; D1 MOVE itself must not acquire DB-04 locks out of order. |
| **CUR-06-B1: D1 Subject ARCHIVE** | **Preserve all historical Subject, published Rule, choice-set/member and old consumer snapshots**, but deny **new publication/Section offering/new Student election** using an archived D1 Subject. An already accepted historical selection is not physically erased or rewritten. If an archived Subject's future-effective accepted choices cannot remain valid, reject/hold future use until a separately reviewed transition resolves them. | **B2:** grandfather existing Students through defined `grandfather_until`, with documented target cohorts, revision/time range and no new students. | B2 requires immutable per-revision grandfather cohort/evidence and Exams/Learning signoff; cannot be faked by simply allowing archived Subjects through generic APIs. |
| **CUR-06-C1: Section Offering closes/changes** | A new close/retire/change **fails closed** when it would orphan current or future accepted Student choice sets, make Section Subject eligibility false, or make strict B-M1 `max > actual available elective members` for any affected date segment. Require a separately accepted plan before a permitted close, preserve old effective/recorded history. | **C2:** administration may stage an explicit approved transition mapping and Student acceptance set changes, then close old offering as one serialized reviewed plan. | C2 needs stable set-head impact calculation and a reviewed multi-Student transition protocol without publication acquiring Student locks late. |
| **CUR-06-D1: revised Curriculum publication/replacement** | **No silent migration or auto-reclassification** of existing accepted choice sets to a new immutable Revision/Group; preserve old published Rule and original choice-set digest. Replacement **rejects or remains blocked** when active or future Student sets are stranded. Mid-year replacement is **not generally enabled** until CUR-01 effective-date policy is separately approved. | **D2:** explicit one-way cutover with per-Student independently accepted new sets and safe old/new applicability transition, only after CUR-01 timing and CUR-05 P2 signoff. | D2 requires reviewed cutover plan and School-first publication fence; keep both old and successor version histories and no overlapping School-wide/Campus applicability. |
| **CUR-06-E1: retrospective correction and downstream historical truth** | P2 correction retains old accepted source and records a typed superseding BF-1 set/member version and reason/evidence, with `valid_at`/`observed_at` both retained. **Do not change a published Exam's original observed source snapshot**; request downstream reassessment only by separately authorized Exam process. | **E2:** allow explicit Exam impact workflow initiated by a Curriculum correction with signed, typed cross-domain request, never automatic mark rewrite. | E2 requires signed Exams owner API, request identity, old/new evidence, school reviewer chain and consumer-owned re-publication authorization (CUR-07). |
| **CUR-06-F1: transfers and pending decisions** | Pending/unfinalized election submissions/reviews tied to an old Enrollment **cannot APPLY after its MOVE/END**; invalidate stale approved P1 request at APPLY, leave D1 placement intact. **NOT_SUBMITTED** is distinguished from **FINALIZED_EMPTY**; destination status is computed from destination's own BF-1 history. | **F2:** explicit transfer/restart of a pending intent into a new versioned request bound to the new Enrollment and revised digest, with School review; never auto-approve or reuse old receipt ID. | F2 requires typed request supersession, reviewer/scope/permission recheck and new idempotency receipt. |

**Owner choice format:** `Approve CUR-06 A1+B1+C1+D1+E1+F1` or select alternatives with precise amendment text. **No CUR-06 product decision is approved by the current message**: the owner said only “I approved” to the preceding *CUR-05* option set.

## 3. Business-valid versus as-observed truth

Use **half-open effective intervals** `[effective_from,effective_until)` within the exact D1 Academic Year (its `ends_on` is inclusive, thus `YearUpper=ends_on + 1 day`), accepted Enrollment and published Section Subject Offering. Do not resolve Year from the latest name, wall-clock “active Year,” or a Subject's shared label.

| Event | Authoritative record and safe projection | Immutable evidence retained |
|---|---|---|
| Student MOVE from Campus A Grade 9-A to Campus B Grade 9-A on a particular date | D1 old Enrollment ends at move boundary, new PRIMARY Enrollment starts; DB-04 old T7/T8 choice-set eligibility ends where old Enrollment ends | old Enrollment UUID, old Revision/Rule/Group/Section offering, accepted set members, receipt and captured Exam snapshot |
| New Academic Year with same Grade and Group code | D1 Year and Class Offering IDs change; separately published DB-04 applicability/revision; new Enrollment and newly accepted selections | prior Year and revision digests, old set/selection IDs, valid-at and observed-at |
| D1 Subject archived after previous Exam publication | Deny new use under candidate B1; old Subject ID and historic published Rule remain | previous Exam's exact original Subject/revision/selection IDs and observation |
| Section offering closes effective future date | Before accepting closure check *all* affected Section/date breakpoints; do not strand finalized Student sets or violate strict B-M1 | old availability declared upper, one-way closure date, receipt and prior snapshots |
| P2 correction accepted in October for an election effective in September | Current as-known read may show corrected accepted successor for September; previous published Exam retains its originally observed September source | original and successor set heads/recorded acceptance, exact old consumer `observed_at` |
| P2 Curriculum replacement proposed with two overlapping versions on same Class Offering/date | Reject under CUR-01, regardless of reviewer approval, unless scopes and effective intervals are made unambiguous by a separately authorized cutover | old revision/content digest and rejected request evidence; no partial publication |

A Student/FAMILY current read uses the *current* grant and exact target Enrollment; access to prior correction history is **staff-only separately granted** under CUR-04. Do not expose other Student selections or raw reviewer notes in Timetable/AI/notifications.

## 4. Lock and publication versus Enrollment MOVE/END conflict contract

**Current source-compatible (not runtime-verified DB-04) lock outline:** Foundation SHARED authorization/receipt fence → **School** → for *Student-scoped* choice changes Student→accepted D1 Enrollment→D1 academic/Subject ancestors→DB-04 applicability and T7/T8 set/member history. D1 MOVE/END sources use a School-first prefix then retained roll-policy/allocator pools before Student; DB-04 must not reverse that prefix. For *publication/Section availability*, School→sorted D1 academic/Subject path→DB-04 Revision/Applicability/Section offering, **never acquire Student late** after DB-04 publication locks.

A publication impact check may inspect accepted choice-set facts while holding a School serialization fence; **it does not itself prove** that Foundation review, D1 triggers, foreign keys or future concurrent workers share that fence. An operation that needs to mutate per-Student accepted choices requires a separate Student-scoped typed operation with its own lock prefix or a reviewed serialization protocol. D1 archived Subject write/revision apply and Student Enrollment MOVE/END races need **genuine opposing-backend observed waits** in an approved local install; no SQL/races are executed here.

## 5. CUR-06 test plan — designed, not run

| ID | Scenario | Required expected result if selected |
|---|---|---|
| `TR-01` | Student moves from Section A to Section B (same Class/Year), old `E-1` accepted choice exists | Old BF-1 set remains historic and cannot satisfy new Enrollment; A1 requires new independently accepted set |
| `TR-02` | Promotion to AY27; both Years use group code “SCI” | New Year does not reuse old Group UUID/revision/set even when display code matches |
| `TR-03` | Old Student had `FINALIZED_EMPTY`, then MOVEs | New Enrollment remains `NOT_SUBMITTED` unless separately finalized empty again; do not reuse old empty set |
| `TR-04` | Assigned teacher or FAMILY attempts carrying choices forward | No unauthorized mutation; Staff A1/CUR-04 live grant still needed |
| `TR-05` | Archive Subject after 2026 Exam snapshot and before 2027 publication | Preserve 2026 evidence; new 2027 Subject use denied if B1; no Exam rewrite |
| `TR-06` | Archive with future-effective old accepted selection | Do not delete; require separately approved transition, no silent grandfather rule |
| `TR-07` | Section B offers only one member but Group max=2 | B-M1 rejects publication/Section activation despite min=1 |
| `TR-08` | Section Subject Offering end at Nov 1 invalidates Student FINALIZE scheduled Nov 15 | Reject closing or scheduled election unless authorized transition resolves invalid interval |
| `TR-09` | New School-wide and Campus-specific applicability cover same Class Offering/day | Conflict denied regardless of old/new Revision timestamp |
| `TR-10` | P2 publication approved by different reviewer, but CUR-01 timing/cutover remains unresolved | No APPLY of an unapproved mid-year transition; REVIEW≠business exception |
| `TR-11` | P2 corrected accepted September choice in October after September Exam published | Old Exam retains original observed source; corrected head independently queryable only to authorized consumer |
| `TR-12` | Approved P1 Student choice request based on old Enrollment, then D1 MOVE before APPLY | Stale APPLY rejects; no new Enrollment source is invented, old receipt/history retained |
| `TR-13` | School staff with wrong Campus grant tries transfer election | Deny, do not reveal unauthorized Student existence or old Campus selections |
| `TR-14` | Deleted/closed published Revision or Subject would be referenced by archived BF-1 set | Reject destructive erasure; preserve referenced history |
| `TR-15` | Student not-yet-finalized in destination versus deliberately finalized zero Subjects | Use BF-1 T7 accepted fact, not presence/absence of T8 member rows; no fake finalization |
| `TR-16` | CUR-03 Group max=3 but Section only has 2 offered members after future offering close | B-M1 rejects future closure/activation; no default relax to max-as-cap |

**Concurrent two-backend tests required after future authorization:**
- **TRR-01:** D1 Enrollment MOVE vs approved FINALIZE old Enrollment, both arrival orders, School→Student and observed parent/FK waits; no destination reparent.
- **TRR-02:** D1 Enrollment END vs P1 APPLY finalization, both arrivals; stale D1 source invalidates APPLY.
- **TRR-03:** D1 Subject ARCHIVE vs revision/Section Subject Offering P2 or P1 APPLY, both arrivals; no archived Subject new use.
- **TRR-04:** Section availability close vs future-effective Student finalization, both arrivals; no stranded selected head or B-M1 max underavailability.
- **TRR-05:** Competing campus-specific vs School-wide publication with overlapping exact Class Offering/date; at most one accepted revision.
- **TRR-06:** P2 correction versus Exams consumer snapshot capture; immutable originally observed Exam basis and later as-known correction coexist.
- **TRR-07:** Revocation of requester/reviewer grant between APPROVED and APPLY while Enrollment is moving; current authority and target rechecked, no bypass.

**No executed test or green CI evidence is claimed.** Runtime requirements: 2 actual PostgreSQL connections, visible `pg_blocking_pids()`/`pg_stat_activity` lock wait, both commit orders, fresh third-connection post-commit DB-04 + D1 + Foundation receipt/outbox validation, and deny/rollback in all unauthorized or stale paths. Existing D1 own-local tests **do not prove DB-04 integration**.

## 6. Open decision boundaries and next step

**Owner-approved domains:** CUR-01 school-wide/Campus overlap/no precedence only; CUR-02 subject obligation/classification; CUR-03 group semantics+BF-1/B-M1; CUR-04 actor and checked-read product rules; CUR-05 P0/P1/P2 and independent reviewer/workflow.

**Still OPEN:** CUR-01 initial effective date, future/mid-year cutover; **CUR-06 A1+B1+C1+D1+E1+F1**, CUR-07 consumer snapshot/Exam correction interfaces, CUR-08 exact 8-table schema and registrar/operation registration. No School default, exception, grandfather period or automatic cross-Enrollment transfer is assumed.

**Owner review request:** approve **CUR-06 A1+B1+C1+D1+E1+F1** or provide alternative codes and exact transition behavior. After explicit response, record the approved decision in a separate DB-04-only document and reconcile the eight-entity physical/integration/acceptance matrices. If owner defers, a safe independent next design task is the **CUR-07 Exams/Learning/Timetable immutable eligibility/snapshot decision gate**, without implementing code.

**Disposition: CUR-06 D1 TRANSFER, SUBJECT ARCHIVE, REVISION REPLACEMENT AND HISTORY DESIGN READY; OWNER DECISION REQUIRED, NO SQL OR MERGE.**
