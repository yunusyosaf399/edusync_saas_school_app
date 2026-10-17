"""Post-D1 rollback-only local smoke for quarantined Student Profile history."""
from __future__ import annotations
from pathlib import Path
from domain_draft_guard import ROOT, discover_drafts

CANDIDATE = Path("supabase/proposals/student_profile_history_v1.sql.draft")
PASS_MARKER = "D1_STUDENT_PROFILE_HISTORY_CANDIDATE_PASS"
TYPED_TRIAL = Path("supabase/proposals/student_profile_typed_atomic_trial.sql.draft")
AUTH_PREFLIGHT = Path("supabase/proposals/student_profile_typed_auth_preflight_trial.sql.draft")
DIRECT_TRIAL = Path("supabase/proposals/student_profile_typed_direct_trial.sql.draft")
APPROVAL_TRIAL = Path("supabase/proposals/student_profile_typed_approval_trial.sql.draft")
APPROVAL_TEST = Path("supabase/proposals/student_profile_typed_approval_acceptance.sql.draft")
APPROVAL_BASELINE = Path("supabase/tests/domain/67_student_profile_p1_approval_review_apply.sql")
APPROVAL_PASS_MARKER = "D1_STUDENT_PROFILE_TYPED_APPROVAL_HISTORY_PASS"
DIRECT_PASS_MARKER = "D1_STUDENT_PROFILE_TYPED_DIRECT_RECEIPT_PASS"
AUTH_BASELINE = Path("supabase/tests/domain/66_student_profile_p1_direct_history_authorization.sql")
AUTH_PASS_MARKER = "D1_STUDENT_PROFILE_TYPED_AUTH_PREFLIGHT_PASS"
TRIAL_SQL = "-- Typed six-field plan and truly atomic Student row + restricted revision smoke.\n-- This is a separate transaction savepoint inside the outer rollback test.\n\\ir fixtures/command_actor.sql\nSET ROLE schoolos_schema_owner;\nINSERT INTO app_private.students (\n  id,person_id,school_student_id,admission_number,admission_serial,\n  admitted_on,current_status,date_of_birth,gender_code,previous_school,\n  general_contact,created_by\n) VALUES (\n  'c1000000-0000-4000-8000-000000000001',\n  '10000000-0000-4000-8000-000000000001',\n  'TRIAL-STUDENT-1','TRIAL-ADM-1',98766,CURRENT_DATE-20,'ACTIVE',\n  NULL,'F','Old School','1234','11111111-1111-4111-8111-111111111111'\n);\nINSERT INTO app_private.student_status_transitions(\n  id,student_id,previous_status,new_status,effective_on,\n  sequence_number,reason,created_by\n) VALUES (\n  'c1000000-0000-4000-8000-000000000002',\n  'c1000000-0000-4000-8000-000000000001',\n  NULL,'ACTIVE',CURRENT_DATE-20,1,'Trial initial ACTIVE',\n  '11111111-1111-4111-8111-111111111111'\n);\nUPDATE app_private.operation_contracts SET enabled=true\n WHERE code='student.profile.update';\nINSERT INTO app_private.command_receipts(\n  id,principal_id,operation_id,command_kind,idempotency_key,\n  canonical_payload_hash,expected_target_version,state,\n  result_kind,result_ref,result_summary,completed_at,created_by\n) SELECT\n  'c1000000-0000-4000-8000-000000000003',\n  '55555555-5555-4555-8555-555555555555',\n  o.id,'student.profile.update','trial-typed-once',\n  pg_catalog.decode(pg_catalog.repeat('ac',32),'hex'),\n  1,'SUCCEEDED','D1_STUDENT_PROFILE',\n  'c1000000-0000-4000-8000-000000000001',\n  '{\"row_version\":2}'::jsonb,pg_catalog.clock_timestamp(),\n  '55555555-5555-4555-8555-555555555555'\nFROM app_private.operation_contracts o WHERE o.code='student.profile.update';\n\nDO $typed_trial_smoke$\nDECLARE\n  six_before jsonb:='{\"date_of_birth\":null,\"gender_code\":\"F\",\"nationality_code\":null,\"general_contact\":\"1234\",\"previous_school\":\"Old School\",\"profile_photo_file_id\":null}'::jsonb;\n  school jsonb:='{\"date_of_birth\":{\"action\":\"UNCHANGED\"},\"gender_code\":{\"action\":\"UNCHANGED\"},\"nationality_code\":{\"action\":\"UNCHANGED\"},\"general_contact\":{\"action\":\"UNCHANGED\"},\"previous_school\":{\"action\":\"SET\",\"value\":\"  Other School  \"},\"profile_photo_file_id\":{\"action\":\"UNCHANGED\"}}'::jsonb;\n  clear_contact jsonb:='{\"date_of_birth\":{\"action\":\"UNCHANGED\"},\"gender_code\":{\"action\":\"UNCHANGED\"},\"nationality_code\":{\"action\":\"UNCHANGED\"},\"general_contact\":{\"action\":\"CLEAR\"},\"previous_school\":{\"action\":\"UNCHANGED\"},\"profile_photo_file_id\":{\"action\":\"UNCHANGED\"}}'::jsonb;\n  unchanged jsonb:='{\"date_of_birth\":{\"action\":\"UNCHANGED\"},\"gender_code\":{\"action\":\"UNCHANGED\"},\"nationality_code\":{\"action\":\"UNCHANGED\"},\"general_contact\":{\"action\":\"UNCHANGED\"},\"previous_school\":{\"action\":\"UNCHANGED\"},\"profile_photo_file_id\":{\"action\":\"UNCHANGED\"}}'::jsonb;\n  projected jsonb;\n  observed bigint;\nBEGIN\n  projected:=app_private.d1_student_profile_typed_plan_trial(six_before,school);\n  IF projected->'after'->>'previous_school' <> 'Other School'\n     OR projected->'after'->>'general_contact' <> '1234'\n     OR projected->'after'->>'gender_code' <> 'F'\n     OR projected->'canonical_actions'->'previous_school'->>'value' <> 'Other School' THEN\n    RAISE EXCEPTION 'TYPED_TRIAL_UNCHANGED_OR_NORMALIZATION_FAILED';\n  END IF;\n  projected:=app_private.d1_student_profile_typed_plan_trial(six_before,clear_contact);\n  IF projected->'after'->'general_contact' <> 'null'::jsonb\n     OR projected->'after'->>'previous_school' <> 'Old School' THEN\n    RAISE EXCEPTION 'TYPED_TRIAL_CLEAR_VS_UNCHANGED_FAILED';\n  END IF;\n  BEGIN\n    PERFORM app_private.d1_student_profile_typed_plan_trial(six_before,unchanged);\n    RAISE EXCEPTION 'TYPED_TRIAL_NO_OP_NOT_REJECTED';\n  EXCEPTION WHEN OTHERS THEN\n    IF SQLERRM NOT LIKE 'D1_TYPED_PROFILE_NO_OP%' THEN RAISE; END IF;\n  END;\n  BEGIN\n    PERFORM app_private.d1_student_profile_typed_plan_trial(\n      six_before,school||'{\"person_id\":{\"action\":\"CLEAR\"}}'::jsonb);\n    RAISE EXCEPTION 'TYPED_TRIAL_UNKNOWN_FIELD_NOT_REJECTED';\n  EXCEPTION WHEN OTHERS THEN\n    IF SQLERRM NOT LIKE 'D1_TYPED_PROFILE_FIELD_ALLOWLIST%' THEN RAISE; END IF;\n  END;\n  BEGIN\n    PERFORM app_private.d1_student_profile_typed_plan_trial(\n      six_before,jsonb_set(school,'{previous_school}',\n        '{\"action\":\"SET\",\"value\":null}'::jsonb));\n    RAISE EXCEPTION 'TYPED_TRIAL_SET_NULL_NOT_REJECTED';\n  EXCEPTION WHEN OTHERS THEN\n    IF SQLERRM NOT LIKE 'D1_TYPED_PROFILE_SET_VALUE_REQUIRED%' THEN RAISE; END IF;\n  END;\n  BEGIN\n    PERFORM app_private.d1_student_profile_typed_plan_trial(\n      six_before,jsonb_set(school,'{previous_school}',\n        '{\"action\":\"SET\",\"value\":\"  \"}'::jsonb));\n    RAISE EXCEPTION 'TYPED_TRIAL_SET_BLANK_NOT_REJECTED';\n  EXCEPTION WHEN OTHERS THEN\n    IF SQLERRM NOT LIKE 'D1_TYPED_PROFILE_SET_BLANK%' THEN RAISE; END IF;\n  END;\n  BEGIN\n    PERFORM app_private.d1_student_profile_typed_plan_trial(\n      six_before,jsonb_set(school,'{date_of_birth}',\n        '{\"action\":\"SET\",\"value\":\"2023-02-31\"}'::jsonb));\n    RAISE EXCEPTION 'TYPED_TRIAL_INVALID_DATE_NOT_REJECTED';\n  EXCEPTION WHEN OTHERS THEN\n    IF SQLERRM NOT LIKE 'D1_TYPED_PROFILE_DATE_INVALID%' THEN RAISE; END IF;\n  END;\n  observed:=app_private.d1_student_profile_typed_write_trial(\n    'c1000000-0000-4000-8000-000000000001',1,school,\n    'Trial change to previous school','55555555-5555-4555-8555-555555555555',\n    'c1000000-0000-4000-8000-000000000003',NULL);\n  IF observed<>2 OR NOT EXISTS (\n    SELECT 1 FROM app_private.students s\n    WHERE s.id='c1000000-0000-4000-8000-000000000001'\n      AND s.row_version=2 AND s.previous_school='Other School'\n      AND s.general_contact='1234' AND s.gender_code='F'\n  ) OR NOT EXISTS (\n    SELECT 1 FROM app_private.student_profile_revisions r\n    WHERE r.student_id='c1000000-0000-4000-8000-000000000001'\n      AND r.old_row_version=1 AND r.new_row_version=2\n      AND r.old_previous_school='Old School'\n      AND r.new_previous_school='Other School'\n      AND r.old_general_contact='1234'\n      AND r.new_general_contact='1234'\n      AND r.private_reason='Trial change to previous school'\n  ) THEN\n    RAISE EXCEPTION 'TYPED_TRIAL_ATOMIC_HISTORY_FAILED';\n  END IF;\n  BEGIN\n    PERFORM app_private.d1_student_profile_typed_write_trial(\n      'c1000000-0000-4000-8000-000000000001',1,school,\n      'Trial replay','55555555-5555-4555-8555-555555555555',\n      'c1000000-0000-4000-8000-000000000003',NULL);\n    RAISE EXCEPTION 'TYPED_TRIAL_STALE_REPLAY_MUTATED';\n  EXCEPTION WHEN OTHERS THEN\n    IF SQLERRM NOT LIKE 'D1_TYPED_PROFILE_STALE_OR_ABSENT%' THEN RAISE; END IF;\n  END;\n  IF (SELECT count(*) FROM app_private.student_profile_revisions)<>1 THEN\n    RAISE EXCEPTION 'TYPED_TRIAL_REPLAY_INSERTED_EXTRA_HISTORY';\n  END IF;\nEND\n$typed_trial_smoke$;\nRESET ROLE;\n"
TYPED_FIXTURE = Path("supabase/tests/domain/fixtures/command_actor.sql")
TYPED_PASS_MARKER = "D1_STUDENT_PROFILE_TYPED_ATOMIC_TRIAL_PASS"


