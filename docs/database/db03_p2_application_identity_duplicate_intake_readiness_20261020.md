# DB-03 P2 — Admissions application, identity-resolution and duplicate-intake SQL-readiness

**Date:** 2026-10-20. **Status:** DESIGN / ACCEPTANCE SPECIFICATION READY FOR OWNER REVIEW. **P2 executable SQL, authenticated commands and tests NOT IMPLEMENTED or EXECUTED.** Repository `yunusyosaf399/edusync_saas_school_app`; draft PR [#102](https://github.com/yunusyosaf399/edusync_saas_school_app/pull/102), branch `db/db-03-admissions-intake-design`. Verified baseline `main df1c98d5c2d19424946986fc6ba7615202b0a443`, branch prior HEAD `0f03deeaa71c0c6f9b39712c93576577a36ea902`.

This specification concerns only **P2** (`admission_applications`, `admission_identity_resolutions`, `admission_application_transitions`) and its exact interface with **P1** application-number allocation. It does **not** create `people`, Student, enrollment, admission-finance ledger, files, approvals, Family access, or any D1 command. `student.create` remains disabled. Every new status, permission code, resolution method, timestamp/evidence field and command shape below is a **candidate**, not silently approved business policy.

## 1. Inspected sources and engineering facts vs choices

Read `AGENTS.md`, master requirements §§10–12,18,72.1 and Q62/Q63, frozen decisions/guardrails/security, [#79 proposed Admissions physical design](79_admissions_student_intake_physical_design.md), [D1 Effect36 dependency](76_domain_package_01_effect36_student_create_dependency_review.md) and [Student Creation readiness](155_d1_student_create_admissions_handoff_contract_readiness.md). Read [DB-03 initial physical design](db03_admissions_intake_physical_design_20261019.md), [atomic handoff](db03_admissions_atomic_handoff_readiness_20261019.md), [15-entity phased schema plan](db03_admissions_physical_schema_and_staged_sql_plan_20261020.md), [P1 numbering readiness](db03_p1_numbering_policy_sql_readiness_acceptance_20261020.md) and [owner decisions 2026-10-20](20261020_owner_choices_and_dependency_resolution.md). Inspected exact Foundation `people`, `principals`, `app.campuses`, `app.academic_years`, generic `approval_requests` and D1 `students` schema/lock hierarchy.

**Installed Foundation facts:**
- `app_private.people`: `id uuid`, `display_name text`, `state ACTIVE/INACTIVE/ARCHIVED`, `row_version bigint`, `created_at/by`, `updated_at`; it does **not** expose a frozen national-ID, date-of-birth or verified-identity-matching index. Name equality alone is not a uniqueness or identity proof.
- `app_private.principals` is distinct from Person and Auth; linked `principal.person_id` is **not** an automatic login, Family membership, or admission entitlement. DRAFT creation must not create a Principal.
- `app.campuses` and `app.academic_years` have real School FK/state contracts. D1 Class/Section offerings are separate, mutable academic state; School/Campus/Year/Class/Section ancestry must be checked under their existing lock order at submission/creation as appropriate.
- Existing D1 `students.person_id` is UNIQUE (one Student per canonical Person). An applicant application does not imply a Student; a previously enrolled Person cannot gain a second Student by opening a new Admissions application.
- Foundation owns live actor/permission/approval policy, idempotent `command_receipts`, audit/outbox and private-file identities. No Admissions permission or verified Person-creation/identity-match resolver is installed in current sources reviewed.

**Proposed source #79 conflict:** `admission_applications.person_id NOT NULL` even in unresolved `DRAFT`, while the source says uncertain identity can remain draft. This is **SC-01 owner choice**: recommend nullable Person in DRAFT, mandatory verified Person before SUBMITTED; alternative create/link existing canonical Person before DRAFT. These approaches cannot both be assumed frozen. Also #79 has reciprocal application→identity, application→allocation and application→handoff pointers that complicate install; P2 recommends deriving current heads from immutable child histories and using noncircular FK direction.

**Already selected (owner, 2026-10-20):** final Admissions requires Finance-confirmed clearance OR an explicitly approved waiver; no screenshot or manual flag. **P2 submission is not that final gate**: it neither asserts the fee is paid nor issues a READY handoff. DB-02's School-local roll-policy changes are unrelated to P2 application history and do not define Admissions publication dates.

## 2. Authority, identities, privacy and definition of duplicates

Terminology must remain distinct:

| Identity | Source of truth | Can P2 generate it? | Security boundary |
|---|---|---|---|
| Application UUID | DB-03 `admission_applications.id` | YES, server only, while DRAFT | no Student/Principal/portal access created |
| Person UUID | Foundation `people.id` | **NO direct DB-03 ownership**; `CREATE_PERSON` candidate only through separately approved Foundation-authorized typed operation | one canonical person across school; match is not based solely on name |
| Application number | DB-03 P1 `admission_number_allocations` | Only at accepted SUBMIT through approved P1 allocator | immutable across rejected/withdrawn attempt; server-generated |
| Admission number | DB-03 P7 accepted READY handoff | NO in P2 | never reserve at draft/submit |
| School Student ID, Student UUID, enrollment and roll | D1 | NO in P2 | disabled `student.create` remains external |
| Guardian/person relationship, FAMILY Principal, child-access grant | D1/Foundation | NO in P2 | never infer from applicant contacts |

**Real duplicate limits:** two applications resolved to the same canonical Person in the same school/academic year must not both remain in a concurrently active intake lifecycle. A partial UNIQUE on `(school_id,person_id,academic_year_id)` for live states prevents duplicate **already resolved** rows, but does not detect two unrelated Person UUIDs representing the same real child. Ambiguous identity candidates require an independently authorized human review and evidence; do not export possible matches across campus/role scopes. If the Person already has a Student, P2 may preserve an intake attempt only where a separately approved reenrollment/transfer contract permits it; **P2 must not forge eligibility or manufacture a second Student**.

**Source gap requiring identity-domain decision:** Foundation `people` does not itself store a safe canonical national-ID/DOB predicate. No approved `CREATE_PERSON`, identity-token normalization, Person merge or verified-duplicate search command was verified. Therefore P2's identity-resolution commands must **FAIL CLOSED** unless an authorized source/verified evidence process exists. Local arbitrary `match_score`, plaintext identifier in logs, applicant-name matching and `person_verified=true` client JSON are not admissible replacements. The acceptable source adapter may later provide a typed verification reference, verification result/version, matching principal/actor, institution scope and expiration. Exact source and FKs remain owner/integration decisions.

## 3. Proposed physical SQL field matrices

All three relations reside in `app_private`, with `id uuid DEFAULT gen_random_uuid() PRIMARY KEY`, default-deny `ENABLE ROW LEVEL SECURITY; FORCE ROW LEVEL SECURITY`, no direct `anon`, `authenticated`, `service_role` mutation, and no broad read of private identity/reason columns. Use FK `ON UPDATE RESTRICT ON DELETE RESTRICT`, controlled entity-specific and Foundation-derived timestamps, and no arbitrary JSON as authority. All mutable current projections use server-maintained `row_version > 0`, immutable history uses sequential aggregate revision rather than a mutable row version. **Exact relationship columns and option-dependent NULL rules are proposed.**

### P2.1 — `admission_applications` (M, protected state projection)

| Column | Proposed type/constraint | Provenance / meaningful update |
|---|---|---|
| `id` | uuid PK | server |
| `school_id` | uuid NOT NULL FK `app_private.school_profiles(id)` | immutable School project identity |
| `academic_year_id` | uuid NOT NULL FK `app.academic_years(id)` | exact target year; lock and validate school |
| `campus_id` | uuid NOT NULL FK `app.campuses(id)` | intended campus; state and school validation |
| `class_offering_id` | uuid NOT NULL FK `app_private.class_offerings(id)` | may be applicant's class *intent*, never a seat |
| `section_offering_id` | uuid NULL FK `app_private.section_offerings(id)` | optional target Section pending readiness; exact offering ancestor |
| `person_id` | uuid NULL FK `app_private.people(id)` | **SC-01**: nullable only DRAFT; active Person binding must match latest resolved identity |
| `policy_version_id` | uuid NULL FK `admission_policy_versions(id)` | populated at accepted submission, thereafter frozen unless authorized amendment with history |
| `state` | text NOT NULL DEFAULT 'DRAFT' CHECK IN ('DRAFT','SUBMITTED','IN_PROGRESS','ACCEPTED','REJECTED','WITHDRAWN','CONSUMED') | projection; optional `CANCELED` remains **unapproved** |
| `submitted_at`, `accepted_at` | timestamptz NULL | server stamps only, state-pair guards |
| `stage_epoch` | bigint NOT NULL DEFAULT 1 CHECK >0 | **NEW CANDIDATE**, bumps on changes affecting final evidence/readiness |
| `created_at`, `created_by`, `updated_at`, `row_version` | standard types + Principal FK | protected command identity; optimistic CAS |

Candidate keys/indexes: PK, `(school_id,campus_id,academic_year_id,state,created_at,id)` for scoped queue; `(person_id,academic_year_id)` for checked identity review; `(policy_version_id,state,id)` for publication references; partial **UNIQUE(school_id,person_id,academic_year_id) WHERE person_id IS NOT NULL AND state IN ('SUBMITTED','IN_PROGRESS','ACCEPTED')** (predicate is SC-01-bound). An app with `CONSUMED` is not in this index but D1 unique Person/Student blocks new Student; separate explicit reenrollment policy needed if new intake is later allowed. More conservative predicate including `CONSUMED` is possible, but could prevent valid later academic-year reenrollment only if business key changes: do not guess.

Do **not** store applicant raw national identifier, plaintext DOB/contact snapshot, password, prospective Guardian grant, wallet proof, `verified` boolean, `current_student_id`, `allocated_roll`, capacity reservation or `fee_paid` in this projection. Sensitive pre-Person applicant registration attributes are **not resolved by the existing 15-table proposal**: before adding draft PII, owner must select exact classification, encrypted/checked evidence source, retention, purpose and authorization. A DRAFT can exist as an opaque application+destination record until verified supporting intake evidence exists; this is **not** a claim that complete applicant registration UI is implemented.

**FK-cycle removal recommendation:** do not persist `application_number_allocation_id`, `identity_resolution_id`, `final_handoff_id` reverse pointers from application. Instead query authoritative unique assignment or ordered immutable head under locks. P1's `admission_number_allocations.application_id` FK installs after this table; identity/history children similarly reference this table. If performance later requires a current-head projection, its guarded version/receipt and anti-cycle proof need separate review.

### P2.2 — `admission_identity_resolutions` (H, append-only binding/correction)

| Column | Proposed type/constraint | Contract |
|---|---|---|
| `id` | uuid PK | server |
| `application_id` | uuid NOT NULL FK applications | same application for every predecessor |
| `revision` | integer NOT NULL CHECK >0 | unique `(application_id,revision)`, monotone under locked application |
| `person_id` | uuid NOT NULL FK Foundation people | canonical resolved Person, active at resolution |
| `person_version` | bigint NOT NULL CHECK >0 | server-read `people.row_version` after lock; checked at SUBMIT and READY/consume |
| `resolution_kind` | text NOT NULL CHECK IN ('MATCH_EXISTING','CREATE_PERSON') | former must prove approved matching; latter requires separately authorized Foundation Person creation |
| `verification_source_ref`, `verification_revision` | typed ID and positive bigint **candidate only** | exact source FK **not known**, so NOT deployable as unchecked arbitrary UUID; alternatively bind to verified existing file/identity proof contract after approval |
| `resolved_at`, `resolved_by` | timestamptz NOT NULL / uuid FK principals | trusted staff provenance |
| `reason_code` + restricted `reason` | controlled code/text | nonblank revision/correction reason, not broad event |
| `supersedes_id` | uuid NULL FK same table | partial UNIQUE(supersedes_id) WHERE nonnull; same-app earlier revision, no cycles |
| `created_at/created_by` | history metadata | never silently edit Person binding |

Candidate indexes: `UNIQUE(application_id,revision)`; `UNIQUE(supersedes_id) WHERE supersedes_id IS NOT NULL`; `(application_id,revision DESC)` and `(person_id,application_id)`. Protected predecessor trigger ensures revision 1 has NULL predecessor, revision N>1 follows **exactly** prior head with predecessor ID and same application; no fork/cycle; latest head is authoritative only if verified current Person version and allowed evidence source. A new resolution cannot assert another existing Person's identity merely by UUID input. An explicit `MATCH_EXISTING` lookup must use a Foundation-authorized checked service returning a narrowly scoped match reference; disclose only “verification required” outside qualified review scopes.

### P2.3 — `admission_application_transitions` (H, new proposed entity #13)

| Column | Proposed type/constraint | Contract |
|---|---|---|
| `id` | uuid PK | server |
| `application_id` | uuid NOT NULL FK applications | immutable owner |
| `sequence_number` | bigint NOT NULL CHECK>0 | UNIQUE(application_id,sequence_number); begins 1; contiguous under application lock |
| `from_state` | text NULL only initial event | initial NULL→DRAFT, afterward equals previous `to_state` |
| `to_state` | text NOT NULL CHECK against chosen state vocabulary | only owner-approved FSM edge |
| `reason_code`, `reason_private` | controlled text, optional restricted reason | no raw PII in outbox |
| `actor_id` | uuid NOT NULL FK principals | live command actor |
| `expected_application_version`, `result_application_version` | bigint CHECK>0 when present | match protected projection before/after version bump; no arbitrary version jump |
| `command_receipt_id` | uuid NOT NULL FK Foundation `command_receipts(id)` | candidate one accepted event per transition; avoid event/receipt mismatch |
| `occurred_at`, `created_at/by` | server-only stamp + Principal FK | append only, no DELETE |

Index `(application_id,sequence_number DESC)`; partial unique `(application_id,command_receipt_id)` when one command has exactly one transition. **Care:** a single accepted command may create a first DRAFT and another transition in one transaction or use distinct child outcomes; decide event ordinal model before enforcing receipt uniqueness. For now recommended contract: one state-change transition per accepted application command; internal initial creation records `NULL→DRAFT`, later `DRAFT→SUBMITTED` in another receipt. Pure identity/document amendments keep `state` unchanged, update `row_version/stage_epoch`, and use **typed revision + Foundation audit**, not fake same-state transition rows. If owner chooses to record amendment reason in this table, add typed `transition_kind` and explicitly change this invariant; no silent ambiguity.

**Projection consistency:** guarded immutable transition append and application state+row_version update occur within the same transaction; a deferred validation checks last transition `to_state` equals current projection and expected version, but only for actual state-changing commands. After a same-state amendment, the last event's version can be older; do **not** demand it equal every future application row_version without a separate design. No history deletion on terminal outcome, including rejection/withdrawal. `CONSUMED` projection changes only inside future D1 Student creation transaction under separate owner.

## 4. Status machine, optimistic revisions, and stale evidence

**Authoritative application statuses from #79:** `DRAFT → SUBMITTED → IN_PROGRESS → ACCEPTED → CONSUMED`, with terminal `REJECTED` and `WITHDRAWN` where permitted. **Proposed not frozen:** `CANCELED` terminal and exact precondition eligibility; ability to return IN_PROGRESS after material correction before consumption. Rejected/withdrawn retain identities and numbers; no arbitrary reuse. If an accepted application has an issued READY handoff, *any* correction that undermines it must invalidate READY before application state/evidence can change. After CONSUMED, Admissions never changes canonical Person/Student association; the D1 historical identity correction or enrollment workflow owns that effect.

**Derived phases only, never new P2 state enum:** “Identity verification pending”, “Documents under verification”, “Interview/test pending”, “Offer issued/accepted”, “Enrollment ready”, “Final handoff issued”. P2 does not make a final Admissions acceptance or honor a fee/waiver; P3–P7 add authentic evidence stages. `admission_handoffs.state READY/INVALIDATED/CONSUMED` belongs to P7, not application state.

| Command / transition | Candidate actor authority | Valid state/preconditions and required snapshots | Durable writes and idempotency |
|---|---|---|---|
| CREATE_DRAFT `NULL→DRAFT` | scoped `admission.application.create` staff | authenticated Principal, matching School/Campus/Year/Class intention, no Student/Person mutation; optional person NULL **SC-01** | one application + seq1 transition + successful Foundation receipt/audit; key replay returns same draft |
| RESOLVE_PERSON (same state) | `admission.identity.resolve` and actual identity-authorized helper; Person owner grants separately | DRAFT or allowed pre-consumption amendment; exact application/version+existing identity-head revision; current active Person/version, verified evidence source | append identity revision, update Person projection, bump app version + `stage_epoch`, invalidate affected future evidence atomically; receipt replay no new Person/binding |
| SUBMIT `DRAFT→SUBMITTED` | `admission.application.submit` scoped to destination | **recommended** verified current Person binding, active Person, matching latest resolution, School/Campus/Year/Offering usable, exactly one effective published policy; no competing active same Person/year; expected version; P1 number issuance | append transition, snapshot policy, allocate one APPLICATION number from P1 series, audit/outbox+receipt in one transaction; loss/rollback leaves no partial serial |
| START_PROCESS `SUBMITTED→IN_PROGRESS` | `admission.stage.record` with relevant stage permission | policy snapshotted, appropriate first stage, current application/version | one retained transition/receipt; stage outcomes from P3 onward are independent |
| REJECT `SUBMITTED/IN_PROGRESS→REJECTED` | `admission.application.decide` + approval if configured | not ACCEPTED/CONSUMED unless separate reversal policy; expected version+reason; no current READY | terminal event and receipt; number retained |
| WITHDRAW `DRAFT/SUBMITTED/IN_PROGRESS/(ACCEPTED candidate)→WITHDRAWN` | authorized operator or separately approved applicant self-service | current app/version, no CONSUMED; if READY must invalidate in one transaction under joint lock order | retained transition/reason, no Student deletion; number never recycled |
| CANCEL `…→CANCELED` | **NOT APPROVED SC-01** | independent cancellation permission, allowed origin/approval, historical reason | no SQL state or UI action until owner selects |
| ACCEPT `IN_PROGRESS→ACCEPTED` | `admission.accept` + Foundation approval | P3–P6 verified stages/offer/Finance clearance-or-waiver; SC-01/02 decide ACCEPTED before/with READY | **OUT OF P2**; no fabricated positive acceptance fixture |
| CONSUME `ACCEPTED→CONSUMED` | trusted D1 `student.create` | genuine READY handoff, current dual D1 authority, Student uniqueness+capacity+roll+Finance fence | **OUT OF P2**; atomic D1-created Student and receipt only |

**Staleness:** RESOLVE_PERSON correction after submission invalidates dependent document/stage results, offer/approval and any READY handoff; whether policy already submitted can be revised is owner choice. `person_version` is a snapshot, not lifelong identity truth; recheck current Person state/version at each authoritative gate. Even if Person row changes for an unrelated display-name correction, whether it requires fresh identity re-verification or only renewed checked snapshot is a **product/security choice**. Do not silently treat a stale `person_version` as verified; deny/route re-verification until approved reconciliation. Retain old resolution and application transition history.

## 5. Concurrency, lock ordering and strong integrity guards

**Existing D1/Frozen Foundation prefix:** READ COMMITTED, first Foundation transaction School authorization `(71001,1)` **SHARED** for D1 mutation, then Foundation command-key `(71002)`, Principal locks sorted UUID, then D1 School/allocator → Person/Student → Academic Class → Campus → Year → Class Offering → Section Offering → child histories. Application/Finance rank is **not finalized SC-06**. P2 planning must never prescribe app→School or app→Person inverted locks.

**Candidate common P2 lock DAG, pending SC-06 review:** verify active actor + canonical key/intent → Foundation auth/receipt/Principal prefix → School row/config/P1 policy and number-series anchors for SUBMIT → existing Person row (when present) → D1 academic parents in frozen order (Class → Campus → Year → Class Offering → Section Offering) → Admissions application `FOR UPDATE` → identity head/history/transition children. Resolve only the required locks and precollect school/person/destination ancestry using immutable IDs; acquire in monotonically increasing rank, re-read state/grants/versions after waits. No file/approval/Finance row may be locked after a high-ranked application child if it creates an inverse edge. School suspension/permission revocation uses Foundation first lock. **P2 SQL cannot be considered concurrency-accepted until external writers of same Person, School and application respect this DAG.**

**Important new-document geometry:** `admission_applications` depends on D1 offerings and Foundation Person/School, while `admission_identity_resolutions` depends on applications; application FK to identity head is intentionally omitted. A single School project has many Campuses: check that `campuses.school_id`, `academic_years.school_id`, and `class_offerings.campus_id/year_id` all match. D1 section FK only validates existence, not same offering or current capacity; use D1-approved ancestry guarded checks. DRAFT request to open a target Section never reserves seat. Many nullable fields are *owner decisions*: adding `NOT NULL` before gating rules are frozen could lock out valid drafts.

| Guard | Mechanism (candidate, no code installed) | Failure must leave |
|---|---|---|
| P2K01 | exact PK and RESTRICT FK `application→school/year/campus/offering/section?/Person?` + same-ancestry validator under ordered parents | no cross-School/campus/year application or wrong Section |
| P2K02 | `UNIQUE(school_id,person_id,academic_year_id) WHERE state IN (SUBMITTED,IN_PROGRESS,ACCEPTED)` with `person_id IS NOT NULL`; lock shared Person before submit/rebind | no two active **resolved** applications for same Person/year |
| P2K03 | DRAFT Person NULL allowed **only if owner selects**; SUBMITTED+ require nonnull Person, valid resolution head, current verified source, effective policy and APPLICATION number | no submitted/unverified Person |
| P2K04 | immutable `identity_resolutions` revision, same-app predecessor, ordered revision and actor/source provenance | no fork, cycle, fake verified flag or silent Person change |
| P2K05 | `application.row_version` CAS and `stage_epoch` server trigger; stage/identity changes invalidate live downstream READY under shared lock | no stale acceptance or forged current evidence |
| P2K06 | `application_transitions` contiguous sequence, from→to legality, last-event state consistency and one command receipt mapping | no untracked state changes, negative/duplicate transition |
| P2K07 | P1 `UNIQUE(application_id,number_kind)` + School/kind/render and series `FOR UPDATE`; SUBMIT owns number in same txn | no gap from rolled-back command, second app number, recycled rejected number |
| P2K08 | Foundation current actor/scoped permission, approval route, command-key canonical-intent, replay reauth and explicit checked read | no CAMPUS A actor mutation of CAMPUS B application, no receipt leak |
| P2K09 | no raw identifier, birth record, phone, signed URL, approval reason or assessment text in broad outbox | only IDs/versions/status in event envelope |
| P2K10 | immutable state/history after terminal outcome; approved transition/handoff invalidation required before withdrawal | no consumed Student removed, no number/history deletion |
| P2K11 | direct DML/public/private ACL deny; FORCE RLS; narrow executor role, schema-locked search_path and controlled SECURITY DEFINER | no owner bypass by app client/service_role |
| P2K12 | no valid Person-create/match adapter ⇒ resolution/submission fail closed; absence of typed source FK/proof prevents positive accept | no duplicate Person inferred from display_name or fabricated fixture |
| P2K13 | FK installation order P1 config/policy → P2 app → P2 identity/transitions → P1 allocation, no reciprocal app pointer | no stub Person/application or orphan number |
| P2K14 | anonymous/suspended/withdrawn/permission-revoked replay uses live Foundation actor/grant and locked School status | no previously authorized result disclosed or changed after revocation |

**SQL-review examples only, NOT executable complete DDL:**

```sql
-- Partial unique index under SC-01's proposed active-intake policy:
CREATE UNIQUE INDEX admission_applications_one_resolved_live_per_year_pu
ON app_private.admission_applications (school_id, person_id, academic_year_id)
WHERE person_id IS NOT NULL
  AND state IN ('SUBMITTED','IN_PROGRESS','ACCEPTED');

-- Stable current identity history, not an application→head FK:
CREATE UNIQUE INDEX admission_identity_resolutions_application_revision_uq
ON app_private.admission_identity_resolutions (application_id, revision);

-- Guard after verifying current actor and locking the complete parent set:
-- SELECT ... FOR UPDATE on the application, compare expected row_version.
-- Require a real verified source and Person row_version before SUBMIT.
-- Update application, allocate P1 serial, append one transition and Foundation
-- receipt/audit/outbox in the SAME transaction; never use MAX(number)+1.
```

**Pitfalls:** a partial unique index does not prevent duplicate *unresolved people* with different UUIDs; do not claim it does. `UNIQUE(supersedes_id)` permits multiple NULL roots unless first-revision and head-chain constraints are checked. FK insert/UPDATE can take hidden parent locks, so precollect and lock ancestors before child mutations. A deferred constraint trigger must not reconstruct state from an unsafe stale prelock snapshot. Force `SET CONSTRAINTS ALL IMMEDIATE` in integration acceptance.

## 6. Typed intent/result and role/scope surface (PROPOSED, NOT REGISTERED)

| Command | Minimum canonical intent fields (all server validated) | Minimal result |
|---|---|---|
| `admission.application.create` | School from server, campus/year/class/optional Section, caller idempotency key, initial draft policy/Person **per SC-01** | application UUID, state=DRAFT, version=1, receipt UUID |
| `admission.identity.resolve` | application UUID, expected app version, expected identity revision, verified source reference/version, selected canonical Person UUID (if permitted), reason code | identity resolution UUID/revision, new app version, receipt UUID |
| `admission.application.submit` | application UUID, expected app version+identity revision, snapshotted policy version, number-kind APPLICATION, idempotency key | application UUID, application number allocation UUID/rendered value, SUBMITTED, version and receipt |
| `admission.application.withdraw` | application UUID, expected app version, authorized reason, idempotency key | terminal state/version/receipt; no Student payload |
| `admission.application.reject` | application UUID, expected app version, reviewer approval evidence if configured, reason, key | REJECTED/version/receipt; no Student payload |
| `admission.application.amend` | application UUID, expected app version, typed changed destination/identity fields, required approval/revalidation reason | new version/revision and receipt; no untracked or hidden mutation |

No client may supply actor Principal ID, role name, `is_verified`, `is_paid`, `is_approved`, Student number/roll, permitted School override or resultant state. `admission.identity.resolve` is not a generic Foundation Person-creation API. The result of a guessed UUID probe should not distinguish unrelated Person existence in an unauthorized campus.

All operations use live Foundation scoped permissions, scope ALL/matching CAMPUS/matching SECTION only where registered, configured reviewers and current school state. A School-wide policy operation cannot be authorized by simply grabbing the first Campus grant. Checked list/search of applications and identity candidates needs a separate narrowly privileged read contract; exports and sensitive evidence visibility require extra grants. FAMILY, Student, unrelated teachers and applicants have no automatic view or self-service creation/approval power from these candidate commands. Any future applicant-facing create is a separate consent/auth/privacy owner choice.

## 7. P2 acceptance cases — each states exact durable expectation (not executed)

These cases require **real authenticated operations and SQL catalog**, with normal application actor and independent checker, once identity source and permission registrar exist. Positive fixture cannot fabricate `people` resolution proof or call owner-only direct inserts to claim E2E acceptance. Test false action has no accepted effect rows, counter advance, Student, receipt success or broad outbox; a separately permitted rejection receipt is not an accepted mutation.

| Case | Action and context | Required durable outcome |
|---|---|---|
| P2-A01 | authenticated scoped clerk CREATE_DRAFT | one app DRAFT with seq1 event and receipt, no Student/Person/number |
| P2-A02 | same key exact CREATE replay | same app and receipt, no duplicate event |
| P2-A03 | same key changed campus/target | canonical intent mismatch denied, no new app |
| P2-A04 | DRAFT with unresolved Person under option A | nullable Person allowed only DRAFT, no accepted SUBMIT |
| P2-A05 | attempt SUBMIT with NULL Person | denied; no APPLICATION serial/row status/history |
| P2-A06 | permitted verified existing Person matching | immutable identity resolution v1, application binding, actor evidence |
| P2-A07 | prohibited guessed Person UUID / display-name-only match | deny without unrelated Person disclosure |
| P2-A08 | attempted CREATE_PERSON without approved Foundation narrow helper | fail closed; no people/Principal/app identity event |
| P2-A09 | Person archived/inactive between resolution and submit | submit denies and no numbered application |
| P2-A10 | Person row_version changes after resolution | stale source denies or requires exact approved re-verification |
| P2-A11 | valid P1 policy+verified Person + scope SUBMIT | one immutable APPLICATION number, SUBMITTED transition, version and receipt atomically |
| P2-A12 | submitted number rendered with other School/profile | FK/check denies, no new allocation or state |
| P2-A13 | duplicate active Person+Year app attempt | exactly one accepted live app for Person/year, other fails without allocation |
| P2-A14 | same Person different academic year | only accepted under owner-approved reenrollment/retry contract; no second D1 Student |
| P2-A15 | two Persons with same display_name | no automatic merge/rejection merely because of name; require trusted match |
| P2-A16 | one real child represented by two different Person UUIDs | cannot claim prevention by partial UQ; authenticated identity review must flag or fail closed pending source |
| P2-A17 | corrected identity rebinding pre-consumption | append successor same-app identity head, bump stage_epoch, invalidate dependent accepted evidence |
| P2-A18 | illegal supersedes across different applications | FK/trigger denies, old resolution retained |
| P2-A19 | two competing resolution successors same predecessor | one valid revision/head, other denied/retry; no fork |
| P2-A20 | forged skipped history revision / mutation of old identity row | deny immutable history update |
| P2-A21 | allowed START_PROCESS | one IN_PROGRESS transition, correct from/to, receipt |
| P2-A22 | invalid DRAFT→CONSUMED or REJECTED→IN_PROGRESS | forbidden edge denied; no new event |
| P2-A23 | REJECT submitted app with authorized review | REJECTED terminal, original number retained permanently |
| P2-A24 | WITHDRAW after SUBMITTED | WITHDRAWN terminal, number remains and current stage projection not erased |
| P2-A25 | cancellation request while CANCELED not approved | fail closed; no invented state |
| P2-A26 | amend campus/year/section targeting mismatched ancestry | deny, preserve original target/version |
| P2-A27 | app tries to reserve Section seat at DRAFT/SUBMIT | no D1 enrollment/capacity/roll side effect |
| P2-A28 | out-of-scope Campus B actor on Campus A app | no read, write, export or existence leak |
| P2-A29 | FAMILY/Student applicant self-approve/rebind | deny, no Principal/Family child grant |
| P2-A30 | receipt replay by actor now revoked | deny current-authority, no protected old result |
| P2-A31 | unauthenticated/direct private DML | deny via grants/FORCE RLS, no side effect |
| P2-A32 | two accepted commands updating same expected app version | exactly one version winner; stale loser no history/number |
| P2-A33 | rollback after P1 serial increments, before append receipt | no app submission, allocated ledger, counter advance or success evidence |
| P2-A34 | preexisting D1 Student for resolved Person | P2 cannot issue D1 create; future eligibility determined by approved reenrollment path |
| P2-A35 | partial restored populated upgrade / FK validation | no identity head orphan, transition gaps, duplicate live Person/year or missing number FK |
| P2-A36 | restricted audit/outbox after submit and identity correction | IDs/versions/status only, no identity documents/national IDs/signed URLs |
| P2-A37 | current reads check actor after auth/principal suspension | no unauthorized rows/identity candidate details returned |
| P2-A38 | wrong-school campus or Year relation in draft | FK/ancestry denial even if UUIDs exist |
| P2-A39 | true verified match but current identity source proof expired/revoked | deny submit/issue until new verified snapshot |
| P2-A40 | invoke ACCEPT/READY/Student CREATE before P3–P7/Finance bridge | disabled/reject; zero Student, roll or handoff side effect |

### Observed-lock two-session race schedules (future real PostgreSQL; not mocked)

| Race | A vs B (run both commit/rollback and reverse arrival) | Required final observation |
|---|---|---|
| P2-R01 | same Person/year SUBMIT via two apps, different keys | at most one live app, one APPLICATION allocation per accepted app, failed key no new serial |
| P2-R02 | two CREATE_DRAFT with same command-key/intent | one draft and receipt; replay returns same UUID |
| P2-R03 | two RESOLVE successors from same identity head | one linear chain, no fork, stale expected head denies |
| P2-R04 | matching existing Person vs concurrent authorized Person state change | current locked Person state/version observed; no stale SUBMIT |
| P2-R05 | SUBMIT vs WITHDRAW or REJECT for same app | ordered terminal or submitted winner, never both projections/effects |
| P2-R06 | SUBMIT vs School/published policy close or change | exactly one selected current published version or denial, never unstamped mixed policy |
| P2-R07 | submitted identity rebind vs concurrent later-stage acceptance/READY invalidation | stale acceptance invalidated/rejected; no READY with previous Person binding |
| P2-R08 | two applications to same Campus/year submit and consume last proposed serial | separate numbers and correct overflow behavior, no double allocation |
| P2-R09 | permission revoke exclusive school authorization lock vs P2 mutation shared | revoke-first denies; commit-first accepted only at authorized serialization |
| P2-R10 | accepted submission COMMIT then response dropped vs exact same-key retry | one number, one receipt, stable result if still authorized |
| P2-R11 | one transaction rolls back after series and app transition work; second waits to submit | second sees original number pool; no partial rolled-back identity/history |
| P2-R12 | Person link change vs competing same-Person app / campus mutation | no duplicate active same Person/year; revalidate full FK and permissions after wait |

**Test harness protocol:** two actual PostgreSQL backend sessions with captured backend PIDs, deterministic barriers, `pg_stat_activity`/`pg_locks` blocked-wait evidence, third-session committed state inspect, both arrival orders; `SET CONSTRAINTS ALL IMMEDIATE` before terminal COMMIT/ROLLBACK; assert state, stage_epoch, Person binding, number counters/allocations, receipts, audit and outbox. Never accept a sleep-only or owner-insert forged “identity verified” fixture as positive authorization coverage. If runtime suites or permission registration are absent, label tests **NOT RUN**, not PASS.

## 8. P2 migration DAG and narrow installation plan

1. **Pre-P2 owner/security gate:** select whether DRAFT may lack Person; name an approved verified identity source/matcher and Person-creation authority, plus draft sensitive-data classification and correction/retry policy. P1 publication and number format rules require SC-01 sign-off. No typed identity proof => no positive submit.
2. **P2a schema-only (future, separately approved additive DB-03-owned migration):** `admission_applications` with FK to existing P1 policy, School/Year/Campus/D1 offerings, optional Person; FORCE RLS/no direct executor DML. No published policy or trusted app command can be assumed installed; default-deny remains.
3. **P2b immutable histories:** `admission_identity_resolutions` and `admission_application_transitions` children referencing app; strict lineage/transition guards and no reciprocal FK cycles. Verify schema works for both selected DRAFT Person rule and terminal retention.
4. **P1d allocation FK activation:** create `admission_number_allocations` *after* application exists with real `application_id` FK; enforce UQ across application/kind and School/kind/rendered. Do not create a nullable or unvalidated orphan workaround.
5. **P2c protected commands after separately approved registrar:** scoped DRAFT, typed RESOLVE with genuine source, SUBMIT with locked P1 allocator, WITHDRAW/REJECT; Foundation receipts, authorization, audit/outbox as one transaction. No global permissions, D1 SQL or Foundation edits in DB-03 branch.
6. **P2d local independent acceptance:** acceptance A01–A40 and observed races R01–R12, FK/RLS/ACL and clean/populated install/upgrade; review exact SQL/operation-registrar versions and validate application histories. Still no Student Create.
7. **P3 onward:** stage/doc verification and assessment evidence; P6 Finance verified clearance/waiver and P7 READY; D1-owned P8 cross-domain consumption after SC-02..07 and live fence approval. P2 completion never implies Admissions complete.

**Installation constraint:** existing shared Migration 10 remains a non-executable D1 `.sql.draft`, Foundation 1–9 frozen. P2 may eventually use **new DB-03-only additive candidate paths** after authorized installation slot; do not alter shared migration manifests, acceptance tracker or CI and do not apply hosted Supabase actions here. A schema-only DRAFT/transition layout may be reviewed before a verifier exists but must not accept identity resolution by arbitrary UUIDs or activate SUBMIT.

## 9. Owner decisions: precise material questions, choices and examples

| Gate | Owner question | Recommended review option (not approved) | School example |
|---|---|---|---|
| **P2-D01 / SC-01** | Must Person be verified when DRAFT is created, or may it be unresolved until SUBMIT? | **A:** DRAFT may be Person NULL; server-verified existing/create binding **required before SUBMIT**. Alternative B: no DRAFT until existing Person linked. | Parent starts Grade 5 form before school has checked the child's identity |
| **P2-D02 / SC-01** | Which source proves same real child and who may create/match canonical Person? | Only trusted protected Foundation identity adapter or recorded independent staff verification with an **approved evidence source and reviewer**; no name-only match or silent auto-merge | Two records named “Ali Khan” may be different children; one child may appear under spelling variants |
| **P2-D03 / SC-01** | After REJECTED/WITHDRAWN, may new application be opened for same Person/Year; after CONSUMED how is reenrollment handled? | Retain terminated attempt and permanent number; allow a new separately numbered retry **only under approved rule**; existing Student must use D1 enrollment process | Applicant withdraws from Nursery, applies again next term; never overwrite prior application number |
| **P2-D04 / SC-01/02** | May an ACCEPTED but not yet consumed application change Person/destination; what invalidates READY? | Require independent typed correction/approval, preserve old resolution+number; invalidate READY first; re-evaluate Finance/offer/stages | Registrar notices birth certificate belongs to another child after acceptance |
| **P2-D05 / SC-01** | Who can create/submit on behalf of parents, and is portal applicant self-service allowed? | Start with live scoped staff-only protected commands; self-service later separately reviewed with guardian/consent/identity policies | Receptionist creates draft; parent's portal view does not grant final acceptance |
| **P2-D06 / SC-06** | What approved total lock rank is shared with Foundation Person writers, P1 allocator, D1 academic owners and future Finance? | Respect existing Foundation auth+receipt and D1 School→allocator→Person→academics, then app history with joint ordered review; never lock application then School | Two clerks submit simultaneously while school policy is replaced |
| **P2-D07 / storage/privacy** | What draft identifying data is retained before a Person exists, what retention and checked read? | Do not insert unapproved PII into 15-entity app projection; owner selects private typed intake evidence/file purpose/retention and verified resolver | A paper birth certificate is PRIVATE; public search must not reveal it |
| **P2-D08 / SC-01** | When does identity verification become stale if unrelated Person display info changes? | Fail closed/reverify on mismatched Person `row_version` until approved attribute-level strategy exists | Registrar fixes spelling after identity review; acceptance rechecks source |

**No newly inferred owner approval.** SC-03 selected business rule Finance clearance or explicitly approved waiver remains intact but its verifier/waiver authority and reversal fence remain open. SC-04 D1 Student ID/capacity/roll, SC-05 typed `student.create`, SC-06 interdomain locks, SC-07 integrated acceptance stay separate dependencies.

## 10. Release/readiness statement and independently queued next task

**P2 APPLICATION / VERIFIED IDENTITY SQL-READINESS SPECIFICATION COMPLETE FOR OWNER REVIEW; NOT INSTALLED OR EXECUTED.** All P2-owned candidate columns, FKs, duplicate uniqueness, RLS/read controls, stage/version invalidations, typed command intents, SQL guard examples, 40 planned acceptance scenarios and 12 actual-backend race designs are documented. Positive identity creation/matching and submission SQL **must not be implemented under unapproved identity semantics**. No change to Person, D1 Student Creation, DB-01/02/04, Finance, Foundation, global permissions/CI or hosted database.

**Next independent task:** P3 Admissions document-link and verified stage-outcome SQL-readiness + privacy/retention acceptance (keeping Foundation file_objects ownership and SC-01 controlled stages/purposes open). Alternatively, after the owner selects **P2-D01/P2-D02** and the identity source is approved, review a **non-activating P2 schema-only additive DDL candidate** under a separately authorized migration boundary. Never force a permanent identity policy by code.
