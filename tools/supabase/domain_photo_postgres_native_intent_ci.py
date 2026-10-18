"""Disposable native PostgreSQL Student Photo intent lifecycle, NOT a file service.

This test-only schema is created exclusively in local D1C2A runtime AFTER
the approved genuine P0 enrollment fixture. There is no SQLite token ledger,
upload endpoint, byte persistence, real FILE AVAILABLE or Student photo SET.

Caller-injected db_connect must be a trusted local test harness connection:
a synthetic JWT-shaped claim and a no-login student executor role are set
by the privileged harness, NEVER by a real client or untrusted request.
"""
from __future__ import annotations

from concurrent.futures import ThreadPoolExecutor
from contextlib import closing
from hashlib import sha256
from pathlib import Path
import re
import secrets
import time

SCHEMA = "photo_pg_trial"
TABLE = "photo_pg_trial.intents"
CONTAINER = "supabase_db_saas_OS_school_app"
HEX_TOKEN = re.compile(r"[0-9a-f]{64}\Z", re.ASCII)
SETUP_SQL = """
BEGIN;
-- Quarantined inside the disposable PostgreSQL container only. No
-- public/Data API schema or anonymous/authenticated object grants.
CREATE SCHEMA photo_pg_trial AUTHORIZATION schoolos_student_executor;
REVOKE ALL ON SCHEMA photo_pg_trial FROM PUBLIC,anon,authenticated,service_role;
SET ROLE schoolos_student_executor;
CREATE TABLE photo_pg_trial.intents (
 token_digest bytea PRIMARY KEY,
 student_id uuid NOT NULL,
 campus_id uuid NOT NULL,
 principal_id uuid NOT NULL,
 status text NOT NULL DEFAULT 'ISSUED',
 issued_at timestamptz NOT NULL DEFAULT pg_catalog.clock_timestamp(),
 expires_at timestamptz NOT NULL DEFAULT
   (pg_catalog.clock_timestamp()+interval '3 minutes'),
 consumed_at timestamptz,
 finalized_at timestamptz,
 revoked_at timestamptz,
 CONSTRAINT photo_trial_digest_length CHECK
   (pg_catalog.octet_length(token_digest)=32),
 CONSTRAINT photo_trial_state CHECK
   (status IN ('ISSUED','CONSUMED','FINALIZED_TRIAL','REVOKED')),
 CONSTRAINT photo_trial_state_timestamps CHECK (
  (status='ISSUED' AND consumed_at IS NULL AND finalized_at IS NULL AND revoked_at IS NULL)
  OR (status='CONSUMED' AND consumed_at IS NOT NULL AND finalized_at IS NULL AND revoked_at IS NULL)
  OR (status='FINALIZED_TRIAL' AND consumed_at IS NOT NULL AND finalized_at IS NOT NULL AND revoked_at IS NULL)
  OR (status='REVOKED' AND finalized_at IS NULL AND revoked_at IS NOT NULL)
 )
);
ALTER TABLE photo_pg_trial.intents ENABLE ROW LEVEL SECURITY;
ALTER TABLE photo_pg_trial.intents FORCE ROW LEVEL SECURITY;
-- Narrow no-login executor is the ONLY owner/test policy subject, not a
-- public/client role. Existing Principal/Student/permission checks happen
-- transactionally in the server-held worker before any state modification.
CREATE POLICY photo_pg_local_executor ON photo_pg_trial.intents
 FOR ALL TO schoolos_student_executor
 USING (true) WITH CHECK (true);
REVOKE ALL ON TABLE photo_pg_trial.intents FROM PUBLIC,anon,authenticated,service_role;
RESET ROLE;
COMMIT;
"""


class NativeIntentDenied(Exception):
    """Uniform test-only failure, no underlying PostgreSQL information."""


def _deny() -> None:
    raise NativeIntentDenied("PHOTO_NATIVE_PG_TRIAL_DENIED")