PROBE = r"""
SET ROLE schoolos_schema_owner;
DO $profile_history_smoke$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_catalog.pg_class c
    JOIN pg_catalog.pg_namespace n ON n.oid=c.relnamespace
    WHERE n.nspname='app_private' AND c.relname='student_profile_revisions'
      AND c.relkind='r' AND c.relrowsecurity AND c.relforcerowsecurity
  ) THEN RAISE EXCEPTION 'HISTORY_RLS_NOT_FORCED'; END IF;
  IF (SELECT count(*) FROM pg_catalog.pg_constraint
      WHERE conrelid='app_private.student_profile_revisions'::regclass
        AND contype IN ('p','u')) <> 3 THEN
    RAISE EXCEPTION 'HISTORY_UNIQUENESS_DRIFT';
  END IF;
  IF (SELECT count(*) FROM pg_catalog.pg_constraint
      WHERE conrelid='app_private.student_profile_revisions'::regclass
        AND contype='f') <> 6 THEN
    RAISE EXCEPTION 'HISTORY_FK_DRIFT';
  END IF;
  IF NOT EXISTS (
    SELECT 1 FROM pg_catalog.pg_trigger
    WHERE tgrelid='app_private.student_profile_revisions'::regclass
      AND NOT tgisinternal AND tgname='student_profile_revisions_immutable'
      AND (tgtype & 8)=8 AND (tgtype & 16)=16
  ) THEN RAISE EXCEPTION 'HISTORY_IMMUTABILITY_MISSING'; END IF;
  IF (SELECT count(*) FROM pg_catalog.pg_policies
      WHERE schemaname='app_private' AND tablename='student_profile_revisions') <> 1 THEN
    RAISE EXCEPTION 'HISTORY_POLICY_DRIFT';
  END IF;
  IF EXISTS (
    SELECT 1 FROM (VALUES
      ('anon'),('authenticated'),('service_role'),
      ('schoolos_student_executor'),('schoolos_workflow_executor'),
      ('schoolos_read_executor'),('schoolos_authz_reader')
    ) AS principals(role_name)
    WHERE pg_catalog.has_table_privilege(
      principals.role_name,'app_private.student_profile_revisions',
      'SELECT,INSERT,UPDATE,DELETE,TRUNCATE,REFERENCES,TRIGGER')
  ) THEN RAISE EXCEPTION 'HISTORY_PRIVILEGE_LEAK'; END IF;
  BEGIN
    INSERT INTO app_private.student_profile_revisions
      (student_id,old_row_version,new_row_version,command_receipt_id,
       applied_by_principal_id,private_reason,old_previous_school,new_previous_school)
    VALUES (
      'ff000000-0000-4000-8000-000000000001',2,2,
      'ff000000-0000-4000-8000-000000000002',
      'ff000000-0000-4000-8000-000000000003',
      'local synthetic impossible version',NULL,'Candidate School');
    RAISE EXCEPTION 'HISTORY_IMPOSSIBLE_VERSION_ACCEPTED';
  EXCEPTION WHEN check_violation THEN NULL;
  END;
  IF EXISTS (SELECT 1 FROM app_private.student_profile_revisions) THEN
    RAISE EXCEPTION 'HISTORY_BAD_ROW_PERSISTED';
  END IF;
END
$profile_history_smoke$;
RESET ROLE;
"""
CLEANUP_PROBE = """
DO $history_cleanup$
BEGIN
  IF pg_catalog.to_regclass('app_private.student_profile_revisions') IS NOT NULL THEN
    RAISE EXCEPTION 'HISTORY_CANDIDATE_NOT_ROLLED_BACK';
  END IF;
END
$history_cleanup$;
"""

