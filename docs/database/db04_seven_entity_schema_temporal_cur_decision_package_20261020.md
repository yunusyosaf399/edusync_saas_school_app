# DB-04 — Seven-Entity Physical Schema, Temporal Integrity and CUR Owner-Decision Package

**Gate: PRODUCT DECISION REQUIRED. Design-only implementation-readiness candidate, NOT FROZEN, NOT SQL AUTHORIZATION.** Prepared 2026-10-20 for open draft PR #103, branch `db/db-04-curriculum-electives-design`. Verified `main` = `df1c98d5c2d19424946986fc6ba7615202b0a443`; previously reviewed DB-04 HEAD = `99b64ef5df375652c6bb31c7c4e5c62fd3a84744`. This is a candidate physical contract + owner choice register, **not an approval of any CUR decision**. The task adds DB-04 documentation only and does not activate Migration 10 or contact hosted Supabase.

## 1. Source, boundaries and contract precedence

Reviewed `AGENTS.md`, master specification ``6–9, 12, 17–21, 23–27, `DECISIONS_AND_INVARIANTS.md`, `SAAS_AND_DATABASE_GUARDRAILS.md`, `SECURITY_WORKFLOW_AND_AUDIT.md`, D1-01/D1-07/D1-11 approved decisions, Foundation academic-year physical catalog, and D1 physical/FK/lock sources. Also read all earlier five DB-04 design documents, particularly [the reconciled 2026-10-20 School-first lock contract](db04_d1_curriculum_lock_fk_concurrency_gate_20261019.md). Other domains' source is read-only.

**Source-supported truths** (do not duplicate or mutate): One school Supabase project, multiple Campuses; `app.academic_years` has independently chosen `starts_on`/inclusive `ends_on`; no guaranteed single ACTIVE year or non-overlap. D1 `app_private.academic_classes` (school Class/Grade), `subjects` (school Subject identity and archive), `class_offerings` (Class×Campus×Academic Year), `section_offerings` (exact Class Offering section), `students` and `enrollments` (accepted immutable PRIMARY placement history) are authoritative. D1 Subject has **no curriculum grouping/choice metadata**, Student Enrollment has **no `row_version`**, but `enrollments` has an exact `UNIQUE(id,student_id)` candidate in the inspected base SQL. The spec recognizes compulsory/optional/elective/practical/extra-curricular/custom subject types and different optional choices in one grade; it does **not** freeze group cardinality, default campus precedence, prerequisite meaning or self-service selection authority.

**Current D1 source prefix (non-executable draft)**: END latest `effect40_02` (retained `effect37_02` School→stored source roll policies→allocator→Student); MOVE latest `effect39_01/02/03` (School→source+destination policy/allocator union→Student), then source Enrollment/academic ancestry; Subject and offerings generally School→academic parents. DB-04's candidate lock prefix is **Foundation verified authority/receipt → School → Student and exact Enrollment if election → sorted academic/Subject parents → DB-04 version/applicability/group/offering/selection**. Publication **never locks Student late**. This replaces, rather than coexists with, the historical DB-04 Student-first/no-School suggestion. All physical FK/trigger and 2-session proof remains unexecuted.

**Ownership exclusion**: No new Class, Subject, School, Year, Section Offering, Enrollment, roll allocation, admission, timetable period, Exam component/result or Learning assignment. Do not add permission codes/grants, Foundation engines, shared manifest/CI or modify any other workstream. Proposed private relations use FORCE RLS and restricted fixed checked interfaces, not authenticated base DML. All new relations and fields below are candidate structures, not deployed catalog objects.

## 2. Final candidate entity count and schema conventions

**Recommendation: retain exactly SEVEN DB-04-owned relations**, consistent with prior PR documents. The seventh is actual Student elected-subject history; the sixth, explicit Section-specific Subject availability, is necessary if Section A can offer Biology while Section B does not. A six-table derivation is possible **only after** a product-owner decision prohibiting Section-specific availability/versioned closures and consumer-stable offering IDs. True course-completion prerequisite graphs might require an eighth typed-edge relation, **not included in the seven**; CUR-03 controls that gate.

**Notation**: `NN` = NOT NULL; `?` = nullable; `I` = immutable after creation; `D` = draft-mutability with incremented version; `O` = one-way reviewed effective close (no reopening); `S` = server-owned. PostgreSQL `uuid` identity defaults `gen_random_uuid()` (proposed), timestamps `timestamptz`, academic business intervals `date` with **half-open [from, until)**, null upper = no earlier bound than enclosing Academic Year/Enrollment. `created_at` / `recorded_at` capture server transaction/acceptance evidence; **PostgreSQL transaction_timestamp is not a guaranteed physical COMMIT timestamp**. Exact as-known reconstruction is based on serialized accepted command/receipt provenance and immutable consumer snapshots, not an invented perfect wall-clock commit sequence. Record an immutable valid-time declaration and a separate one-way end/correction, never silently rewrite published content.

**Shared columns in every candidate table**: `id uuid NN PK I S`; `created_at timestamptz NN I S`; `created_by uuid NN I S → app_private.principals(id)`. A mutable DRAFT/configuration row additionally has `row_version bigint NN S` and `updated_at timestamptz NN S` where shown. Durable state transitions are accepted through fixed commands with existing Foundation receipt/audit/outbox, not direct table UPDATE. Where a command claims a workflow or receipt FK, include it **only if the exact existing parent key and ownership/executor path is verified at SQL review**. No relationship-based permissions inferred.

