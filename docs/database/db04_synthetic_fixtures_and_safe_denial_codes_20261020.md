# DB-04 — Synthetic Acceptance Fixtures and Safe Denial-Code Catalog

**Status: DESIGN-ONLY TEST CONTRACT READY FOR REVIEW — NO EXECUTABLE TESTS OR DEPLOYED ERROR CODES.** Prepared 2026-10-20, DB-04 PR #103; verify source and installation baseline again at future implementation. Owner-approved product rules: [CUR-01 nonoverlap/no implicit precedence](db04_cur01_approved_applicability_decision_20261020.md) and [CUR-02 A1+B1+C1 subject semantics](db04_cur02_approved_subject_category_decision_20261020.md). CUR-01 start/cutover details and CUR-03–CUR-08 are **not** approved. This file does **not** authorize SQL, local fixture creation, grants, D1 source changes, shared CI changes or any hosted Supabase access.

## 1. Test authority, fixture safety and evidence provenance

- D1 `app_private.academic_classes`, `subjects`, `class_offerings`, `section_offerings`, `students` and `enrollments` own Class, Subject, actual Campus/Year Offering, accepted PRIMARY Enrollment and historical transitions. **Fixtures must be established with the released D1 protected commands**, not by inventing D1 rows or disabling audit.
- Foundation manages School/Campus/Academic Year, Principal, current live grants/scope, Family CHILD authorization, workflow requests, receipts, audit and outbox. Use **disposable local** projects with deliberately seeded test policies by the authorized harness only; never import private production Student/Family records. No extra role/grant implied for Student/FAMILY/teacher.
- All identifiers in this document are **symbolic aliases** (`S1`, `AY26`, `SEC-A`). Future test setup generates real UUIDs server-side and binds aliases in an in-memory fixture map. Do **not** hardcode illustrative UUIDs into production migrations. Names and group cardinalities are demonstrative, not School defaults.
- Each scenario tests public safe denial plus private minimal audit/receipt behavior, row-version/snapshot fencing, effective business date and recorded/consumer-observed timestamp. Do not infer the latest year by wall clock. The D1 local draft chain may change; do not call an old assembled-SHA test result current evidence.

> **CUR-03 suite extension (2026-10-20):** [CUR-03 decision gate](db04_cur03_choice_groups_prerequisites_collision_owner_gate_20261020.md) refines grouped tests as **G-01…G-18** and opposing-backend races **GR-01…GR-06**. The illustrative Biology-in-group variant is classified **ELECTIVE for that revision**, distinct from the original `SUB-BIO` OPTIONAL fixture. This avoids contradictory Rule categories. All CUR-03 numeric settings remain **conditional** until owner approval; existing `FX-09/FX-10` use illustrative numbers only.

## 2. Compact synthetic School graph

**One School Project** (`S1`) has **two campuses** `C-A` (Main) and `C-B` (North). Academic years `AY26` (2026-01-01 through **2026-12-31 inclusive**) and `AY27` (2027-01-01 through **2027-12-31 inclusive**) are synthetic Foundation rows, not a calendar policy. Their effective interval upper endpoints for DB-04 are 2027-01-01 and 2028-01-01, respectively. Grade 9 `CLASS-9` is a single D1 School Class. Distinct D1 Class Offerings link `CLASS-9` to each (Campus, Year). No global ACTIVE-year inference.

