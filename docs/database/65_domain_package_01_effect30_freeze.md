# D1C1B Effect 30/36 — Family Relationship Freeze

**Status: FROZEN.**

Trusted runtime SHA: `3ae3bc65efb2e5f2d45c05b36d9c094f0d7c22e7`.

Exact-SHA GitHub Actions run #173 (`37140015253`) completed successfully on that SHA. Full log inspection confirms exact checkout, 121/121 tooling unit tests, frozen Foundation integrity, Supabase CLI 2.98.2, clean local reset of nine frozen migrations with no seed, 5/5 Auth fixtures, lint gates, and 220/220 Foundation TAP assertions.

## Frozen operation

`family.relationship.change`

Routing: **P1 DIRECT or APPROVAL according to the effective approval policy**.

Frozen actions:

- `ADD` — append one new open Family relationship for the Student and ACTIVE Family.
- `END` — end one retained open relationship at the accepted effective date.
- `CORRECT` — end the selected source and append a corrected relationship linked by `supersedes_id`.

## Frozen semantics

- Relationship existence grants no command authority.
- Authorization follows the exact interval-effective Student context. ALL or matching CAMPUS/CLASS/SECTION authority may satisfy `family.relationship.change` according to the frozen scope alternatives.
- APPROVAL review requires live `family.access.approve`, the configured reviewer role, and matching affected Student scope.
- Requester and reviewer must be distinct people, not merely distinct Principal UUIDs.
- Review never auto-applies; approved application is explicit and rechecks live policy, requester/reviewer authority, versions, ancestry, and domain preflight.
- Stale approved business state is invalidated deterministically rather than applied.
- ADD is allowed only into an ACTIVE Family and creates no child access, FAMILY membership, Principal, Auth binding, Foundation grant, or primary context.
- END/CORRECT require an open unsuperseded source and a strictly later effective date.
- Duplicate overlapping relationship facts are rejected.
- CORRECT retains the source row and records replacement lineage with `supersedes_id`.
- If END removes an effective selected primary relationship while another selectable relationship exists, an explicit replacement is mandatory. The server never guesses one.
- Replacement ancestry, active Family state, effective containment, and Student identity are validated under lock.
- Future primary/access intervals that cannot be transformed without invalid history are rejected.
- END closes a child-access interval only when the ended relationship removes its final relationship basis. Access justified by another relationship remains open.
- Archived Families cannot receive new relationship ADDs; retained existing facts remain historical evidence and are handled under the frozen END/CORRECT rules.

## Frozen concurrency contract

The command precollects retained ancestry and locks relevant rows in deterministic hierarchy: Person → Student → Family → relationship → dependent primary/access history, with UUID ordering where multiple rows of one type are involved.

Student and Family optimistic versions are checked under lock. Cross-ancestry source/replacement substitution is rejected after locking.

## Frozen replay/evidence contract

Canonical idempotency binds all protected relationship-change intent, including expected versions, action, source/new facts, effective date, reason, and explicit primary replacement.

Successful replay validates retained historical result evidence rather than requiring the successful row to remain the current open lineage head. Later legitimate relationship/access evolution therefore does not invalidate an earlier successful receipt.

Receipt/result shapes are exact, typed, and NULL-safe. Broad audit/outbox evidence is minimized to identifiers and safe action/version/state metadata; display names, relationship contacts, reason text, arbitrary request JSON, and unrelated private child data are excluded.

## Exact runtime boundary

The trusted Effect-30 runtime is the exact SQL state at `3ae3bc65efb2e5f2d45c05b36d9c094f0d7c22e7`. Relative to the Effect-29 trusted runtime SHA `a319c946fdde033d54b8755aa6176b4600aff956`, the runtime additions are the 29 ordered Effect-30 `.sql.draft` continuations; the intervening four Effect-29 review/freeze files are documentation-only. Foundation migrations 1–9 are unchanged. The manifest remains **97 permissions / 322 scope alternatives / 36 operation contracts**.

The Effect-30 review/freeze documents committed after the trusted runtime SHA are documentation-only and do not change the frozen runtime.

Migration 10 remains `.sql.draft` and unexecuted. The exact-SHA CI gate validates the frozen Foundation and does not parse or deploy Effect-30 SQL. D1C2, staging/managed Supabase application, worker activation, and Effect 31 implementation are not authorized by this freeze.

**`DOMAIN PACKAGE D1C1B EFFECT 30/36 FROZEN — FAMILY.RELATIONSHIP.CHANGE ACCEPTED`**