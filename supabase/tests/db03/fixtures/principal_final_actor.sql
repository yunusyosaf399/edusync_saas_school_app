-- P34 disposable rollback-only Principal-final operation activation.
-- This source is INCLUDED ONLY from a transaction-scoped pgTAP fixture.
-- No deployment seed, migration, app-role grant or user authorization.
SET ROLE schoolos_schema_owner;
INSERT INTO app_private.permissions(id,code,state,family_safe,created_by)
VALUES(md5('admission.final.decide:p34-permission')::uuid,
 'admission.final.decide','ENABLED',false,
 '11111111-1111-4111-8111-111111111111');
INSERT INTO app_private.role_permission_grants(
 id,role_id,role_family_only,permission_id,permission_family_safe,valid_from,created_by)
VALUES(md5('admission.final.decide:p34-grant')::uuid,
 'dddddddd-dddd-4ddd-8ddd-dddddddddddd',false,
 md5('admission.final.decide:p34-permission')::uuid,false,
 clock_timestamp()-interval '1 hour','11111111-1111-4111-8111-111111111111');
INSERT INTO app_private.permission_scope_contracts(
 id,permission_id,scope_kind,resolver_key,enabled,created_by)
VALUES(md5('admission.final.decide:p34-scope')::uuid,
 md5('admission.final.decide:p34-permission')::uuid,
 'ALL','DIRECT',true,'11111111-1111-4111-8111-111111111111');
INSERT INTO app_private.assignment_permission_scopes(
 id,assignment_id,grant_id,role_id,permission_id,scope_contract_id,
 scope_kind,resolver_key,valid_from,created_by)
VALUES(md5('admission.final.decide:p34-assignment')::uuid,
 'abababab-abab-4bab-8bab-abababababab',
 md5('admission.final.decide:p34-grant')::uuid,
 'dddddddd-dddd-4ddd-8ddd-dddddddddddd',
 md5('admission.final.decide:p34-permission')::uuid,
 md5('admission.final.decide:p34-scope')::uuid,'ALL','DIRECT',
 clock_timestamp()-interval '1 hour','11111111-1111-4111-8111-111111111111');
INSERT INTO app_private.operation_contracts(
 id,code,handler_key,request_permission_id,created_by)
VALUES(md5('admission.final.decide:p34-operation')::uuid,
 'admission.final.decide','admission.final.decide',
 md5('admission.final.decide:p34-permission')::uuid,
 '11111111-1111-4111-8111-111111111111');
UPDATE app_private.operation_contracts SET enabled=true
WHERE code='admission.final.decide';
RESET ROLE;
-- Test JWT is scoped to this disposable SQL session and linked to real Auth user
-- from policy_publication_actor.sql; no token is issued or stored.
SELECT set_config('request.jwt.claims',
 jsonb_build_object('sub',current_setting('schoolos_test.pub_subject'),
 'role','authenticated','is_anonymous',false,
 'iat',(SELECT extract(epoch FROM tokens_valid_from)::bigint
        FROM app_private.principal_auth_bindings
        WHERE id='cccccccc-cccc-4ccc-8ccc-cccccccccccc'),
 'exp',extract(epoch FROM clock_timestamp()+interval '1 hour')::bigint)::text,true);
SELECT set_config('request.jwt.claim.sub',
 current_setting('schoolos_test.pub_subject'),true);
