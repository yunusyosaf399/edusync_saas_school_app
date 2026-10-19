"""True local PostgreSQL reverse winner and Campus Transfer/photo races.

No hosted SQL, no File AVAILABLE, no upload, and no artificial Enrollment DML.
This executes only after PR96's real END-first race in the disposable D1 stack.
"""
from __future__ import annotations

from concurrent.futures import ThreadPoolExecutor
from contextlib import closing
from threading import Event
import time

from domain_photo_postgres_native_intent_ci import (
    CONTAINER, NativePostgresPhotoIntentTrial, NativeIntentDenied,
    _check, _denied, _digest, _row,
)
from domain_student_photo_real_pg_handoff_ci import (
    CAMPUS, _actor_connection, _local_connect,
)
from domain_photo_protected_enrollment_end_race_ci import (
    SOURCE_SECTION, _observe_end_blocked_consumers,
)

END_STUDENT = "ed000000-0000-4000-8000-000000000001"
MOVE_STUDENT = "ec000000-0000-4000-8000-000000000001"
CAMPUS_B = "ec000000-0000-4000-8000-000000000041"
DEST_SECTION = "ec000000-0000-4000-8000-000000000045"
OWNER = "11111111-1111-4111-8111-111111111111"
END_KEY = "photo-p1-reverse-end-local"
MOVE_KEY = "photo-p1-campus-transfer-local"
PHOTO_FIRST_WORKER = "photo-native-first-finalize"
END_WAIT = "photo-p1-end-reverse-waiter"
MOVE_WAIT = "photo-p1-campus-transfer-waiter"

