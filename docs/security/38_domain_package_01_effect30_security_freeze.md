# D1C1B Effect 30/36 — Family Relationship Security Freeze

**Status: FROZEN.**

Trusted runtime SHA: `3ae3bc65efb2e5f2d45c05b36d9c094f0d7c22e7`.

Security freeze accepts `family.relationship.change` after independent static review and exact-SHA GitHub Actions run #173 (`37140015253`) passed on that runtime SHA.

## Frozen security boundary

- `family.relationship.change` remains a P1 scoped domain operation; relationship existence itself grants no authority.
- Current command authority is derived only through the frozen permission/scope system over the affected Student's interval-effective context.
- APPROVAL requires exact `family.access.approve` review permission, the configured ACTIVE reviewer role, and live matching Student scope.
- A requester cannot approve their own request through the same Principal or another Principal representing the same Person.
- Review does not auto-apply. Apply rechecks requester authority, reviewer authority, policy identity, versions, ancestry, and domain eligibility.
- Stale approved state fails closed through deterministic invalidation.
- Public mutation entry points are fixed SECURITY DEFINER RPCs with pinned `pg_catalog,pg_temp` search paths. Authenticated clients do not receive direct access to private effect/authorization/evidence helpers.
- Internal execution remains under NOLOGIN executor roles with narrowly granted helper privileges.

## Frozen lock and mutation boundary

The implementation precollects source/replacement ancestry and follows deterministic Person → Student → Family → relationship → dependent-history locking, using UUID order for multiple rows of the same type. Ancestry is revalidated after locking.

The effect may mutate retained Family relationship history and only the dependent primary/access intervals required by accepted END/CORRECT semantics. It may not create or alter Principals/Auth bindings, Foundation authorization rows, FAMILY-principal memberships, or new child-access entitlements.

ADD never grants portal access. END closes access only when the ended relationship was its final relationship basis. CORRECT preserves the retained source and appends a linked replacement. Primary replacement is explicit and validated; the server cannot silently choose another Family relationship.

## Frozen replay and disclosure boundary

- Idempotency binds the complete protected caller intent, including reason and explicit replacement selection.
- Changed intent requires a new idempotency key.
- Successful replay uses retained typed historical evidence and does not repeat the mutation.
- Later legitimate relationship evolution does not invalidate an earlier successful ADD/CORRECT replay merely because the old result is no longer current.
- Unrelated later access endings do not corrupt END replay evidence.
- Receipt summaries and approval-application evidence use exact shape/type/state validation and fail closed on NULL/malformed values.
- Broad audit/outbox evidence excludes display name, relationship contact, reason text, arbitrary request payloads, and unrelated child/private data.

## Exact-SHA validation

Full run #173 logs confirm exact checkout of `3ae3bc65efb2e5f2d45c05b36d9c094f0d7c22e7`, 121/121 tooling tests, frozen Foundation source integrity, clean nine-migration/no-seed local reset, 5/5 Auth fixtures, lint passes, and 220/220 Foundation TAP assertions.

The trusted runtime contains 29 ordered Effect-30 `.sql.draft` continuation files. Foundation migrations 1–9 are unchanged and the frozen manifest remains **97 permissions / 322 scope alternatives / 36 operation contracts**.

The review/freeze commits following the trusted runtime SHA are documentation-only. Migration 10 remains non-executable `.sql.draft` material and was not parsed or applied by the validation workflow. This freeze does not authorize D1C2, staging/managed Supabase application, worker activation, or Effect 31.

**`DOMAIN PACKAGE D1C1B EFFECT 30/36 SECURITY FROZEN — FAMILY.RELATIONSHIP.CHANGE ACCEPTED`**