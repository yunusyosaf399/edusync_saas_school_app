"""Fail-closed source review of genuine photo-first Campus MOVE/backend abort CI."""
from pathlib import Path
import inspect
import sys
import unittest

ROOT=Path(__file__).resolve().parents[3]
sys.path.insert(0,str(ROOT/"tools/supabase"))
import domain_photo_consume_first_transfer_backend_retry_ci as trial
import domain_photo_postgres_native_intent_ci as native


class PhotoConsumeFirstRecoveryCI(unittest.TestCase):
    def test_only_disposable_fixture_not_d1_sql_or_raw_enrollment(self):
        self.assertTrue(trial.SETUP_SQL.lstrip().startswith("BEGIN;"))
        self.assertTrue(trial.SETUP_SQL.rstrip().endswith("COMMIT;"))
        for required in ("INSERT INTO app_private.people(",
                         "INSERT INTO app_private.students(",
                         "INSERT INTO app_private.student_status_transitions("):
            self.assertIn(required,trial.SETUP_SQL)
        for denied in ("INSERT INTO app_private.enrollments",
                       "INSERT INTO app_private.roll_allocations",
                       "UPDATE app_private.enrollments",
                       "GRANT EXECUTE ON FUNCTION app.",
                       "DISABLE ROW LEVEL SECURITY",
                       "CREATE TABLE public."):
            self.assertNotIn(denied,trial.SETUP_SQL)
        self.assertNotEqual(trial.CONSUME_FIRST_STUDENT,trial.RECOVERY_STUDENT)
        self.assertNotEqual(trial.CAMPUS,trial.CAMPUS_B)
        with self.assertRaisesRegex(
                RuntimeError,"D1_PHOTO_CONSUME_FIRST_RECOVERY_DISPOSABLE_ONLY"):
            trial.run_photo_consume_first_transfer_backend_retry(
                None,container="hosted",run_psql=None)

    def test_real_p0_and_protected_move_winner_wait(self):
        source=inspect.getsource(trial._consume_first_then_transfer)
        for required in (
                "_p0_new_student(", "NativePostgresPhotoIntentTrial(",
                'action="CONSUME"',
                "before_commit_test_hook=_hold_after_consume_update",
                "_observe_waiter(psycopg,TRANSFER_WAITER,consumer_pid[0])",
                "app.d1_move_student_enrollment(",
                "'CAMPUS_TRANSFER'", "DEST_SECTION",
                "CURRENT_DATE","release.set()",
                'consuming.result(timeout=20)=="CONSUMED"',
                "_no_current_source(psycopg,student,CAMPUS_B)",
                "_denied(lambda:store.transition(token,action=\"FINALIZE_TRIAL\"))",
                "CONSUME_FIRST_STATE_CHANGED_AFTER_MOVE"):
            self.assertIn(required,source)
        self.assertLess(
            source.index("_observe_waiter(psycopg"),
            source.index("release.set()"))
        self.assertNotIn("UPDATE app_private.enrollments",source)
        self.assertNotIn("UPDATE app_private.roll_allocations",source)

    def test_real_pg_backend_termination_holds_after_write(self):
        source=inspect.getsource(trial._aborted_backend_step)
        for required in (
            "ThreadPoolExecutor(max_workers=1)",
            "entered.wait(12)", "release.set()",
            "pg_catalog.pg_terminate_backend(%s,10000)",
            "BACKEND_NOT_TERMINATED",
            "worker.issue(before_commit_test_hook=_pause_after_write)",
            "worker.transition(",
            "before_commit_test_hook=_pause_after_write",
            '_denied(lambda:future.result(timeout=18))',
        ):
            self.assertIn(required,source)
        self.assertLess(source.index("entered.wait(12)"),
                        source.index("pg_catalog.pg_terminate_backend"))
        self.assertLess(source.index("pg_catalog.pg_terminate_backend"),
                        source.index("release.set()"))
        native_issue=inspect.getsource(native.NativePostgresPhotoIntentTrial.issue)
        native_transition=inspect.getsource(native.NativePostgresPhotoIntentTrial.transition)
        for text in (native_issue,native_transition):
            self.assertIn("before_commit_test_hook=None",text)
            self.assertIn("not callable(before_commit_test_hook)",text)
            self.assertIn("before_commit_test_hook()",text)
            self.assertLess(text.index("self._authorized(cur)"),
                            text.index("before_commit_test_hook()"))
            self.assertIn("with con:",text)

    def test_retries_single_digest_denies_replays_and_wiring(self):
        source=inspect.getsource(trial._real_backend_abort_retries)
        for required in (
            '_aborted_backend_step(psycopg,student=student,step="ISSUE")',
            '_aborted_backend_step(psycopg,student=student,step="CONSUME",token=token)',
            'step="FINALIZE_TRIAL",token=token',
            "ABORTED_ISSUE_WAS_COMMITTED",
            "ABORTED_CONSUME_WAS_COMMITTED",
            "ABORTED_FINALIZE_WAS_COMMITTED",
            "ISSUE_RETRY_NOT_ONCE",
            "CONSUME_RETRY_FAILED",
            "FINALIZE_RETRY_FAILED",
            "FINALIZE_RETRY_DUPLICATED",
            "_denied(lambda:store.transition(token,action=\"CONSUME\"))",
            "_denied(lambda:store.transition(token,action=\"FINALIZE_TRIAL\"))",
        ):
            self.assertIn(required,source)
        self.assertIn("_ledger_count(psycopg,student)==1",source)
        runner=(ROOT/"tools/supabase/domain_student_photo_real_pg_handoff_ci.py").read_text()
        self.assertLess(
            runner.index("run_photo_reverse_end_campus_transfer_races("),
            runner.index("run_photo_consume_first_transfer_backend_retry("))
        self.assertIn(
            "D1_STUDENT_PHOTO_CONSUME_FIRST_TRANSFER_PASS",
            inspect.getsource(trial.run_photo_consume_first_transfer_backend_retry))
        self.assertIn(
            "D1_STUDENT_PHOTO_PG_BACKEND_ABORT_RETRY_PASS",
            inspect.getsource(trial.run_photo_consume_first_transfer_backend_retry))


if __name__=="__main__":
    unittest.main()
