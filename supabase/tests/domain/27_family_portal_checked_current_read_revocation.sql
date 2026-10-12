-- D1 Family portal typed checked-read: current membership + entitlement + relationship + live grant.
-- Synthetic disposable-stack acceptance for existing typed checked-read endpoints; not a new API.
BEGIN;
CREATE EXTENSION IF NOT EXISTS pgtap WITH SCHEMA extensions;
SET LOCAL search_path=extensions,pg_catalog,public;
SELECT plan(69);
\ir fixtures/command_actor.sql

SET ROLE schoolos_schema_owner;
UPDATE app_private.permissions SET state='ENABLED'
 WHERE code='family.child_access.change';
UPDATE app_private.operation_contracts SET enabled=true
 WHERE code='family.child_access.change';
UPDATE app_private.permission_scope_contracts SET enabled=true
 WHERE scope_kind='ALL' AND resolver_key='DIRECT'
 AND permission_id=(SELECT id FROM app_private.permissions WHERE code='family.child_access.change');

INSERT INTO app_private.role_permission_grants(
 id,role_id,role_family_only,permission_id,permission_family_safe,valid_from,created_by)
SELECT '64000000-0000-4000-8000-000000000012','aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',false,id,false,
 statement_timestamp()-interval '1 hour','11111111-1111-4111-8111-111111111111'
FROM app_private.permissions WHERE code='family.child_access.change';
INSERT INTO app_private.assignment_permission_scopes(
 id,assignment_id,grant_id,role_id,permission_id,scope_contract_id,
 scope_kind,resolver_key,valid_from,created_by)
SELECT '64000000-0000-4000-8000-000000000013','ffffffff-ffff-4fff-8fff-ffffffffffff',g.id,g.role_id,g.permission_id,c.id,
 'ALL','DIRECT',statement_timestamp()-interval '1 hour','11111111-1111-4111-8111-111111111111'
FROM app_private.role_permission_grants g
JOIN app_private.permission_scope_contracts c ON c.permission_id=g.permission_id
WHERE g.id='64000000-0000-4000-8000-000000000012' AND c.scope_kind='ALL' AND c.resolver_key='DIRECT';

INSERT INTO app_private.students(
 id,person_id,school_student_id,admission_number,admission_serial,admitted_on,current_status,created_by)
VALUES
 ('64000000-0000-4000-8000-000000000002','10000000-0000-4000-8000-000000000001','FAMILY-A','FAM-0001',1,CURRENT_DATE-20,'ACTIVE','11111111-1111-4111-8111-111111111111'),
 ('64000000-0000-4000-8000-000000000003','10000000-0000-4000-8000-000000000002','FAMILY-B','FAM-0002',2,CURRENT_DATE-20,'ACTIVE','11111111-1111-4111-8111-111111111111');
INSERT INTO app_private.student_status_transitions(
 student_id,previous_status,new_status,effective_on,sequence_number,reason,created_by)
VALUES
 ('64000000-0000-4000-8000-000000000002',NULL,'ACTIVE',CURRENT_DATE-20,1,'Synthetic initial status','11111111-1111-4111-8111-111111111111'),
 ('64000000-0000-4000-8000-000000000003',NULL,'ACTIVE',CURRENT_DATE-20,1,'Synthetic initial status','11111111-1111-4111-8111-111111111111');
INSERT INTO app_private.families(id,school_id,code,display_label,created_by)
VALUES ('64000000-0000-4000-8000-000000000001','22222222-2222-4222-8222-222222222222','FAM-001','Family A','11111111-1111-4111-8111-111111111111');
INSERT INTO app_private.approval_policy_versions(
 id,policy_key,version,operation_id,d1_route_mode,created_by)
