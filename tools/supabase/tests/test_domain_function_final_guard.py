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


if __name__ == "__main__":
    unittest.main()
