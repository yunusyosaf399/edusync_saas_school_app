"""DB01-07: observed independent two-backend authenticated REVIEW/APPLY and APPLY/APPLY.

Only disposable local D1. Real pg_blocking_pids/pg_locks wait evidence; no
mock RPCs, sleeps-as-proof, DB02-DB04 edits or production activation.
"""
from concurrent.futures import ThreadPoolExecutor
from contextlib import closing
from pathlib import Path

from domain_concurrency_ci import settings_sql
from domain_db01_p1_review_race_ci import _review
from domain_db01_protected_direct_race_ci import _wait_for_block
from domain_student_photo_real_pg_handoff_ci import _actor_connection, _local_connect
from domain_enrollment_end_lock_prefix_ci import CONTAINER

ROOT = Path(__file__).resolve().parents[2]
FIXTURE = ROOT / "supabase/tests/domain/fixtures/db01_p1_review_two_backend_setup.sql"
CASES = {"ra":("d1070000","d1970000"),
         "ar":("d1080000","d1980000"),
         "aa":("d1090000","d1990000"),
         "am":("d10a0000","d19a0000"),
         "ma":("d10b0000","d19b0000"),
         "ae":("d10c0000","d19c0000"),
         "ea":("d10d0000","d19d0000")}


def _check(valid, label):
    if not valid:
        raise RuntimeError("D1_DB01_P1_APPLY_RACE_" + label)


def _setup(container, run_psql, root, case):
    sp, rp = CASES[case]
    fixture=(Path(root)/FIXTURE.relative_to(ROOT)).read_text(encoding="utf-8")
    for anchor in ("d1020000", "d1920000", "db01-p1-review-race-submit",
                   "db01-p1-live-race-p0", r"\gset submitted_"):
        _check(anchor in fixture, "FIXTURE_DRIFT")
    fixture=(fixture.replace("d1020000",sp).replace("d1920000",rp)
             .replace("db01-p1-review","db01-p1-apply-"+case)
             .replace("db01-p1-live-race-p0","db01-p1-apply-"+case+"-p0")
             .replace("DB01-P1-RACE","DB01-P1-APPLY-"+case.upper()))
    run_psql(container,"BEGIN;\n"+settings_sql()+"\nRESET ROLE;\n"+
             fixture+"\nCOMMIT;\n",
             "D1_DB01_P1_APPLY_SETUP_"+case.upper(),timeout=140)
    student=sp+"-0000-4000-8000-000000000001"
    key="db01-p1-apply-"+case+"-race-submit"
    with closing(_local_connect(__import__("psycopg"))) as conn:
        with conn.cursor() as c:
            c.execute("""SELECT q.id,q.row_version FROM app_private.approval_requests q
              JOIN app_private.command_receipts r ON r.request_id=q.id
              WHERE q.target_ref=%s::uuid AND r.command_kind='request.submit'
                AND r.idempotency_key=%s AND r.state='SUCCEEDED'""",(student,key))
            rows=c.fetchall()
            _check(len(rows)==1,"REQUEST_NOT_UNIQUE_"+case)
            request, version=str(rows[0][0]),int(rows[0][1])
        conn.rollback()
    return student,request,version


def _snapshot(cur, request, student):
    cur.execute("""SELECT
       q.state,q.row_version,st.row_version,
       (SELECT count(*) FROM app_private.roll_allocations r WHERE r.student_id=st.id),
       (SELECT count(*) FROM app_private.approval_applications a WHERE a.request_id=q.id),
       (SELECT count(*) FROM app_private.approval_reviews v
           JOIN app_private.approval_request_steps s ON s.id=v.step_id
           WHERE s.request_id=q.id),
       (SELECT count(*) FROM app_private.command_receipts r WHERE
           r.request_id=q.id AND r.command_kind='request.review' AND r.state='SUCCEEDED'),
       (SELECT count(*) FROM app_private.command_receipts r WHERE
           r.request_id=q.id AND r.command_kind='request.apply' AND r.state='SUCCEEDED'),
       (SELECT count(*) FROM app_private.audit_events a WHERE
           a.approval_request_id=q.id AND a.authority_evidence->>'phase'='APPLY'),
       (SELECT count(*) FROM app_private.outbox_events ev JOIN
           app_private.command_receipts r ON r.id=ev.command_receipt_id
           WHERE r.request_id=q.id AND ev.event_type='enrollment.roll_corrected')
      FROM app_private.approval_requests q JOIN app_private.students st
        ON st.id=q.target_ref WHERE q.id=%s::uuid AND st.id=%s::uuid""",
                (request,student))
    rows=cur.fetchall()
    _check(len(rows)==1,"SNAPSHOT_MISSING")
    return tuple(rows[0])


