"""Disposable PostgreSQL ACK-loss + same-store outbox rehearsal; NO file upload.

The trusted harness simulates a lost response AFTER COMMIT. Exactly one native
token transition, receipt and outbox row share a PostgreSQL transaction. Outbox
delivery uses a same-PostgreSQL synthetic sink, NOT an external object store.
Only disposable local no-login executor connections may invoke these paths.
"""
from __future__ import annotations

from concurrent.futures import ThreadPoolExecutor
from contextlib import closing
from hashlib import sha256
from threading import Event
from uuid import UUID, uuid4

from domain_photo_postgres_native_intent_ci import (
    CONTAINER, NativePostgresPhotoIntentTrial, NativeIntentDenied,
    _check, _denied, _digest, _row, _deny,
)
from domain_photo_reverse_end_campus_transfer_ci import _p0_new_student
from domain_student_photo_real_pg_handoff_ci import (
    CAMPUS, _actor_connection, _local_connect,
)

STUDENT="f1000000-0000-4000-8000-000000000001"
SETUP_SQL="""
BEGIN;
SET ROLE schoolos_schema_owner;
INSERT INTO app_private.people(id,display_name,created_by) VALUES (
 'f1000000-0000-4000-8000-000000000003',
 'Disposable lost acknowledgement outbox Student',
 '11111111-1111-4111-8111-111111111111');
INSERT INTO app_private.students(
 id,person_id,school_student_id,admission_number,admission_serial,
 admitted_on,current_status,created_by) VALUES (
 'f1000000-0000-4000-8000-000000000001',
 'f1000000-0000-4000-8000-000000000003',
 'PHOTO-OUTBOX-ACK-TRIAL','PHOTO-OUTBOX-ACK-94',94006,
 CURRENT_DATE-20,'ACTIVE','11111111-1111-4111-8111-111111111111');
INSERT INTO app_private.student_status_transitions(
 id,student_id,previous_status,new_status,effective_on,
 sequence_number,reason,created_by) VALUES (
 'f1000000-0000-4000-8000-000000000002',
 'f1000000-0000-4000-8000-000000000001',
 NULL,'ACTIVE',CURRENT_DATE-20,1,'Synthetic initial ACTIVE status',
 '11111111-1111-4111-8111-111111111111');
RESET ROLE;
-- Existing quarantined schema is from PR95, owned by the non-login executor.
SET ROLE schoolos_student_executor;
CREATE TABLE photo_pg_trial.ack_receipts (
 request_digest bytea PRIMARY KEY
   CHECK (pg_catalog.octet_length(request_digest)=32),
 token_digest bytea NOT NULL REFERENCES photo_pg_trial.intents(token_digest),
 student_id uuid NOT NULL, campus_id uuid NOT NULL, principal_id uuid NOT NULL,
 action text NOT NULL CHECK(action IN ('CONSUME','FINALIZE_TRIAL')),
 target_status text NOT NULL CHECK(
   (action='CONSUME' AND target_status='CONSUMED') OR
   (action='FINALIZE_TRIAL' AND target_status='FINALIZED_TRIAL')),
 event_id uuid NOT NULL UNIQUE,
 created_at timestamptz NOT NULL DEFAULT pg_catalog.clock_timestamp(),
 UNIQUE (token_digest,action)
);
CREATE TABLE photo_pg_trial.outbox_events (
 event_id uuid PRIMARY KEY REFERENCES photo_pg_trial.ack_receipts(event_id),
 request_digest bytea NOT NULL UNIQUE
   REFERENCES photo_pg_trial.ack_receipts(request_digest),
 token_digest bytea NOT NULL REFERENCES photo_pg_trial.intents(token_digest),
 action text NOT NULL CHECK(action IN ('CONSUME','FINALIZE_TRIAL')),
 delivery_state text NOT NULL DEFAULT 'PENDING'
   CHECK(delivery_state IN ('PENDING','DELIVERED')),
 delivered_at timestamptz,
 CHECK ((delivery_state='PENDING' AND delivered_at IS NULL)
        OR (delivery_state='DELIVERED' AND delivered_at IS NOT NULL))
);
CREATE TABLE photo_pg_trial.mock_sink (
 event_id uuid PRIMARY KEY REFERENCES photo_pg_trial.outbox_events(event_id),
 request_digest bytea NOT NULL UNIQUE,
 action text NOT NULL CHECK(action IN ('CONSUME','FINALIZE_TRIAL')),
 accepted_at timestamptz NOT NULL DEFAULT pg_catalog.clock_timestamp()
);
ALTER TABLE photo_pg_trial.ack_receipts ENABLE ROW LEVEL SECURITY;
ALTER TABLE photo_pg_trial.ack_receipts FORCE ROW LEVEL SECURITY;
ALTER TABLE photo_pg_trial.outbox_events ENABLE ROW LEVEL SECURITY;
ALTER TABLE photo_pg_trial.outbox_events FORCE ROW LEVEL SECURITY;
ALTER TABLE photo_pg_trial.mock_sink ENABLE ROW LEVEL SECURITY;
ALTER TABLE photo_pg_trial.mock_sink FORCE ROW LEVEL SECURITY;
CREATE POLICY photo_ack_trial_executor ON photo_pg_trial.ack_receipts
 FOR ALL TO schoolos_student_executor USING (true) WITH CHECK (true);
CREATE POLICY photo_outbox_trial_executor ON photo_pg_trial.outbox_events
 FOR ALL TO schoolos_student_executor USING (true) WITH CHECK (true);
CREATE POLICY photo_mock_sink_executor ON photo_pg_trial.mock_sink
 FOR ALL TO schoolos_student_executor USING (true) WITH CHECK (true);
REVOKE ALL ON TABLE photo_pg_trial.ack_receipts,
 photo_pg_trial.outbox_events,photo_pg_trial.mock_sink
 FROM PUBLIC,anon,authenticated,service_role;
RESET ROLE;
COMMIT;
"""


