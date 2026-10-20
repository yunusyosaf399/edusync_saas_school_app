# DB-04 — CUR-03 Group-Interval, Lock and Decision-Status Independent Review

**Status: DESIGN REVIEW COMPLETE; PRODUCT DECISION REQUIRED.** 2026-10-20. DB-04 PR #103, branch `db/db-04-curriculum-electives-design`. Verified starting DB-04 HEAD `5dff54dc990e0a7210017dbf5f54f6069d9b9328` and `main` `df1c98d5c2d19424946986fc6ba7615202b0a443` before this task. This is an independent *design review only*. No executable SQL, migrations, registered permission/approval/error code, acceptance tests, hosted Supabase changes or downstream domain edits.

## 1. Owner decision ledger — do not infer approval

User's instruction was **“Complete next task you recommended”** after the [CUR-03 proposal](db04_cur03_choice_groups_prerequisites_collision_owner_gate_20261020.md) offered the owner option `Approve CUR-03 A1+B1+C1+D1+E1`. The user's instruction **is not an explicit selection of those five choices**. Therefore none is approved, declined or frozen by this task.

| Gate | Status | Verbatim or authoritative evidence | Outstanding question |
|---|---|---|---|
| CUR-01 | **PARTIAL APPROVAL** | [Owner-selected no-overlap/no campus precedence policy](db04_cur01_approved_applicability_decision_20261020.md) | Future-effective initial publish, mid-year replacement and applied approval route not settled |
| CUR-02 | **PRODUCT APPROVED A1+B1+C1** | [Owner-confirmed compulsory, optional, elective and independent classification](db04_cur02_approved_subject_category_decision_20261020.md) | B1 classification field/external Exams signoff remains physical/integration, not reopened as product semantics |
| CUR-03-A | **UNAPPROVED** | [Candidate A1](db04_cur03_choice_groups_prerequisites_collision_owner_gate_20261020.md) | One group per ELECTIVE Rule, OPTIONAL standalone vs multi-group membership |
| CUR-03-B | **UNAPPROVED** | [Candidate B1](db04_cur03_choice_groups_prerequisites_collision_owner_gate_20261020.md) | Configurable min/max, whether `max≤Section-offered members`, exactly what a durable finalized choice means |
| CUR-03-C | **UNAPPROVED** | [Candidate C1](db04_cur03_choice_groups_prerequisites_collision_owner_gate_20261020.md) | Defer/deny unsupported prerequisites vs typed co-/prerequisites and Exams attainment |
| CUR-03-D | **UNAPPROVED** | [Candidate D1](db04_cur03_choice_groups_prerequisites_collision_owner_gate_20261020.md) | No seat quotas/lotteries vs reviewed capacity ledger |
| CUR-03-E | **UNAPPROVED** | [Candidate E1](db04_cur03_choice_groups_prerequisites_collision_owner_gate_20261020.md) | No selection deadlines/auto exceptions vs effective-date policy |
| CUR-04–08 | **UNAPPROVED** | [Cross-domain signoff dossier](db04_cur_owner_decision_and_cross_domain_signoff_dossier_20261020.md) | Staff/Student/FAMILY authority; P1/P2; transfers/archive; Exams/Learning/Timetable; physical tables and installation |

**Important distinction:** approval of CUR-03 *product semantics* would not itself approve a new database table, Foundation reviewer role, Exam pass threshold, D1 Enrollment change or migration. CUR-08 and independent specialist review still control those integrations.

## 2. Independent findings requiring explicit clarification

### F-01 — Finalized-empty versus not-yet-finalized: current seven-table model is ambiguous

A finalized Student group selection set with `min_choices=0` and **zero** chosen Subjects produces **zero `student_subject_selections` rows**. A Student who has not submitted any group selection also has zero rows. Those states are indistinguishable from selections alone.

**Evidence:** Candidate `student_subject_selections` records only individually accepted elected Subjects, `curriculum_choice_groups` describes limits, and D1 Enrollment is authoritative, not a CUR finalization marker. The proposed `selection_mode=FINAL_SET` *configuration* on a Group is **not** a Student-specific finalization event.

