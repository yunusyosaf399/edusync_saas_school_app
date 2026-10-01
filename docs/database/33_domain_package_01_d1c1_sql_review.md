# D1C1 Migration 10 SQL review — working draft

## D1C1B receipt/security correction against `71b568c2402be438e56e9f2ea711d112b8d342c9`

The independent Profile re-review identified an explicitly callable
schema-owner receipt helper, JSONB-text hashing instead of frozen RFC 8785
canonicalization, and invented phase-suffixed audit event types. The current
source-only correction splits receipt access under `schoolos_evidence_writer`
from an exact ACTIVE Principal row lock under `schoolos_identity_executor`,
changes the fixed caller envelopes to canonical UUID/decimal-string versions,
serializes the restricted JCS subset before UTF-8 SHA-256, and keeps Profile
audit `event_type` at the stable operation code with phase in safe evidence.
The security review records the trigger-only owner exception and source-only
canonicalization vectors. The draft has not been parsed or executed by
PostgreSQL; D1C1B remains INCOMPLETE and Migration 10 application/D1C2 remain
unauthorized. Foundation migrations 1-9 and tests 01-09 were not changed.

**2026-09-29 continuation status:** D1C1A's structural/integrity kernel and
the separately reviewed bootstrap-manifest gate remain PASS. Commit
`ee7d9adf8718e5a9f2afb0c2c426337fd7eea5a5` is the accepted partial
D1C1B catalog checkpoint: exact bootstrap actor validation, 97 permissions,
322 scope alternatives, 36 operation contracts, and ten approved P1 reviewer
mappings. The current continuation adds static evaluator/read, explicit P1
route, private receipt-lock and one fixed P0 Academic Class command drafts,
recorded in [D1C1B security review](../security/11_domain_package_01_d1c1b_security_review.md),
including the product-owner-approved SQL-translation clarification that P1
route mode is an explicit `DIRECT`/`APPROVAL` field, never inferred from
approval-step count. Missing policy or mode denies, `APPROVAL` requires a valid
step, and P2 cannot select `DIRECT`. The product owner subsequently approved
`D1_REVIEWER_ROLE_SCOPE` as the sole D1 approval-step resolver. The draft now
validates that exact key on P1 APPROVAL/P2 policy activation and provides
private request/step-bound candidate and live reviewer-recheck predicates;
ambiguous source/destination targets fail closed pending typed workflow
commands. The latest narrow continuation adds fixed P1 direct and approval
request/review/apply paths only for `student.profile.update` and
`employee.profile.update`. The reviewer-selection key ambiguity is resolved;
all other protected commands and final RLS/ACL remain incomplete. **D1C1B is not
passed.** Migration 10 remains non-executable `.sql.draft`; D1C1C is separate
and D1C2 execution/runtime testing is not authorized. The historical
checkpoint observations below are retained to explain earlier gaps; their
older manifest counts and bootstrap mismatch do not describe the current
working draft.

**Profile workflow corrective review:** Independent review of
`7977daac5c8af273058e6f41ef3e90a232ac6888` rejected its combined final
review/apply transaction, phase-collapsed receipts, review receipt used as
application evidence, schema-owner runtime function authority, and replay
before current-read authorization. The initially blocking Profile request
participant/apply-trigger decision is now product-owner approved: current
requester visibility requires exact live request permission/scope; an OPEN
assigned reviewer requires live review authority; after closure only an
actual decided reviewer retains live checked read; explicit application may
be triggered by the requester or exact final approver only. No administrator
or background fallback is approved. The corrective draft separates final
review `PENDING -> APPROVED` from explicit later `APPROVED -> EXECUTED` or
deterministic `INVALIDATED`, fixes `request.submit`/`request.review`/
`request.apply` receipts, and assigns runtime functions to the reviewed
authorization, workflow, typed domain, read and evidence roles. The
application row points to the distinct successful apply receipt. This is
**under independent corrective review**; it does not mark overall D1C1B
PASS. Frozen D1C1A integrity, bootstrap, reviewer resolver, 97/322/36
manifest vocabulary and Migration 10 `.sql.draft` boundary remain intact.
The source-only Foundation guard returned `FOUNDATION_SOURCE_PASS 9 migrations
+ 9 tests` and `LOCAL_CONFIG_PASS`; staging validation returned
`STAGING_VALIDATE_PASS`; `git diff --check` found no whitespace error. No D1
SQL was parsed or executed, and no Supabase project was contacted.

**Later D1C1A note:** [Review 35](35_domain_package_01_d1c1a_integrity_review.md) records the subsequently drafted structural and integrity kernel. The missing-trigger statements below describe this earlier checkpoint, not the current unexecuted `.sql.draft`; the D1C1B authorization/command and D1C2 runtime gates remain open.

**Later bootstrap-manifest clarification:** The product owner subsequently froze the deployment-bootstrap actor in the [versioned manifest](../../supabase/config/foundation_bootstrap_manifest.json): UUID `3e0e0b72-762c-44e1-b7eb-98dcc449643a`, `kind=SYSTEM`, `system_purpose=deployment-bootstrap`, `state=ACTIVE`. The earlier draft used `system_purpose='bootstrap'`; the accepted `ee7d9ad...` checkpoint corrected the lookup to require both exact UUID and purpose. The current D1C1B continuation preserves that correction.

