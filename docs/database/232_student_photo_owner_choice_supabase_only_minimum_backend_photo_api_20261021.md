# Student Photo — Product-owner Option A decision: Supabase-only and minimal protected API

**Recorded:** 2026-10-21. **Status:** OWNER PRODUCT DIRECTION CONFIRMED / IMPLEMENTATION AND ACTIVATION UNAPPROVED.
**Scope:** Student Photo PA-01/02 only. Independent of DB-01..04, all SQL migrations, Student Photo SET activation and Flutter rollout.
**Owner wording:** “Option A only, No need alot of security, if we can write an API or something else that can give protection then its okay otherwise no need”.

## 1. Decision and rationale

**Owner-selected provider: Supabase Storage only.** Do not continue pursuing AWS S3, Azure Blob, Cloudflare R2, a hybrid final store, paid final-object retention service, or extra cloud account for Student Photo. The dedicated SchoolAgent US-East Supabase Free-plan lab remains the authorized nonproduction evaluation environment. Keep the accepted ADR-003 provider-neutral interface/metadata schema rather than hard-coding a vendor into file_objects; a single chosen physical adapter is compatible with a provider-neutral business contract.

**Owner risk tolerance:** Favor simple practical application safeguards over hardened provider-enforced WORM / native immutable object versions / protection against compromise or intentional abuse of the cloud-account owner, DB admin, or privileged Storage service key. This is a *product threat-boundary choice*, not a claim that Supabase is immutable. A privileged actor can potentially change or delete stored bytes and private-bucket/RLS protection is not an answer to that threat.

**Still non-negotiable for student photos:** private (not public) file access, authenticated and current School/Student/Campus/Principal/entitlement authorization, server-owned keys, no client service secrets, safe image decoding/re-encoding, actual stored-size/SHA-256 verification and fail-closed F23 lifecycle. Application-level post-validation overwrites must be denied. Existing ADR-003, ADR-004 and #222 frozen rules are not silently downgraded by the phrase “no need alot of security”. If the precise threat-boundary change requires formal revision to an earlier frozen contract, the owner/security reviewers must record that revision explicitly before production activation.

**Engineering direction:** One private Supabase bucket and a thin authenticated backend Photo API is preferred over creating two buckets, exposing signed upload grants to clients, or provisioning a second cloud provider. This is a **proposed implementation pattern**, not yet an owner-approved exact bucket/API schema. Single-bucket logical final objects with unguessable server-allocated unique keys are acceptable for lab evaluation if reviewer confirms no requirement to retain untrusted raw staging in Storage; incoming bytes can remain in short-lived bounded server staging and be discarded after sanitization.

## 2. Simple example

1. A verified Campus A clerk chooses Student A and submits an image to EduSync; the client never chooses bucket, provider, object key or a signed Storage URL.
2. EduSync backend verifies present staff authority, Student's School and PRIMARY Campus, current subscription capability and allowed file purpose.
3. Server safely decodes and re-encodes the image, strips untrusted metadata and checks actual output bytes; final persisted image must be **1 through 1,048,576 bytes** inclusive.
4. Server allocates a never-reused key, writes through a server-only Supabase credential with **upsert=false**, reads final bytes back through a trusted server path and compares SHA-256 and byte count. A write ACK/ETag alone cannot make a file AVAILABLE.
5. Server rechecks current Student authority and entitlement, writes authoritative metadata using the existing F23 PENDING → VALIDATED → AVAILABLE gates, and exposes photo association changes only through the separately protected Student Photo SET command.
6. When the school updates Student A's photo, upload a NEW file/key and follow approved replaces_file_id/history. Do not overwrite the original key through any EduSync endpoint. Retention and deletion of old photos remain subject to the actual adopted policy; no automatic purge is authorized here.

**Important limitation:** Steps 4–6 prevent typical user/API overwrites and detect an unexpected provider byte mismatch at verification time; they do not prevent later project-owner/service-role modification. Do not market the result as native WORM, S3 Object Lock, or indefinite immutable retention.

## 3. Proposed minimal API, not routes deployed

| Route/operation candidate | Client input | Server responsibility | Default denial |
|---|---|---|---|
| photo upload intent / `POST /student-photos/uploads` | Student identifier + photo bytes or approved initiate request | Resolve verified current School/Student/PRIMARY Campus, module, verified Principal, registered purpose; limit input, allocate unique key and durable intent | Anonymous, wrong School, stale grants, oversized/unsafe input |
| upload/finalize operation / backend-only | Trusted durable intent and sanitized server output | One-shot no-upsert private Storage write, independent read-back/checksum, current authority recheck, F23 lifecycle | Repeat/stale intent, tampered key, remote UNKNOWN, bytes not verified |
| `GET /students/{studentId}/photo` | Student identifier | Current-role authorization, controlled private file proxy or **short-lived** download URL after fresh check | Public listings, permanent URLs, foreign Student/Campus access |
| existing protected Student Photo SET command | Verified new available file ID / reviewed history | Preserve old photo, write new relation only with current authority, record lineage | Direct mutation of Storage object or arbitrary provider path |

