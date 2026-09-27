"""P2B2A executor tests: synthetic metadata and faked I/O only."""

import io
import json
import sys
import unittest
from contextlib import redirect_stderr, redirect_stdout
from pathlib import Path
from types import SimpleNamespace
from unittest.mock import Mock, patch

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
import foundation_staging_deploy as deploy


class FakeOps:
    def __init__(self):
        self.calls = []
        self.history = ["f"]
        self.config = {"public", "graphql_public"}
        self.healthy = True
        self.probe_version = "17.6"
        self.dry = "\n".join("Applying migration " + m["file"] for m in
                             deploy.load_contract()["frozen_foundation"]["migrations"])
        self.pushes = 0

    def identity(self, manifest, contract, token):
        self.calls.append("identity")
        return "STAGING_IDENTITY_PASS"

    def health(self, token, ref):
        self.calls.append("health")
        return self.healthy

    def route(self, token, ref):
        self.calls.append("route")
        return "postgresql://postgres." + ref + "@aws-0-ap-northeast-2.pooler.supabase.com:5432/postgres?sslmode=require"

    def probe(self, uri, password):
        self.calls.append("probe")
        return self.probe_version

    def sql(self, uri, password, query, *, stage="", readonly=True):
        self.calls.append(stage)
        if stage == "STAGING_HISTORY_EXISTS":
            return self.history
        if stage == "STAGING_HISTORY_VERSIONS":
            return self.versions
        if stage == "STAGING_CATALOG_SCHEMAS":
            return ["app", "app_private"]
        if stage == "STAGING_SECURITY_FK":
            return ["FOREIGN KEY (auth_user_id) REFERENCES auth.users(id) ON UPDATE RESTRICT ON DELETE SET NULL"]
        if stage == "STAGING_SECURITY_HELPER":
            return ["schoolos_authz_reader"]
        raise AssertionError(stage)

    def count(self, uri, password, query, *, stage=""):
        self.calls.append(stage)
        if stage.startswith("STAGING_BASELINE"):
            return 0
        expected = deploy.load_contract()["expected_catalog"]
        return next(expected[key] for key, sql in deploy.CATALOG_QUERIES.items() if sql == query)

    def command(self, command, uri, password, *, timeout=600):
        self.calls.append(tuple(command))
        if command[:3] == ["db", "push", "--dry-run"]:
            return self.dry
        if command[:2] == ["db", "push"]:
            self.pushes += 1
            return "Finished supabase db push"
        if command[:2] == ["db", "lint"]:
            return "PASS"
        raise AssertionError(command)

    def config_schemas(self, token, ref):
        self.calls.append("config")
        return self.config

    def apply_config(self, manifest, token):
        self.calls.append("PATCH db_schema")
        self.config = {"public", "graphql_public", "app"}
        return "MANAGED_CONFIG_PASS"


