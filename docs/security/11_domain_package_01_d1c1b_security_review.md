# D1C1B security SQL review — in progress

## Correction against `71b568c2402be438e56e9f2ea711d112b8d342c9`

Independent re-review accepted the separate Profile review and apply transactions,
requester/final-approver apply gate, distinct phase receipts and Profile effect
owners, but found three blockers: explicitly callable schema-owner receipt lookup,
PostgreSQL JSONB-text hashing presented as JCS, and phase-suffixed Profile audit
event types. The product-owner clarification distinguishes explicit command/RPC
helpers from trigger-only defensive integrity functions. Frozen Foundation and
D1C1A schema-owner SECURITY DEFINER triggers may fire on protected DML; their
direct EXECUTE remains revoked and they do not authorize a command. This
correction does not change their ownership or structural behavior.

The explicitly callable `d1_command_receipt_lookup` is now SECURITY DEFINER
owned by `schoolos_evidence_writer`, with a fixed operation/phase input
boundary and only reviewed receipt/operation SELECT. It does not read or lock
Principals. `d1_lock_current_principal` is SECURITY DEFINER owned by
`schoolos_identity_executor`: it compares the expected UUID to the verified
current Principal, SELECT FOR UPDATE locks that exact ACTIVE row, checks it
again, returns no Principal fields and mutates none. Its underlying privilege
is SELECT(id,state) plus UPDATE(id), the minimum PostgreSQL row-lock privilege,
with role-specific SELECT/UPDATE RLS. The role is NOLOGIN; no executor
membership was added. EXECUTE is only for the fixed Academic, Student,
Employee and workflow executor roles, never PUBLIC/anon/authenticated/
service_role. Each fixed caller follows SHARED `(71001,1)` authorization lock,
verified Principal, `(71002, resource)` receipt-key lock, exact Principal row
lock, domain locks, post-wait authorization, mutation and atomic evidence.

Canonicalization version 1 hashes `SHA-256(UTF8(JCS(envelope)))`. The server
constructs an object with fixed ASCII keys for canonicalization version,
operation code/version/UUID, fixed command kind, verified Principal UUID,
typed intent and idempotency key. `d1_jcs_typed` sorts these fixed keys with
bytewise `C` collation (equivalent to RFC 8785 UTF-16 order for ASCII),
preserves array order, serializes Unicode strings code point by code point
with the RFC control/quote/backslash escapes, and rejects unsupported keys or
numeric shapes. PostgreSQL UTF-8 text cannot hold NUL or lone surrogates;
other Unicode text is neither trimmed nor normalized. Current bigint versions
are validated typed SQL values converted to decimal JSON strings; typed UUIDs
become lowercase PostgreSQL UUID text. The supported numeric subset is safe
integer literals only (the envelope uses literal 1); no floating-point or
Finance decimal canonicalization is claimed. Typed Profile payloads have
exact fixed key sets with explicit nulls; no universal omitted/null equivalence
is introduced. The final document is never serialized with `jsonb::text`.
Unknown stored receipt canonicalization versions deny replay. These are
source-level claims pending PostgreSQL execution and independent RFC vectors.

Source-only canonicalization vectors for the supported subset (expected
behavior, **not executed assertions**):

| Input distinction | Canonical expectation |
|---|---|
| `{"profile_photo_file_id":"x","general_contact":"y"}` versus reversed key order | Both `{"general_contact":"y","profile_photo_file_id":"x"}`; same UTF-8/hash. |
| `["first","second"]` versus `["second","first"]` | Order retained; different hash. |
| Profile payload keys in different input order | Same fixed-key canonical bytes; explicit required null remains `null`. Missing required Profile key denies before hashing. |
| Typed UUID supplied with uppercase hex | PostgreSQL UUID text is lowercase; same typed UUID hashes identically. |
| Typed bigint version 42 | JSON string `"42"`, never a lossy JSON number. Version 43 changes hash. |
| Same intent under `request.submit`, `request.review`, `request.apply` | `command_kind` differs; hashes differ. |
| Same expected version, different target UUID | Typed target array slot differs; hash differs. |
| Quote, backslash, tab, newline and U+000F in a string | JCS escapes quote/backslash, uses `\t`, `\n`, `\u000f` (lowercase hex); other characters stay intact. |
| Non-ASCII U+20AC (euro sign) and canonically distinct Unicode sequences | UTF-8 characters preserved without normalization; distinct sequences stay distinct. |
| Unsupported numeric fraction/exponent or integer above 9007199254740991 | Deny; no arbitrary IEEE-754 serializer. |
| Existing receipt canonicalization version other than 1 | Deny replay. |

The RFC 8785 primitive example's U+20AC remains unescaped, U+000F becomes
`\u000f`, newline becomes `\n`, slash stays `/`, and object properties sort
lexicographically. Those rules are represented in the narrow serializer; the
RFC floating-point example is outside this reviewed subset. No runtime proof
is asserted by this vector list.

Profile audit `event_type` is now exactly `student.profile.update` or
`employee.profile.update`; the bounded DIRECT/SUBMIT/REVIEW/APPLY phase remains
in `authority_evidence.phase`. No raw Profile value or reason is added to broad
audit evidence. Student successful mutation still uses only
`student.profile_changed`; Employee Profile has no selected outbox event.

The explicit Profile call graph uses `schoolos_authz_reader` for authorization
and participant/policy checks, `schoolos_identity_executor` for the Principal
row lock, `schoolos_evidence_writer` for receipt/audit/outbox work,
`schoolos_workflow_executor` for workflow, `schoolos_student_executor` and
`schoolos_employee_executor` for typed effects, and `schoolos_read_executor`
for the checked read. The pure JCS serializers and fixed invoker dispatch are
SECURITY INVOKER. No explicitly callable Profile command helper in this graph
runs as `schoolos_schema_owner`. Separately, trigger-only defensive functions
include Foundation `advance_row_version`/`guard_approval_requests` and D1
`d1_guard_record`, file-purpose and deferred state guards. Their schema-owner
execution is the clarified structural exception; it is not an RPC grant.

This remains an incomplete, unexecuted Migration 10 `.sql.draft`. D1C1B is
not passed and D1C2/application is not authorized.

After this correction, source checks returned `FOUNDATION_SOURCE_PASS 9
migrations + 9 tests`, `LOCAL_CONFIG_PASS`, and `STAGING_VALIDATE_PASS`;
`git diff --check` found no whitespace error. Registrar recount found 97
unique permissions, 322 unique scope alternatives and 36 unique operations.
These checks do not parse the SQL draft or prove PostgreSQL privilege or JCS
runtime behavior.

**Status: INCOMPLETE STATIC DRAFT.** Migration 10 remains
`supabase/migrations/20260928000000_domain_package_01.sql.draft`. It has not
been executed, and its broad provisional D1 executor policies are not approved
as the final authorization boundary. Do not activate D1 operations or rename
the file to `.sql` on the basis of this review.

## Independent review of `7977daac` and Profile correction

The independent review of `7977daac5c8af273058e6f41ef3e90a232ac6888`
found five material Foundation-contract violations: final review applied the
target in the same transaction, submit/review/apply reused the business code
as `command_kind`, a review receipt served as application evidence, Profile
runtime `SECURITY DEFINER` functions ran as `schoolos_schema_owner`, and
review replay returned stored results before checking current request-read
authority. That commit was **not** a Profile-workflow pass.

