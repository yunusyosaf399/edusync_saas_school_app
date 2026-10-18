"""PostgreSQL DB-API seam vs signed SQLite ledger, LOCAL SIMULATION ONLY.

These DB connections are deliberately synthetic. Separately frozen PR #92
exercises the actual SQL private resolver against authenticated local Postgres;
this suite tests a *proposed handoff*, NOT actual end-to-end two-DB atomicity.
"""
from __future__ import annotations

from contextlib import closing
from pathlib import Path
import sqlite3
import sys
import tempfile
import unittest

from cryptography.hazmat.primitives import serialization
from cryptography.hazmat.primitives.asymmetric.ed25519 import Ed25519PrivateKey

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
sys.path.insert(0, str(Path(__file__).resolve().parent))

from test_student_photo_durable_intent_candidate import (
    SCHOOL, PROJECT, CONTROL_ISSUER, SERVICE_ISSUER, SERVICE_ID,
    signed_control, signed_service,
)
from student_photo_durable_intent_candidate import (
    PrivateIntentDenied, token_hash,
)
from student_photo_postgres_verified_handoff_candidate import (
    LocalPostgresPhotoHandoffTrial,
)

STUDENT = "b1000000-0000-4000-8000-000000000001"
CAMPUS_A = "b1000000-0000-4000-8000-000000000041"
CAMPUS_B = "d2000000-0000-4000-8000-000000000041"
PRINCIPAL_A = "55555555-5555-4555-8555-555555555555"
PRINCIPAL_B = "d2000000-0000-4000-8000-000000000055"


class FakePrivatePgSession:
    """Only a DB-API test double; not a production actor authenticator."""

    def __init__(self):
        self.student = STUDENT
        self.campus = CAMPUS_A
        self.principal = PRINCIPAL_A
        self.granted = True
        self.pg_failure = False
        self.pg_nonboolean = None
        self.open_transactions = 0
        self.finished_transactions = 0
        self.queries = []
        self.connections = []
        self.on_resolve = None

    def connect(self):
        if self.pg_failure:
            raise OSError("synthetic PostgreSQL offline")
        c = FakeConnection(self)
        self.connections.append(c)
        return c


class FakeConnection:
    def __init__(self, state):
        self.state = state
        self.in_tx = False
        self.closed = False

    def __enter__(self):
        assert not self.in_tx
        self.in_tx = True
        self.state.open_transactions += 1
        return self

    def __exit__(self, typ, val, tb):
        assert self.in_tx
        self.in_tx = False
        self.state.open_transactions -= 1
        self.state.finished_transactions += 1

    def close(self):
        self.closed = True

    def cursor(self):
        assert self.in_tx
        return FakeCursor(self)


class FakeCursor:
    def __init__(self, conn):
        self.conn = conn
        self.query = None
        self.parameters = None

    def execute(self, statement, parameters=None):
        assert self.conn.in_tx
        self.conn.state.queries.append((statement, parameters))
        if statement == "SELECT app_private.current_principal_id()":
            assert parameters is None
            self.query = "PRINCIPAL"
        elif statement == (
            "SELECT app_private.d1_student_photo_private_issue_resolver_trial(%s::uuid,%s::uuid)"
        ):
            assert type(parameters) is tuple and len(parameters) == 2
            self.parameters = parameters
            self.query = "RESOLVER"
            if self.conn.state.on_resolve is not None:
                self.conn.state.on_resolve()
        else:
            raise RuntimeError("unexpected private SQL")

    def fetchone(self):
        assert self.conn.in_tx
        if self.query == "PRINCIPAL":
            if self.conn.state.principal is None:
                return (None,)
            return (self.conn.state.principal,)
        if self.query == "RESOLVER":
            if self.conn.state.pg_nonboolean is not None:
                return (self.conn.state.pg_nonboolean,)
            s, c = self.parameters
            return (self.conn.state.granted and s == self.conn.state.student
                    and c == self.conn.state.campus,)
        raise RuntimeError("missing SQL")

    def close(self):
        pass


