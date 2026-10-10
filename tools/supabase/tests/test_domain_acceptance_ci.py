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


if __name__ == "__main__":
    unittest.main()
