-- Local-only Foundation catalog and privilege checks. No fixture or production seed.
BEGIN;
CREATE EXTENSION IF NOT EXISTS pgtap WITH SCHEMA extensions;
SET LOCAL search_path = extensions, pg_catalog, public;
SELECT plan(43);

SELECT is((SELECT count(*) FROM pg_namespace WHERE nspname IN ('app','app_private')), 2::bigint, 'both application schemas exist');
SELECT is((SELECT count(*) FROM pg_class t JOIN pg_namespace n ON n.oid=t.relnamespace WHERE n.nspname IN ('app','app_private') AND t.relkind='r'), 33::bigint, '33 application tables');
SELECT is((SELECT count(*) FROM information_schema.columns WHERE table_schema IN ('app','app_private')), 385::bigint, '385 application columns');
SELECT is((SELECT count(*) FROM pg_constraint c JOIN pg_namespace n ON n.oid=c.connamespace WHERE n.nspname IN ('app','app_private') AND c.contype='f'), 90::bigint, '90 application-origin FKs');
SELECT is((SELECT count(*) FROM pg_constraint WHERE conname IN ('school_profiles_default_academic_year_id_id_fkey','school_profiles_logo_file_id_fkey','people_created_by_fkey')), 3::bigint, 'three application late FKs');
SELECT is((SELECT count(*) FROM pg_constraint c JOIN pg_namespace n ON n.oid=c.connamespace WHERE n.nspname IN ('app','app_private') AND c.contype='f' AND c.confdeltype='c'), 0::bigint, 'no application FK cascades on delete');
SELECT is((SELECT count(*) FROM pg_index x JOIN pg_class t ON t.oid=x.indrelid JOIN pg_namespace n ON n.oid=t.relnamespace LEFT JOIN pg_constraint c ON c.conindid=x.indexrelid WHERE n.nspname IN ('app','app_private') AND c.oid IS NULL), 49::bigint, '49 reviewed non-constraint indexes');
SELECT is((SELECT count(*) FROM pg_policy p JOIN pg_class t ON t.oid=p.polrelid JOIN pg_namespace n ON n.oid=t.relnamespace WHERE n.nspname IN ('app','app_private')), 49::bigint, '49 policies');
SELECT is((SELECT count(*) FROM pg_trigger g JOIN pg_class t ON t.oid=g.tgrelid JOIN pg_namespace n ON n.oid=t.relnamespace WHERE n.nspname IN ('app','app_private') AND NOT g.tgisinternal), 63::bigint, '63 application triggers');
SELECT is((SELECT count(*) FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace WHERE n.nspname IN ('app','app_private') AND p.prosecdef), 39::bigint, '39 security-definer functions');
SELECT is((SELECT count(*) FROM pg_class t JOIN pg_namespace n ON n.oid=t.relnamespace WHERE n.nspname IN ('app','app_private') AND t.relkind='r' AND t.relrowsecurity), 33::bigint, 'RLS enabled on every application table');
SELECT is((SELECT count(*) FROM pg_class t JOIN pg_namespace n ON n.oid=t.relnamespace WHERE n.nspname IN ('app','app_private') AND t.relkind='r' AND t.relforcerowsecurity), 33::bigint, 'RLS forced on every application table');
SELECT is((SELECT count(*) FROM pg_class t JOIN pg_namespace n ON n.oid=t.relnamespace WHERE n.nspname IN ('app','app_private') AND t.relname='notification_channel_deliveries'), 0::bigint, 'deferred F28 is absent');

SELECT is((SELECT count(*) FROM pg_attribute WHERE attrelid='app_private.file_objects'::regclass AND attname='uploaded_by_principal_id' AND attnum>0 AND NOT attisdropped), 1::bigint, 'file uploader provenance column exists');
SELECT is((SELECT count(*) FROM pg_attribute WHERE attrelid='app_private.file_objects'::regclass AND attname='owner_principal_id' AND attnum>0 AND NOT attisdropped), 0::bigint, 'obsolete file owner column absent');
SELECT ok((SELECT pg_get_constraintdef(oid) LIKE '%byte_size <= 1048576%' FROM pg_constraint WHERE conrelid='app_private.file_objects'::regclass AND conname='file_objects_ck_01'), 'file byte-size ceiling exists');
SELECT ok((SELECT pg_get_constraintdef(oid) LIKE '%octet_length(content_hash) = 32%' FROM pg_constraint WHERE conrelid='app_private.file_objects'::regclass AND conname='file_objects_ck_02'), 'file SHA-256 byte-length check exists');
SELECT ok((SELECT pg_get_constraintdef(oid) LIKE '%purpose_code ~%' FROM pg_constraint WHERE conrelid='app_private.file_objects'::regclass AND conname='file_objects_ck_07'), 'file purpose-code lexical check exists');

SELECT is((SELECT count(*) FROM pg_constraint WHERE conname='principal_auth_bindings_auth_user_id_fkey'), 1::bigint, 'external Auth FK exists once');
SELECT ok((SELECT conrelid='app_private.principal_auth_bindings'::regclass AND confrelid='auth.users'::regclass AND confdeltype='n' AND confupdtype='r' FROM pg_constraint WHERE conname='principal_auth_bindings_auth_user_id_fkey'), 'Auth FK target and actions are exact');
SELECT is((SELECT pg_get_userbyid(relowner) FROM pg_class WHERE oid='app_private.principal_auth_bindings'::regclass), 'schoolos_schema_owner', 'Auth binding table retained its owner');

