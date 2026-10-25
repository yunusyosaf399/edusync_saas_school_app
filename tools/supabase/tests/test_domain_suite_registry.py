"""G01: prevent silently dropped/colliding acceptance suites before any SQL."""
import sys
import unittest
from pathlib import Path
from tempfile import TemporaryDirectory
from unittest.mock import patch
sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
import domain_business_ci as business


class SuiteRegistryTests(unittest.TestCase):
    def write_suite(self, root, name, count=1):
        directory = root / 'supabase/tests/domain'
        directory.mkdir(parents=True, exist_ok=True)
        (directory / name).write_text(
            '-- disposable suite\nBEGIN;\nSELECT plan('+str(count)+');\n'
            '\\ir fixtures/command_actor.sql\nSELECT * FROM finish();\nROLLBACK;\n')

    def test_current_registry_preserves_all_112_full_filenames_and_4292_assertions(self):
        business.validate_test_registry(business.ROOT, business.DOMAIN_TESTS)
        self.assertEqual(len(business.DOMAIN_TESTS), 112)
        self.assertEqual(sum(count for _, count in business.DOMAIN_TESTS), 4292)
        names = {name for name, _ in business.DOMAIN_TESTS}
        for number in (82, 83, 84, 85, 86, 89, 90, 91, 92):
            for owner in ('db01', 'db02'):
                self.assertEqual(sum(n.startswith(str(number)+'_'+owner+'_') for n in names), 1)

    def test_same_numeric_label_across_owners_is_valid(self):
        with TemporaryDirectory() as directory:
            root = Path(directory)
            names = ['82_db01_source.sql', '82_db02_source.sql']
            for name in names:
                self.write_suite(root, name)
            business.validate_test_registry(root, [(name, 1) for name in names])

    def test_duplicate_full_filename_stops_before_any_subprocess(self):
        with TemporaryDirectory() as directory:
            root = Path(directory)
            name = '82_db01_source.sql'
            self.write_suite(root, name)
            with patch.object(business, 'ROOT', root), patch.object(
                business, 'DOMAIN_TESTS', [(name, 1), (name, 1)]), patch.object(
                business.subprocess, 'run') as run:
                with self.assertRaisesRegex(RuntimeError, 'MANIFEST_DUPLICATE'):
                    business.run_business_tests()
                run.assert_not_called()

    def test_same_owner_numeric_collision_is_rejected(self):
        with TemporaryDirectory() as directory:
            root = Path(directory)
            names = ['82_db01_source.sql', '82_db01_other.sql']
            for name in names:
                self.write_suite(root, name)
            with self.assertRaisesRegex(RuntimeError, 'OWNER_ORDINAL'):
                business.validate_test_registry(root, [(name, 1) for name in names])

    def test_dropped_registration_cannot_silently_skip_source(self):
        with TemporaryDirectory() as directory:
            root = Path(directory)
            self.write_suite(root, '82_db01_source.sql')
            self.write_suite(root, '82_db02_source.sql')
            with self.assertRaisesRegex(RuntimeError, 'SOURCE_UNREGISTERED.*82_db02_source'):
                business.validate_test_registry(root, [('82_db01_source.sql', 1)])

    def test_future_suite_requires_registered_owner(self):
        with TemporaryDirectory() as directory:
            root = Path(directory)
            self.write_suite(root, '104_unknown_case.sql')
            with self.assertRaisesRegex(RuntimeError, 'MANIFEST_OWNER'):
                business.validate_test_registry(root, [('104_unknown_case.sql', 1)])

    def test_reserved_db03_and_db04_namespaces_can_reuse_an_ordinal(self):
        with TemporaryDirectory() as directory:
            root = Path(directory)
            names = ['104_db03_intake.sql', '104_db04_curriculum.sql']
            for name in names:
                self.write_suite(root, name)
            business.validate_test_registry(root, [(name, 1) for name in names])

    def test_bad_path_and_invalid_assertion_counts_are_rejected(self):
        with TemporaryDirectory() as directory:
            root = Path(directory)
            self.write_suite(root, '104_db02_case.sql')
            for name, count, error in [('../104_db02_case.sql', 1, 'MANIFEST_NAME'),
                                       ('104_db02_case.sql', 0, 'MANIFEST_COUNT'),
                                       ('104_db02_case.sql', True, 'MANIFEST_COUNT'),
                                       ('104_db02_case.sql', 2, 'MANIFEST_PLAN')]:
                with self.subTest(name=name, count=count), self.assertRaisesRegex(RuntimeError, error):
                    business.validate_test_registry(root, [(name, count)])

    def test_bad_transaction_boundary_is_rejected_before_execution(self):
        with TemporaryDirectory() as directory:
            root = Path(directory)
            name = '104_db02_case.sql'
            self.write_suite(root, name)
            path = root / 'supabase/tests/domain' / name
            path.write_text(path.read_text().replace('ROLLBACK;', 'COMMIT;'))
            with self.assertRaisesRegex(RuntimeError, 'TRANSACTION_BOUNDARY'):
                business.validate_test_registry(root, [(name, 1)])


if __name__ == '__main__':
    unittest.main()
