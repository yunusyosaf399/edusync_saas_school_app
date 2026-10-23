# DB-02 I04 — atomic immutable Roll Policy revision history

**Date:** 2026-10-23. **Scope:** private draft-only INIT/REPLACE revision write, not live or independently reviewed. Stacked on I03 [PR #145](https://github.com/yunusyosaf399/edusync_saas_school_app/pull/145) head `c350d735d52e0d3379884296e497e11901e205ea`.

## SQL behavior (I04 only)

`effect50_01_db02_policy_revision_transition.sql.draft` creates a single Student executor-owned private `app_private.d1_roll_policy_revision_transition(uuid,text,text,uuid,integer,text,bigint,date,text,bigint,text)` with fixed SECURITY DEFINER search_path. It calls the exact I01–I03 DIRECT command-context/receipt and live Principal/School ALL/global Foundation P1 version checks, then repeats the current School-locked source and future-commitment preflight. SQL raises on non-success; no suppressed exception or partial commit.

- **INIT** only if no previous School Roll Policy exists. INSERT one revision numbered 1 with caller's validated mode/start/reason, trusted School-local effective date, no predecessor, verified actor ID, server-allocated UUID.
- **REPLACE** only for exact still-open prior policy UUID, revision, mode, start and effective date. Close exactly one source with `effective_until = School-local today`, `ended_at=statement_timestamp()`, `ended_by=verified actor`, then INSERT **one** successor `revision=source+1`, `supersedes_id=exact source UUID`, `effective_from=same School-local date`. Invalid same-day closure is denied by I03 and the immutable effective-history constraint. The INSERT and UPDATE share one PostgreSQL transaction and exceptions roll back both.
- Does **not** update any student Roll allocation, existing allocator high-water, Enrollment, source reason or earlier history.
- **No public EXECUTE** for PUBLIC, anon, authenticated, service_role, or the independent Workflow executor. The helper is not an app RPC or an enabled endpoint. This intermediate can only be exercised by its private owner in disposable/rollback fixtures.

**Critical partial-effect warning:** I04 intentionally does **not yet** create target allocator pools or success evidence/receipt/audit/outbox. Do not call as a committed business operation before I05 and I06 are atomically composed; absence of new allocator is not a release-ready policy transition. Do not grant a public or Workflow edge.

## Rollback acceptance

`92_db02_atomic_policy_revision_transition.sql` has 27 assertions including private ownership and ACLs, synthetic currently authorized DIRECT INIT, duplicate INIT rejection, exact trusted date, then a rolled-back INIT fixture and a distinct REPLACE fixture proving source closure, actual Principal identity, contiguous date, new revision/version/mode/start, unchanged old allocator, no fabricated receipt/event, and retained historic source. Synthetic operation enablement, global P1 version and role grant are rolled back.

Expected catalog: **553 total functions / 535 security definers / 396 private / 157 app**, 34 forced RLS relations, no client private EXECUTE. The new suite increases business assertions from 3,422 to **3,449** if successful. Exact-head CI static/Foundation/disposable runtime is required; do not mark I04 complete before it passes.

## Pending

I05 will provision exactly one matching revision-specific pool per eligible Offering for academic context or one School-wide persistent pool, without reusing retained numbers; I06 will atomically compose receipt/audit/outbox and a historical effect verifier. I07–I11 add final authenticated DIRECT and independent approval workflows. T04–T07 must test real races and history. P03/G03 independent non-author SQL review remains open and no hosted Supabase deployment, merge, or SQL activation is authorized.
