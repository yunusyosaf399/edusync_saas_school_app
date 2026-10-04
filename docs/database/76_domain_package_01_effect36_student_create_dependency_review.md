# D1C1B Effect 36/36 — Student Create Admissions Dependency Review

**Status: ACCEPTED DEPENDENCY CONTRACT; RUNTIME ACTIVATION DEFERRED.**

Effect 36 closes the final D1C1B operation-ledger item, `student.create`, by freezing the already-selected cross-package integration contract. It does **not** implement or enable Student creation because the required verified final Admissions handoff belongs to a later package and does not exist in D1.

The trusted executable/static runtime boundary therefore remains Effect 35 runtime SHA `97e6eb7d8329475861fd3b4c0f7fc5f7e7c175c7`. Effect 36 has zero SQL/runtime delta.

## Frozen operation identity

Operation: `student.create`

Required permissions: exact current `student.create` **and** `student.enrollment.place` authority for the resulting accepted placement context.

Routing: **P0 protected direct**, but the operation remains disabled/unavailable until a later approved Admissions package supplies the verified final handoff contract and D1 integration implementation.

The existing 36-operation manifest entry remains registered disabled. No authenticated direct INSERT into Student/Person/Enrollment/status/roll tables is authorized.

## Frozen Admissions handoff boundary

A successful future invocation may consume only a trusted, final, unused Admissions handoff produced by the approved Admissions domain. D1C1B does not define, fabricate or infer that handoff from client input.

The future handoff must be server-verifiable and race-safe. At minimum, integration must prove that the source Admissions process reached the accepted/final state required for Student creation, is bound to the intended applicant/person identity and placement intent, and has not already been consumed for another Student creation.

The following are explicitly **not** substitutes for the handoff:

- a Flutter/client boolean such as `approved=true`;
- a caller-supplied application/admission number without server-side Admissions verification;
- arbitrary JSON claiming approval;
- a generic administrator override;
- direct privileged inserts that bypass the protected command.

One accepted handoff may create at most one Student. Retry/replay must not create a duplicate Student.

## Frozen atomic effect

When the later Admissions package exists and runtime activation is separately reviewed, one protected transaction must perform the accepted creation effect atomically:

1. validate and lock the final Admissions handoff;
2. establish or consume the approved Person/applicant identity relationship required by the later integration design;
3. allocate the permanent school-facing Student ID through trusted server/database logic;
4. create the Student core with immutable Admissions-facing identifiers supplied/verified by the trusted handoff contract;
5. append the required initial Student status and synchronize the current projection;
6. create the accepted PRIMARY enrollment in the approved destination Section/Class/Campus/Academic-Year ancestry;
7. allocate the roll using the frozen allocator/roll-policy rules;
8. enforce class and Section capacity, including the separately frozen capacity-override contract when applicable;
9. mark the handoff consumed in the same transaction or through an equivalent race-safe single-consumption mechanism;
10. append only the approved command receipt/audit/outbox evidence.

If any required step fails, none of the Student/status/enrollment/roll/handoff-consumption effects may commit.

## Authorization and placement boundary

`student.create` authority alone does not grant placement authority. The actor must also satisfy current `student.enrollment.place` permission/scope for the exact resulting destination.

Destination scope is evaluated from the accepted placement ancestry. Authority in Campus A does not permit creation into Campus B. Existing capacity, Section state, offering ancestry, Academic Year, roll-policy and enrollment invariants remain mandatory.

No role name, job title, Department, Designation, teaching assignment or UI visibility substitutes for the required live permissions/scopes.

## Identifier ownership

The permanent `school_student_id` remains server-allocated by the Student domain at actual Student creation and is never a client-selected identifier.

The existing physical contract keeps internal Student UUID, permanent school Student ID, Admissions number/serial and roll as distinct identifiers. A later Admissions integration must preserve that separation; it may supply/verify Admissions-owned identifiers only through the trusted handoff contract.

## Family and authorization side-effect prohibition

Student creation does not automatically create or grant:

- a Family grouping;
- Father/Mother/Guardian relationships;
- FAMILY Principal membership;
- child-access authority;
- primary Family context;
- Foundation roles, grants, permissions or scopes.

Those facts remain controlled by their separately frozen Family/Foundation operations.

## Evidence boundary

The selected broad event vocabulary includes `student.created`. Future runtime evidence must remain identifier/state/context evidence only. It must not copy restricted identity, guardian contact, birth-certificate content, private address, arbitrary Admissions payload or arbitrary reason text into broad audit/outbox records.

Exact receipt/result/audit shapes are runtime SQL syntax work for the later integration pass; Effect 36 does not invent them before the Admissions source contract exists.

## D1C1B closure meaning

The D1B4 future-test contract already permits the 36-operation ledger to be accounted for by either an explicit entry point or a documented disabled dependency, explicitly naming `student.create` pending Admissions. Effect 36 uses that approved path.

Therefore D1C1B is contract-complete at **36/36 accounted operations**, but only **35 D1 operation effects are implemented/frozen as current Migration-10 draft runtime behavior**. `student.create` is the one frozen cross-package dependency and remains unavailable.

This distinction is mandatory: 36/36 ledger closure is not 36/36 executable mutation coverage.

## Change boundary

Effect 36 adds documentation only. It adds no SQL draft, RPC, table, trigger, grant, RLS policy, role, worker, Flutter code, Admissions allocator or handoff placeholder.

Foundation migrations 1–9 and tests 01–09 remain unchanged. The manifest remains **97 permissions / 322 permission-scope alternatives / 36 operation contracts**. Migration 10 remains non-executable `.sql.draft` material and unexecuted. D1C2, staging/managed Supabase application and worker activation remain unauthorized.

The next gate after this freeze is D1C1C integrated Migration-10 closeout/static audit, with `student.create` preserved as disabled pending Admissions.