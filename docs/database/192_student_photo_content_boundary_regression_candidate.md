# Student Profile photo — additional decoded-content regression boundaries (quarantined)

Date: 2026-10-17. **Candidate; exact-head CI and independent review required before freeze.** This is a local test extension of the already-merged PR #86 decoded-image component and does not enable upload or Student photo SET.

## Purpose and scope

The existing isolated Python validator tests already prove JPEG/PNG decoded content, sanitized output and measured server-side SHA-256. This next test-only slice closes three remaining regression gaps without changing validator code or its provisional resource-limit semantics:

1. **JPEG EXIF orientation and privacy:** generate a JPEG with orientation 6 and private text metadata. Assert the sanitized photo pixels are rotated to the correct dimensions, the private text and EXIF tags are removed, and the returned SHA-256 matches the actual sanitized bytes.
2. **PNG transparency:** generate a non-sensitive RGBA test image and assert alpha survives decoding and re-encoding while image dimensions remain bound to the result.
3. **Decoded-image resource ceiling:** generate a highly compressible valid PNG under the frozen S1 byte ceiling but just above the *provisional* four-million-pixel decoder guard; require a closed denial. This is a candidate implementation safety guard, **not an approved new commercial image dimension limit**.

All test images are generated in memory. No real student photograph or record is read or stored.

## Boundaries preserved

Only `tools/photo_validation/tests/test_student_photo_content_validation_candidate.py` is changed by this test slice. The production domain/RPC schema, Foundation/D1 migrations, permissions, entitlement logic, and provider-neutral storage adapter remain unchanged.

**Do not activate** a Student photo upload or SET based on this evidence. The live trusted upload issuance/finalization service, actual Student-bound ownership, signed control-plane entitlement revision/fencing, provider storage of *exact sanitized bytes*, successful DIRECT/APPROVAL file-link tests, privacy/forensic/retention review, and genuine two-session races are separate required gates. The provisional pixel maximum, sandboxing and decoder lifecycle still need production review.

Frozen acceptance count remains **31/35** protected change operations; Issue #67 remains open; Migration 10 remains `.sql.draft`, not hosted/applied. This PR is eligible for independent review only after its exact-head local photo + D1 static + D1 runtime + Foundation checks pass.

**Example:** A portrait JPEG carrying a camera-rotation flag and embedded private text must emerge correctly oriented without the camera metadata. A tiny compressed PNG that would decode to too many pixels must be refused. Neither result grants permission to upload a photo for a Student.
