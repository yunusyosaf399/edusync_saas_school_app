# Student Creation — Admissions-dependent P0 implementation contract readiness

Status: **BLOCKED BY CROSS-PACKAGE DEPENDENCY**, not a runnable D1 mutation (2026-10-16). Operation: `student.create`. Frozen [Effect36 dependency review](76_domain_package_01_effect36_student_create_dependency_review.md) explicitly forbids invented handoffs and states the operation must remain unavailable until trusted Admissions integration exists.

## Frozen non-negotiable transaction

1. A trusted Admissions domain, **not a Flutter/client boolean, arbitrary JSON or admin override**, issues a server-verifiable final **unused** handoff for an accepted application, exact resolved Person/identity, approved year/campus/class/section placement and required fee/stage/approval state.
2. Current authenticated staff actor must have BOTH `student.create` and `student.enrollment.place` permission/scope for the target destination; no Family role or job title shortcut. Handoff and identity/placement ancestry must be locked and **revalidated** after lock waits.
3. In one protected transaction allocate permanent `school_student_id` from D1 server logic, create the Student/Person relation and Admissions identifiers, append initial status/projection, create PRIMARY enrollment with exact Class/Section capacity rules, allocate correct roll and mark the handoff consumed exactly once.
4. Store accepted typed command receipt, minimal `student.created` audit/outbox; no sensitive applicant identity/contact/document/payment payload in broad evidence. Failure rolls back every Student, status, placement, roll, numbering, handoff and evidence effect.
5. Idempotent same-key retry returns prior result after current authorization; changed intent or competing key cannot create another Student from one final handoff. No automatic Family grouping/relationship/portal access/child entitlement or Foundation grant.

## External dependency versus proposed design

The [Admissions intake physical design #79](79_admissions_student_intake_physical_design.md) proposes `admission_applications`, `admission_handoffs`, immutable stage/outcome/fee/identity snapshots, publication, consumed state and indexes. It is explicitly **PROPOSED**, not installed nor accepted. The frozen D1 [Effect36](76_domain_package_01_effect36_student_create_dependency_review.md) has **zero SQL delta** and deliberately defines no `student.create` RPC. A pass in #65 only shows the operation remains safely disabled.

## Required external decisions and deliverables

| ID | Prerequisite | Acceptance evidence before enabling |
|---|---|---|
| SC-01 | Approved final Admissions policy/stages and identity-resolution source | Authoritative table/command/contract version, verified Person binding, unexpired exact outcome; no client flags |
| SC-02 | Final handoff issuance and consumption | Durable READY/CONSUMED/INVALIDATED state machine, unique single-consumption and actor/receipt binding with real database constraints |
| SC-03 | Correct fee clearance/approval and version snapshots | Finance-owned current clearance and configured reviewer evidence cannot be forged by admin override |
| SC-04 | Atomic destination and Student numbering handoff | Effective Academic Year/Campus/Class/Section with current capacity and approved roll policy; D1 school Student ID allocator serializes correctly |
| SC-05 | Typed D1 P0 command and result | Verified handoff ID, expected versions, idempotency key, server-validated placement, typed result/receipt with no sensitive broad payload |
| SC-06 | Cross-package lock order and race outcomes | Competing intake, handoff invalidation, payment reversal, Student creation replay, School permissions revoke races have explicit serialization/invalidation rules |
| SC-07 | Full acceptance across package boundary | Real Admissions-produced handoff consumed by authenticated D1 command; no SQL-owner forged handoff or direct Student INSERT as application actor |

## Mandatory tests after Admissions is approved and implemented

- Successful authenticated accepted Admissions-to-Student handoff builds Student core, first status, initial PRIMARY placement and roll, consumes handoff, allocates permanent Student ID and emits exactly one `student.created` event/receipt.
- Deny draft/rejected/withdrawn/used/invalidated handoff, incomplete stage, wrong Person/year/section, stale identity, missing Finance clearance, wrong campus/permission, disabled policy, capacity full and duplicate competing intake key, all with zero partial effects.
- Independent two-session verified Student creation/creation and creation/Admissions invalidation races plus receipt terminal replay, exact blocking evidence, crash/retry and no double consumption.
- The physical Admissions proposal must pass its own Foundation/RLS/role tests and receive separate approval; it cannot be smuggled into inactive D1 migration as a fabricated test fixture.

**Decision gate:** SC-01…SC-07 depend on a separately frozen, installed and accepted Admissions package. Until then `student.create` remains intentionally disabled, with **no** plausible authorized success path. Do not count a denial-only placeholder as completed.