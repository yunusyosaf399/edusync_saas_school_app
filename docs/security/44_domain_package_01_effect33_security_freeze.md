# D1C1B Effect 33/36 — Family Primary Context Security Freeze

**Status: FROZEN.**

Trusted runtime SHA: `3c2e7fbe2521cce685e96f493b1dd92729108e49`.

Security freeze accepts `family.primary_context.change` after independent static review and exact-SHA GitHub Actions run #206 (`37184333023`) passed on that runtime SHA.

## Frozen security boundary

- `family.primary_context.change` remains P0 and non-family-safe.
- Requester authority is exact current ACS staff authority for the affected Student: ALL/CAMPUS/CLASS/SECTION.
- There is no approval workflow or reviewer substitution for this operation.
- Family relationship, FAMILY Principal membership, child-access entitlement and primary display context remain separate facts.
- Family membership, FAMILY credentials, child access or being the related adult never grants mutation authority.
- Primary context creates no Foundation/staff authority and no Auth/Principal identity.
- The selection is an operational display/responsibility fact only and carries no legal custody, pickup or financial-responsibility semantics.

## Frozen SELECT/END/CORRECT distinction

SELECT requires an exact effective Father/Mother/Guardian relationship belonging to the Student, full interval containment, non-overlap and an ACTIVE target Family. Replacing an effective current context requires the exact source context; the server does not guess. A normal SELECT replacement closes and retains that source but starts a fresh selection lineage with `supersedes_id IS NULL`.

END is reduction-only and closes the exact open source without replacement. It remains available after Family archive and does not mutate the selected relationship or portal access.

CORRECT closes the exact open source and appends a retained successor through `supersedes_id`. It must make a factual change and remains available for historical repair after Family archive subject to relationship containment and overlap rules.

`supersedes_id` is therefore correction lineage only; an ordinary display-selection change cannot be misrepresented as factual correction history.

## Frozen concurrency boundary

Lock order is Foundation authorization/idempotency and current actor Principal → Student rows UUID-ascending → relevant Family rows UUID-ascending → source/target relationship rows UUID-ascending → retained primary-context history UUID-ascending.

Source/target ancestry is revalidated under these locks. Effect 30 uses the same domain ordering for dependent primary-context handling, preventing relationship and primary-selection races.

The Student row is the serialization/version anchor and is not mutated merely to manufacture a version bump. Expected Student version is checked under lock; exact source lineage and locked history provide stale-selection protection.

## Frozen replay/evidence boundary

- Canonical idempotency binds Student ID/version, action, source context where applicable, target relationship, interval and private reason.
- Successful replay uses retained history and does not require an earlier result to remain current after a legitimate later END/CORRECT.
- Replay proves SELECT has no correction predecessor and CORRECT names its exact accepted source; a replaced SELECT source is separately proven closed at the accepted boundary.
- The HE provenance guard supplies end actor/time on one-way closure and accepted initially bounded rows.
- END reason is required and canonical-intent-bound without mutating the source row's original immutable reason.
- The only successful domain event is `family.primary_context_changed`.
- Broad audit/outbox evidence is minimized to typed IDs, action, safe interval/version data and receipt/correlation evidence.
- Private reason text, relationship contact/display values, Auth-user IDs, Student private fields and copied arbitrary request JSON are excluded from broad evidence.
- No normal delete exists.

## Audit corrections frozen

Six Effect-33 draft continuations form the accepted implementation. Continuation 05 removes the artificial Student parent-version bump; continuation 06 reserves `supersedes_id` for CORRECT and makes normal SELECT switches fresh lineages, with corresponding durable replay validation.

## Exact-SHA validation and boundary

Full run #206 logs confirm exact checkout of `3c2e7fbe2521cce685e96f493b1dd92729108e49`, 121/121 tooling tests, frozen Foundation source integrity, Supabase CLI 2.98.2, clean nine-migration/no-seed reset, 5/5 Auth fixtures, lint passes and 220/220 Foundation TAP assertions.

The executable/runtime Effect-33 delta since Effect-32 freeze tip `f593105baf95805766586a3f9ffd3b6459b624e8` is six Effect-33 `.sql.draft` continuations. Four documentation commits from the interrupted pre-correction freeze attempt occur before continuation 06 in commit ancestry; the corrected documentation after the trusted runtime SHA supersedes them and changes no runtime behavior. Foundation migrations 1–9 remain unchanged and the manifest remains **97 permissions / 322 scope alternatives / 36 operation contracts**.

Migration 10 remains `.sql.draft` and unexecuted. This freeze does not authorize D1C2, staging/managed Supabase application, worker activation or Effect 34 implementation.

**`DOMAIN PACKAGE D1C1B EFFECT 33/36 SECURITY FROZEN — FAMILY.PRIMARY_CONTEXT.CHANGE ACCEPTED`**
