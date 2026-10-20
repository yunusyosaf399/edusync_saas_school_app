# DB-03 P1 — Admissions numbering and policy: SQL-readiness and acceptance specification

**2026-10-20. STATUS: DESIGN / TEST SPECIFICATION READY FOR OWNER REVIEW; P1 SQL NOT AUTHORIZED, NOT RUN, NOT INSTALLED.** This is an Admissions-owned specification, not a migration. PR [#102](https://github.com/yunusyosaf399/edusync_saas_school_app/pull/102), base for this increment `b7a5bbb2f4f62fe0b583af3f1fbc309146fc2d2c`; inspected `main df1c98d5c2d19424946986fc6ba7615202b0a443`. No registered Admissions operations or permission catalog exists yet. Do not activate `student.create`.

## 1. Authority, scope and exact dependency boundary

Inspected `AGENTS.md`, master specification §§11 and 18 and decision Q62/Q63, `DECISIONS_AND_INVARIANTS`, database guardrails/security, proposed Admissions physical design [#79](79_admissions_student_intake_physical_design.md), [DB-03 schema plan](db03_admissions_physical_schema_and_staged_sql_plan_20261020.md), [atomic handoff](db03_admissions_atomic_handoff_readiness_20261019.md), D1 Effect36 dependency [#76](76_domain_package_01_effect36_student_create_dependency_review.md), D1 readiness [#155](155_d1_student_create_admissions_handoff_contract_readiness.md) and [2026-10-20 owner decisions](20261020_owner_choices_and_dependency_resolution.md). The owner confirmed admission stage configuration/history and admission-number format composed from school prefix, session and up-to-eight-digit sequence. **No explicit product-owner selection was found** for a specific prefix, start value, separator, session policy/time, permanent correction/reuse procedure, or the full published-policy effective-date contract. These remain **SC-01 choices**.

The owner **did** select financial eligibility = **verified Finance clearance OR explicitly approved waiver**; neither an uploaded screenshot nor admin-set `paid`/`waived` flag is proof. No Finance verification/waiver/reversal fence has been installed or approved; P1 may model a `fee_requirement` configuration but cannot create a clearance path. DB-02's *School-local today-only roll-policy INIT/REPLACE* and historical roll non-reuse belong solely to DB-02; **do not import that policy date into Admissions publication** or confuse application/admission numbers with roll/Student ID allocation.

P1 covers only:
- `app_private.admission_numbering_profiles` (immutable published number format revisions).
- `app_private.admission_number_series` (mutable per-profile/per-year serial state).
- `app_private.admission_number_allocations` (**referentially depends on P2** `admission_applications`; cannot be fully installed or invoked in a standalone P1).
- `app_private.admission_policy_versions` (draft/published policy revisions, selected number profiles).
- `app_private.admission_policy_stages` (ordered immutable-at-publication stages).
No new `people`, `students`, `student_id_allocator_states`, roll, Foundation approval/file/receipt/event, Finance tables, Auth accounts, or global permissions/manifest edits. **Policy configuration never directly creates an application or Student.** Both application/admission identifiers are permanent *Admissions* identifiers; D1 allocates school Student ID and roll separately.

## 2. Schema contract: five proposed P1 relations

These are column-by-column **candidate** definitions. Common foundation-like metadata must use exact installed Foundation `app_private.principals(id)` and established server-version trigger conventions rather than inventing actor identity. `school_id` denotes a campus-containing *one-school* Supabase project; not a multi-tenant claim. All UUID PKs server-generated, all private base relations `ENABLE ROW LEVEL SECURITY` and `FORCE ROW LEVEL SECURITY`; no direct client/private helper DML or unverified service-role shortcut. All FKs RESTRICT on update/delete.

### P1.1 — `admission_numbering_profiles` (versioned config, M while DRAFT, then immutable)

| Field | Type / shape | Dependency, mutability and guard |
|---|---|---|
| `id` | uuid PK default `gen_random_uuid()` | server identity |
| `school_id` | uuid NOT NULL | FK `app_private.school_profiles(id)`; immutable |
| `profile_key` | text NOT NULL nonblank | immutable family key; normalize/canonicalize under approved naming policy |
| `version` | integer NOT NULL CHECK > 0 | immutable, UNIQUE(school_id,profile_key,version) |
| `number_kind` | text NOT NULL | CHECK IN ('APPLICATION','ADMISSION'); immutable |
| `prefix`, `separator` | text NOT NULL | exact allowed characters/empty rules **SC-01**; bounded resulting value required |
| `session_format` | text NOT NULL | CHECK IN ('FULL_YEAR','TWO_DIGIT_YEAR') as **candidate from #79**, final choices SC-01 |
| `digits` | integer NOT NULL | CHECK BETWEEN 1 AND 8; max numeric component `10^digits - 1` |
| `start_value` | bigint NOT NULL | CHECK >0; publish-time `start_value <= 10^digits-1` |
| `state` | text NOT NULL | CHECK IN ('DRAFT','PUBLISHED','RETIRED'); protected one-way transitions; no direct edits to PUBLISHED configuration |
| `created_at/created_by`, `updated_at/row_version` | timestamptz/uuid and bigint | FK actor Principal, server-managed positive version |

Unique/index: `UNIQUE (school_id,profile_key,version)`; `(school_id,number_kind,state,profile_key,version DESC)`. Require all revisions of a `profile_key` to keep the same `number_kind` (locked school/profile-family check) unless explicitly approved migration to a different key. A published profile referenced by any series, policy or historical allocation cannot change prefix, separator, session format, digits, start, kind or school. RETIRED prevents selection in new publication but keeps old references readable; whether old published policy may continue using a retired format for late submission is **SC-01** and must be explicit. A new published version does not update existing issued numbers.

### P1.2 — `admission_number_series` (M counter, NOT a number identity)

| Field | Type / shape | Dependency, mutability and guard |
|---|---|---|
| `id` | uuid PK | server |
| `profile_id` | uuid NOT NULL | FK `#P1.1`, immutable |
| `academic_year_id` | uuid NOT NULL | FK `app.academic_years(id)`; same school as profile |
| `session_label` | text NOT NULL | server-derived from the chosen academic year's start date and profile's fixed session_format; immutable |
| `next_value` | bigint NOT NULL CHECK >0 | first `start_value`; only protected atomic allocation advances |
| `created_at/created_by, updated_at,row_version` | standard M contract | server-managed version and actor |

UQ `(profile_id,academic_year_id)`. Series initialization is serialized by an **approved parent lock**, e.g. School then profile/version, before checking absence and inserting. Recheck policy, year/profile school match, format validity after wait. Do not create a series for a cross-school academic year. `next_value` may be greater than max **only as an exhausted sentinel** *if* the implementation explicitly allows max+1 and guards integer overflow; otherwise store last-issued and a separate exhausted flag under a reviewed design. **No issuance** if `next_value > 10^digits-1`. Do not reseed/reinitialize after consumption. Counter is not a durable promise of gap-free externally visible numbering, and must not be computed by `MAX(allocation)+1`.

### P1.3 — `admission_number_allocations` (H allocation ledger; **P2 FK blocker**)

| Field | Type / shape | Dependency, mutability and guard |
|---|---|---|
| `id` | uuid PK | server |
| `school_id` | uuid NOT NULL | FK School; must match profile and application |
| `series_id` | uuid NOT NULL | FK #P1.2 |
| `application_id` | uuid NOT NULL | FK **P2** `admission_applications(id)`; **never remove this FK just to install P1 early** |
| `number_kind` | text NOT NULL | CHECK APPLICATION/ADMISSION; match profile kind |
| `numeric_value` | bigint NOT NULL CHECK >0 | within profile digits and >= profile start; server-reserved |
| `session_label`, `rendered_number` | text NOT NULL nonblank | immutable server-rendered from snapshotted profile+year+number; never client-rendered authority |
| `state` | text NOT NULL | CHECK ALLOCATED/CANCELED; one-way cancellation marker, never reusable |
| `canceled_at/canceled_by` | timestamptz/uuid nullable | pair shape with state and Principal FK; cancellation reason/history evidence kept separately through command/audit |
| `created_at/created_by` | common history metadata | append-preserved, no ordinary update except explicitly guarded cancellation marker |

Unique constraints: `UNIQUE(series_id,numeric_value)`; `UNIQUE(school_id,number_kind,rendered_number)` **across all profile versions**; `UNIQUE(application_id,number_kind)`. Indexed lookup `(application_id,number_kind)` is satisfied by UQ. In case of profile-collision with a rendered number from another series, allocator **must not commit** a duplicate. Whether allocator **skips collision candidates**, or fails and demands a revised format (recommended for clarity), is **SC-01**. A new handoff revision may refer to the *same* `ADMISSION` ledger row after prior handoff INVALIDATED; do not place `UNIQUE(admission_number_allocation_id)` across every handoff revision.

**Installation blocker:** the #03→P2 application FK is real; no accidental stub `admission_applications` and no `NULL application_id` workaround. Install table #03 **with P2 in a later dedicated DB-03 package** after #06 exists, unless a reviewed deferred-FK migration sequence proves strict referential integrity with no operational exposure. P1 numbering config/series can be staged independently; number allocation is not executable until P2.

### P1.4 — `admission_policy_versions` (M DRAFT, immutable published/retired snapshot)

Fields: `id uuid PK`; `school_id uuid NOT NULL→school_profiles`; `policy_key text NOT NULL`; `version integer NOT NULL CHECK>0`; `state text NOT NULL CHECK IN ('DRAFT','PUBLISHED','RETIRED')`; `effective_from timestamptz`, `effective_until timestamptz` (half-open interval); `published_at timestamptz`, `published_by uuid→principals`; `fee_requirement text NOT NULL CHECK IN ('NOT_REQUIRED','REQUIRED')` **candidate from #79, not final eligibility truth**; `application_numbering_profile_id uuid NOT NULL→#P1.1`; `admission_numbering_profile_id uuid NOT NULL→#P1.1`; common actor/timestamps/version. `UNIQUE(school_id,policy_key,version)`.

Publication-time constraints: effective_from NOT NULL on PUBLISHED, published_at/by nonnull; nonempty policy key; both profiles PUBLISHED (or exactly allowed prior publication state per SC-01), same school, and distinct number_kind APPLICATION/ADMISSION, using actual checked FK lookups. No implicitly selected “latest policy” if none or multiple effective. For any `(school_id,policy_key)`, PUBLISHED effective ranges `[from,until)` cannot overlap; adjacent is allowed. Pending owner approval: future-effective publishing vs School-local today, replacement of current open interval, whether retired version can remain effective for submitted existing applications. Published configuration fields are immutable; a one-way close of `effective_until` or `state=RETIRED` is allowed **only through an explicitly approved lifecycle transition**, not unrestricted update. Do **not** apply DB-02 roll-policy date rule to Admissions.

Indexes: `(school_id,policy_key,state,effective_from)`, UQ family/version; additional EXCLUDE / GiST only if extension and frozen temporal lifecycle support it. Otherwise protected `school_profiles FOR UPDATE` parent serialization and indexed overlap scan. Under READ COMMITTED, a plain `NOT EXISTS(overlap)` without an agreed lock **cannot** prevent concurrent overlapping publishes.

### P1.5 — `admission_policy_stages` (M DRAFT child, immutable post-publication)

Fields: `id uuid PK`; `policy_version_id uuid NOT NULL→#P1.4`; `ordinal integer NOT NULL CHECK>0`; `stage_kind text NOT NULL CHECK IN ('DOCUMENT_VERIFICATION','ADMISSION_TEST','INTERVIEW','APPROVAL','ADMISSION_FEE')`; `requirement text NOT NULL CHECK IN ('REQUIRED','SKIPPED')`; `label text NOT NULL`; optional `approval_policy_version_id uuid→app_private.approval_policy_versions(id)` only if matching configured Foundation approval route; common actor/version. UQ `(policy_version_id,ordinal)`, UQ `(policy_version_id,stage_kind)`, index `(policy_version_id,ordinal)`. Stage kinds are **controlled deployment vocabulary**, not arbitrary school SQL.

Publish must verify: ordinals are `1..N` contiguous, allowed/required stage set matches the frozen product-approved policy, approval policy has an authenticated correct operation/route when applicable, documented stage order and fee-stage consistency, no stage edit after parent becomes PUBLISHED. `SKIPPED` is **published configuration**, and actual skipped outcomes are recorded at application time in P3, not manufactured during P1. A policy row with fee requirement `NOT_REQUIRED` is **not an approved financial waiver** under the 2026-10-20 owner decision. Required Admissions fee handling cannot be implemented from P1's `fee_requirement` field alone: wait for source-owning Finance verifier and approved waiver route.

## 3. SQL-level guard catalogue and reference DDL fragments (NOT RUNNABLE MIGRATION)

Suggested constraint names P1Kxx are review labels. Exact PostgreSQL trigger functions, ACL ownership and error codes are implementation items within an approved installation boundary.

| Guard | Preferred mechanism | Proof obligation |
|---|---|---|
| P1K01 school/profile kind | guarded same-school FK/parent validation; additional composite candidate keys only on new Admissions tables | both policy profiles exist, match School and distinct APPLICATION/ADMISSION kinds |
| P1K02 published immutability | BEFORE UPDATE/DELETE protected trigger; restrict lifecycle close fields; actor scope | no edits to historical prefix, digits, fee/stages after publish |
| P1K03 published policy temporal uniqueness | same School anchor lock + bounded indexed overlap scan and/or PostgreSQL exclusion constraint with vetted extension | concurrent publishes cannot create two effective policies for same key/date |
| P1K04 contiguous stage roster | deferred constraint trigger on publish + locked stage rows; UQ policy+ordinal/kind | no holes, duplicates or illicit stages, including zero-stage policy if disallowed |
| P1K05 bounded counter | transactional FOR UPDATE on existing series; initialization under parent lock; server-version row trigger | no race loss, no out-of-range issue, after failed transaction counter unadvanced |
| P1K06 permanent number uniqueness | unique `(series_id,numeric_value)`, `(school_id,number_kind,rendered_number)`, `(application_id,number_kind)` | no duplicates across profile revisions, campuses, years, or repeated application commands |
| P1K07 cross-record ancestry | FK on series→year and guarded School equality, #03 allocation→application/policy/year consistency | wrong School/Year/Kind/Person cannot allocate; no P1-alone #03 bypass |
| P1K08 immutable render | server-only pure deterministic renderer with approved format + snapshotted session; immutability trigger and recomputation check | client JSON/prefix cannot forge a previously allocated school-facing number |
| P1K09 provenance and replay | Foundation `command_receipts` canonical intent, command-key lock and scoped current permission recheck | same-key exact replay returns same ID; changed intent denied; no new number |
| P1K10 role/RLS boundaries | FORCE RLS, REVOKE direct base DML, reviewed narrow executor; no new public registrar until separately authorized | family/student/anon/unrelated-campus actor cannot publish or allocate |
| P1K11 evidence | same transaction command receipt, audit, identifier-only outbox; accepted event code is deployment-owned | no raw Person/Finance document or signed URL in broad evidence |
| P1K12 FK/transition installation | DAG P1 config→P2 application→#03 allocation; no fake early FK, no circular relation | clean install, populated upgrade, no orphan allocation |

Examples to refine **after SC-01 is approved** (illustrative snippets, not complete SQL; do not execute from this Markdown):

```sql
-- Unique number identities must hold even across changed profile versions:
UNIQUE (school_id, number_kind, rendered_number)
UNIQUE (application_id, number_kind)
UNIQUE (series_id, numeric_value)

-- Guarded series allocator is invoked only by a protected application/acceptance command.
SELECT next_value
FROM app_private.admission_number_series
WHERE id = v_series_id
FOR UPDATE;
-- Validate version, School, profile, academic Year, digits, and all reserved render collisions.
-- INSERT retained allocation + UPDATE series.next_value + command receipt/audit/outbox
-- in ONE transaction; do not allocate via client-provided number.
```

```sql
-- Candidate state-shape CHECK, not a publication authorization policy:
CHECK (state IN ('DRAFT','PUBLISHED','RETIRED'))
CHECK (effective_until IS NULL OR effective_from IS NULL
       OR effective_until > effective_from)
CHECK (digits BETWEEN 1 AND 8)
CHECK (start_value > 0)
-- Cross-row published interval and stage-completeness need guarded locks/constraints.
```

**One subtle temporal issue:** if retiring a policy changes `state` from PUBLISHED to RETIRED, a partial exclusion index keyed only on `state='PUBLISHED'` ceases to cover historical effective intervals. Define whether retired history remains part of the no-overlap range and how new submissions select exactly one effective version; ensure revision close is retained in an approved one-way transition. Policy-effective `timestamptz` is not interchangeable with an academic-year `date` or a School-local roll business date.

## 4. Candidate protected command choreography (nothing registered yet)

No command here is approved to run; actor labels are proposed permission codes and must use installed Foundation operation+scope+reviewer grants, **not** Flutter role labels. Every writer obtains Foundation School auth SHARED advisory, command namespace `71002` key, actor/principal authorization and configured approval route before protected School/config/numbering rows; locked-source/permission recheck after waits. Complete ordered cross-package lock graph with D1 is SC-06, but P1-only mutation must not take Person/Section and later lock School.

| Candidate operation | Actor permission proposal | Row lock/order and preconditions | Atomic accepted effect |
|---|---|---|---|
| `admission.number_profile.draft` | `admission.policy.manage` | Foundation prefix → School/profile family → draft; expected version, valid kind/format | draft profile revision; typed receipt, audit; never emits number |
| `admission.number_profile.publish` | `admission.policy.publish` + configured Foundation reviewer if needed | School → all profile-family versions by version/UUID; publication predicate | freeze profile and version; same key same result |
| `admission.policy.draft` | `admission.policy.manage` | School → numbering profiles→policy family→stage child set | create/update draft + stage edits, versioned; no application/intake |
| `admission.policy.publish` | `admission.policy.publish` + scoped reviewer | School → profile refs → policy family → all stage children; no out-of-order lock | publish immutable policy snapshot with no overlap, stage completeness; receipt+event |
| `admission.application.submit` (P2) | `admission.application.submit` | only after verified Person binding, scoped current published policy, application anchor, number series+ledger lock order jointly reviewed | allocate APPLICATION number once with application state/history in same command |
| `admission.handoff.issue` (P7) | `admission.accept` + final approval | only after current stages/offer and Finance-clearance-or-waiver verified under joint fence | allocate ADMISSION number at first authorized issuance; on invalidated reissue reuse original application-owned ledger entry |

**Fundamental lock dependency:** proposed P1 numbering series must be locked before P2 application child rows if chosen global School→allocators→Person→application scheme. A command that already holds the application row and *then* requests a lower ranked series/policy lock would invert with other writers; the P1 schema can be reviewed now, but P2/P7 **effect-call ordering** requires explicit SC-06 cross-domain lock proof before enabling number-mutating commands.

No user-visible command directly accepts `numeric_value`, `next_value`, `rendered_number`, `policy_state`, payment status or stage PASSED boolean. Serial assignment is server-owned and should not be a generic public RPC.

## 5. Independent acceptance catalogue: exact expected durable outcomes

These are **future tests**, not performed. Use disposable local PostgreSQL and real registered operations after installation; do not fabricate trusted `Admissions` evidence to pretend D1 acceptance. Every positive test asserts typed receipt, no sensitive outbox, row-version, row/actor audit and FORCE RLS. Every rejection verifies **no profile/policy/series/number allocation or successful effect outbox committed** beyond separately approved durable rejection receipt semantics. Each test records exact SQLSTATE/error code after implementation.

| Case | Given/action | Expected durable database result |
|---|---|---|
| P1-A01 | scoped actor drafts APPLICATION profile v1 with approved format | one DRAFT row, positive version; zero series/allocation/Student |
| P1-A02 | publish a valid profile twice with same key/canonical intent | one PUBLISHED revision and one terminal successful receipt; replay returns same IDs |
| P1-A03 | same key with changed digits or prefix | mismatch denied; published profile untouched |
| P1-A04 | change immutable prefix/start/session after publish | protected command and privileged restricted DML denied; original retained |
| P1-A05 | publish ADMISSION profile under another school's ID | FK/scope denial; zero publication |
| P1-A06 | publish policy whose two profile references have same number_kind | denial; no published policy |
| P1-A07 | valid policy publish with complete stages 1..N and approved optional skips | exactly one immutable PUBLISHED version and stage roster; no Student/payment/grant |
| P1-A08 | publication stage order hole 1,3 or repeated kind | failed publication; draft retained unchanged |
| P1-A09 | stages changed during publish attempt | one ordered winning revision; no PUBLISHED snapshot with mixed stage heads |
| P1-A10 | publish two overlapping policies for same school/key | second denied or deterministically serialized according to finalized transition; never two effective policies |
| P1-A11 | adjacent `[t0,t1)`, `[t1,t2)` policies | only if SC-01 authorizes boundary replacement; one effective at t1 |
| P1-A12 | retire/change effective_until of published policy | only approved one-way history close, previous application snapshots unchanged; no silent policy-free gap |
| P1-A13 | publish required ADMISSION_FEE policy without known Finance adapter | configuration may be retained as a **future rule only** if owner approves; no final READY or paid proof |
| P1-A14 | attempt policy publication with fee NOT_REQUIRED claimed as waiver | no waiver evidence/READY; selected SC-03 still requires Finance clearance or approved waiver |
| P1-A15 | year from another School in series | denied; no counter and no number |
| P1-A16 | open duplicate same profile/year series | exactly one series row from UQ and locked parent; no duplicate namespace |
| P1-A17 | allocate next in-range serial after P2 installed, authenticated submission | one APPLICATION ledger row, incremented counter, application transition and receipt one transaction |
| P1-A18 | allocate the last possible `digits=1` value, then retry new application | last succeeds exactly once; next denied overflow without wrapping/reusing |
| P1-A19 | new profile revision renders same school/kind number already issued | global unique index denies collision; no duplicate even when old series closed |
| P1-A20 | two number kinds render same text for different purposes | safe because identity namespace includes `number_kind`; no accidental admission/application cross-FK |
| P1-A21 | rejected/withdrawn application with original number | history and number remain allocated; a new attempt gets a distinct number under approved SC-01 rule |
| P1-A22 | prior READY handoff invalidated, then reissued | same original ADMISSION allocation referenced by new handoff revision, no second ADMISSION number |
| P1-A23 | anonymous/client/direct DML to profiles/policy/series/allocation | denied by grants/FORCE RLS; no policy/number changed |
| P1-A24 | staff with Campus A-only authority manages Campus B's scoped Admissions policy | denied; do not infer policy scope from School single-project alone |
| P1-A25 | receipt replay after Principal permission revocation | denied current-authority check; no old protected result disclosure or number mutation |
| P1-A26 | published policy query when no effective version | explicit unavailable/deny (no newest fallback), no silent stage/fee bypass |
| P1-A27 | invalid oversized prefix/Unicode/collision formatting | policy draft validation or publish denies until approved encoding/length policy satisfied; no ambiguous render |
| P1-A28 | direct SQL calls private helper from authenticated or service_role | denied; checked app boundary only |
| P1-A29 | force deferred constraints immediate and roll back an accepted draft transaction | no durable profile, series, receipt or outbox on rollback |
| P1-A30 | verify SQL catalog and clean install/upgrade | exact new relations forced RLS, FK targets valid, no client-private EXECUTE, no edits Foundation 1–9 or D1 draft |
| P1-A31 | two applications same Person/year with distinct submitted keys (P2) | protected identity/active-app uniqueness; no two current active applications or duplicate student creation |
| P1-A32 | publish policy or profile while School S suspended / actor inactive | denied under current Foundation state/permission; no published row |

### Real two-backend schedules (future PostgreSQL, both arrival orders)

| Race | Session A vs B | Expected durable outcome / forbidden effect |
|---|---|---|
| P1-R01 | simultaneous publish same `policy_key`, overlapping effective windows | one winner or explicit compatible nonoverlap; **never overlapping PUBLISHED facts** |
| P1-R02 | simultaneous create same `(profile_id,year)` series | one row; loser replay or UQ-conflict denial; no two independent counters |
| P1-R03 | two different applications allocate next serial from one locked series | different numeric values, both committed under valid accepted transactions; no lost increment |
| P1-R04 | serial allocation rolls back after ledger INSERT and before receipt; B waits | A zero durable changes; B sees correctly retained prior `next_value`, receives one authorized number |
| P1-R05 | publisher attempts to change profile from PUBLISHED to RETIRED while submit locks referenced profile | agreed lock order, no new app issued with policy/profile that became ineligible first; historical references remain |
| P1-R06 | two changed-prefix profile versions race and would render same final number | global school/kind/rendered UQ stops duplicate; both counters must reflect only committed allocations |
| P1-R07 | submit vs published policy close/replace | either submission snapshots exactly one valid policy version at its serialization point, or rejects; never mismatched stage/profile |
| P1-R08 | approval permission revocation vs profile or policy publish | Foundation school authorization lock orders results: revocation-first denies; publish-first only accepted if authorized at its serialization point |
| P1-R09 | ADMISSION number first handoff issue vs competing issuance | one committed ADMISSION ledger entry and READY handoff; loser denial or same-key receipt replay |
| P1-R10 | identical same-key request response dropped; caller retries after successful COMMIT | same receipt, same application/serial, no new profile/number/event |

Each actual race fixture must (1) open **two real PostgreSQL backend connections**, (2) lock one verified anchor in A, (3) launch B and inspect `pg_stat_activity`/`pg_locks` for observed blocking and backend IDs, (4) release A to commit or rollback, (5) force `SET CONSTRAINTS ALL IMMEDIATE` before commit, (6) inspect outcomes in a third session; repeat reversed ordering. A sleep-only test, mocked call, or owner-forged final handoff is not acceptance.

## 6. P1 installation DAG, allowed package paths and change boundaries

This is a **plan**, not approved migration numbers; exact installation slot must be coordinated without modifying global manifests.

1. **P1a (schema-only, after format and ownership approval):** new DB-03-owned additive file(s) for profiles, series, policy versions/stages; validate FKs to existing School/Year/Principals and publication immutability; FORCE RLS/grant lockdown. No client/grant for unregistered commands; no seeded PUBLISHED policy.
2. **P1b (registration, separately authorized):** deployment-owned permission, command, scope, reviewer/receipt/event catalog additions in an approved integration registrar. **Not done in PR #102 and never smuggled into Foundation/D1 manifests.**
3. **P1c (protected policy configuration):** scoped DRAFT/PUBLISH/RETIRE commands under Foundation receipt/security and locked temporal checks; only after owner SC-01 publication/format decisions. Real approval route must exist before PUBLISH success.
4. **P2/P1d (application-coupled number issuance):** install `admission_applications` and identity lifecycle first; then add `admission_number_allocations` with real application FK, unique numbers, guarded allocator effects; test real concurrency. Do **not** create an orphan allocation table without FK.
5. **P7 (admission number at final READY):** integrated number allocation/reissue only after Finance verified clearance/waiver, final handoff and lock DAG accepted. D1 Student ID/roll integration remains P8 and other owner.
6. **P9:** local install and populated upgrade, actual authenticated acceptance, two-backend observed waits, fixed security audit; independent exact-commit CI and product sign-off. No hosted Supabase run, automatic `student.create` activation or PR merge.

**File ownership contract:** new DB-03-only `docs/database/db03_*` and future authorized additive DB-03 schema/draft/test filenames. Forbidden: Foundation migrations/tests, D1 `.sql.draft`, DB-01/02/04, Finance, `supabase/config` shared manifests, acceptance tracker, CI workflows and any hosted/production SQL. Never implement private Finance or D1 functionality to make these tests pass.

## 7. Decisions and sign-off required before executable P1 SQL

This specification resolves **engineering precision**, not any owner-policy choice.

| Decision ID | Material choice still needed | DB-03 recommended option (NOT selected) | Simple school example |
|---|---|---|---|
| P1-D01 / SC-01 | default APPLICATION/ADMISSION profile values, exact prefix and separator syntax, legal display length, normalization and session label | school-admin configurable **published immutable version** with server render and strict max length; require published valid profile before policy publish | `ABC-2026-000123` can never collide with another Campus's published number |
| P1-D02 / SC-01 | first serial and permanent cancellation/correction semantics | configurable positive start within digits; retain issued numbers forever; any exceptional correction needs own typed approved history, not edit | canceled applicant keeps `APP-2026-015`; another applicant never receives it |
| P1-D03 / SC-01 | published policy effective instant source, current/future publication, contiguous version replacement and retirement gaps | publish at trusted server instant with explicit contiguous replacement; no automatic roll-policy School-today import | Principal switches Nursery stages for admissions starting a defined date, without changing older submissions |
| P1-D04 / SC-01 | whether policy can contain zero stages, which stages are mandatory, approval order and allowed configured SKIPPED | fixed stage kinds/unique ordinals, every configured stage creates recorded outcome; independent approval if explicitly configured | Kindergarten may skip test, but still record policy SKIPPED instead of pretending PASSED |
| P1-D05 / SC-01/03 | how old `fee_requirement=NOT_REQUIRED` policy rows coexist with owner clearance-or-waiver rule | disallow NOT_REQUIRED as final readiness proof; require typed current clearance or explicit approved waiver regardless of stage skip | an owner says admissions fee is waived: only verified signed waiver qualifies |
| P1-D06 / SC-01/02 | collision on format revision, reissue of invalidated admission number, whether retired formats remain eligible | fail publication/issuance safely on rendered collision, never silently skip or reuse; reissue same application's retained ADMISSION allocation | new prefix accidentally creates the same printed number as older session; owner must choose different format |
| P1-D07 / SC-06 | one global lock order including P1 allocator, Person/application, Finance reversal, D1 school/roll | Foundation prefix → School → approved allocator parents/series → Person/academic → app/handoff/history; jointly verify before activation | second clerk submits while first creates application; no reversed School lock |
| P1-D08 / integration | migration slot, command/permission registrar, scoped reviewer policy and accepted event codes | keep schema and app commands separate from shared frozen files, enable only after independent ACL/receipt review | campus registrar can configure its own Admissions policy only if scope actually authorizes it |

**Product owner check (no signatures inferred):** SC-01 requires material numbering/session/correction/stage/publication choices. SC-02 READY/handoff reissue still pending. SC-03 financial eligibility **already selected**, implementation proof pending. SC-04 D1 allocation/capacity, SC-05 D1 P0 command, SC-06 joint lock ranking and SC-07 accepted end-to-end evidence pending. A signed P1-D01…D06 decision packet plus installation-path owner is the minimum P1 schema/command start gate.

**Outcome:** `DB-03 P1 NUMBERING/POLICY SQL-READINESS AND ACCEPTANCE SPECIFICATION READY FOR OWNER REVIEW`. P1 SQL/commands remain NOT INSTALLED; next independent DB-03 item is a **P1 schema-only, non-activating additive DDL candidate** after the exact material numbering/policy selections, otherwise independently design P2 identity/duplicate intake acceptance while waiting for SC-01.
