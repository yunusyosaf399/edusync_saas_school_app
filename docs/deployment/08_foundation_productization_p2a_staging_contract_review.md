# Foundation deployment productization — P2A staging contract and drift operations

**DEPLOYMENT PRODUCTIZATION P2A PASS — STAGING CONTRACT, SECRET POLICY, AND DRIFT OPERATIONS READY — REMOTE STAGING NOT YET AUTHORIZED**

P2A prepares a **local/static** contract and offline checks for a future dedicated staging project. It performs no managed action. The predecessor [P1 rehearsal](07_foundation_productization_p1_success_review.md) passed and its disposable project was destroyed. Starting HEAD: `7ec805c193e9b773807360de5ba6607a8217571a`.

At the start of this task, the worktree had an unrelated modified project-management workbook and an untracked Excel lock file under `reference/`. They were left untouched. The P2A commit contains only the five files listed below; future remote deployment still requires a **clean** worktree and exact commit.

## Contract and target boundary

The versioned [staging contract](../../supabase/config/foundation_staging_contract.json) has `environment = staging`, `foundation_id = schoolos-foundation-v1`, and a reference to the existing managed Foundation contract. It does not duplicate the frozen migration hashes or catalog counts. It requires a dedicated non-customer project named with `schoolos-staging-` in allowed region `ap-northeast-2`. A staging project is a non-production engineering environment, neither a customer school operational project nor the SaaS control plane. It must use synthetic data and `.example.invalid` identities where practical. Real student, staff, payroll, medical, and customer data are not copied into staging by default.

A future target manifest must explicitly supply `environment`, `project_ref`, `project_name`, `organization_id`, `region`, and `foundation_id`. The pure validator rejects unknown or missing fields, refs other than exactly 20 lowercase letters, wrong environment/region/Foundation ID, empty organization, wrong name prefix, and the P1 disposable prefix. No actual target manifest was created. Future mutation must compare its exact ref/name/organization/region against independent live project identity; it must never choose the first project in a list.

A future staging deployment must name a full 40-character Git commit, have a clean worktree, pass the Foundation source guard, contain no unreviewed future migration, and record the exact SHA in deployment evidence. It uses the reviewed TLS Supavisor **session** pooler on port **5432** and requires a clean-project baseline before first deployment, exact dry-run, separate push authorization, one push, and strict history verification. P2A does none of those hosted steps.

## Secret and CI boundary

`SUPABASE_ACCESS_TOKEN` is permitted only in an operator process environment or approved secret manager during a separately authorized Management operation. It must not appear in the repository, `.env`, CLI arguments, logs, Flutter, generated evidence, or P2A GitHub Actions. The future staging DB password variable is `SCHOOL_OS_STAGING_DB_PASSWORD`; its value belongs in approved secret management or a temporary process environment during an authorized database operation, never in a URI, command argument, repository, log, Flutter, or documentation. A service/admin key may be retrieved only during separately authorized work and held in memory, never persisted in the repository or Flutter. A public client key may eventually be environment-specific public configuration; it is not authorization and cannot replace RLS or be confused with an admin key.

The default `foundation_staging.py` plan and its `validate` and `drift-plan` modes do not inspect environment secrets. Only explicit `secret-preflight` checks **presence or absence by variable name** and prints no value. Its tests use unmistakably fake values. Current GitHub CI remains local-stack only with no hosted secrets; P2A adds no remote staging workflow or deployment.

## Read-only drift policy

The future drift categories are `SOURCE`, `TARGET_IDENTITY`, `HEALTH`, `POSTGRESQL_VERSION`, `MIGRATION_HISTORY`, `CATALOG`, `SECURITY_SMOKE`, `DATA_API`, `LINT`, `FOUNDATION_TESTS`, and `WORKER_ACTIVATION_BOUNDARY`. The pure snapshot validator uses the managed contract for the exact nine Foundation migration versions, 12 roles, 33 tables, 49 policies, 33 enabled and forced RLS tables, 39 `SECURITY DEFINER` functions, Auth binding FK, and current-principal helper owner. It requires exactly `public`, `graphql_public`, and `app` as exposed Data API schemas; `app_private` and any extra schema block. It requires healthy project/database/Auth/REST, both lint levels passing, and 220 Foundation assertions. PostgreSQL must meet the managed-contract minimum major **15**; the reviewed **17.6** is evidence, not a permanent exact-version requirement. All mismatches produce fixed safe failure codes.

Drift checking is read-only and fail-closed. It never repairs migration history, runs migrations, resets a database, disables RLS, adds/drops policies, alters grants, patches unexpected API exposure, recreates schema, or deletes a project. Repair is a separate authorized operation. Staging project deletion also requires separate authorization. The contract prohibits automatic destructive repair, production promotion, and customer-data copying. Production school projects must be bootstrapped independently from reviewed source and contracts; a staging database is never promoted into a customer project.

Worker activation remains **deferred**: no worker LOGIN password, worker secret, long-lived worker connection, or event/identity/file worker runtime is provisioned here. P2A does **not** prove production backup/recovery readiness. Before production rollout, a later authorized phase must define and validate backup ownership, restore procedure, isolated restore target, recovery verification, credential rotation when required, and RPO/RTO policy when business requirements define it. This task performs no backup or restore and invents no RPO/RTO number.

## Files and verification

- `AGENTS.md`: current phase wording only.
- `supabase/config/foundation_staging_contract.json`: versioned staging policy without a target ref or secret.
- `tools/supabase/foundation_staging.py`: zero-network local plan, validation, explicit secret-presence check, drift plan, and pure target/snapshot checks. It has no remote apply or repair mode.
- `tools/supabase/tests/test_foundation_staging.py`: synthetic contract, target, secret, drift, and mode tests.
- `docs/deployment/08_foundation_productization_p2a_staging_contract_review.md`: this review.

`plan` printed the 19-step future sequence without execution; `validate` returned `STAGING_VALIDATE_PASS`; `drift-plan` printed the eleven read-only categories and no-repair boundary. The explicit secret-preflight behavior was tested with fake present and missing variables; their values did not appear in output. A compliant synthetic snapshot returned `STAGING_DRIFT_PASS`. Target, migration, catalog/RLS, security, Data API, health/version, source, test-count and worker-boundary mismatches failed in the new tests.

`python -m unittest discover -s tools/supabase/tests -v`: **74/74 PASS** (39 existing plus 35 new). `foundation_guard.py`: `FOUNDATION_SOURCE_PASS 9 migrations + 9 tests`, `LOCAL_CONFIG_PASS`; no future migration. `foundation_local_ci.py`: Supabase CLI **2.98.2**, Docker Linux, clean local reset of the nine frozen migrations without seed, **5/5** local Auth fixtures, error and warning lint PASS, and serial tests 01–09 **220/220 PASS** (44, 6, 16, 16, 25, 16, 33, 41, 23).

Managed API calls, managed projects created/contacted, hosted SQL/Auth/config operations and hosted migration pushes in P2A: **0**. Frozen migrations 1–9 and database tests 01–09, the managed Foundation contract, Flutter, and dependencies were not changed. No migration 10 was created. Remote staging and production remain unauthorized; the next separately reviewed phase is **FOUNDATION DEPLOYMENT PRODUCTIZATION — P2B DEDICATED STAGING PROJECT PROVISIONING + FIRST DEPLOYMENT**.
