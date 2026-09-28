# D1B1 — physical-design review gate

**Status: proposed D1B1 physical catalog, pending D1B2/D1B3 review; NO SQL AUTHORIZED.** [Catalog](../database/27_domain_package_01_physical_catalog.md), [exact dependency graph](../database/28_domain_package_01_exact_dependency_graph.md), [ERDs](../database/29_domain_package_01_physical_erd.md). The [approved product decisions](DOMAIN_PACKAGE_01_APPROVED_DECISIONS.md) settle D1-01–D1-12. **Product-owner questions remaining: 0.** Technical choices below are explicitly gated; they are not permission to weaken the approved rule. If later review finds a genuine product conflict, mark **PRODUCT OWNER DECISION REQUIRED** and suspend the affected package rather than invent an answer.

## Blocks D1B2 constraint/concurrency design

| Gate | Exact issue D1B2 must settle before accepting constraints |
|---|---|
| B2-01 | Define which placement states and effective dates count against class/section capacity, whether pending/reserved placements exist, and atomic check of both offering aggregates with override evidence. Both capacities always apply. |
| B2-02 | Select cross-command lock order/isolation/retry for Student ID, later Admissions number handoff, roll, active PRIMARY enrollment, both capacity limits and concurrent promotion/transfer. Never `MAX()+1` or read-then-write count. |
| B2-03 | Define roll namespace/collision rule for academic-context versus persistent-student mode, NULL-context uniqueness in counter, policy change/migration behavior, persistent-origin/correction invariants and exactly one current allocation per active placement. Numeric is authority, display is derived. |
| B2-04 | Specify no-overlap enforcement for one active PRIMARY placement per Student, its effective intervals and predecessor chain; do not assume a current-row partial unique index alone protects backdated overlaps. |
| B2-05 | Specify one class teacher per section/time; normally one PRIMARY Subject teacher per Subject+section/time; CO_TEACHER and SUBSTITUTE overlap/coverage, mandatory bounded substitute interval and race-safe end/replacement. |
| B2-06 | Specify family relationship versus principal-membership/child-access/primary-display interval checks and revocation ordering; a simultaneous read/revoke must not continue to authorize revoked child access. |
| B2-07 | Make assignment eligibility race-safe against Employee ACTIVE interval, teacher capability interval, section/year bounds and campus ancestry; an ended capability cannot leave current action authority. |
| B2-08 | Specify D1 ancestry structural validation against frozen `app.campuses` and `app.rooms` without assuming unavailable composite keys or altering Foundation. Include class/year same-school consistency and room/section same-campus proof. |

## Can be selected in D1B2

- Exact positive/zero capacity constraint (D1B1 proposes `integer NOT NULL` and zero as closed intake), count query shape, and historical capacity revision sequencing, while retaining both required limits.
- Temporal mechanism: exclusion constraints if a reviewed extension/key supports them, serialized protected checks, or another demonstrably safe implementation. Choose matching indexes from observed roster/history/family/assignment queries rather than broad speculative GIN.
- Candidate UQ redundancies and composite-FK supporting keys on **D1** tables only. `academic_years(id,school_id)` exists; frozen campus/room keys are not presumed.
- Student/Employee current-state projection synchronization and correction ordering. D1B1 chooses controlled projections; events/spells remain source of truth.
- Section room effective-assignment overlap and correction sequencing; no timetable model.
- Initial roll/Student ID counter setup and replay semantics, subject to approved ownership and the later Admissions allocation handoff.

## Can be deferred to D1B3 security/command design

- Exact action/permission codes, operation contracts, worker/definer ownership, search paths, EXECUTE ceilings, RLS/read projection definitions and direct-client denial tests. All D1 base tables stay `app_private` and no anonymous access is proposed.
- ROSTER/PROFILE/RESTRICTED IDENTITY/SENSITIVE-SPECIAL projections; sensitive correction history representation must reconstruct meaningful business changes without emitting raw identity/special values into broad audit/outbox content.
- Typed approval hooks for sensitive corrections/status/transfer/assignment changes, with capacity override **not** needing approval solely because of fullness. Foundation audit, outbox and receipts remain the shared engines.
- FAMILY principal kind validation, emergency-contact non-escalation, Employee affiliation/designation non-escalation, historical read policies and self/ASSIGNED scope contracts.
- File-purpose/entitlement/checked link validation for nullable Student/Employee file references; no D1-22 purpose activation from schema existence.

## Can be deferred to D1C SQL implementation

- Final migration grouping/timestamps, SQL syntax, constraint/trigger/function names and privileges, extension availability, exact indexes after D1B2 review, and seeded permission/operation/event code registration after D1B3.
- Exact Student ID public formatting; `students.school_student_id text` is permanent and server allocated, distinct from `students.id` and child-table `student_id` UUID FKs, but a public prefix is not invented by D1B1.
- Managed/local fresh rebuild and upgrade execution, executable pgTAP 10+, non-owner positive/negative RLS and concurrent race tests. This D1B1 task creates **no** executable test.
- Reproducible Admissions allocator integration when the later Admissions package exists. No fabricated D1 Admissions table, no Student creation activation before a verified final number/serial is supplied.

## Later domain package

Full Admissions application/stages and its number reservation implementation; curriculum composition/versions, elective selections and assessment rules; timetable, attendance, learning, exams/results; Finance, payroll/contracts/leave, medical, transport, hostel/library; custody/court-order/pickup workflows; provider upload-purpose activation; notification delivery, AI/search and full offline protocol. D1 stores only approved identity/history anchors needed by these packages.

## Pass boundary

The catalog proposes **31 D1 relations**: zero in `app`, 31 in `app_private`. All approved concepts have an explicit physical home, and zero new inter-table FK cycles or late FKs are proposed. The Foundation schema remains untouched. D1B2 may review/replace technical candidates with evidence while preserving product invariants. D1B1 is **not** a release, deployment, SQL or migration authorization.
