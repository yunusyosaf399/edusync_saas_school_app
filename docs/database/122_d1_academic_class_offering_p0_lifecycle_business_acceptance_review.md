# D1 Class Offering P0 lifecycle, ancestry and capacity — business acceptance review

Date: 2026-10-13
Verdict: **PASS — independently reviewed incremental disposable-local PostgreSQL acceptance. Full D1 remains OPEN.**

## Exact source and independent CI

- Prior accepted and frozen `main`: `390bee78fcfe76018f0fd77a719825da27f46467` (**32 suites, 1,648 business assertions, 19 true two-session races**).
- [PR #43](https://github.com/yunusyosaf399/edusync_saas_school_app/pull/43) **MERGED**, exact reviewed and tested source head `10844617e7cad916c3f8ee5bff9d291c263d3f50`, merge commit `b9b2b078486f6eac8480ab69826f033dc7221337`. The merge has exactly those two parents (the prior accepted `main` and the candidate), and exactly **three acceptance-only paths** changed.
- [D1 Migration 10 disposable-local runtime #38338886790](https://github.com/yunusyosaf399/edusync_saas_school_app/actions/runs/38338886790) **PASS** on the exact PR SHA: **1,700/1,700** business pgTAP assertions across **33** suites; `33_academic_class_offering_lifecycle_authorization.sql` **52/52**; **50/50** D1 Python tooling tests; **220/220** post-D1 frozen Foundation SQL assertions; **19/19** previously accepted actual two-session observed-lock races; both SQL lint levels; `D1C2A_PASS`. D1 probe: `D1C2A_SOURCE_PASS 202 fragments; 34 relations; final_functions=540`; `D1C2A_APPLY_PASS` locally; `D1C2A_CATALOG_PASS tables=34 rls=34/34 functions=540 definers=522 app=157 private=383 auth_private=0 anon=0 service_role=0`.
- [Foundation local stack #38338886818](https://github.com/yunusyosaf399/edusync_saas_school_app/actions/runs/38338886818) **PASS**: nine frozen migrations/nine SQL test files, **206/206** Python tooling tests, **220/220** Foundation pgTAP assertions, clean local reset, fixture checks and lint.

## Newly accepted distinct operation

The tested fixed RPC is `app.d1_change_academic_offering`, enforcing `academic.offering.change` and separate `academic.offering.manage` authority. A Class Offering associates an Academic Class with one exact Campus and Academic Year within the School; it does not modify the global Academic Class catalog. The installed permission catalog supports ALL/CAMPUS/CLASS, while the synthetic acceptance fixture uses one exact non-FAMILY, active ALL/DIRECT grant with the current staff Principal. An unrelated `academic.class.manage` grant alone cannot authorize a Class Offering command.

The **52/52** synthetic pgTAP assertions verify:
1. CREATE from eligible School/Class/Campus/Academic Year ancestry returns a Class Offering UUID and version 1. It retains exactly one initial capacity revision with `INITIAL_CONFIGURATION`, new capacity 30 and a successful command-receipt link. Negative initial capacity, archived initial state and missing School/Class/Campus/Year fail.
2. Exact-key CREATE replay returns its original identity/version after later changes; same key with changed capacity conflicts; a second Class/Campus/Year duplicate fails even after archival. The stored ancestry and stable identity remain unmodified.
3. Protected UPDATE follows PLANNED → OPEN → CLOSED, increments optimistic version 2 and 3, and cannot alter capacity. Stale version, invalid state, mismatched ancestry and changed-key intent deny.
4. ARCHIVE is blocked while a nonarchived Section Offering exists; the fixture-created Section and its starting capacity evidence are rolled back to an isolated SAVEPOINT. With no blocking Section, CLOSED → ARCHIVED succeeds at version 4, preserves actor/archive timestamp, and cannot be reopened. CREATE, UPDATE and ARCHIVE successful receipts remain replayable after later lifecycle mutations.
5. Independent scope-only and role-grant-only revocation both deny previously successful-key replay under fresh current authority. An independently disabled operation likewise denies replay. Authenticated private Offering SELECT/DELETE deny.
6. Exactly one archived Class Offering, one initial capacity revision, **four accepted receipts**, **four audit events** and **four** version-distinct minimized `academic.offering_changed` outbox events survive the synthetic command sequence. Broad outbox payload includes state but excludes raw capacity, and failed/replayed commands do not add success evidence.
7. All test state is transaction-local: deferred constraints are forced, pgTAP `finish()` passes, then a full ROLLBACK discards synthetic School data. No managed database is touched.

## Exact diff and scope

1. `supabase/tests/domain/33_academic_class_offering_lifecycle_authorization.sql` — **52** assertions, transaction-local fixture, explicit rejected cases and receipt/evidence checks.
2. `tools/supabase/domain_business_ci.py` — append suite #33 and move the planned assertions from **1,648 to 1,700** without altering older suite registrations.
3. `tools/supabase/tests/test_domain_acceptance_ci.py` — static source guard, exact suite/manifest count, rollback discipline, feature/security markers, and retention of the prior 32/1,648 checkpoint as an immutable prefix.

No Foundation SQL, D1 Migration 10 draft SQL, application source, Supabase configuration, deployment automation or previously accepted D1 tests were changed. The **202** Migration 10 fragments remain inactive `.sql.draft`; they were assembled/applied **only in disposable local CI**, not on any hosted school Supabase project.

## Frozen checkpoint and remaining work

**Accepted/frozen incremental D1C2A:** **33 suites / 1,700/1,700 business assertions**, **19/19 genuine observed-lock two-session races**, **50/50 D1 Python**, **206/206 Foundation Python** and **220/220 Foundation SQL** assertions. This extends distinct operation-specific business acceptance from eight to **nine** covered operations. **26** other drafted D1 operations still lack a dedicated suite and `student.create` remains disabled pending Admissions.

**Not accepted:** exhaustive RLS/scope/approval/read permutations or all domain operations; populated-database upgrades/reconciliation; hosted Migration 10 activation; Admissions and Finance integration; production readiness. Full D1 remains **OPEN** and Migration 10 execution remains unauthorized.

**Next breadth target:** `academic.section.change` — Section Offering lifecycle/ancestry/capacity and scope-aware protected commands; first verify the exact registered code/signature before constructing an acceptance-only suite.

**Checkpoint:** `D1_ACADEMIC_CLASS_OFFERING_P0_LIFECYCLE_ACCEPTANCE_PASS — 1700/1700 BUSINESS — 33 SUITES — 19/19 OBSERVED-LOCK RACES — 220/220 FOUNDATION — 50/50 D1 UNIT — 202 INACTIVE DRAFT FRAGMENTS — FULL D1 OPEN`.