def _request_digest(request_id: str) -> bytes:
    if type(request_id) is not str:
        _deny()
    try:
        uuid=UUID(request_id)
    except (ValueError,AttributeError,TypeError):
        _deny()
    if str(uuid)!=request_id or uuid.version!=4:
        _deny()
    return sha256(b"photo_pg_trial.receipt.v1:"+uuid.bytes).digest()


class NativeAckOutboxTrial:
    """Trusted disposable executor only; no client RPC or external transport."""

    def __init__(self, store: NativePostgresPhotoIntentTrial):
        if type(store) is not NativePostgresPhotoIntentTrial:
            _deny()
        self.store=store

    def apply(self, token: str, *, action: str, request_id: str,
              lose_ack=False) -> tuple[str,str]:
        digest=_digest(token)
        request=_request_digest(request_id)
        if action not in ("CONSUME","FINALIZE_TRIAL") or type(lose_ack) is not bool:
            _deny()
        source,target,stamp={
            "CONSUME":("ISSUED","CONSUMED","consumed_at"),
            "FINALIZE_TRIAL":("CONSUMED","FINALIZED_TRIAL","finalized_at"),
        }[action]
        try:
            with closing(self.store._open()) as con:
                with con:
                    with closing(con.cursor()) as cur:
                        # Identical shared Foundation lock / Student FOR UPDATE /
                        # live Principal and private current PRIMARY Campus grants.
                        principal=self.store._authorized(cur)
                        cur.execute(
                            "SELECT token_digest,student_id,campus_id,principal_id,"
                            "action,target_status,event_id FROM photo_pg_trial.ack_receipts "
                            "WHERE request_digest=%s FOR UPDATE",(request,))
                        receipt=cur.fetchone()
                        if receipt is not None:
                            if (receipt[0]!=digest or str(receipt[1])!=self.store._student
                                    or str(receipt[2])!=self.store._campus
                                    or str(receipt[3])!=principal
                                    or receipt[4]!=action or receipt[5]!=target):
                                _deny()
                            cur.execute(
                                "SELECT status FROM photo_pg_trial.intents "
                                "WHERE token_digest=%s FOR UPDATE",(digest,))
                            current=cur.fetchone()
                            if current!=(target,):
                                _deny()
                            result=(str(receipt[6]),target)
                        else:
                            cur.execute(
                                "SELECT student_id,campus_id,principal_id,status,"
                                "(expires_at>pg_catalog.clock_timestamp()) "
                                "FROM photo_pg_trial.intents "
                                "WHERE token_digest=%s FOR UPDATE",(digest,))
                            row=cur.fetchone()
                            if (row is None or str(row[0])!=self.store._student
                                    or str(row[1])!=self.store._campus
                                    or str(row[2])!=principal or row[3]!=source
                                    or row[4] is not True):
                                _deny()
                            cur.execute(
                                "UPDATE photo_pg_trial.intents SET status=%s,"
                                f"{stamp}=pg_catalog.clock_timestamp() "
                                "WHERE token_digest=%s AND status=%s RETURNING status",
                                (target,digest,source))
                            if cur.fetchone()!=(target,):
                                _deny()
                            event_id=str(uuid4())
                            cur.execute(
                                "INSERT INTO photo_pg_trial.ack_receipts "
                                "(request_digest,token_digest,student_id,campus_id,"
                                "principal_id,action,target_status,event_id) "
                                "VALUES (%s,%s,%s::uuid,%s::uuid,%s::uuid,%s,%s,%s::uuid)",
                                (request,digest,self.store._student,self.store._campus,
                                 principal,action,target,event_id))
                            cur.execute(
                                "INSERT INTO photo_pg_trial.outbox_events "
                                "(event_id,request_digest,token_digest,action) "
                                "VALUES (%s::uuid,%s,%s,%s)",
                                (event_id,request,digest,action))
                            result=(event_id,target)
            # PostgreSQL committed; simulate losing the reply *after* COMMIT.
            # Repeating the same stable request_id retrieves its receipt.
            if lose_ack:
                _deny()
            return result
        except NativeIntentDenied:
            raise
        except Exception:
            _deny()

    def deliver_one(self, *, fail_before_commit=False, lose_ack=False,
                    before_commit_test_hook=None) -> str | None:
        if (type(fail_before_commit) is not bool or type(lose_ack) is not bool
                or (before_commit_test_hook is not None
                    and not callable(before_commit_test_hook))):
            _deny()
        try:
            with closing(self.store._open()) as con:
                with con:
                    with closing(con.cursor()) as cur:
                        # Trusted local queue worker: not reusing the Student's
                        # photo scope; delivery is of a *committed* event only.
                        # No client role has schema/table privileges.
                        cur.execute(
                            "SELECT event_id,request_digest,action "
                            "FROM photo_pg_trial.outbox_events "
                            "WHERE delivery_state='PENDING' "
                            "ORDER BY event_id FOR UPDATE SKIP LOCKED LIMIT 1")
                        event=cur.fetchone()
                        if event is None:
                            return None
                        event_id=str(event[0])
                        cur.execute(
                            "INSERT INTO photo_pg_trial.mock_sink "
                            "(event_id,request_digest,action) VALUES "
                            "(%s::uuid,%s,%s) ON CONFLICT (event_id) DO NOTHING",
                            (event_id,event[1],event[2]))
                        cur.execute(
                            "SELECT request_digest,action FROM photo_pg_trial.mock_sink "
                            "WHERE event_id=%s::uuid",(event_id,))
                        if cur.fetchone()!=(event[1],event[2]):
                            _deny()
                        cur.execute(
                            "UPDATE photo_pg_trial.outbox_events "
                            "SET delivery_state='DELIVERED',"
                            "delivered_at=pg_catalog.clock_timestamp() "
                            "WHERE event_id=%s::uuid AND delivery_state='PENDING' "
                            "RETURNING event_id",(event_id,))
                        if cur.fetchone() is None:
                            _deny()
                        if fail_before_commit:
                            _deny()
                        if before_commit_test_hook is not None:
                            before_commit_test_hook()
            if lose_ack:
                _deny()
            return event_id
        except NativeIntentDenied:
            raise
        except Exception:
            _deny()


