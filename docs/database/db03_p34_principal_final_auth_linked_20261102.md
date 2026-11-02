# DB03 P34 — Auth-linked Principal-final authority acceptance

**2 November 2026. Status: disposable database acceptance, no activation.** Branch is based on DB03 #203 merge `152e5322929ef62b4fab1b913f999fa7c33e2f37`. P33 returned a functional server-owned RETURN/REJECT command candidate but did not grant it to application users. P34 tests the dedicated authority chain with an **existing actual Supabase Auth user** rather than merely inspecting SQL source and grants.

## What the test proves

The 17-assertion, rollback-only pgTAP test imports the repository's existing `policy_publication_actor` and `intake_grace_actor` fixtures. This binds a synthetic Principal and school/Campus to an **actual local `auth.users` row** created by the disposable foundation setup. Only inside the test transaction, P34 registers and enables `admission.final.decide` with a separate permission, a current role/grant/scope chain and the exact server-side Principal authority source. No existing document-review or admissions-draft permission suffices for final decisions.

With database JWT claims modeled as a PostgreSQL request context, the test verifies that the correct Auth-linked individual, Principal role and Campus yield a nonnull authority digest, while a missing operation, invalid Campus or unknown person yields none. It independently tests denial following retirement of the Principal role, revocation of role assignment, grant or scope, disabling of the operation, and future-dating of Auth binding. Each mutation uses a SAVEPOINT and is rolled back before the next check. The authorized digest reappears after the rollback sequence.

It also verifies that the positive *authority* test cannot invoke the client-facing RPC through the authenticated or service role, nor produce any Principal decision, command receipt or outbox item. The SQL finishes with `ROLLBACK`; no test operation, permission, person, Auth binding or School survives the fixture.

The existing DB03 CI source validator embeds both fixtures exactly once and requires 17 assertions, the expected SAVEPOINT checks, and transaction rollback. The disposable schema runner executes this after installing the P33 candidate, while keeping all earlier P1–P33 and D1 validation intact.

## What P34 does **not** prove

The request claims in pgTAP are **simulated database GUCs**, not an externally verified signed GoTrue JWT. This test is Auth-**linked**, not a genuine login/HTTP round-trip. No real positive RETURN or REJECT effect is exercised; those commands remain unavailable to authenticated clients. No competing transaction locks, stale token from a separate session, same-key replay after an accepted decision, or fail-after-write rollback is proven. Those require a distinct signed Auth and cross-connection runtime test harness.

Do not describe P34 passing as admission-finalization readiness, or merge to `main` / deploy from it. The separate operation permission is test-only and no hosted or live school user receives it. The P33 protected write path remains **inactive** until genuine signed-Auth positive RETURN/REJECT, revocation-after-lock and concurrency tests pass.

**Next task:** implement signed GoTrue local login and protected-Principal decision race acceptance with two database sessions, a real current Forward and original document checks. Keep APPROVE, Student creation and DB01/DB02 roll handoff blocked pending the independently reviewed atomic D1 integration.
