# D1B1 — physical-design review gate

**D1B3B disposition:** D1B3A scope storage/resolvers plus the [D1B3B permission/disclosure catalog](../security/08_domain_permission_disclosure_catalog.md), [checked-read/command contract](../security/09_domain_checked_reads_and_commands.md), [execution/RLS matrix](../security/10_domain_execution_rls_matrix.md), [approved disclosure decisions](DOMAIN_PACKAGE_01_D1B3B_APPROVED_DECISIONS.md) and [D1B3B review](DOMAIN_PACKAGE_01_D1B3B_REVIEW.md) complete the D1B security design. Exact permissions, family_safe flags, supported scope alternatives, field-limited reads, protected commands, approval classes, audit/outbox redaction, file-purpose bindings and non-owner test requirements are frozen. **Migration 10 remains unauthorized; D1C SQL drafting requires separate authorization and no remote staging action is authorized.**

**D1B2 disposition:** The technical gates below are resolved for physical design by the [D1B2 review](DOMAIN_PACKAGE_01_D1B2_REVIEW.md), [constraint matrix](../database/30_domain_package_01_constraint_matrix.md), [locking contract](../database/31_domain_package_01_concurrency_and_locking.md), and [index freeze](../database/32_domain_package_01_index_review.md). This section preserves the review questions as history; it is not an open D1B2 blocker list. D1B3B permission/RLS/read/command contracts are next. Migration 10 and SQL remain unauthorized.

**Status: historical D1B1 gate; D1B2 and D1B3 design are resolved in linked reviews; NO SQL AUTHORIZED.** [Catalog](../database/27_domain_package_01_physical_catalog.md), [exact dependency graph](../database/28_domain_package_01_exact_dependency_graph.md), [ERDs](../database/29_domain_package_01_physical_erd.md). The [approved product decisions](DOMAIN_PACKAGE_01_APPROVED_DECISIONS.md) settle D1-01–D1-12. **Product-owner questions remaining: 0.** Technical choices below are explicitly gated; they are not permission to weaken the approved rule. If later review finds a genuine product conflict, mark **PRODUCT OWNER DECISION REQUIRED** and suspend the affected package rather than invent an answer.

## Blocks D1B2 constraint/concurrency design

| Gate | Exact issue D1B2 must settle before accepting constraints |
|---|---|
| B2-01 | D1 Enrollment is accepted PRIMARY placement only. Define which accepted placement states/effective intervals, including future-dated accepted placements, count against class/section capacity; atomically check both aggregates with override evidence under promotion/transfer concurrency. Admissions owns provisional application, waitlist and any later approved seat reservation. |
| B2-02 | Select cross-command lock order/isolation/retry for Student ID, later Admissions number handoff, roll, active PRIMARY enrollment, both capacity limits and concurrent promotion/transfer. Never `MAX()+1` or read-then-write count. |
| B2-03 | Define roll namespace/collision rule for academic-context versus persistent-student mode, NULL-context uniqueness in counter, policy change/migration behavior, persistent-origin/correction invariants and exactly one current allocation per active placement. Numeric is authority, display is derived. |
| B2-04 | Specify no-overlap enforcement for one active PRIMARY placement per Student, its effective intervals and predecessor chain; do not assume a current-row partial unique index alone protects backdated overlaps. |
| B2-05 | Specify one class teacher per section/time; normally one PRIMARY Subject teacher per Subject+section/time; CO_TEACHER and SUBSTITUTE overlap/coverage, mandatory bounded substitute interval and race-safe end/replacement. |
| B2-06 | Specify family relationship versus principal-membership/child-access/primary-display interval checks and revocation ordering; primary context's selected relationship interval must contain its context interval. A simultaneous read/revoke must not continue to authorize revoked child access. Preserve the checked immutable `principal_kind = 'FAMILY'` and composite Foundation FK even for privileged fixture DML. |
| B2-07 | Make assignment eligibility race-safe against Employee ACTIVE interval, teacher capability interval, section/year bounds and campus ancestry; an ended capability cannot leave current action authority. |
| B2-08 | Specify D1 ancestry structural validation against frozen `app.campuses` and `app.rooms` without assuming unavailable composite keys or altering Foundation. Include class/year same-school consistency and room/section same-campus proof. |
| B2-09 | Specify Student restricted-identity and special-detail HE snapshot non-overlap, one-way close, same-Student successor lineage and current/historical resolution. Sensitive values remain only in narrow private snapshots, never broad audit/outbox JSON. |
| B2-10 | Specify Employee restricted-identity HE snapshot non-overlap/current resolution; qualification and external-experience lineage, correction/archive uniqueness and experience date validity. Keep original joining/rehire derivable from this-school employment periods. |