# A new Student must be created through the accepted protected P0 operation,
# never an owner-side Enrollment/roll insert. Reuse the existing School,
# approved Campus A/Class/Year and effective school-wide Roll allocator.
SETUP_SQL = """
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
INSERT INTO app_private.people(id,display_name,created_by) VALUES
 ('ed000000-0000-4000-8000-000000000003',
 'Disposable reverse END race Student', '11111111-1111-4111-8111-111111111111'),
 ('ec000000-0000-4000-8000-000000000003',
 'Disposable Campus Transfer race Student','11111111-1111-4111-8111-111111111111');
INSERT INTO app_private.students(
 id,person_id,school_student_id,admission_number,admission_serial,
 admitted_on,current_status,created_by) VALUES
 ('ed000000-0000-4000-8000-000000000001',
  'ed000000-0000-4000-8000-000000000003',
  'PHOTO-END-REVERSE-TEST','PHOTO-END-REVERSE-94',94002,
  CURRENT_DATE-20,'ACTIVE','11111111-1111-4111-8111-111111111111'),
 ('ec000000-0000-4000-8000-000000000001',
  'ec000000-0000-4000-8000-000000000003',
  'PHOTO-CAMPUS-MOVE-TEST','PHOTO-CAMPUS-MOVE-94',94003,
  CURRENT_DATE-20,'ACTIVE','11111111-1111-4111-8111-111111111111');
INSERT INTO app_private.student_status_transitions(
 id,student_id,previous_status,new_status,effective_on,
 sequence_number,reason,created_by) VALUES
 ('ed000000-0000-4000-8000-000000000002',
  'ed000000-0000-4000-8000-000000000001',
  NULL,'ACTIVE',CURRENT_DATE-20,1,'Synthetic initial ACTIVE status',
  '11111111-1111-4111-8111-111111111111'),
 ('ec000000-0000-4000-8000-000000000002',
  'ec000000-0000-4000-8000-000000000001',
  NULL,'ACTIVE',CURRENT_DATE-20,1,'Synthetic initial ACTIVE status',
  '11111111-1111-4111-8111-111111111111');
-- Genuine same-School distinct Campus B destination for CAMPUS_TRANSFER.
INSERT INTO app.campuses(id,school_id,code,name,state,created_by) VALUES (
 'ec000000-0000-4000-8000-000000000041',
 '22222222-2222-4222-8222-222222222222',
 'PHOTO-P1-TRANSFER-CAMPUS-B','Disposable photo Campus B',
 'ACTIVE','11111111-1111-4111-8111-111111111111');
INSERT INTO app_private.class_offerings(
 id,school_id,class_id,campus_id,academic_year_id,capacity,state,created_by)
VALUES ('ec000000-0000-4000-8000-000000000044',
 '22222222-2222-4222-8222-222222222222',
 'e4000000-0000-4000-8000-000000000043',
 'ec000000-0000-4000-8000-000000000041',
 'e4000000-0000-4000-8000-000000000042',30,'OPEN',
 '11111111-1111-4111-8111-111111111111');
INSERT INTO app_private.section_offerings(
 id,class_offering_id,campus_id,code,label,display_order,capacity,state,created_by)
VALUES ('ec000000-0000-4000-8000-000000000045',
 'ec000000-0000-4000-8000-000000000044',
 'ec000000-0000-4000-8000-000000000041',
 'B','Disposable transfer destination',1,30,'OPEN',
 '11111111-1111-4111-8111-111111111111');
INSERT INTO app_private.capacity_revisions(
 id,class_offering_id,section_offering_id,old_capacity,new_capacity,
 effective_on,reason,created_by)
VALUES ('ec000000-0000-4000-8000-000000000047',
 'ec000000-0000-4000-8000-000000000044',
 NULL,NULL,30,CURRENT_DATE-20,'Campus B Class capacity',
 '11111111-1111-4111-8111-111111111111'),
 ('ec000000-0000-4000-8000-000000000048',
 NULL,'ec000000-0000-4000-8000-000000000045',
 NULL,30,CURRENT_DATE-20,'Campus B Section capacity',
 '11111111-1111-4111-8111-111111111111');
UPDATE app_private.permissions SET state='ENABLED'
 WHERE code='student.enrollment.move';
UPDATE app_private.operation_contracts SET enabled=true
 WHERE code='student.enrollment.move';
UPDATE app_private.permission_scope_contracts SET enabled=true
 WHERE permission_id=(SELECT id FROM app_private.permissions
                      WHERE code='student.enrollment.move')
   AND scope_kind='ALL' AND resolver_key='DIRECT';
INSERT INTO app_private.role_permission_grants(
 id,role_id,role_family_only,permission_id,permission_family_safe,
 valid_from,created_by)
SELECT 'ec000000-0000-4000-8000-000000000057',
 'e9000000-0000-4000-8000-000000000001',false,id,family_safe,
 pg_catalog.statement_timestamp()-interval '1 hour',
 '11111111-1111-4111-8111-111111111111'
 FROM app_private.permissions WHERE code='student.enrollment.move';
INSERT INTO app_private.assignment_permission_scopes(
 id,assignment_id,grant_id,role_id,permission_id,scope_contract_id,
 scope_kind,resolver_key,valid_from,created_by)
SELECT 'ec000000-0000-4000-8000-000000000058',
 'e9000000-0000-4000-8000-000000000002',
 g.id,g.role_id,g.permission_id,c.id,'ALL','DIRECT',
 pg_catalog.statement_timestamp()-interval '1 hour',
 '11111111-1111-4111-8111-111111111111'
 FROM app_private.role_permission_grants g
 JOIN app_private.permission_scope_contracts c ON c.permission_id=g.permission_id
 WHERE g.id='ec000000-0000-4000-8000-000000000057'
 AND c.scope_kind='ALL' AND c.resolver_key='DIRECT';
INSERT INTO app_private.approval_policy_versions(
 id,policy_key,version,operation_id,d1_route_mode,created_by)
SELECT 'ec000000-0000-4000-8000-000000000059',
 'photo-p1-campus-transfer-direct-local',1,id,'DIRECT',
 '11111111-1111-4111-8111-111111111111'
 FROM app_private.operation_contracts WHERE code='student.enrollment.move';
UPDATE app_private.approval_policy_versions SET state='ACTIVE',
 effective_from=pg_catalog.statement_timestamp()-interval '1 hour',
 activated_at=pg_catalog.statement_timestamp()
 WHERE id='ec000000-0000-4000-8000-000000000059';
RESET ROLE;
COMMIT;
"""


