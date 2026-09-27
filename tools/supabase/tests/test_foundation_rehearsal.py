"""P1 safety tests; all destructive paths use fakes only."""

import io
import json
import subprocess
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

    def test_run_without_token_fails_before_network(self):
        with patch.dict(p1.os.environ, {}, clear=True), \
             patch.object(p1, "api", side_effect=AssertionError("network")), \
             redirect_stderr(io.StringIO()) as output:
            self.assertEqual(p1.main(["run", "--run", "--confirm-organization-name", p1.ORG_NAME]), 2)
        self.assertIn("SUPABASE_ACCESS_TOKEN_ABSENT", output.getvalue())

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
                p1.confirm_absence("secret", ref, {peer}, state=p1.CleanupState(delete_count=1), attempts=1, sleep=lambda _: None)
        with patch.object(p1, "api", side_effect=[(404, None), (200, [])]):
            with self.assertRaisesRegex(p1.RehearsalError, "DELETE_ABSENCE_UNCONFIRMED"):
                p1.confirm_absence("secret", ref, {peer}, state=p1.CleanupState(delete_count=1), attempts=1, sleep=lambda _: None)
        with patch.object(p1, "api", side_effect=[(404, None), (200, [{"id": peer}])]):
            evidence = p1.confirm_absence("secret", ref, {peer}, state=p1.CleanupState(delete_count=1), attempts=1, sleep=lambda _: None)
            self.assertEqual(evidence["phase"], "CLEANUP_CONFIRMED")

    def test_management_http_exception_is_redacted(self):
        import urllib.error
        error = urllib.error.HTTPError("https://example/?password=secret-pw", 403,
                                      "secret-pw", {}, None)
        with patch.object(p1.urllib.request, "urlopen", side_effect=error):
            with self.assertRaises(p1.RehearsalError) as caught:
                p1.api("GET", "/v1/projects", "secret-pw")
            self.assertNotIn("secret-pw", str(caught.exception))