## Can be selected in D1B2

- Exact positive/zero capacity constraint (D1B1 proposes `integer NOT NULL` and zero as closed intake), count query shape, and historical capacity revision sequencing, while retaining both required limits.
- Temporal mechanism: exclusion constraints if a reviewed extension/key supports them, serialized protected checks, or another demonstrably safe implementation. Choose matching indexes from observed roster/history/family/assignment queries rather than broad speculative GIN.
- Candidate UQ redundancies and composite-FK supporting keys on **D1** tables only. `academic_years(id,school_id)` exists; frozen campus/room keys are not presumed.
- Student/Employee current-state projection synchronization and correction ordering. D1B1 chooses controlled projections; events/spells remain source of truth.
- Section room effective-assignment overlap and correction sequencing; no timetable model.
- Initial roll/Student ID counter setup and replay semantics, subject to approved ownership and the later Admissions allocation handoff.

## Can be deferred to D1B3 security/command design

- Exact action/permission codes, operation contracts, worker/definer ownership, search paths, EXECUTE ceilings, RLS/read projection definitions and direct-client denial tests. All D1 base tables stay `app_private` and no anonymous access is proposed.
- ROSTER/PROFILE/RESTRICTED IDENTITY/SENSITIVE-SPECIAL projections and narrow Employee HR/OWN identity/history projections. Physical HE snapshot history is now selected; D1B3 must prevent raw identity/special values from entering broad audit/outbox content.
- Typed approval hooks for sensitive corrections/status/transfer/assignment changes, with capacity override **not** needing approval solely because of fullness. Foundation audit, outbox and receipts remain the shared engines.
- FAMILY principal ACTIVE/current-binding/complete-grant/interval runtime checks beyond the structural discriminator, emergency-contact non-escalation, Employee affiliation/designation/qualification non-escalation, historical read policies and self/ASSIGNED scope contracts.
- File-purpose/entitlement/checked link validation for nullable Student/Employee file references; no D1-22 purpose activation from schema existence.

## Can be deferred to D1C SQL implementation

- Final migration grouping/timestamps, SQL syntax, constraint/trigger/function names and privileges, extension availability, exact indexes after D1B2 review, and seeded permission/operation/event code registration after D1B3.
- Exact Student ID public formatting; `students.school_student_id text` is permanent and server allocated, distinct from `students.id` and child-table `student_id` UUID FKs, but a public prefix is not invented by D1B1.
- Managed/local fresh rebuild and upgrade execution, executable pgTAP 10+, non-owner positive/negative RLS and concurrent race tests. This D1B1 task creates **no** executable test.
- Reproducible Admissions allocator integration when the later Admissions package exists. No fabricated D1 Admissions table, no Student creation activation before a verified final number/serial is supplied.

## Later domain package

Full Admissions application/stages, provisional decision/waitlist/seat reservation if later approved, and its number reservation implementation; curriculum composition/versions, elective selections and assessment rules; timetable, attendance, learning, exams/results; Finance, employment contracts/contract compensation, salary/payroll/leave, Employee attendance and performance management, general HR documents, medical, transport, hostel/library; custody/court-order/pickup workflows; provider upload-purpose activation; notification delivery, AI/search and full offline protocol. D1 stores only approved identity/history anchors needed by these packages.

## Pass boundary

The catalog proposes **34 new D1 relations**: zero in `app`, 34 in `app_private`. All approved concepts have an explicit physical home; there are zero new D1-to-D1 inter-table FK cycles or late FKs among those new relation creations. D1B3A additionally plans a cross-boundary authorization ALTER and three FKs on **one existing Foundation relation** after its D1 targets exist; this does not change the 34 count. Frozen Foundation SQL remains untouched. D1B1–D1B3B are **not** release, deployment, SQL or migration authorization. D1C SQL drafting and migration 10 require separate authorization.
