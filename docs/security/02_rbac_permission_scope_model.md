# 02 - RBAC, Permission and Scope Model

**Status:** PROPOSED evaluation model and examples, 2026-09-22. Role/action/scope/assignment/workflow requirements are CONFIRMED; specific grant combinations below are illustrations, not seeded defaults.  
**Authority:** [AGENTS.md](../../AGENTS.md), [invariants](../decisions/DECISIONS_AND_INVARIANTS.md), [security rules](SECURITY_WORKFLOW_AND_AUDIT.md), [master specification](../requirements/School_OS_SaaS_Master_Specification_v0.2.md) sections 15-17 and 66.

## 1. Permission vocabulary

A permission is a resource/action pair, such as attendance.record:UPDATE, result:VIEW, result:PUBLISH or finance.payment:CANCEL. Codes are PROPOSED examples, not a final catalog. School-configurable roles group application-defined permissions; changing a label cannot introduce new operations.

| Action concept | Meaning |
|---|---|
| VIEW | Read permitted data; not implicit export or modification. |
| CREATE | Initiate an allowed record/command. |
| UPDATE | Modify permitted mutable state; does not unlock protected history. |
| CANCEL | Cancel or request a domain-defined reversal; never generic destructive delete. |
| APPROVE | Decide an assigned review step in permitted scope. |
| REJECT | Reject a review step with its required reason. |
| EXPORT | Release an authorized data set/file through a separately checked path. |
| PUBLISH | Publish after domain validation and required reviews; not implied by UPDATE or APPROVE. |

Additional command concepts already appear in requirements, including REQUEST_CHANGE and GENERATE_DOCUMENT. Their exact codes are TBD with the catalog; a generic UPDATE is not substituted for them. SQL SELECT/INSERT privileges and PostgreSQL roles are implementation mechanisms, not this business permission vocabulary.

## 2. Scope meanings

| Scope | Proposed resolution | Guardrail |
|---|---|---|
| ALL | All eligible records of the named resource inside this one school project | No cross-school reach; still subject to field restrictions, assignments where required and workflow state |
| CAMPUS | Explicit campus set for the relevant grant | A campus chosen in the UI cannot add membership |
| CLASS | Specified configured class and its applicable academic context | Does not imply every year or campus using the same label |
| SECTION | Specified section with consistent class/year/campus ancestry | Reject mismatched parent identifiers |
| SUBJECT | Specified subject offering and academic context | A reusable subject name is not all sections teaching it |
| ASSIGNED | Domain resolver checks actual current/historical responsibility for the requested action | Viewing an assignment is not making oneself assigned |
| OWN | Resolve a permitted subject relationship | Self person/student/employee, or approved family-child links in FAMILY context; never simply creator_id |

FOUNDATION enables school-wide, campus and principal/context predicates. CLASS, SECTION, SUBJECT and teaching/family/enrollment resolvers are **postponed** until their domain entities exist. Unknown or unresolved scope returns deny, not ALL.

Within one scope binding, required dimensions are intersected: campus AND section AND applicable subject/assignment. Independent allowed bindings for the same grant are alternatives. No unchecked type/id string grants arbitrary resource access. F13 in the [entity map](../database/02_foundation_entity_map.md) describes typed bindings.

## 3. A grant is an indivisible authorization unit

PROPOSED path: principal -> active role assignment -> role-permission grant -> scope binding for that same assignment and permission. Include validity interval, access context and permitted grant ceiling. Role-permission grants and assignments are revocable with retained history.

A scope binding references both the role assignment and the role-permission grant. Their role identities must agree. There is **no** free-standing account-wide scope list whose scopes can be combined with unrelated permissions.

For example, Teacher VIEW with ALL scope and Teacher UPDATE with ASSIGNED scope do not produce UPDATE/ALL. A Parent OWN grant cannot widen an Accountant CAMPUS grant, and FAMILY-context permissions never activate staff context. Multiple grants union only fully evaluated allowed results, not their individual permission/scope ingredients.

PROPOSED evaluation, as prose pseudocode:

1. Validate school-project identity, active principal and verified access context.
2. Reject unsupported resource/action or unavailable module/handler.
3. Find an active assignment and matching role-permission grant in that context.
4. Evaluate one compatible scope binding and all required contextual assignments at the relevant business time.
5. Apply resource state, field sensitivity and workflow/approval restrictions.
6. Permit only if the complete chain succeeds. Otherwise deny.

Recheck on writes, reviews, exports, background application and offline replay. Role names, dashboard selection, a cached JWT role list and possession of an object ID are insufficient.

## 4. Nine concrete examples

