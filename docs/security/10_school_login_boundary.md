# Section 02 - school-local password login boundary

Status: source candidate, 1 November 2026. DB-013 implementation; not a hosted
login endpoint, executable migration, credential lifecycle implementation or
Section 02 release. Reuses the frozen Foundation binding and alias structures.

## Contract

The HTTP host constructs `SchoolLogin` with its deployment-owned school UUID,
dedicated worker database pool, trusted Auth project URL/public key, server-only
Auth admin credential for alias resolution, and persistent 32-byte-or-stronger
throttle secret. None of these comes from a login request. The source identifier
comes from a trusted ingress adapter, not a JSON field or an untrusted forwarded
header. The host returns one generic failure shape/status, applies no-store and
disables body/session logging. There is no HTTP framework/route or Flutter code
in this increment. Provider keys and passwords never enter school settings.

Email path: normalize -> charge source/identifier attempts -> supported Auth
password verification -> /user verification -> charge account attempts ->
resolve verified Auth subject to current school principal twice -> check token
cutoff and versions -> return only the session and principal context.

Username path: normalize -> charge source/identifier attempts -> private alias
and binding snapshot -> charge account attempts -> fetch the exact bound Auth
user using the server-only supported admin API -> supported password and /user
verification -> re-resolve original alias -> compare principal/binding/alias
versions, verified subject and token cutoff -> return session.

Unknown aliases take the password path using a reserved nonexistent mailbox,
then always deny; failures do not disclose which private lookup failed. This is
uniform error behavior, not a promise of constant network/password timing.
The trusted HTTP host must retain rate limits and generic responses. A valid
Supabase JWT may itself contain Auth-owned identity claims such as email; this
contract does not promise to remove claims from provider-issued tokens. There
is no unauthenticated alias-to-email lookup endpoint or separate email return.

Alias syntax follows the frozen table: lowercase ASCII letter followed by
2-31 ASCII letters/digits/dot/underscore/hyphen; normalize ASCII case and trim
outer ordinary spaces. Usernames are never recycled to another principal.
Emails use the supported Auth provider to prove identity; no application FK,
index, policy, trigger or grant is installed on managed Auth tables. Unknown
school, inactive school/person/principal, missing/unbound credential, retired
alias, changed binding/alias/principal version, wrong Auth subject, anonymous
Auth, pre-cutoff token, limit/backend failure all deny.

## Privileges and persistence

`supabase/proposals/section02_identity_login.sql.draft` is NOT in migrations and
is installed only by disposable CI. Trusted deployment creates NOLOGIN,
NOINHERIT, NOBYPASSRLS `schoolos_login_executor`. It owns two private functions
with a fixed search path and narrowly scoped grants/RLS inputs. It has no managed
Auth reads, business DML, grant-administration or workflow privileges.

Only the existing dedicated `schoolos_identity_login` can EXECUTE these
functions; both functions check the actual `session_user`. Authenticated, anon,
service_role and arbitrary SET ROLE/JWT-claim impersonation receive no entry.
The service worker is not granted executor membership or table access. The
PostgreSQL test authenticates as the real worker LOGIN with a synthetic in-memory
password; SET ROLE from postgres is not substituted for worker identity.

This is a preauthentication read/rate-meter boundary. It deliberately has no
client-provided actor, cannot assert that a human is authenticated, and does not
create a business receipt or mutate Person/roles/child entitlements. Existing
post-authentication commands still reauthorize every action; a login never
grants staff/family scope. Credential mutation workers must continue to follow
the existing SYSTEM purpose/trusted-intent/workflow contract separately.

Two private forced-RLS tables hold a deployment-owned policy and expiring
attempt counters. Installation does not seed a policy: absent policy denies.
Limits apply separately to source, normalized identifier and resolved account.
Keys are HMAC-SHA256 digests with a server-only secret, not passwords, emails,
IP addresses, tokens or direct UUIDs. Keep the secret stable across instances;
rotation must be coordinated with ingress limits so it cannot reset budgets
as an authentication bypass. This has no connection to deferred bank signing.

Counter updates use sorted conflict-lock order and commit independently of
password failure; a later failed password cannot roll back its attempts.
The fixed-window policy permits a boundary burst and is supplemented by Auth
and ingress limits. On requests, at most 100 expired buckets are cleaned using
SKIP LOCKED. Idle-school cleanup/retention scheduling is an activation concern;
attempt tables are not immutable business audit history. No unrestricted worker
table DML is granted to the login connection.

## Validation and limitations

The 24 unit tests cover both identifier paths, uniform error handling, redacted
representations, throttles, missing bindings, suspension/version changes during
Auth, stale tokens, subject mismatches, URL/redirect boundaries and remote token
verification before interpreting claims.

`section02-identity.yml` runs the frozen Foundation regressions, then resets an
isolated loopback school and runs real Auth/password and private PostgreSQL
tests. It injects a failed candidate install and verifies rollback, authenticates
as the worker, tests client privilege denial and concurrent rate admission.
Only CI source/fixtures run; no hosted school, production account, SMTP, owner
PC or external infrastructure is provisioned. Exact-head results belong in the
PR and Section 02 ledger, never inferred from unit tests alone.

The SQL remains draft until release packaging/upgrade/security acceptance.
Before hosted activation, report the need for a trusted HTTP host, worker pool
credentials, deployment-pinned project/school routing, server secret management,
ingress limits, TLS, recovery delivery and Auth settings. Do not provision or
choose those silently. The HTTP host must also avoid logging provider exceptions,
request bodies, tokens or returned session objects. No real-world connection or
secret is needed for current GitHub disposable tests.

DB-014 protected create/suspend/revoke/recover commands and saga/workflow
acceptance remain separate; fixture state updates are not those commands.
Other planned modules keep their own scope/approval/receipt acceptance gates.
