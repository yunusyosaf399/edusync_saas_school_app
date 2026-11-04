"""MOVE lock-union regression scope, SQL preservation and safe harness bounds."""
import sys
import unittest
from pathlib import Path
from unittest.mock import Mock, MagicMock, patch
from types import SimpleNamespace

ROOT = Path(__file__).resolve().parents[3]
sys.path.insert(0, str(ROOT/'tools/supabase'))
import domain_enrollment_move_roll_union_ci as trial

MIG = ROOT/'supabase/migrations'
PREFIX = '20260928000000_domain_package_01_'

def read(suffix):
    return (MIG/(PREFIX+suffix+'.sql.draft')).read_text()


class EnrollmentMoveUnionTests(unittest.TestCase):
    def test_local_target_only(self):
        with self.assertRaisesRegex(RuntimeError, 'MOVE_DISPOSABLE_CONTAINER_ONLY'):
            trial.run_enrollment_move_roll_union('hosted', None)

    def test_new_fixture_namespace_is_disjoint(self):
        prefix = trial.STUDENT.rsplit('-',1)[0]+'-'
        own = ROOT/'tools/supabase/domain_enrollment_move_roll_union_ci.py'
        for path in (ROOT/'tools/supabase').glob('domain_*ci.py'):
            if path != own:
                self.assertNotIn(prefix, path.read_text(), str(path))

    def test_direct_and_submit_preserve_everything_except_prelock_placement(self):
        old = read('effect26_05_enrollment_move_direct_submit')
        old = old[old.index('GRANT CREATE ON SCHEMA app TO schoolos_student_executor;'):]
        old = old.replace('CREATE FUNCTION app.', 'CREATE OR REPLACE FUNCTION app.')
        for phase in ('',' request'):
            block = "  SELECT * INTO prelock FROM app_private.d1_enrollment_place_prelock_roll(p_destination_section_id,p_effective_from);\n" + f"  IF prelock.error_code IS NOT NULL THEN RAISE EXCEPTION 'D1 Enrollment move{phase} roll prelock denied: %',prelock.error_code; END IF;\n"
            self.assertEqual(old.count(block),1)
            old = old.replace(block,'',1)
            marker = f"  IF locked.error_code IS NOT NULL THEN RAISE EXCEPTION 'D1 Enrollment move{phase} denied: %',locked.error_code; END IF;\n"
            old = old.replace(marker,marker+block,1)
        new = read('effect39_02_enrollment_move_entry_order')
        self.assertEqual(new[new.index('GRANT CREATE'):],old)

    def test_apply_preserves_authority_and_effect_outside_preflight_order(self):
        old = read('effect26_09_enrollment_move_apply_hardening')
        old = old[old.index('GRANT CREATE ON SCHEMA app TO schoolos_workflow_executor;'):]
        old = old[:old.index('\nSET ROLE schoolos_schema_owner;')]
        block = "  IF invalidation_code IS NULL THEN SELECT * INTO prelock FROM app_private.d1_enrollment_place_prelock_roll(destination_section,effective_from);\n    IF prelock.error_code IS NOT NULL THEN invalidation_code:=prelock.error_code; END IF; END IF;\n"
        comparison = "    ELSIF locked.school_id IS DISTINCT FROM prelock.school_id OR locked.destination_class_offering_id IS DISTINCT FROM prelock.class_offering_id THEN invalidation_code:='D1_ENROLLMENT_MOVE_DESTINATION_STALE'; END IF;\n"
        self.assertEqual(old.count(block),1)
        old = old.replace(block,'').replace(comparison,'    END IF;\n',1)
        marker = '  IF invalidation_code IS NULL THEN\n    SELECT * INTO cap FROM app_private.d1_enrollment_move_capacity'
        replacement = "  IF invalidation_code IS NULL THEN SELECT * INTO prelock FROM app_private.d1_enrollment_place_prelock_roll(destination_section,effective_from);\n    IF prelock.error_code IS NOT NULL THEN invalidation_code:=prelock.error_code;\n"+comparison+"  END IF;\n"
        old = old.replace(marker,replacement+marker,1)
        new = read('effect39_03_enrollment_move_apply_order')
        self.assertEqual(new[new.index('GRANT CREATE'):],old)

    def test_union_locks_both_namespaces_before_base_student_lock(self):
        sql = read('effect39_01_enrollment_move_roll_union')
        self.assertLess(sql.index('d1_enrollment_place_lock_school'),sql.index('ORDER BY rp.id FOR UPDATE'))
        self.assertLess(sql.index('ORDER BY rp.id FOR UPDATE'),sql.index('ORDER BY a.id FOR UPDATE'))
        self.assertLess(sql.index('ORDER BY a.id FOR UPDATE'),sql.index('SELECT * INTO c FROM app_private.d1_enrollment_move_lock_context_base'))
        self.assertIn('p_effective_from<rp.effective_until',sql)
        self.assertIn('r.policy_revision_id',sql)
        self.assertIn('source_class ELSE NULL::uuid',sql)
        self.assertIn('destination_class ELSE NULL::uuid',sql)
        self.assertIn('pools.pool_class IS NOT DISTINCT FROM a.class_offering_id',sql)
        self.assertIn('d1_enrollment_move_kind_valid',sql)
        for forbidden in ('CREATE TABLE','CREATE POLICY','TO authenticated','TO service_role','DISABLE ROW LEVEL SECURITY','CURRENT_DATE'):
            self.assertNotIn(forbidden,sql)

    def test_fixture_cannot_fake_source_history_or_approval(self):
        sql = (ROOT/'supabase/tests/domain/fixtures/enrollment_move_roll_union.sql').read_text()
        for forbidden in ('INSERT INTO app_private.enrollments','INSERT INTO app_private.roll_allocations','INSERT INTO app_private.approval_requests','revoked_at=NULL'):
            self.assertNotIn(forbidden,sql)
        runtime = (ROOT/'tools/supabase/domain_local_ci.py').read_text()
        self.assertLess(runtime.index('run_enrollment_end_lock_prefix(container,'),runtime.index('run_enrollment_move_roll_union(container,'))
        self.assertLess(runtime.index('run_enrollment_move_roll_union(container,'),runtime.index('print("D1C2A_PASS'))

    def test_row_probe_rejects_missing_reverse_conflict(self):
        conn = MagicMock()
        driver = SimpleNamespace(errors=SimpleNamespace(LockNotAvailable=type("LockNotAvailable", (Exception,), {})))
        with patch.object(trial,'_local_connect',return_value=conn), patch.object(trial,'_lock'):
            with self.assertRaisesRegex(RuntimeError,'MOVE_EXPECTED_PREFIX_NOT_HELD'):
                trial._probe(driver,'school',trial.SCHOOL,held=True)
        conn.rollback.assert_called_once()
        conn.close.assert_called_once()


if __name__ == '__main__':
    unittest.main()
