# Foundation managed Supabase preflight — M5 final evidence and closure

## Final verdict

**FOUNDATION MANAGED SUPABASE PREFLIGHT PASS — THROWAWAY DESTROYED — FOUNDATION DATABASE VALIDATED.** The frozen nine-migration Foundation deployed to a disposable managed Supabase project, passed catalog/security and real hosted Auth/JWT/runtime checks, and its real Auth deletion reconciliation passed. M5 confirmed continuity of the deployed state before deleting that exact project. Direct lookup then returned HTTP 404, its ref disappeared from the project list, and the organization's other project remained listed. This validates the Foundation database architecture and managed-Supabase compatibility; it does not establish readiness of the whole SaaS product for production.

## Source and tooling identity

- Starting main HEAD: `679504f17105cfbd4663c13c0bf704b75a565311`; initial worktree clean. Supabase CLI: `2.98.2`, unchanged. Hosted PostgreSQL: `17.6`.
- `.gitattributes` retains the reviewed LF policy for itself, `supabase/migrations/*.sql`, and `supabase/tests/database/*.sql`. All nine migration and nine database-test Git blob IDs and canonical SHA-256 hashes matched [review 15](15_foundation_managed_source_integrity_review.md): **18/18**. Their current filesystem bytes normalized from CRLF to LF equal the Git blobs. The three previously documented Windows CRLF working-file copies do not alter canonical source content. No migration, frozen test, or migration history was changed in M5.
- The reviewed Foundation baseline is migration versions `20260924122442`, `20260924122445`, `20260924122446`, `20260924122448`, `20260924122450`, `20260924122451`, `20260924122453`, `20260924122455`, and `20260924183537`. The M5 live catalog returned these nine once each, with no migration 10.

## Disposable target identity

| Field | Verified value |
| --- | --- |
| Name | `schoolos-foundation-preflight-pooler-m1-20260925-5fdddb` |
| Ref | `lndjtslixvugswnnctam` |
| Organization | Ilmora (`jyssocxpozqlditlaogq`) |
| Region | `ap-northeast-2` |
| Created | `2026-09-25T13:52:50.448327Z` |
| Before deletion | `ACTIVE_HEALTHY` |

The Management project-detail response, independent project list, and organization lookup agreed on the exact ref, name, organization ID/name, and region at the initial M5 gate and again immediately before deletion. The list showed one separate organization project before deletion. Its identifier and metadata matched after deletion; it was not modified. This target is the same one recorded in [M1](19_foundation_managed_throwaway_m1_session_pooler_review.md), [M2](20_foundation_managed_throwaway_m2_security_review.md), [M3](21_foundation_managed_throwaway_m3_auth_jwt_rbac_review.md), and [M4](22_foundation_managed_throwaway_m4_auth_deletion_review.md).

## M0–M4 validated evidence summary