The product owner then approved the exact Profile-only request-participant
contract. An ACTIVE INDIVIDUAL requester has safe request visibility only
while the original operation permission and pinned target scope/context remain
current. An OPEN-step reviewer needs one non-withdrawn
`D1_REVIEWER_ROLE_SCOPE` assignment and current role, exact review grant,
scope and requester separation. After closure, only a reviewer with their own
immutable decision retains read/replay access under those same current checks;
former candidates do not. The final approver is the reviewer whose APPROVE
decision closed the highest required sequential step. Only the currently
authorized requester or that exact final approver may explicitly trigger
`request.apply`. Neither a role-name administrator fallback nor an automatic
SYSTEM/background apply exists. No new permission code is introduced.

The corrective draft adds a fixed checked Profile participant predicate and
a field-limited Profile request projection. It acquires the Foundation SHARED
authorization lock and resolves the current Principal before request-specific
results. Submit, review and apply use separate internally fixed receipt phases
`request.submit`, `request.review` and `request.apply`; the canonical intent
binds operation/version, phase, actor, typed target/request, expected version,
payload and key. A final APPROVE transaction ends at `APPROVED`, with its
review receipt and transition, and never runs the domain effect. An explicit
later apply transaction starts only from `APPROVED`, locks the typed target,
rechecks requester, all required reviewers, policy and target, then either
atomically executes the fixed effect and records a distinct SUCCEEDED apply
receipt/application row, or records deterministic `INVALIDATED` with a
REJECTED apply receipt and no domain/outbox effect. Transient failures roll
back, leaving the approved request and its prior reviews intact. Replay
requires current participant authority; old receipts confer no access.
The draft also adds a Profile-only application-row trigger: in addition to
the frozen composite request/operation FK, it requires the referenced receipt
to be `SUCCEEDED` with `command_kind='request.apply'`.

The intended final runtime owners in this draft are `schoolos_authz_reader`
for the private Profile authority/policy/evidence evaluators,
`schoolos_workflow_executor` for submit/review/apply orchestration and its
fixed public RPCs, `schoolos_student_executor` and
`schoolos_employee_executor` for their respective public direct commands and
fixed private target effects, `schoolos_read_executor` for the checked
projection, and `schoolos_evidence_writer` for receipt/audit/outbox append.
The generic payload/effect/direct helpers are `SECURITY INVOKER`; no Profile
runtime SECURITY DEFINER function retains schema-owner execution authority.
Executors have explicit private EXECUTE edges and no inter-executor membership.
All private Profile helpers revoke authenticated EXECUTE.

This is a **corrective static draft under independent re-review**, not proof
that the SQL parses, the owners/ACLs behave as designed, or D1C1B is complete.

## Accepted checkpoint

Commit `ee7d9adf8718e5a9f2afb0c2c426337fd7eea5a5` is an accepted
**partial** D1C1B checkpoint. It already supplied the exact approved
`deployment-bootstrap` SYSTEM actor UUID/purpose check, 97 permission rows,
322 scope alternatives, 36 operation contracts, and the ten product-owner
approved P1 reviewer permissions and operation mappings. Those are inherited
from that checkpoint, not new work in this continuation. Registration remains
private, post-bootstrap, disabled by default, and uninvoked by the migration.

## Continuation work under static review

- A D1 business actor is restricted to an ACTIVE INDIVIDUAL or FAMILY Principal;
  SYSTEM Principals cannot enter the ordinary D1 evaluator. The existing
  same-chain Foundation authority query and six named contextual resolvers
  remain the basis for further review. Subject-teacher resolution now requires
  an explicit Subject, and an Employee-campus target can be evaluated against
  the particular stored affiliation row rather than a different concurrent
  affiliation.
  The evaluator and P1 policy selector are declared `VOLATILE` so a protected
  command can make a fresh authorization/policy read after waiting on its row
  locks; declaring either `STABLE` would risk retaining the calling statement's
  earlier snapshot. This is a static concurrency correction, not a runtime
  concurrency test.
- The product owner selected an explicit P1 route field. The draft adds
  nullable `approval_policy_versions.d1_route_mode` with `DIRECT` and
  `APPROVAL` values, preserves existing Foundation rows, and freezes a
  selected route after activation. This was a **product-owner-approved
  clarification discovered during SQL translation**: approval-step count is
  validation evidence, never the source of truth for the mode. A private P1
  selector recognizes only the frozen P1 codes and requires exactly one
  applicable active policy. Missing/invalid mode denies; `DIRECT` selects the
  protected direct path regardless of template count; `APPROVAL` requires at
  least one structurally valid sequential step with an ACTIVE reviewer role
  and denies direct application. Policy
  activation checks the P1 mode/step requirement, and a mandatory-approval
  operation cannot select `DIRECT`; the two mixed P0-current/P2-retroactive
  teaching contracts likewise cannot use the field to select `DIRECT`. P0
  retains its frozen direct contract; P2 retains mandatory approval. This is
  draft SQL, not a runtime-proven
  workflow.
- The product owner has now approved the sole D1 reviewer-selection key,
  `D1_REVIEWER_ROLE_SCOPE`. The draft activation guard requires that exact key
  on every sequential ACTIVE-role step for P1 APPROVAL and the frozen P2
  policies, including the retroactive teaching branches. This also guards an
  attempted direct ACTIVE insert; a policy must be created as DRAFT before
  its templates can be added and the policy activated. The P1 selector
  rejects an APPROVAL route containing any other step key. Existing non-D1
  Foundation policies are not rewritten.
- A private `d1_review_candidates(request_id,step_id)` branch accepts only a
  pinned PENDING request and OPEN step with that key. It derives the registered
  review permission and step reviewer-role UUID from Foundation rows; a
  candidate must be an ACTIVE INDIVIDUAL Principal with a bound Auth subject,
  a live assignment to the configured ACTIVE non-FAMILY role, and one separate
  complete live direct-scope chain for the exact review permission. The role
  filter alone grants nothing. Stored School, Student placement, or Employee
  affiliation facts determine the supported target scope. Same Principal and
  same proven Person as the requester are excluded; FAMILY, SYSTEM, missing,
  inactive, detached, and unproved requester identity produce no candidate.
  In the Profile workflow, an Employee CAMPUS reviewer grant must match the
  request's pinned campus; a grant for another current affiliation cannot be
  mixed into that request. A campus-free Employee request requires ALL scope.
  No administrator or role-label fallback exists. An empty candidate result
  must block the later step-open command, never approve or select DIRECT.
- The companion private `d1_current_reviewer_eligible(request_id,step_id)`
  derives the caller through Foundation request identity, recomputes the live
  candidate predicate, and also requires a current non-withdrawn
  `approval_step_reviewers` row. Thus a candidate snapshot is not durable
  review authority; anonymous claims, grant/role revocation, withdrawn
  assignment, closed step, or lost target context deny on recheck. Both helpers
  revoke PUBLIC/anon/authenticated/service-role EXECUTE and grant only the
  existing NOLOGIN `schoolos_workflow_executor`. They return safe Principal IDs
  or a Boolean, not sensitive request payloads. The new profile workflow grants
  their EXECUTE to the NOLOGIN workflow executor for fixed server-side
  orchestration; they remain non-executable by authenticated clients.
