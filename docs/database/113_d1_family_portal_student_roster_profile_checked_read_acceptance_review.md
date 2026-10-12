# D1 Family portal — enrolled Student ROSTER and PROFILE checked-read isolation

Date: 2026-10-12
Verdict: **PASS — exact-source disposable local PostgreSQL business acceptance; full Domain Package D1 remains OPEN.**

## Exact accepted source and workflow evidence

- Previously accepted and documented `main`: `c5bc7679a9d24b32e12ac2a06ccc9db77cf8e030`.
- [PR #34](https://github.com/yunusyosaf399/edusync_saas_school_app/pull/34) **MERGED** at `b0035f8db074e8525b15cc5ca288d2e23199c2ea` from exact accepted branch head `a3da92bdb92950a28eb939a87b978cd9f8601600`.
- Both passing GitHub workflow jobs checked out PR merge ref `a6f5fdcc24a1f12a9e81f727c4cc90db57186ebe`, which merged that exact source head into the exact prior frozen `main`.
- [D1 Migration 10 disposable runtime #268](https://github.com/yunusyosaf399/edusync_saas_school_app/actions/runs/38202422644) **PASS**, including `D1C2A_PASS`, **1,358/1,358** business pgTAP assertions over **28** suites and the new `28_family_portal_student_roster_profile_disclosure.sql` **67/67**. The same job passed **41/41** D1 Python tooling tests, **220/220** post-D1 Foundation SQL regressions, error/warning SQL lint, and unchanged **13/13** genuine lock-observed two-session races (3 Employee creation, 3 Family Principal Membership, 7 Family Relationship).
- [Foundation local stack #445](https://github.com/yunusyosaf399/edusync_saas_school_app/actions/runs/38202422621) **PASS**: frozen nine Foundation migrations and nine SQL test files, **197/197** tooling unit tests, clean local reset, error/warning lint and **220/220** SQL assertions.
- The D1 runtime assembled/applied **202 inactive `.sql.draft` Migration 10 fragments only on disposable local PostgreSQL**. Catalog: **34/34** forced-RLS D1 relations, **540** SQL functions (**522** SECURITY DEFINER), zero authenticated/anon/service_role access to private helpers. No hosted Supabase activation or school data changed.

## Frozen security contract and scenario

The existing protected typed functions `app.d1_read_student_roster(uuid)` and `app.d1_read_student_profile(uuid)` have **separate current permissions**: `student.roster.view` and `student.profile.view`. Neither permission implies the other. The fixed ROSTER read discloses **six allowlisted fields** (Student ID, display name, school Student ID, current Section, current roll, photo reference); the PROFILE read discloses **eleven allowlisted fields** (ROSTER plus birth date, gender, nationality, general contact and previous school), but never Restricted Identity, guardian contact or Student Special fields. FAMILY access is further gated by the separate family-safe `OWN/D1_FAMILY_CHILD` live permission/assignment, authentic current FAMILY Principal/membership, effective GUARDIAN relationship basis and effective Student-specific child entitlement. ROSTER/PROFILE also require exactly one current effective PRIMARY placement and valid class/section and roll evidence. Student B's enrollment at another campus grants no access to Student A's FAMILY Principal.

The 67-assertion rollback-only suite:
1. Creates two real, current PRIMARY placements for separate Student A and Student B with two campus Section/Class offerings, an academic year, retained capacity revisions, persistent school roll policy/allocator and genuine roll allocations (Student A roll 10000). The Student A fixture's approved PROFILE sample values are configured **at initial Student INSERT**, not by an intermediate version-changing UPDATE. A real staff child-access ADD grants a separate effective Student A Family entitlement with valid membership/relationship basis. There is no Student B Family entitlement.
2. As a real JWT-authenticated FAMILY Principal with valid `family.summary.view`, confirms linked Student A Family summary works, but both Student ROSTER and PROFILE return **zero** rows before the separate Student grants exist.
3. Adds only a family-safe `student.roster.view` role grant and a correctly matched **OWN/D1_FAMILY_CHILD** scope. The authenticated FAMILY account can read Student A's exact active Section/school ID/roll, but not equally enrolled Student B or a NULL Student target; it gets a six-key typed projection with no DOB, general contact, private identity or special fields. PROFILE and protected Restricted Identity/Special read functions remain denied.
4. Independently adds `student.profile.view` with its own family-safe role grant and OWN scope, without widening ROSTER or private table SELECT. Student A's PROFILE now returns only the reviewed eleven-field class, including the fixture birth date, non-guardian general contact and previous school. Student B, NULL, Restricted Identity and Special remain denied. The projection never gains national ID, birth certificate number, private address, guardian contact, disability/orphan indicator or blood group.
5. In separate savepoints, revokes the live PROFILE grant and proves PROFILE disappears **without disabling ROSTER**, restores it, then revokes live ROSTER and proves ROSTER disappears **without disabling PROFILE**. This demonstrates independent current-grant checks, not cached permission inference.
6. A different authorized staff actor performs an actual `app.d1_change_family_child_access` **REVOKE**, closing Student A's child entitlement on the current business date with exclusive end. Even though both read permissions, Family Principal membership, GUARDIAN basis and real PRIMARY placement persist, the authenticated FAMILY account immediately loses ROSTER, PROFILE and Family summary reads. Student B stays invisible and direct raw `app_private.students` SELECT is denied. Exactly one genuine child-access ADD and one REVOKE succeed with two receipts/events, retaining a single closed entitlement row rather than deleting it.

The test uses **BEGIN/ROLLBACK** and existing protected `app` RPCs under `SET ROLE authenticated`. Private fixture table SQL and evidence validation occur only under owner/test roles; no client raw Student SELECT permissions or RLS/grants were broadened.

## Source boundary, accepted checkpoint, and remaining work

Exactly three acceptance-only files changed:
- `supabase/tests/domain/28_family_portal_student_roster_profile_disclosure.sql` — new **67/67** rollback-only assertions;
- `tools/supabase/domain_business_ci.py` — explicit 28th suite registration;
- `tools/supabase/tests/test_domain_acceptance_ci.py` — one new Python static fixture/permission/read guard.

**No frozen Foundation migration/test, D1 draft/production SQL, installed permission/grant/RLS, Flutter UI/API or hosted Supabase resource was modified.** The **28-suite, 1,358-assertion D1C2A local business checkpoint is accepted and frozen**, with previously accepted **13/13** lock-observed races unchanged.

**Still OPEN:** additional Family emergency-contact, historical-read, current/alternative-basis, disclosure and inter-Family isolation combinations; concurrency/authorization matrix; populated migration upgrade; broader D1 business operations, Admissions/Finance and hosted Migration 10 activation. All **202** Migration 10 fragments remain non-executable `.sql.draft`.

**Marker:** `D1_FAMILY_STUDENT_ROSTER_PROFILE_READ_PASS — 1358/1358 BUSINESS — 220/220 FOUNDATION — 41/41 D1 UNIT — 13/13 OBSERVED-LOCK RACES — 202 DRAFT FRAGMENTS — FULL D1 OPEN`.