- **M0:** The new target was healthy and had expected platform/Auth ownership and `auth.users(id)` primary key, with no School OS roles, schemas, migrations, or test users. The `app` and `app_private` schemas were not exposed. See [M1 baseline](19_foundation_managed_throwaway_m1_session_pooler_review.md).
- **M1:** Canonical source was deployed through an explicit TLS Supavisor **session** pooler URI on port 5432. The dry-run listed exactly nine pending versions in order; exactly one real `db push` applied all nine. Managed PostgreSQL accepted 12 School OS role creations, the explicit memberships, `SET ROLE`, global default privileges, schema ownership/authorization, the `auth.users` FK, and migration 9's request-GUC identity helper. The project remained healthy. See [review 19](19_foundation_managed_throwaway_m1_session_pooler_review.md).
- **M2:** The hosted catalog had 2 application schemas, 33 tables, 385 columns, 90 logical FKs, 3 late FKs, 49 reviewed nonconstraint indexes, 49 policies, 63 noninternal triggers, 39 application `SECURITY DEFINER` functions, and 12 School OS roles. All 33 tables were owned by `schoolos_schema_owner` with ENABLE and FORCE RLS. The 12 role attributes, PostgreSQL 17 membership semantics, fixed function search paths, effective privileges, safe function default ACLs, Auth boundary, and hosted API exposure passed the review. PUBLIC, anon, and service_role had zero application function EXECUTE and direct table/column surfaces; authenticated had exactly six reviewed function EXECUTEs and column-limited SELECT on five tables, without direct DML. The error-level and warning-level lint commands with `--fail-on error` passed. See [review 20](20_foundation_managed_throwaway_m2_security_review.md).
- **M3:** Five synthetic hosted Auth users signed in with real passwords and yielded JWTs with matching `sub`, authenticated role, numeric `iat`, and `is_anonymous=false`. Live requests proved unbound and stale-token denial, fresh bound identity resolution, complete-grant access and incomplete/mixed-grant denial, Campus A allow/Campus B deny, FAMILY ceiling, OWN isolation, direct DML denial, and private-schema rejection. The frozen hosted pgTAP suite passed serially: **9 files / 220 planned / 220 passed**, before the committed M3 runtime fixture. It was not rerun after that fixture or in M5. See [review 21](21_foundation_managed_throwaway_m3_auth_jwt_rbac_review.md).
- **M4:** A dedicated hosted Auth Admin hard `DELETE` returned HTTP 200. The Auth row disappeared, the real FK set the same binding's `auth_user_id` to NULL, the Person and ACTIVE principal survived, `binding_version` and `row_version` advanced `1 → 2`, the token cutoff advanced, and `bound_at` stayed unchanged. Exactly one historical BOUND and one new UNBOUND event, plus initial and `AUTH_RECONCILIATION` audits, remained. The deleted UUID was retained in historical evidence. The old real JWT resolved no principal; fresh and stale deleted-subject helper claims returned NULL. Immutable evidence deletion and historical subject reassignment probes raised the expected `P0001` errors. See [review 22](22_foundation_managed_throwaway_m4_auth_deletion_review.md).

Three earlier throwaways failed before hosted migration compatibility could be measured: Windows source line endings, a PowerShell credential-generator incompatibility, and a linked/direct IPv6 connection timeout. All three were destroyed safely; none was a hosted migration SQL failure. The successful run used canonical Git source, Python `secrets` for temporary credentials, and the explicit session-pooler `--db-url` route, as recorded in [reviews 14–19](14_foundation_managed_throwaway_m1_review.md).

## Final pre-destruction state

The last M5 read-only SQL snapshot ran on **2026-09-26 at 16:41:18 UTC** inside `BEGIN READ ONLY`/`COMMIT`, over the official session pooler on port 5432 with TLS. A fresh temporary database password was rotated through the supported Management endpoint; the first immediate connection hit normal password propagation, and the same route then succeeded. No transaction-pooler, direct IPv6, linked mode, or credential-bearing URI was used.

| Final live measure | Result |
| --- | --- |
| Project / database / Auth / REST | `ACTIVE_HEALTHY`; each service reported healthy |
| PostgreSQL / pgTAP installed version | `17.6` / `1.3.3` |
| Migration history | Exactly the nine versions above, once each |
| Application schemas / tables / roles | `app`, `app_private` / 33 / 12 |
| Tables with ENABLE / FORCE RLS | 33 / 33 |
| Auth FK | `FOREIGN KEY (auth_user_id) REFERENCES auth.users(id) ON UPDATE RESTRICT ON DELETE SET NULL` |
| `app_private.current_principal_id()` | Exists; owner `schoolos_authz_reader` |
| Hosted exposed schemas | Exactly `public,graphql_public,app`; `app_private` absent |
| Hosted Auth users | Exactly the five retained M3 synthetic users; deleted M4 UUID/email absent |

The five retained Auth labels were `foundation-test-001@example.invalid`, `foundation-rbac-001@example.invalid`, `foundation-family-001@example.invalid`, `foundation-own-001@example.invalid`, and `foundation-own-002@example.invalid`. The M4 deletion label `foundation-auth-delete-integration-001@example.invalid` and UUID `69f22c68-8a5f-4f69-bb11-35d75faec519` were absent.

