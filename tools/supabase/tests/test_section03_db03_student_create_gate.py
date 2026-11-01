"""Non-activating SC-01…SC-07 dependency gate for DB03 to D1 Student.create.

This test is intentionally local-source only: DB03 proposal files remain on
separate, unmerged owner branches, never implicitly installed by this gate.
"""
import json
import re
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[3]
PACKET = ROOT / "docs/database/section03_db03_student_create_handoff_gate_20261101.json"
AUDIT = ROOT / "docs/database/section03_db03_student_create_dependency_audit_20261101.md"
D1_DENIAL = ROOT / "supabase/tests/domain/65_remaining_student_commands_fail_closed.sql"
G02 = ROOT / "supabase/config/db02_g02_composition_manifest.json"


class StudentCreateHandoffReadinessGate(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.packet = json.loads(PACKET.read_text(encoding="utf-8"))

    def test_seven_distinct_explicitly_blocked_requirements(self):
        d = self.packet
        self.assertEqual(d["schema_version"], 1)
        self.assertEqual(d["scope"], "source_only_cross_owner_readiness")
        self.assertEqual(d["state"], "BLOCKED")
        self.assertEqual([g["id"] for g in d["gates"]],
                         ["SC-%02d" % n for n in range(1, 8)])
        self.assertTrue(all(g["status"] == "BLOCKED" and
                            g["requirement"] and g["evidence"] for g in d["gates"]))
        self.assertEqual(d["owner_integration_pr"], 168)
        self.assertEqual(d["db03_latest_forward_pr"], 203)

    def test_no_authority_or_finished_principal_handoff_implied(self):
        d = self.packet
        for flag in ("student_create_enabled", "release_approved",
                     "merge_to_main_authorized", "hosted_activation_authorized",
                     "principal_final_approval_available", "db03_can_finalize"):
            self.assertIs(d[flag], False, flag)
        self.assertEqual(d["db03_forward_ci_result"], "passed_inactive_draft_only")

    def test_current_fee_disposition_is_not_bank_clearance(self):
        d = self.packet
        self.assertEqual(d["fee_dispositions"],
                         ["SKIPPED", "MARKED_PAID", "UNPAID"])
        self.assertIs(d["fee_is_finance_clearance"], False)
        doc = AUDIT.read_text(encoding="utf-8")
        for marker in ("UNPAID", "MARKED_PAID", "Principal", "FAILED",
                       "single-use", "SC-07"):
            self.assertIn(marker, doc)

    def test_production_student_create_remains_inactive_in_d1_fixture(self):
        source = D1_DENIAL.read_text(encoding="utf-8")
        self.assertEqual(re.findall(r"(?mi)^\\s*SELECT\\s+plan\\((\\d+)\\);", source), ["38"])
        self.assertIn("WHERE code='student.create'),false", source)
        self.assertIn("student.create remains explicitly disabled at runtime", source)
        self.assertIn("student.create permission cannot issue a protected command", source)
        self.assertTrue(source.rstrip().endswith("ROLLBACK;"))

    def test_no_implicit_db03_test_registration_or_manifest_changes(self):
        manifest = json.loads(G02.read_text(encoding="utf-8"))
        self.assertEqual(manifest["draft_fragments"], 291)
        self.assertEqual(manifest["business_assertions"], 4315)
        suites = dict(manifest["business_suites"])
        self.assertEqual(len(suites), 113)
        self.assertEqual(suites["65_remaining_student_commands_fail_closed.sql"], 38)
        self.assertEqual(suites["94_db01_db02_retired_policy_cutover.sql"], 23)


if __name__ == "__main__":
    unittest.main()
