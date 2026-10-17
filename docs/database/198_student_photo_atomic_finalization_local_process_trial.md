# Student photo — atomic FINALIZE vs signed entitlement revision, separate-process local trial

Date: 2026-10-17. **Status: isolated candidate; requires exact-head CI and independent review. NOT a private file service, production photo SET or real upload.** Prior frozen `main`: `715e8084170e6ff838f8a4b4b29735aa1fb5f1b2`, after [PR #89 freeze](197_student_photo_signed_entitlement_revision_ci_merge_freeze.md).

## Problem this isolated slice addresses

The previous Ed25519 snapshot verifier uses a durable **single-file SQLite** high-water revision, but `require_current` returns before a later file metadata write. An entitlement downgrade can commit between that check and an unfenced finalization. The [storage contract](../architecture/05_storage_entitlements_and_document_purposes.md) requires entitlement activation and finalization to be serialized with a current-revision recheck **before the protected metadata transition**. Previously accepted files survive downgrade, while new disallowed finalizations must fail.

## Implemented local-only trial

`tools/photo_validation/student_photo_atomic_finalize_fence_candidate.py` subclasses the frozen `LocalSignedPhotoSnapshotCandidate` and uses the **same trusted test SQLite file** and its existing `photo_snapshots` monotonic revision state. It adds only ephemeral **photo_trial_intents** and **photo_trial_events** tables inside a test database, never Foundation/D1 schema. These are intentionally named **TRIAL_PENDING / TRIAL_FINALIZED**, not a real file `AVAILABLE` state.

- `seed_synthetic_intent` creates fake, Student/Campus/school/project/actor-bound records strictly for tests. It is **not authenticated issuance** and must never be exposed.
- `accept_signed_revision_trial` invokes the existing **actual pinned Ed25519 verifier** over a new revision, then uses `BEGIN IMMEDIATE` to accept a **strictly higher** revision and record an audit event under the **same SQLite write fence** as finalization. Signed suspensions/downgrades commit through this path. No replay to an older/equal revision is allowed.
- `finalize_synthetic_intent` also begins with `BEGIN IMMEDIATE`, then **inside that same transaction** reads current active snapshot and the fake intent, rechecks school/project/Student/Campus/actor/purpose, original revision, current active entitlement, not-invalidated state, subscription expiry/cache freshness and intent expiry, and finally updates the fake intent from TRIAL_PENDING to TRIAL_FINALIZED with exactly one trial event. Failure rolls back with no partial receipt/event. A second attempt cannot finalize the same intent.
- Optional lock-observation callbacks are **test interlocks only**; neither method yields an upload credential, storage URL, real photo file, file-state transition or authorization token.

## Real separate-process evidence

`tools/photo_validation/tests/test_student_photo_atomic_finalize_fence_candidate.py` uses spawned Python processes and independent SQLite connections on the same temporary file. Both processes initialize before a controlled contender starts, making lock contention distinct from initialization. Synthetic test clock, real ephemeral Ed25519 signer, fake Student and intents, and process events are never production input. The tests exercise:

1. **FINALIZE acquires the write lock first:** a signed disabling revision blocks until trial finalization commits; exactly one TRIAL_FINALIZED/event at the earlier revision remains preserved, then the current revision becomes disabled. No later finalization succeeds.
2. **Signed downgrade acquires the write lock first:** trial finalization blocks, then observes the disabled new revision and denies; fake intent remains TRIAL_PENDING and no event/receipt exists.
3. **Two independent FINALIZE contenders:** only one consumes an identical fake intent, with one trial event.
4. Wrong school/project/Student/Campus/Principal, unknown intent, duplicate finalization, expiry/staleness/invalidation, signed revision rollback, and reopening a new SQLite connection all fail closed or preserve one canonical event as appropriate.

A contender's inability to complete while the other worker holds an SQLite write transaction is asserted. This establishes **single-host, same-DB-file ordering** and no atomic-check-then-update gap in this trial. It does **not** establish multi-host distributed locking, a genuine revocation push, real Student permissions/ownership or real provider storage.

## Production activation explicitly blocked

This code is in `tools/photo_validation` only, is a **non-deployable local SQLite concurrency experiment** and is not used by any app/worker/SQL RPC. It **does not implement** a shared control-plane revision authority across different machines/regions or an accepted future effective activation schedule, actual trusted Student-bound intent issuance/one-time storage verification, public/worker security boundary, domain permission current reads, image byte storage/hash, file-object lifecycle or Student DIRECT/P1 APPLY. The trial signer accepts test-created keys, its clocks and bindings are caller-provided, and the `after_lock` hooks exist exclusively for tests. Never treat `TRIAL_FINALIZED` or the returned integer revision as a real entitlement grant, available file or Student photo SET.

The trial also cannot guarantee simultaneous global revocation for offline schools; signed caching/freshness and propagation remain owner-approved production security design items. Any real activation needs a reviewed **shared distributed authority**, durable trust and audited multi-instance transactions with separate Principal/domain/scope binding, provider-neutral exact sanitized bytes, history/retention control, real file and protected-Student data, and genuine end-to-end race tests before approval.

**Frozen baseline unchanged:** 31/35 protected change operations accepted; Issue #67 open, Student Profile photo SET remains DENY; 34 D1 relations, 228 Migration 10 `.sql.draft` fragments, 97 permissions, 322 scope alternatives, 36 operations; no hosted Supabase changes or production upload authorization.

**Simple example:** Two independent processes use the same test database. If finalization wins the transaction lock, it records one fake finalized item before the signed subscription downgrade. If the downgrade wins first, the later finalization refuses the same item. Neither test stores a real student photo.