| Alias | Authoritative source | Fixture values and invariant |
|---|---|---|
| `CO-A26` | D1 `class_offerings` | Grade 9/C-A/AY26, OPEN |
| `CO-B26` | D1 `class_offerings` | Grade 9/C-B/AY26, OPEN |
| `CO-A27` | D1 `class_offerings` | Grade 9/C-A/AY27, OPEN |
| `SEC-A` | D1 `section_offerings` | Grade 9-A attached to CO-A26 |
| `SEC-A2` | D1 `section_offerings` | Grade 9-B attached to CO-A26 |
| `SEC-B` | D1 `section_offerings` | Grade 9-A attached to CO-B26 (**same label, different Campus**) |
| `SEC-A27` | D1 `section_offerings` | Grade 9-A attached to CO-A27 |
| `SUB-MATH` | D1 `subjects` | ACTIVE Mathematics; COMPULSORY under candidate CUR revision |
| `SUB-BIO` | D1 `subjects` | ACTIVE Biology; OPTIONAL under one Rule/Revision |
| `SUB-CS` | D1 `subjects` | ACTIVE Computer Science; ELECTIVE under grouped choice |
| `SUB-CHEM` | D1 `subjects` | ACTIVE Chemistry; ELECTIVE under grouped choice |
| `SUB-ART` | D1 `subjects` | ACTIVE Art; ELECTIVE under grouped choice, **offered only in SEC-A2** in a variant |
| `ST-1,ST-2` | D1 `students` | Two distinct Students in School S1; server-owned row_version |
| `E-1,E-2` | D1 `enrollments` | Accepted PRIMARY Student placements ST-1→SEC-A and ST-2→SEC-A2, distinct IDs and effective intervals |
| `E-1B` | D1 future accepted move record | ST-1→SEC-B via protected D1 MOVE and old E-1 effective closure; never overwrite E-1 |
| `E-1Y27` | D1 future Year progression | ST-1→SEC-A27 via D1 approved workflow, never repoint old selection |
| `P-ADMIN-A` | Foundation verified Principal | Staff with hypothetical explicitly test-granted approved DB-04 action and **C-A** scope only; not a privileged role shortcut |
| `P-ADMIN-ALL` | Foundation verified Principal | Staff with hypothetical explicitly granted all-campus DB-04 permission only under future CUR-04 approval |
| `P-TEACHER` | Foundation+D1 teacher assignment | Teacher has Subject assignment to SEC-A but **no DB-04 selection permission** |
| `P-ST1` | Foundation Student SELF | Bound only to ST-1; own checked reads subject to future registered grant |
| `P-FAMILY-1` | Foundation FAMILY CHILD | Current linked child ST-1 with hypothetical family_safe **read only**, never write |
| `P-FAMILY-OLD` | Foundation FAMILY CHILD | Previously linked child ST-1, now revoked; must deny new reads/mutation |

**Candidate Curriculum aliases** (seven relation candidates only): `DEF-9` parent definition; `REV26` published Grade 9 AY26 school-wide applicability `APP26` and immutable content digest `D26`, `RULE-MATH` compulsory, `RULE-BIO` optional, `RULE-CS/CHEM/ART` elective, `GRP-STEM` published choice group, per-Section availability entries `O-A-MATH`, `O-A-BIO`, `O-A-CS`, `O-A-CHEM`, etc.; accepted student election `SEL-1` e.g. ST-1 Biology with `E-1`. `REV27/APP27` belongs to AY27 and has a different digest `D27`. **Do not infer an arbitrary default group min/max:** for individual scenario `F-G1`, deliberately configure `min=1,max=2` if and only if CUR-03 later authorizes that semantic; until then those cases are **conditional** and documentation-only.

For CUR-02 B1, an additional symbolic **Practical classification** on compulsory Mathematics is useful; the *physical classification field is NOT frozen*. Exams owns theory/practical marks and must sign off before asserting deployed metadata.

## 3. Fixture commands, expected result class and evidence

| Scenario | Precondition and action | Outcome mandated by approved policy vs conditional |
|---|---|---|
| `FX-01` | Publish REV26 school-wide for CO-A26 and CO-B26, valid interval `[2026-01-01,2027-01-01)`; then attempt conflicting Campus A coverage same dates | **APPROVED CUR-01**: second publish conflicts; no implicit Campus override, exactly one applicable revision |
| `FX-02` | Two concurrent conflicting publications, one school-wide, one Campus A with same Class/Year/date | **APPROVED CUR-01**: one conflict-free result, loser no partial publication; two real backends required |
| `FX-03` | REV26 campus-A only + another separate Campus-B-only scope with same dates | **CUR-01**: no overlap across those distinct Class Offerings; valid assuming remaining publication policy is approved |
| `FX-04` | ST-1 has E-1 in SEC-A, `RULE-MATH`/O-A-MATH effective, but no selection row for Mathematics | **APPROVED CUR-02 A1**: Maths obligation derived, Student selection count for Math remains zero |
| `FX-05` | ST-1 sees Biology offered in SEC-A but has no SEL-1 | **APPROVED CUR-02 A1/C1**: Section offering true; Student chosen-eligibility false |
| `FX-06` | Staff with live complete future approved permission accepts Biology for E-1 with correct revision/Section | **CUR-02 A1/C1**: accepted choice produces one immutable ST-1/E-1 subject selection, never a second Enrollment; actor/route **CUR-04/05 conditional** |
| `FX-07` | Maths classified Practical as well as COMPULSORY | **APPROVED CUR-02 B1**: classification does not replace obligatory nature; physical field/Exams representation pending |
| `FX-08` | Rule for CS is ELECTIVE, candidate group GRP-STEM; attempt accepted CS outside published group | **APPROVED CUR-02 C1**: invalid ELECTIVE group membership denied |
| `FX-09` | In `F-G1` min=1 max=2, two valid choices followed by third | **CUR-03 conditional**: first two can pass, third is over maximum; numbers only test parameters |
| `FX-10` | In `F-G1` min=2 but SEC-A offers only 1 eligible group Subject | **CUR-03 conditional**: publication must reject impossible per-Section membership rather than blocking D1 Enrollment |
| `FX-11` | Select Biology `O-A-BIO` against ST-1 moved via D1 to E-1B in SEC-B | **D1/CUR-02**: old `SEL-1` does not migrate; after effective MOVE old offered Section not current |
| `FX-12` | Use ST-1 new Year E-1Y27 but supply REV26's selection ID | **D1/CUR-01**: wrong Year/Enrollment/revision denied; old historic ID preserved for checked read |
| `FX-13` | Archive `SUB-CS` after historic accepted selection, then attempt new election | Archive-new-use policy **CUR-06 pending**; never erase original Subject/rule/selection/Exam evidence |
| `FX-14` | P-TEACHER has D1 assignment, attempts `curriculum.selection.initial` without separate DB-04 grant | Foundation least privilege: **deny**; no teacher role shortcut |
| `FX-15` | P-FAMILY-1 reads own linked ST-1 vs tries write; P-FAMILY-OLD reads after revocation | Current SELF/FAMILY_CHILD/family_safe checked read only with **CUR-04 grant**; linked Family alone never authorizes write; revoked read denies |
| `FX-16` | Revise CUR from REV26 to REV27 after an Exam recorded 2026 basis and later Student correction | **Historical invariant**: old Exams consumer snapshot `valid_at/observed_at`+REV26 D26 retained; exact integration CUR-07 pending |