**Status: INCOMPLETE WORKING DRAFT — NOT AUTHORIZED FOR APPLICATION.** This record tracks the local D1C1 translation from approved D1B3B baseline `e71d3be34f55235c18255795f32dfb6f09a2b182`. Commit `146174fa5e14b1728d6ee9e5b3353faed9071cab` is an incomplete D1C1 checkpoint, not a pass. No SQL has been applied, no Supabase project has been contacted, and no D1C2 test has been created. The working file uses the non-executable suffix `supabase/migrations/20260928000000_domain_package_01.sql.draft` so an ordinary CLI migration scan cannot select it.

## Profile workflow implementation gate (static only)

This section records the historical `7977daac` implementation snapshot,
which the independent review above rejected. Its description of same-
transaction final apply is not the current corrective draft contract.

The continuation from `14292465063a33bc975f69aed0466c2b98f0563d`
implements the reusable P1 workflow pattern for exactly two fixed operations.
The public command inventory added by this gate is
`app.d1_change_student_profile`, `app.d1_submit_student_profile_update`,
`app.d1_change_employee_profile`, `app.d1_submit_employee_profile_update`,
and `app.d1_review_profile_request`. No other business effect is added.
Private helpers perform fixed profile-payload validation, exact live
requester/reviewer grant and scope checks, active policy selection, direct
mutation, request submission, retained review-evidence checks, and final
apply. They are not executable by `authenticated` or `service_role`.

Direct calls require the reviewed explicit `DIRECT` policy, complete current
request authority, an expected ACTIVE target/version and the existing
Foundation receipt-key lock after the SHARED authorization lock. Approval
submission requires the explicit `APPROVAL` route and creates DRAFT,
SUBMITTED and PENDING Foundation states, immutable transition evidence,
snapshotted sequential steps, an OPEN first step, and exact
`D1_REVIEWER_ROLE_SCOPE` candidate rows. A zero-candidate first or subsequent
step raises an error and rolls back that whole action. Review locks the
current assignment and step, rechecks current eligibility and request
version, records the fixed APPROVE/REJECT decision, then progresses one step
or terminates. Final approval rechecks every reviewer, the requester and
target after locks; stale state or authority invalidates the request without
mutation. A valid final step records APPROVED to EXECUTED and an application
row in the same transaction.

Only the reviewed Student PROFILE columns and Employee core-row photo link
are updated. Existing profile-photo purpose/AVAILABLE triggers still run;
upload/download authorization remains with the file service. The direct and
approved Student effect alone emits `student.profile_changed`. Employee
Profile writes safe audit evidence without inventing an outbox event.
Foundation receipts bind exact principal/operation/key to a typed canonical
intent; changed intent conflicts and successful replay returns the stored
result. Broad audit/outbox data contains only identifiers, route, decision,
state, version and correlation. Private request snapshots and review reasons
are not copied into broad evidence. All of this remains unexecuted draft SQL;
neither PostgreSQL parse correctness nor non-owner runtime behavior is
established by source checks. Static registrar extraction at this gate found
97 distinct permission IDs, 322 distinct scope-alternative IDs and 36
distinct operation IDs. Source inventory found five new public Profile
functions, eight new private helpers, 86 total SECURITY DEFINER declarations,
205 policy declarations and 34 D1 FORCE RLS statements. The Foundation guard
returned `FOUNDATION_SOURCE_PASS 9 migrations + 9 tests` and
`LOCAL_CONFIG_PASS`; staging validation returned `STAGING_VALIDATE_PASS`;
`git diff --check` reported no whitespace errors. The draft was not
executed and no Supabase project was contacted.

## Bootstrap attribution boundary

Migration-time D1 catalog insertion was rejected because the Foundation permission, scope-contract and operation-contract rows require a trusted `created_by` Principal. The Foundation bootstrap SYSTEM actor is created after structural migrations on a fresh school project. The approved sequence is Foundation migrations 1–9, structural Migration 10, Foundation bootstrap, trusted D1 registration, D1 non-owner tests, then separately approved activation. Migration 10 must not create a SYSTEM Principal or call its registrar. The working draft defines a private `d1_register_catalog_v1()` owned by `schoolos_bootstrap_executor`: it requires exactly one ACTIVE SYSTEM Principal with bootstrap purpose, takes authorization lock `(71001,1)` exclusively, and uses preassigned manifest UUIDs. New permission, scope and operation rows start disabled; exact replay is a no-op and incompatible code/UUID/classification/contract collisions raise an error. It does not create grants or assignments. This is a structural definition only, not execution evidence.

## Drafted objects and static counts

At that earlier checkpoint, the file described 34 new private D1 relations in the reviewed dependency order; 34 UUID PKs, 21 full candidate unique keys, 3 partial unique indexes, 34 row-local CHECK bundles, 47 D1 secondary indexes, 34 FORCE RLS tables, five NOLOGIN D1 executor roles, and the three typed authorization target columns/FKs on `assignment_permission_scopes`. It extended the Foundation scope-kind checks and typed target shape, immutability and overlap guards without changing `has_complete_grant(text,text,uuid)`. It also contained an initial private D1 evaluator, defensive record and file-purpose triggers, role-specific internal policies/grants, the then-current private post-bootstrap manifest (87 permissions, 297 scope alternatives, 36 operation codes), and a private 32-code event vocabulary function. Those historical counts are not the current manifest baseline. None is a live PostgreSQL count or evidence of correct execution.

