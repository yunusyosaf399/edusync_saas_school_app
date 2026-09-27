# Foundation deployment productization — separately authorized P1 retry

**DEPLOYMENT PRODUCTIZATION P1 RETRY FAIL — DISPOSABLE PROJECT DESTROYED.** The one authorized fresh disposable project was created and reached a successful read-only connection probe. The attempt stopped during the pre-migration clean-baseline query of Foundation migration history with `PSQL_FAILURE stage=DB_MIGRATION_HISTORY class=PSQL_SQL_ERROR exit=3`. The runner intentionally suppressed raw `psql` output, so the precise PostgreSQL message and SQLSTATE are unavailable. No migration dry-run or push ran. One exact-target DELETE was accepted and the runner confirmed detail absence, list absence, and preservation of the pre-existing peer.

## Source and authorization gate

- Starting HEAD `7d07c36e01d725ae6889b6fc3583b7516e2b7a19`; worktree clean before and after the managed attempt.
- Tooling unit tests **34/34 PASS**; `foundation_guard.py`: `FOUNDATION_SOURCE_PASS 9 migrations + 9 tests`, `LOCAL_CONFIG_PASS`; P1 default plan passed; zero unexpected future migrations. Supabase CLI **2.98.2**.
- `SUPABASE_ACCESS_TOKEN` presence was checked without displaying its value. The runner used the process environment for authenticated Management API calls. Neither `supabase login` nor the CLI credential store was used.
- The user reports local-only GitHub Actions run `36316230446` **SUCCESS** before this retry; its run log was not independently fetched here.
- The runner was invoked once with `run --run --confirm-organization-name Ilmora`. There was no arbitrary ref, force flag, linked mode or CLI upgrade. This invocation consumed the task's one-project authorization.

## One managed attempt

| Gate | Observed result |
| --- | --- |
| Project creation | One generated Free-plan disposable target: `schoolos-foundation-productization-p1-20260927-114930-000a5c`, ref `ateglrfmxeryetelwdhu`, region `ap-northeast-2`. The runner resolved the exact Ilmora organization and pre-existing peers before creation. Its failed-run output did not emit the organization ID or peer count; historical reviews record Ilmora ID `jyssocxpozqlditlaogq`, but those values are not a new output of this run. |
| Health / identity | Passed the runner's bounded project, database, Auth and REST health checks and independent project-detail/list ref/name/organization/region checks; otherwise it could not have reached the database probe. The specific response bodies were not logged. |
| Database route | Validated, passwordless TLS Supavisor **session pooler 5432**, `postgres.<ref>` user, `postgres` database, temporary process `PGPASSWORD`. No direct IPv6, linked mode, transaction port 6543 or credential-bearing URI. |
| Read-only connection probe | Passed, including the expected database/user/version gates. PostgreSQL version and any probe retries were not emitted before the later failure; exact values/count cannot be reported. No probe failure category occurred at the terminal gate. |
| Clean baseline | Roles and schema read-only queries completed before the third query failed; their numeric results were not emitted and the four-part zero-baseline assertion was **not reached**. The migration-history query failed with `PSQL_SQL_ERROR`, exit 3. Foundation Auth-user baseline query was not reached. The target cannot be certified clean from this attempt. |
| Migration dry-run | **NOT RUN**; no pending-version list observed. The expected nine frozen versions remain a source contract, not a managed result of this retry. |
| Migration push / history | **0 pushes**. No migration was applied by the runner. Post-push history was not tested. |
| Security/catalog smoke | **NOT RUN**: 12 roles, 33 tables, 49 policies, 33 ENABLE/FORCE RLS tables, 39 `SECURITY DEFINER` functions, Auth FK and helper owner were not measured. |
| Data API / lint / pgTAP | Initial and final exposed schemas, config drift/apply, both lint levels, pgTAP version and serial tests 01–09 were **NOT RUN**. Hosted assertion total is **not measured**, not 220/220. |
| Hosted Auth / JWT | **0** synthetic hosted Auth users created. Optional real-JWT smoke **NOT PERFORMED**. No service-role key was retrieved. |
| Post-test drift / wrong confirmation / final health | **NOT RUN** because the pre-migration baseline failed. No worker LOGIN role was activated. |

The allowlisted category proves the failing `psql` process emitted text recognized as a SQL error at the migration-history stage. It does **not** preserve the underlying PostgreSQL message or prove a particular missing relation, privilege, or platform cause. Do not patch the frozen migrations or retry another target based on an assumed cause.

## Exact-target failure cleanup

The runner performed a fresh independent target-identity check, sent **one** Management API DELETE for `ateglrfmxeryetelwdhu`, and recorded accepted HTTP **200** at `2026-09-27T11:49:58.362871+00:00`. It did not send a second DELETE. Bounded confirmation completed at `2026-09-27T11:50:07.190938+00:00` with state `CLEANUP_CONFIRMED`: direct detail lookup **404**, target ref **absent from project list**, and all pre-existing peer refs **preserved**. The generated DB password, passwordless URI and token were not written to this document or repository; the runner process ended, dropping its temporary application references. No long-lived credential or worker password was provisioned.

Post-cleanup local guard again returned `FOUNDATION_SOURCE_PASS 9 migrations + 9 tests` and `LOCAL_CONFIG_PASS`. The nine frozen migration files, tests 01–09, Foundation contract, historical reviews, Flutter code and dependencies are unchanged. No migration 10 exists. This review is the only repository change from the retry.

The single authorized P1 retry is exhausted. **P1 has not passed, and P2 is not authorized.** A separate static review should first address the migration-history baseline query and the runner's lack of safe failure-stage value capture; any new disposable managed attempt requires separate authorization. No further project was created in this task.
