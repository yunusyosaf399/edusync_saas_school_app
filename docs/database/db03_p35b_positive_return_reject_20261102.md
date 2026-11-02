# DB03 P35B — Positive server-only Principal RETURN/REJECT with measured upload

**Date:** 2026-11-02. **Status: disposable candidate, not production activation.**

Base: DB03 draft parent PR #203 at `551cb3e33772009bed66b55572b809b8db7670af` (P34 and P35A already integrated). D1 / DB01 / DB02 integration PR #168 remains separate.

## What P35B exercises

The existing DB03 disposable `destination_command_ci.py` runs a real Supabase GoTrue local password sign-in, then checks its access token against the local Auth endpoint with `SupabaseAuthenticator`. P35A proves the private Principal operation is revoked after a real PostgreSQL authorization lock wait. **After** that denial test, P35B installs only transaction/test-stack-scoped document permissions on the *existing* synthetic administrator and restores the earlier fixture's revoked grants; it never registers roles or permissions on a hosted school.

The new `principal_positive_decision_ci.py` provisions a local signed entitlement, private archive and real file worker. For each of two new applicant drafts, it attempts to: (1) prepare the published admissions policy, (2) record an explicit `UNPAID` admission-fee declaration (not payment or Finance clearance), (3) record a typed current Campus Grade offering, (4) upload a valid original PDF through `AdmissionDocumentService` and check that the file worker confirmed `AVAILABLE`, and (5) Forward using the actual application version and private document snapshot. These are real service paths and not inserted synthetic `AVAILABLE` rows.

With an actual signed local Auth subject, the test invokes the **private, fixed-owner** P33 Principal final command under `schoolos_workflow_executor`, not through an `authenticated` client grant. It targets one real Forward for RETURN and a separate real Forward for REJECT. Acceptance checks require a retained immutable P29/P31 decision, exact-key replay without duplicate effects, canonical-payload conflict denial, a second decision on the same Forward denied, RETURN's correction-pending state, REJECT's terminal state and post-reject admission mutation denial. Each decision must map to one successful receipt, audit and outbox record via the same application ID. No Student command is invoked.

## Boundaries

This is the first **positive final-decision transaction** acceptance candidate. It is *not yet* a full independently verified document review: the signed and measured PDF is uploaded and Forwarded, but the test does not assert that a separate human examiner has completed review and clearance. That is a distinct future gate.

This test still does **not** test two Principals competing on the same real Forward; no inter-session positive RETURN vs REJECT race, different-key conflicting submission during a lock wait, changed document quarantine before decision, nor injected post-insert evidence failure is included yet. Those remain P35B continuation gates. It does not implement positive APPROVE, trusted Finance settlement, Student creation, DB01/DB02 roll allocation, or D1 atomic handoff.

Most importantly, although the private command is invoked by this disposable test, **there is still no EXECUTE permission for `authenticated`, `anon` or `service_role`**, and no production seed for `admission.final.decide`. Do not treat a green source or runtime test as permission to release this feature. Separate owner acceptance, completed adversarial concurrency and independent security review must precede activation.

**Checks:** exact two real decisions for separate original-blob-backed Forwards, per-application decision/receipt/audit/outbox evidence, retry conflict and lifecycle denial. Failures should block DB03 draft candidate runtime, and all disposable Auth, fixture, file, and School state are wiped at stack shutdown.
