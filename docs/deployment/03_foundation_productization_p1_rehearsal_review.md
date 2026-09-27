# Foundation deployment productization — P1 disposable rehearsal attempt

**Verdict: DEPLOYMENT PRODUCTIZATION P1 FAIL — DISPOSABLE PROJECT DESTROYED.** The single authorized managed P1 project was created and passed the initial Management API health and target-identity gates. Its first read-only PostgreSQL session exited 3, before a migration dry-run or push. The runner reported `PSQL_FAILED exit=3` but suppressed the underlying stderr; the exact connection/PostgreSQL error is therefore **not available**. No migration compatibility or hosted test result can be claimed from this attempt. Independent post-failure checks subsequently confirmed project destruction.

## Source and local preparation

- Starting HEAD: `88a5c43f81046ff9f4ba55a57748676c0ee4f0a0`; main worktree initially clean.
- The process environment contained `SUPABASE_ACCESS_TOKEN`; only presence was displayed. The token was passed in memory to Management API requests. The CLI credential store and `supabase login` were not used.
- P0 unit tests: **11/11**. Frozen source guard: **nine migrations and nine tests passed**; local config passed. The P0 deployment plan reported **zero future migrations** and kept unrestricted remote apply disabled.
- The previously completed local clean validation in this session passed: CLI **2.98.2**, Docker Linux, nine-migration local reset, five synthetic local Auth users, both lint levels, and serial tests **220/220** across files 01–09.
- New P1 runner unit tests: **10/10**; combined P0/P1 unit suite **21/21**. These test default plan/no mutation, exact run/organization confirmation, disposable target validation, detail/list identity, dry-run mismatch, no blind command retry, bounded health, deletion absence/peer preservation, and exception redaction.
- `foundation_rehearsal.py` defaults to `plan`; `run` requires `--run --confirm-organization-name Ilmora`. It creates its own generated P1-prefixed target and has no existing-project-ref argument. The unrelated peer was read only for organization/project count and safe API response shape; it was not modified.

## Managed attempt

| Gate | Empirical result |
| --- | --- |
| Organization | Authenticated organization lookup found one `Ilmora` organization, ID `jyssocxpozqlditlaogq`. One unrelated project existed before creation. |
| Region | `ap-northeast-2` appeared in the available-regions response. |
| Project creation | One Free-plan project was created: `schoolos-foundation-productization-p1-20260927-035833-ee3487`, ref `csjcqoouddaivuimafea`. A generated 48-character database password was held only in process memory. |
| Health and identity | The runner advanced past project health and independent detail/list identity checks. Those checks required exact ref, P1 name, organization, and region. |
| Session pooler | The runner discovered the official pooler endpoint and constructed a passwordless TLS URI for Supavisor **session port 5432**, with temporary process `PGPASSWORD`. Neither linked mode nor transaction port 6543 was used. The URI and password were not logged. |
| First database operation | The initial `psql` read-only PostgreSQL-version query failed: `PSQL_FAILED exit=3`. The runner did not capture a sanitized PostgreSQL/connection message, so the cause cannot be classified more narrowly. |
| Migration dry-run / push | **Not run / 0 pushes.** No migration was applied by this attempt. |
| Later gates | Catalog/security smoke, Data API apply/check, hosted lint, pgTAP, hosted Auth fixtures, serial tests, JWT smoke, and final drift checks were **not run**. |
| Worker activation | **Not performed.** No Flutter, dependency, migration, or frozen database-test file was changed. |

The first `run` invocation stopped before project creation on `CLI_VERSION_MISMATCH`: the runner compared combined stdout/stderr, and the CLI's update notice contaminated the version string. The comparison was narrowed to the first version line before the **single** project-creating invocation. This was a harness error, not a managed SQL failure. No CLI upgrade occurred.

## Cleanup and retained risk

The runner printed `P1_FAILURE_CLEANUP_UNCONFIRMED` immediately after the database failure. It therefore did **not** claim a safe cleanup at that moment. Two subsequent independent Management API checks found direct project lookup **HTTP 404**, project-list count **0** for `csjcqoouddaivuimafea`, and the unrelated original project retained (**1** matching ref). The eventual project absence is confirmed, but the runner's own deletion/confirmation sequence needs better stage diagnostics and a longer bounded eventual-consistency window. The raw deletion HTTP result was not captured; no second DELETE was issued manually.

The passwordless URI, generated DB password, Management token, and any service key were not written to the repository or this review. No hosted Auth user was created; no service key was retrieved. The runner process exited, discarding its temporary secret references. The account-level Management token was not revoked.

## Automation assessment and next gate

| Step | State in this attempt |
| --- | --- |
| Source guard, CLI pin, plan, disposable naming, organization confirmation, Management creation, health/identity | Automated and reached; the first CLI-pin parsing bug was corrected before creation. |
| Initial DB baseline and all subsequent deployment/test gates | Implemented in the runner but **not empirically reached** because the first `psql` connection failed. |
| Exact underlying connection error and cleanup sequence evidence | Diagnostic gap requiring correction before another managed attempt. |
| Target selection authorization | Guarded explicit `--run` and exact organization confirmation. |
| Worker activation, staging, production, customer deployment | Deferred; not authorized by P1. |

This attempt exhausted the instruction to create **exactly one** fresh disposable project. Do not retry inside P1 or infer a managed migration result. A separate task should review the runner's connection diagnostics, test its cleanup/absence behavior with mocks, and authorize a new disposable target before any further hosted run. P2 was not started.
