"""Fail-closed guards for local-only committed-but-lost ACK + PostgreSQL outbox."""
from pathlib import Path
import inspect
import sys
import unittest

ROOT=Path(__file__).resolve().parents[3]
sys.path.insert(0,str(ROOT/"tools/supabase"))
import domain_photo_pg_lost_ack_outbox_ci as trial


class PhotoPgLostAckOutboxStaticCI(unittest.TestCase):
    def test_quarantined_sql_schema_rls_and_no_client_or_media(self):
        sql=trial.SETUP_SQL
        self.assertTrue(sql.startswith("\nBEGIN;"))
        self.assertTrue(sql.rstrip().endswith("COMMIT;"))
        for name in ("ack_receipts","outbox_events","mock_sink"):
            self.assertIn("CREATE TABLE photo_pg_trial."+name,sql)
            self.assertIn("ALTER TABLE photo_pg_trial."+name+" FORCE ROW LEVEL SECURITY",sql)
        self.assertIn("SET ROLE schoolos_student_executor",sql)
        self.assertIn("foundation-rbac-001@example.invalid",sql)
        self.assertIn("request.jwt.claims",sql)
        self.assertIn("tokens_valid_from",sql)
        self.assertIn("FROM PUBLIC,anon,authenticated,service_role",sql)
        self.assertIn("event_id uuid NOT NULL UNIQUE",sql)
        self.assertIn("event_id uuid PRIMARY KEY",sql)
        self.assertIn("UNIQUE (token_digest,action)",sql)
        for dangerous in ("INSERT INTO app_private.enrollments",
                          "INSERT INTO app_private.roll_allocations",
                          "UPDATE app_private.enrollments",
                          "GRANT SELECT ON photo_pg_trial.",
                          "GRANT EXECUTE ON FUNCTION app.",
                          "DISABLE ROW LEVEL SECURITY",
                          "CREATE TABLE public."):
            self.assertNotIn(dangerous,sql)
        source=inspect.getsource(trial)
        self.assertNotIn("storage.objects",source)
        self.assertNotIn("File AVAILABLE",sql)

    def test_real_p0_and_stable_idempotency_identity(self):
        sql=inspect.getsource(trial.run_photo_native_lost_ack_outbox_trial)
        self.assertIn("_p0_new_student(psycopg,STUDENT",sql)
        self.assertIn("store.issue()",sql)
        self.assertIn("_assert_private(psycopg)",sql)
        ident=inspect.getsource(trial._request_digest)
        for code in ("UUID(request_id)","uuid.version!=4",
                     "str(uuid)!=request_id","sha256("):
            self.assertIn(code,ident)
        self.assertNotIn("token",ident)

    def test_token_state_receipt_outbox_single_transaction(self):
        source=inspect.getsource(trial.NativeAckOutboxTrial.apply)
        for required in (
            "with con:",
            "principal=self.store._authorized(cur)",
            "WHERE request_digest=%s FOR UPDATE",
            "FROM photo_pg_trial.intents ",
            "WHERE token_digest=%s FOR UPDATE",
            "UPDATE photo_pg_trial.intents SET status=%s",
            "INSERT INTO photo_pg_trial.ack_receipts ",
            "INSERT INTO photo_pg_trial.outbox_events ",
            "if lose_ack:",
            "_deny()",
        ):
            self.assertIn(required,source)
        self.assertLess(source.index("self.store._authorized(cur)"),
                        source.index("INSERT INTO photo_pg_trial.ack_receipts"))
        self.assertLess(source.index("INSERT INTO photo_pg_trial.ack_receipts"),
                        source.index("INSERT INTO photo_pg_trial.outbox_events"))
        self.assertLess(source.index("INSERT INTO photo_pg_trial.outbox_events"),
                        source.index("if lose_ack:"))
        self.assertNotIn("ON CONFLICT DO UPDATE",source)

    def test_queue_is_synthetic_durable_and_two_worker_safe(self):
        source=inspect.getsource(trial.NativeAckOutboxTrial.deliver_one)
        for required in (
            "WHERE delivery_state='PENDING'",
            "FOR UPDATE SKIP LOCKED LIMIT 1",
            "INSERT INTO photo_pg_trial.mock_sink ",
            "ON CONFLICT (event_id) DO NOTHING",
            "WHERE event_id=%s::uuid",
            "UPDATE photo_pg_trial.outbox_events ",
            "SET delivery_state='DELIVERED'",
            "if fail_before_commit:",
            "if lose_ack:",
        ):
            self.assertIn(required,source)
        self.assertLess(source.index("INSERT INTO photo_pg_trial.mock_sink"),
                        source.index("UPDATE photo_pg_trial.outbox_events"))
        self.assertLess(source.index("UPDATE photo_pg_trial.outbox_events"),
                        source.index("if fail_before_commit:"))
        self.assertIn("with con:",source)

    def test_lost_ack_retries_and_post_ack_replay_evidence(self):
        run=inspect.getsource(trial.run_photo_native_lost_ack_outbox_trial)
        for required in (
            'request_id=consume_request,lose_ack=True',
            'request_id=finalize_request,lose_ack=True',
            "ACK_REPLAY_SIDE_EFFECT",
            "CONSUME_RECEIPT_OUTBOX_NOT_ATOMIC",
            "FINALIZE_RECEIPT_OUTBOX_NOT_ATOMIC",
            "OUTBOX_PRECOMMIT_ABORT_WAS_VISIBLE",
            "OUTBOX_DOUBLE_CLAIM",
            "OUTBOX_DELIVERY_ACK_LOST_DID_NOT_COMMIT",
            "OUTBOX_DUPLICATED_SINK_EFFECT",
            "ThreadPoolExecutor(max_workers=2)",
            "D1_STUDENT_PHOTO_PG_LOST_ACK_RECEIPT_PASS",
            "D1_STUDENT_PHOTO_PG_DURABLE_OUTBOX_TRIAL_PASS",
        ):
            self.assertIn(required,run)
        self.assertLess(run.index("other.result(timeout=8)"),
                        run.index("release.set()"))
        self.assertIn("InsufficientPrivilege",inspect.getsource(trial._assert_private))

    def test_wired_last_and_disposable_only(self):
        runner=(ROOT/"tools/supabase/domain_student_photo_real_pg_handoff_ci.py").read_text()
        self.assertLess(runner.index("run_photo_consume_first_transfer_backend_retry("),
                        runner.index("run_photo_native_lost_ack_outbox_trial("))
        with self.assertRaisesRegex(RuntimeError,"D1_PHOTO_ACK_OUTBOX_DISPOSABLE_ONLY"):
            trial.run_photo_native_lost_ack_outbox_trial(
                None,container="hosted",run_psql=None)
        with self.assertRaises(trial.NativeIntentDenied):
            trial._request_digest("not-a-uuid")
        with self.assertRaises(trial.NativeIntentDenied):
            trial._request_digest(str(__import__("uuid").uuid1()))


if __name__=="__main__":
    unittest.main()
