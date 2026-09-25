# Foundation managed preflight — CLI connection-path review and M1 retry plan

**Verdict: CONNECTION PATH PASS — SESSION POOLER DB-URL APPROVED FOR FRESH M1 RETRY.** This is a static connection-model decision, not a managed migration-compatibility result. No managed project was created, linked, queried, or contacted in this review. The nine migrations remain unexecuted on managed Supabase.

## Source and observed failure

- Reviewed clean repository HEAD: `9913ca76482c31ce9489e4f52ce4403ca55edd36`. Installed Supabase CLI: `2.98.2` (`supabase --version`); it was not upgraded.
- Installed `supabase db push --help` exposes `--db-url string` (a connection string that must be percent-encoded as needed), `--dry-run`, `--linked` (default `true`), and `--local`. Thus the pinned binary supports both `--db-url` with `--dry-run` and `--db-url` for an actual push. Installed `supabase link --help` exposes `--project-ref` and `--skip-pooler`; linking is a distinct operation and does not force `db push` to use a pooler.
- [Review 17](17_foundation_managed_throwaway_m1_retry2_review.md) records one linked dry-run that selected `db.<project-ref>.supabase.co:5432` over IPv6 and timed out while writing the PostgreSQL startup message. It produced no pending-migration list and executed no migration SQL. A separate read-only PostgreSQL 17.6 session through Supavisor **session mode on port 5432** succeeded; DB, Auth, and REST were healthy. The throwaway was destroyed. This was a **CLI/direct-network connection failure**, not a SQL, privilege, or migration-compatibility finding.

## Pinned CLI behavior

