# Student Profile photo — decoded-content validation candidate (post-PR85)

Date: 2026-10-17. **Status: isolated Python file-service validation candidate; no upload/finalization endpoint, entitled photo SET, public RPC, active migration or hosted deployment.**

## Why this slice is necessary

PR #85's [synthetic ownership/campus/purpose provenance gate](189_student_profile_photo_provenance_ci_merge_freeze.md) confirmed SQL-side current Student placement and authorization, but expressly **did not validate decoded image content**. Its fixture supplied synthetic SHA-256 and byte counts; those values do not prove real media content. The owner-approved [storage taxonomy](../architecture/05_storage_entitlements_and_document_purposes.md) calls for IMG = JPEG/PNG with decoded-content verification and S1 = 1..1,048,576 verified bytes.

This proposal implements the independent local file-service **byte validation and sanitization component** in `tools/photo_validation/student_photo_content_validation_candidate.py`. It does not modify PR #85's SQL predicate or allow photo linking. It is test-only.

## Exact checks

- Input must be actual immutable `bytes`, size within S1, declared purpose **STUDENT_PROFILE_PHOTO** and MIME precisely `image/png` or `image/jpeg`. MIME alone is not accepted as proof of content: check PNG or JPEG magic plus format-specific terminal marker.
- A pinned Pillow decoder independently reads the data twice, first `verify()` for container integrity, then `load()` for **full pixel decoding** (particularly important for JPEG). Mismatched declared/decoded formats, truncated inputs, PNG CRC failures, PDF masquerading as PNG, trailing appended payloads, animated PNG frames and corrupt images reject. Pillow's unsafe `LOAD_TRUNCATED_IMAGES` setting is rejected, and decompression warnings become errors.
- As a provisional *test-only decoder memory guard*, reject image dimensions over 4 million decoded pixels; this is **not yet an owner-approved commercial/IMG product limit** and must be reviewed before enabling a server endpoint.
- Strip EXIF/GPS/text/metadata by decoding, orientation-correcting and **re-encoding** as an image. Recheck the verified output size/format within S1. Return the **sanitized bytes** and server-calculated output length, SHA-256, MIME and dimensions. The trusted storage adapter must persist those exact returned bytes, never the caller's original file or a caller-supplied hash. The candidate itself does not write any file/object metadata.
- Normal images and adversarial input are generated in-memory by the tests, not downloaded or drawn from student records. Tests demonstrate JPEG/PNG full decode, output SHA-256, metadata removal, signature/type mismatch, PDF/nonimage, corruption, truncation, append-only polyglots, malformed input, oversized byte buffers, disallowed purpose, animated PNG and a fake client checksum.

## CI isolation

The separate `.github/workflows/student-photo-content-candidate.yml` sets Python 3.12 and installs pinned `Pillow==12.3.0` **only in its local CI job**; it executes the eight real decoder regression tests. The frozen Foundation, D1 runtime and D1 draft-static workflows gain path triggers for `tools/photo_validation/**`, so source changes cannot evade their pre-existing source/runtime protections. No global production dependencies or package versions are changed.

## Hard production blockers

1. The trusted per-school upload-intent issuance/finalization service, versioned purpose manifest and control-plane signed `student_photo.upload` entitlement snapshot remain **DESIGN ONLY**; this candidate is not a replacement. No user-selected Student UUID, MIME, metadata, byte hash or file key can prove ownership or subscription entitlement.
2. Content validation cannot prove a photograph is semantically a *portrait* rather than a pictured contract or identity document; the Student-purpose binding and human/domain policy still govern that. For production, security engineers must review decoder sandboxing, resource quotas/dimensions, dependency patch process and storage of sanitized output.
3. Real end-to-end Student file issuance/commit and positive `DIRECT`/`APPROVAL APPLY` linking, current file state and true concurrency/downgrade/revocation races remain unresolved. **The frozen typed Student Profile PHOTO SET continues to deny.**
4. Separately approved additive purpose-specific provenance/history/intent-seal schema, executor grants, file retention/legal erasure policy, checked forensic reads and independent app/security acceptance remain outstanding.

**Baseline remains frozen:** 31/35 protected operations accepted; Issue #67 open; 34 D1 relations, 228 Migration 10 draft fragments, 97 permissions, 322 scope alternatives, 36 contracts; Migration 10 inactive, hosted Supabase unchanged.

**Simple example:** Someone tries to upload a document named `student.png` that actually contains PDF bytes. This decoder refuses it even if the declared MIME is `image/png`. A genuinely decoded, correctly sized PNG is sanitized and its real SHA-256 is computed, but still cannot be linked to a Student without separately validated Student ownership and subscription entitlement.
