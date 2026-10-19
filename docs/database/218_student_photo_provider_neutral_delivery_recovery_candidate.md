# Student Photo — provider-neutral delivery and uncertain-ACK recovery candidate

Date: 2026-10-19. **Candidate, local-only, not accepted until exact-head CI.** This is a separate **SQLite metadata stand-in**, NOT a real object-storage provider or real photo upload.

## Frozen source and reason for this gate

Continue from frozen `main` `e526de3fd4668483623ef52cccc34d38d893c249`, [PR #99 freeze](217_student_photo_native_pg_lost_ack_receipt_outbox_ci_merge_freeze.md). PR #99 proved a native PostgreSQL receipt and durable outbox with a mock sink in **the same PostgreSQL transaction**. That alone cannot model an external service independently committing before PostgreSQL records success. This test intentionally introduces **two separate durable transaction domains**, while still writing **no file bytes or media objects**.

## Isolated private fixture and trust limits

- The disposable `supabase_db_saas_OS_school_app` runtime creates one new synthetic Person/Student/status under the preexisting *verified* local test Principal; a real authenticated public `app.d1_place_student_enrollment(...,'INITIAL')` P0 operation creates a genuine current PRIMARY Enrollment and Roll. No direct Enrollment/Roll DML.
- The accepted PR #99 native receipt and `outbox_events` tables remain authoritative for committed CONSUME tokens and events. A new **local-only** `photo_pg_trial.provider_dispositions` table links stable event ID and hashed provider key to terminal **ACKED** or **CANCELLED**, with owner-only access, FORCE RLS and explicit revocation of PUBLIC, anon, authenticated, and service_role.
- A separate file-backed **SQLite mock metadata provider** has its own committed transaction, unique delivery key and event identity, plus `ACCEPTED` / `VOIDED` states. It contains **only event UUID, token digest, action and delivery key**; there is no image payload, object path, network request or file lifecycle.
- Delivery key = SHA-256 over a domain-separated fixed string, canonical event UUID bytes, SHA-256 token digest and bounded action. The token **bearer never leaves the trusted local photo worker**. Same event reuses the same key; mismatched payload or replay after VOID rejects.
- The trusted **no-login local queue worker** claims `PENDING` PostgreSQL outbox event with `FOR UPDATE SKIP LOCKED`; revalidates current Principal, Student row lock, current PRIMARY and Campus/photo/profile scope, cross-checks the authenticated receipt and token state; then invokes the separate provider mock. It only records `ACKED` disposition and acknowledges outbox inside the PostgreSQL transaction **after** a matching provider acceptance. Failed authorization must deny before the separate provider side effect. This is **not** a public API or production service credential.

## Five failure sequences tested

1. **Failure before provider acceptance:** no provider record, PostgreSQL event remains PENDING with no ACKED disposition; retry possible.
2. **Provider commits but reply is lost:** separate SQLite commits ACCEPTED; PostgreSQL transaction rolls back, event remains PENDING. A new worker retries using the **same deterministic key**, reads the provider's existing acceptance and writes exactly one PostgreSQL ACKED disposition. Privileged local-only requeue must not generate a second provider record.
3. **Concurrent two-worker claim:** first worker locks the PostgreSQL queue event, commits the synthetic provider acceptance in its separate SQLite file, then pauses before PostgreSQL ACK. Second independent PostgreSQL worker uses SKIP LOCKED and must find no work; releasing first worker commits ACK, without an additional metadata record.
4. **PostgreSQL commits but its ACK is lost:** synthetic provider and PostgreSQL disposition both committed; repeated poll finds no pending event. No second provider event is created.
5. **Stale authorization / compensation:** provider accepts an event but its acknowledgement is lost before PostgreSQL commit. The **real authenticated protected P1 `app.d1_end_student_enrollment`** closes the student's current PRIMARY. Normal photo delivery now denies. A *privileged disposable-only reconciliation worker* verifies there is no current effective PRIMARY, invokes **idempotent metadata-only VOID**, and writes a distinct `CANCELLED` disposition before marking the event processed. A VOID reply lost after provider commit is retried and leads to the same terminal result. The historic native photo token remains CONSUMED, never File AVAILABLE or Student photo SET.

The last test intentionally distinguishes **processing completed as CANCELLED** from **successfully ACKED** by using a separate private disposition table; `outbox_events.delivery_state='DELIVERED'` by itself is only queue processing state and must **not** be presented as file availability. No live provider deletion guarantee is inferred from a SQLite metadata VOID.

## Exact-head acceptance

The change must pass:
- Foundation `FOUNDATION_LOCAL_CI_PASS 9 files / 220 planned / 220 passed` and all source tests.
- D1 `D1_BUSINESS_PASS 3124 assertions`, all accepted PR #94–99 Student Photo markers, new **`D1_STUDENT_PHOTO_PROVIDER_NEUTRAL_DELIVERY_PASS`** and **`D1_STUDENT_PHOTO_PROVIDER_NEUTRAL_COMPENSATION_PASS`**, then `D1C2A_PASS`.
- No failed workflow, missing real PostgreSQL race, unexpected file change or new hosted grant is acceptable. Candidate PR stays draft until proven and separately reviewed.

## Explicit nonactivation and next independent gate

This trial **cannot** prove exactly-once behavior with S3/Supabase Storage or other real providers, HTTP partitions, authentication credentials, retries across machines, irreversible media writes, remote deletion, costs, encrypted storage, content hash validation, uploaded bytes-to-File binding, scan/sanitize/EXIF handling, permanent File records, outbox metrics or webhook signatures. It does not implement recovery of an initial lost ISSUE bearer response. Current production subscription/module/purpose/`file.upload` authorization and a real immutable Student-photo file provenance gate remain unimplemented, and Student Profile photo SET stays **DENY**. `CANCELLED` here means *metadata mock VOID*, not physical object deletion or image privacy erasure.

Next review should formalize an external provider contract (stable opaque idempotency, authenticated service identity, signature verification, content provenance, cancellation retention, reconciliation SLA and alerting) before implementing any hosted integration. Migration 10 remains non-executable `.sql.draft`, **31/35 protected operations** accepted and no real Student Photo upload enabled.

**School example:** A staff photo-intent event reaches the fictional provider, but the acknowledgment is lost. A retry finds the existing event rather than repeating it. If the student's Enrollment is later ended before final acknowledgment, the isolated mock metadata is voided and the event records CANCELLED—not a live picture or File AVAILABLE.