SELECT '64000000-0000-4000-8000-000000000014','d1-test-family-child-access-direct',1,id,'DIRECT','11111111-1111-4111-8111-111111111111'
FROM app_private.operation_contracts WHERE code='family.child_access.change';
UPDATE app_private.approval_policy_versions
 SET state='ACTIVE',effective_from=statement_timestamp()-interval '1 hour',
 activated_at=statement_timestamp() WHERE id='64000000-0000-4000-8000-000000000014';
RESET ROLE;

-- Client table access is denied even if a Student UUID is known.
SET ROLE authenticated;
SELECT throws_ok($sql$SELECT * FROM app_private.students$sql$,
 '42501'::char(5),NULL::text,'authenticated cannot query private Student rows');
SELECT throws_ok($sql$SELECT * FROM app_private.family_relationships$sql$,
 '42501'::char(5),NULL::text,'authenticated cannot enumerate private relationships');
SELECT throws_ok($sql$SELECT * FROM app_private.family_student_access$sql$,
 '42501'::char(5),NULL::text,'authenticated cannot enumerate family child entitlements');
SELECT throws_ok(format($sql$SELECT * FROM app.d1_change_family_child_access(
 '64000000-0000-4000-8000-000000000002',1,'64000000-0000-4000-8000-000000000001',1,'ADD',NULL,
 CURRENT_DATE-5,NULL,'Authorized child portal entitlement','no-credential')$sql$),
 'P0001'::char(5),
 'D1 Family child access preflight denied: D1_FAMILY_CHILD_ACCESS_FAMILY_CREDENTIAL_NOT_READY'::text,
 'relationship-free Family with no shared FAMILY credential cannot gain child access');
RESET ROLE;
SELECT is((SELECT count(*) FROM app_private.family_student_access),0::bigint,
 'credential denial cannot insert any child entitlement');

-- Create a REAL, currently valid FAMILY-only / family-safe / OWN child authorization chain.
-- Being eligible for Family membership is still not a child-specific access entitlement.
SELECT set_config('schoolos_test.family_subject',
 (SELECT id::text FROM auth.users WHERE email='foundation-family-001@example.invalid'),true);
SET ROLE schoolos_schema_owner;
UPDATE app_private.permissions SET state='ENABLED'
 WHERE code='family.summary.view';
UPDATE app_private.permission_scope_contracts SET enabled=true
 WHERE scope_kind='OWN' AND resolver_key='D1_FAMILY_CHILD'
 AND permission_id=(SELECT id FROM app_private.permissions WHERE code='family.summary.view');
INSERT INTO app_private.principals(id,kind,label,state,created_by) VALUES
 ('64000000-0000-4000-8000-000000000005','FAMILY','Shared Family A login','ACTIVE','11111111-1111-4111-8111-111111111111');
INSERT INTO app_private.principal_auth_bindings(
 id,principal_id,principal_kind,auth_user_id,bound_at,tokens_valid_from,created_by)
VALUES ('64000000-0000-4000-8000-000000000010',
 '64000000-0000-4000-8000-000000000005','FAMILY',
 current_setting('schoolos_test.family_subject')::uuid,
 clock_timestamp(),to_timestamp(floor(extract(epoch FROM clock_timestamp()))),
 '11111111-1111-4111-8111-111111111111');
INSERT INTO app_private.roles(id,code,label,family_only,state,created_by) VALUES
 ('64000000-0000-4000-8000-000000000006','d1-test-family-child-role','Family child view',true,'ACTIVE','11111111-1111-4111-8111-111111111111');
INSERT INTO app_private.principal_role_assignments(
 id,principal_id,principal_kind,role_id,role_family_only,context_kind,valid_from,created_by)
VALUES ('64000000-0000-4000-8000-000000000007','64000000-0000-4000-8000-000000000005','FAMILY','64000000-0000-4000-8000-000000000006',true,'FAMILY',
 statement_timestamp()-interval '1 hour','11111111-1111-4111-8111-111111111111');
INSERT INTO app_private.role_permission_grants(
 id,role_id,role_family_only,permission_id,permission_family_safe,valid_from,created_by)
