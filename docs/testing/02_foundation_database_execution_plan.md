# 02 - Foundation Database Execution Plan

**SELECTED FOR SQL DRAFT, 2026-09-23. Future test plan; nothing installed, connected, reset or executed against a database.**
Companions: [conceptual strategy](01_foundation_test_strategy.md), [physical review](../decisions/FOUNDATION_PHYSICAL_DESIGN_REVIEW.md), [execution security](../security/04_foundation_execution_security.md), [bootstrap](../database/07_foundation_bootstrap_plan.md), [dependency graph](../database/08_foundation_exact_dependency_graph.md).

## 1. Environment and tooling recommendation

Use a disposable local Supabase stack for full Auth/Data API/Storage behavior. A disposable PostgreSQL 15+ database may run relational/unit tests with explicitly modeled Auth inputs, but cannot alone prove managed JWT, gateway or Storage integration. Use the repository's later chosen migration runner, psql-style assertions/transactions, and a small multi-connection harness for race tests. pgTAP is an optional later choice, not a required extension or dependency selected now. Use the actual non-owner roles and gateway sessions described in execution security.

Each run records engine version, migration manifest/checksums, bootstrap manifest, role/grant inventory and test result artifacts outside production. Synthetic names/data only; no copied student/financial/medical records or credentials. Destructive reset is permitted only after the future runner proves the explicitly isolated environment. This plan authorizes no reset or deployment today.

## 2. Required clean-build workflow

1. Start empty isolated PostgreSQL/Supabase and verify isolation/project identity.
2. Apply reviewed migration files in exact dependency order with restricted privileges from the first object.
3. Assert 33 Foundation application tables, no deferred F28 relation, all expected constraints validated, and no operational domain tables.
4. Apply reviewed bootstrap twice; the second run must be a no-op for stable identities/customizations.
5. Run local/relational constraint tests.
6. Run actual anon/authenticated/non-owner RLS and function-execute tests.
7. Run protected command and evidence-transaction tests.
8. Run independent-session concurrency, revocation and idempotency tests.
9. Reset only the verified disposable environment, rebuild completely from zero and repeat all checks.
10. Compare both inventories and outcomes; unexplained nondeterminism or missing evidence blocks activation.

No successful service_role/postgres test substitutes for the real caller's denial/allow path. SQL files being syntactically valid is not acceptance of security behavior.

## 3. Required cases and expected results

