"""Real Ed25519 private-service signatures and local opaque Student intent tests.

All signers, Principals, school/Student bindings and timestamps are synthetic.
No actual file uploads, auth resolver, protected SQL or URLs are exercised.
"""
from __future__ import annotations

import base64
from contextlib import closing
import json
import multiprocessing
from pathlib import Path
import sqlite3
import sys
import tempfile
import unittest

from cryptography.hazmat.primitives import serialization
from cryptography.hazmat.primitives.asymmetric.ed25519 import Ed25519PrivateKey

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from student_photo_signed_entitlement_candidate import (
    CAPABILITY, SIGNING_CONTEXT, SignedSnapshotDenied,
)
from student_photo_durable_intent_candidate import (
    LocalPrivatePhotoIntentCandidate, PrivateIntentDenied,
    REQUEST_CONTEXT, token_hash,
)

SCHOOL = "school-A"
PROJECT = "project-A"
CONTROL_ISSUER = "trial-control"
SERVICE_ISSUER = "trial-private-service"
SERVICE_ID = "fileworker-student-photo"


def signed_control(key, *, revision=7, enabled=True, state="ACTIVE",
                   school=SCHOOL, project=PROJECT):
    payload = dict(
        schema_version=1, issuer=CONTROL_ISSUER,
        school_id=school, project_id=project, revision=revision,
        plan_definition_version="trial-plan-v1",
        capabilities={CAPABILITY: enabled}, subscription_state=state,
        issued_at=100, effective_at=110, expires_at=300,
    )
    return _sign(key, SIGNING_CONTEXT, payload, "control-key")


def _sign(key, context, payload, kid):
    protected = {"alg": "Ed25519", "kid": kid, "payload": payload}
    encoded = json.dumps(protected, sort_keys=True,
                         separators=(",", ":"), ensure_ascii=True).encode("ascii")
    sig = base64.b64encode(key.sign(context + encoded)).decode("ascii")
    return json.dumps({**protected, "signature": sig},
                      separators=(",", ":")).encode("utf-8")


def signed_service(key, *, stage="ISSUE", request_id="issue-1", now=150,
                   intent_hash_value=None, **changes):
    payload = dict(
        schema_version=1, issuer=SERVICE_ISSUER,
        service_id=SERVICE_ID, stage=stage, request_id=request_id,
        school_id=SCHOOL, project_id=PROJECT,
        student_id="student-A", campus_id="campus-A",
        principal_id="principal-A", purpose_code="STUDENT_PROFILE_PHOTO",
        principal_verified=True, file_upload_granted=True,
        photo_submit_granted=True, student_scope_verified=True,
        student_ownership_verified=True, module_enabled=True,
        registry_approved=True, issued_at=now - 1,
        expires_at=now + 15, intent_hash=intent_hash_value,
    )
    payload.update(changes)
    return _sign(key, REQUEST_CONTEXT, payload, "service-key")


def _two_process_consume(path, control_public, service_public, token,
                         signed_request, start, ready, result):
    try:
        store = LocalPrivatePhotoIntentCandidate(
            path, pinned_issuer=CONTROL_ISSUER,
            pinned_public_keys={"control-key": control_public},
            service_issuer=SERVICE_ISSUER, service_id=SERVICE_ID,
            service_public_keys={"service-key": service_public},
        )
        ready.put("READY")
        if not start.wait(timeout=8):
            result.put(("ERROR", "start timeout"))
            return
        rev = store.consume_trial(token, signed_request, now_epoch=160)
        result.put(("CONSUMED", rev))
    except PrivateIntentDenied:
        result.put(("DENIED", None))
    except Exception as exc:
        result.put(("ERROR", type(exc).__name__))