SELECT '64000000-0000-4000-8000-000000000008','64000000-0000-4000-8000-000000000006',true,p.id,true,
 statement_timestamp()-interval '1 hour','11111111-1111-4111-8111-111111111111'
FROM app_private.permissions p WHERE p.code='family.summary.view';
INSERT INTO app_private.assignment_permission_scopes(
 id,assignment_id,grant_id,role_id,permission_id,scope_contract_id,
 scope_kind,resolver_key,valid_from,created_by)
SELECT '64000000-0000-4000-8000-000000000009','64000000-0000-4000-8000-000000000007',g.id,'64000000-0000-4000-8000-000000000006',g.permission_id,c.id,
 'OWN','D1_FAMILY_CHILD',statement_timestamp()-interval '1 hour','11111111-1111-4111-8111-111111111111'
FROM app_private.role_permission_grants g
JOIN app_private.permission_scope_contracts c ON c.permission_id=g.permission_id
WHERE g.id='64000000-0000-4000-8000-000000000008' AND c.scope_kind='OWN' AND c.resolver_key='D1_FAMILY_CHILD';
INSERT INTO app_private.family_principal_memberships(
 id,family_id,principal_id,principal_kind,effective_from,reason,created_by)
VALUES ('64000000-0000-4000-8000-000000000011','64000000-0000-4000-8000-000000000001','64000000-0000-4000-8000-000000000005','FAMILY',CURRENT_DATE-20,
 'Synthetic shared Family credential membership','11111111-1111-4111-8111-111111111111');
RESET ROLE;

SELECT is((SELECT count(*) FROM app_private.principal_auth_bindings
 WHERE principal_id='64000000-0000-4000-8000-000000000005'),1::bigint,
 'shared FAMILY Principal has one synthetic auth binding');
SELECT is((SELECT count(*) FROM app_private.family_principal_memberships
 WHERE family_id='64000000-0000-4000-8000-000000000001' AND principal_id='64000000-0000-4000-8000-000000000005'),1::bigint,
 'Family membership is distinct from any child entitlement');
SELECT is((SELECT count(*) FROM app_private.family_student_access),0::bigint,
 'family membership alone creates no child access');

SET ROLE authenticated;
SELECT throws_ok(format($sql$SELECT * FROM app.d1_change_family_child_access(
 '64000000-0000-4000-8000-000000000002',1,'64000000-0000-4000-8000-000000000001',1,'ADD',NULL,
 CURRENT_DATE-5,NULL,'Authorized child portal entitlement','no-relationship')$sql$),
 'P0001'::char(5),
 'D1 Family child access preflight denied: D1_FAMILY_CHILD_ACCESS_RELATIONSHIP_BASIS_GAP'::text,
 'valid shared Family credential does not replace Student relationship evidence');
RESET ROLE;

-- The relationship grants no entitlement until a distinct child-access ADD succeeds.
SET ROLE schoolos_schema_owner;
INSERT INTO app_private.family_relationships(
 id,family_id,student_id,adult_person_id,relationship_kind,display_name,
 effective_from,reason,created_by)
VALUES ('64000000-0000-4000-8000-000000000004','64000000-0000-4000-8000-000000000001','64000000-0000-4000-8000-000000000002',
 '10000000-0000-4000-8000-000000000003','GUARDIAN','Synthetic guardian A',
 CURRENT_DATE-20,'Approved relationship basis','11111111-1111-4111-8111-111111111111');
RESET ROLE;
SELECT is((SELECT count(*) FROM app_private.family_relationships
 WHERE family_id='64000000-0000-4000-8000-000000000001' AND student_id='64000000-0000-4000-8000-000000000002'),1::bigint,
 'Student A relationship basis is retained');
SELECT is((SELECT count(*) FROM app_private.family_student_access),0::bigint,
 'relationship alone still grants no portal entitlement');
