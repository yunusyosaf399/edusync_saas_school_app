# Foundation managed throwaway preflight — M0 baseline and target safety gate

**Verdict: M0 PASS — READY FOR SEPARATE M1 AUTHORIZATION.** M0 inspected and linked a new disposable managed Supabase project. It did not apply migrations, create School OS objects or users, change hosted settings, or run M1 commands. The project and isolated linked worktree are retained for the separately authorized deployment gate.

## Source and isolation

- Date: 2026-09-25. Source HEAD: `8c7081c1bc62567102bb36d69d05228bb004fa8c`. Main worktree was clean before and after M0.
- Supabase CLI: `2.98.2`, unchanged. No CLI update was performed.
- Isolated worktree: `C:\Users\yunus\StudioProjects\saas_OS_school_app_m0_worktree`, created detached at the source HEAD. It was clean before linking. Its ignored `supabase/.temp/project-ref` contains the target ref; the main checkout has no `supabase/.temp/project-ref`.
- The isolated link completed with `supabase link --project-ref <verified ref>` using a temporary process environment for the database password. The linked ref was reread and matched the independently queried Management API project identity. No credential value was printed or added to a tracked file.

## Disposable target identity and readiness

| Observation | Empirical result |
|---|---|
| Project name | `schoolos-foundation-preflight-20260925-05bf6d` |
| Project ref | `qdbqefmpuacksyylodmj` |
| Organization | `Ilmora` (`jyssocxpozqlditlaogq`), Free plan; no billing or add-on change |
| Region | `ap-southeast-2` |
| Created | `2026-09-25T11:35:07.217224Z` |
| Identity check | Fresh create result and independent project GET agreed on name, ref, organization, and region; status `ACTIVE_HEALTHY` |
| Service health | Auth, REST, and database each reported `ACTIVE_HEALTHY` through the Management API |
| Hosted PostgreSQL | `17.6` from a read-only SQL session; project metadata reported `17.6.1.166` |
| API exposed schemas | `public, graphql_public`; neither `app` nor `app_private` exposed |

One other existing project was present in this organization and was not linked, queried for School OS data, changed, or used. The throwaway was created as the organization's second Free project without changing billing.

## Read-only database baseline

The direct database host was not reachable from this workstation. The supported regional **session pooler on port 5432** was reachable and used for the M0 catalog inspection; the transaction pooler was not used as evidence of session identity. PostgreSQL `psql` 17.6 ran inside the local disposable Docker tooling container as a client to the managed endpoint. Credentials were supplied through a temporary process environment and standard input, not command arguments. All inspection SQL ran in explicit `BEGIN READ ONLY` transactions.

| Check | Observed value |
|---|---|
| `current_database()` | `postgres` |
| `session_user` / `current_user` | `postgres` / `postgres` |
| Database owner | `postgres` |
| Database `CREATE` privilege for current user | `true` (catalog observation only; no CREATE attempted) |
| Relevant schema owners | `auth`: `supabase_admin`; `extensions`: `postgres`; `public`: `pg_database_owner`; `storage`: `supabase_admin` |
| `auth.users` | Exists; owner `supabase_auth_admin`; `users_pkey` is `PRIMARY KEY (id)` |
| `supabase_migrations.schema_migrations` | Absent; consequently no School OS migration versions |
| `schoolos_%` roles | 0 |
| School OS schemas | `app` absent; `app_private` absent |
| Auth users | 0 total |
| School OS Auth fixture emails | All six specified addresses absent |
| School OS relevant role memberships | 0; PostgreSQL 17 `admin_option`, `inherit_option`, and `set_option` inspected |

The six absent addresses were `foundation-test-001@example.invalid`, `foundation-rbac-001@example.invalid`, `foundation-family-001@example.invalid`, `foundation-own-001@example.invalid`, `foundation-own-002@example.invalid`, and `foundation-auth-delete-integration-001@example.invalid`. No Auth user was created.

After linking, a second read-only check still found zero School OS roles, zero School OS schemas, no migration-history table, and zero Auth users. The project remained `ACTIVE_HEALTHY`, and API exposed schemas remained `public,graphql_public`.

Platform role attributes observed (`true`/`false` in the order superuser, create-role, create-db, login, inherit, bypass-RLS):

| Role | Super | Create role | Create DB | Login | Inherit | Bypass RLS |
|---|---|---|---|---|---|---|
| `anon` | false | false | false | false | true | false |
| `authenticated` | false | false | false | false | true | false |
| `authenticator` | false | false | false | true | false | false |
| `postgres` | false | true | true | true | true | true |
| `service_role` | false | false | false | false | true | true |
| `supabase_admin` | true | true | true | true | true | true |
| `supabase_auth_admin` | false | true | false | true | false | false |

