# D1 Effect 30 — P1 final-reviewer scope revoked after APPROVE, before APPLY

Date: 2026-10-11
Verdict: **PASS — exact-source disposable PostgreSQL business acceptance. Full D1 remains OPEN.**

## Source and verified GitHub Actions

- Previously accepted `main`: `50b9e920fa52c7c04c0f2d1d6580049962e23b98`.
- [PR #27](https://github.com/yunusyosaf399/edusync_saas_school_app/pull/27) was merged at `db9fadfdc827d088dce7fb3ee09c349660f5e112` from exact accepted head `17de4e00df66a1781562a8d6bf3a190ef8a62137`. Both successful GitHub workflows checked out the same merge-ref tree `796cb3c21ba04615bcf378a5a8a9b74bf4adc977`, merging that head into that exact previous base. The accepted production `main` merge has the same parents/content.
- [D1 disposable runtime #224](https://github.com/yunusyosaf399/edusync_saas_school_app/actions/runs/38123586371): **PASS**; **873/873** D1 business pgTAP assertions over **21** suites, including **36/36** new `21_family_relationship_p1_reviewer_scope_stale_apply.sql` assertions; **220/220** post-D1 Foundation regressions; **34/34** D1 Python acceptance tooling unit tests; **13/13** real observed-lock two-session races (three Employee creation, three Family membership, seven Family relationship).
- [Foundation #411](https://github.com/yunusyosaf399/edusync_saas_school_app/actions/runs/38123586389): **PASS**; **190/190** tooling unit tests, nine frozen migrations plus nine test files, **220/220** SQL assertions.
- The run assembled and applied **202 non-executable Migration 10 `.sql.draft` fragments** exclusively on disposable local PostgreSQL. **34/34** D1 relations forced RLS; **540** final SQL functions (**522** SECURITY DEFINER), no private-helper direct authenticated/anon/service-role EXECUTE; five synthetic Auth fixtures; both local SQL lint levels PASS. No hosted database or executable migration changed.

## Acceptance boundary and exact business evidence

Previously accepted Effect 30 P1 tests checked a reviewer's revoked grant **before** their decision, a requester's permission revoked **after** approval, and current-authority restrictions on protected P1 request reads. This test isolates the previously untested case: the **already approved final reviewer loses only their permission assignment scope before the separate APPLY**.

A disposable fixture configures one real APPROVAL step with an active review policy, one verified requester, and a **different authenticated Person/Principal reviewer** assigned the required `family.access.approve` permission with ALL/DIRECT scope. The requester SUBMITs a valid Student A / Family A relationship ADD, storing a **PENDING v3** request. That real reviewer APPROVEs, producing **APPROVED v4** and exactly one immutable review. APPROVE does not mutate the Family/Student history.

Before APPLY, the schema owner sets `revoked_at` on **only** the selected reviewer's `assignment_permission_scopes` row. The reviewer role-permission grant and the requester's own mutation grant remain live; the approval policy remains ACTIVE, expected Student/Family aggregate versions remain current, and business facts remain unchanged. An authenticated requester then APPLYs the reviewed request. The runner verifies:

- The application returns **INVALIDATED v5** with no relationship identity, rather than `EXECUTED`.
- A rejected typed APPLY command receipt records exactly `D1_FAMILY_RELATIONSHIP_REVIEW_AUTHORITY_STALE` and exactly one immutable `APPROVED → INVALIDATED` transition; no successful application evidence is inserted.
- Replaying the same idempotency key returns the exact original terminal state/version and null result without duplicate receipt or review; a different-key attempt cannot reopen a terminal request.
- The real earlier APPROVE review and request history are retained. No Family relationship or primary-context history, Student child-access entitlement, or success outbox event is created. Original Student and Family versions remain unchanged.
- The test never grants authenticated users raw read access to `app_private.approval_requests`, `approval_reviews`, or `approval_applications`. Assertions of retained private history run under the test owner's role, outside authenticated-role segments.

This is **36 new rollback-only pgTAP assertions**; it is **not** a new concurrency case, so the previously frozen **13/13 lock-observed races remain unchanged**.

## Failed attempts, diagnosis and corrected-source gate

The first proposed head `7c156f381e1bea92ce4f15b702c1c9ac7e1721fe` had [D1 runtime #219](https://github.com/yunusyosaf399/edusync_saas_school_app/actions/runs/38122464283) fail inside the new fixture: it asserted a nonexistent SUBMIT return field `request_state`. No domain code was implicated; prior 20 business suites passed. The corrected head `7b43dc0ae177cb2b5036405ba00d739e37be6319` had [D1 runtime #221](https://github.com/yunusyosaf399/edusync_saas_school_app/actions/runs/38123163938) fail because the fixture attempted to inspect the private `approval_requests` table as `authenticated`, and PostgreSQL correctly denied raw access. The corresponding Foundation #408 and #409 workflows passed.

Two final test-only corrections moved the private state check **after RESET ROLE** and added a Python unit test guard that forbids raw private approval-table reads in any authenticated test segment. The **exact final source passed both checks** at D1 #224 and Foundation #411. These intermediate failed commits were **not merged**. No permission was broadened or frozen domain behavior changed.

## Accepted checkpoint and outstanding work

Exactly three acceptance files changed:
- `supabase/tests/domain/21_family_relationship_p1_reviewer_scope_stale_apply.sql` — new rollback-only suite.
- `tools/supabase/domain_business_ci.py` — register the 21st suite with its 36 assertions.
- `tools/supabase/tests/test_domain_acceptance_ci.py` — guard suite registration/rollback and authenticated client ACL boundaries.

This **21-suite, 873-assertion D1C2A disposable-local business checkpoint** is accepted and frozen at the verified PR head and merge SHA. The prior **13/13 real two-session race checkpoint remains accepted**. This is not full Effect 30, full D1, a migration activation, or remote deployment approval.

**Still OPEN:** broader live scope/policy and approval/replacement permutations, full Family checked portal reads and field disclosure, populated upgrades, other D1 operations, Admissions/Finance, hosted application/activation. Migration 10 remains **202 inactive `.sql.draft` fragments**.

**Checkpoint:** `D1_EFFECT30_P1_REVIEWER_SCOPE_STALE_APPLY_PASS — 873/873 BUSINESS — 220/220 FOUNDATION — 34/34 D1 UNIT — 13/13 OBSERVED-LOCK RACES — 202 DRAFT FRAGMENTS — FULL D1 OPEN`.
