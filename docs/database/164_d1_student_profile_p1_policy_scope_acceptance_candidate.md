# D1 Student Profile P1 — policy replacement, active-policy ambiguity, and reviewer scope candidate

Date: 2026-10-16. **Status: UNVERIFIED ROLLBACK-ONLY ACCEPTANCE CANDIDATE. Student Profile full operation NOT frozen/activated.**

## Frozen preconditions

- Exact parent `main`: `8f983d447bbe3eb1477bfca73fba2266838de7ec`, following PR #73 and freeze #163.
- Previously verified 71 business suites / 3,057 assertions remain an unchanged ordered manifest prefix.
- Test-only synthetic authenticated P0 INITIAL placement/roll creates real current Student context. Synthetic requester and independent reviewer each have precise current roles, individual auth binding, enabled test permissions and ALL/DIRECT scope. Fixture reuses the existing accepted Student Profile candidate prior-school field but does not freeze its ultimate production allowlist.
- All new tests use transaction `BEGIN;` … `ROLLBACK;` with genuine public typed submit/review/apply RPCs and real stored approval/receipt effects.
- Adds **three suites, 67 proposed assertions**, for a combined **74 suites / 3,124 assertions** pending exact-head independent runtime verification.
- **No SQL migration, function, catalog, RLS, execution role, permission or production activation change**: only three SQL test files, the append-only test manifest, static guard and documentation.

## Proposed distinct scenarios

1. **#72 Policy replacement (22 assertions).** An independent reviewer approves a pending v3 request to APPROVED v4 under effective policy A. Policy A is genuinely RETIRED; a distinct independently configured valid APPROVAL policy B becomes sole ACTIVE policy. Because the request is pinned to A, a separate authenticated application must return terminal `INVALIDATED` v5, preserving original review evidence but creating no private Student mutation/application proof/outbox event. Replaying the same receipt stays invalidated. This goes beyond #69's retirement with *no successor*.
2. **#73 Simultaneously active conflicting policies (22 assertions).** After independent APPROVE, leave original policy A ACTIVE and activate second valid policy B. A fresh submission must deny rather than arbitrarily choose a route, and a previously approved request must `INVALIDATED` at apply. Both grants and the target Student remain otherwise unchanged. No optimistic selection of one of two policies.
3. **#74 Reviewer exact scope revoked (23 assertions).** Independently approve before revoking the reviewer's specific assignment permission scope (not the grant, which remains live). Current reviewer may no longer read the request. Requester remains authorized but cannot apply an approval whose reviewer's *effective scope* has been revoked; the state becomes `INVALIDATED` with zero protected Student effect.

The 4 baseline assertions per fixture are inherited from #67 and actually exercise protected P0 placement, APPROVAL route direct bypass, and denial without eligible reviewer.

## Merge gate / deliberate omissions

PR head must independently pass D1 static/final-function/ownership checks, clean Foundation 220/220, disposable local D1 business 74/74 with **3,124/3,124** assertions and existing observed races before a SHA-guarded merge and separately verified docs-only freeze. Failure requires correcting the same PR and retesting its new exact head. Never merge a draft based on static checks alone.

The eight owner-contract decisions `SP-01`–`SP-08` documented in `docs/database/152_d1_student_profile_update_p1_contract_readiness.md` remain unapproved. This batch does **not** establish full field allowlist/null/patch/photo file provenance/private value history, Campus/Section scope substitution, or real two-session Student Profile races. The accepted protected operation count remains **31/35**, with `student.profile.update`, `student.roll.correct`, `student.roll_policy.change`, `student.create` outstanding and disabled in real defaults. Migration 10 stays non-executable `.sql.draft` and hosted Supabase is untouched.

**Example:** A school staff member submits a request to change a student's previous-school field. The reviewer approves it, but the school's approval policy is replaced before the change is applied. The system must invalidate the old request rather than honor an obsolete approval.
