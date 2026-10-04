# D1C1B Effect 36/36 — Student Create Security Freeze

**Status: FROZEN.**

Effect 36 freezes `student.create` as the one intentionally disabled cross-package D1 dependency. Runtime activation is deferred until a separately approved Admissions package provides a verified final handoff and the resulting integration is reviewed.

Trusted runtime boundary remains Effect 35 runtime SHA `97e6eb7d8329475861fd3b4c0f7fc5f7e7c175c7`. Effect 36 has no SQL/runtime delta and therefore claims no new runtime validation.

## Frozen security invariants

- The operation remains disabled; there is no temporary Student-create RPC or denial stub counted as a successful implementation.
- A future success requires trusted server-side verification of a final, unused Admissions handoff.
- Client booleans, arbitrary JSON, caller-supplied application/admission identifiers or generic administrator override cannot satisfy the handoff requirement.
- One handoff may create at most one Student under a race-safe exactly-once/single-consumption contract.
- Future application requires both current `student.create` and current `student.enrollment.place` authority for the exact destination context.
- Permanent school Student ID remains server allocated; internal UUID, school Student ID, Admissions identifiers and roll remain separate namespaces.
- Initial Student status, accepted PRIMARY placement, roll allocation and capacity enforcement are one atomic business effect; partial success is forbidden.
- Student creation does not grant Family authority or create Foundation roles/grants/scopes.
- Broad `student.created` evidence must be field-minimized and exclude restricted identity, guardian/private contact, birth-certificate content and arbitrary Admissions payload.
- Effect 36 adds no public EXECUTE surface, executor privilege, RLS relaxation, direct base-table DML path or service-role business bypass.

## D1C1B closure

The approved D1B4 test contract explicitly permits a documented disabled dependency for `student.create` pending Admissions. The operation ledger is therefore **36/36 accounted**, while executable/frozen current Migration-10 draft effects remain **35 plus one deferred dependency**.

The manifest remains **97 permissions / 322 permission-scope alternatives / 36 operation contracts**. Foundation migrations 1–9 and tests 01–09 remain unchanged.

Migration 10 remains non-executable `.sql.draft` material and unexecuted. D1C2, remote/staging application, worker activation and the Admissions package remain unauthorized by this freeze.

Next gate: **D1C1C integrated Migration-10 closeout/static audit**, with the disabled `student.create` dependency preserved exactly.

**`DOMAIN PACKAGE D1C1B EFFECT 36/36 SECURITY FROZEN — STUDENT.CREATE REMAINS FAIL-CLOSED PENDING ADMISSIONS`**