The matching [CLI v2.98.2 flag registration](https://github.com/supabase/cli/blob/v2.98.2/cmd/db.go) marks `--db-url`, `--linked`, and `--local` mutually exclusive. `--dry-run` is independent. Although `--linked` defaults to true in help, an explicitly supplied `--db-url` takes precedence; **do not also pass `--linked`**. In [v2.98.2 connection parsing](https://github.com/supabase/cli/blob/v2.98.2/internal/utils/flags/db_url.go), the explicit URL branch loads the local config and calls `pgconn.ParseConfig` on the supplied value. It does not load a project ref or construct `db.<ref>.supabase.co`; that construction belongs to the linked branch. The internal name `direct` for this branch means an explicitly supplied database URL, not the Supabase direct endpoint. A checkout with its existing `supabase/config.toml` is needed, but **M1 does not require `supabase link`**.

The [v2.98.2 push runner](https://github.com/supabase/cli/blob/v2.98.2/internal/db/push/push.go) passes that parsed config to `ConnectByConfig` for both dry-run and push. It uses the connection to inspect pending migrations and, on push, applies them through the same connection. [Migration application](https://github.com/supabase/cli/blob/v2.98.2/pkg/migration/apply.go) resets connection settings between migration files; [migration batches](https://github.com/supabase/cli/blob/v2.98.2/pkg/migration/file.go) include the history insert and are implicitly transactional. The source shows no direct-host rewrite or direct-only requirement on this path. It does **not** prove that a future managed database will allow the migrations' role and ownership operations.

## Connection mode and session semantics

[Supabase connection guidance](https://supabase.com/docs/guides/database/connecting-to-postgres) describes the direct `db.<PROJECT_REF>.supabase.co:5432` endpoint as IPv6 by default, with IPv4 support available separately. Direct is the usual migration choice, but this workstation's latest direct IPv6 attempt timed out. The supported shared Supavisor **session pooler** uses a project-specific `postgres.<PROJECT_REF>` username and port **5432** on the project's advertised pooler host. It offers an IPv4-compatible path and retains a database backend for the lifetime of a client session. The pooler host must come from that fresh project's official Connect information; do not guess its cluster index or reuse a prior project's host.

That session affinity is the relevant property for `SET ROLE`, `RESET ROLE`, effective-user observations, object ownership under the current role, session-level advisory locks if used, and any state spanning SQL statements or transaction boundaries. `ALTER DEFAULT PRIVILEGES`, transactional migration batches, and migration-history writes still run under PostgreSQL's normal authorization rules. Session pooling does not grant missing authority or change `postgres` membership. The pinned runner's one connection is compatible at the **connection-model** level; its managed authority is unmeasured. Session-level state should be checked during the actual retry if the migrations expose a failure.

The shared **transaction pooler on port 6543** is excluded from this experiment. Transaction pooling can assign different backends between transactions and is documented for short-lived workloads, with limitations such as prepared statements; it is not the appropriate route for a chain that deliberately uses role/session behavior. [Supabase pooling guidance](https://supabase.com/docs/guides/database/connecting-to-postgres/pooling-and-limits) and the [session-mode port notice](https://supabase.com/changelog/32755-supabase-connection-pooler-deprecating-session-mode-on-port-6543-on-february-28-2025) distinguish session mode on 5432 from transaction mode on 6543. A paid dedicated IPv4 option and workstation/network reconfiguration are alternatives, not prerequisites or the default retry plan. Keep CLI `2.98.2` for experiment continuity.

## URL, TLS, and credential handling

The conventional full URI shape is `postgresql://postgres.<PROJECT_REF>:<PASSWORD>@<POOLER_HOST>:5432/postgres?sslmode=require`. **Do not pass that password-bearing form to `--db-url`: command arguments can appear in process listings, shell transcripts, or diagnostic output.** Instead, use the passwordless form below as the CLI argument and supply the password through the temporary child-process environment variable `PGPASSWORD`:

```text
postgresql://postgres.<PROJECT_REF>@<POOLER_HOST>:5432/postgres?sslmode=require
```

The pinned CLI depends on `github.com/jackc/pgconn v1.14.3` ([go.mod](https://github.com/supabase/cli/blob/v2.98.2/go.mod)); its [`ParseConfig` implementation](https://github.com/jackc/pgconn/blob/v1.14.3/config.go) accepts `PGPASSWORD` when the URL does not contain a password. This is distinct from the linked CLI's `SUPABASE_DB_PASSWORD` handling. `sslmode=require` requests TLS, as described by [Supabase SSL guidance](https://supabase.com/docs/guides/database/connecting-to-postgres); it does not by itself establish full server-certificate hostname verification. Use the officially supplied pooler host and do not silently substitute another endpoint.

For the fixed future components, `postgres.<PROJECT_REF>` (validated project ref), an official DNS pooler hostname, numeric port, `postgres` database, and literal `sslmode=require` contain no characters requiring percent encoding. Any future variable URI component containing reserved characters must be encoded by a URI builder, not manual escaping. Keeping the password out of the URI avoids the most error-prone encoding case. Do not print the constructed URI together with a password, place a password in a tracked file or command argument, or run `--debug` with live credentials; debug output has not been proven safe. Generate and hold the disposable password only in process memory, set `PGPASSWORD` only for the narrow `psql`/CLI invocation scope, and clear it afterward. Do not save a full connection URI, key, token, or credential in the review.

## Future fresh-target M1 retry procedure — not executed here

1. Start from the approved source and a new isolated clean worktree. Recheck the pinned CLI, `.gitattributes`, all nine migration blob IDs, canonical SHA-256 values, and LF materialization against [review 15](15_foundation_managed_source_integrity_review.md). Create exactly one new disposable target only after those gates pass, under the separate M1 retry authorization.
2. Verify target identity independently from management-plane project **name, ref, organization, region, and status**, and from the project's official session-pooler Connect information. Confirm the pooler hostname, port 5432, and username suffix match the intended fresh ref. No old target ref, host, or credential may be reused. Do not link the worktree for M1.
3. With the same passwordless session-pooler URI and temporary `PGPASSWORD`, run an explicit `BEGIN READ ONLY` baseline through `psql`: record `current_database()`, `session_user`, `current_user`, PostgreSQL version, Auth availability, and absence of School OS roles, schemas, versions, and test Auth users. Cross-check hosted API exposed schemas and service health independently. A read-only `psql` session narrows route and credential uncertainty but does **not** prove the exact identity or authority that CLI will exercise.
4. Recheck target name/ref, URI host/username/ref, and migration hashes immediately before the CLI call. Run the dry-run **without `--linked`** and require exactly the nine frozen versions in order, no seed or extras:

   ```text
   supabase db push --dry-run --db-url <PASSWORDLESS_SESSION_POOLER_URI>
   ```

5. Only if that dry-run passes, use the **same pooler URI and temporary `PGPASSWORD`** for exactly one actual push, with no seed, reset, repair, manual SQL fallback, or second push after failure:

   ```text
   supabase db push --db-url <SAME_PASSWORDLESS_SESSION_POOLER_URI>
   ```

6. Stop on the first meaningful connection, SQL, or privilege error; capture redacted evidence and use the fresh disposable project as the rollback boundary. If push succeeds, perform only the separately authorized M1 smoke checks. Do not infer M2 clearance from M1. Clear the password environment variable and retain or destroy the target according to that future task's outcome.

The explicit URI points the CLI at the same **connection route** used for baseline inspection, avoiding the linked mode's direct-host selection. It does not prove that the two clients have identical effective identity or that managed deployment will accept `CREATE ROLE`, LOGIN role creation, grants to `postgres`, `SET ROLE`, `ALTER DEFAULT PRIVILEGES`, `CREATE SCHEMA AUTHORIZATION`, the Auth foreign key, or migration 9. Those remain empirical gates for the next throwaway attempt.

**Scope:** No managed project or former throwaway was contacted; no hosted URL, password, key, token, or project ref was used; no dry-run or push ran; no migration, test, configuration, application code, or earlier review was changed. The next separately authorized task is `FOUNDATION MANAGED SUPABASE THROWAWAY PREFLIGHT — SESSION-POOLER M1 DEPLOYMENT RETRY`.
