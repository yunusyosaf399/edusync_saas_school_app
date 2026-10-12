-- D1 shared authorization-lock races: two distinct new Students.
-- Reuses accepted PR38/39 two staff users, two FAMILY principals, existing
-- current family memberships, permission/scope grant chains and DIRECT routes.
-- Synthetic facts only; protected command mutations run as authenticated.
SELECT set_config('request.jwt.claim.sub',
 (SELECT id::text FROM auth.users WHERE email='foundation-rbac-001@example.invalid'),true);
SELECT set_config('request.jwt.claims',jsonb_build_object(
 'sub',current_setting('request.jwt.claim.sub'),'role','authenticated',
 'iat',(SELECT extract(epoch FROM tokens_valid_from)::bigint
 FROM app_private.principal_auth_bindings
 WHERE id='66666666-6666-4666-8666-666666666666'),
 'is_anonymous',false)::text,true);
SET ROLE schoolos_schema_owner;
INSERT INTO app_private.people(id,display_name,created_by) VALUES
 ('97000000-0000-4000-8000-000000000001','Authority race A Student',
 '11111111-1111-4111-8111-111111111111'),
 ('98000000-0000-4000-8000-000000000001','Authority race B Student',
 '11111111-1111-4111-8111-111111111111');
INSERT INTO app_private.students(
 id,person_id,school_student_id,admission_number,admission_serial,
 admitted_on,current_status,created_by) VALUES
 ('97000000-0000-4000-8000-000000000002',
 '97000000-0000-4000-8000-000000000001',
 'AUTH-RACE-A','AUTH-RACE-A',970001,CURRENT_DATE-28,'ACTIVE',
 '11111111-1111-4111-8111-111111111111'),
 ('98000000-0000-4000-8000-000000000002',
 '98000000-0000-4000-8000-000000000001',
 'AUTH-RACE-B','AUTH-RACE-B',980001,CURRENT_DATE-28,'ACTIVE',
 '11111111-1111-4111-8111-111111111111');
INSERT INTO app_private.student_status_transitions(
 student_id,previous_status,new_status,effective_on,sequence_number,reason,created_by)
VALUES
 ('97000000-0000-4000-8000-000000000002',NULL,'ACTIVE',
 CURRENT_DATE-28,1,'Authority A Student initial status',
 '11111111-1111-4111-8111-111111111111'),
 ('98000000-0000-4000-8000-000000000002',NULL,'ACTIVE',
 CURRENT_DATE-28,1,'Authority B Student initial status',
 '11111111-1111-4111-8111-111111111111');
INSERT INTO app_private.family_relationships(
 id,family_id,student_id,adult_person_id,relationship_kind,
 display_name,effective_from,reason,created_by)
VALUES
 ('97000000-0000-4000-8000-000000000003',
 '95000000-0000-4000-8000-000000000003',
 '97000000-0000-4000-8000-000000000002',
 '10000000-0000-4000-8000-000000000003','GUARDIAN',
 'Race A current Guardian',CURRENT_DATE-23,
 'Authority revocation race A live basis',
 '11111111-1111-4111-8111-111111111111'),
 ('98000000-0000-4000-8000-000000000003',
 '95000000-0000-4000-8000-000000000004',
 '98000000-0000-4000-8000-000000000002',
 '10000000-0000-4000-8000-000000000004','MOTHER',
 'Race B current Mother',CURRENT_DATE-23,
 'Authority revocation race B live basis',
 '11111111-1111-4111-8111-111111111111');
INSERT INTO app_private.family_student_access(
 id,family_id,student_id,effective_from,reason,created_by)
VALUES
 ('97000000-0000-4000-8000-000000000004',
 '95000000-0000-4000-8000-000000000003',
 '97000000-0000-4000-8000-000000000002',
 CURRENT_DATE-19,'Authority A current child access',
 '11111111-1111-4111-8111-111111111111'),
 ('98000000-0000-4000-8000-000000000004',
 '95000000-0000-4000-8000-000000000004',
 '98000000-0000-4000-8000-000000000002',
 CURRENT_DATE-19,'Authority B current child access',
 '11111111-1111-4111-8111-111111111111');
RESET ROLE;
