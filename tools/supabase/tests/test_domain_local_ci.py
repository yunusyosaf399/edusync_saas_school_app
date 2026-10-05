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
