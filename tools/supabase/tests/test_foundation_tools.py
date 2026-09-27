import contextlib
import io
import json
import shutil
import sys
import tempfile
import unittest
import urllib.error
from pathlib import Path
from unittest.mock import patch

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
import foundation_deploy as deploy
import foundation_guard as guard
import foundation_local_ci as local_ci
import foundation_managed_config as managed
import prepare_local_auth_fixtures as fixtures


class GuardTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.root = Path(self.temp.name)
        (self.root / "supabase/config").mkdir(parents=True)
        (self.root / "supabase/migrations").mkdir()
        (self.root / "supabase/tests/database").mkdir(parents=True)
        shutil.copyfile(guard.CONTRACT, self.root / "supabase/config/foundation_managed_contract.json")
        shutil.copyfile(guard.ROOT / ".gitattributes", self.root / ".gitattributes")
        shutil.copyfile(guard.ROOT / "supabase/config.toml", self.root / "supabase/config.toml")
        self.contract = guard.load_contract(self.root / "supabase/config/foundation_managed_contract.json")
        for section, directory in (("migrations", "migrations"), ("database_tests", "tests/database")):
            for item in self.contract["frozen_foundation"][section]:
                source = guard.ROOT / "supabase" / directory / item["file"]
                target = self.root / "supabase" / directory / item["file"]
                target.write_bytes(source.read_bytes().replace(b"\r\n", b"\n"))

    def tearDown(self):
        self.temp.cleanup()

    def test_malformed_contract(self):
        path = self.root / "bad.json"
        path.write_text("{}", encoding="utf-8")
        with self.assertRaises(guard.GuardError):
            guard.load_contract(path)

    def test_baseline_pass_and_hash_failure(self):
        self.assertEqual(guard.inspect_source(self.root, self.contract, check_git=False)[0], [])
        path = self.root / "supabase/migrations" / self.contract["frozen_foundation"]["migrations"][0]["file"]
        path.write_bytes(path.read_bytes() + b"-- modified\n")
        self.assertTrue(any("SHA-256 mismatch" in x for x in guard.inspect_source(self.root, self.contract, check_git=False)[0]))

    def test_missing_and_future_migration(self):
        name = self.contract["frozen_foundation"]["migrations"][0]["file"]
        (self.root / "supabase/migrations" / name).unlink()
        (self.root / "supabase/migrations/20270101000000_future.sql").write_text("-- future\n")
        errors, notices, extras = guard.inspect_source(self.root, self.contract, check_git=False)
        self.assertTrue(any("missing" in x for x in errors))
        self.assertEqual(extras, ["20270101000000_future.sql"])
        self.assertTrue(any(x.startswith("FUTURE_MIGRATIONS_PRESENT") for x in notices))
        (self.root / "supabase/migrations" / name).write_bytes((guard.ROOT / "supabase/migrations" / name).read_bytes())
        errors, _, _ = guard.inspect_source(self.root, self.contract, future="report", check_git=False)
        self.assertEqual(errors, [])

    def test_crlf_and_private_config(self):
        name = self.contract["frozen_foundation"]["migrations"][0]["file"]
        path = self.root / "supabase/migrations" / name
        path.write_bytes(path.read_bytes().replace(b"\n", b"\r\n"))
        self.assertTrue(any("CRLF" in x for x in guard.inspect_source(self.root, self.contract, require_lf=True, check_git=False)[0]))
        conf = self.root / "supabase/config.toml"
        text = conf.read_text(encoding="utf-8")
        conf.write_text(text.replace('"graphql_public", "app"', '"graphql_public", "app", "app_private"'), encoding="utf-8")
        with self.assertRaises(guard.GuardError):
            guard.inspect_local_config(self.root, self.contract)


