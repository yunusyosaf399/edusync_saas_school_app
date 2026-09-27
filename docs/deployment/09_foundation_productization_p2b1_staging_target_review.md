# Foundation deployment productization — P2B1 staging target and identity preflight

**DEPLOYMENT PRODUCTIZATION P2B1 PASS — STAGING TARGET PINNED — READ-ONLY LIVE IDENTITY CHECK READY — FOUNDATION DEPLOYMENT NOT YET AUTHORIZED**

Local/static preparation only. Starting HEAD: `12965a8d34c44a151d850acb09ce59d150ad5906`; starting worktree clean. The dedicated staging project was manually provisioned before this task. It is **long-lived staging** and must not be automatically deleted or treated as a disposable P1 target.

## Pinned, non-secret identity

The committed [staging target manifest](../../supabase/config/foundation_staging_target.json) contains exactly:

| Field | Value |
| --- | --- |
| `environment` | `staging` |
| `project_ref` | `whwongqcgjakcfrzbvcg` |
| `project_name` | `schoolos-staging-main` |
| `organization_id` | `jyssocxpozqlditlaogq` |
| `region` | `ap-northeast-2` |
| `foundation_id` | `schoolos-foundation-v1` |

The manifest contains identity metadata only: no Management token, database password, service/admin or public key, JWT, or credential-bearing URI. Local `validate` now requires this one manifest, parses JSON strictly, rejects unknown/missing fields and values that violate the staging contract, and performs no network request. The local plan places the committed manifest and independent live identity verification before any database or migration work.

## Read-only identity check prepared, not executed

`foundation_staging.py identity-check` is available for a later **manual operator run**. It takes `SUPABASE_ACCESS_TOKEN` only from that process's environment. Its sole transport constructs Management API **GET** requests to `/v1/projects/<manifest ref>` and `/v1/projects`; it never selects a project by first result, name, organization, or prefix. The exact-ref detail must match ref, name, organization ID and region. The project list must contain exactly one entry with that ref and the same four fields. Missing, duplicate, mismatched, malformed and HTTP-failure paths return fixed safe codes without raw response bodies or token values. Success prints only a safe PASS marker and the manifest's ref, name and region. No POST, PATCH, DELETE, database connection, pooler discovery, migration-history query, dry-run, push, Data API change, lint, Auth fixture or key retrieval is part of this mode.

Codex **did not run `identity-check` against the real staging project**. It used mocked HTTP only in unit tests. P2B1 made zero managed API calls, hosted SQL operations and hosted mutations; it did not use `SUPABASE_ACCESS_TOKEN`, contact or modify the project, or delete it. The exact next manual step is for the authorized operator to supply the token through an approved process environment and run `python tools/supabase/foundation_staging.py identity-check` from the committed source, recording only its safe result. A successful identity check alone does **not** authorize Foundation deployment; health, database, migration and configuration work belongs to separately authorized P2B2.

## Source and local verification

Changes are limited to the manifest, `foundation_staging.py`, its tests, and this review. Frozen migrations 1–9, Foundation database tests 01–09, the managed Foundation contract, Flutter and worker activation are unchanged; no migration 10 or worker credential was created. Worker activation remains **deferred**.

Local verification: tooling unit tests **89/89 PASS**, including the existing P2A drift tests and mocked identity checks. `foundation_guard.py` returned `FOUNDATION_SOURCE_PASS 9 migrations + 9 tests` and `LOCAL_CONFIG_PASS`. `foundation_staging.py validate` returned `STAGING_VALIDATE_PASS`; `plan` printed the local-only 19-step sequence with manifest and live identity gates before database work. Local Foundation CI pinned Supabase CLI **2.98.2**, used Docker Linux, rebuilt all nine frozen migrations from a clean local reset without seed, prepared **5/5** local Auth fixtures, passed error- and warning-level lint, and ran database tests 01–09 serially: **220/220 PASS**.