def _counts(psycopg, student):
    with closing(_local_connect(psycopg)) as con:
        with closing(con.cursor()) as cur:
            cur.execute(
                "SELECT count(*) FROM photo_pg_trial.ack_receipts "
                "WHERE student_id=%s::uuid",(student,))
            receipts=cur.fetchone()[0]
            cur.execute(
                "SELECT count(*),count(*) FILTER (WHERE delivery_state='DELIVERED') "
                "FROM photo_pg_trial.outbox_events")
            outbox=cur.fetchone()
            cur.execute("SELECT count(*) FROM photo_pg_trial.mock_sink")
            sink=cur.fetchone()[0]
        con.rollback()
    return (receipts,outbox[0],outbox[1],sink)


def _assert_private(psycopg):
    # Client-facing authenticated role must not SELECT private queue tables.
    from psycopg.errors import InsufficientPrivilege
    for table in ("ack_receipts","outbox_events","mock_sink"):
        with closing(_actor_connection(psycopg)) as con:
            with closing(con.cursor()) as cur:
                cur.execute("RESET ROLE")
                cur.execute("SET ROLE authenticated")
                try:
                    cur.execute("SELECT count(*) FROM photo_pg_trial."+table)
                except InsufficientPrivilege:
                    con.rollback()
                else:
                    raise RuntimeError("D1_PHOTO_ACK_OUTBOX_CLIENT_READ_ALLOWED")


