# Student Profile photo — synthetic entitlement and upload-intent policy CI/merge freeze

Date: 2026-10-17. **Verdict: all exact-head CI PASS; PR #88 MERGED. Non-production eligibility-model tests ONLY.** Not an accepted Student photo upload/finalization operation or positive Student Profile photo SET.

## Review provenance

- Previously frozen `main`: `3f6c218139a502eb6afdaff910ea47427a4cc6cd` (PR #87 freeze).
- [PR #88](https://github.com/yunusyosaf399/edusync_saas_school_app/pull/88) exact tested HEAD `bf4bc7dbcf73edf0452eb1524b42ef1680af2dce`; confirmed merge commit `d08548893d716f16d7855102dd135941daf881e0`.
- Independently checked exact PR diff: four approved paths only: `tools/photo_validation/student_photo_intent_entitlement_candidate.py` (+177 lines), `tools/photo_validation/tests/test_student_photo_intent_entitlement_candidate.py` (+174 lines), `.github/workflows/student-photo-content-candidate.yml` (+2 lines), and `docs/database/194_student_photo_intent_entitlement_candidate.md` (+35 lines). **No active/SQL-draft migration, direct RPC, provider adapter, hosted database, production endpoint, grants or existing frozen validator changes.**

## Exact-head workflow outcomes

All four `pull_request` runs completed successfully against `bf4bc7dbcf73edf0452eb1524b42ef1680af2dce`:

1. [Student photo decoded-content candidate #39051576656](https://github.com/yunusyosaf399/edusync_saas_school_app/actions/runs/39051576656): **PASS** — existing 11 real JPEG/PNG decode/sanitization tests plus **9 new synthetic entitlement/intent eligibility tests**, each independently reported `OK` (`D1_STUDENT_PHOTO_CONTENT_CANDIDATE_PASS`). This local unit-test verdict is not signed control-plane authority.
2. [D1 Migration 10 draft static #39051576661](https://github.com/yunusyosaf399/edusync_saas_school_app/actions/runs/39051576661): **PASS** — `D1_DRAFT_STATIC_PASS` (228 fragments, 34 relations, 97 permissions, 322 scope alternatives, 36 operations) and `D1_FUNCTION_FINAL_PASS`.
3. [D1 Migration 10 local runtime #39051576670](https://github.com/yunusyosaf399/edusync_saas_school_app/actions/runs/39051576670): **PASS** — `D1_BUSINESS_PASS 3124 assertions`, synthetic rollback-only Student photo provenance gate and `D1C2A_PASS`; disposable local DB only, Migration 10 still **`.sql.draft`**.
4. [Foundation database local stack #39051576681](https://github.com/yunusyosaf399/edusync_saas_school_app/actions/runs/39051576681): **PASS** — `FOUNDATION_LOCAL_CI_PASS 9 files / 220 planned / 220 passed`; isolated local stack.

## Model scope and security hold

The added pure Python model `check_photo_new_use_candidate` tests two stages: **ISSUE**, requiring internally modeled trusted school/project snapshot, currently active revision/freshness, the exact `storage.student_photo.upload` entitlement, eligible subscription, verified actor, private worker, module, approved purpose and live file/photo permissions and Student scope/ownership; and **FINALIZE**, requiring all of those again plus matching, unconsumed, unexpired, Student/school/Campus/Principal-bound original intent, including deny after downgrade/suspension/revocation.

**Critically, the Python dataclass evidence fields are supplied by synthetic in-memory test fixtures.** True signed snapshot verification, issuer/key material, durable anti-rollback/high-water records, atomic revision activation, trusted upload intent issuance/one-time consumption, real backend principal and Student authorization, purpose-bound workers, provider persistence of sanitized image bytes, file state changes, telemetry/retention, multi-service/multi-session races and final positive protected Student photo LINK/APPLY acceptance **are neither implemented nor proven here**. Never wire these caller-constructible evidence objects into a public upload endpoint as security claims. No new upload or attachment is enabled.

**Freeze unchanged:** Student Profile photo SET **DENY by default**, Issue #67 **OPEN**, **31/35 protected change operations accepted**; 34 D1 relations, 228 draft fragments, 97 permissions, 322 scope alternatives and 36 operation contracts unchanged. No hosted Supabase migration or production deployment authorized.

**Simple example:** An administrator obtains an intent for Student A while the school has photo-upload entitlement. A subscription downgrade or the administrator's permission revocation before FINALIZE causes the candidate policy check to deny. The original intent cannot be reused for Student B. This is only proof of deterministic decision logic with fake trust evidence, not a real upload.

## Recommended next protected gate

Implement a separately reviewed **cryptographically verified signed school/project entitlement snapshot plus bounded, monotonic, shared revision cache candidate**, with explicit finite policy settings and negative signature/audience/revision/expiry tests, still isolated from production uploads. Later implement trusted durable Student-specific issuance/finalization and genuine concurrency evidence; do not activate Student photo SET early.
