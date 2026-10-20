"""Fail-closed observer and local-only boundaries for the END lock proof."""
import sys
import unittest
from concurrent.futures import Future
from pathlib import Path
from unittest.mock import Mock, patch

ROOT = Path(__file__).resolve().parents[3]
sys.path.insert(0, str(ROOT/'tools/supabase'))
import domain_enrollment_end_lock_prefix_ci as trial


class EnrollmentEndPrefixTests(unittest.TestCase):
    def test_fixture_namespace_does_not_overlap_other_runtime_suites(self):
        prefix = trial.STUDENT.rsplit('-', 1)[0] + '-'
        own = ROOT/'tools/supabase/domain_enrollment_end_lock_prefix_ci.py'
        for path in (ROOT/'tools/supabase').glob('domain_*ci.py'):
            if path != own:
                self.assertNotIn(prefix, path.read_text(), str(path))

    def test_hosted_target_rejected_before_connecting(self):
        with self.assertRaisesRegex(RuntimeError, 'DISPOSABLE_CONTAINER_ONLY'):
            trial.run_enrollment_end_lock_prefix('hosted', None)

    def test_completed_worker_never_counts_as_contention(self):
        f = Future()
        f.set_result(None)
        with self.assertRaisesRegex(RuntimeError, 'WORKER_FINISHED_BEFORE_WAIT'):
            trial._observe(Mock(), 21, 22, f)

    def test_real_wait_binds_both_backend_ids(self):
        cursor = Mock()
        cursor.fetchone.return_value = (True,)
        trial._observe(cursor, 21, 22, Future())
        sql, params = cursor.execute.call_args.args
        self.assertEqual(params, (21, 22))
        self.assertIn('pg_catalog.pg_blocking_pids(a.pid)', sql)
        self.assertIn('NOT l.granted', sql)
        self.assertIn("a.wait_event_type='Lock'", sql)

    def test_unobserved_wait_fails_boundedly(self):
        cursor = Mock()
        cursor.fetchone.return_value = (False,)
        with patch.object(trial.time, 'monotonic', side_effect=[0, 0, 9]), patch.object(trial.time, 'sleep'):
            with self.assertRaisesRegex(RuntimeError, 'REAL_WAIT_NOT_OBSERVED'):
                trial._observe(cursor, 21, 22, Future())

    def test_lock_identifiers_are_closed_and_rows_parameterized(self):
        cursor = Mock()
        cursor.fetchone.return_value = ('row',)
        trial._lock(cursor, 'student', trial.STUDENT, nowait=True)
        sql, params = cursor.execute.call_args.args
        self.assertIn('FOR UPDATE NOWAIT', sql)
        self.assertNotIn(trial.STUDENT, sql)
        self.assertEqual(params, (trial.STUDENT,))
        with self.assertRaisesRegex(RuntimeError, 'INVALID_LOCK_KIND'):
            trial._lock(cursor, 'students; DROP SCHEMA app', trial.STUDENT)

    def test_missing_lock_row_cannot_pass(self):
        cursor = Mock()
        cursor.fetchone.return_value = None
        with self.assertRaisesRegex(RuntimeError, 'LOCK_ROW_MISSING'):
            trial._lock(cursor, 'school', trial.SCHOOL)

    def test_committed_fixture_has_no_fabricated_enrollment_or_roll(self):
        fixture = (ROOT/'supabase/tests/domain/fixtures/enrollment_end_lock_prefix.sql').read_text()
        for forbidden in ('INSERT INTO app_private.enrollments', 'INSERT INTO app_private.roll_allocations',
                          'DISABLE ROW LEVEL SECURITY', 'revoked_at=NULL'):
            self.assertNotIn(forbidden, fixture)
        runtime = (ROOT/'tools/supabase/domain_local_ci.py').read_text()
        self.assertLess(runtime.index('run_real_postgres_photo_handoff(container,'),
                        runtime.index('run_enrollment_end_lock_prefix(container,'))
        self.assertLess(runtime.index('run_enrollment_end_lock_prefix(container,'),
                        runtime.index('print("D1C2A_PASS'))


if __name__ == '__main__':
    unittest.main()