- The resolver deliberately returns no candidate for move/reassignment,
  Family two-sided, roll lineage, restricted-identity/Special lineage, Emergency
  Contact lineage, Employee qualification/experience lineage,
  state/capability effects, and teaching correction targets until the fixed typed
  command defines their source/destination and target-ref interpretation.
  The supported static request targets are Student profile/current status
  change and Employee profile. Future
  workflow code must persist eligible IDs to `approval_step_reviewers` with
  safe `D1_REVIEWER_ROLE_SCOPE` assignment reason, fail closed on zero eligible
  reviewers, recheck before APPROVE/REJECT and again before apply, and enforce
  expected versions. The narrow Student/Employee Profile continuation below
  implements those actions only for its two typed operations; other routes
  still have no workflow command.
- Fixed, typed checked-read functions have been added for the approved
  Academic, Student, Family, Employee, and Teaching current/history disclosure
  families. Current FAMILY Emergency Contact returns only display name,
  relationship, phone, and email. FAMILY relationship/summary reads filter
  each returned Family row to the caller's current membership, preventing
  one child's other Family records from appearing through that projection.
  Current and retained relationship rows additionally require current
  child-access evidence for that **same** Family; a grant through another
  Family cannot disclose them.
  Sensitive Student identity/Special and Employee restricted identity remain
  separately permissioned from roster/profile. Historical reads use their
  separate history permission and present grant checks. These interfaces
  still require independent field-by-field and non-owner review.
- A private receipt lookup takes the Foundation authorization SHARED lock,
  a namespace-71002 SHA-256-derived command-key lock, and the current actor
  row lock before comparing the full immutable receipt tuple. The six fixed
  Academic P0 drafts use it for typed effects, expected versions where the
  target is mutable, post-lock reauthorization, atomic evidence, stable audit
  discriminators and the six selected outbox events. None has been executed;
  the other 28 operation effects remain outside this Academic continuation.

## Student and Employee Profile P1 workflow continuation

The following paragraphs record the **rejected `7977daac` checkpoint** as
historical context. Its combined final-review/application behavior and
schema-owner runtime functions are superseded by the corrective draft above.
They must not be treated as current implementation claims.

From parent `14292465063a33bc975f69aed0466c2b98f0563d`, the draft adds
fixed typed `app.d1_change_student_profile`,
`app.d1_submit_student_profile_update`, `app.d1_change_employee_profile`,
`app.d1_submit_employee_profile_update`, and
`app.d1_review_profile_request`. The Student payload is an exact full
replacement of DOB, gender code, nationality code, general contact, previous
school, and profile-photo reference. Employee Profile changes only its
approved core-row photo reference; restricted identity, employment state,
qualification, experience, jobs, and affiliations have no update path through
these entry points. Private payload validation rejects extra keys and wrong
JSON types. Existing file-purpose/AVAILABLE triggers protect the two photo
links; FK or profile permission does not grant upload or download authority.

Each direct/submission call uses the Foundation `(71001,1)` SHARED
authorization lock, the existing principal/operation/idempotency receipt-key
lock, a pinned active policy and target aggregate lock, then a fresh exact
INDIVIDUAL grant/scope and target-state/version check. Absent/ambiguous policy
denies. `DIRECT` executes only the fixed allowlisted mutation; `APPROVAL`
blocks direct mutation and requires typed request submission. The canonical
intent hash includes route, typed values, target and expected version. An
exact successful receipt replay returns its stored result; changed intent
under the same key conflicts. Failed transactions leave no successful receipt.
The live Profile authority helper, reviewer candidate evaluator and reused
P1 selector evaluate their validity windows from a fresh clock instant after
lock waits; the earlier outer-statement timestamp cannot extend a grant past
revocation or expiry.

Submission creates a private Foundation request with typed old/new PROFILE
snapshots, advances DRAFT → SUBMITTED → PENDING, snapshots every sequential
policy template as a WAITING step, opens step 1, and materializes current
`D1_REVIEWER_ROLE_SCOPE` candidates into `approval_step_reviewers`. Zero
candidates raises an error and rolls back the entire submission, including
its receipt. The review entry point accepts only these two operation codes.
It locks the request, open step and current reviewer assignment, checks the
expected request version, and invokes the frozen live eligibility predicate
before recording an immutable `approval_reviews` decision. A rejection
terminates the path and cancels waiting steps. Approval opens only the next
sequential step, materializing fresh candidates; zero candidates rolls back
that review. The final approval checks every prior immutable approval and
current reviewer role/grant/scope/assignment, as well as current requester
authority, target context, state and expected version. Stale authority or
target returns INVALIDATED without profile mutation. A valid result passes
through APPROVED to EXECUTED and records `approval_applications` atomically.

The direct and applied Student mutation emits only the selected
`student.profile_changed` outbox event. Employee Profile emits no D1 outbox
event. Receipts and broad audit/outbox payloads contain identifiers, route,
state, version and correlation evidence, never raw profile values or reason
text. The requested/old values and reviewer reason remain in the private
Foundation workflow records. The two profile effects update only the fixed
columns, with existing D1 row-version and file-purpose triggers still in force.
All new private helpers revoke PUBLIC, anon, authenticated and service-role
EXECUTE. The five exact public entry points grant only `authenticated`
EXECUTE. No authenticated base-table DML is added. This is static SQL only;
PostgreSQL parsing, function ownership, non-owner RLS and concurrency behavior
remain unproven until separately authorized execution testing.

## Open completion gates

1. The complete 36-operation ledger is not implemented. Six Academic P0
   operations and the two Profile P1 operations now have draft effects, leaving
   28 operation contracts without effects. In particular, `student.create`
   remains unavailable pending the approved Admissions handoff. The Academic
   family still needs independent static and later runtime review.
2. The two Profile operations above are the only drafted P1 workflow core.
   Other P1/P2 source/destination interpretation, candidate materialization,
   review, apply, receipt and evidence paths remain unimplemented. The
   capacity-override and Admissions handoff commands remain separate gates.
3. The provisional broad executor `USING (true)`/`WITH CHECK (true)` policies
   and DML grants still require final narrowing, along with the function
   EXECUTE allowlist and file-service authorization boundary.
4. Static SQL syntax and privilege review, complete inventory, manifest
   recount, and the required Foundation guard/staging validation must be
   repeated at completion. D1C1C and D1C2 are separate and unauthorized.

This document is a continuation work record, **not** a D1C1B PASS or an
independent review approval.

## Academic P0 command-family continuation (static only)

The continuation from `bb2b7a803af332704565fe1da6892ad8a09280ec`
drafts the complete six-operation Academic P0 family:
`app.d1_change_academic_class`, `app.d1_change_academic_subject`,
`app.d1_change_academic_offering`, `app.d1_change_academic_section`,
`app.d1_change_academic_section_room`, and
`app.d1_change_academic_capacity`. Each function is owned by the NOLOGIN
`schoolos_academic_executor`; only its exact signature grants EXECUTE to
`authenticated`. PUBLIC, anon and service_role retain no D1 application
EXECUTE and no client receives base-table DML.