class ManagedTests(unittest.TestCase):
    REF = "abcdefghijklmnopqrst"

    def transport(self, schemas, *, other_ref=None):
        calls = []
        state = {"schemas": schemas}

        def fake(method, path, token, payload=None):
            calls.append((method, path, payload))
            if path.endswith("/postgrest"):
                if method == "PATCH":
                    state["schemas"] = payload["db_schema"]
                    return 200, {}
                return 200, {"db_schema": state["schemas"]}
            return 200, {"id": other_ref or self.REF, "name": "Synthetic", "organization_id": "org-test"}

        return fake, calls

    def test_missing_app_and_private_exposure(self):
        fake, calls = self.transport("public,graphql_public")
        with self.assertRaisesRegex(managed.ManagedConfigError, "DRIFT"):
            managed.execute(self.REF, token="fake", transport=fake)
        self.assertFalse(any(x[0] == "PATCH" for x in calls))
        fake, _ = self.transport("public,graphql_public,app,app_private")
        with self.assertRaisesRegex(managed.ManagedConfigError, "FORBIDDEN_SCHEMA"):
            managed.execute(self.REF, token="fake", transport=fake)

    def test_apply_requires_exact_confirmation_and_target(self):
        fake, calls = self.transport("public,graphql_public")
        with self.assertRaisesRegex(managed.ManagedConfigError, "CONFIRMATION"):
            managed.execute(self.REF, apply=True, confirm_ref="wrong", token="fake", transport=fake)
        self.assertEqual(calls, [])
        fake, calls = self.transport("public,graphql_public", other_ref="other")
        with self.assertRaisesRegex(managed.ManagedConfigError, "identity mismatch"):
            managed.execute(self.REF, apply=True, confirm_ref=self.REF, token="fake", transport=fake)
        self.assertFalse(any(x[0] == "PATCH" for x in calls))

    def test_confirmed_apply_patches_only_schema_and_rereads(self):
        fake, calls = self.transport("public,graphql_public")
        self.assertEqual(managed.execute(self.REF, apply=True, confirm_ref=self.REF, token="fake", transport=fake), "MANAGED_CONFIG_PASS")
        patches = [x for x in calls if x[0] == "PATCH"]
        self.assertEqual(len(patches), 1)
        self.assertEqual(patches[0][2], {"db_schema": "public,graphql_public,app"})

    def test_token_redaction(self):
        secret = "fake-management-token-should-not-appear"
        error = urllib.error.HTTPError("https://example.invalid", 403, "failure", {}, io.BytesIO(secret.encode()))
        with patch.object(managed.urllib.request, "urlopen", side_effect=error):
            with self.assertRaises(managed.ManagedConfigError) as cm:
                managed.http_transport("GET", "/v1/projects/" + self.REF, secret)
        self.assertNotIn(secret, str(cm.exception))


class RuntimeTests(unittest.TestCase):
    def test_remote_auth_endpoint_rejected(self):
        for url in ("https://host.supabase.co", "http://localhost.evil:54321", "http://127.0.0.1:6543"):
            with self.assertRaises(fixtures.FixtureError):
                fixtures.validate_local_url(url)

    def test_tap_totals(self):
        good = "1..2\nok 1 - one\nok 2 - two\n"
        self.assertEqual(local_ci.parse_tap(good, 2), 2)
        harness = "file.sql .. ok\nAll tests successful.\nFiles=1, Tests=44,  1 wallclock secs\nResult: PASS\n"
        self.assertEqual(local_ci.parse_tap(harness, 44), 44)
        with self.assertRaises(local_ci.LocalCIError):
            local_ci.parse_tap(harness, 6)
        with self.assertRaises(local_ci.LocalCIError):
            local_ci.parse_tap(good, 3)
        with self.assertRaises(local_ci.LocalCIError):
            local_ci.parse_tap("1..2\nok 1\nnot ok 2\n", 2)

    def test_remote_deploy_apply_disabled(self):
        with contextlib.redirect_stderr(io.StringIO()):
            self.assertEqual(deploy.main(["apply"]), 2)


if __name__ == "__main__":
    unittest.main()
