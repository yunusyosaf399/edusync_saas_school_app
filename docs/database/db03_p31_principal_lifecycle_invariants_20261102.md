# DB03 P31 — Principal RETURN/REJECT lifecycle invariants (2026-11-02)

**Status: inactive database safety increment; a protected Principal RETURN/REJECT command is not yet deployed or implemented.** This isolated draft builds on PR #203 head `4e9798a549af2c199df2ea86d733677ec3db27eb` after P30 authorization, without changing its prior SQL or the separate D1/DB01/DB02 integration #168.

## Defect/risk addressed before a writer

P29 already provides an immutable, restricted `admission_principal_decisions` table, but its initial structural checks allow more than one decision to refer to the same Forward and do not explicitly prevent a later source from following a REJECT. This is unacceptable once a real Principal decision command exists. P31 establishes **one decision per Forward** at the database level with a compound unique constraint and an additional terminal-history trigger. It rejects any append after a previously recorded REJECT, and separately rejects reuse of a decided Forward. These checks remain in addition to P29's original DRAFT, expected-version, stage-epoch, exact current document snapshot, and linear predecessor guards.

P31 also provides the **private invoker-only** `db03_principal_lifecycle_projection(application)` for a future protected workflow to distinguish `DRAFT`, `FORWARDED_FOR_REVIEW`, `RETURNED_FOR_CORRECTION`, `REJECTED`, and `WITHDRAWN` without falsifying the source `admission_applications.state` constraint. The projection gives REJECT precedence even when older source state is still DRAFT. RETURN stays pending until a **newer** Forward exists. A newer Forward is not sufficient on its own: the function still calls the current document-snapshot check before reporting FORWARDED.

**This projection is NOT currently wired into the existing intake/document mutator entrypoints.** Until those existing commands also enforce a terminal REJECT and complete the RETURN invalidation path under consistent lock/role/receipt checks, this projection is not an authorization or globally enforced rejection policy. It has no client/worker grants and is not exposed as an application queue view.

## Blockers for a real protected RETURN / REJECT command

1. **Dedicated authority:** P30's independent `admission.final.decide` current-Principal role/scope/identity reader exists, but the final operation and permission are not seeded or enabled. No grant from `admission.document.approve` may be reused.
2. **Accepted effects and state:** P29 has no INSERT grant and there is no protected write RPC. A RETURN must increment/invalidate the review cycle, retain the same application, accept later correction and new Forward, and preserve prior evidence. REJECT must be terminal in **every** relevant intake/document/fee/forward/assessment route, not just in the new P31 history projection.
3. **Authorization and replay:** Future code must lock School → Campus/Year → Application and relevant private evidence; reauthorize the same Principal after waits and on replay; use typed payload version, an idempotency receipt and minimal audit/outbox. A concurrent Forward, document quarantine, fee revision, withdraw or different Principal decision cannot create multiple incompatible accepted states.
4. **Full acceptance:** Add real Auth-bound success and denial tests, exact-key retries, cross-Principal races, rejected mutation blocking, failed-install rollback and transaction rollback. Existing P31 22 assertions test structural integrity/ACL only, not an accepted final decision.
5. **APPROVE remains blocked:** Admission approval must be the same transaction as trusted Person binding, Student and admission identifiers, first PRIMARY Enrollment and Roll, correct DB01/DB02 lock order, and private certificate lineage. P31 creates none of these.

## This increment's exact boundary

One `.sql.draft` fragment adds a unique constraint and a private terminal guard + private status reader. One rollback-only pgTAP suite (22 checks) verifies ACLs, constraint and prior trigger retention, terminal-reject and Forward fencing, NULL/unavailable input, intact no-writer status. The DB03 disposable runner exercises injected failed-install rollback and 22 pgTAP assertions after P1–P30. No role/permission seed, public RPC, update to the existing application table/check constraints, direct DML, `main` merge, hosted Supabase, Finance charge or D1 Student-create mutation.

**Next task:** implement and independently test a coherent protected RETURN/REJECT write path that enforces these lifecycle effects in all existing application command guards. Do not enable approval or production access before the full integration review.
