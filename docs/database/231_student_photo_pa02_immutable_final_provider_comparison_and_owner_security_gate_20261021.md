# Student Photo PA-02 — Immutable-final provider comparison, newly verified R2 native locks and owner/security gate

**Prepared:** 2026-10-21. **State:** EVIDENCE-BASED ENGINEERING RECOMMENDATION ONLY / OWNER PROVIDER CHOICE OPEN / INDEPENDENT SECURITY REVIEW OPEN / NO EXTERNAL PROVIDER PROVISIONING.
**Scope:** PA-01/PA-02 synthetic Student Photo provider evaluation only. Does not authorize paid accounts, additional vendors, Cloudflare/AWS/Azure resources, buckets, tokens, migrations, user uploads or production activation.
**Prior source and constraints:** [#230 privileged authority finding](230_student_photo_pa02_privileged_storage_immutability_security_review_decision_20261021.md); [#229 read-only Storage state](229_student_photo_pa02_live_storage_readonly_security_inspection_and_bucket_policy_review_20261021.md); [#224 initial provider comparison](224_student_photo_pa01_provider_selection_evidence_and_sandbox_gate_20261020.md); [#222 gate packet](222_student_photo_pa01_pa08_owner_security_decision_packet_20261020.md); [ADR-003](../decisions/ADR-003-provider-neutral-object-storage.md).

## 1. Live state reverified before the comparison

- The separate approved **SchoolAgent** synthetic-only Supabase lab remains ACTIVE_HEALTHY in **us-east-1**. A read-only SQL query returned **zero Storage buckets and zero Storage object/bucket custom policies**. The security advisor reported no findings; this is not an immutability acceptance test.
- The first sandbox vendor choice remains **Supabase Storage**. The product owner's later country preference remains U.S.-first. Neither authorizes another provider, a hybrid architecture, a retention policy or production use.
- All projects, account IDs, keys, billing identifiers, private object keys and signed URLs remain outside this public document. No new provider project was created, linked or changed in this research.

## 2. Important R2 correction discovered in fresh official documentation

**The R2 S3-compatibility matrix does not implement AWS S3 Object Lock headers or S3 versioning. Nevertheless, Cloudflare R2 separately offers NATIVE BUCKET LOCKS outside its S3 API.** Previous #224's comment about absent *S3 Object Lock / legal-hold headers* remains true, but it must not be read as a blanket claim that R2 has no retention/overwrite-prevention feature.

Cloudflare's [R2 native bucket-lock documentation](https://developers.cloudflare.com/r2/buckets/bucket-locks/) (last updated 2026-10-20) says:

- Rule-scoped objects can be protected from overwrite/deletion for a duration, until a date or indefinitely; rules apply to existing as well as newly written objects.
- Once enabled, the rule blocks overwrites, deletes, in-flight upload completion and lifecycle deletion of protected objects.
- **Authorized operators can remove or replace bucket-lock rules** in the dashboard, CLI or management API. The feature therefore does not automatically establish an irrevocable retention guarantee against a malicious/compromised account administrator. This is a key difference from AWS S3 compliance-mode Object Lock.
- Creation of new objects remains possible; a server-owned immutable key and trusted final-pointer semantics are still required. Later lock-rule deletion, lifecycle behavior, role scope, audit and rollback must be tested under all effective actors.
- R2's [S3 API matrix](https://developers.cloudflare.com/r2/api/s3/api/) has atomic conditional PutObject using If-None-Match: * (single competing winner for an absent key), but cannot be substituted for the native bucket-lock API or presumed to protect administration.
- R2 offers a [United States jurisdiction](https://developers.cloudflare.com/r2/reference/data-location/) (jurisdiction **us**) to constrain location. Its S3 API's us-east-1 setting normally aliases **auto** and must NEVER be mistaken for a physical Northern Virginia designation. Bucket jurisdiction is chosen at creation and cannot simply be changed in place.

**Engineering conclusion:** Reopen R2 as a conditional lower-cost final-store candidate for the owner/security review. It is NOT verified as adequate under the strict compromised-administrator threat model and is NOT deployed. This discovery refines, rather than silently overwrites, the earlier comparison.

## 3. Provider-specific risk / suitability matrix — published capabilities, not verified EduSync acceptance

| Candidate final byte store | Published write/retention control | What can defeat application assumptions | Design disposition |
|---|---|---|---|
| Supabase Storage both stage/final | Private buckets; RLS; no-upsert path conflict | No native S3 versioning/Object Lock; service_role BYPASSRLS; copy/move/delete/recreate and privileged paths | **NOT sufficient for final strict immutability on existing evidence**. Keep synthetic lab and no uploads until owner/security verdict |
| **Cloudflare R2 native bucket locks** | Retention rules can block overwrite/delete and are separate from unsupported S3 Object Lock; atomic conditional create documented | Rule-management principals can remove/change rules; no S3 Object Lock version-pinning; jurisdiction must be explicitly selected and checked | **Review candidate only** for a bounded admin-tamper threat; not compliance-grade by assumption |
| **AWS S3** with Object Lock | Versioning plus **compliance-mode retention** can protect an exact object version even from root deletion until expiry; conditional PutObject and enforceable conditional-write policy available | New versions and delete markers still possible; default latest-key GET may show wrong version; short/long irreversible retention affects cleanup and cost; governance mode can be bypassed by privileged role | **Primary technical reference candidate** for strict retained-version protection, subject to object-version pinning, immutable mapping, conditional-write policy and verified runtime |
| **Azure Blob immutable storage** | Version- or container-level WORM, locked time-based retention and legal holds documented | Unlocked policy may be shortened/deleted; version or container semantics and matching read identity vary; locked rules and holds affect teardown/cost | **Comparable strict-protection candidate**; require exact account/config/IAM/SDK, regional and retention trial |

Primary official sources:

- [Supabase S3 compatibility](https://supabase.com/docs/guides/storage/s3/compatibility) and [Supabase Storage RLS](https://supabase.com/docs/guides/storage/security/access-control).
- [R2 bucket locks](https://developers.cloudflare.com/r2/buckets/bucket-locks/), [lock-management API](https://developers.cloudflare.com/api/resources/r2/subresources/buckets/subresources/locks/methods/update/), [S3 compatibility](https://developers.cloudflare.com/r2/api/s3/api/), [jurisdictions](https://developers.cloudflare.com/r2/reference/data-location/), [pricing](https://developers.cloudflare.com/r2/pricing/).
- [AWS S3 Object Lock / compliance and governance mode](https://docs.aws.amazon.com/AmazonS3/latest/userguide/object-lock.html), [conditional writes](https://docs.aws.amazon.com/AmazonS3/latest/userguide/conditional-writes.html), [conditional-write bucket policies](https://docs.aws.amazon.com/AmazonS3/latest/userguide/conditional-writes-enforce.html).
- [Azure immutable Blob storage](https://learn.microsoft.com/en-us/azure/storage/blobs/immutable-storage-overview).

## 4. Important AWS and Azure subtleties for EduSync

**AWS protected VERSION is not necessarily a protected KEY/alias.** AWS notes that locking a version does not prohibit another version or a delete marker. If AWS is used, bind final verification to a provider-authenticated version ID in restricted service-owned immutable mapping, and have every future read address/validate precisely that version, not the latest key. Never claim that a version-locked bucket prevents all new writes. Create-once conditional PUT may need explicit bucket policy, but AWS warns that conditional bucket policies can break CopyObject destination writes (403 or 501). Plan a verified PUT-only seal or independently reviewed copy strategy and test concurrency, retention, and delete markers. An ETag is not measured final SHA-256.

**AWS governance versus compliance:** Governance can be bypassed with BypassGovernanceRetention authority. Compliance mode protects retained versions even against AWS account root during the retention window, but its irreversibility can create unplanned cleanup or billing obligations. Never use indefinite or long-lived compliance retention in a trial without exact owner and security approval; choose a deliberately reviewed finite retention period that is compatible with evidentiary holds and teardown.

**Azure locked versus unlocked:** Azure documentation distinguishes unlocked retention settings used for testing (can be shortened/removed) from locked WORM retention (cannot be deleted/shortened). Version-level and container-level protections have different write behaviors and prerequisites. Do not infer protected key behavior, rollback or exact pricing from the word 'immutable' alone. Locking is a separately reviewed irreversible action.

## 5. Cost and U.S. residency are constraints, not presumed approvals

- The existing US-East Supabase lab is on a Free project previously quoted at USD 0/month. It remains the only authorized provider infrastructure for PA-02.
- Cloudflare's [published R2 Standard free tier](https://developers.cloudflare.com/r2/pricing/) includes **10 GB-month, 1 million Class A operations and 10 million Class B operations per month** (published Oct 1, 2026), but excess usage is billable; this is **not a quoted customer cost of $0**, nor permission to open/bill a Cloudflare account. R2 regional jurisdiction **us** is a separate configuration from Supabase's AWS-specific us-east-1.
- AWS S3 and Azure Blob can incur object, operation, retrieval, data transfer, version retention, lock and other fees. Obtain a provider/account/region-specific quote and explicit owner approval before any new resources or test writes. Never assume equivalent price to Supabase Free or set retention without a budget/hold owner.
- End-to-end School data residency covers transfers from staged Supabase objects to any final provider, audit logs, backups, signed URLs, edge processing, egress and third parties. U.S. preference for a synthetic lab does not resolve real-school data protection obligations.

## 6. Proposed fail-closed test and evidence plan (not run)

| Case ID | Synthetic-only negative test | PASS required before a specific option can be approved |
|---|---|---|
| ALT-01 | Ordinary unauthorized client read/list/create across private stage/final | Denied for every path, including presigned tokens/expiry |
| ALT-02 | Parallel conditional-create at the same canonical final key | Exactly one canonical winner; conflicting bytes cannot replace committed version |
| ALT-03 | Stale signed bearer, spoofed School, Campus or user-chosen provider key | Denied or quarantined without final-byte mutation |
| ALT-04 | Full-privilege worker attempts overwrite, delete+recreate, copy/move and multipart variant | Final protected canonical version/bytes unchanged; all exceptional routes enumerated |
| ALT-05 | **Cloudflare R2 native lock**: privileged operator changes/removes rule then attempts overwrite | Document whether original survives. If override succeeds and admin tamper is in threat model: FAIL this candidate |
| ALT-06 | **AWS S3 version lock**: create new current version and delete marker; GET with/without version ID | Canonical version-ID read returns exact measured immutable bytes, no silent latest alias; deletion of protected version denied |
| ALT-07 | **AWS governance bypass** vs compliance lock | Governance bypass demonstrated/controlled; compliance protected version persists during approved retention window |
| ALT-08 | **Azure locked/unlocked retention**, administrative action and deletion attempts | Unlocked policy weakness known; locked protected blob/version survives required effective identities |
| ALT-09 | Lost provider ACK, interrupted seal, changed server state, key mapping revision | Unknown state remains private; read-back and hash compare before any available state; no blind retry |
| ALT-10 | Out-of-scope expiry, retained evidence, teardown/rollback and billing | Reviewer approves bounded retention, holds, cost/egress, no unauthorized irreversible retention or deletion |

Crosswalk: existing P01-01..12 and P02-01..16 (especially P02-04..08/10/11/15/16) still apply. Synthetic lab tests do NOT satisfy live Campus Transfer / Enrollment END / current Student authorization tests: these remain PA-05/08 DEFERRED. Every test requires exact SDK/API version, project/region in restricted records, role matrix, expected/observed status, measured synthetic SHA-256/byte length, immutable evidence manifest and independent review. No ETag-only verification.

## 7. Engineering recommendation and user/security decision required

**Ranked for design review, not a purchase or vendor selection:**

1. **AWS S3 version-pinned compliance retention** as reference for the strongest published version-level immutability guarantees under a privileged credential threat; keep strict conditional-create and immutable version-bound reads. Do not implement until retention and spending implications are accepted.
2. **Azure Blob locked WORM** as a comparable strict candidate if Azure operations or jurisdiction are preferred; evaluate equivalent revision/mapping and locking semantics.
3. **Cloudflare R2 native bucket locks** as a potentially low-cost U.S.-jurisdiction candidate **only if** the independent reviewer accepts that authorized lock configuration operators can remove rules or an independently enforced compensating control closes that threat. Its S3 API's lack of Object Lock does not mean native bucket locking is absent.
4. **Supabase-only final** remains blocked under the currently stated immutable final-byte requirement and verified privileged/RLS path. Supabase remains the approved synthetic staging evaluation environment, not the certified final immutable store.

These are engineering rankings according to the **specific hard-immutability requirement**, not product owner decisions, or evidence of account availability/performance. No third-party account is connected or authorized for creation, and no provider-specific implementation is approved.

### Explicit gate questions (all OPEN; do not autofill)

| Owner/security decision | Unresolved choice | Required signature/evidence |
|---|---|---|
| Final-byte threat boundary (R3-IM1) | Does compromise of final-store administrator/operator count? What maximum retention/hold must survive? | Product owner AND independent security |
| Final provider (PA-01 + R3-IM2) | Supabase-only (requires further proof), R2 native locks, AWS S3, Azure Blob or alternate | Owner selects one trial + provider budget + security review |
| Effective IAM/revocation (R4) | Account, least privilege, key custody, policy management, audit, expiry | Independent security |
| Retention, teardown and cost (R6) | Legal/operational hold vs short-lived disposable fixture, time bound, no silent payment | Product owner + independent security |
| Real-provider acceptance (R5/PA-08) | Exact-region lab test runs ALT and all applicable P01/P02 with stable final-byte read | NOT RUN; separate independent verdict |

**Owner-facing plain example:** A school uploads a portrait in private Supabase staging. The server checks and sanitizes it, then creates a final immutable object in a separately approved store. The file's canonical identity points only to the verified protected version; a later replacement upload or administrative delete must not make a different portrait appear under that identity. If an alternative vendor cannot enforce this at the required threat boundary, the upload remains DENY.

## 8. No activation and noncollision

Completed here: official source comparison and R2 native-bucket-lock correction; pricing/location caveats; detailed provider-specific adversarial test packet; clean no-write Supabase lab check and concrete owner/security selection gate.

Not performed or authorized: any AWS/Cloudflare/Azure resource, credential, billed operation, bucket, policy, vendor migration, Student Photo upload, PA-03 parser, F23 AVAILABLE, Photo SET, D1 migration, Flutter or DB-01..04 changes. PR #120 stays draft. This document is documentation, not independent security approval.


## Subsequent owner choice — 2026-10-21 (supersedes provider rankings)

**Owner explicitly chose “Option A only” (Supabase Storage only) with minimal application-level protection rather than AWS/Azure/Cloudflare or a hybrid final-file service.** This supersedes section 7's earlier *engineering ranking and provider-trial recommendation*, **not** the verified comparative vendor facts. The new implementation direction is the private Supabase bucket plus verified server-only Photo API/new unique keys described in [#232](232_student_photo_owner_choice_supabase_only_minimum_backend_photo_api_20261021.md). Its limits are explicit: ordinary API and accidental overwrite protection, **no native WORM** and no guarantee against a fully privileged Supabase account/server key. Independent PA-01..08 gates and ADR-003/F23 integrity requirements remain unapproved for runtime activation. This comparison is historical evidence only, not authority to continue a different-provider procurement.

