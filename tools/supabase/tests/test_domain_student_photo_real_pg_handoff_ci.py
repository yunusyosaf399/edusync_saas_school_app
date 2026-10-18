"""Guard local-only true psycopg photo handoff and reused frozen P0 fixture.

Static checks run before the disposable stack starts. Actual PostgreSQL
transaction and lock race are tested by domain_local_ci after D1 suites.
"""
from pathlib import Path
import sys
import unittest

ROOT=Path(__file__).resolve().parents[3]
sys.path.insert(0,str(ROOT/"tools"/"supabase"))
import domain_student_photo_real_pg_handoff_ci as trial


class RealPostgresStudentPhotoHandoffGuards(unittest.TestCase):
    def test_uses_frozen_real_protected_primary_placement_fixture(self):
        sql=trial._fixture_sql(ROOT)
        self.assertIn("BEGIN;",sql)
        self.assertTrue(sql.rstrip().endswith("COMMIT;"))
        self.assertIn("app.d1_place_student_enrollment(",sql)
        self.assertIn("'INITIAL',CURRENT_DATE-20",sql)
        self.assertIn("CREATE FUNCTION app_private.d1_student_photo_private_issue_resolver_trial(",sql)
        self.assertIn("CAMPUS','DIRECT'",sql)
        self.assertIn("D1_PHOTO_REAL_PG_P0_PRIMARY_MISSING",sql)
        self.assertIn("'e4000000-0000-4000-8000-000000000001'",sql)
        self.assertIn("'e4000000-0000-4000-8000-000000000041'",sql)
        self.assertIn("'e6000000-0000-4000-8000-000000000012'",sql)
        self.assertIn("'e9000000-0000-4000-8000-000000000001'",sql)
        self.assertIn("'e9000000-0000-4000-8000-000000000002'",sql)
        self.assertIn("'photo-real-pg-94-authz'",sql)
        self.assertNotIn("'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa'",sql)
        self.assertNotIn("'ffffffff-ffff-4fff-8fff-ffffffffffff'",sql)
        self.assertIn("'22222222-2222-4222-8222-222222222222'",sql)
        self.assertNotIn("INSERT INTO app_private.school_profiles(",sql)
        self.assertNotIn("INSERT INTO app_private.roll_policy_revisions(",sql)
        self.assertNotIn("INSERT INTO app_private.roll_allocator_states(",sql)
        self.assertIn("'e8000000-0000-4000-8000-000000000001'",sql)
        self.assertIn("'PHOTO-REAL-PG-94-CAMPUS'",sql)
        self.assertIn("'photo-real-pg-94-place'",sql)
        self.assertNotIn("'b1000000-0000-4000-8000-000000000010'",sql)
        self.assertNotIn("'b6000000-0000-4000-8000-000000000011'",sql)
        self.assertNotIn("'d2000000-0000-4000-8000-000000000012'",sql)
        self.assertNotIn("\\ir ",sql)
        self.assertNotIn("\\gset",sql)
        self.assertNotIn("INSERT INTO app_private.enrollments(",sql)
        self.assertNotIn("INSERT INTO app_private.roll_allocations(",sql)
        self.assertEqual(sql.count("CREATE FUNCTION app_private.d1_student_photo_private_issue_resolver_trial("),1)

    def test_local_connection_is_not_remote_or_hosted(self):
        source=Path(trial.__file__).read_text()
        self.assertEqual(trial.PORT,54322)
        self.assertEqual(trial.CONTAINER,"supabase_db_saas_OS_school_app")
        self.assertIn('host="127.0.0.1"',source)
        self.assertIn('autocommit=False',source)
        self.assertIn('user="postgres", password="postgres"',source)
        self.assertIn('schoolos_student_executor',source)
        self.assertIn('app_private.current_principal_id()',source)
        self.assertNotIn('supabase.co',source)

    def test_actual_two_session_lock_wait_and_real_scope_revoke(self):
        source=Path(trial.__file__).read_text()
        for required in (
            "from concurrent.futures import ThreadPoolExecutor",
            "pg_catalog.pg_advisory_xact_lock(71001,1)",
            "NOT granted",
            "AND classid=71001",
            "app_private.assignment_permission_scopes",
            "revoked_at=pg_catalog.clock_timestamp()",
            "with ThreadPoolExecutor(max_workers=1)",
            "_observe_wait(psycopg)",
            "revoker.commit()",
            "PrivateIntentDenied",
            "D1_PHOTO_REAL_PG_REVOKED_INTENT_CONSUMED",
            "D1_STUDENT_PHOTO_REAL_PG_HANDOFF_PASS",
        ):
            self.assertIn(required,source)
        self.assertNotIn("FakeConnection",source)
        self.assertNotIn("FakePrivatePgSession",source)

    def test_local_runner_invokes_after_concurrency_before_shutdown(self):
        source=(ROOT/"tools/supabase/domain_local_ci.py").read_text()
        self.assertLess(source.index("run_concurrency_tests(container, run_psql)"),
                        source.index("run_real_postgres_photo_handoff(container, run_psql, ROOT)"))
        self.assertLess(source.index("run_real_postgres_photo_handoff(container, run_psql, ROOT)"),
                        source.index('print("D1C2A_PASS local-only runtime baseline'))
        self.assertIn('["supabase", "stop", "--project-id", EXPECTED_PROJECT_ID]',source)

    def test_never_run_outside_disposable_container(self):
        with self.assertRaisesRegex(RuntimeError,"D1_PHOTO_REAL_PG_DISPOSABLE_CONTAINER_ONLY"):
            trial.run_real_postgres_photo_handoff("hosted-or-other",None,ROOT)


if __name__=="__main__":
    unittest.main()
