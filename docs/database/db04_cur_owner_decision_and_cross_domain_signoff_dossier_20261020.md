# DB-04 — CUR Owner Decision Freeze Worksheet and Cross-Domain Integration Signoff Dossier

**Status: OWNER/DOMAIN SIGNOFF REQUEST PREPARED; CUR-02–CUR-08 NOT APPROVED.** Prepared 2026-10-20. Documentation only; DB-04 PR #103 `db/db-04-curriculum-electives-design`. Base `main` verified `df1c98d5c2d19424946986fc6ba7615202b0a443`. No SQL migration, D1 implementation, Foundation permissions, Exams/Learning/Timetable edits, acceptance results, hosted deployment or PR merge. All signatures/decisions explicitly absent except the scoped owner CUR-01 selection below.

## 1. Evidence register and decision provenance

| Evidence ID | Read-only authority | Meaning and limitation |
|---|---|---|
| `E-01` | `AGENTS.md`; Master Specification `19; `DECISIONS_AND_INVARIANTS.md` | Curriculum per Class/Academic Year, six listed Subject types, different Student optional choices, historical/data security requirements. The source **does not** freeze CUR-02 selection representation or category dimension. |
| `E-02` | D1 decisions D1-01, D1-07, D1-11 | D1 owns Subject catalog, accepted PRIMARY Enrollment and staffing; DB-04 owns Curriculum category/Student selections. Teacher assignment not a permission grant. |
| `E-03` | [CUR-01 approved no-overlap record](db04_cur01_approved_applicability_decision_20261020.md) | **Owner approved exactly:** “Approve CUR-01: reject overlapping school-wide and campus-specific curricula, without implicit precedence.” CUR-01 effective-start, mid-year replacement and approval route were **not** approved. |
| `E-04` | [CUR-02 owner decision candidate](db04_cur02_subject_category_owner_decision_gate_20261020.md) | Proposed derived COMPULSORY obligation, explicit OPTIONAL/ELECTIVE elections and independent practical/classification question; **no owner decision yet**. |
| `E-05` | [Seven-entity schema](db04_seven_entity_schema_temporal_cur_decision_package_20261020.md) and [publication contract](db04_curriculum_publication_eligibility_gate_20261019.md) | Exactly seven **candidate** relations and version/selection history plan; not frozen DDL. |
| `E-06` | [D1/Curriculum revised lock gate](db04_d1_curriculum_lock_fk_concurrency_gate_20261019.md) | Current D1 draft School-first END (`effect40_02`) and MOVE (`effect39_01/02/03`) supersede old Student-first source. DB-04 School-first proposal; no DB-04 PostgreSQL runtime pass. |
| `E-07` | [Migration/test readiness gate](db04_migration_installation_and_acceptance_readiness_gate_20261020.md) | D1 guarded 34 relations, 97 permissions, 322 scope alternatives, 36 operations; new DB-04 owner migration/registrar integration must be separate and approved. Proposed 35 authentication/constraint checks + 14 actual opposing-session races; **none executed for DB-04**. |
| `E-08` | `docs/security/09_domain_checked_reads_and_commands.md` and ``17–19, 23–27 of Master Spec | Foundation P0/P1/P2, reviewer separation and field-scoped checked reads; downstream Exams/Learning/Timetable consumer signoff required; *not* proof of activated DB-04 permissions. |

**Decision accounting:** CUR-01 overlap/precedence **approved in part** (owner text in E-03). CUR-01 applicability timing, future effective date, cutover/approval remain **OPEN**. CUR-02, CUR-03, CUR-04, CUR-05, CUR-06, CUR-07 and CUR-08 **OPEN**. Nothing is counted as approved merely because code, a proposal, a passing D1 test, a previous assistant recommendation, or a “Complete next task” message exists.

## 2. Owner choices in one freeze worksheet

*For each row, owner response required: **APPROVE RECOMMENDATION / APPROVE WITH EDITS (specific replacement text) / REJECT / DEFER**. A specialist's interface/implementation signature is separate from the product owner's choice. No row below carries an inferred signature.*

| CUR / priority | Current approved portion | Recommendation needing explicit choice | Alternative and impact | Accountable owner / downstream acknowledgment | Acceptance proof | Status |
|---|---|---|---|---|---|---|
| **CUR-01** applicability | **APPROVED:** one unambiguous published revision for same real D1 Class Offering/date; no campus override or school-wide precedence | First effective date explicitly bound within offered Year, future publication allowed; P2 reviewed mid-year cutover; no stranded choices | Restrict first publish to Year start / defer mid-year changes; affects interval model, cutover workflow | **School product owner**, D1 Academic ancestry/Year signer | same-scope school+Campus overlaps deny, adjacent half-open ranges unambiguous, wrong-year deny | **PARTIAL APPROVAL; timing open** |
| **CUR-02** Subject categories | None | Derived compulsory obligation (no Student selection row), optional individually selected, elective grouped/selected; decide Practical/Extra-curricular/Custom as second dimension vs exclusive type | Materialize compulsory rows, collapse Optional/Elective, exclusive six-way types; may change T5/T7, snapshot, Exams treatment | **School product owner**, Exams subject/assessment owner | `CAT-01…CAT-16` (candidate) | **PENDING OWNER** |
| **CUR-03** group/prerequisite | None | One group per Subject Rule per revision; final election batch meets group min/max; defer true prerequisites until typed DAG + Exams completion contract approved | Multi-group, credits/capacity/prereq graph; likely eighth entity & new dependencies | **School product owner**, Exams prerequisites/completion owner | empty-positive-min group denies; 2-of-3 valid; concurrent last-slot no overflow | **PENDING OWNER** |
| **CUR-04** actors | None | Staff-only accepted elective change by complete scope grant; Student/FAMILY current checked read, self-service proposals only after separate permission/consent review; teachers assigned Subject get no automatic mutating permission | Student or linked Family may submit reviewed proposals; demands new explicit family_safe grants, target checks | **School product owner**, Foundation Authorization/Privacy owner | teacher/guardian/other Campus write denied; revoked access blocks read/write; no peer leakage | **PENDING OWNER** |
| **CUR-05** workflow | None | P0 draft/edit/validate; P2 publish/replace/retire/correct; P1 normal election changes; P2 exception only if activated; exact independent reviewer and explicit APPLY | Different per-action policy classes with registered reviewer chains; changes catalog/scope and acceptance | **School product owner**, Foundation Workflow/Registrar owner | self-review deny, stale approved apply invalidates, missing P1 policy fails closed | **PENDING OWNER** |
| **CUR-06** replacement & moves | None | Preserve old Student selection bound to D1 Enrollment; new Section/Year requires separate validated choice; archived Subject stops new use, preserve history; incompatible mid-year replacement refuses without approved transition | Audited mapped electives/grandfathering/retroactive exceptions; requires exact temporal closure + consent policy | **School product owner**, D1 Enrollment/Subject and Admissions owners | MOVE/END versus choice two-session, no silent migration, historic Exam snapshot unchanged | **PENDING OWNER** |
| **CUR-07** consumers | None | Immutable consumer-owned `valid_at` + `observed_at`, revision/Rule/Section Offering/Enrollment/Student choice IDs, digest and fixed private resolver; no latest-revision replay for old Exams | Additional provider snapshot ledger if consumers cannot persist sufficient evidence | **School product owner**, Exams/Learning/Timetable owners + Security | Exam published in 2026 still reproducible after 2027 publish and P2 correction, without client-purpose injection | **PENDING OWNER + THREE DOMAIN SIGNOFFS** |
| **CUR-08** physical/release | None | Retain seven candidate tables with recorded-time one-way closure, FK/backstop/School-first locks; separate post-D1 migration; no self-activation | six if no Section variability, eighth if prerequisites/ledger required; index and migration graph changed | **School product owner**, D1/Foundations SQL integration and independent security reviewer | exact schema/ACL catalog, 35 auth/constraint specs, 14 2-session observed waits, populated local upgrade | **PENDING OWNER + INTEGRATION REVIEW** |

### Decisions that must not be conflated

- **Approved no-overlap** does not approve mid-year replacement or a P2 workflow route; CUR-01 timing remains open.
- CUR-02 obligation category is not D1 Subject Catalog `state`/`assignment_kind`. Exam theory/practical components belong to Exams, not Curriculum.
- A Category or Group `min_choices` cannot invalidate accepted D1 PRIMARY Enrollment. “No choice accepted” does not mean “no Student exists.”
- CUR-03 group granularity/prerequisites can require schema revision, regardless of CUR-02's choice.
- CUR-04 relationship/assignment context alone never grants accepted selection mutation.
- CUR-07 exact consumer format and snapshot freeze time must be agreed by each owner; a digest alone cannot reconstruct what a consumer actually observed.
- CUR-08 table count and temporal fields may not be locked as frozen while other CUR decisions could add an eighth entity.
- No permission, reviewer role, operation/event registration, workflow policy or School default is active solely because listed in a DB-04 file.

## 3. Cross-domain signatures and compatibility evidence requested

| Dependency owner / signature | Exact handoff contract | Evidence to request; fail condition | Recorded status |
|---|---|---|---|
| **D1 Academic owner** | `academic_classes`, `subjects`, `class_offerings`, `section_offerings` PK/schema lifecycle and lock prefix | Released D1 version, actual compatible Year/Class/Campus ancestry and Subject ARCHIVE/Offering close guards; no undocumented new composite FK | **OPEN** |
| **D1 Student/Enrollment owner** | accepted `students` + `enrollments(id,student_id)` and exact snapshot; School-first END/MOVE/current School-date behavior | Final assembled END `effect40_02` and MOVE `effect39_01/02/03` installed shape; true two-session School/Student/roll/Enrollment/DB-04 conflicts; no fabricated Enrollment row_version | **OPEN** |
| **DB-01/DB-02 roll owner** | roll-policy and allocator remain D1/roll-owned, DB-04 does not lock allocator pools or change rolls | Validate Curriculum School-first choice path does not indirectly invoke roll allocator helpers, late triggers or bypass retained source roll ownership | **OPEN — read-only dependency** |
| **DB-03 Admissions owner** | verified offer/admission only creates Student after D1 handoff; no elective accepted from prospective admission | Admission draft/offer cannot supply fake `enrollment_id` or selection; Student activation/handoff remains Admissions-owned | **OPEN — read-only dependency** |
| **Foundation security/registrar owner** | verified Principal, grant/scope, family_safe checked reads, Foundation P0/P1/P2 reviewer, command receipts, audit/outbox | Exact proposed permission/operation codes and review scopes registered **separately**; one-way apply receipt, safe event name/payload, no broad SELECT/EXECUTE or new role template | **OPEN** |
| **Exams owner** | Student+assessment `valid_at`, observed accepted `revision_id`, published-content digest, rule/Section Subject Offering, D1 Enrollment+elected selection if any | Define assessment/Exam-Controller freeze point and immutable storage; check old Exam never changes after revised Curriculum/corrected election | **OPEN** |
| **Learning owner** | published section/subject recipient eligibility and subsequent submission recheck from fixed private resolver | Define assignment audience snapshot at publication, submission policy, historical course access and opt-out effects without peer selection leaks | **OPEN** |
| **Timetable owner** | effective Section Subject Offering and revision-date availability, no Student row list required | Confirm teacher/room/period conflicts stay Timetable-owned, Section availability is not proof of individual election | **OPEN** |
| **DB/security integrator** | approved seven-table installation dependency DAG and final FK/implicit-lock/ownership proof | D1 migration gate & exact assembled SHA; parent key uniqueness and trigger `FOR UPDATE` ranks; disposable fresh and populated upgrade, 14 real wait races, exact-head CI | **OPEN** |

### Candidate interface surfaces (not installed, not signatures)

**Exams**: fixed `curriculum_exams_student_subject_eligibility(student_id,enrollment_id,section_subject_offering_id,valid_at)`, caller derived server-side, no client arbitrary purpose; denies Student elective without accepted choice and wrong-year Section. Returns purpose-minimized identifiers/digest/interval and safe decision. Consumer persists exact evidence at its approved freeze time.

**Learning**: fixed `curriculum_learning_section_subject_eligibility(section_offering_id,section_subject_offering_id,valid_at)` and separately authorized per-Student eligibility; consumer persists recipient snapshot, no unchecked bulk Student list.

**Timetable**: fixed `curriculum_timetable_section_subject_eligibility(section_offering_id,section_subject_offering_id,valid_at)`; returns Section subject availability, effective interval, revision identity, group constraints if authorized. Never returns Student selection/Personal data and never authorizes staff assignments.

The actual PostgreSQL schema `app_private`, column list, EXECUTE target role, denial-code taxonomy and transaction/snapshot cut-off remain **CUR-07 + security signer decisions**.

## 4. Integration compatibility matrix — required before implementation

| Gate | Verified from existing source | What still must be proved in final implementation |
|---|---|---|
| `I-01 Foundation` | Foundation migrations 1–9 frozen; existing shared auth, approval/receipt/audit/outbox engines | exact schema owner, column grants, narrower DB-04 Executor, no broad future migration privileges |
| `I-02 D1` | exact parent FK candidate `enrollments(id,student_id)`; `students` row_version and `enrollments` no version | final released D1 effective definitions/foreign keys, D1 active states, Student and academic lock ranks |
| `I-03 Prefix` | D1 END/MOVE School-first in current ordered 243 D1 draft chain | D1 + DB-04 observed two-session END/MOVE, source roll-trigger implicit locks and FK waits after Student |
| `I-04 Publication` | CUR-01 overlap/no precedence owner approved | formal interval rule/initial start/mid-year semantics, unambiguous expanded Class Offering coverage and concurrent conflicts |
| `I-05 Selection` | D1-07 Enrollment truth and DB-04 candidate Section/choice entities | approved group category semantics, Student/Family permissions, D1 MOVE/END intersection, correction lineage |
| `I-06 Historical` | Foundation history; Exams published marks immutable | two-clock evidentiary strategy with durable receipt and consumer-owned frozen eligibility Snapshot |
| `I-07 Installation` | guarded D1-only local CI expects 34/97/322/36; current DB-04 PR only Markdown | separate DB-04-owned migration/tests/integration-owned CI registration after D1 release; no alteration of D1 guarded inventory |

**Acceptance-bundle handoff:** 16 new CUR-02 `CAT-xx` scenarios in [category decision gate](db04_cur02_subject_category_owner_decision_gate_20261020.md), 35 proposed `AT-xx` tests in [migration-readiness plan](db04_migration_installation_and_acceptance_readiness_gate_20261020.md), and 14 `LX-xx` genuine 2-backend races in [lock contract](db04_d1_curriculum_lock_fk_concurrency_gate_20261019.md). These **overlap by invariant**; they are **planned coverage**, not 65 independent passing tests. Deduplicate physical test fixture IDs at implementation design freeze, but preserve every negative or race outcome.

## 5. Exact owner and specialist approval handoff

**Owner:** choose CUR-02-A/B/C first (these have direct schema/Exams effects); then CUR-03 cardinalities; CUR-04 who may submit/apply; CUR-05 workflow; CUR-06 transfer/archival/grandfather policy; CUR-01 remaining effective/mid-year timing; CUR-07 persisted snapshot; CUR-08 final table count. An owner decision must be recorded with exact user words and date, and the changed accepted portion must be separated from remaining undecided parts.

**Domain signers:** Foundation security/registrar on permissions/P1/P2/PRINCIPAL/family_safe and event safe payload; D1 Academic/Student/Roll/Admissions on source identities/locks/handoff; Exams/Learning/Timetable each on their bounded read-only resolver+immutable observation.

**Runtime reviewer:** prove final assembled source SHA, seven DB-04 table FKs/index/RLS and no changes to D1/Fnd objects, populated local migration from existing Student/Subject history, true observed locks in both arrival orders, three consumers' immutable snapshots and exact-head green CI. No remote Supabase database is a test target.

**PR handoff:** update only PR #103 description and DB-04 documents with decision provenance and the link to this dossier. All cross-workstream signoffs here are **requested**, not implied by PR descriptions. No merge/activation without explicit independent approval.

## 6. Next task queue

1. **Next owner choice:** CUR-02-A/B/C decision (ask one concise combined question with recommended default). If approved, make a distinct decision record and update tables/statuses, without implementing SQL.
2. While CUR-02 pending, a further safe task is **DB-04-specific test fixture and API denial-code catalog (design-only)**. It can specify realistic Grade 9-A/B, two Campus and Year synthetic cases, expected canonical idempotency and negative outcomes, without writing tests/shared runners.
3. After all choices and specialist signoffs, freeze seven-entity or owner-approved variant and request separate implementation authorization, then Schema → constraints/history → typed commands → checked reads → concurrency → downstream validation. Do not self-merge, activate Migration 10, modify other workstreams or deploy hosted Supabase.

**School example:** Grade 9-A Mathematics is compulsory. Biology and Computer Science are offered choices under a candidate Curriculum. A Student with a current Grade 9-A PRIMARY Enrollment may receive compulsory Mathematics through the published Rule, but Biology exam eligibility needs an accepted election if CUR-02's recommended model is approved. When a newer Year is published, the earlier Exam's immutable snapshot still points to the original Rule, Subject and accepted election, and the Student's old selection does not follow to Grade 10.

**Disposition: OWNER DECISION + CROSS-DOMAIN SIGNOFF DOSSIER READY; CUR-01 PARTIAL APPROVAL RETAINED, CUR-02–CUR-08 OPEN; SQL BLOCKED.**
