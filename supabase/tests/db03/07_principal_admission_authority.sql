BEGIN;
CREATE EXTENSION IF NOT EXISTS pgtap WITH SCHEMA extensions;
SET LOCAL search_path=extensions,pg_catalog,public;
SELECT plan(27);
\ir fixtures/policy_publication_actor.sql
\ir fixtures/intake_grace_actor.sql
\ir fixtures/original_identity_actor.sql
\ir fixtures/person_creation_actor.sql
UPDATE app_private.operation_contracts SET enabled=true WHERE code LIKE 'admission.%';
-- The same authenticated person holds both roles. Giving administrators every
-- operation permission must still not turn their chain into principal authority.
INSERT INTO app_private.roles(id,code,label,state,created_by)
VALUES('71717171-7171-4171-8171-717171717171','ADMINISTRATOR','Principal','ACTIVE','11111111-1111-4111-8111-111111111111');
INSERT INTO app_private.principal_role_assignments(id,principal_id,principal_kind,role_id,role_family_only,context_kind,valid_from,created_by)
VALUES('72727272-7272-4272-8272-727272727272','bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb','INDIVIDUAL','71717171-7171-4171-8171-717171717171',false,'INDIVIDUAL',clock_timestamp()-interval '1 hour','11111111-1111-4111-8111-111111111111');
INSERT INTO app_private.role_permission_grants(id,role_id,role_family_only,permission_id,permission_family_safe,valid_from,created_by)
SELECT md5(p.code||':admin-grant')::uuid,'71717171-7171-4171-8171-717171717171',false,p.id,false,clock_timestamp()-interval '1 hour','11111111-1111-4111-8111-111111111111'
FROM app_private.permissions p WHERE p.code LIKE 'admission.%';
INSERT INTO app_private.assignment_permission_scopes(id,assignment_id,grant_id,role_id,permission_id,scope_contract_id,scope_kind,resolver_key,valid_from,created_by)
SELECT md5(p.code||':admin-scope')::uuid,'72727272-7272-4272-8272-727272727272',md5(p.code||':admin-grant')::uuid,'71717171-7171-4171-8171-717171717171',p.id,c.id,'ALL','DIRECT',clock_timestamp()-interval '1 hour','11111111-1111-4111-8111-111111111111'
FROM app_private.permissions p JOIN app_private.permission_scope_contracts c ON c.permission_id=p.id AND c.scope_kind='ALL' AND c.resolver_key='DIRECT'
WHERE p.code LIKE 'admission.%';
SAVEPOINT admin_only;
UPDATE app_private.principal_role_assignments SET revoked_at=clock_timestamp() WHERE id='abababab-abab-4bab-8bab-abababababab';
SET ROLE authenticated;
SELECT * FROM app.create_admission_draft('91919191-9191-4191-8191-919191919191','93939393-9393-4393-8393-939393939393','principal-admin-intake') \gset admin_
SELECT ok(:'admin_application_id'::uuid IS NOT NULL,'administrator can create unresolved application');
SELECT throws_ok(format($q$SELECT * FROM app.attest_admission_original_identity(%L,1,'61616161-6161-4161-8161-616161616161',1,'Original','Reason','admin-attest')$q$,:'admin_application_id'),'P0001'::char(5),'DB03 identity School ALL authority denied'::text,'administrator with exact permission cannot attest identity');
SELECT throws_ok(format($q$SELECT * FROM app.check_admission_person_candidates(%L,1,'RashidUnique','admin-check')$q$,:'admin_application_id'),'P0001'::char(5),'DB03 Person School ALL authority denied'::text,'administrator cannot use principal identity discovery');
SELECT throws_ok(format($q$SELECT * FROM app.create_admission_person(%L,1,'77777777-7777-4777-8777-777777777777','Original','Reason','admin-person')$q$,:'admin_application_id'),'P0001'::char(5),'DB03 Person School ALL authority denied'::text,'administrator cannot create an attested identity');
RESET ROLE;
SELECT ok((SELECT person_id IS NULL AND state='DRAFT' AND row_version=1 FROM app_private.admission_applications WHERE id=:'admin_application_id'),'denials preserve unresolved pending intake');
SELECT is((SELECT count(*) FROM app_private.command_receipts WHERE command_kind IN('admission.identity.attest','admission.person.check','admission.person.create')),0::bigint,'denied administrator operations have no receipts');
SELECT is((SELECT label FROM app_private.roles WHERE code='ADMINISTRATOR'),'Principal'::text,'a principal display label is deliberately insufficient');
SELECT throws_ok($q$UPDATE app_private.roles SET code='PRINCIPAL' WHERE code='ADMINISTRATOR'$q$,'P0001'::char(5),'roles: immutable field changed'::text,'administrator role code cannot be renamed to elevate authority');
ROLLBACK TO SAVEPOINT admin_only;
SET ROLE authenticated;
SELECT * FROM app.create_admission_draft('91919191-9191-4191-8191-919191919191','93939393-9393-4393-8393-939393939393','principal-existing') \gset existing_
SELECT * FROM app.create_admission_draft('91919191-9191-4191-8191-919191919191','93939393-9393-4393-8393-939393939393','principal-new') \gset new_
RESET ROLE;
SAVEPOINT missing_principal_grants;
UPDATE app_private.role_permission_grants SET revoked_at=clock_timestamp() WHERE role_id='dddddddd-dddd-4ddd-8ddd-dddddddddddd' AND permission_id IN(SELECT id FROM app_private.permissions WHERE code IN('admission.identity.attest','admission.person.check','admission.person.create'));
SET ROLE authenticated;
SELECT throws_ok(format($q$SELECT * FROM app.attest_admission_original_identity(%L,1,'61616161-6161-4161-8161-616161616161',1,'Original','Reason','mixed-attest')$q$,:'existing_application_id'),'P0001'::char(5),'DB03 identity School ALL authority denied'::text,'principal membership cannot borrow administrator attestation permission');
SELECT throws_ok(format($q$SELECT * FROM app.check_admission_person_candidates(%L,1,'RashidUnique','mixed-check')$q$,:'new_application_id'),'P0001'::char(5),'DB03 Person School ALL authority denied'::text,'principal membership cannot borrow administrator discovery permission');
SELECT throws_ok(format($q$SELECT * FROM app.create_admission_person(%L,1,'77777777-7777-4777-8777-777777777777','Original','Reason','mixed-create')$q$,:'new_application_id'),'P0001'::char(5),'DB03 Person School ALL authority denied'::text,'principal membership cannot borrow administrator creation permission');
RESET ROLE;
ROLLBACK TO SAVEPOINT missing_principal_grants;
SAVEPOINT retired_principal;
UPDATE app_private.roles SET state='RETIRED' WHERE code='PRINCIPAL';
SET ROLE authenticated;
SELECT throws_ok(format($q$SELECT * FROM app.attest_admission_original_identity(%L,1,'61616161-6161-4161-8161-616161616161',1,'Original','Reason','retired-attest')$q$,:'existing_application_id'),'P0001'::char(5),'DB03 identity School ALL authority denied'::text,'retired principal role denies attestation despite active administrator');
SELECT throws_ok(format($q$SELECT * FROM app.check_admission_person_candidates(%L,1,'RashidUnique','retired-check')$q$,:'new_application_id'),'P0001'::char(5),'DB03 Person School ALL authority denied'::text,'retired principal role denies Person commands');
RESET ROLE;
ROLLBACK TO SAVEPOINT retired_principal;
SAVEPOINT revoked_principal_scope;
UPDATE app_private.assignment_permission_scopes SET revoked_at=clock_timestamp() WHERE role_id='dddddddd-dddd-4ddd-8ddd-dddddddddddd' AND permission_id IN(SELECT id FROM app_private.permissions WHERE code IN('admission.identity.attest','admission.person.check','admission.person.create'));
SET ROLE authenticated;
SELECT throws_ok(format($q$SELECT * FROM app.attest_admission_original_identity(%L,1,'61616161-6161-4161-8161-616161616161',1,'Original','Reason','scope-attest')$q$,:'existing_application_id'),'P0001'::char(5),'DB03 identity School ALL authority denied'::text,'revoked principal scope denies identity attestation');
SELECT throws_ok(format($q$SELECT * FROM app.check_admission_person_candidates(%L,1,'RashidUnique','scope-check')$q$,:'new_application_id'),'P0001'::char(5),'DB03 Person School ALL authority denied'::text,'revoked principal scope denies discovery');
RESET ROLE;
ROLLBACK TO SAVEPOINT revoked_principal_scope;
SET ROLE authenticated;
SELECT * FROM app.attest_admission_original_identity(:'existing_application_id',1,'61616161-6161-4161-8161-616161616161',1,'Private original','Principal inspection','principal-attest') \gset attested_
SELECT ok(:'attested_resolution_id'::uuid IS NOT NULL,'principal with exact current permission can attest existing identity');
SELECT * FROM app.check_admission_person_candidates(:'new_application_id',1,'RashidUnique','principal-check') \gset checked_
SELECT is(:'checked_candidate_count'::bigint,0::bigint,'principal can perform school-wide candidate check');
SELECT * FROM app.create_admission_person(:'new_application_id',1,:'checked_check_id','Private original','Principal inspection after duplicate check','principal-create') \gset created_
SELECT ok(:'created_person_id'::uuid IS NOT NULL,'principal can create attested canonical Person');
RESET ROLE;
SELECT ok((SELECT state='DRAFT' AND person_id=:'created_person_id'::uuid FROM app_private.admission_applications WHERE id=:'new_application_id'),'identity creation alone never submits application');
SELECT is((SELECT count(*) FROM app_private.admission_person_creations),1::bigint,'one real Person creation source');
SELECT is((SELECT count(*) FROM app_private.admission_identity_resolutions),2::bigint,'original inspections retain both principal decisions');
UPDATE app_private.principal_role_assignments SET revoked_at=clock_timestamp() WHERE id='abababab-abab-4bab-8bab-abababababab';
SET ROLE authenticated;
SELECT throws_ok(format($q$SELECT * FROM app.attest_admission_original_identity(%L,1,'61616161-6161-4161-8161-616161616161',1,'Private original','Principal inspection','principal-attest')$q$,:'existing_application_id'),'P0001'::char(5),'DB03 identity School ALL authority denied'::text,'revoked principal assignment blocks historical attestation replay');
SELECT throws_ok(format($q$SELECT * FROM app.check_admission_person_candidates(%L,1,'RashidUnique','principal-check')$q$,:'new_application_id'),'P0001'::char(5),'DB03 Person School ALL authority denied'::text,'revoked principal assignment blocks historical candidate replay');
SELECT throws_ok(format($q$SELECT * FROM app.create_admission_person(%L,1,%L,'Private original','Principal inspection after duplicate check','principal-create')$q$,:'new_application_id',:'checked_check_id'),'P0001'::char(5),'DB03 Person School ALL authority denied'::text,'revoked principal assignment blocks historical Person creation replay');
RESET ROLE;
SELECT is((SELECT count(*) FROM app_private.admission_person_creations),1::bigint,'denied replay never duplicates Person');
SELECT is((SELECT count(*) FROM app_private.command_receipts WHERE command_kind='admission.identity.attest'),1::bigint,'denied replay never duplicates attestation evidence');
SELECT ok(NOT has_table_privilege('authenticated','app_private.roles','INSERT,UPDATE,DELETE'),'clients cannot manufacture the deployment principal role');
SELECT * FROM finish();
ROLLBACK;
