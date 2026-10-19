"""Local-only native photo CONSUME-first Campus Transfer and backend-abort retries.

Uses only synthetic identities and genuine accepted P0/P1 application commands
inside the disposable D1C2A PostgreSQL stack. No external file operation,
production session, Student photo SET, hosted SQL or migration is performed.
"""
from __future__ import annotations

from concurrent.futures import ThreadPoolExecutor
from contextlib import closing
from threading import Event

from domain_photo_postgres_native_intent_ci import (
    CONTAINER, NativePostgresPhotoIntentTrial, NativeIntentDenied,
    _check, _denied, _digest, _row,
)
from domain_student_photo_real_pg_handoff_ci import (
    CAMPUS, _actor_connection, _local_connect,
)
from domain_photo_reverse_end_campus_transfer_ci import (
    CAMPUS_B, DEST_SECTION, SOURCE_SECTION, _p0_new_student,
    _public_actor, _observe_waiter, _no_current_source,
)

CONSUME_FIRST_STUDENT="ef000000-0000-4000-8000-000000000001"
RECOVERY_STUDENT="f0000000-0000-4000-8000-000000000001"
CONSUME_WORKER="photo-consume-first-transfer"
TRANSFER_WAITER="photo-protected-move-waits-on-consume"
TRANSFER_KEY="photo-consume-first-campus-transfer-20261019"
BACKEND_WORKER_PREFIX="photo-local-backend-abort-"

SETUP_SQL="""
BEGIN;
SELECT set_config('request.jwt.claim.sub',
 (SELECT id::text FROM auth.users
  WHERE email='foundation-rbac-001@example.invalid'),true);
SELECT set_config('request.jwt.claims',jsonb_build_object(
 'sub',current_setting('request.jwt.claim.sub'),'role','authenticated',
 'iat',(SELECT extract(epoch FROM tokens_valid_from)::bigint
  FROM app_private.principal_auth_bindings
  WHERE id='66666666-6666-4666-8666-666666666666'),
 'is_anonymous',false)::text,true);
SET ROLE schoolos_schema_owner;
-- New disposable Students, but no fake Enrollment or Roll writes.
INSERT INTO app_private.people(id,display_name,created_by) VALUES
 ('ef000000-0000-4000-8000-000000000003',
  'Disposable consume-first transfer Student',
  '11111111-1111-4111-8111-111111111111'),
 ('f0000000-0000-4000-8000-000000000003',
  'Disposable backend-abort recovery Student',
  '11111111-1111-4111-8111-111111111111');
INSERT INTO app_private.students(
 id,person_id,school_student_id,admission_number,admission_serial,
 admitted_on,current_status,created_by) VALUES
 ('ef000000-0000-4000-8000-000000000001',
  'ef000000-0000-4000-8000-000000000003',
  'PHOTO-CONSUME-TRANSFER-TRIAL','PHOTO-CONSUME-TRANSFER-94',94004,
  CURRENT_DATE-20,'ACTIVE','11111111-1111-4111-8111-111111111111'),
 ('f0000000-0000-4000-8000-000000000001',
  'f0000000-0000-4000-8000-000000000003',
  'PHOTO-BACKEND-RECOVERY-TRIAL','PHOTO-BACKEND-RECOVERY-94',94005,
  CURRENT_DATE-20,'ACTIVE','11111111-1111-4111-8111-111111111111');
INSERT INTO app_private.student_status_transitions(
 id,student_id,previous_status,new_status,effective_on,
 sequence_number,reason,created_by) VALUES
 ('ef000000-0000-4000-8000-000000000002',
  'ef000000-0000-4000-8000-000000000001',
  NULL,'ACTIVE',CURRENT_DATE-20,1,
  'Synthetic initial ACTIVE status',
  '11111111-1111-4111-8111-111111111111'),
 ('f0000000-0000-4000-8000-000000000002',
  'f0000000-0000-4000-8000-000000000001',
  NULL,'ACTIVE',CURRENT_DATE-20,1,
  'Synthetic initial ACTIVE status',
  '11111111-1111-4111-8111-111111111111');
RESET ROLE;
COMMIT;
"""


def _ledger_count(psycopg, student):
    with closing(_local_connect(psycopg)) as con:
        with closing(con.cursor()) as cur:
            cur.execute(
                "SELECT count(*) FROM photo_pg_trial.intents "
                "WHERE student_id=%s::uuid",(student,))
            count=cur.fetchone()[0]
        con.rollback()
        return count