**Candidate remedies (not authorized):** (1) An existing Foundation accepted command receipt can prove a Student submitted a completed group set only **if** it has a durable typed target/Enrollment/revision key, remains queryable through a restricted DB-04 projection and supports one-way re-finalization/version lineage; Foundation owners must affirm those properties. (2) A distinct DB-04 Student finalization/choice-batch fact may be required, taking the candidate entity count above seven. (3) For v1, **do not claim an independently queryable FINALIZED status**: retain final-batch validation at command acceptance, and treat missing selection as "no accepted elective choice" without equating it to "finalized empty". This is the narrowest design fallback but changes product UX/School policy and needs approval.

**Decision request B-F:** Must EduSync remember “the Student submitted/finalized their choices,” including when they selected none? If yes, specify immutable receipt-backed projection vs an extra domain entity under CUR-08 before SQL.

### F-02 — Group `max_choices` versus Section member count: two different policies

Previous [CUR-03-B1 proposal](db04_cur03_choice_groups_prerequisites_collision_owner_gate_20261020.md) requires **`0≤min≤max≤|M(section,d)|`** for every Section/date segment; the [physical candidate](db04_seven_entity_schema_temporal_cur_decision_package_20261020.md) echoes `max≤offered members`. This is **stricter than the logical meaning of “at most max”**.

Example: Group max=2, min=1, but Section B offers only one of the group's otherwise eligible Subjects. A Student can still choose 1 and satisfy both min and max; no logical group violation arises. Under prior strict proposal Section B's publication would be rejected.

**Preserve old candidate until owner choice.** Alternatives:
- **B-M1 (original strict):** `0≤min≤max≤|M(section,d)|`. School guarantees every affected Section offers at least as many choices as the configured maximum.
- **B-M2 (recommended clarification):** `0≤min≤max` and `min≤|M(section,d)|`; `max` remains a *cap*, which may exceed a particular Section's available member count. A Student can never select more than actual offered Subjects, so acceptance still enforces `|A|≤min(max,|M|)` by distinct membership. Group `min=0,max=0` can still be published only under an explicit accepted empty-offering policy.
- **B-M3:** Section-specific max, a separately modeled override; needs versioned Section policy fields or an additional relation and CUR-08 approval.

**No automatic change** is made to previous B1 schema or G-06/FX-10 test expectations: both original and clarified modes reject `min=2` when only one Subject is offered. A **new differentiating test** requires `min=1,max=2,available=1` and checks accept vs reject according to selected B-M1/B-M2.

### F-03 — Applicability changes cannot create impossible ongoing final sets

A Curriculum publication that closes a Section offering or changes a group must examine scheduled and current **accepted elections across the entire affected business interval**, including future choices, to prevent an accepted Student from being stranded. The publication must **not lock Student rows after academic/DB-04 locks**: this would risk reverse order with D1 Enrollment MOVE/END and group changes. The proposed safe fence is School first for every D1/DB-04 mutating operation, then academic parents and Curriculum applicability (publication) or Student→Enrollment→academic→Curriculum applicability (election); a read-only impact scan under the School serialization anchor is a design candidate, **not proof** that all internal Foundation or deferred triggers obey it.

An approved *future-effective* replacement policy is **still CUR-01/05/06 pending**; this document tests candidate behavior without assuming such replacement is allowed.

### F-04 — Historical corrections need both business-valid and as-observed truth

A correction recorded on 20 October that retroactively changes a choice effective from 1 September must not rewrite a published September Exam's original observed revision/selection snapshot. `accepted_at`/`closed_recorded_at` are provenance, but transaction timestamps alone are not guaranteed COMMIT order. Use the existing accepted Foundation receipt and consumer-owned immutable `valid_at`, `observed_at`, revision digest and source IDs; historical correction lineage is append-only or one-way, never destructive.

**CUR-05 P2 correction** and **CUR-07 consumer freeze point** remain approvals, not active commands.

## 3. Interval algebra and event-boundary verification

