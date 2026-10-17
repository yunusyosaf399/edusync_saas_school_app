"""Post-D1 rollback-only local smoke for quarantined Student Profile history."""
from __future__ import annotations
from pathlib import Path
from domain_draft_guard import ROOT, discover_drafts

CANDIDATE = Path("supabase/proposals/student_profile_history_v1.sql.draft")
PASS_MARKER = "D1_STUDENT_PROFILE_HISTORY_CANDIDATE_PASS"

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

def run_history_candidate(container: str, run_psql, root: Path = ROOT) -> None:
    source = (Path(root) / CANDIDATE).read_text(encoding="utf-8")
    validate_candidate_source(source, root)
    if container != "supabase_db_saas_OS_school_app":
        raise RuntimeError("HISTORY_LOCAL_CONTAINER_MISMATCH")
    run_psql(container, "BEGIN;\n" + source + "\n" + PROBE + "\nROLLBACK;\n",
        "D1_STUDENT_PROFILE_HISTORY_DESIGN_SMOKE", timeout=180)
    run_psql(container, CLEANUP_PROBE,
        "D1_STUDENT_PROFILE_HISTORY_ROLLBACK_PROOF", timeout=45)
    print(PASS_MARKER + " rollback-only DDL/RLS/ACL/check/FK smoke")
