# Foundation deployment productization — P1 successful managed rehearsal

**DEPLOYMENT PRODUCTIZATION P1 PASS — DISPOSABLE MANAGED BOOTSTRAP REHEARSAL COMPLETE — PROJECT DESTROYED**

This review records results supplied by the user from a manually executed, separately authorized managed P1 rehearsal. This documentation task did not rerun the rehearsal or independently query the destroyed project. The run started from exact HEAD `d205a71e1f69f148ac4e91e2db1bfe7611b39d8f`.

## Disposable target and bootstrap

| Gate | Observed result |
| --- | --- |
| Project | Exactly one disposable project created: `schoolos-foundation-productization-p1-20260927-124529-804b63`, ref `qrpjpsfjinxknzmloskh`. |
| Organization and region | `Ilmora`; `ap-northeast-2`. Pre-existing peer count: **1**. |
| Clean baseline | `[0, 0, 0, 0]` for School OS roles, `app`/`app_private` schemas, Foundation migration history, and synthetic Foundation Auth users. |
| Database route | TLS Supavisor **session pooler port 5432**; PostgreSQL **17.6**. |
| Migration dry-run | Exactly the nine versions listed below. |
| Migration deployment | Exactly **one** push. Post-push migration history contained the same exact nine versions. |

The dry-run and final migration history versions were:

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

## Managed verification

| Gate | Observed result |
| --- | --- |
| Catalog | **12** School OS roles; **33** tables; **49** policies; **33** tables with RLS enabled; **33** tables with RLS forced; **39** `SECURITY DEFINER` functions. |
| Security smoke | **PASS**. The existing runner sets this only after checking that `principal_auth_bindings_auth_user_id_fkey` references `auth.users(id)` with `ON UPDATE RESTRICT` and `ON DELETE SET NULL`, and that `app_private.current_principal_id()` is owned by `schoolos_authz_reader`. |
| Initial Data API state | Reviewed drift: `app` absent. |
| Managed configuration | `MANAGED_CONFIG_PASS`. |
| Database lint | Error and warning levels **PASS**. |
| pgTAP | Version **1.3.3**. |
| Hosted Auth fixtures | **5** users. |
| Post-test drift | **PASS**. |
| Wrong confirmation | Blocked before HTTP PATCH. |
| Final project health before cleanup | `ACTIVE_HEALTHY`. |

Hosted database tests passed:

| Test file | Assertions passed |
| --- | ---: |
| `01_foundation_catalog.sql` | 44 |
| `02_auth_helper_preflight.sql` | 6 |
| `03_file_objects.sql` | 16 |
| `04_family_intervals.sql` | 16 |
| `05_approval_lifecycle.sql` | 25 |
| `06_evidence_delivery.sql` | 16 |
| `07_authorization_rbac.sql` | 33 |
| `08_family_own_scope.sql` | 41 |
| `09_auth_deletion_reconciliation.sql` | 23 |
| **Total** | **220/220** |

## Cleanup and repository scope

Cleanup finished with `phase = CLEANUP_CONFIRMED`: exactly **one** DELETE, HTTP status **200**, `detail_absent = true`, `list_absent = true`, and `peers_preserved = true`. Destruction of the disposable project was confirmed. No worker LOGIN role was activated.

Frozen migrations 1–9 and frozen tests 01–09 remained unchanged. There was no migration 10 and no Flutter change. This review is the only repository change in this documentation task. It contains no credentials or credential-bearing URI.

P2 is now eligible for **separate authorization**. P2 was **not started** by this task.
