# DB-02 I07 — authenticated Roll Policy DIRECT entry (draft, local-only)

**Implementation:** `supabase/migrations/20260928000000_domain_package_01_effect54_01_db02_authenticated_direct.sql.draft`  
**Acceptance:** `supabase/tests/domain/95_db02_authenticated_direct_entry.sql` (37 rollback-only assertions).  
**Dependency:** I06 draft transition + receipt/evidence/proof from PR #151; this I07 branch is stacked on the exact I06 green commit `756f8947ba7aa90df1286cf013869386d6c16af8`.

## Public API (no publication, hosted migration, or live switch)

```sql
app.d1_change_student_roll_policy(
  p_school_id uuid,
  p_action text, -- INIT | REPLACE only
  p_source_policy_id uuid,
  p_expected_source_revision integer,
  p_expected_source_mode text,
  p_expected_source_start_value bigint,
  p_expected_source_effective_from date,
  p_new_mode text,
  p_new_start_value bigint,
  p_reason text,
  p_idempotency_key text
) RETURNS uuid
```

Only `authenticated` may execute the fixed `app` function; `anon`, `service_role` and `PUBLIC` receive no new grant. The `schoolos_student_executor` NOLOGIN role owns the SECURITY DEFINER implementation with `search_path=pg_catalog,pg_temp`. The user cannot call its private receipt/evidence/policy-transition helpers directly or read raw private tables.

The function delegates exclusively to `app_private.d1_roll_policy_revision_transition`, which checks a verified current Principal and School-wide ALL permission, selects and rechecks the exact global Foundation P1 DIRECT policy UUID, holds the receipt/School/source/allocator lock sequence, and performs INIT/REPLACE with the trusted School-local business date. It returns only the persisted new or historically re-verified revision UUID. No supplied actor, P1 version, target revision UUID, business/cutover date, receipt or event is trusted.

One call commits **revision + allocator pools + one receipt + one minimized audit + one schema-v1 event** atomically or raises and leaves no effect. Same authenticated actor, idempotency key and canonical private intent must pass *current authorization and exact historical row/evidence proof* before replay; the private reason participates in the hash but is not part of broad receipt summary, audit/outbox or public return.

## Scope and release gates

This change does **not** enable the operation by default; local acceptance tests explicitly enable it only inside a transaction which ends with `ROLLBACK`. No END, scheduled, retroactive, campus-specific policy, direct APPROVAL bypass, generic phases, new Student Roll renumbering, private reason projection, nonessential privileges, hosted SQL or PR merge.

I07 is a functional draft API with rollback-only acceptance; independent non-author SQL/security signoff remains open under issue #131. The standalone approval workflow I08–I11, two-backend concurrency and release integration remain separate issue #69 gates. Record completion in issue #69 **only after the exact I07 PR head passes D1 static, Foundation local and disposable D1 runtime**; otherwise leave I07 open.