def _apply(conn,request,version,key):
    with conn.cursor() as cur:
        cur.execute("SET ROLE authenticated")
        cur.execute("SET LOCAL statement_timeout='18s'")
        cur.execute("""SELECT request_id,request_version,request_state,
            corrected_roll_allocation_id,student_version,correction_effective_from
          FROM app.d1_apply_student_roll_correction(%s::uuid,%s::bigint,%s)""",
                    (request,version,key))
        row=cur.fetchone()
        _check(row is not None,"NO_APPLY_RESULT")
        return (str(row[0]),int(row[1]),row[2],
                str(row[3]) if row[3] else None,
                int(row[4]) if row[4] is not None else None,row[5])


def _approve(psycopg,request,version,case):
    # _reviewer_identity sets the restricted authenticated SQL role for the
    # whole connection, so each verified P1 step needs a fresh postgres
    # connection to resolve the Auth fixture before SET ROLE authenticated.
    for step,state in ((1,"PENDING"),(2,"APPROVED")):
        with closing(_local_connect(psycopg)) as reviewer:
            result=_review(reviewer,request,version+step-1,
                           "db01-p1-apply-"+case+"-review-"+str(step),
                           "Genuine independent configured P1 reviewer")
            _check(result==(request,version+step,state),
                   "REVIEW_STAGE_"+case+str(step))
            reviewer.commit()
    return version+2


def _assert_executed(cur,request,student,start_version):
    got=_snapshot(cur,request,student)
    target=("EXECUTED",start_version+3,2,2,1,2,2,1,1,1)
    _check(got==target,"EXECUTED_EVIDENCE_"+str(got))
    cur.execute("""SELECT count(*) FROM app_private.roll_allocations
      WHERE student_id=%s::uuid AND supersedes_id IS NOT NULL
        AND effective_until IS NULL""",(student,))
    _check(cur.fetchone()==(1,),"SINGLE_CORRECTED_ROLL")
    cur.execute("""SELECT count(*) FROM app_private.outbox_events o JOIN
       app_private.command_receipts rc ON rc.id=o.command_receipt_id
       WHERE rc.request_id=%s::uuid AND o.event_type='enrollment.roll_corrected'
         AND NOT(o.payload ? 'new_numeric_value')
         AND NOT(o.payload ? 'correction_reason')""",(request,))
    _check(cur.fetchone()==(1,),"OUTBOX_PRIVACY")


def _denied_review(conn,psycopg,request,version,key):
    try:
        _review(conn,request,version,key,"Stale reviewer must be denied after APPLY")
    except psycopg.errors.RaiseException as exc:
        conn.rollback()
        _check(exc.sqlstate=="P0001","REVIEW_DENIAL_CODE")
        return "DENIED"
    conn.rollback()
    return "WRONG_SUCCESS"


