"""Bind G02 runtime acceptance to the composed sources, registry and call graph."""
import hashlib
import json
import re
import sys
import unittest
from pathlib import Path
sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
import domain_business_ci as business
import domain_draft_guard as draft
import domain_function_final_guard as final
import domain_local_ci as local

ROOT = business.ROOT
MANIFEST = ROOT/'supabase/config/db02_g02_composition_manifest.json'


class G02CompositionTests(unittest.TestCase):
    def setUp(self):
        self.manifest = json.loads(MANIFEST.read_text())

    def test_exact_composed_draft_chain_registry_and_catalog_are_bound(self):
        digest = hashlib.sha256()
        paths = draft.discover_drafts(ROOT)
        for path in paths:
            data = path.read_bytes()
            digest.update(path.name.encode()+b'\0'+str(len(data)).encode()+b'\0'+data)
        self.assertEqual(len(paths), self.manifest['draft_fragments'])
        self.assertEqual(digest.hexdigest(), self.manifest['draft_chain_sha256'])
        self.assertEqual(business.DOMAIN_TESTS, self.manifest['business_suites'])
        self.assertEqual(sum(n for _, n in business.DOMAIN_TESTS), self.manifest['business_assertions'])
        self.assertEqual(local.EXPECTED_RUNTIME_METRICS, self.manifest['runtime_metrics'])
        business.validate_test_registry(ROOT, business.DOMAIN_TESTS)

    def test_shared_receipt_final_override_keeps_owner_and_private_call_edges(self):
        definitions = []
        pattern = re.compile(r'CREATE(?:\s+OR\s+REPLACE)?\s+FUNCTION\s+app_private\.d1_command_receipt_lookup\s*\(', re.I)
        for path in draft.discover_drafts(ROOT):
            if pattern.search(path.read_text()):
                definitions.append(path.name)
        self.assertEqual(definitions[-1], self.manifest['final_receipt_fragment'])
        errors, _, states = final.inspect(ROOT)
        self.assertEqual(errors, [])
        state = states['app_private.d1_command_receipt_lookup']
        self.assertEqual(state.owner, 'schoolos_evidence_writer')
        self.assertTrue(state.security_definer)
        self.assertEqual(state.execute_roles, {
            'schoolos_academic_executor', 'schoolos_employee_executor',
            'schoolos_family_executor', 'schoolos_student_executor',
            'schoolos_teaching_executor', 'schoolos_workflow_executor'})

    def test_every_required_owner_race_remains_called_before_runtime_pass(self):
        source = (ROOT/'tools/supabase/domain_local_ci.py').read_text()
        success = source.index('print("D1C2A_PASS')
        for name in self.manifest['required_race_calls']:
            # Require an invocation, not merely an import or documentation.
            calls = list(re.finditer(r'^\s*'+re.escape(name)+r'\(', source, re.M))
            self.assertEqual(len(calls), 1, name)
            self.assertLess(calls[0].start(), success, name)


if __name__ == '__main__':
    unittest.main()