class ExecutorTests(unittest.TestCase):
    def setUp(self):
        self.foundation = deploy.load_contract()
        self.stage = deploy.staging.load_staging_contract(foundation=self.foundation)
        self.target = deploy.staging.load_target_manifest(staging=self.stage)
        self.sha = "a" * 40
        self.args = SimpleNamespace(apply=True, confirm_environment="staging",
            confirm_project_ref=self.target["project_ref"],
            confirm_project_name=self.target["project_name"], confirm_source_sha=self.sha)

    def assert_code(self, code, callback):
        with self.assertRaisesRegex(deploy.DeployError, "^" + code + "$"):
            callback()

    def test_plan_is_zero_network_and_pinned(self):
        with patch.object(deploy.Runtime, "identity", side_effect=AssertionError("network")), \
             redirect_stdout(io.StringIO()) as out:
            self.assertEqual(deploy.main(["plan"]), 0)
        self.assertIn("project_ref=" + self.target["project_ref"], out.getvalue())
        self.assertIn("persistent project", out.getvalue())

    def test_preflight_and_deploy_missing_secrets_fail_safely(self):
        with patch.dict(deploy.os.environ, {}, clear=True), \
             patch.object(deploy, "source_gate", side_effect=AssertionError("remote")), \
             redirect_stderr(io.StringIO()) as errors:
            self.assertEqual(deploy.main(["preflight", "--source-sha", self.sha]), 1)
            self.assertEqual(deploy.main(["deploy", "--apply", "--confirm-environment", "staging",
                "--confirm-project-ref", self.target["project_ref"], "--confirm-project-name",
                self.target["project_name"], "--confirm-source-sha", self.sha]), 1)
        self.assertEqual(errors.getvalue().count("STAGING_MANAGEMENT_TOKEN_MISSING"), 2)

    def test_arbitrary_target_cli_flag_impossible(self):
        with redirect_stderr(io.StringIO()), self.assertRaises(SystemExit) as error:
            deploy.main(["plan", "--project-ref", "b" * 20])
        self.assertEqual(error.exception.code, 2)

    def test_exact_confirmations_required(self):
        for field, wrong in (("apply", False), ("confirm_environment", "production"),
                             ("confirm_project_ref", "b" * 20),
                             ("confirm_project_name", "other"),
                             ("confirm_source_sha", "b" * 40)):
            args = SimpleNamespace(**vars(self.args))
            setattr(args, field, wrong)
            with self.subTest(field=field):
                self.assert_code("STAGING_DEPLOY_CONFIRMATION_MISMATCH",
                    lambda: deploy.exact_confirmations(args, self.target, self.sha))

    def test_dirty_tree_blocks_source_gate(self):
        outputs = [SimpleNamespace(stdout=self.sha), SimpleNamespace(stdout=" M docs/file.md\n")]
        with patch.object(deploy.subprocess, "run", side_effect=outputs):
            self.assert_code("STAGING_SOURCE_NOT_EXACT_AND_CLEAN",
                lambda: deploy.source_gate(self.sha, self.foundation, self.stage))

    def test_source_sha_requires_full_exact_commit(self):
        self.assert_code("STAGING_SOURCE_SHA_REQUIRED",
            lambda: deploy.source_gate("latest", self.foundation, self.stage))

    def test_identity_mismatch_blocks_before_route(self):
        ops = FakeOps()
        ops.identity = Mock(return_value="wrong")
        with patch.object(deploy, "source_gate", return_value=self.sha):
            self.assert_code("STAGING_IDENTITY_FAILURE",
                lambda: deploy.run_preflight(ops, self.target, self.foundation, self.stage,
                                             self.sha, "FAKE_TOKEN", "FAKE_PASSWORD"))
        self.assertNotIn("route", ops.calls)

    def test_unhealthy_project_blocks(self):
        ops = FakeOps()
        ops.healthy = False
        with patch.object(deploy, "source_gate", return_value=self.sha):
            self.assert_code("STAGING_HEALTH_FAILURE",
                lambda: deploy.run_preflight(ops, self.target, self.foundation, self.stage,
                                             self.sha, "FAKE_TOKEN", "FAKE_PASSWORD"))
        self.assertNotIn("route", ops.calls)

    def test_session_pooler_accepted_and_bad_routes_blocked(self):
        ops = FakeOps()
        valid = ops.route(None, self.target["project_ref"])
        self.assertEqual(deploy.p1.validate_session_uri(valid, self.target["project_ref"]), valid)
        for bad in (valid.replace(":5432", ":6543"),
                    valid.replace("postgres." + self.target["project_ref"] + "@",
                                  "postgres." + self.target["project_ref"] + ":FAKE_PASSWORD@")):
            with self.subTest(bad_route="synthetic"):
                with self.assertRaises(deploy.p1.RehearsalError):
                    deploy.p1.validate_session_uri(bad, self.target["project_ref"])

    def test_read_only_probe_reuses_redacted_diagnostics(self):
        self.assertEqual(deploy.p1.classify_psql_failure("connection timed out", "", 1),
                         "PSQL_CONNECT_TIMEOUT")
        self.assertEqual(deploy.p1.PsqlFailure("DB_PROBE", "PSQL_PROCESS_TIMEOUT", 124).category,
                         "PSQL_PROCESS_TIMEOUT")

    def test_history_absent_is_fresh(self):
        ops = FakeOps()
        self.assertIsNone(deploy.history_probe(ops, "fake-uri", "FAKE_PASSWORD"))
        self.assertNotIn("STAGING_HISTORY_VERSIONS", ops.calls)
        self.assertEqual(deploy.classify_history(None, deploy.p1.migration_versions(self.foundation)),
                         "STAGING_FOUNDATION_BOOTSTRAP_ELIGIBLE")

    def test_exact_history_is_already_deployed(self):
        expected = deploy.p1.migration_versions(self.foundation)
        ops = FakeOps()
        ops.history, ops.versions = ["t"], expected
        self.assertEqual(deploy.history_probe(ops, "fake-uri", "FAKE_PASSWORD"), expected)
        self.assertEqual(deploy.classify_history(expected, expected),
                         "STAGING_FOUNDATION_ALREADY_DEPLOYED")

    def test_partial_and_unexpected_history_block(self):
        expected = deploy.p1.migration_versions(self.foundation)
        self.assert_code("STAGING_FOUNDATION_PARTIAL_HISTORY",
                         lambda: deploy.classify_history(expected[:-1], expected))
        self.assert_code("STAGING_FOUNDATION_UNEXPECTED_HISTORY",
                         lambda: deploy.classify_history(expected + ["20990101000000"], expected))

    def test_exact_dry_run_and_drift_cases(self):
        expected = deploy.p1.migration_versions(self.foundation)
        output = FakeOps().dry
        self.assertEqual(deploy.p1.verify_dry_run(output, expected), expected)
        names = [row["file"] for row in self.foundation["frozen_foundation"]["migrations"]]
        for bad in ("\n".join("Applying migration " + name for name in reversed(names)),
                    output + "\nApplying migration 20990101000000_extra.sql",
                    "\n".join("Applying migration " + name for name in names[:-1])):
            with self.subTest(case="dry-run mismatch"), self.assertRaises(deploy.p1.RehearsalError):
                deploy.p1.verify_dry_run(bad, expected)

    def test_catalog_and_security_mismatches_block(self):
        ops = FakeOps()
        self.assertEqual(deploy.catalog_smoke(ops, "fake", "FAKE", self.foundation)["roles"], 12)
        ops.count = lambda *a, **k: 11
        self.assert_code("STAGING_CATALOG_MISMATCH",
                         lambda: deploy.catalog_smoke(ops, "fake", "FAKE", self.foundation))
        for stage, code in (("STAGING_SECURITY_FK", "STAGING_AUTH_FK_MISMATCH"),
                            ("STAGING_SECURITY_HELPER", "STAGING_HELPER_OWNER_MISMATCH")):
            ops = FakeOps()
            original = ops.sql
            ops.sql = lambda *a, **k: ["wrong"] if k.get("stage") == stage else original(*a, **k)
            with self.subTest(stage=stage):
                self.assert_code(code, lambda: deploy.catalog_smoke(ops, "fake", "FAKE", self.foundation))

    def test_data_api_states(self):
        self.assertEqual(deploy.classify_api_schemas({"public", "graphql_public"}, self.foundation),
                         "STAGING_DATA_API_REVIEWED_APP_ABSENT")
        self.assertEqual(deploy.classify_api_schemas({"public", "graphql_public", "app"}, self.foundation),
                         "MANAGED_CONFIG_PASS")
        for bad in ({"public", "graphql_public", "app_private"},
                    {"public", "graphql_public", "app", "extra"}):
            self.assert_code("STAGING_DATA_API_UNEXPECTED",
                             lambda: deploy.classify_api_schemas(bad, self.foundation))

    def test_lint_failure_blocks(self):
        ops = FakeOps()
        ops.command = Mock(side_effect=deploy.DeployError("STAGING_LINT_FAILED"))
        self.assert_code("STAGING_LINT_FAILED", lambda: deploy.run_lint(ops, "fake", "FAKE"))

    def test_runtime_config_apply_delegates_only_reviewed_field(self):
        with patch.object(deploy, "configure", return_value="MANAGED_CONFIG_PASS") as configured:
            self.assertEqual(deploy.Runtime().apply_config(self.target, "FAKE_TOKEN"), "MANAGED_CONFIG_PASS")
        self.assertTrue(configured.call_args.kwargs["apply"])
        self.assertEqual(configured.call_args.kwargs["confirm_ref"], self.target["project_ref"])
        self.assertEqual(configured.call_args.args[0], self.target["project_ref"])

    def test_no_project_delete_path_or_production_mode(self):
        source = Path(deploy.__file__).read_text(encoding="utf-8")
        self.assertNotIn("delete_project_once", source)
        self.assertNotIn('"DELETE", "/v1/projects/', source)
        self.assertNotIn("schoolos_event_login", source)
        with redirect_stderr(io.StringIO()), self.assertRaises(SystemExit) as error:
            deploy.main(["production"])
        self.assertEqual(error.exception.code, 2)

    def deploy_with_fakes(self, state, *, ops=None):
        ops = ops or FakeOps()
        expected = deploy.p1.migration_versions(self.foundation)
        evidence = {"source_sha": self.sha, "project_ref": self.target["project_ref"],
                    "project_name": self.target["project_name"],
                    "organization_id": self.target["organization_id"], "region": self.target["region"],
                    "postgresql_version": "17.6", "route_class": "TLS Supavisor session pooler 5432",
                    "baseline_classification": state, "push_count": 0,
                    "data_api": "STAGING_DATA_API_REVIEWED_APP_ABSENT" if state.endswith("ELIGIBLE")
                                else "MANAGED_CONFIG_PASS"}
        ops.config = {"public", "graphql_public"} if state.endswith("ELIGIBLE") else \
                     {"public", "graphql_public", "app"}
        counts = {k: self.foundation["expected_catalog"][k] for k in deploy.CATALOG_QUERIES}
        tests = {row["file"]: row["assertions"] for row in self.foundation["frozen_foundation"]["database_tests"]}
        with patch.object(deploy, "run_preflight", return_value=("fake-uri", evidence)), \
             patch.object(deploy, "history_probe", return_value=expected), \
             patch.object(deploy, "catalog_smoke", return_value=counts), \
             patch.object(deploy, "run_lint", return_value={"error": "PASS", "warning": "PASS"}), \
             patch.object(deploy, "run_hosted_tests_with_cleanup", return_value=tests):
            return deploy.run_deploy(ops, self.args, self.target, self.foundation,
                                     self.stage, "FAKE_TOKEN", "FAKE_PASSWORD"), ops

    def test_fresh_deploy_pushes_exactly_once(self):
        result, ops = self.deploy_with_fakes("STAGING_FOUNDATION_BOOTSTRAP_ELIGIBLE")
        self.assertEqual(result["push_count"], 1)
        self.assertEqual(ops.pushes, 1)
        self.assertEqual(ops.calls.count("PATCH db_schema"), 1)
        self.assertEqual(result["drift"], "STAGING_DRIFT_PASS")

    def test_failed_push_never_retried(self):
        ops = FakeOps()
        def failed_push(command, uri, password, *, timeout=600):
            if command[:2] == ["db", "push"]:
                ops.pushes += 1
                raise RuntimeError("FAKE_PASSWORD")
            return ""
        ops.command = failed_push
        self.assert_code("STAGING_PUSH_FAILED_NO_RETRY",
            lambda: self.deploy_with_fakes("STAGING_FOUNDATION_BOOTSTRAP_ELIGIBLE", ops=ops))
        self.assertEqual(ops.pushes, 1)

    def test_exact_history_rerun_has_zero_pushes(self):
        result, ops = self.deploy_with_fakes("STAGING_FOUNDATION_ALREADY_DEPLOYED")
        self.assertEqual(result["push_count"], 0)
        self.assertEqual(ops.pushes, 0)
        self.assertNotIn("PATCH db_schema", ops.calls)

    def test_final_drift_and_final_health_block(self):
        with patch.object(deploy.staging, "evaluate_staging_drift",
                          side_effect=deploy.staging.StagingError("DRIFT_CATALOG")):
            self.assert_code("STAGING_FINAL_DRIFT_FAILURE",
                lambda: self.deploy_with_fakes("STAGING_FOUNDATION_ALREADY_DEPLOYED"))
        ops = FakeOps()
        ops.config = {"public", "graphql_public", "app"}
        def health(token, ref):
            ops.calls.append("health")
            return len([x for x in ops.calls if x == "health"]) < 1
        ops.health = health
        self.assert_code("STAGING_FINAL_HEALTH_FAILURE",
            lambda: self.deploy_with_fakes("STAGING_FOUNDATION_ALREADY_DEPLOYED", ops=ops))

    def auth_ops(self, *, fail_test=False, fail_delete=False, malformed_tap=False):
        ids = {}
        ops = FakeOps()
        ops.service_key = Mock(return_value="FAKE_SERVICE_KEY")
        ops.sql = Mock(side_effect=lambda *a, **k:
            ["app.table_" + str(i) for i in range(33)]
            if k.get("stage") == "STAGING_APPLICATION_TABLE_LIST" else [])
        ops.count = Mock(return_value=0)
        def auth(method, ref, key, *, user_id=None, payload=None):
            if method == "POST":
                number = len(ids) + 1
                uid = "00000000-0000-0000-0000-" + str(number).zfill(12)
                ids[payload["email"]] = uid
                return 201, {"id": uid}
            if fail_delete:
                raise RuntimeError("FAKE_SERVICE_KEY")
            for email, uid in list(ids.items()):
                if uid == user_id:
                    del ids[email]
            return 200, None
        ops.auth_request = Mock(side_effect=auth)
        def command(command, uri, password, *, timeout=600):
            name = Path(command[-1]).name
            assertions = next(row["assertions"] for row in
                              self.foundation["frozen_foundation"]["database_tests"] if row["file"] == name)
            if fail_test and name.startswith("04_"):
                raise RuntimeError("FAKE_PASSWORD")
            if malformed_tap:
                return "ambiguous TAP"
            return "Files=1, Tests=" + str(assertions) + ",  0 wallclock secs\nResult: PASS\n"
        ops.command = Mock(side_effect=command)
        return ops, ids

    def test_exactly_five_auth_fixtures_and_cleanup_after_pass(self):
        ops, ids = self.auth_ops()
        with patch.object(deploy, "fixture_ids", side_effect=lambda *a: dict(ids)):
            result = deploy.run_hosted_tests_with_cleanup(ops, self.target, "fake-uri", "FAKE_PASSWORD",
                                                          "FAKE_TOKEN", self.foundation)
        self.assertEqual(sum(result.values()), 220)
        self.assertEqual(len([c for c in ops.auth_request.call_args_list if c.args[0] == "POST"]), 5)
        self.assertEqual(len([c for c in ops.auth_request.call_args_list if c.args[0] == "DELETE"]), 5)
        self.assertEqual(ids, {})

    def test_auth_cleanup_after_failed_suite(self):
        ops, ids = self.auth_ops(fail_test=True)
        with patch.object(deploy, "fixture_ids", side_effect=lambda *a: dict(ids)):
            self.assert_code("STAGING_HOSTED_TEST_FAILURE",
                lambda: deploy.run_hosted_tests_with_cleanup(ops, self.target, "fake-uri",
                                                              "FAKE_PASSWORD", "FAKE_TOKEN", self.foundation))
        self.assertEqual(ids, {})
        self.assertEqual(len([c for c in ops.auth_request.call_args_list if c.args[0] == "DELETE"]), 5)

    def test_auth_cleanup_failure_blocks_without_project_delete(self):
        ops, ids = self.auth_ops(fail_delete=True)
        with patch.object(deploy, "fixture_ids", side_effect=lambda *a: dict(ids)):
            self.assert_code("STAGING_AUTH_CLEANUP_UNCONFIRMED",
                lambda: deploy.run_hosted_tests_with_cleanup(ops, self.target, "fake-uri",
                                                              "FAKE_PASSWORD", "FAKE_TOKEN", self.foundation))
        self.assertTrue(ids)
        self.assertTrue(all(c.args[0] != "DELETE" or c.args[1] == self.target["project_ref"]
                            for c in ops.auth_request.call_args_list))

    def test_cleanup_requires_independent_id_and_email_absence(self):
        ops, ids = self.auth_ops()
        ops.count.side_effect = lambda *a, **k: 1 if k.get("stage") == "STAGING_AUTH_FIXTURE_ABSENCE" else 0
        with patch.object(deploy, "fixture_ids", side_effect=lambda *a: dict(ids)):
            self.assert_code("STAGING_AUTH_CLEANUP_UNCONFIRMED",
                lambda: deploy.run_hosted_tests_with_cleanup(ops, self.target, "fake-uri",
                                                              "FAKE_PASSWORD", "FAKE_TOKEN", self.foundation))
        self.assertEqual(ids, {})
        self.assertEqual(ops.count.call_args.kwargs["stage"], "STAGING_AUTH_FIXTURE_ABSENCE")

    def test_application_rows_left_by_suite_block_after_auth_cleanup(self):
        ops, ids = self.auth_ops()
        row_queries = 0
        def count(uri, password, query, *, stage=""):
            nonlocal row_queries
            if stage == "STAGING_APPLICATION_ROW_COUNT":
                row_queries += 1
                return 1 if row_queries == 34 else 0
            return 0
        ops.count = Mock(side_effect=count)
        with patch.object(deploy, "fixture_ids", side_effect=lambda *a: dict(ids)):
            self.assert_code("STAGING_APPLICATION_DATA_REMAINS",
                lambda: deploy.run_hosted_tests_with_cleanup(ops, self.target, "fake-uri",
                                                              "FAKE_PASSWORD", "FAKE_TOKEN", self.foundation))
        self.assertEqual(ids, {})

    def test_malformed_tap_blocks_and_cleans(self):
        ops, ids = self.auth_ops(malformed_tap=True)
        with patch.object(deploy, "fixture_ids", side_effect=lambda *a: dict(ids)):
            self.assert_code("STAGING_TAP_MALFORMED",
                lambda: deploy.run_hosted_tests_with_cleanup(ops, self.target, "fake-uri",
                                                              "FAKE_PASSWORD", "FAKE_TOKEN", self.foundation))
        self.assertEqual(ids, {})

    def test_219_tap_assertions_block(self):
        ops, ids = self.auth_ops()
        old = self.foundation["frozen_foundation"]["database_tests"][0]["assertions"]
        # The frozen plan remains 44; a harness reporting one fewer assertion fails.
        def short(command, uri, password, *, timeout=600):
            return "Files=1, Tests=" + str(old - 1) + ",  0 wallclock secs\nResult: PASS\n"
        ops.command = short
        with patch.object(deploy, "fixture_ids", side_effect=lambda *a: dict(ids)):
            self.assert_code("STAGING_TAP_MALFORMED",
                lambda: deploy.run_hosted_tests_with_cleanup(ops, self.target, "fake-uri",
                                                              "FAKE_PASSWORD", "FAKE_TOKEN", self.foundation))
        self.assertEqual(ids, {})

    def test_safe_evidence_and_secret_redaction(self):
        result, _ = self.deploy_with_fakes("STAGING_FOUNDATION_ALREADY_DEPLOYED")
        raw = json.dumps(result)
        for secret in ("FAKE_TOKEN", "FAKE_PASSWORD", "FAKE_SERVICE_KEY"):
            self.assertNotIn(secret, raw)
        ops = FakeOps()
        ops.identity = Mock(side_effect=RuntimeError("FAKE_TOKEN"))
        with patch.dict(deploy.os.environ, {"SUPABASE_ACCESS_TOKEN": "FAKE_TOKEN",
                                           "SCHOOL_OS_STAGING_DB_PASSWORD": "FAKE_PASSWORD"}), \
             patch.object(deploy, "source_gate", return_value=self.sha), \
             redirect_stderr(io.StringIO()) as errors:
            self.assertEqual(deploy.main(["preflight", "--source-sha", self.sha], ops=ops), 1)
        self.assertNotIn("FAKE_TOKEN", errors.getvalue())
        self.assertNotIn("FAKE_PASSWORD", errors.getvalue())


if __name__ == "__main__":
    unittest.main()
