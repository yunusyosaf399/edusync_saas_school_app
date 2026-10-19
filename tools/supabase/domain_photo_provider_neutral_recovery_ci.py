"""External-transaction rehearsal using a separate durable SQLite metadata provider.

DISPOSABLE CI ONLY. No bytes, object storage, HTTP, public identity or Photo SET.
PostgreSQL records authoritative intent/receipt/outbox; a separate SQLite file
represents a provider that may commit before an ACK is lost. Unique deterministic
delivery IDs provide idempotency for this synthetic provider *only*.
"""
from __future__ import annotations

from concurrent.futures import ThreadPoolExecutor
from contextlib import closing
from hashlib import sha256
from pathlib import Path
from tempfile import TemporaryDirectory
from threading import Event
import sqlite3
from uuid import UUID,uuid4

from domain_photo_postgres_native_intent_ci import (
    CONTAINER,NativePostgresPhotoIntentTrial,_check,_denied,_digest,_row,_deny,
)
from domain_photo_pg_lost_ack_outbox_ci import NativeAckOutboxTrial
from domain_photo_reverse_end_campus_transfer_ci import (
    _p0_new_student,_public_actor,_no_current_source,
)
from domain_student_photo_real_pg_handoff_ci import (
    CAMPUS,_actor_connection,_local_connect,
)

STUDENT="f2000000-0000-4000-8000-000000000001"
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
INSERT INTO app_private.people(id,display_name,created_by) VALUES (
 'f2000000-0000-4000-8000-000000000003',
 'Disposable provider delivery Student',
 '11111111-1111-4111-8111-111111111111');
INSERT INTO app_private.students(
 id,person_id,school_student_id,admission_number,admission_serial,
 admitted_on,current_status,created_by) VALUES (
 'f2000000-0000-4000-8000-000000000001',
 'f2000000-0000-4000-8000-000000000003',
 'PHOTO-PROVIDER-DELIVERY-TRIAL','PHOTO-PROVIDER-94',94007,
 CURRENT_DATE-20,'ACTIVE','11111111-1111-4111-8111-111111111111');
INSERT INTO app_private.student_status_transitions(
 id,student_id,previous_status,new_status,effective_on,
 sequence_number,reason,created_by) VALUES (
 'f2000000-0000-4000-8000-000000000002',
 'f2000000-0000-4000-8000-000000000001',
 NULL,'ACTIVE',CURRENT_DATE-20,1,'Synthetic initial ACTIVE',
 '11111111-1111-4111-8111-111111111111');
RESET ROLE;
SET ROLE schoolos_student_executor;
CREATE TABLE photo_pg_trial.provider_dispositions(
 event_id uuid PRIMARY KEY REFERENCES photo_pg_trial.outbox_events(event_id),
 provider_key bytea NOT NULL UNIQUE CHECK (
   pg_catalog.octet_length(provider_key)=32),
 disposition text NOT NULL CHECK (
   disposition IN ('ACKED','CANCELLED')),
 created_at timestamptz NOT NULL DEFAULT pg_catalog.clock_timestamp()
);
ALTER TABLE photo_pg_trial.provider_dispositions ENABLE ROW LEVEL SECURITY;
ALTER TABLE photo_pg_trial.provider_dispositions FORCE ROW LEVEL SECURITY;
CREATE POLICY photo_provider_disposition_local ON
 photo_pg_trial.provider_dispositions
 FOR ALL TO schoolos_student_executor USING (true) WITH CHECK (true);
REVOKE ALL ON TABLE photo_pg_trial.provider_dispositions
 FROM PUBLIC,anon,authenticated,service_role;
