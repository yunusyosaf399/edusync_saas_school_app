# D1 Section Offering P0 lifecycle, ancestry, capacity and room archive — business acceptance review

Date: 2026-10-13
Verdict: **PASS — independently verified incremental disposable-local PostgreSQL business acceptance. Full D1 remains OPEN.**

## Exact source and independent CI evidence

- Prior accepted/frozen `main`: `00e3f2f78989f451a7e1deb1c00c452e51c3e032` (**33 suites / 1,700/1,700 pgTAP business assertions / 19 observed-lock races**), incorporating the frozen Class Offering review.
- [PR #44](https://github.com/yunusyosaf399/edusync_saas_school_app/pull/44) **MERGED**. Exact corrected, reviewed, tested candidate SHA: `765f50da571c94ddd2c467ef844c3f44fe5f1c95`. Merge commit: `524f6a50182513bac65c7ac4406efe530db88347` with **exactly two expected parents**, prior frozen main and tested head. Comparison confirms **exactly three acceptance-only paths**.
- [D1 Migration 10 disposable-local PR runtime #38345219772](https://github.com/yunusyosaf399/edusync_saas_school_app/actions/runs/38345219772) **PASS** on the candidate: **34 suites / 1,756/1,756 business pgTAP assertions**, including new `34_academic_section_offering_lifecycle_authorization.sql` **56/56**, **51/51 D1 Python tooling tests**, **220/220 post-D1 Foundation SQL regressions**, all **19/19** previously accepted true two-session observed-lock concurrency cases, both SQL lint levels, and `D1C2A_PASS`. Confirmed `D1C2A_SOURCE_PASS 202 fragments; 34 relations; final_functions=540` and local-only assembly/application; `D1C2A_CATALOG_PASS tables=34 rls=34/34 functions=540 definers=522 app=157 private=383 auth_private=0 anon=0 service_role=0`.
- [Foundation local stack PR #38345219748](https://github.com/yunusyosaf399/edusync_saas_school_app/actions/runs/38345219748) **PASS**: nine frozen migrations / nine SQL files, **207/207 Python tooling tests**, **220/220 Foundation SQL assertions**, fixture checks, clean local reset, and local SQL lint. Independent push workflows [D1 #38345216290](https://github.com/yunusyosaf399/edusync_saas_school_app/actions/runs/38345216290) and [Foundation #38345216304](https://github.com/yunusyosaf399/edusync_saas_school_app/actions/runs/38345216304) also **PASS** on the identical candidate SHA.
- The first candidate had a **tooling-guard-only CI failure**, not a database acceptance result: old Class Offering test assumed suite #33 would always be last. Follow-up commit `765f50da571c94ddd2c467ef844c3f44fe5f1c95` changed the earlier guard to assert an immutable 33-suite/1,700-assertion **prefix**. All four latest workflows passed on that corrected exact SHA. The failing earlier candidate is **not** the accepted SHA.

## Newly accepted distinct operation

The fixed deployed-in-disposable-local RPC is `app.d1_change_academic_section(text,uuid,uuid,uuid,text,text,integer,integer,text,bigint,text)`, registered as `academic.section.change` with its distinct `academic.section.manage` permission. CREATE resolves permission at the parent Class Offering scope; UPDATE/ARCHIVE at the Section scope. Section code, Class Offering and Campus ancestry are retained. The fixture grants a non-FAMILY staff Principal one exact active `ALL/DIRECT` Section role permission and matching current assignment scope; an unrelated `academic.class.manage` permission is not sufficient.

The **56/56** accepted synthetic pgTAP assertions verify:

1. CREATE in the exact School/Class/Campus/Academic-Year/Class Offering context returns version 1 and retains Section initial capacity **20**, a new `INITIAL_CONFIGURATION` typed capacity revision and a successful Section receipt reference. No missing/mismatched parent Campus, negative capacity or initially ARCHIVED state is accepted; duplicate code within an Offering is rejected, including after archive.
2. Protected UPDATE allows PLANNED → OPEN → CLOSED, increments optimistic Section versions 2 and 3, retains stable ID/ancestry/code and rejects direct capacity mutation; invalid target/code/state, stale expected_version, zero expected_version and missing label fail.
3. Successful CREATE and UPDATE idempotency replays preserve the *original* identity/version, including after later updates and archive. Changed intent with the same key conflicts. Successful ARCHIVE replay remains version 4; denied/duplicate requests introduce no extra successful effect.
4. A **current room-history assignment** blocks ARCHIVE with `D1 Academic Section has current/future Room assignment`. The room/assignment fixture is privileged synthetic data created only under a SAVEPOINT; failed ARCHIVE changes no version. After rolling back the room blocker, CLOSED → ARCHIVED succeeds at version 4, sets verified actor and timestamp and cannot be reopened.
5. Independent revocation of just the permission assignment scope or just the role-permission grant denies previously successful command replay. Turning off the exact operation also denies replay. Direct authenticated `app_private.section_offerings` SELECT or DELETE remains disallowed.
6. Exactly **one retained archived Section**, **one initial Section capacity revision** linked to receipt, **four successful receipts**, **four successful audit entries**, and **four minimized** `academic.section_changed` SECTION outbox events survive until final transaction rollback. Outbox contains reviewed state but not raw capacity values.
7. Deferred constraints are forced before `finish()`; the shared Auth fixture and all test-created School data are discarded by a final top-level `ROLLBACK`. These are disposable-local-only checks, not evidence of a hosted database release.

## Exact diff and scope

1. `supabase/tests/domain/34_academic_section_offering_lifecycle_authorization.sql`: new rollback-only SQL suite **56 assertions**, including current/future Room archive blocker and evidence isolation.
2. `tools/supabase/domain_business_ci.py`: append suite #34, preserving previously accepted 33-suite/1,700 assertion manifest unchanged.
3. `tools/supabase/tests/test_domain_acceptance_ci.py`: static source/security/rollback guard for #34, plus correction of previous #33 guard to assert the accepted **prefix**, not a perpetually final slot.

No Foundation schema/tests, domain Migration 10 `.sql.draft` fragment, Supabase config, application code, existing 33 SQL business suites, production role grant or hosted school data changed. All **202** Migration 10 SQL fragments remain non-executable `.sql.draft` in GitHub and were assembled/applied solely on disposable PostgreSQL in CI.

## Accepted checkpoint and remaining work

**Frozen incremental D1C2A checkpoint:** **34 suites / 1,756/1,756 business assertions**, **19/19 independently observed-lock true two-session races**, **51/51 D1 tooling tests**, **207/207 Foundation tooling tests**, **220/220 Foundation SQL**. Dedicated business-suite breadth has grown from nine to **ten distinct D1 operations**; **25** other drafted operations still lack individual dedicated suites, and `student.create` remains disabled pending Admissions.

**Still OPEN:** exhaustive authorization, scope/approval/read permutations, further genuine races, remaining domain operations, populated-database migration/upgrade/reconciliation, Admissions/Finance and any hosted Migration 10 activation. Passing local execution is **not** production readiness and does not authorize `supabase db push`.

**Next operation-specific breadth target:** `academic.section_room.change` through `app.d1_change_academic_section_room` — protected room assignment ADD/END/CORRECT, Section/Room Campus ancestry, effective intervals, history and idempotent receipts. For example: assigning Room 101 to Section A on a given date should require the room and section to share the correct Campus; changing the room must preserve historical assignments, not overwrite old records. Confirm the frozen exact signature and rules before test construction.

**Checkpoint:** `D1_ACADEMIC_SECTION_OFFERING_P0_LIFECYCLE_ACCEPTANCE_PASS — 1756/1756 BUSINESS — 34 SUITES — 19/19 OBSERVED-LOCK RACES — 220/220 FOUNDATION SQL — 51/51 D1 PYTHON — 207/207 FOUNDATION PYTHON — 202 INACTIVE DRAFT FRAGMENTS — FULL D1 OPEN`.