### 2.1 `curriculum_definitions` — school-scoped reusable named identity (entity 1)

| Candidate additional column | Type and null / mutability | Meaning and invariants |
|---|---|---|
| `school_id` | uuid NN I | FK `school_profiles(id)`; one school's namespace |
| `code` | text NN I | normalized nonblank school-unique code, no silent reuse |
| `label` | text NN D | display label, nonempty, no identity change |
| `state` | text NN D/O | `ACTIVE`/`ARCHIVED` candidate; archive prohibited with future/effective published applicability |
| `row_version,updated_at` | bigint NN S; timestamptz NN S | expected-version contract |
| `archived_at,archived_by` | timestamptz ?, uuid ? O | one-way archive evidence; actor FK Principal, no hard delete |

**Keys**: `UNIQUE(school_id,code)`. Index `(school_id,state)`. School/codes immutable even if archived. A definition may have many revisions; no inheritance of Subject identity or global cross-school catalog.

### 2.2 `curriculum_revisions` — frozen content version (entity 2)

| Candidate additional column | Type / mutability | Meaning |
|---|---|---|
| `curriculum_id` | uuid NN I | FK `curriculum_definitions(id)`; parent owns monotonically increasing ordinal |
| `revision_no` | integer NN I | positive sequentially server-allocated under definition lock |
| `predecessor_revision_id` | uuid ? I | FK self; must belong to same definition, ordinal strictly earlier; no cycles |
| `status` | text NN D/O | `DRAFT,VALIDATED,PUBLISHED,ABANDONED,RETIRED` candidate; do **not** globally mark SUPERSEDED merely because one Campus's applicability was closed |
| `row_version,updated_at` | bigint NN S; timestamptz NN S | edit/version compare; validated digest invalidated when unpublished content changes |
| `validated_digest` | text ? S | canonical typed draft content+coverage hash bound to row version; not authorization by itself |
| `validated_at,validated_by` | timestamptz ?, uuid ? S | successful draft validation and actor FK |
| `published_at,published_by` | timestamptz ?, uuid ? O | first successful reviewed publication recorded, never overwritten |
| `published_content_digest` | text ? I-after-publish | exact immutable version+group+rule digest; nonnull at PUBLISH |
| `publication_receipt_id` | uuid ? I-after-publish | approved existing Foundation receipt reference, not a second receipt table |
| `retired_at,retired_by` | timestamptz ?, uuid ? O | only when all remaining applicability has ended and no forbidden active/future obligations |

**Keys/constraints**: `UNIQUE(curriculum_id,revision_no)`; candidate `UNIQUE(id,curriculum_id)` solely if needed for a real composite child FK. `revision_no>0` and `row_version>0`. Same-parent predecessor enforced with composite key if physically approved or protected check under locked definition. **Published rules/groups/initial applicable coverage cannot be edited in place**; only a separately reviewed one-way end of a specific applicability window is permitted. New published version is a **new revision ID**; a new version is not mutation of the old digest. `status=VALIDATED` alone does not authorize publication.

### 2.3 `curriculum_applicabilities` — exact Class/Year/Campus/time version mapping (entity 3)

| Candidate additional column | Type / mutability | Meaning |
|---|---|---|
| `revision_id` | uuid NN I | FK published `curriculum_revisions(id)`, lock/validate status |
| `academic_year_id` | uuid NN I | FK `app.academic_years(id)` |
| `academic_class_id` | uuid NN I | FK D1 `academic_classes(id)`; school ancestry checked |
| `campus_id` | uuid ? I | FK `app.campuses(id)`; NULL = school-wide target (NOT automatic priority) |
| `effective_from` | date NN I | explicit accepted lower business date, inclusive |
| `declared_effective_until` | date ? I | original allowed upper-exclusive business bound, e.g. year+1 day |
| `cutover_effective_until` | date ? O | separately reviewed one-way earlier cutoff for REPLACE/RETIRE; never increases/reopens |
| `cutover_recorded_at` | timestamptz ? O | when closure was accepted; preserve old as-known upper before this event |
| `cutover_receipt_id` | uuid ? O | exact close/cutover receipt; no freehand edits |
| `accepted_at,accepted_by` | timestamptz NN S, uuid NN S | published applicability accepted provenance |
| `publication_receipt_id` | uuid NN I | Foundation accepted publication command reference |
| `state` | text NN O | candidate `PUBLISHED,CLOSED`; CLOSED means no future use, not erasure of historical interval |

**Computed current effective upper**: `min_nonnull(declared_effective_until,cutover_effective_until,AcademicYear.ends_on + 1 calendar day)`. A year boundary is derived from the **offering's** exact `academic_year_id`, not `CURRENT_DATE` or a globally unique ACTIVE year. Reject unsupported date overflow. For an observer before `cutover_recorded_at`, use the original declared upper; old observed client/Exam evidence remains separately frozen. One-way cutoff must satisfy `effective_from < effective_until`, must not retroactively invalidate existing published Exam contexts, and requires P2 proposal approval (CUR-01/05/06). No duplicate overlapping school-wide/campus-specific coverage for a **real D1 Class Offering** at any business day; a school-wide row and exact-campus row collide and **DENY AMBIGUOUS**, not implicit override. A row is valid only within its referenced Year; its `revision_id` is immutable. Index `(academic_year_id,academic_class_id,campus_id,effective_from)` and `(revision_id)`; apply partial NULL-campus and non-NULL-campus keys plus a protected expanded Class-Offering temporal conflict check. Plain `UNIQUE(...,campus_id)` is **insufficient** due to NULL semantics and cross-scope coverage. Physical exclusion strategy vs locked trigger remains CUR-08 decision.

