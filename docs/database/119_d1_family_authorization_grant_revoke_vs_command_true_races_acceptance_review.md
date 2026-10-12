# D1 Family authorization grant revocation versus protected command — two ordering races

Date: 2026-10-12
Verdict: **PASS — exact-source, disposable-local two-session PostgreSQL acceptance. Full Domain Package D1 remains OPEN.**

## Exact verified source and GitHub acceptance

- Previous frozen/documented `main`: `09f852d919a007ea76159bef750258718f977257` — **31 suites, 1,594/1,594 business assertions and 15/15 true observed-lock races**.
- [PR #40](https://github.com/yunusyosaf399/edusync_saas_school_app/pull/40) **MERGED** at `d75eb1503b8494630a72d97d0d7e4446ea12ad0a` from verified head `9820358914e60b16335866c45660cd027d4a9c8d`. Both successful workflows checked out identical PR test-merge commit `ec478743a7c683b9abfd71ee9eeaeb9f3a013266`, combining exactly this source and the previously accepted base.
- [D1 Migration 10 disposable local runtime #318](https://github.com/yunusyosaf399/edusync_saas_school_app/actions/runs/38276305918) **PASS** with `D1C2A_PASS`: unchanged **1,594/1,594** pgTAP business assertions across **31** suites; **220/220** post-D1 frozen Foundation SQL regressions; **47/47** D1 Python tooling unit tests; **17/17** actual observed-lock two-session races (**3** Employee creation, **3** Family Principal Membership, **7** Family Relationship, **2** inverse-order cross-Family operations, and **2 new** authorization SHARED/EXCLUSIVE lock-order races). Both error and warning SQL lint passed. The detailed log includes `D1_AUTHORIZATION_REVOKE_FIRST_RACE_PASS` and `D1_AUTHORIZATION_COMMAND_FIRST_RACE_PASS` following the existing fifteen accepted race markers.
- [Foundation local database stack #483](https://github.com/yunusyosaf399/edusync_saas_school_app/actions/runs/38276305971) **PASS**: **203/203** Python tooling unit tests; frozen **9 migrations and 9 SQL tests**, **220/220** pgTAP assertions; clean reset and both SQL lint levels.
- D1 harness assembled/applied **202 otherwise inactive Migration 10 `.sql.draft` fragments only in disposable local PostgreSQL**, validating **34/34** force-RLS relations, **540** functions (**522** SECURITY DEFINER), and no authenticated/anon/service-role private helper EXECUTE. **No** hosted Supabase, active SQL migration, released grant/RLS rule, application code or real school data changed.

## Frozen Foundation T04 ordering contract

[Foundation execution security](../security/04_foundation_execution_security.md) defines the one school-local, transaction-scoped advisory authorization key `(71001,1)`. Protected D1 commands acquire it **SHARED** before fresh verified/current actor, role permission/grant and assignment/scope checks; authority changes acquire **EXCLUSIVE** before changing grants. Higher transaction isolation is not assumed safe; authorization is refreshed under READ COMMITTED after waits, without a SHARED→EXCLUSIVE upgrade.

Two legal, deliberately different orderings:
- **EXCLUSIVE revocation first:** a later command waits for SHARED, then sees the revoked grant and denies with **zero domain mutation and zero successful receipt**.
- **SHARED command first:** a valid already-authorized command can finish its whole transaction; revocation cannot retroactively erase its result. The exclusive revocation waits, then takes effect for subsequent commands.

These cases exercise the existing frozen implementation. They **do not** implement or claim testing of a public security-administration grant revoke API.

## Two additional true two-session cases

**Local fixture:** `family_authority_revoke_race_setup.sql` creates **two new synthetic active Students**, each with one effective same-Family relationship and one independent effective Family-to-Student child entitlement. It reuses the already tested independent Family A/B verified Auth principals, current memberships, family-safe `OWN/D1_FAMILY_CHILD` summary, relationship and historical relationship read grants, and separate validated direct-route authenticated staff users. Verified `foundation-rbac-001@example.invalid` JWT claims are installed **before schema-owner fixture DML** in the transaction. All setup runs on disposable local PostgreSQL.

**Case 16 — grant REVOKE wins and protected command is denied:**
1. A **schema-owner-only synthetic authority revoker** starts a PostgreSQL transaction, explicitly obtains the exact school authorization **EXCLUSIVE advisory lock** `(71001,1)`, revokes only staff A's `family.child_access.change` role permission grant (retaining assignment/previous grant history) and holds the transaction open.
2. A separate verified authenticated **staff A** runs actual protected `app.d1_change_family_child_access(...,'REVOKE',...)` against the separate Family A child's valid current entitlement, using correct expected Student/Family versions. The runner must positively observe staff command's own backend **waiting on ShareLock**, with an ungranted `advisory` lock at exact `classid=71001,objid=1`, blocked by the revoker's **granted ExclusiveLock** on the same key via `pg_blocking_pids`.
3. When the revoker commits, the command re-evaluates authority and fails with **`D1 Family child access authority denied`**. No command receipt is created and Student row versions, Family A child's valid relationship/entitlement, Family B's independent data, and both authenticated Families' separate summary/current/history checked reads remain unchanged. Staff B's unrelated mutation grant remains effective. The success marker is `D1_AUTHORIZATION_REVOKE_FIRST_RACE_PASS`.

**Case 17 — protected command wins before grant REVOKE:**
1. Distinct genuine authenticated **staff B**, with independently valid `family.relationship.change` ALL/DIRECT grant, executes protected `app.d1_change_family_relationship(...,'END',...)` for the second Student's **last Family B relationship**, closing that exact current relationship and its dependent Family B child entitlement atomically. The original B command transaction deliberately stays open after the effect while holding **SHARED** school authorization lock.
2. A separate **synthetic schema-owner-only revoker** requests **EXCLUSIVE** `(71001,1)` to end staff B's live `family.relationship.change` grant. The runner requires the revoker backend's real ungranted advisory **ExclusiveLock**, positively blocked by the verified B command backend's matching granted **ShareLock**, using `pg_blocking_pids` and exact authorization-key classid/objid.
3. The B command succeeds and commits its one valid domain effect **before** the waiting revoker commits. Then the grant revocation completes. Both staff A and B targeted grants are now revoked as historical intervals. Family A's own child entitlement, relationship and three typed checked reads remain current and readable. Family B's three checked reads now deny due to its genuinely ended final relationship/child entitlement, **not** because revocation somehow retroactively rolled back the domain command.
4. Exact retained evidence: **two original relationship rows**, **two original child access interval rows** (Family A still effective, Family B ended today); **one successful B END receipt**, **zero** A denied-command receipt, **one new `family.relationship_changed` outbox event**, **zero new explicit `family.child_access_changed` event** (implicit dependent closure cannot impersonate a separate child REVOKE). The success marker is `D1_AUTHORIZATION_COMMAND_FIRST_RACE_PASS`.

The revoker is an intentionally privileged **synthetic schema-owner test session** with the frozen exclusive lock, **not** an authorized user-accessible permission administration workflow. The two actual Family change commands are executed only under verified staff JWT roles through existing `app` RPCs; FAMILY portals are also checked under their actual independent Auth principals. Lock contention is confirmed with specific PostgreSQL backend identity, advisory lock type, lock mode, `pg_blocking_pids` and exact Foundation key, **not** timing assumptions.

## Bounded changes, frozen checkpoint and remaining work

Exactly **four test-only** files:
1. `supabase/tests/domain/fixtures/family_authority_revoke_race_setup.sql` — two isolated Students and initial Family-specific relationship/entitlement facts;
2. `tools/supabase/domain_authorization_revocation_race_ci.py` — two true two-session race schedules, exact-key lock probes, domain/read/receipt/event checks;
3. `tools/supabase/domain_concurrency_ci.py` — append the two tests **after** the fifteen previously accepted observed-lock races;
4. `tools/supabase/tests/test_domain_acceptance_ci.py` — one Python test guard for correct JWT fixture, exact advisory key and both lock-order outcomes.

No accepted 31-suite business test, manifest, D1 SQL draft, Foundation migration, production grant administration command, Flutter/API, external Auth fixture, hosted resource or school data changed.

**Accepted/frozen:** **31 suites, 1,594/1,594 D1 business assertions; 17/17 true observed-lock PostgreSQL concurrency races**, **47/47 D1 Python unit tests, 203/203 Foundation Python unit tests and 220/220 Foundation SQL assertions** in disposable local CI. **Full D1 remains OPEN** for non-synthetic authorized security-administration workflows, other grant/scope and user-binding revocation permutations, time boundaries, remaining D1 operations, populated schema upgrade/reconciliation, Admissions/Finance, and hosted Migration 10 activation. All **202** Migration 10 fragments remain inactive `.sql.draft`.

**Checkpoint:** `D1_AUTH_GRANT_REVOKE_VS_COMMAND_BOTH_ORDERS_PASS — 1594/1594 BUSINESS — 17/17 OBSERVED-LOCK RACES — 220/220 FOUNDATION — 47/47 D1 UNIT — 202 DRAFT FRAGMENTS — FULL D1 OPEN`.
