# Effect 18/36 formal freeze record

Status: FROZEN.

Trusted implementation SHA: `ce26409ce24958a539945003cd3690b45b9926b3`.

Operation: `employee.identity.correct` with review permission `employee.identity.approve`.

This freeze supersedes the earlier pending-candidate status in the effect-18 implementation/security review notes. The trusted package includes ordered continuations 01 through 11, including the final-approver participant correction and terminal-replay correction discovered during independent audit.

## Frozen semantics

- mandatory P2 submit -> review -> explicit apply;
- first Restricted Identity snapshot is allowed;
- accepted effective instant is server apply-time;
- reviewed CLEAR appends a null/null successor and never deletes history;
- exact no-op corrections are denied;
- only the current open lineage head may be corrected;
- mutation authority is ALL or matching current CAMPUS EA authority, with no OWN/self-resolver mutation path;
- reviewer requires `employee.identity.approve`, configured reviewer role, live scope, and requester/reviewer Person separation;
- multi-campus policy selection resolves campus-over-school precedence for every current campus and requires all resolutions to converge to one policy-version ID;
- lock order remains Foundation authorization/idempotency/principal -> Employee -> Restricted Identity history;
- malformed protected workflow facts fail closed;
- deterministic stale policy/authority/history conditions invalidate without domain mutation; unclassified failures roll back;
- successful application evidence is bound to the EXECUTED request, successful apply receipt, Employee version, predecessor closure, successor lineage, requested values, and accepted instant;
- broad receipts, audit and outbox evidence never carry raw identity numbers;
- `employee.identity_corrected` publishes aggregate kind `EMPLOYEE_IDENTITY`, aggregate ref = new identity snapshot UUID, aggregate version `1`;
- catalog counts remain 97 permissions / 322 scope alternatives / 36 operations.

## Cross-effect approval correction included in the trusted SHA

The final-approver participant correction applies to Student/Employee Profile, Employee State, Employee Job Assignment, Employee Campus Affiliation, Teacher Capability, Class Teacher Assignment, Subject Teacher Assignment and Employee Restricted Identity.

The correction is workflow-classification only: it removes row-order dependence when the same authorized reviewer legitimately decided multiple sequential stages, and it preserves current-authority-gated terminal apply replay after EXECUTED/INVALIDATED. It does not change domain mutation semantics, reviewer Person separation, permission/scope catalog entries, lock order or approval state-machine semantics.

## Validation evidence

GitHub Actions run #44, run ID `37001888766`, executed against exact SHA `ce26409ce24958a539945003cd3690b45b9926b3` and completed SUCCESS.

Verified log evidence:
- checkout SHA: `ce26409ce24958a539945003cd3690b45b9926b3`;
- tooling: 121/121 tests passed;
- Foundation source: 9 frozen migrations + 9 tests passed;
- local config and CLI pin passed;
- local reset: nine frozen migrations, no seed;
- auth fixtures: 5/5;
- lint error/warning gates passed;
- pgTAP suites: 44 + 6 + 16 + 16 + 25 + 16 + 33 + 41 + 23 = 220/220 passed;
- final marker: `FOUNDATION_LOCAL_CI_PASS 9 files / 220 planned / 220 passed; serial execution`.

Final exact-SHA static review found no remaining blocker in identity lineage, CLEAR behavior, safe evidence boundaries, policy convergence, final-approver classification, terminal replay, authority rechecks, application binding, event aggregation, or privilege exposure.

Migration 10 and all effect continuations remain non-executable `.sql.draft` material. D1C2 and remote/staging execution remain unauthorized.
