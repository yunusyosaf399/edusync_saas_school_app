import io
from contextlib import redirect_stderr
import sys
import tempfile
import unittest
from unittest.mock import patch
from subprocess import CompletedProcess
from pathlib import Path

TOOLS = Path(__file__).resolve().parents[1]
if str(TOOLS) not in sys.path:
    sys.path.insert(0, str(TOOLS))

import domain_local_ci as runtime


class DomainLocalCITests(unittest.TestCase):
    def make_root(self, project_id=runtime.EXPECTED_PROJECT_ID):
        temp = tempfile.TemporaryDirectory()
        self.addCleanup(temp.cleanup)
        root = Path(temp.name)
        (root / "supabase/migrations").mkdir(parents=True)
        (root / "supabase/config.toml").write_text(
            f'project_id = "{project_id}"\n', encoding="utf-8", newline="\n"
        )
        return root

    def test_failed_start_reports_only_safe_diagnostic_code_and_container_state(self):
        secret = "postgresql://admin:private-password@internal-host/private"
        def fake_run(args, **kwargs):
            if args[:2] == ["supabase", "start"]:
                return CompletedProcess(args, 1, "untrusted " + secret,
                                        "port is already allocated; " + secret)
            if args[:2] == ["supabase", "stop"]:
                return CompletedProcess(args, 0, "", "")
            if args[:2] == ["docker", "inspect"]:
                self.assertIn("supabase_db_" + runtime.EXPECTED_PROJECT_ID, args)
                return CompletedProcess(args, 0, "exited|137|true", "")
            self.fail("Unexpected diagnostic command")
        captured = io.StringIO()
        with patch.object(runtime.subprocess, "run", side_effect=fake_run):
            with redirect_stderr(captured):
                with self.assertRaisesRegex(runtime.DomainLocalCIError, "supabase start"):
                    runtime._start_disposable_stack()
        output = captured.getvalue()
        self.assertIn("D1C2A_START_DIAGNOSTIC code=PORT_CONFLICT", output)
        self.assertIn("pg_state=exited,exit=137,oom=true", output)
        self.assertNotIn(secret, output)
        self.assertNotIn("private-password", output)

    def test_failed_start_does_not_echo_unclassified_cli_output(self):
        secret = "eyJprivate.secret.jwt"
        def fake_run(args, **kwargs):
            if args[:2] == ["supabase", "start"]:
                return CompletedProcess(args, 1, secret, secret)
            if args[:2] == ["docker", "inspect"]:
                return CompletedProcess(args, 1, "", secret)
            self.fail("Unexpected diagnostic command")
        captured = io.StringIO()
        with patch.object(runtime.subprocess, "run", side_effect=fake_run):
            with redirect_stderr(captured):
                with self.assertRaises(runtime.DomainLocalCIError):
                    runtime._start_disposable_stack()
        output = captured.getvalue()
        self.assertIn("code=UNCLASSIFIED pg_state=ABSENT", output)
        self.assertNotIn(secret, output)

    def test_image_pull_failure_retries_an_official_registry_without_changing_tag(self):
        calls = []
        def fake_run(args, **kwargs):
            calls.append((args, kwargs))
            if args[:2] == ["supabase", "start"]:
                if kwargs["env"]["SUPABASE_INTERNAL_IMAGE_REGISTRY"] == "ghcr.io":
                    return CompletedProcess(args, 1, "failed to pull image", "")
                if kwargs["env"]["SUPABASE_INTERNAL_IMAGE_REGISTRY"] == "docker.io":
                    return CompletedProcess(args, 0, "", "")
                self.fail("Unexpected image registry")
            if args[:2] == ["supabase", "stop"]:
                self.assertEqual(args[3], runtime.EXPECTED_PROJECT_ID)
                return CompletedProcess(args, 0, "", "")
            if args[:2] == ["docker", "inspect"]:
                return CompletedProcess(args, 1, "", "")
            self.fail("Unexpected command")
        with patch.dict(runtime.os.environ, {"SUPABASE_INTERNAL_IMAGE_REGISTRY": "ghcr.io"}):
            with patch.object(runtime.subprocess, "run", side_effect=fake_run):
                with redirect_stderr(io.StringIO()) as captured:
                    runtime._start_disposable_stack()
                    self.assertEqual(
                        runtime.os.environ["SUPABASE_INTERNAL_IMAGE_REGISTRY"],
                        "docker.io",
                        "Later local pgTAP commands must use the working image registry",
                    )
        registries = [kwargs["env"]["SUPABASE_INTERNAL_IMAGE_REGISTRY"]
                      for args, kwargs in calls if args[:2] == ["supabase", "start"]]
        self.assertEqual(registries, ["ghcr.io", "docker.io"])
        self.assertNotIn("failed to pull image", captured.getvalue())

    def test_startup_fallback_denies_invalid_project(self):
        from local_stack_registry import start_disposable_stack
        with self.assertRaisesRegex(RuntimeError, "LOCAL_STACK_TARGET_INVALID"):
            start_disposable_stack(runtime.ROOT, "some-other-project", "D1C2A")

    def test_project_id_is_fail_closed_and_pinned(self):
        root = self.make_root()
        self.assertEqual(runtime.local_project_id(root), runtime.EXPECTED_PROJECT_ID)
        wrong = self.make_root("another_project")
        with self.assertRaisesRegex(runtime.DomainLocalCIError, "LOCAL_PROJECT_ID_MISMATCH"):
            runtime.local_project_id(wrong)

    def test_assemble_chain_uses_exact_lexical_order(self):
        root = self.make_root()
        mig = root / "supabase/migrations"
        names = [
            "20260928000000_domain_package_01.sql.draft",
            "20260928000000_domain_package_01_a.sql.draft",
            "20260928000000_domain_package_01_b.sql.draft",
        ]
        for index, name in enumerate(reversed(names)):
            (mig / name).write_text(
                f"SELECT {index};\n", encoding="utf-8", newline="\n"
            )
        drafts, text = runtime.assemble_draft_chain(root)
        self.assertEqual([p.name for p in drafts], names)
        offsets = [text.index("D1C2A BEGIN " + name) for name in names]
        self.assertEqual(offsets, sorted(offsets))

    def test_runtime_probe_exact_metrics_pass(self):
        observed = dict(runtime.EXPECTED_RUNTIME_METRICS)
        runtime.validate_runtime_probe(observed)

    def test_runtime_inventory_private_helper_delta(self):
        # DB-01 effects 41_01/02 add Student-owned private functions;
        # effect 41_03 adds two authz-reader-owned private gates.
        # Public RPCs, client grants and RLS remain frozen.
        expected = runtime.EXPECTED_RUNTIME_METRICS
        self.assertEqual(expected["functions"], 566)
        self.assertEqual(expected["security_definers"], 548)
        self.assertEqual(expected["private_functions"], 405)
        self.assertEqual(expected["app_functions"], 161)
        self.assertEqual(expected["authenticated_app_execute"], 161)
        self.assertEqual(expected["authenticated_private_execute"], 0)
        self.assertEqual(expected["anon_execute"], 0)
        self.assertEqual(expected["service_role_execute"], 0)
        self.assertEqual(expected["authenticated_table_dml"], 0)
        self.assertEqual(expected["unknown_function_owners"], 0)
        self.assertEqual(expected["app_schema_owner_functions"], 0)
        self.assertEqual(
            expected["functions"],
            expected["app_functions"] + expected["private_functions"] + 0,
        )

    def test_db01_single_helper_signature_acl_and_non_activation(self):
        # Source guard complements runtime pg_proc owner/has_function_privilege checks.
        helper = runtime.ROOT / "supabase/migrations" / (
            "20260928000000_domain_package_01_effect38_02_db01_roll_correct_result_pair.sql.draft"
        )
        sql = helper.read_text(encoding="utf-8")
        self.assertEqual(
            sql.count("CREATE FUNCTION app_private.d1_roll_correct_result_rows_match_exact("), 1
        )
        self.assertIn("p_student uuid,p_enrollment uuid,p_source_roll uuid,p_successor_roll uuid,p_summary jsonb", sql)
        self.assertIn("SET ROLE schoolos_student_executor;", sql)
        self.assertIn("SECURITY DEFINER SET search_path=pg_catalog,pg_temp", sql)
        self.assertIn(
            "REVOKE ALL ON FUNCTION app_private.d1_roll_correct_result_rows_match_exact", sql
        )
        self.assertIn("FROM PUBLIC,anon,authenticated,service_role;", sql)
        self.assertIn("TO schoolos_student_executor,schoolos_workflow_executor;", sql)
        self.assertNotIn("GRANT EXECUTE ON FUNCTION app_private.d1_roll_correct_result_rows_match_exact(uuid,uuid,uuid,uuid,jsonb) TO authenticated", sql)
        self.assertNotIn("CREATE FUNCTION app.d1_correct_student_roll", sql)
        self.assertNotIn("UPDATE app_private.operation_contracts", sql)
        self.assertNotIn("INSERT INTO app_private.roll_allocations", sql)

    def test_db01_second_receipt_helper_is_private_and_direct_only(self):
        helper = runtime.ROOT / "supabase/migrations" / (
            "20260928000000_domain_package_01_effect38_03_db01_direct_receipt_provenance.sql.draft"
        )
        sql = helper.read_text(encoding="utf-8")
        self.assertEqual(
            sql.count("CREATE FUNCTION app_private.d1_roll_correct_direct_receipt_matches_exact("), 1
        )
        self.assertIn("SET ROLE schoolos_schema_owner;", sql)
        self.assertIn("TO schoolos_schema_owner;", sql)
        self.assertNotIn("GRANT SELECT ON app_private.", sql)
        self.assertIn("SECURITY DEFINER SET search_path=pg_catalog,pg_temp", sql)
        self.assertIn("FROM PUBLIC,anon,authenticated,service_role;", sql)
        self.assertIn("TO schoolos_student_executor,schoolos_workflow_executor;", sql)
        self.assertIn("r.command_kind='student.roll.correct'", sql)
        self.assertIn("r.request_id IS NULL", sql)
        self.assertIn("r.result_ref=p_successor_roll", sql)
        self.assertIn("app_private.d1_roll_correct_result_rows_match_exact(", sql)
        self.assertNotIn("UPDATE app_private.operation_contracts", sql)
        self.assertNotIn("CREATE FUNCTION app.d1_correct_student_roll", sql)

    def test_db01_approval_application_guard_is_scoped_and_private(self):
        helper = runtime.ROOT / "supabase/migrations" / (
            "20260928000000_domain_package_01_effect38_04_db01_apply_application_receipt_guard.sql.draft"
        )
        sql = helper.read_text(encoding="utf-8")
        self.assertEqual(
            sql.count("CREATE FUNCTION app_private.d1_roll_correct_application_receipt_guard()"), 1
        )
        self.assertIn("SET ROLE schoolos_schema_owner;", sql)
        self.assertIn("RETURNS trigger LANGUAGE plpgsql VOLATILE SECURITY DEFINER", sql)
        self.assertIn("IF v_code IS DISTINCT FROM 'student.roll.correct' THEN RETURN NEW;", sql)
        self.assertIn("CREATE TRIGGER d1_roll_correct_application_receipt_guard", sql)
        self.assertIn("FROM PUBLIC,anon,authenticated,service_role;", sql)
        self.assertIn("TO schoolos_schema_owner;", sql)
        self.assertIn("app_private.d1_roll_correct_result_rows_match_exact(", sql)
        self.assertNotIn("GRANT EXECUTE ON FUNCTION app_private.d1_roll_correct_application_receipt_guard", sql)
        self.assertNotIn("UPDATE app_private.operation_contracts", sql)

    def test_db01_source_prelock_exact_identity_private_acl(self):
        helper = runtime.ROOT / "supabase/migrations" / (
            "20260928000000_domain_package_01_effect41_01_db01_correct_source_prelock.sql.draft"
        )
        sql = helper.read_text(encoding="utf-8")
        self.assertEqual(sql.count("CREATE FUNCTION app_private.d1_roll_correct_lock_source("), 1)
        self.assertIn("SET ROLE schoolos_student_executor;", sql)
        self.assertIn("SECURITY DEFINER SET search_path=pg_catalog,pg_temp", sql)
        self.assertIn("app_private.d1_enrollment_place_lock_school(", sql)
        self.assertIn("ORDER BY a.id FOR UPDATE", sql)
        self.assertIn("business_date:=app_private.d1_roll_business_date(school_id);", sql)
        self.assertLess(sql.index("app_private.d1_enrollment_place_lock_school("),
                        sql.index("FROM app_private.roll_policy_revisions rp"))
        self.assertLess(sql.index("ORDER BY a.id FOR UPDATE"),
                        sql.index("FROM app_private.students s WHERE s.id=p_student FOR UPDATE"))
        self.assertIn("FROM PUBLIC,anon,authenticated,service_role;", sql)
        self.assertIn("TO schoolos_student_executor,schoolos_workflow_executor;", sql)
        self.assertNotIn("CREATE FUNCTION app.d1_correct_student_roll", sql)
        self.assertNotIn("INSERT INTO app_private.roll_allocations", sql)
        self.assertNotIn("UPDATE app_private.roll_allocations", sql)

    def test_db01_private_correction_effect_has_server_owned_history_guards(self):
        helper = runtime.ROOT / "supabase/migrations" / (
            "20260928000000_domain_package_01_effect41_02_db01_correct_effect.sql.draft"
        )
        sql = helper.read_text(encoding="utf-8")
        self.assertEqual(sql.count("CREATE FUNCTION app_private.d1_roll_correct_effect("), 1)
        self.assertIn("SET ROLE schoolos_student_executor;", sql)
        self.assertIn("SECURITY DEFINER SET search_path=pg_catalog,pg_temp", sql)
        self.assertIn("app_private.d1_roll_correct_lock_source(", sql)
        self.assertIn("app_private.current_principal_id()", sql)
        self.assertIn("r.student_id<>p_student", sql)
        self.assertIn("so.class_offering_id=c.class_offering_id", sql)
        self.assertIn("SET next_value=p_new_numeric+1", sql)
        self.assertIn("source_row.origin_allocation_id,p_roll,p_reason", sql)
        self.assertIn("UPDATE app_private.students SET current_status='ACTIVE'", sql)
        self.assertIn("FROM PUBLIC,anon,authenticated,service_role;", sql)
        self.assertNotIn("UPDATE app_private.operation_contracts", sql)
        self.assertNotIn("CREATE FUNCTION app.d1_correct_student_roll", sql)

    def test_db01_private_roll_authority_policy_gate_is_narrow_and_inactive(self):
        helper = runtime.ROOT / "supabase/migrations" / (
            "20260928000000_domain_package_01_effect41_03_db01_roll_correct_private_authority_p1.sql.draft"
        )
        sql = helper.read_text(encoding="utf-8")
        self.assertEqual(sql.count("CREATE FUNCTION app_private.d1_roll_correct_authorized("), 1)
        self.assertEqual(sql.count("CREATE FUNCTION app_private.d1_roll_correct_policy("), 1)
        self.assertEqual(sql.count("SECURITY DEFINER SET search_path=pg_catalog,pg_temp"), 2)
        self.assertEqual(sql.count("SET ROLE schoolos_authz_reader;"), 1)
        self.assertIn("p_permission='student.roll.approve' AND p_reviewer_role IS NULL", sql)
        self.assertIn("p.code=p_permission AND p.state='ENABLED'", sql)
        self.assertIn("o.code='student.roll.correct' AND o.contract_version=1 AND o.enabled", sql)
        self.assertIn("sc.scope_kind='SECTION' AND sc.section_offering_id=target.section_id", sql)
        self.assertIn("t.selection_resolver_key IS DISTINCT FROM 'D1_REVIEWER_ROLE_SCOPE'", sql)
        self.assertIn("FROM PUBLIC,anon,authenticated,service_role;", sql)
        self.assertIn("TO schoolos_student_executor,schoolos_workflow_executor,schoolos_read_executor;", sql)
        self.assertNotIn("CREATE FUNCTION app.", sql)
        self.assertNotIn("UPDATE app_private.operation_contracts", sql)
        self.assertNotIn("INSERT INTO app_private.roll_allocations", sql)
        self.assertNotIn("GRANT EXECUTE ON FUNCTION app_private.d1_roll_correct_authorized(uuid,text,uuid,uuid)\n TO authenticated", sql)

    def test_db01_canonical_command_context_is_private_typed_and_not_a_command(self):
        sql = (runtime.ROOT / "supabase/migrations" / (
            "20260928000000_domain_package_01_effect41_04_db01_roll_correct_canonical_command_context.sql.draft"
        )).read_text(encoding="utf-8")
        self.assertEqual(sql.count("CREATE FUNCTION app_private.d1_roll_correct_command_context("), 1)
        self.assertEqual(sql.count("SET ROLE schoolos_evidence_writer;"), 1)
        self.assertIn("SECURITY DEFINER SET search_path=pg_catalog,pg_temp", sql)
        self.assertIn("WHEN 'student.roll.correct' THEN 11", sql)
        self.assertIn("WHEN 'request.submit' THEN 11", sql)
        self.assertIn("WHEN 'request.review' THEN 4", sql)
        self.assertIn("WHEN 'request.apply' THEN 2", sql)
        self.assertIn("app_private.d1_jcs_typed(", sql)
        self.assertIn("p_intent->>10", sql)
        self.assertIn("pg_catalog.pg_advisory_xact_lock_shared(71001,1)", sql)
        self.assertIn("pg_catalog.pg_advisory_xact_lock(71002,resource::integer)", sql)
        self.assertIn("rec.canonical_payload_hash IS DISTINCT FROM h", sql)
        self.assertIn("FROM PUBLIC,anon,authenticated,service_role;", sql)
        self.assertIn("TO schoolos_student_executor,schoolos_workflow_executor;", sql)
        self.assertNotIn("CREATE FUNCTION app.", sql)
        self.assertNotIn("UPDATE app_private.operation_contracts", sql)
        self.assertNotIn("INSERT INTO app_private.command_receipts", sql)
        self.assertNotIn("INSERT INTO app_private.roll_allocations", sql)

    def test_db01_direct_evidence_writer_binds_retained_reason_and_safe_evidence(self):
        sql = (runtime.ROOT / "supabase/migrations" / (
            "20260928000000_domain_package_01_effect41_05_db01_roll_correct_direct_success_evidence.sql.draft"
        )).read_text(encoding="utf-8")
        self.assertEqual(sql.count("CREATE FUNCTION app_private.d1_roll_correct_reason_matches_exact("), 1)
        self.assertEqual(sql.count("CREATE FUNCTION app_private.d1_roll_correct_direct_success_evidence("), 1)
        self.assertEqual(sql.count("SECURITY DEFINER SET search_path=pg_catalog,pg_temp"), 2)
        self.assertIn("dst.correction_reason=p_expected_reason", sql)
        self.assertIn("ctx.receipt_id IS NOT NULL", sql)
        self.assertIn("ctx.actor_id IS DISTINCT FROM p_actor", sql)
        self.assertIn("app_private.d1_roll_correct_result_rows_match_exact(", sql)
        self.assertIn("app_private.d1_roll_correct_reason_matches_exact(", sql)
        self.assertIn("'D1_STUDENT_ROLL_CORRECT'", sql)
        self.assertIn("'enrollment.roll_corrected'", sql)
        self.assertIn("TO schoolos_student_executor;", sql)
        self.assertIn("FROM PUBLIC,anon,authenticated,service_role;", sql)
        self.assertNotIn("CREATE FUNCTION app.", sql)
        self.assertNotIn("UPDATE app_private.operation_contracts", sql)
        self.assertNotIn("UPDATE app_private.roll_allocations", sql)
        self.assertNotIn("INSERT INTO app_private.roll_allocations", sql)
        self.assertNotIn("'old_numeric_value',old_num", sql)
        self.assertNotIn("'new_numeric_value',new_num", sql)

    def test_db01_direct_rpc_requires_frozen_source_p1_and_proven_receipt(self):
        sql = (runtime.ROOT / "supabase/migrations" / (
            "20260928000000_domain_package_01_effect41_07_db01_roll_correct_direct_handler.sql.draft"
        )).read_text(encoding="utf-8")
        self.assertEqual(sql.count("CREATE FUNCTION app.d1_correct_student_roll("), 1)
        self.assertIn("SET ROLE schoolos_student_executor;", sql)
        self.assertIn("SECURITY DEFINER SET search_path=pg_catalog,pg_temp", sql)
        for marker in (
            "app_private.d1_roll_correct_command_context(",
            "app_private.d1_lock_current_principal(ctx.actor_id)",
            "app_private.d1_roll_correct_authorized(",
            "app_private.d1_roll_correct_policy(",
            "route.route_mode IS DISTINCT FROM 'DIRECT'",
            "app_private.d1_roll_correct_lock_source(",
            "app_private.d1_roll_correct_effect(",
            "app_private.d1_roll_correct_direct_success_evidence(",
            "app_private.d1_roll_correct_direct_receipt_matches_exact(",
            "app_private.d1_roll_correct_reason_matches_exact(",
            "CROSS JOIN LATERAL app_private.d1_enrollment_place_destination(",
            "retained_enrollments<>discovered_enrollments",
            "student.roll_history.view",
            "TO authenticated;",
            "FROM PUBLIC,anon,authenticated,service_role;",
        ):
            self.assertIn(marker, sql)
        for forbidden in (
            "UPDATE app_private.operation_contracts",
            "UPDATE app_private.permissions",
            "INSERT INTO app_private.roll_allocations",
            "INSERT INTO app_private.command_receipts",
            "INSERT INTO app_private.outbox_events",
            "JOIN app_private.class_offerings",
            "JOIN app_private.section_offerings",
        ):
            self.assertNotIn(forbidden, sql)

    def test_db01_two_backend_protected_direct_races_run_last(self):
        race = runtime.ROOT / "tools/supabase/domain_db01_protected_direct_race_ci.py"
        sql = race.read_text(encoding="utf-8")
        compile(sql, str(race), "exec")
        driver = (runtime.ROOT / "tools/supabase/domain_local_ci.py").read_text(encoding="utf-8")
        self.assertLess(driver.index("run_db01_roll_correct_races(container, run_psql, ROOT)"),
                        driver.index("run_db01_protected_direct_races(container, run_psql)"))
        self.assertIn("D1_DB01_PROTECTED_DIRECT_DIFFERENT_KEYS_RACE_PASS", sql)
        self.assertIn("D1_DB01_PROTECTED_DIRECT_LOST_ACK_PASS", sql)
        self.assertIn("D1_DB01_PROTECTED_DIRECT_HISTORY_REVOCATION_PASS", sql)
        self.assertIn("D1_DB01_PROTECTED_DIRECT_AUTH_REVOCATION_RACE_PASS", sql)
        for marker in (
            "ThreadPoolExecutor(max_workers=1)", "_wait_for_block(",
            "pg_catalog.pg_blocking_pids", "pg_catalog.pg_advisory_xact_lock(71001,1)",
            "app.d1_correct_student_roll(", "app.d1_place_student_enrollment(",
            "D1_DB01_PROTECTED_DIRECT_LOCK_WAIT_NOT_OBSERVED",
            "schoolos_schema_owner", "SET ROLE authenticated",
        ):
            self.assertIn(marker, sql)
        self.assertNotIn("ALTER ROLE", sql)
        self.assertNotIn("GRANT EXECUTE", sql)
        self.assertNotIn("UPDATE app_private.roll_allocations", sql)
        self.assertNotIn("UPDATE app_private.students", sql)

    def test_db01_historic_replay_after_protected_move_end_is_real_pg_and_fail_closed(self):
        file = runtime.ROOT / "tools/supabase/domain_db01_replay_after_move_end_ci.py"
        trial = file.read_text(encoding="utf-8")
        compile(trial, str(file), "exec")
        driver = (runtime.ROOT / "tools/supabase/domain_local_ci.py").read_text(encoding="utf-8")
        self.assertLess(driver.index("run_db01_protected_direct_races(container, run_psql)"),
                        driver.index("run_db01_roll_replay_after_move_end(container, run_psql)"))
        for expected in (
            "app.d1_place_student_enrollment(",
            "app.d1_correct_student_roll(",
            "app.d1_move_student_enrollment(",
            "app.d1_end_student_enrollment(",
            "app_private.d1_roll_business_date(",
            "D1_DB01_REPLAY_AFTER_PROTECTED_MOVE_PASS",
            "D1_DB01_REPLAY_AFTER_PROTECTED_END_PASS",
            "D1_DB01_REPLAY_AFTER_MOVE_END_REVOKED_PASS",
            "schoolos_schema_owner",
            "Pacific/Kiritimati",
            "Etc/GMT+12",
            "student.roll_history.view",
            "MOVE_P1_ROUTE_NOT_DIRECT",
            "END_P1_ROUTE_NOT_DIRECT",
            "db01-historic-protected-move-direct",
            "db01-historic-protected-end-direct",
        ):
            self.assertIn(expected, trial)
        self.assertNotIn("INSERT INTO app_private.roll_allocations", trial)
        self.assertNotIn("UPDATE app_private.roll_allocations", trial)
        self.assertNotIn("UPDATE app_private.enrollments", trial)
        self.assertNotIn("GRANT EXECUTE", trial)
        self.assertNotIn("time.sleep(", trial)

    def test_db01_protected_correct_move_end_four_real_pg_races(self):
        file = runtime.ROOT / "tools/supabase/domain_db01_correct_vs_move_end_ci.py"
        source = file.read_text(encoding="utf-8")
        compile(source, str(file), "exec")
        driver = (runtime.ROOT / "tools/supabase/domain_local_ci.py").read_text(encoding="utf-8")
        self.assertLess(driver.index("run_db01_roll_replay_after_move_end(container, run_psql)"),
                        driver.index("run_db01_correct_vs_move_end_races(container, run_psql)"))
        for marker in (
            "CORRECT_OVER_MOVE", "MOVE_OVER_CORRECT",
            "CORRECT_OVER_END", "END_OVER_CORRECT",
            "D1_DB01_CORRECT_MOVE_END_FOUR_RACES_PASS",
            "app.d1_place_student_enrollment(",
            "app.d1_correct_student_roll(",
            "app.d1_move_student_enrollment(",
            "app.d1_end_student_enrollment(",
            "ThreadPoolExecutor(max_workers=1)",
            "pg_catalog.pg_blocking_pids(a.pid)",
            "D1_DB01_CORRECT_CROSS_OPERATION_WAIT_NOT_OBSERVED",
            "R0_NOT_CLOSED_",
            "LEDGER_OR_EVIDENCE_",
            "PROTECTED_CORRECT_DISABLED_IN_TEST",
            "SET ROLE authenticated",
        ):
            self.assertIn(marker, source)
        for forbidden in (
            "INSERT INTO app_private.roll_allocations",
            "UPDATE app_private.roll_allocations",
            "INSERT INTO app_private.enrollments",
            "UPDATE app_private.enrollments",
            "GRANT EXECUTE",
            "ALTER FUNCTION app.d1_correct_student_roll",
        ):
            self.assertNotIn(forbidden, source)

    def test_db01_replay_disclosure_scope_security_regressions(self):
        path = (runtime.ROOT / "supabase/tests/domain" /
                "88_db01_roll_correct_direct_authenticated.sql")
        suite = path.read_text(encoding="utf-8")
        self.assertIn("SELECT plan(48);", suite)
        self.assertEqual(sum(suite.count("SELECT " + name + "(") for name in
                             ("is", "ok", "throws_ok")), 48)
        for marker in (
            "SAVEPOINT db01_wrong_history_campus;",
            "SAVEPOINT db01_matching_history_campus;",
            "SAVEPOINT db01_disabled_history_contract;",
            "scope_kind='CAMPUS'",
            "WHERE code='student.roll_history.view'",
            "b1000000-0000-4000-8000-000000000071",
            "wrong Campus scope denies historical DIRECT receipt replay",
            "matching CAMPUS history scope replays only the original corrected R1",
            "disabled live history scope contract blocks immutable receipt replay",
            "broad Roll-corrected event discloses no numeric Roll or original reason",
            "broad correction audit discloses no numeric Roll or original reason",
            "all historical disclosure tests remain read-only for the corrected Student",
        ):
            self.assertIn(marker, suite)
        self.assertNotIn("UPDATE app_private.roll_allocations", suite)
        self.assertNotIn("UPDATE app_private.enrollments", suite)

    def test_db01_true_cross_campus_roll_history_replay_is_current_scope_only(self):
        path = runtime.ROOT / "tools/supabase/domain_db01_cross_campus_replay_ci.py"
        source = path.read_text(encoding="utf-8")
        compile(source, str(path), "exec")
        driver = (runtime.ROOT / "tools/supabase/domain_local_ci.py").read_text(encoding="utf-8")
        self.assertLess(driver.index("run_db01_correct_vs_move_end_races(container, run_psql)"),
                        driver.index("run_db01_cross_campus_roll_history_replay(container, run_psql)"))
        parent = (runtime.ROOT / "tools/supabase/domain_db01_replay_after_move_end_ci.py").read_text(encoding="utf-8")
        self.assertIn("app.d1_place_student_enrollment(", parent)
        self.assertIn("app.d1_correct_student_roll(", parent)
        for required in (
            "CAMPUS_TRANSFER", "app.d1_move_student_enrollment(",
            "SCHOOL, SOURCE, CLASS, _p0, _correct, _ledger",
            "_p0(actor,STUDENT,", "_correct(actor,STUDENT,",
            "D1_DB01_REAL_CROSS_CAMPUS_REPLAY_PASS",
            "D1_DB01_CROSS_CAMPUS_HISTORY_REVOKED_PASS",
            "SOURCE_CAMPUS_BEFORE_TRANSFER",
            "OLD_CAMPUS_SCOPE_AFTER_TRANSFER",
            "CURRENT_CAMPUS_B_AFTER_TRANSFER",
            "CURRENT_PRIMARY_NOT_ON_CAMPUS_B",
            "D1_DB01_CROSS_CAMPUS_HISTORY_SETUP",
            "student.roll_history.view", "scope_kind='CAMPUS'",
            "Pacific/Kiritimati", "Etc/GMT+12",
        ):
            self.assertIn(required, source)
        for forbidden in (
            "INSERT INTO app_private.roll_allocations",
            "UPDATE app_private.roll_allocations",
            "INSERT INTO app_private.enrollments",
            "UPDATE app_private.enrollments",
            "GRANT EXECUTE",
        ):
            self.assertNotIn(forbidden, source)

    def test_db01_p1_review_two_backend_race_only_after_prior_protected_races(self):
        source_path = runtime.ROOT / "tools/supabase/domain_db01_p1_review_race_ci.py"
        source = source_path.read_text(encoding="utf-8")
        compile(source, str(source_path), "exec")
        driver = (runtime.ROOT / "tools/supabase/domain_local_ci.py").read_text(encoding="utf-8")
        self.assertLess(driver.index("run_db01_cross_campus_roll_history_replay(container, run_psql)"),
                        driver.index("run_db01_p1_review_live_races(container, run_psql, ROOT)"))
        fixture = (runtime.ROOT /
                   "supabase/tests/domain/fixtures/db01_p1_review_two_backend_setup.sql").read_text(encoding="utf-8")
        for marker in ("SET ROLE authenticated;", "app.d1_place_student_enrollment(",
                       "app.d1_submit_student_roll_correction(", "D1_REVIEWER_ROLE_SCOPE",
                       "foundation-own-001@example.invalid", "\\gset submitted_"):
            self.assertIn(marker, fixture)
        for marker in ("_wait_for_block", "pg_advisory_xact_lock(71001,1)",
                       "app.d1_review_student_roll_correction(",
                       "D1_DB01_P1_REVIEW_REVIEW_REAL_PG_RACE_PASS",
                       "D1_DB01_P1_REVIEW_AUTH_REVOCATION_REAL_PG_RACE_PASS",
                       "D1_DB01_P1_REVIEW_RACES_PASS"):
            self.assertIn(marker, source)
        for forbidden in ("UPDATE app_private.roll_allocations", 
                          "INSERT INTO app_private.roll_allocations", "DROP TABLE",
                          "GRANT EXECUTE"):
            self.assertNotIn(forbidden, fixture)
        self.assertNotIn("pg_sleep", source)
        self.assertNotIn("SET ROLE service_role", source)

    def test_runtime_probe_drift_fails(self):
        observed = dict(runtime.EXPECTED_RUNTIME_METRICS)
        observed["authenticated_private_execute"] = 1
        with self.assertRaisesRegex(runtime.DomainLocalCIError, "RUNTIME_CATALOG_DRIFT"):
            runtime.validate_runtime_probe(observed)

    def test_foundation_catalog_runs_only_at_baseline(self):
        contract = {"frozen_foundation": {"database_tests": [
            {"file": "01_foundation_catalog.sql", "assertions": 44},
            {"file": "02_auth_helper_preflight.sql", "assertions": 5},
        ]}}
        with patch.object(runtime.subprocess, "run", return_value=CompletedProcess([], 0, "", "")) as command:
            with patch.object(runtime, "parse_tap", side_effect=lambda output, expected: expected):
                self.assertEqual(runtime.run_foundation_regression(contract, catalog_only=True), 44)
        self.assertEqual(command.call_count, 1)
        self.assertIn("01_foundation_catalog.sql", command.call_args.args[0][3])

    def test_foundation_behavior_runs_after_domain_without_catalog_snapshot(self):
        contract = {"frozen_foundation": {"database_tests": [
            {"file": "01_foundation_catalog.sql", "assertions": 44},
            {"file": "02_auth_helper_preflight.sql", "assertions": 5},
        ]}}
        with patch.object(runtime.subprocess, "run", return_value=CompletedProcess([], 0, "", "")) as command:
            with patch.object(runtime, "parse_tap", side_effect=lambda output, expected: expected):
                self.assertEqual(runtime.run_foundation_regression(contract), 5)
        self.assertEqual(command.call_count, 1)
        self.assertIn("02_auth_helper_preflight.sql", command.call_args.args[0][3])

    def test_local_lint_reports_errors_without_stderr_credentials(self):
        report = '[{"function":"app_private.example","issues":[{"level":"error","message":"bad column","sqlState":"42703"}]}]'
        with patch.object(runtime.subprocess, "run", return_value=CompletedProcess([], 1, report, "secret connection string")):
            with self.assertRaises(runtime.DomainLocalCIError) as caught:
                runtime.run_local_lint("error")
        self.assertIn("app_private.example", str(caught.exception))
        self.assertIn("bad column", str(caught.exception))
        self.assertNotIn("secret", str(caught.exception))

    def test_local_lint_passes_success(self):
        with patch.object(runtime.subprocess, "run", return_value=CompletedProcess([], 0, "[]", "")):
            runtime.run_local_lint("warning")

    def test_local_lint_rejects_invalid_level(self):
        with self.assertRaisesRegex(runtime.DomainLocalCIError, "LOCAL_LINT_LEVEL_INVALID"):
            runtime.run_local_lint("debug")

    def test_probe_parser_rejects_duplicates_and_nonintegers(self):
        with self.assertRaisesRegex(runtime.DomainLocalCIError, "RUNTIME_PROBE_MALFORMED"):
            runtime.parse_runtime_probe("d1_tables\t34\nd1_tables\t34\n")
        with self.assertRaisesRegex(runtime.DomainLocalCIError, "RUNTIME_PROBE_NONINTEGER"):
            runtime.parse_runtime_probe("d1_tables\tthirty-four\n")


if __name__ == "__main__":
    unittest.main()
