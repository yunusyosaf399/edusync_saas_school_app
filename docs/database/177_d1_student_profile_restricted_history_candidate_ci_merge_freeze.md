# D1 Student PROFILE restricted history physical candidate — CI/merge freeze

Date: 2026-10-17. **Verdict: local-only additive physical-candidate test ACCEPTED / FROZEN; NOT a deployed history schema, NOT a fully accepted Student Profile operation.**

## Exact reviewed GitHub evidence

- [PR #79](https://github.com/yunusyosaf399/edusync_saas_school_app/pull/79), merged, exact reviewed head `b94a3b47da8b8e8e7349814cedc704c78daefe1a`, original base `83a1316ad752770ec6f367aa1dd0477e38a0162e`, merge commit `f8d512e5a6a27eafaf35522c5f54b9c157f28ee5`.
- Independently verified the exact six-file diff has **zero trailing whitespace**, includes no executable or D1 base `supabase/migrations/` changes, and does not enable any operation or hosted Supabase deployment. It includes [physical candidate proposal #176](176_d1_student_profile_restricted_history_physical_candidate.md), quarantined `supabase/proposals/student_profile_history_v1.sql.draft`, the disposable smoke harness and source tests, and narrowly updates local runtime and static CI wiring.
- Exact tested **pull_request** workflows at the PR head: [D1 local runtime #39004119456](https://github.com/yunusyosaf399/edusync_saas_school_app/actions/runs/39004119456) **SUCCESS**, [Foundation #39004119370](https://github.com/yunusyosaf399/edusync_saas_school_app/actions/runs/39004119370) **SUCCESS**, [D1 draft static #39004119366](https://github.com/yunusyosaf399/edusync_saas_school_app/actions/runs/39004119366) **SUCCESS**.
- The same head also had three successful push workflows: D1 local #39004095591, Foundation #39004095600 and static #39004095593.
- Independently inspected the job logs, not just GitHub green UI: `D1_BUSINESS_PASS 3124 assertions`, Foundation `220/220`, `D1C2A_CATALOG_PASS tables=34 rls=34/34`, `D1_DRAFT_STATIC_PASS 228 fragments; 34 relations; 97 permissions; 322 scope alternatives; 36 operations`, and `D1_STUDENT_PROFILE_HISTORY_CANDIDATE_PASS rollback-only DDL/RLS/ACL/check/FK smoke`.
- The candidate DDL runs **only within a verified disposable local transaction** followed by `ROLLBACK`; a separate subsequent check proves the candidate table did not persist.

## Accepted limited engineering evidence

PostgreSQL successfully parsed the independently quarantined proposed `student_profile_revisions` schema and accepted the forced-RLS/owner-only policy, denied-client-privilege, uniqueness/FK, version-check and immutable-trigger smoke. D1's installed local baseline remains exactly 34 relations. Static source tests reject accidental unsafe grants, disabled FORCE RLS, an inserted COMMIT or version-check drift. This is **test evidence for a proposed physical design**, not authorization to introduce it into any deployed schema or to expose a history read API.

## Still blocked — separate future work

1. Independent **physical and privacy approval** for a separately versioned additive migration, protected storage lifecycle, real receipt/actor/operation chain validation and controlled retention/erasure. The physical design remains a **candidate**, not a final approved installation.
2. A purpose-scoped, narrow atomic history writer that captures genuine locked before/after Student profile values and never allows a successful DIRECT or approved APPLY commit without the corresponding immutable revision. The proposal currently deliberately grants no runtime writer access.
3. Replace the existing all-fields-NULL Student Profile transport with approved typed `UNCHANGED / SET / CLEAR` semantics, and require a private DIRECT reason. Validate true photo entitlement, requester/reviewer grants, exact current Student contexts, idempotency and real two-session races. Preserve Employee Profile behavior.
4. Only after exact-head runtime, negative security, field-by-field, historical replay and current-authority acceptance may Issue #67 be closed and accepted protected operations rise from **31/35** to **32/35**.

**Hard boundary:** Migration 10 remains `.sql.draft`, **34 original D1 tables**, 228 draft fragments, 97 permissions, 322 scope alternatives, and 36 registered operations; no live Supabase or staging deployment and no product/business acceptance change. The other pending Student operations (roll correction #68, roll policy #69, Admissions-dependent creation #70) remain open.

**Simple example:** A future approved Student Profile update from Previous School A to Previous School B must capture A and B in an access-restricted immutable revision and emit only a safe version-change event. PR #79 proves that the proposed revision table can be created **and rolled back safely in local PostgreSQL**, not that this end-to-end update already works.
