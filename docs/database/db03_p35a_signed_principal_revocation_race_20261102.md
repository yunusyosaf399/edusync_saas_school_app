# DB03 P35A — Signed local Auth and Principal revocation during lock wait

**Date:** 2026-11-02. **Status:** disposable runtime acceptance candidate; inactive Principal operation. **No hosted migration, user permission activation, admission finalization, or Student creation.**

## Purpose and isolation

P33's protected RETURN/REJECT implementation is server-only. P34 (PR #217) covers a rollback-only database authorization chain using an actual `auth.users` row, but simulates request JWT claims. This independent P35A increment uses the existing DB03 `destination_command_ci.py` runner, which actually signs a local Foundation Auth user into Supabase GoTrue and verifies its access token using `SupabaseAuthenticator` before issuing any SQL. It adds a later, disposable-only Principal-final operation fixture, never a production operation seed. P35A changes only that existing CI helper, one new CI Python module, a test fixture and this contract. It does not touch the concurrently active P34 runner or tests.

## Acceptance procedure

1. In the existing **real local GoTrue login** integration harness, the signed token is verified and its authenticated subject/claims are passed to the P35A module (the module does **not** blindly trust caller-provided JWT text).
2. Only in the disposable database, create a dedicated enabled `admission.final.decide` permission, role grant, School-wide direct scope and operation. Reuse the existing Auth-bound individual Principal and Campus; do **not** grant `app.decide_admission_principal` to `authenticated`, `anon`, `service_role`, or any worker.
3. Use an independent PostgreSQL transaction, set the verified subject/claims and `SET LOCAL ROLE schoolos_workflow_executor`. The private `db03_principal_final_actor` must return the exact Principal and **distinct** operation identity; an unscoped Campus must be denied.
4. With another backend holding **exclusive** Foundation authorization advisory lock `(71001,1)`, revoke the Principal role assignment and keep that transaction open. A second backend, using the **same previously verified signed JWT**, must be observed actually waiting with PostgreSQL `wait_event_type='Lock'` while trying the Principal-only actor resolver.
5. Commit the revocation and release the lock. The waiting attempt must deny with the dedicated Principal authorization error. A subsequent request using the **same signed JWT** must also deny, demonstrating that unexpired cached token claims cannot bypass current server-role revocation.
6. Check that **no** Principal decision, final receipt or final outbox row exists and that the public final-decision RPC remains unavailable to authenticated users. Require all 13 concrete checks before printing `DB03_P35A_SIGNED_AUTH_RACE_PASS`.

This is a **genuine two-connection PostgreSQL lock schedule** with one real signed local GoTrue login, not a mock of the database lock or a claim-only unit test. All changes are made exclusively in the temporary disposable stack, which the existing runner stops after acceptance; the authorization fixture is not shipped to production.

## Not established by P35A

- P35A verifies successful **private Principal authorization** and an independently blocked **authorization revocation race**, **not** successful acceptance of RETURN/REJECT. It does not create an actual reviewed Forward or append a final decision. These require P35B positive effects.
- It does not test competing decisions by two different authorized Principals, exact-key successful replay/changed intent conflict, quarantine of a signed original file while waiting, or deliberate rollback after evidence insertion.
- It does not enable `APPROVE` or `student.create`; those require coordinated, atomic DB03→D1 Person/Student/Admission/Enrollment/Roll/document lineage and DB01/DB02 locks, plus independent security review.
- It does not change Finance authoritative settlement or archived document retention.

**Next:** P35B — assemble a complete current reviewed Forward from real measured document uploads, destination and fee declaration, then execute and test one positive RETURN and REJECT per source with idempotency, cross-Principal races, and rollback. Keep all public final-decision permissions disabled until the end-to-end and security gates pass.