SET ROLE authenticated;
SELECT throws_ok(format($sql$SELECT * FROM app.d1_change_family_child_access(
 '64000000-0000-4000-8000-000000000003',1,'64000000-0000-4000-8000-000000000001',1,'ADD',NULL,
 CURRENT_DATE-5,NULL,'Authorized child portal entitlement','unrelated-b')$sql$),
 'P0001'::char(5),
 'D1 Family child access preflight denied: D1_FAMILY_CHILD_ACCESS_RELATIONSHIP_BASIS_GAP'::text,
 'Student B UUID cannot use Student A Family relationship basis');
RESET ROLE;
SELECT is((SELECT count(*) FROM app_private.family_student_access
 WHERE student_id='64000000-0000-4000-8000-000000000003'),0::bigint,'unrelated Student B never gains portal access');

SET ROLE authenticated;
SELECT * FROM app.d1_change_family_child_access(
 '64000000-0000-4000-8000-000000000002',1,'64000000-0000-4000-8000-000000000001',1,'ADD',NULL,
 CURRENT_DATE-5,NULL,'Authorized child portal entitlement','linked-a') \gset first_
SELECT is(:'first_action','ADD'::text,'authorized linked Student A ADD succeeds');
SELECT is(:'first_student_version'::bigint,2::bigint,'Student A version advances atomically');
SELECT is(:'first_family_version'::bigint,2::bigint,'Family version advances atomically');
SELECT * FROM app.d1_change_family_child_access(
 '64000000-0000-4000-8000-000000000002',1,'64000000-0000-4000-8000-000000000001',1,'ADD',NULL,
 CURRENT_DATE-5,NULL,'Authorized child portal entitlement','linked-a') \gset add_replay_
SELECT is(:'add_replay_access_id'::uuid,:'first_access_id'::uuid,
 'ADD replay returns retained original child-access ID');
SELECT is(:'add_replay_student_version'::bigint,2::bigint,
 'ADD replay preserves accepted Student version');
SELECT throws_ok(format($sql$SELECT * FROM app.d1_change_family_child_access(
 '64000000-0000-4000-8000-000000000002',2,'64000000-0000-4000-8000-000000000001',2,'ADD',NULL,
 CURRENT_DATE-5,NULL,'Authorized child portal entitlement','overlap-a')$sql$),
 'P0001'::char(5),
 'D1 Family child access preflight denied: D1_FAMILY_CHILD_ACCESS_OVERLAP'::text,
 'new key cannot grant overlapping Family/Student access');
RESET ROLE;
SELECT is((SELECT count(*) FROM app_private.family_student_access
 WHERE family_id='64000000-0000-4000-8000-000000000001' AND student_id='64000000-0000-4000-8000-000000000002'),1::bigint,
 'successful ADD and replay write exactly one retained entitlement');
SELECT is((SELECT count(*) FROM app_private.family_student_access
 WHERE student_id='64000000-0000-4000-8000-000000000003'),0::bigint,
 'successful Student A access never grants Student B access');


-- The exact Family summary permission does not automatically permit
-- relationship, Student roster/profile, restricted identity or historic reads.
-- All client-visible reads are fixed typed RPCs; never select raw private tables.
SELECT set_config('request.jwt.claim.sub',current_setting('schoolos_test.family_subject'),true);
SELECT set_config('request.jwt.claims',jsonb_build_object(
 'sub',current_setting('schoolos_test.family_subject'),'role','authenticated',
 'iat',(SELECT extract(epoch FROM tokens_valid_from)::bigint
 FROM app_private.principal_auth_bindings
 WHERE id='64000000-0000-4000-8000-000000000010'),
 'is_anonymous',false)::text,true);
SET ROLE authenticated;
SELECT is((SELECT count(*) FROM app.d1_read_family_summary_for_student(
 '64000000-0000-4000-8000-000000000002')),1::bigint,
 'FAMILY login reads exact currently authorized Student A Family summary');
