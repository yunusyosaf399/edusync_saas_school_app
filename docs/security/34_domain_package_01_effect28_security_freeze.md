# D1C1B Effect 28/36 — Student Emergency Contact Security Freeze

**Status: FROZEN.**

Trusted runtime SHA: `a2d725b4bddbd4df1d891f10c091e0547dbaf20d`.

Exact-SHA GitHub Actions run #142 (`37134286751`) completed successfully on that SHA. Independent security review accepts the runtime only after the canonical-reason and retained-history-replay corrections were included and retested.

## Frozen security contract

- `student.emergency_contact.change` is the only business change permission for ADD/END/CORRECT.
- P1 review, when configured, requires `student.emergency_contact.approve`, the configured reviewer role, exact workflow step, matching current Student scope, and requester/reviewer separation.
- Verified Principal is derived server-side; the client supplies no actor, grant list, resolver key, or arbitrary permission.
- Foundation authorization lock `(71001,1)` is SHARED for the D1 business path; Foundation grant/scope administration remains outside this command.
- Student serialization occurs before final current Student-scope authorization on the hardened paths.
- Emergency Contact existence, record ownership, associated Person, or creator identity never creates application authority.
- Existing Person linkage never creates Family/guardian/pickup/custody authority.
- Authenticated users receive no direct D1 base-table DML.

## Frozen privacy contract

Contact name, relationship label, phone, email, and arbitrary reason text are excluded from broad audit/outbox payloads. `student.emergency_contact_changed` carries only allowlisted identifier/action evidence. Purpose-bound protected request/read/apply surfaces may use the exact sensitive values required to review and prove the operation.

## Frozen idempotency contract

DIRECT and request.submit canonical intent includes the private reason as well as Student/version/action/source/proposed-contact/date facts. Same key + changed reason or other changed intent conflicts.

A successful retained-history receipt remains replayable after later legitimate END/CORRECT evolution by proving its retained summary and immutable lineage facts. Replay does not require the old ADD/CORRECT result row to remain current/open forever.

## Boundary

No permission, scope alternative, role-template grant, Principal assignment, or operation contract is added. Manifest remains **97 / 322 / 36**.

Migration 10 remains non-executable `.sql.draft`; no D1C2 or remote/staging execution is authorized.

**`DOMAIN PACKAGE D1C1B EFFECT 28/36 SECURITY FROZEN`**
