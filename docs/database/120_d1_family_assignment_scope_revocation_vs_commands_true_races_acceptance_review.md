# D1 Family assignment-scope revocation versus protected commands — both true concurrency orders

Date: 2026-10-12
Verdict: **PASS — exact-source, disposable-local PostgreSQL two-session acceptance. Full Domain Package D1 remains OPEN.**

## Exact accepted source and CI evidence

- Prior frozen and documented `main`: `beebaf0c9e77d97f2bcf3f81f346695823c2170c` — **31 business suites, 1,594/1,594 pgTAP assertions and 17/17 observed-lock races**.
- [PR #41](https://github.com/yunusyosaf399/edusync_saas_school_app/pull/41) **MERGED** at `1a5a1a34cecb611de529423601ee6b1c68c1be5d` from exact verified head `f873ef2c59812c0cc5d4f073c0b104ed8c8cb59e`. Both successful workflows checked out the same PR test-merge ref `180f8fda0fe08737b51ea2c5e25e8a9a21343cdf`, combining this exact head with the previously frozen base.
- [D1 Migration 10 disposable-local runtime #324](https://github.com/yunusyosaf399/edusync_saas_school_app/actions/runs/38281877195) **PASS**: `D1C2A_PASS`, unchanged **1,594/1,594** business pgTAP assertions across **31** suites; **220/220** post-D1 Foundation SQL regressions; **48/48** D1 Python tooling tests; both error and warning SQL lint; and expanded **19/19** real two-session, observed-lock PostgreSQL races: **3** Employee creation, **3** Family Principal Membership, **7** Family Relationship, **2** inverse-order cross-Family relationship/entitlement races, **2** authority role-grant revocation races, and **2 new** assignment-scope revocation races. The passing log includes `D1_ASSIGNMENT_SCOPE_REVOKE_FIRST_RACE_PASS` and `D1_ASSIGNMENT_SCOPE_COMMAND_FIRST_RACE_PASS` after the prior seventeen race cases.
- [Foundation database local stack #488](https://github.com/yunusyosaf399/edusync_saas_school_app/actions/runs/38281877220) **PASS**: **204/204** Python tooling tests; nine frozen migrations and nine frozen SQL test files; **220/220** Foundation SQL assertions; 5/5 local Auth fixtures, clean local reset and both SQL lint levels.
- D1 disposable CI assembled/applied **202 otherwise inactive Migration 10 `.sql.draft` fragments only in local PostgreSQL**, checking **34/34** forced-RLS domain relations, **540** D1 functions (**522** SECURITY DEFINER), zero authenticated/anonymous/service-role private-helper EXECUTE, and no production/hosted migration activation. No real school data or hosted Supabase resources were accessed or modified.

## Frozen T04 contract and distinct risk

[Foundation execution security](../security/04_foundation_execution_security.md) defines the exact shared authorization-lock key `(71001,1)`: sensitive D1 mutation commands acquire the transaction-scoped key **SHARED**, and any grant or **assignment-scope authority change** requires **EXCLUSIVE** before its mutation, without upgrading a held SHARED lock. After any wait, the domain executor refreshes the current actor, current role grant and *complete exact scope chain* at READ COMMITTED. A valid permission/grant and principal-role assignment **cannot substitute** for a currently effective matching `assignment_permission_scopes` row.

PR #40 already proved both orders for revoking the **staff role-permission grant**. This suite separately revokes **only the staff assignment-to-grant scope row**, and positively checks that both matching staff role-permission grants **and** both actual staff principal-role assignments remain active before and after the races. Thus a denied command is attributable to missing target scope rather than to loss of a role grant or actor assignment.

## Synthetic fixture with genuine authenticated protected commands

The new `family_assignment_scope_revoke_race_setup.sql` fixture runs inside the disposable local PostgreSQL stack **after all seventeen accepted races** and explicitly restores the verified `foundation-rbac-001@example.invalid` JWT subject, authenticated role, and bound `iat` before schema-owner synthetic inserts. It seeds two **fresh** separate active Students (`990...`, `9a0...`), each with one effective Family A/B relationship and one distinct current Family-child entitlement. Both genuine independent FAMILY Auth principals continue to have their valid separate memberships and family-only/family-safe `OWN/D1_FAMILY_CHILD` summary, current relationship and historical relationship read chains.

The prior accepted grant-revocation races have closed their staff role grants. To avoid a false denial, the fixture verifies that earlier historical state, then provisions **two fresh, valid, catalog-matched, currently effective staff role-permission grants** and two independent `ALL/DIRECT` `assignment_permission_scopes` rows attached to their existing staff principal-role assignments. Their distinct grant IDs and scope intervals respect the frozen Foundation nonoverlap constraint; the current D1 Effect30/Effect32 DIRECT policy routes remain unchanged. Initial relationship and access facts are explicitly **owner-created disposable fixtures**, not falsely counted as genuine public ADD commands.

The two actual tested mutations use **different real JWT-authenticated INDIVIDUAL staff principals** and existing public protected `app` RPCs: staff A calls `app.d1_change_family_child_access(...,'REVOKE',...)` for Family A, and staff B calls `app.d1_change_family_relationship(...,'END',...)` for Family B. Real independently authenticated FAMILY logins use the allowlisted summary/current-relationship/history checked-read functions. Privileged scope revocation is **schema-owner-only synthetic test DML**, performed under the exact EXCLUSIVE authorization key; this is not a claim that a public security-administration API has been implemented.

## Two additional true PostgreSQL two-session cases

**Case 18 — EXCLUSIVE scope revocation commits first:**
1. An owner-only synthetic revoker explicitly locks `pg_advisory_xact_lock(71001,1)`, changes **only staff A's** live `assignment_permission_scopes.revoked_at` and holds its transaction open. The matching staff A grant and principal-role assignment remain effective.
2. A different verified authenticated staff A connection starts a protected Family A child-entitlement `REVOKE` with correct Student/Family optimistic versions. It cannot acquire the required SHARED lock until the revoker commits. The observer requires `pg_blocking_pids` evidence tied to the exact PostgreSQL backend names, an ungranted advisory **ShareLock** at `classid=71001,objid=1`, and the holder's granted **ExclusiveLock** at that same key; sleeping alone is not accepted as proof.
3. After revocation commits, the protected command rechecks scope authority and fails with exactly `D1 Family child access authority denied`, leaving **zero** successful receipt, zero entitlement mutation, and unchanged Student versions/history. Independent Family A/B checked reads continue with their prior permissions. Both fresh staff role grants and both staff principal-role assignments are still current. Marker: `D1_ASSIGNMENT_SCOPE_REVOKE_FIRST_RACE_PASS`.

**Case 19 — SHARED protected command commits before EXCLUSIVE scope revocation:**
1. Independently authenticated staff B starts a genuine protected `app.d1_change_family_relationship(...,'END',...)` command on Family B's *last current* relationship, holding its transaction open after the accepted effect while it still has an effective `ALL/DIRECT` scope and the Foundation SHARED lock.
2. A separate owner-only scope revoker requests EXCLUSIVE `(71001,1)` for **only staff B's** independent assignment scope. The runner requires positive `pg_blocking_pids` evidence for the waiting **ExclusiveLock** on the exact key and the B command's granted **ShareLock**.
3. The authorized relationship END **commits first**, preserving one successful domain command receipt and one new `family.relationship_changed` event. Only then does the waiting scope revocation commit. Family B's final relationship and its dependent child entitlement end in one protected change; the implicit dependent closure creates **no forged explicit** `family.child_access_changed` event. Family A's independent relationship/entitlement and all three checked-read surfaces remain current; Family B's checked reads deny because its relationship/entitlement ended, not because of unrelated Family membership or staff authority leakage.
4. Final immutable evidence: both targeted assignment scopes are retained **revoked**, both new staff role grants and both staff principal-role assignments are still **active**, the two original Family relationships and two original child-entitlement rows are retained (Family A current, Family B effective interval ended), **one** successful B END receipt, **zero** denied A command receipts, exactly **one new relationship event** and **no new explicit child-access event**. Marker: `D1_ASSIGNMENT_SCOPE_COMMAND_FIRST_RACE_PASS`.

Both cases use the previously accepted exact-key advisory-lock observation helper and two real PostgreSQL sessions. They prove both legal commit orderings, not an arbitrary delay, a shared actor lock, a broad revoked role grant, or a generic advisory resource.

## Source boundary, acceptance and remaining work

Exactly four **test-only** paths changed:
1. `supabase/tests/domain/fixtures/family_assignment_scope_revoke_race_setup.sql` — separate Students and live staff grant/scope chains, with verified fixture actor;
2. `tools/supabase/domain_assignment_scope_revocation_race_ci.py` — two actual two-session scope-change/command races, exact lock observation, authenticated protected commands and FAMILY checked-read/receipt/history/event checks;
3. `tools/supabase/domain_concurrency_ci.py` — append two scope races **after** the accepted seventeen races;
4. `tools/supabase/tests/test_domain_acceptance_ci.py` — one static fixture, lock, actor and scope-preservation guard.

The 31 already accepted business suites and manifest are unchanged. No Foundation migration/SQL test, D1 implementation or `.sql.draft`, deployed RLS/grants, Flutter/API, real Auth fixture inventory, hosted Supabase resource or school data changed.

**Accepted/frozen:** **31 suites, 1,594/1,594 D1 business assertions, 19/19 genuinely observed-lock two-session races, 48/48 D1 Python unit tests, 204/204 Foundation Python tests and 220/220 Foundation SQL assertions**, on disposable local CI only. **Full D1 remains OPEN** for genuine security-administration API tests, more permission/assignment/identity revoke interleavings, further domain operations, populated upgrade/reconciliation, Admissions/Finance, and hosted Migration 10 activation. All **202** Migration 10 fragments remain inactive `.sql.draft`.

**Checkpoint:** `D1_ASSIGNMENT_SCOPE_REVOKE_VS_COMMAND_BOTH_ORDERS_PASS — 1594/1594 BUSINESS — 19/19 OBSERVED-LOCK RACES — 220/220 FOUNDATION — 48/48 D1 UNIT — 202 DRAFT FRAGMENTS — FULL D1 OPEN`.