def validate_candidate_source(source: str, root: Path = ROOT) -> None:
    if not source.startswith("-- STUDENT_PROFILE_HISTORY_POST_D1_REVIEW_ONLY\n"):
        raise RuntimeError("HISTORY_REVIEW_ONLY_HEADER")
    if "\r" in source or "\x00" in source or not source.endswith("\n"):
        raise RuntimeError("HISTORY_SOURCE_ENCODING")
    for token in (
        "CREATE TABLE app_private.student_profile_revisions",
        "old_row_version > 0 AND new_row_version = old_row_version + 1",
        "old_previous_school IS DISTINCT FROM new_previous_school",
        "CREATE TRIGGER student_profile_revisions_immutable",
        "ALTER TABLE app_private.student_profile_revisions FORCE ROW LEVEL SECURITY",
        "FOR ALL TO schoolos_schema_owner",
        "REVOKE ALL ON TABLE app_private.student_profile_revisions",
        "RESET ROLE;",
    ):
        if token not in source:
            raise RuntimeError("HISTORY_CANDIDATE_SOURCE_GUARD " + token)
    for token in (
        "\nCOMMIT;", "\nBEGIN;", "CREATE ROLE ", "CREATE EXTENSION ",
        "GRANT SELECT", "GRANT INSERT", "GRANT EXECUTE",
    ):
        if token in source.upper():
            raise RuntimeError("HISTORY_CANDIDATE_UNSAFE_SQL " + token.strip())
    if CANDIDATE.parts[1] == "migrations":
        raise RuntimeError("HISTORY_CANDIDATE_MIGRATION_PATH")
    if any(path.name == CANDIDATE.name for path in discover_drafts(root)):
        raise RuntimeError("HISTORY_CANDIDATE_ASSEMBLED_IN_D1")


def validate_typed_trial_source(source: str, root: Path = ROOT) -> None:
    if not source.startswith("-- STUDENT_PROFILE_TYPED_ATOMIC_TRIAL_ONLY\n"):
        raise RuntimeError("TYPED_TRIAL_INVALID_HEADER")
    if "\r" in source or "\x00" in source or not source.endswith("\n"):
        raise RuntimeError("TYPED_TRIAL_INVALID_ENCODING")
    for required in (
        "SECURITY INVOKER",
        "CURRENT_USER <> 'schoolos_schema_owner'",
        "FOR UPDATE;",
        "app_private.d1_student_profile_typed_plan_trial(",
        "app_private.d1_student_profile_typed_write_trial(",
        "CREATE FUNCTION app_private.d1_student_profile_typed_plan_trial(",
        "CREATE FUNCTION app_private.d1_student_profile_typed_write_trial(",
        "D1_TYPED_PROFILE_NO_OP",
        "D1_TYPED_PROFILE_PHOTO_SET_NEEDS_ENTITLEMENT",
        "INSERT INTO app_private.student_profile_revisions",
        "REVOKE ALL ON FUNCTION",
    ):
        if required not in source:
            raise RuntimeError("TYPED_TRIAL_SOURCE_GUARD "+required)
    for forbidden in ("\nCOMMIT;", "\nBEGIN;", "GRANT EXECUTE ",
        "GRANT SELECT ", "GRANT INSERT ", "CREATE ROLE ",
        "LANGUAGE plpgsql VOLATILE SECURITY DEFINER",
        "ALTER TABLE app_private.student_profile_revisions DISABLE"):
        if forbidden in source.upper() if forbidden.isupper() else forbidden in source:
            raise RuntimeError("TYPED_TRIAL_UNSAFE_SQL "+forbidden.strip())
    if TYPED_TRIAL.parts[1] != "proposals":
        raise RuntimeError("TYPED_TRIAL_NOT_QUARANTINED")
    if any(path.name == TYPED_TRIAL.name for path in discover_drafts(root)):
        raise RuntimeError("TYPED_TRIAL_ASSEMBLED_IN_D1")

