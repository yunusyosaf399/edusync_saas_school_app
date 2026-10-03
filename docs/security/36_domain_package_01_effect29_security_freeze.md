# D1C1B Effect 29/36 — Family Manage Security Freeze

**Status: FROZEN.**

Trusted runtime SHA: `a319c946fdde033d54b8755aa6176b4600aff956`.

Security freeze accepts `family.manage` after independent static review and exact-SHA GitHub Actions run #144 (`37135931454`) passed on that runtime SHA.

## Frozen security boundary

- `family.manage` remains P0/direct staff administration and is not family-safe.
- A FAMILY principal, Family relationship, child-access row, Emergency Contact, adult Person, Employee fact or teaching fact grants no Family-management authority.
- The externally callable surface is the fixed `app.d1_manage_family(...)` SECURITY DEFINER RPC with pinned `pg_catalog,pg_temp` search path.
- PUBLIC, anon and service_role do not receive RPC EXECUTE. Authenticated callers can invoke only the fixed RPC, not the private command/evidence helpers.
- Internal Family execution remains under the NOLOGIN `schoolos_family_executor` role.
- The generic idempotency first phase takes the frozen shared authorization advisory lock; the command then locks the current Principal identity row before domain mutation.
- Existing-target mutations lock the exact Family and require current authority plus the expected row version.
- The Effect-29 audit correction grants the Family executor only private EXECUTE on `d1_lock_current_principal(uuid)`; it does not expose that helper to clients or alter Foundation role/grant/scope rows.

## Frozen mutation boundary

The operation may only:

1. INSERT one ACTIVE `app_private.families` row for CREATE;
2. UPDATE only `display_label` for RELABEL;
3. UPDATE only archive state/evidence fields for ARCHIVE.

The existing mutable-record guard keeps `school_id` and `code` immutable. There is no ordinary delete, unarchive/reactivate, or archived-row relabel path.

Effect 29 performs no mutation of `family_relationships`, `family_principal_memberships`, `family_student_access`, `student_primary_family_contexts`, Principals/Auth bindings, or Foundation assignment/role/permission/grant/scope/contract data. Consequently Family archive cannot silently revoke existing portal child access or erase retained human relationship facts.

## Frozen evidence/disclosure boundary

- Canonical intent binds all caller-controlled Family-management intent relevant to replay and optimistic concurrency.
- Successful receipt replay does not repeat the mutation.
- Broad audit/outbox evidence is minimized to IDs, safe action/state/version labels and receipt/correlation evidence.
- Family display label, child information, relationship contacts and arbitrary request payloads are not copied into broad evidence.
- The only domain outbox event for this effect is `family.changed`.

## Exact-SHA validation

Full run #144 logs confirm exact checkout of `a319c946fdde033d54b8755aa6176b4600aff956`, 121/121 tooling tests, frozen Foundation source integrity, clean nine-migration/no-seed local reset, 5/5 Auth fixtures, lint passes and 220/220 Foundation TAP assertions.

The runtime delta from Effect 28 consists only of the two Effect-29 `.sql.draft` continuations. The frozen manifest remains **97 permissions / 322 scope alternatives / 36 operation contracts**.

Migration 10 remains non-executable `.sql.draft` material and was not parsed or applied by the validation workflow. This freeze does not authorize D1C2, staging/managed Supabase application, worker activation, or Effect 30.

**`DOMAIN PACKAGE D1C1B EFFECT 29/36 SECURITY FROZEN — FAMILY.MANAGE ACCEPTED`**
