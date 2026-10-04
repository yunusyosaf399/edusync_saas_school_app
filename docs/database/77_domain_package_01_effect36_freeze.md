# D1C1B Effect 36/36 — Student Create Dependency Freeze

**Status: FROZEN AS DISABLED CROSS-PACKAGE DEPENDENCY.**

Effect 36 freezes the final D1C1B ledger item, `student.create`, without pretending that the operation is executable before the Admissions package exists.

Trusted runtime boundary remains Effect 35 runtime SHA `97e6eb7d8329475861fd3b4c0f7fc5f7e7c175c7`. Effect 36 introduces **no SQL/runtime delta**.

## Frozen contract

- `student.create` remains a deployment-owned operation contract and stays disabled.
- Successful future invocation requires a trusted, final, unused Admissions handoff.
- No client approval flag, caller-supplied application/admission identifier, arbitrary JSON or administrator bypass can substitute for that handoff.
- One handoff may produce at most one Student; retries must be duplicate-safe.
- The future protected effect must atomically validate/consume the handoff, allocate permanent Student identity, create Student + initial status + accepted PRIMARY placement + roll, enforce capacity and placement rules, and commit approved evidence.
- The actor must satisfy both current `student.create` and `student.enrollment.place` authorization for the exact resulting context.
- School Student ID remains server allocated. Internal UUID, school Student ID, Admissions number/serial and roll remain distinct identities.
- Student creation creates no Family relationship/access/membership/context and no Foundation grant/role/scope side effect.
- Broad `student.created` evidence must remain field-minimized and must not carry restricted identity, guardian/private contact, birth-certificate content or arbitrary Admissions payload.

## Ledger closure

The frozen D1B4 test contract permits an operation to be accounted for by a documented disabled dependency and explicitly identifies `student.create` pending Admissions.

Accordingly:

- **36/36 operation contracts are now accounted for in D1C1B.**
- **35 operation effects are implemented/frozen in the current Migration-10 draft runtime material.**
- **1 operation (`student.create`) is a frozen disabled cross-package dependency.**

This is a design/integration closure, not a successful runtime implementation claim.

## Exact change boundary

Effect 36 is documentation-only. No `.sql.draft`, RPC, table, trigger, policy, grant, worker, Flutter code, Admissions schema or placeholder implementation is added.

Foundation migrations 1–9 and tests 01–09 remain frozen and unchanged. Manifest counts remain **97 permissions / 322 permission-scope alternatives / 36 operation contracts**.

Migration 10 remains `.sql.draft` and unexecuted. D1C2, remote/staging application and worker activation remain unauthorized.

The next authorized engineering gate is **D1C1C integrated Migration-10 closeout/static audit**, preserving `student.create` as disabled pending the later Admissions integration.

**`DOMAIN PACKAGE D1C1B EFFECT 36/36 FROZEN — STUDENT.CREATE ADMISSIONS DEPENDENCY ACCEPTED; RUNTIME ACTIVATION DEFERRED`**