TYPED_CLEANUP = """
DO $trial_cleanup$
BEGIN
  IF pg_catalog.to_regprocedure('app_private.d1_student_profile_typed_plan_trial(jsonb,jsonb)') IS NOT NULL
    OR pg_catalog.to_regprocedure('app_private.d1_student_profile_typed_write_trial(uuid,bigint,jsonb,text,uuid,uuid,uuid)') IS NOT NULL THEN
    RAISE EXCEPTION 'TYPED_TRIAL_FUNCTIONS_NOT_ROLLED_BACK';
  END IF;
END
$trial_cleanup$;
"""


def validate_typed_auth_preflight_source(source: str, root: Path = ROOT) -> None:
    if not source.startswith("-- STUDENT_PROFILE_TYPED_AUTH_PREFLIGHT_TRIAL_ONLY\n"):
        raise RuntimeError("TYPED_AUTH_PREFLIGHT_QUARANTINE")
    if "\r" in source or "\x00" in source or not source.endswith("\n"):
        raise RuntimeError("TYPED_AUTH_PREFLIGHT_ENCODING")
    for required in (
        "CREATE FUNCTION app.d1_student_profile_typed_preflight_trial(",
        "SET ROLE schoolos_student_executor;",
        "SECURITY DEFINER",
        "app_private.d1_student_profile_typed_plan_trial(original,p_actions)",
        "app_private.d1_profile_authorized(",
        "app_private.d1_profile_policy(",
        "app_private.d1_lock_current_principal(actor)",
        "pg_catalog.pg_advisory_xact_lock_shared(71001,1)",
        "FOR UPDATE;",
        "D1_TYPED_PREFLIGHT_DENIED",
        "D1_TYPED_PREFLIGHT_PLACEMENT_OR_CAMPUS",
        "D1_TYPED_PREFLIGHT_PHOTO_ENTITLEMENT_PENDING",
        "REVOKE CREATE ON SCHEMA app FROM schoolos_student_executor;",
    ):
        if required not in source:
            raise RuntimeError("TYPED_AUTH_PREFLIGHT_REQUIRED "+required)
    for disallowed in (
        "\nCOMMIT;","\nBEGIN;",
        "CREATE TABLE ","DROP TABLE ","UPDATE APP_PRIVATE.STUDENTS ",
        "INSERT INTO APP_PRIVATE.STUDENTS ", "ALTER TABLE APP_PRIVATE.STUDENTS ",
        "GRANT SELECT ON TABLE APP_PRIVATE.STUDENT_PROFILE_REVISIONS",
        "GRANT INSERT ON TABLE APP_PRIVATE.STUDENT_PROFILE_REVISIONS",
        "SET ROLE POSTGRES;",
    ):
        if disallowed in source.upper():
            raise RuntimeError("TYPED_AUTH_PREFLIGHT_UNSAFE_SQL "+disallowed.strip())
    if AUTH_PREFLIGHT.parts[1]!="proposals" or any(
      item.name==AUTH_PREFLIGHT.name for item in discover_drafts(root)
    ):
        raise RuntimeError("TYPED_AUTH_PREFLIGHT_ACTIVE_MIGRATION")

AUTH_INSERT_ANCHOR = (
  "SELECT * FROM app.d1_change_student_profile(\n"
  " 'b1000000-0000-4000-8000-000000000001',NULL,NULL,NULL,NULL,NULL,\n"
  " 'Old Academy',NULL,:'start_expected_version'::bigint,\n"
  " 'student-profile-success-one'\n"
  ") \\gset profile_one_"
)

def render_auth_trial_sql(source66: str, fixture: str, history: str,
                          typed: str, auth: str, checks: str) -> str:
    if source66.count("BEGIN;\n") != 1 or not source66.rstrip().endswith("ROLLBACK;"):
        raise RuntimeError("TYPED_AUTH_BASELINE_BOUNDARY")
    if source66.count(r"\ir fixtures/command_actor.sql")!=1:
        raise RuntimeError("TYPED_AUTH_FIXTURE_BOUNDARY")
    if source66.count(AUTH_INSERT_ANCHOR)!=1:
        raise RuntimeError("TYPED_AUTH_ANCHOR_MISMATCH")
    baseline=source66.replace(r"\ir fixtures/command_actor.sql",fixture)
    baseline=baseline.replace("BEGIN;\n",
      "BEGIN;\n"+history+"\n"+typed+"\n"+auth+"\n",1)
    baseline=baseline.replace(AUTH_INSERT_ANCHOR,
      checks+"\n"+AUTH_INSERT_ANCHOR,1)
    if r"\ir " in baseline:
        raise RuntimeError("TYPED_AUTH_UNRESOLVED_INCLUDE")
    return baseline

