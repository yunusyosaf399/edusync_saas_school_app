# DB-02 — Fixed Roll Policy source preflight: security and integration review

**Status: NON-ACTIVATING CANDIDATE; independent review and authenticated command pending.** Date: 2026-10-20. PR #101 only. The frozen owner selections are in [20 October owner choices](20261020_owner_choices_and_dependency_resolution.md): INIT/REPLACE now using School-local server date; END/RESUME/backdate/scheduling deferred; retain historical persistent numbers; global School-level DIRECT or independent APPROVAL.

## Implemented non-activating increment

- `supabase/migrations/20260928000000_domain_package_01_effect43_01_db02_roll_policy_source_preflight.sql.draft` creates exactly one **private** Student-executor-owned, fixed-signature `app_private.d1_roll_policy_change_preflight(uuid,text,uuid,integer,text,bigint,date,date,text,bigint)`.
- It is `SECURITY DEFINER` with `search_path=pg_catalog,pg_temp`. Direct `PUBLIC`, `authenticated`, `anon`, `service_role` EXECUTE is revoked; **no other role is given direct EXECUTE**, no app/RPC function is added, and no Foundation/permission/outbox/event/roll DML is enabled.
- Returns fixed typed `(school_id,business_date,source_policy_id,source_revision,source_mode,locked_allocator_count,error_code)`. Typed action is INIT/REPLACE only, exact requested source snapshot is ID+revision+mode+start+date+until. Future protected callers must still independently recheck live change grant, requester identity, School ALL/DIRECT scope, Foundation global P1 policy UUID, recipient/reviewer authority and receipt/idempotency after their own lock prefix. **This preflight is NOT authorization, reviewer selection, effect or approval.**
- Locks the **School first**, via existing `app_private.d1_enrollment_place_lock_school(uuid)`. Captures the existing `app_private.d1_roll_business_date(uuid)` after that wait; no caller date, Campus inference or timezone fallback. REPLACE then locks the exact current open School policy and existing source allocator row(s) by UUID. No Student row or history child is locked before its School anchor.
- INIT requires **zero retained** School policy revisions and an **entirely empty** expected-source envelope, not merely an absence of today's active policy. A previously ENDed School cannot silently restart.
- REPLACE rejects missing or ambiguous active open head; mismatched expected immutable ID/revision/mode/start/from/until; same-day `source.effective_from>=School-local-today` (avoids empty predecessor interval); unplanned successor or scheduled revision; an already accepted future Roll whose start would become incompatible; and malformed source persistent allocator pool (must have exactly one).
- It only **reads and locks** HE policy and M allocator rows; does not close revision, provision target allocator rows, reserve a number, change Student roll, create an approval request or write a receipt/outbox item. Existing allowed Enrollment placement/MOVE prelocks and roll allocation owner remain unchanged.

## Fixed error surface (internal, not exposed as client contract)

| Error | Meaning |
|---|---|
| `D1_ROLL_POLICY_PREFLIGHT_INVALID` | Invalid action, mode, start or School input |
| `D1_ROLL_POLICY_SCHOOL_MISSING` | Exact School not found under School lock |
| `D1_ROLL_POLICY_INIT_SOURCE_NOT_EMPTY` | INIT mistakenly supplied source snapshot |
| `D1_ROLL_POLICY_INIT_HISTORY_EXISTS` | School ever had a policy |
| `D1_ROLL_POLICY_REPLACE_SOURCE_INVALID` | Missing required expected source or non-open expected end |
| `D1_ROLL_POLICY_REPLACE_SOURCE_MISSING` | No unique current open as-of source |
| `D1_ROLL_POLICY_REPLACE_STALE` | Expected source snapshot differs from lock-time state |
| `D1_ROLL_POLICY_REPLACE_SAME_DAY` | Would produce zero-length source interval |
| `D1_ROLL_POLICY_REPLACE_SUCCESSOR_EXISTS` | Unapproved future/successor policy already retained |
| `D1_ROLL_POLICY_REPLACE_FUTURE_ROLL` | Accepted Roll starts on/after replacement date |
| `D1_ROLL_POLICY_REPLACE_SOURCE_POOL_INVALID` | Persistent source has missing/multiple allocator pool(s) |

All names above are **private preflight error strings**, not an approved client API, event code or receipt `result_kind`. Public codes stay subject to separate approval and consumer versioning.

## Acceptance coverage

- New rollback-only `supabase/tests/domain/83_db02_roll_policy_source_preflight.sql`: **18** planned pgTAP assertions for definer ownership, fixed private privilege surface, school-local day, no-policy INIT, missing/invalid source and School, same-day REPLACE denial, exact source/pool lock, stale source and immutable no-effect guarantees.
- Manifest/verification changes only in `tools/supabase/domain_business_ci.py` and `tools/supabase/tests/test_domain_acceptance_ci.py` append DB-02 #83 after #82. Keep existing #1–80 intact; independent DB-01 PR #117 owns #81. This branch **does not incorporate #81**.
- No claim of positive complete protected change, concurrent two-session acceptance, successful future-commit rejection under actual Enrollment fixture, historical replay, independent sign-off or hosted deployment is implied by a preflight test.

## Independent security-review requests

Review both DB-02 additions: reviewer selector `effect42_01`, source preflight `effect43_01`, #82 and #83 rollback-only tests, fixed owners/grants and full branch diff. In particular verify (a) absence of a public call path to non-authorizing preflight, (b) order School→policy→sorted allocator, (c) current date captured after lock, (d) open head/exact source/stale race handling, (e) future accepted allocation interpretation across cutover, (f) absence of privilege/RLS/Enrollment or Foundation changes, and (g) combined #81 and #82/#83 manifest ordering in a **separately owned** DB-01 integration. Independent reviewer must sign or request changes on the exact SHA; engineer's own source review does not count.

## Next contract needed

After independent sign-off, add a fixed global NULL-Campus School P1 route **version UUID** selector with no extra public privileges, then compose an authenticated, receipt-bound DIRECT/SUBMIT/REVIEW/APPLY command under the frozen Foundation auth and School lock order. Pool provisioning/high-water and tests for future accepted placement and true two-session APPLY-versus-PLACE/REPLACE remain **unimplemented**. Never enable `student.roll_policy.change` or make Migration 10 executable on this basis.
