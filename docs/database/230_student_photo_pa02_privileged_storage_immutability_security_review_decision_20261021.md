# PA-02 — Privileged Storage authority audit, immutable-seal design risk and security decision

**Date:** 2026-10-21  
**Status:** **ENGINEERING SECURITY ASSESSMENT COMPLETE / INDEPENDENT SECURITY APPROVAL STILL OPEN / NO PROVIDER MUTATION**  
**Scope:** dedicated synthetic-only US-East SchoolAgent Supabase photo lab; Student Photo PA-01/02 only. No School data, migrations, Flutter changes, external data, secret issuance, bucket creation or upload.  
**Companions:** [#229 live baseline and proposed buckets](229_student_photo_pa02_live_storage_readonly_security_inspection_and_bucket_policy_review_20261021.md), [#225 Supabase private location design](225_student_photo_supabase_storage_sandbox_isolation_contract_20261021.md), [#223 acceptance matrix](223_student_photo_provider_activation_dependency_and_test_matrix_20261020.md), [#222 owner/security decisions](222_student_photo_pa01_pa08_owner_security_decision_packet_20261020.md), [ADR-003 provider-neutral objects](../decisions/ADR-003-provider-neutral-object-storage.md).

## 1. Material result: logical workers are not provider-enforced isolation

The original two-zone proposal separates temporary staged images from verified final bytes at the *application* level. The Supabase project's actual default role privileges show that this alone cannot prove provider-enforced write-once final bytes when trusted privileged credentials are within the attacker/failure model. The application contract requires private, fully verified, non-overwritable bytes after seal, independent current Student authority, and retention of original evidence. A Storage RLS policy or SDK default upload setting does not meet that contract without testing effective privileged and alternate API paths.

**Recommendation: retain the two-bucket topology only as a test candidate, not as an approved final immutable storage architecture.** Do not create even the private lab buckets until the security reviewer accepts a narrowly defined trial plan and explicit privilege boundaries, retention/teardown policy and an implementation that could satisfy the contractual final-byte guarantee. This review does not act as an independent security signoff.

## 2. Verified read-only privilege audit of the actual lab

Queries were run through the authenticated **SchoolAgent** Supabase connector against the **dedicated US-East synthetic photo lab**, not the existing School staging project. No secrets, account IDs, project reference or API endpoints were copied into this public document.

### 2.1 Database role attributes, actually observed

| Database role | BYPASSRLS | SUPERUSER | CREATEROLE | Interpretation |
|---|---|---|---|---|
| anon | false | false | false | Ordinary requests still constrained by RLS |
| authenticated | false | false | false | Ordinary requests still constrained by RLS |
| service_role | **true** | false | false | Explicit RLS bypass, critical for Storage trusted-key assessment |
| postgres | **true** | false | **true** | Database operator authority requires separate security/custody assessment |
| supabase_storage_admin | false | false | **true** | Storage administration role has elevated management implications; do not presume its RLS posture proves byte protection |

These are properties of database roles, not an enumeration of every provider API, infrastructure/root-account or signed-URL entitlement. The **service-role credential must never be put in Flutter or user code**.

### 2.2 Table-level privileges, actually observed

For each Storage relation — **storage.buckets** and **storage.objects** — the database returned **TRUE** for SELECT, INSERT, UPDATE and DELETE table privileges for each of these roles: **anon**, **authenticated**, **service_role**, **supabase_storage_admin**.

**Precise effect:** a table GRANT permits the *possibility* of that SQL operation; it is not final authorization. The project has **RLS=true** and **zero configured Storage object/bucket RLS policies**. Ordinary non-bypass roles are therefore *expected* to encounter RLS denial, but **no real anonymous or authenticated Storage REST/SDK negative request has been run**. The service-role's verified **BYPASSRLS=true** means a normal RLS deny is not a provider-enforced wall for that role. This does **not** justify changing Supabase-managed table grants: removing required grants or altering ownership could break Supabase Storage upgrades.

### 2.3 No-write reproducible query reference

~~~sql
SELECT rolname, rolbypassrls, rolsuper, rolcreaterole
FROM pg_roles
WHERE rolname IN
 ('anon', 'authenticated', 'service_role',
  'supabase_storage_admin', 'postgres')
ORDER BY rolname;

SELECT c.relname, r.rolname AS role_name,
 has_table_privilege(r.rolname,c.oid,'SELECT') AS select_granted,
 has_table_privilege(r.rolname,c.oid,'INSERT') AS insert_granted,
 has_table_privilege(r.rolname,c.oid,'UPDATE') AS update_granted,
 has_table_privilege(r.rolname,c.oid,'DELETE') AS delete_granted
FROM pg_class c
JOIN pg_namespace n ON n.oid=c.relnamespace
CROSS JOIN pg_roles r
WHERE n.nspname='storage'
 AND c.relname IN ('objects','buckets')
 AND r.rolname IN ('anon','authenticated','service_role','supabase_storage_admin')
ORDER BY c.relname,r.rolname;

SELECT count(*)::int AS custom_storage_policy_count
FROM pg_policies
WHERE schemaname='storage' AND tablename IN ('buckets','objects');
~~~

The policy count returned **0** and a renewed read-only count of storage.buckets returned **0**. The project was healthy in **us-east-1** at inspection time. None of these observations proves actual network denial, sealed bytes, or replay/recovery correctness. [Previous zero-lint security advisor evidence](229_student_photo_pa02_live_storage_readonly_security_inspection_and_bucket_policy_review_20261021.md) is not a substitute for security acceptance.

## 3. Independent vendor-document check

Official published sources, checked 2026-10-21:

- [Supabase Storage S3 compatibility](https://supabase.com/docs/guides/storage/s3/compatibility) explicitly states **S3 versioning not supported**; implemented operations have **no S3 Object Lock semantics** (no object-lock mode/retain-until/legal-hold support in its compatibility listing).
- [Supabase Storage access control](https://supabase.com/docs/guides/storage/security/access-control) describes service keys used to **bypass RLS** from trusted clients.
- [Storage bucket fundamentals](https://supabase.com/docs/guides/storage/buckets/fundamentals): private bucket downloads may still be authorized via limited signed URLs, so private is not "never accessible."
- [Supabase standard uploads](https://supabase.com/docs/guides/storage/uploads/standard-uploads): same-key upload without upsert normally conflicts, but an explicit upsert can overwrite.
- [Supabase database RLS](https://supabase.com/docs/guides/database/postgres/row-level-security): GRANT and RLS are distinct layers; policy checks do not eliminate privileged bypass.

Thus **neither native version-history nor S3 WORM/retention enforcement may be assumed for this Supabase trial**. A candidate using different workers but a shared privileged service key has the **same effective ability** to mutate objects regardless of the logical stage/seal separation. A signed SHA-256 ledger can detect later corruption when content is re-read, but by itself **cannot prevent overwrite, preserve original bytes, or guarantee recovery** after deletion.

## 4. Threat-model and capability review — design dispositions, NOT test PASS

| Case | Ordinary RLS/single-create effect | Privileged or failure path | Verdict |
|---|---|---|---|
| Anonymous or authenticated user without object policy | Expected RLS denial; no actual HTTP test | Bad future policy may open broad read/write | **DENIAL NOT TESTED** (P02-01,09,14) |
| Client uploads same key without upsert | Vendor documents collision/one winner | Other protocol or upsert route may replace | **DOC ONLY** (P02-04..06) |
| Client submits another School/Campus/object path | Server mapping and live-domain checks needed | Signed bearer stale or path substitution | **NOT IMPLEMENTED** (P02-02,03,08,13) |
| App stage-writer attempts sealed-bucket delete | Intended role matrix says DENY | Shared service_role credential BYPASSRLS; worker label is insufficient | **UNSAFE IF SHARED PRIVILEGE** (P02-07) |
| Privileged final writer attempts overwrite/delete+recreate | Application can refuse request | No native Object Lock/versioning; key custody/privileged path not resolved | **IMMUTABILITY OPEN / STOP** (P01-01..06, P02-05..08) |
| Successfully sealed object is later changed | Compare independently measured stored bytes with SHA-256 | Without original retained bytes, hash can detect but not restore | **DETECT ≠ PREVENT** (P02-10) |
| Remote write ACK lost, worker crashes or retries | Durable intent/receipt and provider read-back required | Double write, orphan, false AVAILABLE | **NOT RUN** (P02-11,15) |
| Staff authority/capability revoked while staging | Intent/finalization must reauthorize live Student+PRIMARY Campus | No composed School runtime in isolated lab | **PA-05/08 DEFERRED** (P02-12) |
| Teardown with held/evidence objects | Explicit owner retention/hold required | Free-plan project deletion destroys provider bytes | **R6 OPEN / NO PURGE** (P02-16) |

This assessment classifies documented capabilities and live database role/grant posture. It is **not a penetration test, incident investigation or acceptance run**.

## 5. Architecture alternatives requiring owner and independent security choice

### A. Supabase Storage for stage AND final, with RLS/no-upsert and backend checks

**Benefit:** One provider/region and straightforward two-private-bucket layout.  
**Deficiency:** No native Object Lock or versions; privileged credentials can bypass RLS; a worker app refusing overwrites does not prevent credential misuse. **Does not currently demonstrate the strict final-byte non-overwrite invariant under all effective principals.**

**State: NOT APPROVABLE AS A VERIFIED IMMUTABLE FINAL SEAL ON EVIDENCE AVAILABLE.** A reviewer must not sign R3/R5 on RLS and no-upsert alone.

### B. Supabase private stage + separately enforceable immutable final backend

**Benefit:** Honors the owner's **Supabase-first sandbox evaluation** for ingress while preserving ADR-003's provider-neutral adapters and delegating final retention/immutable versions to a provider that offers independently auditable write-once controls.  
**Cost/risk:** Adds another provider, compliance, secrets, cross-service transfer/reconciliation and potential billing approval; requires separate owner choice, external-provider verification and a new capability matrix. The School app may still use Supabase for PostgreSQL/Auth and staging, with logical file location mapping behind a backend adapter.

**State: PREFERRED SECURITY REVIEW CANDIDATE IF STRICT WORM IS NONNEGOTIABLE; NOT OWNER-SELECTED AND NOT DEPLOYED.** Do not silently acquire another provider or create new cloud assets.

### C. Supabase final + independent tamper-evident attestation/retained escrow

**Benefit:** Independent hashes/append-only evidence can expose later provider tampering and assist controlled recovery *if separate original bytes are available*.  
**Deficiency:** Merely storing a hash outside Supabase does not prevent a privileged DELETE, same-key overwrite or a temporary substitute, and does not restore lost originals. It does not automatically fulfill the contract's "prevent post-validation overwrite" semantics.

**State: REQUIRES PROOF OF ACTUAL PREVENTION + RECOVERY OR AN EXPLICIT SEPARATE CONTRACT DECISION.** Cannot be accepted as equivalence through hashes alone.

### D. Use a provider with a verifiable immutable final-object guarantee for the whole byte lifecycle

**Benefit:** Potentially simpler security boundary if provider-native object retention and immutable versions are documented and empirically verified.  
**Cost/risk:** Would change the preferred first sandbox vendor, require a separately approved provider/project/cost/location and new tests. DB remains provider-neutral under ADR-003.

**State: FALLBACK, NOT SELECTED.**

**Do not choose A/B/C/D automatically as a production architecture.** In particular, the existing owner preference for Supabase Storage first does not authorize adding an external object provider or weakening F23.

## 6. Actionable independent security decision request

An independent reviewer must explicitly decide, with a dated approval/rejection and versioned reference, the following:

1. **R3-IM1: Threat boundary.** Does byte non-overwrite include compromised worker or service-role credentials, provider project owner, backend root account and administrators? If any privileged override is considered out of scope, record a formal risk/contract exception signed by the appropriate product and security owners; no implicit exception.
2. **R3-IM2: Sealing mechanism.** Which physical provider, per-object version/key strategy, write-once API, finalization sequence and retention constraints genuinely preserve the original final byte sequence? A logical two-bucket split without enforceable privilege separation fails.
3. **R4-IAM1: Effective roles/credentials.** Which *provider-enforced* identities can CREATE, UPSERT, COPY, MOVE, DELETE and READ in stage and final via every protocol? How are secrets stored, rotated, revoked and independently audited? Any unavoidable broad key is a named security exception.
4. **R5-T01: Real-provider attacks.** Reproduce P01-01..12 and P02-01..16 as applicable using only synthetic bytes. Run client and authorized server identities, wrong-school and stale-authority simulator, final DELETE+re-CREATE, concurrent PUT, upsert, signed token replay, remote ACK loss and independent final SHA-256 read-back. Mark deferred integrated cases explicitly.
5. **R6-OPS1: Incident and teardown.** Who can stop issuance, quarantine unknown bytes, freeze an account, approve purges and preserve held evidence; what are test lifespan and retention? The dedicated Free-plan project must not be destroyed while evidence is retained.

### Evidence form (blank; no fabricated reviewer)

| Decision | Proposed result | Evidence / reviewer |
|---|---|---|
| Native Supabase S3 Object Lock/versions available | **NO**, per published docs | Independent reviewer must acknowledge |
| Supabase-only stage/final can satisfy privileged byte immutability | **UNPROVEN; BLOCKED** | R3/R4 reviewer must adjudicate |
| Option B hybrid or D alternative warranted | **RECOMMENDED FOR REVIEW IF HARD GUARANTEE REQUIRED** | Product owner choice OPEN |
| PA-02-R1 geographic preference | US first; previously recorded | Owner choice recorded |
| PA-02-R2 separate project/cost | Approved synthetic US-East lab created, $0/month quote | Verified project receipt #228 |
| PA-02-R3 physical final seal + bucket mapping | **UNSIGNED** | Independent security + product |
| PA-02-R4 IAM + privileged bypass | **UNSIGNED** | Independent security |
| PA-02-R5 real-provider proof | **NOT RUN** | Exact run evidence required |
| PA-02-R6 hold/teardown | **UNSIGNED** | Product and security |
| Any live upload / F23 AVAILABLE / Student Photo SET | **DENY** | Requires PA-03..08 + activation decision |

## 7. Next bounded task and independent-workstream protection

**Completed in this task:** live nonmutating PostgreSQL role and effective table-GRANT inventory, renewed empty policy/bucket proof, vendor feature check, explicit privileged-immutability risk finding, design alternatives, and testable review/signoff request.

**Not authorized or performed:** new bucket, RLS grants, credential, token, uploaded object, photo decoder, SQL migration, hosted changes, production integration, project billing alteration, provider switch or real security PASS.

**Next action:** obtain independent security/product disposition on the final-byte immutability mechanism and R3/R4/R6. Only then allow separately authorized **synthetic-only** private bucket/policy and negative provider trials. If strict sealed-byte immutability cannot be satisfied under the selected provider, leave PA-01/02 blocked and assess an alternate provider-neutral adapter. The draft PR must not be merged as production provider approval. No DB-01..04 changes are within this task.


## Subsequent comparison update (2026-10-21) — no Supabase security gate change

[#231 immutable-final provider comparison](231_student_photo_pa02_immutable_final_provider_comparison_and_owner_security_gate_20261021.md) verifies that Cloudflare R2 has **separate native bucket-lock rules**, notwithstanding its lack of AWS **S3 Object Lock API** support. Because a duly authorized R2 lock-configuration actor can remove or replace its rules, this is **not yet an approved substitute** for administrator-resistant immutable final-byte retention; the exact attacker boundary and P01/P02 real-provider test evidence remain mandatory. AWS compliance-mode version retention (which protects **the retained version**, not necessarily the latest-key alias) and Azure locked WORM remain independent alternatives for review. The live Supabase stage lab and R3/R4/R6/R5 STOP states in this document are unchanged; no external vendor, resource or cost has been approved.