**Source domains:** D1 accepted PRIMARY Enrollment `E` has a business-effective interval; Section offering `O` references D1 Class Offering/Year/Campus; DB-04 `App` has published applicability interval, `Rule` immutable published category/group, `SecRule` Section-Subject availability interval, and optional/elective `Sel` accepted source/election intervals. Foundation `academic_years.ends_on` is **inclusive**, so the upper-exclusive Year bound is `ends_on + 1 calendar day`.

Let `I=[from,until)` where `until` may be unbounded only before intersection with finite Year/Enrollment context. A valid Student election for `(Student S, Enrollment E, Revision R, Group G, Subject X)` at business day `d` requires:

`E(d) ∧ App(R,E.class_offering,d) ∧ SecRule(R,E.section_offering,X,d) ∧ Rule(R,X,G,ELECTIVE) ∧ Sel(S,E,X,d)`, with an accepted (not invalidated) recorded command and checked caller authorization. This is **not** proved by matching Class/Section display labels. A change to `E` creates a *new Enrollment ID* and cannot reuse `Sel` identity.

**Compute candidate event boundaries**, within each authoritative D1 Year/Enrollment applicability horizon, from:
1. enrollment effective start/end, including any scheduled D1 MOVE/END;
2. old and new applicability effective starts/ends and reviewed one-way cutover;
3. Section Subject Offering starts, ends and one-way closures;
4. accepted Student election starts, original scheduled ends, one-way withdrawn ends and historical correction effective points;
5. any approved future policy windows (none approved under CUR-03-E1 yet).

Sort distinct boundary dates `b0<b1<…<bn`, evaluate constant state for **every** segment `[bi,bi+1)`. Check exact IDs, no more than one published applicable revision per Class Offering/date (approved CUR-01), offered membership `M(R,G,Sec,bi)`, and valid chosen distinct set `A(S,E,R,G,bi)`. Revalidate after every lock wait against live grants, original accepted Enrollment snapshot (Student `row_version`, Enrollment source fields; **no Enrollment row_version**) and revision content digest.

**Half-open boundary examples (illustrative, not School defaults):**

| Segment | D1 Enrollment | Curriculum / offerings | Candidate election | Expected |
|---|---|---|---|---|
| `[2026-10-01,2026-11-01)` | E-1 / SEC-A | REV26, G-SCI members CS,CHEM effective | both chosen, illustrative `min=2,max=2` | final batch valid on those days |
| `[2026-11-01,2027-01-01)` | E-1 / SEC-A | CHEM Section offering ends 2026-11-01; CS remains | CHEM still has historic accepted row, but effective eligibility ends with offering | finalized count drops to 1 ⇒ reject unplanned offering closure/plan; do not delete Student row |
| `[2026-12-15,2027-01-01)` | E-1 ends on Dec 15 in an alternative D1 MOVE scenario | Original REV26 retained | old election `E-1` lineage retained | zero eligibility after Dec 15 for old Enrollment; **no cross-Enrollment transfer** |
| `[2027-01-01,2028-01-01)` | E-1Y27 / SEC-A27 | REV27 published and separately applicable | REV26 election still bound to E-1 | cannot satisfy any REV27 group; needs new accepted choice |
| `[2026-09-01,2026-10-20)` as *observed before correction* | E-1 / SEC-A | REV26 | earlier accepted Biology choice | existing published Exam uses original frozen observed choice |
| `[2026-09-01,2026-10-20)` as *later retrospectively corrected* | E-1 / SEC-A | REV26 retained | later P2 correction successor (if approved) | current as-known replay may differ; original Exam snapshot remains immutable |

**Section vs global distinct count:** `M` counts **distinct Subject IDs offered in the exact Section** for a specific immutable revision and group, not globally offered revision Subjects and not the number of teacher assignments. `A` counts **distinct accepted Subject IDs in the exact Enrollment**, not all years or a Student's previous Campus. Reject duplicate overlapping election heads, cross-Group reference and mismatched revision. Under B-M2, `min≤|M|` is sufficient for publication capacity *only as a group arithmetic fact*; actual successful Student finalization also depends on which Subjects are authorized, published, archived and concurrently accepted.

