# Student Photo — provider activation dependencies and acceptance matrix

**Date:** 2026-10-20. **Status: DOCUMENTATION-ONLY / NO PA APPROVAL / NO UPLOAD ACTIVATION.**  
**Source:** `main` `df1c98d5c2d19424946986fc6ba7615202b0a443`.  
**Companion owner packet:** [PA-01…PA-08 decisions](222_student_photo_pa01_pa08_owner_security_decision_packet_20261020.md).  
**Authoritative:** [ADR-003](../decisions/ADR-003-provider-neutral-object-storage.md), [ADR-004](../decisions/ADR-004-storage-plan-entitlements.md), [storage architecture](../architecture/04_provider_neutral_object_storage.md), [entitlement architecture](../architecture/05_storage_entitlements_and_document_purposes.md), [F23 catalog](05_foundation_physical_catalog.md). New choices here are **recommendations, not approved engineering contracts**.

**Recorded PA-01 sandbox preference (2026-10-20):** The Product Owner prefers **Supabase Storage** as the first provider to evaluate. This resolves only **which vendor to test first**. It does not choose region, authorize live IAM/credentials, approve production provider selection, satisfy immutability/security acceptance, or change the PA-01…PA-08 **OPEN** design/release gates. [Provider evaluation record #224](224_student_photo_pa01_provider_selection_evidence_and_sandbox_gate_20261020.md) now scopes the first eventual sandbox to Supabase Storage; all P01-01…P01-12 and STP-001…STP-035 gates still apply.

## 1. Dependency graph (do not treat document signoff as permission to deploy)

```text
Confirmed ADR-003 provider-neutral ownership + ADR-004 signed entitlement architecture
                          |
        PA-01 provider + PA-02 location/IAM
                          |
        PA-03 real image validation + PA-04 durable one-time upload intent
                          |                  |
               PA-07 content/receipt     PA-05 verified Principal
               immutable seal             purpose/module/entitlement/Student
                          \                  /
                           \                /
                    Private staged upload service
                                |
                       PA-06 reconciliation
                       rollback/retention
                                |
                Real sandbox PA-08 security acceptance
                                |
          Independent product/security + release decision
                                |
            ONLY THEN consider protected F23 lifecycle
                                |
       Separate Student Profile Photo SET authorization
                  (#67 still default DENY)
```

**No current edge authorizes another edge.** A provider contract can be coded/tested with mock objects before PA-05 production identity is connected, but it **must not be exposed**. Real-F23 availability and Photo SET require all relevant prior gates and their own accepted runtime/approval contracts. No external provider implementation or hosted migration is part of this task.

## 2. Ownership matrix

| Deliverable | Primary owner | Dependencies / reviewers | Must not edit |
|---|---|---|---|
| PA-01 provider adapter conditional-create/immutability | File-service / deployment | Product/security/provider capability review | Foundation F23 topology, DB-01..04 |
| PA-02 School location, IAM and secrets | Infrastructure | School isolation, key custody, incident response | Flutter secrets, operational provider table |
| PA-03 verified portrait sanitizer | File validation | Security/image parser reviewers | Unreviewed content_type/media definitions |
| PA-04 immutable idempotent durable intent | File service | Foundation auth/receipt, provider worker | Existing public direct-RPC grants |
| PA-05 Student/School entitlement+auth service | File security/control plane | Current Principal, live Student context, ADR-004 signed snapshot | Client-side claims, Roll/Admissions/Curriculum |
| PA-06 outbox/recovery/quarantine | File worker / operations | Provider, legal retention, security | Unreviewed purge of retained evidence |
| PA-07 authenticated byte provenance and F23 lifecycle | File service + Foundation metadata owners | F23, Student photo owner, workflow approval | Actual Photo SET activation in this PR |
| PA-08 provider integration tests/release | CI/security operations | Independent product/security reviews, school deployment | Hosted upload activation absent signoff |

The PR #105 `LocalPrivateByteProvider` and PR #104 separate SQLite metadata mock are **simulations**. Their PASS markers are reusable regression evidence, but do not discharge any real provider or security-identity acceptance row.

## 3. Proposed protected execution sequence and fail-closed results

| Phase | Required trusted input / check | On denial, timeout or uncertain provider result |
|---|---|---|
| 0. Request admission | Verified current Principal, School project, Student ID/current PRIMARY+Campus, file.upload, Student action, module, purpose code and signed capability revision | No upload credential/key disclosure; typed private audit denial; no file row |
| 1. Allocate | Protected server UUIDv4 intent/file ID, controlled immutable location/key, purpose, uploader attribution, expiry, idempotency key; record durable issued credential status | Deny/revoke/reissue rather than reconstruct opaque bearer; orphan staging queued for reconciliation |
| 2. Stage | Write-only capability bound to exactly one private object and short validity; conditional create and conflict-safe idempotency | Remain PRIVATE; no VERIFIED/AVAILABLE; retry using stable event identity only if safe |
| 3. Inspect | Provider-authenticated object identity/version and **actual final stored bytes**; full decode, sanitization, allowed type, measured bytes SHA-256 and 1…1,048,576-byte bound | Quarantine or keep staged; mismatch/tampering/success claim alone never validates |
| 4. Seal | Enforce nonoverwritable final bytes, immutable key/version and integrity barrier; re-check live Student/Campus and entitlement revision | No provider overwrite, PENDING-only or quarantine; a direct return URL grants nothing |
| 5. Persist metadata | Protected F23 insert with verified content_type, byte_size, 32-byte hash, purpose, PRIVATE, immutable key, uploaded_by Principal; transition PENDING→VALIDATED→AVAILABLE only after required checks | No F23 premeasurement row; if inserted and later fails, QUARANTINED; never partially available |
| 6. Link profile | Separate currently disabled `student.photo.set` approval/command with current context/row versions, File AVAILABLE, typed Student provenance, audit/history | DENY on stale permission/Enrollment/Photo version; no silent previous-photo replacement |
| 7. Serve/download | Fresh view permission, School/Student domain relationship, PRIVATE AVAILABLE file, audited short temporary access | Unknown/revoked scope denies; do not cache or log durable bearer URL |
| 8. Recover | Trusted outbox leases + idempotent event and object revision; independently inspect provider on uncertain ACK; protect retention | Pending until proven; bounded alert/escalation; cancellation is not proof of physical deletion |

The real workflow is **not implemented**. The row ordering is a proposed integration review checklist; exact lock/retry/approval operation selection must follow previously accepted Foundation and current Enrollment contracts.

## 4. Acceptance evidence matrix: required before PA-08 PASS

Tests below are **requirements**, not executed test results. Numbered IDs serve as a stable planning contract for later implementation.

| Test | Threat or failure | Mandatory proof / loser behavior | PA |
|---|---|---|---|
| STP-001 | Wrong School project or cross-school location | Complete request denial; no object created or metadata exposed | 01,02,05 |
| STP-002 | Client-supplied key/endpoint/purpose substitution | Server ignores or denies; immutable server allocation retained | 02,04,05 |
| STP-003 | Unauthenticated/user-forged Principal | Fail verified auth binding, no bearer/worker effect | 04,05 |
| STP-004 | Valid actor, wrong Student/Campus/PRIMARY | Scope/relationship denial before provider side effect | 05 |
| STP-005 | Super Admin lacks upload capability | Deny; no entitlement bypass | 05 |
| STP-006 | Signed snapshot wrong school/issuer/key, bad signature | Fail closed, no stale permissive fallback | 05 |
| STP-007 | Snapshot rollback, future effective, expired, invalidated | Monotonic durable high-water and deny-new-use across multiple workers | 05 |
| STP-008 | Downgrade during upload | Retain existing authorized file; reject new finalization and quarantine unvalidated bytes | 05,06,07 |
| STP-009 | Student Enrollment END while staged | Re-check current PRIMARY, deny VALIDATED/AVAILABLE and Photo SET; conflict winner deterministic | 05,07 |
| STP-010 | Campus A → B transfer while staged | Old Campus token/read/link denied, no cross-campus authorization | 05,07 |
| STP-011 | Wrong module, permission or unregistered purpose | Independent AND gates deny; type syntax alone never grants upload | 05 |
| STP-012 | Zero bytes / 1 MiB + 1 byte | Reject; inclusive exactly 1 MiB measured bytes succeeds for allowed test fixture | 03,07 |
| STP-013 | Forged MIME/extension, truncated/corrupt, polyglot | Safe full decode/signature rejects; no available object | 03 |
| STP-014 | Metadata/EXIF and dangerous decoder payload | Sanitized/reencoded output proves metadata removed and limits enforced | 03 |
| STP-015 | Scanner timeout or image validator rejects | Quarantine; no mutation to AVAILABLE or Photo SET | 03,06 |
| STP-016 | Provider ETag equals arbitrary nonhash | Read-back/immutable proof derives actual SHA-256 rather than ETag | 01,07 |
| STP-017 | Competing PUTs at allocated object key | One exact-content/version winner; loser cannot replace stored bytes | 01,02,07 |
| STP-018 | Same-key duplicate after seal | Immutable final revision remains byte-identical; deny replacement | 01,07 |
| STP-019 | Provider returns ACK then serves different bytes | Detect tampering; quarantine/alert; refuse file READY or read access | 01,06,07 |
| STP-020 | Provider commit succeeds but ACK lost | Stable idempotency and authenticated HEAD/read-back recover single object | 01,04,06 |
| STP-021 | New issuance bearer response lost | Old bearer unrecoverable from digest; safe revoke/reissue decision enforced | 04 |
| STP-022 | Intent expired or replayed on second device | No authority extension, duplicate File, or public credential | 04,05 |
| STP-023 | Crash after remote write before DB commit | Retry reconciliation identifies orphan/known revision; no duplicate availability | 04,06,07 |
| STP-024 | Crash after DB commit before caller ACK | Authorized stable receipt replay; no second F23 or event | 04,06,07 |
| STP-025 | Two outbox workers concurrently claim same event | One lease/claim; no duplicated durable effect or contradictory disposition | 06 |
| STP-026 | Remote delete/VOID times out or returns ambiguous | Never claim erasure; retry or manual escalation respecting retention | 06 |
| STP-027 | Retained object or legal hold marked for cleanup | Reject physical purge without authorized retention release and audit | 06 |
| STP-028 | Missing validated_at, unsealed bytes or broken object reference | Deny AVAILABLE transition and private download; audit orphan | 07 |
| STP-029 | Forged uploader identity as domain owner | No uploader-self permission, subject relation required | 05,07 |
| STP-030 | Replaced photo/file linked to Student | History/lineage preserved; current Photo SET requires its own approved command | 07 |
| STP-031 | Leakage into logs, analytics, Flutter config, URLs | No secrets/keys/presigned URLs retained; redacted negative audit | 02,08 |
| STP-032 | Real provider quota/IAM/endpoint/region unavailable | Backoff and escalation; no availability claim or silent storage reroute | 01,06,08 |
| STP-033 | Roll or Enrollment lock-prefix changed by other workstream | Repeat accepted native PG photo race markers against composed head; no lock inversion | 05,08 |
| STP-034 | Wrong test environment / live credential or real Student | Refuse suite; sandbox fixture only; no production bucket or PII | 08 |
| STP-035 | Staging rollback and incident disablement | Disable new issuance/finalization without erasing preexisting authorized evidence | 06,08 |

## 5. Evidence and freeze rules

For each implementation PR, collect: **exact commit SHA**, environment and provider SDK version (no credentials), school/project isolation route, trust principal, approved PA-xx versions, test IDs, genuine provider and PostgreSQL logs with secrets redacted, immutable object/version proof, provider failure injection proof, independent security review, required CI PASS markers and nonactivation confirmation. UI screenshots alone are not authorization/security evidence.

**CI is not approval:** The current `main` includes DB-01/Enrollment composed draft enhancements after PR #105's frozen 3,124-assertion D1 run. New integrations must use **current** expected D1 suite inventory/marker set, not hard-code old totals. Current [owner-choice engineering note](20261020_owner_choices_and_dependency_resolution.md) describes 80 local suites / 3,257 assertions as **planned/locally validated composed evidence**; it is not itself an independent full provider or Photo SET approval. The merged Photo mock's older PASS markers remain necessary but not sufficient.

**Stop conditions:** Scope crossover with DB-01/02/03/04, newly ambiguous Principal/capability/intent provenance, provider unable to prove immutability, missing real image validator, unresolved physical purge/retention, stale signed entitlement, unauthorized direct RPC, or non-green exact-head runtime. Stop deployment, preserve denial/records, record dependency resolution; do not invent a silent default.

### Minimal signoff record template

```text
PA Gate / version:
Approved option / alternatives rejected:
Product owner and date:
Independent security reviewer and date:
Code/protocol SHA:
Provider/SDK/environment evidence:
Exact test IDs and accepted CI run URLs:
Release gate: DESIGN ONLY | SANDBOX APPROVED | HOSTED ACTIVATION APPROVED
Expiry/rollback and incident contact:
```

**No such signoff exists for PA-01–PA-08 in this packet.** The only acceptable release gate after merging this documentation is **DESIGN ONLY**.

**School example:** A private file service checks the School's signed capability and the Student's current Campus before issuing a bounded upload. If a retry races with Campus transfer or a provider failure, the upload stays private/unavailable and an auditable reconciliation task handles it. A valid mock-provider test never unlocks the Student photo button.