def _canonical_uuid(value: str) -> str:
    from uuid import UUID
    if type(value) is not str:
        _deny()
    try:
        canonical = str(UUID(value))
    except (ValueError, AttributeError, TypeError):
        _deny()
    if canonical != value:
        _deny()
    return canonical


def _digest(token: str) -> bytes:
    if type(token) is not str or HEX_TOKEN.fullmatch(token) is None:
        _deny()
    return sha256(bytes.fromhex(token)).digest()


class NativePostgresPhotoIntentTrial:
    """Single-database authorization, token row and transition transaction.

    This Python caller is a trusted local test worker. It is NOT a reviewed
    service identity, opaque RPC or production policy. All stage transitions
    revalidate the live PostgreSQL Principal and restricted private resolver.
    """

    def __init__(self, *, db_connect, student_id: str, campus_id: str):
        if not callable(db_connect):
            _deny()
        self._connect = db_connect
        self._student = _canonical_uuid(student_id)
        self._campus = _canonical_uuid(campus_id)

    def _authorized(self, cursor):
        # Same Foundation grant/revocation lock as protected D1 commands.
        cursor.execute("SELECT pg_catalog.pg_advisory_xact_lock_shared(71001,1)")
        # This row lock blocks a competing Student update during this stage.
        # Placement changes must independently honor the same Student lock.
        cursor.execute(
            "SELECT id FROM app_private.students "
            "WHERE id=%s::uuid AND current_status='ACTIVE' FOR UPDATE",
            (self._student,))
        if cursor.fetchone() is None:
            _deny()
        cursor.execute("SELECT app_private.current_principal_id()")
        row = cursor.fetchone()
        if not row or row[0] is None:
            _deny()
        principal = _canonical_uuid(str(row[0]))
        cursor.execute(
            "SELECT app_private.d1_student_photo_private_issue_resolver_trial(%s::uuid,%s::uuid)",
            (self._student, self._campus))
        result = cursor.fetchone()
        if not result or type(result[0]) is not bool or result[0] is not True:
            _deny()
        return principal

    def _open(self):
        try:
            conn = self._connect()
            if getattr(conn, "autocommit", None) is not False:
                try: conn.close()
                finally: _deny()
            return conn
        except NativeIntentDenied:
            raise
        except Exception:
            _deny()

    def issue(self, *, fail_before_commit=False) -> str:
        # Unpredictable bearer is returned ONCE; the DB stores SHA-256 only.
        if type(fail_before_commit) is not bool:
            _deny()
        token = secrets.token_hex(32)
        digest = _digest(token)
        try:
            with closing(self._open()) as con:
                with con:
                    with closing(con.cursor()) as cur:
                        principal = self._authorized(cur)
                        cur.execute(
                            "INSERT INTO photo_pg_trial.intents "
                            "(token_digest,student_id,campus_id,principal_id)"
                            " VALUES (%s,%s::uuid,%s::uuid,%s::uuid)",
                            (digest,self._student,self._campus,principal))
                        if fail_before_commit:
                            _deny()
            return token
        except NativeIntentDenied:
            raise
        except Exception:
            _deny()

    def transition(self, token: str, *, action: str,
                   fail_before_commit=False) -> str:
        digest = _digest(token)
        if action not in ("CONSUME", "FINALIZE_TRIAL", "REVOKE") or type(fail_before_commit) is not bool:
            _deny()
        source, target = {
            "CONSUME": ("ISSUED","CONSUMED"),
            "FINALIZE_TRIAL": ("CONSUMED","FINALIZED_TRIAL"),
            "REVOKE": ("ISSUED","REVOKED"),
        }[action]
        timestamp_col = {
            "CONSUME": "consumed_at",
            "FINALIZE_TRIAL": "finalized_at",
            "REVOKE": "revoked_at",
        }[action]
        try:
            with closing(self._open()) as con:
                with con:
                    with closing(con.cursor()) as cur:
                        principal = self._authorized(cur)
                        cur.execute(
                            "SELECT student_id,campus_id,principal_id,status,"
                            " (expires_at>pg_catalog.clock_timestamp()) "
                            "FROM photo_pg_trial.intents WHERE token_digest=%s FOR UPDATE",
                            (digest,))
                        row=cur.fetchone()
                        if (row is None or str(row[0])!=self._student
                                or str(row[1])!=self._campus
                                or str(row[2])!=principal
                                or row[3]!=source or row[4] is not True):
                            _deny()
                        # timestamp_col comes from our fixed action table,
                        # never from caller-provided SQL identifier.
                        cur.execute(
                            "UPDATE photo_pg_trial.intents "
                            f"SET status=%s,{timestamp_col}=pg_catalog.clock_timestamp() "
                            "WHERE token_digest=%s AND status=%s RETURNING status",
                            (target,digest,source))
                        result=cur.fetchone()
                        if result!=(target,):
                            _deny()
                        if fail_before_commit:
                            _deny()
            return target
        except NativeIntentDenied:
            raise
        except Exception:
            _deny()


