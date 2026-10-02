# D1C1B Effect 17/36 — Subject Teacher Assignment SQL Review

Status: **FROZEN after corrective independent review and CI; see freeze note below.**

Baseline: `6b60fb5d93ab13359682837cfb948a16234e0ede` (effect 16 corrected re-freeze).
Operation: `teaching.subject_assignment.change`.
Static SQL continuations, in exact concatenation/review order:
1. `supabase/migrations/20260928000000_domain_package_01_effect17_01_subject_assignment.sql.draft`
2. `supabase/migrations/20260928000000_domain_package_01_effect17_02_subject_assignment.sql.draft`
3. `supabase/migrations/20260928000000_domain_package_01_effect17_03_subject_assignment.sql.draft`
4. `supabase/migrations/20260928000000_domain_package_01_effect17_04_subject_assignment.sql.draft`
5. `supabase/migrations/20260928000000_domain_package_01_effect17_05_subject_assignment.sql.draft`
6. `supabase/migrations/20260928000000_domain_package_01_effect17_06_subject_assignment.sql.draft`
7. `supabase/migrations/20260928000000_domain_package_01_effect17_07_subject_assignment.sql.draft`
8. `supabase/migrations/20260928000000_domain_package_01_effect17_08_subject_assignment.sql.draft`
9. `supabase/migrations/20260928000000_domain_package_01_effect17_09_subject_assignment.sql.draft`
10. `supabase/migrations/20260928000000_domain_package_01_effect17_10_subject_assignment.sql.draft`
11. `supabase/migrations/20260928000000_domain_package_01_effect17_11_subject_assignment.sql.draft`
12. `supabase/migrations/20260928000000_domain_package_01_effect17_12_subject_assignment.sql.draft`
13. `supabase/migrations/20260928000000_domain_package_01_effect17_13_subject_assignment.sql.draft`
14. `supabase/migrations/20260928000000_domain_package_01_effect17_14_subject_assignment.sql.draft`
15. `supabase/migrations/20260928000000_domain_package_01_effect17_15_subject_assignment_apply_correction.sql.draft`.

## Packaging

The repository's Migration 10 remains the non-executable
`20260928000000_domain_package_01.sql.draft`. Because the connected GitHub write
surface cannot safely patch the very large frozen draft in place, effect 17 is
stored as **15 ordered non-executable continuation drafts**. It is not an independently
authorized migration. Static review treats the original Migration-10 draft followed by these 15 ordered continuations as one unit. Before any future D1C2/runtime
authorization, the continuation must be folded/reconciled into the executable
migration package and validated as a whole.

No D1 SQL is executed by this commit.

## Product contract implemented

1. ADD is P0 only when `effective_from >= CURRENT_DATE`.
   `PRIMARY` and `CO_TEACHER` may be open or bounded. `SUBSTITUTE` must be bounded.
2. END is P0 only at a current/future boundary. It one-way closes one open source
   without rewriting the source reason and creates no successor.
3. CORRECT is P0 at a current/future boundary and P2 when the correction boundary
   is before the current business date.
4. CORRECT retains exact Section+Subject and may change Employee and/or
   `assignment_kind`. Section or Subject movement is not a CORRECT.
5. Only an open, unsuperseded lineage head may END/CORRECT.
6. CORRECT rejects an exact no-op. Employee, kind, protected reason, or a genuine
   successor bound must change.
7. ADD/CORRECT require ACTIVE employment and Teacher Capability across the full
   requested interval. Open PRIMARY/CO_TEACHER validation uses Academic Year
   exclusive end as the horizon.
8. At most one overlapping PRIMARY exists per Section+Subject.
9. Same Employee+Section+Subject+kind duplicate overlap is denied; distinct
   CO_TEACHER employees may overlap.
10. Requester self-assignment as destination Employee is denied.
11. Mutation/review authorization accepts only live DIRECT ALL, matching CAMPUS,
    exact SECTION, or exact SUBJECT (Section+Subject). CLASS is not accepted.
12. Source/destination Employees are collected and locked UUID-ascending, followed
    by Academic Class → Campus → Academic Year → Class Offering → Section Offering
    → Subject → effective-history locks.
13. Retroactive CORRECT uses submit → review → explicit apply with current-authority
    replay, configured reviewer role, requester/reviewer Person separation,
    deterministic APPROVED→INVALIDATED business failures, application/receipt
    binding, and a bounded checked request read.
14. Successful domain effects emit only `teaching.subject_assignment_changed`.
    Protected reason text is absent from broad audit/outbox payloads.
15. Permission/operation manifests remain 97 permissions / 322 scope alternatives /
    36 operations. Migration 10 stays draft-only; D1C2 and remote Supabase remain
    unauthorized.

## Structural relation-34 correction

