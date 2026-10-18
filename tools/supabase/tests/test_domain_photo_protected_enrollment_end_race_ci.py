"""Fail-closed P1 real Enrollment END versus private photo intent CI guards."""
from pathlib import Path
import sys
import unittest

ROOT=Path(__file__).resolve().parents[3]
sys.path.insert(0,str(ROOT/"tools/supabase"))
import domain_photo_protected_enrollment_end_race_ci as trial


class PhotoProtectedEnrollmentEndRaceSourceTests(unittest.TestCase):
    def test_p1_genuine_frozen_public_rpc_and_exact_scope(self):
        import inspect
        src=inspect.getsource(trial.run_photo_protected_enrollment_end_race)
        for required in (
            "app.d1_end_student_enrollment(",
            "SET ROLE authenticated",
            "END_KEY",
            "_source_primary(psycopg)",
            "SELECT pg_catalog.pg_backend_pid()",
            "NativePostgresPhotoIntentTrial",
        ):
            self.assertIn(required,src)
        source_lookup=inspect.getsource(trial._source_primary)
        self.assertIn("SOURCE_PRIMARY_COUNT",source_lookup)
        self.assertIn("SOURCE_SECTION_CHANGED",source_lookup)
        self.assertIn("SOURCE_SECTION",source_lookup)
        self.assertNotIn("UPDATE app_private.enrollments",src)
        self.assertNotIn("INSERT INTO app_private.roll_allocations",src)
        self.assertIn("'student.enrollment.end'",trial.SETUP_SQL)
        self.assertIn("d1_route_mode",trial.SETUP_SQL)
        self.assertIn("'DIRECT'",trial.SETUP_SQL)
        self.assertIn("scope_kind='ALL'",trial.SETUP_SQL)
        self.assertIn("resolver_key='DIRECT'",trial.SETUP_SQL)
        self.assertIn("student.photo.submit",trial.SETUP_SQL)
        self.assertIn("eb000000-0000-4000-8000-000000000001",trial.SETUP_SQL)
        self.assertIn("eb000000-0000-4000-8000-000000000012",trial.SETUP_SQL)
        self.assertNotIn("revoked_at=NULL",trial.SETUP_SQL)
        self.assertNotIn("UPDATE app_private.students",trial.SETUP_SQL)
        self.assertNotIn("DISABLE ROW LEVEL SECURITY",trial.SETUP_SQL)

    def test_two_real_sessions_both_transitions_block_then_deny(self):
        import inspect
        source=inspect.getsource(trial.run_photo_protected_enrollment_end_race)
        wait=inspect.getsource(trial._observe_end_blocked_consumers)
        self.assertIn("ThreadPoolExecutor(max_workers=2)",source)
        self.assertIn('action="CONSUME"',source)
        self.assertIn('action="FINALIZE_TRIAL"',source)
        self.assertIn("_observe_end_blocked_consumers(psycopg,end_pid)",source)
        self.assertIn("end_con.commit()",source)
        self.assertIn("_denied(lambda f=fut:f.result(timeout=15))",source)
        self.assertLess(source.index("_observe_end_blocked_consumers("),
                        source.index("end_con.commit()"))
        self.assertIn("pg_catalog.pg_blocking_pids(a.pid)",wait)
        self.assertIn("NOT l.granted",wait)
        self.assertIn("('transactionid','tuple')",wait)
        self.assertIn("count(DISTINCT a.pid)",wait)
        self.assertIn("_check(active_count==0",inspect.getsource(trial._assert_ended))
        self.assertIn("STALE_FINALIZE_CHANGED_TOKEN",source)
        self.assertIn("STALE_CONSUME_CHANGED_TOKEN",source)
        self.assertIn("D1_STUDENT_PHOTO_PROTECTED_END_INTENT_RACE_PASS",source)

    def test_wired_after_existing_native_and_cross_db_regressions(self):
        src=(ROOT/"tools/supabase/domain_student_photo_real_pg_handoff_ci.py").read_text()
        self.assertLess(src.index("run_native_pg_intent_trial("),
                        src.index("D1_STUDENT_PHOTO_REAL_PG_HANDOFF_PASS"))
        self.assertLess(src.index("D1_STUDENT_PHOTO_REAL_PG_HANDOFF_PASS"),
                        src.index("run_photo_protected_enrollment_end_race("))
        self.assertLess(src.index("run_photo_protected_enrollment_end_race("),
                        src.index("D1C2A_PASS") if "D1C2A_PASS" in src else len(src))
        self.assertIn("run_real_postgres_photo_handoff(container, run_psql, ROOT)",
                      (ROOT/"tools/supabase/domain_local_ci.py").read_text())

    def test_exact_container_and_static_frozen_p1_signature(self):
        with self.assertRaisesRegex(RuntimeError,"D1_PHOTO_PROTECTED_END_DISPOSABLE_ONLY"):
            trial.run_photo_protected_enrollment_end_race(
                None,container="hosted",run_psql=None)
        frozen=(ROOT/"supabase/tests/domain/62_student_enrollment_end_p1_direct_history.sql").read_text()
        self.assertIn("SELECT * FROM app.d1_end_student_enrollment(",frozen)
        self.assertIn("CURRENT_DATE-20,CURRENT_DATE",frozen)
        self.assertIn("student.enrollment.end",frozen)
        self.assertEqual(trial.SOURCE_SECTION,"e4000000-0000-4000-8000-000000000045")


if __name__=="__main__":
    unittest.main()
