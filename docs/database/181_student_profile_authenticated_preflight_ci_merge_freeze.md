# Student Profile typed authenticated preflight — exact-head CI merge freeze

Date: 2026-10-17. **VERDICT: isolated, test-only authenticated P1 preflight ACCEPTED / MERGED / FROZEN. Full `student.profile.update` protected operation remains disabled and NOT accepted.**

## Immutable provenance

- [PR #81](https://github.com/yunusyosaf399/edusync_saas_school_app/pull/81) merged exactly reviewed HEAD `84bbac6ad946972d6b92a0f8f2f6c26f9ee4906c` into prior main `8cd958ad974ad81f8221b433871632653bfd807e`; GitHub merge SHA `170af5aa358504de21312be4c9d68d29b999d9f5`.
- Exactly four paths were changed: [preflight boundary document #180](180_student_profile_authenticated_typed_preflight_gate.md), `supabase/proposals/student_profile_typed_auth_preflight_trial.sql.draft`, and the rollback-only test runner + source unit tests. Independently checked the PR diff for **zero trailing whitespace** and no executable `supabase/migrations/` changes.
- The initial PR source-test attempt failed due to a nonunique reused test anchor and a misspelled expected test marker. A subsequent branch change corrected a misleading active-state filter: current PRIMARY enrollment ancestry is resolved from the actual Section/Class relationship while the existing live-authority predicate owns applicable resource-state requirements. All pre-approval failed runs remain historical evidence, **not** pass claims.
- The last exact PR head passed all three required **pull_request** workflows:
  - [D1 local runtime #39012038508](https://github.com/yunusyosaf399/edusync_saas_school_app/actions/runs/39012038508): **SUCCESS**. Inspected log messages `D1_STUDENT_PROFILE_TYPED_AUTH_PREFLIGHT_PASS authenticated DIRECT scope/P1/preflight+revocation, rollback-only`, `D1_STUDENT_PROFILE_HISTORY_CANDIDATE_PASS`, `D1_STUDENT_PROFILE_TYPED_ATOMIC_TRIAL_PASS`, `D1_BUSINESS_PASS 3124 assertions`, `D1C2A_FOUNDATION_REGRESSION_PASS 220/220`, `D1C2A_CATALOG_PASS tables=34 rls=34/34` and `D1C2A_PASS`.
  - [Foundation local #39012038460](https://github.com/yunusyosaf399/edusync_saas_school_app/actions/runs/39012038460): **SUCCESS**. Log `FOUNDATION_LOCAL_CI_PASS 9 files / 220 planned / 220 passed`.
  - [D1 draft/static #39012038471](https://github.com/yunusyosaf399/edusync_saas_school_app/actions/runs/39012038471): **SUCCESS**. Log `D1_DRAFT_STATIC_PASS 228 fragments; 34 relations; 97 permissions; 322 scope alternatives; 36 operations` and final function-state guard clean.
- Rollback-only verifier loads a separate copy of unchanged authenticated DIRECT business suite #66 and inserts positive/negative `DO` checks immediately before its successful first legacy DIRECT mutation. The test injects the trial SQL within `BEGIN/ROLLBACK` and independently verifies no trial function/history table persists. The original #66 suite continues to be executed unchanged in the frozen 74-suite baseline.

## Precisely accepted evidence

A sandboxed SECURITY DEFINER helper owned by `schoolos_student_executor` rechecks JWT-backed current individual Principal, shared Foundation authorization lock, Student current PRIMARY Section/Class/Campus resolution, live `student.profile.update` authority, exact Student expected `row_version`, effective P1 route, validated six-field `UNCHANGED/SET/CLEAR` intent, nonblank private reason and default-denied photo SET. Tested legitimate authenticated DIRECT preflight and negative wrong Campus, stale version, route mismatch, absent Student, no-op, unverified photo and current scope-revocation denial. This is an authorization **preflight only**; no Student mutation or public production interface was added.

## Explicit future blockers

1. The independent additive secure-history physical approval, versioned migration/rollback and access/retention privacy policy remain unresolved. No actual hosted school or new permanent D1 relation was touched.
2. The real Student DIRECT command must use a verified canonical idempotency hash bound to the six normalized typed actions, private reason and exact Student version. It must atomically emit a successful typed receipt, modify only selected fields and retain restricted before/after values, then minimized audit/outbox. Current all-six-positional Student RPC cannot do this; existing Employee RPC must remain untouched.
3. A distinct approved SUBMIT/REVIEW/APPLY path must retain typed action snapshots, verify different-Person reviewers and current reviewer roles/scope, correctly invalidate stale approval, and handle true concurrent Student locking and historical idempotent replay.
4. Photo SET requires positive same-Student file ownership, currently AVAILABLE purpose, current verified entitlement and committed file intent; no safe shortcut was introduced. The zero-placement ALL/schoolwide authorization case was conservatively denied by this trial and still needs a separately reviewed implementation.
5. Full authenticated per-field, privacy/RLS and both-order race acceptance, independent SQL/security audit and exact-head Foundation/D1/static checks must precede advancing the protected-operation ledger.

**Hard stop:** unchanged baseline D1 34 relations, 228 fragments, 97 permissions, 322 scope alternatives and 36 contracts; Migration 10 remains `.sql.draft`. No live deployment, existing authenticated D1 public profile writer remains unmodified, Issue #67 open, **31/35 accepted protected operations**.

**Simple example:** an authorized staff member with current Student Profile change scope can validate a Previous School correction without clearing the contact. A different-Campus actor, expired scope, stale Student version or photo with no verified file entitlement is refused before any write. No live Student data changes in PR #81.
