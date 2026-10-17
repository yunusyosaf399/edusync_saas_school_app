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

    def test_direct_authenticated_trial_quarantine(self):
        source=(ROOT/history.DIRECT_TRIAL).read_text(encoding="utf-8")
        history.validate_typed_direct_source(source,ROOT)
        self.assertIn("TYPED_DIRECT_CANONICAL_REPLAY_FAIL",history.DIRECT_TRIAL_TESTS)
        self.assertIn("TYPED_DIRECT_RESTRICTED_HISTORY_BINDING_FAIL",history.DIRECT_TRIAL_TESTS)
        self.assertIn("D1_TYPED_DIRECT_TRIAL_NOT_ROLLED_BACK",history.DIRECT_TRIAL_CLEANUP)
        self.assertEqual(history.DIRECT_TRIAL.parts[1],"proposals")

    def test_direct_guard_denies_active_or_unsafe_variants(self):
        source=(ROOT/history.DIRECT_TRIAL).read_text(encoding="utf-8")
        cases=[
            source+"\nCOMMIT;\n",
            source.replace("D1_TYPED_DIRECT_STALE","REMOVED_VERSION_PROTECTION"),
            source.replace("FOR UPDATE;",";"),
            source.replace("app_private.d1_profile_authorized(","true("),
            source.replace("app_private.d1_profile_receipt(","fake_receipt("),
            source.replace("REVOKE CREATE ON SCHEMA app_private,app FROM schoolos_student_executor;",""),
        ]
        for altered in cases:
            with self.subTest(kind=altered[-50:]):
                with self.assertRaises(RuntimeError):
                    history.validate_typed_direct_source(altered,ROOT)

    def test_direct_trial_uses_genuine_66_fixture_and_savepoint(self):
        src=history.render_auth_trial_sql(
            (ROOT/history.AUTH_BASELINE).read_text(encoding="utf-8"),
            (ROOT/history.TYPED_FIXTURE).read_text(encoding="utf-8"),
            (ROOT/history.CANDIDATE).read_text(encoding="utf-8"),
            (ROOT/history.TYPED_TRIAL).read_text(encoding="utf-8"),
            (ROOT/history.AUTH_PREFLIGHT).read_text(encoding="utf-8")+"\n"+
                (ROOT/history.DIRECT_TRIAL).read_text(encoding="utf-8"),
            history.DIRECT_TRIAL_TESTS)
        self.assertTrue(src.rstrip().endswith("ROLLBACK;"))
        self.assertIn("SAVEPOINT typed_direct_trial_boundary;",src)
        self.assertIn("ROLLBACK TO SAVEPOINT typed_direct_trial_boundary;",src)
        self.assertEqual(src.count("CREATE FUNCTION app.d1_student_profile_typed_direct_trial("),1)

    def test_approval_is_quarantined_and_uses_existing_review_engine(self):
        source=(ROOT/history.APPROVAL_TRIAL).read_text(encoding="utf-8")
        history.validate_typed_approval_source(source,ROOT)
        self.assertIn("app_private.d1_profile_submit(",source)
        self.assertIn("app.d1_apply_profile_request(",source)
        self.assertIn("D1_TYPED_APPROVAL_POSTIMAGE_MISMATCH",source)
        self.assertNotIn("CREATE FUNCTION app.d1_review_profile_request(",source)
        self.assertEqual(history.APPROVAL_TRIAL.parts[1],"proposals")

    def test_approval_source_guard_rejects_unsafe_variants(self):
        source=(ROOT/history.APPROVAL_TRIAL).read_text(encoding="utf-8")
        for candidate in (
            source+"\nCOMMIT;\n",
            source.replace("D1_TYPED_APPROVAL_POSTIMAGE_MISMATCH","DISABLED_POST_CHECK"),
            source.replace("app.d1_apply_profile_request(","unsafe_apply("),
            source.replace("REVOKE CREATE ON SCHEMA app FROM schoolos_workflow_executor;",""),
            source.replace("FOR UPDATE;",";"),
        ):
            with self.subTest(suffix=candidate[-35:]):
                with self.assertRaises(RuntimeError):
                    history.validate_typed_approval_source(candidate,ROOT)

    def test_approval_injection_preserves_original_p1_fixture_and_rollback(self):
        source=history.render_approval_trial(
            (ROOT/history.APPROVAL_BASELINE).read_text(encoding="utf-8"),
            (ROOT/history.TYPED_FIXTURE).read_text(encoding="utf-8"),
            (ROOT/history.CANDIDATE).read_text(encoding="utf-8"),
            (ROOT/history.TYPED_TRIAL).read_text(encoding="utf-8"),
            (ROOT/history.AUTH_PREFLIGHT).read_text(encoding="utf-8"),
            (ROOT/history.APPROVAL_TRIAL).read_text(encoding="utf-8"),
            (ROOT/history.APPROVAL_TEST).read_text(encoding="utf-8"))
        self.assertTrue(source.rstrip().endswith("ROLLBACK;"))
        self.assertIn("SAVEPOINT typed_approval_integration;",source)
        self.assertIn("ROLLBACK TO SAVEPOINT typed_approval_integration;",source)
        self.assertIn("SELECT * FROM finish();",source)
        self.assertEqual(source.count(
            "CREATE FUNCTION app.d1_apply_student_profile_typed_approval_trial("),1)
        self.assertEqual(source.count(history.APPROVAL_INSERT_ANCHOR),1)

    def test_typed_approval_intent_seal_isolated_and_linked(self):
        source=(ROOT/history.INTENT_SEAL_TRIAL).read_text(encoding="utf-8")
        history.validate_approval_intent_seal_source(source,ROOT)
        self.assertIn("D1_TYPED_APPROVAL_SEALED_INTENT_CONFLICT",source)
        self.assertIn("CREATE TRIGGER student_profile_approval_intent_seal_immutable",source)
        self.assertIn("app_private.d1_profile_submit(",source)
        self.assertIn("D1_TYPED_APPROVAL_SEAL_UNSEALED_KEY",source)
        self.assertIn("D1_STUDENT_PROFILE_APPROVAL_INTENT_SEAL_PASS",
                      history.INTENT_SEAL_PASS_MARKER)
        self.assertNotIn("CREATE OR REPLACE FUNCTION app.d1_review_profile_request(",source)

    def test_typed_approval_seal_security_source_guard(self):
        source=(ROOT/history.INTENT_SEAL_TRIAL).read_text(encoding="utf-8")
        for changed in (
            source+"\nCOMMIT;\n",
            source.replace("FORCE ROW LEVEL SECURITY","DISABLE ROW LEVEL SECURITY"),
            source.replace("D1_TYPED_APPROVAL_SEALED_INTENT_CONFLICT","DISABLED_CONFLICT"),
            source.replace("D1_TYPED_APPROVAL_SEAL_UNSEALED_KEY","UNSAFE_PRIOR_RECEIPT"),
            source.replace("REVOKE CREATE ON SCHEMA app_private FROM schoolos_workflow_executor;",""),
            source.replace("CREATE TRIGGER student_profile_approval_intent_seal_immutable","CREATE TRIGGER missing_immutability"),
        ):
            with self.subTest(variant=changed[-60:]):
                with self.assertRaises(RuntimeError):
                    history.validate_approval_intent_seal_source(changed,ROOT)

    def test_typed_approval_seal_injected_into_auth_review_apply(self):
        fixture=(ROOT/history.TYPED_FIXTURE).read_text(encoding="utf-8")
        baseline=(ROOT/history.APPROVAL_BASELINE).read_text(encoding="utf-8")
        checks=(ROOT/history.APPROVAL_TEST).read_text(encoding="utf-8")
        seal_checks=(ROOT/history.INTENT_SEAL_CHECKS).read_text(encoding="utf-8")
        self.assertEqual(checks.count("ROLLBACK TO SAVEPOINT typed_approval_integration;"),1)
        checks=checks.replace("ROLLBACK TO SAVEPOINT typed_approval_integration;",
            seal_checks+"\nROLLBACK TO SAVEPOINT typed_approval_integration;",1)
        sql=history.render_approval_trial(
            baseline,fixture,
            (ROOT/history.CANDIDATE).read_text(encoding="utf-8"),
            (ROOT/history.TYPED_TRIAL).read_text(encoding="utf-8"),
            (ROOT/history.AUTH_PREFLIGHT).read_text(encoding="utf-8"),
            (ROOT/history.APPROVAL_TRIAL).read_text(encoding="utf-8")+"\n"+
              (ROOT/history.INTENT_SEAL_TRIAL).read_text(encoding="utf-8"),
            checks)
        self.assertTrue(sql.rstrip().endswith("ROLLBACK;"))
        self.assertEqual(sql.count(
            "CREATE TABLE app_private.student_profile_approval_intent_seals ("),1)
        self.assertIn("TYPED_SEAL_DISTINCT_ACTIONS_ACCEPTED",sql)
        self.assertIn("D1_TYPED_APPROVAL_SEAL_PERMISSION_REVOKED",sql)
        self.assertIn("SELECT * FROM finish();",sql)
        self.assertIn("ROLLBACK TO SAVEPOINT typed_approval_integration;",sql)

    def test_student_photo_provenance_is_not_live_schema(self):
        proposal=(ROOT/history.PHOTO_PROVENANCE_TRIAL).read_text(encoding="utf-8")
        history.validate_photo_provenance_trial_source(proposal,ROOT)
        self.assertIn("D1_PHOTO_PROVENANCE_TRIAL_NOT_ROLLED_BACK",
                      history.PHOTO_PROVENANCE_CLEANUP)
        self.assertIn("f.state='AVAILABLE'",proposal)
        self.assertIn("b.student_id=p_student_id",proposal)
        self.assertIn("b.school_id=expected_school",proposal)
        self.assertNotIn("CREATE FUNCTION app.d1_change_student_profile(",proposal)

    def test_student_photo_provenance_guard_refuses_unsafe_sql(self):
        proposal=(ROOT/history.PHOTO_PROVENANCE_TRIAL).read_text(encoding="utf-8")
        for changed in (
            proposal+"\nCOMMIT;\n",
            proposal.replace("FORCE ROW LEVEL SECURITY","DISABLE ROW LEVEL SECURITY"),
            proposal.replace("b.student_id=p_student_id","true"),
            proposal.replace("f.state='AVAILABLE'","true"),
            proposal.replace("app_private.d1_profile_authorized(","wrong_photo_auth("),
            proposal.replace("REVOKE CREATE ON SCHEMA app_private FROM schoolos_student_executor;",""),
        ):
            with self.subTest(changed=changed[-35:]):
                with self.assertRaises(RuntimeError):
                    history.validate_photo_provenance_trial_source(changed,ROOT)

    def test_student_photo_provenance_acceptance_injected_in_66_savepoint(self):
        acceptance=(ROOT/history.PHOTO_PROVENANCE_ACCEPTANCE).read_text(encoding="utf-8")
        self.assertIn("D1_PHOTO_ELIGIBLE_COMMITTED_FILE_DENIED",acceptance)
        self.assertIn("D1_PHOTO_WRONG_PURPOSE_ACCEPTED",acceptance)
        self.assertIn("D1_PHOTO_UPLOADER_EVIDENCE_MISMATCH_ACCEPTED",acceptance)
        self.assertIn("D1_PHOTO_REVOKED_PERMISSION_ACCEPTED",acceptance)
        sql=history.render_auth_trial_sql(
            (ROOT/history.AUTH_BASELINE).read_text(encoding="utf-8"),
            (ROOT/history.TYPED_FIXTURE).read_text(encoding="utf-8"),
            (ROOT/history.CANDIDATE).read_text(encoding="utf-8"),
            (ROOT/history.TYPED_TRIAL).read_text(encoding="utf-8"),
            (ROOT/history.AUTH_PREFLIGHT).read_text(encoding="utf-8")+"\n"+
                (ROOT/history.PHOTO_PROVENANCE_TRIAL).read_text(encoding="utf-8"),
            acceptance)
        self.assertTrue(sql.rstrip().endswith("ROLLBACK;"))
        self.assertIn("SAVEPOINT photo_provenance_trial_savepoint;",sql)
        self.assertIn("ROLLBACK TO SAVEPOINT photo_provenance_trial_savepoint;",sql)
        self.assertEqual(sql.count("CREATE TABLE app_private.student_profile_photo_provenance_trial ("),1)

    def test_local_runner_always_rolls_back(self):
        source=(ROOT / history.CANDIDATE).read_text(encoding="utf-8")
        self.assertIn("HISTORY_PRIVILEGE_LEAK",history.PROBE)
        self.assertIn("HISTORY_IMPOSSIBLE_VERSION_ACCEPTED",history.PROBE)
        self.assertIn("HISTORY_CANDIDATE_NOT_ROLLED_BACK",history.CLEANUP_PROBE)
        self.assertNotIn("\nCOMMIT;",source)
        self.assertEqual(history.PASS_MARKER,"D1_STUDENT_PROFILE_HISTORY_CANDIDATE_PASS")

if __name__ == "__main__":
    unittest.main()