## Source artifact SHA-256 baseline

These hashes were captured from the clean source revision before any deployment. Names are relative to the directories named in each table.

`supabase/migrations/`:

| File | SHA-256 |
|---|---|
| `20260924122442_foundation_roles_schemas.sql` | `f8793604a4b8b0b25392540bf81dfe39e43941729998bb76a9dc8506e7dd0d1d` |
| `20260924122445_foundation_identity_school_files.sql` | `f846b41121d3e125be8de0a1f0e7fd6e48d2d812ad2330107a5ffca3ac229b5b` |
| `20260924122446_foundation_rbac_workflow.sql` | `f007e057f9a76f5697680de8ee709ee888ffae6aec600be3cf5eadcea0b50542` |
| `20260924122448_foundation_receipts_events_settings.sql` | `e72d773328a96bfc3b2c1ea04ccb3f6bffb9f409434a952fb94dbf6361bc84b7` |
| `20260924122450_foundation_late_fks_indexes.sql` | `40c43e7d978c64322c053598244bdbb5009087478a94cd491dee0449d4b60a13` |
| `20260924122451_foundation_structural_triggers.sql` | `d5612f73f07102cad4ef41b1642db04a2afc061271f6c2158aad73ff0fb4c4fb` |
| `20260924122453_foundation_authorization_rls.sql` | `f8f8d3dda44a1685c82561cf7825a87d1d662e0480c8b8adcb0714cb4919e056` |
| `20260924122455_foundation_privilege_lockdown.sql` | `330d583878ab6282f6a0b56e5665a25e87d3c6cae93b8dd0ded915b9fcaddff2` |
| `20260924183537_foundation_auth_helper_schema_usage.sql` | `3ecddebe953935724636dff14a2c15f27da86e804e2877a37396d85cebdf69c1` |

`supabase/tests/database/`:

| File | SHA-256 |
|---|---|
| `01_foundation_catalog.sql` | `5eb2b26c6a2e1cc3c2de46634e933ba355b7842eea3c1d2c5150dca3eaef6696` |
| `02_auth_helper_preflight.sql` | `89cf95b97c056778257595e68951ae59faf9101bd285e4870bbeb63f7242630c` |
| `03_file_objects.sql` | `8af39fccbae32d5c0a310e18a742613d9cf3d695582f88e69e03fbb0b8eb29e4` |
| `04_family_intervals.sql` | `7a1fdbd33e516e30228bfad3f11ed7b318e7834df1b28fbe8733cd5284926f13` |
| `05_approval_lifecycle.sql` | `cc6818e8c0c4b410a98f6a47bfa7852161ebf5aaaea8b4b8dd20fa075ce0e05c` |
| `06_evidence_delivery.sql` | `0f2a58e958a6fa37cd8c124538a74e2b48ddb50c971c6513be5cb75d4a54fbae` |
| `07_authorization_rbac.sql` | `125a50b842279590be511ce700a43daa9b97464178cc28392e889ef9dc8aca5b` |
| `08_family_own_scope.sql` | `7310070ef37b005d4b90ffa01d7f0fee995c63a45715563b8816c437a11fb5d8` |
| `09_auth_deletion_reconciliation.sql` | `22cdf44d6169ab8480cc845eb32f43c54ead9e09eaec48da364a987fd73eeb9a` |

| Document | SHA-256 |
|---|---|
| `docs/database/11_foundation_managed_throwaway_preflight.md` | `fcb90755e87e0a87e125a71e1d5b370d3901159a633c01ff916af928d27e1369` |
| `docs/database/12_foundation_managed_throwaway_independent_review.md` | `5f5abd1ffff195c72e374ee2f15b3d9df3e324d98e28906705f458d004ded484` |

## Phase boundary and limitation

No `supabase db push`, `supabase migration up`, remote SQL migration, dry run, migration repair, linked test, linked lint, pgTAP installation, Auth fixture, School OS schema/role/data creation, or API configuration change occurred. Nine Foundation migrations remain unapplied on the managed target. No secret was recorded in this review or committed to Git. The linked project's local CLI state remains only in the ignored isolated worktree.

The read-only `session_user = postgres` and `current_user = postgres` observations **do not prove** that `supabase db push --linked` will use the same effective identity. M1 must empirically establish migration authority, including `CREATE ROLE`, membership grants, `SET ROLE`, default privileges, schema authorization, and Auth foreign-key authority. M0 does not establish managed migration compatibility or production readiness.

**M0 PASS — M1 NOT STARTED.** The next task, only after separate authorization, is `FOUNDATION MANAGED SUPABASE THROWAWAY PREFLIGHT — M1 NINE-MIGRATION DEPLOYMENT GATE`.