class P1RDiagnosticTests(unittest.TestCase):
    def test_allowlisted_psql_categories(self):
        cases = {
            "password authentication failed for user secret": "PSQL_AUTH_FAILED",
            "Tenant or user not found secret": "PSQL_TENANT_OR_USER_NOT_FOUND",
            "could not translate host name private.example": "PSQL_DNS_FAILED",
            "connection refused private.example": "PSQL_CONNECTION_REFUSED",
            "connection timed out private.example": "PSQL_CONNECT_TIMEOUT",
            "psql: error: connection to server private.example failed: connection timed out": "PSQL_CONNECT_TIMEOUT",
            "SSL error: secret": "PSQL_TLS_FAILED",
            "server closed the connection unexpectedly": "PSQL_SERVER_CLOSED",
            "FATAL: database \"postgres\" does not exist": "PSQL_DATABASE_UNAVAILABLE",
            "no pg_hba.conf entry for host secret": "PSQL_PG_HBA_DENIED",
            "psql: ERROR: syntax error at or near secret": "PSQL_SQL_ERROR",
            "mystery output with secret": "PSQL_UNKNOWN_FAILURE",
        }
        for message, expected in cases.items():
            with self.subTest(expected=expected):
                self.assertEqual(p1.classify_psql_failure(message, "", 3), expected)

    def test_stage_aware_psql_error_is_secret_free(self):
        fake_secret = "FAKE_DB_PASSWORD_123"
        fake = type("Result", (), {"returncode": 3, "stdout": "",
             "stderr": "psql: password authentication failed " + fake_secret +
                       " postgresql://postgres.fake:pass@host:5432/postgres Authorization: Bearer FAKE_PAT"})()
        ref = "a" * 20
        uri = "postgresql://postgres." + ref + "@aws-0-ap-northeast-2.pooler.supabase.com:5432/postgres?sslmode=require"
        with patch.object(p1.subprocess, "run", return_value=fake):
            with self.assertRaises(p1.PsqlFailure) as caught:
                p1.db_sql(uri, fake_secret, "SELECT 1;", stage="DB_PROBE_VERSION")
        output = str(caught.exception) + json.dumps(caught.exception.__dict__)
        self.assertIn("stage=DB_PROBE_VERSION", output)
        self.assertIn("class=PSQL_AUTH_FAILED", output)
        for secret in (fake_secret, "FAKE_PAT", "Authorization", "postgresql://", "host"):
            self.assertNotIn(secret, output)

    def test_subprocess_timeout_is_process_not_connection_timeout(self):
        ref = "a" * 20
        uri = "postgresql://postgres." + ref + "@aws-0-ap-northeast-2.pooler.supabase.com:5432/postgres?sslmode=require"
        password = "FAKE_DB_PASSWORD"
        timeout = subprocess.TimeoutExpired(
            cmd=["docker", "run", "FAKE_PAT", uri], timeout=25,
            output=b"FAKE_JWT", stderr=b"Authorization: Bearer FAKE_SERVICE_KEY")
        with patch.object(p1.subprocess, "run", side_effect=timeout):
            with self.assertRaises(p1.PsqlFailure) as caught:
                p1.db_sql(uri, password, "SELECT 1;", stage="DB_PROBE_VERSION", timeout=25)
        failure = caught.exception
        self.assertEqual(failure.stage, "DB_PROBE_VERSION")
        self.assertEqual(failure.category, "PSQL_PROCESS_TIMEOUT")
        self.assertNotEqual(failure.category, "PSQL_CONNECT_TIMEOUT")
        self.assertEqual(failure.returncode, 124)
        safe_output = str(failure) + json.dumps(failure.__dict__)
        for secret in (uri, password, "FAKE_PAT", "FAKE_JWT", "FAKE_SERVICE_KEY",
                       "Authorization", "docker", "SELECT 1"):
            self.assertNotIn(secret, safe_output)

    def test_probe_retries_only_transient_read_only_failure(self):
        ref = "a" * 20
        uri = "postgresql://postgres." + ref + "@aws-0-ap-northeast-2.pooler.supabase.com:5432/postgres?sslmode=require"
        transient = p1.PsqlFailure("DB_PROBE_VERSION", "PSQL_AUTH_FAILED", 3)
        with patch.object(p1, "db_sql", side_effect=[transient, ["17.6", "postgres", "postgres"]]) as query:
            self.assertEqual(p1.probe_database_connection(uri, "fake", attempts=2, delay=0, sleep=lambda _: None), "17.6")
            self.assertEqual(query.call_count, 2)
            self.assertTrue(all("SELECT current_setting" in c.args[2] for c in query.call_args_list))
        process_timeout = p1.PsqlFailure("DB_PROBE_VERSION", "PSQL_PROCESS_TIMEOUT", 124)
        with patch.object(p1, "db_sql", side_effect=[process_timeout, ["17.6", "postgres", "postgres"]]) as query:
            self.assertEqual(p1.probe_database_connection(uri, "fake", attempts=2, delay=0, sleep=lambda _: None), "17.6")
            self.assertEqual(query.call_count, 2)
        permanent = p1.PsqlFailure("DB_PROBE_VERSION", "PSQL_TLS_FAILED", 3)
        with patch.object(p1, "db_sql", side_effect=permanent) as query:
            with self.assertRaises(p1.PsqlFailure):
                p1.probe_database_connection(uri, "fake", attempts=4, delay=0, sleep=lambda _: None)
            self.assertEqual(query.call_count, 1)

    def test_probe_retry_exhaustion_is_bounded(self):
        failure = p1.PsqlFailure("DB_PROBE_VERSION", "PSQL_CONNECT_TIMEOUT", 124)
        with patch.object(p1, "db_sql", side_effect=failure) as query:
            with self.assertRaises(p1.PsqlFailure):
                p1.probe_database_connection("synthetic", "fake", attempts=3, delay=0, sleep=lambda _: None)
            self.assertEqual(query.call_count, 3)

    def test_failed_push_is_never_retried_and_output_is_redacted(self):
        ref = "a" * 20
        uri = "postgresql://postgres." + ref + "@aws-0-ap-northeast-2.pooler.supabase.com:5432/postgres?sslmode=require"
        fake = type("Result", (), {"returncode": 1,
             "stdout": "FAKE_JWT FAKE_SERVICE_KEY FAKE_DB_PASSWORD Authorization: Bearer FAKE_PAT",
             "stderr": "postgresql://postgres:FAKE_DB_PASSWORD@host/db"})()
        with patch.object(p1.subprocess, "run", return_value=fake) as run:
            with self.assertRaises(p1.RehearsalError) as caught:
                p1.cli(["db", "push", "--yes"], uri, "FAKE_DB_PASSWORD")
            self.assertEqual(run.call_count, 1)
        output = str(caught.exception) + json.dumps(caught.exception.__dict__)
        self.assertIn("CLI_PUSH_FAILED", output)
        for secret in ("FAKE_JWT", "FAKE_SERVICE_KEY", "FAKE_DB_PASSWORD", "FAKE_PAT",
                       "Authorization", "postgresql://"):
            self.assertNotIn(secret, output)

    def test_session_route_validation(self):
        ref = "a" * 20
        host = "aws-0-ap-northeast-2.pooler.supabase.com"
        response = [{"db_host": host, "db_user": "postgres." + ref,
                     "db_name": "postgres", "db_port": 6543, "pool_mode": "transaction"}]
        route = p1.route_from_pooler_response(response, ref)
        self.assertEqual(route, "postgresql://postgres." + ref + "@" + host +
                         ":5432/postgres?sslmode=require")
        for bad in (route.replace(":5432/", ":6543/"),
                    route.replace(host, "non-supabase.example"),
                    route.replace("postgres." + ref, "postgres:fake-password@postgres." + ref),
                    route.replace("postgres." + ref, "postgres." + "b" * 20)):
            with self.assertRaises(p1.RehearsalError):
                p1.validate_session_uri(bad, ref)
        with self.assertRaises(p1.RehearsalError):
            p1.route_from_pooler_response(response + [dict(response[0], db_host="other.pooler.supabase.com")], ref)
        with self.assertRaises(p1.RehearsalError):
            p1.route_from_pooler_response([dict(response[0], db_user="postgres." + "b" * 20)], ref)


