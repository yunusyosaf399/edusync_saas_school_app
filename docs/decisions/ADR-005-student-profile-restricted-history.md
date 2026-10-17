# ADR-005 — Restricted retained Student PROFILE value history

Date: 2026-10-17  
Status: **BUSINESS REQUIREMENT APPROVED (SP-08 B); PHYSICAL SQL/DEPLOYMENT NOT YET AUTHORIZED**

## Context

The existing D1 `app_private.students` mutable projection contains six nullable PROFILE fields (date of birth, gender, nationality, general contact, previous school, profile photo file ID), with an optimistic `row_version`. The draft `app.d1_change_student_profile` and `app.d1_submit_student_profile_update` wrap six positional nullable arguments into a complete JSON object. The private `d1_profile_effect` currently assigns every supplied key on update, including NULLs. This **cannot** encode independent UNCHANGED versus CLEAR and, for DIRECT, the public signature has **no reason**. Existing broad audit/outbox records are deliberately minimized and cannot act as raw private before/after value history.

The previously frozen D1C1 base physical design contains exactly **34 D1 relations**; arbitrary insertion of an extra relation into Migration 10 would violate its audited count and dependency gate. Existing `student_identity_details`/`student_special_details` are separately permissioned histories and **must not** become PROFILE history by overloading them. Owner-selected SP-08 option B requires restricted value-level accountability without widening those access surfaces.

## Decision

Retain typed old/new PROFILE facts, Student version transition, actor, purpose and private reason for each **successful** Student PROFILE DIRECT or explicit approved APPLY. Do not store raw values in `audit_events`, `outbox_events`, general command receipt summaries, application summaries or broad request search. The same transaction must persist the Student version and its single accepted historical evidence row; failed/stale/denied operations must leave neither.

### Additive design boundary

A future *separately authorized additive migration*, rather than a rewrite of the 34 frozen D1 base tables, will provide a purpose-limited immutable history relation or an equally narrow independently reviewed physical mechanism. Working design candidate: `app_private.student_profile_revisions` with:
- server-generated immutable row ID;
- Student ID with restrictive FK and immutable Student version before/after, constrained to exactly one successful version transition;
- typed old and new snapshots of the six allowed PROFILE fields (not unrestricted table-shaped JSON, no Identity/Special columns), or equivalent typed value-delta columns with explicit `was_null` semantics;
- accepted mutation timestamp, applying individual Principal, immutable typed receipt ID and optional linked application/request ID;
- protected private nonblank reason, stored only in this restricted-purpose surface where allowed by the frozen workflow;
- uniqueness preventing two recorded successful revisions for the same Student/new row version or accepted receipt; no DELETE/UPDATE after insert.

These are **physical-design candidates, not authorized DDL**. Final schema decisions must address chronology/version proof, FK constraints under actual Foundation receipt model, replay proof after subsequent updates, direct and approved executor column privileges, retention/legal erasure policy, file-object association versus copying storage keys, indexing, schema ownership and transactional triggers. This ADR selects the privacy/retention outcome only, **not** a final table/column list.

### Security and access

- Default-deny, `ENABLE` and `FORCE ROW LEVEL SECURITY`, no authenticated/anon/service_role direct SELECT, INSERT, UPDATE or DELETE. No runtime executor may be schema owner or `BYPASSRLS`.
- Only narrow current-purpose no-login executor may write a valid revision through the reviewed typed effect; never expose an arbitrary JSON or table name write interface.
- No Student self or FAMILY entitlement to historical DOB/contact/photo, no implicit `student.profile.view` → history permission escalation. A future checked forensic read requires independently approved fixed permission, appropriate grant/scope, exact field ceilings and sensitive audit, and cannot be enabled merely through this decision.
- Never copy private phone/contact, previous school, DOB, reason or object key into broad outbox or workflow event payloads. Protect historical value fields against debug/log/diagnostic leakage.
- Enforce the existing Foundation SHARED authorization serialization boundary before Student locks and any privileged history write; preserve current authority replay semantics and idempotency proof.

## Alternatives and consequences

**A — metadata-only audit:** rejected for the selected baseline because it cannot reconstruct old and new facts. **B — restricted history (selected):** costs an additional schema/security/release gate, testing and data-retention responsibility, but preserves fact-level forensic accountability. **Reuse general audit JSON or Student identity history:** rejected because it confuses privacy classes and widens a previously reviewed access surface.

## Explicitly not authorized

- Adding a 35th table *inside the frozen 34-relation D1 base* or reinterpreting the old migration count;
- Editing Foundation migrations/tests, the active/bootstrap environment, Auth identities, grants or RLS for production;
- Creating a new historical-read permission or auto-seeding any role grant;
- Enabling `student.profile.update`, renaming `.sql.draft`, deploying to a hosted project or increasing accepted operations before independent SQL/test review.

## Verification before future implementation

Require an additive architecture/DDL review, exact old/new value and version-preservation tests, direct/APPLY exactly-once atomic history tests, current-permission revocation tests, negative unauthenticated and FAMILY read tests, photo purpose tests, observed two-session races, and exact-head Foundation/D1 runtime/static workflow success. Reference [owner-approved contract #173](../database/173_d1_student_profile_p1_owner_approved_contract.md), [pre-approval readiness #152](../database/152_d1_student_profile_update_p1_contract_readiness.md), and [last accepted local test-only freeze #171](../database/171_d1_student_profile_submit_vs_apply_ci_merge_freeze.md).
