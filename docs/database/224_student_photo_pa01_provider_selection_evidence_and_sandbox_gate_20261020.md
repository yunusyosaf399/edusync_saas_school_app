# Student Photo PA-01 — Storage-provider evidence, shortlist and sandbox selection gate

**Reviewed:** 2026-10-20.  
**Status:** **PA-01 RESEARCH COMPLETE / SUPABASE STORAGE PREFERRED FOR FIRST SANDBOX / PRODUCTION PROVIDER AND SECURITY APPROVAL PENDING**.  
**Parent owner/security decision packet:** [#222](222_student_photo_pa01_pa08_owner_security_decision_packet_20261020.md).  
**Implementation and test-gate matrix:** [#223](223_student_photo_provider_activation_dependency_and_test_matrix_20261020.md).  
**Source snapshot:** repository `main` `df1c98d5c2d19424946986fc6ba7615202b0a443`; this review is independent of DB-01–04 PRs #100–103 and of non-executable Migration 10 drafts.

## 1. Scope and method

PA-01 asks **which provider and precise write-once API can demonstrate a server-authorized immutable private object across concurrent writes, retries, ambiguous acknowledgements and a later verified-object seal**. PA-01 is *not* the choice of a commercial SaaS plan, a School's data residency, the current default Storage location, the JPEG/PNG validator, the entitlement policy or Photo SET. These have their own PA-02…08 gates. This document compares **vendor-published API behavior**, not measurements from EduSync infrastructure: no provider credentials were accessed, no buckets were created, no network PUT was performed and no provider SDK was added.

**Frozen EduSync invariants (ADR-003/004 and F23):** one isolated School project; deployment-owned logical location; server-allocated immutable file ID/key; private bytes; provider-independent PostgreSQL `file_objects` (PENDING only after actual final bytes are measured, later protected VALIDATED→AVAILABLE); fixed `STUDENT_PROFILE_PHOTO` purpose; current verified Principal, permissions, current PRIMARY/Campus and signed entitlement revision; client never chooses provider/key, and object existence or ETag never grants read/Photo SET. The PR #105 mock checks these properties synthetically; it does not certify any provider.

## 2. Official-doc evidence by candidate

| Provider option | Official documented behavior relevant to PA-01 | What this does **not** prove for EduSync | Assessment |
|---|---|---|---|
| **Supabase Storage** | Standard uploads default to a `400 Asset Already Exists` error when a path already exists; simultaneous no-upsert uploads to the same path yield one completed winner, while `x-upsert` permits replacement. Private access is governed by Storage RLS; ordinary upload needs an INSERT policy, while enabling upsert also requires SELECT+UPDATE. | Default same-key conflict is **not a permanent immutability/retention guarantee**. A privileged service key bypasses Storage RLS. Signed upload paths and re-issued credentials must not permit later replacement. Need real API tests for delete/reupload, copy/move, signed URL expiry, service-key boundary and CDN stale-read risk. | **Shortlist for sandbox**, especially because the project already uses Supabase. No selection. |
| **Amazon S3** | `PutObject` with `If-None-Match: *` conditionally creates an absent key. Concurrent conditional creations have one successful winner, later existing-key requests normally fail `412`; races may yield `409` and require careful retry. Bucket policies can require conditional-write headers. Optional S3 Object Lock protects **object versions** with retention/hold. | A protected version does **not** prevent a fresh current version or delete marker. `If-None-Match` considers the *current version*; a delete marker may allow new creation. Bucket policy, version-ID pinning, retention and cleanup must be designed together, including documented `CopyObject` limitations with conditional policy. S3 ETag is not a universal verified SHA-256 of final content. | **Shortlist for sandbox** due to explicit conditional-write/policy primitives. No selection. |
| **Cloudflare R2** | Its S3 API documentation (updated October 14, 2026) states `PutObject` `If-None-Match: *` is evaluated atomically at commit: at most one competing create succeeds, others fail `412`. It warns that a negative read during an in-flight write does not prove the write failed. | Current S3-compatibility matrix does **not support S3 Object Lock / legal hold headers**; no WORM retention equivalence may be assumed. Different copy and multipart behavior requires R2-specific testing and approved retention/compensation, especially if the business later needs preservation of immutable evidence. | **Conditional alternate**: strong documented create-once primitive; retention/legal-hold requirements may exclude it. No selection. |
| **Azure Blob Storage** | `Put Blob` supports conditional headers; Azure offers time-based retention/hold immutability policies for blob data, with container-level and version-level models. | Concrete conditional-create SDK/header combination, versioning + legal-hold compatibility, immutability policy rollbacks, overwrite/delete behavior, IAM, account/region and retention cost must be demonstrated in an owned sandbox. Documentation of WORM does not alone prove EduSync's server-side final content hash or stable byte identity. | **Conditional alternate**: worth evaluating if Azure operational/IAM/residency requirements favor it. No selection. |

Official primary sources (observed on 2026-10-20):
1. Supabase [Standard uploads — same-path conflict/upsert/concurrency](https://supabase.com/docs/guides/storage/uploads/standard-uploads); [Storage access control / RLS / privileged key bypass](https://supabase.com/docs/guides/storage/security/access-control); [Resumable uploads concurrency](https://supabase.com/docs/guides/storage/uploads/resumable-uploads).
2. AWS [Conditional writes](https://docs.aws.amazon.com/AmazonS3/latest/userguide/conditional-writes.html), [Enforcement by bucket policy](https://docs.aws.amazon.com/AmazonS3/latest/userguide/conditional-writes-enforce.html), [S3 Object Lock's version-scoped guarantee](https://docs.aws.amazon.com/AmazonS3/latest/userguide/object-lock.html).
3. Cloudflare [S3 compatibility matrix](https://developers.cloudflare.com/r2/api/s3/api/) and [R2 conditional PutObject details](https://developers.cloudflare.com/r2/api/s3/extensions/).
4. Microsoft [Put Blob REST API and conditional-header support](https://learn.microsoft.com/en-us/rest/api/storageservices/put-blob), [Azure Blob immutability overview](https://learn.microsoft.com/en-us/azure/storage/blobs/immutable-storage-overview).
5. Supabase [breaking-change index](https://supabase.com/changelog?types=breaking-change): October 12, 2026 notice that legacy CBC TLS 1.2 ciphers on project HTTP APIs, including Storage, are scheduled for retirement **no earlier than November 10, 2026**. This is an integration compatibility check for later sandbox clients, **not a PA-01 selection reason**. The 2026-10-30 Data API auto-exposure change concerns SQL Data API exposure; do not infer Storage immutability from it.

**Evidence discipline:** Vendor docs establish advertised behavior only. They do **not** establish the compatibility of a particular EduSync account, SDK release, bucket policy, IAM principal, tenant mapping, jurisdiction, price or your incident/recovery plan. No current vendor is approved or authorized by this review.

## 3. Recorded owner preference — Supabase Storage first, no production selection

**Product Owner preference recorded on 2026-10-20:** **“Supabase storage is prefered.”** This is treated as selection of **Supabase Storage for the first isolated sandbox evaluation**, responding to the previously offered Supabase-vs-AWS-first choice. It is **not** approval of a production provider, sandbox secrets, live project, region, upload launch, or PA-01 full security signoff.

**Updated evaluation plan, subject to environment/IAM/security approval:**
- Evaluate **Supabase Storage first** in a verified isolated nonproduction project with synthetic bytes only (no Student information). Retain **Amazon S3** as the comparison/fallback candidate if actual overwrite/retention tests fail, or if an approved architecture constraint requires reconsideration.
- Keep **R2** and **Azure Blob** as alternatives if residency, retention requirements, existing operator tooling, cost, billing/export policy, or sandbox results favor them. Avoid claiming a precise provider cost without the School fleet's object counts, real reads/egress, chosen region and retention requirements.
- Start with a *single* approved provider sandbox if setting up two is not desired; still use the **same provider-neutral acceptance harness**. Do not configure live buckets or buy a service by treating this comparison as a signed owner decision.
- **No automatic PA-01 APPROVED state.** Two signoffs required: Product Owner names sandbox candidate/region, independent Security Reviewer approves the threat model, IAM policy and testing boundary. Selecting a sandbox candidate is **not** permission to expose a live file.upload/photo endpoint or to deploy a real adapter.

## 4. PA-01 sandbox conformance checklist and pass/fail protocol

The eventual sandbox harness must be self-contained, restricted to an explicitly verified disposable project/bucket and synthetic non-image bytes, with redacted request traces. The test must fail closed if the environment looks hosted/production, a user token or unknown School key is supplied, or fixture cleanup cannot be distinguished from retained evidence. No hidden dependency on prod credentials.

| PA01-ID | Required provider test | Acceptance evidence | Failure handling |
|---|---|---|---|
| P01-01 | Server-controlled location, key and private ACL | No direct public LIST/GET; no arbitrary client destination; explicit School A vs School B isolation | Block provider |
| P01-02 | Same-key competing conditional create (≥2 parallel writers with distinct bytes) | At most one success; winning bytes remain stable after all calls complete | Block provider |
| P01-03 | First write succeeds, response is lost before client ACK | Retry with same stable identity discovers exact accepted content/version; no replacement | Mark UNKNOWN and reconcile, never blind second PUT |
| P01-04 | Existing object gets another upload without `upsert`/without conditional create | Deny and leave winner's content/version unchanged | Block unsafe write privilege |
| P01-05 | Prove privileged operator/service can't bypass final immutability accidentally | Distinct IAM/runtime principals; force no-overwrite for all relevant paths, direct SDK and copy/move methods | Block until policy/architecture changes |
| P01-06 | Delete marker, version creation, key reuse and copy-based overwrite attempts | Demonstrate pinning exact sealed version and no stale-current-object substitution | Block or require compensating architecture review |
| P01-07 | Authenticated HEAD and full read-back after write/seal | Final stored byte count and server SHA-256 match; ETag ignored as canonical hash | Quarantine and deny AVAILABLE |
| P01-08 | Alter storage object after server attestation | Tamper detected, previously sealed content not substituted, no green Photo SET | Quarantine/alert and block |
| P01-09 | Concurrent DELETE/PUT, provider timeout, `409`/`412`/HTTP 5xx | Typed loss/unknown/outcome classification, bounded retry and no duplicate visible file | Uncertain status never becomes AVAILABLE |
| P01-10 | Revoke credential, reset session, stale signed upload token, cross-school path | No unauthorized new writes, reads, key listing or overwrites | Block provider/rework IAM |
| P01-11 | Quarantine, legal hold, retention, cancellation and operator purge rights | Demonstrate authorized reconciliation without claiming `VOID` equals erasure | PA-06 legal/retention gate remains open |
| P01-12 | Version/SDK pinning, logs, region, service health and complete teardown | Redacted run evidence; no live secret leaked; repeatable clean disposable suite | No acceptance without reproducibility |

**Nonnegotiable semantics:** PUT return success, `400/409/412` status, provider-owned ETag, SQL mock HMAC, file UUID and signed URL are *not* verified image provenance. Real validation (PA-03), exact byte hash and F23 transition (PA-07), signed entitlement revision and current scope (PA-05) remain separately required. This checklist has **NOT** run against any remote provider and is **NOT** equivalent to sandbox PASS.

## 5. Decision block (PA-01 still OPEN)

| Required field | Value |
|---|---|
| PA gate | PA-01, provider selection and write-once strategy |
| Production provider selected | **NONE** — do not infer a production decision from preference |
| Candidate to evaluate first | **Supabase Storage — Product Owner preference recorded 2026-10-20** |
| Target region / School residency constraint | **PENDING** — don't infer School location from user interface location |
| Sandbox IAM/policy and funding approval | **PENDING** |
| Chosen conditional-write / immutable-final/version strategy | **PENDING real sandbox evidence** |
| Product Owner | **Sandbox-first preference recorded (2026-10-20); final PA-01 product approval UNSIGNED** |
| Independent Security Reviewer | **UNSIGNED** |
| Required test evidence | P01-01…P01-12 + applicable STP-001…STP-035, future exact-head CI |
| Effective state | **DESIGN ONLY / NOT APPROVED / UPLOAD DISABLED** |

### Remaining product/security details after the owner preference

Supabase Storage is now the **preferred first sandbox candidate**, so the provider-first question is resolved. Still open before actual provider-side tests: required School data-residency jurisdiction/project region; designation of an isolated disposable test project; who authorizes test IAM/secret custody, budget and audit; actual write-once/seal design and P01-01…P01-12 acceptance; independent security reviewer. No live project or Student data may be used. PA-02…PA-08 remain independently open, and **PA-01 itself remains OPEN** until full evidence and signoff.

## 6. Workstream and release guard

Only this PA-01 research document is added to [PR #120](https://github.com/yunusyosaf399/edusync_saas_school_app/pull/120), alongside its existing documents #222 and #223. No DB-01/DB-02/DB-03/DB-04 branch, command, migration, lock-order, authorization, metadata table, Flutter code, provider account or secrets are changed. All PR #120 files remain **docs-only** and its review state remains **DRAFT**; neither this comparison nor a future documentation merge grants production authority.

**School example:** Two workers try to create a private photo-staging object for the same student using the same server-generated key. Only one immutable version may become the winner. The other gets a conflict and must inspect the existing object; it cannot overwrite it or mark it AVAILABLE. If the Student moves Campus before finalization, the separate Student authorization service still rejects the old Campus token even when storage itself succeeded.


## 2026-10-21 supplemental provider evidence — native Cloudflare R2 bucket locks

The earlier comparison's Cloudflare R2 row correctly reports **no AWS S3 Object Lock or S3 legal-hold headers through the R2 S3-compatible API**. A newly verified **separate Cloudflare-native R2 bucket-lock feature** was not evaluated in that row: [R2 bucket locks](https://developers.cloudflare.com/r2/buckets/bucket-locks/) (2026-10-20 update) describe retention rules that prevent covered object overwrites/deletes while enabled. The vendor also documents how authorized operators **remove/replace rules**, which means this is **not automatically administrator-resistant compliance WORM**. R2 U.S. **jurisdiction** is available, distinct from any S3 SDK `us-east-1` alias, which maps to `auto` ([data location](https://developers.cloudflare.com/r2/reference/data-location/)). Neither R2 lock management nor external-provider access has been tested or selected for EduSync.

For the corrected current comparison, architectural threat boundaries, AWS and Azure alternatives, pricing caution and required owner/security signoff, see [#231 immutable-final provider review](231_student_photo_pa02_immutable_final_provider_comparison_and_owner_security_gate_20261021.md). **No earlier mock PASS, first Supabase Storage sandbox preference or release gate is changed.**
