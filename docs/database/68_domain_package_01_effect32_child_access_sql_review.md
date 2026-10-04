# D1C1B Effect 32/36 — Family Child Access SQL Review

**Status: ACCEPTED STATIC RUNTIME CANDIDATE.**

Trusted runtime candidate: `47f6d9748fe981f4c4026a06e4d51393d45a636e`.

Effect 32 implements frozen operation `family.child_access.change` as the P1 protected command for the retained Family→Student portal entitlement fact in `app_private.family_student_access`. Access remains separate from Father/Mother/Guardian relationship history, FAMILY Principal membership, Foundation authority and primary-family display context.

## Reviewed command surface

Application entry points are:

- `app.d1_change_family_child_access(...)` for P1 DIRECT;
- `app.d1_submit_family_child_access_change(...)` for P1 APPROVAL submission;
- `app.d1_review_family_child_access_change(...)` for configured review steps;
- `app.d1_apply_family_child_access_change(...)` for explicit apply after approval;
- `app.d1_read_family_child_access_request(...)` for current authorized workflow participants.

Frozen actions are **ADD** and **REVOKE** only. There is no generic CORRECT action: a mistaken entitlement is closed explicitly and any replacement is a new ADD.

## ADD and relationship basis

ADD requires an exact Student and ACTIVE Family, expected Student/Family versions, a nonblank private reason, no source access row and no overlapping retained Family/Student access interval.

The entire requested access interval must be covered by the union of approved retained `family_relationships` intervals for that exact Family+Student. The implementation reuses the Effect-30 `d1_family_relationship_access_first_gap(...)` helper, including open-ended intervals. Emergency-contact rows are never considered and therefore cannot become an access basis.

ADD also requires one current effective Family Principal membership whose Foundation `FAMILY` Principal is currently ready under the frozen family-only/family-safe credential chain. This check establishes that the Family grouping has a usable shared FAMILY credential; it does not create Foundation authority and it does not replace the separate relationship/access conjunction used by family child reads.

## REVOKE

REVOKE closes the selected unsuperseded open Family/Student access interval at an exclusive end date after its start and records end evidence. It does not delete history.

Revocation is deliberately reduction-only. It does **not** require the Family to remain ACTIVE, the relationship basis to remain current, or the FAMILY credential to remain usable. Staff authority, exact Student/Family/source identity, expected versions and source interval validity are still checked.

Ending access leaves the relationship history, FAMILY Principal membership and primary display context unchanged.

## Authorization and P1 routing

`family.child_access.change` is non-family-safe and uses frozen ACS Student-context authority: ALL, matching CAMPUS, matching CLASS or matching SECTION. `family.access.approve` uses the same ACS target context for configured reviewers.

The P1 resolver selects the one compatible active school/campus policy for the Student's current placement and fails closed on missing/ambiguous policy. APPROVAL steps require one review and `D1_REVIEWER_ROLE_SCOPE` with an active configured reviewer role.

Reviewer candidates are current authenticated INDIVIDUAL Principals, separate from the requester at Principal and Person level, with exact current `family.access.approve` authority through the configured role and affected Student scope. Review never auto-applies. Explicit apply rechecks current policy, requester authority, all accepted reviewer authority and domain facts; stale approved requests invalidate.

## Concurrency and audit corrections

The final implementation follows the frozen order:

1. Foundation authorization/idempotency prefix and current actor Principal;
2. any currently effective shared FAMILY membership Principal(s), UUID ordered;
3. Student rows, UUID ordered;
4. Family rows, UUID ordered;
5. relationship history, then access history, deterministically ordered.

Two audit-driven append-only corrections are included:

- `effect32_06_child_access_request_lock_order.sql.draft` pre-reads immutable typed request identity, takes domain locks, then locks/revalidates the approval-request row. This removes the request-row→domain inversion in the first REVIEW/APPLY draft.
- `effect32_07_child_access_family_principal_lock.sql.draft` locks the current shared FAMILY membership Principal before Student/Family anchors, then rechecks credential readiness after the Family lock stabilizes membership ancestry. This closes an ADD race with concurrent credential/Principal disablement without making REVOKE depend on credential readiness.

Expected Student and Family row versions are checked under these locks and are advanced through the frozen mutable-record update trigger when the access effect succeeds.

## Idempotency and replay

Canonical intent binds Student ID/version, Family ID/version, action, source access where applicable, effective start/end, private reason and idempotency key namespace.

Successful replay is retained-history based. In particular, an open-ended ADD remains replayable after a later legitimate REVOKE because the accepted retained row need not remain open; a REVOKE proves the retained accepted closure. Approval apply additionally verifies the exact request/application/receipt/result/version relationship.

## Workflow guards and evidence

Approval-request insertion is protected by an exact typed shape guard. Approval-application insertion is protected by request/receipt/result/version checks and typed result matching.

The only successful domain event is `family.child_access_changed`.

Broad audit/outbox evidence contains typed Student/Family/access/source IDs, action, safe versions/outcome and receipt/request/correlation references. It excludes arbitrary reason text, relationship contact/display values, Auth-user IDs, labels, child private details and copied protected request JSON. Protected workflow state retains the reason only where required.

## Exact-SHA gate

GitHub Actions run #200 (`37181000210`) completed successfully on exact SHA `47f6d9748fe981f4c4026a06e4d51393d45a636e`.

Full log inspection confirms:

- exact checkout of `47f6d9748fe981f4c4026a06e4d51393d45a636e`;
- 121/121 tooling unit tests;
- frozen Foundation source integrity (`9 migrations + 9 tests`);
- Supabase CLI 2.98.2 and Docker/Linux local stack;
- clean reset of nine frozen migrations with no seed;
- 5/5 Auth fixtures;
- lint error/warning gates passed;
- all nine Foundation TAP files passed, 220/220 assertions total.

This gate intentionally validates the frozen Foundation. Migration 10 and Effect-32 continuation SQL remain `.sql.draft`; they were not parsed, executed, deployed or remotely applied by this gate.

## Runtime boundary

The runtime delta from Effect-31 freeze tip `02e3af1e24251706019be3b8e096f6115202adc3` to trusted runtime SHA `47f6d9748fe981f4c4026a06e4d51393d45a636e` consists only of seven ordered `20260928000000_domain_package_01_effect32_*.sql.draft` files.

Foundation migrations 1–9 are unchanged. The frozen manifest remains **97 permissions / 322 scope alternatives / 36 operation contracts**. No D1C2, staging/managed Supabase application or worker activation is authorized by this review.