SELECT is((SELECT family_id FROM app.d1_read_family_summary_for_student(
 '64000000-0000-4000-8000-000000000002')),
 '64000000-0000-4000-8000-000000000001'::uuid,
 'Family summary exposes only the linked Family identity');
SELECT is((SELECT student_id FROM app.d1_read_family_summary_for_student(
 '64000000-0000-4000-8000-000000000002')),
 '64000000-0000-4000-8000-000000000002'::uuid,
 'Family summary binds Student A exactly, not a supplied unrelated student');
SELECT is((SELECT family_label FROM app.d1_read_family_summary_for_student(
 '64000000-0000-4000-8000-000000000002')),
 'Family A'::text,'Family summary exposes reviewed Family display label');
SELECT is((SELECT count(*) FROM app.d1_read_family_summary_for_student(
 '64000000-0000-4000-8000-000000000002') summary
 CROSS JOIN LATERAL jsonb_object_keys(to_jsonb(summary)) exposed(field)),4::bigint,
 'Family summary exposes exactly four typed fields, not the entire Student row');
SELECT is((SELECT count(*) FROM app.d1_read_family_summary_for_student(
 '64000000-0000-4000-8000-000000000002') summary
 WHERE to_jsonb(summary) ?| ARRAY['national_id','date_of_birth','family_version',
 'guardian_contact','private_address','disability_indicator','admission_number']),0::bigint,
 'Family summary has no restricted identity, special, contact or internal values');
SELECT is((SELECT count(*) FROM app.d1_read_family_summary_for_student(
 '64000000-0000-4000-8000-000000000003')),0::bigint,
 'knowing Student B UUID cannot expose unrelated child Family summary');
SELECT is((SELECT count(*) FROM app.d1_read_family_summary_for_student(
 '00000000-0000-4000-8000-000000000000')),0::bigint,
 'unknown Student UUID returns no family summary');
SELECT is((SELECT count(*) FROM app.d1_read_family_summary_for_student(NULL::uuid)),0::bigint,
 'NULL target cannot enumerate linked child summaries');
SELECT is((SELECT count(*) FROM app.d1_read_family_relationships_for_student(
 '64000000-0000-4000-8000-000000000002')),0::bigint,
 'family.summary.view does not grant separate family.relationship.view');
SELECT is((SELECT count(*) FROM app.d1_read_family_relationship_history(
 '64000000-0000-4000-8000-000000000002')),0::bigint,
 'current Family summary does not grant historical relationship disclosure');
SELECT is((SELECT count(*) FROM app.d1_read_student_roster(
 '64000000-0000-4000-8000-000000000002')),0::bigint,
 'Family summary grant does not grant Student roster permission');
SELECT is((SELECT count(*) FROM app.d1_read_student_profile(
 '64000000-0000-4000-8000-000000000002')),0::bigint,
 'Family summary grant does not grant Student profile permission');
SELECT is((SELECT count(*) FROM app.d1_read_student_restricted_identity(
 '64000000-0000-4000-8000-000000000002')),0::bigint,
 'FAMILY has no restricted identity disclosure through summary permission');
SELECT is((SELECT count(*) FROM app.d1_read_student_special(
 '64000000-0000-4000-8000-000000000002')),0::bigint,
 'FAMILY has no sensitive Student Special disclosure');
SELECT throws_ok($sql$SELECT * FROM app_private.family_student_access$sql$,
 '42501'::char(5),NULL::text,
 'authenticated FAMILY cannot SELECT raw child-entitlement history');
SELECT throws_ok($sql$SELECT * FROM app_private.family_relationships$sql$,
 '42501'::char(5),NULL::text,
 'authenticated FAMILY cannot enumerate raw Guardian relationships');
SELECT throws_ok($sql$SELECT * FROM app_private.students$sql$,
 '42501'::char(5),NULL::text,
 'authenticated FAMILY cannot query raw Student profiles');
RESET ROLE;

