# Domain Package 01 — Effect 19 Employee Qualification SQL Review

**Status:** EFFECT 19/36 IMPLEMENTATION CANDIDATE — INDEPENDENT REVIEW / CI REQUIRED — NOT FROZEN.

**Source HEAD:** `53130caa90383013055a2a5161b48bd4db2d2272` (effect 18 frozen baseline).

## Scope

This candidate implements only `employee.qualification.change` using the already-frozen D1 permission/operation manifests. It does not change the 97 permissions, 322 permission/scope alternatives, or 36 operation contracts. Migration 10 remains non-executable `.sql.draft`; D1C2 and remote/staging application remain unauthorized.

Seven ordered draft continuations implement:

1. ALL/CAMPUS Employee qualification change/approve authorization and multi-campus P1 route convergence;
2. retained-history ADD/CORRECT/ARCHIVE validation, School → Employee → qualification-history serialization, and one shared domain effect;
3. fixed-shape canonical command receipts plus minimized audit/outbox evidence;
4. reviewer candidate selection and DIRECT protected RPC;
5. APPROVAL submit;
6. APPROVAL review with current operation/policy/role/scope revalidation;
7. all-review current-authority revalidation, participant classification, explicit apply, deterministic invalidation, bounded checked request read, and approval-application receipt/history guard.

## Approved semantics represented

- ADD creates a server-generated stable `qualification_record_id` lineage and a new current snapshot.
- CORRECT only replaces an open lineage head, closes it at server apply-time, and appends a successor under the same lineage.
- ARCHIVE only closes the open head and creates no successor; an archived lineage is never reopened.
- Effective acceptance time is server apply-time. `awarded_on`, when supplied, cannot be later than apply date.
- Multiple independent qualification lineages may coexist for one Employee.
- A correction that changes no qualification fact is denied; reason-only change is not a qualification correction.
- Employee ACTIVE state is not required merely to maintain retained HR qualification history.
- Qualification type/title/institution/specialization are facts only and never create authority.

## P1 authorization and workflow

`employee.qualification.change` and `employee.qualification.approve` use the frozen Employee-action ALL/CAMPUS family. An ALL grant satisfies the target globally. Otherwise every current Employee campus must be covered by a complete matching CAMPUS grant. An Employee with no current campus therefore requires ALL.

Routing is derived server-side across every current Employee campus. Missing/ambiguous policy, conflicting DIRECT/APPROVAL route, or non-convergent APPROVAL policy denies. The client cannot choose a campus or easier approval path.

APPROVAL uses submit → review → explicit apply. Requester/reviewer Person separation is mandatory. Apply rechecks the requester plus every completed approval step's current reviewer role and `employee.qualification.approve` scope. Deterministic policy/authority/version/lineage/preflight staleness converts APPROVED → INVALIDATED with a rejected apply receipt and no domain mutation/application/event. Corrupt stored request payload fails closed and rolls back rather than becoming a workflow mutation.

Terminal apply replay is evaluated before mutation preflight and requires a current authorized requester or exact current final approver; it returns retained durable evidence without re-closing the predecessor or duplicating history/evidence.

## Evidence/privacy

Successful effects emit only `employee.qualification_changed`. Retained-history outbox aggregation uses the resulting/closed qualification snapshot as the aggregate at version 1. Broad receipt/audit/outbox evidence contains only bounded identifiers/action/version/correlation facts; title, institution, specialization and raw reason text are not copied into broad evidence.

The checked request read is purpose-bound to current request participants and may disclose the structured old/proposed qualification fields required for review. It does not expose generic request JSON, Foundation grant/role internals, or the private reason.

## Static review observations

During construction, three issues were caught before commit: the canonical direct/submit intent shape was corrected from 12 to 11 fields; requester-triggered apply was separated from final-approver resolution so valid requester apply does not self-invalidate; and outbox aggregation was corrected to the retained qualification snapshot at version 1 rather than the parent Employee version.

The candidate intentionally does not edit Foundation migrations/tests, Supabase config, Flutter, deployment tooling, or executable D1 tests. No SQL was executed and no remote Supabase operation was performed as part of this implementation.

**Next gate:** push exact candidate → repository CI/source validation → independent exact-SHA audit → correction if required → formal effect-19 freeze only after PASS.
