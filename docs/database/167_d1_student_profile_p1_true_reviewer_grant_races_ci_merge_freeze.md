# D1 Student Profile P1 genuine reviewer-grant concurrency — CI merge freeze

Date: 2026-10-16. **Verdict: incremental genuine two-session Student Profile P1 approval APPLY-versus-reviewer-grant revocation races ACCEPTED, but full protected operation remains BLOCKED.** Accepted protected operations remain **31/35**. Migration 10 remains **inactive, non-executable .sql.draft**, with no hosted Supabase changes.

## Exact-head GitHub acceptance and SHA-guarded merge

- [Merged PR #75](https://github.com/yunusyosaf399/edusync_saas_school_app/pull/75), from frozen base `8e93bbbe32795ef0ef7e8499859075502dbd8aba` (PR #74 / documentation freeze #165).
- **Exact CI-tested head:** `63f1661149287800f90a98195c35143c5767012f`. The final corrective test change uses actual, nonoverlapping effective timestamps when renewing an expired reviewer grant, and regression-guards this history constraint.
- **SHA-guarded merge SHA:** `84e60699488729b34002f880bb27204eda0c5b6c`. Independently re-read PR state `merged=true`, merged SHA and `main` pointing to that exact merge SHA before this document was added.
- [D1 Migration 10 local runtime #38914744062](https://github.com/yunusyosaf399/edusync_saas_school_app/actions/runs/38914744062) **SUCCESS**. Log proves `D1C2A_APPLY_PASS 228 draft fragments parsed/applied locally`, `D1C2A_CATALOG_PASS tables=34 rls=34/34 functions=542 ... auth_private=0 anon=0 service_role=0`, `D1_BUSINESS_PASS 3124 assertions`, existing Foundation regression **220/220**, and `D1C2A_PASS local-only runtime baseline`. The two explicit **Student Profile** concurrency pass markers are separately required, and both appeared.
- [Foundation database #38914743855](https://github.com/yunusyosaf399/edusync_saas_school_app/actions/runs/38914743855) **SUCCESS**; 9 files, **220/220** assertions.
- [D1 draft static #38914744106](https://github.com/yunusyosaf399/edusync_saas_school_app/actions/runs/38914744106) **SUCCESS**; 228 inactive draft fragments, 34 relations, 97 permissions, 322 scope alternatives, 36 operations, 542 final functions; final `unknown_owners=0`, `signature_shape_drift=0`.

## Verified real two-session PostgreSQL lock orderings

1. **`D1_STUDENT_PROFILE_APPLY_FIRST_RACE_PASS`** — One genuine independently approved P1 public APPLY holds the Foundation shared advisory `(71001,1)` lock. Another PostgreSQL connection attempts owner-only reviewer-grant revocation under EXCLUSIVE, and a separate independent observer verifies exact `pg_blocking_pids` advisory waiting relationship. Authenticated profile APPLY commits first, then grant retirement. Exactly one protected Student mutation, application, successful receipt, and minimized `student.profile_changed` outbox event.
2. **`D1_STUDENT_PROFILE_REVOKE_FIRST_RACE_PASS`** — A new genuine, independently approved request uses a *fresh, nonoverlapping* reviewer role permission grant and exact scope, preserving the earlier retired grant history. EXCLUSIVE revocation obtains lock before another authenticated APPLY, which is observed waiting on SHARED. After authorization recheck, request terminally **INVALIDATED** with a rejected receipt; no second Student mutation/version, application or success event. The original EXECUTED and new INVALIDATED receipt keys both replay immutable outcomes, with no duplication.

This is genuine concurrency, not sequential test simulation. Both protected APPLY calls are public authenticated typed RPCs. Privileged reviewer grant revocation and initial Student/permission fixture setup remain synthetic **disposable local-only** test actions.

## Exact five-file reviewed PR diff

1. `docs/database/166_d1_student_profile_p1_true_reviewer_grant_race_candidate.md`
2. `supabase/tests/domain/fixtures/student_profile_reviewer_grant_true_race_setup.sql`
3. `tools/supabase/domain_concurrency_ci.py`
4. `tools/supabase/domain_student_profile_reviewer_grant_race_ci.py`
5. `tools/supabase/tests/test_domain_acceptance_ci.py`

The PR **does not** modify any executable migration, `.sql.draft` implementation fragment, D1 function, default operation activation, production grants, RLS, tenant schema or remote database. The 74 frozen business suites / 3,124 assertions and Foundation 220/220 remain unchanged. New acceptance is two lock-observed runtime test scenarios and static/unit test evidence.

## Remaining product contract gates and exclusions

`student.profile.update` remains entirely **unaccepted for production** pending explicit owner approval of **SP-01–SP-08** in `docs/database/152_d1_student_profile_update_p1_contract_readiness.md`: definitive field allowlist, absent/NULL semantics, photo-file entitlement, idempotency/version rules, route and reviewer selection, scope/actor drift, privacy-safe evidence and secure before/after retention. This race candidate does not establish two simultaneous Student Profile writes, every Campus/Section scope transition, or full privacy compliance.

The other remaining blocked operations are `student.roll.correct`, `student.roll_policy.change`, `student.create` (Admissions final atomic single-use handoff). Therefore the correct accepted protected-operation count is **31/35**, not 32/35; Migration 10 is not deployable.

**Simple example:** A reviewer approves changing a Student's recorded previous school. If the administrator withdraws the reviewer's permission before the waiting profile command gets its authorization lock, that pending approved request becomes INVALIDATED with no Student change. If the approved profile command already has the lock, it completes exactly once before the revocation transaction can commit.