Every entry point uses the frozen direct P0 sequence: the evidence-owned
receipt lookup takes the `(71001,1)` SHARED authorization lock and namespace
71002 idempotency-key lock, the identity executor locks the verified current
Principal, the Academic executor takes the deterministic stored-ancestry
locks, and a fresh authorization call rechecks one complete live grant/scope
chain before expected state/version validation and mutation. School catalog
commands use SCHOOL authority; new Offerings use their locked destination
Campus and existing Offerings use their stored Class Offering; new Sections
use the locked parent Offering and existing Sections use the stored Section.
Section-room source and destination share the same locked Section scope and
both Room rows are locked UUID-sorted when they differ. Capacity authority is
typed to exactly CLASS or SECTION. No role name, administrator or partial-chain
fallback is present.

Class and Subject expose only create, mutable-label/order profile update, and
one-way archive; Class alone also retains its reviewed optional stage label.
Offering ancestry and Section ancestry/code are immutable. Offering update
changes only the reviewed PLANNED/OPEN/CLOSED lifecycle state, and Section
update changes only label/order plus that lifecycle state; capacity is routed
through the separate capacity command. Offering and Section creation append
the required initial typed capacity revision in the same transaction. Archive
retains history and rejects active dependent catalog/room state selected by
the command boundary. D1C1A guards remain the final ancestry, lifecycle,
version and archive-use defense.

Section-room supports only ADD, END and CORRECT. END performs the sole HE
one-way close. CORRECT locks the retained predecessor and source/destination
Rooms, closes the open predecessor, and appends a same-Section successor with
`supersedes_id`; it never deletes or rewrites historical business fields.
Room and Section Campus must match, and the destination Room must be ACTIVE.
Reason text remains only in private retained history and is excluded from
broad audit/outbox evidence.

Capacity accepts only `CLASS_OFFERING` or `SECTION`, locks the trusted parent
hierarchy, rechecks retained accepted commitments on reductions, updates the
current projection, and appends one matching typed immutable revision with the
same receipt in the transaction. Existing placements are never modified and
no enrollment capacity override is synthesized. The D1C1A deferred projection
and revision checks remain unchanged.

The prior Class command's direct receipt/audit/outbox inserts were removed.
Three fixed SECURITY DEFINER helpers owned by `schoolos_evidence_writer` now
validate the six-operation allowlist, result kind, stable operation-code audit
discriminator and exact selected outbox mapping before appending Foundation
evidence. `schoolos_academic_executor` has no broad evidence-table INSERT.
Its domain DML grants are explicit by relation and column; immutable capacity
history has no UPDATE grant. Lock-only UPDATE(id) privileges on Foundation
School/Campus/Year/Room anchors have matching SELECT and UPDATE lock policies;
no mutable Foundation business column is granted and the fixed Academic RPCs
issue no Foundation UPDATE. The authorization evaluator remains owned by
`schoolos_authz_reader`, the Principal lock remains owned by
`schoolos_identity_executor`, and no membership chain or executor role was
added.

The receipt phase allowlist now admits only the five new operation-equals-
command-kind pairs and their fixed positional array lengths. Bigint versions
remain canonical decimal strings and the restricted Canonicalization V1
serializer was not generalized. Audit event types are exactly the six dotted
operation codes. Outbox types are exactly `academic.class_changed`,
`academic.subject_changed`, `academic.offering_changed`,
`academic.section_changed`, `academic.section_room_changed`, and
`academic.capacity_changed`.

This continuation does not alter Profile routing, review, apply or payload
behavior. It is unexecuted draft SQL; PostgreSQL parsing, ownership, RLS,
locking, replay and concurrency behavior remain D1C2 evidence gates.

The source-only gate returned `FOUNDATION_SOURCE_PASS 9 migrations + 9 tests`
and `LOCAL_CONFIG_PASS`; staging contract validation returned
`STAGING_VALIDATE_PASS`; `git diff --check` reported no whitespace error.
Static extraction reconfirmed 97 unique permissions, 322 unique supported
scope alternatives and 36 unique operations. These checks did not parse or
execute Migration 10 and contacted no local or managed Supabase project.

## Academic parent-lock correction after independent review

Independent review of `f1c2a63b660554fec06ba24afcfc1d0c909d9b44`
found two blockers: the Academic executor had the column privileges needed by
PostgreSQL locking reads on four Foundation parents but only SELECT RLS, and
the capacity-reduction branch read retained Enrollments without evaluating
the frozen breakpoint occupancy algorithm. This correction records those as
review findings; it does not rewrite `f1c2a63b...` as a pass.

PostgreSQL applies UPDATE privilege and UPDATE RLS to `SELECT ... FOR UPDATE`.
The draft therefore pairs each Foundation parent's existing SELECT policy and
narrow SELECT columns with a `FOR UPDATE ... USING (true) WITH CHECK (true)`
policy and `UPDATE(id)` only. This is lock-only capability: the NOLOGIN
`schoolos_academic_executor` has no membership chain, is reached only as owner
of the six fixed SECURITY DEFINER Academic RPCs, and none of those functions
issues a Foundation UPDATE. No mutable Foundation business column is granted.

| Locked relation | Clause in fixed Academic path | Required privilege | Applicable RLS | Runtime owner |
|---|---|---|---|---|
| `app_private.principals` | `FOR UPDATE` in `d1_lock_current_principal` | `SELECT(id,state)`, `UPDATE(id)` | `d1_command_principal_lock_read`; `d1_command_principal_lock_update` | `schoolos_identity_executor` |
| `app_private.school_profiles` | `FOR UPDATE` for Class, Subject, Offering and Section configuration anchors | `SELECT(id)`, `UPDATE(id)` | `d1_academic_school_lock_input`; `d1_academic_school_lock_update` | `schoolos_academic_executor` |
| `app.campuses` | `FOR UPDATE` after Academic Class and before Academic Year | `SELECT(id,school_id,state)`, `UPDATE(id)` | `d1_academic_campus_lock_input`; `d1_academic_campus_lock_update` | `schoolos_academic_executor` |
| `app.academic_years` | `FOR UPDATE` after Campus and before Class Offering | `SELECT(id,school_id,state)`, `UPDATE(id)` | `d1_academic_year_lock_input`; `d1_academic_year_lock_update` | `schoolos_academic_executor` |
| `app.rooms` | UUID-sorted `FOR UPDATE` after Section for Section Room source/destination | `SELECT(id,campus_id,state)`, `UPDATE(id)` | `d1_academic_room_lock_input`; `d1_academic_room_lock_update` | `schoolos_academic_executor` |
| `app_private.academic_classes` | `FOR UPDATE` before Campus for stored Offering ancestry, or as the catalog target | explicit SELECT columns and mutable-column UPDATE | `d1_01_executor_read`; `d1_01_executor_update` | `schoolos_academic_executor` |
| `app_private.subjects` | catalog-target `FOR UPDATE` | explicit SELECT columns and mutable-column UPDATE | `d1_02_executor_read`; `d1_02_executor_update` | `schoolos_academic_executor` |
| `app_private.class_offerings` | `FOR UPDATE` after Year | explicit SELECT columns and capacity/state/archive UPDATE | `d1_03_executor_read`; `d1_03_executor_update` | `schoolos_academic_executor` |
| `app_private.section_offerings` | `FOR UPDATE` after Offering | explicit SELECT columns and profile/capacity/state/archive UPDATE | `d1_04_executor_read`; `d1_04_executor_update` | `schoolos_academic_executor` |
| `app_private.section_room_assignments` | retained predecessor `FOR UPDATE` after all Room locks | explicit SELECT columns and `UPDATE(effective_until)` | `d1_05_executor_read`; `d1_05_executor_update` | `schoolos_academic_executor` |
| D1 relation selected by `d1_guard_crossrow` | trigger-only repeat lock of the row being validated | schema-owner table privileges | `d1_schema_owner_maintenance` | `schoolos_schema_owner` |
| Academic ancestry reached by `d1_guard_effective_history` through `d1_lock_academic_path` | trigger-only Class, Campus, Year, Offering and Section locks in global order | schema-owner table privileges | `d1_schema_owner_maintenance` | `schoolos_schema_owner` |
| Offering/Section ancestry reached by `d1_guard_capacity_lineage` | trigger-only Class Offering then Section Offering lock | schema-owner table privileges | `d1_schema_owner_maintenance` | `schoolos_schema_owner` |