The frozen D1C1A trigger originally used `section_offering_id,subject_id,assignment_kind`
as its supersession-lineage parent. That contradicts the approved effect-17 CORRECT
semantics because changing `assignment_kind` would be rejected as cross-parent
supersession.

The continuation recreates only relation 34's `ab_d1_integrity` trigger with:
- overlap identity unchanged:
  `section_offering_id,subject_id,employee_id,assignment_kind`;
- lineage parent narrowed to:
  `section_offering_id,subject_id`.

The existing special PRIMARY overlap check remains unchanged. Therefore kind-changing
CORRECT becomes possible without weakening duplicate overlap or PRIMARY uniqueness.

## Protected SQL surfaces

Private helpers:
- `d1_teaching_subject_assignment_payload_valid`
- `d1_teaching_subject_assignment_request_payload_valid`
- `d1_teaching_subject_assignment_result_matches`
- `d1_teaching_subject_assignment_lock_context`
- `d1_teaching_subject_assignment_preflight`
- `d1_teaching_subject_assignment_effect`
- `d1_teaching_subject_assignment_authorized`
- `d1_teaching_subject_assignment_not_self`
- `d1_teaching_subject_assignment_p2_policy`
- `d1_teaching_subject_assignment_candidates`
- `d1_teaching_subject_assignment_reviews_live`
- `d1_teaching_subject_assignment_participant`
- `d1_teaching_subject_assignment_receipt`
- `d1_teaching_subject_assignment_audit`
- `d1_teaching_subject_assignment_event`
- `d1_teaching_subject_assignment_application_receipt_guard`

Authenticated RPCs:
- `app.d1_change_subject_teacher_assignment`
- `app.d1_submit_subject_teacher_assignment_correction`
- `app.d1_review_subject_teacher_assignment_request`
- `app.d1_apply_subject_teacher_assignment_request`
- `app.d1_read_subject_teacher_assignment_request`

## Static review findings before push

- Exact payload schemas bind Section target version, Subject, source assignment,
  source Employee, source kind, source start, source supersedes, destination Employee,
  destination kind and requested dates.
- Replay result matching re-reads retained history rather than trusting receipt JSON alone.
- P2 approval application has an operation-specific schema-owner trigger tying the
  EXECUTED request, successful `request.apply` receipt, exact source/successor facts,
  target version, Subject and kinds to the application row.
- Direct and P2 success produce one subject-assignment event and one minimized audit
  trail; neither includes private reason text.
- No CLASS, ASSIGNED, role-name, creator, campus-affiliation or generic administrator
  path is accepted as mutation authority.
- No executable `.sql` file, D1C2 artifact, remote deployment action, or manifest row
  is introduced by this candidate.

The independent audit of candidate `60fc799629971e70004499762505f7b1377042f5` found the malformed-P2-payload participant fallback and recorded the older TS/CLASS structural-catalog conflict. Correction commit `af916100936b33c71b0ce4711389e6ada108a086` removes the payload fallback; `b7ed5c7e83cc8b803258796a74b6f81990d102cb` records the operation-specific CLASS denial without changing the frozen 97/322/36 registrar counts.

## Independent freeze note — effect 17/36

Correction commit `af916100936b33c71b0ce4711389e6ada108a086` passed independent source review and GitHub Actions run `36976293526` / run **#41**. The run checked out that exact SHA and completed **121/121** Supabase tooling unit tests, `FOUNDATION_SOURCE_PASS 9 migrations + 9 tests`, `LOCAL_CONFIG_PASS`, lint error/warning gates, all nine frozen Foundation migrations, and **220/220** frozen Foundation pgTAP assertions. Final review confirmed the approved P0/P2 date routing, same Section+Subject retained lineage, kind-changing correction, open-head/no-op rules, full-interval employment and Teacher-Capability coverage, PRIMARY uniqueness, CO_TEACHER coexistence, bounded SUBSTITUTE behavior, no-self-assignment, UUID-ordered Employee locks followed by Academic Class → Campus → Academic Year → Class Offering → Section Offering → Subject → history, ALL/matching-CAMPUS/exact-SECTION/exact-SUBJECT authorization with CLASS alone denied, current requester/reviewer authority, Person separation, deterministic valid-request invalidation, malformed-request fail-closed behavior, receipt/application binding, checked-read minimization and single `teaching.subject_assignment_changed` success event.

`teaching.subject_assignment.change` is therefore frozen as effect **17/36** at implementation SHA `af916100936b33c71b0ce4711389e6ada108a086`, with the corrective audit record at `b7ed5c7e83cc8b803258796a74b6f81990d102cb`. Migration 10 and all 15 continuations remain static `.sql.draft` artifacts and unexecuted; this freeze does not authorize D1C2, Migration 10 application, staging/remote Supabase execution, or any effect-18 implementation.
