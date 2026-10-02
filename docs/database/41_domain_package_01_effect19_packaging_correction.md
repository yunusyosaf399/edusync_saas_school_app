# Domain Package 01 — Effect 19 Packaging Correction Review

**Status:** CORRECTIVE CANDIDATE — EFFECT 19/36 STILL NOT FROZEN.

**Base candidate:** `80e90cec216f47a2e532fba61211ca4e9bca6001`.

The post-push independent assembly audit found two SQL packaging/ACL defects that the source-only Foundation workflow does not prove:

1. effect-19 fragments 05 and 06 intentionally entered `schoolos_workflow_executor` but did not restore the outer migration role before fragment 07. A clean ordered assembly could therefore attempt fragment-07 authorization-reader grants while still executing as the workflow executor.
2. fragment 07 creates `app.d1_apply_employee_qualification_request(uuid,bigint,text)` after its authorization-reader section has reset to the outer migration role. Without an explicit final ownership transfer, the apply RPC would not be owned by the reviewed `schoolos_workflow_executor`.

The same audit also checked the frozen School → Employee → qualification-history lock hierarchy. `d1_employee_qualification_lock_context` uses `SELECT ... FOR UPDATE` on `app_private.school_profiles`; effect 19 therefore supplies the narrow `SELECT(id), UPDATE(id)` lock privilege to `schoolos_employee_executor`, matching the D1 executor-lock pattern rather than granting broad School mutation authority.

## Correction

Two ordered non-executable continuations are added:

- `effect19_06a_role_reset.sql.draft` restores the outer migration role immediately after the review fragment and revokes the temporary workflow-executor CREATE edge on `app`.
- `effect19_08_qualification_owner_acl.sql.draft` grants only the School-anchor lock columns to the employee executor and, from the outer migration owner, transfers the apply RPC to `schoolos_workflow_executor` while preserving the exact authenticated EXECUTE boundary.

No effect-19 product semantics, permission/scope catalog, route policy, history behavior, event vocabulary, disclosure, or workflow decisions are changed. The 97 / 322 / 36 manifest remains untouched. Migration 10 remains `.sql.draft` and unexecuted.

After this correction the ordered effect-19 package contains nine SQL continuations. Exact-SHA CI plus a final independent audit remain required before freeze.
