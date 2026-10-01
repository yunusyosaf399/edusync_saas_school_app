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
School/Campus/Year/Room anchors have SELECT-only RLS and cannot perform an
application update. The authorization evaluator remains owned by
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