The M4 Person `7b6d44ef-4bd0-535c-b9bb-b583f61e0005` and ACTIVE INDIVIDUAL principal `8d67a35a-1e0c-536e-a2d3-baccd746f3de` survived. Binding `4cd00920-4c08-5825-a3d8-0dc8d7aac7ff` survived detached, with `binding_version=2`, `row_version=2`, cutoff `2026-09-26T13:27:10+00:00`, and unchanged `bound_at=2026-09-26T13:25:23.069051+00:00`. It had exactly one BOUND and one UNBOUND event, plus exactly one initial WORKER audit and one `AUTH_RECONCILIATION` audit. Both event/audit chains used the single ACTIVE SYSTEM reconciliation actor `fd91abd0-b90a-5d79-af62-626f70cbb34c`; the deleted UUID remained in UNBOUND and audit snapshots. The live FAMILY principal ID was `3a4adb29-9585-5176-b33b-0664048e24b0`, clarifying a malformed UUID transcription in review 21 without altering that historical review.

## Complete validation matrix

| Area | Gate | Status | Evidence |
| --- | --- | --- | --- |
| Deployment | Fresh target platform baseline | PASS | M0/M1; no School OS state before push |
| Deployment | Exact nine-version dry-run and one push | PASS | M1; all nine applied |
| Deployment | CREATE ROLE, memberships, SET ROLE | PASS | M1 deployment; M2 PostgreSQL 17 catalog |
| Deployment | Default privileges and schema authorization | PASS | M1 apply; M2 effective ACL/owners |
| Deployment | Auth FK and final helper | PASS | M1 apply; M5 FK/owner continuity |
| Security | Schema/table ownership and role attributes | PASS | M2 full inventory |
| Security | PostgreSQL 17 membership semantics | PASS | M2 explicit and creator memberships |
| Security | RLS ENABLE/FORCE and 49 policies | PASS | M2; M5 33/33 smoke |
| Security | 39 SECURITY DEFINER functions and fixed paths | PASS | M2 full function inventory |
| Security | Function default ACL; PUBLIC/anon boundaries | PASS | M2 effective checks |
| Security | Authenticated six functions, five read surfaces, no direct DML | PASS | M2 effective checks; M3 denial |
| Security | service_role application SQL boundary | PASS | M2 effective checks |
| Security | Auth ownership/privilege boundary and FK | PASS | M2; M4 real deletion |
| Security | `app` exposed, `app_private` excluded | PASS | M2 change; M3 requests; M5 unchanged config |
| Runtime | Real Auth/password sign-in and JWT context | PASS | M3 five hosted identities |
| Runtime | Binding cutoff and bound/unbound resolution | PASS | M3; M4 deleted subject |
| Runtime | Complete/incomplete/mixed RBAC grants | PASS | M3 real JWT requests |
| Runtime | Campus, FAMILY, OWN boundaries | PASS | M3 real JWT requests |
| Runtime | Direct DML denial and private API exclusion | PASS | M3 real requests |
| Test | Managed database lint | PASS | M2 error and warning checks |
| Test | Frozen hosted pgTAP suite | PASS | M3, 9 files / 220 planned / 220 passed before runtime fixture |
| Identity lifecycle | Real hosted Auth Admin hard delete | PASS | M4 HTTP 200; M5 Auth UUID absent |
| Identity lifecycle | FK detach; Person/principal preserved | PASS | M4 integration; M5 live continuity |
| Identity lifecycle | Binding/row version and cutoff; bound_at | PASS | M4 before/after; M5 final values |
| Identity lifecycle | BOUND/UNBOUND and reconciliation audit | PASS | M4; M5 exactly two of each |
| Identity lifecycle | Old JWT and fresh/stale deleted-subject denial | PASS | M4 real RPC/helper checks |
| Identity lifecycle | Immutable evidence and reassignment guard | PASS | M4 expected `P0001` probes |
| Operations | Worker LOGIN credential/pooler activation | DEFERRED | M2 measured CONNECT only; no worker authentication |
| Operations | Reproducible bootstrap, CI, drift and production rollout | DEFERRED | Separate deployment productization track |
| Scope | Production/staging deployment in this throwaway experiment | NOT APPLICABLE | No production/staging target was used |

