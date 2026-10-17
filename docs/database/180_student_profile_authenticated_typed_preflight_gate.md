# Student Profile typed authenticated preflight — disposable test gate

Date: 2026-10-17. **Status: independent rollback-only AUTH/P1/PAYLOAD gate; not a public live Student update or accepted protected operation.**

## What this implements

- Quarantined SQL at `supabase/proposals/student_profile_typed_auth_preflight_trial.sql.draft`, **not** under executable migrations or the 228 Migration 10 draft fragments.
- Disposable `SECURITY DEFINER` check owned by existing `schoolos_student_executor` no-login role, called through a fixed Student-only `app.d1_student_profile_typed_preflight_trial` interface *only inside local BEGIN/ROLLBACK*. It has no persistent SELECT/INSERT/UPDATE/delete path and does not read private values back to caller.
- Rejects missing Principal, stale Student `row_version`, missing/ambiguous current PRIMARY placement, mismatched caller Campus hint, missing live `student.profile.update` scope, absent or wrong effective DIRECT/APPROVAL policy, malformed six-field tri-state intent, invalid/no-op input, blank private reason and unverified profile-photo SET. The checker reacquires the Foundation shared auth advisory lock before locking current Principal and Student.
- The same source reuses the verified six-field normalization routine from PR #80. A positive authenticated DIRECT check is injected into a second, rollback-only copy of the existing suite #66 **before its first successful profile mutation**, with the suite's actual authenticated Student, Placement, current ALL permission grant, effective DIRECT policy, Principal/JWT fixture. Negative checks prove wrong Campus, stale Student version, mismatched policy route, no-op, nonexistent Student, unverified photo and current scope revocation.
- Original suite #66 is still executed unmodified among all **74 business suites**. The duplicate local smoke is also within its own `BEGIN/ROLLBACK`, with cleanup proving the extra public trial RPC and history/typed helpers were not installed. It does not alter the frozen 34-table catalog.

## Still required before accepting `student.profile.update`

This is a **preflight**, not a writer: the real typed DIRECT receipt, canonical intent binding, exact history writer under narrowly scoped executor, idempotent historical replay and minimized outbox are not connected yet. APPROVAL route can be checked for selection, but this slice deliberately does not accept an approval/request ID or prove live reviewer steps; a separate APPLY gate must integrate current reviewer Persons, workflow, stale invalidation and Student snapshots. Zero-placement ALL/school-wide routing requires independently reviewed semantics and is currently denied, not silently allowed. Photo SET remains **default denied** until same-Student file ownership, current entitlement and availability can be independently verified.

No owner/schema/design or hosted-deployment approval is inferred from GitHub checks. History remains a proposal, no installed table/grants/retention policy; the older public positional Student RPCs still have NULL overwrite issues. Only the proposal's **local authenticated preflight behavior** may be claimed after exact-head runtime proof. Foundation and Employee Profile remain unchanged; **31/35 operations accepted**; Issue #67 stays open.

**Example:** An authorized teacher with Student Profile change authority for the Student's current Section can validate “change only Previous School”, but staff limited to a different campus, or a staff member whose grant was revoked, cannot pass preflight. No Student is actually updated by this check.