The command-owned locks retain the global hierarchy: receipt and Principal,
then School/configuration, Academic Class, Campus, Academic Year, Class
Offering, Section Offering, UUID-sorted Room rows, and finally retained child
history. Defensive D1C1A triggers reached by these mutations remain the
previously reviewed trigger-only `schoolos_schema_owner` exception; their
schema-maintenance policies and owner privileges cover their internal locking
reads. The only relation selection in the generic cross-row guard comes from
frozen trigger arguments installed by the draft, not caller input. This
correction adds no dynamic relation selection and no client-callable locking
surface.

For a capacity reduction, the command now scans only accepted PRIMARY
Enrollment history in states ACTIVE, COMPLETED or ENDED. Under the already
held Offering and applicable Section locks it evaluates occupancy at the
requested effective date and every retained start/end breakpoint on or after
that date. Class capacity includes every Section of the Class Offering;
Section capacity includes only that Section. Each row counts only where its
half-open retained interval contains the evaluated date, so future accepted
placements reserve future capacity and ended placements stop counting at
their exclusive end. The computed peak is deliberately private and has no
new audit, outbox, warning-table, approval or override representation. A
reduction below accepted occupancy still succeeds: it preserves every
Enrollment, emits no capacity override, and leaves later placement commands
to enforce the new projection. The Academic role receives only the additional
`placement_state` SELECT column needed by this scan and receives no Enrollment
INSERT or UPDATE.

The product-owner-approved capacity contract is immediate-only for a new
execution. Commit `d952c88b...` incorrectly enforced `CURRENT_DATE` before
receipt lookup and is not treated as a passed replay design. The corrected
initial validation denies NULL but lets a non-NULL historical date reach the
unchanged canonical receipt lookup. After the Principal and target hierarchy
locks and fresh `academic.capacity.change` authorization, an exact successful
receipt may return its stored result across a calendar-date boundary. The old
receipt never supplies authority and replay performs no second effect or
evidence append. Only a no-receipt/new execution reaches the fail-closed
`p_effective_on IS DISTINCT FROM CURRENT_DATE` gate. A changed date changes the
canonical hash and conflicts; it is never substituted by the server.

No backdated or scheduled new execution, correction, queue, job or approval
authorization path exists. The accepted date remains part of the canonical
receipt intent and retained capacity revision, while the current capacity
projection changes in that same transaction. Immediate application does not
remove the future Enrollment commitment scan or change its preservation
semantics.

The six public APIs, Canonicalization V1, Profile workflow, HE Section Room
behavior, stable audit/outbox codes and evidence-writer ownership remain
unchanged by this correction. Runtime SQL remains unexecuted and D1C1B remains
incomplete.

Source-only verification after the correction returned
`D1C1B_ACADEMIC_LOCK_AND_CAPACITY_STATIC_PASS`, including applicable global
lock order, four Foundation parent policy/grant pairs, all six command
evidence paths, both capacity targets, accepted placement states, half-open
interval boundaries and absence of Enrollment DML. Registrar extraction
returned 97/97 permissions, 322/322 scope alternatives and 36/36 operations,
with unique stable IDs and unique permission/operation codes. The frozen
guards returned `FOUNDATION_SOURCE_PASS 9 migrations + 9 tests`,
`LOCAL_CONFIG_PASS` and `STAGING_VALIDATE_PASS`; `git diff --check` found no
whitespace error. These are static findings only. No D1 SQL was parsed or
executed and no Supabase project was contacted.

## Corrective source-only verification (2026-09-29)

The current diff is limited to this review, the D1C1 working review, and the
non-executable Migration 10 `.sql.draft`. A lexical recount of the unchanged
registrar lists found 97 distinct permissions, 322 distinct scope rows and
36 distinct operations. The Profile command inventory now includes the fixed
checked request read and separate apply RPC alongside the two direct and two
submission RPCs and review RPC. The final review body contains no call to
the domain apply helper. The explicit apply path is the only path that inserts
`approval_applications`, and it passes the newly inserted `request.apply`
receipt ID for the same operation and request. The Foundation FK retains
that chain; PostgreSQL execution has not yet verified it. The apply helper
requires `APPROVED`; a deterministic stale condition yields a terminal
REJECTED apply receipt and `INVALIDATED`, while an exception rolls back the
transaction. Every Profile private helper explicitly revokes EXECUTE from
PUBLIC, anon, authenticated and service_role; only exact public RPCs grant
authenticated EXECUTE.

`foundation_guard.py --future report` returned `FOUNDATION_SOURCE_PASS 9
migrations + 9 tests` and `LOCAL_CONFIG_PASS`; `foundation_staging.py
validate` returned `STAGING_VALIDATE_PASS`; `git diff --check` found no
whitespace error. These checks do not parse or execute the D1 draft. D1C1B
still needs independent SQL/ACL review, all remaining command families,
privilege narrowing and separately authorized D1C2 runtime tests.

## Interim static inventory

An independent lexical recount of the registrar VALUE lists in this working
draft found **97/97 unique permission IDs/codes**, **322/322 unique scope IDs**
for the approved 97 permission codes, and **36/36 unique operation IDs/codes**.
After the Profile continuation, the draft has 47 public `app.d1_read_*`
functions, six public D1 command/workflow functions (the prior Academic Class
command and five Profile functions), 86 `SECURITY DEFINER` declarations,
205 policy declarations, 34 D1 `FORCE ROW LEVEL SECURITY` statements, and the five named
D1 executor-role declarations. These are text counts, not PostgreSQL catalog
counts or proof that the SQL parses and runs.

During this continuation, `foundation_guard.py --future report` returned
`FOUNDATION_SOURCE_PASS 9 migrations + 9 tests` and `LOCAL_CONFIG_PASS`;
`foundation_staging.py validate` returned `STAGING_VALIDATE_PASS`, and
`git diff --check` found no whitespace errors. These checks cover the frozen
Foundation/config boundary and formatting. No D1 SQL or remote operation was
executed. All counts and checks must be repeated after the remaining command
and policy work.

