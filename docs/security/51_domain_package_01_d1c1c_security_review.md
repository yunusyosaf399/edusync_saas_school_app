# D1C1C Integrated Security Review

**Status: PASS — STATIC SECURITY CLOSEOUT ONLY.**

This review records the final source-level security posture of the ordered Migration-10 `.sql.draft` chain at trusted source/tooling SHA:

`c3dc47829e2b9a3e967f9b89f21771dd90948820`

It is not PostgreSQL runtime evidence. D1C2 remains the separate gate for actual parse/application/catalog/RLS/non-owner execution testing.

## Exact-SHA security evidence

D1 static workflow run **#9** (`37200103059`) completed successfully on the exact trusted SHA.

The integrated source guards established:

- **34/34** selected D1 relations retain ENABLE and FORCE RLS statements;
- manifest remains **97 permissions / 322 scope alternatives / 36 operation contracts**;
- Migration 10 remains non-executable `.sql.draft` material;
- the D1 registrar is defined but not invoked by Migration 10;
- `student.create` remains disabled with no premature public create RPC;
- all **638** detected `SECURITY DEFINER` declarations use the pinned `pg_catalog,pg_temp` search path;
- no source-level D1 EXECUTE grant to `PUBLIC`, `anon` or `service_role` survives the guard;
- no direct exposed-role `app_private` table/schema access passes the guard;
- shared/exclusive Foundation authorization lock calls remain visible in the chain.

The function final-state reconstruction reported:

- **540** final function names;
- **522** final `SECURITY DEFINER` functions in reconstructed source state;
- **83** same-name redefinition families;
- **120** `CREATE OR REPLACE` declarations;
- **26** explicit owner transfers;
- **9** rename-then-recreate corrections;
- **0** unresolved bare CREATE collisions;
- **0** redefinition argument-shape drift;
- **0** unresolved final owners;
- **157** final `app.*` functions;
- **383** final `app_private.*` functions;
- **157** reconstructed authenticated `app.*` EXECUTE surfaces;
- **0** reconstructed authenticated `app_private.*` EXECUTE surfaces;
- **0** reconstructed public `app.*` functions owned by `schoolos_schema_owner`.

## Rename/redefinition security handling

The append-only chain contains deliberate corrective sequences where an earlier private helper is renamed to a retained `_v0` or `_base` name and a corrected helper is then created under the original name.

D1C1C models those renames explicitly. This prevents a false duplicate diagnosis and, more importantly, prevents the final ACL/owner reconstruction from merging the retained legacy helper with the corrected helper.

`CREATE OR REPLACE FUNCTION` is treated as preserving existing owner/ACL state unless a later explicit owner or grant/revoke statement changes it. This is necessary because a safe earlier owner/ACL does not become irrelevant merely because a body is later replaced.

The additional signature-shape invariant fails closed if a same-name redefinition changes the declared argument shape, because that could represent a second overload rather than replacement of the reviewed function.

## Privilege boundary

The reconstructed final source state preserves the intended split:

- `app.*` is the typed authenticated API surface;
- `app_private.*` remains executor/internal only;
- broad runtime roles do not receive private helper EXECUTE;
- schema-owner-owned functions do not appear in the final public `app.*` surface;
- final function ownership resolves only to reviewed `schoolos_*` roles.

The owner distribution is source-audit evidence, not a live `pg_proc`/ACL catalog query. D1C2 must verify the actual installed catalog after PostgreSQL has parsed/applied the candidate.

## Foundation concurrency and regression boundary

The D1 chain retains the selected Foundation authorization advisory lock discipline:

- SHARED `(71001,1)` for D1 business execution paths;
- EXCLUSIVE `(71001,1)` for bootstrap/authorization administration paths.

Exact-SHA Foundation workflow run **#218** (`37200103019`) passed at the same trusted SHA with:

- **141/141 tooling tests**;
- frozen Foundation source integrity;
- **5/5 Auth fixtures**;
- lint error/warning gates;
- **220/220 Foundation pgTAP assertions**.

This proves Foundation regression safety at the trusted source/tooling SHA, not D1 runtime correctness.

## Admissions / Student-create boundary

`student.create` remains intentionally fail-closed pending the later Admissions package. No client approval flag, arbitrary payload, caller-supplied admission identifier, generic administrator bypass or direct base-table route becomes a substitute for the frozen final Admissions handoff contract.

D1C1C adds no Student-create public EXECUTE surface.

## Remote/staging boundary

`foundation_staging.py validate` returned `STAGING_VALIDATE_PASS`, but that mode validates committed source/contract material only. It did not use a management token, contact a hosted project, apply SQL or change runtime configuration.

No staging/managed D1 application is authorized by this review.

## Security conclusion

The ordered Migration-10 draft chain passes the D1C1C **static security** gate at trusted SHA `c3dc47829e2b9a3e967f9b89f21771dd90948820`.

The remaining uncertainty is intentionally moved to D1C2: real PostgreSQL parse semantics, installed ownership/ACLs, trigger and constraint behavior, RLS under non-owner roles, concurrency behavior and protected command execution must be proven there before any runtime freeze can exist.
