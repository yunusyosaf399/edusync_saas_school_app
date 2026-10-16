# D1 Student Profile DIRECT acceptance — independent CI review and merge freeze

Date: 2026-10-16. **Verdict: DIRECT-path local acceptance PASS; FULL `student.profile.update` contract NOT YET FROZEN.**

## Trusted tested source and repository checkpoints

- Accepted prerequisite merged `main` baseline: `ad3f2391d964d93a98750d5bc03be05d20b831fb` (four-operation non-authorizing readiness freeze).
- PR: https://github.com/yunusyosaf399/edusync_saas_school_app/pull/71.
- Exact independently tested PR head: `54963749acd503b509ed1ecc54794d17666f46d6`.
- Exact-head D1 disposable local runtime: **PASS** https://github.com/yunusyosaf399/edusync_saas_school_app/actions/runs/38864414713.
- Exact-head Foundation local regression: **PASS** https://github.com/yunusyosaf399/edusync_saas_school_app/actions/runs/38864414660.
- Exact-head D1 draft static/last-function/ownership guards: **PASS** https://github.com/yunusyosaf399/edusync_saas_school_app/actions/runs/38864414670.
- PR #71 merge commit: `c44b26713e2242340154dbc2f716c91d7afb8540`.
- The merge was SHA-guarded; no change was made to a hosted Supabase project.

## Independently inspected evidence

The D1 local job records:
- `D1C2A_APPLY_PASS 225 draft fragments parsed/applied locally`.
- 34 force-RLS private D1 relations and the unchanged catalog of 97 permissions / 322 scope alternatives / 36 operation contracts.
- `D1_BUSINESS_TEST_PASS 65_remaining_student_commands_fail_closed.sql 38/38` (default denial preserved).
- `D1_BUSINESS_TEST_PASS 66_student_profile_p1_direct_history_authorization.sql 33/33` (authenticated P1 DIRECT positive/negative candidate).
- `D1_BUSINESS_PASS 2939 assertions` across **66** rollback-isolated business suites.
- `D1C2A_FOUNDATION_REGRESSION_PASS ... 220/220`; independent Foundation job `FOUNDATION_LOCAL_CI_PASS 9 files / 220 planned / 220 passed`.
- 78 D1 Python tooling tests; static: `D1_DRAFT_STATIC_PASS`, `D1_FUNCTION_FINAL_PASS`.

Review of the five-file PR diff found one append-only owner-preserving change to the existing Student Profile authorization helper. It fixes the impossible `ACTIVE` Class/Section Offering predicate to the approved `OPEN` offering state, retaining current ACTIVE Student, unique current PRIMARY enrollment, current COMPLETE permission chain, campus/section/role-scope matching, and private authorized execution. The new SQL fragment temporarily restores CREATE privilege to the original NOLOGIN `schoolos_authz_reader` function owner and revokes it after the `CREATE OR REPLACE FUNCTION`. No direct table grant, new scope/permission/role, D1 catalog operation activation, arbitrary patch RPC, or relaxed row security is introduced.

The suite exercises real authenticated protected P0 Student initial placement (and real roll allocation), then Student Profile P1 DIRECT for an editable field, optimistic version, historical idempotent replay, wrong campus/Student, absent policy and grant, permission-scope revocation, unchanged admission/identity/special facts, receipt/audit/outbox counts, and rejection of authenticated direct private DML. This is genuine disposable Postgres execution, unlike a static source assertion.

## Scope of the freeze and open contractual gates

**Freeze only the tested Student Profile DIRECT acceptance slice and the five reviewed files.** It does **not** approve an unreviewed Student PROFILE allowlist, absent-vs-NULL/partial update semantics, historical value retention model, photo entitlement edge cases, P1 APPROVAL submit/review/apply/stale/replay behavior, or observed direct Student Profile two-session contention. Readiness #152 SP-01 through SP-08 are still product-owner decisions. The existing approval helper's presence in the large draft is not equivalent to an approved/accepted approval route.

Therefore **do not yet report full Student Profile operation accepted or advance the distinct-operation ledger from 31/35.** The database has 66 tested local suites and 2,939 assertions; the four-operation blocker register remains in readiness state until owner approvals and the complete authenticated acceptance gate are satisfied.

Other blocked mutators `student.roll.correct`, `student.roll_policy.change` and `student.create` have no new implementation in PR #71. Student Create additionally requires its separately accepted, single-use final Admissions handoff. The negative suite #65 is preserved. Migration 10 is still `.sql.draft`, release/deployment is unauthorized, Foundation migrations/tests 1–9 remain frozen, and hosted/staging Supabase has not been changed.

**Next safe gate:** explicitly freeze Student Profile SP-01…SP-08 business semantics, then test its P1 APPROVAL, photo/update/history and concurrency paths. Only after this independently passes may the protected-operation completion ledger be revised.
