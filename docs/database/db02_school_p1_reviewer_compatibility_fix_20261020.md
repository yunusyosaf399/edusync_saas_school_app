# DB-02 — School-wide P1 reviewer compatibility fix (non-activating)

**Status:** additive SQL compatibility patch committed to draft PR #101, **not** a working `student.roll_policy.change` endpoint, approval application, or owner-authorized activation. Date: **2026-10-20**.

## Cause identified in final assembled SQL

The effective latest generic `app_private.d1_review_candidates(uuid,uuid)` originated in `effect35_21_student_profile_approval_candidate_open_offerings.sql.draft`. It recognizes `student.roll_policy.change` in the *route classifier*, but its *target resolver* covers Student Profile/Status and Employee Profile only; the ELSE branch returns zero candidates for a School UUID target. `app_private.d1_current_reviewer_eligible` calls this same resolver and then requires a retained, unwithdrawn reviewer assignment, so even a correctly configured roll-policy reviewer could not review a School-target request.

This is an **existing implementation coverage gap**, not evidence of a live permission bypass: the operation and permission remain disabled. The original source has unchanged gates for P1 mode, current role/permission grants, Principal binding, Person separation and current workflow reviewer assignment.

## Precise narrow resolution

New additive **DB-02-only** final override:

`supabase/migrations/20260928000000_domain_package_01_effect42_01_db02_school_reviewer_candidates.sql.draft`

It **replaces only the body of the same existing restricted function**, preserving its name, signature, owner `schoolos_authz_reader`, SECURITY DEFINER, original Student/Employee branches and existing `schoolos_workflow_executor` EXECUTE. The source text is inherited from the final `effect35_21` body on `main df1c98d5c2d19424946986fc6ba7615202b0a443`. Original shared fragment and frozen Foundation migrations are untouched.

The exact new branch requires all conditions:

1. Existing Foundation request has `operation_code = student.roll_policy.change`, enabled operation, enabled non-family-safe `student.roll_policy.approve`, `PENDING` request and `OPEN` matching one-review `D1_REVIEWER_ROLE_SCOPE` step.
2. `req.target_ref` is an **existing School** row; `req.campus_id IS NULL` and `policy.campus_id IS NULL`. A Campus-specific policy never makes a School reviewer eligible.
3. Exactly **one** currently ACTIVE/effective **global** `approval_policy_versions` for the enabled, not-mandatory-approval operation; its UUID must equal the request's immutable `policy_id` and route must be `APPROVAL`. This prevents a previously approved V1 request from inheriting a new V2 route even when both use APPROVAL, or picking from overlapping live global policies.
4. Whole Foundation APPROVAL step set is valid: one or more contiguous steps starting at 1, active reviewer roles, required_reviews=1 and resolver `D1_REVIEWER_ROLE_SCOPE`.
5. Every candidate is currently ACTIVE/INDIVIDUAL and bound to an auth user, has a **different Person** from requester, holds an ACTIVE configured reviewer role/assignment and a *current* unrevoked `student.roll_policy.approve` grant through enabled **ALL/DIRECT only** scope. No CAMPUS, CLASS, SECTION, ASSIGNED, OWN, FAMILY or role-name fallback.
6. The original `d1_current_reviewer_eligible` already checks this resolver and requires an exact current nonwithdrawn `approval_step_reviewers` row. Because the function is overwritten in place, the same live check gains the School branch **without weakening or replacing its stored-assignment requirement**.

**Threats guarded:** foreign Campus approval, self-review via a second Principal sharing the same Person, stale/retired/overlapping global policy UUID, revoked reviewer grant/scope, invalid or missing configured role/steps, unauthenticated direct enumeration, and unauthorized D1 operation activation.

**No change to capability catalog or client surface:** zero new functions/tables/roles/permitted scope alternatives, zero new public RPC, zero new `authenticated`/`anon`/`service_role` EXECUTE, no new SELECT/UPDATE RLS policy or Foundation grant, no event registration, no enabled operation and no roll-number/history changes. The temporary schema CREATE grant for `schoolos_authz_reader` is returned to its pre-fragment state.

## Test and CI details

DB-02 adds `supabase/tests/domain/82_db02_school_reviewer_candidates.sql`, a **10-assertion rollback-only synthetic owner-fixture** test. It covers positive School+ALL reviewer selection, different Person identity, assigned live reviewer eligibility, revoked ALL grant, already-assigned review revocation, overlapping active global versions, direct `authenticated` private EXECUTE denial, and absence of Policy, Roll and event side effects.

**Important accuracy boundary:** this file is intentionally **not registered** in the shared `tools/supabase/domain_business_ci.py` suite manifest because PR #117 already changes that manifest to register its separate DB-01 suite #81. DB-02 did not edit shared CI, DB-01 files or another workstream's test. Merely committing a pgTAP file does **not** demonstrate a run or pass of these 10 assertions. It requires a separately coordinated, narrowly reviewed manifest integration and genuine rollback-only PostgreSQL run to become accepted positive evidence.

The existing D1 draft static, Foundation local and D1 local runtime workflows are expected to validate the **SQL fragment's compilation, current privilege/catalog inventory and old accepted operations** when finished. They do not validate the currently unregistered new suite. Recheck exact-head results rather than claiming success on an in-progress workflow.

## Conflict disposition and remaining gate

**Code-level compatibility blocker addressed:** the generic D1 P1 selector now has an explicit, narrow School-target branch that existing `d1_current_reviewer_eligible` can use. No Foundation migrations or other domain functions were edited. This is non-activating: it **does not make protected policy change/submission/review/apply functional**, nor grant approval merely because a reviewer is a candidate. Future DB-02 typed submit must create the correctly shaped global School-target request/step/assignments, and protected review must verify the current candidate and assigned-row identity. Separate APPLY must recheck policy revision/source snapshots and Foundation policy UUID.

**Remaining before treating this fix as accepted:** actual database runtime PASS for latest SHA, separately registered and genuinely executed DB-02 #82 10/10, privilege/ACL audit and independent review. Shared runner registration must be coordinated with the DB-01 #117 integrator. Do not merge or activate until those gates are satisfied.

**Next DB-02 task, only after compatibility acceptance:** implement a narrow fixed School P1 policy-ID selector and non-mutating source/prelock preflight against latest integrated School-local date, then build DIRECT and APPROVAL commands in separately reviewed increments.