### 2.4 `curriculum_choice_groups` — minimum/maximum final choice cardinality (entity 4 in creation order; proposed relation 5)

| Additional column | Type / mutability | Meaning |
|---|---|---|
| `revision_id` | uuid NN I | FK parent Revision, same content version as member rules |
| `code` | text NN D-before-publish | revision-unique nonblank group code |
| `label` | text NN D-before-publish | allowed display label |
| `min_choices,max_choices` | integer NN D-before-publish | `0≤min≤max`; `max≤distinct eligible member offerings` at validation |
| `row_version,updated_at` | bigint NN S; timestamptz NN S | only unpublished revision editing |
| `selection_mode` | text NN D-before-publish | candidate `FINAL_SET` (no independently effective incomplete Student draft set) |

**Key** `UNIQUE(revision_id,code)`; candidate `UNIQUE(id,revision_id)` supports same-revision grouped FK if approved. A group can offer more than one simultaneous Subject up to max; *min is checked across all groups, including groups with zero Student rows, in an atomic accepted batch*. There is no Client-written partial accepted choice row. A D1 Student may already have an authoritative Enrollment while the required elective batch is not yet accepted; **do not block, roll back or rewrite D1 Enrollment to satisfy a DB-04 group minimum**. Until final acceptance, OPTIONAL/ELECTIVE eligibility is false for unchosen Subjects. Any school requirement to finalize choices by a deadline is a distinct CUR-02/CUR-04 product decision.

### 2.5 `curriculum_subject_rules` — Subject membership/obligation (entity 5 in creation order; proposed relation 4)

| Additional column | Type / mutability | Meaning |
|---|---|---|
| `revision_id` | uuid NN I | FK Revision; content copied only when drafting successor |
| `subject_id` | uuid NN I | FK authoritative D1 `subjects(id)`; same-school ancestry and new-use `ACTIVE` checked at PUBLISH/APPLY |
| `category` | text NN D-before-publish | candidate `COMPULSORY,OPTIONAL,ELECTIVE` *obligation category*, not a replacement for Spec's `Practical`/`Custom` subject type |
| `choice_group_id` | uuid ? D-before-publish | FK Choice Group; group must share same Revision |
| `display_order` | integer NN D-before-publish | label/order only; does not confer permission |
| `row_version,updated_at` | bigint NN S; timestamptz NN S | unpublished edits only |

**Key** `UNIQUE(revision_id,subject_id)` (single category, single group per Subject per revision recommended). Group membership uniqueness and `choice_group_id` null handling require typed command validation; a nullable group does not cause a fake required choice. **No Student selection for COMPULSORY** in baseline; compulsory eligibility derives from published rule + accepted Enrollment. Optional and ELECTIVE require accepted explicit selection. A genuinely enforceable prerequisite graph or achievement threshold is **unsupported** until CUR-03 chooses a typed eighth table and Exams completion contract. Do not put fabricated `prerequisites jsonb` in the seven-table model.

### 2.6 `curriculum_section_subject_offerings` — explicit Section availability (entity 6)

| Additional column | Type / mutability | Meaning |
|---|---|---|
| `section_offering_id` | uuid NN I | FK authoritative D1 `section_offerings(id)` |
| `curriculum_applicability_id` | uuid NN I | FK exactly one published Applicability |
| `curriculum_subject_rule_id` | uuid NN I | FK exactly one Rule in the same revision as Applicability |
| `subject_id` | uuid NN I | **candidate immutable denormalized consistency key** copied/checked from subject rule to make exact Section+Subject overlap enforceable locally |
| `effective_from` | date NN I | Section-specific first day, intersecting Applicability and D1 Section's Year |
| `declared_effective_until` | date ? I | immutable originally accepted end |
| `cutover_effective_until,cutover_recorded_at` | date ?, timestamptz ? O | one-way availability closure; retain before/after knowledge time |
| `cutover_receipt_id` | uuid ? O | accepted closure receipt |
| `availability_state` | text NN O | candidate `AVAILABLE,CLOSED`; no in-place reclassification of published Subject |
| `accepted_at,accepted_by` | timestamptz NN S; uuid NN S | original publication evidence |
| `publication_receipt_id` | uuid NN I | Foundation command provenance |

