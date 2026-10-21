"""DB-01 protected DIRECT CORRECT vs genuine protected Enrollment MOVE/END races.

Four independent Students, all four winner orders. Disposable D1 PostgreSQL
only; reuses the accepted test-only P1/direct School ancestry and permission
fixtures from historical replay. No production SQL, mock Roll rows or clock
overrides. Every contested call invokes the actual authenticated app RPC.
"""
from concurrent.futures import ThreadPoolExecutor
from contextlib import closing
from datetime import timedelta
import time

from domain_db01_replay_after_move_end_ci import SCHOOL, SOURCE, DEST, CLASS
from domain_student_photo_real_pg_handoff_ci import _actor_connection, _local_connect
from domain_concurrency_ci import settings_sql
from domain_enrollment_end_lock_prefix_ci import CONTAINER

PREFIX="db1c0000-0000-4000-8000-"
STUDENTS={
 "CORRECT_OVER_MOVE": PREFIX+"000000000001",
 "MOVE_OVER_CORRECT": PREFIX+"000000000101",
 "CORRECT_OVER_END": PREFIX+"000000000201",
 "END_OVER_CORRECT": PREFIX+"000000000301",
}
CASE_IDS={"CORRECT_OVER_MOVE":1, "MOVE_OVER_CORRECT":2,
          "CORRECT_OVER_END":3, "END_OVER_CORRECT":4}
CORRECTION_REASON="DB-01 protected cross-operation contested correction"
MOVE_REASON="DB-01 genuine protected move cross-operation race"
END_REASON="DB-01 genuine protected end cross-operation race"


def _check(ok, code):
    if not ok:
        raise RuntimeError("D1_DB01_CORRECT_CROSS_OPERATION_"+code)


def _seed(container, run_psql, business_date):
    # No source Enrollment or Roll is fabricated. P0 creates those through the
    # reviewed public authenticated command after this bare Student fixture.
    tuples=[]
    transitions=[]
    for name, student in STUDENTS.items():
        index=CASE_IDS[name]
        person=PREFIX+f"{index:012d}"[:-2]+"90"
        status=PREFIX+f"{index:012d}"[:-2]+"02"
        tuples.append(f"""('{student}'::uuid,'{person}'::uuid,
          'DB01-CROSS-STUDENT-{index}','DB01-CROSS-ADM-{index}',
          {19900+index},%s::date-21,'ACTIVE',
          '11111111-1111-4111-8111-111111111111')""")
        transitions.append(f"""('{status}'::uuid,'{student}'::uuid,NULL,'ACTIVE',
          %s::date-21,1,'Synthetic DB-01 cross-race P0 prerequisite',
          '11111111-1111-4111-8111-111111111111')""")
    # Deterministic UUIDs and identifiers; dates are quoted below from an
    # already-resolved School-local date, not imported user input.
    day=business_date.isoformat()
    people=[]
    for index in range(1,5):
        person=PREFIX+f"{index:012d}"[:-2]+"90"
        people.append(f"('{person}'::uuid,'DB-01 contested Student Person {index}',"+
                      "'11111111-1111-4111-8111-111111111111')")
    # Construct one transaction with schema-owner fixture writes only.
    student_rows=",\n".join(t.replace("%s::date",f"'{day}'::date") for t in tuples)
    transition_rows=",\n".join(t.replace("%s::date",f"'{day}'::date") for t in transitions)
    script=(
        "BEGIN;\n" + settings_sql() +
        "SET ROLE schoolos_schema_owner;\n" +
        "INSERT INTO app_private.people(id,display_name,created_by) VALUES\n" +
        ",\n".join(people) + ";\n" +
        "INSERT INTO app_private.students(id,person_id,school_student_id,admission_number,\n"
        " admission_serial,admitted_on,current_status,created_by) VALUES\n" +
        student_rows + ";\n" +
        "INSERT INTO app_private.student_status_transitions(\n"
        " id,student_id,previous_status,new_status,effective_on,\n"
        " sequence_number,reason,created_by) VALUES\n" +
        transition_rows + ";\nRESET ROLE;\nCOMMIT;"
    )
    run_psql(container,script,"D1_DB01_CORRECT_CROSS_OPERATION_SEED",timeout=60)


