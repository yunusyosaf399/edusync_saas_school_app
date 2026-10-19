# Student Photo — provider-neutral adapter trust contract and immutable provenance candidate

Date: 2026-10-19. **DRAFT / exact-head CI pending. No production provider or activation approved.** This design and its pure-Python security fixture are isolated from DB-01 through DB-04.

## Frozen baseline and authority

Source `main` = `f38c087b989328f0c871b8ec5707e46ba12a856f`, [PR #104 freeze](219_student_photo_provider_neutral_delivery_recovery_ci_merge_freeze.md). The accepted ADR-003 [provider-neutral storage](../decisions/ADR-003-provider-neutral-object-storage.md), its [architecture contract](../architecture/04_provider_neutral_object_storage.md), and ADR-004 [entitlement revision model](../decisions/ADR-004-storage-plan-entitlements.md) outrank this candidate. The existing PR #94–104 trials proved genuine protected P0/Enrollment END/Campus MOVE lock ordering, native token revocation, backend aborts, lost commit acknowledgements, PostgreSQL outbox state and independently committed **mock metadata**. None uploaded verified bytes or selected a real object provider.

This task adds **a reference interface and fail-closed contract tests** with `LocalPrivateByteProvider` and `LocalAdapterContractTrial`. The provider stores only synthetic **opaque test strings**, not real photographs. `TrustedTestContext` is explicitly a *privileged Python test input*, **NOT** a verified JWT/session or a production authorization token. Its booleans are not usable authority outside the test harness.

## Frozen rules this contract must preserve

- One school per Supabase project; deployment-owned school-specific allowlisted `storage_location_key`; do not add multi-school/provider FK tables or provider credentials to `file_objects`. School, Student, Campus and Principal are bound to server-created immutable upload intent; upload can never choose arbitrary destination, key, school or location.
- `file_objects` metadata remains PostgreSQL-authoritative. Server allocates future file UUID/immutable object key before upload, but creates **no measured file row** until *after* successful byte inspection. File UUID and key are stable for idempotent retries. Immutable uploader provenance is not ownership. Purpose must be semantically checked against a versioned registry, not accepted from the Flutter caller.
- Each new upload/verification gate must check trusted current principal identity, `file.upload`, relevant `student.photo.submit` + Student Profile authority, current PRIMARY Campus scope and typed Student association, enabled module, effective school entitlement snapshot/capability, permitted `STUDENT_PROFILE_PHOTO` purpose and private classification. Expired/stale entitlement denies new use. This is **AND**, not an OR/wildcard. Later provider acceptance cannot waive current Student/Campus authority.
- Byte checks use measured server-side read-back, **not** client-declared MIME/size/SHA-256, provider ETag or a signed URL's mere existence. Approved V1 bound is **1..1,048,576 bytes inclusive**. Actual image decoding/content signature/sanitization/EXIF stripping and malware/quarantine implementation remain explicit activation blockers. Never declare an image `AVAILABLE` on byte length, extension, or hash alone.
- Private staging must be immutable before any `AVAILABLE` transition. An unexpired retry with the same idempotency identity must not overwrite verified bytes. A conflicting payload under the same key denies. `SEALED_TRIAL` is *not* actual `VALIDATED` or `AVAILABLE`. Never infer authorization or permanent download access from opaque object keys.
- Backend credentials/signing secrets reside only in deployment/server secret management, never Flutter, PostgreSQL file rows, application settings, signed URLs, logs or receipts. No SQL provider network calls. Temporary downloads require live domain authorization; no direct anonymous/client bucket/list grants.

## Candidate adapter operations / test-only evidence

| Operation | Required boundary and observable result | Unapproved production choice |
|---|---|---|
| `allocate` | Verified server context binds school, Student, Campus, Principal, future UUID, fixed purpose, PRIVATE classification, deployment-owned location and server object key; no file row yet | Durable intent representation, server API, logical location naming, expiry |
| `put` | Private staging WRITE-ONCE at identity-bound key; measured length inclusive 1 MiB; exact replay after lost provider ACK is tolerated only while STAGED; conflicting bytes and expired/changed authority deny | Upload URL/direct proxy policy, provider conditional PUT mechanics, egress limits |
| `head` | Locate object under immutable key, but ETag and reported length are untrusted assertions | Authenticated provider metadata API, IAM and region/bucket configuration |
| `read_back_for_validation` | **Server** reads stored bytes and computes SHA-256 + actual size; checks injected trusted validator; returns opaque scoped trial evidence only after verification | Real PNG/JPEG decoding, malware/EXIF handling, content allowlist, byte-copy/seal pipeline |
| `seal_trial` | Local object becomes non-overwritable **including with identical data**; any further PUT denied | Provider revision lock/object immutability/versioning and overwrite prevention |
| `verify_receipt` | Local HMAC attestation binds school, Campus, Student, file, intent, logical location, object key, purpose, measured size+hash; mutation denies | Production key format/rotation, provider-authenticated proof and replay domain |
| `quarantine` | Privileged test worker makes object inaccessible and emits test alert without erasing retained evidence or rewriting key | Retention/legal hold, purge permissions, malware quarantine, operational alerting |
| `bounded_reconcile` | Current authorization rechecked; exhausted retry budget fails closed and generates alert; test budget is injected | Production retry timing/backoff, max attempts, SLO, metrics, durable queue/leases |

**Important:** The test HMAC is a *server-side local attestation* made after fake byte read-back, **not a signature emitted by S3, Supabase Storage, R2 or any remote provider**. The fixed test key is non-production. The synthetic validator deliberately accepts a sentinel `OPAQUE-TEST-` prefix and **does not decode JPEG/PNG or sanitize media**; that is why the fixture has no operation to create an actual File AVAILABLE row, upload bytes to a provider, or apply Student Photo SET.

## Threat model and regression suite

New test file: `tools/supabase/tests/test_domain_photo_provider_adapter_contract_ci.py`. Cases include:

- Server-controlled PRIVATE purpose/location/key/UUID allocation with no DB file row or signed URL.
- Lost PUT ACK **after immutable mock write**, same-key retry, conflicting-bytes denial; exact same-byte PUT denied **after** trial seal.
- HEAD/ETag untrusted, actual read-back size/hash mismatch denies, simulated provider byte corruption detected.
- HMAC receipt binding catches changed byte count, digest, signature and object key.
- Changed School, Student, Campus or Principal denied; each of eight context gates (authenticated identity, permission, scope, current PRIMARY, module, entitlement, purpose, file.upload) denies independently on recheck after staging.
- Token/intent expiry denies retries and evidence inspection; 0 or >1 MiB bytes deny, inclusive 1 MiB accepted for **opaque mock bytes only**.
- Missing validator denies; quarantine blocks raw byte visibility but retains historical trial evidence; stale scope and bounded retry exhaustion alert without destructive purge.
- Marker `D1_STUDENT_PHOTO_PROVIDER_ADAPTER_CONTRACT_PASS` runs **after** PR #94–104 genuine PostgreSQL photo gates in disposable D1 CI. Foundation Python tooling also discovers the standalone tests. No SQL migration or changes to protected P0/P1 commands.

The test suite proves that the **reference contract rejects dangerous inputs in local simulation**; it does not prove real provider semantics. A real adapter must show server-controlled conditional/immutable PUT, true byte read-back (or a verifiably immutable equivalent), authenticated provider responses, provider-side overwrite/policy tests, scrub/sanitize/antivirus gates and cleanup across crashes before choosing that adapter.

## Workstream collision and product-decision gates

DB-01 PR #100 Roll Correction, DB-02 PR #101 Roll Policy, DB-03 PR #102 Admissions handoff and DB-04 PR #103 Curriculum own their designs and any approved future domain SQL. This PR owns only `docs/database/220_*student_photo*`, `tools/supabase/domain_photo_provider_adapter_contract_ci.py`, its isolated unit tests and one **late** existing D1 photo CI runner invocation. Do not modify their files, code, or owner decision checklists. Shared eventual Student PRIMARY and Campus scope mutations must continue to pass PR #94–104 race tests once other domain implementations are approved.

**Approval gates remain open**: PA-01 actual provider/SDK and safe conditional/write-once API; PA-02 location/mapping/key custody and staging/final bucket separation; PA-03 real decoded-image validation, stripping, scanning and exact allowed MIME matrix; PA-04 preupload intent durable expiry and idempotency (including ISSUE lost bearer response); PA-05 identity and signed entitlement revisions, upload purpose/module grants and Student scope; PA-06 object reconciliation/retention/legal hold, worker backoff and alarms; PA-07 authenticated receipts/HEAD-readback immutable proof, versioning, later File row lifecycle and photo SET link; PA-08 real provider CI and incident recovery across process/server/region failures. These are **design questions for approval**, not invented production choices.

## Activation and merge constraints

The current protected operations remain **31/35 accepted**; #67 Student Profile Photo SET stays **DENY**. Migration 10 remains `.sql.draft`. No actual file upload, new permission, hosted deployment, SDK or release enablement is allowed by this PR.

Before merging this **test-only** PR, require exact-head Foundation `FOUNDATION_LOCAL_CI_PASS 9 files / 220 planned / 220 passed`, D1 `D1_BUSINESS_PASS 3124 assertions`, all prior accepted Student Photo markers, new `D1_STUDENT_PHOTO_PROVIDER_ADAPTER_CONTRACT_PASS` and `D1C2A_PASS`, plus a narrow disjoint file diff and independent workstream conflict check. Keep a candidate PR draft until confirmed.

**School example:** A student's private test upload goes to a school-specific, server-generated object key. The provider writes the opaque test bytes, but its response is lost. A retry using the same allocated key cannot create new or altered content. Before any trial attestation, the server independently reads back bytes and checks SHA-256; if Campus authorization was revoked or the object changed, the trial denies and can quarantine it. This **does not upload a Student photo**.
