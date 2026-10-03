# D1C1B Effect 21 — Student Restricted Identity Security Freeze

**Status: FROZEN**

Trusted runtime implementation SHA: `08a5c2c6912170738f1ded9e809e01d8dc8d6150`.

Exact-SHA GitHub Actions run **#53** (`37096183204`) completed successfully with 121/121 tooling tests and 220/220 Foundation pgTAP assertions. The run checked out the trusted SHA exactly.

`student.identity.correct` remains P2 REQUIRED_REVIEW with separate `student.identity.approve`; there is no DIRECT route. Requester/reviewer Person separation, current authority recheck, deterministic approved-request invalidation, terminal replay semantics and application-receipt binding follow the hardened P2 contract.

Student scope uses the frozen ACS model from stored PRIMARY placement ancestry: ALL, matching CAMPUS, matching CLASS or matching SECTION may authorize according to the exact live grant/scope chain. Enrollment existence itself grants nothing. The caller cannot supply ancestry to widen scope.

The protected effect is CORRECT-only and requires one current open restricted-identity snapshot. It closes that predecessor at apply-time and appends one successor at the same instant. No-op correction is denied. Birth-certificate file linkage must remain purpose `BIRTH_CERTIFICATE` and AVAILABLE; the FK relationship does not create upload/download entitlement.

Broad receipt/audit/outbox evidence excludes raw national/B-Form identity, birth-certificate number or file metadata, private address/city, guardian identity/contact and arbitrary reason. Successful event `student.identity_corrected` aggregates on the retained `STUDENT_IDENTITY` snapshot, version 1.

Effect 21 adds no new permission, scope alternative, role, operation contract or event vocabulary. The frozen manifest remains **97 permissions / 322 scope alternatives / 36 operation contracts**.

Migration 10 remains `.sql.draft`; this freeze does not authorize D1C2 or remote/staging execution.