def _check(predicate, code: str):
    if not predicate:
        raise RuntimeError("D1_PHOTO_NATIVE_PG_" + code)


def _denied(f):
    try:
        f()
    except NativeIntentDenied:
        return
    raise RuntimeError("D1_PHOTO_NATIVE_PG_FAIL_OPEN")


def _row(psycopg, digest: bytes):
    # Isolated owner test inspection, never an app-facing API.
    from domain_student_photo_real_pg_handoff_ci import _local_connect
    with closing(_local_connect(psycopg)) as con:
        with con:
            with closing(con.cursor()) as cur:
                cur.execute(
                    "SELECT status,consumed_at IS NOT NULL,"
                    "finalized_at IS NOT NULL,revoked_at IS NOT NULL "
                    "FROM photo_pg_trial.intents WHERE token_digest=%s",(digest,))
                return cur.fetchone()


def _wait_on_row(psycopg, other_pid: int, *, timeout: float=8):
    from domain_student_photo_real_pg_handoff_ci import _local_connect
    deadline=time.monotonic()+timeout
    with closing(_local_connect(psycopg)) as observer:
        while time.monotonic()<deadline:
            with closing(observer.cursor()) as cur:
                cur.execute(
                    "SELECT EXISTS (SELECT 1 FROM pg_catalog.pg_locks "
                    "WHERE pid=%s AND NOT granted AND locktype IN "
                    "('transactionid','tuple'))",(other_pid,))
                blocked=cur.fetchone()[0]
            observer.rollback()
            if blocked:
                return
            time.sleep(.05)
    raise RuntimeError("D1_PHOTO_NATIVE_PG_LOCK_WAIT_NOT_OBSERVED")


