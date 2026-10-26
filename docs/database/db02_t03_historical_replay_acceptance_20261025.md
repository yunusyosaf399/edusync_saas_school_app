# DB-02 T03 — historical response replay (draft, rollback-only)

T03 extends authenticated DIRECT suite #95 to 58 assertions and approval APPLY suite #98 to 79 assertions. Existing #94–#98 tests cover exact canonical intent replay, changed reason or request-version conflict, SUBMIT/REVIEW/APPLY retries, current authority denial, and privacy of reason in receipt/audit/event projections.

The new DIRECT checks deny a same-key changed private reason after a saved REPLACE, then show that restoring current School ALL authority returns its original persisted revision. Under a savepoint, the fixture represents a later-day successor revision and pool without invoking a second today-only public command. The authenticated replay still proves its original revision, allocator, receipt, audit and event, with no duplicate effects.

The new APPLY checks deny a changed expected version with the original key. A separate savepoint represents a later-day successor after successful INIT APPLY. The authenticated retry returns the original application revision, and counts prove no extra policy, receipt, audit or event. Both synthetic successors are discarded before the surrounding suites finish with `ROLLBACK`.

This is draft-local deterministic historical-state acceptance, not a simulation of a second backend or a live calendar advance. Exact-head D1 static, Foundation local, and disposable D1 runtime are required for T03 completion. Two-backend races, independent non-author security review and hosted release remain separate gates.
