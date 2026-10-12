-- D1 reverse cross-Family race: new shared Student with independent A/B links.
-- Runs after PR38 forward race; reuses its separately verified Auth principals,
-- Family-specific membership, safe read roles, scoped grants and DIRECT policies.
-- Transactional test-only fixture committed only in disposable local PostgreSQL.
-- The PR38 setup authenticated staff JWT was transaction-local and did not
-- survive COMMIT; restore real current staff identity before owner fixture DML.
SELECT set_config('request.jwt.claim.sub',
 (SELECT id::text FROM auth.users
  WHERE email='foundation-rbac-001@example.invalid'),true);
SELECT set_config('request.jwt.claims',jsonb_build_object(
 'sub',current_setting('request.jwt.claim.sub'),'role','authenticated',
 'iat',(SELECT extract(epoch FROM tokens_valid_from)::bigint
 FROM app_private.principal_auth_bindings
 WHERE id='66666666-6666-4666-8666-666666666666'),
 'is_anonymous',false)::text,true);
SET ROLE schoolos_schema_owner;
INSERT INTO app_private.people(id,display_name,created_by)
VALUES ('96000000-0000-4000-8000-000000000001',
 'Cross Family Reverse Race Student',
 '11111111-1111-4111-8111-111111111111');
INSERT INTO app_private.students(
 id,person_id,school_student_id,admission_number,admission_serial,
 admitted_on,current_status,created_by)
VALUES ('96000000-0000-4000-8000-000000000002',
 '96000000-0000-4000-8000-000000000001',
 'CF-REVERSE-001','CF-REVERSE-001',960001,CURRENT_DATE-26,'ACTIVE',
 '11111111-1111-4111-8111-111111111111');
INSERT INTO app_private.student_status_transitions(
 student_id,previous_status,new_status,effective_on,sequence_number,reason,created_by)
VALUES ('96000000-0000-4000-8000-000000000002',NULL,'ACTIVE',
 CURRENT_DATE-26,1,'Reverse cross Family Student initial ACTIVE',
 '11111111-1111-4111-8111-111111111111');
INSERT INTO app_private.family_relationships(
 id,family_id,student_id,adult_person_id,relationship_kind,
 display_name,effective_from,reason,created_by)
VALUES
 ('96000000-0000-4000-8000-000000000003',
  '95000000-0000-4000-8000-000000000003',
  '96000000-0000-4000-8000-000000000002',
  '10000000-0000-4000-8000-000000000003','GUARDIAN',
  'Reverse race A Guardian',CURRENT_DATE-22,
  'Independent Family A basis for reverse cross-operation race',
  '11111111-1111-4111-8111-111111111111'),
 ('96000000-0000-4000-8000-000000000004',
  '95000000-0000-4000-8000-000000000004',
  '96000000-0000-4000-8000-000000000002',
  '10000000-0000-4000-8000-000000000004','MOTHER',
  'Reverse race B Mother',CURRENT_DATE-21,
  'Independent Family B basis for reverse cross-operation race',
  '11111111-1111-4111-8111-111111111111');
INSERT INTO app_private.family_student_access(
 id,family_id,student_id,effective_from,reason,created_by)
VALUES
 ('96000000-0000-4000-8000-000000000005',
  '95000000-0000-4000-8000-000000000003',
  '96000000-0000-4000-8000-000000000002',
  CURRENT_DATE-19,'Independent Family A reverse race child entitlement',
  '11111111-1111-4111-8111-111111111111'),
 ('96000000-0000-4000-8000-000000000006',
  '95000000-0000-4000-8000-000000000004',
  '96000000-0000-4000-8000-000000000002',
  CURRENT_DATE-19,'Independent Family B reverse race child entitlement',
  '11111111-1111-4111-8111-111111111111');
RESET ROLE;
