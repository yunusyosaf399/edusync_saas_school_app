# Effect 19 security re-freeze

Status: FROZEN at trusted implementation SHA `ea1754da142a70fb8a6ceceeffae6f9256305cb4`.

This record closes the pending security status for `employee.qualification.change` after exact-SHA CI, post-push packaging correction, and final static review.

Security properties revalidated:
- mutation remains protected-command only; authenticated callers receive no direct DML on `app_private.employee_qualifications`;
- requester/reviewer same-Person separation remains mandatory for APPROVAL routing;
- final reviewers must retain the configured reviewer role and current operation-specific review scope;
- multi-campus Employees cannot select an easier route: all current-campus policy resolutions must converge to one policy-version ID;
- terminal apply replay rechecks current participant/final-review authority and does not create mutation authority;
- deterministic stale policy, authority, target-version, lineage and qualification-preflight conditions invalidate without domain mutation;
- malformed protected workflow facts fail closed and unclassified failures roll back;
- CORRECT is restricted to the current open lineage head and appends a successor; ARCHIVE only closes the open head;
- executor packaging is explicit: effect fragments no longer inherit the preceding executor role across the apply boundary;
- `schoolos_employee_executor` receives only the School-anchor privileges needed for the frozen lock sequence;
- the public apply RPC is owned by `schoolos_workflow_executor` after assembly;
- application evidence binds the request and result without becoming an authorization source;
- outbox aggregation is `EMPLOYEE_QUALIFICATION` / resulting qualification snapshot UUID / version 1 with minimized payload;
- catalog counts remain 97 permissions / 322 scope alternatives / 36 operations.

GitHub Actions run #46 (`37035244526`) completed SUCCESS on exact SHA `ea1754da142a70fb8a6ceceeffae6f9256305cb4`: 121/121 tooling tests and 220/220 Foundation assertions passed, with source/config/reset/auth-fixture/lint gates also passing.

Migration 10 and all effect-19 continuations remain `.sql.draft`; D1C2 and remote/staging execution remain unauthorized.