def _source(conn, student, p0_date, key):
    with conn.cursor() as cur:
        cur.execute("SET ROLE authenticated")
        cur.execute("SET LOCAL statement_timeout='18s'")
        cur.execute("""SELECT enrollment_id,roll_allocation_id,numeric_value,
                 student_version FROM app.d1_place_student_enrollment(
                 %s::uuid,1,%s::uuid,'INITIAL',%s::date,NULL,
                 'DB-01 cross-operation real P0',NULL,%s)""",
                 (student,SOURCE,p0_date,key))
        r=cur.fetchone()
        _check(r is not None and r[3]==1,"P0_PROTECTED_SOURCE")
        return str(r[0]),str(r[1]),int(r[2])


def _correct(conn, student, enrollment, roll, policy, old, p0_date, proposed, key):
    with conn.cursor() as cur:
        cur.execute("SET ROLE authenticated")
        cur.execute("SET LOCAL statement_timeout='18s'")
        cur.execute("""SELECT corrected_roll_allocation_id,
                  corrected_numeric_value,correction_effective_from,
                  student_version FROM app.d1_correct_student_roll(
                  %s::uuid,1,%s::uuid,%s::uuid,%s::date,%s::uuid,%s::date,
                  %s::uuid,%s,%s,%s,%s)""",
                  (student,enrollment,SOURCE,p0_date,roll,p0_date,policy,old,
                   proposed,CORRECTION_REASON,key))
        result=cur.fetchone()
        _check(result is not None and int(result[1])==proposed
               and int(result[3])==2,"CORRECT_PROTECTED_RESULT")
        return str(result[0]),result[2]


def _move(conn, student, enrollment, p0_date, business_date, key):
    with conn.cursor() as cur:
        cur.execute("SET ROLE authenticated")
        cur.execute("SET LOCAL statement_timeout='18s'")
        cur.execute("""SELECT enrollment_id,roll_allocation_id,numeric_value,
                  roll_mode,student_version
               FROM app.d1_move_student_enrollment(
                  %s::uuid,1,%s::uuid,%s::uuid,%s::date,
                  %s::uuid,'SECTION_CHANGE',%s::date,%s,NULL,%s)""",
                  (student,enrollment,SOURCE,p0_date,DEST,business_date,
                   MOVE_REASON,key))
        r=cur.fetchone()
        _check(r is not None and str(r[0])!=enrollment and r[4]==1,
               "MOVE_PROTECTED_RESULT")
        return str(r[0]),str(r[1])


def _end(conn, student, enrollment, p0_date, business_date, key):
    with conn.cursor() as cur:
        cur.execute("SET ROLE authenticated")
        cur.execute("SET LOCAL statement_timeout='18s'")
        cur.execute("""SELECT enrollment_id,roll_allocation_id,
                    student_version,effective_until
                 FROM app.d1_end_student_enrollment(
                    %s::uuid,1,%s::uuid,%s::uuid,%s::date,%s::date,%s,%s)""",
                   (student,enrollment,SOURCE,p0_date,business_date,
                    END_REASON,key))
        r=cur.fetchone()
        _check(r is not None and str(r[0])==enrollment
               and int(r[2])==1 and r[3]==business_date,
               "END_PROTECTED_RESULT")
        return str(r[1]),r[3]


def _blocking(cur, waiter, holder, future):
    _check(holder!=waiter,"SAME_BACKEND")
    deadline=time.monotonic()+12
    while time.monotonic()<deadline:
        if future.done():
            future.result()  # Surface a real SQL failure.
            raise RuntimeError("D1_DB01_CORRECT_CROSS_OPERATION_UNEXPECTED_NO_WAIT")
        cur.execute("SELECT pg_catalog.pg_stat_clear_snapshot()")
        cur.execute("""SELECT EXISTS(
           SELECT 1 FROM pg_catalog.pg_stat_activity a
           WHERE a.pid=%s AND a.wait_event_type='Lock'
             AND %s=ANY(pg_catalog.pg_blocking_pids(a.pid))
             AND EXISTS (SELECT 1 FROM pg_catalog.pg_locks l
                  WHERE l.pid=a.pid AND NOT l.granted
                    AND l.locktype IN ('tuple','transactionid','advisory')))""",
                    (waiter,holder))
        if cur.fetchone()==(True,):
            return
        time.sleep(0.025)
    raise RuntimeError("D1_DB01_CORRECT_CROSS_OPERATION_WAIT_NOT_OBSERVED")


