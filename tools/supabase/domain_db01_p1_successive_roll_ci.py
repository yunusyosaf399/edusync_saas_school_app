"""DB01-08 genuine protected R0 -> R1 -> R2 P1 Roll-correction history.

All commands execute only against the disposable local D1 PostgreSQL stack:
two successive independent authenticated SUBMIT -> two REVIEWs -> APPLY.
School-local UTC -> Pacific/Kiritimati advances the day between corrections.
Backdated stored-zone and wrong-policy source probes must reject without effect.
"""
from contextlib import closing
from datetime import datetime, timezone
from zoneinfo import ZoneInfo

from domain_concurrency_ci import settings_sql
from domain_db01_p1_apply_race_ci import (
    ROOT, CASES, _setup, _approve, _apply, _check,
)
from domain_db01_p1_review_race_ci import _review
from domain_student_photo_real_pg_handoff_ci import _actor_connection, _local_connect
from domain_enrollment_end_lock_prefix_ci import CONTAINER

SCHOOL = "22222222-2222-4222-8222-222222222222"
OUTSIDE_SCHOOL = "f1080000-0000-4000-8000-000000000001"
OUTSIDE_POLICY = "f1080000-0000-4000-8000-000000000002"


def _school_date(cur):
    cur.execute("SELECT app_private.d1_roll_business_date(%s::uuid)",(SCHOOL,))
    result=cur.fetchone()
    _check(result is not None and result[0] is not None,"SCHOOL_DATE_MISSING")
    return result[0]


def _current(cur, student):
    cur.execute("""SELECT s.row_version,e.id,e.section_offering_id,e.effective_from,
        r.id,r.effective_from,r.policy_revision_id,r.numeric_value,
        r.origin_allocation_id,r.supersedes_id
      FROM app_private.students s JOIN app_private.enrollments e
        ON e.student_id=s.id AND e.placement_kind='PRIMARY'
       AND e.effective_until IS NULL JOIN app_private.roll_allocations r
        ON r.enrollment_id=e.id AND r.student_id=s.id
       AND r.effective_until IS NULL
      WHERE s.id=%s::uuid""",(student,))
    rows=cur.fetchall()
    _check(len(rows)==1,"CURRENT_UNIQUE")
    v,e,section,enroll_from,r,roll_from,policy,numeric,origin,prior=rows[0]
    return (int(v),str(e),str(section),enroll_from,str(r),roll_from,
            str(policy),int(numeric),str(origin) if origin else None,
            str(prior) if prior else None)


def _submit(conn, student, state, proposed, key):
    version,enrollment,section,enroll_from,roll,roll_from,policy,old,_,_=state
    with conn.cursor() as cur:
        cur.execute("SET ROLE authenticated")
        cur.execute("SET LOCAL statement_timeout='18s'")
        cur.execute("""SELECT request_id,request_version
          FROM app.d1_submit_student_roll_correction(
          %s::uuid,%s::bigint,%s::uuid,%s::uuid,%s::date,%s::uuid,%s::date,
          %s::uuid,%s::bigint,%s::bigint,%s,%s)""",
          (student,version,enrollment,section,enroll_from,roll,roll_from,
           policy,old,proposed,"DB01-08 genuine second corrected Roll",key))
        r=cur.fetchone()
        _check(r is not None,"SUBMIT_NO_RESULT")
        return str(r[0]),int(r[1])


def _reject_submit(psycopg,student,state,proposed,key,label):
    try:
        with closing(_actor_connection(psycopg)) as conn:
            try:
                _submit(conn,student,state,proposed,key)
            except psycopg.errors.RaiseException as exc:
                _check(exc.sqlstate=="P0001",label+"_DENIAL_CODE")
                conn.rollback()
                return
            conn.rollback()
    except psycopg.errors.RaiseException as exc:
        _check(exc.sqlstate=="P0001",label+"_DENIAL_CODE")
        return
    raise RuntimeError("D1_DB01_P1_R2_"+label+"_WRONG_SUCCESS")