def _source(psycopg, student):
    with closing(_local_connect(psycopg)) as con:
        with closing(con.cursor()) as cur:
            cur.execute("""
                SELECT e.id,e.effective_from,e.section_offering_id
                FROM app_private.enrollments e
                WHERE e.student_id=%s::uuid AND e.placement_kind='PRIMARY'
                  AND e.placement_state='ACTIVE'
                  AND e.effective_from<=CURRENT_DATE
                  AND (e.effective_until IS NULL OR CURRENT_DATE<e.effective_until)
            """,(student,))
            rows=cur.fetchall()
        con.rollback()
    _check(len(rows)==1 and str(rows[0][2])==SOURCE_SECTION,
           "P0_SOURCE_MISSING")
    return rows[0]


def _public_actor(psycopg, app_name):
    con=_actor_connection(psycopg)
    try:
        with closing(con.cursor()) as cur:
            cur.execute("RESET ROLE")
            cur.execute("SET ROLE authenticated")
            cur.execute("SELECT pg_catalog.set_config('application_name',%s,true)",
                        (app_name,))
        return con
    except Exception:
        con.close()
        raise


def _p0_new_student(psycopg, student, key):
    with closing(_public_actor(psycopg,"photo-p0-new-student")) as con:
        with con:
            with closing(con.cursor()) as cur:
                cur.execute("""
                  SELECT * FROM app.d1_place_student_enrollment(
                     %s::uuid,1,%s::uuid,'INITIAL',CURRENT_DATE-20,
                     NULL,'Disposable genuine P0 placement',NULL,%s)
                """,(student,SOURCE_SECTION,key))
                _check(cur.fetchone() is not None,"NEW_P0_DENIED")
    return _source(psycopg,student)


def _observe_waiter(psycopg, name, owner_pid, seconds=12):
    """A real unresolved lock must depend on the named winner PID."""
    deadline=time.monotonic()+seconds
    with closing(_local_connect(psycopg)) as con:
        while time.monotonic()<deadline:
            with closing(con.cursor()) as cur:
                cur.execute("""
                 SELECT EXISTS (
                   SELECT 1 FROM pg_catalog.pg_stat_activity a
                   JOIN pg_catalog.pg_locks l ON l.pid=a.pid
                   WHERE a.application_name=%s AND NOT l.granted
                     AND l.locktype IN ('tuple','transactionid')
                     AND %s=ANY(pg_catalog.pg_blocking_pids(a.pid))
                 )
                """,(name,owner_pid))
                found=cur.fetchone()[0]
            con.rollback()
            if found:
                return
            time.sleep(.05)
    raise RuntimeError("D1_PHOTO_P1_REVERSE_DIRECT_WAITER_NOT_OBSERVED")


def _no_current_source(psycopg, student, target_campus):
    with closing(_local_connect(psycopg)) as con:
        with closing(con.cursor()) as cur:
            cur.execute("""
               SELECT count(*),min(co.campus_id::text)
               FROM app_private.enrollments e
               JOIN app_private.section_offerings so ON so.id=e.section_offering_id
               JOIN app_private.class_offerings co ON co.id=so.class_offering_id
               WHERE e.student_id=%s::uuid AND e.placement_kind='PRIMARY'
                 AND e.placement_state='ACTIVE' AND e.effective_from<=CURRENT_DATE
                 AND (e.effective_until IS NULL OR CURRENT_DATE<e.effective_until)
            """,(student,))
            count,campus=cur.fetchone()
        con.rollback()
    _check(count == (1 if target_campus else 0)
           and campus==(target_campus if target_campus else None),
           "PRIMARY_STALE_AFTER_PROTECTED_COMMAND")


