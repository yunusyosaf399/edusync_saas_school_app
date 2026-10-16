# D1 Student Profile P1 two concurrent approved APPLY operations — CI merge freeze

Date: 2026-10-16. **Verdict: two incremental genuine same-Student approved-APPLY races ACCEPTED as local runtime test evidence. Full `student.profile.update` operation remains BLOCKED and Migration 10 remains non-executable `.sql.draft`. Accepted protected operations: 31/35.**

## Exact GitHub head, CI and independent merge verification

- [Merged PR #76](https://github.com/yunusyosaf399/edusync_saas_school_app/pull/76), based on the previous independent freeze `6e1e078310d901ee6c212a6821d986d8e568523c`.
- Exact successful CI head: `bf2010b5bb012b2f7ae511b2bebfcfa8b986cd23`. SHA-guarded merge commit: `fb4e79b5c2211d299910ae13516ef566192d9c09`. After merge, independently re-read GitHub PR state `merged=true`, merge SHA and `main` pointing to that exact commit.
- [D1 Migration 10 local runtime run #38931033111](https://github.com/yunusyosaf399/edusync_saas_school_app/actions/runs/38931033111): **SUCCESS** on exact head; **228** inactive draft fragments parsed/applied only in the disposable local database; 34 tables with 34/34 enabled and forced RLS; 542 final functions, 524 SECURITY DEFINER, zero authenticated private execute, zero anon/service-role execute. **74 SQL domain business suites / 3,124 assertions** retained and passed. Foundation post-D1 regression **220/220**; `D1C2A_PASS local-only runtime baseline`.
- [Foundation database #38931033143](https://github.com/yunusyosaf399/edusync_saas_school_app/actions/runs/38931033143): **SUCCESS**, 9 files / **220/220** assertions.
- [D1 Migration 10 draft static #38931033114](https://github.com/yunusyosaf399/edusync_saas_school_app/actions/runs/38931033114): **SUCCESS**, 228 fragments, 34 relations, 97 permissions, 322 scope alternatives, 36 operations, 542 final functions, `unknown_owners=0` and `signature_shape_drift=0`.

## Verified two independent two-session Student-row lock races

- `D1_STUDENT_PROFILE_SAME_STUDENT_ONE_RACE_PASS`: two **genuinely** independently approved Student Profile P1 proposals on the same Student and expected Student row version were attempted by distinct authenticated sessions. **Requester** held the actual Student-row lock first; independent final reviewer was observably blocked on a PostgreSQL transaction/tuple lock with precise `pg_blocking_pids` relationship. Result: one `EXECUTED`, one `INVALIDATED`. Only the selected approved previous-school value applied; the competing value never overwrote it.
- `D1_STUDENT_PROFILE_SAME_STUDENT_TWO_RACE_PASS`: after a fresh new pair of proposals were independently submitted and approved at the advanced Student version, the **independent final reviewer** held the Student-row lock first; the requester was observably blocked on the same kind of dependency. Again, one `EXECUTED` and one `INVALIDATED` with no stale overwrite.
- Each race independently asserts exactly **one** new Student optimistic version, successful application proof, successful apply receipt, minimized `student.profile_changed` event; exactly one rejected stale-apply receipt, no second successful event/application, no mutation of restricted `student_identity_details` or `student_special_details`, and no previous-school value in broadly visible outbox payload.
- Exact receipt-key replay under each original authenticated actor retains historical `EXECUTED` or `INVALIDATED` outcomes without duplicating version increments, change events, review approvals, applications or history.
- The runner first requires accepted [PR #75](https://github.com/yunusyosaf399/edusync_saas_school_app/pull/75) authorization-versus-revocation race evidence. A synthetic **fresh nonoverlapping** reviewer grant restores test-only authority after the previous accepted test retired two historical grants. All new reviews, submissions and applies use public typed authenticated RPCs, not fabricated terminal request states.

## Four-file PR scope (no production SQL)

1. `docs/database/168_d1_student_profile_p1_competing_approved_apply_races_candidate.md`
2. `tools/supabase/domain_concurrency_ci.py`
3. `tools/supabase/domain_student_profile_competing_applies_race_ci.py`
4. `tools/supabase/tests/test_domain_acceptance_ci.py`

Exact PR diff independently verified to include only those four files. **No** production executable migration, D1 `.sql.draft` implementation fragment, database DDL, database permission, RLS rule, hosted project, tenant data or remote Supabase deployment was changed.

## Frozen exclusions and next gates

This is **incremental negative/race acceptance only**, **not** Student Profile P1 production enablement. The owner-contract decisions `SP-01` through `SP-08` in `docs/database/152_d1_student_profile_update_p1_contract_readiness.md` remain unresolved, including the final changed-field allowlist, omitted/NULL behavior, photo-file entitlement, historical before/after redaction, scope policy and approval rules. Other disabled protected operations remain `student.roll.correct`, `student.roll_policy.change`, and `student.create` (final atomic Admissions single-use handoff). **31/35 accepted operations** remains the only valid count.

**Example:** Two authorized actors have different approved corrections to a student's previous school, both tied to Student version 3. Under actual simultaneous database contention, one commits and produces Student version 4. The other must terminate as INVALIDATED, not silently change the record again or issue a second event; a subsequent genuinely fresh approval based on version 4 may separately change the field.
