# DB03 P34 — Real Auth-bound Principal-final authorization acceptance

**Date:** 2026-11-02. **Status:** rollback-only disposable acceptance candidate; *not* an activated school operation.

Based on DB03 #203 merged P33 at `152e5322929ef62b4fab1b913f999fa7c33e2f37`. This PR adds no SQL migration or production permission. PR #168's DB01/DB02/D1 stack is untouched.

## Purpose

P33 has a private, typed RETURN/REJECT handler with idempotency and source/evidence checks. Its 30 pgTAP tests verified deny-only access and structural security, **not** that a separately authorized, real Auth-linked school Principal can pass the P30 authority reader or that revocation takes effect. P34 fills the *Principal authentication and authorization* part of that missing acceptance. It is **not** yet a successful committed RETURN/REJECT end-to-end or a two-connection concurrency race.

## Precisely what the test exercises

A transaction-scoped fixture uses the existing pinned Foundation `auth.users` subject `foundation-rbac-001@example.invalid`, binds it to the existing synthetic Principal in the `policy_publication_actor` fixture, and creates a **test-only**, distinct `admission.final.decide` permission, current Principal role grant, direct scope and operation. It enables that operation **only inside the rollback-only test transaction** and adds a current expiration claim to the disposable JWT. It never registers these rows in migration or hosted configuration.

The 19 pgTAP assertions verify:
- The final operation is inaccessible before this fixture, then an actual Auth-backed Principal has a non-null authority digest and the correct dedicated operation ID under a valid JWT.
- The future private workflow executor can resolve the authenticated Principal. The same identity can create an ordinary draft via the existing admission permission; a direct server-only attempt to REJECT that unforwarded draft correctly stops at the current-Forward gate, leaving neither a Principal decision nor a final receipt.
- Principal role-assignment revocation, disabling the dedicated operation, or revoking the final permission grant independently removes current authority.
- A Campus-only final assignment authorizes the assigned Campus but not another Campus.
- An expired JWT and an unbound Auth subject fail Principal actor resolution.
- Even after test-only operation registration, `authenticated` still has **no EXECUTE** on `app.decide_admission_principal`.

The runner expands only the three explicitly named fixture files, executes everything on the existing disposable DB03 integration database, verifies 19 TAP assertions and rolls back. Source validation rejects a test without `ROLLBACK`, an unexpected test count, extra fixture scopes or a fixture that grants final RPC EXECUTE. No hosted environment, production role/permission, migration, or merge to main is touched.

## Explicitly outstanding before permission activation

1. Build a **positive** RETURN and REJECT fixture that creates actual reviewed document files, exact current Forward, approved destination and required detail sources. Prove an authenticated Principal can append one immutable decision + one receipt/audit/outbox atomically and that its result is safely replayed.
2. Use multiple independent database sessions in CI to prove lock waiting, authorization/grant revocation **during** a wait, simultaneous different-Principal decisions and opposite outcomes, same-key retries, changed-intent conflict, stale Forward, file quarantine, correction/return and School-policy changes.
3. Inject a database failure after immutable decision insertion and verify no decision, receipt, audit or outbox remains. Confirm no final effects leak in queues after terminal REJECT and resubmission requires a genuine revision.
4. Only after these tests and owner-reviewed final-role provisioning, consider activating distinct `admission.final.decide` and an `authenticated` EXECUTE grant for RETURN/REJECT. This PR intentionally does neither.
5. APPROVE must remain unavailable until **one transaction** also creates Student/ID/admission number/first Enrollment/Roll and private-document lineage with DB01/DB02 D1 coordination. P34 adds no D1 mutation.

**Bottom line:** Passing P34 demonstrates real Auth-backed **positive Principal authority** and a **safe negative decision attempt without a Forward**. It does **not** demonstrate successful acceptance of RETURN/REJECT, concurrency correctness or atomic Student creation.
