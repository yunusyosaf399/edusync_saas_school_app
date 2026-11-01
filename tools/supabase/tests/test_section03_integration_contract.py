"""Section 03 cross-domain source-contract regression checks.

These checks intentionally do not modify the DB02 G02 pinned SQL-suite registry,
database migrations, permission seeds or hosted state. They protect the D1
academic/Student handoff against accidental edits during parallel integration.
They do not replace disposable PostgreSQL or authenticated race acceptance.
"""
import json
import re
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[3]
DOMAIN = ROOT / "supabase" / "tests" / "domain"
MANIFEST = ROOT / "supabase" / "config" / "db02_g02_composition_manifest.json"
RUNNER = ROOT / "tools" / "supabase" / "domain_business_ci.py"


def sql_test(name: str) -> str:
    return (DOMAIN / name).read_text(encoding="utf-8")


class Section03CrossDomainContractTests(unittest.TestCase):
    def test_academic_offering_enforces_ancestry_and_archive(self):
        source = sql_test("33_academic_class_offering_lifecycle_authorization.sql")
        self.assertIn("app.d1_change_academic_offering(", source)
        self.assertIn("academic.offering.manage", source)
        for case in (
            "offering-unknown-class",
            "offering-unknown-campus",
            "offering-unknown-year",
            "offering-unknown-school",
            "offering-duplicate",
            "offering-new-archived",
            "offering-create",
        ):
            with self.subTest(case=case):
                self.assertIn(case, source)
        self.assertIn("ROLLBACK;", source)

    def test_capacity_preserves_revision_and_archived_guard(self):
        source = sql_test("36_academic_capacity_change_revision_authorization.sql")
        for case in (
            "academic.capacity.change",
            "app.d1_change_academic_capacity(",
            "capacity-archived-section",
            "capacity-section-a-stale",
            "capacity-offering-stale",
            "capacity-section-b-0",
            "supersedes_id",
            "command_receipt_id",
        ):
            with self.subTest(case=case):
                self.assertIn(case, source)
        self.assertTrue(source.rstrip().endswith("ROLLBACK;"))

    def test_initial_enrollment_requires_protected_roll_and_replay(self):
        source = sql_test("61_student_enrollment_place_p0_initial_roll.sql")
        for case in (
            "app.d1_place_student_enrollment(",
            "student.enrollment.place",
            "student-place-wrong-kind",
            "student-place-stale",
            "student-place-initial",
            "replay_enrollment_id",
            "replay_roll_allocation_id",
            "roll_allocator_states",
            "enrollment.created",
        ):
            with self.subTest(case=case):
                self.assertIn(case, source)
        self.assertIn("one retained roll allocation, no replay duplicate", source)
        self.assertTrue(source.rstrip().endswith("ROLLBACK;"))

    def test_exact_g02_suite_registry_is_not_silently_redefined(self):
        manifest = json.loads(MANIFEST.read_text(encoding="utf-8"))
        suites = manifest["business_suites"]
        expected = {
            "33_academic_class_offering_lifecycle_authorization.sql": 52,
            "36_academic_capacity_change_revision_authorization.sql": 85,
            "61_student_enrollment_place_p0_initial_roll.sql": 18,
        }
        self.assertEqual(len(suites), manifest["business_suite_count"] if "business_suite_count" in manifest else 112)
        self.assertEqual(len({name for name, _ in suites}), len(suites))
        for name, count in expected.items():
            with self.subTest(name=name):
                self.assertEqual(dict(suites)[name], count)
                source = sql_test(name)
                self.assertEqual(re.findall(r"(?mi)^\\s*SELECT\\s+plan\\((\\d+)\\);", source), [str(count)])
        self.assertEqual(manifest["draft_fragments"], 291)
        runner = RUNNER.read_text(encoding="utf-8")
        for name in expected:
            self.assertIn(name, runner)


if __name__ == "__main__":
    unittest.main()