## Final project destruction

At **2026-09-26 16:41:38 UTC**, immediately before deletion, fresh project-detail, project-list, and organization lookups again matched all exact target identifiers and `ACTIVE_HEALTHY` status. Source integrity and main worktree cleanliness were rechecked. The previously captured database evidence and local DB/Auth secret cleanup were required programmatically before the one Management API `DELETE /v1/projects/lndjtslixvugswnnctam` request. It returned **HTTP 200**, response class JSON object, at **16:41:39 UTC**. No second DELETE, reverse migration, Auth-user-by-user deletion, or fixture cleanup was attempted. The [supported project-delete endpoint](https://supabase.com/docs/reference/api/v1-delete-a-project) was used.

## Post-destruction verification

The first immediate detail lookup briefly returned HTTP 403 while the project list already omitted the target. A repeat at **2026-09-26 16:41:52 UTC** returned **HTTP 404** from direct target lookup. The independent project list still contained **zero** entries for `lndjtslixvugswnnctam` and retained the organization's **one** unrelated project with its original metadata. The success verdict rests on the repeated 404 and list absence, not the deletion response alone.

## Security and local state

The temporary DB password, process `PGPASSWORD`, passwordless URI, and unused Auth/API secret variables were cleared after the final database snapshot; the Management token reference was cleared after absence verification. No password, JWT, refresh token, API/service key, management token, Authorization header, or credential-bearing URI was printed into this review or committed. The Supabase CLI's pre-existing account credential was neither changed nor revoked.

The main checkout and five existing isolated worktrees had no `supabase/.temp/project-ref`, no untracked files, and no secret-named or disposable credential files. The only broad literal scanner hit was review 18's explicit `<PASSWORD>` placeholder, not a credential. Existing unrelated worktrees and CLI `cli-latest` cache files were preserved. The M1 deployment used `--db-url` and no link; M5 created no link artifact.

## Foundation database conclusions

The managed experiment resolves the Foundation questions of nine-migration deployment, custom roles and role switching, Auth FK compatibility, RLS/ACL ownership, real JWT/RBAC/FAMILY/OWN enforcement, real Auth deletion reconciliation, immutable evidence, and the `app`/`app_private` API boundary. The [local execution review](10_foundation_local_execution_review.md) separately records the successful clean nine-migration rebuild and full local validation. M5 captured continuity and destroyed the synthetic target; it was not another full security or pgTAP run.

Engineering completion estimates for the **frozen Foundation scope**: architecture/design **approximately 98–100%**, SQL implementation **100%**, local validation **100%**, and managed Supabase Foundation validation **100% after M5**. These are judgmental estimates, not measured percentages. The remaining work below concerns deployment and operations, and later product modules remain outside this Foundation claim.

## Explicit deferred productionization items

Reproducible `app` exposed-schema automation with guaranteed `app_private` exclusion; environment bootstrap and migration deployment automation; hosted drift checks and CI validation; environment secret provisioning/rotation; worker LOGIN credentials, authentication and pooler validation; staging and production rollout procedures; backup/recovery runbooks; observability/alerting; and long-term platform/CLI upgrade strategy remain to be designed and executed separately. M2 measured worker database CONNECT privilege but did not activate the three worker LOGIN roles.

## Final repository state

This review is the sole tracked M5 change. Migrations 1–9, database tests 01–09, `.gitattributes`, `supabase/config.toml`, historical reviews 11–22, Flutter code, and dependencies were not modified. No migration 10, worker activation, new schema design, or production/staging action occurred.

## Next recommended engineering phase

`FOUNDATION DEPLOYMENT PRODUCTIZATION — REPRODUCIBLE SUPABASE CONFIG + ENVIRONMENT BOOTSTRAP + CI/DRIFT SAFETY`. This is a separate track and was not started in M5.
