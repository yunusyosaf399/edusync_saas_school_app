# D1 Restricted Employee Identity P2 REJECT and stale requester — independent acceptance review

Date: 2026-10-14

**Verdict: ACCEPTED additional Employee Restricted Identity P2 rejection and revoked-requester invalidation scenarios**, complementing prior [approved ADD/CLEAR review #137](137_d1_employee_identity_p2_approval_history_business_acceptance_review.md). This adds depth, **not another distinct accepted operation**.

## Verified exact-head acceptance evidence

Candidate head `e3b3413c4947d0725d9577f478dd7eceb2c900e2`; merge [PR #58](https://github.com/yunusyosaf399/edusync_saas_school_app/pull/58) at `a2a41bd802d0dd74fede4db6c24f1ce0876d4bb3`. Verified merge parents are prior frozen `main` `96a7160dd5d0bf89e901b94a98866087149def72` and exact candidate head. [D1 PR runtime #38526549186](https://github.com/yunusyosaf399/edusync_saas_school_app/actions/runs/38526549186), [D1 push runtime #38526540928](https://github.com/yunusyosaf399/edusync_saas_school_app/actions/runs/38526540928), [Foundation PR #38526549295](https://github.com/yunusyosaf399/edusync_saas_school_app/actions/runs/38526549295), [Foundation push #38526540933](https://github.com/yunusyosaf399/edusync_saas_school_app/actions/runs/38526540933), [D1 static #38526548997](https://github.com/yunusyosaf399/edusync_saas_school_app/actions/runs/38526548997) all **PASS**. D1: **50/50 suites, 2,581/2,581 assertions**, **65/65 Python**, Foundation **221/221 Python** and **220/220 SQL**, pre-existing **19** genuinely observed two-session race checks retained, 207 inactive draft fragments loaded into disposable local stack, 34/34 forced-RLS relations, final 541 functions/523 SECURITY DEFINER (157 app / 384 private), zero private EXECUTE exposed to authenticated, anon or service_role, static signature-shape drift 0. Migration 10 remains inactive `.sql.draft`; no hosted Supabase deployment.

New `supabase/tests/domain/49_employee_identity_p2_reject_requester_stale.sql` passed **32/32** pgTAP assertions in both D1 runtime runs.

## Observed behavior

A verified requester creates a synthetic Employee and submits an identity correction under a live one-step mandatory APPROVAL policy with a separate real authenticated reviewer and matching `employee.identity.approve` permission and role/scope. Requester self-review and premature APPLY are prohibited. A selected independent reviewer submits an explicit **REJECT**; state advances to terminal REJECTED v4. A same-key review REJECT replay returns the same decision without duplication, and reusing its key with APPROVE fails the exact canonical intent check. Original SUBMIT receipt remains replayable without creating new requests; rejected APPLY fails. Exactly one immutable reviewer decision, one terminal workflow transition, one typed review receipt, **zero** identity snapshots, approval applications or `employee.identity_corrected` success events result.

A distinct second synthetic Employee/request undergoes genuine independent APPROVE. Revoking the requester's current role-permission grant before terminal application causes authorized final-approver APPLY to produce **INVALIDATED** without restricted-identity mutation, application proof or success event. The negative revocation is rolled back at a savepoint; the entire suite ends with transaction ROLLBACK.

## Real-runtime ACL issue exposed and corrected

The first exact-head batch D1 run completed suite 48 but failed at exact terminal **REJECT replay**. The original workflow-executor-owned review RPC attempted a direct SELECT against `app_private.command_receipts`, for which the NOLOGIN workflow executor has deliberately **no table SELECT**. This was not worked around with an unrestricted grant.

An append-only inactive `supabase/migrations/20260928000000_domain_package_01_effect18_13_employee_identity_review_replay_kind.sql.draft` instead redefines the existing NOLOGIN evidence-writer-owned `d1_employee_identity_command_context` to validate exact `D1_EMPLOYEE_IDENTITY_REVIEW` receipt kind, request ID and result ref for request.review replay. It redefines only the existing protected review RPC to remove the duplicate prohibited direct-table query. Canonical typed JCS hash, lock, exact idempotent intent, current reviewer authorization and receipt result validation remain. No new functions, broad client EXECUTE/SELECT grants, change to frozen SQL files or hosted migration. The final exact-head runtime is green.

This review does not cover multi-step approvals, campus-specific review scope, unrestricted restricted-identity read or a new identity-specific observed-lock race. **Full D1 remains OPEN; Migration 10 inactive.**