def _evidence(cur, student, correction_key, other_key):
    cur.execute("""SELECT
       (SELECT row_version FROM app_private.students WHERE id=%s::uuid),
       (SELECT count(*) FROM app_private.enrollments WHERE student_id=%s::uuid),
       (SELECT count(*) FROM app_private.roll_allocations WHERE student_id=%s::uuid),
       (SELECT count(*) FROM app_private.roll_allocations
          WHERE student_id=%s::uuid AND effective_until IS NULL),
       (SELECT count(*) FROM app_private.command_receipts
          WHERE idempotency_key=%s AND command_kind='student.roll.correct'
            AND state='SUCCEEDED'),
       (SELECT count(*) FROM app_private.command_receipts
          WHERE idempotency_key=%s AND state='SUCCEEDED'),
       (SELECT count(*) FROM app_private.audit_events a
          JOIN app_private.command_receipts r ON r.id=a.command_receipt_id
          WHERE r.idempotency_key IN (%s,%s)),
       (SELECT count(*) FROM app_private.outbox_events ev
          JOIN app_private.command_receipts r ON r.id=ev.command_receipt_id
          WHERE r.idempotency_key IN (%s,%s))""",
       (student,student,student,student,correction_key,other_key,
        correction_key,other_key,correction_key,other_key))
    return tuple(cur.fetchone())


