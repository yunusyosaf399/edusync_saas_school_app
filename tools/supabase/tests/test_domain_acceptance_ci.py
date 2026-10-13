import re
import sys
import unittest
from tempfile import TemporaryDirectory
from pathlib import Path
sys.path.insert(0,str(Path(__file__).resolve().parents[1]))
import domain_concurrency_ci as races
import domain_business_ci as business
import domain_local_ci as local

class DomainAcceptanceToolsTests(unittest.TestCase):
    def test_image_pin_restores_existing_cache_bytes(self):
        with TemporaryDirectory() as directory:
            root = Path(directory)
            path = root / "supabase/.temp/postgres-version"
            path.parent.mkdir(parents=True)
            original = b"17.6.1.106\n"
            path.write_bytes(original)
            with local.local_postgres_image_pin(root):
                self.assertEqual(path.read_text(), "17.6.1.113")
            self.assertEqual(path.read_bytes(), original)

    def test_image_pin_removes_only_its_new_cache_file(self):
        with TemporaryDirectory() as directory:
            root = Path(directory)
            path = root / "supabase/.temp/postgres-version"
            with local.local_postgres_image_pin(root):
                self.assertTrue(path.is_file())
            self.assertFalse(path.exists())

    def test_image_pin_restores_cache_after_runtime_exception(self):
        with TemporaryDirectory() as directory:
            root = Path(directory)
            path = root / "supabase/.temp/postgres-version"
            path.parent.mkdir(parents=True)
            path.write_bytes(b"original")
            with self.assertRaisesRegex(RuntimeError, "stack failed"):
                with local.local_postgres_image_pin(root):
                    raise RuntimeError("stack failed")
            self.assertEqual(path.read_bytes(), b"original")

    def test_fixture_renderer_inlines_exactly_one_include(self):
        marker = chr(92)+"ir fixtures/command_actor.sql"
        self.assertEqual(business.render_fixture("BEGIN;"+marker+"ROLLBACK;","fixture"),"BEGIN;fixtureROLLBACK;")
        for source in ("BEGIN;ROLLBACK;",marker+marker):
            with self.assertRaisesRegex(RuntimeError,"FIXTURE_MARKER"):
                business.render_fixture(source,"fixture")

    def test_result_parser_ignores_synthetic_request_settings(self):
        value = races.parse_result('{"sub":"synthetic"}\n11111111-1111-4111-8111-111111111111\t1\n')
        self.assertEqual(value,("11111111-1111-4111-8111-111111111111",1))

    def test_result_parser_rejects_missing_and_multiple_results(self):
        for output in ("", "not a result", "11111111-1111-4111-8111-111111111111\t1\n"*2):
            with self.subTest(output=output):
                with self.assertRaisesRegex(RuntimeError,"D1_RACE_RESULT_SHAPE"):
                    races.parse_result(output)

    def test_race_runner_rejects_other_database_containers(self):
        with self.assertRaisesRegex(RuntimeError,"LOCAL_CONTAINER_MISMATCH"):
            races.worker_args("supabase_db_other_school")

    def test_intent_builder_rejects_nonfixture_inputs(self):
        for person,code,key in ((5,"EMP-ONE","one"),(1,"EMP';COMMIT;--","one"),(1,"EMP-ONE","one';--")):
            with self.subTest(person=person,code=code,key=key):
                with self.assertRaisesRegex(RuntimeError,"D1_RACE_INTENT_INVALID"):
                    races.command_sql(person,code,key)

    def test_worker_transaction_preserves_authenticated_role(self):
        sql = races.command_sql(1,"EMP-ONE","one",True)
        self.assertTrue(sql.startswith("BEGIN;"))
        self.assertTrue(sql.rstrip().endswith("COMMIT;"))
        self.assertIn("SET ROLE authenticated;",sql)
        self.assertIn("pg_sleep(2)",sql)

    def test_family_lineage_sql_only_allows_test_owned_source_and_actions(self):
        source = "64000000-0000-4000-8000-000000000099"
        for action in ("END", "CORRECT"):
            sql = races.family_lineage_setup_sql(action, source)
            self.assertTrue(sql.startswith("BEGIN;"))
            self.assertTrue(sql.rstrip().endswith("COMMIT;"))
            self.assertEqual(sql.count("app.d1_submit_family_principal_membership_change("), 2)
            self.assertEqual(sql.count("app.d1_review_family_principal_membership_change("), 2)
            self.assertIn("SET ROLE authenticated;", sql)
            self.assertIn("CURRENT_DATE-3", sql)
            self.assertIn("'"+action+"','"+source+"'::uuid", sql)
        for action, source in (
            ("ADD", "64000000-0000-4000-8000-000000000099"),
            ("CORRECT", "x';DROP TABLE app_private.families;--"),
            ("END", "00000000-0000-0000-0000-000000000000';--"),
        ):
            with self.subTest(action=action, source=source):
                with self.assertRaisesRegex(RuntimeError, "LINEAGE_RACE_INTENT_INVALID"):
                    races.family_lineage_setup_sql(action, source)

    def test_family_lineage_apply_worker_allows_only_known_race_keys(self):
        good = races.family_membership_apply_sql(
            "D1 simultaneous family CORRECT first",
            "family-race-correct-first-apply", True,
        )
        self.assertIn("SET ROLE authenticated;", good)
        self.assertIn("pg_sleep(3)", good)
        with self.assertRaisesRegex(RuntimeError, "D1_FAMILY_RACE_INTENT_INVALID"):
            races.family_membership_apply_sql(
                "D1 simultaneous family END first",
                "family-race-end-second-apply",
            )


    def test_family_relationship_end_worker_sql_rejects_unowned_cases(self):
        for pos in ("first", "second"):
            sql = races.family_relationship_end_apply_sql(pos, True)
            self.assertTrue(sql.startswith("BEGIN;"))
            self.assertTrue(sql.rstrip().endswith("COMMIT;"))
            self.assertIn("SET ROLE authenticated;", sql)
            self.assertIn("pg_sleep(3)", sql)
            self.assertIn("d1-relationship-end-" + pos, sql)
            self.assertIn("app.d1_apply_family_relationship_change(", sql)
        for pos, hold in (("third", False), ("first';--", False),
                          ("first", "true")):
            with self.subTest(pos=pos, hold=hold):
                with self.assertRaisesRegex(RuntimeError,
                    "D1_RELATIONSHIP_END_RACE_INTENT_INVALID"):
                    races.family_relationship_end_apply_sql(pos, hold)

    def test_family_relationship_end_uses_distinct_request_keys(self):
        first = races.family_relationship_end_apply_sql("first")
        second = races.family_relationship_end_apply_sql("second")
        self.assertIn("family-relationship-end-first-apply", first)
        self.assertIn("family-relationship-end-second-apply", second)
        self.assertNotEqual(first, second)


    def test_family_relationship_correct_worker_validates_intents(self):
        for pos in ("first", "second"):
            sql = races.family_relationship_correct_apply_sql(pos, True)
            self.assertTrue(sql.startswith("BEGIN;"))
            self.assertTrue(sql.rstrip().endswith("COMMIT;"))
            self.assertIn("SET ROLE authenticated;", sql)
            self.assertIn("pg_sleep(3)", sql)
            self.assertIn("d1-relationship-correct-" + pos, sql)
            self.assertIn("app.d1_apply_family_relationship_change(", sql)
        for pos, hold in (("third", False), ("first';--", False),
                          ("first", "true")):
            with self.subTest(pos=pos, hold=hold):
                with self.assertRaisesRegex(
                        RuntimeError, "D1_RELATIONSHIP_CORRECT_RACE_INTENT_INVALID"):
                    races.family_relationship_correct_apply_sql(pos, hold)

    def test_family_relationship_correct_workers_have_distinct_approved_intents(self):
        first = races.family_relationship_correct_apply_sql("first")
        second = races.family_relationship_correct_apply_sql("second")
        self.assertIn("family-relationship-correct-first-apply", first)
        self.assertIn("family-relationship-correct-second-apply", second)
        self.assertNotEqual(first, second)


    def test_family_relationship_cross_action_strict_action_pair(self):
        valid_source = "81000000-0000-4000-8000-000000000010"
        for phase, actions in (("a", ("CORRECT","END")), ("b", ("END","CORRECT"))):
            setup = races.family_relationship_cross_action_setup_sql(phase,valid_source)
            self.assertTrue(setup.startswith("BEGIN;"))
            self.assertTrue(setup.rstrip().endswith("COMMIT;"))
            self.assertEqual(setup.count("app.d1_submit_family_relationship_change("),2)
            self.assertEqual(setup.count("app.d1_review_family_relationship_change("),2)
            self.assertIn("SET ROLE authenticated;",setup)
            for position, action in (("first",actions[0]),("second",actions[1])):
                sql = races.family_relationship_cross_action_submit_sql(
                    phase,action,position,valid_source)
                self.assertIn("'" + action + "','" + valid_source + "'",sql)
                self.assertIn("D1 crossaction " + phase + " " + action,sql)
        for phase,action,position,source in (
            ("z","CORRECT","first",valid_source),
            ("a","END","first",valid_source),
            ("b","CORRECT","first",valid_source),
            ("a","CORRECT","third",valid_source),
            ("a","CORRECT","first","x';DROP TABLE app_private.families;--"),
        ):
            with self.subTest(phase=phase,action=action,position=position):
                with self.assertRaisesRegex(
                    RuntimeError,"D1_RELATIONSHIP_CROSS_ACTION_INTENT_INVALID"
                ):
                    races.family_relationship_cross_action_submit_sql(
                        phase,action,position,source)

    def test_family_relationship_cross_action_workers_are_independent(self):
        for phase, actions in (("a",("CORRECT","END")),("b",("END","CORRECT"))):
            first=races.family_relationship_cross_action_apply_sql(
                phase,actions[0],"first",True)
            second=races.family_relationship_cross_action_apply_sql(
                phase,actions[1],"second",False)
            self.assertIn("pg_sleep(3)",first)
            self.assertNotIn("pg_sleep(3)",second)
            self.assertIn("SET ROLE authenticated;",first)
            self.assertIn("SET ROLE authenticated;",second)
            self.assertNotEqual(first,second)
            self.assertIn("d1-rel-xa-"+phase+"-first",first)
            self.assertIn("d1-rel-xa-"+phase+"-second",second)
            with self.assertRaisesRegex(
                RuntimeError,"D1_RELATIONSHIP_CROSS_ACTION_INTENT_INVALID"
            ):
                races.family_relationship_cross_action_apply_sql(
                    phase,actions[1],"first")
            with self.assertRaisesRegex(
                RuntimeError,"D1_RELATIONSHIP_CROSS_ACTION_INTENT_INVALID"
            ):
                races.family_relationship_cross_action_apply_sql(
                    phase,actions[0],"first","true")


    def test_family_primary_replacement_workers_require_exact_test_positions(self):
        for position in ("first","second"):
            sql=races.family_primary_replacement_apply_sql(position,True)
            self.assertTrue(sql.startswith("BEGIN;"))
            self.assertTrue(sql.rstrip().endswith("COMMIT;"))
            self.assertIn("SET ROLE authenticated;",sql)
            self.assertIn("pg_sleep(3)",sql)
            self.assertIn("d1-primary-repl-"+position,sql)
            self.assertIn("app.d1_apply_family_relationship_change(",sql)
        for position,hold in (("third",False),("first';--",False),
                              ("first","true")):
            with self.subTest(position=position,hold=hold):
                with self.assertRaisesRegex(
                    RuntimeError,"D1_PRIMARY_REPLACEMENT_RACE_INTENT_INVALID"):
                    races.family_primary_replacement_apply_sql(position,hold)

    def test_family_primary_replacement_workers_have_distinct_typed_keys(self):
        first=races.family_primary_replacement_apply_sql("first")
        second=races.family_primary_replacement_apply_sql("second")
        self.assertIn("D1 primary replacement race END first",first)
        self.assertIn("D1 primary replacement race CORRECT second",second)
        self.assertIn("family-primary-replacement-end-apply",first)
        self.assertIn("family-primary-replacement-correct-apply",second)
        self.assertNotEqual(first,second)


    def test_family_replacement_stale_workers_require_known_positions(self):
        for pos in ("first","second"):
            sql=races.family_replacement_stale_apply_sql(pos,True)
            self.assertTrue(sql.startswith("BEGIN;"))
            self.assertTrue(sql.rstrip().endswith("COMMIT;"))
            self.assertIn("SET ROLE authenticated;",sql)
            self.assertIn("pg_sleep(3)",sql)
            self.assertIn("d1-repl-stale-"+pos,sql)
            self.assertIn("app.d1_apply_family_relationship_change(",sql)
        for pos,hold in (("third",False),("first';--",False),("first","true")):
            with self.subTest(pos=pos,hold=hold):
                with self.assertRaisesRegex(
                    RuntimeError,"D1_REPLACEMENT_STALE_INTENT_INVALID"):
                    races.family_replacement_stale_apply_sql(pos,hold)

    def test_family_replacement_stale_distinct_approved_actions(self):
        first=races.family_replacement_stale_apply_sql("first")
        second=races.family_replacement_stale_apply_sql("second")
        self.assertIn("D1 replacement stale race candidate END first",first)
        self.assertIn("D1 replacement stale race primary END second",second)
        self.assertIn("family-stale-replacement-candidate-end-apply",first)
        self.assertIn("family-stale-replacement-primary-end-apply",second)
        self.assertNotEqual(first,second)


    def test_family_replacement_reverse_worker_positions_are_bounded(self):
        for pos in ("primary","candidate"):
            sql=races.family_replacement_reverse_apply_sql(pos,True)
            self.assertTrue(sql.startswith("BEGIN;"))
            self.assertTrue(sql.rstrip().endswith("COMMIT;"))
            self.assertIn("SET ROLE authenticated;",sql)
            self.assertIn("pg_sleep(3)",sql)
            self.assertIn("d1-repl-reverse-"+pos,sql)
            self.assertIn("app.d1_apply_family_relationship_change(",sql)
        for pos,hold in (("first",False),("primary';--",False),("primary","yes")):
            with self.subTest(pos=pos,hold=hold):
                with self.assertRaisesRegex(RuntimeError,
                    "D1_REPLACEMENT_REVERSE_INTENT_INVALID"):
                    races.family_replacement_reverse_apply_sql(pos,hold)

    def test_family_replacement_reverse_starts_with_primary_winner(self):
        primary=races.family_replacement_reverse_apply_sql("primary",True)
        candidate=races.family_replacement_reverse_apply_sql("candidate",False)
        self.assertIn("D1 reverse replacement primary END first",primary)
        self.assertIn("D1 reverse replacement candidate END second",candidate)
        self.assertIn("family-reverse-replacement-primary-end-apply",primary)
        self.assertIn("family-reverse-replacement-candidate-end-apply",candidate)
        self.assertIn("pg_sleep(3)",primary)
        self.assertNotIn("pg_sleep(3)",candidate)
        self.assertNotEqual(primary,candidate)


    def test_family_reviewer_scope_stale_suite_is_registered(self):
        filename="21_family_relationship_p1_reviewer_scope_stale_apply.sql"
        self.assertIn((filename,36),[(name,total) for name,total in business.DOMAIN_TESTS])
        path=business.ROOT/"supabase/tests/domain"/filename
        sql=path.read_text(encoding="utf-8")
        self.assertIn("SELECT plan(36);",sql)
        self.assertEqual(sql.count(chr(92)+"ir fixtures/command_actor.sql"),1)
        self.assertTrue(sql.lstrip().startswith("--"))
        self.assertTrue(sql.rstrip().endswith("ROLLBACK;"))
        self.assertIn("D1_FAMILY_RELATIONSHIP_REVIEW_AUTHORITY_STALE",sql)
        self.assertIn("UPDATE app_private.assignment_permission_scopes",sql)
        self.assertIn("effect30-revoked-reviewer-scope-apply",sql)
        self.assertNotIn("UPDATE app_private.approval_requests SET state='APPROVED'",sql)
        # Private retained request state is asserted only after RESET ROLE;
        # authenticated users must never receive approval_requests table SELECT.
        for block in sql.split("SET ROLE authenticated;")[1:]:
            authenticated_segment=block.split("RESET ROLE;",1)[0]
            self.assertNotIn("FROM app_private.approval_requests",authenticated_segment)
            self.assertNotIn("FROM app_private.approval_reviews",authenticated_segment)
            self.assertNotIn("FROM app_private.approval_applications",authenticated_segment)



    def test_family_retired_policy_stale_apply_suite_is_registered(self):
        filename="22_family_relationship_p1_retired_policy_stale_apply.sql"
        self.assertIn((filename,43),[(name,total) for name,total in business.DOMAIN_TESTS])
        path=business.ROOT/"supabase/tests/domain"/filename
        sql=path.read_text(encoding="utf-8")
        self.assertIn("SELECT plan(43);",sql)
        self.assertEqual(sql.count(chr(92)+"ir fixtures/command_actor.sql"),1)
        self.assertTrue(sql.startswith("--"))
        self.assertTrue(sql.rstrip().endswith("ROLLBACK;"))
        self.assertIn("UPDATE app_private.approval_policy_versions SET state='RETIRED'",sql)
        self.assertIn("D1_FAMILY_RELATIONSHIP_POLICY_STALE",sql)
        self.assertIn("effect30-policy-retired-apply",sql)
        self.assertNotIn("UPDATE app_private.role_permission_grants SET revoked_at",sql)
        self.assertNotIn("UPDATE app_private.assignment_permission_scopes SET revoked_at",sql)
        self.assertNotIn("UPDATE app_private.approval_requests SET state='APPROVED'",sql)
        for block in sql.split("SET ROLE authenticated;")[1:]:
            authenticated_segment=block.split("RESET ROLE;",1)[0]
            for table in ("approval_requests","approval_reviews","approval_applications"):
                self.assertNotIn("FROM app_private."+table,authenticated_segment)



    def test_family_policy_replacement_stale_apply_suite_is_registered(self):
        filename="23_family_relationship_p1_policy_replacement_stale_apply.sql"
        self.assertIn((filename,65),[(name,total) for name,total in business.DOMAIN_TESTS])
        path=business.ROOT/"supabase/tests/domain"/filename
        sql=path.read_text(encoding="utf-8")
        self.assertIn("SELECT plan(65);",sql)
        self.assertEqual(sql.count(chr(92)+"ir fixtures/command_actor.sql"),1)
        self.assertTrue(sql.startswith("--"))
        self.assertTrue(sql.rstrip().endswith("ROLLBACK;"))
        self.assertIn("UPDATE app_private.approval_policy_versions SET state='RETIRED'",sql)
        self.assertIn("'d1-family-relationship-p1-approval',2,id,'APPROVAL'",sql)
        self.assertIn("D1_FAMILY_RELATIONSHIP_POLICY_STALE",sql)
        self.assertIn("effect30-policy-replaced-fresh-submit",sql)
        self.assertIn("effect30-policy-replaced-fresh-review",sql)
        self.assertNotIn("UPDATE app_private.role_permission_grants SET revoked_at",sql)
        self.assertNotIn("UPDATE app_private.assignment_permission_scopes SET revoked_at",sql)
        self.assertNotIn("UPDATE app_private.approval_requests SET state='APPROVED'",sql)
        for block in sql.split("SET ROLE authenticated;")[1:]:
            client=block.split("RESET ROLE;",1)[0]
            for table in ("approval_requests","approval_reviews","approval_applications"):
                self.assertNotIn("FROM app_private."+table,client)


    def test_family_p1_approved_policy_ambiguity_suite(self):
        filename="24_family_relationship_p1_approved_policy_ambiguity.sql"
        self.assertIn((filename,77),[(name,total) for name,total in business.DOMAIN_TESTS])
        sql=(business.ROOT/"supabase/tests/domain"/filename).read_text(encoding="utf-8")
        self.assertTrue(sql.startswith("--"))
        self.assertTrue(sql.rstrip().endswith("ROLLBACK;"))
        self.assertIn("SELECT plan(77);",sql)
        self.assertEqual(sql.count(chr(92)+"ir fixtures/command_actor.sql"),1)
        self.assertIn("D1_FAMILY_RELATIONSHIP_POLICY_STALE",sql)
        self.assertIn("effect30-policy-ambiguous-denied-submit",sql)
        self.assertIn("effect30-policy-ambiguous-fresh-submit",sql)
        self.assertIn("'d1-family-relationship-p1-approval',2,id,'APPROVAL'",sql)
        self.assertIn("UPDATE app_private.approval_policy_versions SET state='RETIRED'",sql)
        self.assertNotIn("UPDATE app_private.role_permission_grants SET revoked_at",sql)
        self.assertNotIn("UPDATE app_private.assignment_permission_scopes SET revoked_at",sql)
        self.assertNotIn("UPDATE app_private.approval_requests SET state='APPROVED'",sql)
        for block in sql.split("SET ROLE authenticated;")[1:]:
            client=block.split("RESET ROLE;",1)[0]
            for table in ("approval_requests","approval_reviews","approval_applications"):
                self.assertNotIn("FROM app_private."+table,client)



    def test_family_p1_approval_to_direct_route_stale_suite(self):
        filename="25_family_relationship_p1_approval_to_direct_route_stale_apply.sql"
        self.assertIn((filename,84),[(name,total) for name,total in business.DOMAIN_TESTS])
        sql=(business.ROOT/"supabase/tests/domain"/filename).read_text(encoding="utf-8")
        self.assertTrue(sql.startswith("--"))
        self.assertIn("SELECT plan(84);",sql)
        self.assertEqual(sql.count(chr(92)+"ir fixtures/command_actor.sql"),1)
        self.assertTrue(sql.rstrip().endswith("ROLLBACK;"))
        self.assertIn("'d1-family-relationship-p1-approval',2,id,'DIRECT'",sql)
        self.assertIn("D1_FAMILY_RELATIONSHIP_POLICY_STALE",sql)
        self.assertIn("D1 Family relationship policy selects direct command",sql)
        self.assertIn("D1 Family relationship requires approval request",sql)
        self.assertIn("effect30-route-direct-new-command",sql)
        self.assertIn("effect30-route-direct-apply",sql)
        self.assertIn("UPDATE app_private.approval_policy_versions SET state='RETIRED'",sql)
        self.assertNotIn("UPDATE app_private.role_permission_grants SET revoked_at",sql)
        self.assertNotIn("UPDATE app_private.assignment_permission_scopes SET revoked_at",sql)
        self.assertNotIn("UPDATE app_private.approval_requests SET state='APPROVED'",sql)
        for block in sql.split("SET ROLE authenticated;")[1:]:
            client=block.split("RESET ROLE;",1)[0]
            for table in ("approval_requests","approval_reviews","approval_applications"):
                self.assertNotIn("FROM app_private."+table,client)




    def test_family_p1_direct_to_approval_route_requires_new_review(self):
        filename="26_family_relationship_p1_direct_to_approval_route.sql"
        self.assertIn((filename,80),[(name,total) for name,total in business.DOMAIN_TESTS])
        sql=(business.ROOT/"supabase/tests/domain"/filename).read_text(encoding="utf-8")
        self.assertTrue(sql.startswith("--"))
        self.assertTrue(sql.rstrip().endswith("ROLLBACK;"))
        self.assertIn("SELECT plan(80);",sql)
        self.assertEqual(sql.count(chr(92)+"ir fixtures/command_actor.sql"),1)
        self.assertIn("'d1-family-relationship-p1-approval',1,id,'DIRECT'",sql)
        self.assertIn("'d1-family-relationship-p1-approval',2,id,'APPROVAL'",sql)
        self.assertIn("effect30-direct-to-p1-original-direct",sql)
        self.assertIn("effect30-direct-to-p1-new-submit",sql)
        self.assertIn("effect30-direct-to-p1-new-review",sql)
        self.assertIn("effect30-direct-to-p1-new-apply",sql)
        self.assertIn("D1 Family relationship requires approval request",sql)
        self.assertIn("D1 Family relationship policy selects direct command",sql)
        self.assertIn("same-key DIRECT replay works while policy still selects DIRECT",sql)
        self.assertIn("old successful DIRECT same-key API replay is denied under current P1 route",sql)
        self.assertNotIn("UPDATE app_private.role_permission_grants SET revoked_at",sql)
        self.assertNotIn("UPDATE app_private.assignment_permission_scopes SET revoked_at",sql)
        self.assertNotIn("UPDATE app_private.approval_requests SET state='APPROVED'",sql)
        for block in sql.split("SET ROLE authenticated;")[1:]:
            client=block.split("RESET ROLE;",1)[0]
            for table in ("approval_requests","approval_reviews","approval_applications"):
                self.assertNotIn("FROM app_private."+table,client)



    def test_family_portal_current_checked_read_and_revocation_suite(self):
        filename="27_family_portal_checked_current_read_revocation.sql"
        self.assertIn((filename,69),[(name,total) for name,total in business.DOMAIN_TESTS])
        sql=(business.ROOT/"supabase/tests/domain"/filename).read_text(encoding="utf-8")
        self.assertTrue(sql.startswith("--"))
        self.assertIn("SELECT plan(69);",sql)
        self.assertEqual(sql.count(chr(92)+"ir fixtures/command_actor.sql"),1)
        self.assertTrue(sql.rstrip().endswith("ROLLBACK;"))
        for rpc in ("d1_read_family_summary_for_student",
                    "d1_read_family_relationships_for_student",
                    "d1_read_family_relationship_history",
                    "d1_read_student_restricted_identity"):
            self.assertIn("app."+rpc,sql)
        self.assertIn("effect-family-portal-read-revoke",sql)
        self.assertIn("jsonb_object_keys(to_jsonb(summary))",sql)
        self.assertIn("jsonb_object_keys(to_jsonb(rel))",sql)
        self.assertIn("SAVEPOINT ended_family_membership_read;",sql)
        self.assertIn("ROLLBACK TO SAVEPOINT ended_family_membership_read;",sql)
        self.assertIn("UPDATE app_private.role_permission_grants SET revoked_at",sql)
        self.assertIn("D1_FAMILY_CHILD",sql)
        self.assertNotIn("GRANT SELECT ON app_private",sql)
        for block in sql.split("SET ROLE authenticated;")[1:]:
            client=block.split("RESET ROLE;",1)[0]
            for table in ("students","family_student_access","family_relationships",
                          "approval_requests","approval_reviews","approval_applications"):
                self.assertNotIn("FROM app_private."+table+" WHERE",client)


    def test_family_student_roster_profile_permission_and_disclosure(self):
        filename="28_family_portal_student_roster_profile_disclosure.sql"
        self.assertIn((filename,67),[(name,total) for name,total in business.DOMAIN_TESTS])
        sql=(business.ROOT/"supabase/tests/domain"/filename).read_text(encoding="utf-8")
        self.assertTrue(sql.rstrip().endswith("ROLLBACK;"))
        self.assertEqual(sql.count(chr(92)+"ir fixtures/command_actor.sql"),1)
        self.assertIn("SELECT plan(67);",sql)
        self.assertIn("INSERT INTO app_private.enrollments(",sql)
        self.assertIn("INSERT INTO app_private.roll_allocations(",sql)
        for key in ("student.roster.view","student.profile.view","D1_FAMILY_CHILD",
                    "profile_grant_revoked","roster_grant_revoked",
                    "effect-family-portal-student-profile-revoke"):
            self.assertIn(key,sql)
        self.assertNotIn("GRANT SELECT ON app_private",sql)
        for block in sql.split("SET ROLE authenticated;")[1:]:
            client=block.split("RESET ROLE;",1)[0]
            for table in ("students","family_student_access","family_relationships",
                          "approval_requests","approval_reviews","approval_applications"):
                self.assertNotIn("FROM app_private."+table+" WHERE",client)



    def test_family_emergency_contact_current_checked_read_disclosure_and_revoke(self):
        filename="29_family_portal_emergency_contact_current_checked_read.sql"
        self.assertIn((filename,77),[(name,total) for name,total in business.DOMAIN_TESTS])
        sql=(business.ROOT/"supabase/tests/domain"/filename).read_text(encoding="utf-8")
        self.assertTrue(sql.startswith("--"))
        self.assertIn("SELECT plan(77);",sql)
        self.assertEqual(sql.count(chr(92)+"ir fixtures/command_actor.sql"),1)
        self.assertTrue(sql.rstrip().endswith("ROLLBACK;"))
        for fragment in ("app.d1_read_student_emergency_contacts",
                         "app.d1_read_student_emergency_contact_history",
                         "student.emergency_contact.view",
                         "D1_FAMILY_CHILD",
                         "INSERT INTO app_private.student_emergency_contacts(",
                         "end_one_current_contact",
                         "emergency_view_grant_revoked",
                         "emergency_view_scope_revoked",
                         "current_family_membership_ended",
                         "effect-family-portal-emergency-contacts-revoke",
                         "jsonb_object_keys(to_jsonb(c))"):
            self.assertIn(fragment,sql)
        self.assertNotIn("GRANT SELECT ON app_private",sql)
        for block in sql.split("SET ROLE authenticated;")[1:]:
            client=block.split("RESET ROLE;",1)[0]
            for table in ("students","student_emergency_contacts","student_identity_details",
                          "family_student_access","family_relationships",
                          "approval_requests","approval_reviews","approval_applications"):
                self.assertNotIn("FROM app_private."+table+" WHERE",client)



    def test_family_history_alternative_basis_requires_current_child_scope(self):
        filename="30_family_portal_historical_relationship_alternate_basis.sql"
        self.assertIn((filename,78),[(name,total) for name,total in business.DOMAIN_TESTS])
        sql=(business.ROOT/"supabase/tests/domain"/filename).read_text(encoding="utf-8")
        self.assertTrue(sql.startswith("--"))
        self.assertIn("SELECT plan(78);",sql)
        self.assertEqual(sql.count(chr(92)+"ir fixtures/command_actor.sql"),1)
        self.assertTrue(sql.rstrip().endswith("ROLLBACK;"))
        for fragment in ("app.d1_read_family_relationship_history",
                         "app.d1_read_family_relationships_for_student",
                         "app.d1_read_family_admin_relationship_history",
                         "family.relationship_history.view","family.relationship.view",
                         "D1_FAMILY_CHILD","effect30-bases-first-end",
                         "effect30-bases-final-end","end_family_membership_history",
                         "revoke_history_permission_only","revoke_current_permission_only",
                         "Other Family confidential Guardian",
                         "INSERT INTO app_private.enrollments("):
            self.assertIn(fragment,sql)
        self.assertIn("false,p.id,p.family_safe",sql)
        self.assertIn("both independent ended Family A relationship rows are retained",sql)
        self.assertNotIn("GRANT SELECT ON app_private",sql)
        for block in sql.split("SET ROLE authenticated;")[1:]:
            client=block.split("RESET ROLE;",1)[0]
            for table in ("students","family_relationships","family_student_access",
                          "approval_requests","approval_reviews","approval_applications"):
                self.assertNotIn("FROM app_private."+table+" WHERE",client)



    def test_two_distinct_family_principals_read_and_revoke_isolation(self):
        filename="31_family_portal_two_family_child_access_isolation.sql"
        self.assertIn((filename,81),[(name,total) for name,total in business.DOMAIN_TESTS])
        sql=(business.ROOT/"supabase/tests/domain"/filename).read_text(encoding="utf-8")
        self.assertTrue(sql.startswith("--"))
        self.assertIn("SELECT plan(81);",sql)
        self.assertEqual(sql.count(chr(92)+"ir fixtures/command_actor.sql"),1)
        self.assertTrue(sql.rstrip().endswith("ROLLBACK;"))
        for fragment in ("foundation-own-002@example.invalid",
                         "second_family_subject",
                         "effect30-two-family-b-relationship-add",
                         "effect32-two-family-b-child-add",
                         "effect32-two-family-a-revoke",
                         "effect30-two-family-b-final-end",
                         "revoke_family_b_relationship_view",
                         "family.summary.view","family.relationship.view",
                         "family.relationship_history.view",
                         "D1_FAMILY_CHILD",
                         "app.d1_read_family_summary_for_student",
                         "app.d1_read_family_relationship_history"):
            self.assertIn(fragment,sql)
        self.assertIn("permission_family_safe,valid_from",sql)
        self.assertNotIn("GRANT SELECT ON app_private",sql)
        for block in sql.split("SET ROLE authenticated;")[1:]:
            client=block.split("RESET ROLE;",1)[0]
            for table in ("students","family_relationships","family_student_access",
                          "approval_requests","approval_reviews","approval_applications"):
                self.assertNotIn("FROM app_private."+table+" WHERE",client)



    def test_two_family_cross_operation_lock_race_is_true_concurrent_runtime(self):
        fixture=(business.ROOT/"supabase/tests/domain/fixtures/"
                 "family_cross_operation_race_setup.sql").read_text(encoding="utf-8")
        runner=(business.ROOT/"tools/supabase/domain_cross_family_race_ci.py").read_text(
            encoding="utf-8")
        concurrency=(business.ROOT/"tools/supabase/domain_concurrency_ci.py").read_text(
            encoding="utf-8")
        for fragment in ("foundation-family-001@example.invalid",
                         "foundation-own-002@example.invalid",
                         "family.summary.view","family.relationship.view",
                         "family.relationship_history.view","D1_FAMILY_CHILD",
                         "family.child_access.change","family.relationship.change",
                         "d1-cross-family-race-direct-child",
                         "d1-cross-family-race-direct-relationship",
                         "SET ROLE schoolos_schema_owner"):
            self.assertIn(fragment,fixture)
        self.assertNotIn("GRANT SELECT ON app_private",fixture)
        for fragment in ("pg_blocking_pids","transactionid","tuple",
                         "wait_event_type='Lock'","_probe_worker",
                         "subprocess.Popen","foundation-rbac-001@example.invalid",
                         "foundation-test-001@example.invalid",
                         "D1 Family relationship target version changed",
                         "d1-cross-family-a-revoke",
                         "d1-cross-family-b-end-stale",
                         "d1-cross-family-b-end-refreshed",
                         "D1_CROSS_FAMILY_OPERATION_RACE_PASS"):
            self.assertIn(fragment,runner)
        self.assertIn("from domain_cross_family_race_ci import run_cross_family_race",concurrency)
        self.assertIn("run_cross_family_race(container, execute_sql)",concurrency)
        self.assertLess(concurrency.index("D1_FAMILY_REPLACEMENT_REVERSE_RACE_PASS"),
                        concurrency.index("run_cross_family_race(container, execute_sql)"))
        self.assertNotIn("supabase db push",runner)
        self.assertNotIn("service_role",runner)



    def test_cross_family_reverse_end_wins_actual_lock_race_and_read_isolation(self):
        fixture=(business.ROOT/"supabase/tests/domain/fixtures/"
                 "family_cross_operation_reverse_race_setup.sql").read_text(
                    encoding="utf-8")
        runner=(business.ROOT/"tools/supabase/domain_cross_family_reverse_race_ci.py"
                ).read_text(encoding="utf-8")
        concurrency=(business.ROOT/"tools/supabase/domain_concurrency_ci.py"
                     ).read_text(encoding="utf-8")
        for item in ("96000000-0000-4000-8000-000000000002",
                     "96000000-0000-4000-8000-000000000003",
                     "96000000-0000-4000-8000-000000000004",
                     "96000000-0000-4000-8000-000000000005",
                     "96000000-0000-4000-8000-000000000006",
                     "family_relationships","family_student_access",
                     "schoolos_schema_owner"):
            self.assertIn(item,fixture)
        self.assertNotIn("GRANT SELECT ON app_private",fixture)
        self.assertNotIn("COMMIT;",fixture)
        self.assertIn("foundation-rbac-001@example.invalid",fixture)
        self.assertIn("request.jwt.claim.sub",fixture)
        self.assertIn("request.jwt.claims",fixture)
        self.assertIn("66666666-6666-4666-8666-666666666666",fixture)
        self.assertLess(fixture.index("request.jwt.claims"),
                        fixture.index("SET ROLE schoolos_schema_owner;"))
        for item in ("pg_blocking_pids", "wait_event_type='Lock'",
                     "transactionid","tuple","subprocess.Popen",
                     "foundation-test-001@example.invalid",
                     "foundation-rbac-001@example.invalid",
                     "foundation-family-001@example.invalid",
                     "foundation-own-002@example.invalid",
                     "D1 Family child access target version changed",
                     "d1-cross-reverse-b-end-winner",
                     "d1-cross-reverse-a-revoke-stale",
                     "d1-cross-reverse-a-revoke-refreshed",
                     "D1_CROSS_FAMILY_REVERSE_RACE_PASS",
                     "d1_read_family_summary_for_student",
                     "d1_read_family_relationship_history",
                     "D1_CROSS_REVERSE_EVENT_OR_RECEIPT_MISMATCH"):
            self.assertIn(item,runner)
        self.assertIn("from domain_cross_family_reverse_race_ci import run_cross_family_reverse_race",
                      concurrency)
        self.assertIn("run_cross_family_reverse_race(container, execute_sql)",concurrency)
        self.assertLess(concurrency.index("run_cross_family_race(container, execute_sql)"),
                        concurrency.index("run_cross_family_reverse_race(container, execute_sql)"))
        self.assertNotIn("supabase db push",runner)
        self.assertNotIn("service_role",runner)



    def test_authority_revocation_serializes_family_commands_both_orders(self):
        fixture=(business.ROOT/"supabase/tests/domain/fixtures/"
                 "family_authority_revoke_race_setup.sql").read_text(
                     encoding="utf-8")
        runner=(business.ROOT/"tools/supabase/"
                "domain_authorization_revocation_race_ci.py").read_text(
                     encoding="utf-8")
        concurrency=(business.ROOT/"tools/supabase/"
                     "domain_concurrency_ci.py").read_text(encoding="utf-8")
        for item in ("97000000-0000-4000-8000-000000000002",
                     "98000000-0000-4000-8000-000000000002",
                     "family_relationships","family_student_access",
                     "request.jwt.claims",
                     "foundation-rbac-001@example.invalid",
                     "SET ROLE schoolos_schema_owner;"):
            self.assertIn(item,fixture)
        self.assertLess(fixture.index("request.jwt.claims"),
                        fixture.index("SET ROLE schoolos_schema_owner;"))
        self.assertNotIn("COMMIT;",fixture)
        self.assertNotIn("GRANT SELECT ON app_private",fixture)
        for item in ("pg_catalog.pg_advisory_xact_lock(71001,1)",
                     "pg_blocking_pids", "locktype='advisory'",
                     "classid=71001", "objid=1",
                     "ExclusiveLock", "ShareLock",
                     "pending.mode='{mode}'",
                     "D1 Family child access authority denied",
                     "D1_AUTHORIZATION_REVOKE_FIRST_RACE_PASS",
                     "D1_AUTHORIZATION_COMMAND_FIRST_RACE_PASS",
                     "d1-authority-revoke-first-a-denied",
                     "d1-authority-command-first-b-end",
                     "family.child_access_changed",
                     "family.relationship_changed",
                     "foundation-test-001@example.invalid",
                     "foundation-rbac-001@example.invalid",
                     "foundation-family-001@example.invalid",
                     "foundation-own-002@example.invalid",
                     "d1_read_family_summary_for_student",
                     "d1_read_family_relationship_history",
                     "subprocess.Popen"):
            self.assertIn(item,runner)
        self.assertIn(
            "from domain_authorization_revocation_race_ci import run_family_authority_revocation_races",
            concurrency)
        self.assertIn("run_family_authority_revocation_races(container, execute_sql)",
                      concurrency)
        self.assertLess(concurrency.index("run_cross_family_reverse_race(container, execute_sql)"),
                        concurrency.index("run_family_authority_revocation_races(container, execute_sql)"))
        self.assertNotIn("supabase db push",runner)
        self.assertNotIn("service_role",runner)



    def test_assignment_scope_revocation_serializes_family_command_both_orders(self):
        fixture=(business.ROOT/"supabase/tests/domain/fixtures/"
                 "family_assignment_scope_revoke_race_setup.sql").read_text(
                    encoding="utf-8")
        runner=(business.ROOT/"tools/supabase/"
                "domain_assignment_scope_revocation_race_ci.py").read_text(
                    encoding="utf-8")
        accepted=(business.ROOT/"tools/supabase/"
                  "domain_authorization_revocation_race_ci.py").read_text(
                    encoding="utf-8")
        concurrency=(business.ROOT/"tools/supabase/domain_concurrency_ci.py"
                     ).read_text(encoding="utf-8")
        for item in ("99000000-0000-4000-8000-000000000002",
                     "9a000000-0000-4000-8000-000000000002",
                     "99000000-0000-4000-8000-000000000005",
                     "9a000000-0000-4000-8000-000000000005",
                     "99000000-0000-4000-8000-000000000006",
                     "9a000000-0000-4000-8000-000000000006",
                     "role_permission_grants",
                     "assignment_permission_scopes",
                     "permission_family_safe",
                     "ALL","DIRECT",
                     "foundation-rbac-001@example.invalid",
                     "request.jwt.claims","SET ROLE schoolos_schema_owner;"):
            self.assertIn(item,fixture)
        self.assertLess(fixture.index("request.jwt.claims"),
                        fixture.index("SET ROLE schoolos_schema_owner;"))
        self.assertNotIn("COMMIT;",fixture)
        self.assertNotIn("GRANT SELECT ON app_private",fixture)
        for item in ("_observe(", "_process(",
                     "pg_catalog.pg_advisory_xact_lock(71001,1)",
                     "UPDATE app_private.assignment_permission_scopes",
                     "revoked_at=pg_catalog.clock_timestamp()",
                     "D1 Family child access authority denied",
                     "D1_ASSIGNMENT_SCOPE_REVOKE_FIRST_RACE_PASS",
                     "D1_ASSIGNMENT_SCOPE_COMMAND_FIRST_RACE_PASS",
                     "d1-scope-a-command-denied",
                     "d1-scope-b-command-succeeded",
                     "family.child_access_changed",
                     "family.relationship_changed",
                     "foundation-rbac-001@example.invalid",
                     "foundation-test-001@example.invalid",
                     "foundation-family-001@example.invalid",
                     "foundation-own-002@example.invalid",
                     "app.d1_read_family_summary_for_student",
                     "app.d1_read_family_relationship_history",
                     "role_permission_grants",
                     "principal_role_assignments"):
            self.assertIn(item,runner)
        for item in ("pg_blocking_pids", "locktype='advisory'",
                     "classid=71001", "objid=1",
                     "ShareLock", "ExclusiveLock"):
            self.assertIn(item,accepted)
        self.assertIn(
            "from domain_assignment_scope_revocation_race_ci import run_family_assignment_scope_races",
            concurrency)
        self.assertIn("run_family_assignment_scope_races(container, execute_sql)",
                      concurrency)
        self.assertLess(
            concurrency.index("run_family_authority_revocation_races(container, execute_sql)"),
            concurrency.index("run_family_assignment_scope_races(container, execute_sql)"))
        self.assertNotIn("supabase db push",runner)
        self.assertNotIn("service_role",runner)



    def test_academic_subject_school_catalog_p0_business_acceptance(self):
        from domain_business_ci import DOMAIN_TESTS, ROOT as domain_root
        source=(domain_root/"supabase/tests/domain/"
                "32_academic_subject_lifecycle_authorization.sql").read_text(
                    encoding="utf-8")
        # Preserve the accepted 32-suite snapshot as an append-only prefix.
        self.assertEqual(DOMAIN_TESTS[31],
                         ["32_academic_subject_lifecycle_authorization.sql",54])
        self.assertGreaterEqual(len(DOMAIN_TESTS),32)
        self.assertEqual(sum(count for _,count in DOMAIN_TESTS[:32]),1648)
        self.assertIn("SELECT plan(54);",source)
        self.assertEqual(
            len(re.findall(r"SELECT (?:is|ok|throws_ok)\(",source)),54)
        self.assertTrue(source.startswith("--"))
        self.assertTrue(source.rstrip().endswith("ROLLBACK;"))
        self.assertEqual(source.count(r"\ir fixtures/command_actor.sql"),1)
        for marker in ("app.d1_change_academic_subject",
                       "academic.subject.change","academic.subject.manage",
                       "CREATE","UPDATE","ARCHIVE",
                       "subject_create_subject_id",
                       "subject_updated_subject_id",
                       "subject_archived_subject_id",
                       "D1 Academic Subject stale version/state",
                       "D1 Academic Subject target/ancestry changed",
                       "D1 Academic Subject authority denied",
                       "D1 operation is not enabled",
                       "D1 idempotency key conflicts with prior intent",
                       "SAVEPOINT subject_scope_revocation",
                       "SAVEPOINT subject_grant_revocation",
                       "SAVEPOINT subject_permission_disabled",
                       "SAVEPOINT subject_operation_disabled",
                       "schoolos_schema_owner",
                       "SET ROLE authenticated;",
                       "role_permission_grants",
                       "assignment_permission_scopes",
                       "permission_scope_contracts",
                       "subject-before-grant",
                       "subject-create",
                       "subject-update",
                       "subject-archive",
                       "academic.subject_changed",
                       "aggregate_kind='SUBJECT'",
                       "SELECT * FROM app_private.subjects",
                       "DELETE FROM app_private.subjects",
                       "SET CONSTRAINTS ALL IMMEDIATE",
                       "SELECT * FROM finish();"):
            self.assertIn(marker,source)
        self.assertNotIn("GRANT SELECT ON app_private",source)
        self.assertNotIn("supabase db push",source)



    def test_academic_class_offering_p0_lifecycle_and_capacity_acceptance(self):
        from domain_business_ci import DOMAIN_TESTS, ROOT as domain_root
        source=(domain_root/"supabase/tests/domain/"
                "33_academic_class_offering_lifecycle_authorization.sql").read_text(
                    encoding="utf-8")
        # Preserve accepted 33-suite checkpoint as an append-only prefix.
        self.assertEqual(DOMAIN_TESTS[32],
                         ["33_academic_class_offering_lifecycle_authorization.sql",52])
        self.assertGreaterEqual(len(DOMAIN_TESTS),33)
        self.assertEqual(sum(count for _,count in DOMAIN_TESTS[:33]),1700)
        self.assertIn("SELECT plan(52);",source)
        self.assertEqual(
            len(re.findall(r"SELECT (?:is|ok|throws_ok)\(",source)),52)
        self.assertTrue(source.startswith("--"))
        self.assertTrue(source.rstrip().endswith("ROLLBACK;"))
        self.assertEqual(source.count(r"\ir fixtures/command_actor.sql"),1)
        for marker in (
            "app.d1_change_academic_offering",
            "academic.offering.change","academic.offering.manage",
            "CREATE","UPDATE","ARCHIVE",
            "app.campuses","app.academic_years",
            "app_private.academic_classes","app_private.class_offerings",
            "app_private.capacity_revisions",
            "app_private.section_offerings",
            "D1 Offering Class ancestry missing",
            "D1 Offering Campus ancestry missing",
            "D1 Offering Academic Year ancestry missing",
            "D1 Academic Offering stale version/state",
            "D1 Academic Offering authority denied",
            "D1 Academic Offering has nonarchived Sections",
            "D1 Academic Offering intent invalid",
            "D1 operation is not enabled",
            "D1 idempotency key conflicts with prior intent",
            "SAVEPOINT offering_scope_revoked",
            "SAVEPOINT offering_grant_revoked",
            "SAVEPOINT offering_blocking_section",
            "SAVEPOINT offering_operation_disabled",
            "INITIAL_CONFIGURATION",
            "command_receipt_id IS NOT NULL",
            "academic.offering_changed",
            "aggregate_kind='CLASS_OFFERING'",
            "SELECT * FROM app_private.class_offerings",
            "DELETE FROM app_private.class_offerings",
            "SET CONSTRAINTS ALL IMMEDIATE",
            "SELECT * FROM finish();"):
            self.assertIn(marker,source)
        self.assertLess(
            source.index("SAVEPOINT offering_blocking_section"),
            source.index("NULL,'CLOSED',2,'offering-closed')"))
        self.assertIn("SET ROLE authenticated;",source)
        self.assertNotIn("GRANT SELECT ON app_private",source)
        self.assertNotIn("supabase db push",source)

    def test_academic_section_offering_p0_lifecycle_and_room_archive_acceptance(self):
        from domain_business_ci import DOMAIN_TESTS, ROOT as domain_root
        source=(domain_root/"supabase/tests/domain/"
                "34_academic_section_offering_lifecycle_authorization.sql").read_text(
                    encoding="utf-8")
        self.assertEqual(DOMAIN_TESTS[32],
                         ["33_academic_class_offering_lifecycle_authorization.sql",52])
        self.assertEqual(sum(count for _,count in DOMAIN_TESTS[:33]),1700)
        # Preserve the accepted 34-suite/1,756 assertion manifest as prefix.
        self.assertEqual(DOMAIN_TESTS[33],
                         ["34_academic_section_offering_lifecycle_authorization.sql",56])
        self.assertGreaterEqual(len(DOMAIN_TESTS),34)
        self.assertEqual(sum(count for _,count in DOMAIN_TESTS[:34]),1756)
        self.assertIn("SELECT plan(56);",source)
        self.assertEqual(
            len(re.findall(r"SELECT (?:is|ok|throws_ok)\(",source)),56)
        self.assertTrue(source.startswith("--"))
        self.assertTrue(source.rstrip().endswith("ROLLBACK;"))
        self.assertEqual(source.count(r"\ir fixtures/command_actor.sql"),1)
        for marker in (
            "app.d1_change_academic_section",
            "academic.section.change","academic.section.manage",
            "CREATE","UPDATE","ARCHIVE",
            "app.campuses","app.academic_years",
            "app_private.class_offerings","app_private.section_offerings",
            "app_private.capacity_revisions",
            "app_private.section_room_assignments","app.rooms",
            "D1 Section parent ancestry missing",
            "D1 Academic Section target/ancestry changed",
            "D1 Academic Section stale version/state",
            "D1 Academic Section authority denied",
            "D1 Academic Section has current/future Room assignment",
            "D1 Academic Section intent invalid",
            "D1 idempotency key conflicts with prior intent",
            "D1 operation is not enabled",
            "SAVEPOINT section_scope_revoked",
            "SAVEPOINT section_grant_revoked",
            "SAVEPOINT section_room_blocks_archive",
            "SAVEPOINT section_operation_disabled",
            "INITIAL_CONFIGURATION",
            "command_receipt_id IS NOT NULL",
            "academic.section_changed",
            "aggregate_kind='SECTION'",
            "SELECT * FROM app_private.section_offerings",
            "DELETE FROM app_private.section_offerings",
            "SET CONSTRAINTS ALL IMMEDIATE",
            "SELECT * FROM finish();"):
            self.assertIn(marker,source)
        self.assertLess(
            source.index("SAVEPOINT section_room_blocks_archive"),
            source.index("section-closed"))
        self.assertIn("SET ROLE authenticated;",source)
        self.assertNotIn("GRANT SELECT ON app_private",source)
        self.assertNotIn("supabase db push",source)


    def test_academic_section_room_add_end_correct_history_acceptance(self):
        from domain_business_ci import DOMAIN_TESTS, ROOT as domain_root
        source=(domain_root/"supabase/tests/domain/"
                "35_academic_section_room_assignment_history_authorization.sql").read_text(
                    encoding="utf-8")
        # Preserve the frozen 35-suite/1,833-assertion immutable prefix.
        self.assertGreaterEqual(len(DOMAIN_TESTS),35)
        self.assertEqual(DOMAIN_TESTS[33],
                         ["34_academic_section_offering_lifecycle_authorization.sql",56])
        self.assertEqual(sum(count for _,count in DOMAIN_TESTS[:34]),1756)
        self.assertEqual(DOMAIN_TESTS[34],
                         ["35_academic_section_room_assignment_history_authorization.sql",77])
        self.assertEqual(sum(count for _,count in DOMAIN_TESTS[:35]),1833)
        self.assertIn("SELECT plan(77);",source)
        self.assertEqual(
            len(re.findall(r"SELECT (?:is|ok|throws_ok)\(",source)),77)
        self.assertTrue(source.startswith("--"))
        self.assertTrue(source.rstrip().endswith("ROLLBACK;"))
        self.assertEqual(source.count(r"\ir fixtures/command_actor.sql"),1)
        for marker in (
            "app.d1_change_academic_section_room",
            "academic.section_room.change",
            "ADD",
            "END",
            "CORRECT",
            "app_private.section_room_assignments",
    "app_private.capacity_revisions",
    "INITIAL_CONFIGURATION",
            "app_private.section_offerings",
            "app.rooms",
            "app_private.assignment_permission_scopes",
            "app_private.role_permission_grants",
            "D1 Section Room target missing",
            "D1 Section Room Room missing",
            "D1 Section Room destination Room unusable",
            "D1 Section Room target is archived",
            "D1 Section Room retained target changed",
            "D1 Section Room correction predecessor invalid",
            "D1 overlapping effective history: section_room_assignments",
            "D1 Academic Section Room authority denied",
            "D1 Academic Section Room intent invalid",
            "D1 Section Room assignment already ended",
            "D1 idempotency key conflicts with prior intent",
            "D1 operation is not enabled",
            "SAVEPOINT room_archived_section",
            "SAVEPOINT room_other_section",
            "SAVEPOINT room_scope_revoked",
            "SAVEPOINT room_grant_revoked",
            "SAVEPOINT room_permission_disabled",
            "SAVEPOINT room_operation_disabled",
            "supersedes_id",
            "effective_from",
            "effective_until",
            "ended_by",
            "D1_SECTION_ROOM_ASSIGNMENT",
            "academic.section_room_changed",
            "aggregate_kind='SECTION_ROOM_ASSIGNMENT'",
            "SELECT * FROM app_private.section_room_assignments",
            "DELETE FROM app_private.section_room_assignments",
            "SET CONSTRAINTS ALL IMMEDIATE",
            "SELECT * FROM finish();",
        ):
            self.assertIn(marker,source)
        self.assertLess(
            source.index("SAVEPOINT room_archived_section"),
            source.index("room-bounded-add"))
        self.assertEqual(source.count("INSERT INTO app_private.capacity_revisions"),2)
        for projection in (
            "'95000000-0000-4000-8000-000000000004',NULL,35",
            "'95000000-0000-4000-8000-000000000005',NULL,20",
            "'95000000-0000-4000-8000-000000000011',NULL,15"):
            self.assertIn(projection,source)
        self.assertIn("SET ROLE authenticated;",source)
        self.assertIn("SET ROLE anon;",source)
        self.assertNotIn("GRANT SELECT ON app_private",source)
        self.assertNotIn("supabase db push",source)


    def test_academic_capacity_class_offering_section_projection_acceptance(self):
        from domain_business_ci import DOMAIN_TESTS, ROOT as domain_root
        source=(domain_root/"supabase/tests/domain/"
                "36_academic_capacity_change_revision_authorization.sql").read_text(
                    encoding="utf-8")
        # Preserve the previously frozen 36-suite/1,918-assertion prefix.
        self.assertGreaterEqual(len(DOMAIN_TESTS),36)
        self.assertEqual(DOMAIN_TESTS[34],
                         ["35_academic_section_room_assignment_history_authorization.sql",77])
        self.assertEqual(sum(count for _,count in DOMAIN_TESTS[:35]),1833)
        self.assertEqual(DOMAIN_TESTS[35],
                         ["36_academic_capacity_change_revision_authorization.sql",85])
        self.assertEqual(sum(count for _,count in DOMAIN_TESTS[:36]),1918)
        self.assertIn("SELECT plan(85);",source)
        self.assertEqual(
            len(re.findall(r"SELECT (?:is|ok|throws_ok)\(",source)),85)
        self.assertTrue(source.startswith("--"))
        self.assertTrue(source.rstrip().endswith("ROLLBACK;"))
        self.assertEqual(source.count(r"\ir fixtures/command_actor.sql"),1)
        for marker in (
            "app.d1_change_academic_capacity",
            "academic.capacity.change",
            "CLASS_OFFERING",
            "SECTION",
            "app_private.class_offerings",
            "app_private.section_offerings",
            "app_private.capacity_revisions",
            "INITIAL_CONFIGURATION",
            "SET CONSTRAINTS ALL DEFERRED",
            "SET CONSTRAINTS ALL IMMEDIATE",
            "D1 Academic Capacity intent invalid",
            "D1 Academic Capacity authority denied",
            "D1 Academic Capacity stale version/state",
            "D1 Academic Capacity effective date must be current",
            "D1 Capacity value unchanged",
            "D1 Capacity Section missing",
            "D1 Capacity Offering missing",
            "D1 idempotency key conflicts with prior intent",
            "D1 operation is not enabled",
            "supersedes_id",
            "command_receipt_id",
            "D1_CAPACITY_REVISION",
            "academic.capacity_changed",
            "aggregate_kind='ACADEMIC_CAPACITY'",
            "SAVEPOINT capacity_archived_section",
            "SAVEPOINT capacity_scope_revoked",
            "SAVEPOINT capacity_grant_revoked",
            "SAVEPOINT capacity_permission_disabled",
            "SAVEPOINT capacity_operation_disabled",
            "SELECT * FROM app_private.capacity_revisions",
            "DELETE FROM app_private.capacity_revisions",
            "SET ROLE authenticated;",
            "SET ROLE anon;",
            "SELECT * FROM finish();",
            "ROLLBACK;",
        ):
            self.assertIn(marker,source)
        self.assertEqual(source.count("INSERT INTO app_private.capacity_revisions"),2)
        for projection in (
            "'96000000-0000-4000-8000-000000000004',NULL,35",
            "'96000000-0000-4000-8000-000000000005',NULL,20",
            "'96000000-0000-4000-8000-000000000006',NULL,15"):
            self.assertIn(projection,source)
        self.assertLess(
            source.index("SET CONSTRAINTS ALL IMMEDIATE"),
            source.index("SET CONSTRAINTS ALL DEFERRED"))
        self.assertLess(
            source.index("SET CONSTRAINTS ALL DEFERRED"),
            source.index("capacity_a_revision_id"))
        self.assertNotIn("GRANT SELECT ON app_private",source)
        self.assertNotIn("supabase db push",source)


    def test_student_roll_policy_current_checked_read_and_disabled_change_gate(self):
        from domain_business_ci import DOMAIN_TESTS, ROOT as domain_root
        path=domain_root/"supabase/tests/domain/37_student_roll_policy_current_checked_read_authorization.sql"
        source=path.read_text(encoding="utf-8")
        draft=(domain_root/"supabase/migrations/20260928000000_domain_package_01.sql.draft").read_text(encoding="utf-8")
        # Immutable historical 37-suite, 1,953-assertion checkpoint.
        self.assertGreaterEqual(len(DOMAIN_TESTS),37)
        self.assertEqual(DOMAIN_TESTS[35],
                         ["36_academic_capacity_change_revision_authorization.sql",85])
        self.assertEqual(sum(count for _,count in DOMAIN_TESTS[:36]),1918)
        self.assertEqual(DOMAIN_TESTS[36],
                         ["37_student_roll_policy_current_checked_read_authorization.sql",35])
        self.assertEqual(sum(count for _,count in DOMAIN_TESTS[:37]),1953)
        self.assertIn("SELECT plan(35);",source)
        self.assertEqual(len(re.findall(r"SELECT (?:is|ok|throws_ok)\(",source)),35)
        self.assertTrue(source.startswith("--"))
        self.assertTrue(source.rstrip().endswith("ROLLBACK;"))
        self.assertEqual(source.count(r"\ir fixtures/command_actor.sql"),1)
        for marker in (
            "app.d1_read_roll_policy", "student.roll_policy.view",
            "student.roll_policy.change", "app_private.roll_policy_revisions",
            "PERSISTENT_STUDENT", "ACADEMIC_CONTEXT",
            "SAVEPOINT roll_policy_scope_revoked",
            "SAVEPOINT roll_policy_grant_revoked",
            "SAVEPOINT roll_policy_permission_disabled",
            "SAVEPOINT roll_policy_scope_contract_disabled",
            "SET CONSTRAINTS ALL IMMEDIATE",
            "SELECT * FROM app_private.roll_policy_revisions",
            "DELETE FROM app_private.roll_policy_revisions",
            "SET ROLE authenticated;", "SET ROLE anon;",
            "SELECT * FROM finish();",
        ):
            self.assertIn(marker,source)
        self.assertEqual(source.count("INSERT INTO app_private.roll_policy_revisions"),3)
        self.assertIn("GRANT EXECUTE ON FUNCTION app.d1_read_roll_policy(uuid) TO authenticated;",draft)
        self.assertNotIn("CREATE FUNCTION app.d1_change_roll_policy(",draft)
        self.assertNotIn("CREATE FUNCTION app.d1_change_student_roll_policy(",draft)
        self.assertIn("'student.roll_policy.change', 'student.roll_policy.change', 'student.roll_policy.approve', false",draft)
        self.assertNotIn("GRANT SELECT ON app_private",source)
        self.assertNotIn("supabase db push",source)


    def test_student_roll_policy_retained_history_p1_readiness_integrity(self):
        from domain_business_ci import DOMAIN_TESTS, ROOT as domain_root
        source=(domain_root/"supabase/tests/domain/"
            "38_student_roll_policy_retained_history_defensive_invariants.sql").read_text(
                encoding="utf-8")
        draft=(domain_root/"supabase/migrations/"
            "20260928000000_domain_package_01.sql.draft").read_text(encoding="utf-8")
        self.assertEqual(len(DOMAIN_TESTS),38)
        self.assertEqual(DOMAIN_TESTS[36],
            ["37_student_roll_policy_current_checked_read_authorization.sql",35])
        self.assertEqual(sum(count for _,count in DOMAIN_TESTS[:37]),1953)
        self.assertEqual(DOMAIN_TESTS[-1],
            ["38_student_roll_policy_retained_history_defensive_invariants.sql",40])
        self.assertEqual(sum(count for _,count in DOMAIN_TESTS),1993)
        self.assertIn("SELECT plan(40);",source)
        self.assertEqual(len(re.findall(r"SELECT (?:is|ok|throws_ok)\(",source)),40)
        self.assertTrue(source.startswith("--"))
        self.assertTrue(source.rstrip().endswith("ROLLBACK;"))
        self.assertEqual(source.count(r"\ir fixtures/command_actor.sql"),1)
        for marker in (
            "app_private.roll_policy_revisions",
            "PERSISTENT_STUDENT",
            "ACADEMIC_CONTEXT",
            "SELECT throws_ok(",
            "SET CONSTRAINTS ALL IMMEDIATE;",
            "student.roll_policy.change",
            "app_private.command_receipts",
            "app_private.approval_requests",
            "app_private.roll_allocations",
            "SET ROLE schoolos_schema_owner;",
            "SET ROLE authenticated;",
            "SELECT * FROM finish();",
        ):
            self.assertIn(marker,source)
        self.assertEqual(
            source.count("INSERT INTO app_private.roll_policy_revisions"),12)
        self.assertIn("CREATE FUNCTION app_private.d1_guard_record()",draft)
        self.assertIn("CREATE FUNCTION app_private.d1_guard_effective_history()",draft)
        self.assertIn(
            "D1 roll policy revision must follow locked school sequence",draft)
        self.assertIn(
            "'student.roll_policy.change', 'student.roll_policy.change', 'student.roll_policy.approve', false",draft)
        self.assertNotIn("CREATE FUNCTION app.d1_change_roll_policy(",draft)
        self.assertNotIn("CREATE FUNCTION app.d1_change_student_roll_policy(",draft)
        self.assertNotIn("GRANT SELECT ON app_private",source)
        self.assertNotIn("supabase db push",source)



if __name__ == "__main__":
    unittest.main()