## 4. D1 cross-domain concurrency/lock matrix — source-compatible candidate

The read-only integration audit and prior [D1/CUR lock proof](db04_d1_curriculum_lock_fk_concurrency_gate_20261019.md) identify these **currently ordered draft** D1 operations; no executable DB-04 code exists yet:

| Writer | Relevant source lock prefix | DB-04 contention / required post-wait check |
|---|---|---|
| D1 Enrollment END, `effect40_02` after `effect37_02` | School → retained source roll-policy IDs/allocator rows → Student → source Enrollment/academic/roll updates | Student election School→Student→Enrollment; see newly ended source and reject stale applicability; do not change D1 retained roll |
| D1 Enrollment MOVE, `effect39_01/02/03` | School → sorted source/destination roll policies+allocators → Student → source Enrollment and source/destination academic paths | election must not attach old Section choice to destination Enrollment, verify exact Student version/source snapshot |
| D1 Subject ARCHIVE | School → Subject and expected Subject row version | revision publish and new-use offering/selection recheck ACTIVE Subject after School wait; historical snapshot unchanged |
| D1 Class Offering/Section Offering archive | School → Class→Campus→Year→Class Offering→Section, guarded D1 lifecycle | School-first Section offering publication/Student election rechecks current state; no new-use from archived Section |
| DB-04 publication/replace (not installed) | Foundation → School → sorted academic/Subject→version/applicability/group | never acquire Student late, reject overlapping scope and orphaned **current/future accepted choices** |
| DB-04 election/withdraw/correction (not installed) | Foundation → School → Student→exact Enrollment→academic/Subject→revision/applicability/group→selection history | after School/Student wait, compare revision digest and Student+Enrollment snapshot, evaluate each effective segment including future offerings |

**Serious unknowns:** parent FK key-share and deferred constraint triggers can acquire locks outside the explicit sequence; Foundation reviewer/permission revocation lock order and D1 final assembled after-file overrides must be independently proven. A source-level candidate is **not** a runtime passed deadlock test. Do not assume D1 School-first prelock protects an unrelated future operator.

**Proposed lock witness evidence for each two-session test:** physical PostgreSQL backend PIDs, transaction/barrier order, waited lock relation/tuple/advisory identifier, `pg_blocking_pids` snapshot, winner/loser safe result, revalidated Enrollment/version/digest/authority, and post-commit retained selection/receipt/audit/outbox count. Execute each race with both commit orders. Don't replace with sequential tests or rely on `lock_timeout` alone.

## 5. Exact acceptance matrix — *designed*, not executed

Existing [G-01…G-18 and GR-01…GR-06](db04_cur03_choice_groups_prerequisites_collision_owner_gate_20261020.md) remain planned; this review adds design distinctions and no new registered test runner.

| Candidate ID | Preconditions | Expected result / owner dependency |
|---|---|---|
| `GI-01` | `min=1,max=2,|M|=1` on SEC-B | **B-M1 rejects, B-M2 permits** under remaining context; settles max-cap ambiguity |
| `GI-02` | `min=0,max=0,|M|=0`; Student has no selections | Clarify `FINALIZED_EMPTY` vs `NOT_SUBMITTED`; no invented state from zero rows |
| `GI-03` | `min=2,max=2,|M|=1` | Both B-M1/B-M2 reject publication; does not contradict earlier G-06 |
| `GI-04` | `min=1,max=2`, one accepted row, two simultaneous amendments on same Student | School+Student/applicability serialization; final set valid and duplicate head prevented; only after CUR-03 approval |
| `GI-05` | Current group passes on 2026-10-31, Section Subject CHEM ends at 2026-11-01 | Analyze future segment; reject unexpected November-invalid finalization/closure |
| `GI-06` | A historical Exam captured before P2 correction to September choice | Current corrected read and original as-observed Exam evidence remain distinct; CUR-05/07 needed |
| `GI-07` | Exact D1 PRIMARY Enrollment ends on Dec 15, new Enrollment Section B starts same day | Old election never supplies choice to new `enrollment_id`; no school/campus label reuse |
| `GI-08` | New Academic Year on Jan 1, same Grade/Class labels and Group code | Resolve Year from D1 Class Offering; old revision/group/selection IDs never silently reused |
| `GI-09` | Section B offers Biology as OPTIONAL but another Section Rule treats same Subject as ELECTIVE in a different immutable revision | Enforce precise Rule/Section applicability, not global Subject category; CUR-01 coverage and CUR-02 approved |
| `GI-10` | Foundation permission revoked between P1/P2 review and APPLY | Current verified Principal+scope/reviewer checks before acceptance; fail closed (CUR-04/05 authorization gate) |
| `GI-11` | Mid-year Group min increases after Student finalized earlier smaller set | Reject unapproved cutover that strands Student; CUR-01/05/06 needed |
| `GI-12` | Two accepted selections for same Subject with overlapping effective time, separate idempotency keys | Never count twice; whole final set/status/fence remains valid, safe duplicate/lineage denial |

