# D1C1B Effect 33/36 — Family Primary Context Security Review

**Status: ACCEPTED.**

Trusted runtime candidate: `8a6e580150a8e4ba0923704f01fc7a2a6e9053d6`.

## Security conclusion

Effect 33 preserves the separation between family relationship truth, FAMILY identity/membership, Family→Student portal entitlement and the Student's primary/responsible display selection. `family.primary_context.change` only appends or closes retained `student_primary_family_contexts` history. It does not create/revoke child access, create/end relationships, mutate FAMILY Principal membership, change Principal/Auth identity or alter Foundation roles/grants/scopes.

The externally callable mutation surface is the typed SECURITY DEFINER RPC `app.d1_change_family_primary_context(...)` under the NOLOGIN Family executor with pinned `pg_catalog,pg_temp` search path. PUBLIC, anon and service_role do not receive EXECUTE. Authenticated callers reach the protected RPC rather than private helpers or direct table DML.

## Authorization boundary

`family.primary_context.change` is non-family-safe. Current requester authority is exact ACS staff authority for the affected Student: ALL, matching CAMPUS, matching CLASS or matching SECTION.

The resolver uses the Student's current PRIMARY placement. Ambiguous effective placement fails closed; absent placement allows only ALL authority. Family membership, child access, relationship facts, being a related adult or possessing a FAMILY credential never grants mutation authority.

This operation is P0. No approval policy, reviewer role or workflow request can substitute for the direct permission check.

## Relationship/context integrity

SELECT and CORRECT require an exact Father/Mother/Guardian relationship belonging to the same Student and containing the entire requested context interval. Open-ended context therefore requires an open-ended selected relationship at acceptance time.

Only one effective primary context may exist per Student. The command locks the retained context set and rejects overlap rather than relying on a current-row-only check.

SELECT refuses creation of a new current selection into an archived Family. END and factual CORRECT remain available for reduction/history repair after archive. Family archive itself does not silently mutate retained primary-context history.

Effect 30 remains authoritative when a selected relationship is later ended/corrected; its dependent-primary handling serializes on the same anchors.

## Concurrency boundary

The final order is canonical idempotency/current actor Principal → Student rows UUID-ascending → relevant Family rows UUID-ascending → source/target relationship rows UUID-ascending → primary-context history UUID-ascending.

Source and target ancestry are precollected then revalidated after locking. This keeps Effect 33 compatible with Effect 30 relationship operations and prevents a relationship closure/reselection race.

The Student row is only the serialization/version anchor here. Continuation 05 removes an unnecessary parent-row mutation that would otherwise manufacture a Student version change for a child-history-only operation. Expected Student version is still checked under lock, while exact source context plus retained lineage protects against stale display-selection state.

## Idempotency and replay

Canonical intent includes Student ID, expected Student version, action, source context where applicable, target relationship, effective interval and private reason. Reuse of an idempotency key with different intent conflicts through the shared command-receipt canonical hash.

Replay validates an exact typed eight-field result summary against retained history. Earlier open-ended SELECT/CORRECT results remain replayable after later legitimate closure because replay does not require the accepted row to remain current. END replay proves the accepted retained closure.

## Provenance and evidence

The frozen HE guard supplies `ended_at`/`ended_by` on one-way closure and on initially bounded accepted rows, while all other history facts remain immutable.

The only successful domain event is `family.primary_context_changed`.

Audit/outbox evidence is restricted to typed Student/Family/context/source/relationship IDs, action, safe interval/version data and receipt/correlation evidence. Arbitrary private reason text, relationship contact/display values, Auth-user identifiers, private Student data and copied request JSON are excluded from broad evidence.

## Exact-SHA validation

Exact-SHA GitHub Actions run #205 (`37183363297`) passed on `8a6e580150a8e4ba0923704f01fc7a2a6e9053d6`. Full logs confirm exact checkout, 121/121 tooling tests, frozen Foundation source integrity, Supabase CLI 2.98.2, clean nine-migration/no-seed reset, 5/5 Auth fixtures, lint passes and 220/220 Foundation TAP assertions.

Migration 10 remains non-executable `.sql.draft` material and was not parsed or applied by that gate. This security acceptance does not authorize D1C2, remote/staging application, worker activation or Effect 34.
