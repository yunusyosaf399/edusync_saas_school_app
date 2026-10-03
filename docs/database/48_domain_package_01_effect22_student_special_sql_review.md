# D1C1B Effect 22/36 — Student Special SQL review

**Status: IMPLEMENTATION CANDIDATE — POST-CI REVIEWED.**

Effect 22 implements `student.special.correct` as the frozen P2 REQUIRED_REVIEW operation with review permission `student.special.approve`, relation `app_private.student_special_details`, and event `student.special_corrected`.

## Approved behavior

- CORRECT only: one effective source snapshot must already exist; absence denies with `D1_STUDENT_SPECIAL_SOURCE_REQUIRED`.
- An accepted correction closes the exact current source at server apply time and inserts one successor at the same instant with `supersedes_id=source_snapshot_id`.
- Full replacement facts are `disability_indicator`, `orphan_indicator`, and `blood_group_code`; nullable booleans preserve unknown as distinct from false.
- Canonical blood-group values are `A_POSITIVE`, `A_NEGATIVE`, `B_POSITIVE`, `B_NEGATIVE`, `AB_POSITIVE`, `AB_NEGATIVE`, `O_POSITIVE`, `O_NEGATIVE`, or NULL.
- Exact factual no-op is rejected; reason-only changes do not create history.
- P2 review is mandatory. No DIRECT route is accepted. Requester and reviewer must be different People, not merely different Principals or roles.
- Authorization is Student ACS: current PRIMARY placement derives Section/Class/Campus; ALL/CAMPUS/CLASS/SECTION scope may satisfy the exact permission. Placement itself grants nothing.
- Review/apply recheck live requester/reviewer authority, policy, Student version, exact source snapshot/facts, and current placement ancestry. Deterministic stale conditions invalidate the approved request; malformed protected workflow data rolls back.
- Terminal `request.apply` replay returns the durable result without duplicate mutation/evidence and requires current requester or exact final-approver authority.
- Broad audit/outbox excludes disability indicator, orphan indicator, blood group, and arbitrary reason text. The outbox aggregate is the resulting `STUDENT_SPECIAL` snapshot at version 1; the Student remains the authorization/concurrency target.
- The application guard binds successful apply receipt, request target/version, exact predecessor facts, exact successor facts, lineage, and close/append timestamp.
- No authenticated direct base-table DML is added.

## Package

Ordered `.sql.draft` continuations:

1. `20260928000000_domain_package_01_effect22_01_student_special_core.sql.draft`
2. `20260928000000_domain_package_01_effect22_02_student_special_evidence.sql.draft`
3. `20260928000000_domain_package_01_effect22_03a_student_special_submit.sql.draft`
4. `20260928000000_domain_package_01_effect22_03b_student_special_review.sql.draft`
5. `20260928000000_domain_package_01_effect22_03c_student_special_apply.sql.draft`
6. `20260928000000_domain_package_01_effect22_03d_student_special_read.sql.draft`
7. `20260928000000_domain_package_01_effect22_04_student_special_guard.sql.draft`

Independent audit corrected the application binding before freeze so predecessor/successor values cannot diverge from the reviewed request while still producing a successful application row.

Migration 10 remains non-executable `.sql.draft`. This review authorizes no PostgreSQL application, D1C2 execution, remote deployment or staging action.