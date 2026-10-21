# DB-03 Owner decision — administration test skip; FAILED cannot be bypassed (21 October 2026)

**Status: OWNER-SELECTED BUSINESS CONTRACT. SQL and runtime acceptance NOT IMPLEMENTED.**

## Owner instruction (meaning preserved)

> "Yes they can also allow to skip test but failed not allowed to admit just administration allow to skip test and proceed with further requirements like admissions fee clearance etc"

**Approved behavior, precise scope:**

1. An authorized School administration actor may **exempt an applicant from the admission test** and let the application proceed through **all other** published policy requirements, including **mandatory Finance-authorizer clearance**. The authorization is application-specific and must be retained with actor, current permission, exact ADMISSION_TEST policy stage/application, expected versions, decision timestamp and controlled reason.
2. An actual, current, valid examiner-recorded **FAILED** admission-test outcome **blocks school admission completion and final READY/Student Creation**. **Administration may not apply a SKIP after FAILED as a bypass.** For implementation safety, ordinary test skipping is permitted only while that stage is unassessed/pending and there is no effective PASSED or FAILED assessment decision. The exact treatment of a legitimately voided/corrected or reattempted assessment is a **separate P4-D02/P4-D03 owner/security choice**; no retake, score correction or failed-to-passed reset is approved by this instruction.
3. A recorded examiner **PASSED** satisfies the admission-test requirement when otherwise valid. The already approved P4-D01 stays unchanged: an authorized examiner determines PASSED or FAILED, numeric score optional, **no automatic passing threshold**.
4. School-administration SKIP is a **typed, independently auditable exception** to the *ADMISSION_TEST requirement only*, not a fabricated assessment PASSED, not a client `test_skipped=true` field and not a general-purpose override. The published policy can itself declare ADMISSION_TEST SKIPPED as an independent policy configuration; individual administrative exemption must remain distinguishable from the published configuration.
5. Even with a legitimately skipped test, **verified Person identity, other REQUIRED document/interview/approval stages, any school-confirmed internal offer as configured, current school adjudication ACCEPTED and explicit Finance-authorizer clearance** remain required for READY. Waiver/tuition discount decided by Admissions does **not** replace Finance clearance. D1 `student.create` remains disabled pending separately approved gates and code.
6. A historical FAILED result is immutable even if a later separately approved correction/retake ever becomes possible. The present decision does not authorize clearing a FAILED stage by administrative discretion, deleting the result, retroactively recording that the exam never happened, reopening CONSUMED history or permitting Student creation from a FAILED source.
7. The current app need not automatically become REJECTED merely because test FAILED unless an independently approved application-rejection policy commands that transition. Until then it may remain IN_PROGRESS but **must not become READY/CONSUMED**. An invalid school ACCEPTED projection cannot be used as an exemption from the FAILED gate.

## Candidate non-executable SQL guard, selected precedence and lineage

**Existing proposed DB-03 entity #15** `admission_stage_exceptions` may record typed `ADMIN_TEST_SKIP` with a real application ID and matching policy stage ID, authorized administrative Principal, expected application/stage/assessment head versions, reason, approval request link **only if configured Foundation route actually requires one**, immutable revision/predecessor and Foundation command receipt. The presence or absence of a second reviewer, allowed administration role/scope/approval route and exact stage epoch/lock rank remain pending technical/security sign-off.

**Guard order at one serialization point:**
- Verify active School/Principal/scope and authorized `admission.test.skip` equivalent; this is a candidate permission name, **not registered**.
- Lock Foundation authorization/command prefix, School/Person/catalog parents, Admissions application and current ADMISSION_TEST evidence at owner-approved rank, then re-read the actual current assessment stream and stage outcome heads **after any wait**.
- If assessment is currently FAILED ⇒ **DENY ADMIN_TEST_SKIP**. If assessment already PASSED ⇒ no SKIP is necessary; a competing skip must deny rather than rewrite the assessment. If outcome is pending and no committed assessment decision exists, append exactly one current typed `ADMIN_TEST_SKIP` decision as an exception head and update evidence epoch/accepted receipt atomically. An independent P1 policy-configured SKIPPED stage does not require a per-application exception.
- Once a SKIP is current, subsequent assessment INSERT/record for the same stage is blocked unless a separately approved **typed rescind-and-reassess** workflow preserves the original skip; no race may result in an effective FAILED being bypassed by the skip.
- P7 `ENROLLMENT_READY` tests that the latest valid ADMISSION_TEST predicate is **(a) current PASSED**, or **(b) policy-configured SKIPPED**, or **(c) current specifically authorized ADMIN_TEST_SKIP with NO committed FAILED assessment**. Current FAILED ⇒ always DENY. Every other REQUIRED stage remains independently validated.
- Handoff P7 issuance and future D1 consumption recheck this source under the same eventual global lock/fence; any current FAILED decision, identity amendment or test-skip revocation makes prior unused READY unusable. Original history stays intact.

**Important design distinction:** current #10 `admission_stage_outcomes` has `PENDING,PASSED,FAILED,SKIPPED,INVALIDATED` but no special `ADMIN_TEST_SKIP` status. Do **not** write `PASSED` or policy `SKIPPED` to hide a required-stage exception. Prefer an explicit typed #15 effect plus a derived `test_requirement_satisfied_by_admin_skip` predicate, retaining honest raw assessment/outcome history. Any implementation change to stage outcome enum is a separately reviewed migration.

## Business examples

- **Allowed:** applicant is awaiting admission test; authorized administrator records a reasoned exemption. School may review the rest of the application. Finance authorization still required before student creation.
- **Blocked:** examiner already recorded FAILED; administrator attempts SKIP to admit the same applicant. Reject SKIP and final READY, preserving FAILED history.
- **Passed:** examiner records PASSED (score optional). Stage may pass without an administrative exception. Other stages and Finance remain required.
- **Concurrent:** examiner records FAILED while administrator attempts a test skip. There must be a single serialized outcome: FAILED first denies skip; SKIP first means the examiner cannot quietly record a valid conflicting assessment without a separately approved rescind process.

## What is and is not approved

**Selected:** administration may skip admission test for an eligible pending application; a FAILED test cannot be bypassed for admission; all remaining requirements including Finance-authorizer clearance still apply.

**Not selected by this statement:** exact registered administration permission name/role and Campus scope, independently reviewed second approval, policy for rescinding a skip, late recorded results and genuine retakes or corrections, whether FAILED also mandates terminal REJECTED, privileged correction time limits, SQL lock rank across Finance/D1, and the Finance-owned verifier. These remain separately gated. Do not implement a permissive fallback.

This decision narrows prior P6-D03 and P5-D04 proposals and is binding for new DB-03 documentation; older draft alternatives remain historical. No SQL, D1, Finance, Foundation, global permissions, shared manifests, hosted database changes or PR merge are authorized by this document.
