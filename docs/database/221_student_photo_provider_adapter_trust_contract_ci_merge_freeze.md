# PR #105 — Student Photo provider adapter trust / synthetic-byte provenance CI merge freeze

Date: 2026-10-19. **ACCEPTED: local-only contract reference and disposable synthetic-byte/mock-provider security tests. NOT an actual media uploader, provider implementation, File AVAILABLE, Student Profile Photo SET or hosted production deployment.**

## Provenance, correction and narrow merge

- Previous frozen `main`: `f38c087b989328f0c871b8ec5707e46ba12a856f`, [PR #104 freeze](219_student_photo_provider_neutral_delivery_recovery_ci_merge_freeze.md).
- [PR #105](https://github.com/yunusyosaf399/edusync_saas_school_app/pull/105) exact corrected and successful CI head: **`1e2a3400ab002d3844ec9b2d75138cae78f0acb8`**.
- Initial candidate head `bf0fa93eb4577e1153f443258bbae6bba1cbffbe` failed both tool-suite workflows because the local runner invoked an undefined `_check` helper. This was corrected with a strict Boolean assertion helper; the initial failed head was **not** accepted.
- Premerge gates verified prior `main` unchanged, PR open/draft/mergeable at exact head/base; reviewed diff of exactly four intended files, no public grant, direct Enrollment mutation, SQL migration, RLS-disable or DB-01–04 file collision. Moved to ready-for-review only after both exact-head workflows succeeded.
- SHA-guarded merge successfully returned `6618886a39782c3bf6c8a60c1d38414c25a02f2b`. Independently checked `main` at this merge SHA, PR closed/merged and exactly four reviewed changed paths:
  1. `docs/database/220_student_photo_provider_adapter_trust_contract_candidate.md` — reference contract, threat model and pending PA-01–PA-08 approval decisions.
  2. `tools/supabase/domain_photo_provider_adapter_contract_ci.py` — disposable, standalone private-byte mock and test-only attestation, not a real provider or upload API.
  3. `tools/supabase/domain_student_photo_real_pg_handoff_ci.py` — invokes this local-only test marker **after** all PR #94–104 genuine PostgreSQL photo tests.
  4. `tools/supabase/tests/test_domain_photo_provider_adapter_contract_ci.py` — 14 fail-closed Python tests against the synthetic adapter.

## Exact-head successful workflow evidence

- [Foundation database local stack #39238452530](https://github.com/yunusyosaf399/edusync_saas_school_app/actions/runs/39238452530) **COMPLETED SUCCESS**: `FOUNDATION_LOCAL_CI_PASS 9 files / 220 planned / 220 passed` and 313 Python tests.
- [D1 Migration 10 local runtime #39238452507](https://github.com/yunusyosaf399/edusync_saas_school_app/actions/runs/39238452507) **COMPLETED SUCCESS**: `D1_BUSINESS_PASS 3124 assertions`, 153 Python tooling/source tests, all ten previously accepted Student Photo integration markers through PR #104, **`D1_STUDENT_PHOTO_PROVIDER_ADAPTER_CONTRACT_PASS`**, final `D1C2A_PASS`; Migration 10 remains non-executable `.sql.draft`.

## Exactly what was proved in the reference mock

- Future Student Photo upload intent identity, School, Student, Campus and initiating Principal are bound to server-generated UUIDv4 file/intent identities and a mock school-specific PRIVATE logical key. Allocation does **not** create a validated file record.
- Synthetic opaque *test-only* bytes are accepted into a local staging object with deterministic same-key replay after a committed-but-lost mock provider response; conflicting bytes deny. After local `SEALED_TRIAL` attestation, even identical repeat PUT denies. `SEALED_TRIAL` is not a real storage-provider immutable seal, `VALIDATED` or `AVAILABLE`.
- Neither an ETag nor unverified HEAD metadata is accepted as SHA-256 proof. The local fixture reads back its own stored bytes, checks the measured 1..1,048,576 inclusive byte bound and SHA-256 against an expected digest, and calls a synthetic test validator; an altered byte stream denies.
- Test-only local HMAC receipt binds school, Student, Campus, intent/file UUID, PRIVATE logical key/location, purpose, byte count and digest. Forged size/hash/key/signature deny; **this receipt is not issued by a real provider**.
- A changed Principal, School, Student, Campus, expired intent or any separately disabled authentication/permission/scope/PRIMARY/module/entitlement/purpose/`file.upload` test-context Boolean denies on recheck. Those Booleans are *injected trusted CI fixtures*, not production or verified identity/entitlement integrations.
- Mock quarantine removes test raw-byte access without pretending to erase retained historical attestation. Retry budget exhaustion and lost permission cause local alerts. The test does not purge remote objects or implement operational SLO.
- The marker runs after all prior real D1 PostgreSQL Principal, token, P0/P1 Enrollment END and Campus MOVE, backend abort, outbox, synthetic provider and compensation tests. There is **no new production application command** or SQL.

## DB-01..DB-04 workstream collision check

Before merge, current PRs #100 (DB-01 Roll Correction), #101 (DB-02 Roll Policy), #102 (DB-03 Admissions) and #103 (DB-04 Curriculum) were open and unmerged; their diff files remained in distinct `docs/database/db01_*`, `db02_*`, `db03_*` and `db04_*` paths. **No overlap** with the four PR #105 files; no branch/PR was modified or merged by this workstream. Proposed owner decisions there remain open. Future implementation altering Student PRIMARY or Campus state must rerun the native Photo permission/lock/race tests.

## Hard nonactivation and recommended next bounded review

ADR-003 and ADR-004 remain authoritative. No real object-storage provider/SDK selection, signed provider response, HTTP/SDK/cloud tests, verified production identity, entitlement snapshot, `STUDENT_PROFILE_PHOTO` semantic registry activation, approved user-action grants, JPEG/PNG image decoding, EXIF/content sanitization, malware scanning, actual bytes-to-PG File metadata seal, `file_objects` AVAILABLE, Student Profile Photo SET, signed upload URL, credential, bucket, hosted Supabase write or Flutter feature was delivered.

The next independent task is a **product/security approval decision packet for PA-01–PA-08** (provider IAM and write-once staging, server identity and signed entitlement snapshots, verified bytes/decoded image provenance, provider receipts/retry, orphan cleanup/retention, and real end-to-end D1 photo apply). After decisions are approved, introduce a separately reviewed implementation spike against a selected sandbox provider—never merge live activation from this mock.

**Project state unchanged:** 31/35 protected operations accepted; Student Profile photo SET #67 DENY, DB-01 Roll Correction #68, DB-02 Roll Policy #69 and DB-03 Admissions handoff #70 not yet accepted. D1 Migration 10 remains `.sql.draft`. All real Student Photo uploads and Photo SET remain disabled.

**School example:** The local server fixture allocates a private Student Photo object key. A synthetic provider acknowledges the byte write only after an indistinguishable retry; the test reads bytes back, verifies hash and seals this disposable object against future overwrite. It does not place or display a real Student photograph.
