# D1C1B Effect 21/36 — Student Restricted Identity security review

**Status: IMPLEMENTATION CANDIDATE — NOT FROZEN.**

Effect 21 adds no permission, scope alternative, role, operation contract or event vocabulary. The frozen manifest remains **97 permissions / 322 scope alternatives / 36 operation contracts**.

`student.identity.correct` and `student.identity.approve` use the frozen non-family-safe ACS scope family. The candidate requires one current effective PRIMARY placement and derives Campus/Class/Section from stored ancestry. A complete live grant/scope chain is required; assignment or enrollment existence alone grants nothing. Reviewer authorization is bound to the configured reviewer role as well as the matching Student scope.

The operation is P2 only. A current source restricted-identity snapshot is mandatory. Submission, review and explicit apply are separate phases. Requester/reviewer Person separation is enforced. Apply rechecks current requester authority, all approved reviewers, policy, Student version and exact predecessor facts. Deterministic stale conditions become `APPROVED -> INVALIDATED` with a REJECTED apply receipt; malformed protected payload or unclassified failure rolls back.

Terminal replay requires current requester or exact final-approver authority and does not repeat mutation/evidence. Idempotency hashes bind Student ID, all proposed restricted facts, birth-certificate file reference and reason; changed intent conflicts with the retained key.

Sensitive values remain only in the protected request/snapshot domain. Broad audit and outbox do not copy national ID, birth-certificate number, private address/city, guardian identity/contact, arbitrary reason or file object internals. The success event carries only Student/snapshot/source identifiers and effective time. The event aggregate is the new `STUDENT_IDENTITY` snapshot at version 1.

Birth-certificate validation uses a narrow schema-owner predicate for AVAILABLE `BIRTH_CERTIFICATE` file metadata and retains the existing structural purpose trigger. Neither the FK nor this correction grants upload/download access.

No authenticated direct table DML is granted. Migration 10 remains `.sql.draft`; no D1 runtime execution or remote/staging action is authorized by this review.