The current draft has **not** implemented the complete approved D1B2/D1B3 runtime contract and must not be renamed to `.sql`, applied, reviewed as ready, or committed as a completed D1C1 migration yet. Specifically:

1. Cross-row temporal overlap, same-parent supersession, sorted lock order, ancestry/eligibility, capacity breakpoint counts and persistent roll namespace checks remain to be implemented and independently reviewed. The row-local CHECKs and FKs alone cannot enforce them.
2. Deferred same-transaction Student status, enrollment-roll, capacity-revision and override completeness checks are absent.
3. The current private evaluator needs full target-state, historical and resolver-path review. Its presence is not proof that every allowed and denied D1B3B path is implemented.
4. Four fixed academic checked-read surfaces are now present in the working draft, but the remaining reviewed read families and all 36 protected command families are absent. No command receipts, approval apply path, redacted audit/outbox writes or command-level reauthorization are installed.
5. The file-purpose trigger checks the three approved purpose codes and AVAILABLE state on a new link, but typed ownership, current entitlement and upload/download authorization remain separately gated by the reviewed file service.
6. Foundation has no generic event-registry table. The draft's event vocabulary is a private function, not a worker registration or permission to publish events. This needs explicit review with the eventual evidence writer.
7. **Subsequently resolved by the manifest and `ee7d9ad...` checkpoint:** The approved bootstrap identity is UUID `3e0e0b72-762c-44e1-b7eb-98dcc449643a` with `system_purpose='deployment-bootstrap'`. The registrar now requires exact UUID **and** purpose, exactly one ACTIVE SYSTEM Principal, and fails closed on absence, mismatch or ambiguity. Foundation migrations do not seed the actor; trusted bootstrap creates it after structural migrations.
8. Foundation `operation_contracts.requires_approval` is a Boolean. The P1 school-configurable choice and retroactive teaching P0/P2 split must be enforced by fixed policy/apply code before any operation is enabled. The manifest deliberately leaves every D1 operation disabled.
9. `student.create` depends on a verified final Admissions handoff from a later package. Pending a product-owner clarification, the conservative D1C1 working assumption is that this entry point remains unavailable until the handoff exists; Migration 10 must not fabricate an Admissions allocator or label a denial-only placeholder as a completed command.

## Local evidence and next work

### Historical focused static review findings

The bullets in this subsection describe the early incomplete checkpoint and
are retained as review history. Later D1C1A, bootstrap, Profile and Academic
continuation sections supersede their then-current absence claims.

- The earlier checkpoint contained no D1 protected command function, command-key lock, `pg_advisory_xact_lock_shared(71001,1)`, command-receipt write, approval apply call, audit write or outbox write. The current continuation adds a private receipt lookup and one fixed Academic Class command, but the remaining command/workflow paths are absent. The five D1 executor roles still have provisional direct private-table INSERT and selected UPDATE grants with `USING (true)` / `WITH CHECK (true)` policies. These grants are not an acceptable final protected-command boundary.
- There is no cross-row D1 trigger or deferred constraint trigger. For example, the draft has no parent-locked primary-enrollment overlap/capacity check, no same-transaction initial Student status requirement, and no roll-allocation coverage check. The row-local CHECK bundles and partial unique indexes do not close these gaps.
- The checkpoint version of `d1_authorized()` required exactly one effective PRIMARY enrollment before it could authorize *any* `STUDENT` target. The working correction allows Student-self or current FAMILY-child resolution without placement where the permission can apply to retained facts, while current ROSTER/PROFILE and direct staff scopes still require a placement; more than one effective PRIMARY placement denies. This is a static correction only. Other permission-specific target-state rules, historical placement interpretation and every fixed resolver/read projection still require full review.
- The post-bootstrap registrar is only a structural proposal. It has not been parsed or run. The subsequently approved manifest now establishes the stable bootstrap actor UUID and `deployment-bootstrap` purpose, but the SQL draft has not yet been corrected to match both. Its disabled catalog rows do not authorize calling the absent commands.

These are design and implementation blockers, not failed PostgreSQL assertions. The draft must remain outside the executable migration set until they are corrected and independently reviewed.

The current worktree also normalizes six creation-block comments and constraint-name prefixes to the frozen catalog numbers: `roll_allocations` 10, `students` 11, identity 12, special 13, status 14 and enrollments 15. Creation order remains dependency driven; the existing CHECK/policy numbering already followed the catalog.

Static privilege review found that the checkpoint attempted to create `d1_authorized()` as `schoolos_authz_reader` after Foundation had revoked that role's `CREATE` on `app_private`. The working draft now temporarily grants schema `CREATE` immediately before that function's creation and revokes it immediately after, matching the Foundation helper-install pattern. This repair has not been executed or proven by PostgreSQL.

A read-only static extraction found 87 distinct permission codes/UUIDs, 297 distinct `(permission,scope_kind,resolver_key)` alternatives/UUIDs, and 36 distinct operation codes/UUIDs in the three registrar value lists. The 297 scope alternatives match the 87 declared support-set abbreviations in the draft. This does not validate SQL parsing, registrar behavior or the permission semantics of any read/command.