def _review_second(psycopg,request,version):
    for step,state in ((1,"PENDING"),(2,"APPROVED")):
        with closing(_local_connect(psycopg)) as reviewer:
            result=_review(reviewer,request,version+step-1,
                           "db01-p1-r2-second-review-"+str(step),
                           "Distinct-Person configured live reviewer of R1 to R2")
            _check(result==(request,version+step,state),
                   "SECOND_REVIEW_"+str(step))
            reviewer.commit()
    return version+2


def _set_school_zone(container,run_psql,zone,phase):
    # Test-only School profile change; never use caller time zone as business date.
    sql="BEGIN;\n"+settings_sql()+"""
SET ROLE schoolos_schema_owner;
UPDATE app_private.school_profiles SET timezone='"""+zone+"""'
 WHERE id='22222222-2222-4222-8222-222222222222';
RESET ROLE;
COMMIT;"""
    run_psql(container,sql,"D1_DB01_R2_SCHOOL_ZONE_"+phase,timeout=55)


def _verify_chain(cur, student, first, second, west, east):
    cur.execute("""SELECT id,numeric_value,effective_from,effective_until,
      origin_allocation_id,supersedes_id,policy_revision_id,correction_reason
      FROM app_private.roll_allocations WHERE student_id=%s::uuid
      ORDER BY effective_from,id""",(student,))
    rows=cur.fetchall()
    _check(len(rows)==3,"THREE_RETAINED_HEADS")
    r0,r1,r2=rows
    v,enrollment,section,old_enroll,first_id,from_day,policy,num,origin,prior=first
    _check(str(r1[0])==first_id and str(r2[0])==second,
           "R1_R2_EXPECTED_IDS")
    _check(r0[3]==west and r1[2]==west and r1[3]==east and
           r2[2]==east and r2[3] is None,"RETAINED_HALF_OPEN_DATES")
    _check(str(r1[5])==str(r0[0]) and str(r2[5])==str(r1[0]),
           "EXACT_SUPERSEDES_CHAIN")
    _check(r0[4]==r1[4]==r2[4],
           "ORIGIN_RETAINED_ALL_THREE")
    _check(r0[6]==r1[6]==r2[6],"PINNED_POLICY_REVISION")
    _check(r1[1]==num and r2[1]==num+7 and r0[1] !=r1[1],
           "NUMBER_SEQUENCE")
    _check(r0[7] is None and r1[7] is not None and r2[7] is not None,
           "RESTRICTED_REASON_ON_CORRECTIONS_ONLY")
    cur.execute("SELECT row_version FROM app_private.students WHERE id=%s::uuid",
                (student,))
    _check(cur.fetchone()==(3,),"STUDENT_VERSION_1_2_3")
    cur.execute("""SELECT count(*) FROM app_private.roll_allocations
     WHERE student_id=%s::uuid AND effective_until IS NULL""",(student,))
    _check(cur.fetchone()==(1,),"ONE_CURRENT_ROLL")
    cur.execute("""SELECT next_value FROM app_private.roll_allocator_states
     WHERE policy_revision_id=%s::uuid
       AND class_offering_id IS NOT DISTINCT FROM
       (CASE WHEN (SELECT mode FROM app_private.roll_policy_revisions
              WHERE id=%s::uuid)='ACADEMIC_CONTEXT'
         THEN (SELECT co.id FROM app_private.class_offerings co
               JOIN app_private.section_offerings so ON so.class_offering_id=co.id
               WHERE so.id=%s::uuid)
         ELSE NULL::uuid END)""",(policy,policy,section))
    value=cur.fetchone()
    _check(value is not None and value[0]>=num+8,"ALLOCATOR_HIGHWATER")
    return r0,r1,r2


