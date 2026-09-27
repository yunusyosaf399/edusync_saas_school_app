"""P2A local-only staging policy tests using synthetic inputs."""

import copy
import io
import json
import sys
import tempfile
import unittest
from contextlib import redirect_stderr, redirect_stdout
from pathlib import Path
from unittest.mock import patch

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
import foundation_staging as staging


class StagingTests(unittest.TestCase):
    def setUp(self):
        self.foundation = staging.load_contract()
        self.contract = staging.load_staging_contract(foundation=self.foundation)
        self.target = {
            "environment": "staging", "project_ref": "a" * 20,
            "project_name": "schoolos-staging-synthetic-001", "organization_id": "synthetic-org",
            "region": "ap-northeast-2", "foundation_id": "schoolos-foundation-v1",
        }

    def snapshot(self):
        catalog = self.foundation["expected_catalog"]
        return {
            "source": {"commit": "a" * 40, "clean": True, "guard_pass": True, "future_migrations": 0},
            "target": copy.deepcopy(self.target),
            "health": {"project": True, "database": True, "auth": True, "rest": True},
            "postgresql_version": "17.6",
            "migration_versions": [row["version"] for row in self.foundation["frozen_foundation"]["migrations"]],
            "catalog": {key: catalog[key] for key in
                        ("roles", "tables", "policies", "rls_enabled", "rls_forced", "security_definer_functions")},
            "security_smoke": {"auth_fk_name": catalog["auth_binding_fk"],
                               "auth_fk_target": "auth.users(id)", "on_update": "RESTRICT",
                               "on_delete": "SET NULL", "helper_owner": catalog["current_principal_owner"]},
            "data_api_schemas": ["public", "graphql_public", "app"],
            "lint": {"error": "PASS", "warning": "PASS"},
            "foundation_tests": 220, "worker_activation": "deferred",
        }

    def drift_error(self, snapshot, code):
        with self.assertRaisesRegex(staging.StagingError, "^" + code + "$"):
            staging.evaluate_staging_drift(snapshot, self.foundation, self.contract)

    def test_default_is_local_plan_and_no_mutation(self):
        with redirect_stdout(io.StringIO()) as output, patch.dict(staging.os.environ, {}, clear=True):
            self.assertEqual(staging.main([]), 0)
        self.assertIn("no remote apply path", output.getvalue())
        self.assertEqual(len(staging.STEPS), 19)

    def test_plan_is_local_and_does_not_inspect_secrets(self):
        with patch.object(staging, "secret_presence", side_effect=AssertionError("secret inspected")), \
             redirect_stdout(io.StringIO()) as output:
            self.assertEqual(staging.main(["plan"]), 0)
        self.assertIn("one migration push", output.getvalue())

    def test_validate_is_local_and_does_not_inspect_secrets(self):
        with patch.object(staging, "secret_presence", side_effect=AssertionError("secret inspected")), \
             patch.object(staging, "inspect_source", return_value=([], [], [])), \
             patch.object(staging, "inspect_local_config", return_value=["public", "graphql_public", "app"]), \
             redirect_stdout(io.StringIO()) as output:
            self.assertEqual(staging.main(["validate"]), 0)
        self.assertIn("STAGING_VALIDATE_PASS", output.getvalue())

    def test_contract_validates_and_references_managed_baseline(self):
        self.assertEqual(staging.validate_staging_contract(self.contract, self.foundation), self.contract)
        self.assertEqual(self.contract["foundation_contract"], staging.CONTRACT_REL)

    def test_malformed_contract_fails(self):
        for change in (lambda x: x.pop("source_policy"),
                       lambda x: x.update(environment="production"),
                       lambda x: x["project_policy"].update(extra=True),
                       lambda x: x["drift_policy"].update(automatic_repair_forbidden=False)):
            bad = copy.deepcopy(self.contract)
            change(bad)
            with self.subTest(bad=bad):
                with self.assertRaises(staging.StagingError):
                    staging.validate_staging_contract(bad, self.foundation)

    def test_embedded_secret_like_config_rejected(self):
        for value in ("sbp_FAKE00000000000000000000", "sb_secret_FAKE00000000000000000000"):
            bad = copy.deepcopy(self.contract)
            bad["foundation_id"] = value
            with self.subTest(value_type="synthetic"):
                with self.assertRaisesRegex(staging.StagingError, "STAGING_CONTRACT_EMBEDDED_SECRET"):
                    staging.validate_staging_contract(bad, self.foundation)

    def test_contract_file_load_fails_closed(self):
        with tempfile.TemporaryDirectory() as folder:
            path = Path(folder) / "contract.json"
            path.write_text('{"format_version": 1}', encoding="utf-8")
            with self.assertRaises(staging.StagingError):
                staging.load_staging_contract(path, self.foundation)

    def test_valid_target(self):
        self.assertEqual(staging.validate_target_manifest(self.target, self.contract), "TARGET_MANIFEST_PASS")

    def test_bad_project_ref(self):
        for value in ("A" * 20, "a" * 19, "a" * 21, "bad-ref"):
            bad = {**self.target, "project_ref": value}
            with self.subTest(value=value), self.assertRaisesRegex(staging.StagingError, "TARGET_REF"):
                staging.validate_target_manifest(bad, self.contract)

    def test_wrong_staging_prefix(self):
        bad = {**self.target, "project_name": "customer-school"}
        with self.assertRaisesRegex(staging.StagingError, "TARGET_NAME"):
            staging.validate_target_manifest(bad, self.contract)

    def test_p1_prefix_rejected(self):
        bad = {**self.target, "project_name": "schoolos-foundation-productization-p1-20260927"}
        with self.assertRaisesRegex(staging.StagingError, "TARGET_NAME"):
            staging.validate_target_manifest(bad, self.contract)

    def test_wrong_environment(self):
        bad = {**self.target, "environment": "production"}
        with self.assertRaisesRegex(staging.StagingError, "TARGET_ENVIRONMENT"):
            staging.validate_target_manifest(bad, self.contract)

    def test_wrong_foundation_id(self):
        bad = {**self.target, "foundation_id": "other"}
        with self.assertRaisesRegex(staging.StagingError, "TARGET_FOUNDATION_ID"):
            staging.validate_target_manifest(bad, self.contract)

    def test_wrong_region(self):
        bad = {**self.target, "region": "other"}
        with self.assertRaisesRegex(staging.StagingError, "TARGET_REGION"):
            staging.validate_target_manifest(bad, self.contract)

    def test_missing_organization(self):
        bad = {**self.target, "organization_id": "  "}
        with self.assertRaisesRegex(staging.StagingError, "TARGET_ORGANIZATION"):
            staging.validate_target_manifest(bad, self.contract)

    def test_manifest_missing_and_unknown_fields_rejected(self):
        for bad in ({k: v for k, v in self.target.items() if k != "region"},
                    {**self.target, "extra": True}):
            with self.assertRaisesRegex(staging.StagingError, "TARGET_MANIFEST_SHAPE"):
                staging.validate_target_manifest(bad, self.contract)

    def test_secret_preflight_presence_without_value(self):
        fake = {"SUPABASE_ACCESS_TOKEN": "FAKE_MANAGEMENT_TOKEN",
                "SCHOOL_OS_STAGING_DB_PASSWORD": "FAKE_STAGING_DB_PASSWORD"}
        with patch.dict(staging.os.environ, fake, clear=True), redirect_stdout(io.StringIO()) as output:
            self.assertEqual(staging.main(["secret-preflight"]), 0)
        shown = output.getvalue()
        self.assertIn("SUPABASE_ACCESS_TOKEN=present", shown)
        self.assertIn("SCHOOL_OS_STAGING_DB_PASSWORD=present", shown)
        self.assertNotIn("FAKE_MANAGEMENT_TOKEN", shown)
        self.assertNotIn("FAKE_STAGING_DB_PASSWORD", shown)

    def test_secret_preflight_missing(self):
        with patch.dict(staging.os.environ, {}, clear=True), redirect_stdout(io.StringIO()) as output:
            self.assertEqual(staging.main(["secret-preflight"]), 0)
        self.assertIn("SUPABASE_ACCESS_TOKEN=missing", output.getvalue())
        self.assertIn("SCHOOL_OS_STAGING_DB_PASSWORD=missing", output.getvalue())

    def test_drift_plan_is_read_only(self):
        with redirect_stdout(io.StringIO()) as output:
            self.assertEqual(staging.main(["drift-plan"]), 0)
        self.assertIn("no automatic repair", output.getvalue())
        self.assertTrue(all(category in output.getvalue() for category in staging.DRIFT_CATEGORIES))

    def test_compliant_snapshot_passes(self):
        self.assertEqual(staging.evaluate_staging_drift(self.snapshot(), self.foundation, self.contract),
                         "STAGING_DRIFT_PASS")

    def test_missing_migration_fails(self):
        snap = self.snapshot()
        snap["migration_versions"].pop()
        self.drift_error(snap, "DRIFT_MIGRATION_HISTORY")

    def test_extra_migration_fails(self):
        snap = self.snapshot()
        snap["migration_versions"].append("20990101000000")
        self.drift_error(snap, "DRIFT_MIGRATION_HISTORY")

    def test_catalog_count_mismatch_fails(self):
        snap = self.snapshot()
        snap["catalog"]["tables"] += 1
        self.drift_error(snap, "DRIFT_CATALOG")

    def test_rls_mismatch_fails(self):
        snap = self.snapshot()
        snap["catalog"]["rls_forced"] -= 1
        self.drift_error(snap, "DRIFT_CATALOG")

    def test_auth_fk_mismatch_fails(self):
        snap = self.snapshot()
        snap["security_smoke"]["on_delete"] = "CASCADE"
        self.drift_error(snap, "DRIFT_SECURITY_SMOKE")

    def test_helper_owner_mismatch_fails(self):
        snap = self.snapshot()
        snap["security_smoke"]["helper_owner"] = "postgres"
        self.drift_error(snap, "DRIFT_SECURITY_SMOKE")

    def test_app_private_exposure_fails(self):
        snap = self.snapshot()
        snap["data_api_schemas"].append("app_private")
        self.drift_error(snap, "DRIFT_DATA_API")

    def test_extra_data_api_schema_fails(self):
        snap = self.snapshot()
        snap["data_api_schemas"].append("extra")
        self.drift_error(snap, "DRIFT_DATA_API")

    def test_unhealthy_service_fails(self):
        snap = self.snapshot()
        snap["health"]["auth"] = False
        self.drift_error(snap, "DRIFT_HEALTH")

    def test_unsupported_postgresql_major_fails(self):
        snap = self.snapshot()
        snap["postgresql_version"] = "14.9"
        self.drift_error(snap, "DRIFT_POSTGRESQL_VERSION")

    def test_newer_postgresql_major_allowed(self):
        snap = self.snapshot()
        snap["postgresql_version"] = "18.0"
        self.assertEqual(staging.evaluate_staging_drift(snap, self.foundation, self.contract),
                         "STAGING_DRIFT_PASS")

    def test_foundation_test_total_mismatch_fails(self):
        snap = self.snapshot()
        snap["foundation_tests"] = 219
        self.drift_error(snap, "DRIFT_FOUNDATION_TESTS")

    def test_source_and_worker_activation_fail_closed(self):
        snap = self.snapshot()
        snap["source"]["clean"] = False
        self.drift_error(snap, "DRIFT_SOURCE")
        snap = self.snapshot()
        snap["worker_activation"] = "active"
        self.drift_error(snap, "DRIFT_WORKER_ACTIVATION_BOUNDARY")

    def test_no_automatic_repair_or_remote_apply_mode(self):
        self.assertTrue(self.contract["drift_policy"]["automatic_repair_forbidden"])
        self.assertTrue(all(self.contract["destructive_action_policy"].values()))
        with redirect_stderr(io.StringIO()), self.assertRaises(SystemExit) as error:
            staging.main(["apply"])
        self.assertEqual(error.exception.code, 2)

    def test_premature_target_manifest_blocks_validate(self):
        with tempfile.TemporaryDirectory() as folder:
            root = Path(folder)
            (root / "supabase/config").mkdir(parents=True)
            with patch.object(staging, "inspect_source", return_value=([], [], [])), \
                 patch.object(staging, "inspect_local_config", return_value=[]):
                with self.assertRaisesRegex(staging.StagingError, "STAGING_TARGET_MANIFEST_REQUIRED"):
                    staging.validate_local(self.contract, self.foundation, root=root)

    def test_committed_manifest_loads(self):
        manifest = staging.load_target_manifest(staging=self.contract)
        self.assertEqual(manifest["project_ref"], "whwongqcgjakcfrzbvcg")
        self.assertEqual(manifest["project_name"], "schoolos-staging-main")

    def test_missing_target_manifest_fails(self):
        with tempfile.TemporaryDirectory() as folder:
            with self.assertRaisesRegex(staging.StagingError, "TARGET_MANIFEST_UNREADABLE"):
                staging.load_target_manifest(Path(folder) / "missing.json", self.contract)

    def test_malformed_target_json_fails(self):
        with tempfile.TemporaryDirectory() as folder:
            path = Path(folder) / "target.json"
            path.write_text("{broken", encoding="utf-8")
            with self.assertRaisesRegex(staging.StagingError, "TARGET_MANIFEST_UNREADABLE"):
                staging.load_target_manifest(path, self.contract)

    def test_local_validate_rejects_wrong_pinned_target(self):
        with tempfile.TemporaryDirectory() as folder:
            root = Path(folder)
            config = root / "supabase/config"
            config.mkdir(parents=True)
            path = config / "foundation_staging_target.json"
            for key, value, code in (("project_ref", "invalid", "TARGET_REF"),
                                     ("project_name", "customer", "TARGET_NAME"),
                                     ("organization_id", "", "TARGET_ORGANIZATION"),
                                     ("region", "other", "TARGET_REGION"),
                                     ("environment", "production", "TARGET_ENVIRONMENT")):
                bad = dict(self.target)
                bad[key] = value
                path.write_text(json.dumps(bad), encoding="utf-8")
                with self.subTest(key=key), \
                     patch.object(staging, "inspect_source", return_value=([], [], [])), \
                     patch.object(staging, "inspect_local_config", return_value=[]):
                    with self.assertRaisesRegex(staging.StagingError, code):
                        staging.validate_local(self.contract, self.foundation, root=root)

    def test_identity_check_requires_token_before_http(self):
        with patch.dict(staging.os.environ, {}, clear=True), \
             patch.object(staging, "management_get", side_effect=AssertionError("network")), \
             patch.object(staging, "validate_local", return_value="STAGING_VALIDATE_PASS"), \
             redirect_stderr(io.StringIO()) as error:
            self.assertEqual(staging.main(["identity-check"]), 1)
        self.assertIn("STAGING_IDENTITY_TOKEN_MISSING", error.getvalue())

    def test_detail_mismatch_fails(self):
        for key, wrong in (("id", "b" * 20), ("name", "wrong"),
                           ("organization_id", "wrong"), ("region", "wrong")):
            item = {**self.live_item(), key: wrong}
            with self.subTest(key=key), \
                 self.assertRaisesRegex(staging.StagingError, "STAGING_IDENTITY_DETAIL_MISMATCH"):
                staging.check_live_identity(self.target, self.contract, "FAKE_MANAGEMENT_TOKEN",
                                            get=lambda path, token: (200, item))

    def test_project_not_found_fails(self):
        with self.assertRaisesRegex(staging.StagingError, "STAGING_IDENTITY_PROJECT_NOT_FOUND"):
            staging.check_live_identity(self.target, self.contract, "FAKE_MANAGEMENT_TOKEN",
                                        get=lambda path, token: (404, None))

    def test_list_absence_fails(self):
        expected = self.live_item()
        def get(path, token):
            return (200, expected) if path.endswith(self.target["project_ref"]) else (200, [])
        with self.assertRaisesRegex(staging.StagingError, "STAGING_IDENTITY_LIST_MISMATCH"):
            staging.check_live_identity(self.target, self.contract, "FAKE_MANAGEMENT_TOKEN", get=get)

    def test_duplicate_list_identity_fails(self):
        expected = self.live_item()
        def get(path, token):
            return (200, expected) if path.endswith(self.target["project_ref"]) else (200, [expected, expected])
        with self.assertRaisesRegex(staging.StagingError, "STAGING_IDENTITY_LIST_MISMATCH"):
            staging.check_live_identity(self.target, self.contract, "FAKE_MANAGEMENT_TOKEN", get=get)

    def test_list_identity_mismatch_fails(self):
        expected = self.live_item()
        bad = {**expected, "region": "wrong"}
        def get(path, token):
            return (200, expected) if path.endswith(self.target["project_ref"]) else (200, [bad])
        with self.assertRaisesRegex(staging.StagingError, "STAGING_IDENTITY_LIST_MISMATCH"):
            staging.check_live_identity(self.target, self.contract, "FAKE_MANAGEMENT_TOKEN", get=get)

    def live_item(self):
        return {"id": self.target["project_ref"], "name": self.target["project_name"],
                "organization_id": self.target["organization_id"], "region": self.target["region"]}

    def test_correct_detail_and_list_pass(self):
        item = self.live_item()
        paths = []
        def get(path, token):
            paths.append(path)
            return (200, item) if path.endswith(self.target["project_ref"]) else (200, [item])
        self.assertEqual(staging.check_live_identity(self.target, self.contract, "FAKE_MANAGEMENT_TOKEN", get=get),
                         "STAGING_IDENTITY_PASS")
        self.assertEqual(paths, ["/v1/projects/" + self.target["project_ref"], "/v1/projects"])

    def test_management_transport_get_only(self):
        item = self.live_item()
        class Response:
            status = 200
            def __enter__(self):
                return self
            def __exit__(self, *args):
                return False
            def read(self):
                return json.dumps(item).encode("utf-8")
        with patch.object(staging.urllib.request, "urlopen", return_value=Response()) as opened:
            status, result = staging.management_get("/v1/projects/" + self.target["project_ref"],
                                                     "FAKE_MANAGEMENT_TOKEN")
        request = opened.call_args.args[0]
        self.assertEqual(request.get_method(), "GET")
        self.assertIsNone(request.data)
        self.assertEqual(status, 200)
        self.assertEqual(result, item)

    def test_no_mutating_http_method_or_remote_apply_mode(self):
        self.assertNotIn("apply", staging.main.__code__.co_consts)
        with redirect_stderr(io.StringIO()), self.assertRaises(SystemExit) as error:
            staging.main(["apply"])
        self.assertEqual(error.exception.code, 2)

    def test_http_errors_are_redacted(self):
        with patch.object(staging.urllib.request, "urlopen",
                          side_effect=staging.urllib.error.URLError("FAKE_MANAGEMENT_TOKEN")):
            with self.assertRaisesRegex(staging.StagingError, "^STAGING_IDENTITY_MANAGEMENT_HTTP_ERROR$") as error:
                staging.management_get("/v1/projects/" + self.target["project_ref"], "FAKE_MANAGEMENT_TOKEN")
        self.assertNotIn("FAKE_MANAGEMENT_TOKEN", str(error.exception))

    def test_token_never_appears_in_safe_result_or_error(self):
        secret = "FAKE_MANAGEMENT_TOKEN"
        item = self.live_item()
        def get(path, token):
            return (200, item) if path.endswith(self.target["project_ref"]) else (200, [item])
        self.assertNotIn(secret, staging.check_live_identity(self.target, self.contract, secret, get=get))
        with self.assertRaises(staging.StagingError) as error:
            staging.check_live_identity(self.target, self.contract, secret,
                                        get=lambda path, token: (_ for _ in ()).throw(RuntimeError(secret)))
        self.assertEqual(str(error.exception), "STAGING_IDENTITY_MANAGEMENT_HTTP_ERROR")


if __name__ == "__main__":
    unittest.main()