def run_db01_correct_vs_move_end_races(container, run_psql):
    _check(container==CONTAINER,"DISPOSABLE_ONLY")
    import psycopg
    with closing(_local_connect(psycopg)) as observer:
        with observer.cursor() as cur:
            cur.execute("SELECT app_private.d1_roll_business_date(%s::uuid)",(SCHOOL,))
            today=cur.fetchone()[0]
            p0_date=today-timedelta(days=20)
            cur.execute("""SELECT app_private.d1_enrollment_move_policy(
                    %s::uuid,%s::uuid)""",(SOURCE,DEST))
            route=cur.fetchone()
            _check(route is not None and "DIRECT" in str(route[0]),"MOVE_P1_NOT_DIRECT")
            cur.execute("SELECT app_private.d1_enrollment_end_policy(%s::uuid)",(SOURCE,))
            route=cur.fetchone()
            _check(route is not None and "DIRECT" in str(route[0]),"END_P1_NOT_DIRECT")
            cur.execute("""SELECT count(*) FROM app_private.roll_policy_revisions rp
                 WHERE rp.school_id=%s::uuid AND rp.effective_from<=%s::date
                   AND (rp.effective_until IS NULL OR %s::date<rp.effective_until)""",
                        (SCHOOL,today,today))
            _check(cur.fetchone()==(1,),"CURRENT_POLICY_AMBIGUOUS")
            cur.execute("""SELECT enabled FROM app_private.operation_contracts
                  WHERE code='student.roll.correct'""")
            _check(cur.fetchone()==(True,),"PROTECTED_CORRECT_DISABLED_IN_TEST")
        observer.rollback()
    _seed(container,run_psql,today)
    for name in ("CORRECT_OVER_MOVE","MOVE_OVER_CORRECT",
                 "CORRECT_OVER_END","END_OVER_CORRECT"):
        student=STUDENTS[name]
        with closing(_actor_connection(psycopg)) as conn:
            enrollment,roll,old=_source(conn,student,p0_date,
                                          "db01-cross-p0-"+name.lower().replace("_","-"))
            conn.commit()
        with closing(_local_connect(psycopg)) as check:
            with check.cursor() as cur:
                cur.execute("""SELECT policy_revision_id FROM app_private.roll_allocations
                     WHERE id=%s::uuid""",(roll,))
                row=cur.fetchone()
                _check(row is not None,"STORED_ROLL_POLICY_MISSING")
                policy=str(row[0])
                cur.execute("""SELECT a.next_value FROM app_private.roll_allocator_states a
                       JOIN app_private.roll_policy_revisions rp ON rp.id=a.policy_revision_id
                       WHERE a.policy_revision_id=%s::uuid
                         AND a.class_offering_id IS NOT DISTINCT FROM
                           (CASE WHEN rp.mode='ACADEMIC_CONTEXT'
                                 THEN %s::uuid ELSE NULL::uuid END)""",
                            (policy,CLASS))
                next_row=cur.fetchone()
                _check(next_row is not None,"CORRECTION_ALLOCATOR_MISSING")
                proposal=int(next_row[0])+19
            check.rollback()
        correction_key="db01-cross-correction-"+name.lower().replace("_","-")
        other_is_move=name.endswith("MOVE") or name.startswith("MOVE")
        other_key="db01-cross-"+("move-" if other_is_move else "end-")+name.lower().replace("_","-")
        correct_first=name.startswith("CORRECT")
        def command(conn,which):
            if which=="CORRECT":
                return _correct(conn,student,enrollment,roll,policy,old,
                                p0_date,proposal,correction_key)
            if other_is_move:
                return _move(conn,student,enrollment,p0_date,today,other_key)
            return _end(conn,student,enrollment,p0_date,today,other_key)

        winner_kind="CORRECT" if correct_first else ("MOVE" if other_is_move else "END")
        loser_kind=("MOVE" if other_is_move else "END") if correct_first else "CORRECT"
        with closing(_actor_connection(psycopg)) as winner, \
             closing(_actor_connection(psycopg)) as loser, \
             closing(_local_connect(psycopg)) as observer:
            winner_result=command(winner,winner_kind)
            with ThreadPoolExecutor(max_workers=1) as pool:
                def contested():
                    try:
                        command(loser,loser_kind)
                    except psycopg.errors.RaiseException:
                        loser.rollback()
                        return "STALE_DENIED"
                    loser.rollback()
                    return "SECOND_SUCCESS"
                future=pool.submit(contested)
                try:
                    with observer.cursor() as cur:
                        _blocking(cur,loser.info.backend_pid,
                                  winner.info.backend_pid,future)
                finally:
                    winner.commit()
                _check(future.result(timeout=21)=="STALE_DENIED",
                       "LOSER_ACCEPTED_"+name)
            with observer.cursor() as cur:
                actual=_evidence(cur,student,correction_key,other_key)
                expected=(2,1,2,1,1,0,1,1) if correct_first else (
                         (1,2,2,1,0,1,1,1) if other_is_move
                         else (1,1,1,0,0,1,1,1))
                _check(actual==expected,
                       "LEDGER_OR_EVIDENCE_"+name+"_"+str(actual))
                cur.execute("""SELECT effective_until FROM app_private.roll_allocations
                    WHERE id=%s::uuid""",(roll,))
                _check(cur.fetchone()==(today,),"R0_NOT_CLOSED_"+name)
                if correct_first:
                    cur.execute("""SELECT count(*) FROM app_private.roll_allocations r
                         WHERE r.student_id=%s::uuid
                           AND r.supersedes_id=%s::uuid
                           AND r.effective_from=%s::date
                           AND r.effective_until IS NULL""",
                           (student,roll,today))
                    _check(cur.fetchone()==(1,),"CORRECT_R1_LINEAGE_"+name)
                elif other_is_move:
                    cur.execute("""SELECT count(*) FROM app_private.enrollments
                         WHERE student_id=%s::uuid AND section_offering_id=%s::uuid
                           AND predecessor_id=%s::uuid
                           AND effective_from=%s::date""",
                            (student,DEST,enrollment,today))
                    _check(cur.fetchone()==(1,),"MOVE_DESTINATION_"+name)
                else:
                    cur.execute("""SELECT count(*) FROM app_private.enrollments
                         WHERE id=%s::uuid AND placement_state='ENDED'
                           AND effective_until=%s::date""",
                            (enrollment,today))
                    _check(cur.fetchone()==(1,),"END_RETAINED_"+name)
            observer.rollback()
        print("D1_DB01_"+name+"_REAL_PG_RACE_PASS "
              "two authenticated backends, observed blocking wait, winner="+
              winner_kind+", loser denied, one historical effect/receipt/audit/outbox; "
              "no duplicate Enrollment or Roll")
    print("D1_DB01_CORRECT_MOVE_END_FOUR_RACES_PASS "
          "genuine protected CORRECT vs MOVE/END; both winner orders; "
          "four observed contention waits and exactly one successful operation per Student")