def _receipt_evidence(cur, request):
    cur.execute("""SELECT
      (SELECT count(*) FROM app_private.approval_applications a
         WHERE a.request_id=%s::uuid),
      (SELECT count(*) FROM app_private.command_receipts r
         WHERE r.request_id=%s::uuid AND r.command_kind='request.apply'
           AND r.state='SUCCEEDED'),
      (SELECT count(*) FROM app_private.audit_events a
         WHERE a.approval_request_id=%s::uuid
           AND a.authority_evidence->>'phase'='APPLY'),
      (SELECT count(*) FROM app_private.outbox_events ev
          JOIN app_private.command_receipts r ON r.id=ev.command_receipt_id
         WHERE r.request_id=%s::uuid AND ev.event_type='enrollment.roll_corrected')""",
                (request,request,request,request))
    _check(cur.fetchone()==(1,1,1,1),"ONE_REQUEST_APPLICATION_RECEIPT_AUDIT_OUTBOX")


def _cross_school_probe(psycopg, student, latest):
    # Foundation's School profile is singleton per tenant. A distinct School
    # cannot be hosted simultaneously here, and is NEVER provisioned by this
    # DB01 workstream. Explicitly prove the cross-School policy reference
    # does not become a valid P1 correction source.
    with closing(_local_connect(psycopg)) as observer:
        with observer.cursor() as cur:
            cur.execute("SELECT count(*) FROM app_private.school_profiles")
            _check(cur.fetchone()==(1,),"FOUNDATION_SCHOOL_SINGLETON")
            cur.execute("""SELECT count(*) FROM app_private.roll_policy_revisions
                WHERE school_id=%s::uuid""",(OUTSIDE_SCHOOL,))
            _check(cur.fetchone()==(0,),"FOREIGN_SCHOOL_NO_POLICY")
        observer.rollback()
    tampered=list(latest)
    tampered[6]=OUTSIDE_POLICY
    _reject_submit(psycopg,student,tuple(tampered),latest[7]+31,
                   "db01-p1-r2-wrong-school-policy",
                   "FOREIGN_POLICY_DENIED")


