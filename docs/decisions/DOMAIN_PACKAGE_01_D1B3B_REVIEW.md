# D1B3B — permission, RLS, checked-read and protected-command review

**Status: DESIGN PASS, no SQL authorized.** Reviewed from exact trusted HEAD 082d11a3ba720bd37bf197e248788bf791240802 after product-owner approval of the four D1B3B disclosure defaults. The permission/disclosure catalog, command/read contract and execution/RLS matrix complete the D1B3 security design. D1B3A scope storage/resolver architecture remains intact.

| Review area | Selected D1B3B contract |
|---|---|
| Product/privacy gate | Parent/FAMILY may see current Emergency Contact through a separate family-safe checked permission; Student self Restricted Identity denies; only class-teacher may receive PROFILE beyond ROSTER; all historical reads use separate permissions with no default role grants. |
| Permission catalog | Deployment-owned exact D1 permission codes are frozen by security/08. No school-defined executable code and no role-template grants are seeded. family_safe is true only for the reviewed FAMILY read capabilities. |
| Scope alternatives | Each permission names an exact support set. ROSTER supports D1_TEACHING_ANY; PROFILE supports D1_CLASS_TEACHER but not Subject teacher; sensitive Student reads have no OWN/ASSIGNED path. FAMILY principal is hard-limited to OWN/D1_FAMILY_CHILD even when the same family-safe permission has direct alternatives for staff. |
| Historical rule | Current VIEW never implies history. Present live authority is required; as-of target relationship/placement is additional evidence. Ended teaching responsibility cannot revive current access. |
| Checked reads | Fixed typed, field-limited read contracts select both row and disclosure class. No broad Student/Employee row, arbitrary JSON projection, anonymous read or Flutter-only hiding. |
| Commands | Fixed-purpose protected commands use expected state/version, SHARED Foundation authorization lock plus D1B2 aggregate locks, command receipts, current reauthorization after waits and retained domain history. No client direct DML. |
| Approval | Three classes are defined: protected direct, policy-reviewed, and required-review. Sensitive Student/Employee identity and special/factual corrections require review; configured high-risk status/enrollment/family/employee operations route through Foundation workflow. Capacity override explicitly needs its action permission/reason/audit but no approval solely for capacity. |
| Audit/outbox | Safe event vocabulary is selected. Broad payloads are identifiers/state evidence only and forbid raw identity, guardian/emergency contact, special, qualification/experience values, arbitrary reason text and file capabilities. Outbox activation is not authorized. |
| Files | D1 file FKs are bound only to STUDENT_PROFILE_PHOTO, BIRTH_CERTIFICATE and EMPLOYEE_PROFILE_PHOTO. FK presence never activates upload/download. Student/FAMILY self upload and Employee self upload are not D1 baseline. Other HR/student document purposes remain later typed-domain work. |
| SQL roles/RLS | All 34 D1 tables remain app_private + FORCE RLS. Existing read/authz/evidence/workflow/platform roles are reused; five narrow D1 mutation executor roles are designed. No runtime role membership chain, BYPASSRLS, broad service_role shortcut or authenticated private-table access. |
| Resolver input correction | employee_campus_affiliations is added to the future authz-reader input list only to resolve an Employee target against CAMPUS scope. It is still non-authorizing by itself. |
| Test gate | D1C must add non-owner paired allow/deny tests for disclosure, FAMILY isolation, teacher ROSTER/PROFILE split, historical denial, source/destination moves, ACL/EXECUTE, sensitive payload redaction and file purpose mismatch while rerunning frozen Foundation tests unchanged. |

## Approved disclosure decisions

The product-owner decision record is DOMAIN_PACKAGE_01_D1B3B_APPROVED_DECISIONS.md. These choices are no longer D1B3B TBDs.

## Security invariants retained

- role label, Department, Designation, qualification, Employee Campus Affiliation, Emergency Contact and historical relationship grant nothing.
- FAMILY and INDIVIDUAL principals do not borrow each other's roles or contextual relationships.
- subject authority is exact Section+Subject; same subject catalog identity elsewhere is not authority.
- present live grant is required for every read/write, including history.
- RLS and SQL privileges are both default-deny; no base table is made public for convenience.
- Foundation grant/scope mutation remains isolated behind the EXCLUSIVE authorization lock. D1 business commands use SHARED and never self-grant.
- Foundation migrations 1–9 and tests 01–09 remain frozen.

## D1C boundary

D1B3B freezes design contracts only. D1C may draft the exact migration-10 SQL, SQL function signatures/names, grants/policies/triggers, seeded deployment permission/operation/event catalog rows and executable tests **only after separate authorization**. D1C must implement the already-reviewed 34 relations, D1B2 constraints/locks/indexes and D1B3A/B security contracts without silently widening them.

No migration 10, SQL file, executable test, Supabase configuration, remote action, Flutter change, worker activation or production/customer deployment is authorized by this pass.

**Verdict:** DOMAIN PACKAGE D1B3B PASS — PERMISSION/DISCLOSURE, CHECKED READ, PROTECTED COMMAND, APPROVAL/AUDIT/FILE AND RLS/EXECUTION CONTRACTS FROZEN — READY FOR SEPARATE D1C SQL-DRAFT AUTHORIZATION — NO SQL AUTHORIZED.

## D1B4 product-owner refinement (subsequent decision)

The original review above remains the historical D1B3B result. During D1B4 the product owner explicitly approved **ten domain-specific P1 review permissions**: `student.roll_policy.approve`, `student.roll.approve`, `student.profile.approve`, `student.emergency_contact.approve`, `employee.profile.approve`, `employee.qualification.approve`, `employee.experience.approve`, `employee.job_assignment.approve`, `employee.campus_affiliation.approve`, and `teaching.capability.approve`. The deployment-owned D1 permission vocabulary is now **97 codes** with **322 supported scope alternatives**; the **36 operation contracts** are unchanged. The exact mapping is recorded in the corrected [command matrix](../security/09_domain_checked_reads_and_commands.md) and each code's `family_safe=false` direct scope set is in the [permission catalog](../security/08_domain_permission_disclosure_catalog.md).

This refinement removes P1 reviewer-authority ambiguity. It leaves D1B3A storage/resolvers and all disclosure/privacy decisions unchanged. No role, reviewer assignment, grant or school policy is seeded; in approval mode the exact permission, complete live scope grant, configured Foundation workflow step/role eligibility, current target authority and self-approval separation are all required. It authorizes no SQL or runtime deployment.
