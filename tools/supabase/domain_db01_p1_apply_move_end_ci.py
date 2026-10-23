"""DB01-07: two real PostgreSQL backends race approved P1 APPLY vs MOVE/END.

For each operation test both winner orders. Require observed pg_blocking_pids
before releasing the winner and verify request, receipt, audit, Roll and outbox.
Disposable local Supabase only; not a production migration.
"""
from concurrent.futures import ThreadPoolExecutor
from contextlib import closing

from domain_concurrency_ci import settings_sql
from domain_db01_p1_apply_race_ci import (
    ROOT, CASES, _setup, _approve, _apply, _snapshot, _assert_executed, _check
)
from domain_db01_protected_direct_race_ci import _wait_for_block
from domain_student_photo_real_pg_handoff_ci import _actor_connection, _local_connect
from domain_enrollment_end_lock_prefix_ci import CONTAINER

SCHOOL = "22222222-2222-4222-8222-222222222222"


def _destination(container, run_psql, case):
    prefix = CASES[case][0]
    section = prefix + "-0000-4000-8000-000000000055"
    script = ("BEGIN;\n" + settings_sql() + "\nSET ROLE schoolos_schema_owner;\n" +
        """INSERT INTO app_private.section_offerings(
 id,class_offering_id,campus_id,code,label,display_order,capacity,state,created_by)
VALUES ('""" + section + """','""" + prefix + """-0000-4000-8000-000000000044',
 '""" + prefix + """-0000-4000-8000-000000000041','B',
 'DB01-07 protected move destination',2,30,'OPEN',
 '11111111-1111-4111-8111-111111111111');
INSERT INTO app_private.capacity_revisions(
 id,class_offering_id,section_offering_id,old_capacity,new_capacity,
 effective_on,reason,created_by)
VALUES('""" + prefix + """-0000-4000-8000-000000000056',
 NULL,'""" + section + """',NULL,30,CURRENT_DATE-1,
 'DB01-07 alternate Section initial capacity',
 '11111111-1111-4111-8111-111111111111');
RESET ROLE;
COMMIT;
""")
    run_psql(container, script, "D1_DB01_P1_APPLY_" + case.upper() + "_DEST",
             timeout=100)
    return section


def _preflight(cur, student, case, destination):
    prefix = CASES[case][0]
    source = prefix + "-0000-4000-8000-000000000045"
    cur.execute("""SELECT e.id,e.effective_from,r.id,r.policy_revision_id,r.numeric_value
      FROM app_private.enrollments e JOIN app_private.roll_allocations r
        ON r.enrollment_id=e.id
      WHERE e.student_id=%s::uuid AND e.section_offering_id=%s::uuid
        AND e.effective_until IS NULL AND r.effective_until IS NULL""",
                (student,source))
    rows = cur.fetchall()
    _check(len(rows)==1, "P0_SOURCE_" + case)
    cur.execute("SELECT app_private.d1_roll_business_date(%s::uuid)",(SCHOOL,))
    today = cur.fetchone()[0]
    cur.execute("SELECT app_private.d1_enrollment_move_policy(%s::uuid,%s::uuid)",
                (source,destination))
    move = cur.fetchone()
    cur.execute("SELECT app_private.d1_enrollment_end_policy(%s::uuid)",(source,))
    end = cur.fetchone()
    _check(move is not None and "DIRECT" in str(move[0]),
           "MOVE_ROUTE_NOT_DIRECT_" + case)
    _check(end is not None and "DIRECT" in str(end[0]),
           "END_ROUTE_NOT_DIRECT_" + case)
    return source,(str(rows[0][0]),rows[0][1],str(rows[0][2]),
                   str(rows[0][3]),int(rows[0][4])),today


def _other(conn, case, student, source, destination, original, today, key):
    enrollment, from_day, _, _, _ = original
    with conn.cursor() as cur:
        cur.execute("SET ROLE authenticated")
        cur.execute("SET LOCAL statement_timeout='18s'")
        if case in ("am","ma"):
            cur.execute("""SELECT enrollment_id,roll_allocation_id,student_version
              FROM app.d1_move_student_enrollment(
                %s::uuid,1,%s::uuid,%s::uuid,%s::date,%s::uuid,
                'SECTION_CHANGE',%s::date,%s,NULL,%s)""",
                (student,enrollment,source,from_day,destination,today,
                 "DB01-07 authentic protected MOVE",key))
            value=cur.fetchone()
            _check(value is not None and str(value[0])!=enrollment and
                   int(value[2])==1,"MOVE_RESULT_"+case)
        else:
            cur.execute("""SELECT enrollment_id,roll_allocation_id,student_version
              FROM app.d1_end_student_enrollment(
                %s::uuid,1,%s::uuid,%s::uuid,%s::date,%s::date,%s,%s)""",
                (student,enrollment,source,from_day,today,
                 "DB01-07 authentic protected END",key))
            value=cur.fetchone()
            _check(value is not None and str(value[0])==enrollment and
                   int(value[2])==1,"END_RESULT_"+case)
        return str(value[0])