def run_db01_p1_successive_roll_date_boundaries(container,run_psql,root=ROOT):
    _check(container==CONTAINER,"DISPOSABLE_LOCAL_ONLY")
    import psycopg
    student, first_req, start_version=_setup(container,run_psql,root,"r2")
    with closing(_local_connect(psycopg)) as reader:
        with reader.cursor() as cur:
            west=_school_date(cur)
            east=cur.execute("""SELECT pg_catalog.timezone(
              'Pacific/Kiritimati',pg_catalog.clock_timestamp())::date""").fetchone()[0]
            _check(west<east,"NEXT_SCHOOL_DAY_NOT_LATER")
            _check(start_version>=1,"INITIAL_REQUEST_VERSION")
            original=_current(cur,student)
            _check(original[0]==1 and original[7]>0,"AUTOMATIC_P0_ROLL")
        reader.rollback()
    approved=_approve(psycopg,first_req,start_version,"r2")
    first_key="db01-p1-r2-original-apply"
    with closing(_actor_connection(psycopg)) as actor:
        first_result=_apply(actor,first_req,approved,first_key)
        _check(first_result[:3]==(first_req,approved+1,"EXECUTED")
               and first_result[4]==2 and first_result[5]==west,
               "FIRST_R1_APPLY_SCHOOL_DATE")
        actor.commit()
    with closing(_local_connect(psycopg)) as reader:
        with reader.cursor() as cur:
            first=_current(cur,student)
            _check(first[0]==2 and first[5]==west and
                   first[9]==original[4],"R1_FROM_R0")
            _receipt_evidence(cur,first_req)
        reader.rollback()
    print("D1_DB01_P1_R0_R1_INITIAL_REAL_PG_PASS genuine initial automatic P0, "
          "two independent reviewer steps, first authenticated R1")

    # The School's server-authoritative date moves to the following calendar
    # day while a random client/session timezone remains irrelevant.
    _set_school_zone(container,run_psql,"Pacific/Kiritimati","NEXT_DAY")
    with closing(_local_connect(psycopg)) as reader:
        with reader.cursor() as cur:
            _check(_school_date(cur)==east,"EAST_SCHOOL_DATE_NOT_CURRENT")
        reader.rollback()
    new_num=first[7]+7
    with closing(_actor_connection(psycopg)) as actor:
        with actor.cursor() as cur:
            cur.execute("SET LOCAL TimeZone='Etc/GMT+12'")
        req2,v2=_submit(actor,student,first,new_num,
                        "db01-p1-r2-second-submit")
        _check(v2>=1 and req2 !=first_req,"SECOND_REQUEST_UNIQUE")
        actor.commit()
    approval2=_review_second(psycopg,req2,v2)
    second_key="db01-p1-r2-second-apply"
    with closing(_actor_connection(psycopg)) as actor:
        with actor.cursor() as cur:
            cur.execute("SET LOCAL TimeZone='Etc/GMT+12'")
        second_result=_apply(actor,req2,approval2,second_key)
        _check(second_result[:3]==(req2,approval2+1,"EXECUTED")
               and second_result[4]==3 and second_result[5]==east
               and second_result[3]!=first_result[3],"SECOND_R2_APPLY_DAY")
        actor.commit()
    with closing(_local_connect(psycopg)) as reader:
        with reader.cursor() as cur:
            _verify_chain(cur,student,first,second_result[3],west,east)
            _receipt_evidence(cur,first_req)
            _receipt_evidence(cur,req2)
            final=_current(cur,student)
            _check(final[0]==3 and final[4]==second_result[3]
                   and final[9]==first[4],"R2_HEAD_CURRENT")
        reader.rollback()
    print("D1_DB01_P1_R0_R1_R2_REAL_PG_PASS retained 3 allocations, exact "
          "R0->R1->R2 lineage, School dates, one head, Student 1->2->3, "
          "two approved independent request evidence sets")

    # Canonical replay of the earlier R1 must never mutate newer R2.
    with closing(_actor_connection(psycopg)) as actor:
        repeated=_apply(actor,first_req,approved,first_key)
        _check(repeated==first_result,"OLD_R1_RECEIPT_CHANGED_AFTER_R2")
        actor.commit()
    with closing(_local_connect(psycopg)) as reader:
        with reader.cursor() as cur:
            after=_current(cur,student)
            _check(after==final,"OLD_R1_REPLAY_MUTATED_HEAD")
            _receipt_evidence(cur,first_req)
            _receipt_evidence(cur,req2)
        reader.rollback()
    # Preserve the latest Student optimistic token so denial cannot be
    # attributed merely to stale row_version; R1 itself is now historical.
    superseded=list(first)
    superseded[0]=final[0]
    _reject_submit(psycopg,student,tuple(superseded),new_num+3,
                   "db01-p1-r2-obsolete-r1-source","STALE_R1_DENIED")
    _cross_school_probe(psycopg,student,final)
    print("D1_DB01_P1_R2_HISTORIC_REPLAY_POLICY_BOUNDARY_PASS earlier R1 "
          "receipt canonical after R2; stale R1 and foreign School policy denied")

    # An authorized attempt at a retrograde School-local day must fail when
    # the current R2 begins later. The DB must not write zero/negative-length
    # Roll history; restoring the real stored zone changes no Roll.
    _set_school_zone(container,run_psql,"Etc/GMT+12","REGRESSED_DAY")
    with closing(_local_connect(psycopg)) as reader:
        with reader.cursor() as cur:
            _check(_school_date(cur)<east,"BACKDATED_SCHOOL_TEST_DATE")
        reader.rollback()
    _reject_submit(psycopg,student,final,final[7]+41,
                   "db01-p1-r2-retrograde-source","BACKDATED_DATE_DENIED")
    _set_school_zone(container,run_psql,"Pacific/Kiritimati","RESTORE_NEXT_DAY")
    with closing(_local_connect(psycopg)) as reader:
        with reader.cursor() as cur:
            _check(_school_date(cur)==east,"RESTORED_SCHOOL_DATE")
            _check(_current(cur,student)==final,"BACKDATE_PROBE_MUTATED_R2")
            _verify_chain(cur,student,first,second_result[3],west,east)
            _receipt_evidence(cur,first_req)
            _receipt_evidence(cur,req2)
        reader.rollback()
    print("D1_DB01_P1_R2_SCHOOL_LOCAL_DATE_BOUNDARY_PASS current stored "
          "School date controls future corrections, retrograde School date "
          "rejected, canonical lineage and two receipts unchanged")
