-- Disposable Effect30 P1 competing CORRECT: same retained guardian,
-- distinct proposed facts, two independent APPROVE decisions.
-- This runs after the accepted END race, whose original source is closed.
-- No hosted database, no direct workflow-state insertion or policy bypass.
SET ROLE schoolos_schema_owner;
-- A different open, current guardian source is a synthetic pre-existing fact.
-- Its start is after the prior END race's exclusive boundary.
INSERT INTO app_private.family_relationships(
 id,family_id,student_id,adult_person_id,relationship_kind,display_name,
 effective_from,reason,created_by)
VALUES (
 '81000000-0000-4000-8000-000000000010',
 '64000000-0000-4000-8000-000000000001',
 '64000000-0000-4000-8000-000000000002',
 '10000000-0000-4000-8000-000000000003',
 'GUARDIAN','Uncorrected retained guardian',
 CURRENT_DATE-2,'New historical guardian source for independent P1 CORRECT competition',
 '11111111-1111-4111-8111-111111111111');
-- This source is the currently selected display relationship: a winning
-- CORRECT must both retain relationship lineage and replace display lineage.
INSERT INTO app_private.student_primary_family_contexts(
 id,student_id,family_relationship_id,effective_from,reason,created_by)
VALUES (
 '81000000-0000-4000-8000-000000000011',
 '64000000-0000-4000-8000-000000000002',
 '81000000-0000-4000-8000-000000000010',
 CURRENT_DATE-2,'Pre-existing selected Family context',
 '11111111-1111-4111-8111-111111111111');
RESET ROLE;
SELECT row_version AS student_v FROM app_private.students
 WHERE id='64000000-0000-4000-8000-000000000002' \gset student_
SELECT row_version AS family_v FROM app_private.families
 WHERE id='64000000-0000-4000-8000-000000000001' \gset family_
SELECT set_config('request.jwt.claim.sub',
 (SELECT id::text FROM auth.users WHERE email='foundation-rbac-001@example.invalid'),true);
SELECT set_config('request.jwt.claims',jsonb_build_object(
 'sub',current_setting('request.jwt.claim.sub'),'role','authenticated',
 'iat',(SELECT extract(epoch FROM tokens_valid_from)::bigint
 FROM app_private.principal_auth_bindings
 WHERE id='66666666-6666-4666-8666-666666666666'),
 'is_anonymous',false)::text,true);
SET ROLE authenticated;
-- Each CORRECT is independently valid when submitted. Different display
-- values and distinct intent keys mean these are not replay duplicates.
SELECT * FROM app.d1_submit_family_relationship_change(
 '64000000-0000-4000-8000-000000000002',:'student_student_v'::bigint,
 '64000000-0000-4000-8000-000000000001',:'family_family_v'::bigint,
 'CORRECT','81000000-0000-4000-8000-000000000010',
 '10000000-0000-4000-8000-000000000003','GUARDIAN',
 'Guardian corrected by first approved intent',NULL,
 CURRENT_DATE-1,'D1 competing relationship CORRECT first',NULL,
 'family-relationship-correct-first-submit') \gset first_
SELECT * FROM app.d1_submit_family_relationship_change(
 '64000000-0000-4000-8000-000000000002',:'student_student_v'::bigint,
 '64000000-0000-4000-8000-000000000001',:'family_family_v'::bigint,
 'CORRECT','81000000-0000-4000-8000-000000000010',
 '10000000-0000-4000-8000-000000000003','GUARDIAN',
 'Guardian corrected by second approved intent',NULL,
 CURRENT_DATE-1,'D1 competing relationship CORRECT second',NULL,
 'family-relationship-correct-second-submit') \gset second_
RESET ROLE;
-- A verified different Person with current family.access.approve authority
-- performs two genuine P1 decisions, not synthetic pre-approved request rows.
SELECT set_config('request.jwt.claim.sub',
 (SELECT id::text FROM auth.users WHERE email='foundation-test-001@example.invalid'),true);
SELECT set_config('request.jwt.claims',jsonb_build_object(
 'sub',current_setting('request.jwt.claim.sub'),'role','authenticated',
 'iat',(SELECT extract(epoch FROM tokens_valid_from)::bigint
 FROM app_private.principal_auth_bindings
 WHERE id='76000000-0000-4000-8000-000000000005'),
 'is_anonymous',false)::text,true);
SET ROLE authenticated;
SELECT * FROM app.d1_review_family_relationship_change(
 :'first_request_id','APPROVE',3,
 'Independent CORRECT review first','family-relationship-correct-first-review') \gset first_review_
SELECT * FROM app.d1_review_family_relationship_change(
 :'second_request_id','APPROVE',3,
 'Independent CORRECT review second','family-relationship-correct-second-review') \gset second_review_
RESET ROLE;
