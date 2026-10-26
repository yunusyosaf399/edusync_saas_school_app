# DB01-03 — Independently Reviewed P1 Student Roll APPROVED → APPLY

**Engineering acceptance date:** 2026-10-22. **Scope:** only DB01 Roll correction, new draft PR #141 stacked on DB01-02's accepted PR #139. **Status:** PASSED on disposable PostgreSQL; DRAFT / unmerged / no hosted activation. The independent external security acceptance and integration release gates are separate.

## Implementation

1. **Authenticated exact requester command.** `app.d1_apply_student_roll_correction(request_id uuid, expected_request_version bigint, idempotency_key text)` is a SECURITY DEFINER RPC owned by the existing workflow executor, accessible to the authenticated API role only through the verified Principal and active authorization checks. Public APPLY cannot run as a reviewer; the original authorized requester must issue a new command after independent approval. No new operation or permission is switched on.
2. **Live workflow and authorization.** Canonical `request.apply` command/Principal binding and per-key locks, request row FOR UPDATE, validated nine-key old source/one-key proposed value, state APPROVED + exact version, all configured approved stage votes, fresh reviewer role/scope and unwithdrawn assignment, distinct requester/reviewer Persons, requester Roll permission, and unchanged pinned Campus P1 APPROVAL policy. Revalidate after the protected source lock wait.
3. **Real Roll effect reused.** The existing private `d1_roll_correct_lock_source` and `d1_roll_correct_effect` run in the School→policy→allocator→Student→academic ancestry→Enrollment→Roll order, validate school-local correction date and source identity, check current persistent/academic Roll numeric namespace, close immutable R0 and insert one R1 with retained original lineage, then advance Student version exactly one. No second Roll-writing algorithm.
4. **Atomic workflow evidence.** Exactly one SUCCEEDED `request.apply` receipt, one minimal APPLY audit, one `enrollment.roll_corrected` outbox event with no numeric values, one APPROVED→EXECUTED transition, and one `approval_applications` record binding the prior target version N to the corrected Roll. Failed transactions roll back both effect and evidence.
5. **Guard reconciliation without privilege widening.** The final operation-specific approval application trigger implementation overrides the earlier frozen `effect40_03` result-version comparison in additive `effect41_11_db01_apply_guard_corrected_student_version.sql.draft`. The exact successful resulting Student version is **N+1**, not the snapshot N. The original `expected_target_version`, application `applied_target_version` and receipt `expected_request_version` guards still require N and the precise approved request predecessor. All other guard checks are unchanged. The older synthetic fixture #79 now models actual Student N→N+1, and tests the same guard along with forged receipt denial. Temporary debugging overrides were removed.

## Exact tested evidence

**Code HEAD:** `917c908942a87ceac27aad1fcb0ed1712b714e35` (before this documentation-only commit).

| Workflow | Outcome |
| --- | --- |
| [D1 draft static #39776341742](https://github.com/yunusyosaf399/edusync_saas_school_app/actions/runs/39776341742) | SUCCESS |
| [Foundation database #39776341696](https://github.com/yunusyosaf399/edusync_saas_school_app/actions/runs/39776341696) | SUCCESS |
| [D1 disposable runtime #39776341686](https://github.com/yunusyosaf399/edusync_saas_school_app/actions/runs/39776341686) | SUCCESS |

Disposable PostgreSQL log: `D1_BUSINESS_TEST_PASS 92_db01_roll_correct_p1_apply.sql 30/30`, `D1_BUSINESS_TEST_PASS 79_db01_approval_application_receipt_guard.sql 14/14`, `D1_BUSINESS_PASS 3603 assertions`, `D1C2A_PASS`, and catalog `tables=34 rls=34/34 functions=564 definers=546 app=161 private=403 auth_private=0 anon=0 service_role=0`. Source, functional and authz checks were run on the same code SHA.

## Remaining gates and restrictions

- **DB01-04:** robust same-key APPLY replay, distinct-key duplicate, REJECTED/INVALIDATED/stale and revoked grant terminal receipt integrity. This gate deliberately fails closed on repeated APPLY instead of pretending replay is proven.
- **DB01-05 through DB01-10:** checked reads, authorization edge and independent PostgreSQL races (especially REVIEW/APPLY and APPLY over CORRECT/MOVE/END), historical boundaries, integration.
- **DB01-11 / DB01-12:** independent security assessment, product acceptance, non-draft deployment planning, and any future merge/activation. These are not authorized by disposable engineering success.

**No hosted Supabase write, no executable Migration 10 or activated `student.roll.correct`, and no DB02/DB03/DB04 changes.**