At the `98a9ddf07cd4a3840c24d818d0e025a79105c984` resolver-prerequisite
checkpoint, the working tree was clean and matched `origin/main`. The
product-owner-approved reviewer key correction is confined to this review,
the D1C1 working review, and the Migration 10 `.sql.draft`. Static checks
again returned `FOUNDATION_SOURCE_PASS 9 migrations + 9 tests`,
`LOCAL_CONFIG_PASS`, and `STAGING_VALIDATE_PASS`; `git diff --check` found no
whitespace errors. Registrar text still contains 97 unique permission rows,
322 unique scope-alternative IDs, and 36 unique operation rows. No Migration
10 SQL was executed and no Supabase project was contacted. These source checks
do not establish D1 runtime or PostgreSQL parse correctness.

At the `14292465063a33bc975f69aed0466c2b98f0563d` Profile workflow
starting point, `git status --short` was clean. After drafting the two fixed
effects, static registrar extraction again found **97/97 distinct permission
IDs**, **322/322 distinct scope-alternative IDs**, and **36/36 distinct
operation IDs**. A source-level ACL inventory found eight new private
SECURITY DEFINER helpers, each with an explicit PUBLIC/anon/authenticated/
service-role EXECUTE revoke, and five exact public Profile entry points with
authenticated EXECUTE. No other public D1 operation effect was added.
`python tools/supabase/foundation_guard.py --future report` returned
`FOUNDATION_SOURCE_PASS 9 migrations + 9 tests` and `LOCAL_CONFIG_PASS`;
`python tools/supabase/foundation_staging.py validate` returned
`STAGING_VALIDATE_PASS`; `git diff --check` found no whitespace errors.
Those checks do not parse or execute Migration 10 and do not prove runtime
security. No local or managed Supabase database was contacted.

## Employee organization catalog P0 family continuation (static only)

The draft adds only the fixed direct P0 commands
`app.d1_change_employee_department` and
`app.d1_change_employee_designation`, for operation codes
`employee.department.change` and `employee.designation.change`. The exact
permissions are `employee.department.manage` and
`employee.designation.manage`; each permission has only the already-registered
`ALL` scope with resolver `DIRECT`. The checked target is the owning School.
The live complete Foundation permission/scope chain is re-evaluated after the
School and catalog-row locks. FAMILY cannot satisfy these non-family-safe
permissions, and the frozen D1 evaluator admits no SYSTEM actor. No title,
Department membership, Designation, HR label or role-name shortcut is used.

Each command's executor and public RPC owner is the existing NOLOGIN
`schoolos_employee_executor`; authorization remains with
`schoolos_authz_reader`, the current Principal row lock with
`schoolos_identity_executor`, and append-only evidence with
`schoolos_evidence_writer`. The deterministic lock order is the receipt
helper's shared Foundation authorization lock `(71001,1)`, verified Principal,
namespace-71002 idempotency lock inside receipt lookup, current Principal row,
School row, then the relevant Department or Designation row. A fresh live
authorization statement follows target locks and precedes replay or mutation.
CREATE replay locks and verifies the stored result row. Exact successful
replay returns the immutable stored result only after current authority;
changed intent under the same key conflicts in the frozen canonical receipt
helper. Bigint expected versions are represented as decimal strings in the
six-element canonical intent array. Existing UPDATE/ARCHIVE requires the
expected version and ACTIVE target state.

RLS and ACL are limited for this family: Department and Designation SELECT and
INSERT use explicit columns; UPDATE is limited to `label`, `state`,
`archived_at` and `archived_by`. Parent School locking has only SELECT(id) and
UPDATE(id) with matching executor RLS policies. Public EXECUTE is granted to
`authenticated` only for the two exact typed RPC signatures; private helpers
revoke PUBLIC, anon, authenticated and service_role. The Employee executor
does not receive evidence-table INSERT from this work. It receives no new
Employee/Student/Family/Teaching mutation privileges from this continuation;
pre-existing Employee Profile grants are unchanged.

The dedicated evidence-writer helpers accept only the two exact operation
codes and append one successful immutable receipt and one minimized audit row
atomically with each effect. Audit event types are exactly
`employee.department.change` and `employee.designation.change`; action, state
and resulting version are bounded safe details, with no arbitrary reason
text. Neither operation has a selected D1 outbox event, and no outbox row is
written. Department and Designation are organizational facts only: these
commands create no role, permission, principal assignment, scope grant,
reviewer authority or Teacher capability. Archival retains rows and all
historical references; it does not cascade or rewrite Employee history.

This continuation drafts two of the 36 operation effects and does not change
the manifest counts (97 permissions, 322 scope alternatives, 36 operations).
It remains unexecuted, unparsed Migration 10 draft SQL. D1C1B is still
incomplete and awaits independent review; D1C2, migration application and
remote Supabase operations are not authorized. Source-only validation for
this continuation reconfirmed 97 unique permissions, 322 unique scope
alternatives and 36 unique operations, with exactly these two P0/direct
operation mappings and no additional public command. The command protocol and
evidence-boundary assertions passed. The Foundation guard returned
`FOUNDATION_SOURCE_PASS 9 migrations + 9 tests` and `LOCAL_CONFIG_PASS`;
staging validation returned `STAGING_VALIDATE_PASS`; `git diff --check` found
no whitespace errors. These checks do not establish PostgreSQL parse or
runtime behavior. No Migration 10 SQL was executed and no Supabase project
was contacted.

## Employee create P0 security continuation (static only)

`app.d1_create_employee(uuid,text,date,text)` is the only new public command
and is owned by the existing NOLOGIN `schoolos_employee_executor`. It requires
exact permission `employee.create` under the already-registered `ALL` /
`DIRECT` scope, evaluated against the locked School. No CAMPUS inference is
possible before affiliation. Current live authorization is checked after
School, Person and any replay Employee locks. FAMILY cannot satisfy the
non-family-safe permission; the D1 evaluator rejects SYSTEM and no role-name
fallback exists.

The command locks only the existing Person row before Employee creation.
Employee receives SELECT(id,state) plus UPDATE(id) solely for `SELECT ... FOR
UPDATE`, with matching role-specific RLS policies; it receives no Person
business-column update grant and issues no Person mutation. Employee SELECT
is limited to ID, row version, Person, employee code, current state and photo
link, retaining the frozen Profile projection. Employee INSERT is limited to
Person, code, current state, photo link and actor columns. Employment-period
INSERT is limited to employee, state, effective dates, reason, supersession
and actor columns; no history SELECT or additional UPDATE is granted for this
command. Existing Profile and history-end UPDATE grants are unchanged. The
existing Employee and period RLS policies remain enabled, and no authenticated
base-table DML is granted.

Receipt, audit and outbox appends cross three operation-fixed SECURITY
DEFINER helpers owned by `schoolos_evidence_writer`. Each explicitly revokes
PUBLIC, anon, authenticated and service_role EXECUTE, and grants EXECUTE only
to the Employee executor. The Employee executor receives no direct INSERT on
receipts, audit or outbox. The public RPC revokes broad EXECUTE and grants only
the exact signature to authenticated. The Employee executor owns the public
domain command; authorization is evaluated by `schoolos_authz_reader` and the
verified Principal lock remains owned by `schoolos_identity_executor`.