The draft now defines four partial typed `app` checked reads for Academic Class, Subject, Class Offering and Section Offering. Each has an explicit result column list, fixed permission code, stored target lookup and a narrow `authenticated` EXECUTE grant. The reader role receives schema `CREATE` only for function installation. These four functions have not been PostgreSQL-parsed or exercised under a non-owner role and do not constitute full D1B3B read coverage.

Current read-only source counts, including the new partial functions, are 34 D1 `CREATE TABLE`, five new roles, 34 `FORCE ROW LEVEL SECURITY`, 193 `CREATE POLICY`, 12 `CREATE FUNCTION`/`CREATE OR REPLACE FUNCTION`, four `app.d1_read_*` functions, 49 triggers, 34 named D1 CHECK bundles and 52 `CREATE INDEX` statements. The 52 comprise the selected 47 D1 secondary indexes, three partial unique indexes and two typed-scope lookup indexes. These are lexical counts, not PostgreSQL catalog results; several functions and checks still required by D1C1 are absent.

`python tools/supabase/foundation_guard.py --future report` reported `FOUNDATION_SOURCE_PASS 9 migrations + 9 tests`, `FUTURE_MIGRATIONS_PRESENT`, and `LOCAL_CONFIG_PASS` while the file had a `.sql` suffix. After moving the incomplete file to `.sql.draft`, the default `python tools/supabase/foundation_guard.py` reported `FOUNDATION_SOURCE_PASS 9 migrations + 9 tests` and `LOCAL_CONFIG_PASS`. This validates only the frozen source/config boundary. The working draft has not been SQL-parsed by PostgreSQL, applied locally or remotely, linted, or tested under non-owner roles. Foundation migrations and database tests 01–09 remain untouched.

Finish and statically review the SQL against all D1B2/D1B3 contracts before creating the final Migration 10 `.sql`, then update this record with the actual object inventory and validation. D1C2 later covers clean install and upgrade sequencing, registrar exact/no-op/collision behavior, runtime non-owner security and regressions. No corrective D1C1 completion commit has been made after the incomplete checkpoint.

## Academic P0 family continuation from `bb2b7a8` (static only)

The working Migration 10 `.sql.draft` now contains all six reviewed Academic
P0 command entry points. The existing Class command was re-reviewed and its
broad direct Foundation receipt/audit/outbox inserts were replaced by fixed
evidence helpers owned by `schoolos_evidence_writer`. Its frozen
create/update/archive fields, receipt-before-Principal-lock ordering,
post-lock SCHOOL authorization, expected ACTIVE version, stable audit code and
selected Class outbox code otherwise remain intact.

Five additional typed commands implement Subject create/profile-update/archive;
Class Offering create/state-update/archive; Section create/profile-and-state
update/archive; retained Section Room add/end/correct; and typed Class/Section
capacity change. Offering and Section create append the initial capacity
revision required by the existing deferred D1C1A completeness trigger.
Capacity change updates the parent projection and appends its matching
revision under the same locked transaction and command receipt. No command
changes an ancestry key, deletes retained history, mutates an Enrollment, or
creates a capacity override.

The public Academic command signatures are owned by
`schoolos_academic_executor` and granted only to `authenticated`. Three
private Academic evidence helpers are owned by `schoolos_evidence_writer`,
explicitly unavailable to PUBLIC/anon/authenticated/service_role, and callable
only by the Academic executor. The Academic executor no longer has receipt,
audit or outbox INSERT. Its Academic table privileges are explicit column
grants for these six effects. The shared current-Principal and authorization
owners remain `schoolos_identity_executor` and `schoolos_authz_reader`.

The fixed receipt lookup accepts the new five operations only when command
kind equals operation code and the positional intent has its exact approved
shape. The JCS object-key language was not expanded. The six audit event types
remain the stable operation codes, and the only Academic outbox codes are the
six frozen `_changed` codes. Profile workflow code and behavior were not
changed; its evidence policies were merely shared through the same evidence
writer table boundary rather than duplicated.

This brings the drafted effect count to eight of the 36 registered operation
contracts: six Academic P0 effects plus Student Profile and Employee Profile.
Exactly 28 operation effects remain, including the intentionally unavailable
`student.create`. D1C1B therefore remains incomplete and is not approved for
application. Migration 10 remains a `.sql.draft`; no SQL was parsed or
executed and no Supabase project was contacted by this continuation.

The final source-only checks for this continuation returned
`FOUNDATION_SOURCE_PASS 9 migrations + 9 tests`, `LOCAL_CONFIG_PASS`, and
`STAGING_VALIDATE_PASS`; `git diff --check` found no whitespace error. A fresh
registrar extraction found 97/97 permission rows, 322/322 scope-alternative
rows and 36/36 operation rows, all unique. A fixed-function inventory found
exactly the six Academic public command entry points and no Academic command
body with direct receipt/audit/outbox INSERT. These are static findings, not
PostgreSQL parse or runtime evidence.

## Academic parent-lock and capacity correction

