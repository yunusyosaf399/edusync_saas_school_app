# DB-02 T08 privacy, function ACL and RLS acceptance

Scope: inactive Migration 10 draft, effects 42–58, plus the existing Foundation and DB-01 dependencies they call. This review does not replace the independent non-author decision in issue #131/G03.

## Inventory and boundary

The rollback-only suite `101_db02_t08_privacy_acl_rls.sql` enumerates all 32 distinct function names created or replaced by the DB-02 fragments (five `app` endpoints and 27 `app_private` routines). It checks their actual applied catalog state: SECURITY DEFINER, pinned `pg_catalog, pg_temp` search path, reviewed NOLOGIN owners without BYPASSRLS, no `PUBLIC` implicit EXECUTE, no `anon`/`service_role` EXECUTE, no `authenticated` private EXECUTE, and exactly five authenticated public entries. The schema-owner application trigger remains private. Every public return signature is checked for raw reason, receipt, audit, outbox, hash or intent fields. Routine source is screened for user-editable JWT metadata and deprecated `auth.role()` authorization.

The same suite checks FORCE RLS on nine policy, allocator, Roll, approval and evidence tables; denies client raw SELECT/DML in the actual catalog; executes denied authenticated raw reads for policy history, receipt, audit, outbox and approval request; and checks that the public request projection returns no row for a null target. The full local runtime also checks 34/34 forced D1 RLS relations, zero authenticated/private EXECUTE, zero `anon`/`service_role` function EXECUTE, and zero client raw D1 table DML.

Earlier suites #94–#99 exercise persisted receipt/audit/outbox evidence, replay row proof, request participant filtering, reviewer authority revocation and minimized public responses. T07's additional protected P0 placement consumes the restored persistent number (5501) after its synthetic corrected history, before savepoint rollback. The owner-only synthetic correction is a test fixture and does not activate a Roll CORRECT RPC.

## Release boundary

No hosted migration or operation activation, shared receipt merge, or independent security signoff follows from local acceptance. Issue #131, DB-01 compatibility, final composition and release authorization remain separate gates.
