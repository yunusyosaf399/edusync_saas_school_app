# Student Photo PA-02 — Single private bucket and backend credential preflight

**Reviewed:** 2026-10-22.
**Owner decision:** Option A — Supabase Storage ONLY, simple authenticated backend protection; do not pursue AWS, R2, Azure, or expensive WORM infrastructure.
**Status:** DESIGN + OFFLINE PREFLIGHT WRITTEN. INDEPENDENT SECURITY/CREDENTIAL VERIFICATION OPEN. BUCKET NOT CREATED. UPLOAD/PHOTO SET DISABLED.
**Scope:** Student Photo workstream only, draft code PR #135. Owner decision is recorded separately in draft PR #120. No modification to DB-01 through DB-04, executable migrations, Flutter, or school data.

## 1. Real provider re-inspection (read-only)

Read-only Supabase inspection was directed at the dedicated SchoolAgent synthetic photo lab in US-East (us-east-1); the other SchoolAgent staging project was not used or changed.

| Check | Actual observation | Interpretation |
|---|---|---|
| Storage buckets | **0** | No photo bucket has been provisioned |
| User-created Storage bucket + object policies | **0** | No ordinary-client policies currently configured |
| RLS for storage.objects and storage.buckets | **Enabled on both**; FORCE RLS false | Database RLS exists but is not absolute for privileged actors |
| anon and authenticated roles | BYPASSRLS false | Ordinary users remain subject to RLS; real HTTP denial tests NOT run |
| service_role | **BYPASSRLS true** | Elevated credential can bypass Storage RLS; key secrecy matters |
| Storage operations performed by this task | **NONE** | No DDL, bucket, policy, upload, download or key handling |

Supabase managed-table SQL grants do not automatically allow access: ordinary table permissions and RLS are separate checks. Do not treat zero Storage policies or a green advisor result as a passed security penetration test.

## 2. Finalized review candidate — ONE private physical photo bucket

The owner selected a simplified Supabase-only direction. The earlier two-bucket topology is no longer the preferred proposal. This is an APPROVAL CANDIDATE, not a deployed setting or an amendment to frozen F23 contracts.

| Setting | Proposed value | Must be enforced before a live sandbox test |
|---|---|---|
| Physical name | edusync-pa02-photo-private | Exact name, selected ONLY for dedicated synthetic photo lab |
| Bucket public flag | false | No public downloads |
| Allowed MIME | image/png and image/jpeg | Actual image must be safely decoded, re-encoded and stripped of sensitive metadata |
| Limit | 1,048,576 bytes | Verified sanitized FINAL bytes 1 through 1,048,576 inclusive |
| Extra photo buckets in lab | none | Reject unexpected inventory |
| Storage object and bucket RLS | enabled | Never modify managed schema ownership or remove RLS |
| Ordinary client Storage policies | none | No public, authenticated or anonymous direct Storage upload/list/read policies in the candidate |
| Deployment-owned logical location | PHOTO_PRIVATE_TRIAL (candidate only) | Not an active F23 business code or a client-selectable field |
| Final object key | photo/<server-school-UUID-v4>/<server-file-UUID-v4> | Fresh server-allocated key for every new/replacement photo; no user-supplied key |
| Write | authenticated server-only POST create, upsert false | No user-facing DELETE, LIST, COPY, MOVE or UPSERT route |
| Read | authenticated server-only private GET | Fresh School, Student, Principal, PRIMARY Campus and entitlement check |
| Receipt | ACKED_NOT_VERIFIED until server reads bytes back and checks SHA-256/size | Must not issue F23 AVAILABLE or Student Photo SET based on ACK/ETag alone |

This one-bucket proposal does not provide provider-level administrator-proof immutability. The owner accepts simple application-level overwrite protection rather than native WORM. Full privileged key misuse can still delete or replace bytes. Preserve a truthful risk statement and reconcile it with frozen ADR-003/F23 before any production approval.

## 3. Minimal backend secret-custody checklist — not yet verified

