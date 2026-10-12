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
        self.assertNotIn("GRANT SELECT ON app_private",sql)
        for block in sql.split("SET ROLE authenticated;")[1:]:
            client=block.split("RESET ROLE;",1)[0]
            for table in ("students","family_relationships","family_student_access",
                          "approval_requests","approval_reviews","approval_applications"):
                self.assertNotIn("FROM app_private."+table+" WHERE",client)


if __name__ == "__main__":
    unittest.main()
