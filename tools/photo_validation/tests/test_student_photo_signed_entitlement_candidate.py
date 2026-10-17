"""Genuine in-memory Ed25519 signatures and file-backed SQLite regressions.

Private keys exist ONLY inside these disposable tests; never store them.
"""
import base64
from concurrent.futures import ThreadPoolExecutor
from contextlib import closing
import json
from pathlib import Path
import sqlite3
import sys
import tempfile
import unittest

from cryptography.hazmat.primitives import serialization
from cryptography.hazmat.primitives.asymmetric.ed25519 import Ed25519PrivateKey

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from student_photo_signed_entitlement_candidate import (
    ALGORITHM, CAPABILITY, SIGNING_CONTEXT,
    LocalSignedPhotoSnapshotCandidate, SignedSnapshotDenied,
)

ISSUER = "edusync-test-control-plane"
SCHOOL = "school-A"
PROJECT = "project-A"


def payload(**changes):
    p = dict(
        schema_version=1, issuer=ISSUER, school_id=SCHOOL, project_id=PROJECT,
        revision=7, plan_definition_version="plan-release-3",
        capabilities={CAPABILITY: True}, subscription_state="ACTIVE",
        issued_at=100, effective_at=110, expires_at=300,
    )
    p.update(changes)
    return p


def signed(key, p=None, *, alg=ALGORITHM, kid="test-key-1"):
    protected = {"alg": alg, "kid": kid, "payload": payload() if p is None else p}
    content = json.dumps(protected, sort_keys=True, separators=(",", ":"),
                         ensure_ascii=True, allow_nan=False).encode("ascii")
    signature = base64.b64encode(key.sign(SIGNING_CONTEXT + content)).decode("ascii")
    return json.dumps({**protected, "signature": signature},
                      separators=(",", ":")).encode("utf-8")


class SignedPhotoSnapshotTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.path = str(Path(self.tmp.name) / "entitlement.sqlite")
        self.private = Ed25519PrivateKey.generate()
        self.public = self.private.public_key().public_bytes(
            encoding=serialization.Encoding.Raw,
            format=serialization.PublicFormat.Raw)
        self.store = self.open_store()

    def open_store(self):
        return LocalSignedPhotoSnapshotCandidate(
            self.path, pinned_issuer=ISSUER,
            pinned_public_keys={"test-key-1": self.public})

    def accept(self, p=None, now=150, *, raw=None, school=SCHOOL, project=PROJECT, store=None):
        (store or self.store).accept(
            signed(self.private, p) if raw is None else raw,
            school=school, project=project, now_epoch=now)

    def current(self, now=150, *, school=SCHOOL, project=PROJECT, store=None):
        return (store or self.store).require_current(
            school=school, project=project, now_epoch=now)

    def denied(self, func, *args, **kwargs):
        with self.assertRaisesRegex(
                SignedSnapshotDenied, "^PHOTO_SIGNED_ENTITLEMENT_DENIED$"):
            func(*args, **kwargs)

    def test_real_signature_acceptance_and_reopen_shared_local_file(self):
        self.assertIsNone(self.accept())
        self.assertIsNone(self.current())
        another_process_surrogate = self.open_store()
        self.assertIsNone(self.current(store=another_process_surrogate))
        self.denied(self.current, school="school-B")
        self.denied(self.current, project="project-B")
        with closing(sqlite3.connect(self.path)) as db:
            rows = db.execute("SELECT revision, enabled FROM photo_snapshots").fetchall()
            events = db.execute("SELECT event_type FROM photo_revision_events").fetchall()
        self.assertEqual(rows, [(7, 1)])
        self.assertEqual(events, [("ACCEPT",)])

    def test_signature_tampering_wrong_key_algorithm_kid_and_invalid_encoding(self):
        genuine = signed(self.private)
        tampered = json.loads(genuine)
        tampered["payload"]["capabilities"][CAPABILITY] = False
        self.denied(self.accept, raw=json.dumps(tampered).encode())
        self.denied(self.accept, raw=signed(Ed25519PrivateKey.generate()))
        self.denied(self.accept, raw=signed(self.private, alg="none"))
        self.denied(self.accept, raw=signed(self.private, kid="unknown"))
        tampered = json.loads(genuine)
        tampered["signature"] = "not::base64"
        self.denied(self.accept, raw=json.dumps(tampered).encode())
        self.denied(self.accept, raw=genuine+b" garbage")
        self.denied(self.accept, raw=b"a"*8193)
        self.denied(self.current)

    def test_duplicate_json_fields_and_unsigned_extras_rejected(self):
        legitimate = signed(self.private)
        data = legitimate.decode("utf-8")
        self.denied(self.accept, raw=data.replace('"alg":', '"alg":"none","alg":', 1).encode())
        self.denied(self.accept, raw=data.replace('"revision":7', '"revision":6,"revision":7', 1).encode())
        bad = json.loads(legitimate)
        bad["extra"] = "not-signed"
        self.denied(self.accept, raw=json.dumps(bad).encode())

    def test_tenant_issuer_schema_and_strict_capability_types(self):
        for change in (
            {"school_id": "school-B"}, {"project_id": "project-B"},
            {"issuer": "unknown"}, {"schema_version": 2},
            {"schema_version": True}, {"revision": True},
            {"revision": 0}, {"revision": -1},
            {"plan_definition_version": ""},
            {"subscription_state": "TRIAL"},
            {"capabilities": {CAPABILITY: "true"}},
            {"capabilities": {CAPABILITY: 1}},
            {"capabilities": {"storage.*": True}},
            {"capabilities": [CAPABILITY]},
        ):
            with self.subTest(change=change):
                self.denied(self.accept, p=payload(**change))
        self.denied(self.accept, school="school-B")
        self.denied(self.accept, project="project-B")
        self.denied(self.current)

    def test_finite_age_expiry_future_effective_and_lifetime(self):
        for now, p in (
            (99, payload()),
            (109, payload()),
            (300, payload()),
            (500, payload(expires_at=501)),
            (150, payload(expires_at=401)),
            (150, payload(issued_at=151)),
            (150, payload(issued_at=True)),
            (150, payload(expires_at=False)),
        ):
            with self.subTest(now=now, p=p):
                self.denied(self.accept, p=p, now=now)
        self.denied(self.accept, now=True)
        self.denied(self.current)

    def test_revision_highwater_rejects_rollback_or_conflicting_same_revision(self):
        self.accept()
        self.denied(self.accept, p=payload(revision=6))
        self.denied(self.accept, p=payload(capabilities={CAPABILITY: False}))
        self.denied(self.accept, p=payload(issued_at=101))
        self.assertIsNone(self.accept())  # identical signed replay
        self.accept(payload(revision=8, capabilities={CAPABILITY: False}))
        self.denied(self.current)
        self.denied(self.accept, p=payload(revision=7))
        self.denied(self.current, store=self.open_store())
        with closing(sqlite3.connect(self.path)) as db:
            self.assertEqual(db.execute("SELECT revision FROM photo_snapshots").fetchone(), (8,))
            self.assertEqual(db.execute("SELECT COUNT(*) FROM photo_revision_events").fetchone(), (2,))

    def test_identical_replay_does_not_extend_freshness(self):
        self.accept(now=150)
        self.assertIsNone(self.current(now=209))
        self.assertIsNone(self.accept(now=209))
        self.denied(self.current, now=210)
        # A fresh accepted revision is required to refresh this candidate.
        self.accept(payload(revision=8), now=210)
        self.assertIsNone(self.current(now=210))
        self.denied(self.current, now=270)

    def test_signed_suspension_and_expiry_preserve_history_deny_new_use(self):
        self.accept()
        self.accept(payload(revision=8, subscription_state="SUSPENDED"))
        self.denied(self.current)
        self.denied(self.accept, p=payload(revision=7))
        self.accept(payload(revision=9, subscription_state="ACTIVE"))
        self.assertIsNone(self.current())
        self.denied(self.current, now=300)

    def test_push_invalidation_cannot_be_cleared_by_replaying_same_revision(self):
        self.accept()
        self.store.invalidate(school=SCHOOL, project=PROJECT, now_epoch=155)
        self.denied(self.current)
        self.denied(self.accept)
        self.denied(self.current, store=self.open_store())
        self.accept(payload(revision=8))
        self.assertIsNone(self.current())
        with closing(sqlite3.connect(self.path)) as db:
            events = db.execute("SELECT event_type FROM photo_revision_events ORDER BY rowid").fetchall()
        self.assertEqual(events, [("ACCEPT",), ("INVALIDATE",), ("ACCEPT",)])

    def test_local_two_connections_serialize_competing_revision_updates(self):
        self.accept()
        def apply(revision):
            try:
                self.accept(payload(revision=revision), store=self.open_store())
                return "PASS"
            except SignedSnapshotDenied:
                return "DENY"
        with ThreadPoolExecutor(max_workers=2) as pool:
            results = list(pool.map(apply, (8, 9)))
        self.assertIn("PASS", results)
        with closing(sqlite3.connect(self.path)) as db:
            self.assertEqual(db.execute("SELECT revision FROM photo_snapshots").fetchone(), (9,))
        self.denied(self.accept, p=payload(revision=8))

    def test_fail_closed_when_cache_not_initialized_or_unavailable(self):
        self.denied(self.current)
        self.denied(self.store.invalidate, school=SCHOOL, project=PROJECT, now_epoch=150)
        self.denied(LocalSignedPhotoSnapshotCandidate,
                    ":memory:", pinned_issuer=ISSUER,
                    pinned_public_keys={"test-key-1": self.public})
        self.denied(LocalSignedPhotoSnapshotCandidate,
                    self.path, pinned_issuer=ISSUER,
                    pinned_public_keys={"test-key-1": b"short"})


if __name__ == "__main__":
    unittest.main()