RESET ROLE;
COMMIT;
"""


def _delivery_key(event_id,token_digest,action):
    if type(token_digest) is not bytes or len(token_digest)!=32:
        _deny()
    if action not in ("CONSUME","FINALIZE_TRIAL"):
        _deny()
    try:
        event_bytes=UUID(str(event_id)).bytes
    except (TypeError,AttributeError,ValueError):
        _deny()
    return sha256(b"edusync-photo-provider-metadata-v1:"
                  +event_bytes+token_digest+action.encode("ascii")).digest()


class ProviderReplyLost(RuntimeError):
    """Local simulation: separate provider committed but caller got no ACK."""


class MockMetadataProvider:
    """Separate durable SQLite transaction, *never* a real media provider."""

    def __init__(self,path):
        self.path=str(path)
        with closing(self._connect()) as con:
            con.execute("""CREATE TABLE IF NOT EXISTS provider_metadata (
               provider_key BLOB PRIMARY KEY CHECK(length(provider_key)=32),
               event_id TEXT NOT NULL UNIQUE,
               token_digest BLOB NOT NULL CHECK(length(token_digest)=32),
               action TEXT NOT NULL CHECK(action IN ('CONSUME','FINALIZE_TRIAL')),
               state TEXT NOT NULL CHECK(state IN ('ACCEPTED','VOIDED'))
               )""")
            con.commit()

    def _connect(self):
        con=sqlite3.connect(self.path,timeout=10)
        con.execute("PRAGMA busy_timeout=10000")
        return con

    def accept(self,*,event_id,key,token_digest,action,lose_response=False):
        if (type(key) is not bytes or type(token_digest) is not bytes
                or _delivery_key(event_id,token_digest,action)!=key):
            _deny()
        with closing(self._connect()) as con:
            with con:
                con.execute(
                    "INSERT OR IGNORE INTO provider_metadata "
                    "(provider_key,event_id,token_digest,action,state) "
                    "VALUES (?,?,?,?,'ACCEPTED')",
                    (key,str(event_id),token_digest,action))
                row=con.execute(
                    "SELECT event_id,token_digest,action,state "
                    "FROM provider_metadata WHERE provider_key=?",(key,)
                ).fetchone()
                if row!=(str(event_id),token_digest,action,"ACCEPTED"):
                    _deny()
        # SQLite has already COMMITTED at this point: PostgreSQL still has
        # an uncommitted delivery decision in a separate connection.
        if lose_response:
            raise ProviderReplyLost("synthetic provider accepted; ACK lost")
        return str(event_id)

    def void(self,*,event_id,key,token_digest,action,lose_response=False):
        if _delivery_key(event_id,token_digest,action)!=key:
            _deny()
        with closing(self._connect()) as con:
            with con:
                row=con.execute(
                    "SELECT event_id,token_digest,action,state "
                    "FROM provider_metadata WHERE provider_key=?",(key,)
                ).fetchone()
                if row is None or row[:3]!=(str(event_id),token_digest,action):
                    _deny()
                con.execute(
                    "UPDATE provider_metadata SET state='VOIDED' "
                    "WHERE provider_key=? AND state='ACCEPTED'",(key,))
        if lose_response:
            raise ProviderReplyLost("synthetic VOID committed; ACK lost")
        return str(event_id)

    def rows(self):
        with closing(self._connect()) as con:
            return con.execute(
                "SELECT event_id,state FROM provider_metadata "
                "ORDER BY event_id").fetchall()

    def state(self,event_id):
        with closing(self._connect()) as con:
            row=con.execute(
                "SELECT state FROM provider_metadata WHERE event_id=?",
                (str(event_id),)).fetchone()
            return None if row is None else row[0]


class ProviderQueueWorker:
    """No-login private queue client; remote mock metadata only."""

    def __init__(self,store,provider):
        if (type(store) is not NativePostgresPhotoIntentTrial
                or type(provider) is not MockMetadataProvider):
            _deny()
        self.store=store
        self.provider=provider

    def deliver_one(self,*,fail_before_provider=False,
                    lose_provider_reply=False,lose_db_reply=False,
                    before_commit_test_hook=None):
        if (any(type(v) is not bool for v in (
                fail_before_provider,lose_provider_reply,lose_db_reply))
                or (before_commit_test_hook is not None
                    and not callable(before_commit_test_hook))):
            _deny()
        try:
            with closing(self.store._open()) as con:
                with con:
                    with closing(con.cursor()) as cur:
                        # Claim the queue first so an independent worker can
                        # SKIP LOCKED instead of waiting on Student FOR UPDATE.
                        cur.execute("""
                          SELECT event_id,request_digest,token_digest,action
                          FROM photo_pg_trial.outbox_events
                          WHERE delivery_state='PENDING'
                          ORDER BY event_id FOR UPDATE SKIP LOCKED LIMIT 1
                        """)
                        event=cur.fetchone()
                        if event is None:
                            return None
                        event_id=str(event[0])
                        request_digest,token_digest,action=event[1:]
                        principal=self.store._authorized(cur)
                        cur.execute("""
                          SELECT token_digest,student_id,campus_id,principal_id,
                                 action,target_status
                          FROM photo_pg_trial.ack_receipts
                          WHERE event_id=%s::uuid AND request_digest=%s
                        """,(event_id,request_digest))
                        receipt=cur.fetchone()
                        target={"CONSUME":"CONSUMED",
                                "FINALIZE_TRIAL":"FINALIZED_TRIAL"}.get(action)
                        if (receipt is None or target is None
                                or receipt[0]!=token_digest
                                or str(receipt[1])!=self.store._student
                                or str(receipt[2])!=self.store._campus
                                or str(receipt[3])!=principal
                                or receipt[4]!=action or receipt[5]!=target):
                            _deny()
                        cur.execute(
                            "SELECT status FROM photo_pg_trial.intents "
                            "WHERE token_digest=%s FOR UPDATE",(token_digest,))
                        if cur.fetchone()!=(target,):
                            _deny()
                        key=_delivery_key(event_id,token_digest,action)
                        if fail_before_provider:
                            _deny()
                        self.provider.accept(
                            event_id=event_id,key=key,
                            token_digest=token_digest,action=action,
                            lose_response=lose_provider_reply)
                        cur.execute("""
                           INSERT INTO photo_pg_trial.provider_dispositions
                           (event_id,provider_key,disposition)
                           VALUES (%s::uuid,%s,'ACKED')
                           ON CONFLICT (event_id) DO NOTHING
                        """,(event_id,key))
                        cur.execute("""
                           SELECT provider_key,disposition
                           FROM photo_pg_trial.provider_dispositions
                           WHERE event_id=%s::uuid
                        """,(event_id,))
                        if cur.fetchone()!=(key,"ACKED"):
                            _deny()
                        cur.execute("""
                           UPDATE photo_pg_trial.outbox_events
                           SET delivery_state='DELIVERED',
                               delivered_at=pg_catalog.clock_timestamp()
                           WHERE event_id=%s::uuid AND delivery_state='PENDING'
                           RETURNING event_id
                        """,(event_id,))
                        if cur.fetchone() is None:
                            _deny()
                        if before_commit_test_hook is not None:
                            before_commit_test_hook()
            if lose_db_reply:
                _deny()
            return event_id
        except Exception:
            _deny()

    def cancel_ended(self,psycopg,*,lose_provider_reply=False):
        """Privileged disposable-only reconciliation, no production path.

        Require no current effective PRIMARY placement (real ended Student);
        metadata already accepted by the separate provider is VOIDED before
        the local outbox is acknowledged as terminally CANCELLED.
        """
        if type(lose_provider_reply) is not bool:
            _deny()
        try:
            with closing(_local_connect(psycopg)) as con:
                with con:
                    with closing(con.cursor()) as cur:
                        cur.execute("""
                          SELECT o.event_id,o.token_digest,o.action,
                                 r.student_id
                          FROM photo_pg_trial.outbox_events o
                          JOIN photo_pg_trial.ack_receipts r
                            ON r.event_id=o.event_id
                          WHERE o.delivery_state='PENDING'
                          ORDER BY o.event_id
                          FOR UPDATE OF o SKIP LOCKED LIMIT 1
                        """)
                        event=cur.fetchone()
                        if event is None:
                            _deny()
                        event_id,token_digest,action,student=event
                        if str(student)!=self.store._student:
                            _deny()
                        cur.execute("""
                          SELECT count(*) FROM app_private.enrollments e
                          WHERE e.student_id=%s::uuid
                          AND e.placement_kind='PRIMARY'
                          AND e.placement_state='ACTIVE'
                          AND e.effective_from<=CURRENT_DATE
                          AND (e.effective_until IS NULL
                               OR CURRENT_DATE<e.effective_until)
                        """,(student,))
                        if cur.fetchone()!=(0,):
                            _deny()
                        key=_delivery_key(event_id,token_digest,action)
                        self.provider.void(
                            event_id=event_id,key=key,
                            token_digest=token_digest,action=action,
                            lose_response=lose_provider_reply)
                        cur.execute("""
                          INSERT INTO photo_pg_trial.provider_dispositions
                          (event_id,provider_key,disposition)
                          VALUES (%s::uuid,%s,'CANCELLED')
                          ON CONFLICT (event_id) DO NOTHING
                        """,(event_id,key))
                        cur.execute("""
                          SELECT provider_key,disposition
                          FROM photo_pg_trial.provider_dispositions
                          WHERE event_id=%s::uuid
                        """,(event_id,))
                        if cur.fetchone()!=(key,"CANCELLED"):
                            _deny()
                        cur.execute("""
                          UPDATE photo_pg_trial.outbox_events
                          SET delivery_state='DELIVERED',
                              delivered_at=pg_catalog.clock_timestamp()
                          WHERE event_id=%s::uuid AND delivery_state='PENDING'
                          RETURNING event_id
                        """,(event_id,))
                        if cur.fetchone() is None:
                            _deny()
            return str(event_id)
        except Exception:
            _deny()


def _pg_status(psycopg,event_id):
    with closing(_local_connect(psycopg)) as con:
        with closing(con.cursor()) as cur:
            cur.execute("""
              SELECT o.delivery_state,d.disposition
              FROM photo_pg_trial.outbox_events o
              LEFT JOIN photo_pg_trial.provider_dispositions d
                ON d.event_id=o.event_id
              WHERE o.event_id=%s::uuid
            """,(event_id,))
            state=cur.fetchone()
        con.rollback()
    return state


def _outbox_count(psycopg):
    with closing(_local_connect(psycopg)) as con:
        with closing(con.cursor()) as cur:
            cur.execute("SELECT count(*) FROM photo_pg_trial.outbox_events")
            row=cur.fetchone()[0]
        con.rollback()
    return row


def _requeue_test_event(psycopg,event_id):
    # Privileged local-only artificial retry. Never expose this in a service.
    with closing(_local_connect(psycopg)) as con:
        with con:
            with closing(con.cursor()) as cur:
                cur.execute("""
                  UPDATE photo_pg_trial.outbox_events
                  SET delivery_state='PENDING',delivered_at=NULL
                  WHERE event_id=%s::uuid AND delivery_state='DELIVERED'
                  RETURNING event_id
                """,(event_id,))
                _check(cur.fetchone() is not None,"PROVIDER_DUPLICATE_REQUEUE")


def run_photo_provider_neutral_recovery_trial(psycopg,*,container,run_psql):
    if container!=CONTAINER:
        raise RuntimeError("D1_PHOTO_PROVIDER_RECOVERY_DISPOSABLE_ONLY")
    run_psql(container,SETUP_SQL,"D1_PHOTO_PROVIDER_SETUP",timeout=90)
    # New synthetic Student gets a genuine P0 Enrollment and Roll (no fake DML).
    source_id,source_start,source_section=_p0_new_student(
        psycopg,STUDENT,"photo-provider-recovery-new-student-p0")
    store=NativePostgresPhotoIntentTrial(
        db_connect=lambda:_actor_connection(psycopg),
        student_id=STUDENT,campus_id=CAMPUS)
    receipt_trial=NativeAckOutboxTrial(store)

    with TemporaryDirectory(prefix="edusync_provider_mock_") as folder:
        provider=MockMetadataProvider(Path(folder)/"metadata.sqlite")
        worker=ProviderQueueWorker(store,provider)

        # 1. Failure before provider acceptance is fully retriable.
        token=store.issue()
        first=receipt_trial.apply(
            token,action="CONSUME",request_id=str(uuid4()))[0]
        _denied(lambda:worker.deliver_one(fail_before_provider=True))
        _check(provider.state(first) is None
               and _pg_status(psycopg,first)==("PENDING",None),
               "PROVIDER_PRE_ACCEPT_FAILURE_LEAK")

        # 2. Provider COMMIT succeeds but caller loses its acknowledgement;
        # PG rolls back and exact deterministic provider key retries safely.
        _denied(lambda:worker.deliver_one(lose_provider_reply=True))
        _check(provider.state(first)=="ACCEPTED"
               and _pg_status(psycopg,first)==("PENDING",None),
               "PROVIDER_UNCERTAIN_ACCEPT_NOT_RECONCILABLE")
        _check(worker.deliver_one()==first,"PROVIDER_RETRY_DID_NOT_ACK")
        _check(_pg_status(psycopg,first)==("DELIVERED","ACKED")
               and len(provider.rows())==1,"PROVIDER_RETRY_DUPLICATE")
        # Force a duplicate schedule: stable event key returns same metadata.
        _requeue_test_event(psycopg,first)
        _check(worker.deliver_one()==first
               and len(provider.rows())==1,"PROVIDER_REDELIVERY_DUPLICATED")

        # 3. Two live PostgreSQL workers compete for one pending event,
        # despite provider acceptance being committed in a separate store.
        second_token=store.issue()
        second=receipt_trial.apply(second_token,action="CONSUME",
                                   request_id=str(uuid4()))[0]
        entered=Event()
        release=Event()
        def pause_after_provider_commit():
            entered.set()
            if not release.wait(15):
                raise RuntimeError("D1_PHOTO_PROVIDER_HOLD_TIMEOUT")
        with ThreadPoolExecutor(max_workers=2) as pool:
            one=pool.submit(worker.deliver_one,
                            before_commit_test_hook=pause_after_provider_commit)
            try:
                _check(entered.wait(10),"PROVIDER_WORKER_NOT_HELD")
                _check(provider.state(second)=="ACCEPTED"
                       and _pg_status(psycopg,second)==("PENDING",None),
                       "PROVIDER_SEPARATE_COMMIT_NOT_VISIBLE")
                other=pool.submit(worker.deliver_one)
                _check(other.result(timeout=8) is None,
                       "PROVIDER_DOUBLE_CLAIM")
            finally:
                release.set()
            _check(one.result(timeout=12)==second,
                   "PROVIDER_FIRST_WORKER_NOT_ACKED")
        _check(len(provider.rows())==2
               and _pg_status(psycopg,second)==("DELIVERED","ACKED"),
               "PROVIDER_CONCURRENT_WORKERS_DUPLICATED")

        # 4. PostgreSQL delivery commits, then its response gets lost.
        third_token=store.issue()
        third=receipt_trial.apply(third_token,action="CONSUME",
                                  request_id=str(uuid4()))[0]
        _denied(lambda:worker.deliver_one(lose_db_reply=True))
        _check(_pg_status(psycopg,third)==("DELIVERED","ACKED")
               and worker.deliver_one() is None
               and len(provider.rows())==3,
               "PROVIDER_PG_ACK_LOST_REPLAY")

        # 5. Remote acceptance precedes a protected Student Enrollment END;
        # after scope vanishes, normal delivery is denied, while a *local*
        # privileged compensator can VOID the metadata and record CANCELLED.
        fourth_token=store.issue()
        fourth=receipt_trial.apply(fourth_token,action="CONSUME",
                                   request_id=str(uuid4()))[0]
        _denied(lambda:worker.deliver_one(lose_provider_reply=True))
        _check(provider.state(fourth)=="ACCEPTED"
               and _pg_status(psycopg,fourth)==("PENDING",None),
               "PROVIDER_COMPENSATE_PRECONDITION")
        with closing(_public_actor(psycopg,"photo-provider-p1-real-end")) as con:
            with con:
                with closing(con.cursor()) as cur:
                    cur.execute("""
                      SELECT * FROM app.d1_end_student_enrollment(
                        %s::uuid,1,%s::uuid,%s::uuid,%s::date,CURRENT_DATE,
                        'Cancel pending mock provider event after real END',%s)
                    """,(STUDENT,source_id,source_section,source_start,
                         "photo-provider-end-compensation-20261019"))
                    _check(cur.fetchone() is not None,
                           "PROVIDER_PROTECTED_END_FAILED")
        _no_current_source(psycopg,STUDENT,None)
        _denied(lambda:worker.deliver_one())
        _denied(lambda:worker.cancel_ended(
            psycopg,lose_provider_reply=True))
        _check(provider.state(fourth)=="VOIDED"
               and _pg_status(psycopg,fourth)==("PENDING",None),
               "PROVIDER_VOID_ACK_LOST_STATE")
        _check(worker.cancel_ended(psycopg)==fourth,
               "PROVIDER_VOID_RETRY_FAILED")
        _check(_pg_status(psycopg,fourth)==("DELIVERED","CANCELLED")
               and provider.state(fourth)=="VOIDED",
               "PROVIDER_COMPENSATION_NOT_ATOMICALLY_RECORDED")
        _check(len(provider.rows())==4 and _outbox_count(psycopg)==4,
               "PROVIDER_FINAL_EVENT_DUPLICATION")
        _check(_row(psycopg,_digest(fourth_token))==
               ("CONSUMED",True,False,False),
               "PROVIDER_CANCEL_CHANGED_NATIVE_TOKEN")
        _denied(lambda:store.transition(
            fourth_token,action="FINALIZE_TRIAL"))

    print("D1_STUDENT_PHOTO_PROVIDER_NEUTRAL_DELIVERY_PASS "
          "separate durable SQLite metadata provider; deterministic "
          "idempotency key, remote-commit ACK loss, same-PostgreSQL SKIP "
          "LOCKED two-worker claim, PG ACK loss and duplicate schedule; "
          "NO bytes or real object store")
    print("D1_STUDENT_PHOTO_PROVIDER_NEUTRAL_COMPENSATION_PASS "
          "genuine authenticated P1 END invalidates scope after remote "
          "mock acceptance; post-END new delivery denies; private local "
          "VOID ACK loss/retry and CANCELLED disposition; NO Photo SET")
