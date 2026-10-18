# Student Profile photo — spawned-process atomic finalization versus signed revision CI/merge freeze

Date: 2026-10-18. **Verdict: PR #90 exact-head CI PASS and MERGED; local test-evidence freeze only.** No live Student photo upload, real file AVAILABLE transition, hosted database deployment or Student Profile photo SET is authorized.

## Exact provenance and reviewed scope

- Prior frozen `main`: `715e8084170e6ff838f8a4b4b29735aa1fb5f1b2` (PR #89 freeze).
- [PR #90](https://github.com/yunusyosaf399/edusync_saas_school_app/pull/90) tested exact head `e85ae70fcc7af58acfa00306df5aaef23a3ebb91`; GitHub confirmed merge SHA `f780a2d402e392be5abfb535d0a063c34702a04d`. Final branch and `main` comparison confirmed only the intended four paths changed.
- Paths: `tools/photo_validation/student_photo_atomic_finalize_fence_candidate.py` (+165 lines), `tools/photo_validation/tests/test_student_photo_atomic_finalize_fence_candidate.py` (+269 lines), `.github/workflows/student-photo-content-candidate.yml` (+6 lines), and `docs/database/198_student_photo_atomic_finalization_local_process_trial.md` (+37 lines). Zero active/draft migration changes, public RPC, role changes, real provider/Student file service or hosted Supabase modifications.

## Exact-head GitHub Actions verification

All four pull-request workflows **completed successfully** against `e85ae70fcc7af58acfa00306df5aaef23a3ebb91`:

1. [Quarantined Student photo tests #39057246015](https://github.com/yunusyosaf399/edusync_saas_school_app/actions/runs/39057246015): **38/38 unit tests PASS** — previously frozen 11 real decoded-content tests, 9 synthetic ISSUE/FINALIZE policy tests and 11 real Ed25519/local revision tests, plus **7 new transactional synthetic intent tests**. Genuine spawned-process checks passed for FINALIZE-first versus signed downgrade, signed downgrade-first versus FINALIZE denial, and two competing FINALIZE attempts; one fake intent/event is consumed at most once.
2. [D1 Migration 10 draft static #39057246022](https://github.com/yunusyosaf399/edusync_saas_school_app/actions/runs/39057246022): **PASS** `D1_DRAFT_STATIC_PASS`, `D1_FUNCTION_FINAL_PASS`; 228 draft fragments, 34 relations, 97 permissions, 322 scope alternatives, 36 protected operations.
3. [Foundation database local stack #39057246003](https://github.com/yunusyosaf399/edusync_saas_school_app/actions/runs/39057246003): **PASS** `FOUNDATION_LOCAL_CI_PASS`, 9 files and **220/220 planned assertions**.
4. [D1 Migration 10 local runtime #39057246043](https://github.com/yunusyosaf399/edusync_saas_school_app/actions/runs/39057246043): **PASS** `D1_BUSINESS_PASS 3124 assertions`, `D1C2A_PASS`; disposable local database, Migration 10 remains `.sql.draft`.

## Precisely bounded conclusion

Under a single **shared SQLite test file**, two separate spawned Python processes use `BEGIN IMMEDIATE` on the **same** snapshot revision and synthetic intent tables to order signed entitlement change against a trial finalization. A finalized trial event can commit only if the then-current cached entitlement is active and the exact Student/Campus/Principal/school/project fake intent is pending and unexpired. If downgrade commits first, later finalization denies without consuming or writing a fake receipt. Once consumed, replay denies, and newly disabled entitlement cannot be overridden with a stale signed revision. Test interlocks deliberately separate construction/setup time from actual write-lock contention.

This is **not a real file finalization or production authorization mechanism**. The `photo_trial_intents` and `photo_trial_events` rows are generated synthetic evidence, not protected `file_objects`. The test module trusts its synthetic actor, school/project, clock, local path and public keys. No actual trusted issuance and consumption service, Student authenticated scope/ownership verification, provider-neutral exact sanitized-byte persistence, transaction-ordered protected PENDING→VALIDATED→AVAILABLE file transition, hosted SQL controls, real two-session Student DIRECT/P1 APPLY nor genuine multi-host distributed revision fencing is implemented. Local SQLite serialization **does not prove cross-machine concurrent safety**. Owner-approved production expiry, snapshot freshness/propagation and security review remain unresolved. No app endpoint may use this module as a real upload grant.

**Unchanged freeze:** 31/35 protected change operations accepted; Issue #67 open, Student Profile photo SET **DENY**; 34 relations, 228 Migration 10 draft fragments, 97 permissions, 322 scope alternatives and 36 contracts frozen. No hosted Supabase migration, upload deployment or storage policy activation.

**Simple example:** When a local synthetic upload FINALIZE holds the database write transaction first, one fake receipt commits before the signed subscription revocation. When revocation holds it first, the fake FINALIZE fails and records no receipt. This evidence is necessary but far from sufficient to activate real Student photo uploads.

## Suggested next isolated gate

Demonstrate **actual durable opaque Student/school/Principal-bound upload intent issuance with strict private service identity and one-time consumption**, then separate verified provider-byte and file-object transition integration in a local stack. Real shared multi-host revision storage must be designed before any production authorization or finalization.
