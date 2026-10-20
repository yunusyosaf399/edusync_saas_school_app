"""Approval fixture and transactional lock-proof safety boundaries."""
import sys
import unittest
from pathlib import Path
from unittest.mock import Mock

ROOT = Path(__file__).resolve().parents[3]
sys.path.insert(0,str(ROOT/'tools/supabase'))
import domain_enrollment_move_approval_ci as trial


class MoveApprovalTests(unittest.TestCase):
    def test_only_named_internal_prelock_call_edge_is_added(self):
        path = ROOT/'supabase/migrations/20260928000000_domain_package_01_effect39_04_enrollment_move_workflow_prelock_acl.sql.draft'
        sql = path.read_text()
        body = '\n'.join(line for line in sql.splitlines() if not line.startswith('--'))
        self.assertEqual(body, 'SET ROLE schoolos_student_executor;\nGRANT EXECUTE ON FUNCTION app_private.d1_enrollment_place_prelock_roll(uuid,date)\n  TO schoolos_workflow_executor;\nRESET ROLE;')

    def test_reviewer_reads_are_projection_and_operation_bound(self):
        sql = (ROOT/'supabase/migrations/20260928000000_domain_package_01_effect39_05_enrollment_move_reviewer_projections.sql.draft').read_text()
        self.assertNotIn('SELECT q.*',sql)
        self.assertNotIn('SELECT t.*',sql)
        self.assertNotIn('GRANT SELECT',sql)
        self.assertNotIn('USING (true)',sql)
        self.assertEqual(sql.count('CREATE POLICY'),2)
        self.assertEqual(sql.count("WHERE q.id=p_request AND o.code='student.enrollment.move'"),2)
        self.assertIn('p.id<>req.requester_id AND p.person_id<>requester_person',sql)
        self.assertIn('reviewer_person=requester_person',sql)
        self.assertIn('d1_enrollment_move_authorized',sql)

    def test_application_replay_read_is_operation_and_column_bound(self):
        sql = (ROOT/'supabase/migrations/20260928000000_domain_package_01_effect39_06_enrollment_move_application_replay.sql.draft').read_text()
        self.assertIn('FOR SELECT TO schoolos_workflow_executor',sql)
        self.assertIn("o.code='student.enrollment.move'",sql)
        self.assertIn('GRANT SELECT (request_id,command_receipt_id,operation_id,result_ref)',sql)
        for forbidden in ('USING (true)','TO authenticated','TO anon','TO service_role','GRANT SELECT ON'):
            self.assertNotIn(forbidden,sql)

    def test_hosted_target_fails_before_driver_import(self):
        with self.assertRaisesRegex(RuntimeError,'MOVE_APPROVAL_DISPOSABLE_ONLY'):
            trial.run_enrollment_move_approval('hosted',None)

    def test_fixture_cannot_fabricate_approval_or_enrollment_success(self):
        fixture = (ROOT/'supabase/tests/domain/fixtures/enrollment_move_approval.sql').read_text()
        for table in ('enrollments','roll_allocations','approval_requests','approval_reviews','approval_applications','command_receipts'):
            self.assertNotIn('INSERT INTO app_private.'+table,fixture)
        self.assertIn('D1_REVIEWER_ROLE_SCOPE',fixture)
        self.assertNotIn('revoked_at=NULL',fixture)
        self.assertNotIn('DISABLE ROW LEVEL SECURITY',fixture)

    def test_fresh_fixture_namespace_disjoint_from_other_suites(self):
        prefix = trial.STUDENT.rsplit('-',1)[0]+'-'
        own = ROOT/'tools/supabase/domain_enrollment_move_approval_ci.py'
        for path in (ROOT/'tools/supabase').glob('domain_*ci.py'):
            if path != own:
                self.assertNotIn(prefix,path.read_text(),str(path))

    def test_approval_gate_is_required_before_final_runtime_pass(self):
        source = (ROOT/'tools/supabase/domain_local_ci.py').read_text()
        self.assertLess(source.index('run_enrollment_move_roll_union(container,'),source.index('run_enrollment_move_approval(container,'))
        self.assertLess(source.index('run_enrollment_move_approval(container,'),source.index('print("D1C2A_PASS'))

    def test_reviewer_setup_closes_connection_on_setup_failure(self):
        from unittest.mock import MagicMock,patch
        conn = MagicMock()
        conn.cursor.return_value.__enter__.return_value.execute.side_effect = RuntimeError('setup fails')
        with patch.object(trial,'_local_connect',return_value=conn):
            with self.assertRaisesRegex(RuntimeError,'setup fails'):
                trial._reviewer(Mock())
        conn.close.assert_called_once()


if __name__ == '__main__':
    unittest.main()