class LocalPrivatePhotoIntentTests(unittest.TestCase):
    def setUp(self):
        tmp = tempfile.TemporaryDirectory()
        self.addCleanup(tmp.cleanup)
        self.dbpath = str(Path(tmp.name) / "intents.sqlite")
        self.control_private = Ed25519PrivateKey.generate()
        self.service_private = Ed25519PrivateKey.generate()
        self.control_public = self.public(self.control_private)
        self.service_public = self.public(self.service_private)
        self.store = self.open_store()
        self.store.accept(
            signed_control(self.control_private), school=SCHOOL,
            project=PROJECT, now_epoch=150,
        )

    @staticmethod
    def public(key):
        return key.public_key().public_bytes(
            encoding=serialization.Encoding.Raw,
            format=serialization.PublicFormat.Raw,
        )

    def open_store(self):
        return LocalPrivatePhotoIntentCandidate(
            self.dbpath, pinned_issuer=CONTROL_ISSUER,
            pinned_public_keys={"control-key": self.control_public},
            service_issuer=SERVICE_ISSUER, service_id=SERVICE_ID,
            service_public_keys={"service-key": self.service_public},
        )

    def issue(self, **kw):
        return self.store.issue_trial(
            signed_service(self.service_private, **kw), now_epoch=150,
        )

    def consume(self, token, *, store=None, now=160, request_id="consume-1", **kw):
        return (store or self.store).consume_trial(
            token, signed_service(
                self.service_private, stage="CONSUME", request_id=request_id,
                now=now, intent_hash_value=token_hash(token), **kw,
            ),
            now_epoch=now,
        )

    def ledger(self):
        with closing(sqlite3.connect(self.dbpath)) as db:
            intents = db.execute("""SELECT student,campus,principal,
                issued_revision,status,consumed_revision
                FROM photo_private_trial_intents ORDER BY rowid""").fetchall()
            events = db.execute("""SELECT kind,revision
                FROM photo_private_trial_events ORDER BY rowid""").fetchall()
            nonce_count = db.execute(
                "SELECT count(*) FROM photo_private_trial_nonces").fetchone()[0]
        return intents, events, nonce_count

    def test_opaque_token_persists_only_hash_and_can_consume_after_reopen(self):
        token = self.issue()
        self.assertTrue(token.startswith("photo_trial_v1_"))
        self.assertEqual(len(token_hash(token)), 64)
        with closing(sqlite3.connect(self.dbpath)) as db:
            dump = "\n".join(db.iterdump())
        self.assertNotIn(token, dump)
        self.assertIn(token_hash(token), dump)
        self.assertEqual(self.consume(token, store=self.open_store()), 7)
        self.assertEqual(self.ledger(), (
            [("student-A", "campus-A", "principal-A", 7, "CONSUMED", 7)],
            [("ISSUE", 7), ("CONSUME", 7)], 2,
        ))

    def test_one_time_consumption_and_signed_request_nonce_replay_closed(self):
        token = self.issue()
        self.assertEqual(self.consume(token), 7)
        with self.assertRaises(PrivateIntentDenied):
            self.consume(token, request_id="consume-2")
        with self.assertRaises(PrivateIntentDenied):
            self.issue(request_id="issue-1")
        self.assertEqual(self.ledger()[1], [("ISSUE", 7), ("CONSUME", 7)])
        self.assertEqual(self.ledger()[2], 2)

    def test_false_or_unsigned_service_proof_never_mints(self):
        for field, bad in (
            ("principal_verified", False), ("photo_submit_granted", False),
            ("student_scope_verified", False),
            ("student_ownership_verified", False),
            ("file_upload_granted", False), ("module_enabled", False),
            ("registry_approved", False), ("principal_verified", "true"),
            ("purpose_code", "BIRTH_CERTIFICATE"),
            ("service_id", "other-worker"), ("issuer", "other-control"),
            ("schema_version", 2), ("student_id", ""),
        ):
            with self.subTest(field=field, bad=bad):
                proof = signed_service(self.service_private, **{field: bad})
                with self.assertRaises(PrivateIntentDenied):
                    self.store.issue_trial(proof, now_epoch=150)
        self.assertEqual(self.ledger()[0], [])

    def test_signature_tampering_wrong_key_and_malformed_envelope(self):
        authentic = signed_service(self.service_private)
        altered = json.loads(authentic)
        altered["payload"]["student_id"] = "student-B"
        invalid = [
            json.dumps(altered).encode("utf-8"),
            signed_service(Ed25519PrivateKey.generate()),
            b"{}", b"not-json", authentic+b" garbage",
            authentic.replace(b'"alg":', b'"alg":"none","alg":', 1),
            authentic.replace(b'"student_id":', b'"student_id":"wrong","student_id":', 1),
            authentic.replace(b'"signature":', b'"signature":"broken","signature":', 1),
        ]
        for raw in invalid:
            with self.subTest(length=len(raw)), self.assertRaises(PrivateIntentDenied):
                self.store.issue_trial(raw, now_epoch=150)
        self.assertEqual(self.ledger()[0], [])

    def test_cross_student_campus_school_project_and_principal_consume_denied(self):
        token = self.issue()
        for change in (
            {"student_id": "student-B"}, {"campus_id": "campus-B"},
            {"school_id": "school-B"}, {"project_id": "project-B"},
            {"principal_id": "principal-B"},
        ):
            with self.subTest(change=change), self.assertRaises(PrivateIntentDenied):
                self.consume(token, request_id="attempt-"+next(iter(change)), **change)
        self.assertEqual(self.ledger()[1], [("ISSUE", 7)])
        self.assertEqual(self.consume(token), 7)

    def test_cross_token_signed_binding_rejected(self):
        token_a = self.issue()
        token_b = self.issue(request_id="issue-2")
        signed_for_a = signed_service(
            self.service_private, stage="CONSUME", request_id="consume-b",
            now=160, intent_hash_value=token_hash(token_a),
        )
        with self.assertRaises(PrivateIntentDenied):
            self.store.consume_trial(token_b, signed_for_a, now_epoch=160)
        self.assertEqual(self.consume(token_a), 7)
        self.assertEqual(self.consume(token_b, request_id="consume-2"), 7)

    def test_signed_downgrade_suspension_blocks_existing_intent(self):
        token = self.issue()
        self.store.accept(
            signed_control(self.control_private, revision=8, enabled=False),
            school=SCHOOL, project=PROJECT, now_epoch=155,
        )
        with self.assertRaises(PrivateIntentDenied):
            self.consume(token)
        with self.assertRaises(SignedSnapshotDenied):
            self.open_store().accept(
                signed_control(self.control_private, revision=7),
                school=SCHOOL, project=PROJECT, now_epoch=160,
            )
        self.assertEqual(self.ledger()[0][0][4], "ISSUED")
        self.assertEqual(self.ledger()[1], [("ISSUE", 7)])

    def test_invalidation_and_later_signed_reactivation(self):
        token = self.issue()
        self.store.invalidate(school=SCHOOL, project=PROJECT, now_epoch=155)
        with self.assertRaises(PrivateIntentDenied):
            self.consume(token)
        self.open_store().accept(
            signed_control(self.control_private, revision=8),
            school=SCHOOL, project=PROJECT, now_epoch=160,
        )
        self.assertEqual(self.consume(token), 8)

    def test_intent_expiry_snapshot_staleness_and_absent_entitlement(self):
        token = self.issue()
        with self.assertRaises(PrivateIntentDenied):
            self.consume(token, now=190)  # Intent expiry is exclusive.
        with self.assertRaises(PrivateIntentDenied):
            self.store.issue_trial(signed_service(self.service_private,
                                  now=210, request_id="stale-issue"), now_epoch=210)
        self.assertEqual(self.ledger()[0][0][4], "ISSUED")

    def test_tampered_token_and_wrong_stage_rejected(self):
        token = self.issue()
        with self.assertRaises(PrivateIntentDenied):
            self.store.consume_trial(token+"A", b"{}", now_epoch=160)
        with self.assertRaises(PrivateIntentDenied):
            self.store.consume_trial(token, signed_service(self.service_private,
                                     stage="ISSUE"), now_epoch=160)
        with self.assertRaises(PrivateIntentDenied):
            self.store.issue_trial(signed_service(
                self.service_private, stage="CONSUME", request_id="forged",
                intent_hash_value=token_hash(token)), now_epoch=150)
        self.assertEqual(self.consume(token), 7)

    def test_two_spawned_processes_can_consume_at_most_once(self):
        token = self.issue()
        ctx = multiprocessing.get_context("spawn")
        start = ctx.Event()
        ready = ctx.Queue()
        result = ctx.Queue()
        processes = []
        try:
            for nonce in ("consume-a", "consume-b"):
                signed_req = signed_service(
                    self.service_private, stage="CONSUME",
                    request_id=nonce, now=160,
                    intent_hash_value=token_hash(token),
                )
                proc = ctx.Process(
                    target=_two_process_consume,
                    args=(self.dbpath, self.control_public,
                          self.service_public, token, signed_req,
                          start, ready, result),
                )
                proc.start()
                processes.append(proc)
            self.assertEqual(ready.get(timeout=8), "READY")
            self.assertEqual(ready.get(timeout=8), "READY")
            start.set()
            outcomes = [result.get(timeout=8), result.get(timeout=8)]
        finally:
            start.set()
            for proc in processes:
                proc.join(timeout=10)
                if proc.is_alive():
                    proc.terminate()
                    proc.join(timeout=3)
        self.assertEqual([p.exitcode for p in processes], [0, 0])
        self.assertEqual(sorted(outcomes), [("CONSUMED", 7), ("DENIED", None)])
        self.assertEqual(self.ledger()[1], [("ISSUE", 7), ("CONSUME", 7)])
        self.assertEqual(self.ledger()[2], 2)


if __name__ == "__main__":
    unittest.main()
