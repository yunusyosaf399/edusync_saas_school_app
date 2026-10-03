# D1C1B Effect 29/36 — Family Manage SQL Review

**Status: ACCEPTED STATIC RUNTIME CANDIDATE.**

Trusted runtime candidate: `a319c946fdde033d54b8755aa6176b4600aff956`.

Effect 29 implements frozen operation `family.manage` as the P0 administration surface for the Family grouping itself. It does not implement relationship, principal-membership, child-access, or primary-context effects.

## Reviewed command surface

`app.d1_manage_family(p_action, p_family_id, p_code, p_display_label, p_expected_version, p_idempotency_key)`

Returns the resulting Family ID, accepted row version, and accepted Family state.

Accepted shapes are exact:

- `CREATE`: Family ID and expected version absent; nonblank code and display label required.
- `RELABEL`: existing Family ID and positive expected version required; code absent; nonblank replacement display label required.
- `ARCHIVE`: existing Family ID and positive expected version required; code and display label absent.

The one-school project anchor is resolved server-side from the singleton `school_profiles` row rather than accepted from the caller. Family `school_id` and `code` remain immutable under the existing `d1_guard_record('M','school_id','code')` guard.

## Concurrency and authorization

The command uses the frozen generic receipt/idempotency first phase, takes the current Principal identity row lock, and then takes the Family row lock for existing-target operations before mutating it. CREATE has no predecessor Family row; the structural `(school_id,code)` unique constraint arbitrates conflicting creates.

Current authority is rechecked through `d1_authorized('family.manage','SCHOOL',resolved_school_id)`. The frozen permission catalog supports this operation through the ALL/DIRECT staff path only; `family.manage` is not family-safe. A FAMILY principal therefore gains no management authority merely by being linked to a Family.

The static review found one missing private privilege in the initial candidate: `schoolos_family_executor` did not yet have EXECUTE on the frozen `d1_lock_current_principal(uuid)` helper. Continuation `effect29_02_family_identity_lock.sql.draft` corrects only that helper allowlist. No identity row, role, grant, permission, or scope data is mutated by this correction.

## State and retention behavior

- CREATE inserts an ACTIVE Family with server-generated UUID.
- RELABEL is accepted only from ACTIVE and updates only `display_label`.
- ARCHIVE is accepted only from ACTIVE and sets `state=ARCHIVED` plus retained archive actor/time evidence.
- There is no delete path and no reactivation path.
- Archived Families cannot later be relabeled by this command.
- ARCHIVE performs no write to `family_relationships`, `family_principal_memberships`, `family_student_access`, or `student_primary_family_contexts`; established relationship/access history therefore remains intact and no silent access revocation occurs.
- Creating or managing a Family never creates a Principal, Auth binding, Foundation role/grant/scope, Family relationship, shared-principal membership, child access, or primary display context.

## Idempotency and replay

Canonical intent binds action, Family ID where applicable, code where applicable, display label where applicable, and expected target version. The generic receipt lookup also binds operation contract, principal, command kind and client idempotency key.

CREATE replay proves the retained result still names the same immutable school/code Family. RELABEL/ARCHIVE replay proves the same target ID and returns the retained accepted version/state from the successful receipt. A later legitimate Family state evolution does not rewrite the earlier receipt.

## Evidence boundary

Successful commands create one typed command receipt and minimized broad evidence:

- audit event: `family.changed`, target kind `FAMILY`, action/state only;
- outbox event: `family.changed`, aggregate kind `FAMILY`, Family ID/action/state only.

Family code, display label, child information, relationship contacts, arbitrary request JSON and unrelated sensitive values are not copied into broad audit/outbox payloads.

The public RPC is SECURITY DEFINER with pinned `pg_catalog,pg_temp` search path; direct EXECUTE is revoked from PUBLIC/anon/service_role and granted only to authenticated callers. Private helpers are not directly executable by authenticated clients. The owning Family executor is NOLOGIN and receives only the additional private helper privileges needed by this fixed command.

## Exact-SHA gate

GitHub Actions run #144 (`37135931454`) completed successfully on exact SHA `a319c946fdde033d54b8755aa6176b4600aff956`.

Full log inspection confirms:

- exact checkout of the trusted SHA;
- 121/121 tooling unit tests;
- frozen Foundation source integrity (`9 migrations + 9 tests`);
- Supabase CLI 2.98.2 and Docker/Linux local stack;
- clean reset of nine frozen migrations with no seed;
- 5/5 auth fixtures;
- lint error/warning gates passed;
- all nine Foundation TAP files passed, 220/220 assertions total.

This gate intentionally validates the frozen Foundation only. Migration 10 remains `.sql.draft`; Effect-29 SQL was not parsed, executed, deployed, or applied to a local/managed project by this review.

## Boundary

The runtime delta from the Effect-28 freeze tip `0d886f9d68062273527ed460827b15713a0f5549` to the trusted runtime candidate consists only of two Effect-29 `.sql.draft` continuation files. Foundation migrations 1–9 are unchanged. The manifest remains **97 permissions / 322 scope alternatives / 36 operation contracts**.