AUTH_TRIAL_CHECKS = "\n-- Added inside the existing 66-suite rollback transaction, just before\n-- its first authenticated DIRECT success, with real placement, grant and P1 policy.\nSELECT pg_catalog.set_config('schoolos_test.typed_preflight_expected',\n  :'start_expected_version',true);\nDO $typed_preflight_auth$\nDECLARE\n  v bigint:=current_setting('schoolos_test.typed_preflight_expected')::bigint;\n  student uuid:='b1000000-0000-4000-8000-000000000001';\n  actions jsonb:='{\"date_of_birth\":{\"action\":\"UNCHANGED\"},\"gender_code\":{\"action\":\"UNCHANGED\"},\"nationality_code\":{\"action\":\"UNCHANGED\"},\"general_contact\":{\"action\":\"UNCHANGED\"},\"previous_school\":{\"action\":\"SET\",\"value\":\"  Other Academy  \"},\"profile_photo_file_id\":{\"action\":\"UNCHANGED\"}}'::jsonb;\nBEGIN\n  IF app.d1_student_profile_typed_preflight_trial(student,NULL,v,actions,\n     'Private academic record correction','DIRECT') IS DISTINCT FROM true THEN\n    RAISE EXCEPTION 'TYPED_AUTH_PREFLIGHT_VALID_DIRECT_DENIED';\n  END IF;\n  BEGIN\n    PERFORM app.d1_student_profile_typed_preflight_trial(\n      student,'e9000000-0000-4000-8000-000000000099',v,actions,'reason','DIRECT');\n    RAISE EXCEPTION 'TYPED_AUTH_PREFLIGHT_WRONG_CAMPUS_ACCEPTED';\n  EXCEPTION WHEN OTHERS THEN\n    IF SQLERRM NOT LIKE 'D1_TYPED_PREFLIGHT_PLACEMENT_OR_CAMPUS%' THEN RAISE; END IF;\n  END;\n  BEGIN\n    PERFORM app.d1_student_profile_typed_preflight_trial(\n      student,NULL,v+1,actions,'reason','DIRECT');\n    RAISE EXCEPTION 'TYPED_AUTH_PREFLIGHT_STALE_ACCEPTED';\n  EXCEPTION WHEN OTHERS THEN\n    IF SQLERRM NOT LIKE 'D1_TYPED_PREFLIGHT_STALE%' THEN RAISE; END IF;\n  END;\n  BEGIN\n    PERFORM app.d1_student_profile_typed_preflight_trial(\n      student,NULL,v,actions,'reason','APPROVAL');\n    RAISE EXCEPTION 'TYPED_AUTH_PREFLIGHT_WRONG_ROUTE_ACCEPTED';\n  EXCEPTION WHEN OTHERS THEN\n    IF SQLERRM NOT LIKE 'D1_TYPED_PREFLIGHT_ROUTE%' THEN RAISE; END IF;\n  END;\n  BEGIN\n    PERFORM app.d1_student_profile_typed_preflight_trial(\n      'b1000000-0000-4000-8000-000000000099',NULL,v,actions,'reason','DIRECT');\n    RAISE EXCEPTION 'TYPED_AUTH_PREFLIGHT_MISSING_STUDENT_ACCEPTED';\n  EXCEPTION WHEN OTHERS THEN\n    IF SQLERRM NOT LIKE 'D1_TYPED_PREFLIGHT_PLACEMENT_OR_CAMPUS%' THEN RAISE; END IF;\n  END;\n  BEGIN\n    PERFORM app.d1_student_profile_typed_preflight_trial(\n      student,NULL,v,\n      pg_catalog.jsonb_set(actions,'{previous_school}','{\"action\":\"UNCHANGED\"}'),\n      'reason','DIRECT');\n    RAISE EXCEPTION 'TYPED_AUTH_PREFLIGHT_NOOP_ACCEPTED';\n  EXCEPTION WHEN OTHERS THEN\n    IF SQLERRM NOT LIKE 'D1_TYPED_PROFILE_NO_OP%' THEN RAISE; END IF;\n  END;\n  BEGIN\n    PERFORM app.d1_student_profile_typed_preflight_trial(\n      student,NULL,v,\n      pg_catalog.jsonb_set(actions,'{profile_photo_file_id}',\n        '{\"action\":\"SET\",\"value\":\"e9000000-0000-4000-8000-000000000010\"}'),\n      'reason','DIRECT');\n    RAISE EXCEPTION 'TYPED_AUTH_PREFLIGHT_UNVERIFIED_PHOTO_ACCEPTED';\n  EXCEPTION WHEN OTHERS THEN\n    IF SQLERRM NOT LIKE 'D1_TYPED_PREFLIGHT_PHOTO_ENTITLEMENT_PENDING%' THEN RAISE; END IF;\n  END;\nEND\n$typed_preflight_auth$;\nRESET ROLE;\nSAVEPOINT typed_preflight_revocation_probe;\nSET ROLE schoolos_schema_owner;\nUPDATE app_private.assignment_permission_scopes\n  SET revoked_at=pg_catalog.clock_timestamp()\n  WHERE id='b6000000-0000-4000-8000-000000000012';\nSET ROLE authenticated;\nDO $typed_preflight_revoked$\nDECLARE\n  v bigint:=current_setting('schoolos_test.typed_preflight_expected')::bigint;\n  actions jsonb:='{\"date_of_birth\":{\"action\":\"UNCHANGED\"},\"gender_code\":{\"action\":\"UNCHANGED\"},\"nationality_code\":{\"action\":\"UNCHANGED\"},\"general_contact\":{\"action\":\"UNCHANGED\"},\"previous_school\":{\"action\":\"SET\",\"value\":\"Other Academy\"},\"profile_photo_file_id\":{\"action\":\"UNCHANGED\"}}'::jsonb;\nBEGIN\n  BEGIN\n    PERFORM app.d1_student_profile_typed_preflight_trial(\n      'b1000000-0000-4000-8000-000000000001',NULL,v,actions,'reason','DIRECT');\n    RAISE EXCEPTION 'TYPED_AUTH_PREFLIGHT_REVOKED_GRANT_ACCEPTED';\n  EXCEPTION WHEN OTHERS THEN\n    IF SQLERRM NOT LIKE 'D1_TYPED_PREFLIGHT_DENIED%' THEN RAISE; END IF;\n  END;\nEND\n$typed_preflight_revoked$;\nRESET ROLE;\nROLLBACK TO SAVEPOINT typed_preflight_revocation_probe;\nSET ROLE authenticated;\n"

AUTH_CLEANUP = """
DO $cleanup$
BEGIN
  IF pg_catalog.to_regprocedure('app.d1_student_profile_typed_preflight_trial(uuid,uuid,bigint,jsonb,text,text)') IS NOT NULL
    OR pg_catalog.to_regclass('app_private.student_profile_revisions') IS NOT NULL THEN
    RAISE EXCEPTION 'TYPED_AUTH_PREFLIGHT_NOT_ROLLED_BACK';
  END IF;
END
$cleanup$;
"""

def run_typed_authenticated_preflight(container: str, run_psql,
      history: str, typed: str, root: Path = ROOT) -> None:
    auth=(Path(root)/AUTH_PREFLIGHT).read_text(encoding="utf-8")
    validate_typed_auth_preflight_source(auth,root)
    src=(Path(root)/AUTH_BASELINE).read_text(encoding="utf-8")
    fixture=(Path(root)/TYPED_FIXTURE).read_text(encoding="utf-8")
    prepared=render_auth_trial_sql(src,fixture,history,typed,auth,AUTH_TRIAL_CHECKS)
    if container!="supabase_db_saas_OS_school_app":
        raise RuntimeError("TYPED_AUTH_PREFLIGHT_LOCAL_CONTAINER_ONLY")
    run_psql(container,prepared,"D1_STUDENT_PROFILE_TYPED_AUTH_PREFLIGHT",timeout=300)
    run_psql(container,AUTH_CLEANUP,"D1_STUDENT_PROFILE_TYPED_AUTH_PREFLIGHT_CLEANUP",timeout=45)
    print(AUTH_PASS_MARKER+" authenticated DIRECT scope/P1/preflight+revocation, rollback-only")



