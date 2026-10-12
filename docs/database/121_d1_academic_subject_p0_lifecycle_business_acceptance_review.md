# D1 Academic Subject P0 lifecycle, authorization and receipt — business acceptance review

Date: 2026-10-12
Verdict: **PASS — incremental, exact-source, disposable-local PostgreSQL business acceptance only. Full D1 remains OPEN.**

## Exact CI source, independent green gates and merge

- Previously accepted/frozen `main`: `47386c7963bb61c1a4996d1ede97f371bcf5f8d7`, with **31 suites / 1,594/1,594 business assertions** and **19/19 actual two-session observed-lock concurrency races**.
- [PR #42](https://github.com/yunusyosaf399/edusync_saas_school_app/pull/42) **MERGED** at `aa3fcb13f3c0734930d9a0370a46c9c58bc6acd7` from exact reviewed source head `5109abadd77dfe30ed1983e821434d8f34def32e`. Both passing workflows checked out the same GitHub PR test-merge ref `747a451e5cce861d196ec5314aa20299cc838b57` (the head merged into the previously frozen base). Three, and only three, acceptance-only paths changed.
- [D1 Migration 10 disposable local runtime #331](https://github.com/yunusyosaf399/edusync_saas_school_app/actions/runs/38288359545) **PASS** with `D1C2A_PASS`: **1,648/1,648** business pgTAP assertions across **32** suites. The newly added `32_academic_subject_lifecycle_authorization.sql` passed **54/54**, following the prior 31 accepted suites without rewriting their tests. **49/49** D1 Python tooling tests, **220/220** post-D1 frozen Foundation SQL regressions, **19/19** previously accepted real two-session observed-lock races, both error/warning SQL lint levels and D1 catalog/RLS/ACL checks PASS. The runtime log confirms `D1C2A_SOURCE_PASS 202 fragments; 34 relations; final_functions=540`, `D1C2A_APPLY_PASS 202 draft fragments parsed/applied locally` and `D1C2A_CATALOG_PASS tables=34 rls=34/34 functions=540 definers=522 app=157 private=383 auth_private=0 anon=0 service_role=0`.
- [Foundation database local stack #493](https://github.com/yunusyosaf399/edusync_saas_school_app/actions/runs/38288359435) **PASS**: frozen nine Foundation migrations and nine SQL test files, clean reset, error and warning lint, **205/205** Python tooling tests and **220/220** Foundation SQL assertions.

## Distinct new operation and test boundary

This suite expands dedicated business-acceptance coverage to the **`academic.subject.change`** operation. D1's frozen `app.d1_change_academic_subject(text,uuid,uuid,text,text,integer,bigint,text)` is a school-wide authoritative **Subject catalog** with only three supported lifecycle actions: `CREATE`, `UPDATE`, `ARCHIVE`. Subject identity/code is stable; the label and display order are editable while ACTIVE; archival preserves code and history. The catalog is an input to later teaching assignments. This does **not** constitute acceptance of curriculum revisions, Class-Subject composition, electives, term assessment content or other independent Academic Operations packages.

The new pgTAP suite runs entirely within **one BEGIN/ROLLBACK synthetic fixture transaction**. It reuses the accepted verified INDIVIDUAL staff principal/Auth binding, enables only the installed Subject operation/permission/ALL-DIRECT scope contract, then separately proves the existing `academic.class.manage` grant **cannot** authorize Subject creation. A synthetic schema-owner test setup creates the correctly matched current `academic.subject.manage` role-permission grant and one linked `ALL/DIRECT` assignment scope for the existing active staff role assignment. All business commands themselves use **SET ROLE authenticated** through the fixed `app` Subject RPC, not privileged private-table DML.

**Accepted positive and negative Subject assertions (54/54):**
1. Authenticated Subject **CREATE** returns a non-null UUID and version 1. Exact-key canonical-idempotency replay returns that original UUID and version. Same key with different label rejects. Different-key duplicate school-wide code rejects on unique index.
2. **UPDATE** keeps the original UUID and increments version to 2. Same-key identical UPDATE replay returns the original stable result. Stale expected version, changed immutable stored Subject code/target ancestry, reused update key with a changed payload, NULL required label, zero expected version, blank code, unknown school UUID, missing Subject UUID, unsupported action and nonblank profile payload on ARCHIVE all reject.
3. Temporarily revoke **only the assignment scope**, **only the role grant**, and **only the installed permission** in independent SAVEPOINT scenarios. Each independently denies even an existing successful-key CREATE replay under fresh current authority. Savepoints then restore live grant/scope/permission without mutating the previously accepted Subject or receipt histories.
4. Authorized **ARCHIVE** keeps the original identity and increments version to 3. Same-key ARCHIVE replay keeps the original response; original CREATE/UPDATE receipts remain separately replayable after later lifecycle changes. A different-key UPDATE or ARCHIVE on an already archived Subject cannot reopen/change it; archived Subject code is still reserved.
5. Authenticated attempts at raw `SELECT` or `DELETE` of `app_private.subjects` are denied. Owner-only verification confirms exactly one retained ARCHIVED Subject, original stable MATH code, updated Mathematics and Numeracy label/display order, three versions, verified creator/archiver, and immutable archive timestamp.
6. The successful three business commands produce **exactly three** persisted SUCCEEDED command receipts, three `academic.subject.change` audit records and three minimized `academic.subject_changed` `SUBJECT` outbox events for distinct aggregate versions, with allowed `state` and no raw Subject label in the outbox payload. Rejected intent and replay attempts do not create duplicate success evidence.
7. Temporarily disable only the deployment-owned Subject operation and assert that even a successful-key replay fails with the exact `D1 operation is not enabled` response. The test forces deferred constraints IMMEDIATE and calls pgTAP `finish()` before rolling all synthetic state back.

**Exact source diff:**
- New `supabase/tests/domain/32_academic_subject_lifecycle_authorization.sql` — **54** new pgTAP assertions, single synthetic actor fixture, complete rollback and deferred-check boundary.
- `tools/supabase/domain_business_ci.py` — append the thirty-second suite with 54 assertions; **1,648 total** (previous 31/1,594 unmodified).
- `tools/supabase/tests/test_domain_acceptance_ci.py` — add one static guard verifying the 32-suite registry and 1,648 totals, 54 planned assertion calls, fixture, authorization/replay/evidence coverage and no hosted mutation.

## Accepted checkpoint and remaining gates

**Accepted/frozen incremental local D1C2A:** **32 suites / 1,648/1,648 business assertions**, covering selected happy/denial/replay paths through **eight** distinct domain operations; **19/19 true two-session observed-lock races** remain accepted; **49/49 D1 Python**, **205/205 Foundation Python**, and **220/220 Foundation SQL** regression evidence PASS. No previously frozen schema or SQL draft changed.

**Not accepted by this checkpoint:** exhaustive per-operation/scope/checked-read coverage; remaining **27 implemented D1 operations** with no dedicated business suite (and the disabled `student.create` dependency), full D1 business contract acceptance, populated-database upgrade and reconciliation, hosted Migration 10 activation, Admissions integration, or production/service readiness. All **202** Migration 10 fragments are still inactive `.sql.draft` in the repository and are applied only to disposable local PostgreSQL by the CI harness. No hosted Supabase resource was touched.

**Suggested next operation:** `academic.offering.change` — Class Offering CREATE/UPDATE/ARCHIVE and school/Class/Campus/Academic Year ancestry, lifecycle, versions, current authority, receipt/audit/outbox and unmodified frozen SQL.

**Checkpoint:** `D1_ACADEMIC_SUBJECT_P0_LIFECYCLE_ACCEPTANCE_PASS — 1648/1648 BUSINESS — 32 SUITES — 19/19 OBSERVED-LOCK RACES — 220/220 FOUNDATION — 49/49 D1 UNIT — 202 INACTIVE DRAFT FRAGMENTS — FULL D1 OPEN`.
