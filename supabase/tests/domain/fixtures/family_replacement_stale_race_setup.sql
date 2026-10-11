-- Disposable Effect30 P1 replacement eligibility stale under concurrent APPLY.
-- Student B already has Family B primary selected by the previously accepted
-- P1 replacement race. Introduce a distinct, initially eligible Family A
-- replacement candidate. Neither approved request is pre-applied.
-- The first approved END will close the candidate before the primary-switch
-- END's proposed effective boundary. The latter must INVALIDATE, not select
-- an ineligible Family or silently close the existing primary.
SELECT set_config('request.jwt.claim.sub',
 (SELECT id::text FROM auth.users WHERE email='foundation-rbac-001@example.invalid'),true);
SELECT set_config('request.jwt.claims',jsonb_build_object(
 'sub',current_setting('request.jwt.claim.sub'),'role','authenticated',
 'iat',(SELECT extract(epoch FROM tokens_valid_from)::bigint
 FROM app_private.principal_auth_bindings
 WHERE id='66666666-6666-4666-8666-666666666666'),
 'is_anonymous',false)::text,true);
SET ROLE schoolos_schema_owner;
-- Different historical relationship kind from Student B's already ended
-- guardian avoids any overlapping duplicate-fact semantics.
INSERT INTO app_private.family_relationships(
 id,family_id,student_id,adult_person_id,relationship_kind,display_name,
 effective_from,reason,created_by)
VALUES (
 '83000000-0000-4000-8000-000000000001',
 '64000000-0000-4000-8000-000000000001',
 '64000000-0000-4000-8000-000000000003',
 NULL,'FATHER','Eligible candidate Family A father',
 CURRENT_DATE-4,'Pre-existing selectable replacement candidate for Student B',
 '11111111-1111-4111-8111-111111111111');
RESET ROLE;
SELECT row_version AS student_v FROM app_private.students
 WHERE id='64000000-0000-4000-8000-000000000003' \gset student_
SELECT row_version AS family_v FROM app_private.families
 WHERE id='64000000-0000-4000-8000-000000000001' \gset candidate_family_
SELECT row_version AS family_v FROM app_private.families
 WHERE id='82000000-0000-4000-8000-000000000003' \gset primary_family_
-- Both P1 SUBMITs are valid before either accepted change applies:
-- (1) END non-primary candidate at DATE-2;
-- (2) END selected primary at DATE-1, explicitly replacing it with (1).
SET ROLE authenticated;
SELECT * FROM app.d1_submit_family_relationship_change(
 '64000000-0000-4000-8000-000000000003',:'student_student_v'::bigint,
 '64000000-0000-4000-8000-000000000001',
 :'candidate_family_family_v'::bigint,
 'END','83000000-0000-4000-8000-000000000001',
 NULL,NULL,NULL,NULL,CURRENT_DATE-2,
 'D1 replacement stale race candidate END first',NULL,
 'family-stale-replacement-candidate-end-submit') \gset first_
SELECT * FROM app.d1_submit_family_relationship_change(
 '64000000-0000-4000-8000-000000000003',:'student_student_v'::bigint,
 '82000000-0000-4000-8000-000000000003',
 :'primary_family_family_v'::bigint,
 'END','82000000-0000-4000-8000-000000000002',
 NULL,NULL,NULL,NULL,CURRENT_DATE-1,
 'D1 replacement stale race primary END second',
 '83000000-0000-4000-8000-000000000001',
 'family-stale-replacement-primary-end-submit') \gset second_
RESET ROLE;
-- Distinct real reviewers with live Family P1 role/scope independently
-- approve each request, not synthetic APPROVED state insertion.
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
 'Independent review candidate source closure',
 'family-stale-replacement-candidate-end-review') \gset first_review_
RESET ROLE;
SELECT set_config('request.jwt.claim.sub',
 (SELECT id::text FROM auth.users WHERE email='foundation-own-001@example.invalid'),true);
SELECT set_config('request.jwt.claims',jsonb_build_object(
 'sub',current_setting('request.jwt.claim.sub'),'role','authenticated',
 'iat',(SELECT extract(epoch FROM tokens_valid_from)::bigint
 FROM app_private.principal_auth_bindings
 WHERE id='81000000-0000-4000-8000-000000000013'),
 'is_anonymous',false)::text,true);
SET ROLE authenticated;
SELECT * FROM app.d1_review_family_relationship_change(
 :'second_request_id','APPROVE',3,
 'Independent review primary selection after candidate closure',
 'family-stale-replacement-primary-end-review') \gset second_review_
RESET ROLE;
