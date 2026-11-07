# DB03 P46B-2B2A — Exact Principal APPROVE → consumed Student handoff lineage

**7 November 2026. Inactive, deny-all schema prerequisite. Does not create or approve a Student.**

## Problem solved

P44 retained the exact published policy. P45 linked a final handoff to the policy and admission-number allocation. P46A/B verified Forward/Intake lineage, revision history and Principal preflight. But nothing yet compelled a **committed APPROVE source** to be bound one-for-one to a **CONSUMED** handoff for the exact application, Forward, policy snapshot, receipt, application version and stage epoch.

This patch creates that relational contract without making approval callable.

## New proposal

`app_private.admission_principal_approvals` is a private, forced-RLS, deny-all history table: one immutable APPROVE source per application. It references one approved application's exact P44 policy snapshot, including its **same final approval command receipt**, application version, stage epoch and Forward.

A mandatory `principal_approval_id` on `admission_student_handoffs` and reciprocal eight-column FK ensure that each handoff refers back to the **same** approval source, application, Forward, snapshot, command receipt and version/epoch.

Both sides also reference the same `handoff_id`. A bidirectional, `DEFERRABLE INITIALLY DEFERRED` FK cycle requires the rows to exist *together at COMMIT*. The approval-side FK references handoff state `CONSUMED` specifically, so an approval cannot commit with an unconsumed READY handoff. This inherits P38's CONSUMED shape: non-null D1 Student ID, consumption receipt and consumed timestamp. The existing D1 Student FK remains deferred to COMMIT as designed.

Do not interpret this as proof that every D1 enrollment/roll/seat business invariant is implemented. A later protected writer must create and check them explicitly, with all effects in one transaction.

## Existing protections deliberately unchanged

- P44 immutable policy snapshot write-deny + forced RLS.
- P38 immutable Admissions/D1 handoff write-deny + forced RLS.
- P41 admission-number series/allocations write-deny + forced RLS.
- S5 `db03_unsubmitted_policy_null` CHECK: the mutable application still has no policy version.
- Existing Principal `RETURN`/`REJECT` history remains separate. No APPROVE event is inserted into its deny-only record type.
- No command, permission, new role grant, external `app.*` RPC, Student update, enrollment allocation, or production migration.

## CI

30 pgTAP assertions check exact foreign keys, source keys, state restriction, deferred cyclic integrity, denied client/worker privileges, forced RLS, denied row/TRUNCATE mutations, older safety fences and empty history. The DB03 runner injects a failed install transaction and confirms that new table/constraints/column roll back, before installing in a disposable local DB and running the assertions. This **does not yet test a positive Principal approval, concurrent enrollment, real Student creation or end-to-end rollback**.

## Final positive approval still requires

1. Typed Principal `APPROVE` command with current JWT+role/permission/campus, read-committed authorization fence, idempotency and lock order.
2. Live policy preflight, canonical Person, independently reviewed documents, destination/Section capacity, tests/interviews skip outcomes and owner-approved admission-fee status; do not infer that MARKED_PAID is a settled bank payment.
3. An authorized and append-only policy snapshot + single approval command receipt/audit/outbox, same-source approved record and handoff.
4. Collision-safe admission-number series mutation, permanent number allocation and D1 Student, first enrollment, Section and roll creation, with consumption evidence. Ensure no Student existed for the canonical Person.
5. On any error all effects roll back, and a same-key replay returns one stable result; different-intent reuse conflicts. No partial READY/APPROVE/Student persistence.

**Release status:** proposal `.sql.draft`, not an executable migration. Child PR targets draft parent #102 only; neither `main` nor hosted Supabase is changed.