def run_native_pg_intent_trial(psycopg, *, container: str, run_psql,
                               connect_actor, student_id: str, campus_id: str) -> None:
    if container!=CONTAINER:
        raise RuntimeError("D1_PHOTO_NATIVE_PG_DISPOSABLE_ONLY")
    run_psql(container,SETUP_SQL,"D1_PHOTO_NATIVE_PG_SETUP",timeout=90)
    store=NativePostgresPhotoIntentTrial(
        db_connect=lambda:connect_actor(psycopg),
        student_id=student_id,campus_id=campus_id)
    token=store.issue()
    digest=_digest(token)
    _check(_row(psycopg,digest)==("ISSUED",False,False,False),"ISSUE")
    _denied(lambda:store.transition("A"*64,action="CONSUME"))
    _denied(lambda:store.transition(token,action="CONSUME",fail_before_commit=True))
    _check(_row(psycopg,digest)==("ISSUED",False,False,False),"CONSUME_ROLLBACK")
    _check(store.transition(token,action="CONSUME")=="CONSUMED","CONSUME")
    _denied(lambda:store.transition(token,action="CONSUME"))
    _denied(lambda:store.transition(token,action="FINALIZE_TRIAL",fail_before_commit=True))
    _check(_row(psycopg,digest)==("CONSUMED",True,False,False),"FINALIZE_ROLLBACK")
    _check(store.transition(token,action="FINALIZE_TRIAL")=="FINALIZED_TRIAL","FINALIZE")
    _denied(lambda:store.transition(token,action="FINALIZE_TRIAL"))
    _check(_row(psycopg,digest)==("FINALIZED_TRIAL",True,True,False),"FINAL_STATE")
    second=store.issue()
    _check(store.transition(second,action="REVOKE")=="REVOKED","REVOKE")
    _denied(lambda:store.transition(second,action="CONSUME"))
    _check(_row(psycopg,_digest(second))==("REVOKED",False,False,True),"REVOKE_STATE")
    # Test a second genuine PostgreSQL session blocking on the same durable
    # token row. REVOKE takes the row first and commits; CONSUME must not
    # create a second state transition or a success receipt after that commit.
    pending=store.issue()
    key=_digest(pending)
    revoker=connect_actor(psycopg)
    try:
        with closing(revoker.cursor()) as cur:
            cur.execute(
                "UPDATE photo_pg_trial.intents SET status='REVOKED',"
                "revoked_at=pg_catalog.clock_timestamp() "
                "WHERE token_digest=%s AND status='ISSUED' RETURNING status",
                (key,))
            _check(cur.fetchone()==("REVOKED",),"RACE_REVOKER_UPDATE")
        with ThreadPoolExecutor(max_workers=1) as executor:
            def worker():
                conn=connect_actor(psycopg)
                # Worker connection PID is observed, not invented.
                with closing(conn.cursor()) as cur:
                    cur.execute("SELECT pg_catalog.pg_backend_pid()")
                    pid=cur.fetchone()[0]
                conn.rollback()
                # The per-stage store will start a separate authenticated
                # connection; observe it by application_name instead below.
                return store.transition(pending,action="CONSUME")
            # Every store connection is tagged so pg_locks sees exact waiter.
            original=store._connect
            def tagged():
                conn=original()
                with closing(conn.cursor()) as cur:
                    cur.execute("SET LOCAL application_name='photo-native-pg-consumer'")
                return conn
            store._connect=tagged
            future=executor.submit(worker)
            try:
                deadline=time.monotonic()+8
                observed=False
                from domain_student_photo_real_pg_handoff_ci import _local_connect
                with closing(_local_connect(psycopg)) as check:
                    while time.monotonic()<deadline:
                        with closing(check.cursor()) as c:
                            c.execute(
                                "SELECT EXISTS (SELECT 1 FROM pg_catalog.pg_stat_activity a "
                                "JOIN pg_catalog.pg_locks l ON l.pid=a.pid "
                                "WHERE a.application_name='photo-native-pg-consumer' "
                                "AND NOT l.granted AND l.locktype IN ('transactionid','tuple'))")
                            observed=c.fetchone()[0]
                        check.rollback()
                        if observed: break
                        time.sleep(.05)
                _check(observed,"WAIT_NOT_OBSERVED")
            finally:
                revoker.commit()
                store._connect=original
            _denied(lambda:future.result(timeout=12))
    finally:
        revoker.rollback()
        revoker.close()
    _check(_row(psycopg,key)==("REVOKED",False,False,True),"RACE_STATE")
    # Unexpected values/caller-selected cross-school scope cannot pass.
    _denied(lambda:store.transition(pending.upper(),action="CONSUME"))
    _denied(lambda:NativePostgresPhotoIntentTrial(
        db_connect=lambda:connect_actor(psycopg),
        student_id=student_id,campus_id="d2000000-0000-4000-8000-000000000041"
    ).issue())
    print("D1_STUDENT_PHOTO_NATIVE_PG_INTENT_PASS "
          "single PG atomic issue/consume/finalize-trial/revoke, "
          "rollback denial, replay denial, real row-lock revocation race, "
          "no bytes and no photo SET; DISPOSABLE ONLY")