def _reverse_photo_first_end(psycopg):
    """Photo FINALIZE_TRIAL succeeds first; genuine P1 END then commits."""
    student=END_STUDENT
    source_id,source_start,source_section=_p0_new_student(
        psycopg,student,"photo-p1-reverse-p0")
    store=NativePostgresPhotoIntentTrial(
        db_connect=lambda:_actor_connection(psycopg),
        student_id=student,campus_id=CAMPUS)
    token=store.issue()
    _check(store.transition(token,action="CONSUME")=="CONSUMED",
           "PREPARE_REVERSE_FINALIZE")
    entered=Event()
    release=Event()
    pid_ready=Event()
    pid_holder=[]
    def _tagged_photo():
        con=_actor_connection(psycopg)
        with closing(con.cursor()) as cur:
            cur.execute("SELECT pg_catalog.set_config('application_name',%s,true)",
                        (PHOTO_FIRST_WORKER,))
            cur.execute("SELECT pg_catalog.pg_backend_pid()")
            pid_holder.append(int(cur.fetchone()[0]))
        pid_ready.set()
        return con
    photo=NativePostgresPhotoIntentTrial(
        db_connect=_tagged_photo,student_id=student,campus_id=CAMPUS)
    def hold_precommit():
        entered.set()
        if not release.wait(18):
            raise RuntimeError("D1_PHOTO_P1_REVERSE_HOLD_TIMEOUT")

    with ThreadPoolExecutor(max_workers=2) as pool:
        photo_future=pool.submit(photo.transition,token,action="FINALIZE_TRIAL",
                                 before_commit_test_hook=hold_precommit)
        end_future=None
        try:
            _check(entered.wait(12) and pid_ready.is_set(),
                   "PHOTO_TRANSACTION_NOT_HELD")
            def _end_worker():
                with closing(_public_actor(psycopg,END_WAIT)) as con:
                    with con:
                        with closing(con.cursor()) as cur:
                            cur.execute("SELECT pg_catalog.pg_backend_pid()")
                            pid=int(cur.fetchone()[0])
                            end_started_pid.append(pid)
                            cur.execute("""
                              SELECT * FROM app.d1_end_student_enrollment(
                                %s::uuid,1,%s::uuid,%s::uuid,%s::date,CURRENT_DATE,
                                'Photo-first protected END local race',%s)
                            """,(student,source_id,source_section,source_start,
                                 END_KEY))
                            _check(cur.fetchone() is not None,"REVERSE_END_RPC")
                return True
            end_started_pid=[]
            end_future=pool.submit(_end_worker)
            # Look up the *actual* backend PID by application_name when the
            # RPC blocks before the end_worker appends/returns from command.
            _observe_waiter(psycopg,END_WAIT,pid_holder[0])
        finally:
            release.set()
        _check(photo_future.result(timeout=20)=="FINALIZED_TRIAL",
               "PHOTO_FIRST_DID_NOT_COMMIT")
        _check(end_future is not None and end_future.result(timeout=20) is True,
               "END_AFTER_PHOTO_DID_NOT_COMMIT")
    _check(_row(psycopg,_digest(token))==
           ("FINALIZED_TRIAL",True,True,False),
           "REVERSE_FINALIZED_TRIAL_LOST")
    _no_current_source(psycopg,student,None)
    _denied(lambda:store.issue())
    _denied(lambda:store.transition(token,action="FINALIZE_TRIAL"))
    return True


