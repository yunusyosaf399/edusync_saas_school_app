# Foundation managed preflight — source integrity and LF checkout policy

**SOURCE INTEGRITY PASS — READY FOR FRESH M1 THROWAWAY RETRY.** This gate established deterministic LF checkout bytes for the frozen Foundation migration and database-test SQL. It was local/repository-only; it did not establish managed Supabase compatibility or create a replacement throwaway project.

## Provenance and historical interpretation

- Starting HEAD: `4bcc177c53970f0b1fdafe82b3ef77a98967e359`. Main checkout was clean. Global `core.autocrlf=true` came from `C:/Program Files/Git/etc/gitconfig`; `core.eol` and `core.safecrlf` were unset. No repository `.gitattributes` or `.editorconfig` existed, and `git check-attr -a` reported no SQL attribute. No global Git setting was changed.
- Git-native blob-ID comparison from M0 source `8c7081c1bc62567102bb36d69d05228bb004fa8c` to starting HEAD found **18/18 identical blobs**: all nine migrations and tests 01–09. A second comparison after the policy commit found the same 18 IDs. No SQL was edited, reformatted, renormalized, or staged.
- [M0 review 13](13_foundation_managed_throwaway_m0_review.md) recorded filesystem SHA-256, not canonical Git-content SHA-256. Its values remain valid historical observations. Three migration values represented CRLF or mixed main working-tree bytes; the other six migration values and all nine test values match canonical blobs. The three differences are explained by line endings alone: their Git blobs contain zero CRLF sequences; the main working-tree files contained 360, 266, and 69 CRLF sequences respectively, and their filesystem hashes matched the M0 values. Git reported no content diff.
- [M1 review 14](14_foundation_managed_throwaway_m1_review.md) remains unchanged. Its destroyed throwaway and pre-deployment stop are classified as a **SOURCE MATERIALIZATION / LINE-ENDING PROCEDURAL FAILURE**, not a SQL, migration, managed role-authority, or Supabase compatibility failure. No managed migration was attempted.

The authoritative source identity is now the **Git blob ID plus byte-preserving SHA-256 of the blob content**. A filesystem hash is compared only after a fresh checkout applies the repository's LF attribute. The M0 filesystem hashes for migrations `20260924122446`, `20260924122448`, and `20260924122450` are not canonical values.

## Repository checkout policy

Policy commit: `d4fc59298fc337e07e13b48f2dd9bd385a2219bf` (`chore: enforce LF for database SQL artifacts`). Its only tracked change was the new root `.gitattributes`:

```gitattributes
.gitattributes text eol=lf
supabase/migrations/*.sql text eol=lf
supabase/tests/database/*.sql text eol=lf
```

Before and after that commit, `git diff` for both frozen SQL directories was empty. No `git add --renormalize` or bulk documentation conversion ran. The main checkout retained historical CRLF/mixed working bytes in three migrations immediately after the commit; this is permitted for the existing checkout and does not change its clean Git state. Fresh deployment checkouts must use the canonical LF bytes proved below.

## Canonical migration baseline and fresh-worktree proof

All blob IDs were identical at M0 source, starting HEAD, and policy-commit HEAD. Hashes were calculated from binary `git cat-file blob` output, not a PowerShell text pipeline. The fresh checkout was `C:\Users\yunus\StudioProjects\saas_OS_school_app_integrity_worktree`, detached and clean at the policy commit, with no Supabase link state. For each row, its filesystem SHA-256 equals the canonical value; CRLF count was **0**, LF was present, and result was **MATCH**.

| Migration | Git blob ID | Canonical Git SHA-256 = fresh filesystem SHA-256 |
|---|---|---|
| `20260924122442_foundation_roles_schemas.sql` | `cebf9710f019f591f6c4bda5189e49ca7002bbc5` | `f8793604a4b8b0b25392540bf81dfe39e43941729998bb76a9dc8506e7dd0d1d` |
| `20260924122445_foundation_identity_school_files.sql` | `16e98bc39d19b33204d0576668e48ef2b4626148` | `f846b41121d3e125be8de0a1f0e7fd6e48d2d812ad2330107a5ffca3ac229b5b` |
| `20260924122446_foundation_rbac_workflow.sql` | `e8457f4fbe3c278c90cc706a05371cf3728ab7af` | `8245216fd8ac9e82d13c2f8d614010a41962b372bf16917e2f297caff8819351` |
| `20260924122448_foundation_receipts_events_settings.sql` | `b7c5ab80e1bb84978d06f382efd599df5baa46f7` | `28f0b2a9b49b3245c292e16c9f67a468cb56d1e8aa8bc4cee12d8f8dd73ed795` |
| `20260924122450_foundation_late_fks_indexes.sql` | `41259c8439d041c0de913e119e773fb9981c4b57` | `89aff7d01c6293cced0be0d9f23b90826996690bb8a9a7cfc9a60b60de319447` |
| `20260924122451_foundation_structural_triggers.sql` | `4ce4d54229067173ddfab88cacd481bc1657e811` | `d5612f73f07102cad4ef41b1642db04a2afc061271f6c2158aad73ff0fb4c4fb` |
| `20260924122453_foundation_authorization_rls.sql` | `b992465d95597ae273363c611e729b295e268513` | `f8f8d3dda44a1685c82561cf7825a87d1d662e0480c8b8adcb0714cb4919e056` |
| `20260924122455_foundation_privilege_lockdown.sql` | `caaa791e957a05a1deb1656f87d5198506e1d4f1` | `330d583878ab6282f6a0b56e5665a25e87d3c6cae93b8dd0ded915b9fcaddff2` |
| `20260924183537_foundation_auth_helper_schema_usage.sql` | `30f517d67087011c21aa3b6fb4aaa80d9689cb72` | `3ecddebe953935724636dff14a2c15f27da86e804e2877a37396d85cebdf69c1` |