def run_db01_p1_apply_live_races(container,run_psql,root=ROOT):
    _check(container==CONTAINER,"DISPOSABLE_CONTAINER_ONLY")
    import psycopg

    # REVIEW stage 2 owns request row lock while the requester begins APPLY.
    student,request,v=_setup(container,run_psql,root,"ra")
    with closing(_local_connect(psycopg)) as reviewer:
        r=_review(reviewer,request,v,"db01-p1-apply-ra-review-1",
                  "Genuine independent first P1 step")
        _check(r==(request,v+1,"PENDING"),"RA_STAGE_ONE")
        reviewer.commit()
    with closing(_local_connect(psycopg)) as reviewer, \
         closing(_actor_connection(psycopg)) as applier, \
         closing(_local_connect(psycopg)) as observer:
        r=_review(reviewer,request,v+1,"db01-p1-apply-ra-review-2",
                  "Genuine independent second P1 step")
        _check(r==(request,v+2,"APPROVED"),"RA_STAGE_TWO")
        with ThreadPoolExecutor(max_workers=1) as pool:
            future=pool.submit(_apply,applier,request,v+2,
                               "db01-p1-apply-ra-one-success")
            try:
                with observer.cursor() as cur:
                    _wait_for_block(cur,applier.info.backend_pid,
                                    reviewer.info.backend_pid,future)
                    _check(_snapshot(cur,request,student)==
                           ("PENDING",v+1,1,1,0,1,1,0,0,0),
                           "RA_UNCOMMITTED_EVIDENCE")
                observer.rollback()
            finally:
                reviewer.commit()
            result=future.result(timeout=23)
            _check(result[:3]==(request,v+3,"EXECUTED") and
                   result[3] is not None and result[4]==2,"RA_APPLY_RESULT")
            applier.commit()
        with observer.cursor() as cur:
            _assert_executed(cur,request,student,v)
        observer.rollback()
    print("D1_DB01_P1_REVIEW_APPLY_REAL_PG_RACE_PASS "
          "observed lock, two configured P1 reviews and one corrected Roll")

    # APPLY holds the request lock; stale competing REVIEW waits, then denies.
    student,request,v=_setup(container,run_psql,root,"ar")
    approved=_approve(psycopg,request,v,"ar")
    with closing(_actor_connection(psycopg)) as applier, \
         closing(_local_connect(psycopg)) as reviewer, \
         closing(_local_connect(psycopg)) as observer:
        value=_apply(applier,request,approved,"db01-p1-apply-ar-winner")
        _check(value[:3]==(request,approved+1,"EXECUTED"),"AR_WINNER")
        with ThreadPoolExecutor(max_workers=1) as pool:
            future=pool.submit(_denied_review,reviewer,psycopg,request,
                               approved,"db01-p1-apply-ar-stale-review")
            try:
                with observer.cursor() as cur:
                    _wait_for_block(cur,reviewer.info.backend_pid,
                                    applier.info.backend_pid,future)
                    _check(_snapshot(cur,request,student)==
                           ("APPROVED",approved,1,1,0,2,2,0,0,0),
                           "AR_UNCOMMITTED_EVIDENCE")
                observer.rollback()
            finally:
                applier.commit()
            _check(future.result(timeout=23)=="DENIED","AR_STALE_REVIEW_ACCEPTED")
        with observer.cursor() as cur:
            _assert_executed(cur,request,student,v)
            cur.execute("""SELECT count(*) FROM app_private.command_receipts
              WHERE request_id=%s::uuid AND idempotency_key=%s""",
              (request,"db01-p1-apply-ar-stale-review"))
            _check(cur.fetchone()==(0,),"AR_STALE_RECEIPT")
        observer.rollback()
    print("D1_DB01_P1_APPLY_REVIEW_REAL_PG_RACE_PASS "
          "observed lock, stale REVIEW rejected with no new evidence")

    # A lost acknowledgement races same-key retry from another real backend.
    student,request,v=_setup(container,run_psql,root,"aa")
    approved=_approve(psycopg,request,v,"aa")
    key="db01-p1-apply-aa-identical"
    with closing(_actor_connection(psycopg)) as winner, \
         closing(_actor_connection(psycopg)) as retry, \
         closing(_local_connect(psycopg)) as observer:
        original=_apply(winner,request,approved,key)
        with ThreadPoolExecutor(max_workers=1) as pool:
            future=pool.submit(_apply,retry,request,approved,key)
            try:
                with observer.cursor() as cur:
                    _wait_for_block(cur,retry.info.backend_pid,
                                    winner.info.backend_pid,future)
                    _check(_snapshot(cur,request,student)==
                           ("APPROVED",approved,1,1,0,2,2,0,0,0),
                           "AA_UNCOMMITTED_EVIDENCE")
                observer.rollback()
            finally:
                winner.commit()
            identical=future.result(timeout=23)
            _check(identical==original,"AA_NOT_CANONICAL_REPLAY")
            retry.commit()
        with observer.cursor() as cur:
            _assert_executed(cur,request,student,v)
        observer.rollback()
    print("D1_DB01_P1_APPLY_APPLY_REAL_PG_RACE_PASS "
          "observed lock, exact-key replay shares immutable result/receipt")
