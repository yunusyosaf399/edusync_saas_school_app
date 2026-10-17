# Student Profile decoded JPEG/PNG content validation candidate — exact-head CI/merge freeze

Date: 2026-10-17. **Verdict: local-only real image decoding/sanitization component ACCEPTED AS TEST EVIDENCE, MERGED and FROZEN. Not an operational upload, trusted entitlement validator, or enabled Student Profile photo SET.**

## Repository and exact-head proof

- [PR #86](https://github.com/yunusyosaf399/edusync_saas_school_app/pull/86) merged the exact four-check tested head `e37d4d330acab8034fa5758ee1263f805056a962` into prior `main` `ada6d0fdaf20b1b91d43e3ba6bb0bed958281098`, with GitHub merge SHA `41ddc767dc510083297fbbe30a846c644fac9029`.
- **All four exact PR-head pull_request workflows succeeded:**
  - [Student photo decoded-content candidate #39032985518](https://github.com/yunusyosaf399/edusync_saas_school_app/actions/runs/39032985518): **SUCCESS**. Inspected `Ran 8 tests` and `D1_STUDENT_PHOTO_CONTENT_CANDIDATE_PASS decoded JPEG/PNG, sanitized bytes and measured SHA; upload remains disabled`. Decoder pinned to Pillow 12.3.0 for this CI job only.
  - [D1 local runtime #39032985547](https://github.com/yunusyosaf399/edusync_saas_school_app/actions/runs/39032985547): **SUCCESS**. Inspected `D1_BUSINESS_PASS 3124 assertions`, `D1C2A_FOUNDATION_REGRESSION_PASS 220/220`, `D1C2A_CATALOG_PASS tables=34 rls=34/34`, prior `D1_STUDENT_PROFILE_PHOTO_PROVENANCE_GATE_PASS`, `D1_STUDENT_PROFILE_APPROVAL_INTENT_SEAL_PASS`, `D1_STUDENT_PROFILE_TYPED_APPROVAL_HISTORY_PASS` and terminal `D1C2A_PASS`.
  - [Foundation local #39032985539](https://github.com/yunusyosaf399/edusync_saas_school_app/actions/runs/39032985539): **SUCCESS**, `FOUNDATION_LOCAL_CI_PASS 9 files / 220 planned / 220 passed`.
  - [D1 draft static #39032985517](https://github.com/yunusyosaf399/edusync_saas_school_app/actions/runs/39032985517): **SUCCESS**, `D1_DRAFT_STATIC_PASS 228 fragments; 34 relations; 97 permissions; 322 scope alternatives; 36 operations` and `D1_FUNCTION_FINAL_PASS`.
- Verified exact-head PR diff: **seven files**, zero active migration edits and zero newly introduced trailing whitespace. Added the isolated `tools/photo_validation/` Python candidate + adversarial unit tests, dedicated pinned Pillow test workflow, [design #190](190_student_photo_decoded_content_validation_candidate.md), and path-only source triggers in the existing D1 static, D1 runtime and Foundation workflows. No executable SQL, existing RPC, production library requirement or hosted database alteration.

## Precisely established

The frozen photo provenance predicate from PR #85 validated metadata and current Student scope but did not see actual object bytes. The new isolated Python candidate checks **real** decoded PNG/JPEG bytes, not file extensions or client MIME strings. It requires the approved STUDENT_PROFILE_PHOTO purpose; strict JPEG/PNG magic, terminal marker and declared/decoded MIME agreement; S1 initial **and sanitized output** sizes 1..1,048,576 inclusive; full decoder verification **plus** actual pixel loading; denial of malformed/truncated/nonimage or animated PNG content; and conservative provisional decoded-pixel resource ceiling.

The candidate strips image metadata, re-encodes the decoded image and returns the exact sanitized bytes, MIME, measured output length, width/height and a **server-calculated SHA-256 of the sanitized stored bytes**. Its tests reject a PDF disguised as PNG, cross-MIME JPEG/PNG, corrupt PNG checksum, truncated JPEG/PNG, appended HTML payload, unapproved domain purposes, unsupported MIME, oversized raw buffers, nonbytes and animated PNG. Its tests also verify metadata stripping, positive decoded PNG/JPEG and stable byte/hash consistency. No student media or records were used in tests.

## Product activation remains explicitly blocked

1. **No trusted school file-service issuance/finalization, actual provider storage adapter, accepted Student-bound upload intent, signed versioned control-plane `student_photo.upload` entitlement snapshot, current school/module or approved purpose registry enforcement** was implemented in this task. This verifier cannot establish any of those facts. Its API does not accept client-provided hashes or Student binding claims.
2. PR #85's **synthetic** Student/file/school provenance rows are not live upload ownership evidence. The successful conditional SQL predicate plus successful content decoding remain two separate test components, not an accepted end-to-end uploaded portrait or a file linked into the Student row.
3. Production review must approve decoder dependency lifecycle, sandboxing, provisional 4-million-pixel resource ceiling, policy for re-encoding and metadata removal, agreed backend transactional and key-integrity contract, actual verified content-hash binding and malware/content safety service where applicable. Content verification does not determine whether the image semantically depicts a student.
4. Owner-approved Student photo SET still **denies by default**, including the typed DIRECT and APPROVAL paths. Required remaining work: current entitlement/multi-instance fencing, trusted immutable exact Student ownership issuer, read vs downgrade semantics, live two-session upload/finalization/permission races, positive file-link APPLY with fresh scope, independent privacy/security review and additive versioned schema release/retention/forensic access.

**Frozen baseline:** **31/35** accepted protected operations; Issue #67 still open; 34 D1 base relations, 228 Migration 10 draft fragments, 97 permissions, 322 scope alternatives and 36 operation contracts unchanged. Migration 10 remains `.sql.draft`. No hosted Supabase change.

**Example:** A PDF file renamed `portrait.png` is rejected during actual image decoding. A valid PNG is decoded and sanitized; its real stored-byte hash is calculated. It **still cannot be attached to a Student** until an independently authorized, entitled and Student-bound upload is finalized.