def validate_typed_direct_source(source: str, root: Path = ROOT) -> None:
    if not source.startswith("-- STUDENT_PROFILE_TYPED_DIRECT_ROLLBACK_ONLY\n"):
        raise RuntimeError("D1_DIRECT_TRIAL_QUARANTINE")
    if "\r" in source or "\x00" in source or not source.endswith("\n"):
        raise RuntimeError("D1_DIRECT_TRIAL_ENCODING")
    for required in (
        "CREATE FUNCTION app.d1_student_profile_typed_direct_trial(",
        "CREATE FUNCTION app_private.d1_student_profile_direct_canonical_trial(",
        "app_private.d1_command_receipt_lookup(",
        "app_private.d1_lock_current_principal(receipt.actor_id)",
        "app_private.d1_profile_authorized(",
        "app_private.d1_profile_policy(",
        "app.d1_student_profile_typed_preflight_trial(",
        "app_private.d1_student_profile_typed_plan_trial(",
        "INSERT INTO app_private.student_profile_revisions",
        "app_private.d1_profile_receipt(",
        "app_private.d1_profile_audit(",
        "app_private.d1_profile_student_event(",
        "FOR UPDATE;",
        "D1_TYPED_DIRECT_STALE",
        "CREATE POLICY sprev_typed_direct_trial",
        "REVOKE CREATE ON SCHEMA app_private,app FROM schoolos_student_executor;",
    ):
        if required not in source:
            raise RuntimeError("D1_DIRECT_TRIAL_SOURCE_MISSING "+required)
    for forbidden in ("\nCOMMIT;", "\nBEGIN;", "CREATE TABLE ",
       "CREATE ROLE ", "DROP TABLE ", "DISABLE ROW LEVEL SECURITY",
       "GRANT SELECT ON APP_PRIVATE.STUDENT_PROFILE_REVISIONS",
       "GRANT UPDATE ON APP_PRIVATE.STUDENT_PROFILE_REVISIONS",
       "GRANT DELETE ON APP_PRIVATE.STUDENT_PROFILE_REVISIONS"):
        if forbidden in source.upper():
            raise RuntimeError("D1_DIRECT_TRIAL_UNSAFE_SQL "+forbidden.strip())
    if DIRECT_TRIAL.parts[1]!="proposals" or any(
       f.name==DIRECT_TRIAL.name for f in discover_drafts(root)):
        raise RuntimeError("D1_DIRECT_TRIAL_ACTIVE_MIGRATION")

DIRECT_TRIAL_TESTS = "-- A second isolated replay of the genuine authenticated suite 66 fixture.\n-- SAVEPOINT means the original legacy suite continues with unchanged version.\nSAVEPOINT typed_direct_trial_boundary;\nSELECT pg_catalog.set_config('schoolos_test.direct_initial_version',\n   :'start_expected_version',true);\nDO $real_direct$\nDECLARE\n s uuid:='b1000000-0000-4000-8000-000000000001';\n v bigint:=current_setting('schoolos_test.direct_initial_version')::bigint;\n req jsonb:='{\"date_of_birth\":{\"action\":\"UNCHANGED\"},\"gender_code\":{\"action\":\"UNCHANGED\"},\"nationality_code\":{\"action\":\"UNCHANGED\"},\"general_contact\":{\"action\":\"UNCHANGED\"},\"previous_school\":{\"action\":\"SET\",\"value\":\"  Corrected Academy  \"},\"profile_photo_file_id\":{\"action\":\"UNCHANGED\"}}'::jsonb;\n normalized jsonb;\n r bigint;\nBEGIN\n  SELECT x.row_version INTO r FROM app.d1_student_profile_typed_direct_trial(\n    s,NULL,v,req,'  Private correction  ','student-typed-direct-one') x;\n  IF r<>v+1 THEN RAISE EXCEPTION 'TYPED_DIRECT_SUCCESS_VERSION_FAIL'; END IF;\n  normalized:=pg_catalog.jsonb_set(req,'{previous_school}',\n    '{\"action\":\"SET\",\"value\":\"Corrected Academy\"}'::jsonb);\n  SELECT x.row_version INTO r FROM app.d1_student_profile_typed_direct_trial(\n    s,NULL,v,normalized,'Private correction','student-typed-direct-one') x;\n  IF r<>v+1 THEN RAISE EXCEPTION 'TYPED_DIRECT_CANONICAL_REPLAY_FAIL'; END IF;\n  BEGIN\n    PERFORM app.d1_student_profile_typed_direct_trial(\n      s,NULL,v,normalized,'Altered reason','student-typed-direct-one');\n    RAISE EXCEPTION 'TYPED_DIRECT_KEY_CONFLICT_ACCEPTED';\n  EXCEPTION WHEN OTHERS THEN\n    IF SQLERRM='TYPED_DIRECT_KEY_CONFLICT_ACCEPTED' THEN RAISE; END IF;\n  END;\n  BEGIN\n    PERFORM app.d1_student_profile_typed_direct_trial(\n      s,NULL,v,normalized,'Private correction','student-typed-new-stale');\n    RAISE EXCEPTION 'TYPED_DIRECT_STALE_ACCEPTED';\n  EXCEPTION WHEN OTHERS THEN\n    IF SQLERRM IS DISTINCT FROM 'D1_TYPED_DIRECT_STALE' THEN RAISE; END IF;\n  END;\n  BEGIN\n    PERFORM app.d1_student_profile_typed_direct_trial(\n      s,'e1000000-0000-4000-8000-000000000099',v,\n      normalized,'Private correction','student-typed-other-campus');\n    RAISE EXCEPTION 'TYPED_DIRECT_WRONG_CAMPUS_ACCEPTED';\n  EXCEPTION WHEN OTHERS THEN\n    IF SQLERRM IS DISTINCT FROM 'D1_TYPED_DIRECT_BAD_CONTEXT' THEN RAISE; END IF;\n  END;\n  BEGIN\n    PERFORM app.d1_student_profile_typed_direct_trial(\n      s,NULL,v+1,pg_catalog.jsonb_set(\n        normalized,'{previous_school}','{\"action\":\"UNCHANGED\"}'::jsonb),\n      'reason','student-typed-noop');\n    RAISE EXCEPTION 'TYPED_DIRECT_NOOP_ACCEPTED';\n  EXCEPTION WHEN OTHERS THEN\n    IF SQLERRM IS DISTINCT FROM 'D1_TYPED_PROFILE_NO_OP' THEN RAISE; END IF;\n  END;\n  BEGIN\n    PERFORM app.d1_student_profile_typed_direct_trial(\n      s,NULL,v+1,pg_catalog.jsonb_set(normalized,'{profile_photo_file_id}',\n      '{\"action\":\"SET\",\"value\":\"e1000000-0000-4000-8000-000000000001\"}'),\n      'reason','student-typed-unverified-photo');\n    RAISE EXCEPTION 'TYPED_DIRECT_PHOTO_WITHOUT_ENTITLEMENT_ACCEPTED';\n  EXCEPTION WHEN OTHERS THEN\n    IF SQLERRM IS DISTINCT FROM 'D1_TYPED_PREFLIGHT_PHOTO_ENTITLEMENT_PENDING' THEN RAISE; END IF;\n  END;\nEND\n$real_direct$;\nRESET ROLE;\nSET ROLE schoolos_schema_owner;\nDO $real_direct_evidence$\nDECLARE\n v bigint:=current_setting('schoolos_test.direct_initial_version')::bigint;\n sid uuid:='b1000000-0000-4000-8000-000000000001';\nBEGIN\n IF NOT EXISTS (SELECT 1 FROM app_private.students s WHERE s.id=sid\n     AND s.row_version=v+1 AND s.previous_school='Corrected Academy')\n     OR (SELECT count(*) FROM app_private.student_profile_revisions r\n          WHERE r.student_id=sid)<>1\n     OR NOT EXISTS (\n       SELECT 1 FROM app_private.student_profile_revisions r\n         JOIN app_private.command_receipts c ON c.id=r.command_receipt_id\n         WHERE r.student_id=sid\n           AND r.old_row_version=v AND r.new_row_version=v+1\n           AND r.old_previous_school IS NULL\n           AND r.new_previous_school='Corrected Academy'\n           AND r.private_reason='Private correction'\n           AND c.command_kind='student.profile.update'\n           AND c.state='SUCCEEDED')\n THEN RAISE EXCEPTION 'TYPED_DIRECT_RESTRICTED_HISTORY_BINDING_FAIL'; END IF;\n IF (SELECT count(*) FROM app_private.audit_events a\n      WHERE a.target_ref=sid AND a.event_type='student.profile.update')<>1\n   OR (SELECT count(*) FROM app_private.outbox_events o\n      WHERE o.aggregate_ref=sid AND o.event_type='student.profile_changed')<>1\n   OR EXISTS (SELECT 1 FROM app_private.outbox_events o\n      WHERE o.aggregate_ref=sid AND\n        (o.payload::text LIKE '%Corrected Academy%'\n         OR o.payload::text LIKE '%Private correction%'))\n THEN RAISE EXCEPTION 'TYPED_DIRECT_AUDIT_OUTBOX_PRIVACY_FAIL'; END IF;\nEND\n$real_direct_evidence$;\nRESET ROLE;\nROLLBACK TO SAVEPOINT typed_direct_trial_boundary;\nSET ROLE authenticated;\n"