**Immutable consistency `subject_id` is not another Subject catalog**: its FK D1 `subjects(id)` and cross-check to Rule `subject_id` enforce a stable local overlap key. Exactly one effective Section+Subject offering at a business time, including across successor revisions and mid-year cutover. `section_offering_id` ancestry must be the same D1 Class Offering Year/Class/Campus covered by Applicability; `rule.revision_id=applicability.revision_id`. PostgreSQL FKs to individual PKs do not prove these joins; use reviewed composite keys **only if physically available**, plus protected locking/ancestry validation. Index `(section_offering_id,subject_id,effective_from)` and `(curriculum_applicability_id,curriculum_subject_rule_id)`; conditional GiST exclusion or deterministic locked conflict scan across same Section+Subject windows. Closure cannot silently invalidate accepted elections or downstream snaps. **Validate every effective Section-specific group against its actually available distinct subjects** at each publication/cutover breakpoint: a published group with minimum 2 but only 1 eligible Subject offered in Section B is impossible, even if the revision globally has 4 choices. School-level membership alone is insufficient. This is a DB-04 publication rejection, not a change to D1 Section or Enrollment.

### 2.7 `student_subject_selections` — accepted Student elective history (entity 7)

| Additional column | Type / mutability | Meaning |
|---|---|---|
| `student_id` | uuid NN I | FK D1 `students(id)`, Student `row_version` expected on command |
| `enrollment_id` | uuid NN I | **reviewed composite FK `(enrollment_id,student_id)→enrollments(id,student_id)`**; exact D1 accepted PRIMARY record |
| `section_subject_offering_id` | uuid NN I | FK DB-04 Section Subject Offering, must match `enrollment.section_offering_id` |
| `choice_group_id` | uuid ? I | FK candidate Group; exact same revision if set, never caller-chosen independent of Rule |
| `selected_from` | date NN I | effective date within accepted Enrollment + Applicability + Section Offering |
| `declared_selected_until` | date ? I | initial exclusive upper, bounded by applicable context |
| `closed_selected_until` | date ? O | later one-way withdrawn/amended upper; no increase/reopen |
| `closure_recorded_at,closure_receipt_id` | timestamptz ?, uuid ? O | immutable as-known close evidence, source retained |
| `selection_state` | text NN O | `ACCEPTED,CLOSED,CORRECTED` candidate; *historical validity is dates + immutable events*, not current mutable label alone |
| `accepted_at,accepted_by` | timestamptz NN S; uuid NN S | acceptance provenance and Principal actor |
| `supersedes_id` | uuid ? I | self FK; reviewed historical correction successor, same Student/Enrollment and baseline same Subject lineage |
| `reason` | text NN I | protected private reason, never exposed to broad report/event/cache |
| `command_receipt_id` | uuid NN I | existing Foundation receipt ID for exactly this accepted mutation |

**Invariant**: old Student selection remains tied to old Enrollment even after MOVE/END; its **effective** interval for current/new-use eligibility is the intersection with D1 authoritative Enrollment and revised applicability/availability, never an auto-reparent. No two accepted current overlapping Section/Subject choices per `(student_id,enrollment_id,subject_id)`; to enforce an exclusion on physical columns, either **copy immutable verified `subject_id` onto this table** (proposed schema amendment needs CUR-08 review) or guard via serialized Student+Section offering joins and a considered conflict index. Do not invent `enrollments.row_version`. For a wrong recorded Subject, normal CHANGE + protected P2 correction evidence is safer than silently permitting `supersedes_id` to cross Subject lineage. The request/receipt can link both original and replacement without changing the Source FK.

**Important record-time limit**: `accepted_at`, `closure_recorded_at`, one-way end fields and Foundation receipts can represent **one acceptance plus one closure per selected row**. A second historical restatement must append a successor with `supersedes_id`; never change accepted or closed evidence in place. An Exam published before later correction persists its *own* immutable observed snapshot, never recomputed from current selections.

## 3. FK graph, null handling and prohibited implicit claims

**Creation order** (no D1 alterations): 1 definitions → 2 revisions → 3 applicabilities → 4 choice groups → 5 subject rules → 6 Section subject offerings → 7 Student subject selections, then indexes/approved narrow triggers and checked commands. All normal FKs `ON DELETE RESTRICT ON UPDATE RESTRICT`; no cascade for ever-published/accepted data; actor/receipt FKs as reviewed. Self predecessor FKs within tables allowed. **No D1/Foundation table is created, altered or seeded by this package**.

| Proposed child | Physical FK supported by existing base/source | Additional invariant requiring protected source-version-aware validation |
|---|---|---|
| Definition | `school_id→school_profiles.id`; `created_by→principals.id` | one school project |
| Revision | `curriculum_id→definition.id`; `predecessor_revision_id→revision.id` | same definition and older ordinal |
| Applicability | `revision_id→revision.id`; `academic_year_id→app.academic_years.id`; `academic_class_id→academic_classes.id`; `campus_id?→app.campuses.id` | school/Year/Class/Campus consistent; no overlapping effective revision for any covered Class Offering |
| Group | `revision_id→revision.id` | complete nonempty/effective group cardinality checked on publish |
| Rule | `revision_id→revision.id`; `subject_id→subjects.id`; `choice_group_id?→group.id` | Subject same school/active new-use, group's revision matches Rule revision |
| Section subject offering | `section_offering_id→section_offerings.id`; `applicability_id→applicability.id`; `rule_id→rule.id`; `subject_id→subjects.id` | Section's actual Offering/Year/Class/Campus matches; Rule and Applicability revision identical, Subject equals rule's Subject |
| Student selection | `student_id→students.id`; **`(enrollment_id,student_id)→enrollments(id,student_id)`**; `section_subject_offering_id→DB-04 offering.id`; `supersedes_id?→selection.id` | exact same D1 Section, correct group, valid effective date, no overlap/max breach, lineage and present live authority |

