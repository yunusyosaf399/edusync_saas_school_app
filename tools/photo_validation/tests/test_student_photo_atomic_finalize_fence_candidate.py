"""Separate spawned-process SQLite lock contention with actual signed revisions.

All identities, intent rows, clocks, images (none) and keys are synthetic.
No real file_objects row or photo SET operation exists in this suite.
"""
from __future__ import annotations

import base64
from contextlib import closing
import json
import multiprocessing
from pathlib import Path
from queue import Empty
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
from student_photo_atomic_finalize_fence_candidate import (
    LocalPhotoAtomicFinalizeTrial,
)

ISSUER = "edusync-trial-control-plane"
SCHOOL = "school-A"
PROJECT = "project-A"


def signed(key, *, revision=7, enabled=True, state="ACTIVE"):
    body = {
        "schema_version": 1, "issuer": ISSUER,
        "school_id": SCHOOL, "project_id": PROJECT,
        "revision": revision, "plan_definition_version": "trial-v1",
        "capabilities": {CAPABILITY: enabled},
        "subscription_state": state, "issued_at": 100,
        "effective_at": 110, "expires_at": 300,
    }
    protected = {"alg": "Ed25519", "kid": "trial-key", "payload": body}
    canonical = json.dumps(protected, sort_keys=True, separators=(",", ":"),
                           ensure_ascii=True).encode("ascii")
    sig = base64.b64encode(key.sign(SIGNING_CONTEXT + canonical)).decode("ascii")
    return json.dumps({**protected, "signature": sig},
                      separators=(",", ":")).encode("utf-8")


def _spawned_operation(path, pubkey, action, envelope, locked_event,
                       release_event, results, start_event=None):
    # Module-scope entry point guarantees a genuinely separate spawned process.
    try:
        store = LocalPhotoAtomicFinalizeTrial(
            path, pinned_issuer=ISSUER,
            pinned_public_keys={"trial-key": pubkey})
        results.put(("STARTED", action))
        if start_event is not None and not start_event.wait(timeout=8):
            raise RuntimeError("contender start interlock timed out")

        def hold():
            if locked_event is not None:
                locked_event.set()
                if not release_event.wait(timeout=8):
                    raise RuntimeError("trial interlock timed out")

        if action == "FINALIZE":
            rev = store.finalize_synthetic_intent(
                intent_id="intent-A", school=SCHOOL, project=PROJECT,
                student="student-A", campus="campus-A", principal="admin-A",
                now_epoch=150, after_lock=hold if locked_event is not None else None,
            )
            results.put(("SUCCESS", rev))
        else:
            store.accept_signed_revision_trial(
                envelope, school=SCHOOL, project=PROJECT,
                now_epoch=150,
                after_write_under_lock=hold if locked_event is not None else None,
            )
            results.put(("SUCCESS", action))
    except SignedSnapshotDenied:
        results.put(("DENIED", action))
    except BaseException as exc:
        results.put(("ERROR", type(exc).__name__))