Independent review of `f1c2a63b660554fec06ba24afcfc1d0c909d9b44`
correctly rejected the Foundation parent lock proof: `UPDATE(id)` privilege
alone did not make a locking SELECT pass forced RLS. The corrected draft adds
an Academic-executor UPDATE policy alongside SELECT policy for each of
`school_profiles`, `campuses`, `academic_years`, and `rooms`. Each relation
retains only its reviewed SELECT columns plus `UPDATE(id)`; the role is
NOLOGIN and only the six fixed SECURITY DEFINER Academic commands use it.
Those commands contain no Foundation UPDATE, so this grants row-lock ability
without a mutable Foundation business column. Private D1 target tables already
pair their explicit SELECT/UPDATE column grants with executor SELECT/UPDATE
policies. The current Principal remains separately locked by the identity
executor and its reviewed SELECT plus UPDATE(id) policy pair.

The same review found that capacity reduction discarded one aggregate count.
The corrected command now enumerates the requested effective date and every
accepted PRIMARY Enrollment start/end breakpoint from that date forward,
then computes the half-open interval occupancy at each point while holding the
Class Offering and applicable Section anchors. Class scans include all child
Sections; Section scans remain exact. ACTIVE, COMPLETED and ENDED accepted
rows count only while effective, including future accepted commitments. The
result is a stability recheck, not a new rejection rule: existing commitments
may remain above the lower projection and are neither rewritten nor given an
automatic override. Only `placement_state` was added to the Academic
executor's already narrow Enrollment SELECT grant; it has no Enrollment DML.

This correction preserves all six command signatures, receipt sequencing,
Canonicalization V1, evidence-writer helpers, stable operation audit types,
six selected outbox codes, Profile workflow and retained Section Room HE
behavior. It introduces no operation or operation family. D1C1B remains an
incomplete, non-executable draft pending independent re-review and D1C2.

The correction's source-only checks returned
`D1C1B_ACADEMIC_LOCK_AND_CAPACITY_STATIC_PASS`, 97/97 unique permission rows,
322/322 unique scope-alternative rows, 36/36 unique operation rows,
`FOUNDATION_SOURCE_PASS 9 migrations + 9 tests`, `LOCAL_CONFIG_PASS`, and
`STAGING_VALIDATE_PASS`. `git diff --check` found no whitespace error. These
checks do not establish PostgreSQL parse or runtime correctness; the draft was
not executed and no Supabase project was contacted.

## Immediate-only Academic capacity effective date

The product owner subsequently froze `academic.capacity.change` as an
immediate-only P0 command for new execution. Commit `d952c88b...` placed the
`p_effective_on IS DISTINCT FROM CURRENT_DATE` predicate in initial validation;
independent review correctly rejected that placement because it prevented an
exact successful receipt from replaying after the original calendar date.
That commit is not treated as a passed replay design.

The corrected initial block performs syntactic validation only and still
denies a NULL effective date. Receipt lookup then arbitrates Principal,
operation, idempotency key and the unchanged canonical intent. After the
Principal and Academic hierarchy locks and fresh target authorization, an
exact `SUCCEEDED` receipt returns its stored result. Only the no-receipt/new
path then applies `p_effective_on IS DISTINCT FROM CURRENT_DATE` and denies a
past or future date before version validation or effect. There is no
backdated, scheduled or alternate approval path, and the command does not
normalize a caller-supplied date to the server date.

The accepted `p_effective_on` remains in the Canonicalization V1 positional
intent and is inserted unchanged into `capacity_revisions.effective_on` in
the same transaction that changes the parent capacity projection. A replay
with a different supplied date therefore remains a different intent and
conflicts during receipt lookup rather than being rewritten to match. An exact
same-intent replay can cross a calendar-date boundary, but only after the
current Principal is verified, locked, and freshly authorized for the locked
target; its stored result returns without a second mutation, revision, audit
or outbox event. The reduction path still evaluates
the current date plus every retained accepted PRIMARY Enrollment start/end
breakpoint from that date forward, preserves half-open interval semantics and
does not rewrite or invalidate existing commitments when occupancy exceeds
the lower projection. No operation, table, queue, job or workflow was added.

D1C1B remains incomplete. Migration 10 remains a non-executable `.sql.draft`;
this clarification does not authorize D1C2 or migration application.

## Employee organization catalog P0 family continuation (static draft)

The working Migration 10 `.sql.draft` now drafts exactly two additional
operation effects: `employee.department.change` and
`employee.designation.change`. Their fixed public entry points are
`app.d1_change_employee_department` and
`app.d1_change_employee_designation`, both direct P0 commands. Each accepts
CREATE, UPDATE, or ARCHIVE. Create writes a generated ID, school, stable code,
label and actor. Update changes only label. Archive changes only state,
archive timestamp and archive actor. Stable code and school ancestry are
checked against the locked target and cannot be changed. Existing updates and
archives require the expected row version. No DELETE, historical
job-assignment rewrite, or authorization mutation is performed; retained
Department/Designation references remain intact and the frozen history trigger
remains the future-use defense.

Both commands use only the registered `ALL`/`DIRECT` permission scope and
resolve it through the School target using the live
`employee.department.manage` or `employee.designation.manage` chain. The
fixed receipt lookup allowlist admits only these two operation-equals-command
pairs with six-position typed intent arrays; the shared Canonicalization V1
serializer and JCS object-key language are otherwise unchanged. New fixed
receipt/audit append helpers are owned by `schoolos_evidence_writer` and
allowlist only these two operation codes. The Employee executor has no direct
receipt/audit/outbox INSERT. Audit `event_type` is exactly the stable operation
code; bounded action/state/version data is placed in safe details. No selected
outbox event exists for these operations, so none is emitted.

