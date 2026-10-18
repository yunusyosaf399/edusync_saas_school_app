"""Static fail-closed guards for disposable native PostgreSQL Photo intent gate."""
from pathlib import Path
import sys
import unittest

ROOT=Path(__file__).resolve().parents[3]
sys.path.insert(0,str(ROOT/"tools/supabase"))
import domain_photo_postgres_native_intent_ci as trial


class NativePostgresIntentTrialGuards(unittest.TestCase):
    def test_schema_strictly_quarantined_and_not_client_exposed(self):
        sql=trial.SETUP_SQL
        self.assertTrue(sql.lstrip().startswith("BEGIN;"))
        self.assertTrue(sql.rstrip().endswith("COMMIT;"))
        for needle in (
            "CREATE SCHEMA photo_pg_trial AUTHORIZATION schoolos_student_executor;",
            "REVOKE ALL ON SCHEMA photo_pg_trial FROM PUBLIC,anon,authenticated,service_role",
            "CREATE TABLE photo_pg_trial.intents",
            "token_digest bytea PRIMARY KEY",
            "CHECK",
            "status IN ('ISSUED','CONSUMED','FINALIZED_TRIAL','REVOKED')",
            "ALTER TABLE photo_pg_trial.intents ENABLE ROW LEVEL SECURITY",
            "ALTER TABLE photo_pg_trial.intents FORCE ROW LEVEL SECURITY",
            "FOR ALL TO schoolos_student_executor",
            "REVOKE ALL ON TABLE photo_pg_trial.intents FROM PUBLIC,anon,authenticated,service_role",
        ):
            with self.subTest(needle=needle):
                self.assertIn(needle,sql)
        self.assertNotIn("CREATE TABLE public.",sql)
        self.assertNotIn("CREATE TABLE app.",sql)
        self.assertNotIn("GRANT ALL",sql)
        self.assertNotIn("GRANT EXECUTE",sql)

    def test_atomic_authorization_and_student_lock_before_each_mutation(self):
        import inspect
        a=inspect.getsource(trial.NativePostgresPhotoIntentTrial._authorized)
        issue=inspect.getsource(trial.NativePostgresPhotoIntentTrial.issue)
        transition=inspect.getsource(trial.NativePostgresPhotoIntentTrial.transition)
        for text in (
            "pg_advisory_xact_lock_shared(71001,1)",
            "app_private.students",
            "FOR UPDATE",
            "app_private.current_principal_id()",
            "app_private.d1_student_photo_private_issue_resolver_trial",
        ):
            self.assertIn(text,a)
        for text in (issue,transition):
            self.assertIn("with closing(self._open()) as con:",text)
            self.assertIn("with con:",text)
            self.assertLess(text.index("self._authorized(cur)"),
                            text.index("cur.execute("))
            self.assertIn("fail_before_commit",text)
            self.assertIn("_deny()",text)
        self.assertIn("WHERE token_digest=%s FOR UPDATE",transition)
        self.assertIn("WHERE token_digest=%s AND status=%s RETURNING status",transition)
        self.assertIn("expires_at>pg_catalog.clock_timestamp()",transition)

    def test_opaque_digest_and_exact_transitions(self):
        import inspect
        self.assertEqual(len(trial._digest("0"*64)),32)
        with self.assertRaises(trial.NativeIntentDenied):
            trial._digest("0"*63)
        with self.assertRaises(trial.NativeIntentDenied):
            trial._digest("A"*64)
        with self.assertRaises(trial.NativeIntentDenied):
            trial._digest("literal-token")
        self.assertEqual(trial._canonical_uuid(
            "e4000000-0000-4000-8000-000000000001"),
            "e4000000-0000-4000-8000-000000000001")
        with self.assertRaises(trial.NativeIntentDenied):
            trial._canonical_uuid("E4000000-0000-4000-8000-000000000001")
        source=inspect.getsource(trial.NativePostgresPhotoIntentTrial.transition)
        self.assertIn('"CONSUME": ("ISSUED","CONSUMED")',source)
        self.assertIn('"FINALIZE_TRIAL": ("CONSUMED","FINALIZED_TRIAL")',source)
        self.assertIn('"REVOKE": ("ISSUED","REVOKED")',source)
        self.assertNotIn("AVAILABLE",source)
        self.assertNotIn("sqlite3",inspect.getsource(trial))

    def test_real_race_and_no_production_paths(self):
        import inspect
        source=inspect.getsource(trial.run_native_pg_intent_trial)
        for text in ("ThreadPoolExecutor","photo-native-pg-consumer",
                     "pg_catalog.pg_locks","NOT l.granted",
                     "RACE_STATE","CONSUME_ROLLBACK","FINALIZE_ROLLBACK",
                     "D1_STUDENT_PHOTO_NATIVE_PG_INTENT_PASS"):
            self.assertIn(text,source)
        with self.assertRaisesRegex(RuntimeError,"D1_PHOTO_NATIVE_PG_DISPOSABLE_ONLY"):
            trial.run_native_pg_intent_trial(
                None,container="hosted",run_psql=None,
                connect_actor=None,student_id="",campus_id="")
        runner=(ROOT/"tools/supabase/domain_student_photo_real_pg_handoff_ci.py").read_text()
        self.assertLess(runner.index("run_native_pg_intent_trial("),
                        runner.index("with tempfile.TemporaryDirectory("))
        self.assertIn("run_real_postgres_photo_handoff(container, run_psql, ROOT)",
            (ROOT/"tools/supabase/domain_local_ci.py").read_text())


if __name__=="__main__":
    unittest.main()
