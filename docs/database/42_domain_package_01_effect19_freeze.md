# Effect 19/36 formal freeze record

Status: FROZEN.

Trusted implementation SHA: `ea1754da142a70fb8a6ceceeffae6f9256305cb4`.

Operation: `employee.qualification.change` with review permission `employee.qualification.approve`.

This freeze supersedes the pending candidate status from the effect-19 implementation, security, and packaging-correction review notes. The trusted package includes ordered effect-19 continuations 01 through 08, including the role-reset and executor-ownership correction discovered during post-push audit.

## Frozen semantics

- supported actions are ADD, CORRECT, and ARCHIVE;
- P1 routing permits DIRECT or APPROVAL according to the converged current policy;
- multi-campus Employees must resolve all current-campus policy routes to one policy-version ID before approval routing is accepted;
- reviewer authorization requires `employee.qualification.approve`, the configured reviewer role, current matching scope, and requester/reviewer same-Person separation;
- ADD creates a new open qualification lineage head;
- CORRECT may only target the current open lineage head, closes that head, and appends one successor carrying a stable server lineage key;
- ARCHIVE only closes the current open lineage head and appends no successor;
- exact no-op corrections are denied;
- award-date and qualification payload validation remain protected command concerns; client time does not become accepted apply time;
- employment ACTIVE state is not required merely to maintain retained HR qualification history;
- lock order is Foundation authorization/idempotency/principal -> School -> Employee -> qualification history;
- deterministic stale policy, authority, target-version, lineage, or qualification-preflight conditions invalidate an approved request without domain mutation; malformed protected workflow facts fail closed and unclassified failures roll back;
- terminal apply replay occurs before mutation preflight and retains current participant/final-review authority checks;
- successful application evidence binds the request, apply receipt, expected/resulting Employee version, source qualification where applicable, resulting qualification snapshot, and action;
- broad receipt, audit, application and outbox payloads are minimized to qualification workflow facts and do not create a new authority source;
- `employee.qualification_changed` publishes aggregate kind `EMPLOYEE_QUALIFICATION`, aggregate ref = resulting qualification snapshot UUID, aggregate version `1`;
- ADD/CORRECT publish the created resulting snapshot; ARCHIVE publishes the closed snapshot;
- no authenticated caller receives direct DML on `app_private.employee_qualifications`;
- catalog counts remain 97 permissions / 322 scope alternatives / 36 operations.

## Packaging correction included in the trusted SHA

The post-push audit identified that ordered continuations 05 through 07 could inherit an unintended executor role from the preceding fragment. The trusted SHA adds a role-reset continuation before apply/read assembly and a final owner/ACL continuation.

The correction also grants `schoolos_employee_executor` only the School-anchor privileges required by the frozen School -> Employee -> qualification-history locking sequence and transfers the public apply RPC to `schoolos_workflow_executor`. It changes no domain semantics, policy routing, reviewer separation, catalog counts, or migration manifest.

## Validation evidence

GitHub Actions run #46, run ID `37035244526`, executed against exact SHA `ea1754da142a70fb8a6ceceeffae6f9256305cb4` and completed SUCCESS.

Verified log evidence:
- checkout SHA: `ea1754da142a70fb8a6ceceeffae6f9256305cb4`;
- tooling: 121/121 tests passed;
- Foundation source: 9 frozen migrations + 9 tests passed;
- local config and Supabase CLI pin 2.98.2 passed;
- Docker Linux gate passed and local stack started/stopped cleanly;
- local reset: nine frozen migrations, no seed;
- auth fixtures: 5/5;
- lint error and warning gates passed;
- pgTAP suites: 44 + 6 + 16 + 16 + 25 + 16 + 33 + 41 + 23 = 220/220 passed;
- final marker: `FOUNDATION_LOCAL_CI_PASS 9 files / 220 planned / 220 passed; serial execution`.

Final exact-SHA review found no remaining blocker in qualification lineage semantics, P1 policy convergence, reviewer/current-authority checks, terminal replay, deterministic invalidation, application evidence, outbox aggregation, executor ownership, or privilege exposure.

Migration 10 and all effect-19 continuations remain non-executable `.sql.draft` material. D1C2 and remote/staging execution remain unauthorized.