There are no Auth/Principal/Role/role-assignment/permission/scope/reviewer,
Department/Designation job, campus-affiliation or Teaching writes. Employee
creation does not provision an account or capability. Audit event type is
exactly `employee.create`; the only outbox event is `employee.created`, with
minimized Employee ID/state/version/correlation evidence and no reason or
private profile data. Replay rechecks current authority and verifies the
stored Employee's Person/code binding before returning the durable result.

At the Employee-create checkpoint, the operation-effect inventory was
**11/36**. The current manifest remains **97
permissions, 322 scope alternatives and 36 operations**. The draft remains
unexecuted and D1C1B remains incomplete pending independent review. This
continuation does not authorize D1C2 or Migration 10 application.

## Employee Person-state eligibility clarification

The current Person-state predicate is a new-execution eligibility check only.
After locking Person ID/state and rechecking live `employee.create` authority,
a command with no receipt requires `Person.state='ACTIVE'`; `INACTIVE` and
`ARCHIVED` deny. Person state is not an authorization grant, and the command
does not mutate the Person. The minimum lock boundary is SELECT(id,state) plus
UPDATE(id) for row locking, with matching Employee-executor RLS; there is no
UPDATE privilege on Person state or other business columns.

The exact successful-replay branch precedes the ACTIVE predicate but follows
fresh authorization. It may return the stored Employee result after the
Person later becomes INACTIVE or ARCHIVED, after verifying the Employee,
Person and code binding. No Employee lifecycle coupling or authorization
side effect is introduced. The approved initial employment contract and
receipt/audit/outbox payloads remain unchanged. SQL was not executed and no
Supabase remote operation was performed; D1C1B remains incomplete.

## Employee state P1 security continuation

`employee.state.change` uses a dedicated global-target authorization helper
instead of the single-campus Profile interpretation. It admits only a live
non-family Individual with the exact change or approval permission and either
ALL or complete CAMPUS coverage of every server-derived current affected
campus. Partial and empty CAMPUS-only coverage deny. Submission, review,
apply and terminal replay re-evaluate current authority.

Policy resolution is state-specific and fail-closed. A unique active campus
policy overrides the school policy for that campus; every affected campus
must resolve to the same policy ID. No-campus targets require one school-wide
policy. DIRECT and APPROVAL remain explicit, and APPROVAL requires the frozen
contiguous reviewer-step contract. Frozen Profile helpers are unchanged.

The Employee executor owns the direct RPC, Employee lock and employment
effect. The Workflow executor owns approval orchestration and receives no
general D1 table DML. The Teaching executor owns the fixed dependency-close
helper; Employee receives only its narrow EXECUTE grant. The Evidence writer
alone appends receipts, audit and `employee.state_changed` outbox rows. The
private HR reason remains in the protected request and new employment-period
row and is excluded from broad evidence.

Dependency closing follows Employee, sorted academic ancestry and child-
history locks. It never deletes, shortens a bounded row, creates a zero-length
interval, changes a teaching reason, or restores teaching rows on activation.
Organization and campus history is untouched. No role membership, permission,
grant, scope or runtime schema-owner entry point is added. Migration 10 remains
static and unexecuted; D1C1B remains incomplete.

Approval apply now uses narrow Employee- and Teaching-owned preflight helpers
that return only bounded deterministic eligibility codes. They do not catch
or classify unexpected database exceptions. A deterministic denial after
APPROVED produces a terminal INVALIDATED request, one REJECTED apply receipt,
safe audit and transition; it creates no application row and performs no
domain mutation. Transient and unclassified failures roll back the transaction
and leave the APPROVED request retryable. The Employee lock also stabilizes
the server-derived affiliation and teaching campus set while current policy,
requester and reviewer authority are rechecked.

`app.d1_read_employee_state_request(uuid)` is owned by the NOLOGIN Read
executor and grants authenticated only exact EXECUTE. It returns six typed,
bounded fields and never returns the HR reason. A private Authz-owned
participant helper admits the currently authorized requester, an exact open
reviewer still selected by `D1_REVIEWER_ROLE_SCOPE`, or an actual decided
reviewer who still holds the applicable `employee.state.approve` role/scope.
Requester/reviewer person separation is enforced and no role-name or generic
administrator fallback exists. No new base-table SELECT is granted.

The checked request read takes Foundation `(71001,1)` SHARED before resolving
the current Principal, checking requester/reviewer participation, or disclosing
the bounded projection. Authority administration retains its existing EXCLUSIVE
lock contract.

The trigger-only schema-owner application guard requires a successful
`request.apply` receipt for the same request and operation, fixed
`D1_EMPLOYEE_STATE_APPLY` result kind, an existing Employee target and the
receipt's resulting row version. INVALIDATED requests have no application
row. The frozen Profile application guard remains unchanged. The current D1
draft inventory is **12/36 effects**, with the manifest still **97
permissions, 322 scope alternatives and 36 operations**.

## Employee job-assignment P1 security continuation — candidate 13/36

`employee.job_assignment.change` / `employee.job_assignment.approve` remain non-family-safe EA permissions. The operation uses a dedicated Employee authorization/policy/reviewer/participant path; Department, Designation, campus affiliation, labels and creator identity grant nothing. FAMILY/SYSTEM ordinary-business paths deny. Protected entry points take Foundation `(71001,1)` SHARED before current-Principal/participant decisions and preserve Employee → Department → Designation → history locking.

DIRECT is available only under explicit DIRECT policy. APPROVAL uses separate submit/review/apply phases and exact `D1_REVIEWER_ROLE_SCOPE` role+permission+scope eligibility with requester/reviewer Person separation. Final review stops at `APPROVED`. Apply rechecks requester, reviewers, policy, source/history and catalog invariants; deterministic stale/domain invalidity yields `INVALIDATED` plus REJECTED `request.apply`, with no application row, domain effect or outbox. Unexpected database/infrastructure failures are not normalized to INVALIDATED.

The checked request read is purpose-limited and excludes private reason/arbitrary workflow JSON. Replay requires current participant authority. Successful application is defended by an operation-specific receipt/application guard tied to `request.apply`, `D1_EMPLOYEE_JOB_APPLY`, request/result identity and bounded resulting evidence. Evidence uses `employee.job_assignment.change` audit and `employee.job_changed` outbox with minimized identifiers/interval/action data; raw reason is excluded. Employee executor privileges on `employee_job_assignments` are narrowed to explicit columns plus the one-way HE close.

This remains a static, unexecuted Migration 10 draft and **candidate 13/36** pending independent review. No Foundation/runtime test claim is added here.

## Employee campus-affiliation P1 security continuation — candidate 14/36

`employee.campus_affiliation.change` / `employee.campus_affiliation.approve` remain non-family-safe EA permissions. Authorization is proven from complete live ALL/CAMPUS permission-scope chains for the requested Campus facts: ADD requires destination Campus, END requires source Campus, and CORRECT requires both source and destination Campus. The affiliation row itself is never consulted as a grant. FAMILY/SYSTEM ordinary-business paths deny, and requester/reviewer Person separation remains mandatory.

