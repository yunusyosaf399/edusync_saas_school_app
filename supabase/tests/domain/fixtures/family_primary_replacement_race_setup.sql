-- Effect30 disposable-only competing P1 selected-primary END replacement
-- against CORRECT on the SAME Student B and Family A guardian source.
-- Runs after all ten observed-lock races; their retained Student A history is
-- neither reused as Student B's primary nor modified by this fixture.
-- No hosted Supabase or populated school data; typed workflow only.
-- A fresh transaction needs verified current staff identity before protected
-- synthetic history INSERTs, and Auth IDs are fetched only before role switch.
SELECT set_config('request.jwt.claim.sub',
 (SELECT id::text FROM auth.users WHERE email='foundation-rbac-001@example.invalid'),true);
SELECT set_config('request.jwt.claims',jsonb_build_object(
 'sub',current_setting('request.jwt.claim.sub'),'role','authenticated',
 'iat',(SELECT extract(epoch FROM tokens_valid_from)::bigint
 FROM app_private.principal_auth_bindings
 WHERE id='66666666-6666-4666-8666-666666666666'),
 'is_anonymous',false)::text,true);
SET ROLE schoolos_schema_owner;
-- Family A and Student B were created by the accepted membership fixture.
-- The independent replacement is a newly seeded ACTIVE Family B.
INSERT INTO app_private.families(id,school_id,code,display_label,created_by)
VALUES ('82000000-0000-4000-8000-000000000003',
 '22222222-2222-4222-8222-222222222222','FAM-P1-RACE-ALT',
 'Selected-primary replacement candidate for Student B',
 '11111111-1111-4111-8111-111111111111');
INSERT INTO app_private.family_relationships(
 id,family_id,student_id,adult_person_id,relationship_kind,
 display_name,effective_from,reason,created_by)
VALUES
 ('82000000-0000-4000-8000-000000000001',
 '64000000-0000-4000-8000-000000000001',
 '64000000-0000-4000-8000-000000000003',
 '10000000-0000-4000-8000-000000000003','GUARDIAN',
 'Selected Student B guardian',CURRENT_DATE-19,
 'Pre-existing Student B source for competing primary replacement',
 '11111111-1111-4111-8111-111111111111'),
 ('82000000-0000-4000-8000-000000000002',
 '82000000-0000-4000-8000-000000000003',
 '64000000-0000-4000-8000-000000000003',
 NULL,'MOTHER','Independent Student B mother',CURRENT_DATE-18,
 'Pre-existing independent eligible other Family relationship',
 '11111111-1111-4111-8111-111111111111');
-- Selected context initially points to Family A, not the second Family.
INSERT INTO app_private.student_primary_family_contexts(
 id,student_id,family_relationship_id,effective_from,reason,created_by)
VALUES ('82000000-0000-4000-8000-000000000004',
 '64000000-0000-4000-8000-000000000003',
 '82000000-0000-4000-8000-000000000001',
 CURRENT_DATE-16,'Retained selected primary Family A context',
 '11111111-1111-4111-8111-111111111111');
RESET ROLE;
SELECT row_version AS student_v FROM app_private.students
 WHERE id='64000000-0000-4000-8000-000000000003' \gset student_
SELECT row_version AS family_v FROM app_private.families
 WHERE id='64000000-0000-4000-8000-000000000001' \gset family_
-- Both intents are independently valid and bind the SAME expected versions,
-- source and date; END additionally binds the explicit other-Family relation.
SET ROLE authenticated;
SELECT * FROM app.d1_submit_family_relationship_change(
 '64000000-0000-4000-8000-000000000003',:'student_student_v'::bigint,
 '64000000-0000-4000-8000-000000000001',:'family_family_v'::bigint,
 'END','82000000-0000-4000-8000-000000000001',
 NULL,NULL,NULL,NULL,CURRENT_DATE-6,
 'D1 primary replacement race END first',
 '82000000-0000-4000-8000-000000000002',
 'family-primary-replacement-end-submit') \gset first_
SELECT * FROM app.d1_submit_family_relationship_change(
 '64000000-0000-4000-8000-000000000003',:'student_student_v'::bigint,
 '64000000-0000-4000-8000-000000000001',:'family_family_v'::bigint,
 'CORRECT','82000000-0000-4000-8000-000000000001',
 '10000000-0000-4000-8000-000000000003','GUARDIAN',
 'Rejected competing Student B guardian correction',NULL,CURRENT_DATE-6,
 'D1 primary replacement race CORRECT second',NULL,
 'family-primary-replacement-correct-submit') \gset second_
RESET ROLE;
-- Reviewers have distinct verified Persons and independent real Auth users.
-- They already hold the configured P1 role and ALL/DIRECT review scope.
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
 :'first_request_id','APPROVE',3,'Primary replacement END independent P1 review',
 'family-primary-replacement-end-review') \gset first_review_
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
 :'second_request_id','APPROVE',3,'Competing CORRECT independent P1 review',
 'family-primary-replacement-correct-review') \gset second_review_
RESET ROLE;