DIRECT_TRIAL_CLEANUP = """
DO $direct_trial_rollback_check$
BEGIN
  IF pg_catalog.to_regprocedure('app.d1_student_profile_typed_direct_trial(uuid,uuid,bigint,jsonb,text,text)') IS NOT NULL
    OR pg_catalog.to_regprocedure('app_private.d1_student_profile_direct_canonical_trial(jsonb)') IS NOT NULL
    OR pg_catalog.to_regclass('app_private.student_profile_revisions') IS NOT NULL THEN
    RAISE EXCEPTION 'D1_TYPED_DIRECT_TRIAL_NOT_ROLLED_BACK';
  END IF;
END
$direct_trial_rollback_check$;
"""

def run_typed_direct_trial(container: str, run_psql, history: str,
    typed: str, root: Path = ROOT) -> None:
    auth=(Path(root)/AUTH_PREFLIGHT).read_text(encoding="utf-8")
    validate_typed_auth_preflight_source(auth,root)
    direct=(Path(root)/DIRECT_TRIAL).read_text(encoding="utf-8")
    validate_typed_direct_source(direct,root)
    baseline=(Path(root)/AUTH_BASELINE).read_text(encoding="utf-8")
    fixture=(Path(root)/TYPED_FIXTURE).read_text(encoding="utf-8")
    source=render_auth_trial_sql(baseline,fixture,history,typed,
       auth+"\n"+direct,DIRECT_TRIAL_TESTS)
    if container!="supabase_db_saas_OS_school_app":
        raise RuntimeError("D1_DIRECT_TRIAL_LOCAL_ONLY")
    run_psql(container,source,"D1_STUDENT_PROFILE_TYPED_DIRECT_INTEGRATION",timeout=300)
    run_psql(container,DIRECT_TRIAL_CLEANUP,"D1_STUDENT_PROFILE_TYPED_DIRECT_ROLLBACK_PROOF",timeout=45)
    print(DIRECT_PASS_MARKER+" authenticated DIRECT canonical replay/receipt/locked Student/private history/outbox")


def validate_typed_approval_source(source: str, root: Path = ROOT) -> None:
    if not source.startswith("-- STUDENT_PROFILE_TYPED_APPROVAL_ROLLBACK_ONLY\n"):
        raise RuntimeError("D1_APPROVAL_TRIAL_QUARANTINE")
    if "\r" in source or "\x00" in source or not source.endswith("\n"):
        raise RuntimeError("D1_APPROVAL_TRIAL_ENCODING")
    for required in (
        "CREATE FUNCTION app.d1_submit_student_profile_typed_approval_trial(",
        "CREATE FUNCTION app.d1_apply_student_profile_typed_approval_trial(",
        "CREATE FUNCTION app_private.d1_student_profile_typed_approval_resolve_trial(",
        "CREATE FUNCTION app_private.d1_student_profile_approved_postimage_trial(",
        "app_private.d1_student_profile_typed_plan_trial(",
        "app_private.d1_profile_submit(",
        "app.d1_apply_profile_request(",
        "app_private.d1_student_profile_approved_postimage_trial(",
        "INSERT INTO app_private.student_profile_revisions",
        "FOR UPDATE;",
        "schoolos_workflow_executor",
        "schoolos_student_executor",
        "D1_TYPED_APPROVAL_RECEIPT_BINDING",
        "D1_TYPED_APPROVAL_POSTIMAGE_MISMATCH",
        "REVOKE CREATE ON SCHEMA app FROM schoolos_workflow_executor;",
    ):
        if required not in source:
            raise RuntimeError("D1_APPROVAL_TRIAL_MISSING "+required)
    for forbidden in (
        "\nCOMMIT;", "\nBEGIN;", "CREATE ROLE ", "CREATE TABLE ",
        "DROP TABLE ", "DISABLE ROW LEVEL SECURITY",
        "GRANT SELECT ON APP_PRIVATE.STUDENTS TO AUTHENTICATED",
    ):
        if forbidden in source.upper():
            raise RuntimeError("D1_APPROVAL_TRIAL_UNSAFE "+forbidden.strip())
    if APPROVAL_TRIAL.parts[1]!="proposals" or any(
      p.name==APPROVAL_TRIAL.name for p in discover_drafts(root)):
        raise RuntimeError("D1_APPROVAL_TRIAL_ACTIVE_MIGRATION")

