# Foundation deployment productization — P1R2 fresh-project history baseline

**DEPLOYMENT PRODUCTIZATION P1R2 PASS — FRESH-PROJECT MIGRATION BASELINE HARDENED — READY FOR SEPARATE MANAGED RETRY AUTHORIZATION**. This is a local-only runner correction. It did not create or contact a managed project, retry P1, or start P2.

## Starting evidence and scope

- Starting HEAD: `182ecc13b6e92a62352ad305eef6f851513f0511`; worktree clean.
- The separately authorized [P1 retry](05_foundation_productization_p1_retry_review.md) reached `DB_MIGRATION_HISTORY` and stopped with allowlisted `PSQL_SQL_ERROR`, exit 3, before dry-run or push. Its raw hosted stderr was not retained. **The hosted PostgreSQL message remains unknown.**
- The user's local scratch-database reproduction found no `supabase_migrations.schema_migrations` relation: `to_regclass(...)` returned NULL/blank; the old direct count raised `ERROR: relation "supabase_migrations.schema_migrations" does not exist`; an existence query returned `f`. The scratch database was destroyed. This establishes a concrete fresh-database runner defect at the same logical stage. It does **not** prove that the hidden hosted error was identical.

## Narrow fix

`foundation_migration_baseline_count()` checks `SELECT to_regclass('supabase_migrations.schema_migrations') IS NOT NULL;` inside the runner's read-only database wrapper. It accepts only exactly one `f` or `t` result. `f` returns integer **0** without ever querying the absent table. `t` runs the existing count restricted to the nine frozen Foundation versions and returns the validated integer unchanged. Empty, multiple or malformed existence output fails with `BASELINE_HISTORY_EXISTENCE_MALFORMED`; malformed count output fails with `CATALOG_COUNT_MALFORMED`. The helper validates nine unique 14-digit version strings before constructing the count query.

The four-part pre-push baseline still requires `[0, 0, 0, 0]` for School OS roles, `app`/`app_private` schemas, Foundation migration versions, and synthetic Foundation Auth users. A nonzero history count remains a dirty-target failure. Separate stages `DB_BASELINE_MIGRATION_HISTORY_EXISTS` and `DB_BASELINE_MIGRATION_HISTORY_COUNT` distinguish the two read-only checks. **Post-push** history validation is unchanged and still requires the exact nine migration versions; absence of the history table after push is a failure.

## Verification

- Unit tests cover absent table (`f` → 0 with no count query), existing empty table (`t` → 0), existing dirty table (`t` → nonzero preserved and rejected by the outer baseline), malformed existence output and malformed count output. Existing P1R diagnostic, timeout, dry-run/push and cleanup tests remain in the suite.
- Combined tooling tests: `python -m unittest discover -s tools/supabase/tests -v` — **39/39 passed**.
- Foundation static guard: `FOUNDATION_SOURCE_PASS 9 migrations + 9 tests`; `LOCAL_CONFIG_PASS`.
- Local Foundation CI: CLI `2.98.2`, Docker Linux, clean local reset with nine frozen migrations and no seed, five Auth fixtures, error-level lint and warning-level lint all passed. Tests 01–09 passed serially: **9 files / 220 planned / 220 passed** (44, 6, 16, 16, 25, 16, 33, 41, 23).
- No third-party dependency, migration, frozen database test, Foundation contract, RBAC/RLS/function/trigger, Flutter or platform file changed. No migration 10.
- Managed API calls **0**; managed projects created **0**; managed projects contacted **0**; hosted SQL/Auth/migration operations **0**. `SUPABASE_ACCESS_TOKEN` was not used.

The next step after successful local gates and independent review is a **separately authorized one-project managed retry**. This correction alone does not authorize that retry or P2.
