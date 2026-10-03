# D1C1B Effect 29/36 — Family Manage Security Review

**Status: ACCEPTED.**

Trusted runtime candidate: `a319c946fdde033d54b8755aa6176b4600aff956`.

## Security conclusion

Effect 29 keeps `family.manage` inside the frozen P0 staff-administration boundary. The Family grouping is not a Principal, credential, relationship grant, child entitlement, or Foundation authorization object.

The externally callable surface is only `app.d1_manage_family(...)`, owned by the NOLOGIN `schoolos_family_executor`. It is SECURITY DEFINER with a pinned `pg_catalog,pg_temp` search path. PUBLIC, anon and service_role receive no EXECUTE; authenticated callers reach the fixed RPC only and cannot directly invoke the private receipt, audit, event, authorization, or identity-lock helpers.

## Authorization

The command resolves the singleton school anchor internally and rechecks current authority through `family.manage` against that School. The frozen permission is non-family-safe and ALL/DIRECT only. Current FAMILY membership, child access, adult relationship, Emergency Contact facts, Employee/teaching facts, or a Family row itself do not provide management authority.

The command takes the frozen authorization advisory lock through the generic receipt lookup and then the current Principal identity row lock before the domain target lock. The initial draft was missing Family-executor EXECUTE on `d1_lock_current_principal(uuid)`; the append-only correction at `a319c946...` closes that gap without exposing the helper to authenticated users.

## Mutation boundary

Allowed domain writes are exactly:

- CREATE one `app_private.families` row;
- RELABEL the selected ACTIVE Family's `display_label`;
- ARCHIVE the selected ACTIVE Family by setting state plus archive actor/time evidence.

No command path can update `school_id` or `code`; the existing mutable-record guard also protects those immutable columns. No delete or reactivation path exists. RELABEL is denied after archive.

Effect 29 performs no write to:

- `family_relationships`;
- `family_principal_memberships`;
- `family_student_access`;
- `student_primary_family_contexts`;
- principals/Auth bindings;
- Foundation assignments, roles, permission grants, scopes or contracts.

Therefore Family archive does not silently revoke established child access or erase relationship history. Later link/access operations must independently enforce the frozen rule that archived Families block new links while existing authorized access remains subject to its own current membership/access/relationship checks.

## Concurrency and replay

Existing Family mutations lock the exact Family row and require the expected positive row version while the Family is ACTIVE. The row-version trigger serializes accepted mutable state. CREATE is protected by the one-school anchor plus structural `(school_id,code)` uniqueness.

The idempotency hash binds the full caller intent. Reuse of the same key with changed action, target, code, label or expected version conflicts. Successful replay returns retained receipt evidence rather than issuing a second mutation. CREATE replay additionally proves the immutable school/code target still exists.

## Disclosure and evidence

Broad audit/outbox evidence contains only Family ID, safe action/state labels, version, receipt/correlation identifiers and operation evidence. It does not copy the restricted Family display label, child details, relationship contacts, arbitrary request JSON, or unrelated private data.

The only outbox event emitted by this operation is `family.changed`.

## Exact-SHA validation

Exact-SHA GitHub Actions run #144 (`37135931454`) passed on `a319c946fdde033d54b8755aa6176b4600aff956`. Full logs confirm 121/121 tooling tests, frozen Foundation integrity, clean nine-migration/no-seed local reset, 5/5 Auth fixtures, lint gates and 220/220 Foundation TAP assertions.

Migration 10 remains a non-executable `.sql.draft`; this security acceptance does not authorize D1C2, remote/staging application, worker activation, or Effect 30.
