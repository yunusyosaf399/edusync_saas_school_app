"""Fail-closed source unit checks for the review-only physical candidate."""
import sys
import unittest
from pathlib import Path
sys.path.insert(0,str(Path(__file__).resolve().parents[1]))
import domain_profile_history_candidate_ci as history

ROOT = Path(__file__).resolve().parents[3]

class StudentProfileHistoryCandidateTests(unittest.TestCase):
    def test_quarantined_source(self):
        source = (ROOT / history.CANDIDATE).read_text(encoding="utf-8")
        history.validate_candidate_source(source,ROOT)
        self.assertEqual(history.CANDIDATE.parts[1],"proposals")

    def test_guards_reject_security_and_schema_drift(self):
        source = (ROOT / history.CANDIDATE).read_text(encoding="utf-8")
        changes = (
            source.replace("RESET ROLE;", "GRANT SELECT ON app_private.student_profile_revisions TO authenticated;\nRESET ROLE;"),
            source + "\nCOMMIT;\n",
            source.replace("FORCE ROW LEVEL SECURITY","DISABLE ROW LEVEL SECURITY"),
            source.replace("old_row_version > 0 AND new_row_version = old_row_version + 1","old_row_version > 0"),
        )
        for candidate in changes:
            with self.assertRaises(RuntimeError):
                history.validate_candidate_source(candidate,ROOT)

    def test_typed_trial_is_quarantined_and_no_public_grant(self):
        source = (ROOT / history.TYPED_TRIAL).read_text(encoding="utf-8")
        history.validate_typed_trial_source(source, ROOT)
        self.assertIn("SECURITY INVOKER",source)
        self.assertNotIn("SECURITY DEFINER",source)
        self.assertEqual(history.TYPED_TRIAL.parts[1], "proposals")
        self.assertIn("TYPED_TRIAL_ATOMIC_HISTORY_FAILED", history.TRIAL_SQL)
        self.assertIn("TYPED_TRIAL_CLEAR_VS_UNCHANGED_FAILED", history.TRIAL_SQL)
        self.assertIn("TYPED_TRIAL_FUNCTIONS_NOT_ROLLED_BACK", history.TYPED_CLEANUP)

    def test_typed_trial_source_guard_denies_unsafe_changes(self):
        source = (ROOT / history.TYPED_TRIAL).read_text(encoding="utf-8")
        for bad in (
            source + "\nCOMMIT;\n",
            source.replace("SECURITY INVOKER","SECURITY DEFINER"),
            source.replace("D1_TYPED_PROFILE_NO_OP","DISABLED_NO_OP"),
            source.replace("FOR UPDATE;",";"),
            source + "\nGRANT EXECUTE ON FUNCTION x TO authenticated;\n",
        ):
            with self.subTest(marker=bad[-32:]):
                with self.assertRaises(RuntimeError):
                    history.validate_typed_trial_source(bad, ROOT)

    def test_authenticated_preflight_source_is_quarantined(self):
        source=(ROOT/history.AUTH_PREFLIGHT).read_text(encoding="utf-8")
        history.validate_typed_auth_preflight_source(source,ROOT)
        self.assertIn("AUTH_PREFLIGHT",history.AUTH_PASS_MARKER)
        self.assertIn("TYPED_AUTH_PREFLIGHT_REVOKED_GRANT_ACCEPTED",history.AUTH_TRIAL_CHECKS)
        self.assertIn("TYPED_AUTH_PREFLIGHT_NOT_ROLLED_BACK",history.AUTH_CLEANUP)

    def test_authenticated_preflight_refuses_unsafe_sql(self):
        source=(ROOT/history.AUTH_PREFLIGHT).read_text(encoding="utf-8")
        for changed in (
            source+"\nCOMMIT;\n",
            source.replace("FOR UPDATE;",";"),
            source.replace("D1_TYPED_PREFLIGHT_DENIED","MISSING_AUTH_GUARD"),
            source.replace("REVOKE CREATE ON SCHEMA app FROM schoolos_student_executor;",""),
        ):
            with self.assertRaises(RuntimeError):
                history.validate_typed_auth_preflight_source(changed,ROOT)

    def test_authenticated_preflight_baseline_injection_exact(self):
        fixture=(ROOT/history.TYPED_FIXTURE).read_text(encoding="utf-8")
        baseline=(ROOT/history.AUTH_BASELINE).read_text(encoding="utf-8")
        sql=history.render_auth_trial_sql(
            baseline, fixture,
            (ROOT/history.CANDIDATE).read_text(encoding="utf-8"),
            (ROOT/history.TYPED_TRIAL).read_text(encoding="utf-8"),
            (ROOT/history.AUTH_PREFLIGHT).read_text(encoding="utf-8"),
            history.AUTH_TRIAL_CHECKS)
        self.assertEqual(sql.count("$typed_preflight_auth$"),2)
        self.assertIn("SELECT * FROM finish();",sql)
        self.assertTrue(sql.rstrip().endswith("ROLLBACK;"))
        self.assertEqual(sql.count("CREATE FUNCTION app.d1_student_profile_typed_preflight_trial"),1)
        self.assertNotIn(r"\ir fixtures/command_actor.sql",sql)

    def test_local_runner_always_rolls_back(self):
        source=(ROOT / history.CANDIDATE).read_text(encoding="utf-8")
        self.assertIn("HISTORY_PRIVILEGE_LEAK",history.PROBE)
        self.assertIn("HISTORY_IMPOSSIBLE_VERSION_ACCEPTED",history.PROBE)
        self.assertIn("HISTORY_CANDIDATE_NOT_ROLLED_BACK",history.CLEANUP_PROBE)
        self.assertNotIn("\nCOMMIT;",source)
        self.assertEqual(history.PASS_MARKER,"D1_STUDENT_PROFILE_HISTORY_CANDIDATE_PASS")

if __name__ == "__main__":
    unittest.main()
