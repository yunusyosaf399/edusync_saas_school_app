# D1C1B Effect 27/36 — Student Enrollment End SQL review

**Status: IMPLEMENTATION CANDIDATE REVIEWED — exact-SHA CI PASS; freeze record follows.**

Trusted runtime candidate: `ddcfa8eddc8c20e2ef34afca756704a3d08463e3`.

Effect 27 implements `student.enrollment.end` as the frozen P1 one-way end of the current accepted PRIMARY placement with retained reason and no destructive delete.

## Reviewed behavior

- P1 policy selects DIRECT or APPROVAL; missing/ambiguous policy denies. Campus-specific policy wins, with school policy fallback pinned to the affected source Campus context.
- Source authorization uses current `student.enrollment.end` through the exact stored source Section ACS ancestry. Placement existence grants no authority.
- Approval uses configured reviewer role plus current `student.enrollment.approve`, with requester/reviewer separation by Person.
- The command locks the Student, source academic ancestry, source Enrollment and its single open Roll allocation before the one-way close.
- The source must be the current retained open PRIMARY head for the Student, with expected source Section/start facts and expected Student version.
- Successful effect sets the Enrollment and Roll `effective_until` to the same exclusive date and records server actor/time; Enrollment state becomes `ENDED` and retains the nonblank reason. Student lifecycle status is not changed.
- No destination placement, roll allocation or capacity override is synthesized by this effect.
- Command receipts use an Effect-27-specific canonical intent and Foundation SHARED authorization lock plus per-idempotency-key advisory lock.
- Direct terminal replay returns before mutation preflight only after current authority and exact immutable-result proof.
- Approval apply rechecks current policy, requester authority, all completed reviewer authority, expected Student/source facts and source Roll facts. Deterministic stale failures record `APPROVED → INVALIDATED` with a REJECTED apply receipt and no domain/outbox mutation; malformed protected workflow data rolls back.
- Successful approval apply records exactly one guarded `approval_applications` row tied to the reviewed request, successful apply receipt, expected target version and exact ended Enrollment result.
- Typed request read is limited to the currently authorized requester, final approver, open reviewer or decided reviewer.
- Broad audit/outbox excludes arbitrary enrollment-end reason text. `enrollment.ended` uses the ended Enrollment as the aggregate reference.

## Independent audit corrections

Before freeze the candidate was corrected for:

1. school-policy fallback incorrectly comparing nullable policy-campus selection with the affected Campus;
2. missing operation-specific `approval_applications` guard;
3. replay evidence not proving all durable summary ancestry/version fields;
4. missing typed participant request-read surface and explicit final public RPC ownership/ACL closure.

The final ordered package is seven non-executable `.sql.draft` continuations under `supabase/migrations/20260928000000_domain_package_01_effect27_*`.

Exact-SHA GitHub Actions run #125 (`37125078838`) passed on the trusted runtime candidate. Full logs confirmed exact checkout, 121/121 tooling tests, frozen Foundation integrity, clean local reset of nine frozen migrations/no seed, 5/5 auth fixtures, both lint gates, and 220/220 Foundation pgTAP assertions.

Migration 10 remains non-executable `.sql.draft`. This review authorizes no PostgreSQL application, D1C2 execution, remote deployment, worker activation or staging execution.