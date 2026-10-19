# PR #97 — Reverse Student Photo / protected END and Campus Transfer race CI merge freeze

Date: 2026-10-19. **Verdict: ACCEPTED as an isolated, disposable local PostgreSQL concurrency experiment only. This is NOT File AVAILABLE, Student Profile photo SET, hosted SQL, or a production upload authorization.**

## Exact provenance

- Prior frozen `main`: `30d7cf940f5533e6ffac32f68829532f453055d3`, documented in [PR #96 freeze](211_student_photo_protected_enrollment_end_intent_race_ci_merge_freeze.md).
- [PR #97](https://github.com/yunusyosaf399/edusync_saas_school_app/pull/97) was tested at exact head `2d3d67026b3a534dcc111cc70b2a5c60eda8ba5e`.
- Original frozen main verified unchanged; PR was draft/open/mergeable and moved to ready only after both exact-head successful workflows and five-file scope checks. SHA-guarded GitHub merge reported success at `94df21e91e257f6ec6a4d10db7d1d54c3ace435e`. Independently verified `main` equals that SHA and PR is closed/merged with the same merge commit.
- The merged delta from previous frozen `main` consists of **five intended files only**:
  1. `docs/database/212_student_photo_reverse_end_and_campus_transfer_races_candidate.md` — candidate behavior and unproven boundaries.
  2. `tools/supabase/domain_photo_postgres_native_intent_ci.py` — guarded test-only precommit callback seam in an existing *local* token transition; no public endpoint.
  3. `tools/supabase/domain_photo_reverse_end_campus_transfer_ci.py` — new two genuine protected-command concurrency trials.
  4. `tools/supabase/domain_student_photo_real_pg_handoff_ci.py` — invokes both new trials only after previous accepted local photo security tests.
  5. `tools/supabase/tests/test_domain_photo_reverse_end_campus_transfer_ci.py` — source/frozen-signature, real P0/P1 RPC, lock-observer and local-only fail-closed guards.
- No SQL migration, direct synthetic Enrollment/Roll insert, wider client grants, File AVAILABLE API, or hosted environment modification was merged.

## Two exact-head CI results: completed / success

1. [Foundation database local stack #39193297515](https://github.com/yunusyosaf399/edusync_saas_school_app/actions/runs/39193297515): **SUCCESS**, `FOUNDATION_LOCAL_CI_PASS 9 files / 220 planned / 220 passed`; 282 Python tests.
2. [D1 Migration 10 local runtime #39193297414](https://github.com/yunusyosaf399/edusync_saas_school_app/actions/runs/39193297414): **SUCCESS**, 122 Python runner/source tests, `D1_BUSINESS_PASS 3124 assertions`, existing `D1_STUDENT_PHOTO_NATIVE_PG_INTENT_PASS`, `D1_STUDENT_PHOTO_REAL_PG_HANDOFF_PASS`, `D1_STUDENT_PHOTO_PROTECTED_END_INTENT_RACE_PASS`, new **`D1_STUDENT_PHOTO_REVERSE_END_CAMPUS_TRANSFER_RACES_PASS`**, final `D1C2A_PASS`. The Migration 10 domain artifact still remains nonexecutable `.sql.draft`.

These exact-head checks are the acceptance evidence, rather than prior or unrelated workflow statuses.

## What the disposable local test now establishes

A preexisting D1 local test stack and protected fixture are first prepared. Two **new** synthetic Students and their initial person/status contexts are created, and each Student receives a genuine accepted PRIMARY Enrollment and Roll from the real authenticated `app.d1_place_student_enrollment` P0 application command. The two races do not forge Enrollment or Roll history.

**Reverse END winner:** For the first Student, an existing native PostgreSQL intent is CONSUMED. A live PostgreSQL worker performs `FINALIZE_TRIAL` and intentionally holds its valid token/Student-lock transaction **before commit** using a private Python test-only callback. The independently authenticated test Principal then invokes the real public `app.d1_end_student_enrollment` P1 DIRECT RPC. An observer detects a real unresolved PostgreSQL tuple/transaction-ID lock dependency on the photo worker's backend. Once released, the photo-state transition commits first; END then commits and leaves no current PRIMARY. Fresh intent issuance and stale repeat finalization are rejected after END. `FINALIZE_TRIAL` is a **test-only token state**, not actual media availability or application of Student photo.

**Campus Transfer winner:** For the second Student, a new Campus B and its legitimate same-School Class and Section offerings/capacity revisions are created in the disposable stack. One Campus A token is left ISSUED and a second is already CONSUMED. A different authenticated database session runs the real `app.d1_move_student_enrollment(...,'CAMPUS_TRANSFER',...)` P1 DIRECT RPC from Campus A to B, leaving its transaction holding Student row lock. Two live native PostgreSQL consumers then attempt CONSUME and FINALIZE_TRIAL, respectively, while a third observer confirms two genuine lock waiters on the MOVE holder's dependency graph, including permitted queued soft blockers. After MOVE commits, the Student's unique current effective PRIMARY ancestry points to Campus B; stale Campus A intent transitions deny with both token states unchanged, and new Campus A issuance is denied.

The two cases build on, but do not broaden, the accepted PR #94–96 real-PostgreSQL Principal, authorization revocation, native token, and END-first race rehearsals. All generated state and identities are disposable local CI fixtures.

## Hard boundary / next review

- **31/35 protected operations** accepted, with #67 Student Profile photo SET **DENY**; #68 Student Roll Correction, #69 Roll Policy Change, #70 Admissions handoff remain unaccepted. D1 Migration 10 remains `.sql.draft` and has not been deployed.
- No live verified identity-provider session or secure production service principal, actual file.upload/subscription/module/purpose authorizer, immutable sanitized bytes/sha256 object binding, File AVAILABLE transition, Student Profile photo APPLY, provider storage, recovery of partial external commits, multi-host deployment, or durable revocation publisher. The precommit callback is a local test harness seam and must never be exposed to clients.
- Current reverse winner test covers **FINALIZE_TRIAL before END**, not every photo-first CONSUME/ISSUE or all serializability permutations. The Campus move trial tests **MOVE before photo**, not photo-first versus MOVE or a new Campus B-issued photo scope. Exact rollback/idempotency semantics and cross-service key custody remain independent production design gates.
- The next sensible isolated security step is a **photo-consume-first versus real Campus Transfer** race plus crash/retry/outbox validation for the future file lifecycle, followed by scoped live entitlement trust design. None of these authorize production uploads.

**School example:** A valid local photo-finalization state may commit before a genuine Enrollment END, after which END closes the old placement. In a second test, a genuine Campus A→B transfer commits first, so old Campus A photo tokens cannot be consumed or finalized. No Student photo or external file is written.