def _other_denied(conn, psycopg, case, student, source, destination,
                  original, today, key):
    try:
        _other(conn,case,student,source,destination,original,today,key)
    except psycopg.errors.RaiseException as exc:
        conn.rollback()
        _check(exc.sqlstate=="P0001","STALE_OTHER_SQLSTATE_"+case)
        return "DENIED"
    conn.rollback()
    return "UNEXPECTED_SUCCESS"


def _verify_invalidated(cur,request,student,version,case):
    expected=("INVALIDATED",version+3,1,
              2 if case=="ma" else 1,0,2,2,0,1,0)
    row=_snapshot(cur,request,student)
    _check(row==expected,"INVALIDATION_LEDGER_"+case+"_"+str(row))
    cur.execute("""SELECT count(*) FROM app_private.command_receipts
      WHERE request_id=%s::uuid AND command_kind='request.apply'
        AND state='REJECTED'""",(request,))
    _check(cur.fetchone()==(1,),"ONE_REJECTED_RECEIPT_"+case)
    cur.execute("""SELECT count(*) FROM app_private.approval_applications
      WHERE request_id=%s::uuid""",(request,))
    _check(cur.fetchone()==(0,),"NO_INVALIDATED_APPLICATION_"+case)


def run_db01_p1_apply_vs_move_end_races(container,run_psql,root=ROOT):
    _check(container==CONTAINER,"DISPOSABLE_CONTAINER_ONLY")
    import psycopg
    for case in ("am","ma","ae","ea"):
        student,request,version=_setup(container,run_psql,root,case)
        destination=_destination(container,run_psql,case)
        approved=_approve(psycopg,request,version,case)
        with closing(_local_connect(psycopg)) as check:
            with check.cursor() as cur:
                source,original,today=_preflight(cur,student,case,destination)
                _check(_snapshot(cur,request,student)==
                       ("APPROVED",approved,1,1,0,2,2,0,0,0),
                       "APPROVED_BASELINE_"+case)
            check.rollback()
        other_first=case[0] in ("m","e")
        apply_key="db01-p1-apply-"+case+"-correct"
        other_key="db01-p1-apply-"+case+"-other"
        with closing(_actor_connection(psycopg)) as first, \
             closing(_actor_connection(psycopg)) as second, \
             closing(_local_connect(psycopg)) as observer:
            if other_first:
                _other(first,case,student,source,destination,original,
                       today,other_key)
                contender=lambda: _apply(second,request,approved,apply_key)
            else:
                value=_apply(first,request,approved,apply_key)
                _check(value[:3]==(request,approved+1,"EXECUTED"),
                       "APPLY_FIRST_RESULT_"+case)
                contender=lambda: _other_denied(
                    second,psycopg,case,student,source,destination,original,
                    today,other_key)
            with ThreadPoolExecutor(max_workers=1) as pool:
                future=pool.submit(contender)
                try:
                    with observer.cursor() as cur:
                        _wait_for_block(cur,second.info.backend_pid,
                                        first.info.backend_pid,future)
                        _check(_snapshot(cur,request,student)==
                               ("APPROVED",approved,1,1,0,2,2,0,0,0),
                               "UNCOMMITTED_VISIBILITY_"+case)
                    observer.rollback()
                finally:
                    first.commit()
                result=future.result(timeout=23)
                if other_first:
                    _check(result[:3]==(request,approved+1,"INVALIDATED"),
                           "STALE_APPLY_NOT_INVALIDATED_"+case)
                    second.commit()
                else:
                    _check(result=="DENIED","DUPLICATE_OTHER_SUCCESS_"+case)
            with observer.cursor() as cur:
                if other_first:
                    _verify_invalidated(cur,request,student,version,case)
                else:
                    _assert_executed(cur,request,student,version)
                cur.execute("""SELECT count(*) FROM app_private.command_receipts
                  WHERE idempotency_key=%s""",(apply_key if other_first else other_key,))
                _check(cur.fetchone()==((1 if other_first else 0),),
                       "LOSER_RECEIPT_"+case)
            observer.rollback()
        print("D1_DB01_P1_APPLY_"+case.upper()+"_REAL_PG_RACE_PASS "
              "two authenticated backends; observed School/Student lock; "
              "one winner and no duplicate correction evidence")
