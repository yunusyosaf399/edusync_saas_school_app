# 03 - Foundation Dependency Order

**Status:** PROPOSED design and future migration sequence, 2026-09-22. Names below are planning labels only; no SQL files, seeds, extensions or Supabase configuration are created.
**Authority:** [AGENTS.md](../../AGENTS.md), [database design plan](DATABASE_DESIGN_NEXT_PHASE.md), [entity map](02_foundation_entity_map.md), [conventions](01_database_conventions.md).

## 1. Design first, implementation later

Complete conceptual review before physical design: isolation/identity -> grant and scope semantics -> school anchors -> workflow/audit/event contracts -> relationships/constraints -> RLS/command boundaries -> tests and recovery. Confirm proposals and resolve blocking items in [ADR-001](../decisions/ADR-001-foundation-database-principles.md).

The sequence below is exact for this proposal, but conditional choices such as login alias storage and exposed schema must be settled before producing migration drafts. It is not a claim that every proposed entity must become one table or migration.

## 2. Rules applying to every future stage

- Explicitly restrict privileges and enable default-deny RLS for every exposed sensitive relation at creation. RLS is not postponed until the last migration. Detailed policies become available after their dependencies exist.
- Do not expose partially built foundations. Keep operational account activation and external worker execution closed until the complete release is validated.
- FKs to actors require the stable principal first. Record a one-time bootstrap SYSTEM principal with explicit origin; it cannot authorize interactive users. The bootstrap creation is evidenced by deployment records, then by the audit foundation.
- Add forward/circular references only when both endpoints exist; validate them before exposure. No long-lived unvalidated target strings stand in for domain FKs.
- Existing applied migrations are never rewritten in place. Rehearse new-project rebuild and upgrades; prefer a reviewed forward repair once real history exists. Destructive down migrations are not a recovery strategy.
- Each migration is atomic where supported. Any platform operation that cannot be transactional needs a documented checkpoint and recovery procedure.
- No extension is assumed necessary. Check the target PostgreSQL/Supabase version and installed capabilities; approve an extension only for a demonstrated requirement (T02).

## 3. Ordered stages and dependencies

| Stage / proposed future batch | Depends on | Contents and reason for position | Downstream / separate migration? | Recovery consideration |
|---|---|---|---|---|
| 1 / 0001_platform_baseline | Accepted runtime/schema decisions | Schema ownership, restricted grants, chosen types and side-effect-free UUID/time/validation helpers; extensions only if justified | Everything; yes | Empty-project rebuild; never blindly remove a shared platform extension |
| 2 / 0002_people_and_principals | 1 and managed Auth primary key contract | F05 Person, F06 principal/account profile, F07 binding history, conditional F08 alias; restricted bootstrap actor | Audit and all actor FKs; yes | Roll back new empty structures only; once referenced, retire/relink credentials without cascading history loss |
| 3 / 0003_audit_core | 2 | F19 event and restricted append/read interfaces; no campus/approval FKs until their stages | All later sensitive writes; yes | Preserve evidence on upgrade; failed audit setup prevents activation |
| 4 / 0004_school_academic_anchors | 2-3 | F01 school, F02 campuses, F03 rooms, F04 academic years; add audit campus FK | Scope, policies, metadata; yes | Restrict parent deletion; restore/correct settings rather than deleting historical years |
| 5 / 0005_versioned_configuration | 4 and actors/audit | F24 setting revisions; add school's optional default-year reference after year exists | Workflow/notification configuration; yes | Reinstate a prior setting through a new version, retaining old versions |
| 6 / 0006_permission_and_scope_model | 2, 4, 3 | F09 roles, F10 permission registry, F11 grants, F12 assignments, F13 typed scope bindings; enforce matching roles | Authorization helpers and all operations; yes | Revoke/end incorrect grants with history; do not rewrite effective past authority |
| 7 / 0007_authorization_kernel | 6, 5, current principal state | Verified context resolution, current-grant checks, delegation ceilings and supported scope resolvers; initial protected administration interfaces | Workflow/file/notification policies; yes | Keep fail-closed behavior if replacement fails; test function/view privilege boundaries and recursion |
| 8 / 0008_private_file_metadata | 4, 7, 3 | F23 upload metadata; private access contract. Logo FK can now be added. Actual bucket policies follow chosen configuration | Request evidence and document links; yes | Do not automatically delete object bytes on metadata rollback; reconcile pending/orphan objects |
| 9 / 0009_command_receipts | 2, 7, 3 | F25 idempotency identity/hash/result infrastructure, before workflow application | F18/F26 and later domain commands; yes | Preserve durable operation keys/results; no retry-cache expiry that permits duplicate irreversible effects |
| 10 / 0010_workflow_core | 4-9 | F14 definition versions, F15 templates, F16 requests, F17 steps, F18 reviews, F26 transitions; add request/evidence links and audit/receipt optional request FKs | Protected domain commands, event types; yes | Active policies/requests retain versions; do not drop history or reinterpret approved payloads |
| 11 / 0011_domain_outbox | 2-4, 9-10 | F20 immutable event envelopes and F21 consumer delivery; validate registered payload types and lease/dedupe contracts | Notifications and later automation; yes | Preserve event identity and consumer checkpoints; replay without reapplying business commands |
| 12 / 0012_notification_foundation | 2, 5, 7, 11 | F22 inbox/context, F27 preferences, F28 channel-delivery contract; only validated recipient interfaces | Notification workers; yes | Keep recipient/read history; reconcile sent-but-unacknowledged delivery rather than claiming exactly once |
| 13 / 0013_foundation_command_integration | 3-12 | Join protected foundation mutations, audit, receipts and outbox atomically; install validation/history hooks and supported command interfaces | End-to-end foundation verification; yes | Revert execution path only through a compatible forward repair; no dropping evidence |
| 14 / 0014_access_policy_completion | 7-13 | Complete per-surface RLS/grants, restricted functions/views and chosen private-storage policies; field/context restrictions verified | Activation after test/seed stages; yes | Default deny remains the fallback; no temporary public/ALL policy to repair access |
| 15 / approved seed and bootstrap procedure | 1-14 and accepted default catalog | Repeatable reviewed permissions/roles/settings, workflow definitions only for implemented handlers, initial school/operator provisioning | Acceptance tests and activation; separate seed/provisioning material, not a migration filename | Deterministic lookup/upsert behavior must not overwrite school customizations or restore revoked grants |
| 16 / release verification | Every stage plus synthetic fixtures | Fresh rebuild, prior-version upgrade, constraints/RLS, audit, concurrency and recovery checks; tests are designed before stage 1 and run throughout | Release activation; separate executable tests later | Failed checks block deployment/activation; preserve diagnosis and restore validated prior state |
| 17 / controlled activation | Passed verification and bootstrap evidence | Enable intended accounts/workers only with all grants, context proof and providers ready | Operational use; deployment step, not a migration | Suspend entry points first on failure; preserve history and queued facts; replay after repair |

