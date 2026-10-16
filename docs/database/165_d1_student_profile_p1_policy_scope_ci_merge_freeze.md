# D1 Student Profile P1 policy/scope acceptance — independent CI merge freeze

Date: 2026-10-16. **Verdict: incremental rollback-only negative acceptance accepted. Full `student.profile.update` operation remains NOT FROZEN/NOT ENABLED; 31/35 protected operations remain accepted.**

## GitHub exact-head evidence

- Merged [PR #74](https://github.com/yunusyosaf399/edusync_saas_school_app/pull/74) from exact CI-tested head `dc84a71fe9bb41a6f1ecaac8a629d50bb610fb82`, base frozen `8f983d447bbe3eb1477bfca73fba2266838de7ec`.
- SHA-guarded merge commit `cdaf17e8ef59d5fd9fb7dc016609ea9a30020a77`, independently confirmed as `main` immediately after merge.
- [D1 Migration 10 local runtime](https://github.com/yunusyosaf399/edusync_saas_school_app/actions/runs/38892918966) **SUCCESS**; 228 draft fragments parsed/applied locally, 74/74 rollback-only domain business suites, **3,124/3,124** assertions.
- [Foundation database](https://github.com/yunusyosaf399/edusync_saas_school_app/actions/runs/38892919060) **SUCCESS**, 9 Foundation files / **220/220** assertions, and runtime's post-D1 Foundation regression **220/220**.
- [D1 draft static](https://github.com/yunusyosaf399/edusync_saas_school_app/actions/runs/38892918964) **SUCCESS**, 228 inactive draft fragments, 34 private relations, 97 permissions, 322 scope alternatives, 36 operations, 542 final functions, `unknown_owners=0`, `signature_shape_drift=0`.

## Incremental verified approval scenarios

- `72_student_profile_p1_replacement_policy_stale_apply.sql` **22/22**: independently approved request remains pinned to its original retired policy, and a distinct active successor policy does not authorize application. INVALIDATED without Student effect.
- `73_student_profile_p1_ambiguous_active_policy.sql` **22/22**: two concurrently active policies deny a fresh request and invalidate an already-approved request rather than allowing ambiguous selection.
- `74_student_profile_p1_reviewer_scope_revoked.sql` **23/23**: independently approved request cannot apply after the reviewer's exact ALL/DIRECT authorization scope is revoked; revoked reviewer cannot read request, while original decision evidence stays immutable.

The first 71 suites and their 3,057 assertions remain an unchanged manifest prefix. Each new suite uses an isolated `BEGIN`/`ROLLBACK` fixture, real authenticated Student P0 enrollment placement, typed Student Profile submission, independent review and apply commands. No Student Profile two-session race is claimed.

## Six-file PR change review

1. `docs/database/164_d1_student_profile_p1_policy_scope_acceptance_candidate.md`
2. `supabase/tests/domain/72_student_profile_p1_replacement_policy_stale_apply.sql`
3. `supabase/tests/domain/73_student_profile_p1_ambiguous_active_policy.sql`
4. `supabase/tests/domain/74_student_profile_p1_reviewer_scope_revoked.sql`
5. `tools/supabase/domain_business_ci.py` (three append-only manifest entries)
6. `tools/supabase/tests/test_domain_acceptance_ci.py` (additive guard, plus correct frozen 71-suite **prefix**, not exact full-list-length assertion)

**No executable migration, database implementation SQL fragment, operational permissions, RLS, roles, production activation or hosted Supabase changes**. The baseline remains draft-only and no new migration semantics are frozen.

## Remaining gates

Owner decisions `SP-01` through `SP-08` in `docs/database/152_d1_student_profile_update_p1_contract_readiness.md` are unresolved. Final allowlisted columns, clear/null/no-op rules, file entitlement, scope resolution, before/after private retained history and true Student Profile two-session races remain unaccepted. The three additional outstanding operations `student.roll.correct`, `student.roll_policy.change`, and `student.create` (requires final Admissions handoff) are untouched. Count remains **31/35** protected operations. Migration 10 is inactive.

**Example:** A staff member requests changing a Student's prior school and a reviewer approves. If another approval policy becomes effective before the change is applied, that approval does not automatically transfer to the new policy; the request invalidates instead of changing the Student.
