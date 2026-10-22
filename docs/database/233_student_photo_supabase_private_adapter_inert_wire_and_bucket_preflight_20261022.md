# Student Photo — Supabase-only private Storage REST adapter preflight (INERT)

**Date:** 2026-10-22  
**PR:** #135 (draft, candidate code), companion [#120](https://github.com/yunusyosaf399/edusync_saas_school_app/pull/120) (owner choice and security documentation)  
**Product decision:** Option A only: **Supabase Storage**, simple authenticated server-controlled API, private storage, no additional AWS/Azure/Cloudflare.  
**Current activity:** Local Python request-planning and synthetic read-back verification only. **No network calls, live bucket, credentials, upload endpoint or F23/Photo SET activation.**

## Exact artifact boundary

- `tools/photo_validation/student_photo_supabase_storage_adapter_candidate.py` is a **credential-free, transport-free Supabase Storage REST contract**. It prepares POST create-only and GET private authenticated read-back request plans **without invoking HTTP**. A deliberately hard-disabled `send()` rejects all invocations; there is no SDK instance, environment-secret loader, edge function or deployed route.
- `tools/photo_validation/tests/test_student_photo_supabase_storage_adapter_candidate.py` uses synthetic local JPEG/PNG bytes and the existing decoded-content validator. It checks 13 positive/negative cases including proposed bucket settings, actual documented relative REST paths, no-upsert, private read-back, content hash/length, replay statuses, unsafe paths, forbidden operations and disabled network.
- The candidate does not expose a server public interface and is **not yet a complete operational upload API**. Existing private API orchestration candidate on #135 still uses a mock bucket, a trusted synthetic authorization callback and process-local idempotency. That is **not** a live JWT, PostgreSQL authorization, multi-instance intent/recovery or F23 state machine.

## Proposed *one-bucket* physical configuration (review only)

| Attribute | Proposed sandbox value | Guard |
|---|---|---|
| School deployment | Dedicated SchoolAgent synthetic US-East Supabase lab | Do not reuse the SchoolAgent staging project or production School |
| Bucket | `edusync-pa02-photo-private` | **NOT CREATED** |
| Public access | `public=false` | Never allow public object URLs |
| MIME restrictions | Candidate `image/jpeg`, `image/png` | Final PA-03 policy review remains open |
| File size limit | **1,048,576 final persisted bytes** inclusive | Current F23 invariant; input/decode bounds need separate review |
| Ordinary Storage client policies | **NONE** at baseline | Do not create broad anon/authenticated SELECT/INSERT |
| Server credential | Deployment secret manager only, **not supplied or created here** | Full service-role / secret bypass of RLS is known |
| Logical location | Trial code `PHOTO_PRIVATE_TRIAL` | **Not** an active F23 allowlist code, no mapping in SQL |
| Physical/key location | `photo/<school-uuid-v4>/<file-uuid-v4>` | UUIDs must originate in trusted server intent, not from Flutter |
| Direct client upload/download | **DENY** | Protected server API only, with live current Student authority |
| Storage object mutation | Only POST create without upsert allowed in candidate | UPDATE/DELETE/UPSERT/COPY/MOVE/LIST never exposed by candidate |
| Post-create ACK | `ACKED_NOT_VERIFIED`, never AVAILABLE | A timeout/failed response remains unknown, not blindly retried |
| Final readback | Private GET, independently verify measured size and SHA-256 | Re-read verified bytes before F23, reject mismatches |

The proposed bucket name, MIME policy and single-bucket mapping are **not yet live configuration or independent PA-02 R3/R4/R6 approval**. A private bucket restricts normal access but does **not** provide WORM protection from a compromised full Supabase project admin or privileged Storage key. The owner explicitly prefers application-level protections instead of another cloud provider. This design **does not claim** native Object Lock, immutable provider versions, credential-compromise resilience or automatically permanent original photos.

## Official provider source grounding

