SET ROLE schoolos_schema_owner;
INSERT INTO app_private.principals(id,kind,label,system_purpose,state,created_by) VALUES('08000000-0000-4000-8000-000000000001','SYSTEM','DB08 disposable structural fixture','identity-reconciliation','ACTIVE','08000000-0000-4000-8000-000000000001');
INSERT INTO app_private.school_profiles(id,code,name,timezone,currency_code,locale,created_by) VALUES('08000000-0000-4000-8000-000000000002','DB08-LOCAL','Synthetic School','Asia/Riyadh','SAR','en','08000000-0000-4000-8000-000000000001');
INSERT INTO app.campuses(id,school_id,code,name,state,created_by) VALUES('08000000-0000-4000-8000-000000000003','08000000-0000-4000-8000-000000000002','MAIN','Synthetic Campus','ACTIVE','08000000-0000-4000-8000-000000000001');
INSERT INTO app.academic_years(id,school_id,code,label,starts_on,ends_on,state,created_by) VALUES('08000000-0000-4000-8000-000000000004','08000000-0000-4000-8000-000000000002','2026','2026','2026-01-01','2026-12-31','ACTIVE','08000000-0000-4000-8000-000000000001');
INSERT INTO app_private.people(id,display_name,created_by) VALUES('08000000-0000-4000-8000-000000000005','Synthetic learner without Student','08000000-0000-4000-8000-000000000001');
RESET ROLE;
