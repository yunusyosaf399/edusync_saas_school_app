# Student Profile SP-01…SP-08 owner-decision merge freeze

Date: 2026-10-17. **Verdict: product-decision documentation FROZEN, protected operation NOT ACCEPTED.** This is not a runtime execution, SQL migration, RLS or deployment freeze.

## Immutable provenance

- [PR #78](https://github.com/yunusyosaf399/edusync_saas_school_app/pull/78): independently verified `state=closed`, `merged=true` and exact merged HEAD.
- Previous `main`: `21abb1fdf8e2e4d66b7f8ca3f43710660c415238`.
- Last PR HEAD: `f2c297201e75b645faa1d93134da045195a6083d`.
- GitHub merge: `b6ce4ffa7eb68c0b0023daa0dd0346d001e492d1`.
- Merge changes **only four documentation files**: [#172 proposal](172_d1_student_profile_p1_owner_decision_proposal.md), [#173 owner-approved contract](173_d1_student_profile_p1_owner_approved_contract.md), [#174 independent SQL gap assessment](174_d1_student_profile_p1_implementation_gap_review.md), and [ADR-005](../decisions/ADR-005-student-profile-restricted-history.md).
- The PR diff was independently checked and had no trailing whitespace, no SQL, scripts or tests, no Foundation migration/test changes and no hosted environment changes. GitHub Actions were **not triggered for the documentation-only PR HEAD**; no CI PASS is claimed for PR #78.
- The preceding *test-only* PR #77 is the last exact-source runtime checkpoint: **74/74 D1 business suites, 3,124/3,124 assertions**, Foundation **220/220**, all three workflows successful on its source/merge SHAs.

## Decision closed

The user accepted the recommended SP-01…SP-07 Student-only typed PROFILE write contract and SP-08 **option B**: restricted immutable old/new value history. Exact allowed columns, tri-state UNCHANGED/SET/CLEAR behavior, purpose-checked photo, private reason, idempotent version binding, current P1 policy and reviewer authority, minimized broad evidence and additive separate history package are recorded in [#173](173_d1_student_profile_p1_owner_approved_contract.md). The existing six-field NULL-overwrite public RPC, missing DIRECT private reason and missing dedicated restricted value history are explicitly flagged for future engineering correction in [#174](174_d1_student_profile_p1_implementation_gap_review.md).

## Not closed; release safeguards

`student.profile.update` remains **disabled/not end-to-end accepted**, Issue #67 stays open, and accepted protected-operation count remains **31/35**. The three other open operations remain Student Roll Correction, Roll Policy Change and Admissions-dependent Student Creation. The additive value-history design/DDL, current typed P1 DIRECT/APPROVAL correction, field-level privacy/ACL and successful authenticated/race acceptance must be reviewed on future branches before acceptance advances. Migration 10 remains draft-only; the **34 base D1 relations, 97 permissions, 322 alternatives, 36 operation contracts** are unchanged. There is no authorization here for hosted Supabase deployment or activation.

**Next unblocked planning gate:** independently review an additive, separately versioned immutable Student Profile history physical design without modifying frozen Migration 10 and then implement the approved typed P1 path with exact-head runtime verification.

**Example:** when an authorized staff member corrects a student's previous school, the final implementation must change only that field, atomically preserve its before/after fact in restricted history, and emit an event without exposing either school name or any private Student data.