Each future executable test uses a distinct rollback-isolated fixture or a justified shared immutable fixture, verifies accepted Subject/Enrollment identity and School/Campus ancestors, and asserts Foundation receipt/audit/outbox counts under allowed executor. Never write arbitrary effective history directly through `authenticated`/`anon`, even in tests. When permission/approval policies are not frozen, `FX-06/09/10/13/15` must **not** be misleadingly asserted as product-approved defaults.

## 4. Safe denial-code catalog — candidate, not registered values

The following identifiers are **proposed internal API-level safe codes**, not deployed PostgreSQL SQLSTATEs, Foundation receipt statuses or D1 error codes. Define a fixed allowlist and map existing domain-denial representations in approved SQL; never leak existence of a child/Student/School/Section through untrusted-target differences. No arbitrary exception text, Student PII, freeform reviewer reason or client-provided denied-code selection.

| Safe response code proposal | Conditions, for *authorized* caller only | External exposure policy | Related fixture |
|---|---|---|---|
| `NOT_ACCESSIBLE` | missing Principal/grant/scope, unauthorized or nonexistent arbitrary target; revoked Student/FAMILY basis | **Uniform generic response** to clients; do not distinguish EXISTS vs forbidden | FX-14/15 |
| `INVALID_CONTEXT` | caller authorized for context but exact D1 Section/Enrollment/Year/Subject ancestry mismatch | Limited safe response; unauthorized caller gets NOT_ACCESSIBLE | FX-11/12 |
| `CURRICULUM_NOT_CONFIGURED` | permitted Section/Year has no effective published revision | Authorized academic admin only; Student/Family may receive generic "unavailable" | FX-03 variant |
| `CURRICULUM_AMBIGUOUS` | more than one effective revision or school-wide+Campus conflict | **Block publication**; internal/admin remediation only; not peer/campus details | FX-01/02 |
| `CURRICULUM_NOT_EFFECTIVE` | published version outside approved date/Year or before approved future start | Only scoped authorized admin safe response | FX-12 |
| `REVISION_STALE` | expected content digest/row_version no longer matches, draft was edited, concurrent publish wins | Generic stale/retry as appropriate, never disclose another actor's draft | FX-02 |
| `ENROLLMENT_STALE` | D1 Student row_version, enrollment accepted PRIMARY state, source snapshot or Section changed | Generic invalidated/stale; include no old/new Student context | FX-11/12 |
| `SUBJECT_NOT_OFFERED` | exact Rule and Section Subject Offering not effective in this context | Safe only after authorized scoped context resolution | FX-05/08 |
| `CATEGORY_NOT_SELECTABLE` | attempt to elect a COMPULSORY Subject or forbidden obligation category | Authorized choice command; do not disclose other Student's metadata | FX-04/08 |
| `CHOICE_GROUP_MISMATCH` | ELECTIVE not in a valid published group, Rule references other revision | Scoped choice command only | FX-08 |
| `CHOICE_GROUP_LIMIT` | authorized accepted batch exceeds approved max, or fails approved finalized minimum | Generic group rule failure; exact min/max only to eligible reader | FX-09/10 |
| `DUPLICATE_SELECTION` | already-accepted identical effective Student+Enrollment+Subject interval | Authorized caller only; no raw key/details to unrelated targets | FX-06 |
| `HISTORY_CONFLICT` | attempted one-way close/revision/correction would contradict accepted lineage or immutable downstream history | Retain old evidence; do not leak correction reason | FX-16 |
| `SUBJECT_NOT_USABLE` | archived/retired D1 Subject proposed for **new** use under later approved CUR-06 policy | Scoped admin; do not infer historical subject was deleted | FX-13 |
| `REVIEW_REQUIRED` | exact P1/P2 route configured and current command lacks completed required review | Operation-level safe response; no reviewer identities disclosed | FX-06 |
| `REVIEW_INVALIDATED` | approved request stale at APPLY, requester/reviewer permission/context invalidated | Safe request state per existing Foundation receipt taxonomy; never fabricate success event | FX-06/11 |
| `IDEMPOTENCY_CONFLICT` | same key with **changed canonical typed intent** after current caller authority revalidated | No previous payload/Student ID leaked | FX-06 replay |
| `TEMPORARILY_UNAVAILABLE` | transient transaction/deadlock/connection/internal infrastructure error | Do not falsely label valid operation as a policy denial or create rejected business receipt for rolled-back error | any |

