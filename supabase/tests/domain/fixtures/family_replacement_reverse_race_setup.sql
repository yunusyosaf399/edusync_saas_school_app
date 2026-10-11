-- Effect30 P1 reverse-winner selected-primary replacement race (disposable only).
-- Student B starts with the existing selected primary in Family B. The separate
-- Family A guardian is eligible as a replacement for a future primary END.
-- Both separate END requests are independently approved before applying.
-- PRIMARY END wins and selects Family A; candidate END must then INVALIDATE
-- because the previously unselected guardian became the selected primary.
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
 '84000000-0000-4000-8000-000000000001',
 '64000000-0000-4000-8000-000000000001',
 '64000000-0000-4000-8000-000000000003',
 NULL,'GUARDIAN','Eligible candidate Family A guardian',
 CURRENT_DATE-1,'Pre-existing selectable replacement candidate for Student B',
 '11111111-1111-4111-8111-111111111111');
-- Distinct still-eligible relationship basis guarantees that ending the newly
-- selected primary requires an explicit replacement, not silent clearing.
INSERT INTO app_private.family_relationships(
 id,family_id,student_id,adult_person_id,relationship_kind,display_name,
 effective_from,reason,created_by)
VALUES (
 '84000000-0000-4000-8000-000000000002',
 '64000000-0000-4000-8000-000000000001',
 '64000000-0000-4000-8000-000000000003',
 NULL,'MOTHER','Independent eligible Family A mother',
 CURRENT_DATE-1,'Alternative still eligible after candidate becomes primary',
 '11111111-1111-4111-8111-111111111111');
RESET ROLE;
SELECT row_version AS student_v FROM app_private.students
 WHERE id='64000000-0000-4000-8000-000000000003' \gset student_
SELECT row_version AS family_v FROM app_private.families
 WHERE id='64000000-0000-4000-8000-000000000001' \gset candidate_family_
SELECT row_version AS family_v FROM app_private.families
 WHERE id='82000000-0000-4000-8000-000000000003' \gset primary_family_
-- Both approved ENDs are initially eligible: candidate end on DATE+2,
-- primary switch to candidate on DATE+1; APPLY executes primary first.
SET ROLE authenticated;
SELECT * FROM app.d1_submit_family_relationship_change(
 '64000000-0000-4000-8000-000000000003',:'student_student_v'::bigint,
 '64000000-0000-4000-8000-000000000001',
 :'candidate_family_family_v'::bigint,
 'END','84000000-0000-4000-8000-000000000001',
 NULL,NULL,NULL,NULL,CURRENT_DATE+2,
 'D1 reverse replacement candidate END second',NULL,
 'family-reverse-replacement-candidate-end-submit') \gset first_
SELECT * FROM app.d1_submit_family_relationship_change(
 '64000000-0000-4000-8000-000000000003',:'student_student_v'::bigint,
 '82000000-0000-4000-8000-000000000003',
 :'primary_family_family_v'::bigint,
 'END','82000000-0000-4000-8000-000000000002',
 NULL,NULL,NULL,NULL,CURRENT_DATE+1,
 'D1 reverse replacement primary END first',
 '84000000-0000-4000-8000-000000000001',
 'family-reverse-replacement-primary-end-submit') \gset second_
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
 'Independent review candidate closing after primary switch',
 'family-reverse-replacement-candidate-end-review') \gset first_review_
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
 'Independent review primary switch before candidate END',
 'family-reverse-replacement-primary-end-review') \gset second_review_
RESET ROLE;
