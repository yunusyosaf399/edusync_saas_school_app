import tempfile
import unittest
from pathlib import Path

from tools.supabase import domain_function_final_guard as guard


def _base_sql():
    return """
SET ROLE schoolos_bootstrap_executor;
CREATE FUNCTION app_private.d1_private() RETURNS boolean
LANGUAGE sql SECURITY DEFINER SET search_path=pg_catalog,pg_temp
AS $body$
  SELECT true;
$body$;
REVOKE ALL ON FUNCTION app_private.d1_private()
  FROM PUBLIC,anon,authenticated,service_role;
RESET ROLE;

SET ROLE schoolos_read_executor;
CREATE FUNCTION app.d1_read_sample() RETURNS boolean
LANGUAGE sql SECURITY DEFINER SET search_path=pg_catalog,pg_temp
AS $body$
  SELECT true;
$body$;
REVOKE ALL ON FUNCTION app.d1_read_sample()
  FROM PUBLIC,anon,authenticated,service_role;
GRANT EXECUTE ON FUNCTION app.d1_read_sample() TO authenticated;
CREATE OR REPLACE FUNCTION app.d1_read_sample() RETURNS boolean
LANGUAGE sql SECURITY DEFINER SET search_path=pg_catalog,pg_temp
AS $body$
  SELECT false;
$body$;
RESET ROLE;
"""


