# 03 - Flutter Multiplatform Architecture

**Status:** CONFIRMED product architecture, 2026-09-24. UI implementation details explicitly marked TBD below.
**Decision:** [ADR-002](../decisions/ADR-002-flutter-multiplatform-client-architecture.md).
**Requirements:** [Master specification](../requirements/School_OS_SaaS_Master_Specification_v0.2.md), sections 5, 22.1, 58-59 and 64.

## One project and shared layers

EduSync / School OS uses **one Flutter project/codebase**, with **Android, Windows and Web as first-class current application targets**. This is a target commitment, not a claim that each client is already implemented or release-tested. Database/physical design remains the current engineering phase.

| Layer | Responsibility shared across targets |
|---|---|
| Domain | Models, business rules, validation and historical invariants |
| Application | Use cases, workflows/approvals, authentication flows and feature state |
| Data/infrastructure | Supabase repositories, backend contracts, platform-independent reporting and audit-facing APIs |
| Security | Shared permission evaluation concepts; backend remains authoritative for every action |
| Presentation | Shared routes, localization and reusable components with responsive/adaptive composition |
| Platform adapters | Narrow interfaces for capabilities whose implementation differs by platform |

Conceptual structure, not a proposed restructuring of `lib/`:

```text
Flutter application (one project)
|-- Shared domain, application, data/repositories
|-- Shared security, routing, localization, feature state
|-- Adaptive presentation
|   |-- Compact
|   |-- Medium
|   |-- Expanded
|   '-- Large
'-- Platform adapters
    |-- Android
    |-- Windows
    '-- Web
```

Business features must not be duplicated into separate Android/Windows/Web modules. For example, one Student repository and application/domain state can feed compact, medium and expanded presentations. This example does not authorize a Student schema or feature implementation.

## Responsive and adaptive presentation

Choose layouts primarily from **available window width and interaction capability**, rather than operating-system tests. Windows can be resized, browsers can be narrow, and Android devices can have large screens. Support touch, pointer and keyboard interactions as appropriate without changing business rules.

| Conceptual class | Examples | Navigation guideline |
|---|---|---|
| Compact | Phone or narrow browser/window | Bottom navigation or drawer |
| Medium | Tablet or medium window/browser | Navigation rail or similar |
| Expanded | Laptop or normal desktop/browser | Persistent labeled sidebar or rail |
| Large | Large monitor/admin workstation | Persistent navigation with additional useful panels |

These are guidelines, not mandatory Flutter widgets. **Exact pixel breakpoints are TBD/PROPOSED**, to be validated during UI design. Routes, authorization and logical feature availability remain shared. Capability limitations must be explicit rather than inferred from a different menu.

Students, Attendance, Fees, Results, Employees, Payroll, Library, Reports and Admissions may use dense tables, side-by-side panels, persistent filters, multi-column forms and wider dashboards at suitable widths. Compact views may use cards, stacked fields, detail pages, bottom sheets, compact filters and single-column forms. Both call the same application logic; neither stretching a phone layout nor forcing a fixed desktop layout satisfies this decision.

## Platform capability adapters

| Target | Examples of adapter responsibilities |
|---|---|
| Android | Camera/QR, runtime permissions, push integration; future NFC/device APIs only when authorized |
| Windows | Native filesystem, printing, keyboard shortcuts, window behavior, encrypted local storage; future device SDK/gateway integration |
| Web | Browser file selection/download, browser storage, URL navigation and browser-specific authentication/session handling under browser security restrictions |

A shared DocumentExportService contract may have Android, Windows and Web implementations. Export authorization and reporting rules remain shared. Browser code must not assume unrestricted native filesystem or device access. Isolate native imports and APIs so they do not break other target builds. Exact adapter APIs and packages are TBD; no adapters are implemented by this decision.

## Offline and security

Offline support remains required where specified, particularly attendance. Share record/version contracts, conflict detection, idempotent replay and server-side authorization revalidation on synchronization. Do not silently resolve critical conflicts with last-write-wins.

Storage technology, key management and detailed offline capabilities are **TBD per platform**. Sensitive local data must satisfy encryption and authorization requirements. If a browser or another environment cannot meet those requirements, do not persist that sensitive cache; defer the capability until a compliant design exists. This does not waive the offline requirement or weaken it to unencrypted persistence.

All three clients obey the same authentication, role + action permission + scope + contextual assignment + workflow state model, RLS, approval, audit, history, AI and storage authorization rules. Campus and assignment restrictions apply equally to online/offline data, search, reports and exports. UI hiding is never authorization. Session transport and local storage may differ; backend authority does not.

## Web application scope

Flutter Web is an authenticated operational application: Principal/Admin dashboards, Teacher, Parent and Student portals, Finance/Admin operations, reporting and school workflows. It is not a replacement requirement for an SEO/content-heavy public school marketing website. No separate marketing website is introduced.

## Future hardware and canonical attendance

Preserve the existing flow:

```text
Manual / QR / future biometric / RFID-NFC / camera capture
    -> capture adapter and source event
    -> identity resolution and validation
    -> canonical attendance domain
    -> audit / notifications / analytics
```

Future hardware may require a selected platform or an edge/local gateway. For example, a Windows workstation/gateway may communicate with a biometric terminal and send validated source events to the school backend. Web can consume authorized canonical results without directly speaking that device protocol. Do not require all targets to implement every hardware SDK. Biometric, RFID/NFC and camera integrations remain FUTURE, with no vendor tables, templates or SDKs selected.

## Scope, validation and remaining decisions

The [test strategy](../testing/01_foundation_test_strategy.md) describes future behavior/security parity, width/resizing coverage, adapter contracts and target build isolation.

TBD: exact breakpoints; navigation widgets and visual density; state-management/routing packages; detailed adapter APIs; per-platform storage/key/session mechanics; offline scope and sync algorithms by data type; client release/distribution and Web deployment procedures. No package is selected here.

This decision changes documentation only. It creates no screens, dependency changes, application restructuring, physical schema changes, SQL, migration, Supabase configuration or deployment.