**Cannot claim**: a composite FK to `app.campuses(id,school_id)` or `app_private.section_offerings(id,campus_id)` because no reviewed unique keys exist for those pairs in the inspected D1/Foundation schema. Base D1 `class_offerings` DOES expose `UNIQUE(id,campus_id)` and `UNIQUE(campus_id,academic_year_id,class_id)`; `academic_classes` has `UNIQUE(id,school_id)`. D1 `subjects` has single `id` PK and `UNIQUE(school_id,code)`, not `UNIQUE(id,school_id)`. FK existence alone cannot check a subject's school on a row lacking verified ancestry. Do not claim the indexed derived joins or cross-row group total can be enforced with a CHECK.

**NULL semantics:** `campus_id NULL` is a positive school-wide scope rather than “unknown”; uniqueness must be split into NULL-campus and non-NULL-campus paths, with **cross-path overlap checks** for expanded real Class Offerings. `choice_group_id NULL` means no group for that Rule, not a new implied singleton; group minima evaluated even when Student has zero matching selection rows. Open-ended intervals require explicit `COALESCE` semantics or a bounded Academic Year upper; avoid `UNIQUE NULL` trickery as if it were a temporal exclusion.

## 4. Temporal decision table and revision immutability

| Event / circumstance | Current valid-date result | Historical as-known evidence | Required owner review |
|---|---|---|---|
| Draft edit | no eligibility | draft versions/typed receipt; no published rows | P0 candidate |
| Validate draft | no eligibility | digest/version at validation | P0 candidate |
| Publish for future Year/Class | eligible only on/after `effective_from` | immutable revision/rules/groups + publication receipt and observed snapshot | P2 candidate |
| School-wide + matching campus row | **AMBIGUOUS; DENY**, no precedence | both rows visible for admin remediation | CUR-01 |
| Adjacent revisions `[a,c)` and `[c,b)` | old before `c`, new at/after `c` | one-way cutoff recorded separately; predecessor intact | CUR-01/05/06 |
| Mid-year revision strands accepted elective | **DENY publication** by default | Student source enrollment and choice history untouched | CUR-06 transition approval |
| Subject archived after an old selection | deny **new** use by default; grandfathering explicitly undecided | old Subject ID/rule/choice retained | CUR-06 |
| Student MOVE to new Section/Campus | old choice not valid for new Enrollment | predecessor Enrollment and old Subject choice retained | CUR-06 |
| Next Academic Year on same calendar date | resolve by explicit D1 Class Offering's Year ID; never global current year guess | each Year/Offering/revision separate | CUR-01 |
| P2 historical correction after Exam published | do not rewrite published Exam eligibility or marks | immutable Exam consumer snapshot + prior choice evidence | CUR-07 |

A published revision's **content digest is never rewritten**; PUBLISH may activate a future-dated Applicability, not backdate to a past year without separate approved correction taxonomy. `SUPERSEDED` is **per applicability or derived global status** only when no context uses the old revision, not a mutable global flag on first Campus cutover. Retiring/archiving is a one-way end of future applicability and definition usage, never removal of accepted Student and downstream historic facts.

**Effective-current selection validity** at business date `d` requires `D1 accepted PRIMARY Enrollment(effective_from ≤ d < effective_until)`, exact Section, Year/Class/Campus, single unambiguous published Applicability, matching immutable Subject rule + Section availability, and for OPTIONAL/ELECTIVE an accepted Student choice whose interval covers `d`. Compulsory is derived from rule+Enrollment alone. Historical `valid_at` and `observed_at` must be frozen by Exams/Learning/Timetable consumer; an as-of rerun after correction is not a substitute for an immutable observation.

## 5. Constraints/index enforcement matrix

| ID | Proposed invariant | Schema-level component | Race/negative acceptance |
|---|---|---|---|
| `C01` | definition school code unique | B-tree `(school_id,code)` | duplicate School+code denied; other school independent |
| `C02` | revision ID and ordinal unique, predecessor same parent | `UNIQUE(curriculum_id,revision_no)`; self FK + parent/ordinal trigger | concurrent drafts cannot allocate N twice |
| `C03` | published digest/rules/groups immutable | typed state guard; no generic UPDATE; content hash bound to receipt | PUBLISHED edit/late child insert denied |
| `C04` | group limits coherent and no duplicate Subject | `CHECK(0≤min≤max)`, rule `UNIQUE(revision_id,subject_id)`; whole revision publish validation | group > offered count denies |
| `C05` | school-wide and campus mapping cannot overlap for same Class Offering/day | partial scope indexes + School-locked interval scan (or reviewed exclusion on materialized coverage) | campus A + school-wide collision denied |
| `C06` | Applicability inside explicit Academic Year | FK Year + server ancestry/year bound and immutable valid-time | wrong academic year denies despite matching grade labels |
| `C07` | rule and Section offering from same revision + School/Section | FKs plus protected locked ancestry; possible server-owned consistency Subject ID | Subject from another school or wrong class offering denies |
| `C08` | one effective Section+Subject availability at a time | `(section_offering_id,subject_id)` time-range exclusion **only if backed by physical immutable key**, otherwise locked interval scan | two competing publishes for same Subject/Section one rejected |
| `C09` | Student source Enrollment matches Student/Section | existing composite `enrollments(id,student_id)` FK and current source snapshot after locks | old Campus/Section or pending Admissions denied |
| `C10` | election intervals do not duplicate/overflow | Student aggregate lock + segment breakpoint checks; optional immutable materialized Subject ID/exclusion | two last-slot selections cannot both win |
| `C11` | group **min** holds after finalized batch, withdraw and scheduled future changes | cross-row group enumeration under School+Student+applicability | two simultaneous withdrawals cannot violate min |
| `C12` | historical correction one-way and same lineage | immutable accepted fields, `supersedes_id` FK + head-consumption uniqueness/lock | two corrections race, one stale, prior retained |
| `C13` | approved future cutover does not strand choice/history | School+applicability publish fence + no late Student lock, impact read | select/publish race one valid result, old Exam unchanged |
| `C14` | checked read / protected command separation | FORCE RLS, no direct authenticated DML; exact private fixed resolver executor | wrong Student/FAMILY/teacher/other Campus denied |
| `C15` | exact receipt/idempotency/audit/outbox | Foundation canonical command intent/replay, typed safe events | same-key same intent replay; mismatched intent denies |
| `C16` | temporal as-known reconstruction | immutable original interval, one-way cutoff and recorded receipt, consumer-owned observed snapshot | backdated P2 cannot rewrite prior published Exam |

