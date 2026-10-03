# D1C1B Effect 28/36 — Student Emergency Contact Security Review

**Status: PASS / ready to freeze.**

Trusted runtime SHA: `a2d725b4bddbd4df1d891f10c091e0547dbaf20d`.

Effect 28 introduces no permission, scope-alternative, role-template grant, Principal assignment, or operation-contract count change. The frozen deployment manifest remains **97 permissions / 322 permission-scope alternatives / 36 operation contracts**.

## Authorization

The business permission is `student.emergency_contact.change`. P1 APPROVAL review uses the distinct `student.emergency_contact.approve` permission together with the configured reviewer role and exact workflow-step assignment.

Authorization is Student-context authorization. The protected paths derive the verified Principal server-side, take the Foundation authorization lock SHARED, lock the Student, then resolve/recheck current Student ancestry. The Emergency Contact row, associated Person, Family facts, role labels, or record creator never grant authority by themselves.

Requester/reviewer Person separation is enforced when reviewer candidates are installed. Review and apply preserve current-authority checks; there is no generic Administrator/Principal bypass.

## Sensitive disclosure

Emergency Contact name, relationship label, phone and email are restricted-purpose data. They are not exposed through ordinary roster surfaces or copied into broad audit/outbox payloads. The typed workflow checked read exposes the reviewed contact proposal only to a currently authorized request participant and serializes through the Student lock before participant authorization.

The protected approval request may retain the exact reviewed facts and private reason because apply/application integrity depends on them. The application guard compares those facts privately; it does not duplicate them into broad evidence.

## No Family authority side effect

Effect 28 cannot create or modify:

- Family membership or grouping;
- Family Principal membership;
- Student child-access authority;
- primary Family context;
- guardian Principal authority;
- pickup/custody authority;
- Foundation role/grant/scope assignments.

An Emergency Contact linked to an existing Person is still only an Emergency Contact unless separate Family/access commands establish other authority.

## Idempotency and replay hardening

Independent review found two security/integrity issues and both are included in the trusted runtime SHA:

1. DIRECT and request.submit now bind private `reason` into their canonical intent. The reason itself is not placed in broad evidence; only the canonical hash is retained in the receipt contract.
2. Successful ADD/CORRECT replay now proves the original retained receipt summary and immutable lineage facts rather than demanding that the historical result row remain the current open head. This prevents legitimate later history from turning a valid prior receipt into an authorization/evidence failure, while changed intent under the same key still conflicts.

Terminal replay remains evidence-bound and current authority is still checked by the surrounding protected entry point before a result is returned.

## Approval safety

The APPROVAL path preserves the hardened D1 workflow shape:

- submit, review and apply are separate transactions;
- final review stops at APPROVED;
- apply rechecks requester/reviewer authority and protected Student/contact facts;
- deterministic stale approved requests become INVALIDATED with rejected apply evidence and no domain mutation/application row/success event;
- malformed protected workflow/request state and unclassified database failures roll back instead of being mislabeled as deterministic invalidation;
- successful `approval_applications` evidence is operation-specific and bound to exact reviewed contact facts.

## SQL execution boundary

Public entry points are typed. Authenticated callers receive no direct D1 base-table DML. Private helpers remain restricted to the reviewed NOLOGIN executor roles; no executor membership chain, runtime schema-owner shortcut, broad service-role shortcut, or Foundation authorization mutation was introduced.

Exact-SHA GitHub Actions run #142 (`37134286751`) succeeded on the trusted runtime SHA, including the Tooling unit tests, Frozen Foundation integrity, and Clean local Foundation validation workflow steps.

All Effect-28 SQL remains `.sql.draft`. This review does not authorize Migration 10 execution, D1C2, staging/remote application, or Effect 29.

**Security verdict: `EFFECT 28 STUDENT.EMERGENCY_CONTACT.CHANGE PASS`**.