- Supabase [standard uploads](https://supabase.com/docs/guides/storage/uploads/standard-uploads) documents REST POST `/storage/v1/object/{bucket}/{path}`, no-upsert default conflict and `x-upsert` override; the candidate requests `x-upsert: false`.
- Supabase [private buckets](https://supabase.com/docs/guides/storage/buckets/fundamentals) and [serving downloads](https://supabase.com/docs/guides/storage/serving/downloads) distinguish authenticated private retrieval from public URLs; the candidate plans private `/storage/v1/object/authenticated/...` GET.
- Supabase [bucket creation and upload limits](https://supabase.com/docs/guides/storage/buckets/creating-buckets) supports private bucket settings and MIME/size bounds; this PR deliberately does not execute creation.
- Supabase [Storage RLS](https://supabase.com/docs/guides/storage/security/access-control) states that privileged service keys may bypass RLS. This is the reason secrets must remain on the trusted backend, with independent security review before enabling real access.
- The existing [ADR-003](../decisions/ADR-003-provider-neutral-object-storage.md) and [PA-01..08 decision packet](222_student_photo_pa01_pa08_owner_security_decision_packet_20261020.md) remain binding for provenance, server-allocated identity, measured final bytes, current School/Student/Campus scope, historical replacement, durable intent and default DENY.

## How the future trusted server would use the contract (NOT deployed)

1. Resolve **verified current Principal** from server-validated auth, and **current Student / PRIMARY Campus / School permission / capability** from protected PostgreSQL sources. All checks must be repeated before commit.
2. Allocate file UUID/key inside durable one-shot intent; never trust client-submitted bucket or location. The signed School entitlement revision must be current.
3. Accept bounded input through an approved backend-only media path; use the existing sanitized JPEG/PNG validator, strip metadata and remeasure the resulting image bytes.
4. Prepare private POST create-no-upsert request; a separately reviewed transport inserts the server secret from secret manager and performs the actual authenticated write.
5. On any write ACK, lost ACK, conflict or timeout: **do not** assume verified final bytes. A durable reconciler must read exact destination path, measure length and SHA-256, and classify missing/tampered/unknown results safely, never blindly overwriting an old key.
6. With live authorization still valid and final persisted bytes independently verified, advance F23 by its separately approved PENDING → VALIDATED → AVAILABLE workflow; only an independent Student Photo SET command may change the student's selected photo.
7. For a later replacement, allocate a **new** file/key, keep lineage/old evidence as required by retention policy; do not reuse or upsert old object.

## CI and decision gates

The Photo CI workflow checks the inert wire contract and static no-network restrictions. **Passing synthetic CI is not a live Supabase provider test or security signoff.** The following remain OPEN:

- **R3:** approve the single private bucket name, MIME/size settings, logical location mapping and secret-free F23 boundary. Reconcile previous two-bucket design suggestion only as a superseded *candidate*, not a changed production invariant.
- **R4:** independent review of private access, backend secret manager, current Principal/Student/PRIMARY Campus resolution, least-privilege server behavior and acknowledged privileged bypass.
- **R5:** authorize **synthetic-only** real Supabase negative cases in a separate task after bucket and credential approval (wrong School, stale capability, duplicate/no-upsert, lost ACK, response mismatch, private GET, tamper alarm). No real student fixtures.
- **R6:** decide reviewable fixture retention, incident stop, monitoring, quota/billing and explicit teardown authorization. Do not delete preserved evidence without a policy.
- **PA-03..08, D1/F23:** production upload/Photo SET, SQL migration 10 activation, Flutter UI and real Student data remain **DENY** until their distinct frozen security and test gates are satisfied.

### Non-collision and deployment ledger

This code task adds isolated files under `tools/photo_validation`, one documentation entry in PR #135 and a test step in the existing Photo candidate CI workflow. It does **not** touch DB-01 through DB-04 branches, `supabase/migrations`, production `lib/`, existing SchoolAgent staging data, live Supabase buckets or any provider IAM. **Current live US-East sandbox observed 0 buckets / 0 custom Storage policies during preflight.**

**Next permitted task:** inspect PR #135 CI; fix only Photo candidate failures. Once all code checks pass, request a separately scoped approval for creation of the one private **synthetic lab** bucket and independent security/budget/retention review before any real provider-byte test.
