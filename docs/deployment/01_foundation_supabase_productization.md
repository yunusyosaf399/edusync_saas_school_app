# Foundation Supabase deployment productization

The frozen Foundation database baseline has passed local reset and managed throwaway validation; see [M5 closure](../database/23_foundation_managed_throwaway_m5_final_review.md). This P0 design turns that evidence into reusable source, local validation and hosted configuration contracts. It does not create a managed project or authorize deployment. **One customer school remains one Supabase project**; no operational school data is centralized.

## Deployment contract and source gate

[`foundation_managed_contract.json`](../../supabase/config/foundation_managed_contract.json) pins CLI 2.98.2, minimum PostgreSQL major 15, the reviewed 17.6 version as evidence, the nine frozen migration files and nine test files with Git blob IDs and SHA-256, expected catalog/TAP counts, Data API schemas, and the session-pooler connection class. It contains no target identifier or secret. Later migrations are outside the frozen baseline. The guard reports them as `FUTURE_MIGRATIONS_PRESENT`; strict mode fails until a separate migration sequence is reviewed. `--future report` permits inventory without blessing those files as Foundation.

`python tools/supabase/foundation_guard.py` verifies the frozen hashes against both HEAD Git blobs and filesystem content, reports CRLF materialization, checks `.gitattributes`, and checks local `supabase/config.toml` for exactly `public,graphql_public,app` without `app_private`. Windows may materialize three already documented migration copies as CRLF; canonical Git content remains LF. Linux CI uses `--require-lf` and rejects any CRLF working file. Hash mismatch, missing file, unexpected migration in strict mode, or local API drift fails closed.

## Local validation and CI

`python tools/supabase/foundation_local_ci.py` runs the static gate, verifies CLI 2.98.2 and Docker Linux, starts the local stack if needed, resets **local only** with `--no-seed`, creates five synthetic local Auth users through the local Auth Admin API, runs error/warning lint, then runs test files 01–09 one process at a time. It checks each TAP plan and `ok` count against 44, 6, 16, 16, 25, 16, 33, 41, and 23; total must be 220/220. It ends with local status and stops the stack only if it started it. A reset intentionally clears existing local data; run this on a disposable local database.

If a reset recreates Auth while an existing local Kong gateway still points at the old container address, the driver tests local Auth health, restarts **only this local project's** gateway once, and waits briefly for it to become healthy. It then fails closed if the route remains unavailable. This changes no database schema or hosted service.

The fixture tool accepts only HTTP loopback on the reviewed local port 54321. It obtains the service-role key from `supabase status -o json` in process memory, refuses redirects and pre-existing Auth users after reset, creates only five `.example.invalid` users using Python `secrets`, then independently verifies exact email/UUID membership. It does not create the M4 deletion user or persist passwords/keys. The GitHub workflow runs Python unit tests, the strict LF guard and the full driver on a Linux runner with a local Docker stack. It requires no hosted project ref or repository secret.

## Managed configuration and deployment order

`foundation_managed_config.py` implements `check` (default) and explicit `apply`. It reads the Management token only from the process environment, fetches the exact project identity and PostgREST configuration, and compares exposed schemas with the contract. `app_private` in the live exposure list always fails. Apply requires `apply --apply --project-ref X --confirm-project-ref X`; optional exact name and organization checks narrow the target further. It refuses extra exposed schemas, patches only `db_schema`, rereads it and requires the exact final set. It does not alter database grants. P0 unit tests inject fake HTTP responses; no live call is made.

`foundation_deploy.py plan` lists the required sequence: source integrity, identity, health, session-pooler route, clean baseline, dry-run, exact pending list, separately authorized push, history, security smoke, Data API check/apply, drift and final health. Its `apply` command always exits `REMOTE_APPLY_NOT_AUTHORIZED_IN_P0`. Future migration operations must use TLS Supavisor **session** pooler port 5432, explicit passwordless `--db-url`, and temporary `PGPASSWORD`. Linked/direct host selection and transaction port 6543 are not the reviewed default. No password belongs in command arguments.

## Secrets and target safety

| Category | Allowed location/lifetime | Forbidden location |
| --- | --- | --- |
| Supabase Management token | Restricted operator process environment for a specific authorized operation | Repository, logs, Flutter, local CI |
| School-project DB password | Secret manager; temporary process `PGPASSWORD` for an authorized deployment | URI arguments, repository, logs, Flutter |
| Public client API key | Intended public client configuration after project routing | Treating it as authorization or embedding another school's key |
| Server service/admin key | Server secret manager; local CI obtains only its disposable local key in memory | Flutter, repository, CI outputs |
| Synthetic Auth passwords | Generated for one local/disposable test and held in memory | Files, logs, real users |
| Future worker credentials | Deferred dedicated server secret provision/rotation gate | Flutter, P0 tooling, repository |

Never log JWTs, refresh tokens, Authorization headers, passwords, Management tokens, service keys, or credential-bearing URIs. Tool errors report operation/status class and suppress response bodies. Project refs, migration versions, schema/role names and safe HTTP statuses can be logged. A future remote executor must compare exact project ref, name, organization and region against independent sources before mutation. Productization operates on one explicitly identified school project at a time.

## Drift and failure model

Fast deployment smoke checks are frozen source hashes, expected migration history, exact API exposure, 12 roles, both application schemas, 33 ENABLE/33 FORCE RLS, the Auth FK and final helper owner. A deeper scheduled audit should repeat the M2 privilege/policy/function inventory and targeted M3/M4 security paths when changes justify it. Future migrations need an explicit extension contract rather than silent inclusion in the nine-file baseline.

Any mismatch stops the deployment and reports evidence. The tools must not automatically repair migration history, reset a hosted database, recreate schema, widen privilege or disable RLS. Project deletion is a separate destructive procedure, never a normal deployment step. Worker LOGIN password provisioning, authentication, CONNECT behavior and pooler routing for `schoolos_event_login`, `schoolos_identity_login` and `schoolos_file_login` remain a separate activation gate.

## Automation boundaries and progression

| Step | Boundary |
| --- | --- |
| Frozen source and local configuration checks | Fully automated |
| Disposable local reset, fixtures, lint and serial tests | Automated only on an explicitly local stack |
| Hosted identity, health, dry-run and pending-list checks | Automatically checked in a later authorized rehearsal |
| Real hosted migration push and API config apply | Separate manual authorization followed by guarded execution |
| Hosted project deletion | Separate, exact-target destructive confirmation |
| Worker activation, staging and production rollout | Deferred |

P1 should create a **new disposable managed project** under separate authorization, test the guarded contract/config checks end to end, and record failure cleanup. Only after that rehearsal should staging workflow, secret rotation, CI/drift gates, backup/recovery and production rollout be designed and approved. No P1 or production action is part of P0.
