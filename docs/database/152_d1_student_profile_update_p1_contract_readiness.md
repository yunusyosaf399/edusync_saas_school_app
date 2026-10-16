# Student Profile Update — P1 implementation contract readiness

Status: **BLOCKED / design-to-implementation handoff, NOT frozen write API or runnable acceptance** (2026-10-16). Operation: `student.profile.update`. This document adds no deployed or inactive executable effect and does not approve enabling its permission or operation.

## Frozen facts (supported)

- [Command matrix](../security/09_domain_checked_reads_and_commands.md): P1 PROFILE-only allowlist; use `student.profile.update` permission and `student.profile.approve` for configured approval; enforce exact Student expected `row_version`; restricted Identity/Special data **cannot** be changed via this route.
- [Base draft Student table](../../supabase/migrations/20260928000000_domain_package_01.sql.draft) has existing PROFILE-candidate fields `date_of_birth`, `gender_code`, `nationality_code`, `general_contact`, `previous_school` and `profile_photo_file_id`. The table also has immutable admission/person identifiers and separate `student_identity_details` and `student_special_details` retained histories. **A field being on the Student table does not automatically authorize it for updates.**
- [Retention ledger](34_domain_package_01_query_retention_offline_review.md) expects a versioned PROFILE update, current Student-scope authorization, and the approved broad event `student.profile_changed`. Shared command-receipt code names an operation/phase shape but does **not** implement input validation, a public RPC, a profile effect, or P1 approval wiring.
- [Blocked-operation review #151](151_d1_remaining_four_student_commands_blocked_readiness_review.md) and tested fail-closed suite #65 establish this command is currently unavailable. Existing Identity/Special P2 corrections have **separate** authority and do not substitute for it.

## Required decisions to freeze before SQL

| ID | Unresolved choice | Proposed default for owner review (not approved) |
|---|---|---|
| SP-01 | Exact individually writable subset among the six candidate PROFILE columns | Prefer named typed fields only; freeze per-column update/unchanged/null semantics. Exclude `person_id`, `admission_number`, `admission_serial`, `school_student_id`, status, and Identity/Special history |
| SP-02 | Optional value clearing and no-op command behavior | Distinguish absent/unchanged from explicit NULL; deny a no-op or define its audited meaning |
| SP-03 | Photo reference link rights and lifecycle | Require a committed entitled `STUDENT_PROFILE_PHOTO` `file_objects` reference; never accept caller-owned storage URLs, arbitrary file IDs or private document purposes |
| SP-04 | Source input and concurrency token | Typed Student ID, exact expected `row_version`, normalized changed fields, reason and idempotency key; reject mismatches and changed-intent replay |
| SP-05 | P1 route selection | Require effective nonambiguous DIRECT or configured APPROVAL policy; freeze campus resolution when placement is absent/ambiguous |
| SP-06 | Review participants and stale apply | Independently authorized current `student.profile.approve` reviewer; no self-approval; validate target version, route and grants at apply |
| SP-07 | Receipt/result and audit | Freeze typed receipt/result summary and minimal event fields; never expose DOB/contact/photo URL/restricted identity in broad outbox |
| SP-08 | Before/after data retention | Decide whether secure value history is in restricted audit or a new history relation, while avoiding an invented physical table or direct broad audit content |

## Proposed protected lifecycle (not authorization)

1. Validate current authenticated **INDIVIDUAL** actor, explicit `student.profile.update` scope for the target Student and enabled operation; never interpret FAMILY portal scope as change authority.
2. Require an effective route and approved reviewer conditions before editing. Use the current Foundation shared authorization and idempotency locks, then target Student row lock and version check.
3. Validate only the **frozen allowed PROFILE fields**, permitted file reference and explicit null semantics. Keep Identity/Special Person/Admissions/Student status paths unreachable.
4. DIRECT: apply one atomic versioned update, retain required private change evidence and one `student.profile_changed` typed event. APPROVAL: submit immutable typed snapshot, independent authorized review, recheck at apply.
5. Same-key exact replay returns the original receipt/result without duplicate updates/events; changed-intent key and stale approvals deny or invalidate.

## Minimum acceptance work to replace blocked suite #65

- Authenticated DIRECT positive with genuinely changed allowed field, expected Student version, exact scope, accepted photo if in allowlist; one version increment/evidence/event; unchanged restricted and Special rows.
- Negative: wrong Student/Campus/Section, disabled/ambiguous route, missing grant, FAMILY actor, stale row version, immutable Admissions/Person/Student status attempt, restricted/special fields, unentitled/wrong-purpose file and changed idempotency intent.
- APPROVAL: independent reviewer, self-review denied, route/policy replacement, actor/grant/scope revocation and target drift before apply, terminal replay and stale invalidation.
- Observed real two-session contention on the same Student plus opposing permission revocation; verify at most one accepted effect and no duplicate receipt/outbox.
- Final catalog, RLS, no direct private DML, Foundation, local runtime, static and rollback-only acceptance must all pass **before** activating this operation. Migration 10 remains `.sql.draft` and D1 OPEN.

**Decision gate:** SP-01 through SP-08 must receive explicit review/freeze; until then do not create a guessed public RPC or mark operation accepted.