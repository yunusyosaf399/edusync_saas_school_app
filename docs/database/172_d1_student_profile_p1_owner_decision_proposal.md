# D1 Student PROFILE Update P1 — product-owner decision proposal (SP-01…SP-08)

Date: 2026-10-17. **Status: PROPOSED / NOT APPROVED / NON-AUTHORIZING.** This document requests decisions; it does **not** freeze a business contract, enable a protected operation, change SQL, modify a role/grant, or add any accepted-operation count.

## Verified handoff and scope

- Last independently frozen `main` before this proposal: `21abb1fdf8e2e4d66b7f8ca3f43710660c415238`, documentation-only PR #77 freeze (review #171).
- PR #77 tested head `4a5563af593f6e6e57affdd83cc7b90048412079`; SHA-guarded merge `2f25cc088fcc018872c12649aef9dd1e51178155`.
- Last successfully observed push workflows: D1 local runtime [#38996712123](https://github.com/yunusyosaf399/edusync_saas_school_app/actions/runs/38996712123), Foundation [#38996711835](https://github.com/yunusyosaf399/edusync_saas_school_app/actions/runs/38996711835), and D1 draft static [#38996711815](https://github.com/yunusyosaf399/edusync_saas_school_app/actions/runs/38996711815), all **SUCCESS**, on merge SHA `2f25cc0…`.
- Latest accepted local D1 suite snapshot is **74 rollback-only business suites / 3,124 pgTAP assertions** and Foundation **220/220**. Existing acceptance breadth is still **31/35 protected change operations**, with four intentionally gated. The profile race scripts do **not** independently approve the missing contract.
- Source-of-truth readiness review: [#152](152_d1_student_profile_update_p1_contract_readiness.md), decision register [#156](156_d1_four_student_operation_decision_register.json), and exact latest checkpoint [#171](171_d1_student_profile_submit_vs_apply_ci_merge_freeze.md). Tracking [Issue #67](https://github.com/yunusyosaf399/edusync_saas_school_app/issues/67).

## Product choices for explicit approval

These are **candidate recommendations, not previously accepted rules**. No implementation may rely on a candidate below until it has been independently accepted and reflected in a versioned frozen decision.

| ID | Candidate owner decision | Simple example / security implication |
|---|---|---|
| **SP-01** | Allow only explicitly typed updates to `date_of_birth`, `gender_code`, `nationality_code`, `general_contact`, `previous_school` and `profile_photo_file_id`. Forbid any writable Student ID, Person/admission reference, status, Identity/Special field, generic JSON patch or unrestricted row update. Each field requires its own validation and null contract, not merely table-column existence. | Staff may correct previous school but cannot edit a B-Form number via PROFILE. |
| **SP-02** | Distinguish **UNCHANGED**, **SET(value)** and **CLEAR(NULL)** in a typed intent. Allow clearing only for a physically nullable, owner-approved field; reject an empty patch and an all-no-op patch. Trim/normalize text before equality and intent hashing. | A blank optional previous school can be cleared; omitted DOB must remain unchanged. |
| **SP-03** | A photo change may link only an already committed, currently entitled `STUDENT_PROFILE_PHOTO` object belonging to this Student and school. Prohibit arbitrary file IDs, raw object keys, caller storage URLs or unrelated purpose. Removing a link must not delete the underlying retained file record as an undocumented side effect. | A student's approved portrait may be linked, but a birth certificate cannot be substituted as the portrait. |
| **SP-04** | Bind typed Student UUID, exact expected `row_version`, all field action/value pairs, photo intent, private reason and caller idempotency key to canonical command intent. Re-read under Student lock after the shared Foundation authorization lock. Changed intent with the same key conflicts; stale version denies. | Two staff start from version 5; a version-5 change cannot overwrite the accepted version-6 result. |
| **SP-05** | Resolve P1 **DIRECT** or **APPROVAL** only through a single current unambiguous deployment policy and an authorized Student context. Never let requester select whichever Campus is easiest. If no current placement or conflicting contexts prevents supported scope resolution, **deny pending an explicitly frozen fallback** (candidate: ALL-only). | A Campus A administrator cannot select an unrelated Campus B policy to bypass review. |
| **SP-06** | In APPROVAL mode, require live separate `student.profile.approve` grant/scope, configured reviewer role/step, distinct requester/reviewer Person, and explicit later APPLY. Recheck source version, policy, requester/reviewer grants and approved patch at apply; deterministic stale requests INVALIDATE without profile change. Transient SQL failure rolls back for retry. | The reviewer losing their grant before APPLY invalidates the reviewed change rather than approving by old authority. |
| **SP-07** | Freeze a bounded typed result of Student ID and post-effect version (plus immutable receipt/request/application identifiers as necessary). Emit only approved `student.profile_changed` and safe IDs/version/action/correlation in broad audit/outbox; never DOB, contact, portrait URL/object key, private reason or restricted/special values. Terminal replay must preserve original result and not duplicate outbox. | Audit says Student S1 was updated to version 7; it does not copy the private contact value. |
| **SP-08** | **Requires an explicit retention architecture choice.** The repository does not yet establish a clearly approved restricted before/after PROFILE-value store usable for both DIRECT and APPROVAL. Choose either **A:** accept non-value audit/version metadata only for this baseline, with no claim of value-level historical reconstruction; or **B:** separately design/approve a restricted retained-value history facility, preserving current 34-relation/D1 draft freeze until an additive migration gate is separately approved. Do **not** tuck sensitive before/after values into broad receipts, outbox or audit JSON. | Staff corrects a date of birth: A can prove *who/when/version* but not reconstruct the prior DOB; B preserves the past value in a tightly restricted history facility. |

## Proposed engineering order after owner approval

1. Freeze all eight decisions **including SP-08 and nullable-column specifics** in a versioned contract; independently review that the actual final SQL implementation matches the accepted choices.
2. Validate typed Student-only PROFILE updates in genuine authenticated DIRECT and APPROVAL paths, exact current Student scope, file-purpose entitlement and no Identity/Special mutation.
3. Require two-session real-lock races and revocation/route-drift tests as in PRs #72–#77. Avoid treating a successful test-only rehearsal as a production activation gate.
4. Pass exact-head Foundation, D1 local runtime and D1 draft static CI, record independent security/authorization and retention review, then separately authorize an accepted-operation increment and freeze. Do not activate hosted Migration 10.

## Remaining separate workstreams

- [Issue #68](https://github.com/yunusyosaf399/edusync_saas_school_app/issues/68): `student.roll.correct` — RC-01…RC-08 unresolved.
- [Issue #69](https://github.com/yunusyosaf399/edusync_saas_school_app/issues/69): `student.roll_policy.change` — RP-01…RP-07 unresolved, including an unselected event type.
- [Issue #70](https://github.com/yunusyosaf399/edusync_saas_school_app/issues/70): `student.create` — SC-01…SC-07, must wait for separately accepted and installed Admissions final unused handoff.

**Non-authorization invariant:** Existing D1 manifests remain **97 permissions / 322 scope alternatives / 36 operation contracts**. Migration 10 and D1 fragments stay `.sql.draft`, staging and hosted Supabase remain unchanged, and full D1 acceptance remains **OPEN**.

**Requested owner sign-off:** Approve/amend SP-01…SP-07 and explicitly choose SP-08 A or B. Do not treat approval of this *proposal PR* as approval of domain semantics without a distinct recorded owner decision.
