# ADR-002: Flutter Multiplatform Client Architecture

- **Status:** Accepted (CONFIRMED product decision)
- **Date:** 2026-09-24
- **Owners:** Product owner; implementation responsibility remains with client/backend engineering
- **Requirement references:** [Master specification](../requirements/School_OS_SaaS_Master_Specification_v0.2.md), sections 5, 22.1, 58-59 and 64; [AGENTS.md](../../AGENTS.md)
- **Supersedes:** Earlier client-priority wording in AGENTS.md, specification section 59, the client/offline invariants and ADR-001's client-platform consistency observation. Other Foundation decisions remain unchanged.

## Context

Earlier active documents called Windows the primary client, described Android separately and excluded Web as the selected PC target. The product owner has now confirmed Android, Windows and Web as first-class current application targets, with one Flutter project/codebase. Historical questionnaire and reference artifacts retain the earlier decision as history.

## Decision

Use one Flutter project/codebase for **Android + Windows + Web**. Share domain/application/business logic, authentication flows, authorization/backend contracts, repositories, validation, approvals, routing concepts, localization, feature state, platform-independent reporting, audit APIs and reusable components.

Use responsive/adaptive presentation primarily based on available width and interaction capability. Compact, Medium, Expanded and Large are conceptual categories; exact breakpoints remain TBD. Keep platform-specific implementations behind narrow capability adapters where practical. Do not duplicate business features by operating system.

All targets obey identical backend authorization, RLS, workflow, audit and historical rules. Web is an authenticated School OS application, subject to browser restrictions. Offline contracts are shared while compliant storage implementations can differ by platform. Future hardware may use platform-specific or local gateway adapters into canonical attendance.

The [client architecture](../architecture/03_flutter_multiplatform_architecture.md) defines the boundaries and remaining UI decisions. This acceptance does not start client implementation or change Foundation physical design.

## Rationale

Shared logic prevents behavior and authorization drift. Adaptive presentation supports both dense school administration and compact devices without maintaining separate business modules. Capability adapters accommodate browser and native differences while preserving backend contracts.

## Alternatives considered

1. Separate Flutter project per platform: rejected because it duplicates maintenance and encourages rule drift.
2. Windows-only product: rejected because it excludes the confirmed Android and Web targets.
3. Identical fixed UI at every screen size: rejected because usable density and interaction differ by available space.
4. Separate business logic per platform: rejected because business truth and security must remain consistent.

## Consequences

### Positive

One feature model and backend contract serve three targets, with presentations appropriate to available space.

### Negative / trade-offs

Build/test coverage must include all three targets, multiple widths and capability failures. Adapters and secure offline/session behavior require platform-specific verification.

### Migration impact

No database tables, columns, constraints, SQL or migrations change. No application files or dependency selections are part of this documentation decision.

### Security/RLS impact

Identical backend enforcement on every target; UI hiding never authorizes access. Native and browser capability differences cannot weaken security.

### Offline impact

Shared version/conflict/idempotency/reauthorization contracts; storage and key management remain TBD by platform. Do not persist sensitive data where encryption requirements cannot be met.

### Future extensibility impact

Hardware adapters may operate on selected platforms or gateways; every client can consume authorized canonical attendance results without supporting every device protocol.

## Validation

Future tests are specified in the [Foundation test strategy](../testing/01_foundation_test_strategy.md). This task validates Markdown links, diff scope and platform wording only; it does not claim executable client or backend tests.

Remaining TBD UI decisions include exact breakpoints, widgets, density, state-management/routing packages and adapter implementations. Client deployment and per-platform offline technology also remain TBD.

## Documentation consistency and history

Active Windows-priority wording and Web exclusion are replaced in instructions, context, specification, invariants and project-management Markdown. ADR-001's earlier precedence observation is explicitly superseded.

The initial questionnaire's earlier mobile/Windows entry is retained with a supersession note. The original specification Markdown and binary PDF/DOCX/XLSX files under reference remain historical snapshots; see the [artifact index](../project-management/ARTIFACT_INDEX.md). Remaining device-specific Windows/Android/Web references describe valid capabilities, not target priority. School website metadata and future payment webhooks are unrelated to client selection.
