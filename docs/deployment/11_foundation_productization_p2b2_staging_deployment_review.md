# Foundation deployment productization — P2B2 persistent staging deployment

**DEPLOYMENT PRODUCTIZATION P2B2 PASS — FOUNDATION DEPLOYED AND VALIDATED ON PERSISTENT STAGING — STAGING PRESERVED**

**FOUNDATION DEPLOYMENT PRODUCTIZATION COMPLETE THROUGH FIRST PERSISTENT STAGING DEPLOYMENT**

This documentation-only review records safe evidence reported by the operator from a manually completed staging deployment. Codex did not independently contact or modify staging in this closure task. Exact source SHA: `9e01d72fd670af6c947f53ab03911e019b4982ff`.

## Persistent target and preflight

The pinned, long-lived staging project is `schoolos-staging-main`, ref `whwongqcgjakcfrzbvcg`, in organization `jyssocxpozqlditlaogq`, region `ap-northeast-2`. It is an engineering staging environment, not a customer or production project.

One earlier read-only preflight stopped before mutation with the safe diagnostic `PSQL_FAILURE stage=DB_PROBE_VERSION class=PSQL_AUTH_FAILED exit=2`. The operator corrected the locally supplied database password and reran the read-only preflight. No cause for the initially incorrect password is inferred here.

The subsequent `STAGING_PREFLIGHT_PASS` reported `STAGING_FOUNDATION_BOOTSTRAP_ELIGIBLE`, `push_count=0`, clean fresh baseline `[0, 0, 0]`, exact nine-of-nine migration dry-run, `STAGING_DATA_API_REVIEWED_APP_ABSENT`, and PostgreSQL `17.6`. The reviewed database route was TLS Supavisor **session pooler 5432**. The preflight made no persistent hosted mutation.

## Reported deployment result

The operator reported `STAGING_DEPLOY_PASS` from the exact source SHA above. The fresh baseline was `[0, 0, 0]`. Exactly **one** migration push occurred. The dry-run and final migration history each contained these exact nine frozen Foundation versions, in order:

```text
20260924122442
20260924122445
20260924122446
20260924122448
20260924122450
20260924122451
20260924122453
20260924122455
20260924183537
```

The reported catalog counts were **12** School OS roles, **33** tables, **49** policies, **33** tables with RLS enabled, **33** with RLS forced, and **39** `SECURITY DEFINER` functions. Security smoke was **PASS**. Managed Data API configuration was `MANAGED_CONFIG_PASS`. Error- and warning-level database lint both passed.

Five synthetic hosted Auth fixtures were created for the frozen authorization tests; mandatory cleanup was reported **CONFIRMED**. The hosted Foundation database tests passed:

| Test | Assertions |
| --- | ---: |
| `01_foundation_catalog.sql` | 44/44 |
| `02_auth_helper_preflight.sql` | 6/6 |
| `03_file_objects.sql` | 16/16 |
| `04_family_intervals.sql` | 16/16 |
| `05_approval_lifecycle.sql` | 25/25 |
| `06_evidence_delivery.sql` | 16/16 |
| `07_authorization_rbac.sql` | 33/33 |
| `08_family_own_scope.sql` | 41/41 |
| `09_auth_deletion_reconciliation.sql` | 23/23 |
| **Total** | **220/220** |

Final drift was `STAGING_DRIFT_PASS`; final project health was `ACTIVE_HEALTHY`. The staging project was **preserved**, with **zero project deletes**. The persistent staging project now contains the validated frozen Foundation database: nine migrations applied, nine frozen test files validated, and 220/220 hosted assertions passed. It is no longer a fresh Foundation target. Future audits should classify it as `STAGING_FOUNDATION_ALREADY_DEPLOYED` and require `push_count=0` unless a separately reviewed future migration is introduced. This review authorizes no such migration.

Worker activation remains **deferred**. Migration 10 was not created. Flutter is unchanged. Production and customer-school deployment remain unauthorized and require separate review. The database password, Management token, service-role key, JWTs, fixture passwords, and credential-bearing URLs are absent from this review.

This closure task made no Supabase contact and performed no preflight, deployment, migration, hosted SQL/Auth/configuration action, worker activation, or project deletion. It changed only this review and the narrow current-phase wording in `AGENTS.md`.