| Actor / example configuration | Permitted example | Denied or controlled example |
|---|---|---|
| 1. Super Admin with explicit administrative grants and ALL school scope | Manage allowed settings and reviewed grants across Main and Junior campuses | Cannot hard-delete real financial history, erase audit, bypass result locks or access another school's project; actions are audited |
| 2. Principal with school-wide VIEW and configured APPROVE/PUBLISH grants | Read permitted cross-campus reports and approve eligible requests under the configured chain | Broad visibility is not blanket mutation authority; cannot apply a stale correction or publish without the required Exam Controller review |
| 3. Campus Admin assigned CAMPUS Main | Maintain allowed Main-campus operational records | Cannot select Junior records or move a target to Junior to circumvent scope; both old and new scopes are checked for scope-changing commands |
| 4. Teacher with broader academic VIEW but UPDATE/ASSIGNED | See authorized timetable/student information; mark attendance only for the assigned official session/group and enter marks only for assigned subject/section | Cannot take another campus's attendance merely because it is visible; cannot obtain general student fee records; expired assignments fail |
| 5. Accountant with finance permissions in CAMPUS Main | Verify eligible payment evidence, view finance reports and request a reversal | Cannot mark attendance or read medical records; cannot erase payments or self-apply a protected fee change outside approval |
| 6. Parent/shared family in FAMILY context with OWN-linked children | View permitted records for linked children A and B and submit payment evidence/leave requests | Cannot view child C, claim teacher/staff privileges from the same password, or infer unrelated pupils through search/export/file links |
| 7. Student with OWN scope | View own permitted attendance/results and submit own learning work | Cannot view a peer's result by changing an ID, edit own published marks, or read fees if school policy withholds them |
| 8. Nurse with explicit medical actions and approved scope | Read/update permitted health encounters for authorized students, with audit | Generic student VIEW does not give medical access; nurse status alone does not grant payroll/finance or cross-campus access |
| 9. Exam Controller with scoped review and PUBLISH authority | Review completeness/corrections, approve and publish validated results in allowed scope | Cannot bypass pending corrections, modify a published result in place or publish outside assigned scope |

Historical access is explicit: today's teacher assignment does not automatically expose every past student's record. The next domain package must specify which historical responsibilities authorize which read/correction actions (T05).

## 5. Assignment, delegation and escalation

Role creation/editing, permission mapping, scope assignment and impersonation-like account relinking are themselves protected administrative commands. PROPOSED grant ceiling: administrators can assign only allowed roles/actions/scopes within their own delegated administration boundary; possession of an ordinary action does not itself confer the right to grant it.

Teacher, Parent and Student roles cannot be edited into unrestricted administrators. Additional administrative responsibility must be a distinct reviewed administrative assignment and appropriate verified individual context. Revoked grants retain end times and actor/reason. Delegation requires explicit bounded duration/scope; it is not inferred from a job title.

PROPOSED baseline uses positive grants with default deny and hard domain restrictions. A general configurable negative-permission system is deferred; no unspecified precedence between allow and deny lists. Separation of duties and self-approval rules are T06; the conservative proposed policy forbids approving one's own sensitive request, including under a different role.

## 6. Enforcement surfaces

- Database/API: separate read policies from allowed writes. Validate both existing and proposed scope for moves. Prevent client modification of principal links, grant ownership, approval results and server-managed versions.
- Protected commands: obtain target scope and expected state from stored data, never solely from supplied campus IDs. Perform checks and write/audit within one transaction.
- Field access: row filtering does not hide a sensitive column by itself. Split sensitive facts or use narrowly controlled read interfaces in later physical design; an approved student row must not expose medical/payroll fields.
- Views/search/reports/export/AI: use the same evaluator and disclosure limits. EXPORT is independently checked and filtered; background exports recheck access before delivery.
- Storage/notifications: object key knowledge and notification receipt do not bypass target authorization. Minimal notification content avoids leaking a formerly accessible record.
- Offline: cache only authorized working data; reauthorize queued mutations with current state. Revoked access cannot be restored by an old offline operation.
- Workers: least privilege and explicit purpose. Service credentials that bypass RLS must not turn worker APIs into arbitrary read/write proxies.

Mutable user metadata must not drive authorization, and JWT membership claims may be stale. This proposal uses live grants for security-critical decisions. [Supabase row-level security](https://supabase.com/docs/guides/database/postgres/row-level-security).

## 7. Open choices and validation

T01 covers shared-family/staff context proof; T04 covers RLS/helper placement, revocation and session assurance; T05 covers scope ancestry and historical assignment access; T06 covers reviewer eligibility/delegation. All remain PROPOSED/TBD in [ADR-001](../decisions/ADR-001-foundation-database-principles.md).

See [foundation tests](../testing/01_foundation_test_strategy.md) for paired allow/deny scenarios, scope-combination attacks, current/expired grants and cross-project isolation.

