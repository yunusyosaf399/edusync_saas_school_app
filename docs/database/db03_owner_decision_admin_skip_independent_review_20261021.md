# DB-03 owner decision — ADMIN-SKIP-AUTH Option B: independent second-person review

**Date:** 2026-10-21. **Decision:** OWNER APPROVED. **Implementation:** NOT INSTALLED/TESTED. **Workstream:** DB-03 Admissions, [PR #102](https://github.com/yunusyosaf399/edusync_saas_school_app/pull/102).

## Binding product decision

The owner explicitly selected:

> "For DB-03 ADMIN-SKIP-AUTH, I approve Option B: administration test skips require independent approval by a second authorized reviewer. FAILED cannot be bypassed."

**Rules now frozen for DB-03 design:**
1. **Requester:** an authorized current School administration Principal may request a skip for one pending, unassessed **ADMISSION_TEST** stage of one identified Admissions application, with reason and expected source versions.
2. **Second reviewer:** a **different** currently authorized Principal with approved reviewer role, current relevant application/Campus scope and live Foundation review permission independently APPROVES or REJECTS the request. `reviewer_id != requester_id` must be enforced at the time of review **and protected execution**. One person holding two roles or two logins does not satisfy independence if the same underlying authorized Principal acts both times.
3. **Mandatory Foundation workflow:** this action's `app_private.operation_contracts.requires_approval = true`; the operation has a specific request_permission_id and a **non-null distinct review_permission_id**; an active matching `app_private.approval_policy_versions` and appropriate reviewer role/template/assignment and actual typed review evidence are required. **No DIRECT bypass**, no default actor self-approval, no unregistered app-local `approved_by` flag.
4. **Applied effect after review:** an APPROVED review is not itself `ADMIN_TEST_SKIP`. A trusted Foundation-execution-bound DB-03 command **must recheck** the request's operation, target app, specific stage and expected versions, current authenticated actor/reviewer evidence, current unassessed test and permission/approval status, then atomically apply exactly one immutable `ADMIN_TEST_SKIP` effect. The request must progress to genuine `EXECUTED` through Foundation's approved lifecycle/receipt protocol; a stale APPROVED request does not authorize current READY.
5. **Recorded FAILED is a hard barrier:** a current FAILED assessment rejects both new skip execution and final READY/Student Creation. A request APPROVED before a competing examiner FAILED does **not** override the failure. A PASSED assessment also makes SKIP unnecessary/ineligible. A published-policy SKIPPED stage is separate from an application-specific reviewed skip.
6. **No other bypass:** a valid reviewed skip permits continuing **other** admission requirements; actual Finance-authorizer clearance, verified Person, required documents, school adjudication and D1 intake authorization remain mandatory. The School handles offers internally and Admissions concessions are not Finance clearance.
7. **History:** immutable request, review and applied skip references must survive rejection, invalidation and later auditing; no fabricated test PASSED or mutation of earlier FAILED result.

**Exact Foundation schema verified:** `app_private.operation_contracts`, `approval_policy_versions`, `approval_step_templates`, `approval_requests`, `approval_request_steps`, `approval_step_reviewers`, `approval_reviews`. Real `approval_requests` has `requester_id`, operation/policy/target version and lifecycle; `approval_reviews` has `reviewer_id`, review decision and expected request version; `approval_request_steps.required_reviews = 1` in existing Foundation DDL. Therefore product's *two persons* = one request author + **one independent reviewing authorizer**. Database FKs do not by themselves enforce requester ≠ reviewer; protected command must. `approval_requests` (NOT `approval_applications`) is the real FK target. Foundation permission_scope_contracts allows `ALL,CAMPUS,OWN,ASSIGNED`, not a literal SECTION enum.

## Design consequence

- Update [ADMIN-TEST-01 candidate](db03_admission_test_skip_protected_operation_contract_20261021.md) from undecided DIRECT-vs-REVIEWED to **REVIEWED only**. The previous DIRECT branch is retained as historical alternative, **rejected for DB-03**.
- Proposed `app_private.admission_stage_exceptions` (#15) `approval_request_id` becomes **NOT NULL for applied ADMIN_TEST_SKIP** and must be an FK to actual Foundation `approval_requests(id)`, with checked operation/target/approval version and one typed applied effect. If #15 is ever extended to other exception kinds, its mixed nullable schema needs a separate review rather than relaxing ADMIN_TEST_SKIP.
- **Approval timing:** if examiner records FAIL at any point before protected skip execution, deny the applied skip even if independent review has just approved; no application READY from a FAILED. The reviewer likewise must recheck current assessment when deciding; never approve from a stale prelock read.
- **Authority limits still pending:** actual permission/role IDs and grade/campus resolver, which administrators can request, reviewer role and independence evidence, reason vocabulary, cancellation/invalidation/replay UI behavior, P4 retake rescission, exact Foundation handler registry install, SC-06 global lock rank and Finance adapter are not granted by this decision. The selected **two-person REVIEWED route** itself is no longer an open owner choice.

No executable SQL, operation registration, role grants, hosted database mutation, Foundation/D1/Finance/DB-01/02/04 edit, test execution or PR merge is authorized merely by recording this decision.