| Group | Positive case | Negative/race case and required outcome |
|---|---|---|
| Keys and anchors | Single school, multiple campuses, adjacent/overlapping academic years, optional default year then validated same-school pointer | Second singleton; wrong campus/year parent; missing creator; invalid capacity/date; FK parent deletion all reject |
| Identity | INDIVIDUAL Teacher+Parent, separate FAMILY, multiple retired individual actors and one non-retired Person account | Duplicate live Auth UUID; SYSTEM binding; second non-retired principal; FAMILY staff assignment; forged kind all reject |
| Auth lifecycle | Bind/recover advances version/cutoff; deletion nulls live link and appends SYSTEM evidence; historical actor joins still work | Old signed iat, inactive/missing binding, Auth UUID reassignment to a different historical principal, partial provisioning deny; failed audit aborts managed unbind |
| Alias | ASCII trim/case normalization maps one authorized username to live binding; 3 and 32 character boundaries | Case duplicate, Unicode/confusable/space/control character, retired alias reuse, anonymous enumeration and oversized input reject with generic external failure |
| Composite grants | Matching role/permission/contract scope chain succeeds | Wrong role, permission, resolver version, NULL composite component; VIEW/ALL borrowed for UPDATE/ASSIGNED all reject |
| Intervals | Boundary-adjacent replacement after natural expiry; old revoked_at stays NULL; future cancellation produces empty interval | Two concurrent overlapping insertions yield one success and one conflict; exact boundary accepts; campus NULL comparison does not bypass; parent validity is intersected |
| Revocation | Allowed command obtains shared authorization lock and commits before waiting revocation | Reverse order denies command after fresh read; test operation disable, role/grant/scope revoke, principal suspension and Auth unbind; never use stale pre-lock snapshot |
| Privileges | Five allowed read tables expose permitted columns; checked projections filter sensitive fields | anon/private-table SELECT, direct INSERT/UPDATE/DELETE/TRUNCATE, public EXECUTE, worker role escalation, caller-supplied principal/claims and temp-schema shadow attack deny |
| RLS recursion | authz reader's role-specific input policies terminate, FORCE RLS remains on | No public policy accidentally includes executor role or owner membership; no recursive helper path or service-role proxy; test real gateway and database ownership separately |
| Workflow | Sequential stages, one effective decision; APPROVED remains separate from EXECUTED; no target change on approval | Self/same-Person/family-interest unknown proof, second reviewer race, cross-policy template, changed submitted payload/files and cancellation/application race reject or serialize |
| Application failure | Transient exception rolls back, request stays APPROVED; authorized retry succeeds | Stale target/lost required approver authority records INVALIDATED and immutable REJECTED receipt without business effect; no ambiguous FAILED request row |
| Receipts | Same principal/version/key/canonical payload returns same currently authorized terminal result | Different payload conflicts; concurrent same key serializes; crash before commit leaves no receipt/effect; crash after commit returns saved outcome; no ACCEPTED row is possible |
| Canonicalization | Equivalent object key order/default normalization gives equal digest; arrays/order/strings retain defined semantics | RFC 8785 vectors, invalid Unicode, unsafe/nonfinite numbers, version change, null-vs-omitted semantics, expected-version change and mismatched target IDs produce defined reject/different hash |
| Audit/history | Required actor/executor/context/reason/version/minimized references present; one effect + receipt + audit + outbox transaction | Audit write failure rolls everything back; normal UPDATE/DELETE/soft-delete/TRUNCATE, secret/oversized payload reject; infrastructure privileges explicitly outside tamper-proof claim |
| Outbox/inbox | Consumer dedupe creates one authorized principal-specific inbox row and marks delivery in the same commit | Duplicate/reordered event; stale/expired lease token; crash before/after commit; worker of wrong purpose; cross-principal inbox all fail safely |
| Files | 1 and 1,048,576 measured bytes accepted for allowed validated type; private reference, quarantine and replacement lineage work | Zero or 1,048,577 bytes; supplied false size/hash; immutable object key rewrite; cross-request evidence; public URL or orphan bytes do not grant access |
| Seeds/settings | Repeat bootstrap; new deployment definitions appended; existing customized role/settings/revoked grants preserved | Silent overwrite, reactivation of revoked grants, arbitrary executable code/secret setting or broad SYSTEM grant rejects |
| Offline contract | UUID/expected-version/idempotency fields support authorized replay | Lost scope/current family link, stale target or modified key payload denies; local cache role claims never authorize |
| Deferred boundaries | No active handler for absent domain/endpoint | No F28 SQL relation, no device/sync/finance/student tables, no hidden generic target mutation or external side effect inside a business transaction |

Advisory-lock hash collisions may serialize unrelated keys but must not confuse receipt identity: compare full principal/operation/key and digest after the lock. Managed Auth deletion can acquire managed-row locks before the application FK trigger; race it against relink and verify deadlock abort/retry, never partial actor/evidence loss.

## 4. Upgrade and recovery workflow

Build version N, apply its reviewed bootstrap, then load realistic synthetic historical fixtures: retired actors and binding snapshots, expired/unrevoked grants, revoked future assignments, prior academic years/default pointer, submitted/approved/executed/invalidated requests, terminal receipts, immutable audit/events, pending/dead deliveries, customized role grants/settings and file evidence links.

Apply N+1 migrations and updated bootstrap. Verify all historical keys/meaning, complete authorization chains, frozen intent/policies, unique receipts/applications, object references and school customizations. Existing role differences must remain intentional differences, not seed failures automatically overwritten. No cross-version canonicalization reinterpretation: replay a version-N receipt with its stored canonicalization/operation version.

Rehearse interrupted migration/resume, failed bootstrap, deadlock rollback, backup/restore into a fresh isolated environment, preserved managed Auth binding behavior, and version mismatch. Physical schema validation must finish before any activation. Use forward repair after production history; do not test destructive rollback as the normal business recovery strategy.

## 5. Acceptance and remaining operational work

The SQL draft can now target this selected test contract. Implementation is accepted only with clean-build, rebuild, upgrade, real caller RLS, command/race and evidence outcomes recorded. Deployment additionally needs actual project capability/grant verification, managed Auth integration, private Storage policies and any enabled worker environment. Those are execution/activation gates, not permission to connect during this review.
