# DB03 next gate: identity before a Person is bound

Status: decision required; no executable SQL approved. Reviewed 1 November 2026 after PR #199 exact-head DB03 run 41284473750 and D1 run 41284473749 passed.

## Existing accepted boundaries

- P2-D01 permits a DRAFT with `person_id NULL`; a verified Foundation Person is required before SUBMITTED.
- The administrator creates/prepares intake; the Principal alone verifies admission identity and gives final approval. Missing certificates can remain pending for at most two months.
- PR #199 enforces one nonterminal application for a bound Person across the school, independent of Campus or Academic Year, with a uniform private duplicate error. Eight backend races include two separate drafts competing for one Person.
- `app.create_admission_draft(campus_id,academic_year_id,key)` currently receives no child identity. Its opaque DRAFT cannot be correlated with a second staff member's opaque DRAFT. An idempotency key prevents retry duplication for one actor/intent; it cannot identify a child between distinct requests.
- The S5 Person candidate screen is a conservative name heuristic against existing People, not proof. Two children may share a name; one child's spelling may vary. It neither indexes nor reserves unbound drafts.

## Required product decision

Select what the school can require at initial create, even when the birth certificate is missing. Exact acceptable fields, whether the school can inspect a trusted source at that point, who may correct a claim, and the sensitive-data retention/read policy are P2-D02/P2-D07 decisions. A reliable unique external identifier is unavailable in the current schema. Without it, no software rule can guarantee that two incomplete entries refer to the same real child.

Recommended safe contract for review:

1. Keep the current opaque DRAFT path for missing evidence, but mark it identity-unresolved. Do not present a guarantee of one draft per real child in this state, and do not let it reach SUBMITTED.
2. For a supplied, verified identity source, use a school-private typed claim/reservation created through an authorized server command. Normalize by a versioned rule; retain evidence reference and claim revision privately; never put raw identifier or candidate detail in audit, receipt, outbox, search, or generic error.
3. Lock a school/claim key and maintain a partial unique nonterminal reservation. A competing staff create for that verified claim must return only an authorized existing application or a uniform conflict. Different claims proceed independently. Binding to a Foundation Person transfers the uniqueness authority to the Person constraint in the same transaction, retaining reservation history.
4. On missing or ambiguous evidence, enter a Principal-controlled identity-resolution queue. Flag possible existing Person and unbound application candidates for authorized private review; do not auto-merge by name. A correction appends a new private claim revision, invalidates dependent checks and follows reviewed authority. No self-declared verified flag.
5. Preserve terminal histories and prevent a Person already attached to a Student from entering a duplicate new-student intake. Define rejection/withdrawal release and reapplication before activation. Do not select a retention duration or claim format by guess.

## Acceptance before an executable migration

Two staff same verified claim, different claims, different campuses/years, same name different children, spelling variation, missing document, stale/revoked proof, corrected claim, claim-to-Person transfer, withdrawn/rejected reapplication and already-Student denial. Exercise two actual PostgreSQL backends, replay/authority revocation, RLS/checked read privacy and failed transaction rollback. Reconcile with D1/DB03 lock order, then test a populated upgrade. No hosted school change from this record.

**Decision for owner:** Is there an identifier or source the school can reliably inspect when the administrator first creates a draft, including a child whose birth certificate is missing? If yes, name the exact source and who checks it. If no, accept that opaque drafts may coexist until Principal identity review and enforce uniqueness from verified Person binding onward.
