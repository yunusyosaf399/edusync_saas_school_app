# D1C1B Effect 25/36 — Student Enrollment Place security review

**Status: REVIEWED CANDIDATE — exact-SHA CI PASS; freeze record follows.**

Trusted runtime candidate: `09bd4be80d14d97fd5ddff151b72ba7e13685ef5`.

Effect 25 introduces no permission, role, scope-alternative or operation-contract count change. The frozen manifest remains 97 permissions / 322 scope alternatives / 36 operation contracts.

## Security properties reviewed

- `student.enrollment.place` remains `family_safe=false`, P0 and ACS-scoped. Authorization requires an active bound INDIVIDUAL principal plus the complete current assignment/grant/scope-contract chain; role labels and placement existence grant nothing.
- Destination scope is derived only from stored Section → Class Offering → Campus ancestry. ALL, matching CAMPUS, matching CLASS or matching SECTION may satisfy the permission.
- `student.capacity_override` is a separate conditional authority. It is evaluated only when either authoritative Class or Section capacity would be exceeded. Override does not bypass any other invariant.
- authenticated receives EXECUTE only on the fixed public placement RPC and no direct D1 base-table SELECT/DML grant.
- The public RPC derives actor identity from Foundation, uses SHARED authorization lock semantics, has fixed typed parameters and never accepts role/scope/permission claims from the client.
- Academic parent discovery/locking is isolated behind fixed helpers owned by `schoolos_academic_executor`; no executor-role membership bridge is introduced.
- School/policy/allocator serialization is preserved for roll allocation, including the School anchor required to serialize persistent numeric collisions across policy revisions.
- Student lock plus retained PRIMARY history prevents concurrent overlapping placement commits. Capacity parents are locked before occupancy decisions; deferred structural guards remain defense-in-depth.
- REENROLLMENT is the only status-reactivating Effect-25 path and is restricted to current WITHDRAWN/TRANSFERRED → ACTIVE. It never opens an old placement. Future-dated reactivation is denied.
- PROMOTION, REPEAT, CLASS_CHANGE, SECTION_CHANGE and CAMPUS_TRANSFER are denied here and reserved for the atomic source+destination move command.
- Terminal replay rechecks current `student.enrollment.place`; if the original success used capacity override it also rechecks current `student.capacity_override`. Replay verifies the exact durable result and returns before mutation preflight.
- Same idempotency key with changed typed intent conflicts under a placement-specific canonical receipt context. No shared receipt allowlist was broadened.
- Persistent roll lineage and collision checks use retained authoritative rows; no client-assigned final roll and no `MAX()+1` allocation path exists.
- Broad audit/outbox excludes arbitrary placement and override reasons. Outbox payloads contain only placement/roll/scope identifiers, lifecycle classifications, effective date, roll number and capacity-decision classification.
- Enrollment and capacity-override events use immutable version-1 aggregates; the REENROLLMENT status event uses the Student aggregate only when the Student projection/version actually changes.
- No new FAMILY or SYSTEM business authority path is introduced.

Migration 10 remains a non-executable `.sql.draft`; D1C2, remote deployment and staging execution remain unauthorized.
