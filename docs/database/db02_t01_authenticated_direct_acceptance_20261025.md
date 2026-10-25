# DB-02 T01 — authenticated DIRECT acceptance (draft, rollback-only)

T01 extends `supabase/tests/domain/95_db02_authenticated_direct_entry.sql` from 40 to 49 assertions. The suite invokes the public `app.d1_change_student_roll_policy` API under an authenticated Principal with a synthetic School ALL grant, inside one transaction ending in `ROLLBACK`.

The existing positive INIT and REPLACE cases check the persisted revision, effective interval, allocator, receipt, audit, event, and historical replay. Existing negatives cover disabled routing, absent P1, APPROVAL route, absent or revoked School ALL authority, unsupported END, absent reason, invalid counter, duplicate INIT, stale source fields, and conflicting retry intent.

The added cases reject NULL School/action/mode/idempotency key, an unknown School, an invented INIT predecessor, same-day REPLACE, an unrelated REPLACE source UUID, and a future accepted Enrollment through the public API. The future placement fixture is itself rolled back to a savepoint before the successful REPLACE case. All synthetic fixture changes are rolled back at suite end.

T01 is a draft-local acceptance gate. Exact-head D1 static, Foundation local, and disposable D1 runtime CI are required for its tracker completion. Independent non-author SQL/security review and hosted release gates remain separate.
