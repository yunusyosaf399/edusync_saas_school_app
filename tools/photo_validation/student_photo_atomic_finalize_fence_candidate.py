"""Quarantined local SQLite two-process photo FINALIZE ordering rehearsal.

NOT an API, upload service, authorization receipt, real intent issuance, or
file mutation. These trial rows are wholly unrelated to app_private.file_objects.
All synthetic identities, test clock, paths and interlocks MUST stay in tests.
This proves SQLite same-file serialization only, NEVER multi-host fencing.
"""
from __future__ import annotations

from contextlib import closing
from typing import Callable
import sqlite3

from student_photo_signed_entitlement_candidate import (
    CAPABILITY, LocalSignedPhotoSnapshotCandidate, SignedSnapshotDenied,
    _identifier, _natural, _deny, MAX_AGE_SECONDS, MAX_SHARED_FRESH_SECONDS,
)

PURPOSE = "STUDENT_PROFILE_PHOTO"


class LocalPhotoAtomicFinalizeTrial(LocalSignedPhotoSnapshotCandidate):
    """Use same local revision table and lock for trial-only finalization."""

    def __init__(self, path, *, pinned_issuer, pinned_public_keys):
        super().__init__(
            path, pinned_issuer=pinned_issuer,
            pinned_public_keys=pinned_public_keys,
        )
        try:
            with closing(self._connect()) as db, db:
                db.execute("""CREATE TABLE IF NOT EXISTS photo_trial_intents (
                    intent_id TEXT PRIMARY KEY,
                    school TEXT NOT NULL, project TEXT NOT NULL,
                    student TEXT NOT NULL, campus TEXT NOT NULL,
                    principal TEXT NOT NULL, purpose TEXT NOT NULL,
                    issued_revision INTEGER NOT NULL,
                    issued_at INTEGER NOT NULL, expires_at INTEGER NOT NULL,
                    state TEXT NOT NULL DEFAULT 'TRIAL_PENDING'
                      CHECK(state IN ('TRIAL_PENDING','TRIAL_FINALIZED')),
                    finalized_revision INTEGER, finalized_at INTEGER)""")
                db.execute("""CREATE TABLE IF NOT EXISTS photo_trial_events (
                    intent_id TEXT NOT NULL UNIQUE,
                    school TEXT NOT NULL, project TEXT NOT NULL,
                    revision INTEGER NOT NULL, event_type TEXT NOT NULL,
                    at_epoch INTEGER NOT NULL)""")
        except sqlite3.Error:
            _deny()

    def seed_synthetic_intent(
        self, *, intent_id: str, school: str, project: str,
        student: str, campus: str, principal: str, issued_revision: int,
        issued_at: int = 120, expires_at: int = 290,
    ) -> None:
        """TEST FIXTURE ONLY. Never expose to callers or claim it is a real intent."""
        if (not all(_identifier(v) for v in (
                intent_id, school, project, student, campus, principal))
                or not _natural(issued_revision) or issued_revision < 1
                or not _natural(issued_at) or not _natural(expires_at)
                or not issued_at < expires_at):
            _deny()
        try:
            with closing(self._connect()) as db, db:
                db.execute("BEGIN IMMEDIATE")
                db.execute("""INSERT INTO photo_trial_intents
                    (intent_id, school, project, student, campus, principal,
                     purpose, issued_revision, issued_at, expires_at)
                    VALUES (?,?,?,?,?,?,?,?,?,?)""",
                    (intent_id, school, project, student, campus, principal,
                     PURPOSE, issued_revision, issued_at, expires_at))
        except sqlite3.Error:
            _deny()

    def accept_signed_revision_trial(
        self, envelope: bytes, *, school: str, project: str,
        now_epoch: int, after_write_under_lock: Callable[[], None] | None = None,
    ) -> None:
        """Verify authentic signed change; commit it under SAME lock as FINALIZE.

        after_write_under_lock is an instrumented test interlock exclusively
        for deterministic multi-process contention. NO production call site.
        """
        verified = self._verify(envelope, school, project, now_epoch)
        try:
            with closing(self._connect()) as db, db:
                db.execute("BEGIN IMMEDIATE")
                old = db.execute("""SELECT revision FROM photo_snapshots
                    WHERE school=? AND project=?""", (school, project)).fetchone()
                # Trial only permits strictly newer signed revisions; no
                # same-revision replay, especially following invalidation.
                if old is None or verified.revision <= old[0]:
                    _deny()
                fresh_until = min(
                    now_epoch + MAX_SHARED_FRESH_SECONDS,
                    verified.expires_at,
                    verified.issued_at + MAX_AGE_SECONDS,
                )
                db.execute("""UPDATE photo_snapshots SET revision=?,
                    fingerprint=?, issued_at=?, expires_at=?,
                    fresh_until=?, enabled=?, invalidated=0
                    WHERE school=? AND project=?""",
                    (verified.revision, verified.fingerprint,
                     verified.issued_at, verified.expires_at, fresh_until,
                     int(verified.enabled), school, project))
                db.execute("""INSERT INTO photo_revision_events
                    (school, project, previous_revision, accepted_revision,
                     event_type, at_epoch)
                    VALUES (?, ?, ?, ?, 'ACCEPT', ?)""",
                    (school, project, old[0], verified.revision, now_epoch))
                if after_write_under_lock is not None:
                    after_write_under_lock()
        except sqlite3.Error:
            _deny()

    def finalize_synthetic_intent(
        self, *, intent_id: str, school: str, project: str,
        student: str, campus: str, principal: str,
        now_epoch: int, after_lock: Callable[[], None] | None = None,
    ) -> int:
        """ONE transaction: check revision/eligibility + consume fake intent.

        The returned revision is only test evidence, not an authorization or
        real AVAILABLE transition. Never separate the predicate from UPDATE.
        """
        if (not all(_identifier(v) for v in (
                intent_id, school, project, student, campus, principal))
                or not _natural(now_epoch)):
            _deny()
        try:
            with closing(self._connect()) as db, db:
                db.execute("BEGIN IMMEDIATE")
                if after_lock is not None:
                    after_lock()
                snapshot = db.execute("""SELECT revision, issued_at,
                    expires_at, fresh_until, enabled, invalidated
                    FROM photo_snapshots WHERE school=? AND project=?""",
                    (school, project)).fetchone()
                intent = db.execute("""SELECT school, project, student, campus,
                    principal, purpose, issued_revision, issued_at, expires_at,
                    state FROM photo_trial_intents WHERE intent_id=?""",
                    (intent_id,)).fetchone()
                if (snapshot is None or intent is None
                        or snapshot[4] != 1 or snapshot[5] != 0
                        or not snapshot[1] <= now_epoch <= snapshot[1] + MAX_AGE_SECONDS
                        or not now_epoch < snapshot[2] or not now_epoch < snapshot[3]
                        or intent[:5] != (
                            school, project, student, campus, principal)
                        or intent[5] != PURPOSE
                        or not 1 <= intent[6] <= snapshot[0]
                        or not intent[7] <= now_epoch < intent[8]
                        or intent[9] != "TRIAL_PENDING"):
                    _deny()
                updated = db.execute("""UPDATE photo_trial_intents
                    SET state='TRIAL_FINALIZED', finalized_revision=?, finalized_at=?
                    WHERE intent_id=? AND state='TRIAL_PENDING'""",
                    (snapshot[0], now_epoch, intent_id))
                if updated.rowcount != 1:
                    _deny()
                db.execute("""INSERT INTO photo_trial_events
                    (intent_id, school, project, revision, event_type, at_epoch)
                    VALUES (?, ?, ?, ?, 'TRIAL_FINALIZE', ?)""",
                    (intent_id, school, project, snapshot[0], now_epoch))
                return snapshot[0]
        except sqlite3.Error:
            _deny()