def _transfer_first_stale_photo(psycopg):
    """Real P1 CAMPUS_TRANSFER commits first; stale two-stage photo denies."""
    student=MOVE_STUDENT
    source_id,source_start,source_section=_p0_new_student(
        psycopg,student,"photo-p1-move-p0")
    store=NativePostgresPhotoIntentTrial(
        db_connect=lambda:_actor_connection(psycopg),
        student_id=student,campus_id=CAMPUS)
    pending=store.issue()
    consumed=store.issue()
    _check(store.transition(consumed,action="CONSUME")=="CONSUMED",
           "PREPARE_TRANSFER_FINALIZE")
    # Hold the authenticated public P1 CAMPUS_TRANSFER transaction open.
    con=_public_actor(psycopg,MOVE_WAIT)
    try:
        with closing(con.cursor()) as cur:
            cur.execute("SELECT pg_catalog.pg_backend_pid()")
            holder_pid=int(cur.fetchone()[0])
            cur.execute("""
              SELECT * FROM app.d1_move_student_enrollment(
                %s::uuid,1,%s::uuid,%s::uuid,%s::date,
                %s::uuid,'CAMPUS_TRANSFER',CURRENT_DATE,
                'Campus A to B private photo race',NULL,%s)
            """,(student,source_id,source_section,source_start,DEST_SECTION,
                 MOVE_KEY))
            _check(cur.fetchone() is not None,"TRANSFER_RPC_FAILED")
        # Validate actual Student row lock by two separate photo workers
        # waiting on the move holder or through a queued soft blocker.
        tagged=NativePostgresPhotoIntentTrial(
            db_connect=lambda:_tagged_photo_actor(psycopg),
            student_id=student,campus_id=CAMPUS)
        with ThreadPoolExecutor(max_workers=2) as pool:
            a=pool.submit(tagged.transition,pending,action="CONSUME")
            b=pool.submit(tagged.transition,consumed,action="FINALIZE_TRIAL")
            try:
                _observe_end_blocked_consumers(psycopg,holder_pid)
            finally:
                con.commit()
            _denied(lambda:a.result(timeout=18))
            _denied(lambda:b.result(timeout=18))
    finally:
        con.rollback()
        con.close()
    _no_current_source(psycopg,student,CAMPUS_B)
    _check(_row(psycopg,_digest(pending))==
           ("ISSUED",False,False,False),"TRANSFER_STALE_CONSUME_MUTATION")
    _check(_row(psycopg,_digest(consumed))==
           ("CONSUMED",True,False,False),"TRANSFER_STALE_FINALIZE_MUTATION")
    _denied(lambda:store.transition(pending,action="CONSUME"))
    _denied(lambda:store.transition(consumed,action="FINALIZE_TRIAL"))
    _denied(lambda:store.issue())
    return True


def _tagged_photo_actor(psycopg):
    con=_actor_connection(psycopg)
    try:
        with closing(con.cursor()) as cur:
            cur.execute("SELECT pg_catalog.set_config('application_name',%s,true)",
                        ("photo-protected-end-intent-waiter",))
        return con
    except Exception:
        con.close()
        raise


def run_photo_reverse_end_campus_transfer_races(
    psycopg, *, container: str, run_psql
):
    if container!=CONTAINER:
        raise RuntimeError("D1_PHOTO_P1_REVERSE_TRANSFER_DISPOSABLE_ONLY")
    run_psql(container,SETUP_SQL,
            "D1_PHOTO_P1_REVERSE_TRANSFER_SETUP",timeout=90)
    _check(_reverse_photo_first_end(psycopg),"REVERSE_PHOTO_FIRST_END")
    _check(_transfer_first_stale_photo(psycopg),"TRANSFER_FIRST")
    print("D1_STUDENT_PHOTO_REVERSE_END_CAMPUS_TRANSFER_RACES_PASS "
          "photo-first protected END and transfer-first genuine authenticated "
          "CAMPUS_TRANSFER, observed real PostgreSQL lock waits; "
          "post-transfer Campus A intents rejected, no file and no photo SET; "
          "DISPOSABLE ONLY")
