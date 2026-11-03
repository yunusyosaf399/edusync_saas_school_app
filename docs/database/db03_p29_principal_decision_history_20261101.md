# DB03 P29 — Principal RETURN/REJECT immutable source (2026-11-01)

**Status: INACTIVE / NO-GO.** This is the **physical history prerequisite** for a protected Principal RETURN/REJECT operation; the operation itself is **not implemented or enabled** here. Stacked on DB03 #203, after P27 and P28. No DB01/DB02/D1 SQL changes.

## Current schema constraint and why P29 does not pretend to apply decisions

The existing `app_private.admission_applications` source enforces `state IN('DRAFT','WITHDRAWN')` and the intake trigger freezes state changes outside those transitions. Consequently writing an alleged Principal `REJECTED` state without coordinating both the original state machine and every existing Admissions command would be internally inconsistent and could let a rejected application continue through DRAFT operations. The existing P28 function only validates decision *intent*, and even that function returns `can_apply=false`.

P29 introduces a separate, completely private, append-only `app_private.admission_principal_decisions` source. Its table accepts **RETURN** and **REJECT** only. It cannot hold APPROVE records: success requires an accepted, joint DB03→D1 atomic Student creation transaction, which is absent. The new source has School-bound parent application and composite `(forward_id, application_id)` foreign key, revision/supersession lineage, current application version and stage epoch, reason, actor and unique receipt identity. No new receipt is inserted by P29.

The draft guard enforces only INSERT through `schoolos_workflow_executor`, obtains a locked live DRAFT application, rechecks exact application version/stage and latest Forward document hash, and requires a linear predecessor chain. Both row mutation and TRUNCATE are denied. Crucially, the **executor has no INSERT grant** on the table. A future distinct, authenticated Principal-final operation must be approved and tested before any protected writer grant. Existing `admission.document.approve` is *document review*, not an independent final-admission permission.

## Tests and exact boundaries

- 20 rollback-only pgTAP checks for forced RLS, lack of privileged client or workflow INSERT, private guard, immutable triggers, RETURN/REJECT CHECK, composite Forward and supersession foreign keys, parent lock and latest-file snapshot comparison, absence of a new public final operation.
- CI installs the new table/guard only into an explicitly disposable DB03 stack; an injected failure must leave no table, followed by successful install and tests. The source runner and all previous P1–P28 tests remain.
- No `admission_applications` state or original DRAFT/WITHDRAWN constraints, permissions, public RPCs, worker/grant seeds, Finance payment status, School roll allocator, `student.create`, migration or production hosted SQL is modified.
- Source is **not** a working Return/Reject feature or a passing authorization/RPC integration test. Its 20/20 success only establishes the safe inert physical foundation.

## Next actual protected Principal decision task

First freeze a dedicated Principal-final operation identity and live Principal-only authority/scope (not document-review authority) and the compatible application state/projection model for returned and rejected records. An authenticated protected RETURN command must invalidate the reviewed Forward snapshot while retaining the same application for correction and record append-only reason/history/receipt/outbox. REJECT must deny all subsequent Forward, fee edits and Student creation for that application, preserve original files and immutable history, and be replay-safe. Both need reauthorization after School/application locks and genuine competing-document/decision/cancellation race tests. APPROVE and `student.create` remain **separately gated by the full cross-owner atomic handoff**.

Until those contracts and positive authenticated tests pass, do not grant INSERT on this history table or mark any Principal final decision as recorded. Staging/release security and production authority remain separate.
