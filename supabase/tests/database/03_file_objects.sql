-- F23 metadata only; no object-storage provider or uploaded bytes.
BEGIN;
CREATE EXTENSION IF NOT EXISTS pgtap WITH SCHEMA extensions;
SET LOCAL search_path = extensions, pg_catalog, public;
SELECT plan(16);

SET ROLE schoolos_schema_owner;
INSERT INTO app_private.principals (id,kind,label,system_purpose,state,created_by)
VALUES ('11111111-1111-4111-8111-111111111111','SYSTEM','Synthetic actor','identity-reconciliation','ACTIVE','11111111-1111-4111-8111-111111111111');
INSERT INTO app_private.file_objects (id,uploaded_by_principal_id,storage_location_key,purpose_code,object_key,content_type,byte_size,content_hash,created_by)
VALUES ('44444444-4444-4444-8444-444444444444','11111111-1111-4111-8111-111111111111','LOCAL_TEST','ADMISSIONS','alpha','image/png',1,decode(repeat('ab',32),'hex'),'11111111-1111-4111-8111-111111111111');
RESET ROLE;
SELECT is((SELECT state FROM app_private.file_objects WHERE id='44444444-4444-4444-8444-444444444444'), 'PENDING'::text, 'new file starts PENDING');

SELECT throws_ok($sql$INSERT INTO app_private.file_objects (uploaded_by_principal_id,storage_location_key,purpose_code,object_key,content_type,byte_size,content_hash,created_by) VALUES ('11111111-1111-4111-8111-111111111111','LOCAL_TEST','ADMISSIONS','zero','image/png',0,decode(repeat('ab',32),'hex'),'11111111-1111-4111-8111-111111111111')$sql$, '23514'::character(5), NULL::text, 'zero bytes rejected');
SELECT throws_ok($sql$INSERT INTO app_private.file_objects (uploaded_by_principal_id,storage_location_key,purpose_code,object_key,content_type,byte_size,content_hash,created_by) VALUES ('11111111-1111-4111-8111-111111111111','LOCAL_TEST','ADMISSIONS','large','image/png',1048577,decode(repeat('ab',32),'hex'),'11111111-1111-4111-8111-111111111111')$sql$, '23514'::character(5), NULL::text, 'oversize bytes rejected');
SELECT throws_ok($sql$INSERT INTO app_private.file_objects (uploaded_by_principal_id,storage_location_key,purpose_code,object_key,content_type,byte_size,content_hash,created_by) VALUES ('11111111-1111-4111-8111-111111111111','LOCAL_TEST','ADMISSIONS','bad-hash','image/png',1,decode('ab','hex'),'11111111-1111-4111-8111-111111111111')$sql$, '23514'::character(5), NULL::text, 'non-SHA-256 hash length rejected');
SELECT throws_ok($sql$INSERT INTO app_private.file_objects (uploaded_by_principal_id,storage_location_key,purpose_code,object_key,content_type,byte_size,content_hash,created_by) VALUES ('11111111-1111-4111-8111-111111111111','LOCAL_TEST','bad-code','bad-purpose','image/png',1,decode(repeat('ab',32),'hex'),'11111111-1111-4111-8111-111111111111')$sql$, '23514'::character(5), NULL::text, 'invalid purpose code rejected');
SELECT throws_ok($sql$INSERT INTO app_private.file_objects (uploaded_by_principal_id,storage_location_key,purpose_code,object_key,content_type,byte_size,content_hash,created_by) VALUES ('11111111-1111-4111-8111-111111111111','LOCAL_TEST','ADMISSIONS','alpha','image/png',1,decode(repeat('ab',32),'hex'),'11111111-1111-4111-8111-111111111111')$sql$, '23505'::character(5), NULL::text, 'duplicate location/object key rejected');
SELECT throws_ok($sql$INSERT INTO app_private.file_objects (id,uploaded_by_principal_id,storage_location_key,purpose_code,object_key,content_type,byte_size,content_hash,replaces_file_id,created_by) VALUES ('55555555-5555-4555-8555-555555555555','11111111-1111-4111-8111-111111111111','LOCAL_TEST','ADMISSIONS','self','image/png',1,decode(repeat('ab',32),'hex'),'55555555-5555-4555-8555-555555555555','11111111-1111-4111-8111-111111111111')$sql$, '23514'::character(5), NULL::text, 'self replacement rejected');
SELECT throws_ok($sql$INSERT INTO app_private.file_objects (uploaded_by_principal_id,storage_location_key,purpose_code,object_key,content_type,byte_size,content_hash,state,created_by) VALUES ('11111111-1111-4111-8111-111111111111','LOCAL_TEST','ADMISSIONS','premature','image/png',1,decode(repeat('ab',32),'hex'),'AVAILABLE','11111111-1111-4111-8111-111111111111')$sql$, 'P0001'::character(5), NULL::text, 'new AVAILABLE file rejected');
SELECT throws_ok($sql$UPDATE app_private.file_objects SET object_key='rewritten' WHERE id='44444444-4444-4444-8444-444444444444'$sql$, 'P0001'::character(5), NULL::text, 'object key immutable');
SELECT throws_ok($sql$UPDATE app_private.file_objects SET uploaded_by_principal_id='99999999-9999-4999-8999-999999999999' WHERE id='44444444-4444-4444-8444-444444444444'$sql$, 'P0001'::character(5), NULL::text, 'uploader provenance immutable');
SELECT throws_ok($sql$UPDATE app_private.file_objects SET row_version=99 WHERE id='44444444-4444-4444-8444-444444444444'$sql$, 'P0001'::character(5), NULL::text, 'caller cannot set row_version');

UPDATE app_private.file_objects SET state='VALIDATED', validated_at=transaction_timestamp() WHERE id='44444444-4444-4444-8444-444444444444';
SELECT is((SELECT state FROM app_private.file_objects WHERE id='44444444-4444-4444-8444-444444444444'), 'VALIDATED'::text, 'PENDING to VALIDATED allowed');
UPDATE app_private.file_objects SET state='AVAILABLE' WHERE id='44444444-4444-4444-8444-444444444444';
SELECT is((SELECT state FROM app_private.file_objects WHERE id='44444444-4444-4444-8444-444444444444'), 'AVAILABLE'::text, 'VALIDATED to AVAILABLE allowed');
SELECT ok((SELECT validated_at IS NOT NULL FROM app_private.file_objects WHERE id='44444444-4444-4444-8444-444444444444'), 'AVAILABLE retains validation time');
SELECT throws_ok($sql$UPDATE app_private.file_objects SET validated_at=NULL WHERE id='44444444-4444-4444-8444-444444444444'$sql$, 'P0001'::character(5), NULL::text, 'validated_at cannot clear');
SELECT is((SELECT row_version FROM app_private.file_objects WHERE id='44444444-4444-4444-8444-444444444444'), 3::bigint, 'two valid updates advance row_version twice');
SELECT * FROM finish();
ROLLBACK;
