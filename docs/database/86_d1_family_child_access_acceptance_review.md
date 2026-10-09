# D1 Family/Student child-access boundary acceptance — independent review

Date: 2026-10-09  
Verdict: **PASS — incremental D1 acceptance; full D1 business acceptance remains OPEN.**

## Exact-source provenance

- PR: [#6](https://github.com/yunusyosaf399/edusync_saas_school_app/pull/6), branch `database/d1-family-child-access-boundaries`.
- Source base: `53660de18e0e8b373d7da1264ae3b9841ce7fc1e`.
- Trusted tested source: `997bb5037551f8275d13d1f457bd8058ef6cfb34`.
- PR merge commit: `32dfb27f727c9506e7bf4d61c68873d5cff9ae58` (verified source as second parent; no additional integration edits).
- [D1 local runtime #93](https://github.com/yunusyosaf399/edusync_saas_school_app/actions/runs/37891944915) **PASS** on tested source: 197 draft fragments applied only to disposable local stack; **34/34 forced-RLS D1 relations**; no authenticated/anon/service_role private-function EXECUTE exposures in catalog probe; both lint levels; 5/5 synthetic Auth fixtures; **220/220 Foundation regressions**, **254/254 D1 business assertions**, and **3/3 observed-lock employee-creation races**.
- [Foundation #304](https://github.com/yunusyosaf399/edusync_saas_school_app/actions/runs/37891944930) **PASS** on same SHA: nine frozen Foundation migrations/tests, **175 Python tooling tests**, **220/220** Foundation pgTAP assertions.
- [D1 draft static #71](https://github.com/yunusyosaf399/edusync_saas_school_app/actions/runs/37891944864) **PASS** on same SHA: 197 fragments, 34 relations, **97 permissions / 322 scope alternatives / 36 operation contracts**.
- A prior [Foundation #303](https://github.com/yunusyosaf399/edusync_saas_school_app/actions/runs/37891941365) on this same SHA **FAILED** during local `supabase start`, before substantive Foundation pgTAP execution. Foundation #304 subsequently completed successfully. This transient infrastructure failure is retained, not characterized as a failed business assertion.

## Exactly reviewed source changes

1. `supabase/migrations/20260928000000_domain_package_01.sql.draft` — append only the four `family.child_access.change` canonical intent-array shapes to the typed receipt lookup: DIRECT 9, request.submit 9, request.review 4, request.apply 2. The actor identity, idempotency hashing, guard, operation enablement and command-specific authorization remain unchanged.
2. `supabase/migrations/20260928000000_domain_package_01_effect32_01_child_access_core.sql.draft` — the Family child-access effect executes no-op parent-row updates (`students.updated_at=students.updated_at`, `families.updated_at=families.updated_at`) rather than writing server-owned timestamps. The existing `zz_d1_version` triggers alone update `updated_at` and increment `row_version`. No Foundation triggers, RLS policies or grants changed.
3. `supabase/tests/domain/08_family_child_access_boundaries.sql` — one new rollback-isolated pgTAP suite with **34/34** passing assertions. Synthetic Student records are fixture-only because Admissions/`student.create` remains disabled.
4. `tools/supabase/domain_business_ci.py` — register the eighth suite: **220 + 34 = 254** acceptance assertions.

## Business outcomes proven at disposable runtime

- `authenticated` cannot query raw `app_private.students`, `family_relationships`, or `family_student_access` tables.
- An administrator cannot grant child access with no usable shared FAMILY credential. A usable family-only, family-safe `OWN / D1_FAMILY_CHILD` authority chain still does not replace relationship evidence.
- Student A's approved relationship does not authorize a direct child-access ADD for unrelated Student B, even when B's UUID is supplied.
- Only with a current FAMILY credential **and** matching relationship does staff's authorized ADD for Student A succeed. Child and Family row versions advance via server-owned triggers; same-key replay preserves the original entitlement identity and versions, while a new overlapping ADD is rejected.
- Explicit REVOKE closes the retained entitlement interval even after suspension of its shared FAMILY Principal; relationship and membership history remain intact. Replaying original ADD and REVOKE retains the accepted receipts and does not create duplicate events.
- `anon` cannot execute the protected Family child-access command.

## Failure history preserved

- First [D1 #89](https://github.com/yunusyosaf399/edusync_saas_school_app/actions/runs/37890738381) failed with `D1 receipt operation phase or shape unsupported` before reaching Family preflight. Root cause: missing four-family-phase receipt shapes, repaired in `.sql.draft`.
- Corrected receipt [D1 #91](https://github.com/yunusyosaf399/edusync_saas_school_app/actions/runs/37891309093) passed first **13/34** new assertions but failed with `D1 mutable record has a server-owned field change` on the first valid ADD. Root cause: Family command directly changing parent `updated_at`. Repaired to let the existing version trigger own server fields.
- Final exact-source [D1 #93](https://github.com/yunusyosaf399/edusync_saas_school_app/actions/runs/37891944915) passed all 34 tests and all 254 business assertions. Nothing in the denial expectations, frozen Foundation or hosted database was relaxed to force a pass.

## Still-open gates

- **Family child-entitlement changes are not Family portal profile reads.** The portal Student details, sensitive-field disclosure, campus/section checked-read APIs and broader Family relationship/member management acceptance remain separate work.
- Full authorization/replay/correction/review/race coverage across the other D1 operations remains incomplete. Concurrency evidence is still three employee-creation races, not a comprehensive Family concurrency suite.
- `student.create` remains disabled pending approved Admissions and any Finance-required handoff.
- No populated upgrade/backfill/rollback proof, hosted Supabase deployment, worker activation or Flutter/client implementation is claimed. Migration 10 remains **197 non-executable `.sql.draft` fragments**.

**Result: `D1_FAMILY_CHILD_ACCESS_ACCEPTANCE_PASS — 34/34 FAMILY — 254/254 BUSINESS — 220/220 FOUNDATION — 3 RACES — D1_FULL_ACCEPTANCE_OPEN`.**
