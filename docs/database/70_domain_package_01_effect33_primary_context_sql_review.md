# D1C1B Effect 33/36 — Family Primary Context SQL Review

**Status: ACCEPTED STATIC RUNTIME CANDIDATE.**

Trusted runtime candidate: `3c2e7fbe2521cce685e96f493b1dd92729108e49`.

Effect 33 implements frozen operation `family.primary_context.change` as the P0 protected command for retained `student_primary_family_contexts` display-selection history. Primary/responsible context is an operational display selection only. It is not Father/Mother/Guardian relationship truth, Family portal entitlement, FAMILY Principal membership, Foundation authority, legal custody, pickup authorization or financial responsibility.

## Reviewed command surface

Application entry point:

- `app.d1_change_family_primary_context(...)` — P0 DIRECT only.

There is no approval-request/reviewer/apply workflow for this operation.

Frozen actions are **SELECT**, **END** and **CORRECT**.

## SELECT

SELECT chooses an exact effective Father/Mother/Guardian `family_relationships` row for the Student. The selected relationship must belong to the same Student and contain the complete requested primary-context interval.

If another primary context is effective at the selection boundary, the caller must identify that exact source context. The source is closed and the new selection is appended atomically. The server does not guess which current context to replace.

A normal SELECT switch starts a new display-selection lineage: the replacement row has `supersedes_id IS NULL`. The closed source remains retained and is still proven during idempotent replay. `supersedes_id` is reserved for factual CORRECT lineage.

A new SELECT requires the target Family to be ACTIVE. Family archive does not silently end already retained primary-context history, but a new current display selection is not created into an archived Family.

## END

END requires the exact unsuperseded open source context and an exclusive end date after its start. It closes the retained row without selecting a replacement and without deleting history.

END does not require the selected Family to remain ACTIVE and does not mutate relationship, child-access or FAMILY-membership history. The private command reason is required and bound into canonical intent; the immutable source row retains its original creation reason, matching the frozen HE end model used by prior Family effects.

## CORRECT

CORRECT closes the exact unsuperseded open source context and appends a same-Student successor through `supersedes_id`. The successor may select a different valid Father/Mother/Guardian relationship and may be initially bounded.

A reason-only/no-op correction is rejected. If the source and target relationship are identical, an open-ended successor would make no factual change and therefore denies; a real interval correction may still be represented by a bounded successor.

CORRECT remains available for retained factual repair after Family archive, subject to exact relationship containment and overlap rules.

## Temporal containment and overlap

The physical contract allows at most one effective primary display context per Student. The implementation locks all retained context rows for the Student and rejects retained interval overlap, including historical/future overlap.

For SELECT/CORRECT, the target relationship must start no later than the new context and must remain effective through the whole context interval. An open-ended context therefore requires an open-ended selected relationship at acceptance time.

Later relationship END/CORRECT remains authoritative through Effect 30, which serializes on the same Student/Family/relationship/context anchors and closes or reselects dependent primary context where required.

## Authorization

`family.primary_context.change` is non-family-safe and uses frozen ACS Student-context authority: ALL, matching CAMPUS, matching CLASS or matching SECTION. A current effective primary enrollment resolves the contextual scope; absent placement falls back to ALL-only and ambiguous placement fails closed.

Family membership, FAMILY credentials, relationship facts, child access or being the selected adult never grants mutation authority.

## Concurrency

The command first resolves canonical idempotency and locks the current Principal, then uses the established D1 order:

1. Student rows, UUID ordered when ancestry precollection discovers more than one;
2. relevant Family rows, UUID ordered;
3. source/target `family_relationships` rows, UUID ordered;
4. all retained `student_primary_family_contexts` rows for the Student, UUID ordered.

The ancestry is revalidated after the locks. This matches the Effect-30 dependent-primary ordering and prevents relationship mutation from racing primary-context selection.

The Student row is the serialization/version anchor. Continuation 05 correctly stops manufacturing a Student version bump for a child-history-only mutation. The expected Student version is checked under lock, while source-context lineage and locked history provide stale-selection protection. The successful command returns the locked Student version unchanged.

## Idempotency and replay

Canonical intent binds Student ID, expected Student version, action, source context where applicable, target relationship, effective start/end and private reason.

Successful replay is retained-history based. An earlier open-ended SELECT/CORRECT remains replayable after a later legitimate END/CORRECT because replay proves the original accepted retained row rather than requiring it to remain current. END replay proves the retained accepted closure.

Continuation 06 makes replay aware of the frozen lineage distinction: SELECT requires the accepted result to have no correction predecessor while CORRECT requires `supersedes_id` to equal the supplied source. When SELECT replaced a current source, replay separately proves that source was closed at the accepted boundary.

## Evidence

The only successful domain event is `family.primary_context_changed`.

Broad audit/outbox evidence contains typed Student/Family/context/source/relationship IDs, action, safe interval/version data and receipt/correlation evidence. Private reason text and relationship display/contact values are excluded from broad evidence.

No Principal/Auth/Foundation grant, Family membership, child-access or relationship mutation is performed by Effect 33.

## Independent audit result

Six ordered Effect-33 continuation fragments were reviewed for SELECT/END/CORRECT shape, HE provenance, relationship containment, Student-wide non-overlap, source staleness, correction lineage, ACS authorization, lock ordering, cross-effect serialization, idempotency, replay durability, evidence minimization, SECURITY DEFINER search paths and client/private ACLs.

Two audit corrections are retained:

- continuation 05 removes an artificial Student `updated_at` mutation. Primary-context history is a child fact; the Student row remains a serialization/version anchor without manufacturing a parent version bump;
- continuation 06 corrects SELECT/CORRECT lineage. A normal SELECT switch closes the old selection but starts a fresh lineage, while only factual CORRECT appends through `supersedes_id`. Replay was hardened to prove that exact distinction.

The HE base guard was specifically rechecked: closing an open HE row supplies `ended_at`/`ended_by`, and an accepted initially bounded insert receives matching end evidence. Therefore continuations 05/06 may set the protected `effective_until` while relying on the frozen provenance trigger for end actor/time.

No blocking defect remains after continuation 06.

## Exact-SHA gate

GitHub Actions run #206 (`37184333023`) completed successfully on exact SHA `3c2e7fbe2521cce685e96f493b1dd92729108e49`.

Full log inspection confirms:

- exact checkout of `3c2e7fbe2521cce685e96f493b1dd92729108e49`;
- 121/121 tooling unit tests;
- frozen Foundation source integrity (`9 migrations + 9 tests`);
- Supabase CLI 2.98.2 and Docker/Linux local stack;
- clean reset of nine frozen migrations with no seed;
- 5/5 Auth fixtures;
- lint error/warning gates passed;
- all nine Foundation TAP files passed, 220/220 assertions total.

This gate validates the frozen Foundation. Migration 10 and Effect-33 continuation SQL remain `.sql.draft`; they were not parsed, executed, deployed or remotely applied by this gate.

## Runtime boundary

The executable/runtime delta introduced for Effect 33 since Effect-32 freeze tip `f593105baf95805766586a3f9ffd3b6459b624e8` consists of six ordered `20260928000000_domain_package_01_effect33_*.sql.draft` files. Four Effect-33 review/freeze documents from the interrupted pre-correction freeze attempt also occur in commit ancestry before continuation 06; they are documentation only and are superseded by the corrected records at the final freeze tip.

Foundation migrations 1–9 are unchanged. The frozen manifest remains **97 permissions / 322 scope alternatives / 36 operation contracts**. Migration 10 remains unexecuted. No D1C2, staging/managed Supabase application or worker activation is authorized by this review.
