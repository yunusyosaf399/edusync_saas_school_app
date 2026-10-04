# D1C1B Effect 33/36 — Family Primary Context Freeze

**Status: FROZEN.**

Trusted runtime SHA: `3c2e7fbe2521cce685e96f493b1dd92729108e49`.

Exact-SHA GitHub Actions run #206 (`37184333023`) completed successfully on that SHA. Full log inspection confirms exact checkout, 121/121 tooling unit tests, frozen Foundation source integrity, Supabase CLI 2.98.2, clean local reset of nine frozen migrations with no seed, 5/5 Auth fixtures, lint passes and 220/220 Foundation TAP assertions.

## Frozen operation

`family.primary_context.change`

Routing: **P0 DIRECT only.** There is no approval workflow for this baseline operation.

Frozen actions:

- `SELECT` — choose an exact effective Father/Mother/Guardian relationship as the Student's primary/responsible display context; close an explicitly identified current source context atomically when replacing one. A normal switch starts a fresh selection lineage and therefore does not populate `supersedes_id`.
- `END` — one-way close the selected open primary-context row without replacement.
- `CORRECT` — close the exact open source and append a factual retained successor through `supersedes_id`.

## Frozen semantics

- Primary context is display/operational selection only. It grants no Family portal access, staff/Foundation authority, legal custody, pickup authority or financial responsibility.
- The selected relationship must belong to the same Student and contain the entire primary-context interval.
- At most one effective primary display context may exist per Student.
- SELECT requires an ACTIVE target Family. Family archive does not silently revoke an existing retained context.
- END remains available after Family archive and does not choose a replacement automatically.
- CORRECT may repair retained factual history after Family archive, but must make a real factual change and must still satisfy exact relationship containment and non-overlap.
- `supersedes_id` is correction lineage only. A normal SELECT replacement closes and retains the prior context but creates the new selection with no correction predecessor.
- Relationship END/CORRECT remains authoritative through Effect 30 and serializes against the same primary-context history.
- `family.primary_context.change` is non-family-safe and uses exact ACS Student context: ALL/CAMPUS/CLASS/SECTION.
- Family membership, relationship truth, child-access entitlement or FAMILY credentials never substitute for staff permission.
- Canonical idempotency binds Student ID/version, action, source context where applicable, target relationship, interval and private reason.
- Successful replay uses retained history and does not require an earlier result to remain the current selection. Replay also proves SELECT has no correction predecessor and CORRECT points to the accepted source.
- The only successful domain event is `family.primary_context_changed`.
- Broad evidence excludes private reason text and relationship display/contact values.
- No normal delete exists.

## Frozen concurrency boundary

Lock order is Foundation authorization/idempotency and current actor Principal → Student rows UUID-ascending → relevant Family rows UUID-ascending → source/target relationship rows UUID-ascending → retained primary-context history UUID-ascending.

The Student row is a serialization/version anchor, not a mutable aggregate projection for this child-history operation. Continuation 05 removes the earlier artificial Student `updated_at` mutation and returns the locked expected version unchanged; source-context lineage and locked retained history supply stale-selection protection.

Continuation 06 corrects the normal-selection lineage boundary: SELECT closes any explicitly supplied current source but creates a fresh lineage; CORRECT alone appends through `supersedes_id`.

The frozen HE provenance guard supplies `ended_at`/`ended_by` on one-way closure and on initially bounded accepted rows.

## Exact runtime boundary

The executable/runtime Effect-33 delta since Effect-32 freeze tip `f593105baf95805766586a3f9ffd3b6459b624e8` is exactly six Effect-33 `.sql.draft` continuation files. The earlier four Effect-33 documentation commits in the ancestry were created before the final continuation-06 audit correction and are superseded by the corrected documentation at the final freeze tip; they do not alter runtime behavior.

Foundation migrations 1–9 are unchanged. The manifest remains **97 permissions / 322 scope alternatives / 36 operation contracts**.

Migration 10 remains `.sql.draft` and unexecuted. The exact-SHA CI gate validates the frozen Foundation and does not parse/deploy Effect-33 draft SQL. D1C2, staging/managed Supabase application, worker activation and Effect 34 implementation are not authorized by this freeze.

**`DOMAIN PACKAGE D1C1B EFFECT 33/36 FROZEN — FAMILY.PRIMARY_CONTEXT.CHANGE ACCEPTED`**