-- A separate family-safe permission and OWN/D1_FAMILY_CHILD scope is
-- required for current relationship display; it never grants history.
SET ROLE schoolos_schema_owner;
UPDATE app_private.permissions SET state='ENABLED'
 WHERE code='family.relationship.view';
UPDATE app_private.permission_scope_contracts SET enabled=true
 WHERE scope_kind='OWN' AND resolver_key='D1_FAMILY_CHILD'
 AND permission_id=(SELECT id FROM app_private.permissions
 WHERE code='family.relationship.view');
INSERT INTO app_private.role_permission_grants(
 id,role_id,role_family_only,permission_id,permission_family_safe,valid_from,created_by)
SELECT '64000000-0000-4000-8000-000000000020',
 '64000000-0000-4000-8000-000000000006',true,p.id,true,
 statement_timestamp()-interval '1 hour','11111111-1111-4111-8111-111111111111'
FROM app_private.permissions p WHERE p.code='family.relationship.view';
INSERT INTO app_private.assignment_permission_scopes(
 id,assignment_id,grant_id,role_id,permission_id,scope_contract_id,
 scope_kind,resolver_key,valid_from,created_by)
SELECT '64000000-0000-4000-8000-000000000021',
 '64000000-0000-4000-8000-000000000007',g.id,g.role_id,g.permission_id,c.id,
 'OWN','D1_FAMILY_CHILD',statement_timestamp()-interval '1 hour',
 '11111111-1111-4111-8111-111111111111'
FROM app_private.role_permission_grants g
JOIN app_private.permission_scope_contracts c ON c.permission_id=g.permission_id
WHERE g.id='64000000-0000-4000-8000-000000000020'
 AND c.scope_kind='OWN' AND c.resolver_key='D1_FAMILY_CHILD';
RESET ROLE;

SELECT set_config('request.jwt.claim.sub',current_setting('schoolos_test.family_subject'),true);
SELECT set_config('request.jwt.claims',jsonb_build_object(
 'sub',current_setting('schoolos_test.family_subject'),'role','authenticated',
 'iat',(SELECT extract(epoch FROM tokens_valid_from)::bigint
 FROM app_private.principal_auth_bindings
 WHERE id='64000000-0000-4000-8000-000000000010'),
 'is_anonymous',false)::text,true);
SET ROLE authenticated;
SELECT is((SELECT count(*) FROM app.d1_read_family_relationships_for_student(
 '64000000-0000-4000-8000-000000000002')),1::bigint,
 'separate live family.relationship.view allows exact linked current relationship');
SELECT is((SELECT relationship_kind FROM app.d1_read_family_relationships_for_student(
 '64000000-0000-4000-8000-000000000002')),
 'GUARDIAN'::text,'current relationship returns only authorized kind');
SELECT is((SELECT adult_display_name FROM app.d1_read_family_relationships_for_student(
 '64000000-0000-4000-8000-000000000002')),
 'Synthetic guardian A'::text,'current relationship allows reviewed adult display');
SELECT is((SELECT count(*) FROM app.d1_read_family_relationships_for_student(
 '64000000-0000-4000-8000-000000000002') rel
 CROSS JOIN LATERAL jsonb_object_keys(to_jsonb(rel)) exposed(field)),3::bigint,
 'Family relationship exposes exactly three permitted current display fields');
SELECT is((SELECT count(*) FROM app.d1_read_family_relationships_for_student(
 '64000000-0000-4000-8000-000000000002') rel
 WHERE to_jsonb(rel) ?| ARRAY['adult_person_id','guardian_contact','relationship_id',
 'reason','created_by','national_id']),0::bigint,
 'current Family relationship read has no Person ID, contacts or history evidence');
SELECT is((SELECT count(*) FROM app.d1_read_family_relationships_for_student(
 '64000000-0000-4000-8000-000000000003')),0::bigint,
 'separate relationship permission cannot view unrelated Student B');
