import sys
import tempfile
import unittest
from unittest.mock import patch
from subprocess import CompletedProcess
from pathlib import Path

TOOLS = Path(__file__).resolve().parents[1]
if str(TOOLS) not in sys.path:
    sys.path.insert(0, str(TOOLS))

import domain_local_ci as runtime


class DomainLocalCITests(unittest.TestCase):
    def make_root(self, project_id=runtime.EXPECTED_PROJECT_ID):
        temp = tempfile.TemporaryDirectory()
        self.addCleanup(temp.cleanup)
        root = Path(temp.name)
        (root / "supabase/migrations").mkdir(parents=True)
        (root / "supabase/config.toml").write_text(
            f'project_id = "{project_id}"\n', encoding="utf-8", newline="\n"
        )
        return root

    def test_project_id_is_fail_closed_and_pinned(self):
        root = self.make_root()
        self.assertEqual(runtime.local_project_id(root), runtime.EXPECTED_PROJECT_ID)
        wrong = self.make_root("another_project")
        with self.assertRaisesRegex(runtime.DomainLocalCIError, "LOCAL_PROJECT_ID_MISMATCH"):
            runtime.local_project_id(wrong)

    def test_assemble_chain_uses_exact_lexical_order(self):
        root = self.make_root()
        mig = root / "supabase/migrations"
        names = [
            "20260928000000_domain_package_01.sql.draft",
            "20260928000000_domain_package_01_a.sql.draft",
            "20260928000000_domain_package_01_b.sql.draft",
        ]
        for index, name in enumerate(reversed(names)):
            (mig / name).write_text(
                f"SELECT {index};\n", encoding="utf-8", newline="\n"
            )
        drafts, text = runtime.assemble_draft_chain(root)
        self.assertEqual([p.name for p in drafts], names)
        offsets = [text.index("D1C2A BEGIN " + name) for name in names]
        self.assertEqual(offsets, sorted(offsets))

    def test_runtime_probe_exact_metrics_pass(self):
        observed = dict(runtime.EXPECTED_RUNTIME_METRICS)
        runtime.validate_runtime_probe(observed)

    def test_runtime_inventory_private_helper_delta(self):
        # I01 adds two private definers, no public command or new authenticated grant.\n        # DB-02 effect44_01 adds one more authz-reader private P1 version selector.
        # DB-02 effect43_01 adds exactly one private policy preflight.
        # Effect35_12 and DB-01 effect38_02 each add one reviewed private
        # Student-owned definer; public RPC, client grants and RLS remain frozen.
        expected = runtime.EXPECTED_RUNTIME_METRICS
        self.assertEqual(expected["functions"], 566)
        self.assertEqual(expected["security_definers"], 548)
        self.assertEqual(expected["private_functions"], 405)
        self.assertEqual(expected["app_functions"], 161)
        self.assertEqual(expected["authenticated_app_execute"], 161)
        self.assertEqual(expected["authenticated_private_execute"], 0)
        self.assertEqual(expected["anon_execute"], 0)
        self.assertEqual(expected["service_role_execute"], 0)
        self.assertEqual(expected["authenticated_table_dml"], 0)
        self.assertEqual(expected["unknown_function_owners"], 0)
        self.assertEqual(expected["app_schema_owner_functions"], 0)
        self.assertEqual(
            expected["functions"],
            expected["app_functions"] + expected["private_functions"] + 0,
        )

    def test_db01_single_helper_signature_acl_and_non_activation(self):
        # Source guard complements runtime pg_proc owner/has_function_privilege checks.
        helper = runtime.ROOT / "supabase/migrations" / (
            "20260928000000_domain_package_01_effect38_02_db01_roll_correct_result_pair.sql.draft"
        )
        sql = helper.read_text(encoding="utf-8")
        self.assertEqual(
            sql.count("CREATE FUNCTION app_private.d1_roll_correct_result_rows_match_exact("), 1
        )
        self.assertIn("p_student uuid,p_enrollment uuid,p_source_roll uuid,p_successor_roll uuid,p_summary jsonb", sql)
        self.assertIn("SET ROLE schoolos_student_executor;", sql)
        self.assertIn("SECURITY DEFINER SET search_path=pg_catalog,pg_temp", sql)
        self.assertIn(
            "REVOKE ALL ON FUNCTION app_private.d1_roll_correct_result_rows_match_exact", sql
        )
        self.assertIn("FROM PUBLIC,anon,authenticated,service_role;", sql)
        self.assertIn("TO schoolos_student_executor,schoolos_workflow_executor;", sql)
        self.assertNotIn("GRANT EXECUTE ON FUNCTION app_private.d1_roll_correct_result_rows_match_exact(uuid,uuid,uuid,uuid,jsonb) TO authenticated", sql)
        self.assertNotIn("CREATE FUNCTION app.d1_correct_student_roll", sql)
        self.assertNotIn("UPDATE app_private.operation_contracts", sql)
        self.assertNotIn("INSERT INTO app_private.roll_allocations", sql)

    def test_db01_second_receipt_helper_is_private_and_direct_only(self):
        helper = runtime.ROOT / "supabase/migrations" / (
            "20260928000000_domain_package_01_effect38_03_db01_direct_receipt_provenance.sql.draft"
        )
        sql = helper.read_text(encoding="utf-8")
        self.assertEqual(
            sql.count("CREATE FUNCTION app_private.d1_roll_correct_direct_receipt_matches_exact("), 1
        )
        self.assertIn("SET ROLE schoolos_schema_owner;", sql)
        self.assertIn("TO schoolos_schema_owner;", sql)
        self.assertNotIn("GRANT SELECT ON app_private.", sql)
        self.assertIn("SECURITY DEFINER SET search_path=pg_catalog,pg_temp", sql)
        self.assertIn("FROM PUBLIC,anon,authenticated,service_role;", sql)
        self.assertIn("TO schoolos_student_executor,schoolos_workflow_executor;", sql)
        self.assertIn("r.command_kind='student.roll.correct'", sql)
        self.assertIn("r.request_id IS NULL", sql)
        self.assertIn("r.result_ref=p_successor_roll", sql)
        self.assertIn("app_private.d1_roll_correct_result_rows_match_exact(", sql)
        self.assertNotIn("UPDATE app_private.operation_contracts", sql)
        self.assertNotIn("CREATE FUNCTION app.d1_correct_student_roll", sql)

    def test_db01_approval_application_guard_is_scoped_and_private(self):
        helper = runtime.ROOT / "supabase/migrations" / (
            "20260928000000_domain_package_01_effect38_04_db01_apply_application_receipt_guard.sql.draft"
        )
        sql = helper.read_text(encoding="utf-8")
        self.assertEqual(
            sql.count("CREATE FUNCTION app_private.d1_roll_correct_application_receipt_guard()"), 1
        )
        self.assertIn("SET ROLE schoolos_schema_owner;", sql)
        self.assertIn("RETURNS trigger LANGUAGE plpgsql VOLATILE SECURITY DEFINER", sql)
        self.assertIn("IF v_code IS DISTINCT FROM 'student.roll.correct' THEN RETURN NEW;", sql)
        self.assertIn("CREATE TRIGGER d1_roll_correct_application_receipt_guard", sql)
        self.assertIn("FROM PUBLIC,anon,authenticated,service_role;", sql)
        self.assertIn("TO schoolos_schema_owner;", sql)
        self.assertIn("app_private.d1_roll_correct_result_rows_match_exact(", sql)
        self.assertNotIn("GRANT EXECUTE ON FUNCTION app_private.d1_roll_correct_application_receipt_guard", sql)
        self.assertNotIn("UPDATE app_private.operation_contracts", sql)

    def test_runtime_probe_drift_fails(self):
        observed = dict(runtime.EXPECTED_RUNTIME_METRICS)
        observed["authenticated_private_execute"] = 1
        with self.assertRaisesRegex(runtime.DomainLocalCIError, "RUNTIME_CATALOG_DRIFT"):
            runtime.validate_runtime_probe(observed)

    def test_foundation_catalog_runs_only_at_baseline(self):
        contract = {"frozen_foundation": {"database_tests": [
            {"file": "01_foundation_catalog.sql", "assertions": 44},
            {"file": "02_auth_helper_preflight.sql", "assertions": 5},
        ]}}
        with patch.object(runtime.subprocess, "run", return_value=CompletedProcess([], 0, "", "")) as command:
            with patch.object(runtime, "parse_tap", side_effect=lambda output, expected: expected):
                self.assertEqual(runtime.run_foundation_regression(contract, catalog_only=True), 44)
        self.assertEqual(command.call_count, 1)
        self.assertIn("01_foundation_catalog.sql", command.call_args.args[0][3])

    def test_foundation_behavior_runs_after_domain_without_catalog_snapshot(self):
        contract = {"frozen_foundation": {"database_tests": [
            {"file": "01_foundation_catalog.sql", "assertions": 44},
            {"file": "02_auth_helper_preflight.sql", "assertions": 5},
        ]}}
        with patch.object(runtime.subprocess, "run", return_value=CompletedProcess([], 0, "", "")) as command:
            with patch.object(runtime, "parse_tap", side_effect=lambda output, expected: expected):
                self.assertEqual(runtime.run_foundation_regression(contract), 5)
        self.assertEqual(command.call_count, 1)
        self.assertIn("02_auth_helper_preflight.sql", command.call_args.args[0][3])

    def test_local_lint_reports_errors_without_stderr_credentials(self):
        report = '[{"function":"app_private.example","issues":[{"level":"error","message":"bad column","sqlState":"42703"}]}]'
        with patch.object(runtime.subprocess, "run", return_value=CompletedProcess([], 1, report, "secret connection string")):
            with self.assertRaises(runtime.DomainLocalCIError) as caught:
                runtime.run_local_lint("error")
        self.assertIn("app_private.example", str(caught.exception))
        self.assertIn("bad column", str(caught.exception))
        self.assertNotIn("secret", str(caught.exception))

    def test_local_lint_passes_success(self):
        with patch.object(runtime.subprocess, "run", return_value=CompletedProcess([], 0, "[]", "")):
            runtime.run_local_lint("warning")

    def test_local_lint_rejects_invalid_level(self):
        with self.assertRaisesRegex(runtime.DomainLocalCIError, "LOCAL_LINT_LEVEL_INVALID"):
            runtime.run_local_lint("debug")

    def test_probe_parser_rejects_duplicates_and_nonintegers(self):
        with self.assertRaisesRegex(runtime.DomainLocalCIError, "RUNTIME_PROBE_MALFORMED"):
            runtime.parse_runtime_probe("d1_tables\t34\nd1_tables\t34\n")
        with self.assertRaisesRegex(runtime.DomainLocalCIError, "RUNTIME_PROBE_NONINTEGER"):
            runtime.parse_runtime_probe("d1_tables\tthirty-four\n")


if __name__ == "__main__":
    unittest.main()