Department and Designation executor SELECT/INSERT/UPDATE grants are
column-scoped. The Employee executor receives only `SELECT(id)` and
`UPDATE(id)` on the School parent for fixed row locking, paired with
role-specific SELECT/UPDATE RLS policies; the command issues no School update.
Authenticated receives EXECUTE only on the two public RPC signatures. Private
helpers explicitly revoke PUBLIC, anon, authenticated and service_role
EXECUTE. No unrelated Employee, Student, Family or Teaching mutation grant is
added by this continuation.

This brings the drafted effect count to **10 of 36** operation contracts:
six Academic P0 effects, two Profile effects, and these two Employee
organization-catalog effects. **26 operation effects remain**. This is static
draft work only: D1C1B remains incomplete, Migration 10 remains non-executable,
and neither PostgreSQL parse/runtime correctness nor independent review is
claimed. Static extraction reconfirmed 97 unique permissions, 322 unique
scope alternatives and 36 unique operations; source assertions confirmed the
two P0/direct mappings, exact scope sets, fixed command order, evidence ACLs,
and absence of any additional public operation effect. The Foundation guard
returned `FOUNDATION_SOURCE_PASS 9 migrations + 9 tests` and
`LOCAL_CONFIG_PASS`; staging validation returned `STAGING_VALIDATE_PASS`;
`git diff --check` found no whitespace errors. SQL was not executed and no
Supabase project was contacted.

## Employee create P0 operation continuation (static draft)

The product owner approved the previously unresolved create contract. The
single public entry point is
`app.d1_create_employee(p_person_id uuid, p_employee_code text,
p_effective_from date, p_idempotency_key text)`, for fixed operation and
command kind `employee.create`. It accepts no state, end date, reason or photo
argument. The code is required nonblank and is stored exactly as supplied; the
joining date is required and a new execution denies dates after `CURRENT_DATE`
without replacing the caller's date.

The Employee INSERT is limited to `person_id`, `employee_code`, fixed
`current_state='ACTIVE'`, fixed `profile_photo_file_id=NULL`, and verified
`created_by`; ID, version and timestamps use server defaults. In the same
transaction exactly one initial `employment_periods` row is inserted with the
new Employee ID, fixed `state='ACTIVE'`, caller's `effective_from`,
`effective_until=NULL`, fixed `reason='INITIAL_EMPLOYMENT'`,
`supersedes_id=NULL`, and verified `created_by`. The period ID/creation time
are server defaults and end metadata remains NULL. No photo purpose is
activated. The existing deferred Employee/history completeness triggers and
HE/effective-history guards are unchanged; failure to create either row or
evidence rolls back the whole transaction.

The fixed order is receipt lookup (SHARED Foundation lock and namespace-71002
key lock), verified Principal row lock, School anchor lock, exact existing
Person row lock, replay Employee row lock when applicable, fresh live
`employee.create` authorization, then new-command date/uniqueness checks,
Employee insert, initial history insert and evidence append. Unique Person and
Employee-code constraints remain the race-safe final defenses. Person receives
only SELECT(id,state) and UPDATE(id) lock capability with matching RLS; no
Person column is mutated.

The fixed receipt allowlist adds only `employee.create` with a three-element
intent containing canonical Person UUID, exact Employee code and ISO joining
date; operation/version/Principal/command-kind/key remain in the standard
Canonicalization V1 outer envelope. Existing successful replay locks the
same Person and stored Employee, checks the Employee still matches the pinned
Person/code, then reauthorizes before returning the stored Employee ID/version.
Replay bypasses new-execution date validation and appends no duplicate rows or
evidence. Changed intent conflicts under the same key.

Dedicated `schoolos_evidence_writer` helpers append the fixed receipt, audit
and outbox. Audit event type is `employee.create`; the selected outbox event
is `employee.created` with only Employee ID, ACTIVE state and row version.
No authorization provisioning or other domain side effect is performed.

The drafted effect count is now **11 of 36**: six Academic P0 effects, two
Profile effects, two Employee organization-catalog effects, and
`employee.create`. **25 operation effects remain**. This remains static draft
work; D1C1B is incomplete, Migration 10 remains non-executable, and no SQL was
executed or Supabase project contacted.

## Employee Person-state eligibility clarification (static draft)

The product owner approved current Person state as a new-execution eligibility
rule. After receipt arbitration, Person locking and fresh `employee.create`
authorization, the no-receipt path requires the locked Person state to be
`ACTIVE`. `INACTIVE` and `ARCHIVED` deny with the deterministic error
`D1 Employee Person is not active`. The command reads only Person ID/state
and does not mutate the Person. This does not change the approved ACTIVE
Employee/period fields, joining-date semantics, history, audit or outbox.

