"""Fail-closed source/injection checks for rollback-only real SQL actor resolver."""
from pathlib import Path
import sys
import unittest

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
import domain_profile_history_candidate_ci as history

ROOT = Path(__file__).resolve().parents[3]


class StudentPhotoRealActorResolverCandidateTests(unittest.TestCase):
    def source(self):
        return (ROOT / history.PHOTO_ACTOR_RESOLVER_TRIAL).read_text(encoding="utf-8")

    def acceptance(self):
        return (ROOT / history.PHOTO_ACTOR_RESOLVER_ACCEPTANCE).read_text(encoding="utf-8")

    def test_quarantined_resolver_checks_stored_primary_and_current_identity(self):
        source = self.source()
        history.validate_photo_actor_resolver_trial_source(source, ROOT)
        for required in (
            "app_private.current_principal_id()",
            "app_private.d1_lock_current_principal(actor)",
            "e.placement_kind='PRIMARY'",
            "e.placement_state='ACTIVE'",
            "OPEN state is enforced by d1_profile_authorized below",
            "resolved_campus IS DISTINCT FROM p_campus_id",
            "app_private.d1_profile_authorized(",
            "'student.photo.submit','STUDENT',p_student_id",
            "REVOKE ALL ON FUNCTION",
        ):
            self.assertIn(required, source)
        self.assertNotIn("principal_verified", source)
        self.assertNotIn("student_scope_verified", source)
        self.assertNotIn("CREATE FUNCTION app.d1_student_photo", source)

    def test_mutated_permission_placement_or_privacy_fails_closed(self):
        source = self.source()
        for changed in (
            source.replace("app_private.current_principal_id()",
                           "NULL::uuid"),
            source.replace("e.placement_kind='PRIMARY'", "true"),
            source.replace("e.placement_state='ACTIVE'", "true"),
            source.replace("resolved_campus IS DISTINCT FROM p_campus_id",
                           "false"),
            source.replace("app_private.d1_profile_authorized(",
                           "dummy_profile_check("),
            source.replace("'student.photo.submit','STUDENT',p_student_id",
                           "'student.profile.update','STUDENT',p_student_id"),
            source.replace("REVOKE CREATE ON SCHEMA app_private FROM schoolos_student_executor;", ""),
            source + "\nCOMMIT;\n",
            source + "\nGRANT EXECUTE ON FUNCTION app_private.bad TO authenticated;\n",
        ):
            with self.subTest(change=changed[-55:]), self.assertRaises(RuntimeError):
                history.validate_photo_actor_resolver_trial_source(changed, ROOT)

    def test_acceptance_has_real_campus_scope_positive_denial_and_rollback(self):
        acceptance = self.acceptance()
        for required in (
            "scope_kind='CAMPUS' AND resolver_key='DIRECT'",
            "'CAMPUS','DIRECT'",
            "D1_PHOTO_REAL_AUTHORIZED_PRIMARY_DENIED",
            "D1_PHOTO_REAL_CALLER_CAMPUS_FORGERY_ACCEPTED",
            "D1_PHOTO_REAL_OTHER_CAMPUS_ROLE_ACCEPTED",
            "D1_PHOTO_REAL_REVOKED_SUBMIT_GRANT_ACCEPTED",
            "D1_PHOTO_REAL_PROFILE_GRANT_REVOKED_ACCEPTED",
            "D1_PHOTO_REAL_RESOLVER_PUBLICLY_EXECUTABLE",
            "ROLLBACK TO SAVEPOINT student_photo_private_actor_scope_boundary;",
        ):
            self.assertIn(required, acceptance)
        self.assertNotIn("\nCOMMIT;", acceptance)
        self.assertNotIn("file_objects SET state='AVAILABLE'", acceptance)

    def test_inserted_in_real_suite_66_and_cleaned(self):
        original=(ROOT/history.AUTH_BASELINE).read_text(encoding="utf-8")
        fixture=(ROOT/history.TYPED_FIXTURE).read_text(encoding="utf-8")
        source=(ROOT/history.CANDIDATE).read_text(encoding="utf-8")
        typed=(ROOT/history.TYPED_TRIAL).read_text(encoding="utf-8")
        auth=(ROOT/history.AUTH_PREFLIGHT).read_text(encoding="utf-8")
        provenance=(ROOT/history.PHOTO_PROVENANCE_TRIAL).read_text(encoding="utf-8")
        sql=history.render_auth_trial_sql(
            original,fixture,source,typed,
            auth+"\n"+provenance+"\n"+self.source(),self.acceptance())
        self.assertEqual(sql.count("CREATE FUNCTION app_private.d1_student_photo_private_issue_resolver_trial("),1)
        self.assertIn("D1_PHOTO_REAL_OTHER_CAMPUS_ROLE_ACCEPTED", sql)
        self.assertIn("app.d1_place_student_enrollment", sql)
        self.assertTrue(sql.rstrip().endswith("ROLLBACK;"))
        self.assertIn("D1_PHOTO_ACTOR_RESOLVER_NOT_ROLLED_BACK",
                      history.PHOTO_ACTOR_RESOLVER_CLEANUP)
        self.assertIn("run_student_photo_private_actor_scope_trial(container, run_psql, source, typed, root)",
                      Path(history.__file__).read_text(encoding="utf-8"))

if __name__ == "__main__":
    unittest.main()