1. Select a **named server-only Supabase secret key** for the eventual owning School project; a legacy service_role key is an explicitly reviewed fallback, not a client credential.
2. Keep it in the authorized runtime secret manager. Never embed any Supabase privileged key in Flutter/Web/Windows binaries, GitHub files, build logs, CI artifacts, application settings or browser-generated URL.
3. Limit privileged key use to a trusted Photo backend service after real JWT and current PostgreSQL-domain Student/School/PRIMARY-Campus authorization. It must never be an arbitrary public Storage relay, object path proxy or cross-School service.
4. Assign an operations owner for key rotation, suspected leakage, revocation and incident stop; demonstrate that these procedures work with the real connected credential.
5. An independent reviewer must verify actual custody, client exposure risk, privileged-bypass scope, current server resolver connection and negative authorization tests. **No actual credential was created, requested, accessed, displayed or tested here.**
6. A named secret key enables independent rotation, but it does NOT make the privileged service key obey ordinary Storage object RLS. No secret name or signed paper checklist is a substitute for authorization.

Supabase sources: [API keys](https://supabase.com/docs/guides/getting-started/api-keys), [secret-key migration and rotation](https://supabase.com/docs/guides/getting-started/migrating-to-new-api-keys), [Storage access control](https://supabase.com/docs/guides/storage/security/access-control), [private bucket fundamentals](https://supabase.com/docs/guides/storage/buckets/fundamentals) and [bucket creation parameters](https://supabase.com/docs/guides/storage/buckets/creating-buckets).

## 4. Machine-checkable OFFLINE preflight (draft PR #135 only)

The following two files are added on the Photo implementation branch:

- tools/photo_validation/student_photo_supabase_bucket_preflight_candidate.py — pure offline validator of **non-secret observed bucket and Storage RLS settings**, plus unverified credential-custody declarations. It has no Supabase SDK, HTTP, SQL writes, environment-secret loader, network, project ID, Storage bucket mutation or operational enable switch.
- tools/photo_validation/tests/test_student_photo_supabase_bucket_preflight_candidate.py — **12 synthetic unit cases** checking the valid empty/matching private-bucket states; wrong region/project health; public/wrong/extra buckets; malformed MIME/size; disabled RLS; unexpected policies; false credential declarations; and no operational activation. CI workflow runs these tests and checks the source stays nonoperational.

Outcome strings are deliberately cautious: **NOT_PROVISIONED** when zero buckets are reported; **CONFIG_MATCH_ONLY_NOT_AUTHORIZED** when a hypothetical bucket fits; **REVIEW_OPEN** for incomplete key-custody declarations; **CLAIMS_ONLY_UNVERIFIED** for a fully checked but unverified paper declaration. **runtime_photo_upload remains DENY in every case.** The method intended to approve live setup deliberately raises a denial.

These tests prove only that our intended preflight logic fails closed for tested fixtures. They do not establish live provider permissions, backend domain authorization, new credentials, uploaded bytes or a successful runtime negative test.

## 5. Approval and acceptance gates after this work

| Gate | Current state | Next independent action |
|---|---|---|
| Product provider | **Owner confirmed Supabase ONLY** | No external cloud procurement |
| PA-02 R3 single private bucket | **Review candidate ready; NOT provisioned** | Explicit owner approval for bucket creation + reviewer confirmation of name/MIME/size/mapping |
| PA-02 R4 backend credential security | **Checklist drafted; not verified** | Security checks actual server secret manager, rotation, no client exposure and live Student context |
| PA-02 R5 real-provider trials | **NOT RUN** | After approval: synthetic-only private read/write denial, same-key no-upsert, actual readback digest, ack-loss and scope tests |
| PA-02 R6 operations/retention | **OPEN** | Owner/reviewer confirm test expiry, incident stop and controlled teardown, without silent deletion of evidence |
| PA-03–08, F23 and Student Photo SET | **DENY** | Complete independently reviewed decoder, durable intent, current grants, final-byte proof and rollout tests |

## 6. Noncollision and next task

This task is **documentation and code-only preflight**. It does not create the private bucket, SQL policy, service-role or secret key, Storage object, actual operational Photo service, migration, public route, Student photo relationship or change in any parallel DB-01..04 workstream. The PR stays **DRAFT** and may be code-reviewed but not presented as real hosted Storage acceptance.

The next change requires an explicit, separate approval to create **one private bucket** in the **dedicated synthetic US-East lab** with the exact restrictions above, after independent credential/retention reviewer decisions. If authorized, perform a read-after-create verification before any synthetic upload. No actual student images or production school project can be used.

**Related:** [#233 inert REST adapter](233_student_photo_supabase_private_adapter_inert_wire_and_bucket_preflight_20261022.md); [owner decision PR #120](https://github.com/yunusyosaf399/edusync_saas_school_app/pull/120); [ADR-003](../decisions/ADR-003-provider-neutral-object-storage.md).