**True concurrency additions (separate backends, never reported as executed):**
- **GIR-01:** School-wide publication vs Campus-specific publication overlapping exact Class Offering/date, both orders; approved CUR-01 requires at most one.
- **GIR-02:** Two finalizations on same Student/Enrollment: one `min=0` empty and one nonempty; a receipt-only representation **must** prove exactly one finalization head or be explicitly unsupported.
- **GIR-03:** Publication closes Section CHEM offering effective Nov 1 vs Student's future-effective election Nov 15, either winner; one rejects/invalidates under CUR-06, no stranded accepted fact.
- **GIR-04:** D1 Enrollment MOVE on Dec 15 vs accepted future election of old Section on Dec 20; neither event can attach old election to destination Enrollment.
- **GIR-05:** Revocation of staff permission vs review/APPLY of group amendment; live grant/approval rechecked, no stale authorization bypass.
- **GIR-06:** Retrospective correction vs Exam immutable snapshot capture; one must preserve original consumed `observed_at` and specific source IDs regardless of later correction.

**Tests intentionally blocked:** any action-level “selected min/max passed” claim is conditional on CUR-03 product approval, CUR-08 physical history/finalization data representation, CUR-04/05 permissions/workflows, and independent D1 runtime FK/lock proof.

## 6. Ownership, missing physical fields and recommended next gate

**No eighth relation silently added.** The five CUR-03 product choices remain open, plus **B-F** (durable finalization marker) and **B-M** (max-as-cap vs sufficient available options). These are not an implicit sixth/seventh owner-approved decision—rather **explicit clarifications within CUR-03-B and CUR-08**. If the owner wants a persisted finalized-empty state or enforced prerequisites/capacities, revisit seven-entity physical count with a separate reviewed migration/approval impact; do not encode hidden state on D1 Enrollment, insert a fake Subject choice, or reuse generic Foundation receipt semantics without their schema guarantee.

**Prerequisites deferred only if approved C1**: cannot materialize opaque prerequisite JSON or pretend Exams marks satisfy it. **Capacity/deadlines deferred only if approved D1/E1**: do not auto-create seat holds or time gates. **Group membership A1/B1 unapproved**: published Rule group FK, choice count and publication denial are candidates. B1 Practical/Custom classification remains CUR-02 approved semantically but unfrozen physically.

**Next DB-04 task:** ask the owner to approve or adjust **CUR-03 A1+B1+C1+D1+E1**, **explicitly selecting B-F and B-M**. After approval, create a separate owner decision record, update [seven-entity schema](db04_seven_entity_schema_temporal_cur_decision_package_20261020.md) and [cross-domain signer dossier](db04_cur_owner_decision_and_cross_domain_signoff_dossier_20261020.md) with the approved scope; do not implement SQL before CUR-04…08 and downstream signoffs. If owner defers, another independent safe task is a DB-04-only fixed checked-read/protected-command request/response schema (design-only), without inventing permission registrations.

**Disposition: CUR-03 INTERVAL AND CONCURRENCY DESIGN REVIEW PREPARED; CUR-03 OWNER CHOICES AND CRITICAL FINALIZATION/CAPACITY CLARIFICATIONS REQUIRED.**
