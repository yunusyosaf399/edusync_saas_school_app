"""DB-01 prerequisite boundaries; no correction command acceptance."""
import re
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[3]
MIG = ROOT / "supabase/migrations"
PREFIX = "20260928000000_domain_package_01_"

class DB01PrerequisiteTests(unittest.TestCase):
    def test_allocator_only_removes_other_student_supersession_exemption(self):
        old = (MIG / (PREFIX + "effect35_15_enrollment_place_allocator_server_version.sql.draft")).read_text()
        new = (MIG / (PREFIX + "effect37_01_db01_allocator_history.sql.draft")).read_text()
        old = old[old.index("GRANT CREATE"):]
        new = new[new.index("GRANT CREATE"):]
        exclusion = "          AND NOT EXISTS (SELECT 1 FROM app_private.roll_allocations x WHERE x.supersedes_id=r.id)\n"
        self.assertEqual(old.count(exclusion), 1)
        self.assertEqual(new, old.replace(exclusion, ""))
        self.assertIn("x.student_id=p_student AND x.supersedes_id=r.id", new)

    def test_end_keeps_original_validation_after_prelock(self):
        old = (MIG / (PREFIX + "effect27_02_enrollment_end_context_effect.sql.draft")).read_text()
        old = old[old.index("GRANT CREATE"):old.index("GRANT CREATE ON SCHEMA app_private TO schoolos_evidence_writer;")]
        new = (MIG / (PREFIX + "effect37_02_db01_end_source_prelock.sql.draft")).read_text()
        new = new[new.index("GRANT CREATE"):]
        start = new.index("  -- The Roll history trigger")
        end = new.index("  SELECT * INTO s FROM app_private.students")
        self.assertEqual(new[:start] + new[end:], old)
        prefix = new[start:end]
        self.assertLess(prefix.index("d1_enrollment_place_lock_school"), prefix.index("ORDER BY rp.id FOR UPDATE"))
        self.assertLess(prefix.index("ORDER BY rp.id FOR UPDATE"), prefix.index("ORDER BY a.id FOR UPDATE OF a"))
        self.assertIn("r.policy_revision_id", prefix)
        self.assertNotIn("CURRENT_DATE", prefix)

    def test_registered_transactional_tests_and_no_activation(self):
        import sys
        sys.path.insert(0, str(ROOT / "tools/supabase"))
        from domain_business_ci import DOMAIN_TESTS
        self.assertEqual(sum(n for _, n in DOMAIN_TESTS[:74]), 3124)
        for filename, count in DOMAIN_TESTS[74:76]:
            sql = (ROOT / "supabase/tests/domain" / filename).read_text()
            self.assertIn("SELECT plan(" + str(count) + ");", sql)
            self.assertEqual(len(re.findall(r"SELECT (?:is|ok|throws_ok)\(", sql)), count)
            self.assertTrue(sql.rstrip().endswith("ROLLBACK;"))
            self.assertIn("SET CONSTRAINTS ALL IMMEDIATE;", sql)
            self.assertIn("app.d1_place_student_enrollment(", sql)
        for suffix in ("effect37_01_db01_allocator_history.sql.draft", "effect37_02_db01_end_source_prelock.sql.draft"):
            sql = (MIG / (PREFIX + suffix)).read_text()
            for forbidden in ("CREATE TABLE", "CREATE POLICY", "TO authenticated", "TO service_role", "DISABLE ROW LEVEL SECURITY", "SET enabled=true"):
                self.assertNotIn(forbidden, sql)

if __name__ == "__main__":
    unittest.main()
