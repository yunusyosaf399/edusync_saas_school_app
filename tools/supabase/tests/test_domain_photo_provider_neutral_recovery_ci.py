"""Fail-closed source and portable SQLite provider tests; no hosted dependency."""
from pathlib import Path
from tempfile import TemporaryDirectory
from uuid import uuid4
import inspect
import sys
import unittest

ROOT=Path(__file__).resolve().parents[3]
sys.path.insert(0,str(ROOT/"tools/supabase"))
import domain_photo_provider_neutral_recovery_ci as trial
from domain_photo_postgres_native_intent_ci import NativeIntentDenied


class ProviderNeutralRecoveryCI(unittest.TestCase):
    def test_private_quarantined_pg_and_genuine_student_identity(self):
        sql=trial.SETUP_SQL
        for required in (
            "foundation-rbac-001@example.invalid",
            "request.jwt.claims",
            "tokens_valid_from",
            "SET ROLE schoolos_schema_owner",
            "INSERT INTO app_private.people(",
            "INSERT INTO app_private.students(",
            "INSERT INTO app_private.student_status_transitions(",
            "CREATE TABLE photo_pg_trial.provider_dispositions(",
            "FORCE ROW LEVEL SECURITY",
            "FROM PUBLIC,anon,authenticated,service_role",
            "REFERENCES photo_pg_trial.outbox_events(event_id)",
            "'CANCELLED'",
        ):
            self.assertIn(required,sql)
        for banned in (
            "INSERT INTO app_private.enrollments",
            "INSERT INTO app_private.roll_allocations",
            "UPDATE app_private.enrollments",
            "GRANT SELECT ON",
            "GRANT EXECUTE ON FUNCTION app.",
            "DISABLE ROW LEVEL SECURITY",
            "CREATE TABLE public.",
        ):
            self.assertNotIn(banned,sql)
        self.assertEqual(trial.CONTAINER,"supabase_db_saas_OS_school_app")

    def test_key_has_fixed_event_digest_and_action_not_bearer(self):
        event=str(uuid4())
        digest=b"a"*32
        key=trial._delivery_key(event,digest,"CONSUME")
        self.assertEqual(len(key),32)
        self.assertEqual(key,trial._delivery_key(event,digest,"CONSUME"))
        self.assertNotEqual(key,trial._delivery_key(event,digest,"FINALIZE_TRIAL"))
        self.assertNotEqual(key,trial._delivery_key(event,b"b"*32,"CONSUME"))
        self.assertNotEqual(key,trial._delivery_key(str(uuid4()),digest,"CONSUME"))
        with self.assertRaises(NativeIntentDenied):
            trial._delivery_key(event,b"short","CONSUME")

    def test_provider_is_separate_durable_no_byte_mock_ack_retry(self):
        event=str(uuid4())
        digest=b"c"*32
        key=trial._delivery_key(event,digest,"CONSUME")
        with TemporaryDirectory() as folder:
            path=Path(folder)/"provider.sqlite"
            provider=trial.MockMetadataProvider(path)
            with self.assertRaises(trial.ProviderReplyLost):
                provider.accept(event_id=event,key=key,token_digest=digest,
                                action="CONSUME",lose_response=True)
            # Different provider DB session, existing ACCEPTED row is durable.
            self.assertEqual(trial.MockMetadataProvider(path).state(event),"ACCEPTED")
            self.assertEqual(provider.accept(event_id=event,key=key,
                                             token_digest=digest,
                                             action="CONSUME"),event)
            self.assertEqual(provider.rows(),[(event,"ACCEPTED")])
            with self.assertRaises(NativeIntentDenied):
                provider.accept(event_id=event,key=key,
                                token_digest=b"d"*32,action="CONSUME")
            with self.assertRaises(trial.ProviderReplyLost):
                provider.void(event_id=event,key=key,token_digest=digest,
                              action="CONSUME",lose_response=True)
            self.assertEqual(trial.MockMetadataProvider(path).state(event),"VOIDED")
            self.assertEqual(provider.void(event_id=event,key=key,
                                           token_digest=digest,
                                           action="CONSUME"),event)
            self.assertEqual(len(provider.rows()),1)
            with self.assertRaises(NativeIntentDenied):
                provider.accept(event_id=event,key=key,token_digest=digest,
                                action="CONSUME")

    def test_pg_queue_rechecks_principal_before_remote_side_effect(self):
        src=inspect.getsource(trial.ProviderQueueWorker.deliver_one)
        for required in (
            "FOR UPDATE SKIP LOCKED LIMIT 1",
            "principal=self.store._authorized(cur)",
            "FROM photo_pg_trial.ack_receipts",
            "WHERE token_digest=%s FOR UPDATE",
            "self.provider.accept(",
            "INSERT INTO photo_pg_trial.provider_dispositions",
            "ON CONFLICT (event_id) DO NOTHING",
            "UPDATE photo_pg_trial.outbox_events",
            "if lose_db_reply:",
        ):
            self.assertIn(required,src)
        self.assertLess(src.index("FOR UPDATE SKIP LOCKED"),
                        src.index("principal=self.store._authorized(cur)"))
        self.assertLess(src.index("principal=self.store._authorized(cur)"),
                        src.index("self.provider.accept("))
        self.assertLess(src.index("self.provider.accept("),
                        src.index("UPDATE photo_pg_trial.outbox_events"))
        self.assertIn("with con:",src)
        self.assertNotIn("INSERT INTO app_private.enrollments",src)

    def test_real_end_compensation_after_authority_loss(self):
        src=inspect.getsource(trial.ProviderQueueWorker.cancel_ended)
        for required in (
            "FROM photo_pg_trial.outbox_events o",
            "FOR UPDATE OF o SKIP LOCKED LIMIT 1",
            "FROM app_private.enrollments e",
            "e.placement_kind='PRIMARY'",
            "if cur.fetchone()!=(0,):",
            "self.provider.void(",
            "VALUES (%s::uuid,%s,'CANCELLED')",
            "UPDATE photo_pg_trial.outbox_events",
            "with con:",
        ):
            self.assertIn(required,src)
        self.assertLess(src.index("if cur.fetchone()!=(0,):"),
                        src.index("self.provider.void("))
        self.assertLess(src.index("self.provider.void("),
                        src.index("UPDATE photo_pg_trial.outbox_events"))
        self.assertNotIn("UPDATE app_private.enrollments",src)

    def test_provider_outbox_is_student_scoped_against_prior_suite_events(self):
        source=inspect.getsource(trial._outbox_count)
        self.assertIn("JOIN photo_pg_trial.ack_receipts r",source)
        self.assertIn("WHERE r.student_id=%s::uuid",source)
        self.assertIn("(student,)",source)
        runtime=inspect.getsource(trial.run_photo_provider_neutral_recovery_trial)
        self.assertIn("_outbox_count(psycopg,STUDENT)==4",runtime)
        self.assertNotIn("_outbox_count(psycopg)==4",runtime)

    def test_full_runtime_markers_and_concurrent_worker_gate(self):
        src=inspect.getsource(trial.run_photo_provider_neutral_recovery_trial)
        for required in (
            "_p0_new_student(",
            "NativeAckOutboxTrial(",
            "provider.state(first)==\"ACCEPTED\"",
            "lose_provider_reply=True",
            "PROVIDER_REDELIVERY_DUPLICATED",
            "ThreadPoolExecutor(max_workers=2)",
            "PROVIDER_DOUBLE_CLAIM",
            "lose_db_reply=True",
            "app.d1_end_student_enrollment(",
            "_no_current_source(psycopg,STUDENT,None)",
            "PROVIDER_VOID_ACK_LOST_STATE",
            "provider.state(fourth)==\"VOIDED\"",
            "D1_STUDENT_PHOTO_PROVIDER_NEUTRAL_DELIVERY_PASS",
            "D1_STUDENT_PHOTO_PROVIDER_NEUTRAL_COMPENSATION_PASS",
        ):
            self.assertIn(required,src)
        self.assertLess(src.index("other.result(timeout=8)"),
                        src.index("release.set()"))
        self.assertLess(src.index("app.d1_end_student_enrollment("),
                        src.index("worker.cancel_ended(psycopg)"))
        runner=(ROOT/"tools/supabase/domain_student_photo_real_pg_handoff_ci.py").read_text()
        self.assertLess(runner.index("run_photo_native_lost_ack_outbox_trial("),
                        runner.index("run_photo_provider_neutral_recovery_trial("))
        with self.assertRaisesRegex(RuntimeError,
                                     "D1_PHOTO_PROVIDER_RECOVERY_DISPOSABLE_ONLY"):
            trial.run_photo_provider_neutral_recovery_trial(
                None,container="hosted",run_psql=None)


if __name__=="__main__":
    unittest.main()
