# Domain Package 01 — Effect 19 Employee Qualification Security Review

**Status:** SECURITY CANDIDATE — EFFECT 19/36 NOT FROZEN.

Effect 19 implements `employee.qualification.change` from frozen baseline `53130caa90383013055a2a5161b48bd4db2d2272` without adding permissions, scope alternatives, operations, role grants, or principal assignments.

## Security boundaries

- Change authority: exact `employee.qualification.change` through complete Foundation grants and frozen ALL/CAMPUS Employee scope alternatives only.
- Review authority: exact `employee.qualification.approve`, the configured approval-step reviewer role, `D1_REVIEWER_ROLE_SCOPE`, and the same affected Employee campus coverage.
- FAMILY, role labels, Department, Designation, specialization, qualification facts, campus affiliation by itself, record creator, and Employee identity do not grant mutation authority.
- No Employee self-service write path is introduced.
- No direct authenticated DML is granted on `employee_qualifications`.
- Public RPCs derive the current Principal server-side and deny caller-supplied acting principals, permissions, resolvers, roles, tables, or arbitrary patch JSON.

## Concurrency and replay

Protected command context first acquires Foundation authorization lock `(71001,1)` SHARED, then canonical idempotency serialization. Domain mutation uses the frozen School → Employee → qualification-history lock hierarchy. Exact Employee row version plus source snapshot/lineage facts bind mutable intent.

DIRECT and APPROVAL reuse the same locked qualification effect. Exact replay rechecks current authority and routing/participant requirements but does not re-run predecessor-open mutation preflight after a successful CORRECT/ARCHIVE, preventing false replay failure and duplicate history.

## Approval security

- Deployment policy selects DIRECT or APPROVAL; missing or ambiguous routing denies.
- All current Employee campuses must converge. The client cannot select one campus.
- Conflicting campus routes deny. APPROVAL requires one converged policy-version identity so one request cannot silently mix reviewer chains.
- Requester and reviewer must be different Persons.
- Review rechecks current operation, current converged policy, exact reviewer assignment, role and approval scope.
- Apply is callable only by a current authorized requester or current exact final approver.
- Apply revalidates every completed approval step's reviewer Person separation, reviewer role and current `employee.qualification.approve` scope.
- Deterministic business staleness invalidates; malformed/corrupted stored payload or unexpected SQL/infrastructure failure rolls back.
- INVALIDATED requests create no qualification mutation, approval application, or success outbox event.
- Successful `approval_applications` are guarded against the exact apply receipt, Employee target version, result snapshot/lineage, and ADD/CORRECT/ARCHIVE history shape.

## Disclosure and evidence

Qualification title/institution/specialization/reason are excluded from broad audit/outbox evidence. Successful outbox event is only `employee.qualification_changed`, with snapshot/lineage/source identifiers and Employee ID. Retained-history event aggregate is the affected qualification snapshot at version 1.

The operation-specific checked request read is the only new workflow disclosure surface. It requires current participant authority and returns typed old/proposed qualification fields only; it excludes arbitrary request JSON, private workflow reason, grants/scopes, audit payloads and unrelated Employee information.

## ACL model

`schoolos_authz_reader` owns the narrow authorization/policy/candidate/participant predicates. `schoolos_employee_executor` owns the domain validation/effect and DIRECT RPC. `schoolos_workflow_executor` owns submit/review/apply orchestration. `schoolos_read_executor` owns the checked request read. `schoolos_evidence_writer` owns effect-specific receipt/audit/outbox helpers. `schoolos_schema_owner` owns only the defensive application trigger.

All new private functions revoke PUBLIC/anon/authenticated/service_role EXECUTE and grant only the required NOLOGIN executor edge. Public RPC signatures revoke PUBLIC/anon/service_role and grant only authenticated. No executor membership chain or schema-owner runtime entry point is introduced.

## Gate

This is a source-level static candidate. Migration 10 remains `.sql.draft`; SQL has not been executed; D1C2 and remote/staging Supabase execution remain unauthorized. Exact-SHA CI and independent review are required before effect 19 can be frozen.