class DomainFunctionFinalGuardTests(unittest.TestCase):
    def make_root(self, text=None):
        temp = tempfile.TemporaryDirectory()
        self.addCleanup(temp.cleanup)
        root = Path(temp.name)
        mig = root / "supabase/migrations"
        mig.mkdir(parents=True)
        (mig / guard.BASE_NAME).write_text(
            text if text is not None else _base_sql(),
            encoding="utf-8",
            newline="\n",
        )
        return root

    def test_accepts_final_state_and_preserves_owner_across_replace(self):
        errors, metrics, states = guard.inspect(self.make_root())
        self.assertEqual(errors, [])
        self.assertEqual(metrics["redefined_names"], 1)
        self.assertEqual(states["app.d1_read_sample"].owner, "schoolos_read_executor")
        self.assertIn("authenticated", states["app.d1_read_sample"].execute_roles)

    def trigger_sql(self, before="", after="", creator="schoolos_schema_owner"):
        return _base_sql() + f"""
SET ROLE schoolos_evidence_writer;
CREATE FUNCTION app_private.d1_guard_application() RETURNS trigger
LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,pg_temp
AS $body$ BEGIN RETURN NEW; END $body$;
REVOKE ALL ON FUNCTION app_private.d1_guard_application() FROM PUBLIC,anon,authenticated,service_role;
{before}
RESET ROLE;
SET ROLE {creator};
CREATE TRIGGER d1_application_guard BEFORE INSERT ON app_private.approval_applications
FOR EACH ROW EXECUTE FUNCTION app_private.d1_guard_application();
RESET ROLE;
{after}
"""

    def test_rejects_trigger_creator_without_execute(self):
        errors, _, _ = guard.inspect(self.make_root(self.trigger_sql()))
        self.assertTrue(any("trigger creator lacks explicit EXECUTE" in error for error in errors))

    def test_accepts_temporary_trigger_packaging_grant(self):
        sql = self.trigger_sql(
            before="GRANT EXECUTE ON FUNCTION app_private.d1_guard_application() TO schoolos_schema_owner;",
            after="SET ROLE schoolos_evidence_writer; REVOKE EXECUTE ON FUNCTION app_private.d1_guard_application() FROM schoolos_schema_owner; RESET ROLE;",
        )
        errors, _, states = guard.inspect(self.make_root(sql))
        self.assertEqual(errors, [])
        self.assertNotIn("schoolos_schema_owner", states["app_private.d1_guard_application"].execute_roles)

    def test_later_grant_does_not_fix_trigger_creation(self):
        sql = self.trigger_sql(after="GRANT EXECUTE ON FUNCTION app_private.d1_guard_application() TO schoolos_schema_owner;")
        errors, _, _ = guard.inspect(self.make_root(sql))
        self.assertTrue(any("trigger creator lacks explicit EXECUTE" in error for error in errors))

    def test_function_owner_can_create_trigger(self):
        errors, _, _ = guard.inspect(self.make_root(self.trigger_sql(creator="schoolos_evidence_writer")))
        self.assertEqual(errors, [])

    def test_foundation_trigger_helper_is_outside_d1_chain(self):
        sql = _base_sql() + """
SET ROLE schoolos_schema_owner;
CREATE TRIGGER zz_d1_version BEFORE UPDATE ON app_private.students
FOR EACH ROW EXECUTE FUNCTION app_private.advance_row_version();
RESET ROLE;
"""
        errors, _, _ = guard.inspect(self.make_root(sql))
        self.assertEqual(errors, [])

    def test_rejects_unresolved_d1_trigger_function(self):
        sql = _base_sql() + """
SET ROLE schoolos_schema_owner;
CREATE TRIGGER d1_missing_guard BEFORE INSERT ON app_private.approval_applications
FOR EACH ROW EXECUTE FUNCTION app_private.d1_missing();
RESET ROLE;
"""
        errors, _, _ = guard.inspect(self.make_root(sql))
        self.assertTrue(any("trigger function unresolved" in error for error in errors))

    def test_rejects_qualified_conditionals_inside_function_body(self):
        for expression in ("coalesce", "nullif", "greatest", "least"):
            with self.subTest(expression=expression):
                sql = _base_sql().replace("SELECT true;", f"SELECT pg_catalog.{expression}(1,2) IS NOT NULL;", 1)
                errors, _, _ = guard.inspect(self.make_root(sql))
                self.assertTrue(any("schema-qualified SQL conditional expression" in error for error in errors))

    def test_conditional_guard_ignores_literals_and_comments(self):
        sql = _base_sql().replace("SELECT true;", "SELECT COALESCE(NULL,true); -- pg_catalog.coalesce(1,2)", 1)
        sql += """
-- pg_catalog.least(1,2)
SET ROLE schoolos_schema_owner;
CREATE FUNCTION app_private.d1_conditional_text() RETURNS text LANGUAGE sql
AS $body$ SELECT 'pg_catalog.coalesce(1,2)'; /* pg_catalog.greatest(1,2) */ $body$;
RESET ROLE;
"""
        errors, _, _ = guard.inspect(self.make_root(sql))
        self.assertEqual(errors, [])

    def test_rejects_case_operand_without_parentheses(self):
        sql = _base_sql() + """
SET ROLE schoolos_schema_owner;
CREATE FUNCTION app_private.d1_case_guard() RETURNS boolean LANGUAGE plpgsql
AS $body$ BEGIN
IF 1 IS NOT DISTINCT FROM CASE WHEN true THEN 1 ELSE 2 END THEN RETURN true; END IF;
RETURN false; END $body$;
RESET ROLE;
"""
        errors, _, _ = guard.inspect(self.make_root(sql))
        self.assertTrue(any("CASE comparison operand" in error for error in errors))

    def test_accepts_parenthesized_case_operand(self):
        sql = _base_sql() + """
SET ROLE schoolos_schema_owner;
CREATE FUNCTION app_private.d1_case_guard() RETURNS boolean LANGUAGE plpgsql
AS $body$ BEGIN
IF 1 IS NOT DISTINCT FROM (CASE WHEN true THEN 1 ELSE 2 END) THEN RETURN true; END IF;
RETURN false; END $body$;
RESET ROLE;
"""
        errors, _, _ = guard.inspect(self.make_root(sql))
        self.assertEqual(errors, [])

    def test_rejects_unknown_security_definer_owner(self):
        text = _base_sql() + """
CREATE FUNCTION app_private.d1_unknown() RETURNS boolean
LANGUAGE sql SECURITY DEFINER SET search_path=pg_catalog,pg_temp
AS $body$ SELECT true; $body$;
"""
        errors, _, _ = guard.inspect(self.make_root(text))
        self.assertTrue(any("owner unresolved" in error for error in errors))

    def test_owner_transfer_resolves_unknown_owner(self):
        text = _base_sql() + """
CREATE FUNCTION app_private.d1_transferred() RETURNS boolean
LANGUAGE sql SECURITY DEFINER SET search_path=pg_catalog,pg_temp
AS $body$ SELECT true; $body$;
ALTER FUNCTION app_private.d1_transferred() OWNER TO schoolos_schema_owner;
"""
        errors, _, states = guard.inspect(self.make_root(text))
        self.assertEqual(errors, [])
        self.assertEqual(states["app_private.d1_transferred"].owner, "schoolos_schema_owner")

    def test_rejects_redundant_owner_alter_under_unrelated_role(self):
        sql = _base_sql() + """
SET ROLE schoolos_schema_owner;
ALTER FUNCTION app.d1_read_sample() OWNER TO schoolos_read_executor;
RESET ROLE;
"""
        errors, _, _ = guard.inspect(self.make_root(sql))
        self.assertTrue(any("ownership packaging role mismatch" in error for error in errors))

    def test_outer_deployment_authority_can_repeat_owner_contract(self):
        sql = _base_sql() + "ALTER FUNCTION app.d1_read_sample() OWNER TO schoolos_read_executor;"
        errors, _, states = guard.inspect(self.make_root(sql))
        self.assertEqual(errors, [])
        self.assertEqual(states["app.d1_read_sample"].owner, "schoolos_read_executor")

    def test_rejects_authenticated_private_execute(self):
        text = _base_sql() + """
GRANT EXECUTE ON FUNCTION app_private.d1_private() TO authenticated;
"""
        errors, _, _ = guard.inspect(self.make_root(text))
        self.assertTrue(any("authenticated retains EXECUTE" in error for error in errors))

    def test_final_revoke_clears_historical_dangerous_grant(self):
        text = _base_sql() + """
GRANT EXECUTE ON FUNCTION app.d1_read_sample() TO service_role;
REVOKE ALL ON FUNCTION app.d1_read_sample() FROM service_role;
"""
        errors, _, states = guard.inspect(self.make_root(text))
        self.assertEqual(errors, [])
        self.assertNotIn("service_role", states["app.d1_read_sample"].execute_roles)

    def test_rejects_final_dangerous_grant(self):
        text = _base_sql() + """
GRANT EXECUTE ON FUNCTION app.d1_read_sample() TO service_role;
"""
        errors, _, _ = guard.inspect(self.make_root(text))
        self.assertTrue(any("dangerous role" in error for error in errors))

    def test_rejects_unbalanced_set_role(self):
        text = _base_sql() + "SET ROLE schoolos_workflow_executor;\n"
        errors, _, _ = guard.inspect(self.make_root(text))
        self.assertTrue(any("leaves SET ROLE active" in error for error in errors))

    def test_ignores_ddl_words_inside_function_body_and_comments(self):
        text = _base_sql() + """
-- GRANT EXECUTE ON FUNCTION app_private.d1_private() TO authenticated;
SET ROLE schoolos_schema_owner;
CREATE FUNCTION app_private.d1_body_words() RETURNS text
LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,pg_temp
AS $body$
BEGIN
  RETURN 'SET ROLE schoolos_workflow_executor; GRANT EXECUTE ON FUNCTION app_private.fake() TO authenticated;';
END
$body$;
RESET ROLE;
"""
        errors, _, states = guard.inspect(self.make_root(text))
        self.assertEqual(errors, [])
        self.assertEqual(states["app_private.d1_body_words"].owner, "schoolos_schema_owner")

    def test_rename_then_recreate_produces_two_final_functions(self):
        text = _base_sql() + """
SET ROLE schoolos_authz_reader;
CREATE FUNCTION app_private.d1_participant(uuid,uuid) RETURNS text
LANGUAGE sql SECURITY DEFINER SET search_path=pg_catalog,pg_temp
AS $body$ SELECT 'OLD'::text; $body$;
REVOKE ALL ON FUNCTION app_private.d1_participant(uuid,uuid)
  FROM PUBLIC,anon,authenticated,service_role;
GRANT EXECUTE ON FUNCTION app_private.d1_participant(uuid,uuid)
  TO schoolos_workflow_executor;
ALTER FUNCTION app_private.d1_participant(uuid,uuid)
  RENAME TO d1_participant_v0;
REVOKE ALL ON FUNCTION app_private.d1_participant_v0(uuid,uuid)
  FROM PUBLIC,anon,authenticated,service_role,schoolos_workflow_executor;
CREATE FUNCTION app_private.d1_participant(uuid,uuid) RETURNS text
LANGUAGE sql SECURITY DEFINER SET search_path=pg_catalog,pg_temp
AS $body$ SELECT 'NEW'::text; $body$;
REVOKE ALL ON FUNCTION app_private.d1_participant(uuid,uuid)
  FROM PUBLIC,anon,authenticated,service_role;
GRANT EXECUTE ON FUNCTION app_private.d1_participant(uuid,uuid)
  TO schoolos_workflow_executor;
RESET ROLE;
"""
        errors, metrics, states = guard.inspect(self.make_root(text))
        self.assertEqual(errors, [])
        self.assertEqual(metrics["possible_name_collisions"], 0)
        self.assertEqual(metrics["renames"], 1)
        self.assertIn("app_private.d1_participant", states)
        self.assertIn("app_private.d1_participant_v0", states)
        self.assertEqual(states["app_private.d1_participant"].owner, "schoolos_authz_reader")
        self.assertEqual(states["app_private.d1_participant_v0"].owner, "schoolos_authz_reader")

    def test_rejects_true_duplicate_bare_create_without_rename(self):
        text = _base_sql() + """
SET ROLE schoolos_authz_reader;
CREATE FUNCTION app_private.d1_duplicate() RETURNS boolean
LANGUAGE sql SECURITY DEFINER SET search_path=pg_catalog,pg_temp
AS $body$ SELECT true; $body$;
CREATE FUNCTION app_private.d1_duplicate() RETURNS boolean
LANGUAGE sql SECURITY DEFINER SET search_path=pg_catalog,pg_temp
AS $body$ SELECT false; $body$;
RESET ROLE;
"""
        errors, metrics, _ = guard.inspect(self.make_root(text))
        self.assertEqual(metrics["possible_name_collisions"], 1)
        self.assertTrue(any("unresolved bare CREATE" in error for error in errors))

    def test_rejects_argument_shape_drift_across_replace(self):
        text = _base_sql() + """
SET ROLE schoolos_authz_reader;
CREATE FUNCTION app_private.d1_signature_guard(p_value uuid) RETURNS boolean
LANGUAGE sql SECURITY DEFINER SET search_path=pg_catalog,pg_temp
AS $body$ SELECT true; $body$;
CREATE OR REPLACE FUNCTION app_private.d1_signature_guard(p_value text) RETURNS boolean
LANGUAGE sql SECURITY DEFINER SET search_path=pg_catalog,pg_temp
AS $body$ SELECT true; $body$;
RESET ROLE;
"""
        errors, metrics, _ = guard.inspect(self.make_root(text))
        self.assertEqual(metrics["signature_shape_drift_names"], ["app_private.d1_signature_guard"])
        self.assertTrue(any("argument-shape drift" in error for error in errors))


if __name__ == "__main__":
    unittest.main()
