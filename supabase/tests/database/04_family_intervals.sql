-- Structural FAMILY ceiling, authorization interval overlap, and revocation fields.
BEGIN;
CREATE EXTENSION IF NOT EXISTS pgtap WITH SCHEMA extensions;
SET LOCAL search_path = extensions, pg_catalog, public;
SELECT plan(16);

SET ROLE schoolos_schema_owner;
INSERT INTO app_private.principals (id,kind,label,system_purpose,state,created_by)
VALUES ('11111111-1111-4111-8111-111111111111','SYSTEM','Synthetic actor','identity-reconciliation','ACTIVE','11111111-1111-4111-8111-111111111111');
INSERT INTO app_private.people (id,display_name,created_by)
VALUES ('22222222-2222-4222-8222-222222222222','Synthetic person','11111111-1111-4111-8111-111111111111');
INSERT INTO app_private.principals (id,kind,person_id,label,state,created_by)
VALUES ('33333333-3333-4333-8333-333333333333','INDIVIDUAL','22222222-2222-4222-8222-222222222222','Synthetic staff','ACTIVE','11111111-1111-4111-8111-111111111111'),
       ('44444444-4444-4444-8444-444444444444','FAMILY',NULL,'Synthetic family','ACTIVE','11111111-1111-4111-8111-111111111111');
INSERT INTO app_private.roles (id,code,label,family_only,state,created_by)
VALUES ('55555555-5555-4555-8555-555555555555','STAFF_TEST','Synthetic staff role',false,'ACTIVE','11111111-1111-4111-8111-111111111111'),
       ('66666666-6666-4666-8666-666666666666','FAMILY_TEST','Synthetic family role',true,'ACTIVE','11111111-1111-4111-8111-111111111111');
INSERT INTO app_private.permissions (id,code,family_safe,state,created_by)
VALUES ('77777777-7777-4777-8777-777777777777','campus.view',false,'ENABLED','11111111-1111-4111-8111-111111111111');
RESET ROLE;

SELECT throws_ok($sql$INSERT INTO app_private.principal_role_assignments (principal_id,principal_kind,role_id,role_family_only,context_kind,valid_from,created_by) VALUES ('44444444-4444-4444-8444-444444444444','FAMILY','55555555-5555-4555-8555-555555555555',false,'FAMILY','2020-01-01 UTC','11111111-1111-4111-8111-111111111111')$sql$, '23514'::character(5), NULL::text, 'FAMILY cannot receive staff role');
SELECT throws_ok($sql$INSERT INTO app_private.role_permission_grants (role_id,role_family_only,permission_id,permission_family_safe,valid_from,created_by) VALUES ('66666666-6666-4666-8666-666666666666',true,'77777777-7777-4777-8777-777777777777',false,'2020-01-01 UTC','11111111-1111-4111-8111-111111111111')$sql$, '23514'::character(5), NULL::text, 'family-only role cannot receive unsafe permission');
INSERT INTO app_private.principal_role_assignments (id,principal_id,principal_kind,role_id,role_family_only,context_kind,valid_from,created_by)
VALUES ('88888888-8888-4888-8888-888888888888','44444444-4444-4444-8444-444444444444','FAMILY','66666666-6666-4666-8666-666666666666',true,'FAMILY','2020-01-01 UTC','11111111-1111-4111-8111-111111111111');
SELECT is((SELECT count(*) FROM app_private.principal_role_assignments WHERE principal_id='44444444-4444-4444-8444-444444444444'), 1::bigint, 'FAMILY may hold family-only role');

INSERT INTO app_private.role_permission_grants (id,role_id,role_family_only,permission_id,permission_family_safe,valid_from,valid_until,created_by)
VALUES ('90000000-0000-4000-8000-000000000001','55555555-5555-4555-8555-555555555555',false,'77777777-7777-4777-8777-777777777777',false,'2020-01-01 UTC','2020-02-01 UTC','11111111-1111-4111-8111-111111111111');
SELECT throws_ok($sql$INSERT INTO app_private.role_permission_grants (role_id,role_family_only,permission_id,permission_family_safe,valid_from,valid_until,created_by) VALUES ('55555555-5555-4555-8555-555555555555',false,'77777777-7777-4777-8777-777777777777',false,'2020-01-15 UTC','2020-02-15 UTC','11111111-1111-4111-8111-111111111111')$sql$, 'P0001'::character(5), NULL::text, 'overlapping role-permission grant rejected');
INSERT INTO app_private.role_permission_grants (id,role_id,role_family_only,permission_id,permission_family_safe,valid_from,valid_until,created_by)
VALUES ('90000000-0000-4000-8000-000000000002','55555555-5555-4555-8555-555555555555',false,'77777777-7777-4777-8777-777777777777',false,'2020-02-01 UTC','2020-03-01 UTC','11111111-1111-4111-8111-111111111111');
SELECT is((SELECT count(*) FROM app_private.role_permission_grants WHERE role_id='55555555-5555-4555-8555-555555555555'), 2::bigint, 'adjacent expired grants coexist');

