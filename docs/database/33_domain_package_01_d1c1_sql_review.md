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

### Focused static review findings

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
