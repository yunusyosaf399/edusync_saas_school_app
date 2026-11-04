BEGIN;
CREATE EXTENSION IF NOT EXISTS pgtap WITH SCHEMA extensions;
SET LOCAL search_path=extensions,pg_catalog,public;
SELECT plan(24);
SELECT ok(to_regprocedure('app_private.db03_principal_final_authority(uuid,uuid)') IS NOT NULL,
 'private dedicated final authorization source exists');
SELECT ok(to_regprocedure('app_private.db03_principal_final_actor(uuid)') IS NOT NULL,
 'private authenticated Principal actor source exists');
SELECT ok(NOT has_function_privilege('anon','app_private.db03_principal_final_authority(uuid,uuid)','EXECUTE'),
 'anonymous cannot call final authorization');
SELECT ok(NOT has_function_privilege('authenticated','app_private.db03_principal_final_authority(uuid,uuid)','EXECUTE'),
 'authenticated clients cannot query the final authorization');
SELECT ok(NOT has_function_privilege('service_role','app_private.db03_principal_final_authority(uuid,uuid)','EXECUTE'),
 'service role denied');
SELECT ok(NOT has_function_privilege('schoolos_file_login','app_private.db03_principal_final_authority(uuid,uuid)','EXECUTE'),
 'file worker denied');
SELECT ok(NOT has_function_privilege('schoolos_platform_executor','app_private.db03_principal_final_authority(uuid,uuid)','EXECUTE'),
 'platform executor denied');
SELECT ok(NOT has_function_privilege('schoolos_evidence_writer','app_private.db03_principal_final_authority(uuid,uuid)','EXECUTE'),
 'evidence writer denied');
SELECT ok(has_function_privilege('schoolos_workflow_executor','app_private.db03_principal_final_authority(uuid,uuid)','EXECUTE'),
 'only future protected workflow can call dedicated source');
SELECT ok(NOT has_function_privilege('authenticated','app_private.db03_principal_final_actor(uuid)','EXECUTE'),
 'client cannot call final actor');
SELECT ok(NOT has_function_privilege('service_role','app_private.db03_principal_final_actor(uuid)','EXECUTE'),
 'service role cannot call final actor');
SELECT ok(has_function_privilege('schoolos_workflow_executor','app_private.db03_principal_final_actor(uuid)','EXECUTE'),
 'protected workflow can use JWT-bound actor source');
SELECT ok((SELECT prosecdef FROM pg_proc WHERE oid=
 'app_private.db03_principal_final_authority(uuid,uuid)'::regprocedure),
 'authority uses private dedicated fixed-owner context');
SELECT ok((SELECT prosecdef FROM pg_proc WHERE oid=
 'app_private.db03_principal_final_actor(uuid)'::regprocedure),
 'actor resolver uses private fixed-owner context');
SELECT is(app_private.db03_principal_final_authority(NULL,NULL)::text,NULL::text,
 'null identity and Campus cannot authorize');
SELECT is(app_private.db03_principal_final_authority(
 '77777777-7777-4777-8777-777777777777',
 '91919191-9191-4191-8191-919191919191')::text,NULL::text,
 'unknown Principal cannot authorize');
SELECT is((SELECT count(*) FROM app_private.operation_contracts
 WHERE code='admission.final.decide'),0::bigint,
 'dedicated operation is not registered or activated');
SELECT is((SELECT count(*) FROM app_private.permissions
 WHERE code='admission.final.decide'),0::bigint,
 'dedicated Principal permission not seeded');
SELECT ok(position('admission.final.decide' IN pg_get_functiondef(
 'app_private.db03_principal_final_authority(uuid,uuid)'::regprocedure))>0,
 'requires distinct final-decision operation not document approval');
SELECT ok(position('r.code=''PRINCIPAL''' IN pg_get_functiondef(
 'app_private.db03_principal_final_authority(uuid,uuid)'::regprocedure))>0,
 'final authority demands Principal role code in same chain');
SELECT ok(position('principal_auth_bindings' IN pg_get_functiondef(
 'app_private.db03_principal_final_authority(uuid,uuid)'::regprocedure))>0,
 'active bound individual identity source required');
SELECT ok(position('assignment_permission_scopes' IN pg_get_functiondef(
 'app_private.db03_principal_final_authority(uuid,uuid)'::regprocedure))>0,
 'same-chain live campus and permission scope checked');
SELECT ok(position('request.jwt.claims' IN pg_get_functiondef(
 'app_private.db03_principal_final_actor(uuid)'::regprocedure))>0,
 'final actor checks signed session expiry before role');
SELECT ok(to_regprocedure('app.finalize_admission(uuid,bigint,uuid,text,text,text)') IS NULL,
 'no public Principal final-decision mutation is introduced');
SELECT * FROM finish();
ROLLBACK;