class StudentPhotoLocalAtomicFinalizeTests(unittest.TestCase):
    def setUp(self):
        tmp = tempfile.TemporaryDirectory()
        self.addCleanup(tmp.cleanup)
        self.path = str(Path(tmp.name) / "shared-trial.sqlite")
        self.private = Ed25519PrivateKey.generate()
        self.public = self.private.public_key().public_bytes(
            encoding=serialization.Encoding.Raw,
            format=serialization.PublicFormat.Raw,
        )
        self.store = self.new_store()
        self.store.accept(signed(self.private), school=SCHOOL,
                          project=PROJECT, now_epoch=150)
        self.seed("intent-A")

    def new_store(self):
        return LocalPhotoAtomicFinalizeTrial(
            self.path, pinned_issuer=ISSUER,
            pinned_public_keys={"trial-key": self.public})

    def seed(self, intent_id):
        self.store.seed_synthetic_intent(
            intent_id=intent_id, school=SCHOOL, project=PROJECT,
            student="student-A", campus="campus-A", principal="admin-A",
            issued_revision=7, issued_at=120, expires_at=290)

    def finalize(self, store=None, intent_id="intent-A", now=150, **kwargs):
        return (store or self.store).finalize_synthetic_intent(
            intent_id=intent_id, school=SCHOOL, project=PROJECT,
            student="student-A", campus="campus-A", principal="admin-A",
            now_epoch=now, **kwargs)

    def state(self):
        with closing(sqlite3.connect(self.path)) as db:
            rows = db.execute("""SELECT intent_id, state, finalized_revision
                FROM photo_trial_intents ORDER BY intent_id""").fetchall()
            events = db.execute("""SELECT intent_id, revision, event_type
                FROM photo_trial_events ORDER BY intent_id""").fetchall()
            current = db.execute("""SELECT revision, enabled, invalidated
                FROM photo_snapshots WHERE school=? AND project=?""",
                (SCHOOL, PROJECT)).fetchone()
        return rows, events, current

    def test_valid_local_simulated_finalize_single_consumption(self):
        self.assertEqual(self.finalize(), 7)
        with self.assertRaises(SignedSnapshotDenied):
            self.finalize(store=self.new_store())
        rows, events, current = self.state()
        self.assertEqual(rows, [("intent-A", "TRIAL_FINALIZED", 7)])
        self.assertEqual(events, [("intent-A", 7, "TRIAL_FINALIZE")])
        self.assertEqual(current, (7, 1, 0))

    def test_finalization_denies_wrong_binding_without_partial_state(self):
        for mismatch in (
            {"student": "student-B"}, {"campus": "campus-B"},
            {"principal": "admin-B"}, {"school": "school-B"},
            {"project": "project-B"}, {"intent_id": "missing"},
            {"now_epoch": True},
        ):
            args = dict(intent_id="intent-A", school=SCHOOL, project=PROJECT,
                        student="student-A", campus="campus-A", principal="admin-A",
                        now_epoch=150)
            args.update(mismatch)
            with self.subTest(mismatch=mismatch), self.assertRaises(SignedSnapshotDenied):
                self.store.finalize_synthetic_intent(**args)
        self.assertEqual(self.state()[1], [])
        self.assertEqual(self.finalize(), 7)

    def test_revision_downgrade_suspension_and_replay_after_restart(self):
        self.store.accept_signed_revision_trial(
            signed(self.private, revision=8, enabled=False),
            school=SCHOOL, project=PROJECT, now_epoch=150)
        with self.assertRaises(SignedSnapshotDenied):
            self.finalize(store=self.new_store())
        with self.assertRaises(SignedSnapshotDenied):
            self.new_store().accept_signed_revision_trial(
                signed(self.private, revision=7),
                school=SCHOOL, project=PROJECT, now_epoch=150)
        self.assertEqual(self.state()[0][0][1], "TRIAL_PENDING")
        self.assertEqual(self.state()[1], [])
        self.store.accept_signed_revision_trial(
            signed(self.private, revision=9, state="ACTIVE"),
            school=SCHOOL, project=PROJECT, now_epoch=150)
        self.assertEqual(self.finalize(store=self.new_store()), 9)
        self.assertEqual(self.state()[1], [("intent-A", 9, "TRIAL_FINALIZE")])

    def test_stale_expired_and_invalidated_denials(self):
        with self.assertRaises(SignedSnapshotDenied):
            self.finalize(now=210)  # Cache fresh_until is exclusive.
        with self.assertRaises(SignedSnapshotDenied):
            self.finalize(now=290)  # Intent expiry exclusive.
        self.store.invalidate(school=SCHOOL, project=PROJECT, now_epoch=151)
        with self.assertRaises(SignedSnapshotDenied):
            self.finalize(store=self.new_store())
        self.assertEqual(self.state()[1], [])
        self.store.accept_signed_revision_trial(
            signed(self.private, revision=8),
            school=SCHOOL, project=PROJECT, now_epoch=152)
        self.assertEqual(self.finalize(store=self.new_store()), 8)

    def race(self, holder_action, challenger_action):
        ctx = multiprocessing.get_context("spawn")
        ready = ctx.Event()
        release = ctx.Event()
        qa, qb = ctx.Queue(), ctx.Queue()
        contender_go = ctx.Event()
        revoked = signed(self.private, revision=8, enabled=False)
        holder = ctx.Process(
            target=_spawned_operation, args=(
                self.path, self.public, holder_action, revoked,
                ready, release, qa,
            ))
        contender = ctx.Process(
            target=_spawned_operation, args=(
                self.path, self.public, challenger_action, revoked,
                None, None, qb, contender_go,
            ))
        # Initialize both separate process instances BEFORE holding the write
        # lock; their constructor's schema checks must not fake lock evidence.
        contender.start()
        self.assertEqual(qb.get(timeout=6)[0], "STARTED")
        holder.start()
        try:
            self.assertEqual(qa.get(timeout=6)[0], "STARTED")
            self.assertTrue(ready.wait(timeout=6), "holder never acquired SQLite write lock")
            contender_go.set()
            # Contender has started but cannot finish while the other process
            # owns BEGIN IMMEDIATE. This is local-file lock evidence only.
            with self.assertRaises(Empty):
                qb.get(timeout=0.35)
        finally:
            contender_go.set()
            release.set()
        try:
            one = qa.get(timeout=6)
            two = qb.get(timeout=6)
        finally:
            holder.join(timeout=8)
            if holder.is_alive():
                holder.terminate()
                holder.join(timeout=3)
            if contender.pid is not None:
                contender.join(timeout=8)
                if contender.is_alive():
                    contender.terminate()
                    contender.join(timeout=3)
        self.assertEqual(holder.exitcode, 0)
        self.assertEqual(contender.exitcode, 0)
        self.assertNotEqual(one[0], "ERROR", one)
        self.assertNotEqual(two[0], "ERROR", two)
        return one, two

    def test_two_process_finalize_first_then_signed_revocation(self):
        one, two = self.race("FINALIZE", "REVOKE")
        self.assertEqual(one, ("SUCCESS", 7))
        self.assertEqual(two, ("SUCCESS", "REVOKE"))
        self.assertEqual(self.state()[0], [("intent-A", "TRIAL_FINALIZED", 7)])
        self.assertEqual(self.state()[1], [("intent-A", 7, "TRIAL_FINALIZE")])
        self.assertEqual(self.state()[2], (8, 0, 0))
        with self.assertRaises(SignedSnapshotDenied):
            self.finalize()

    def test_two_process_signed_revocation_first_then_finalize_denied(self):
        one, two = self.race("REVOKE", "FINALIZE")
        self.assertEqual(one, ("SUCCESS", "REVOKE"))
        self.assertEqual(two, ("DENIED", "FINALIZE"))
        self.assertEqual(self.state()[0], [("intent-A", "TRIAL_PENDING", None)])
        self.assertEqual(self.state()[1], [])
        self.assertEqual(self.state()[2], (8, 0, 0))

    def test_two_process_competing_same_intent_one_success(self):
        one, two = self.race("FINALIZE", "FINALIZE")
        self.assertEqual(one, ("SUCCESS", 7))
        self.assertEqual(two, ("DENIED", "FINALIZE"))
        self.assertEqual(self.state()[1], [("intent-A", 7, "TRIAL_FINALIZE")])
        with self.assertRaises(SignedSnapshotDenied):
            self.finalize(store=self.new_store())


if __name__ == "__main__":
    unittest.main()