The check follows the exact successful-replay return branch. Replay still
requires current `employee.create` authority and verifies the stored
Employee/Person/code binding, but does not require Person to remain ACTIVE.
It creates no duplicate Employee, history or evidence. Later Person state
changes do not retroactively invalidate or alter the Employee. The Person
executor grant is only SELECT(id,state) plus lock-only UPDATE(id), with no
Person-state mutation privilege. Manifest counts and the 11/36
implemented-effect count are unchanged. D1C1B remains incomplete; Migration 10
remains non-executable and no Supabase remote operation was performed.

## Employee state P1 operation continuation (static draft)

The draft now implements the single `employee.state.change` effect with
explicit DIRECT/APPROVAL routing. The direct and submission intents bind the
Employee, requested state, expected version and exact private employment
reason. The effect date is never caller input: execution uses its own
`CURRENT_DATE`, while successful replay returns stored result evidence without
recomputing or repeating the effect.

The closed transition graph is ACTIVE→INACTIVE, ACTIVE→ENDED,
INACTIVE→ACTIVE, INACTIVE→ENDED and ENDED→ACTIVE. Same-state and
ENDED→INACTIVE changes deny. The locked Employee must have exactly one open
current employment period whose state matches the projection and whose start
precedes today. The effect closes it at today, appends a new open period with
the exact protected reason, and synchronizes the projection atomically.
Rehire appends history and never reopens an earlier period. Person state is
not consulted.

INACTIVE and ENDED effects precollect every remaining Teacher capability,
Class Teacher assignment and Subject Teacher assignment. Future-starting rows
and bounded rows extending beyond today deny. Only open rows that started
before today are closed; their original reasons remain unchanged. Fixed cause
`EMPLOYMENT_STATE_CHANGE`, safe IDs and counts appear only in minimized
evidence. Reactivation recreates no Teaching authority. Job assignments and
campus affiliations are untouched.

Global authorization derives the current affected-campus union from live
affiliations and live teaching assignments. ALL covers the operation;
otherwise every campus needs a complete exact CAMPUS grant, while an empty
set requires ALL. The state-specific policy selector applies campus-over-
school precedence for every affected campus and requires one common policy
ID and one explicit route. Apply rechecks requester authority, reviewers,
policy, target version and the current campus set.

The corrective apply draft now separates deterministic effect eligibility
from mutation. After the APPROVED request and Employee are locked, stale
target/policy/requester/reviewer facts, invalid transitions, missing or
ambiguous current periods, projection mismatch, same-day or bounded periods,
and same-day/future/bounded-future Teaching dependencies return bounded error
codes. Apply records one REJECTED `request.apply` receipt, safe audit and one
`APPROVED` to `INVALIDATED` transition, with no domain write or application
row. Unexpected SQL, integrity, deadlock, timeout and infrastructure failures
are not caught and therefore roll back with the request still APPROVED.

Preflight holds the same Employee, sorted academic ancestry and child-history
locks through the effect. The effect defensively revalidates under those locks
and requires the dependency closure to remain exact before mutation. The new
checked `app.d1_read_employee_state_request(uuid)` returns only request ID,
version/state, Employee ID and old/requested state. It excludes the private
reason and arbitrary JSON. Current requester authority or a legitimate,
separate workflow reviewer with current exact approval role/scope is required;
there is no generic administrator read path. The trigger-only Employee-state
application guard requires the same request/operation and successful
`request.apply` receipt, fixed `D1_EMPLOYEE_STATE_APPLY` result kind, existing
Employee result, and matching applied row version. The Profile application
guard is unchanged.

This brings the static drafted-effect inventory to **12 of 36**; **24 effects
remain**. Migration 10 stays a non-executable `.sql.draft`. No SQL was applied
and no Supabase project was contacted. Local regression checks returned
`FOUNDATION_SOURCE_PASS 9 migrations + 9 tests`, `LOCAL_CONFIG_PASS`, 121
passing Python tests and `STAGING_VALIDATE_PASS`; `git diff --check` found no
whitespace errors.

## Employee job-assignment P1 continuation — candidate 13/36

Product-owner clarification during D1C1B fixes `employee.job_assignment.change` as typed `ADD`, `END`, and `CORRECT`. ADD uses caller-supplied past/current/future `effective_from` and an optional initial bound. END one-way closes one open row at the caller-supplied boundary without replacing the immutable row reason. CORRECT closes one open predecessor and appends an open Department/Designation successor at the same boundary with `supersedes_id=source.id`, changing Department, Designation, or both. Already-ended rows cannot be corrected. Exact `(Employee,Department,Designation)` overlap is denied while distinct concurrent jobs remain valid; no primary/single-job rule is introduced.

The static draft implements P1 DIRECT/APPROVAL with separate submit, review and explicit apply transactions, current-authority replay, deterministic `APPROVED→INVALIDATED` apply failures, and retained history. The lock order is Foundation authorization/idempotency/Principal then Employee → sorted Department → sorted Designation → history. Department/Designation facts never grant authorization. Broad audit/outbox excludes private reason text; successful effects select `employee.job_changed`.

Public typed surfaces in the draft are `app.d1_change_employee_job_assignment`, `app.d1_submit_employee_job_assignment_change`, `app.d1_review_employee_job_assignment_request`, `app.d1_apply_employee_job_assignment_request`, and bounded `app.d1_read_employee_job_assignment_request`. Migration 10 remains `.sql.draft` and unexecuted. This is effect candidate **13/36**, not a frozen/pass result. Manifests remain **97 permissions / 322 scope alternatives / 36 operations**. D1C1B remains incomplete; D1C2, Migration 10 application and remote Supabase operations remain unauthorized.

