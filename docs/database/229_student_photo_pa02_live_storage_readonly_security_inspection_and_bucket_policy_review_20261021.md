# Student Photo PA-02 — Live Storage inspection and private-bucket policy proposal

**Reviewed:** 2026-10-21
**Status:** READ-ONLY BASELINE VERIFIED. PROPOSED DESIGN ONLY. R3, R4, R6 UNSIGNED; R5 NOT TESTED; NO STORAGE ACTIVATION.
**Workstream:** PA-01/PA-02 Student Photo Storage provider/service; not DB-01 Roll, DB-02 Roll Policy, DB-03 Admissions or DB-04 Curriculum.
**Scope:** The newly created SchoolAgent Free-plan synthetic-only photo lab in US East, Northern Virginia (us-east-1). No live School project or personal data. No provider account or project identifiers/credentials in public GitHub.

## 1. Actual Supabase inspection results (read-only, not mock)

| Inspection | Actual observation | What it does not establish |
|---|---|---|
| Provider project read | New separate synthetic photo lab ACTIVE_HEALTHY and us-east-1 | Does not establish application or object security |
| storage.buckets SELECT (name, privacy, size, MIME) | **ZERO buckets** | No private buckets exist or are approved |
| pg_policies for storage.objects and storage.buckets | **ZERO user-defined policies** | Does not block privileged keys or prove client negative cases |
| pg_class RLS flags on the same two Storage tables | **RLS enabled**, FORCE RLS disabled | Service/privileged roles can bypass ordinary RLS |
| Supabase list_tables compact metadata | storage.objects and storage.buckets each show zero estimated rows | Does not exclude remote orphan bytes or establish write-once behavior |
| Supabase security advisor | **ZERO security lints** | Advisor result is not penetration or immutable-byte evidence |
| Actual modifications to provider | **NONE** during review | No upload, bucket, policy, key, SQL mutation or Student Photo service activation |

The account/project reference is held in the authorized Supabase connector, not written into this public repository. This inspection leaves the preexisting SchoolAgent staging project unchanged.

### Read-only audit queries used

Run only in the correct approved lab connection. The SELECTs below were run without DDL or data writes.

    SELECT id, name, public, file_size_limit, allowed_mime_types
    FROM storage.buckets ORDER BY id LIMIT 50;

    SELECT schemaname, tablename, policyname, permissive, roles,
           cmd, qual, with_check
    FROM pg_policies
    WHERE schemaname = 'storage'
      AND tablename IN ('objects', 'buckets')
    ORDER BY tablename, policyname LIMIT 50;

    SELECT n.nspname AS schema_name, c.relname AS table_name,
           c.relrowsecurity AS rls_enabled,
           c.relforcerowsecurity AS force_rls
    FROM pg_class c JOIN pg_namespace n ON n.oid = c.relnamespace
    WHERE n.nspname = 'storage'
      AND c.relname IN ('objects', 'buckets')
      AND c.relkind IN ('r', 'p')
    ORDER BY table_name;

No green status is claimed for any actual byte-level or signed-token attack scenario.

## 2. Vendor capabilities and **critical absent feature** (published facts, not sandbox proof)

