# D1C1C Security Freeze

**Status: FROZEN — STATIC SECURITY BOUNDARY.**

Trusted source/tooling SHA:

`c3dc47829e2b9a3e967f9b89f21771dd90948820`

## Frozen security invariants

- Migration 10 remains non-executable `.sql.draft` material and has not been applied.
- All **34** selected D1 relations retain source-level ENABLE + FORCE RLS.
- Manifest remains **97 permissions / 322 scope alternatives / 36 operation contracts**.
- All **638** detected `SECURITY DEFINER` declarations pin search path to `pg_catalog,pg_temp`.
- Final-state source reconstruction reports **540** final function names and **522** final `SECURITY DEFINER` functions.
- Final-state reconstruction reports **157 `app.*` / 383 `app_private.*`** functions.
- Reconstructed authenticated EXECUTE is **157 public / 0 private**.
- No final public `app.*` function is reconstructed as owned by `schoolos_schema_owner`.
- No final function owner is unresolved.
- No dangerous `PUBLIC`/`anon`/`service_role` D1 EXECUTE grant survives the static guard.
- No direct exposed-role `app_private` table/schema grant survives the static guard.
- **83** true final same-name redefinition families are reconstructed in lexical order.
- **9** rename-then-recreate corrections are modeled as separate final functions.
- **0** unresolved bare-CREATE collisions remain.
- **0** declaration argument-shape drift remains across same-name redefinitions.
- Foundation authorization lock discipline remains SHARED for D1 business work and EXCLUSIVE for bootstrap/auth administration.
- `student.create` remains disabled pending the trusted final Admissions handoff and has no temporary public RPC.

## Exact-SHA evidence

D1 static run **#9**, ID `37200103059`: **PASS**.

- D1 source tests: **9/9**.
- final function-state tests: **11/11**.
- Foundation source guard: PASS.
- local config guard: PASS.
- source-only staging contract validator: PASS.

Foundation local-stack run **#218**, ID `37200103019`: **PASS** on the same exact SHA.

- tooling tests: **141/141**;
- Auth fixtures: **5/5**;
- lint error + warning gates: PASS;
- Foundation pgTAP: **220/220**;
- local stack reset used the nine frozen Foundation migrations with no seed.

## Freeze limits

This freeze is deliberately not runtime proof. It does not establish:

- PostgreSQL parse success for Migration 10;
- installed `pg_proc` owners/ACLs;
- actual trigger/constraint installation;
- D1 RLS results under non-owner sessions;
- command/workflow concurrency behavior;
- runtime catalog counts after assembly/application;
- managed Supabase compatibility of Migration 10.

Those are D1C2 concerns.

Foundation migrations 1–9 and tests 01–09 remain frozen. No Migration-10 draft fragment changed during D1C1C closeout.

D1C2, hosted/staging application and worker activation remain unauthorized until separately approved.

**`DOMAIN PACKAGE D1C1C SECURITY FROZEN — STATIC OWNERSHIP/ACL/RLS SOURCE BOUNDARY PASS; RUNTIME PROOF DEFERRED TO D1C2`**