**Index budget candidate**: definition `(school_id,code)` unique, revision `(curriculum_id,revision_no)` unique / `(curriculum_id,status)`, applicability `(academic_year_id,academic_class_id,campus_id,effective_from)` plus partial NULL-campus selector, rule `(revision_id,subject_id)` unique and `(revision_id,choice_group_id)`, group `(revision_id,code)` unique, Section offering `(section_offering_id,subject_id,effective_from)` + `(applicability_id,rule_id)`, choices `(student_id,enrollment_id,selected_from)` / `(enrollment_id,section_subject_offering_id,selected_from)` / `(student_id,enrollment_id,choice_group_id,selected_from)` / `(supersedes_id)` / `(command_receipt_id)`. **Do not add GiST/btree_gist/extension or unsupported composite FK without review.** Exact index definitions and uniqueness on `NULL` cases are design freeze items, not implemented features.

## 6. Fixed typed operations, authority, lock prefix and negative checks

All permission names below are **candidate strings, not active registrations**. Each protected mutation takes live verified Foundation Principal + SHARED authz lock, canonical receipt-key advisory fence, exact current typed operation permission/scope, correct P1/P2 policy and independent reviewer where applicable, then **School before Student** for Student-scoped operations. Student/FAMILY self/child relationship and teacher assignment **never** grant mutation authority by themselves. `READ COMMITTED` + post-wait revalidation; no client-supplied resolver `purpose`/School date/Principal.

| Candidate command | Candidate permission / scope | Recommended workflow | Expected targets / positive and negative behavior |
|---|---|---|---|
| `curriculum.definition.create` | `curriculum.definition.manage`, ALL | P0 | unique `school_id+code`, idempotent replay; duplicate denies |
| `curriculum.revision.draft` | `curriculum.revision.draft`, ALL | P0 | exact definition version/predecessor; archived definition denies |
| `curriculum.revision.edit` | same + draft parent context | P0 | expected revision `row_version`; PUBLISHED mutation denies |
| `curriculum.revision.validate` | same, explicit complete intended contexts | P0 | digest and full grouping/Subject/Year ancestry; obsolete validation denies |
| `curriculum.revision.publish` | `curriculum.revision.publish` + distinct reviewer candidate, complete ALL/CAMPUS scope | P2 | reviewed exact digest/approved effective date; overlap/archived Subject denies |
| `curriculum.revision.replace` | publish + reviewer candidate, every affected Campus/Section | P2 | predecessor and cutoff; source selections stranded ⇒ deny |
| `curriculum.revision.retire` | publish/retire distinct grant TBD, complete affected scope | P2 | one-way close; active future obligations ⇒ deny |
| `curriculum.section_subject_offering.change` | `curriculum.offering.manage`, matching CAMPUS/SECTION only when approved | P1 | original and closure receipt, exact Section+Rule; out-of-scope denies |
| `curriculum.selection.initial` | `curriculum.selection.change`, staff scope on exact enrolled Section | P1 DIRECT/APPROVAL TBD | Student `row_version` + exact Enrollment snapshot + revision/group digest; missing min/overflow denies |
| `curriculum.selection.amend` | same, exact source choice IDs | P1; P2 if retroactive | close old/append new, source still eligible; simultaneous amend stale |
| `curriculum.selection.withdraw` | same, exact old selection head | P1 | one-way upper end; group would fall below min ⇒ deny |
| `curriculum.selection.correct_history` | `curriculum.selection.correct` plus distinct reviewer | P2 | append correction successor, prior recorded truth retained; published Exam conflict demands separate policy |
| `curriculum.selection.exception` | independent restricted code **not registered** | P2 if CUR-05 enables | fixed enum/time/source/scope; arbitrary bypass denied |
| `curriculum.selection.propose_self_or_family` | **none until CUR-04** authorizes specific submit grant + FAMILY_SAFE access | proposal only, independently reviewed | no direct accepted selection from Student/FAMILY identity; revoked parent grants deny |

