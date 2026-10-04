# D1C1B Effect 30/36 — Family Relationship Security Review

**Status: ACCEPTED.**

Trusted runtime candidate: `3ae3bc65efb2e5f2d45c05b36d9c094f0d7c22e7`.

## Security conclusion

Effect 30 keeps `family.relationship.change` inside the frozen P1 domain boundary. A Family relationship is a retained human/domain fact; it is not itself a Principal, credential, Foundation authorization assignment, FAMILY-principal membership, or child-access grant.

The public mutation surface is limited to the fixed DIRECT and APPROVAL RPCs. They are SECURITY DEFINER functions with pinned `pg_catalog,pg_temp` search paths. PUBLIC, anon, and service_role do not receive direct execution of the mutation RPCs; authenticated callers cannot directly invoke private authorization, lock, effect, receipt, audit, outbox, or workflow helpers.

## Authorization and approval security

Current command authority is checked through exact `family.relationship.change` scope over the Student's interval-effective context. Existing relationship rows confer no command authority.

When policy selects APPROVAL:

- the operation contract must bind review permission exactly to enabled, non-family-safe `family.access.approve`;
- each approval step must use an ACTIVE configured reviewer role and `D1_REVIEWER_ROLE_SCOPE` resolver;
- reviewer candidates require live `family.access.approve` authority for that configured role and affected Student scope;
- the requester Principal is excluded;
- any other Principal representing the same Person is also excluded;
- review does not auto-apply;
- apply rechecks requester authority and every approved reviewer's live authority.

A stale policy, revoked requester/reviewer authority, stale Student/Family version, stale source, changed replacement ancestry, or newly invalid domain condition invalidates an approved request instead of applying it.

## Locking and ancestry security

The final lock implementation precollects immutable source/replacement ancestry, then locks relevant Person, Student, Family, and relationship rows in deterministic hierarchy/UUID order. It revalidates ancestry after locking and rejects cross-Student/cross-Family substitution.

Dependent primary-context and child-access history is locked before mutation. This prevents the relationship command from racing a dependent-history mutation and accepting an inconsistent primary/access result.

## Mutation boundary

The operation may mutate only the retained relationship fact and the dependent primary/access intervals required by the accepted END/CORRECT semantics. It may not create or mutate:

- Principals or Auth bindings;
- Foundation roles, assignments, permissions, grants, scopes, or operation contracts;
- FAMILY-principal membership;
- new child-access entitlement;
- unrelated Student/Family facts.

ADD never grants portal access merely because a relationship exists. END closes child access only when the ended relationship removes its final relationship basis. CORRECT preserves retained source history and appends the replacement lineage.

Explicit primary replacement prevents the server from silently choosing another Family/relationship. Archived Families cannot receive new relationships.

## Replay and evidence security

Idempotency binds the complete protected intent, including reason and explicit replacement choice. Reuse of a key with changed intent conflicts.

Replay checks retained typed historical evidence. It does not require the successful result to remain the current open relationship and does not count unrelated later access endings. Receipt summaries use exact key/type/state contracts and NULL-safe validation.

Broad audit/outbox evidence is minimized to identifiers and safe action/version/state metadata. Display names, relationship contacts, reason text, arbitrary request payloads, and unrelated child/private data are not copied into broad evidence.

## Exact-SHA validation

Exact-SHA GitHub Actions run #173 (`37140015253`) passed on `3ae3bc65efb2e5f2d45c05b36d9c094f0d7c22e7`. Full logs confirm exact checkout, 121/121 tooling tests, frozen Foundation integrity, clean nine-migration/no-seed local reset, 5/5 Auth fixtures, lint gates, and 220/220 Foundation TAP assertions.

Migration 10 remains non-executable `.sql.draft` material and was not parsed or applied by that validation workflow. This security acceptance does not authorize D1C2, remote/staging application, or worker activation.