class P1RCleanupTests(unittest.TestCase):
    def setUp(self):
        self.ref, self.peer = "a" * 20, "b" * 20
        self.name, self.org = p1.PREFIX + "unit", "test-org"
        self.good = {"id": self.ref, "name": self.name,
                     "organization_id": self.org, "region": p1.REGION}

    def test_one_delete_then_403_200_404_and_absence(self):
        calls = []
        responses = iter([(200, self.good), (200, [self.good, {"id": self.peer}]),
                          (200, None), (403, None), (200, [self.good, {"id": self.peer}]),
                          (200, self.good), (200, [{"id": self.peer}]),
                          (404, None), (200, [{"id": self.peer}])])
        def fake(method, path, token, *args, **kwargs):
            calls.append((method, path))
            return next(responses)
        with patch.object(p1, "api", side_effect=fake):
            state = p1.CleanupState(phase="PROJECT_CREATED")
            result = p1.delete_project_once("fake-token", self.ref, self.name, self.org,
                       p1.REGION, {self.peer}, state=state, attempts=3, delay=0, sleep=lambda _: None)
        self.assertEqual(result["phase"], "CLEANUP_CONFIRMED")
        self.assertEqual(result["delete_status"], 200)
        self.assertEqual(len([c for c in calls if c[0] == "DELETE"]), 1)

    def test_identity_mismatch_never_deletes(self):
        calls = []
        def fake(method, path, token, *args, **kwargs):
            calls.append(method)
            return (200, dict(self.good, region="wrong")) if len(calls) == 1 else (200, [])
        with patch.object(p1, "api", side_effect=fake):
            with self.assertRaisesRegex(p1.RehearsalError, "DETAIL_IDENTITY_MISMATCH"):
                p1.delete_project_once("fake", self.ref, self.name, self.org,
                                       p1.REGION, {self.peer})
        self.assertNotIn("DELETE", calls)

    def test_delayed_absence_timeout_and_peer_loss(self):
        state = p1.CleanupState(phase="DELETE_ACCEPTED", delete_count=1)
        with patch.object(p1, "api", side_effect=[(404, None), (200, [{"id": self.ref}])]):
            with self.assertRaisesRegex(p1.RehearsalError, "DELETE_ABSENCE_UNCONFIRMED"):
                p1.confirm_absence("fake", self.ref, {self.peer}, state=state,
                                   attempts=1, delay=0, sleep=lambda _: None)
        with patch.object(p1, "api", side_effect=[(404, None), (200, [])]):
            with self.assertRaisesRegex(p1.RehearsalError, "DELETE_ABSENCE_UNCONFIRMED"):
                p1.confirm_absence("fake", self.ref, {self.peer}, state=state,
                                   attempts=1, delay=0, sleep=lambda _: None)
        self.assertFalse(state.peers_preserved)

    def test_ambiguous_creation_reconciliation(self):
        self.assertEqual(p1.reconcile_created_project([self.good], self.name, self.org, p1.REGION), self.ref)
        for projects in ([], [self.good, self.good], [dict(self.good, region="wrong")]):
            with self.assertRaisesRegex(p1.RehearsalError, "CREATION_RECONCILIATION_AMBIGUOUS"):
                p1.reconcile_created_project(projects, self.name, self.org, p1.REGION)

    def test_cleanup_evidence_contains_no_secrets(self):
        state = p1.CleanupState(phase="DELETE_ACCEPTED", delete_count=1,
                                delete_status=200, delete_at="2026-09-27T00:00:00Z")
        dump = json.dumps(state.safe_evidence())
        for secret in ("FAKE_DB_PASSWORD", "FAKE_PAT", "FAKE_JWT", "FAKE_SERVICE_KEY",
                       "Authorization", "postgresql://"):
            self.assertNotIn(secret, dump)