1. [Storage private bucket fundamentals](https://supabase.com/docs/guides/storage/buckets/fundamentals) — private download generally requires RLS-controlled authorized access or a time-limited signed URL. Public buckets bypass read access controls: both candidates must be private.
2. [Creating buckets and restrictions](https://supabase.com/docs/guides/storage/buckets/creating-buckets) — bucket-specific privacy, MIME and file-size settings can be configured. Bucket MIME and size checks do **not** substitute for image full decode, sanitization, or final-byte verification.
3. [Standard uploads](https://supabase.com/docs/guides/storage/uploads/standard-uploads) — same-key no-upsert normally conflicts; explicit upsert can replace an object. A default upload conflict alone is **not** durable immutability.
4. [S3 protocol compatibility](https://supabase.com/docs/guides/storage/s3/compatibility) — vendor documentation expressly states that **S3 object versioning is NOT supported**; deleted objects cannot be recovered from version history. Its S3 bucket-operation compatibility matrix does not implement **S3 Object Lock**. Never assert native immutable object versions, Object Lock, legal-hold/WORM or recoverable deletion as Supabase Storage capabilities.
5. [Storage access control](https://supabase.com/docs/guides/storage/security/access-control) and [Supabase RLS](https://supabase.com/docs/guides/database/postgres/row-level-security) — RLS governs ordinary roles; service-role and effective privileged server credentials may bypass those policies. Audit REST, S3, TUS, upload/update, move/copy, delete and re-create capabilities.

**Hard design consequence:** PA-01 may not certify write-once verified final bytes using supposed Supabase S3 Object Lock/version history. The two-zone stage/final model is only a candidate if security can prove no effective identity can silently replace protected final bytes, including after a privileged worker compromise or signed-token misuse. If the provider cannot enforce this with acceptable controls, keep PA-01/02 BLOCKED and review an alternative immutable backing store or provider under accepted ADR-003. Never relax Foundation F23 correctness to fit the provider.

## 3. Candidate physical layout (not created, not selected)

| Attribute | STAGING candidate | SEALED candidate | Status |
|---|---|---|---|
| Proposed lab bucket label | **edusync-pa02-stage-private** | **edusync-pa02-sealed-private** | REVIEW ONLY |
| Public flag | **false** | **false** | Mandatory private in approved solution |
| Data | Temporary synthetic untrusted ingress | Server-sanitized and independently measured verified final synthetic bytes | No Student data |
| Allowed MIME | TBD with PA-03 safe signature / decoder decisions | Proposed JPEG/PNG subject to PA-03 final allowlist | UNDECIDED, no live MIME filter |
| Size bound | Input limit must be separately selected based on decoder and resource exhaustion | **1 to 1,048,576 actual final bytes inclusive** | Exact numeric unit interpretation must be tested; never trust client size |
| Upload key | Server-issued UUID/key from durable intent | New server-allocated immutable logical key | No user-selected provider, bucket or object key |
| External client | DENY until separately reviewed exact one-key short-lived stage capability | DENY direct uploads | No public upload |
| Download/list | DENY all direct clients | DENY all direct clients | Backend needs fresh authorized Student/School check and bounded response later |
| Upsert/move/copy/delete | DENY ordinary client and stage writer | DENY, plus privileged bypass tests | No overwrite after final verification |
| Backend | Stage writer create-only candidate | Separate server-side verifier/sealer create-only candidate | Privilege separation must be effective in provider, not labels |
| Retention | Unknown write acknowledgement -> private reconciliation, not blind retry | Object must remain unchanged/held or securely quarantined | R6 duration and legal hold unapproved |

These are **physical lab labels**, not Foundation location codes, not new business metadata, and not an instruction to insert provider details into file_objects. School-to-project mapping remains deployment-controlled and versioned under ADR-003.

### Proposed privilege matrix — NOT ACTUAL PROVIDER IAM

| Actor / path | Stage create | Stage read/list | Stage update/delete | Final create | Final read | Final update/delete |
|---|---|---|---|---|---|---|
| Anonymous | DENY | DENY | DENY | DENY | DENY | DENY |
| Regular School client | DENY now; future single-key signed cap under PA-04/05 only | DENY | DENY | DENY | DENY direct | DENY |
| Wrong School/Campus/Student, stale entitlement | DENY | DENY | DENY | DENY | DENY | DENY |
| Stage writer service (candidate) | Bound single new stage object only | Exact intent verification only | DENY | DENY | DENY | DENY |
| Verifier/sealer service (candidate) | No write | Read selected stage byte content | DENY | First authorized final create only | Read-back and measure only | DENY after seal |
| Reconciler (candidate) | DENY | Known-intent inspection | No blind overwrite/purge | DENY | Known-object integrity check | Hold/quarantine, not unreviewed delete |
| Broad Supabase service-role or project operator | RLS BYPASS RISK | RLS BYPASS RISK | RLS BYPASS RISK | RLS BYPASS RISK | RLS BYPASS RISK | RLS BYPASS RISK |

**Critical limitation:** Multiple application workers sharing the same service-role secret are not separate IAM identities. Their intended role labels do not prevent a compromised worker from using that secret to delete/re-create a sealed object. R3/R4 cannot be approved without demonstrating enforceable separation or a reviewed architecture resolving this risk.

### Declarative policy review requirements (NO executable migrations proposed)

- Preserve Supabase-managed Storage schema ownership and RLS. At baseline, make **no** anonymous or ordinary authenticated Storage object policies. Never add broad SELECT/INSERT for all authenticated users simply for testing.
- If approved in future, scoped stage insertion must be exactly bound to trusted issued intent and current School/Student/PRIMARY Campus/Principal, signed capability revision, upload scope, purpose and expiry; plain auth.uid() and user-editable JWT metadata do not suffice.
- No direct client access to sealed bucket. No ordinary-client UPDATE/DELETE/UPSERT even for its own objects. Do not rely on policy absence to constrain privileged service, storage admin or S3 credentials.
- Keep secret keys solely in approved server-side secret management; no Flutter, GitHub, public CI artifacts, SQL business fields, or audit payloads. Independently review credential custody, rotation and incident disable control.
- Negative tests must include REST, TUS, S3, presigned/signed upload, COPY/MOVE, DELETE+re-CREATE, all effective privileged worker identities, service-role path, stale bearer and final-object read-back. Final bytes must not change even after an uncertainty/retry.
- Any final-byte sanitization, measured stored SHA-256 and length, F23 PRIVATE lifecycle, issuance/consume receipt and Photo SET remain independently blocked until PA-03–PA-08, D1 and Student domain review. This lab authorizes no Student relation, uploaded image, or production command.

## 4. Reviewer decisions and execution evidence required

| Gate | Evidence needed before changing live Storage | Current result |
|---|---|---|
| **PA-02-R3** | Product-approved two-zone or provably equivalent mapping, privacy/MIME/size configurations, exact bucket labels, logical mapping revision, provider overwrite model | **OPEN / UNSIGNED** |
| **PA-02-R4** | Named independent security reviewer, credentials and secrets owner, enforceable privileged separation or exception/risk decision, rotation/incident control | **OPEN / UNSIGNED** |
| **PA-02-R5** | Real-provider P02-01 through P02-16 and P01-01 through P01-12 cases with exact SDK/runtime, role, case, redacted observed result and read-back SHA-256 evidence | **NOT RUN** |
| **PA-02-R6** | Owner-approved sandbox lifetime, stop procedure, zero-cost guard, quarantine/preservation rule and authorized teardown/holds | **OPEN / UNSIGNED** |
| **Native write-once** | Explicit review that Supabase does not provide S3 Object Lock/versioning; proof of alternative that covers effective privileged paths | **RISK FLAGGED / OPEN** |
| **PA-03–PA-08** | Decoder, intent recovery, current Student authorization, reconciliation, actual final bytes and independent release security tests | **NOT ACTIVATED** |

Mapped test groups from [#225](225_student_photo_supabase_storage_sandbox_isolation_contract_20261021.md): P02-01/09/14 public-privacy/log hygiene; P02-02/03/13 identity and cross-school location; P02-04..08 same-key, upsert, COPY/MOVE, delete/recreate and stale tokens; P02-10/11/15 real-byte read-back, lost acknowledgements and crash; P02-12/16 domain revocation simulator and hold/retention. Actual integrated Student/Enrollment/Campus tests require a separate PA-05/08 runtime; a disconnected sandbox must label them DEFERRED, not PASS.

**Fail-closed STOP on:** public byte download, client-allowed unsanctioned upload, sealed-object mutation by any effective identity, unverified privileged-key overwrite, incorrect final-byte hash/size, secret leakage, expired or revoked bearer writing final bytes, ambiguous provider status wrongly recorded AVAILABLE, real Student data, or silent contract weakening.

Reviewer record, intentionally blank: Product design selection **OPEN**; independent security signature for R3/R4/R6 **OPEN**; retention authority **OPEN**; exact SDK/version and test run **NONE**; release decision **DENY**.

## 5. Scope and handoff

This change only used read-only provider SQL/catalog inspection, advisor read, public vendor technical documents and a docs-only change to the existing PR #120 branch. No bucket, SQL policy, Storage object, credential, SDK, user-facing upload, migration 10, Flutter code or DB-01–04 change was made.

**Next permitted move:** obtain product and independent security approval for the specific lab-only bucket, privileged immutability and hold/teardown design (PA-02-R3/R4/R6); then, in a separately authorized synthetic-only run, create the approved private buckets and prove the P01/P02 negative matrix. If native immutable final bytes cannot be enforced, return to the provider-neutral adapter selection rather than activating unsafe behavior.

**References:** [#228 project creation](228_student_photo_pa02_us_east_synthetic_lab_creation_receipt_20261021.md); [#227 provisioning preflight](227_student_photo_pa02_us_east_1_sandbox_provisioning_preflight_20261021.md); [#226 region and signoff](226_student_photo_pa02_region_sandbox_approval_and_residency_review_20261021.md); [#225 stage/verify model](225_student_photo_supabase_storage_sandbox_isolation_contract_20261021.md); [ADR-003](../decisions/ADR-003-provider-neutral-object-storage.md).
