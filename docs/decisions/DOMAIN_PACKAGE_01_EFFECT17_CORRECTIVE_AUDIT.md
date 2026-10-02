# Domain Package 01 — Effect 17/36 corrective independent audit

**Audited candidate:** `60fc799629971e70004499762505f7b1377042f5` (`Implement D1 subject teacher assignment workflow`).

**Baseline:** `6b60fb5d93ab13359682837cfb948a16234e0ede` (corrected/re-frozen effect 16).

**Status:** corrective source review. Effect 17 is **not frozen** until the correction commit passes the normal CI gate and is independently rechecked. Migration 10 and every effect-17 continuation remain non-executable `.sql.draft`; D1C2 and remote Supabase remain unauthorized.

## CI evidence for the audited candidate

GitHub Actions run `36968437312` / run number 40 completed successfully on the exact audited candidate SHA. It reported:

- 121/121 Supabase tooling unit tests passed;
- frozen Foundation source/config gates passed;
- local reset applied exactly the nine frozen Foundation migrations;
- all nine frozen Foundation pgTAP files passed, 220/220 assertions;
- local lint error/warning gates passed.

This is regression evidence only. The effect-17 `.sql.draft` files are intentionally not executed by that workflow, so the run does not prove PostgreSQL parsing or runtime behavior for effect 17.

## Finding 1 — post-D1B4 Subject-assignment scope clarification

The frozen D1B4 permission catalog defines scope set `TS` as `ACSS` direct, so its structural scope alternatives include ALL, CAMPUS, CLASS, SECTION and SUBJECT. The registrar consequently retains CLASS scope-contract alternatives for both `teaching.subject_assignment.change` and `teaching.assignment.approve`.

During effect-17 contract approval, the product owner made a later, operation-specific decision: Subject Teacher assignment mutation/review authority is limited to complete live DIRECT **ALL, matching CAMPUS, exact SECTION, or exact SUBJECT (Section+Subject)**. CLASS alone does not authorize this protected operation. This is the Subject-assignment counterpart to the already-recorded effect-16 Class Teacher narrowing.

That later operation contract governs the protected effect. The older TS structural alternatives and the frozen 97-permission / 322-scope-alternative / 36-operation registrar counts are not rewritten in effect 17. A CLASS scope row may therefore exist structurally but is intentionally inert for these two protected Subject-assignment authorization checks.

**Simple example:** a principal can possess a structurally valid `teaching.subject_assignment.change` scope row for Grade 5 CLASS, but that row alone cannot assign a Math teacher to Grade 5-A. They need ALL, the matching Campus, the exact Section, or the exact Section+Math Subject scope.

D1C2 must include a negative test proving CLASS-only mutation and CLASS-only review both deny, despite the structurally registered TS CLASS alternative.

## Finding 2 — malformed P2 payload must not bypass current authority

The audited candidate's initial P2 apply implementation had one unsafe fallback: if the stored request payload failed the exact Subject-assignment payload validator, the original requester could still be treated as the `REQUESTER` participant solely by requester UUID. That allowed workflow mutation to `INVALIDATED` without resolving the exact Subject and therefore without proving current target authority.

The corrective continuation removes that fallback. Apply now requires the stored request payload to validate before participant resolution or receipt replay. A malformed stored request is treated as unavailable/integrity failure and causes no workflow mutation, receipt, application, audit or outbox effect. Valid requests still use the approved deterministic failure behavior: stale policy, authority, reviewer eligibility, source/target facts, employment/capability or overlap failures transition APPROVED → INVALIDATED with a REJECTED `request.apply` receipt and no domain mutation.

**Simple example:** if privileged corruption removes the request's Subject ID after approval, a requester who no longer has teaching authority cannot use their original requester identity to alter request state. The apply call denies and rolls back.

## Other independent checks

No further material blocker was found in the candidate source review:

- ADD, END and CORRECT routing matches the approved current/future P0 and retroactive-CORRECT P2 split.
- CORRECT retains Section+Subject and may change Employee/kind; relation-34 supersession lineage was narrowed to Section+Subject while duplicate-overlap identity remains Section+Subject+Employee+kind.
- one overlapping PRIMARY per Section+Subject remains enforced; distinct CO_TEACHER employees may overlap; SUBSTITUTE remains bounded and does not implicitly replace PRIMARY.
- only an open unsuperseded source can END/CORRECT; no-op CORRECT denies.
- ACTIVE employment and Teacher Capability cover the whole requested interval; open PRIMARY/CO_TEACHER uses the Academic Year exclusive-end horizon.
- self-assignment denies for ADD/CORRECT.
- source/destination Employees are UUID-sorted, followed by Academic Class → Campus → Academic Year → Class Offering → Section Offering → Subject → eligibility/history locks.
- exact current requester/reviewer authority, configured reviewer role, Person separation, expected versions and live policy are rechecked through P2.
- application/receipt binding includes exact Section, Subject, source, destination, kind and dates.
- broad audit/outbox evidence excludes private reason text; success emits only `teaching.subject_assignment_changed`.
- authenticated receives only the five fixed RPC EXECUTE grants and no new base-table DML.

## Corrective source artifact

`supabase/migrations/20260928000000_domain_package_01_effect17_15_subject_assignment_apply_correction.sql.draft` replaces only `app.d1_apply_subject_teacher_assignment_request` after the original 14 ordered effect-17 continuations. It is part of the same non-executable Migration-10 review unit and must be folded/reconciled before any later executable migration authorization.

**Freeze gate:** push the correction, require CI PASS on the correction SHA, independently recheck the exact diff, then record the effect-17 freeze. Do not begin effect 18 before that gate.
