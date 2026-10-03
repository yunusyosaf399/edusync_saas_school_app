# D1C1B Effect 28/36 — Student Emergency Contact Freeze

**Status: FROZEN.**

Trusted runtime SHA: `a2d725b4bddbd4df1d891f10c091e0547dbaf20d`.

Exact-SHA GitHub Actions run #142 (`37134286751`) completed successfully on that SHA. The workflow confirms successful Tooling unit tests, Frozen Foundation integrity, and Clean local Foundation validation.

## Frozen operation

`student.emergency_contact.change`

Routing: **P1 POLICY_REVIEWED** — deployment policy selects DIRECT or APPROVAL; missing/ambiguous/incompatible policy denies.

Reviewer permission when APPROVAL applies: `student.emergency_contact.approve`.

Frozen actions:

- `ADD` — create a new independent contact lineage.
- `END` — close the selected open lineage head, no successor.
- `CORRECT` — close the selected open lineage head and append a same-lineage successor.

## Frozen semantics

- Multiple distinct Emergency Contacts may coexist for one Student.
- Existing-Person and standalone contact forms are supported; a Person association grants no Family/access/guardian authority.
- Contact history is retained; no destructive delete or ordinary historical overwrite is permitted.
- CORRECT must change a factual contact value; reason-only correction is rejected.
- Source chronology/open-head validity and duplicate identity are protected under Student serialization.
- Authorization is resolved from current Student context, not from the Emergency Contact row itself.
- DIRECT and APPROVAL share the same typed domain effect and validation contract.
- APPROVAL uses submit -> review -> explicit apply; review does not auto-apply.
- Current requester/reviewer authority is rechecked where required, with deterministic approved-request invalidation for stale business conditions.
- Successful domain effects emit `student.emergency_contact_changed` only.
- Broad audit/outbox evidence excludes contact name, relationship text, phone, email, and arbitrary reason text.
- Emergency Contact facts never create Family membership, Family child access, guardian Principal authority, pickup/custody authority, or Foundation roles/grants/scopes.

## Freeze corrections included

The frozen runtime SHA includes both independent-audit corrections:

1. `f03767cac118a6547733850ba8dcbd9ba21ab7e5` — bind the private reason to DIRECT/request.submit canonical intent so a reused idempotency key with changed reason conflicts.
2. `a2d725b4bddbd4df1d891f10c091e0547dbaf20d` — preserve durable replay of successful retained-history results after later legitimate lineage evolution while still proving exact receipt/result lineage facts.

## Boundary

The runtime delta from Effect-27 freeze baseline `907d35e757b79acfb5dc68702ad3456958f46321` consists only of Effect-28 `.sql.draft` continuations. The manifest remains **97 permissions / 322 scope alternatives / 36 operation contracts**.

Migration 10 remains `.sql.draft` and unexecuted. D1C2, staging application, managed Supabase application, worker activation, and Effect-29 implementation are not authorized by this freeze.

**`DOMAIN PACKAGE D1C1B EFFECT 28/36 FROZEN — STUDENT.EMERGENCY_CONTACT.CHANGE ACCEPTED`**