No fresh PostgreSQL/Foundation regression is asserted by this status section; runtime proof remains a later separately authorized gate.

## Employee campus-affiliation P1 continuation — candidate 14/36

Product-owner clarification fixes `employee.campus_affiliation.change` as typed `ADD`, `END`, and `CORRECT`. ADD accepts a caller-supplied past/current/future start and optional initial bound. END one-way closes exactly one open source affiliation at a caller-supplied boundary without rewriting the immutable source reason. CORRECT closes one open predecessor and appends one open successor at the same boundary with `supersedes_id=source.id`; destination Campus may differ from source Campus. A same-Campus CORRECT must also change the protected successor reason, so an exact same-Campus/no-new-fact rewrite is rejected. Already-ended or already-superseded sources deny. Exact Employee+Campus interval overlap remains forbidden while distinct Campus affiliations may overlap.

The relation-31 HE trigger keeps its overlap key as `(employee_id,campus_id)` but narrows its supersession-parent key to `employee_id`. This is the minimum structural adjustment required by the approved cross-Campus CORRECT semantics: lineage cannot cross Employee, but Campus itself is the corrected historical fact. The generic HE guard is unchanged.

The static draft implements P1 DIRECT/APPROVAL with separate submit, review and explicit apply transactions, source/destination Campus authorization, current-authority replay, deterministic `APPROVED→INVALIDATED` apply failures, retained history, and one successful `employee.campus_affiliation_changed` event. D1 locking is Employee → all affected Campus rows in UUID order → affiliation history. New destination Campuses must belong to the project school and be ACTIVE. Ending/changing affiliation does not mutate Teaching, job assignments, grants, scopes, roles, Principal/Auth, or Employee state.

Public typed surfaces are `app.d1_change_employee_campus_affiliation`, `app.d1_submit_employee_campus_affiliation_change`, `app.d1_review_employee_campus_affiliation_request`, `app.d1_apply_employee_campus_affiliation_request`, and bounded `app.d1_read_employee_campus_affiliation_request`. Migration 10 remains `.sql.draft` and unexecuted. This is effect candidate **14/36**, not a frozen/pass result. Manifests remain **97 permissions / 322 scope alternatives / 36 operations**. D1C1B remains incomplete; D1C2, Migration 10 application and remote Supabase operations remain unauthorized.

No fresh PostgreSQL/D1 runtime claim is made by this status section; runtime proof remains a later separately authorized gate.

## Teacher capability P1 continuation — candidate 15/36

Product-owner clarification fixes `teaching.capability.change` as typed `ADD`, `END`, and `CORRECT`. ADD accepts a caller-supplied past/current/future start and optional initial bound, but the complete requested capability interval must be covered by one ACTIVE employment period; an open capability requires open ACTIVE employment coverage. END one-way closes exactly one open capability at the caller-supplied boundary without rewriting its immutable reason. CORRECT closes one open predecessor and appends one open successor at the same boundary with `supersedes_id=source.id`; because D1 Teacher Capability has no separate category/type attribute, same factual eligibility plus the same protected reason is rejected as a no-op.

Capability END evaluates Class Teacher and Subject Teacher dependencies against their effective validation horizon. A stored finite end at/before D, or an open assignment whose Academic Year exclusive boundary is at/before D, is already outside the affected horizon and is ignored. An affected open assignment starting before D is closed at D; same-day start, future start, and already-bounded future end deny deterministically. Assignment `reason` is never rewritten. The fixed cause `TEACHER_CAPABILITY_END`, affected assignment IDs/counts and affected Campus IDs are stored only in minimized capability-command evidence. No assignment-domain outbox event is emitted; successful capability effect emits only `teaching.capability_changed`.

CORRECT preserves continuous teaching eligibility across adjacent retained capability predecessor/successor rows. The D1 deferred teaching-containment check therefore now accepts gap-free adjacent Teacher Capability coverage for the same Employee rather than requiring one physical capability row to span the whole assignment. Any actual capability gap still rejects. The generic HE overlap/lineage guard remains unchanged, and capability overlap remains forbidden per Employee.

The static draft implements the frozen Employee → Campus/Year → Class → Class Offering → Section → Subject → history lock order for END dependency work, with Employee as the common serialization anchor. ADD/CORRECT still lock Employee, employment history and capability history. Appending capability history does not increment Employee `row_version`; the expected Employee version remains the command/request concurrency binding.

Public typed surfaces are `app.d1_change_teacher_capability`, `app.d1_submit_teacher_capability_change`, `app.d1_review_teacher_capability_request`, `app.d1_apply_teacher_capability_request`, and bounded `app.d1_read_teacher_capability_request`. Migration 10 remains `.sql.draft` and unexecuted. This is effect candidate **15/36**, not a frozen/pass result. Manifests remain **97 permissions / 322 scope alternatives / 36 operations**. D1C1B remains incomplete; D1C2, Migration 10 application and remote Supabase operations remain unauthorized.

No fresh PostgreSQL/D1 runtime claim is made by this status section; runtime proof remains a later separately authorized gate.
