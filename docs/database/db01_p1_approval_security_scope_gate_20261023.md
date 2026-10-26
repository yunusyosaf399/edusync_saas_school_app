# DB01-06 — Approval security, Person boundary and authorization scope

**Acceptance:** PASS in disposable PostgreSQL on 2026-10-23. Tested exact SHA: `ff4bac6d25ecf87fd983f2936c90ee9f33c575fd`. **Not** independent security signoff, production permission enablement, migration application or merge authorization.

## Scope and scenarios

This task extends the existing genuine authenticated SUBMIT→REVIEW→APPLY suite `92_db01_roll_correct_p1_apply.sql`, rather than changing SQL contracts for production.

1. **Same-Person/signed-in self-review.** Foundation enforces one simultaneously live individual Principal per Person through the `principals_individual_person_live_uidx` unique index. A synthetic attempt to create a second active Principal for the requester's Person is rejected with SQLSTATE 23505. Reviewer candidate selection excludes the actual requester Principal, and a requester calling `app.d1_review_student_roll_correction` with genuine authenticated identity cannot self-approve.
2. **Caller binding and impersonation.** A participant helper rejects any `p_actor` argument other than `app_private.current_principal_id()`. A deliberately unbound Auth subject cannot read the P1 request; after restoring a distinct actually bound reviewer Principal, normal authorization still works. These transaction-local claim simulations test the DB-side resolver, **not** the API's JWT signature verification.
3. **Reviewer cross-Campus/Section.** Revoking the original ALL grant and substituting a current Campus grant to a different Campus denies both checked request viewing and protected review. A matching Campus grant succeeds. A grant to a different Section in the same Class denies access, while a matching Section grant succeeds. All grants must also match the assigned reviewer Role.
4. **Evidence privacy.** Disallowed attempts cannot create approval reviews or `request.review` receipts. Review/APPLY broad audit details and correction outbox payload do not reveal numeric Roll identity or submitted free-form reason. One approved correction produces one minimized `enrollment.roll_corrected` outbox event.
5. **Private functions and RLS.** The sampled DB01 security helper signatures and all D1-scoped private functions are EXECUTE-denied to `authenticated`, `anon` and `service_role`. The domain catalog reports zero forbidden execution privileges, 34 of 34 FORCE RLS tables and no expansion of client table permissions.

A distinct test Section carries its matching capacity-revision record to satisfy deferred Foundation integrity checks. All fixture effects are rolled back at the end of the test file.

## Runtime acceptance evidence

| Gate | Verified result |
| --- | --- |
| [D1 draft static #39907929496](https://github.com/yunusyosaf399/edusync_saas_school_app/actions/runs/39907929496) | SUCCESS |
| [Foundation local stack #39907929509](https://github.com/yunusyosaf399/edusync_saas_school_app/actions/runs/39907929509) | SUCCESS |
| [D1 full local runtime #39907929555](https://github.com/yunusyosaf399/edusync_saas_school_app/actions/runs/39907929555) | SUCCESS |
| Roll P1 source suite | `92_db01_roll_correct_p1_apply.sql 113/113` |
| Complete domain suite | `D1_BUSINESS_PASS 3686 assertions` |
| Foundation regression | 220/220 |
| Runtime security catalog | `tables=34 rls=34/34 functions=569 definers=551 app=162 private=407 auth_private=0 anon=0 service_role=0` |

## Release boundary

All Migration 10 fragments stay as `.sql.draft`, including DB01 implementation. PR #141 stays draft/unmerged and stacked on PR #139. The Roll-correction protected operation and permission default to disabled. DB01-07 real two-backend concurrency, DB01-08/09 integration, DB01-10 cross-workstream dependencies, DB01-11 independent security review and DB01-12 explicit production authorization remain separate unfulfilled gates.
