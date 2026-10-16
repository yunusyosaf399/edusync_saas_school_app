# D1 Student Profile P1 negative acceptance — independent CI merge freeze

Date: 2026-10-16. **Status: ACCEPTED incremental rollback-only Student Profile P1 test coverage. The complete `student.profile.update` operation remains BLOCKED; 31/35 accepted protected operations remain unchanged.**

## GitHub exact-commit chain

- Verified predecessor `main`: `034a1efbcf0c467a9a3210c534abde6d7b3465ac`, frozen PR #72 Student Profile P1 APPROVAL acceptance, `docs/database/161_d1_student_profile_p1_approval_ci_merge_freeze.md`.
- [PR #73](https://github.com/yunusyosaf399/edusync_saas_school_app/pull/73) was merged SHA-guarded against exactly its CI-tested head `4194c928fa89807879b399c8ce604d4ed4747aeb`.
- The exact merge commit `b4c99af1e85ada458d93432871ed5aea6f74a6de` was independently read back from GitHub's `main` branch; PR marked merged/closed.
- [D1 local runtime](https://github.com/yunusyosaf399/edusync_saas_school_app/actions/runs/38889896902): **SUCCESS** for exact PR head.
- [Foundation database local stack](https://github.com/yunusyosaf399/edusync_saas_school_app/actions/runs/38889896942): **SUCCESS** for exact PR head.
- [D1 draft static / ownership](https://github.com/yunusyosaf399/edusync_saas_school_app/actions/runs/38889896680): **SUCCESS** for exact PR head.

## Exact runtime evidence independently inspected

- `D1_BUSINESS_TEST_PASS 68_student_profile_p1_reject_no_effect.sql 20/20`: independently authenticated reviewer rejects v3 pending request to terminal REJECTED v4; same-key receipt cannot switch decision; requester cannot apply; no profile mutation, version increment, application proof or success event.
- `D1_BUSINESS_TEST_PASS 69_student_profile_p1_retired_policy_invalidation.sql 21/21`: independent reviewer approves v4 then pinned original approval policy is retired; exact apply returns INVALIDATED v5, with rejected typed receipt, durable independent review and no effect; replay stable.
- `D1_BUSINESS_TEST_PASS 70_student_profile_p1_requester_scope_revocation.sql 19/19`: revoke requester's specific ALL/DIRECT scope after independent review; requester cannot apply; independently authorized FINAL_APPROVER also cannot bypass lost requester authority; INVALIDATED rather than effect.
- `D1_BUSINESS_TEST_PASS 71_student_profile_p1_target_version_drift.sql 17/17`: rollback-only synthetic competing permitted Student field update advances server-owned version; original approved request invalidates without clobbering the newer value. **Not** two-session contention or a deployed raw Student update.
- Existing previous 67 suites remained unchanged and pass; **71/71 business suites / 3,057/3,057 assertions** in disposable local runtime.
- `D1C2A_APPLY_PASS 228 draft fragments parsed/applied locally` (not hosted).
- `D1C2A_CATALOG_PASS tables=34 rls=34/34 functions=542 ... authenticated_app_private=0`; Foundation regression `220/220` and independent Foundation `9 files / 220 planned / 220 passed`.
- Static `D1_DRAFT_STATIC_PASS 228 fragments; 34 relations; 97 permissions; 322 scope alternatives; 36 operations`; final function static `unknown_owners=0`, `signature_shape_drift=0`.
- Existing observed two-session concurrency suites passed, but **no Student Profile-specific two-session race is claimed**.

## Exact seven-file diff independently reviewed

1. `docs/database/162_d1_student_profile_p1_negative_acceptance_candidate.md`: candidate test plan and limitations.
2. `supabase/tests/domain/68_student_profile_p1_reject_no_effect.sql`: new independent rejection/receipt/zero-effect suite.
3. `supabase/tests/domain/69_student_profile_p1_retired_policy_invalidation.sql`: new approved-then-retired policy fail-closed suite.
4. `supabase/tests/domain/70_student_profile_p1_requester_scope_revocation.sql`: new approved-then-revoked requester authority fail-closed suite.
5. `supabase/tests/domain/71_student_profile_p1_target_version_drift.sql`: new expected-version drift and no-clobber suite.
6. `tools/supabase/domain_business_ci.py`: append four planned suites/77 assertions to preserved 67-suite/2,980 prefix, totaling 71/3,057.
7. `tools/supabase/tests/test_domain_acceptance_ci.py`: static test manifest, expected plan, rollback, fixture and scenario evidence guards.

**No executable or dormant SQL implementation fragment was changed by PR #73**; no new permissions, exposed tables, RLS, roles, operation activation, physical history relation or deployment. The SQL test fixtures enable their Student Profile operation only within their own rollback transaction. No hosted Supabase changes.

## Remaining full-operation gates

This milestone adds precisely the 77 verified tests; it does **not** make a full `student.profile.update` product acceptance claim. The eight owner choices **SP-01 through SP-08** in `docs/database/152_d1_student_profile_update_p1_contract_readiness.md` still require explicit contract decisions, including: exact field allowlist, absence/null/no-op semantics, photo entitlement, expected version and idempotent receipt, approved route/scope behavior, reviewer and actor drift, evidence privacy, and secure before/after retention. Remaining acceptance includes campus/section scope changes, policy replacement and ambiguous active policies, typed photo negative cases, and genuine two-session Student Profile versus permission-revocation races.

The other three remaining disabled operations remain `student.roll.correct`, `student.roll_policy.change`, and `student.create` (the last blocked by final Admissions single-use handoff). Thus **31/35** accepted operations remains the only defensible count. Migration 10 remains a draft and is not activated.

**Concrete example:** If an independent reviewer approves changing a Student's old-school field, but the requester's authorization scope is revoked before apply, the reviewer still may not force it through; the original Student record stays unchanged and the pending approved request is marked INVALIDATED. The test proves only this existing rollback-only workflow slice, not the final production data contract.
