"""P1 safety tests; all destructive paths use fakes only."""

import io
import sys
import unittest
from contextlib import redirect_stdout, redirect_stderr
from pathlib import Path
from unittest.mock import patch

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
import foundation_rehearsal as p1


class RehearsalSafetyTests(unittest.TestCase):
    def test_default_plan_has_no_network_or_mutation(self):
        with patch.object(p1, "api", side_effect=AssertionError("network")), redirect_stdout(io.StringIO()):
            self.assertEqual(p1.main([]), 0)

    def test_run_requires_flag_and_exact_organization(self):
        with redirect_stderr(io.StringIO()):
            self.assertEqual(p1.main(["run"]), 2)
            self.assertEqual(p1.main(["run", "--run", "--confirm-organization-name", "Other"]), 2)

    def test_wrong_organization_confirmation_blocks_before_api(self):
        with patch.object(p1, "api", side_effect=AssertionError("network")):
            with self.assertRaisesRegex(p1.RehearsalError, "ORGANIZATION_CONFIRMATION_MISMATCH"):
                p1.choose_org("secret", "Other")

    def test_disposable_prefix_and_unrelated_ref_blocked(self):
        with patch.object(p1, "api", side_effect=AssertionError("network")):
            with self.assertRaisesRegex(p1.RehearsalError, "DISPOSABLE_TARGET_REQUIRED"):
                p1.verify_target("secret", "a" * 20, "production", "org", p1.REGION)
            with self.assertRaisesRegex(p1.RehearsalError, "DISPOSABLE_TARGET_REQUIRED"):
                p1.verify_target("secret", "bad-ref", p1.PREFIX + "x", "org", p1.REGION)

    def test_target_detail_or_list_mismatch_blocks(self):
        ref, name, org = "a" * 20, p1.PREFIX + "x", "org"
        good = {"id": ref, "name": name, "organization_id": org, "region": p1.REGION}
        with patch.object(p1, "api", side_effect=[(200, dict(good, region="wrong")), (200, [good])]):
            with self.assertRaisesRegex(p1.RehearsalError, "DETAIL_IDENTITY_MISMATCH"):
                p1.verify_target("secret", ref, name, org, p1.REGION)
        with patch.object(p1, "api", side_effect=[(200, good), (200, [])]):
            with self.assertRaisesRegex(p1.RehearsalError, "LIST_IDENTITY_MISMATCH"):
                p1.verify_target("secret", ref, name, org, p1.REGION)

    def test_dry_run_mismatch_blocks(self):
        with self.assertRaisesRegex(p1.RehearsalError, "DRY_RUN_MISMATCH"):
            p1.verify_dry_run("20260924122442_one.sql", ["20260924122442", "20260924122445"])

    def test_command_failure_no_retry_and_no_secret_in_exception(self):
        fake = type("Result", (), {"returncode": 1, "stdout": "secret-pw", "stderr": "secret-pw"})()
        with patch.object(p1.subprocess, "run", return_value=fake) as run:
            with self.assertRaises(p1.RehearsalError) as caught:
                p1.run_command(["supabase", "db", "push"])
            self.assertEqual(run.call_count, 1)
            self.assertNotIn("secret-pw", str(caught.exception))

    def test_health_timeout_blocks(self):
        with patch.object(p1, "api", return_value=(200, {"status": "COMING_UP"})):
            with self.assertRaisesRegex(p1.RehearsalError, "HEALTH_TIMEOUT"):
                p1.project_health("secret", "a" * 20, attempts=2, sleep=lambda _: None)

    def test_delete_confirmation_requires_detail_and_list_absence_and_peers(self):
        ref, peer = "a" * 20, "b" * 20
        with patch.object(p1, "api", side_effect=[(404, None), (200, [{"id": ref}, {"id": peer}])]):
            with self.assertRaisesRegex(p1.RehearsalError, "DELETE_ABSENCE_UNCONFIRMED"):
                p1.confirm_absence("secret", ref, {peer}, attempts=1, sleep=lambda _: None)
        with patch.object(p1, "api", side_effect=[(404, None), (200, [])]):
            with self.assertRaisesRegex(p1.RehearsalError, "DELETE_ABSENCE_UNCONFIRMED"):
                p1.confirm_absence("secret", ref, {peer}, attempts=1, sleep=lambda _: None)
        with patch.object(p1, "api", side_effect=[(404, None), (200, [{"id": peer}])]):
            self.assertTrue(p1.confirm_absence("secret", ref, {peer}, attempts=1, sleep=lambda _: None))

    def test_management_http_exception_is_redacted(self):
        import urllib.error
        error = urllib.error.HTTPError("https://example/?password=secret-pw", 403,
                                      "secret-pw", {}, None)
        with patch.object(p1.urllib.request, "urlopen", side_effect=error):
            with self.assertRaises(p1.RehearsalError) as caught:
                p1.api("GET", "/v1/projects", "secret-pw")
            self.assertNotIn("secret-pw", str(caught.exception))


if __name__ == "__main__":
    unittest.main()