The command adds lock-only `schoolos_employee_executor` access to `app.campuses`: `SELECT(id,school_id,state)` plus `UPDATE(id)` solely to support `SELECT ... FOR UPDATE`. Structural broad Employee-executor SELECT/INSERT on `employee_campus_affiliations` is revoked and replaced by explicit columns plus the existing one-way HE close. Authenticated receives only exact RPC EXECUTE and no base-table DML. Reviewer helpers receive only bounded request snapshot/payload columns; the private workflow reason is not granted to the authz reader.

DIRECT is available only under explicit DIRECT policy. APPROVAL uses separate submit/review/apply phases and exact `D1_REVIEWER_ROLE_SCOPE` role+permission+source/destination-scope eligibility. Final review stops at `APPROVED`. Apply rechecks policy, requester, reviewers, Employee/source facts, destination Campus state/school, overlap constraints, and the same-Campus no-op rule; deterministic invalidity yields `INVALIDATED` plus REJECTED `request.apply`, with no application row, affiliation effect or outbox. Unexpected database/infrastructure failures are not normalized to INVALIDATED.

The operation-specific application guard binds successful `approval_applications` to a SUCCEEDED `request.apply` receipt, fixed `D1_EMPLOYEE_CAMPUS_AFFILIATION_APPLY` result kind, EXECUTED request, matching affiliation/result version and bounded request/result intent. The checked request read exposes only workflow state plus Employee/action/source/destination Campus/effective-date fields; it excludes private reason, arbitrary workflow JSON, receipts, audit JSON and unrelated identity fields. Broad audit/outbox evidence excludes the caller's private reason.

This remains a static, unexecuted Migration 10 draft and **candidate 14/36** pending independent review. No Foundation/runtime test claim is added here.

## Teacher capability P1 security continuation — candidate 15/36

`teaching.capability.change` / `teaching.capability.approve` remain non-family-safe EA permissions. Teacher capability is an Employee-global eligibility fact, not a Campus grant. ALL authority covers the target globally. CAMPUS authority is accepted only when the Employee has at least one currently effective Campus affiliation and the same live permission chain covers every currently effective Employee Campus affiliation plus every still-affected current/future teaching Campus for an END boundary. Future Employee campus affiliations do not grant authority. Capability, assignment, Department, Designation, qualification, labels and creator identity never grant the permission.

P1 DIRECT/APPROVAL uses current requester/reviewer authority, exact `D1_REVIEWER_ROLE_SCOPE` role+permission+scope eligibility and requester/reviewer Person separation. Campus-set policy selection must resolve to one unambiguous current policy across the affected Campus set, with school-level fallback only where the frozen policy model permits it. Final review stops at `APPROVED`; apply rechecks policy, requester, reviewers, Employee/source facts, employment coverage, overlap, dependency horizon and Campus authority. Deterministic invalidity yields `INVALIDATED` plus a REJECTED `request.apply`, no `approval_applications` row, no capability/assignment effect and no outbox. Unexpected database/infrastructure failures are not normalized to INVALIDATED.

`schoolos_teaching_executor` receives only the additional privileges needed for this protected effect: lock-only Employee access, read/lock access to ACTIVE employment periods, read-only Campus-affiliation facts, explicit Teacher Capability columns, and the already-frozen academic/teaching dependency locks. It receives no Employee state/profile mutation and authenticated receives no base-table DML. The application guard is schema-owner trigger-only and binds successful apply to a SUCCEEDED `request.apply`, fixed `D1_TEACHING_CAPABILITY_APPLY` result kind, EXECUTED request, exact capability/request facts, protected ADD/CORRECT reason, and bounded END closure IDs/counts whose rows are actually closed at the approved boundary.

The checked request read exposes only request state, Employee, action, source capability/start and requested effective dates. It excludes private reason, arbitrary workflow JSON, receipts, audit JSON, assignment reasons, identity fields and authorization internals. Broad audit/outbox evidence contains no private HR/staffing reason. Successful END auto-closure emits no class/subject assignment event.

This remains a static, unexecuted Migration 10 draft and **candidate 15/36** pending independent review. No Foundation/runtime test claim is added here.

## Independent freeze note — effect 15/36

Commit `5870baf88ceac2f323f3d8dd46fed50231d00f56` passed independent authorization/ACL/workflow review and GitHub Actions run `36896963330` (121 tooling tests; 220/220 frozen Foundation assertions). `teaching.capability.change` is frozen as effect **15/36**. No runtime D1 or Migration 10 execution claim is implied.

## Class-teacher assignment P0/P2 security continuation — candidate 16/36

`teaching.class_assignment.change` is non-family-safe TC authority. The protected authorization path accepts only complete live ALL, matching CAMPUS or exact SECTION scope chains with resolver `DIRECT`; the existence of a Class Teacher assignment never grants mutation authority. Current/future ADD/END/CORRECT use the fixed P0 entry point. Retroactive CORRECT alone uses P2 with `teaching.assignment.approve`, an unambiguous active school/campus policy, configured reviewer role, exact Section-scope applicability and requester/reviewer Person separation.

No-self-assignment is enforced for ADD/CORRECT against the requester's Person and destination Employee and is rechecked at P2 apply. P2 final review stops at `APPROVED`. Apply revalidates policy, current requester and reviewer authority, Section version/ancestry, source head/facts, no-op/self rules, destination employment/capability coverage and one-teacher overlap. Deterministic invalidity yields `INVALIDATED` plus a REJECTED `request.apply`, with no `approval_applications` row, assignment effect or outbox. Unexpected SQL/infrastructure failures are not normalized to INVALIDATED.

The application guard is schema-owner trigger-only and binds a successful P2 application to a SUCCEEDED `request.apply`, fixed `D1_TEACHING_CLASS_ASSIGNMENT_APPLY` result kind, EXECUTED request, exact source/successor Section lineage, destination Employee, approved retroactive boundary, protected reason and Section version. The checked request read exposes only request state plus Section/action/source Employee/source start/destination Employee/correction date. Private reasons, arbitrary workflow JSON, receipts, identity details and authorization internals are excluded.

The provisional broad relation-33 teaching grant is revoked and replaced by explicit retained-history SELECT/INSERT columns plus the existing one-way end update. Additional teaching-executor parent privileges are read/lock-only columns required for Employee and Section ancestry validation. Authenticated receives exact RPC EXECUTE only and no base-table DML. Broad audit/outbox evidence excludes private reason text; successful domain effects emit only `teaching.class_assignment_changed`.

This remains a static, unexecuted Migration 10 draft and **candidate 16/36** pending independent review. No D1 runtime test claim is added here.

## Independent freeze note — effect 16/36

Corrected commit `9bd51d4f1b0a3768d8f4039cd3fbbcc933ac626a` passed independent authorization/ACL/workflow review and GitHub Actions run `36906436388` (121/121 tooling tests; 220/220 frozen Foundation assertions). The final correction removed CLASS as an authorization path, leaving only complete live ALL, matching CAMPUS or exact SECTION scope as approved; reviewer authority follows the same affected-Section scope rule with the configured reviewer role and `teaching.assignment.approve`. No-self-assignment, requester/reviewer Person separation, current-authority replay, deterministic invalidation, application/receipt binding, bounded checked read and minimized audit/outbox evidence were rechecked. `teaching.class_assignment.change` is frozen as effect **16/36** at that SHA. Migration 10 remains a static `.sql.draft`; no D1 runtime, D1C2 or remote Supabase execution claim is implied.