class P1R2MigrationBaselineTests(unittest.TestCase):
    def setUp(self):
        self.versions = p1.migration_versions(p1.load_contract())

    def test_absent_history_table_returns_zero_without_count_query(self):
        with patch.object(p1, "db_sql", return_value=["f"]) as query, \
             patch.object(p1, "count_sql", side_effect=AssertionError("count must not run")) as count:
            self.assertEqual(p1.foundation_migration_baseline_count("fake-uri", "fake-password", self.versions), 0)
        self.assertEqual(query.call_count, 1)
        self.assertEqual(query.call_args.kwargs["stage"], "DB_BASELINE_MIGRATION_HISTORY_EXISTS")
        self.assertIn("to_regclass", query.call_args.args[2])
        count.assert_not_called()

    def test_existing_empty_history_table_returns_zero(self):
        with patch.object(p1, "db_sql", return_value=["t"]) as exists, \
             patch.object(p1, "count_sql", return_value=0) as count:
            self.assertEqual(p1.foundation_migration_baseline_count("fake-uri", "fake-password", self.versions), 0)
        self.assertEqual(exists.call_count, 1)
        self.assertEqual(count.call_count, 1)
        self.assertEqual(count.call_args.kwargs["stage"], "DB_BASELINE_MIGRATION_HISTORY_COUNT")
        self.assertTrue(all(version in count.call_args.args[2] for version in self.versions))

    def test_existing_dirty_history_count_is_preserved(self):
        with patch.object(p1, "db_sql", return_value=["t"]), \
             patch.object(p1, "count_sql", return_value=1):
            count = p1.foundation_migration_baseline_count("fake-uri", "fake-password", self.versions)
        self.assertEqual(count, 1)
        with self.assertRaisesRegex(p1.RehearsalError, "DIRTY_BASELINE"):
            p1.require([0, 0, count, 0] == [0, 0, 0, 0], "DIRTY_BASELINE")

    def test_malformed_existence_fails_closed(self):
        for malformed in ([], ["unexpected"], ["t", "f"], [""], ["T"]):
            with self.subTest(malformed=malformed), \
                 patch.object(p1, "db_sql", return_value=malformed) as query, \
                 patch.object(p1, "count_sql", side_effect=AssertionError("count must not run")):
                with self.assertRaisesRegex(p1.RehearsalError, "BASELINE_HISTORY_EXISTENCE_MALFORMED"):
                    p1.foundation_migration_baseline_count("fake-uri", "fake-password", self.versions)
                self.assertEqual(query.call_count, 1)

    def test_malformed_existing_count_fails_closed(self):
        for malformed in ([], ["not-a-count"], ["0", "1"], ["-1"]):
            with self.subTest(malformed=malformed), \
                 patch.object(p1, "db_sql", side_effect=[["t"], malformed]):
                with self.assertRaisesRegex(p1.RehearsalError, "CATALOG_COUNT_MALFORMED"):
                    p1.foundation_migration_baseline_count("fake-uri", "fake-password", self.versions)


if __name__ == "__main__":
    unittest.main()
