# Student photo — local durable signed private-service opaque intent CI/merge freeze

Date: 2026-10-18. **Verdict: PR #91 exact-head four-workflow CI PASS and MERGED; isolated candidate evidence ONLY, never a real Student upload/finalization activation.**

## Reproducible provenance and reviewed scope

- Frozen pre-PR baseline: `3a8666e56e25d6087dd98085a917fdf9ae987165` (post-PR90 local atomic FINALIZE freeze).
- [PR #91](https://github.com/yunusyosaf399/edusync_saas_school_app/pull/91) tested exact head `c14cba3826885fabb379f2e83a31b262f6c4cbc8`; confirmed GitHub merge commit `57cd8cc0b011bf215d615168351549a4923a1be1`.
- Actual diff independently compared to frozen baseline: four intended files only: `tools/photo_validation/student_photo_durable_intent_candidate.py` (+286 lines), `tools/photo_validation/tests/test_student_photo_durable_intent_candidate.py` (+323 lines), `.github/workflows/student-photo-content-candidate.yml` (+6 lines) and `docs/database/200_student_photo_durable_private_opaque_intent_candidate.md` (+35 lines). Zero SQL migrations, frozen contract modifications, app routes, hosted storage, public RPC or role grants.

## Exact-head CI evidence

All four workflows completed successfully on `c14cba3826885fabb379f2e83a31b262f6c4cbc8`:

1. [Student photo decoded-content candidate #39091582117](https://github.com/yunusyosaf399/edusync_saas_school_app/actions/runs/39091582117): **49/49 unit tests PASS** — 11 JPEG/PNG decoded content/sanitization tests, 9 synthetic ISSUE/FINALIZE policy tests, 11 Ed25519 control-plane signed entitlement and local revision tests, 7 separate-process trial FINALIZE-versus-downgrade tests, **11 new private signed-service opaque intent tests**. The two spawned-process consume-once scenario passes. `D1_STUDENT_PHOTO_CONTENT_CANDIDATE_PASS` confirms upload stays disabled.
2. [D1 Migration 10 draft static #39091582146](https://github.com/yunusyosaf399/edusync_saas_school_app/actions/runs/39091582146): **PASS** — `D1_DRAFT_STATIC_PASS`, `D1_FUNCTION_FINAL_PASS`; frozen 228 fragments, 34 relations, 97 permissions, 322 scope alternatives and 36 operation contracts.
3. [Foundation local stack #39091582099](https://github.com/yunusyosaf399/edusync_saas_school_app/actions/runs/39091582099): **PASS** — `FOUNDATION_LOCAL_CI_PASS 9 files / 220 planned / 220 passed`.
4. [D1 Migration 10 local runtime #39091582148](https://github.com/yunusyosaf399/edusync_saas_school_app/actions/runs/39091582148): **PASS** — `D1_BUSINESS_PASS 3124 assertions`, `D1C2A_PASS`; disposable local runtime, Migration 10 still `.sql.draft`.

## Bounded security conclusion

The non-production Python candidate demonstrates an **actual random opaque, domain-separated SHA-256-hashed token ledger** tied to Student, Campus, school, project, initiating Principal, purpose, issued revision, expiry and ISSUED/CONSUMED state in a temporary SQLite file. A *separately* signed Ed25519 trial private-service request binds exact ISSUE/CONSUME operation, unique nonce, claimed verified actor/grants/ownership/module/purpose, and — on consumption — that exact token digest. Both stages use a `BEGIN IMMEDIATE` write transaction to recheck current signed snapshot eligibility and record an atomic change. Tests cover forged or replayed proof, token substitution and wrong Student binding, revocation/downgrade/invalidation, durable reopening, expiry and two spawned processes attempting to consume one token.

The synthetic test signer **does not establish authentic user authentication, real Principal role/scope grants, school subscription refresh, Student PRIMARY placement or ownership, or an actual private service**. Its signed Boolean assertions are fixture data, not an independent source of authority; its test keys/path/time are supplied locally, not by a reviewed service deployment. A hash/nonce ledger alone is not an upload transport/credential nor a safe substitute for restricted file-worker entry points. The temporary SQLite lock **does not coordinate multiple hosts**. No provider writes real sanitized bytes; no protected `file_objects` state moves to AVAILABLE; no genuine Student photo DIRECT/APPROVAL APPLY, audit/retention or hosted Supabase transition occurs. No public endpoint should use this candidate as authorization.

**Protected-operation state remains 31/35 accepted**; Issue #67 OPEN; Student Profile photo SET **DENY**; 34 D1 relations, 228 Migration 10 `.sql.draft` fragments, 97 permissions, 322 scope alternatives, 36 contracts frozen; no hosted deployment or activation.

**Simple example:** Trial administrator A has a random opaque token for Student A. The local ledger stores its hash rather than the raw token; a signed request to use it for Student B fails, and two independent processes cannot both consume it. That result is not a real photo upload.

## Next isolated gate

Create a **trusted actor/Student placement/grant resolver integration trial**, anchored to actual verified-principal and Student PRIMARY placement in a disposable local DB, without treating any signer-created Boolean as a permission. Keep real upload, provider persistence and multi-host revocation blocked pending separate review.
