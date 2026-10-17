# Student Profile photo — Ed25519 signed entitlement/local revision CI and merge freeze

Date: 2026-10-17. **Verdict: PR #89 exact-head CI PASS; MERGED; freeze for isolated security candidate only, NOT production upload, subscription activation or Student photo SET.**

## Provenance and independent diff gate

- Prior `main` freeze: `35a70c676a58ba2ad67031222b7626c637bcde0e` (PR #88 accepted evidence).
- [PR #89](https://github.com/yunusyosaf399/edusync_saas_school_app/pull/89) verified exact head: `08c55a6eaf08d5680d6fc12c545efe41721f2281`; merged on tested head by merge commit `1ed6aa6d0cd1db57bbc71c0428be7f403867d4a1`.
- Exact PR comparison: only four files: `tools/photo_validation/student_photo_signed_entitlement_candidate.py` (+293 lines), `tools/photo_validation/tests/test_student_photo_signed_entitlement_candidate.py` (+223 lines), `.github/workflows/student-photo-content-candidate.yml` (+6/-1), and `docs/database/196_student_photo_signed_entitlement_revision_candidate.md` (+32 lines). No active/draft migration, protected D1 contract, role grant, public RPC, production upload endpoint, hosted Supabase update or existing Student photo validator mutation.

## Exact-head CI evidence

All four GitHub Actions `pull_request` runs on `08c55a6eaf08d5680d6fc12c545efe41721f2281` **completed successfully**:

1. [Student photo candidate run #39054872841](https://github.com/yunusyosaf399/edusync_saas_school_app/actions/runs/39054872841): **31/31 unit tests PASS** — 11 existing real decoded JPEG/PNG validation and sanitization tests, 9 prior synthetic upload-intent policy tests, **11 new real Ed25519-signed snapshot and local SQLite revision persistence/anti-rollback tests**. Marker: `D1_STUDENT_PHOTO_CONTENT_CANDIDATE_PASS`; upload remains disabled.
2. [D1 Migration 10 static run #39054872856](https://github.com/yunusyosaf399/edusync_saas_school_app/actions/runs/39054872856): **PASS** `D1_DRAFT_STATIC_PASS` and `D1_FUNCTION_FINAL_PASS` — 228 draft fragments, 34 relations, 97 permissions, 322 scope alternatives, 36 operations; no changed frozen SQL topology.
3. [Foundation local-stack run #39054872862](https://github.com/yunusyosaf399/edusync_saas_school_app/actions/runs/39054872862): **PASS** `FOUNDATION_LOCAL_CI_PASS` 9 files, 220 planned, **220/220 passed**, local-only database.
4. [D1 Migration 10 local-runtime run #39054872897](https://github.com/yunusyosaf399/edusync_saas_school_app/actions/runs/39054872897): **PASS** `D1_BUSINESS_PASS 3124 assertions`, `D1C2A_PASS` — disposable local runtime only; Migration 10 remains `.sql.draft`.

## What the new candidate establishes — and does NOT establish

The new Python unit model verifies **actual Ed25519 signatures** over an explicitly domain-separated, deterministically encoded JSON envelope, with pinned expected issuer and public key identifier, exact school/project audience, strict versioned payload/type/capability/subscription and finite candidate expiry/freshness requirements. Its **local-file SQLite** rehearsal stores a monotonic accepted revision, payload fingerprint, freshness, invalidation and candidate audit records across separate connections. A valid older revision cannot reactivate a locally suspended/downgraded school; malformed signatures, wrong keys, altered payloads and duplicate JSON fields fail. It also checks local two-connection update contention.

**No production trusted signer, distribution protocol or key rotation is present.** The demo's pinned keys come from ephemeral tests and the module trusts its constructor's input; never pass client-supplied public keys, SQLite paths, school/project context or clocks. The envelope protocol, 300-second snapshot age/lifetime, 60-second local freshness and zero clock skew are **unapproved test constants**, not deployment decisions. Same-file SQLite transactions are not shared multi-host revision locks; `require_current` is not ordered atomically with production finalization and cannot authorize an upload. There is no durable distributed high-water/fence, actual push invalidation, trusted actor/Student scope lookup, purpose-bound worker, provider byte storage, genuine issued or consumed intent, or real two-session Student photo DIRECT/P1 APPLY acceptance in this PR. The separately frozen synthetic intent model is **not** cryptographic authorization and still uses caller-constructible evidence.

**All activation hard stops remain:** Issue #67 Student Profile Update P1 OPEN, **31/35 protected operations accepted**, Student photo SET DENY by default; 34 relations, 228 D1 Migration 10 `.sql.draft` fragments, 97 permissions, 322 scope alternatives, 36 contracts unchanged; hosted Supabase unaffected. No runtime service should import or invoke this module to authorize production uploads.

**Simple example:** An attacker changes an authentic School A photo entitlement to claim School B or alters the expiry date: its Ed25519 signature fails. An older still-valid signed revision also fails to undo a newer local suspension. This is not yet proof that separate servers would agree at the same instant.

## Next candidate recommendation

Prove **shared-durable active-revision fencing and atomic FINALIZE ordering** across separate local processes, including revoked entitlement/revision races and replay after restart, before any approved backend integration. Real multi-host coordination, trusted key management and principal/Student-bound upload intent issuance remain additional required activation gates.