**No artificial Enrollment version**: candidate request includes exact `enrollment_id,student_id,section_offering_id,placement_state,effective_from,effective_until,predecessor_id` and expected Student `row_version`. Lock Student and Enrollment under approved School-first prefix; fresh source comparison after wait. A client-supplied Year/Campus or selected Subject category is not trusted; resolve from D1 and published DB-04 ancestry.

**Shared safe evidence**: existing Foundation command receipts, typed audit and allowlisted outbox; receipt and actual row ID reference retained; no sensitive Student details/reason in broad outbox. P2 final APPROVE ≠ APPLY; apply separately rechecks requester/reviewer live authority and version. Identical retry returns retained result only after current authority; changed payload with same key conflicts; unexpected PostgreSQL failure rolls back complete transaction and evidence. Actor/grant/scope, approved workflow and event registration remain CUR-04/05 gates.

> **Decision update (2026-10-20):** The owner **approved CUR-01's no-overlap/no-implicit-precedence rule** for school-wide versus Campus-specific curricula. See [CUR-01 approved applicability decision](db04_cur01_approved_applicability_decision_20261020.md). Timing/cutover and approval-level details within CUR-01 remain unresolved; CUR-02–CUR-08 are unapproved. The original proposed choices below are historical recommendations, not a declaration that all choices are pending.

## 7. CUR-01 through CUR-08 — exact proposed owner decision sheet

**The CUR-01 overlap/precedence component was approved separately on 2026-10-20; other CUR-01 timing/cutover details and CUR-02–CUR-08 remain OPEN.** Source-supported basis: configurable class/year curricula and optional Student choices; D1 accepted placement/history; Foundation least-privilege and approvals; Exams published results preserved. Proposed P1/P2 routing and semantic details go beyond source and need explicit signoff.

| Gate / owner response needed | Recommended precise choice | Viable alternative | Schema / security / history impact | Acceptance evidence and necessary approver |
|---|---|---|---|---|
| `CUR-01` *School-wide vs Campus-specific precedence, start date, mid-year cutover?* | **Exactly one matching revision per D1 Class Offering/date**, NULL Campus means school-wide with **no automatic override**. Future first publication at explicit Year start; P2 reviewed mid-year cutover. | Explicit campus override/Section-specific revision with defined precedence. | Applicability null/scope and overlap rules; revision content immutable, one-way scoped cutoff; admin complete affected CAMPUS scope | school-wide+Campus collision rejected, adjacent cutover resolves one revision, wrong-year denies; **School owner + Academic/D1 owner** |
| `CUR-02` *Do compulsory, optional, elective and practical/custom labels have separate meanings?* | COMPULSORY obligation derived for enrolled Student; OPTIONAL explicitly chosen; ELECTIVE grouped min/max. Practical/custom treatment remains orthogonal to choice category pending owner rule. | record every compulsory selection; allow ungrouped elective. | Rule category and group FKs, no duplicate pseudo-elections; group eligibility tested server-side | compulsory read eligible without election row; nonchosen elective denied; **School academic owner + Exams classification owner** |
| `CUR-03` *Single/multi-group, minima, prerequisites, capacity?* | One Subject at most one group per revision, multiple members allowed ≤max; finalized atomic batch meets all group mins; no prerequisites/co-req/quotas until typed model approved. | Multi-group membership; typed prerequisite DAG/credit completion; capacity allocations. | Six/seven existing tables insufficient for true directed prerequisites (candidate 8th table and Exams completion dependency); must not store arbitrary JSON exceptions. | empty-group minimum/overflow denies, 2-of-3 succeeds; **School owner + Exams prerequisite owner if needed** |
| `CUR-04` *Who may choose or propose: staff, Student, FAMILY, teacher?* | Staff-only accepted mutation with live action grant/scope; Student/FAMILY/teacher read-only until distinct approved proposal grants and consent/check workflow exist. | Student/FAMILY typed proposal with staff apply, never relationship-implied direct write. | FORCE RLS, narrow SELF/FAMILY_CHILD reads, approved family_safe permission; no broad child roster disclosure. | unauthorized teacher/guardian mutation denies, current linked Family read only; **Owner + security/privacy/Foundation authorization** |
| `CUR-05` *P0/P1/P2 for publish/change/exception?* | DRAFT/VALIDATE P0; PUBLISH/REPLACE/RETIRE and retroactive correction P2; initial/current elective changes P1; exceptions P2 only if enabled. | Lower-risk operations P1 if explicitly approved with distinct reviewers. | Foundation workflow request/review/apply, revalidation, outbox code registrations (none seeded here). | wrong review/self-approval/stale apply invalidates; **School workflow owner + Foundation owner** |
| `CUR-06` *What if curriculum, Subject or Enrollment changes mid-year?* | No automatic historic rewrite or cross-Enrollment choice migration; new Section/Year requires accepted new set; incompatible publication denied pending explicit transition; archived Subject no new use by default, grandfathering undecided. | separate P2 mapped transfer/grandfathering workflow. | one-way selection closures, exact Enrollment FK, effective interval intersection, old Exam snapshots survive. | MOVE vs selection and Subject ARCHIVE vs PUBLISH two-session tests; **School owner + D1 Student/Subject owner** |
| `CUR-07` *What must Exams/Learning/Timetable snapshot and when?* | Fixed restricted private eligibility resolvers; consumer-owned immutable `valid_at` + `observed_at` + revision digest/IDs + accepted selection/Section offering evidence; never rejoin “latest”. | Additional DB-04 ledger only if consumer cannot retain adequate source evidence. | no Exam writes in DB-04; historical corrections cannot rewrite published snapshot. | Exam from 2026 reconstructs identical curriculum after 2027 revision; **Exams, Learning, Timetable and security owners** |
| `CUR-08` *Seven vs six/eight; schema history/lock gate?* | Retain seven; append-only or one-way closure fields; School-first Student command prefix; no executable DB-04 SQL until released D1, FK/implicit-lock/signature review and real race tests. | six if no Section-specific availability; eight for approved prerequisite DAG/ledger. | FK parent keys, date ranges/recorded evidence, indexes, RLS/private ACL and disposable populated upgrade. | local fresh+upgrade, wrong-campus/Year negative, two-session END/MOVE/Subject archive/publish, no grants leaked; **School owner + D1/Foundation/integration security reviewer** |

