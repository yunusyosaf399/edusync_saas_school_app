-- F7 synthetic two-decimal School currency and verified private file metadata.
SET ROLE schoolos_schema_owner;
INSERT INTO app_private.finance_currency_units(id,school_id,currency_code,minor_unit_scale,created_by)
VALUES('08000000-0000-4000-8000-000000000100','08000000-0000-4000-8000-000000000002',
 'SAR',2,'08000000-0000-4000-8000-000000000001');
INSERT INTO app_private.file_objects(id,uploaded_by_principal_id,campus_id,storage_location_key,
 purpose_code,object_key,content_type,byte_size,content_hash,classification,created_by)
VALUES
 ('08000000-0000-4000-8000-000000000101','08000000-0000-4000-8000-000000000007',
 '08000000-0000-4000-8000-000000000003','test-private','f7-payment-1',
 'image/png',120,sha256(convert_to('proof-a','UTF8')),'PRIVATE','08000000-0000-4000-8000-000000000007'),
 ('08000000-0000-4000-8000-000000000102','08000000-0000-4000-8000-000000000007',
 '08000000-0000-4000-8000-000000000003','test-private','f7-payment-2',
 'application/pdf',120,sha256(convert_to('proof-b','UTF8')),'PRIVATE','08000000-0000-4000-8000-000000000007'),
 ('08000000-0000-4000-8000-000000000103','08000000-0000-4000-8000-000000000007',
 '08000000-0000-4000-8000-000000000003','test-private','f7-payment-3',
 'image/jpeg',120,sha256(convert_to('proof-c','UTF8')),'PRIVATE','08000000-0000-4000-8000-000000000007');
UPDATE app_private.file_objects SET state='VALIDATED',validated_at=clock_timestamp()
 WHERE id IN('08000000-0000-4000-8000-000000000101',
             '08000000-0000-4000-8000-000000000102',
             '08000000-0000-4000-8000-000000000103');
UPDATE app_private.file_objects SET state='AVAILABLE'
 WHERE id IN('08000000-0000-4000-8000-000000000101',
             '08000000-0000-4000-8000-000000000102',
             '08000000-0000-4000-8000-000000000103');
RESET ROLE;
