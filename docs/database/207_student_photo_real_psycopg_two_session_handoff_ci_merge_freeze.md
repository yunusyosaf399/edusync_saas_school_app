# PR #94 — genuine PostgreSQL Student Photo intent handoff / revocation race: CI merge freeze

Date: 2026-10-18. **Verdict: ACCEPTED as a disposable local integration test only. PR #94 merged after four successful exact-head checks. No permission to activate hosted migrations, upload services, actual file finalization, or Student Profile photo SET.**

## Immutable provenance and merge

- Prior frozen `main` from [PR #93 freeze](205_student_photo_postgres_verified_handoff_ci_merge_freeze.md): `37ec353485538f7ec442ceca70c5c70b5bec84de`.
- [PR #94](https://github.com/yunusyosaf399/edusync_saas_school_app/pull/94): [exact accepted test head](https://github.com/yunusyosaf399/edusync_saas_school_app/commit/eba047a6fa497be47d7f82d00d9b15d50f81b572) `eba047a6fa497be47d7f82d00d9b15d50f81b572`.
- GitHub reported merged `true`, PR closed and [merge commit](https://github.com/yunusyosaf399/edusync_saas_school_app/commit/cd332261941aef48b1de57724ec52b02a3b2efab) `cd332261941aef48b1de57724ec52b02a3b2efab`. `main` still matched previous frozen baseline immediately before SHA-guarded merge; independently checked `main` equals merged SHA afterward.
- Comparison of original frozen main to merged main: **eight intended files only**:
  1. `.github/workflows/domain-runtime-local.yml` (+2), pinned `psycopg[binary]==3.2.10` and `cryptography==46.0.4` for the local-only test job.
  2. `docs/database/206_student_photo_real_psycopg_two_session_handoff_trial.md` (new trial design, limitations and correction history).
  3. `supabase/proposals/student_photo_private_actor_scope_resolver_trial.sql.draft` (+12/−7), isolated private resolver uses the preexisting academic-executor-owned destination helper, no new SELECT/EXECUTE grants.
  4. `tools/supabase/domain_local_ci.py` (+4), calls real driver integration after existing D1 concurrency suites and before local stack teardown.
  5. `tools/supabase/domain_profile_history_candidate_ci.py` (+10), rejects widened Class/Section SELECT and requires the private academic helper and OPEN offering states.
  6. `tools/supabase/domain_student_photo_real_pg_handoff_ci.py` (new genuine psycopg driver and observed two-session race test).
  7. `tools/supabase/tests/test_domain_student_photo_real_pg_handoff_ci.py` (new static fixture guard, actor session, exact-school and runtime ordering constraints).
  8. `tools/supabase/tests/test_student_photo_real_actor_resolver_ci.py` (+10), fail-closed private helper/OPEN state source mutation regressions.

There were no edits to `supabase/migrations/**` executable or inactive D1 fragments, no Data API grant, no hosted SQL, no Student Profile image SET, no actual provider storage, no application endpoint.

## Four exact-PR-head CI runs — verified successful

1. [Student photo decoded-content candidate #39134485052](https://github.com/yunusyosaf399/edusync_saas_school_app/actions/runs/39134485052): **SUCCESS**, seven tested groups totaling **65/65 Python tests**, `D1_STUDENT_PHOTO_CONTENT_CANDIDATE_PASS`, explicitly "upload remains disabled".
2. [D1 Migration 10 draft static #39134484993](https://github.com/yunusyosaf399/edusync_saas_school_app/actions/runs/39134484993): **SUCCESS**, `D1_DRAFT_STATIC_PASS` and `D1_FUNCTION_FINAL_PASS`. Baseline remains 228 nonexecutable fragments, 34 relations, 97 permissions, 322 scope alternatives and 36 operations.
3. [Foundation database local stack #39134485070](https://github.com/yunusyosaf399/edusync_saas_school_app/actions/runs/39134485070): **SUCCESS**, `FOUNDATION_LOCAL_CI_PASS 9 files / 220 planned / 220 passed`; 269 Python source/runner tests passed.
4. [D1 Migration 10 local runtime #39134485027](https://github.com/yunusyosaf399/edusync_saas_school_app/actions/runs/39134485027): **SUCCESS**, 109 Python unit/source tests, `D1_BUSINESS_PASS 3124 assertions`, `D1_STUDENT_PHOTO_REAL_ACTOR_SCOPE_RESOLVER_PASS` and **`D1_STUDENT_PHOTO_REAL_PG_HANDOFF_PASS`** followed by **`D1C2A_PASS`**. This run demonstrates real psycopg PostgreSQL sessions and an observed (71001,1) EXCLUSIVE-vs-SHARED advisory-lock wait, not a mocked DB-API handoff.

Do **not** infer final-head CI success from earlier failed attempts. Those were diagnosed and patched before the accepted exact-head run.

## Independent local integration behavior

The runner operates **only** on the disposable `supabase_db_saas_OS_school_app` PostgreSQL 17 stack via `127.0.0.1:54322`, using the standard synthetic Foundation authenticated Principal fixture. Frozen business and concurrency tests execute first. The new trial uses an isolated test Person, Student, Campus/Year/Class/Section, role and assignment, and photo-scope grant with unique IDs, **reuses the existing singleton School and current school-wide Roll policy/allocator**, and invokes the accepted real `app.d1_place_student_enrollment` protected P0 operation for a genuine stored PRIMARY placement. JWT-shaped claims in this stage are established by the privileged local harness and **are not an identity-provider validated production session**. New test-only schema rows and the private function are committed **only within the disposable local stack**, which the current runtime harness stops.

The new `LocalPostgresPhotoHandoffTrial` creates fresh authenticated psycopg connections with `autocommit=False`, derives its current Principal via private PostgreSQL function, and rechecks live current Student PRIMARY placement/Campus/profile+photo grant inside a held PostgreSQL transaction when issuing and consuming local signed opaque SQLite intents. Existing Ed25519 control/service signatures and one-time SQLite consumption remain isolated rehearsal machinery. The trial succeeds on authorized ISSUE/CONSUME once; rejects replay, wrong Campus, and permission-revoked subsequent ISSUE. A separate PostgreSQL session holds the Foundation exclusive grant lock and revokes the exact Campus `student.photo.submit` scope; the in-flight consumer **observably waits** on the shared lock, then is denied after revocation commits, with its opaque token still unconsumed. This is genuine same-instance PostgreSQL contention plus *separate* SQLite consumption behavior.

The prior rollback-only private resolver directly read `class_offerings` and `section_offerings` while created as `schoolos_student_executor`: the fresh driver session confirmed this violated the intended privilege boundary. The accepted correction calls already-granted, academic-owner `app_private.d1_enrollment_place_destination` for the Class/Section ancestry, Campus/School and exact OPEN offering states; no broadening of academic table privileges, public RPCs or hosted grants is permitted.

The test fixture also surfaced and preserved four important existing constraints: no reused primary-key IDs from committed concurrency test records; no second `school_profiles` row (singleton); no overlapping role/permission grants (use a dedicated role/assignment); and no guarded Student mutation before the synthetic current Principal context has been established. Earlier failing heads are intentionally **not** acceptance evidence.

## Freeze boundary, remaining risks and next gate

- **Production disabled**: current protected-operation acceptance remains **31/35**; #67 Student Profile P1 photo SET **DENY**; #68 Student Roll Correction, #69 Roll Policy Change and #70 Admissions handoff have no accepted protected acceptance. `D1 Migration 10` is still `.sql.draft`.
- No actual upload endpoint, persisted sanitized media bytes, provider-neutral file hash/object binding, File `AVAILABLE` transition, retention contract, student photo application, live `file.upload` grant, real subscription/module or photo-purpose registry verification. The Python `trial_file_upload_enabled`, `trial_module_enabled`, and `trial_purpose_approved` booleans are **synthetic flags**, not production evidence.
- PostgreSQL and SQLite maintain **independent transactions**; no distributed atomic commit, shared durable authorization revision, multi-host revocation signal, Student placement movement race serialization, recovery after one database commits and the other fails, or real issuance-time identity-provider trust chain has been proven.
- Next isolated architecture gate: define and test **single durable server-side issue/consume/finalize authority**, independently race Student placement changes against file-intent consumption, and verify real approved `file.upload`/module/purpose with signed origin trust. Do not activate uploads without separate security and domain approval.

**School example:** A staff member with the current Campus A permission issues a disposable test token for Student A. Another genuine PostgreSQL session revokes the exact Campus A photo grant while the token consumer waits on the Foundation lock. After that revocation commits, consumption is rejected and there is **no consumed token receipt**. This test does not upload a student's actual photo.
