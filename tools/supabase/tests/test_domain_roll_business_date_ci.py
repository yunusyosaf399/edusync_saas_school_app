"""Regression boundaries for trusted School-date integration."""
import sys
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[3]
sys.path.insert(0,str(ROOT/'tools/supabase'))
import domain_roll_business_date_ci as trial
import domain_function_final_guard as final


class RollBusinessDateTests(unittest.TestCase):
    def test_hosted_target_fails_before_driver_import(self):
        with self.assertRaisesRegex(RuntimeError,'ROLL_DATE_DISPOSABLE_ONLY'):
            trial.run_roll_business_date('hosted',None)

    def test_no_caller_clock_fallback_or_mutable_timezone_grant(self):
        sql=(ROOT/'supabase/migrations/20260928000000_domain_package_01_effect40_01_school_local_roll_date.sql.draft').read_text()
        self.assertIn('captured_at:=pg_catalog.clock_timestamp()',sql)
        self.assertIn('pg_catalog.timezone(zone,captured_at)::date',sql)
        self.assertIn('pg_catalog.pg_timezone_names',sql)
        for disallowed in ('CURRENT_DATE','current_setting(', 'transaction_timestamp(', 'statement_timestamp(', 'UPDATE (timezone)', 'TO authenticated;'):
            self.assertNotIn(disallowed,sql)

    def test_exact_function_and_acl_inventory(self):
        errors,metrics,states=final.inspect(ROOT)
        self.assertEqual(errors,[])
        state=states['app_private.d1_roll_business_date']
        self.assertEqual(state.owner,'schoolos_academic_executor')
        self.assertTrue(state.security_definer)
        self.assertEqual(state.execute_roles,{'schoolos_student_executor','schoolos_workflow_executor','schoolos_read_executor'})

    def test_mutators_preserve_bodies_except_date_expression(self):
        path=ROOT/'supabase/migrations/20260928000000_domain_package_01_effect40_02_school_local_roll_consumers.sql.draft'
        sql=path.read_text()
        for source,name,before,after in (
            ('effect25_20_enrollment_place_effect_hardening','app_private.d1_enrollment_place_effect','p_effective_from>CURRENT_DATE','p_effective_from>app_private.d1_roll_business_date(c.school_id)'),
            ('effect37_02_db01_end_source_prelock','app_private.d1_enrollment_end_lock_context','src.effective_from>CURRENT_DATE','src.effective_from>app_private.d1_roll_business_date(path.school_id)'),
        ):
            old=(ROOT/f'supabase/migrations/20260928000000_domain_package_01_{source}.sql.draft').read_text()
            def body(text):
                start=text.index('CREATE OR REPLACE FUNCTION '+name+'(')
                end=text.index('END $body$;',start)+len('END $body$;')
                return text[start:end]
            self.assertEqual(body(old).replace(before,after),body(sql))

    def test_read_authorization_precedes_single_materialized_date(self):
        sql=(ROOT/'supabase/migrations/20260928000000_domain_package_01_effect40_02_school_local_roll_consumers.sql.draft').read_text().split('CREATE OR REPLACE FUNCTION app.d1_read_roll_policy')[1]
        self.assertIn('authorized AS MATERIALIZED',sql)
        self.assertIn('school_day AS MATERIALIZED',sql)
        self.assertEqual(sql.count('d1_roll_business_date('),1)
        self.assertLess(sql.index('d1_authorized('),sql.index('d1_roll_business_date('))

    def test_apply_receipt_requires_exact_approved_predecessor(self):
        sql=(ROOT/'supabase/migrations/20260928000000_domain_package_01_effect40_03_db01_apply_request_version.sql.draft').read_text()
        self.assertIn('rec.expected_request_version IS DISTINCT FROM req.row_version-1',sql)
        self.assertNotIn('rec.expected_request_version<1',sql)
        fixture=(ROOT/'supabase/tests/domain/79_db01_approval_application_receipt_guard.sql').read_text()
        self.assertIn('SAVEPOINT mismatched_apply_version',fixture)
        self.assertIn('q.row_version-1',fixture)
        self.assertIn('APPLY receipt naming version 1 cannot apply the APPROVED version 4',fixture)

    def test_apply_result_student_version_matches_approved_target(self):
        sql=(ROOT/'supabase/migrations/20260928000000_domain_package_01_effect40_03_db01_apply_request_version.sql.draft').read_text()
        self.assertIn("rec.result_summary->'student_version' IS DISTINCT FROM pg_catalog.to_jsonb(req.expected_target_version)",sql)
        fixture=(ROOT/'supabase/tests/domain/79_db01_approval_application_receipt_guard.sql').read_text()
        self.assertIn('SAVEPOINT mismatched_result_student_version',fixture)
        self.assertLess(fixture.index('SAVEPOINT mismatched_result_student_version'),fixture.index('no application exists before explicit effect'))
        self.assertIn('result Student version 999 cannot claim approved target version 1',fixture)

    def test_runtime_gate_precedes_final_pass(self):
        source=(ROOT/'tools/supabase/domain_local_ci.py').read_text()
        self.assertLess(source.index('run_roll_business_date(container,'),source.index('print("D1C2A_PASS'))


if __name__=='__main__':
    unittest.main()