def _consume_first_then_transfer(psycopg):
    """A valid CONSUME commits before an authorized P1 Campus Transfer."""
    student=CONSUME_FIRST_STUDENT
    source_id,source_start,source_section=_p0_new_student(
        psycopg,student,"photo-p1-consume-first-new-p0")
    _check(str(source_section)==SOURCE_SECTION,"CONSUME_FIRST_SOURCE")
    store=NativePostgresPhotoIntentTrial(
        db_connect=lambda:_actor_connection(psycopg),
        student_id=student,campus_id=CAMPUS)
    token=store.issue()
    entered=Event()
    release=Event()
    consumer_pid=[]
    def _tagged_consumer():
        con=_actor_connection(psycopg)
        with closing(con.cursor()) as cur:
            cur.execute(
                "SELECT pg_catalog.set_config('application_name',%s,true)",
                (CONSUME_WORKER,))
            cur.execute("SELECT pg_catalog.pg_backend_pid()")
            consumer_pid.append(int(cur.fetchone()[0]))
        return con

    def _hold_after_consume_update():
        entered.set()
        if not release.wait(18):
            raise RuntimeError("D1_PHOTO_CONSUME_FIRST_HOLD_TIMEOUT")

    tagged=NativePostgresPhotoIntentTrial(
        db_connect=_tagged_consumer,student_id=student,campus_id=CAMPUS)
    with ThreadPoolExecutor(max_workers=2) as pool:
        consuming=pool.submit(tagged.transition,token,action="CONSUME",
                              before_commit_test_hook=_hold_after_consume_update)
        moving=None
        try:
            _check(entered.wait(12) and len(consumer_pid)==1,
                   "CONSUME_FIRST_NOT_HELD")
            def _real_transfer():
                with closing(_public_actor(psycopg,TRANSFER_WAITER)) as con:
                    with con:
                        with closing(con.cursor()) as cur:
                            cur.execute("""
                              SELECT * FROM app.d1_move_student_enrollment(
                                %s::uuid,1,%s::uuid,%s::uuid,%s::date,
                                %s::uuid,'CAMPUS_TRANSFER',CURRENT_DATE,
                                'Photo consume-first Campus A to Campus B',NULL,%s)
                            """,(student,source_id,source_section,source_start,
                                 DEST_SECTION,TRANSFER_KEY))
                            _check(cur.fetchone() is not None,
                                   "CONSUME_FIRST_REAL_TRANSFER")
                return True
            moving=pool.submit(_real_transfer)
            # The accepted P1 RPC must wait on the real Student row locked
            # by the photo worker, rather than merely sleep or time out.
            _observe_waiter(psycopg,TRANSFER_WAITER,consumer_pid[0])
        finally:
            release.set()
        _check(consuming.result(timeout=20)=="CONSUMED",
               "CONSUME_FIRST_DID_NOT_COMMIT")
        _check(moving is not None and moving.result(timeout=20) is True,
               "TRANSFER_AFTER_CONSUME_DID_NOT_COMMIT")

    _no_current_source(psycopg,student,CAMPUS_B)
    _check(_row(psycopg,_digest(token))==("CONSUMED",True,False,False),
           "CONSUME_FIRST_STATE_CHANGED_AFTER_MOVE")
    # A consumed token is NOT equivalent to a file upload or finalization.
    _denied(lambda:store.transition(token,action="FINALIZE_TRIAL"))
    _denied(lambda:store.issue())
    _denied(lambda:store.transition(token,action="CONSUME"))


def _aborted_backend_step(psycopg, *, student, step, token=None):
    """Kill a genuine disposable PostgreSQL backend AFTER its state write.

    A separate postgres session uses pg_terminate_backend(pid,timeout)
    and waits for backend exit *before* releasing the worker pause. The
    server must roll back the interrupted PostgreSQL transaction. This is
    not a whole-machine crash or a multi-host storage replay proof.
    """
    _check(step in ("ISSUE","CONSUME","FINALIZE_TRIAL"),
           "BACKEND_ABORT_STAGE_INVALID")
    entered=Event()
    release=Event()
    worker_pid=[]
    def _worker_connection():
        conn=_actor_connection(psycopg)
        try:
            with closing(conn.cursor()) as cur:
                cur.execute(
                    "SELECT pg_catalog.set_config('application_name',%s,true)",
                    (BACKEND_WORKER_PREFIX+step,))
                cur.execute("SELECT pg_catalog.pg_backend_pid()")
                worker_pid.append(int(cur.fetchone()[0]))
            return conn
        except Exception:
            conn.close()
            raise
    worker=NativePostgresPhotoIntentTrial(
        db_connect=_worker_connection,student_id=student,campus_id=CAMPUS)
    def _pause_after_write():
        entered.set()
        if not release.wait(18):
            raise RuntimeError("D1_PHOTO_BACKEND_ABORT_HOLD_TIMEOUT")

    def _action():
        if step=="ISSUE":
            return worker.issue(before_commit_test_hook=_pause_after_write)
        return worker.transition(
            token,action=step,before_commit_test_hook=_pause_after_write)

    with ThreadPoolExecutor(max_workers=1) as pool:
        future=pool.submit(_action)
        try:
            _check(entered.wait(12) and len(worker_pid)==1,
                   "BACKEND_ABORT_NEVER_REACHED_WRITE")
            with closing(_local_connect(psycopg)) as admin:
                with closing(admin.cursor()) as cur:
                    # PostgreSQL 17 native function with explicit wait for
                    # process termination to avoid success/kill races.
                    cur.execute(
                        "SELECT pg_catalog.pg_terminate_backend(%s,10000)",
                        (worker_pid[0],))
                    _check(cur.fetchone()==(True,),"BACKEND_NOT_TERMINATED")
                admin.commit()
        finally:
            release.set()
        _denied(lambda:future.result(timeout=18))


