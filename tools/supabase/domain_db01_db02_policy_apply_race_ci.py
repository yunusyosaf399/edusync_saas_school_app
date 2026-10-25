"""DB01-10: authenticated policy REPLACE versus approved Roll correction APPLY.

Fresh disposable singleton-School databases for both winner orders. The
School row lock and pg_blocking_pids must be observed before either commit.
"""
from concurrent.futures import ThreadPoolExecutor
from contextlib import closing

from domain_concurrency_ci import settings_sql
from domain_db01_p1_apply_race_ci import CASES, _setup, _approve, _apply, _snapshot
from domain_db01_protected_direct_race_ci import _wait_for_block
from domain_student_photo_real_pg_handoff_ci import _actor_connection, _local_connect
from domain_enrollment_end_lock_prefix_ci import CONTAINER
from domain_db02_policy_race_ci import SCHOOL
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
POLICY = "b1000000-0000-4000-8000-000000000049"
CASES.update({"pc": ("d1150000", "d1a50000"),
              "cp": ("d1160000", "d1a60000")})


def _check(ok, label):
    if not ok:
        raise RuntimeError("D1_DB01_DB02_POLICY_APPLY_" + label)


def _seed(container, run_psql):
    fixture=(ROOT/"supabase/tests/domain/fixtures/command_actor.sql").read_text()
    policy=f"""
SET ROLE schoolos_schema_owner;
INSERT INTO app_private.roll_policy_revisions(
 id,school_id,revision,mode,start_value,effective_from,reason,created_by)
VALUES ('{POLICY}','{SCHOOL}',1,'PERSISTENT_STUDENT',12000,
 CURRENT_DATE-30,'DB01/DB02 race retained source',
 '11111111-1111-4111-8111-111111111111');
INSERT INTO app_private.roll_allocator_states(
 policy_revision_id,class_offering_id,next_value,created_by)
VALUES ('{POLICY}',NULL,12001,
 '11111111-1111-4111-8111-111111111111');
RESET ROLE;
"""
    run_psql(container,"BEGIN;\n"+fixture+policy+"COMMIT;\n",
             "D1_DB01_DB02_RACE_BASE",timeout=120)
    p1=(ROOT/"supabase/tests/domain/fixtures/"
        "db02_t04_two_backend_race_setup.sql").read_text()
    # INIT selects the fixture's authority route but does not insert its own
    # old source; the genuine DB01 P0 will use the seeded policy above.
    run_psql(container,"BEGIN;\n"+settings_sql()+"\nRESET ROLE;\n"+
             "SELECT set_config('schoolos_test.t04_action','INIT',true);\n"+
             p1+"\nCOMMIT;\n","D1_DB01_DB02_RACE_CHANGE_P1",timeout=120)


def _change(conn, today, key):
    with conn.cursor() as cur:
        cur.execute("SET ROLE authenticated")
        cur.execute("SET LOCAL statement_timeout='20s'")
        cur.execute("""SELECT app.d1_change_student_roll_policy(
          %s::uuid,'REPLACE',%s::uuid,1,'PERSISTENT_STUDENT',12000,
          %s::date-30,'ACADEMIC_CONTEXT',7000,
          'DB01/DB02 protected policy handoff',%s)""",
                    (SCHOOL,POLICY,today,key))
        row=cur.fetchone()
        _check(row is not None and row[0] is not None,"NO_CHANGE_RESULT")
        return str(row[0])


