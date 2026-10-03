# D1C1B Effect 21/36 — Student Restricted Identity SQL review

**Status: IMPLEMENTATION CANDIDATE — NOT FROZEN.**

Effect 21 implements `student.identity.correct` as the frozen P2 REQUIRED_REVIEW operation with review permission `student.identity.approve`, relation `app_private.student_identity_details`, and event `student.identity_corrected`.

## Approved behavior

- CORRECT only: an effective source snapshot must already exist; absence denies with `D1_STUDENT_IDENTITY_SOURCE_REQUIRED`.
- An accepted correction closes the exact current source at server apply time and inserts one successor at the same instant with `supersedes_id=source_snapshot_id`.
- Full replacement facts are national ID, birth-certificate number/file link, private address, city, guardian identity text and guardian contact. Nullable fields may be cleared; exact factual no-op is rejected.
- P2 review is mandatory. No DIRECT route is accepted. Requester and reviewer must be different People, not merely different Principals/roles.
- Authorization is Student ACS: current PRIMARY placement derives Section/Class/Campus; ALL/CAMPUS/CLASS/SECTION scope may satisfy the exact permission. Placement itself grants nothing.
- Review/apply recheck live requester/reviewer authority. Apply deterministically invalidates stale policy, authority, source/version or no-op/domain state; malformed protected request payload rolls back.
- Successful/deterministic terminal apply replay occurs before mutation preflight and requires current requester or exact final-approver authority. Final-approver terminal classification uses the frozen `d1_final_approver_role` helper.
- Birth-certificate link preflight accepts NULL or an AVAILABLE `BIRTH_CERTIFICATE` file; the existing structural `d1_guard_file_purpose` trigger remains the insertion-time defense. The FK relationship supplies the typed Student identity linkage and does not grant upload/download authority.
- Broad audit/outbox excludes national ID, birth-certificate number, address, city, guardian identity/contact, arbitrary reason and file internals. The outbox aggregate is the resulting `STUDENT_IDENTITY` snapshot at version 1; Student version remains the concurrency anchor/application target version.
- No authenticated direct base-table DML is added.

## Package

Ordered `.sql.draft` continuations:

1. `20260928000000_domain_package_01_effect21_01_student_identity_core.sql.draft`
2. `20260928000000_domain_package_01_effect21_02_student_identity_evidence.sql.draft`
3. `20260928000000_domain_package_01_effect21_03_student_identity_workflow.sql.draft`
4. `20260928000000_domain_package_01_effect21_04_student_identity_application_guard.sql.draft`
5. `20260928000000_domain_package_01_effect21_05_student_identity_hardening.sql.draft`

The fifth continuation records independent-audit hardening discovered while assembling the candidate: exact reviewer-role scope binding, a narrow schema-owner birth-file predicate rather than broad file-table privilege, terminal final-approver replay, and retained-history outbox aggregate semantics.

Migration 10 remains non-executable `.sql.draft`. This review authorizes no PostgreSQL application, D1C2 execution, remote deployment or staging action.