def _real_backend_abort_retries(psycopg):
    """Abort uncommitted ISSUE/CONSUME/FINALIZE, then retry exactly once."""
    student=RECOVERY_STUDENT
    _p0_new_student(psycopg,student,"photo-native-backend-recovery-p0")
    store=NativePostgresPhotoIntentTrial(
        db_connect=lambda:_actor_connection(psycopg),
        student_id=student,campus_id=CAMPUS)
    _check(_ledger_count(psycopg,student)==0,"RECOVERY_START_COUNT")

    _aborted_backend_step(psycopg,student=student,step="ISSUE")
    _check(_ledger_count(psycopg,student)==0,"ABORTED_ISSUE_WAS_COMMITTED")
    token=store.issue()
    key=_digest(token)
    _check(_ledger_count(psycopg,student)==1
           and _row(psycopg,key)==("ISSUED",False,False,False),
           "ISSUE_RETRY_NOT_ONCE")

    _aborted_backend_step(psycopg,student=student,step="CONSUME",token=token)
    _check(_ledger_count(psycopg,student)==1
           and _row(psycopg,key)==("ISSUED",False,False,False),
           "ABORTED_CONSUME_WAS_COMMITTED")
    _check(store.transition(token,action="CONSUME")=="CONSUMED",
           "CONSUME_RETRY_FAILED")
    _denied(lambda:store.transition(token,action="CONSUME"))
    _check(_row(psycopg,key)==("CONSUMED",True,False,False),
           "CONSUME_RETRY_STATE")

    _aborted_backend_step(psycopg,student=student,
                          step="FINALIZE_TRIAL",token=token)
    _check(_ledger_count(psycopg,student)==1
           and _row(psycopg,key)==("CONSUMED",True,False,False),
           "ABORTED_FINALIZE_WAS_COMMITTED")
    _check(store.transition(token,action="FINALIZE_TRIAL")=="FINALIZED_TRIAL",
           "FINALIZE_RETRY_FAILED")
    _denied(lambda:store.transition(token,action="FINALIZE_TRIAL"))
    _check(_ledger_count(psycopg,student)==1
           and _row(psycopg,key)==("FINALIZED_TRIAL",True,True,False),
           "FINALIZE_RETRY_DUPLICATED")
    # Test-only token finalization is not File AVAILABLE, media persistence,
    # or a production idempotency/side-effect guarantee.


def run_photo_consume_first_transfer_backend_retry(
    psycopg, *, container, run_psql
):
    if container!=CONTAINER:
        raise RuntimeError("D1_PHOTO_CONSUME_FIRST_RECOVERY_DISPOSABLE_ONLY")
    run_psql(container,SETUP_SQL,
            "D1_PHOTO_CONSUME_FIRST_RECOVERY_SETUP",timeout=90)
    _consume_first_then_transfer(psycopg)
    print("D1_STUDENT_PHOTO_CONSUME_FIRST_TRANSFER_PASS "
          "real P1 Campus Transfer waits for native PG CONSUME commit; "
          "Campus A FINALIZE then denied; no file and no photo SET")
    _real_backend_abort_retries(psycopg)
    print("D1_STUDENT_PHOTO_PG_BACKEND_ABORT_RETRY_PASS "
          "real terminated PostgreSQL backend rolls back ISSUE/CONSUME/"
          "FINALIZE_TRIAL; fresh-session retry once, replay denied; "
          "DISPOSABLE LOCAL ONLY")
