# D1C1B effect 20/36 — Employee experience security review

Status: implementation candidate; pending exact-SHA CI and independent review.

Effect 20 implements `employee.experience.change` from frozen effect-19 head without adding permissions, scope alternatives, operations, role grants, principal assignments or direct authenticated table DML.

Security properties selected for review:

- Mutation uses only exact `employee.experience.change` through complete Foundation grants and frozen Employee ALL/CAMPUS scope alternatives.
- Approval uses only exact `employee.experience.approve`, configured reviewer role and current complete scope over the affected Employee.
- Multiple current Employee campuses cannot be used to pick an easier route; all resolutions must converge. No-current-campus Employees require ALL authority plus the school policy.
- Requester/reviewer same-Person separation is enforced in candidate selection and live-review validation.
- Apply rechecks requester authority, every completed reviewer authority and current route/policy before domain mutation.
- Terminal replay is participant/current-authority gated and is served from durable receipt evidence without re-running the mutation.
- Malformed stored UUID/date/request facts raise and roll back rather than being converted into a deterministic invalidation.
- Experience history does not create teaching, Subject, Department, Campus or role authority and does not depend on Employee ACTIVE state.
- Only one-way end-marker columns are updateable by the Employee executor; all experience facts are append/correct lineage data.
- Broad evidence excludes organization names, role titles, professional summaries and arbitrary reasons. Typed request read exposes those facts only to a current authorized workflow participant.
- Outbox uses `employee.experience_changed`, aggregate `EMPLOYEE_EXPERIENCE`, aggregate ref = resulting snapshot UUID, version 1.
- The application guard cross-binds request, operation, successful apply receipt, target version, Employee target, result snapshot and stable lineage.
- Public RPCs revoke PUBLIC/anon/service_role and grant only authenticated; internal helpers are restricted to dedicated executors.

The candidate intentionally reuses the hardened effect-19 P1 architecture but has separate operation-specific helpers, payload shapes, receipts and evidence. Qualification text or experience text is never used as an authorization resolver.

Migration 10 and all effect-20 continuations remain `.sql.draft`; D1C2 and remote/staging execution remain unauthorized.
