# Student Photo PA-02 — Supabase Storage private sandbox isolation and nonactivation contract

**Prepared:** 2026-10-21  
**Status:** **PROPOSED SANDBOX CONTRACT / PRODUCT AND SECURITY REVIEW OPEN / NO ACTIVATION**  
**Workstream:** Student Photo provider/service, separate from DB-01 Roll, DB-02 Roll Policy, DB-03 Admissions, DB-04 Curriculum.  
**Parent gate:** [PA-01..PA-08 packet](222_student_photo_pa01_pa08_owner_security_decision_packet_20261020.md); [activation/negative test matrix](223_student_photo_provider_activation_dependency_and_test_matrix_20261020.md); [PA-01 provider shortlist](224_student_photo_pa01_provider_selection_evidence_and_sandbox_gate_20261020.md).  
**Base for collision review:** `main` `df1c98d5c2d19424946986fc6ba7615202b0a443`; no SQL or implementation included here.

## Decision already recorded; decisions NOT made here

The Product Owner prefers **Supabase Storage for the first isolated sandbox evaluation** (2026-10-20). This is *not* approval of a production provider, SDK, project/region, public API, IAM, bucket, or active Student-photo upload. PA-01's write-once proof and PA-02..PA-08 remain open. ADR-003 provider neutrality and ADR-004 entitlement checks remain controlling.

This document **only** prepares a candidate PA-02 isolation contract and runnable-test specification for later independently authorized work. It does not create a Supabase project, bucket, user, secret, file row, Storage policy, Flutter API, photo link, Migration 10 SQL, or workflow.

## Official published Storage capabilities — not EduSync verification

