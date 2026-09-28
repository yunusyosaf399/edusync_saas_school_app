# D1B3B — D1 SQL ownership, EXECUTE and RLS matrix

**Status: SELECTED DESIGN; no SQL authorized.** D1 extends the Foundation execution-security model without weakening it. All 34 D1 base relations remain in app_private, ENABLE RLS and FORCE RLS. app_private remains excluded from the application Data API exposure list. No D1 base table receives anon/authenticated direct SELECT or DML.

## Runtime roles

Existing Foundation roles remain unchanged. D1C may add the following NOLOGIN, NOINHERIT, NOSUPERUSER, NOCREATEDB, NOCREATEROLE, NOBYPASSRLS executor roles. They are not members of each other or schoolos_schema_owner.

| Role | D1 write ceiling | Read/input ceiling |
|---|---|---|
| schoolos_academic_executor | relations 01–06 only: Class, Subject, offerings, section-room and capacity revision effects | Exact academic parents plus private authz/evidence functions needed by fixed commands. |
| schoolos_student_executor | relations 07–16 and 22: allocators, roll, Student core/snapshots/status/enrollment/override/emergency contact | Exact Student/placement/academic parents and fixed file relationship checks. |
| schoolos_family_executor | relations 17–21: Family, relationship, FAMILY principal membership, child access and primary context | Exact Student/Family/principal identifier inputs; no Foundation grant mutation. |
| schoolos_employee_executor | relations 23–31: Department, Designation, Employee core/history/identity/qualification/experience/job/campus affiliation | Exact Employee/Person/Campus parents and authz/evidence helpers. |
| schoolos_teaching_executor | relations 32–34: Teacher capability, class-teacher and subject-teacher assignments | Exact Employee eligibility and Academic target inputs. |

schoolos_read_executor remains the owner of checked read functions and receives column-limited SELECT only on the sources used by those functions. schoolos_authz_reader remains owner of private authorization evaluators. schoolos_evidence_writer remains the only broad application evidence append boundary. schoolos_workflow_executor owns workflow request/review/application orchestration and may EXECUTE only fixed private D1 apply functions for registered operation codes; it receives no general D1 table DML. schoolos_platform_executor/file worker remains the file metadata/provider boundary.

No new worker LOGIN is justified by D1. Worker activation remains separately gated.

## Authorization-reader inputs

schoolos_authz_reader may receive SELECT only on identifiers, state and effective intervals required to resolve D1 scope:
- academic_classes: id, school_id, state only when class eligibility is checked
- class_offerings: id, school_id, class_id, campus_id, academic_year_id, state
- section_offerings: id, class_offering_id, campus_id, state
- subjects: id, school_id, state
- students: id, person_id, current_status
- enrollments: id, student_id, section_offering_id, placement_kind, placement_state, effective_from, effective_until
- families: id, state
- family_principal_memberships: family_id, principal_id, principal_kind, effective_from, effective_until
- family_student_access: family_id, student_id, effective_from, effective_until
- family_relationships: id, family_id, student_id, relationship_kind, effective_from, effective_until; no relationship_contact/display value is needed for authorization
- employees: id, person_id, current_state
- employment_periods: employee_id, state, effective_from, effective_until
- employee_campus_affiliations: employee_id, campus_id, effective_from, effective_until; used only to resolve an Employee target into a CAMPUS scope, never as authority by itself
- teacher_capabilities: employee_id, effective_from, effective_until
- class_teacher_assignments: section_offering_id, employee_id, effective_from, effective_until
- subject_teacher_assignments: section_offering_id, subject_id, employee_id, assignment_kind, effective_from, effective_until

It does not receive Student identity/special/contact values, Employee National/CNIC, qualification/experience content, profile photos, broad audit/outbox payloads or arbitrary file metadata.

Authorization-reader RLS input policies are simple role-specific SELECT predicates that do not call a D1 evaluator. This prevents evaluator → input-table-policy → evaluator recursion.

## Base-table RLS policy classes

| Policy class | TO role | Command | Predicate rule |
|---|---|---|---|
| AUTHZ_INPUT | schoolos_authz_reader | SELECT | Simple role-specific visibility over only the listed resolver relations; no evaluator calls. |
| CHECKED_READ | schoolos_read_executor | SELECT | Role-specific internal read policy on exact source relations. Disclosure is enforced by the SECURITY DEFINER checked read before output. |
| ACADEMIC_EXEC | schoolos_academic_executor | SELECT/INSERT/allowlisted UPDATE as required | Only relations/columns used by academic fixed commands. No DELETE/TRUNCATE. |
| STUDENT_EXEC | schoolos_student_executor | SELECT/INSERT/allowlisted UPDATE as required | Only Student/roll/enrollment/emergency relations and required parents. No generic history UPDATE/DELETE. |
| FAMILY_EXEC | schoolos_family_executor | SELECT/INSERT/one-way end/update as required | Only Family relations and required parent identifiers. No Foundation RBAC DML. |
| EMPLOYEE_EXEC | schoolos_employee_executor | SELECT/INSERT/allowlisted UPDATE as required | Employee/organization relations only. |
| TEACHING_EXEC | schoolos_teaching_executor | SELECT/INSERT/one-way end/update as required | Teacher capability/assignment relations only. |
| SCHEMA_OWNER | schoolos_schema_owner | none at runtime | No ordinary runtime policy; ownership is deployment/DDL, not application authority. |

