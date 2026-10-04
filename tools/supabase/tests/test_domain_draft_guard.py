import tempfile
import unittest
import uuid
from pathlib import Path

from tools.supabase import domain_draft_guard as guard


def _u(n):
    return str(uuid.UUID(int=n + 1))


def _fixture_text():
    parts = []
    for table in guard.EXPECTED_TABLES:
        parts.append(f"CREATE TABLE app_private.{table} (id uuid);\n")
        parts.append(f"ALTER TABLE app_private.{table} ENABLE ROW LEVEL SECURITY;\n")
        parts.append(f"ALTER TABLE app_private.{table} FORCE ROW LEVEL SECURITY;\n")
    permissions = ",\n".join(
        f"('{_u(i)}','permission.{i}',false,'A')" for i in range(97)
    )
    scopes = ",\n".join(
        f"('{_u(1000+i)}','permission.{i % 97}','ALL','DIRECT')" for i in range(322)
    )
    operations = []
    for i in range(36):
        code = "student.create" if i == 5 else f"operation.{i}"
        operations.append(f"('{_u(2000+i)}','{code}','permission.{i % 97}',NULL,false)")
    operations = ",\n".join(operations)
    parts.append(
        "CREATE FUNCTION app_private.d1_register_catalog_v1() RETURNS void\n"
        "LANGUAGE plpgsql SECURITY DEFINER SET search_path = pg_catalog, pg_temp AS $body$\n"
        "BEGIN\n"
        "PERFORM pg_catalog.pg_advisory_xact_lock(71001,1);\n"
        "PERFORM pg_catalog.pg_advisory_xact_lock_shared(71001,1);\n"
        f"FOR item IN SELECT * FROM (VALUES\n{permissions}\n) x LOOP NULL; END LOOP;\n"
        f"FOR item IN SELECT * FROM (VALUES\n{scopes}\n) x LOOP NULL; END LOOP;\n"
        f"FOR item IN SELECT * FROM (VALUES\n{operations}\n) x LOOP NULL; END LOOP;\n"
        "INSERT INTO app_private.operation_contracts(id,code,contract_version,handler_key,request_permission_id,review_permission_id,payload_schema_version,requires_approval,enabled,created_by)\n"
        "VALUES(item.id::uuid,item.code,1,item.code,pid,rid,1,item.requires_approval,false,actor);\n"
        "END $body$;\n"
        "REVOKE ALL ON FUNCTION app_private.d1_register_catalog_v1() FROM PUBLIC,anon,authenticated,service_role;\n"
    )
    parts.append(
        "CREATE FUNCTION app.d1_safe_read() RETURNS boolean\n"
        "LANGUAGE sql SECURITY DEFINER SET search_path=pg_catalog,pg_temp AS $body$ SELECT true $body$;\n"
        "REVOKE ALL ON FUNCTION app.d1_safe_read() FROM PUBLIC,anon,authenticated,service_role;\n"
        "GRANT EXECUTE ON FUNCTION app.d1_safe_read() TO authenticated;\n"
    )
    return "".join(parts)


class DomainDraftGuardTests(unittest.TestCase):
    def make_root(self, text=None):
        temp = tempfile.TemporaryDirectory()
        self.addCleanup(temp.cleanup)
        root = Path(temp.name)
        mig = root / "supabase/migrations"
        mig.mkdir(parents=True)
        (mig / guard.BASE_NAME).write_text(
            text or _fixture_text(), encoding="utf-8", newline="\n"
        )
        return root

    def test_accepts_integrated_source_contract(self):
        errors, metrics = guard.inspect(self.make_root())
        self.assertEqual(errors, [])
        self.assertEqual(metrics["relations"], 34)
        self.assertEqual(metrics["permissions"], 97)
        self.assertEqual(metrics["scope_alternatives"], 322)
        self.assertEqual(metrics["operations"], 36)

    def test_rejects_executable_migration10(self):
        root = self.make_root()
        (root / "supabase/migrations/20260928000000_domain_package_01.sql").write_text(
            "select 1;\n", encoding="utf-8"
        )
        errors, _ = guard.inspect(root)
        self.assertTrue(any("must remain non-executable" in e for e in errors))

    def test_rejects_missing_force_rls(self):
        text = _fixture_text().replace(
            "ALTER TABLE app_private.students FORCE ROW LEVEL SECURITY;\n", "", 1
        )
        errors, _ = guard.inspect(self.make_root(text))
        self.assertIn("RLS FORCE missing for app_private.students", errors)

    def test_rejects_manifest_count_drift(self):
        text = _fixture_text().replace(
            f"('{_u(0)}','permission.0',false,'A'),\n", "", 1
        )
        errors, _ = guard.inspect(self.make_root(text))
        self.assertTrue(any("manifest count mismatch" in e for e in errors))

    def test_rejects_student_create_rpc_before_admissions(self):
        text = _fixture_text() + (
            "CREATE FUNCTION app.d1_student_create() RETURNS void "
            "LANGUAGE sql SECURITY DEFINER SET search_path=pg_catalog,pg_temp "
            "AS $body$ SELECT $body$;\n"
        )
        errors, _ = guard.inspect(self.make_root(text))
        self.assertTrue(any("student.create public command exists" in e for e in errors))

    def test_rejects_unpinned_security_definer_search_path(self):
        text = _fixture_text().replace(
            "SECURITY DEFINER SET search_path=pg_catalog,pg_temp AS $body$ SELECT true",
            "SECURITY DEFINER AS $body$ SELECT true",
            1,
        )
        errors, _ = guard.inspect(self.make_root(text))
        self.assertTrue(any("search_path not pinned" in e for e in errors))

    def test_rejects_broad_execute_grant(self):
        text = _fixture_text() + (
            "GRANT EXECUTE ON FUNCTION app.d1_safe_read() TO service_role;\n"
        )
        errors, _ = guard.inspect(self.make_root(text))
        self.assertTrue(any("broad D1 EXECUTE grant" in e for e in errors))


if __name__ == "__main__":
    unittest.main()
