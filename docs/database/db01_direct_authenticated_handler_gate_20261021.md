# DB-01 — Authenticated protected DIRECT Roll correction (inactive)

**Date:** 2026-10-21. **State: stacked draft SQL, owner-approved RC-01…RC-08 semantics, runtime CI and independent security review pending.** Parent: verified-green DB-01 [PR #125](https://github.com/yunusyosaf399/edusync_saas_school_app/pull/125), head `70671bbfa0569c322b827109f79276ac80d23258`. This PR owns only DB-01 and does not change main, hosted Supabase, executable Migration 10, enrollment MOVE/END or DB-02/03/04.

## Protected DIRECT v1 RPC

Add exactly one typed `app.d1_correct_student_roll(uuid,bigint,uuid,uuid,date,uuid,date,uuid,bigint,bigint,text,text)` SECURITY DEFINER, owned by `schoolos_student_executor`, `authenticated` EXECUTE only, fixed search_path, with the seven pre-approved typed result fields.

1. Reject incomplete exact source, nonpositive/overflow numeric/version, no-op number, blank/overlong original reason or blank/oversize idempotency key. Hash the eleven exact typed caller-intent fields without a caller-supplied effective DATE, Principal, Campus, School, allocator, policy route or receipt ID.
2. Acquire Foundation SHARED auth and per-Principal/operation/key advisory lock using verified private canonical context. Lock the current Principal. A prior terminal success follows a *read-only* checked replay branch.
3. For **new DIRECT**, require live `student.roll.correct` active INDIVIDUAL Principal/Section-scoped ALL/CAMPUS/CLASS/SECTION permission and unambiguous configured source-Campus P1 `DIRECT`. APPROVAL policy cannot call the DIRECT effect.
4. Acquire School→stored policy→allocator→Student→academic→Enrollment→current exact Roll source locks and verify original Student version/source/policy/number/School-local business DATE under the private source helper. Recheck current actor/ACS/P1 route after waiting.
5. Apply private atomic R0 close/R1 successor/highwater/Student N→N+1 effect. The 12-key immutable result carries exact source policy, old/new numeric and server-local correction DATE; restricted original reason is retained only on R1.
6. Require private evidence writer to insert exactly one `D1_STUDENT_ROLL_CORRECT` receipt, one restricted audit and one minimized `enrollment.roll_corrected` outbox. Verify exact receipt+audit+outbox+R0/R1 provenance before returning. Failures roll back *all* changes.

## Checked idempotent replay (separate authorization)

Replay never repeats the private effect or source locking. It reads the exact matching receipt/hash and verifies surviving R0→R1 lineage, original restricted reason, audit/outbox, original expected Student version N and result N+1. Recheck the caller's **current** live `student.roll_history.view` staff scope and retained Student/School identity: a single current active PRIMARY is checked at trusted School-local today; absent a live placement, the retained original PRIMARY enrollment source is used with **current grants**, not historic participation as permission. Ambiguous cross-School Student placement history or ambiguous simultaneous active PRIMARY is denied. History permission is a distinct security gate; current `student.roll.correct` permission or current DIRECT route is not enough to disclose an old Roll number.

The dedicated checked replay path deliberately fails closed if the supported current Student/School scope cannot be established. Independent security review is still required for multiple-campus/school and MOVE/END disclosure, and protected two-backend races remain unaccepted.

## Candidate tests and limits

Rollback-only suite #88 includes **32 assertions**, creating a genuine source Enrollment/Roll using the existing authenticated protected P0 handler; enabling the Roll correction operation, grant and DIRECT P1 policy *only inside a transaction*, then invoking authenticated protected DIRECT once and testing exact R1 history/highwater/Student version/one immutable receipt/audit/outbox. It asserts that same-key replay is denied without current history grant, works after a live grant, rejects a changed reason/number, does not reapply, and remains available on history grant after revocation of the original correction permission.

Expected strict D1 catalog after exactly one public wrapper: **554 functions, 536 SECURITY DEFINER, 158 `app`, 396 `app_private`; 158 authenticated public RPC EXECUTEs, 0 private client EXECUTEs, 34 FORCE RLS**. No other new functions/tables/privileges or privilege escalation is approved.

**Remain disabled:** `student.roll.correct` and `student.roll.approve` are frozen non-operational. The future APPROVAL submit/review/apply, participant checked read, race testing, all independent security and integration reviews, PR merge and hosted activation require separate acceptance. Passing exact-head local runtime CI is not a release authorization.
