# DB-02 I01 — private typed command context, inactive SQL candidate

**2026-10-23.** Proposed on `db/db-02-i01-private-command-context`, stacked on receipt candidate [PR #122](https://github.com/yunusyosaf399/edusync_saas_school_app/pull/122) head `df8caf9162d41d4eb4868b42abc582d042ec8441`. Complements P01 [PR #138](https://github.com/yunusyosaf399/edusync_saas_school_app/pull/138) and P02 [PR #142](https://github.com/yunusyosaf399/edusync_saas_school_app/pull/142); no changes to those or DB-01/03/04 branches.

## Exact owned increment

- Private `app_private.d1_roll_policy_receipt_context(text,text,jsonb)`: evidence-writer-owned `SECURITY DEFINER`, fixed Roll Policy operation and DIRECT/SUBMIT phases only, exactly 12 array positions, delegates original authority+SHA/JCS+idempotency locks to unchanged `d1_command_receipt_lookup`. Only `schoolos_student_executor` gets EXECUTE on the **wrapper**, not blanket private receipt access for other operations. No client EXECUTE or grant to Workflow.
- Private `app_private.d1_roll_policy_command_context(uuid,text,text,text,uuid,integer,text,bigint,date,text,bigint,text)`: Student executor-owned `SECURITY DEFINER`, fixed search_path, validates typed INIT/REPLACE inputs (unsupported END and scheduling fail), first locks Foundation shared advisory guard, selects actual unique global P1 policy UUID, binds its server-derived value into the 12-slot receipt intent, calls the evidence-writer wrapper and checks current verified Principal. The receipt writer supplies canonical JCS/SHA-256 and idempotency serialization. Locks existing School with the frozen Placement/MOVE School anchor; then checks current live School ALL change authority and reselects the global P1 UUID/route after waiting. DIRECT must match DIRECT; SUBMIT must match APPROVAL.
- Terminal receipt replay is deliberately rejected: a later accepted I06 historical effect verifier must independently prove the old revision, allocator rows, receipt/application, audit and event, not treat a recorded UUID as success. The helper creates **no** receipt, policy row, allocator, request, audit or event.
- No new event or receipt kind registration; no writable command. Existing `student.roll_policy.change` remains disabled until a separate approval/enablement, and the helper has no public callable edge.
- Exactly two new private functions: expected catalog `551 total / 533 security definers / 394 private / 157 app`; zero new client private EXECUTE; 34 RLS tables unchanged.
- Rollback-only `89_db02_private_command_context.sql` (28 assertions) covers ownership, ACLs, fixed search path, denied disabled/no-global/no-live-ALL/END/NULL/wrong-route/revoked access, positive DIRECT bound actor/P1 UUID/JCS hash and no business/evidence side effects. Synthetic enablement, Role/Scope and policy versions rollback.
- Note: The separate DB-01 owner presently has suites 81–88; #89 avoids new suffix number overlap. Existing DB-02 #82–86 remain as full filenames until final G01 coordination.

## Remaining requirements

I02 binds/rechecks the exact P1 version at each later authorized phase; I03 validates today's source and future commitments; I04/I05 atomically close/append policy history and provision allocator pools; I06 writes/verifies exact receipt/audit/outbox on success; I07–I10 add checked authenticated DIRECT and independent workflow; I11 adds independently reviewed REVIEW/APPLY receipt shapes. T01–T08 validate these end-to-end and two-backend races. **No current I01 helper may be used as a success signal or a replay verifier.**

PR #122's required non-author reviewer decision is **not supplied by current automated tests, this design, or the project owner**. Issue #131 remains open. The owner has no alternate developer identified, so independent reviewer coordination must remain pending while only inactive draft/testing work proceeds.

**CI evidence:** to be filled from the exact tested PR head after GitHub actions complete; do not assert pass just from source inspection.
