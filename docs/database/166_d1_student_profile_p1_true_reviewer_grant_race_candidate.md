# D1 Student Profile P1 — genuine two-session reviewer-grant revocation races

Date: 2026-10-16. **Status: candidate; exact-head CI NOT YET CONFIRMED.** Follows verified [PR #74](https://github.com/yunusyosaf399/edusync_saas_school_app/pull/74), frozen in `docs/database/165_d1_student_profile_p1_policy_scope_ci_merge_freeze.md`, and exact parent `8e93bbbe32795ef0ef7e8499859075502dbd8aba`.

## Boundary and design

- Existing rollback-only **74/74 business suites / 3,124 assertions** and **220/220 Foundation** regression are preserved exactly.
- Adds `supabase/tests/domain/fixtures/student_profile_reviewer_grant_true_race_setup.sql` for **synthetic local-only** current Student, real protected P0 INITIAL enrollment+roll, live P1 APPROVAL policy, scoped requester permission, distinct reviewer role/scope, and **genuine authenticated P1 submit and independent APPROVE**. It runs only after the accepted concurrency fixture has been committed. Earlier accepted races already occupy the generic Person ID; this fixture creates its own distinct Person before Student insertion. It reuses the distinct real preexisting reviewer principal-auth binding, not a duplicate binding to a Supabase user.
- Adds `tools/supabase/domain_student_profile_reviewer_grant_race_ci.py` and invokes it from the existing D1 local concurrency runner **after** the frozen Family races.
- Both worker processes invoke the actual authenticated `app.d1_apply_profile_request` public RPC using currently validated JWT claims. Independent privileged owner fixture acquires Foundation **exclusive** advisory `(71001,1)` *before* revoking the reviewer's actual `role_permission_grants`. Command acquires existing shared lock. A third PostgreSQL observer verifies the lock holder, exact pending advisory lock mode, and matching `pg_blocking_pids`, **not** merely timing or simultaneous process start.

## Planned two genuine serializations

1. **Apply first, revocation second.** An independently APPROVED P1 request enters `app.d1_apply_profile_request` while holding shared authorization lock; the owner EXCLUSIVE revoker is observed blocked. The approved Student profile changes exactly once to the preapproved previous-school candidate value, with one Student version increment, one application proof, one succeeded typed apply receipt and one minimized `student.profile_changed` event. Grant retirement commits only afterward.
2. **Revocation first, apply second.** An independent *new* test grant/scope to the same previously authorized reviewer is used to create a new genuine reviewed P1 request at the updated Student version. The EXCLUSIVE revoker now holds first, and the requester APPLY is observed blocked on SHARED. After grant revocation commits, the requester remains authorized, but the previously approved reviewer's live approval evidence is stale. APPLY must return `INVALIDATED` v5, with rejected apply receipt, zero additional Student mutation, application proof or success outbox. Replaying both original receipt keys must return exactly the historical `EXECUTED` / `INVALIDATED` outcomes without duplicates.

All fixture IDs/keys are test-owned, strings are bounded, no hosted/network credentials are logged, and worker processes are forcibly terminated on test failure. The runner rejects any nonmatching disposable local container and any missing mandatory fixture boundaries.

## Important exclusions

**Not yet evidence of success** until the exact GitHub workflow run confirms both observed lock waits and all assertions. This candidate does *not* add a SQL implementation or a deployed migration and does *not* approve `SP-01`–`SP-08`, the full Student Profile allowlist, private before/after retention, Campus/Section-scope conflicts, nor opposing concurrent profile-vs-profile writes. The source owner decision gates remain in `docs/database/152_d1_student_profile_update_p1_contract_readiness.md`; accepted operations remain **31/35**. Migration 10 remains inactive.

**Example:** The reviewer approves correcting the student's old school. If the school administrator withdraws that reviewer's permission **before** the final profile change acquires its authorization lock, the change is invalidated. If the change already holds its authorization lock, it commits once before the permission withdrawal is allowed to finish.