Privileges and RLS are both required. A role-specific policy does not imply the role has every column privilege, and a column grant does not bypass FORCE RLS. Defensive triggers preserve immutable/history rules even for executor operations.

## Function exposure and ownership

- app checked-read and protected-command functions are the only D1 application entry points eligible for authenticated EXECUTE.
- Every exposed function derives principal/context from the verified Foundation helper. No acting_principal, role, scope_kind, resolver_key, campus ancestry or permission list from Flutter is trusted as authority.
- Functions use hardened search_path = pg_catalog, pg_temp and schema-qualified application objects.
- PUBLIC, anon and service_role receive no D1 application-function EXECUTE. service_role remains an infrastructure API role with BYPASSRLS characteristics but gets no application schema/table/function grant shortcut.
- authenticated receives EXECUTE only on the explicit fixed D1 entry-point inventory selected in D1C. It receives no direct EXECUTE on current_principal_id, D1 arbitrary-target evaluators, evidence writers, workflow apply internals, file workers or defensive triggers.
- No SECURITY DEFINER function returns arbitrary table rows/JSON selected by a caller-provided resource name.
- D1 private evaluator functions are owned by schoolos_authz_reader and return booleans/minimal resolution data only. authenticated cannot call them directly.
- D1 mutation functions are owned by the matching narrow executor role. They call private authz functions and evidence writers through explicit EXECUTE, not role membership.
- Approved workflow application calls a fixed private domain apply function by registered operation code/typed target; it cannot pass SQL, function names or arbitrary patch JSON.

## Read-executor column discipline

schoolos_read_executor may read only columns needed to assemble each checked surface. A high-sensitivity surface does not make those columns available to lower-sensitivity read functions: each function explicitly selects its output columns after authorization. Where PostgreSQL column privileges cannot practically isolate two functions owned by the same role, function implementation still uses explicit columns and executable tests must prove no extra output; a later split read-executor role is preferred over granting base-table SELECT to authenticated.

## Moves and changing targets

Commands that can change scope authorize both the stored source and proposed destination from trusted rows/IDs. Examples include enrollment move/campus transfer, Employee campus-affiliation change, Section room change and teaching reassignment. After advisory/row-lock waits, the command reloads ancestry and authorization before applying. Client-provided campus/class/year labels are display/request hints only.

## Family and teaching hard barriers

- FAMILY principal evaluation first validates FAMILY context and family_safe permission, then only OWN / D1_FAMILY_CHILD. Direct and teaching alternatives are denied for FAMILY.
- D1_STUDENT_SELF and D1_EMPLOYEE_SELF require INDIVIDUAL principal → Person → exact domain identity.
- D1_CLASS_TEACHER and D1_SUBJECT_TEACHER require INDIVIDUAL principal → Employee → active employment → current Teacher capability → exact effective assignment.
- D1_TEACHING_ANY is a union of complete exact teaching paths only for permissions that explicitly support it; it is not wildcard scope.
- Employee Campus Affiliation, Department, Designation, qualification and specialization never satisfy an action permission.

## D1C non-owner executable gate

Before D1B3B can be considered implemented, D1C tests must run under non-owner roles and prove:
1. anon/authenticated/service_role have zero D1 base-table direct DML and no unintended SELECT.
2. authenticated can EXECUTE only the enumerated public D1 entry points and cannot EXECUTE private evaluators/evidence/apply/worker helpers.
3. schoolos_authz_reader lacks sensitive value columns and its RLS input policies are nonrecursive.
4. every family-safe positive path has a paired unrelated-child/direct-scope/individual-vs-FAMILY denial.
5. Subject-teacher ROSTER works only in exact Section+Subject assignment, while PROFILE denies; class-teacher PROFILE requires its separate grant.
6. Student restricted identity self-read denies; staff restricted read succeeds only with exact permission/scope.
7. historical reads deny with only current VIEW, deny after current grant/access revocation, and cannot revive authority from an old teaching assignment.
8. Employee CAMPUS target resolution uses effective campus affiliation without treating affiliation as a grant.
9. every scope-changing command checks source and destination after locks.
10. grant/scope administration requires Foundation EXCLUSIVE authorization lock, while D1 business commands use SHARED and cannot mutate grants.
11. sensitive audit/outbox events contain no raw protected values.
12. file purpose mismatch/object-ID guessing denies.
13. all frozen Foundation database tests 01–09 continue to pass unchanged.

No executable D1 test is created in D1B3B.
