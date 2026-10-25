"""DB01 + DB02 pinned non-activating integration preview source gates.

This intentionally does not claim protected DB02 policy-change or DB03/04
deployment; the disposable PostgreSQL runtime is the real behavior gate.
"""
import sys
import unittest
from pathlib import Path
sys.path.insert(0,str(Path(__file__).resolve().parents[1]))
from domain_business_ci import DOMAIN_TESTS
from domain_local_ci import EXPECTED_RUNTIME_METRICS,ROOT

class DB01DB02IntegrationPreviewTests(unittest.TestCase):
    def test_pinned_draft_function_inventory_and_zero_private_exposure(self):
        m=EXPECTED_RUNTIME_METRICS
        self.assertEqual((m["functions"],m["security_definers"],
                          m["app_functions"],m["private_functions"]),
                         (599,581,167,432))
        self.assertEqual(m["d1_tables"],34)
        self.assertEqual(m["rls_forced"],34)
        for key in ("authenticated_private_execute","anon_execute",
                    "service_role_execute","authenticated_table_dml",
                    "anon_table_dml","service_role_table_dml"):
            self.assertEqual(m[key],0,key)

    def test_every_named_db01_and_db02_suite_registered_once(self):
        filenames=[name for name,_ in DOMAIN_TESTS]
        self.assertEqual(len(filenames),len(set(filenames)))
        self.assertIn("92_db01_roll_correct_p1_apply.sql",filenames)
        self.assertIn("92_db02_atomic_policy_revision_transition.sql",filenames)
        self.assertIn("93_db02_atomic_roll_allocator_pools.sql",filenames)
        self.assertEqual(dict(DOMAIN_TESTS)["92_db01_roll_correct_p1_apply.sql"],117)
        self.assertEqual(dict(DOMAIN_TESTS)["93_db02_atomic_roll_allocator_pools.sql"],29)
        for name,plan in DOMAIN_TESTS:
            self.assertGreater(plan,0,name)
            self.assertTrue((ROOT/"supabase/tests/domain"/name).is_file(),name)
        self.assertEqual(sum(count for _,count in DOMAIN_TESTS),4280)

    def test_both_workstreams_appear_in_full_disposable_runner(self):
        driver=(ROOT/"tools/supabase/domain_local_ci.py").read_text()
        self.assertIn("run_db01_p1_complete_approve_reject_integration(",driver)
        self.assertIn("run_db01_p1_successive_roll_date_boundaries(",driver)
        self.assertIn("run_db01_p1_apply_vs_move_end_races(",driver)
        migrations=(ROOT/"supabase/migrations")
        db01=list(migrations.glob("*effect41_14_db01_checked_request_read.sql.draft"))
        db02=list(migrations.glob("*effect51_01_db02_atomic_policy_allocators.sql.draft"))
        self.assertEqual(len(db01),1)
        self.assertEqual(len(db02),1)
        self.assertLess(db01[0].name,db02[0].name)
        self.assertIn("D1C2A_PASS",driver)
