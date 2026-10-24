# DB-02 v1.2 — fixed shared receipt allowlist integration candidate

**Date:** 2026-10-20  
**Parent:** DB-02 PR #101 head `1cf6aa51827000c77f17c7489be8b4fc18aebc97`  
**Branch:** `integration/db02-roll-policy-receipt-allowlist` (stacked on `db/db-02-roll-policy-design`)  
**Status:** IMPLEMENTED IN A SEPARATE DRAFT INTEGRATION CANDIDATE; exact-head runtime/independent security review required. **NOT activated or frozen.**

## Exact ownership and files

The parent DB-02 PR #101 is left intact. The new SQL fragment `20260928000000_domain_package_01_effect46_01_db02_roll_policy_receipt_allowlist.sql.draft` is an **explicit shared/evidence-writer integration proposal**. It is a complete, append-only final `CREATE OR REPLACE` of `app_private.d1_command_receipt_lookup(text,text,text,jsonb)`, copied from the currently authoritative effect35_18. The only behavior added is a fixed School Roll Policy allowlist arm. No earlier operation/phase/length, original verified actor lookup, transaction isolation guard, SHA-256/JCS digest, Foundation SHARED advisory lock, idempotency key lock, receipt comparison or return projection is changed. Function ownership remains `schoolos_evidence_writer` and no new function EXECUTE grant is emitted.

**No shared file is overwritten.** The final override is isolated in the additive integration fragment for an independent shared-code owner to review before it is composed or merged.

## Exact accepted phase and canonical intent shape

Only `operation_code='student.roll_policy.change'` with:

- DIRECT: `command_kind='student.roll_policy.change'`;
- SUBMIT: `command_kind='request.submit'`;

may pass the *shape* validator. The canonical JSON array has **exactly twelve** positions:

| Index | Shape | Meaning |
|---:|---|---|
| 0 | UUID string | Stored School ID |
| 1 | `INIT` or `REPLACE` string | Today-only action |
| 2 | UUID string for REPLACE, JSON null for INIT | Exact source policy ID |
| 3 | Positive JSON integer for REPLACE, JSON null for INIT | Expected source revision |
| 4 | Frozen mode string for REPLACE, JSON null for INIT | Expected source mode |
| 5 | Nonnegative JSON integer for REPLACE, JSON null for INIT | Expected source start |
| 6 | ISO date string for REPLACE, JSON null for INIT | Expected source effective start |
| 7 | JSON null | Open expected source end |
| 8 | `PERSISTENT_STUDENT` or `ACADEMIC_CONTEXT` | New mode |
| 9 | Nonnegative JSON integer | Proposed new start |
| 10 | Nonblank JSON string | Private reason, included in typed digest |
| 11 | UUID string | Selected exact global Foundation P1 policy-version ID |

These are **receipt-envelope structural checks**, not authorization or complete semantic validation. The private command must validate actual UUID/date/integer domains, School existence, server-selected P1 UUID, School-local business date and source/allocator locks, checked current ALL permission and mode-specific invariants. The caller cannot use field 11 to select a policy; that value must be derived with the existing private `d1_roll_policy_p1_version` selector. Validity of the date and all business constraints are rechecked after locks and at APPLY.

`request.review` and `request.apply` deliberately remain **denied** until separately fixed and independently accepted as new exact phase shapes. No generic operation wildcard or phase/length fallback is added.

## Disposable runtime acceptance

- `supabase/tests/domain/86_db02_roll_policy_receipt_allowlist.sql`: rollback-only **27 pgTAP** assertions for ownership, fixed search path, private ACL denial, both typed positive phases under a temporary enabled-operation fixture, cryptographically distinct phase digests, disabled operation denial, wrong lengths/action/reason/types/UUIDs/JSON-null School and unapproved review/apply phases, valid typed REPLACE and no receipt/history/event effects.
- Appended `#86` only to DB-02-stacked business acceptance runner and its tooling unit expectation; existing 1–80 and #82–85 keep their order and counts.
- DB-01 draft PR #117 still owns **#81** and has not been imported or represented as executed on this branch.
- No function-count delta: complete replacement of existing private definer, not a new function, table, role, RLS policy, permission, or public RPC.

## Hard freeze gates and exclusions

1. Verify exact candidate commit and D1 disposable PostgreSQL, draft static and Foundation workflow PASS, including suite #86 **27/27**. Passing older #82–85 alone is insufficient.
2. Obtain an independent non-author review specifically of the shared evidence-writer function, typed shape, ACLs, actor/idempotency binding and preservation of all prior operation cases. Self-review and green CI do not count.
3. Merge/composition must preserve DB-01 #81 from PR #117, any concurrently landed shared receipt owner changes and all existing test suites. Do not fast-forward main merely because this stacked PR passes.
4. Protected Roll Policy DIRECT and SUBMIT remain *unimplemented*. Receipt-lookup acceptance is not a success receipt, policy revision, namespace allocator effect or P1 request submission.
5. No `student.roll_policy.change` permission/operation enabling, event registration, hosted Supabase action, Migration 10 activation, client endpoint, DB-01/03/04 domain code or auto-merge is authorized.

**Required next DB-02 gate (after independent shared integration acceptance):** protect INIT/REPLACE DIRECT and SUBMIT through Foundation SHARED lock → current verified ALL actor → typed receipt/idempotency → exact global policy UUID → School-local locked source → atomic history+allocator effect or Foundation SUBMITTED request, with safe audit/outbox and current-authority replay. Approval/review/apply and genuine two-backend race acceptance require separate reviews.