SELECT is((SELECT count(*) FROM app.d1_read_family_relationship_history(
 '64000000-0000-4000-8000-000000000002')),0::bigint,
 'current relationship permission alone does not grant historic disclosure');
SELECT is((SELECT count(*) FROM app.d1_read_family_admin_relationship_history(
 '64000000-0000-4000-8000-000000000002')),0::bigint,
 'FAMILY child relationship grant never supplies staff-only history');
SELECT is((SELECT count(*) FROM app.d1_read_family_membership_history(
 '64000000-0000-4000-8000-000000000001')),0::bigint,
 'FAMILY current view cannot enumerate shared Principal membership history');
SELECT is((SELECT count(*) FROM app.d1_read_family_summary_for_student(
 '64000000-0000-4000-8000-000000000002')),1::bigint,
 'adding separate relationship permission preserves the summary result');
RESET ROLE;

-- Live grant revocation cuts off just the corresponding current projection.
SAVEPOINT revoked_relationship_read_grant;
SET ROLE schoolos_schema_owner;
UPDATE app_private.role_permission_grants SET revoked_at=clock_timestamp()
 WHERE id='64000000-0000-4000-8000-000000000020';
RESET ROLE;
SET ROLE authenticated;
SELECT is((SELECT count(*) FROM app.d1_read_family_relationships_for_student(
 '64000000-0000-4000-8000-000000000002')),0::bigint,
 'revoked relationship read grant immediately hides Guardian display');
SELECT is((SELECT count(*) FROM app.d1_read_family_summary_for_student(
 '64000000-0000-4000-8000-000000000002')),1::bigint,
 'independent still-live summary permission remains usable');
RESET ROLE;
ROLLBACK TO SAVEPOINT revoked_relationship_read_grant;

-- Removing current membership alone closes portal read despite preserved
-- child-access interval, original relationship, grant and shared Principal.
SAVEPOINT ended_family_membership_read;
SET ROLE schoolos_schema_owner;
UPDATE app_private.family_principal_memberships SET effective_until=CURRENT_DATE,
 ended_at=statement_timestamp(),ended_by='11111111-1111-4111-8111-111111111111'
 WHERE id='64000000-0000-4000-8000-000000000011';
RESET ROLE;
SET ROLE authenticated;
SELECT is((SELECT count(*) FROM app.d1_read_family_summary_for_student(
 '64000000-0000-4000-8000-000000000002')),0::bigint,
 'ending shared FAMILY membership immediately revokes linked-child summary');
SELECT is((SELECT count(*) FROM app.d1_read_family_relationships_for_student(
 '64000000-0000-4000-8000-000000000002')),0::bigint,
 'ending FAMILY membership prevents current relationship display');
RESET ROLE;
ROLLBACK TO SAVEPOINT ended_family_membership_read;
SELECT is((SELECT effective_until FROM app_private.family_principal_memberships
 WHERE id='64000000-0000-4000-8000-000000000011'),NULL::date,
 'rollback restores original effective membership without deleting history');
SET ROLE authenticated;
SELECT is((SELECT count(*) FROM app.d1_read_family_summary_for_student(
 '64000000-0000-4000-8000-000000000002')),1::bigint,
 'restored current membership restores only authorized summary projection');
RESET ROLE;

-- Staff performs a real permitted child entitlement REVOKE; current portal
-- views must immediately disappear although historic basis/membership remain.
SELECT set_config('request.jwt.claim.sub',current_setting('schoolos_test.auth_subject'),true);
SELECT set_config('request.jwt.claims',jsonb_build_object(
 'sub',current_setting('schoolos_test.auth_subject'),'role','authenticated',
 'iat',(SELECT extract(epoch FROM tokens_valid_from)::bigint
 FROM app_private.principal_auth_bindings
 WHERE id='66666666-6666-4666-8666-666666666666'),
 'is_anonymous',false)::text,true);