APPROVAL_INSERT_ANCHOR = (
  "SELECT * FROM app.d1_submit_student_profile_update(\n"
  " 'b1000000-0000-4000-8000-000000000001',NULL,NULL,NULL,NULL,NULL,\n"
  " 'Candidate P1 Approved School',NULL,:'initial_target_version'::bigint,\n"
  " 'Review previous-school data','p1-profile-submit-one'\n"
  ") \\gset req_"
)

APPROVAL_CLEANUP = """
DO $approval_trial_cleanup$
BEGIN
 IF pg_catalog.to_regprocedure(
   'app.d1_submit_student_profile_typed_approval_trial(uuid,uuid,bigint,jsonb,text,text)'
 ) IS NOT NULL
 OR pg_catalog.to_regprocedure(
   'app.d1_apply_student_profile_typed_approval_trial(uuid,bigint,text)'
 ) IS NOT NULL
 OR pg_catalog.to_regclass('app_private.student_profile_revisions') IS NOT NULL
 THEN RAISE EXCEPTION 'D1_APPROVAL_TRIAL_NOT_ROLLED_BACK'; END IF;
END
$approval_trial_cleanup$;
"""

def render_approval_trial(
  source67: str, fixture: str, history: str, typed: str, auth: str,
  approval: str, checks: str
) -> str:
    if source67.count("BEGIN;\n") != 1 or not source67.rstrip().endswith("ROLLBACK;"):
        raise RuntimeError("D1_APPROVAL_BASELINE_TRANSACTION_DRIFT")
    if source67.count(r"\ir fixtures/command_actor.sql")!=1:
        raise RuntimeError("D1_APPROVAL_FIXTURE_DRIFT")
    if source67.count(APPROVAL_INSERT_ANCHOR)!=1:
        raise RuntimeError("D1_APPROVAL_INJECTION_ANCHOR_DRIFT")
    sql=source67.replace(r"\ir fixtures/command_actor.sql",fixture)
    sql=sql.replace("BEGIN;\n","BEGIN;\n"+history+"\n"+typed+"\n"+
      auth+"\n"+approval+"\n",1)
    sql=sql.replace(APPROVAL_INSERT_ANCHOR,checks+"\n"+APPROVAL_INSERT_ANCHOR,1)
    if r"\ir " in sql:
        raise RuntimeError("D1_APPROVAL_UNRESOLVED_INCLUDE")
    return sql

def run_typed_approval_trial(
  container: str, run_psql, history: str, typed: str, root: Path = ROOT
) -> None:
    approval=(Path(root)/APPROVAL_TRIAL).read_text(encoding="utf-8")
    auth=(Path(root)/AUTH_PREFLIGHT).read_text(encoding="utf-8")
    checks=(Path(root)/APPROVAL_TEST).read_text(encoding="utf-8")
    validate_typed_auth_preflight_source(auth,root)
    validate_typed_approval_source(approval,root)
    if not checks.startswith("-- Local-only injected approval acceptance") or "\nCOMMIT;" in checks:
        raise RuntimeError("D1_APPROVAL_INTEGRATION_TEST_QUARANTINE")
    baseline=(Path(root)/APPROVAL_BASELINE).read_text(encoding="utf-8")
    fixture=(Path(root)/TYPED_FIXTURE).read_text(encoding="utf-8")
    sql=render_approval_trial(baseline,fixture,history,typed,auth,approval,checks)
    if container!="supabase_db_saas_OS_school_app":
        raise RuntimeError("D1_APPROVAL_TRIAL_DISPOSABLE_CONTAINER_ONLY")
    run_psql(container,sql,"D1_STUDENT_PROFILE_TYPED_APPROVAL_INTEGRATION",timeout=300)
    run_psql(container,APPROVAL_CLEANUP,
      "D1_STUDENT_PROFILE_TYPED_APPROVAL_ROLLBACK_PROOF",timeout=45)
    print(APPROVAL_PASS_MARKER+" authenticated SUBMIT/independent REVIEW/APPLY/stale invalidation/private history rollback-only")


def run_history_candidate(container: str, run_psql, root: Path = ROOT) -> None:
    source = (Path(root) / CANDIDATE).read_text(encoding="utf-8")
    validate_candidate_source(source, root)
    typed = (Path(root) / TYPED_TRIAL).read_text(encoding="utf-8")
    validate_typed_trial_source(typed, root)
    fixture = (Path(root) / TYPED_FIXTURE).read_text(encoding="utf-8")
    if fixture.count("SET ROLE schoolos_schema_owner;") < 1:
        raise RuntimeError("TYPED_TRIAL_FIXTURE_MISSING")
    synthetic = TRIAL_SQL.replace(r"\ir fixtures/command_actor.sql", fixture)
    if r"\ir " in synthetic:
        raise RuntimeError("TYPED_TRIAL_UNRESOLVED_INCLUDE")
    if container != "supabase_db_saas_OS_school_app":
        raise RuntimeError("HISTORY_LOCAL_CONTAINER_MISMATCH")
    run_psql(container, "BEGIN;\n" + source + "\n" + typed + "\n" + PROBE + "\n" + synthetic + "\nROLLBACK;\n",
        "D1_STUDENT_PROFILE_HISTORY_DESIGN_SMOKE", timeout=180)
    run_psql(container, CLEANUP_PROBE,
        "D1_STUDENT_PROFILE_HISTORY_ROLLBACK_PROOF", timeout=45)
    run_psql(container, TYPED_CLEANUP, "D1_STUDENT_PROFILE_TYPED_ATOMIC_TRIAL_CLEANUP", timeout=45)
    run_typed_authenticated_preflight(container, run_psql, source, typed, root)
    run_typed_direct_trial(container, run_psql, source, typed, root)
    run_typed_approval_trial(container, run_psql, source, typed, root)
    print(PASS_MARKER + " rollback-only DDL/RLS/ACL/check/FK smoke")
    print(TYPED_PASS_MARKER + " normalized fixed-six-field plan, row/revision atomic trial, rollback cleanup")
