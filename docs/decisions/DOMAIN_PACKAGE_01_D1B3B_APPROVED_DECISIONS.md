# D1B3B — approved disclosure and historical-access decisions

**Status: PRODUCT DECISIONS APPROVED, design only; no SQL authorized.** Approved by the product owner on 2026-09-28 after D1B3A. These decisions govern D1B3B permission, checked-read and command design. They do not authorize migration 10, executable database tests, remote deployment, worker activation or Flutter implementation.

| ID | Approved D1B3B rule | Security consequence |
|---|---|---|
| D1B3B-01 | A current FAMILY principal may read the current emergency-contact display name, relationship, phone and email for an actively linked child, but only through a separate family-safe checked permission. | Emergency Contact remains a fact, never a guardian principal, child-access basis, staff authority or search/export capability. FAMILY receives no Person ID, lineage, audit or historical emergency-contact disclosure. |
| D1B3B-02 | Student self-service does not receive RESTRICTED IDENTITY by default. | D1_STUDENT_SELF is not a supported scope alternative for Student restricted-identity current/history permissions. National ID/B-Form, birth-certificate data/file, private address and guardian identity/contact remain separately protected. |
| D1B3B-03 | Teacher PROFILE access beyond ROSTER is limited to an exact current class-teacher assignment when the separate PROFILE permission is granted. | student.profile.view may support D1_CLASS_TEACHER. D1_SUBJECT_TEACHER and D1_TEACHING_ANY do not authorize PROFILE. Subject teachers remain ROSTER-only by the D1 baseline. No teaching resolver grants RESTRICTED IDENTITY or SENSITIVE/SPECIAL disclosure. |
| D1B3B-04 | Historical reads are separate permissions and are never implied by current VIEW. No D1 role/template receives historical authority by default. | A historical read requires a present live grant plus the explicit historical permission, current principal/context validity, and the target relationship/placement relevant to the requested historical date. A former teaching assignment cannot revive access after current authority ends. Student/FAMILY/Employee own-history surfaces may exist only through their explicit history permissions. |

## Family principal hard boundary

For every D1 permission marked family_safe, a FAMILY principal may satisfy only the reviewed OWN / D1_FAMILY_CHILD contextual path. Direct ALL/CAMPUS/CLASS/SECTION/SUBJECT and teaching ASSIGNED bindings are not admissible for a FAMILY principal even if a permission also supports those alternatives for staff. A current family membership, current family-student access and approved relationship basis remain mandatory. This prevents an accidental family-role ALL binding from becoming school-wide authority.

## Default grant posture

D1B3B freezes application permission codes and supported scope contracts, not role templates. No role-to-permission grant, principal assignment or scope row is seeded or inferred from labels such as Parent, Teacher, Principal, Department or Designation. Historical permissions are registered only as available capabilities; they receive no default role grant.

## Related design

The exact permission/scope/disclosure catalog is in ../security/08_domain_permission_disclosure_catalog.md. Checked reads, protected commands, approval/audit/outbox and file-purpose bindings are in ../security/09_domain_checked_reads_and_commands.md. SQL ownership, EXECUTE and RLS boundaries are in ../security/10_domain_execution_rls_matrix.md.

**Decision boundary:** these product choices close the four D1B3B disclosure questions left by D1B3A. Any later widening of FAMILY emergency history, Student restricted identity, Subject-teacher PROFILE, or default historical grants is a new product/privacy decision, not a D1C implementation detail.