def _verify(cur,request,student,policy_id,change_first):
    cur.execute("""SELECT mode,effective_from FROM app_private.roll_policy_revisions
      WHERE id=%s::uuid AND revision=2""",(policy_id,))
    row=cur.fetchone()
    _check(row is not None and row[0]=="ACADEMIC_CONTEXT","NO_NEW_POLICY")
    cur.execute("SELECT effective_until FROM app_private.roll_policy_revisions WHERE id=%s::uuid",(POLICY,))
    _check(cur.fetchone()==(row[1],),"SOURCE_CUTOFF")
    cur.execute("""SELECT count(*) FROM app_private.roll_allocator_states
      WHERE policy_revision_id=%s::uuid AND class_offering_id IS NOT NULL""",(policy_id,))
    _check(cur.fetchone()==(1,),"OFFERING_POOL")
    got=_snapshot(cur,request,student)
    if change_first:
        _check(got[0]=="INVALIDATED" and got[2]==1 and got[3]==1
               and got[4]==0 and got[7]==0 and got[9]==0,
               "CHANGE_FIRST_LEDGER_"+str(got))
        cur.execute("""SELECT count(*) FROM app_private.command_receipts
          WHERE request_id=%s::uuid AND command_kind='request.apply'
            AND state='REJECTED'""",(request,))
        _check(cur.fetchone()==(1,),"REJECTED_APPLY_RECEIPT")
    else:
        _check(got[0]=="EXECUTED" and got[2]==2 and got[3]==2
               and got[4]==1 and got[7]==1 and got[9]==1,
               "APPLY_FIRST_LEDGER_"+str(got))
    cur.execute("""SELECT count(*) FROM app_private.command_receipts
      WHERE result_ref=%s::uuid AND command_kind='student.roll_policy.change'
        AND state='SUCCEEDED'""",(policy_id,))
    _check(cur.fetchone()==(1,),"ONE_POLICY_RECEIPT")


def run_db01_db02_policy_apply_races(container,run_psql,fresh_database):
    _check(container==CONTAINER,"DISPOSABLE_CONTAINER_ONLY")
    import psycopg
    for case in ("pc","cp"):
        fresh_database()
        _seed(container,run_psql)
        student,request,v=_setup(container,run_psql,ROOT,case)
        approved=_approve(psycopg,request,v,case)
        with closing(_local_connect(psycopg)) as observer:
            with observer.cursor() as c:
                c.execute("SELECT app_private.d1_roll_business_date(%s::uuid)",(SCHOOL,))
                today=c.fetchone()[0]
            observer.rollback()
        with closing(_actor_connection(psycopg)) as changer, \
             closing(_actor_connection(psycopg)) as applier, \
             closing(_local_connect(psycopg)) as observer:
            first,second=(changer,applier) if case=="pc" else (applier,changer)
            first_result=(_change(first,today,"db01-db02-"+case+"-change")
                          if case=="pc" else
                          _apply(first,request,approved,"db01-db02-cp-apply"))
            with ThreadPoolExecutor(max_workers=1) as pool:
                if case=="pc":
                    future=pool.submit(_apply,second,request,approved,
                                       "db01-db02-pc-apply")
                else:
                    future=pool.submit(_change,second,today,
                                       "db01-db02-cp-change")
                try:
                    with observer.cursor() as c:
                        _wait_for_block(c,second.info.backend_pid,
                                        first.info.backend_pid,future)
                        c.execute("""SELECT EXISTS (SELECT 1 FROM pg_catalog.pg_locks l
                          JOIN pg_catalog.pg_class r ON r.oid=l.relation
                          WHERE l.pid=%s AND l.granted
                            AND r.relname='school_profiles')""",
                                  (first.info.backend_pid,))
                        _check(c.fetchone()==(True,),"SCHOOL_LOCK_NOT_HELD")
                    observer.rollback()
                finally:
                    first.commit()
                second_result=future.result(timeout=25)
                second.commit()
            policy_id=first_result if case=="pc" else second_result
            result=second_result if case=="pc" else first_result
            _check(result[0]==request and
                   result[2]==("INVALIDATED" if case=="pc" else "EXECUTED"),
                   "APPLY_RESULT_"+case+"_"+str(result))
            with observer.cursor() as c:
                _verify(c,request,student,policy_id,case=="pc")
            observer.rollback()
        print("D1_DB01_DB02_POLICY_APPLY_RACE_PASS "+case+
              " exact_school_wait=true retained_roll_and_evidence=true")
    print("D1_DB01_DB02_POLICY_APPLY_PASS 2 protected winner orders")
