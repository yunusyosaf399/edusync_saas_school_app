# DB01 + DB02 I05 — frozen draft-only combined PostgreSQL preview

**Integration-only, no owner branch edits and no production activation.**

Source parents are immutable: DB01 [draft PR #141](https://github.com/yunusyosaf399/edusync_saas_school_app/pull/141) at `c8800dcfa8f2a4439c989f6d37bc25da611227d4`; DB02 [draft PR #147](https://github.com/yunusyosaf399/edusync_saas_school_app/pull/147) at `2553e10a1848762f9865038c3efcfdf12b53585a`. This integration branch creates a **two-parent merge** and brings only DB02-owned docs, effects42–51, suites82–93 and its acceptance-unit additions onto the DB01 source. SQL fragments are **byte-for-byte from DB02**, with no rewritten School Policy behaviors or unexpected client EXECUTE grants. The three common test manifests are reconciled separately on this preview branch.

## Test ownership and measurable acceptance

- DB01 source tests #81–92 plus genuine authenticated P1 APPLY, multistep rejection, School-local correction, and real two-backend race drivers remain registered.
- DB02 test suites #82–86, #89–93 are registered under their **full distinct filenames**, not numeric prefixes. The DB02 original #92 and DB01 #92 must both run.
- Expected sum of registered domain pgTAP plans: **3,906 = DB01 3,686 + ten DB02-only suites totaling 220**. This is only a manifest prediction before real CI.
- Expected D1 catalog after applying draft effects: **577 functions, 559 definers, 162 app, 415 private**, with 34 FORCE-RLS relations, no forbidden anon/authenticated/service-role private EXECUTE. This is a computed union (**DB01 569 functions + DB02 8 net private definers**), not a passing observed count.
- Revalidate static, Foundation 220/220, D1 all suites, and all real PostgreSQL race markers on the **same integration SHA**. No earlier separate-workstream success constitutes this result.

## Release-blocked integration decisions

1. **DB02 policy REPLACE / DB01 correction:** The current DB01 `effect41_01` refuses an expired stored Roll policy; DB02 I04/I05 retains original current Roll allocations across revision cutover. Keep this fail-closed behavior; the owner must separately decide whether and how a legitimate later correction under a newly effective policy is possible. Do not silently assign a new policy UUID to historical Roll.
2. **DB02 I05 private-only cutover:** no protected authenticated DIRECT/APPROVAL, terminal receipt/audit/outbox, future Class Offering hook, independent non-author security signoff, or genuine two-backend CHANGE/CORRECT contention yet.
3. **DB03 P7:** approved Finance-authorizer clearance and one-shot Student creation handoff are not installed; no generated Roll during a mere application or submitted offer. Initial Roll is server-assigned at successful Enrollment P0 under owner Option A.
4. **DB04 CUR-06:** no automatic migration of elective history on actual Enrollment MOVE; Roll correction changes Student version but not Enrollment identity, selection sets or prior consumer-published snapshots. DB04 eight-table physical schema and Exams/Learning/Timetable signoffs are not installed.

## Merge/rollback

This draft integration head is **not** intended as a second deployable copy of either owner stack. Do not merge it into main along with its complete source ancestry; choose one reviewed integration ancestry after CI, independent DB01-11/security approval and user-authorized DB01-12. All Migration 10 fragments remain `.sql.draft` and Roll operations remain disabled outside ephemeral CI.

## Exact-head integrated PostgreSQL acceptance — PASS

The **tested two-parent integration code** is `79e4aedefea03e1d4e874171115638b4a45a7143` (DB01 parent `c8800dcfa8f2a4439c989f6d37bc25da611227d4`, DB02 parent `2553e10a1848762f9865038c3efcfdf12b53585a`). All three required workflows completed **SUCCESS**:

- [D1 static #39949975376](https://github.com/yunusyosaf399/edusync_saas_school_app/actions/runs/39949975376)
- [Foundation local-stack #39949975323](https://github.com/yunusyosaf399/edusync_saas_school_app/actions/runs/39949975323)
- [D1 disposable PostgreSQL #39949976507](https://github.com/yunusyosaf399/edusync_saas_school_app/actions/runs/39949976507) — **SUCCESS**, duplicate [runtime #39949927193](https://github.com/yunusyosaf399/edusync_saas_school_app/actions/runs/39949927193) also SUCCESS on the **same** code.

**Actual log evidence on both full runtimes:** `D1C2A_APPLY_PASS 267 draft fragments`; `D1C2A_CATALOG_PASS tables=34 rls=34/34 functions=577 definers=559 app=162 private=415 auth_private=0 anon=0 service_role=0`; `D1C2A_FOUNDATION_REGRESSION_PASS ... 220/220`; `D1_BUSINESS_TEST_PASS 92_db01_roll_correct_p1_apply.sql 113/113`; `D1_BUSINESS_TEST_PASS 92_db02_atomic_policy_revision_transition.sql 27/27`; `D1_BUSINESS_TEST_PASS 93_db02_atomic_roll_allocator_pools.sql 29/29`; `D1_BUSINESS_PASS 3906 assertions`; `D1C2A_PASS`.

**Real authenticated interaction markers preserved on the composed stack:** `D1_DB01_P1_APPLY_AM_REAL_PG_RACE_PASS`, `..._MA_...`, `..._AE_...`, `..._EA_...` (both winner orders for correction/MOVE and correction/END), `D1_DB01_P1_R0_R1_R2_REAL_PG_PASS`, `D1_DB01_P1_FULL_SUBMIT_APPROVE_APPLY_INTEGRATION_PASS`, `D1_DB01_P1_FULL_SUBMIT_REJECT_STAGE1_INTEGRATION_PASS`, `D1_DB01_P1_FULL_SUBMIT_APPROVE_REJECT_STAGE2_INTEGRATION_PASS`.

**Accepted gate:** DB01+DB02 I05 source/SQL/CI composition coexists and all existing enrolled Roll/allocator/approval/race tests pass in one disposable local database. DB02's I05 transition remains a **private rollback-fixture effect**, not a protected authenticated public policy command. This result is **not** a new two-backend DB01 APPLY versus DB02 REPLACE race and does **not** exercise an end-to-end after-cutover correction by the same Student. That gap and DB03/DB04 deployment/interface gates remain blocked exactly as above; no independent security signoff, hosted migration or production rollout was performed.

**Evidence binding:** This report is documentation added *after* the tested SHA; any documentation-only head has its own CI status. The acceptance belongs to `79e4aedefea03e1d4e874171115638b4a45a7143` and both tests were verified on that exact SHA.