def run_photo_native_lost_ack_outbox_trial(psycopg, *, container: str,
                                           run_psql) -> None:
    if container!=CONTAINER:
        raise RuntimeError("D1_PHOTO_ACK_OUTBOX_DISPOSABLE_ONLY")
    run_psql(container,SETUP_SQL,"D1_PHOTO_ACK_OUTBOX_SETUP",timeout=90)
    _assert_private(psycopg)
    _p0_new_student(psycopg,STUDENT,"photo-native-ack-outbox-new-p0")
    store=NativePostgresPhotoIntentTrial(
        db_connect=lambda:_actor_connection(psycopg),
        student_id=STUDENT,campus_id=CAMPUS)
    trial=NativeAckOutboxTrial(store)
    token=store.issue()
    key=_digest(token)
    consume_request=str(uuid4())
    _denied(lambda:trial.apply(token,action="CONSUME",
                               request_id=consume_request,lose_ack=True))
    _check(_row(psycopg,key)==("CONSUMED",True,False,False),
           "CONSUME_LOST_ACK_DID_NOT_COMMIT")
    _check(_counts(psycopg,STUDENT)==(1,1,0,0),
           "CONSUME_RECEIPT_OUTBOX_NOT_ATOMIC")
    consume_receipt=trial.apply(token,action="CONSUME",
                                request_id=consume_request)
    _check(consume_receipt[1]=="CONSUMED","CONSUME_RECEIPT_REPLAY")
    _check(trial.apply(token,action="CONSUME",request_id=consume_request)
           ==consume_receipt,"CONSUME_RECEIPT_NOT_STABLE")
    _denied(lambda:trial.apply(token,action="CONSUME",
                               request_id=str(uuid4())))
    _denied(lambda:trial.apply(token,action="FINALIZE_TRIAL",
                               request_id=consume_request))
    _check(_counts(psycopg,STUDENT)==(1,1,0,0),"ACK_REPLAY_SIDE_EFFECT")

    _denied(lambda:trial.deliver_one(fail_before_commit=True))
    _check(_counts(psycopg,STUDENT)==(1,1,0,0),
           "OUTBOX_PRECOMMIT_ABORT_WAS_VISIBLE")

    # Two genuine independent PG connections: one locks the queue row, the
    # other SKIP LOCKED sees no delivery work. No double sink insertion.
    entered=Event()
    release=Event()
    def hold_one():
        entered.set()
        if not release.wait(15):
            raise RuntimeError("D1_PHOTO_ACK_OUTBOX_HOLD_TIMEOUT")
    with ThreadPoolExecutor(max_workers=2) as pool:
        first=pool.submit(trial.deliver_one,before_commit_test_hook=hold_one)
        try:
            _check(entered.wait(10),"OUTBOX_WORKER_NOT_HELD")
            other=pool.submit(trial.deliver_one)
            _check(other.result(timeout=8) is None,"OUTBOX_DOUBLE_CLAIM")
        finally:
            release.set()
        _check(first.result(timeout=12)==consume_receipt[0],
               "OUTBOX_FIRST_DELIVERY_NOT_COMMITTED")
    _check(_counts(psycopg,STUDENT)==(1,1,1,1),
           "OUTBOX_CONSUME_DUPLICATE_EFFECT")

    finalize_request=str(uuid4())
    _denied(lambda:trial.apply(token,action="FINALIZE_TRIAL",
                               request_id=finalize_request,lose_ack=True))
    _check(_row(psycopg,key)==("FINALIZED_TRIAL",True,True,False),
           "FINALIZE_LOST_ACK_DID_NOT_COMMIT")
    _check(_counts(psycopg,STUDENT)==(2,2,1,1),
           "FINALIZE_RECEIPT_OUTBOX_NOT_ATOMIC")
    final_receipt=trial.apply(token,action="FINALIZE_TRIAL",
                              request_id=finalize_request)
    _check(final_receipt[1]=="FINALIZED_TRIAL",
           "FINALIZE_LOST_ACK_REPLAY")
    _denied(lambda:trial.apply(token,action="FINALIZE_TRIAL",
                               request_id=str(uuid4())))
    _denied(lambda:trial.deliver_one(lose_ack=True))
    _check(_counts(psycopg,STUDENT)==(2,2,2,2),
           "OUTBOX_DELIVERY_ACK_LOST_DID_NOT_COMMIT")
    _check(trial.deliver_one() is None,
           "OUTBOX_ACK_LOST_REDELIVERED")
    # Simulate duplicate notification scheduling *after* a delivery
    # acknowledgement (privileged owner-only test operation). The sink's
    # stable event-id uniqueness prevents a second same-PG effect.
    with closing(_local_connect(psycopg)) as con:
        with con:
            with closing(con.cursor()) as cur:
                cur.execute(
                    "UPDATE photo_pg_trial.outbox_events "
                    "SET delivery_state='PENDING',delivered_at=NULL "
                    "WHERE event_id=%s::uuid AND delivery_state='DELIVERED'",
                    (final_receipt[0],))
    _check(trial.deliver_one()==final_receipt[0],
           "OUTBOX_REDELIVERY_NOT_ACKED")
    _check(_counts(psycopg,STUDENT)==(2,2,2,2),
           "OUTBOX_DUPLICATED_SINK_EFFECT")
    _check(trial.deliver_one() is None,"OUTBOX_STILL_PENDING")
    print("D1_STUDENT_PHOTO_PG_LOST_ACK_RECEIPT_PASS "
          "true PostgreSQL commit before lost reply, stable request digest "
          "replays same CONSUME and FINALIZE_TRIAL receipts, no extra events")
    print("D1_STUDENT_PHOTO_PG_DURABLE_OUTBOX_TRIAL_PASS "
          "same-PG atomic receipt/outbox/synthetic sink, precommit rollback, "
          "SKIP LOCKED two-session single claim, postcommit lost delivery ACK, "
          "idempotent replay by event ID; NO external storage or photo SET")