These are illustrative API boundaries, **not** a commitment to exact HTTP paths, database handlers, or new general-purpose upload table. Reuse current EduSync authorization, idempotency/receipt and immutable-file history contracts; do not invent conflicting DB-01–04 locks or modify their branches.

## 4. Recommended low-complexity security implementation and acceptance tests

- **Private bucket:** proposed lab name `edusync-pa02-photo-private`, `public=false`. No client public read/list/upload policies. Only the trusted backend can use the credential. The single-bucket pattern replaces #229's earlier **two-bucket proposal** as the recommended lab design; neither topology has been provisioned or signed off.
- **Backend authentication/authorization:** verify JWT/user server-side; never trust raw user_metadata for business grants. Apply current domain and entitlement checks at both request and finalization. Supabase `service_role`/new secret key remains backend-only; it can bypass RLS and is never a client token.
- **No direct client Storage writes:** upload via the existing trusted server layer; allocate random unique keys; never expose create/delete/upsert routes and never store signed URLs or Storage secrets in `file_objects` or Flutter.
- **Safe bytes:** image signature/full decode/sanitization and size bound are mandatory; owner has not yet chosen exact PNG/JPEG-only/image dimension policy. Final stored bytes must be re-read and hashed; failures stay private and unavailable, with bounded retries and audit.
- **No overwrite in application:** always allocate a new file ID/key on photo replacement, forbid final UPDATE/UPSERT/MOVE/COPY/DELETE in EduSync API except an independently approved retention administration path. A server-side code rule **is not** a privileged Supabase account guarantee.
- **Small lab test suite:** positive synthetic JPEG/PNG when formats are approved; anonymous denied; wrong-School denied; stale Campus/permission denied; malicious file rejected; oversized final file rejected; duplicate/replay denied; same-key second PUT no-upsert conflict; privileged tamper demonstrates known residual risk; read-back SHA and size; safe new-key replacement; no Student data or real upload activation.
- **No false shortcuts:** Do not mark security PASS based only on `upsert=false`, SDK success or no visible RLS policy. Strict cross-domain races/reconciliation tests in #222/#223 remain separate release gates and must be completed or explicitly revised by authorized owners; product simplicity does not certify them.

## 5. Decision ledger and supersession

| Topic | State after this user decision |
|---|---|
| Provider for Student Photo evaluation | **OWNER CHOICE: SUPABASE ONLY (Option A)**; no alternate/hybrid provider work |
| Malicious full-account admin / leaked broad privileged key defeating file immutability | **OUTSIDE OWNER-DESIRED HARDENING SCOPE** for initial practical API design; risk disclosed; any conflict with frozen semantics must be formally reconciled before release |
| Backend proxy API and new object keys for replacements | **ENGINEERING RECOMMENDATION**, not yet implemented |
| Single private photo bucket, no direct client Storage policy | **ENGINEERING RECOMMENDATION**, not yet created |
| PA-02 private bucket / API details (R3) | Product provider selection recorded; exact mapping and policy implementation **OPEN** |
| PA-02 IAM and security review (R4) | Backend-only credential rule required; independent acceptance **OPEN** |
| PA-02 real-provider tests (R5) | **NOT RUN** |
| PA-02 retention and teardown (R6) | **OPEN**; no default purge of evidence |
| PA-03 decoder / PA-04 intent / PA-05 grants / PA-07 lifecycle / PA-08 release | **OPEN** |
| Production F23/Student Photo SET and migration 10 | **DENY / NOT ACTIVATED** |

**Supersedes only the earlier engineering suggestion** in #230/#231 to *prefer trying AWS S3/Azure/R2 as final providers*. Their comparative technical facts remain archival evidence; no competing storage vendor should be pursued without a new explicit owner decision. This is not independent security approval or a final amendment to accepted architectural requirements.

## 6. Next scoped development task

Perform a fresh noncollision review against the implementation baseline, then create a **non-activating backend Photo API design/adapter skeleton and synthetic-only tests on a dedicated Student Photo implementation branch/PR** (not inside DB-01–04), after the required interface/policy review. First implement safe one-use create and read-back against a mock, then separately authorize the real Supabase private bucket and runtime tests. Never enable photo uploads or spend beyond the existing Free lab without an explicit next-step approval.
