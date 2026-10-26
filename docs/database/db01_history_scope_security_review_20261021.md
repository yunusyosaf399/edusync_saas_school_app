# DB-01 — current historical Roll disclosure and authority security gate

**Date:** 2026-10-21. **State:** isolated, draft, acceptance-only; exact-head runtime validation and independent reviewer outstanding. Parent: green [PR #130](https://github.com/yunusyosaf399/edusync_saas_school_app/pull/130), commit `b17c0ba3e03154201923816ebd109ba7c868cf81`.

## Approved contract and precise review finding

The protected DIRECT correction persists an immutable Principal+operation+canonical-intent receipt. Replay is **not** a new mutation and never reruns source locks/effect, but it may reveal an historic Roll number and therefore requires current `student.roll_history.view` authorization resolved through the current Student PRIMARY Section or retained source ancestry when ended. Original requester identity or possession of the idempotency key does not grant history access by itself. A current `student.roll.correct` grant or prior CORRECT success cannot substitute for history permission. Existing tests already prove permission-state revocation, source tampering, same-key changed payload, replay after genuine protected MOVE/END, and the four protected cross-operation races. This gate extends the missing **live scope** and **broad evidence privacy** cases.

## New checks

The existing rollback-only suite `88_db01_roll_correct_direct_authenticated.sql` is increased from **32 to 48 pgTAP assertions**. It retains the genuine authenticated P0-created source and protected DIRECT correction, with no new tables, permanent permissions, application code or executable migration. Within nested savepoints:

1. Replace the genuine authorized staff `ALL/DIRECT` Roll-history assignment scope with one exact `CAMPUS/DIRECT` grant for an unrelated, test-only Campus. Prove `d1_authorized` denies source Student history and the public authenticated same-key correction replay rejects the receipt. The previously issued success receipt must remain singular.
2. On the same committed correction receipt, prove broad `enrollment.roll_corrected` outbox payload and linked audit details disclose **neither original nor corrected Roll numeric identity nor the restricted correction reason**.
3. Roll back the unrelated-Campus scope and confirm the original valid scope still authorizes the Student. Then replace it with a **matching** `CAMPUS/DIRECT` history grant, prove current authorization returns true, and authenticate another same-key replay returning the exact original R1 without mutation. Roll back test-only scope modifications.
4. Temporarily disable the exact `ALL/DIRECT` Roll-history `permission_scope_contracts` row, leaving the original receipt and role grant untouched. The current authorization resolver and protected replay must deny. Restore the enabled scope contract.
5. Verify exactly one correction receipt, audit and outbox and unchanged Student version N+1 across every grant/scope and rejected-replay experiment.

The suite's test fixture changes remain transaction-local and are rolled back. The parent D1 race suite and immutable receipt tests must pass unchanged on this branch; the strict expected database inventory is not changed (**554 functions / 536 SECURITY DEFINER / 158 app / 396 private / 34 FORCE RLS / 0 client private EXECUTEs**). The Python regression guard pins each new authorization and privacy proof.

## Security assessment / boundary

This is a **regression test**, not an assertion of independent review signoff. Additional controls still requiring scrutiny before activation: current Principal binding and token replay for a different individual; active Section scope after an actual cross-Campus MOVE (not merely same-Campus SECTION_CHANGE); multiple historic Schools fail-closed; invalid/expired/ambiguous P1 policy routes for a fresh DIRECT call; private helper EXECUTE ownership; historical receipt consistency after later Roll correction(s); and P1 APPROVAL independent reviewer/terminal application. Those are distinct test increments and must not be inferred from this suite.

The frozen `student.roll.correct` and `student.roll.approve` operations remain **disabled** outside local fixtures. Migration 10 stays `.sql.draft`; no hosted operation, PR merge, external reviewer approval or production activation is authorized.