SET ROLE authenticated;
SELECT * FROM app.d1_change_family_child_access(
 '64000000-0000-4000-8000-000000000002',2,
 '64000000-0000-4000-8000-000000000001',2,
 'REVOKE',:'first_access_id',CURRENT_DATE,NULL,
 'Explicit portal entitlement revocation', 'effect-family-portal-read-revoke') \gset closed_
SELECT is(:'closed_action','REVOKE'::text,
 'authorized staff executes actual child entitlement REVOKE');
SELECT is(:'closed_access_id'::uuid,:'first_access_id'::uuid,
 'REVOKE closes original entitlement rather than creating a new link');
RESET ROLE;
SELECT is((SELECT effective_until FROM app_private.family_student_access
 WHERE id=:'first_access_id'),CURRENT_DATE,
 'entitlement end date is now exclusive of current portal day');
SELECT is((SELECT count(*) FROM app_private.family_relationships
 WHERE id='64000000-0000-4000-8000-000000000004'),1::bigint,
 'entitlement revocation retains original Guardian relationship evidence');
SELECT is((SELECT count(*) FROM app_private.family_principal_memberships
 WHERE id='64000000-0000-4000-8000-000000000011'),1::bigint,
 'entitlement revocation retains original FAMILY membership history');
SELECT is((SELECT state FROM app_private.principals
 WHERE id='64000000-0000-4000-8000-000000000005'),'ACTIVE'::text,
 'shared FAMILY Principal stays active to isolate entitlement revocation');

SELECT set_config('request.jwt.claim.sub',current_setting('schoolos_test.family_subject'),true);
SELECT set_config('request.jwt.claims',jsonb_build_object(
 'sub',current_setting('schoolos_test.family_subject'),'role','authenticated',
 'iat',(SELECT extract(epoch FROM tokens_valid_from)::bigint
 FROM app_private.principal_auth_bindings
 WHERE id='64000000-0000-4000-8000-000000000010'),
 'is_anonymous',false)::text,true);
SET ROLE authenticated;
SELECT is((SELECT count(*) FROM app.d1_read_family_summary_for_student(
 '64000000-0000-4000-8000-000000000002')),0::bigint,
 'after real child-access REVOKE old Student A summary is inaccessible');
SELECT is((SELECT count(*) FROM app.d1_read_family_relationships_for_student(
 '64000000-0000-4000-8000-000000000002')),0::bigint,
 'after child-access REVOKE old Guardian display is inaccessible');
SELECT is((SELECT count(*) FROM app.d1_read_family_summary_for_student(
 '64000000-0000-4000-8000-000000000003')),0::bigint,
 'after entitlement REVOKE unrelated Student B remains inaccessible');
SELECT is((SELECT count(*) FROM app.d1_read_family_relationship_history(
 '64000000-0000-4000-8000-000000000002')),0::bigint,
 'revoked entitlement cannot be bypassed using Family relationship history');
RESET ROLE;
SELECT is((SELECT count(*) FROM app_private.command_receipts
 WHERE operation_id=(SELECT id FROM app_private.operation_contracts
 WHERE code='family.child_access.change') AND state='SUCCEEDED'),2::bigint,
 'exactly one real child-entitlement ADD and REVOKE receipt are retained');
SELECT is((SELECT count(*) FROM app_private.outbox_events
 WHERE event_type='family.child_access_changed'),2::bigint,
 'exactly one child entitlement event per accepted ADD and REVOKE');
SELECT is((SELECT count(*) FROM app_private.family_student_access),1::bigint,
 'entitlement history is closed, not deleted or replaced');
SET ROLE anon;
SELECT throws_ok($sql$SELECT * FROM app.d1_read_family_summary_for_student(
 '64000000-0000-4000-8000-000000000002')$sql$,
 '42501'::char(5),NULL::text,
 'anon cannot EXECUTE protected Family summary checked read');
RESET ROLE;
SET CONSTRAINTS ALL IMMEDIATE;
SELECT * FROM finish();
ROLLBACK;
