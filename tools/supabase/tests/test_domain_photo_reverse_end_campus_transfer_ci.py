"""Source-gate true protected reverse winner and Campus Transfer trial."""
from pathlib import Path
import inspect
import sys
import unittest

ROOT=Path(__file__).resolve().parents[3]
sys.path.insert(0,str(ROOT/"tools/supabase"))
import domain_photo_reverse_end_campus_transfer_ci as race
import domain_photo_postgres_native_intent_ci as native


class PhotoReverseEndCampusTransferTests(unittest.TestCase):
    def test_single_pg_precommit_pause_is_explicitly_test_only(self):
        source=inspect.getsource(native.NativePostgresPhotoIntentTrial.transition)
        self.assertIn("before_commit_test_hook=None",source)
        self.assertIn("not callable(before_commit_test_hook)",source)
        self.assertIn("before_commit_test_hook()",source)
        self.assertLess(source.index("self._authorized(cur)"),
                        source.index("FROM photo_pg_trial.intents WHERE token_digest="))
        self.assertLess(source.index("WHERE token_digest=%s AND status=%s RETURNING status"),
                        source.index("before_commit_test_hook()"))
        self.assertIn("with con:",source)
        self.assertIn("fail_before_commit",source)

    def test_new_student_is_genuinely_placed_via_public_p0(self):
        source=inspect.getsource(race._p0_new_student)
        self.assertIn("app.d1_place_student_enrollment(",source)
        self.assertIn("'INITIAL'",source)
        self.assertIn("CURRENT_DATE-20",source)
        self.assertIn("_source(psycopg,student)",source)
        self.assertNotIn("INSERT INTO app_private.enrollments",race.SETUP_SQL)
        self.assertNotIn("INSERT INTO app_private.roll_allocations",race.SETUP_SQL)
        self.assertNotIn("UPDATE app_private.enrollments",race.SETUP_SQL)
        self.assertIn("INSERT INTO app_private.student_status_transitions(",race.SETUP_SQL)
        self.assertIn("INSERT INTO app_private.people(",race.SETUP_SQL)
        self.assertIn("UPDATE app_private.permissions SET state='ENABLED'",race.SETUP_SQL)

    def test_genuine_source_and_distinct_campus_transfer_contract(self):
        sql=race.SETUP_SQL
        for x in ("INSERT INTO app.campuses(","INSERT INTO app_private.class_offerings(",
                  "INSERT INTO app_private.section_offerings(",
                  "INSERT INTO app_private.capacity_revisions(",
                  "scope_kind='ALL' AND resolver_key='DIRECT'",
                  "'student.enrollment.move'","'DIRECT'",
                  "'22222222-2222-4222-8222-222222222222'"):
            self.assertIn(x,sql)
        self.assertIn(race.CAMPUS_B,sql)
        self.assertIn(race.DEST_SECTION,sql)
        self.assertNotEqual(race.CAMPUS_B,race.CAMPUS)
        self.assertNotIn("GRANT SELECT ON app_private.",sql)
        self.assertNotIn("DISABLE ROW LEVEL SECURITY",sql)
        self.assertNotIn("GRANT EXECUTE ON FUNCTION app.",sql)
        self.assertNotIn("UPDATE app_private.assignment_permission_scopes SET revoked_at=NULL",sql)
        moved=inspect.getsource(race._transfer_first_stale_photo)
        self.assertIn("app.d1_move_student_enrollment(",moved)
        self.assertIn("'CAMPUS_TRANSFER'",moved)
        self.assertIn("CURRENT_DATE",moved)
        self.assertIn("_observe_end_blocked_consumers(psycopg,holder_pid)",moved)
        self.assertIn("_no_current_source(psycopg,student,CAMPUS_B)",moved)
        self.assertIn("TRANSFER_STALE_CONSUME_MUTATION",moved)
        self.assertIn("TRANSFER_STALE_FINALIZE_MUTATION",moved)
        self.assertNotIn("UPDATE app_private.enrollments",moved)
        frozen=(ROOT/"supabase/migrations/20260928000000_domain_package_01_effect26_05_enrollment_move_direct_submit.sql.draft").read_text()
        self.assertIn("CREATE FUNCTION app.d1_move_student_enrollment(",frozen)
        self.assertIn("'CAMPUS_TRANSFER'",frozen)

    def test_photo_first_genuine_end_blocked_then_committed(self):
        source=inspect.getsource(race._reverse_photo_first_end)
        for x in ("before_commit_test_hook=hold_precommit",
                  "photo_future.result(timeout=20)",
                  "end_future.result(timeout=20)",
                  "_observe_waiter(psycopg,END_WAIT,pid_holder[0])",
                  "app.d1_end_student_enrollment(",
                  "_no_current_source(psycopg,student,None)",
                  "FINALIZED_TRIAL", "release.set()"):
            self.assertIn(x,source)
        self.assertLess(source.index("_observe_waiter("),source.index("release.set()"))
        self.assertIn("pg_catalog.pg_blocking_pids(a.pid)",
                      inspect.getsource(race._observe_waiter))
        self.assertIn("NOT l.granted",inspect.getsource(race._observe_waiter))
        self.assertNotIn("UPDATE app_private.enrollments",source)

    def test_runner_is_after_existing_three_photo_markers_and_is_local(self):
        runner=(ROOT/"tools/supabase/domain_student_photo_real_pg_handoff_ci.py").read_text()
        self.assertLess(runner.index("run_native_pg_intent_trial("),
                        runner.index("D1_STUDENT_PHOTO_REAL_PG_HANDOFF_PASS"))
        self.assertLess(runner.index("run_photo_protected_enrollment_end_race("),
                        runner.index("run_photo_reverse_end_campus_transfer_races("))
        self.assertIn("D1_STUDENT_PHOTO_REVERSE_END_CAMPUS_TRANSFER_RACES_PASS",
                      inspect.getsource(race.run_photo_reverse_end_campus_transfer_races))
        with self.assertRaisesRegex(RuntimeError,"D1_PHOTO_P1_REVERSE_TRANSFER_DISPOSABLE_ONLY"):
            race.run_photo_reverse_end_campus_transfer_races(
                None,container="hosted",run_psql=None)


if __name__=="__main__":
    unittest.main()