INSERT INTO app_private.principal_role_assignments (id,principal_id,principal_kind,role_id,role_family_only,context_kind,valid_from,valid_until,created_by)
VALUES ('90000000-0000-4000-8000-000000000003','33333333-3333-4333-8333-333333333333','INDIVIDUAL','55555555-5555-4555-8555-555555555555',false,'INDIVIDUAL','2020-01-01 UTC','2020-02-01 UTC','11111111-1111-4111-8111-111111111111');
SELECT throws_ok($sql$INSERT INTO app_private.principal_role_assignments (principal_id,principal_kind,role_id,role_family_only,context_kind,valid_from,valid_until,created_by) VALUES ('33333333-3333-4333-8333-333333333333','INDIVIDUAL','55555555-5555-4555-8555-555555555555',false,'INDIVIDUAL','2020-01-15 UTC','2020-02-15 UTC','11111111-1111-4111-8111-111111111111')$sql$, 'P0001'::character(5), NULL::text, 'overlapping principal-role assignment rejected');
INSERT INTO app_private.principal_role_assignments (id,principal_id,principal_kind,role_id,role_family_only,context_kind,valid_from,valid_until,created_by)
VALUES ('90000000-0000-4000-8000-000000000004','33333333-3333-4333-8333-333333333333','INDIVIDUAL','55555555-5555-4555-8555-555555555555',false,'INDIVIDUAL','2020-02-01 UTC','2020-03-01 UTC','11111111-1111-4111-8111-111111111111');
SELECT is((SELECT count(*) FROM app_private.principal_role_assignments WHERE principal_id='33333333-3333-4333-8333-333333333333'), 2::bigint, 'adjacent expired assignments coexist');

INSERT INTO app_private.permission_scope_contracts (id,permission_id,scope_kind,resolver_key,enabled,created_by)
VALUES ('90000000-0000-4000-8000-000000000005','77777777-7777-4777-8777-777777777777','ALL','DIRECT',true,'11111111-1111-4111-8111-111111111111');
INSERT INTO app_private.assignment_permission_scopes (id,assignment_id,grant_id,role_id,permission_id,scope_contract_id,scope_kind,resolver_key,valid_from,valid_until,created_by)
VALUES ('90000000-0000-4000-8000-000000000006','90000000-0000-4000-8000-000000000003','90000000-0000-4000-8000-000000000001','55555555-5555-4555-8555-555555555555','77777777-7777-4777-8777-777777777777','90000000-0000-4000-8000-000000000005','ALL','DIRECT','2020-01-01 UTC','2020-02-01 UTC','11111111-1111-4111-8111-111111111111');
SELECT throws_ok($sql$INSERT INTO app_private.assignment_permission_scopes (assignment_id,grant_id,role_id,permission_id,scope_contract_id,scope_kind,resolver_key,valid_from,valid_until,created_by) VALUES ('90000000-0000-4000-8000-000000000003','90000000-0000-4000-8000-000000000001','55555555-5555-4555-8555-555555555555','77777777-7777-4777-8777-777777777777','90000000-0000-4000-8000-000000000005','ALL','DIRECT','2020-01-15 UTC','2020-02-15 UTC','11111111-1111-4111-8111-111111111111')$sql$, 'P0001'::character(5), NULL::text, 'overlapping assignment scope rejected');
INSERT INTO app_private.assignment_permission_scopes (id,assignment_id,grant_id,role_id,permission_id,scope_contract_id,scope_kind,resolver_key,valid_from,valid_until,created_by)
VALUES ('90000000-0000-4000-8000-000000000007','90000000-0000-4000-8000-000000000003','90000000-0000-4000-8000-000000000001','55555555-5555-4555-8555-555555555555','77777777-7777-4777-8777-777777777777','90000000-0000-4000-8000-000000000005','ALL','DIRECT','2020-02-01 UTC','2020-03-01 UTC','11111111-1111-4111-8111-111111111111');
SELECT is((SELECT count(*) FROM app_private.assignment_permission_scopes WHERE assignment_id='90000000-0000-4000-8000-000000000003'), 2::bigint, 'adjacent expired scopes coexist');

UPDATE app_private.role_permission_grants SET revoked_at=clock_timestamp() WHERE id='90000000-0000-4000-8000-000000000001';
SELECT ok((SELECT revoked_at IS NOT NULL FROM app_private.role_permission_grants WHERE id='90000000-0000-4000-8000-000000000001'), 'grant revocation marker may be set');
SELECT throws_ok($sql$UPDATE app_private.role_permission_grants SET revoked_at=NULL WHERE id='90000000-0000-4000-8000-000000000001'$sql$, 'P0001'::character(5), NULL::text, 'grant revocation marker cannot clear');
SELECT throws_ok($sql$UPDATE app_private.role_permission_grants SET revoked_at=clock_timestamp() + interval '1 second' WHERE id='90000000-0000-4000-8000-000000000001'$sql$, 'P0001'::character(5), NULL::text, 'grant revocation marker cannot change');
UPDATE app_private.principal_role_assignments SET revoked_at=clock_timestamp() WHERE id='90000000-0000-4000-8000-000000000003';
SELECT ok((SELECT revoked_at IS NOT NULL FROM app_private.principal_role_assignments WHERE id='90000000-0000-4000-8000-000000000003'), 'assignment revocation marker may be set');
SELECT throws_ok($sql$UPDATE app_private.principal_role_assignments SET revoked_at=NULL WHERE id='90000000-0000-4000-8000-000000000003'$sql$, 'P0001'::character(5), NULL::text, 'assignment revocation marker cannot clear');
UPDATE app_private.assignment_permission_scopes SET revoked_at=clock_timestamp() WHERE id='90000000-0000-4000-8000-000000000006';
SELECT ok((SELECT revoked_at IS NOT NULL FROM app_private.assignment_permission_scopes WHERE id='90000000-0000-4000-8000-000000000006'), 'scope revocation marker may be set');
SELECT throws_ok($sql$UPDATE app_private.assignment_permission_scopes SET revoked_at=NULL WHERE id='90000000-0000-4000-8000-000000000006'$sql$, 'P0001'::character(5), NULL::text, 'scope revocation marker cannot clear');

SELECT * FROM finish();
ROLLBACK;