**Resolution order proposal:** authenticate current Principal and live complete permission/scope → resolve allowed target ancestry → check idempotency **with current authority** → check expected Student/Enrollment/Revision snapshots → protected School-first lock/context revalidation → validate publication/Section/group/Subject → apply or safely deny. Exact Foundation receipt semantics and relative lock/read ordering must follow its installed security contract, not this presentation row's shorthand. Use internal structured audit reason in protected evidence only, never in public response.

**Information-leak protections:** A Student requesting peer ST-2 selections and a revoked Family Principal requesting a formerly linked child must receive a **non-enumerating denial** indistinguishable from inaccessible/not found. Timetable eligibility must not expose Student IDs/individual elective records. Exams uses fixed restricted resolver: never accepts client-selected `purpose`, grant level or School context. Only approved administrative interfaces may show actionable group min/max or overlap conflict, and only for their own School/campus scope.

## 5. Idempotency and race test harness contracts (not executable)

**Canonical request identity:** `(verified_current_principal, fixed_operation_code, idempotency_key, target_school+student+enrollment+section IDs, published_revision+content_digest, expected_student_version, expected_immutable_enrollment_snapshot, effective_date/interval, sorted chosen_subject_offering_IDs, exact source_selection_IDs, reason, reviewed_approval_id_if_any)`. Actual Foundation receipt input hash and schema must be reviewed—**do not invent a new receipt table**. Retries with same key/intent return the retained result **only after fresh authorization**; changed payload produces `IDEMPOTENCY_CONFLICT`; stale approved request invalidates with one safe rejected receipt, whereas PostgreSQL unexpected error rolls back atomically.

**True two-session fixtures**, referencing [LX-01–LX-14](db04_d1_curriculum_lock_fk_concurrency_gate_20261019.md): publication vs competing school-wide/Campus publish; two students? group count race is **two commands on same Student**; D1 END/MOVE vs elective selection; archived Subject vs publication; two choice changes for same accepted head; review revocation vs apply; historical correction vs Exams snapshot capture. Use separate PostgreSQL connections, deterministic start barriers, observed `pg_blocking_pids()`/`pg_stat_activity` waits, run both winner orders, assert no deadlock/no duplicate receipt/outbox, and inspect durable history from a third fresh read. **No concurrency outcomes have been executed or observed here.**

## 6. Freeze/acceptance blockers and next task

**Approved**: CUR-01 conflict/no precedence; CUR-02 A1+B1+C1. **Still undecided**: CUR-01 applicability timing; CUR-03 group semantics/prerequisites/quotas/deadlines; CUR-04 Student/FAMILY/teacher mutation roles; CUR-05 P0/P1/P2 route/reviewer powers; CUR-06 transfer/archive grandfathering and mid-year impacts; CUR-07 immutable consumer snapshots/executor signoff; CUR-08 physical seven-entity/schema and bitemporal implementation. D1 release, Foundation permission/operation registration and cross-domain FK/lock runtime checks are also prerequisites.

**CUR-03 owner-decision package is now prepared** in [the group/prerequisite gate](db04_cur03_choice_groups_prerequisites_collision_owner_gate_20261020.md), including G-01…18 and GR-01…06. **Next:** obtain explicit CUR-03-A…E owner selections; in the meantime a safe independent DB-04-only follow-on is a date-segment/lock-conflict audit for concurrent elective changes and year rollover. No SQL.

**Disposition: DB-04 SYNTHETIC FIXTURE AND SAFE DENIAL-CODE SPECIFICATION READY; CUR-02 APPROVED, ALL REMAINING IMPLEMENTATION GATES OPEN.**