The fresh worktree returned `text: set` and `eol: lf` for a migration. A second brand-new worktree from the same policy commit reproduced the canonical filesystem hashes and zero CRLF in **9/9 migrations**; it was removed after verification. The first clean, unlinked integrity worktree remains available for review. Both main and first fresh worktrees had empty staged/unstaged diffs at the verification point.

## Canonical database-test baseline and fresh-worktree proof

The fresh worktree also returned `text: set` and `eol: lf` for a database test. For every test below, its fresh filesystem SHA-256 equals the canonical value, CRLF count was **0**, LF was present, and result was **MATCH**. All nine canonical SHA-256 values also match review 13's historical values.

| Test | Git blob ID | Canonical Git SHA-256 = fresh filesystem SHA-256 |
|---|---|---|
| `01_foundation_catalog.sql` | `07072e0ff3348b7d06e8a283089caf27391d75c9` | `5eb2b26c6a2e1cc3c2de46634e933ba355b7842eea3c1d2c5150dca3eaef6696` |
| `02_auth_helper_preflight.sql` | `4c5bd9953180698bcaa661f1816d910bc4e2bef2` | `89cf95b97c056778257595e68951ae59faf9101bd285e4870bbeb63f7242630c` |
| `03_file_objects.sql` | `d6620b850cbff00fa5231027c259ca44dba14d14` | `8af39fccbae32d5c0a310e18a742613d9cf3d695582f88e69e03fbb0b8eb29e4` |
| `04_family_intervals.sql` | `73a4596dc8e38d93a22698ee90352f01613f902d` | `7a1fdbd33e516e30228bfad3f11ed7b318e7834df1b28fbe8733cd5284926f13` |
| `05_approval_lifecycle.sql` | `1fc7526b45ec7178ac78d7ebca5d2af8a8b43b4e` | `cc6818e8c0c4b410a98f6a47bfa7852161ebf5aaaea8b4b8dd20fa075ce0e05c` |
| `06_evidence_delivery.sql` | `718aa2688b6fe6f021024d7a0ecb3813fa054990` | `0f2a58e958a6fa37cd8c124538a74e2b48ddb50c971c6513be5cb75d4a54fbae` |
| `07_authorization_rbac.sql` | `b7543f8a006b7d224c7124d88ac4e0471110c40a` | `125a50b842279590be511ce700a43daa9b97464178cc28392e889ef9dc8aca5b` |
| `08_family_own_scope.sql` | `da2ccb0a1db86f4db1fb5ff1c549037f9d23817e` | `7310070ef37b005d4b90ffa01d7f0fee995c63a45715563b8816c437a11fb5d8` |
| `09_auth_deletion_reconciliation.sql` | `2ed7e5c3ded5609dc3ba884ac56208c5564002e3` | `22cdf44d6169ab8480cc845eb32f43c54ead9e09eaec48da364a987fd73eeb9a` |

## Local SQL validation

The existing local Supabase stack was used; **no reset** was run. Critical pgTAP files were run serially and passed: catalog **44/44**, Auth helper preflight **6/6**, positive RBAC **33/33**, FAMILY/OWN **41/41**, and Auth-deletion reconciliation contract **23/23**. The full `supabase test db --local` run passed **9 files / 220 planned / 220 passed**. `supabase db lint --local --level error --fail-on error` exited 0 with no schema errors; `--level warning --fail-on warning` also exited 0 with no schema errors. These tests validate the unchanged local SQL behavior; they are not a fresh migration rebuild or managed compatibility test.

## Integrity rule for a future managed retry

Before any new managed deployment: **(1)** verify the reviewed Git blob IDs, **(2)** verify byte-preserving canonical Git-content SHA-256, **(3)** create a fresh deployment worktree from the reviewed HEAD, **(4)** verify `eol=lf`, **(5)** verify each materialized migration SHA-256 equals its canonical SHA-256, and **(6)** only then create, link, or use a disposable target. An uncontrolled historical working-tree hash must never serve as the sole canonical baseline.

Only `.gitattributes` and this review are tracked changes from this task, in separate commits. Reviews 13–14, migrations 1–9, tests 01–09, Supabase config, Flutter code, and dependencies were untouched. No managed project was contacted and no hosted credential was used. The next task, if separately authorized, is `FOUNDATION MANAGED SUPABASE THROWAWAY PREFLIGHT — FRESH TARGET + M1 RETRY`; it must create a wholly new target and repeat target-safety checks. This task does not start it.