SELECT is((SELECT count(*) FROM pg_roles WHERE rolname LIKE 'schoolos_%'), 12::bigint, '12 application roles');
SELECT is((SELECT count(*) FROM pg_roles WHERE rolname LIKE 'schoolos_%' AND rolcanlogin), 3::bigint, 'only three purpose-bound logins');
SELECT is((SELECT count(*) FROM pg_roles WHERE rolname LIKE 'schoolos_%' AND (rolsuper OR rolbypassrls OR rolinherit OR rolcreatedb OR rolcreaterole)), 0::bigint, 'application roles have no elevated attributes');
SELECT is((SELECT count(*) FROM pg_auth_members am JOIN pg_roles r ON r.oid=am.member WHERE r.rolname LIKE 'schoolos_%'), 0::bigint, 'application roles inherit no memberships');
SELECT ok(has_schema_privilege('schoolos_authz_reader','auth','USAGE'), 'authz reader can resolve managed Auth helpers');
SELECT ok(NOT has_schema_privilege('schoolos_authz_reader','auth','CREATE'), 'authz reader cannot create in Auth schema');
SELECT ok(NOT has_any_column_privilege('schoolos_authz_reader','auth.users','SELECT'), 'authz reader cannot select Auth users or columns');
SELECT ok(NOT has_any_column_privilege('schoolos_authz_reader','auth.users','INSERT'), 'authz reader cannot insert Auth users or columns');
SELECT ok(NOT has_any_column_privilege('schoolos_authz_reader','auth.users','UPDATE'), 'authz reader cannot update Auth users or columns');
SELECT ok(NOT has_table_privilege('schoolos_authz_reader','auth.users','DELETE'), 'authz reader cannot delete Auth users');
SELECT ok(has_function_privilege('schoolos_authz_reader','auth.uid()','EXECUTE'), 'authz reader can execute managed auth.uid');
SELECT ok(has_function_privilege('schoolos_authz_reader','auth.jwt()','EXECUTE'), 'authz reader can execute managed auth.jwt');
SELECT is((SELECT count(*) FROM pg_default_acl d JOIN pg_roles r ON r.oid=d.defaclrole WHERE r.rolname LIKE 'schoolos_%' AND d.defaclobjtype='f'), 9::bigint, 'nine function-owner default ACLs');
SELECT is((SELECT count(*) FROM pg_default_acl d JOIN pg_roles r ON r.oid=d.defaclrole CROSS JOIN LATERAL aclexplode(d.defaclacl) a WHERE r.rolname LIKE 'schoolos_%' AND d.defaclobjtype='f' AND a.grantee=0 AND a.privilege_type='EXECUTE'), 0::bigint, 'new application functions do not default to PUBLIC EXECUTE');

SELECT is((SELECT count(*) FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace WHERE n.nspname IN ('app','app_private') AND has_function_privilege('public',p.oid,'EXECUTE')), 0::bigint, 'PUBLIC cannot execute application functions');
SELECT is((SELECT count(*) FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace WHERE n.nspname IN ('app','app_private') AND has_function_privilege('anon',p.oid,'EXECUTE')), 0::bigint, 'anon cannot execute application functions');
SELECT is((SELECT count(*) FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace WHERE n.nspname IN ('app','app_private') AND has_function_privilege('service_role',p.oid,'EXECUTE')), 0::bigint, 'service_role has no application function shortcut');
SELECT is((SELECT count(*) FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace WHERE n.nspname IN ('app','app_private') AND has_function_privilege('authenticated',p.oid,'EXECUTE')), 6::bigint, 'authenticated can execute exactly six reviewed read functions');
SELECT ok(NOT has_function_privilege('authenticated','app_private.current_principal_id()','EXECUTE') AND NOT has_function_privilege('authenticated','app_private.has_complete_grant(text,text,uuid)','EXECUTE'), 'authenticated cannot directly call internal identity/grant helpers');
SELECT is((SELECT count(*) FROM pg_class t JOIN pg_namespace n ON n.oid=t.relnamespace WHERE n.nspname IN ('app','app_private') AND t.relkind='r' AND has_any_column_privilege('authenticated',t.oid,'SELECT')), 5::bigint, 'authenticated has only five reviewed table read surfaces');
SELECT is((SELECT count(*) FROM pg_class t JOIN pg_namespace n ON n.oid=t.relnamespace WHERE n.nspname IN ('app','app_private') AND t.relkind='r' AND (has_table_privilege('authenticated',t.oid,'INSERT') OR has_table_privilege('authenticated',t.oid,'UPDATE') OR has_table_privilege('authenticated',t.oid,'DELETE') OR has_table_privilege('authenticated',t.oid,'TRUNCATE'))), 0::bigint, 'authenticated has no direct table mutation privilege');
SELECT is((SELECT count(*) FROM pg_class t JOIN pg_namespace n ON n.oid=t.relnamespace WHERE n.nspname IN ('app','app_private') AND t.relkind='r' AND (has_any_column_privilege('anon',t.oid,'SELECT') OR has_table_privilege('anon',t.oid,'INSERT'))), 0::bigint, 'anon has no application table access');

SELECT * FROM finish();
ROLLBACK;