### Explicit questions for the product owner (no inferred agreement)

1. **CUR-01:** Accept “one unambiguous revision per offering/date, no implicit campus override, explicit P2 mid-year cutover”?
2. **CUR-02:** Accept derived COMPULSORY plus recorded OPTIONAL/ELECTIVE choices, and keep Practical/Custom classification separate from choice obligation?
3. **CUR-03:** Accept one choice group per Subject, bounded atomic finalized sets and **defer prerequisites** until separate design?
4. **CUR-04:** Accept staff-only subject selection mutations until separately approved Student/FAMILY proposals?
5. **CUR-05:** Accept the P0/P1/P2 action matrix above and Foundation independent reviewer rules?
6. **CUR-06:** Accept “no automatic cross-Section/Year transfer; fail closed if revision/Subject archive strands accepted choices”?
7. **CUR-07:** Require Exams/Learning/Timetable immutable consumer-owned snapshots with both business date and observation/provenance time?
8. **CUR-08:** Approve exactly seven tables *as a design direction*, with the proposed original/one-way-closure temporal columns and School-first locking, **without authorizing SQL yet**?

Answers must be recorded explicitly as approved/rejected/modified with owner/time, not inferred from “continue” or from CI. Required specialist approvals above remain separate from owner product intent.

## 8. Immutable downstream handoff and actual implementation blockers

**Candidate shared internal response** (not a function signature, exact consumers to approve): `schema_version; valid_at date; observed_at timestamptz; school_id; academic_year_id; academic_class_id; campus_id; class_offering_id; section_offering_id; curriculum_definition_id; revision_id; revision_content_digest; applicability_id; section_subject_offering_id; subject_rule_id; subject_id; category; choice_group_id?; student_id?; enrollment_id?; accepted_selection_id?; accepted_at?; effective_start/end; authorization decision + safe reason`. Consumers persist allowed source IDs and their own immutable evidence at *their actual freeze boundary*, not a mutable DB-04 pointer. Timetable section offering descriptor omits Student identity; Learning recipients use checked per-Student eligibility, not unrestricted roster; Exams freeze at the assessment/Exam-owned lock point and never reinterpret published results after corrections.

**Blockers prior to DB-04 executable migration**: CUR-01..CUR-08 owner choices; any real prerequisite graph/new table scope; exact Foundation operation/grant/approval/event registrations and executor ownership; independent final assembled D1 Migration 10 including FK/deferred-trigger lock proof; D1 runtime and release gate; Exams/Learning/Timetable snapshot signatures; fresh+populated disposable upgrade design; protected authz/row-scoped negative tests and true concurrent waits. No changes to Foundation, D1, DB-01/02/03, Exams/Learning/Timetable files, global permissions/manifests/CI.

**Why not declare schema FROZEN now?** Product choices determine categories, required group rows, future cutover and transfer effects, student/family authority, and possibly the *number of entities*. Even a perfect physical field list cannot select those values on behalf of the owner.

## 9. Independent DB-04 next-task queue

1. **NEXT and safe without CUR approvals:** prepare an **exact DB-04 migration/acceptance readiness checklist and SQL installation graph (design-only)** mapping the seven candidate tables to Foundation/D1 existing PKs, implicit FK order, D1 243-draft assembled dependency, private ACL/checked read entrypoints and 14 observed-lock race fixtures. Re-audit latest D1 `main` before starting; no SQL, shared CI, external-domain source or hosted Supabase changes.
2. **Owner-review gate:** record CUR-01..CUR-08 actual owner responses and cross-domain signatures; revise candidate fields/count only if approved, then independently review/freeze physical schema.
3. **After separate SQL authorization:** add only approved new Curriculum-owned migration files; install locally after D1 dependency, implement typed history/RLS/receipts, run authentic two-session tests and downstream immutable snapshot checks, request independent security/integration signoff. Never activate Migration 10, merge PR #103 or deploy remotely on design authority.

**Disposition: SEVEN-ENTITY PHYSICAL AND TEMPORAL DESIGN PACKAGE READY FOR OWNER REVIEW — CUR PRODUCT DECISIONS REQUIRED BEFORE IMPLEMENTATION.**