The ordering numbers are conceptual prefixes. Final Supabase-compatible naming, including timestamp/version conventions if selected, is T02. No .sql file has been generated.

## 4. Resolving cycles and unsafe shortcuts

**Principal and audit:** the private bootstrap principal is the explicit origin of deployment actions. Later principals and all business-facing changes require audit. Do not make created_by on the first bootstrap record depend on a nonexistent person/login; use a documented self/system bootstrap origin and deployment evidence.

**Audit and workflow:** F19 is available early with a restricted append contract. Its optional approval reference is introduced and validated at stage 10. A protected business operation cannot run in the interval with missing workflow enforcement because operational activation is closed.

**School and default year/logo:** F01 does not initially require a default-year or logo object. Add and validate references after F04/F23. Changing the current year does not change any old record.

**Authorization and RLS recursion:** helper routines reading grant tables must not recursively invoke the same policies. PROPOSED solution is a narrow internal evaluator with explicitly controlled privileges and search path, not broad security-definer access or a service-key shortcut. Exact namespace/runtime mechanism is T04.

**Outbox and commands:** the complete command/audit/outbox transaction contract is connected after its dependencies exist. Early structural migrations and bootstrap records use the available restricted audit/deployment path; no production domain operation is exposed before integration.

**Future typed targets:** Foundation workflow cannot mutate a nonexistent Attendance/Finance/Student domain. Later domain migrations add real target/result/evidence links, validators and policies before enabling their operation codes. Deferred CLASS/SECTION/SUBJECT/family resolvers deny access until supplied.

**Auth, Storage and database operations:** these services do not share an assumed single transaction. Use pending states, idempotent reconciliation and explicit ownership checks; never delete an object/credential merely because a schema step failed.

## 5. Proposed future sequence at a glance

0001_platform_baseline
0002_people_and_principals
0003_audit_core
0004_school_academic_anchors
0005_versioned_configuration
0006_permission_and_scope_model
0007_authorization_kernel
0008_private_file_metadata
0009_command_receipts
0010_workflow_core
0011_domain_outbox
0012_notification_foundation
0013_foundation_command_integration
0014_access_policy_completion

Approved seed/provisioning, test execution and controlled activation are separate steps. Do not populate speculative business records or broad role grants merely to make the schema runnable.

## 6. Exit criteria and next task

Accept or revise the proposal; resolve implementation-blocking T01-T07 and relevant T08/T10-T12 decisions. Produce a reviewed relationship diagram, concrete FK/constraint/RLS matrix, tested command contracts and reversible deployment plan before applying anything.

**Recommended next task: "Foundation ERD and SQL Migration Draft".** That task is a draft/review activity, not authorization to apply migrations. It has not been started here. Full academic/student/employee domain design follows foundation validation.
