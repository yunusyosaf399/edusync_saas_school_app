# P46B-2B2B2 — Rebased Principal APPROVE binding intent (inactive)

Recovered the distinct read-only policy-binding intent candidate from draft PR #238 onto PR #102 at f71a5d0. The original PR #238 diverged and was not directly mergeable. Existing P48 revision fence, P49 Principal preflight, P50 approval/consumed-handoff lineage and P51 dual D1 authorization remain authoritative and unchanged.

# DB03 P46B-2A — exact Principal approval policy-binding intent

**7 November 2026. Inactive private read-only source. NOT a positive binding writer.**

## Why this increment exists

P46A identifies the exact published policy, both numbering profiles, configuration hash and retained Forward → document Intake. P46B-1 adds mandatory composite foreign keys to future policy snapshots. But policy provenance alone does not authorize Student creation: the Principal must have current authority and see a current verified identity, independently reviewed documents, grade destination and fee declaration.

The owner requires Principal APPROVE to commit the policy binding, admission number, canonical Student and initial enrollment/roll as **one atomic database transaction**, or none. A standalone snapshot writer today would risk a binding with no Student. The P44 writer and the S5 NULL policy projection therefore remain closed.

## Change

- A private SECURITY INVOKER function named app_private.db03_principal_policy_binding_intent(application_id, expected_version, forward_id).
- It composes the already-tested private sources for Principal approval inputs, the exact forwarded policy and the retained document-review source.
- It checks agreement on the current Application/version/epoch, School, Academic Year, exact Forward, Person identity resolution, document clearance, destination intent, explicit fee declaration, published policy and two numbering profiles.
- It retains the original policy configuration hash. It **does not** choose a newer policy or accept a caller-selected policy.
- It computes a deterministic intent hash over these source identities when the inputs agree. This fingerprint is a read-only diagnostic, **not** an actor authorization, signature, receipt or finalized binding. Any future writer must recompute it with locks.
- UNPAID, SKIPPED and MARKED_PAID are treated as documented admission-fee declarations; MARKED_PAID is not proof of official Finance settlement and UNPAID may proceed to future approval.
- All result variants keep actor_authorized_to_bind, policy_binding_committed, atomic_student_handoff_available, can_bind, can_approve and can_create_student as false.

## Validation

31 rollback-only pgTAP assertions include private ownership/ACL, safe search path, invoker mode, current-source composition, missing/invalid input rejection, P44/P46B-1 structural preservation and no new Student/Principal/public command.

An injected failed-install rollback probe verifies this function is not left installed after an aborted transaction. The complete disposable DB03 CI stack runs the test on the exact PR commit.

These tests are **not** yet positive end-to-end Principal approve/Student creation acceptance.

## Next: P46B-2B and final approval

The future authorized writer must use a documented lock order, re-check the signed-in Principal's currently effective permission and original private documents, validate application version and stage epoch, produce exact replay-safe receipts/audit/outbox, and atomically write the P44 policy snapshot alongside the P38/P45 handoff, admission number allocation and D1 Person/Student/initial enrollment/roll effects. It must explicitly reconcile the S5 draft policy NULL constraint and existing S10 admission fee guard without weakening unrelated security.

No live/hosted Supabase migration, main branch merge, public binding API, or production Student record is changed in this increment.


## Current boundary

This change adds **only** a private source-consistency digest. The digest is not an authorization token, signed receipt, snapshot writer or Student creation effect. The final protected writer must recompute under the reviewed lock order, verify live Principal plus dual D1 authority, and atomically allocate Admissions and D1 numbers, create Student/status/PRIMARY Enrollment/roll, consume the handoff and append receipt/audit/outbox. No live migration, grant, approval, number issue or deployment.
