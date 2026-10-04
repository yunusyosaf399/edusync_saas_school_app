# D1C1C Integrated Migration-10 Static Review

**Status: PASS — SOURCE/STATIC CLOSEOUT ONLY.**

D1C1C closes the integrated source-review gate for the ordered, non-executable Migration-10 draft chain. The trusted source/tooling candidate is:

`c3dc47829e2b9a3e967f9b89f21771dd90948820`

This review does **not** claim that PostgreSQL has parsed or executed Migration 10. The entire D1 package remains `.sql.draft`; D1C2 is a separate runtime gate and remains unauthorized.

## Exact-SHA evidence

### D1 Migration 10 draft static

GitHub Actions workflow: `D1 Migration 10 draft static`

- run number: **#9**
- run ID: **37200103059**
- exact head SHA: `c3dc47829e2b9a3e967f9b89f21771dd90948820`
- conclusion: **success**
- D1 draft-guard tests: **9/9 passed**
- final function-state tests: **11/11 passed**
- Foundation source boundary: `FOUNDATION_SOURCE_PASS 9 migrations + 9 tests`
- local config boundary: `LOCAL_CONFIG_PASS`
- source-only staging contract validator: `STAGING_VALIDATE_PASS`

`foundation_staging.py validate` is an offline/source-contract check. It did not contact, mutate or apply anything to a hosted Supabase project.

### Frozen Foundation local stack

GitHub Actions workflow: `Foundation database (local stack)`

- run number: **#218**
- run ID: **37200103019**
- exact head SHA: `c3dc47829e2b9a3e967f9b89f21771dd90948820`
- conclusion: **success**
- tooling tests: **141/141 passed**
- frozen source guard: **9 migrations + 9 tests PASS**
- Supabase CLI pin: **2.98.2 PASS**
- Linux Docker/local stack: **PASS**
- local reset: **nine frozen migrations, no seed**
- Auth fixtures: **5/5 PASS**
- lint: **error PASS; warning PASS**
- Foundation pgTAP: **220/220 passed**, serial execution

Per-file pgTAP remained 44 + 6 + 16 + 16 + 25 + 16 + 33 + 41 + 23 = 220.

## Integrated draft inventory

The source guard reviewed the full lexical Migration-10 chain and reported:

- **197** `.sql.draft` fragments;
- **34** D1 relations;
- **97** permission definitions;
- **322** permission/scope alternatives;
- **36** operation contracts;
- **656** function declarations across the append-only history;
- **638** `SECURITY DEFINER` declarations;
- **39** shared `(71001,1)` authorization-lock calls;
- **3** exclusive `(71001,1)` authorization/bootstrap-lock calls.

All 34 selected D1 relations retain both ENABLE and FORCE RLS in source. No executable `20260928000000_domain_package_01*.sql` migration exists.

## Final function-state reconstruction

Because the append-only continuation chain intentionally contains corrective `CREATE OR REPLACE`, `ALTER FUNCTION ... OWNER TO`, and rename-then-recreate sequences, aggregate declaration counts are not treated as final catalog counts.

The final-state auditor reconstructs the terminal lexical ownership/ACL surface and reported:

- **540** final function names;
- **83** true same-name redefinition families after rename reconstruction;
- **120** `CREATE OR REPLACE` declarations;
- **26** explicit owner transfers;
- **9** function renames retained as separate legacy/base helpers;
- **0** unresolved bare-create collisions;
- **0** argument-shape drift across redefinition families;
- **522** final `SECURITY DEFINER` functions in the reconstructed source state;
- **157** final `app.*` functions;
- **383** final `app_private.*` functions;
- **157** public `app.*` functions with authenticated EXECUTE in the reconstructed ACL state;
- **0** authenticated EXECUTE grants on `app_private.*`;
- **0** unresolved final owners;
- **0** public `app.*` functions reconstructed as owned by `schoolos_schema_owner`.

The nine rename-then-recreate corrections are modeled explicitly rather than misclassified as duplicate bare CREATE statements. The retained names are the eight `*_v0` participant helpers plus `d1_enrollment_move_lock_context_base`.

## Static security/source invariants

The D1C1C guard fails closed on source drift including:

- renaming Migration 10 into executable `.sql` material;
- relation-catalog or 97/322/36 manifest drift;
- missing FORCE RLS;
- invocation of the deployment-owned D1 registrar from Migration 10;
- creation of a premature public `student.create` command;
- `SECURITY DEFINER` declarations without pinned `pg_catalog,pg_temp` search path;
- broad D1 EXECUTE to `PUBLIC`, `anon` or `service_role`;
- direct exposed-role table/schema access to `app_private`;
- unresolved final function ownership;
- authenticated EXECUTE on final private helpers;
- malformed rename/recreate assembly;
- unresolved duplicate bare CREATE function names;
- redefinition argument-shape drift that could mask an overload/signature split.

These are source-level invariants only. PostgreSQL catalog ownership, actual signature resolution, trigger installation, RLS behavior and non-owner runtime behavior remain D1C2 concerns.

## `student.create` dependency boundary

D1C1B remains **36/36 operation contracts accounted**, comprising **35 implemented/frozen D1 effects plus one disabled cross-package dependency**.

`student.create` remains registered disabled and has no public create RPC. It still requires the separately approved future Admissions handoff integration before any runtime activation may be proposed.

## Change-boundary verification

Comparing the Effect-36 freeze commit `ba0577e9459a065d66565ab3a44c4046a71d242c` to the trusted D1C1C source/tooling SHA `c3dc47829e2b9a3e967f9b89f21771dd90948820` shows only seven tooling/CI files changed:

- `.gitattributes`;
- `.github/workflows/domain-draft-static.yml`;
- `.github/workflows/foundation-database.yml`;
- two D1 static analyzers;
- two analyzer test files.

**No Migration-10 `.sql.draft` fragment changed during D1C1C closeout.** Foundation migrations 1–9 and tests 01–09 remain frozen.

## Conclusion

D1C1C passes as an integrated **source/static** closeout at exact SHA `c3dc47829e2b9a3e967f9b89f21771dd90948820`.

Migration 10 remains non-executable and unexecuted. No remote project was contacted by the D1C1C source-only staging validator. D1C2 execution/runtime validation is not authorized by this review.