- [Supabase private buckets](https://supabase.com/docs/guides/storage/buckets/fundamentals): private access is gated through Storage RLS or bounded signed download URLs; **public** buckets expose assets to anyone with the URL. All Student Photo buckets must be private.
- [Standard uploads/concurrency](https://supabase.com/docs/guides/storage/uploads/standard-uploads): no-upsert same-key uploads conflict, while `upsert`/`x-upsert` permits replacement. **No-upsert is not an immutable retention guarantee** or sufficient seal proof.
- [Storage access control](https://supabase.com/docs/guides/storage/security/access-control): an ordinary INSERT policy differs from UPDATE/SELECT permission needed for upsert. Policy configuration and every effective write/copy/move path must be verified.
- [Storage bucket restrictions](https://supabase.com/docs/guides/storage/buckets/creating-buckets): bucket MIME and maximum-size filters supplement, but do not replace, server-side full image decode/re-encode and *measured final stored bytes* checks.
- [Storage ownership](https://supabase.com/docs/guides/storage/security/ownership): `owner_id` is not business authorization; service-key-created objects may not have ordinary user ownership. Privileged service-key behavior and credential custody require an independent check.

The documents establish advertised behavior, **not** a successful real-provider immutability, isolation, IAM, expiry, or revocation test. Reconfirm API behavior and SDK/version at test execution.

## Proposed physical separation — conditional, unapproved

| Concern | Candidate sandbox baseline | Mandatory evidence / alternative |
|---|---|---|
| Project boundary | Dedicated disposable **nonproduction Supabase project**, never a school live project; synthetic nonpersonal image fixtures only | Product owner chooses allowed jurisdiction/region; security verifies account/project identity and teardown |
| School isolation | One School project and deployment-owned logical-to-physical mapping, no School selector supplied by Flutter | Cross-project/key/bucket/location substitution denied with demonstrable provider boundary |
| Logical locations | Versioned deployment allowlist, not mutable `file_objects` provider data. Use approved logical code **only after** owner selection; `TRIAL_PRIVATE` stays a mock-only identifier | Immutable mapping proof; fail closed on unknown, disabled or cross-school location |
| Private bytes | Candidate two-zone design: private **staging** with sharply bounded write capability and separate private **sealed/final** bytes inaccessible to client writes | Simpler one-bucket architecture allowed only if it *proves* equivalent immutable-final guarantees under all effective principals |
| Write API | Server allocates random UUID/key and purpose-bounded intent; enforce create-only where supported, without client-selected paths or `upsert` | Actual same-key concurrency, DELETE+recreate, COPY/MOVE, signed-token and privileged-service tests; denial of post-seal substitution |
| Read API | No private public URLs; backend checks current Principal, School, Student, PRIMARY/Campus, purpose, grant and AVAILABLE state before a short-lived response | Reauthorization and expiry tests; no permanent bearer in logs/DB/client caches |
| Credentials | Deployment secret manager with separate scoped sandbox identities for staging write, seal/verify, read, reconcile and teardown where feasible | Security owner approves privilege matrix; no secret in source, Flutter, SQL settings, CI logs or stored audit payload |
| Blob identity | Provider-authenticated object/key/version where supported, followed by trusted full read-back and final byte-size/hash measurement | Never treat ETag, upload ACK, client digest or SQL mock HMAC as validated immutable-byte provenance |
| End-state | No real Student Photo `file_objects` transition, AVAILABLE, Photo SET or private-download activation during PA-02 review | Separate PA-03/04/05/06/07/08 and D1 migration/Student Profile gates |

**Important limitation:** a broadly privileged Storage service key can bypass normal Storage RLS. Therefore RLS plus `upsert:false` cannot by themselves prove immutable sealed bytes. The sandbox must demonstrate an enforceable separation of write capability from the sealed object, including trusted infrastructure/worker credentials and delete, copy, move, reupload and stale-token paths. If Supabase Storage does not satisfy that proof under the selected design, **keep PA-01/02 BLOCKED** and review a different sealing architecture or provider; do not weaken F23's invariants.

### Proposed credential boundaries (no grants made)

1. **Request broker**: verifies live application Principal, domain permission, School capability and current Student/PRIMARY Campus; allocates one canonical server-owned intent/key. No broad Storage list/read/delete privilege.
2. **Stage writer**: can upload only the exact approved private staging object within a short validity interval. Cannot write final bytes, enumerate keys, or use `x-upsert` to replace a sealed object.
3. **Verifier/sealer**: performs trusted stored-byte inspection and finalization; does not make private bytes client-readable merely by sealing.
4. **Reconciler**: reads bounded provider status for known intents, quarantines uncertainty and respects holds; deletion capability, if any, must be separately approved and auditable.
5. **School domain metadata executor**: applies approved F23 state/history and photo relationship transitions only behind independently authorized commands; no network Storage credentials in PostgreSQL functions.

These are *separation-of-duty requirements*, not claims that the Supabase SDK natively exposes these exact IAM roles. Any unavoidable consolidated privileged role is an explicit PA-02 security-exception decision requiring compensating controls and adversarial tests.

## PA-02 sandbox test register — required evidence, not performed

| ID | Scenario to reproduce using fake images and distinct sandbox principals | Required PASS condition; otherwise STOP |
|---|---|---|
| P02-01 | Direct public or anonymous upload/list/download to staged/final locations | Denied; neither bucket public |
| P02-02 | Authenticated but wrong Student, current Campus or School project | Denied before issuing provider capability |
| P02-03 | Client changes object key, bucket name, endpoint or logical location | Trusted server mapping unchanged; substitution denied |
| P02-04 | Simultaneous no-upsert upload to one allocated staging key | One byte-identical winning write; loser cannot alter object |
| P02-05 | Repeat same-key upload after finalization via all accessible REST/SDK paths | Sealed bytes remain unchanged; no second AVAILABLE state |
| P02-06 | `x-upsert`, UPDATE, COPY, MOVE, DELETE then re-create from stage-client identity | No post-seal replacement, including object/path reuse |
| P02-07 | Same overwrite/delete/copy/move attempt from each trusted worker identity | Strictly bounded to approved role; privilege exception documented and separately reviewed |
| P02-08 | Reissue, expire, revoke or leak old signed upload credential | Cannot change sealed bytes or access a different object |
| P02-09 | Malicious public-bucket flip, overbroad RLS policy or unauthorized policy edit | Provisioning drift flagged; activate nothing; independent IAM-owner check |
| P02-10 | Tamper with provider response/ETag; read back changed content | Verifier measures actual final bytes; mismatch is QUARANTINED, never AVAILABLE |
| P02-11 | Lost remote PUT acknowledgement, timeout or duplicate reconcile attempt | Discovery/read-back is idempotent; never blindly overwrite or promote uncertain bytes |
| P02-12 | Campus transfer / Enrollment END / signed capability downgrade during staged upload | Fresh server-side checks deny finalization and Photo SET; no new entitlement |
| P02-13 | Cross-school identical UUID/path and wrong deployment location revision | No cross-school object visibility or grant; versioned allowlist protects retained keys |
| P02-14 | Inspect repository, client build, test logs and F23/audit/receipt rows after all trials | No secret, signed URL, raw image, token or unsafe provider mapping leaked |
| P02-15 | Crash after remote seal but before metadata commit | Object reconciled privately; no fake PENDING premeasurement row or duplicate F23 |
| P02-16 | Simulate rollback, quarantine and teardown with a retained/held object | Does not equate VOID with physical deletion or destroy protected evidence |

Related full-lifecycle requirements: STP-001, 002, 004, 008–010, 016–020, 023, 027–035 and P01-01..P01-12 in the companion documents. A real adapter also needs the separate PA-03 image decoder and PA-05 entitlements before any usable upload route can be approved.

## Required owner/security selection and acceptance ledger

| Decision | Current status | Specific answer required |
|---|---|---|
| PA-02-R1 Jurisdiction and project region | **OPEN** | Actual customer-school legal/data residency requirement and approved Supabase region; never inferred from account geography |
| PA-02-R2 Disposable sandbox/account | **OPEN** | Owner-designated nonproduction project, payer/administrator and allowable synthetic data |
| PA-02-R3 Physical bucket design | **PROPOSED, NOT SELECTED** | Two private stage/final zones vs explicitly proven equivalent; document names and their deployment mappings without copying secrets |
| PA-02-R4 Credential and policy review | **OPEN** | Named independent reviewer, redacted least-privilege role matrix, key custody/rotation and service-key exceptions |
| PA-02-R5 Immutable-final guarantee | **OPEN** | Precise SDK/API version and provider proof across P02-04..08, including privileged routes |
| PA-02-R6 Expiry, incident stop and teardown | **OPEN** | Bound lifetimes, rollback/revocation semantics, operator approvals and retained-evidence rules |

Product preference alone approves none of these. Mark **SANDBOX APPROVED** only after owner and independent security signatures for the concrete isolation mapping, real-provider test evidence and acceptable failure behavior; do not infer production authorization from sandbox approval.

### Nonactivation / handoff

- Branch/PR #120 remains **draft**. This document changes **documentation only**. Do not merge into DB-01..04 or rebase their stacked PRs.
- No new migration, bucket, policy, provider key, SDK, image parser, CI credential or live API call is authorized here.
- Future real sandbox work must test against the then-current composed `main` and repeat the native photo vs Enrollment END/Campus Transfer/DB-01 lock and revocation races. Prior mock Photo #104/#105 green runs are not real-provider evidence.
- PA-01..08 remain **OPEN / default-deny**; `student.photo.set`, `STUDENT_PROFILE_PHOTO` activation and hosted Migration 10 deployment remain separately blocked.

**Example:** A clerk authorized at Campus A requests a student's image upload. The backend allocates one private staging key. If the student moves to Campus B, neither a previously issued staging capability nor a successful Supabase Storage upload allows finalization or photo linking; the later current Campus and entitlement checks deny it.
