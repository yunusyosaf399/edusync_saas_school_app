# D1 Student Profile P1 — four negative acceptance candidates in one PR

Date: 2026-10-16. **Status: PENDING EXACT-HEAD CI; no runtime/final-operation acceptance claimed.** This batch extends PR #72's already merged, frozen P1 Student Profile DIRECT and APPROVAL test slices, not the 31/35 operation completion register.

## Frozen parent and scope

- Parent `main` exact SHA `034a1efbcf0c467a9a3210c534abde6d7b3465ac` (includes the documentation-only merge freeze #161).
- Existing 67 SQL domain suites **2,980/2,980** previously passed on exact PR #72 head.
- PR contains **four** incremental disposable local SQL test scripts, one additive manifest update and one Python static-guard update, plus this document. **No** SQL function, operation enable flag, permission grant, RLS policy, executable migration, production catalog default or app code changes.
- Each SQL test runs `BEGIN;`, the real authenticated P0 Student Enrollment placement/roll command, real Profile P1 APPROVAL submit and independent reviewer flows in a **synthetic fixture**, and `ROLLBACK;`. Every test reuses only the known accepted previous-school field as a candidate to exercise stored approval plumbing. **No final PROFILE allowlist is inferred.**
- Planned **71 suites / 3,057 assertions**, subject to independently inspected exact-commit local runtime CI (not yet verified).

## Added suites and specific fail-closed evidence

| SQL suite | Assertions | Current evidence it aims to establish |
|---|---:|---|
| `68_student_profile_p1_reject_no_effect.sql` | 20 | Independent rejection is terminal v4; exact receipt replay remains rejected, opposing receipt intent denied, requester cannot APPLY, Student version/data and success events untouched |
| `69_student_profile_p1_retired_policy_invalidation.sql` | 21 | Independent approval v4 occurs before effective policy retirement; previously approved request becomes INVALIDATED v5 at APPLY; rejected typed receipt and replay stable; no application proof or Student mutation |
| `70_student_profile_p1_requester_scope_revocation.sql` | 19 | After independently approved request, the original requester's specific ALL/DIRECT grant-scope is revoked; original requester loses APPLY access; a still-valid independent reviewer cannot apply on behalf of the revoked requester and instead gets INVALIDATED; no effect |
| `71_student_profile_p1_target_version_drift.sql` | 17 | A synthetic schema-owner permitted Profile field change using the server-owned version trigger inside the same rollback-only test models a stale target **without asserting observed two-session contention**; approved v4 request becomes INVALIDATED v5; new Student state remains authoritative and no duplicate effect or event appears |

The scripts preserve the four baseline tests from suite #67's frozen synthetic setup in each fixture, and each test exercises its own independent authenticated requester/reviewer. All receipt idempotency keys are unique per suite. Every suite uses real command RPCs; there is no handcrafted approval record. Synthetic test-only setup and target drift are never deployed. The first 67 manifest entries and SQL tests are unchanged.

## Explicit exclusions / further work

This PR does **not** finalize `SP-01` through `SP-08` in `docs/database/152_d1_student_profile_update_p1_contract_readiness.md`. It does not test all PROFILE fields, photo entitlement, Campus/Section scope replacement, route DIRECT-to-APPROVAL replacement, multiple active conflicting policies, a true two-session Student Profile race, nor final private before/after retention decisions. Full Student Profile P1 operation stays unaccepted/disabled and 31/35 remains accurate even when these new suites pass. The other three outstanding operations (`student.roll.correct`, `student.roll_policy.change`, `student.create`) are untouched.

**CI merge gate:** the exact PR head must pass D1 static/final-owner/function shape, Foundation 220/220, D1 runtime 71/71 with 3,057/3,057 business assertions and all accepted races, and independent seven-file diff review; then SHA-guarded merge followed by a docs-only freeze. If any check fails, correct on the same PR and require entirely new exact-commit CI. Never infer completion from plan counts alone.

**Simple example:** A reviewer rejects a proposed prior-school correction because the record is insufficient. The Student's existing prior-school value remains unchanged. In another case the reviewer approved the request, but the school's policy was retired before it could be applied; the system must mark the request invalid instead of changing the Student.
