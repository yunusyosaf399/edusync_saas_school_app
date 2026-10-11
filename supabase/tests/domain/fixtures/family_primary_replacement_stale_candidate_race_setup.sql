-- Effect30 P1 competing approved ENDs on different relationship rows:
-- candidate END closes eligible unselected Family A replacement while
-- selected-primary Family B END waits and must INVALIDATE as stale.
-- Runs after the accepted eleven-race fixture for the same Student B.
-- Disposable PostgreSQL only. No synthetic workflow states or ACL bypass.
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
-- An independent pre-existing candidate enters Family A AFTER that Family
-- relationship's earlier historical source ended at CURRENT_DATE-6. The
-- current selected primary relationship is still the eligible Family B row.
INSERT INTO app_private.family_relationships(
 id,family_id,student_id,adult_person_id,relationship_kind,display_name,
 effective_from,reason,created_by)
VALUES ('83000000-0000-4000-8000-000000000001',
 '64000000-0000-4000-8000-000000000001',
 '64000000-0000-4000-8000-000000000003',
 NULL,'FATHER','Independent prospective Student B replacement',
 CURRENT_DATE-5,'Pre-existing independently eligible Family A candidate',
 '11111111-1111-4111-8111-111111111111');
RESET ROLE;
SELECT row_version AS student_v FROM app_private.students
 WHERE id='64000000-0000-4000-8000-000000000003' \gset student_
SELECT row_version AS family_a_v FROM app_private.families
 WHERE id='64000000-0000-4000-8000-000000000001' \gset a_
SELECT row_version AS family_b_v FROM app_private.families
 WHERE id='82000000-0000-4000-8000-000000000003' \gset b_
-- Both independently valid at request time; source Family differs.
-- Candidate END removes replacement before selected-primary END's date.
SET ROLE authenticated;
SELECT * FROM app.d1_submit_family_relationship_change(
 '64000000-0000-4000-8000-000000000003',:'student_student_v'::bigint,
 '64000000-0000-4000-8000-000000000001',:'a_family_a_v'::bigint,
 'END','83000000-0000-4000-8000-000000000001',
 NULL,NULL,NULL,NULL,CURRENT_DATE-3,
 'D1 replacement eligibility race candidate END first',NULL,
 'family-replacement-stale-candidate-end-submit') \gset first_
SELECT * FROM app.d1_submit_family_relationship_change(
 '64000000-0000-4000-8000-000000000003',:'student_student_v'::bigint,
 '82000000-0000-4000-8000-000000000003',:'b_family_b_v'::bigint,
 'END','82000000-0000-4000-8000-000000000002',
 NULL,NULL,NULL,NULL,CURRENT_DATE-2,
 'D1 replacement eligibility race primary END second',
 '83000000-0000-4000-8000-000000000001',
 'family-replacement-stale-primary-end-submit') \gset second_
RESET ROLE;
-- Two distinct real reviewer Persons/Auth principals from the accepted
-- P1 policy fixture independently APPROVE; review causes no domain effect.
SELECT set_config('request.jwt.claim.sub',
 (SELECT id::text FROM auth.users
 WHERE email='foundation-test-001@example.invalid'),true);
SELECT set_config('request.jwt.claims',jsonb_build_object(
 'sub',current_setting('request.jwt.claim.sub'),'role','authenticated',
 'iat',(SELECT extract(epoch FROM tokens_valid_from)::bigint
 FROM app_private.principal_auth_bindings
 WHERE id='76000000-0000-4000-8000-000000000005'),
 'is_anonymous',false)::text,true);
SET ROLE authenticated;
SELECT * FROM app.d1_review_family_relationship_change(
 :'first_request_id','APPROVE',3,'Independent candidate END reviewer',
 'family-replacement-stale-candidate-end-review') \gset first_review_
RESET ROLE;
SELECT set_config('request.jwt.claim.sub',
 (SELECT id::text FROM auth.users
 WHERE email='foundation-own-001@example.invalid'),true);
SELECT set_config('request.jwt.claims',jsonb_build_object(
 'sub',current_setting('request.jwt.claim.sub'),'role','authenticated',
 'iat',(SELECT extract(epoch FROM tokens_valid_from)::bigint
 FROM app_private.principal_auth_bindings
 WHERE id='81000000-0000-4000-8000-000000000013'),
 'is_anonymous',false)::text,true);
SET ROLE authenticated;
SELECT * FROM app.d1_review_family_relationship_change(
 :'second_request_id','APPROVE',3,'Independent primary END reviewer',
 'family-replacement-stale-primary-end-review') \gset second_review_
RESET ROLE;