class StudentPhotoPostgresVerifiedHandoffTests(unittest.TestCase):
    def setUp(self):
        tmp = tempfile.TemporaryDirectory()
        self.addCleanup(tmp.cleanup)
        self.path = str(Path(tmp.name) / "photo.sqlite")
        self.control_private = Ed25519PrivateKey.generate()
        self.service_private = Ed25519PrivateKey.generate()
        self.state = FakePrivatePgSession()
        self.store = self.make_store()
        self.store.accept(signed_control(self.control_private),
                          school=SCHOOL, project=PROJECT, now_epoch=150)

    @staticmethod
    def public(key):
        return key.public_key().public_bytes(
            encoding=serialization.Encoding.Raw,
            format=serialization.PublicFormat.Raw,
        )

    def make_store(self, **changes):
        args = dict(
            pinned_issuer=CONTROL_ISSUER,
            pinned_public_keys={"control-key": self.public(self.control_private)},
            service_issuer=SERVICE_ISSUER, service_id=SERVICE_ID,
            service_public_keys={"service-key": self.public(self.service_private)},
            db_connect=self.state.connect, signer=self.service_private,
            signing_kid="service-key", school_id=SCHOOL, project_id=PROJECT,
            trial_file_upload_enabled=True, trial_module_enabled=True,
            trial_purpose_approved=True,
        )
        args.update(changes)
        return LocalPostgresPhotoHandoffTrial(self.path, **args)

    def issue(self, **kw):
        return self.store.issue_verified_trial(student_id=STUDENT,
                  campus_id=CAMPUS_A, now_epoch=150, **kw)

    def consume(self, token, **kw):
        return self.store.consume_verified_trial(
            token, student_id=STUDENT, campus_id=CAMPUS_A, now_epoch=160, **kw)

    def persisted(self):
        with closing(sqlite3.connect(self.path)) as db:
            intents = db.execute("""SELECT principal,student,campus,status,
                consumed_revision FROM photo_private_trial_intents""").fetchall()
            events = db.execute("""SELECT kind,revision
                FROM photo_private_trial_events ORDER BY rowid""").fetchall()
        return intents, events

    def test_verified_pg_context_signs_exact_db_principal_then_consumes(self):
        token = self.issue()
        self.assertTrue(token.startswith("photo_trial_v1_"))
        self.assertNotIn(token, repr(self.persisted()))
        self.assertEqual(self.consume(token), 7)
        self.assertEqual(self.persisted(), (
            [(PRINCIPAL_A, STUDENT, CAMPUS_A, "CONSUMED", 7)],
            [("ISSUE", 7), ("CONSUME", 7)]))
        self.assertEqual(self.state.open_transactions, 0)
        self.assertEqual(self.state.finished_transactions, 2)
        self.assertEqual(len(self.state.queries), 4)
        self.assertTrue(all(c.closed for c in self.state.connections))

    def test_revoked_permission_after_issue_fails_before_ledger_mutation(self):
        token = self.issue()
        self.state.granted = False
        with self.assertRaises(PrivateIntentDenied):
            self.consume(token)
        self.assertEqual(self.persisted()[0][0][3], "ISSUED")
        self.assertEqual(self.persisted()[1], [("ISSUE", 7)])
        self.state.granted = True
        self.assertEqual(self.consume(token), 7)

    def test_relocated_student_rejects_old_and_new_campus_binding(self):
        token = self.issue()
        self.state.campus = CAMPUS_B
        with self.assertRaises(PrivateIntentDenied):
            self.consume(token)
        with self.assertRaises(PrivateIntentDenied):
            self.store.consume_verified_trial(token, student_id=STUDENT,
                                              campus_id=CAMPUS_B, now_epoch=160)
        self.assertEqual(self.persisted()[1], [("ISSUE", 7)])

    def test_changed_authenticated_principal_cannot_consume_prior_intent(self):
        token = self.issue()
        self.state.principal = PRINCIPAL_B
        with self.assertRaises(PrivateIntentDenied):
            self.consume(token)
        self.assertEqual(self.persisted()[0][0][3], "ISSUED")
        self.state.principal = PRINCIPAL_A
        self.assertEqual(self.consume(token), 7)

    def test_direct_signed_true_bypass_is_forbidden(self):
        malicious = signed_service(self.service_private)
        with self.assertRaises(PrivateIntentDenied):
            self.store.issue_trial(malicious, now_epoch=150)
        token = self.issue()
        with self.assertRaises(PrivateIntentDenied):
            self.store.consume_trial(
                token, signed_service(
                    self.service_private, stage="CONSUME",
                    intent_hash_value=token_hash(token), now=160,
                ), now_epoch=160)
        self.assertEqual(self.persisted()[1], [("ISSUE", 7)])

    def test_pg_failure_missing_principal_and_nonboolean_result_fail_closed(self):
        for mode in ("connection", "none-principal", "str-true"):
            with self.subTest(mode=mode):
                self.state.pg_failure = mode == "connection"
                self.state.principal = None if mode == "none-principal" else PRINCIPAL_A
                self.state.pg_nonboolean = "true" if mode == "str-true" else None
                with self.assertRaises(PrivateIntentDenied):
                    self.issue()
        self.assertEqual(self.persisted(), ([], []))
        self.assertEqual(self.state.open_transactions, 0)

    def test_bad_uuid_and_wrong_student_do_not_mint_intent(self):
        for student, campus in (
            ("student-A", CAMPUS_A), (STUDENT.upper(), CAMPUS_A),
            (STUDENT, "campus-A"), ("b1000000-0000-4000-8000-000000000099", CAMPUS_A),
            (STUDENT, CAMPUS_B),
        ):
            with self.subTest(student=student,campus=campus), self.assertRaises(PrivateIntentDenied):
                self.store.issue_verified_trial(
                    student_id=student, campus_id=campus, now_epoch=150)
        self.assertEqual(self.persisted(), ([], []))

    def test_trial_operator_policy_flags_required_both_phases(self):
        for change in (
            {"trial_file_upload_enabled": False},
            {"trial_module_enabled": False},
            {"trial_purpose_approved": False},
        ):
            with self.subTest(change=change):
                store = self.make_store(**change)
                with self.assertRaises(PrivateIntentDenied):
                    store.issue_verified_trial(
                        student_id=STUDENT,campus_id=CAMPUS_A,now_epoch=150)
        token = self.issue()
        invalid = self.make_store(trial_file_upload_enabled=False)
        with self.assertRaises(PrivateIntentDenied):
            invalid.consume_verified_trial(
                token, student_id=STUDENT,campus_id=CAMPUS_A,now_epoch=160)
        self.assertEqual(self.persisted()[1], [("ISSUE", 7)])

    def test_signed_entitlement_revocation_denies_even_pg_auth_is_true(self):
        token = self.issue()
        self.store.accept(
            signed_control(self.control_private, revision=8, enabled=False),
            school=SCHOOL, project=PROJECT, now_epoch=155,
        )
        with self.assertRaises(PrivateIntentDenied):
            self.consume(token)
        self.assertEqual(self.persisted()[1], [("ISSUE", 7)])

    def test_reopened_worker_can_consume_once_but_replay_is_denied(self):
        token = self.issue()
        second = self.make_store()
        self.assertEqual(second.consume_verified_trial(
            token, student_id=STUDENT,campus_id=CAMPUS_A,now_epoch=160), 7)
        with self.assertRaises(PrivateIntentDenied):
            self.consume(token)
        self.assertEqual(self.persisted()[1], [("ISSUE", 7),("CONSUME", 7)])

    def test_pg_authorization_transaction_is_open_at_sqlite_commit(self):
        token = self.issue()
        # At the time SQLite writes the CONSUMED row, the independent PG
        # transaction remains open, mimicking a held shared grant lock.
        seen = []
        original = self.store._nonce_under_lock
        def inspect(db, data):
            if data["stage"] == "CONSUME":
                seen.append(self.state.open_transactions)
            return original(db,data)
        self.store._nonce_under_lock = inspect
        self.assertEqual(self.consume(token), 7)
        self.assertEqual(seen, [1])
        self.assertEqual(self.state.open_transactions, 0)

if __name__ == "__main__":
    unittest.main()
