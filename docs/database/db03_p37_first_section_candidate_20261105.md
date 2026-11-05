# DB03 P37 — first Section candidate for Principal approval / D1 intake

**Date:** 5 November 2026. **State:** isolated, inactive read-only candidate; not a Principal finalization, Student creation, Enrollment, Roll allocation, grant, hosted migration or seat reservation.

## Why this increment is necessary

Admissions P15 currently records the application’s **Class Offering (grade)**. D1’s permanent FIRST PRIMARY Enrollment requires a **Section Offering** with correct Class, Campus, Academic Year, live placement policy, capacity and roll allocator. A grade-only intention cannot be converted into a Student Enrollment, and a Principal must not silently choose any section by name or from client-supplied unverified JSON.

Example: an administrator forwards Ahmad’s complete Grade 1 application, with admission-fee status UNPAID. The school later proposes Grade 1-A as the first Section. The database must prove that Grade 1-A belongs to **the same grade, campus, school and year as the current forwarded application** before final approval. Grade 1-A in the Girls Campus or a stale review must be rejected. The Principal is still the sole final approval authority.

## Source implemented

`app_private.db03_principal_section_candidate_source(application_id,expected_version,forward_id,section_offering_id)` composes the existing private P36 source with current **D1 Section Offering → Class Offering** ancestry. It returns a typed candidate only when:

- application version and real latest forwarded snapshot remain current under P36;
- current fee declaration and Class Offering are bound by P36 (UNPAID is a valid declaration, not verified payment);
- Section Offering belongs to precisely that Class Offering, Campus, School and Academic Year;
- current Class and Section state are both OPEN.

It rejects missing/nonexistent Section, version-stale Forward and other-campus or wrong-grade Section. The source is **SECURITY INVOKER**, private schema-owned, and denies `PUBLIC`, `anon`, `authenticated`, `service_role` and worker/executor roles. It returns no actual applicant documents or contact information.

This is **not** the ultimate Section reservation or D1 authorization gate. It does not lock the School, Class, Section, capacity revisions, allocation policy, active Principal appointment or a particular seat. It does not seed Student/Enrollment/Roll, and its outputs permanently report:

- `section_capacity_reserved=false`, `section_capacity_available_verified=false`, `roll_policy_locked=false`;
- `principal_approve_authorized=false`, `atomic_student_handoff_available=false`, `can_approve=false`, `can_create_student=false`.

Actual final approval must recheck every binding and current authorization **after locks** in one School→Admissions→D1 transaction and consume a genuine single-use handoff.

## Acceptance

- Source-only CI forbids schema/data mutation, grants, public commands and permissive success fields.
- **21 rollback-only pgTAP assertions** prove the private signature, ACL, owner, invoker status, safe search path and invalid/no-input rejection.
- Real signed-auth P35B integration forwards an actual private measured PDF for a Grade 1 application marked UNPAID. CI creates **two test-only Section Offerings**, one in the correct School/Campus/Class and one in another Campus. It must observe positive matching, cross-campus rejection, stale-version rejection and no capacity reservation or Student creation.
- The P37 SQL draft also passes failed-install injection / absence and rollback-only installation, all inside the disposable school CI environment.

## Remaining critical implementation

The next boundary requires a **protected, independently authorized Principal APPROVE mutation**, Person identity final proof, one-use accepted handoff, server-generated School Student ID and admission number, first Student status, **actual capacity check and PRIMARY Section Enrollment, roll allocator and retained historical lineage**, original certificate links, exact-key replay and one receipt/audit/outbox. It must prove both competing-approval and crash/rollback winner/loser behavior with true two-session database tests.

Do **not** merge P37 to its parent until exact-head DB03 acceptance passes; do **not** enable `student.create`, grant new permissions, deploy Supabase or merge `main` without explicit separate production review.
