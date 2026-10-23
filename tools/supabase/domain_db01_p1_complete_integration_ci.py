"""DB01-09 end-to-end real authenticated P1 correction accept/reject integration.

No fabricated approvals, no private write helpers. Use three independent
synthetic Students with automatically issued original R0 Roll numbers:
one fully accepted 2-step request, one stage-1 rejection, one rejection
after a genuine first approval. Verify typed histories, immutable receipts,
evidence and absence of rejected Roll effects after COMMIT.
"""
from contextlib import closing

from domain_db01_p1_apply_race_ci import (
    ROOT, _setup, _approve, _apply, _snapshot, _assert_executed, _check
)
from domain_db01_p1_review_race_ci import _reviewer_identity
from domain_student_photo_real_pg_handoff_ci import _actor_connection, _local_connect
from domain_enrollment_end_lock_prefix_ci import CONTAINER


def _review_decision(conn, request, version, decision, key, reason):
    with conn.cursor() as cur:
        _reviewer_identity(cur)  # real bound distinct-Person reviewer, SET ROLE authenticated
        cur.execute("""SELECT request_id,request_version,request_state
          FROM app.d1_review_student_roll_correction(
            %s::uuid,%s,%s::bigint,%s,%s)""",
            (request,decision,version,reason,key))
        result=cur.fetchone()
        _check(result is not None,"REVIEW_NO_RESULT")
        return str(result[0]),int(result[1]),result[2]


def _rejected_call(psycopg, command, label):
    # PostgreSQL RaiseException is the expected protected API refusal. A
    # non-P0001 failure is a test/regression error, not a successful denial.
    with closing(_actor_connection(psycopg)) as actor:
        try:
            command(actor)
        except psycopg.errors.RaiseException as exc:
            _check(exc.sqlstate=="P0001",label+"_SQLSTATE")
            actor.rollback()
            return
        actor.rollback()
    raise RuntimeError("D1_DB01_P1_INTEGRATION_" + label + "_UNEXPECTED_SUCCESS")


def _review_denied(psycopg,request,version,decision,key,reason,label):
    with closing(_local_connect(psycopg)) as reviewer:
        try:
            _review_decision(reviewer,request,version,decision,key,reason)
        except psycopg.errors.RaiseException as exc:
            _check(exc.sqlstate=="P0001",label+"_SQLSTATE")
            reviewer.rollback()
            return
        reviewer.rollback()
    raise RuntimeError("D1_DB01_P1_INTEGRATION_"+label+"_UNEXPECTED_REVIEW")


def _rows(cur,request):
    cur.execute("""SELECT step_number,state FROM app_private.approval_request_steps
       WHERE request_id=%s::uuid ORDER BY step_number""",(request,))
    steps=cur.fetchall()
    _check(len(steps)==2,"EXACTLY_TWO_CONFIGURED_STEPS")
    return [(int(x[0]),x[1]) for x in steps]


def _review_evidence(cur,request,decisions):
    cur.execute("""SELECT rv.decision,rv.reviewer_id,rv.created_by
      FROM app_private.approval_reviews rv JOIN app_private.approval_request_steps s
        ON s.id=rv.step_id WHERE s.request_id=%s::uuid
      ORDER BY s.step_number""",(request,))
    reviews=cur.fetchall()
    _check([r[0] for r in reviews]==decisions,"EXACT_REVIEW_DECISION_HISTORY")
    _check(all(x[1]==x[2] and str(x[1])!="55555555-5555-4555-8555-555555555555"
               for x in reviews),"REVIEW_NOT_DISTINCT_ACTOR")
    cur.execute("""SELECT count(*) FROM app_private.command_receipts rc
       WHERE rc.request_id=%s::uuid AND rc.command_kind='request.review'
         AND rc.state='SUCCEEDED'
         AND rc.result_kind='D1_STUDENT_ROLL_CORRECT_REVIEW'""",(request,))
    _check(cur.fetchone()==(len(decisions),),"REVIEW_RECEIPTS_COUNT")
    cur.execute("""SELECT authority_evidence->>'decision',details
       FROM app_private.audit_events
       WHERE approval_request_id=%s::uuid AND authority_evidence->>'phase'='REVIEW'
       ORDER BY created_at,command_receipt_id""",(request,))
    audit=cur.fetchall()
    _check(len(audit)==len(decisions),"REVIEW_AUDIT_COUNT")
    _check(sorted(a[0] for a in audit)==sorted(decisions),"AUDIT_DECISIONS")
    _check(all(not(a[1] ? key) for a in audit for key in
           ("old_numeric_value","new_numeric_value","correction_reason",
            "source_numeric_value","proposed_numeric_value")),
           "REVIEW_AUDIT_LEAKS_ROLL")
    cur.execute("""SELECT count(*) FROM app_private.outbox_events o
       JOIN app_private.command_receipts rc ON rc.id=o.command_receipt_id
       WHERE rc.request_id=%s::uuid AND rc.command_kind='request.review'""",
       (request,))
    _check(cur.fetchone()==(0,),"REVIEW_EMITTED_OUTBOX")


def _original(cur,student):
    cur.execute("""SELECT r.id,r.numeric_value,r.effective_from,
       r.effective_until,r.origin_allocation_id,r.supersedes_id,
       st.row_version,e.id
      FROM app_private.roll_allocations r JOIN app_private.enrollments e
        ON e.id=r.enrollment_id JOIN app_private.students st ON st.id=r.student_id
      WHERE r.student_id=%s::uuid""",(student,))
    rows=cur.fetchall()
    _check(len(rows)==1,"INITIAL_ROLL_IS_SERVER_ALLOCATED")
    row=rows[0]
    _check(row[3] is None and row[5] is None and row[6]==1
           and row[1]>=1,"INITIAL_ROLL_ACTIVE")
    return row


def _assert_no_roll_effect(cur,student,original):
    cur.execute("""SELECT r.id,r.numeric_value,r.effective_from,
        r.effective_until,r.origin_allocation_id,r.supersedes_id,
        st.row_version,e.id
      FROM app_private.roll_allocations r JOIN app_private.enrollments e
        ON e.id=r.enrollment_id JOIN app_private.students st ON st.id=r.student_id
      WHERE r.student_id=%s::uuid""",(student,))
    _check(cur.fetchall()==[original],"REJECT_MUTATED_ROLL_OR_STUDENT")


def _enrollment_evidence(cur,student,expected=1):
    cur.execute("""SELECT count(*) FROM app_private.enrollments e
        WHERE e.student_id=%s::uuid AND e.placement_kind='PRIMARY'
          AND e.effective_until IS NULL""",(student,))
    _check(cur.fetchone()==(expected,),"REJECT_MUTATED_ENROLLMENT")


def _rejection_evidence(cur,student,request,version,approved_prefix):
    expected_review_count=approved_prefix+1
    _check(_snapshot(cur,request,student)==
           ("REJECTED",version+expected_review_count,1,1,0,
            expected_review_count,expected_review_count,0,0,0),
           "REJECTED_REQUEST_NO_EFFECT")
    expected_steps=[(1,"REJECTED"),(2,"CANCELLED")] if approved_prefix==0 else [
        (1,"APPROVED"),(2,"REJECTED")]
    _check(_rows(cur,request)==expected_steps,"TERMINAL_STEPS_WRONG")
    _review_evidence(cur,request,
                     (["APPROVE"] if approved_prefix else [])+["REJECT"])
    cur.execute("""SELECT count(*) FROM app_private.command_receipts r
      WHERE r.request_id=%s::uuid AND r.command_kind='request.apply'""",
      (request,))
    _check(cur.fetchone()==(0,),"REJECTED_HAS_APPLY_RECEIPT")
    cur.execute("""SELECT count(*) FROM app_private.approval_applications
      WHERE request_id=%s::uuid""",(request,))
    _check(cur.fetchone()==(0,),"REJECTED_HAS_APPLICATION")
    cur.execute("""SELECT count(*) FROM app_private.outbox_events o
       JOIN app_private.command_receipts r ON r.id=o.command_receipt_id
       WHERE r.request_id=%s::uuid""",(request,))
    _check(cur.fetchone()==(0,),"REJECTED_HAS_CORRECTION_OUTBOX")


def run_db01_p1_complete_approve_reject_integration(container,run_psql,root=ROOT):
    _check(container==CONTAINER,"DISPOSABLE_CONTAINER_REQUIRED")
    import psycopg

    # ACCEPT: P0 (server-issued Roll) -> authenticated SUBMIT -> two independent
    # APPROVE reviews -> authenticated APPLY -> exactly one corrected Roll.
    student,request,version=_setup(container,run_psql,root,"i9ok")
    with closing(_local_connect(psycopg)) as admin:
        with admin.cursor() as cur:
            initial=_original(cur,student)
            _check(_snapshot(cur,request,student)==
                   ("PENDING",version,1,1,0,0,0,0,0,0),"ACCEPT_P0_SUBMIT_BASELINE")
            _check(_rows(cur,request)==[(1,"OPEN"),(2,"WAITING")],
                   "ACCEPT_SUBMIT_STEP_CONFIGURATION")
        admin.rollback()
    approved=_approve(psycopg,request,version,"i9ok")
    with closing(_local_connect(psycopg)) as admin:
        with admin.cursor() as cur:
            _check(_snapshot(cur,request,student)==
                   ("APPROVED",approved,1,1,0,2,2,0,0,0),"ACCEPT_APPROVED_NO_ROLL_EFFECT")
            _check(_rows(cur,request)==[(1,"APPROVED"),(2,"APPROVED")],
                   "ACCEPT_ALL_STEPS_APPROVED")
            _review_evidence(cur,request,["APPROVE","APPROVE"])
            _assert_no_roll_effect(cur,student,initial)
        admin.rollback()
    with closing(_actor_connection(psycopg)) as actor:
        result=_apply(actor,request,approved,"db01-p1-i9-accepted-apply")
        _check(result[:3]==(request,approved+1,"EXECUTED") and
               result[3] is not None and result[4]==2,
               "ACCEPT_APPLY_RESULT")
        actor.commit()
    with closing(_local_connect(psycopg)) as admin:
        with admin.cursor() as cur:
            _assert_executed(cur,request,student,version)
            _review_evidence(cur,request,["APPROVE","APPROVE"])
            _enrollment_evidence(cur,student)
            cur.execute("""SELECT origin_allocation_id,supersedes_id,
                 numeric_value FROM app_private.roll_allocations
               WHERE id=%s::uuid""",(result[3],))
            successor=cur.fetchone()
            _check(successor is not None and successor[0]==
                   (initial[4] if initial[4] else initial[0])
                   and successor[1]==initial[0] and successor[2]!=initial[1],
                   "ACCEPT_RETAINED_SOURCE_ORIGIN")
            cur.execute("""SELECT count(*) FROM app_private.approval_requests
               WHERE id=%s::uuid AND state='EXECUTED'""",(request,))
            _check(cur.fetchone()==(1,),"ACCEPT_TERMINAL_EXECUTED")
        admin.rollback()
    with closing(_actor_connection(psycopg)) as actor:
        repeated=_apply(actor,request,approved,"db01-p1-i9-accepted-apply")
        _check(repeated==result,"ACCEPT_APPLY_REPLAY_DIFFERENT")
        actor.commit()
    print("D1_DB01_P1_FULL_SUBMIT_APPROVE_APPLY_INTEGRATION_PASS "
          "genuine P0 and two live independent APPROVE decisions, one R1 "
          "application/receipt/audit/minimized outbox, canonical replay")

    # REJECT early: live independent stage-1 reviewer stops the entire
    # request. Stage-2 WAITING must be cancelled, Roll/Student untouched.
    student,request,version=_setup(container,run_psql,root,"i9r1")
    with closing(_local_connect(psycopg)) as admin:
        with admin.cursor() as cur:
            initial=_original(cur,student)
        admin.rollback()
    decision_key="db01-p1-i9-reject-first"
    decision_reason="DB01-09 independent first reviewer rejects the correction"
    with closing(_local_connect(psycopg)) as reviewer:
        out=_review_decision(reviewer,request,version,"REJECT",
                             decision_key,decision_reason)
        _check(out==(request,version+1,"REJECTED"),"EARLY_REJECT_RESULT")
        reviewer.commit()
    with closing(_local_connect(psycopg)) as admin:
        with admin.cursor() as cur:
            _rejection_evidence(cur,student,request,version,0)
            _assert_no_roll_effect(cur,student,initial)
            _enrollment_evidence(cur,student)
        admin.rollback()
    with closing(_local_connect(psycopg)) as reviewer:
        replay=_review_decision(reviewer,request,version,"REJECT",
                                decision_key,decision_reason)
        _check(replay==out,"REJECT_EARLY_REPLAY_DIFFERENT")
        reviewer.commit()
    _review_denied(psycopg,request,version,"REJECT",decision_key,
                   "Changed review reason",
                   "EARLY_REJECT_CHANGED_KEY_PAYLOAD")
    _review_denied(psycopg,request,version,"APPROVE",
                   "db01-p1-i9-forbidden-approve-after-reject",
                   "Approval forbidden after terminal rejection",
                   "EARLY_APPROVE_AFTER_REJECT")
    _rejected_call(psycopg,
         lambda actor:_apply(actor,request,version+1,
                             "db01-p1-i9-forbidden-apply-after-reject"),
         "EARLY_APPLY_AFTER_REJECT")
    with closing(_local_connect(psycopg)) as admin:
        with admin.cursor() as cur:
            _rejection_evidence(cur,student,request,version,0)
            _assert_no_roll_effect(cur,student,initial)
            _enrollment_evidence(cur,student)
        admin.rollback()
    print("D1_DB01_P1_FULL_SUBMIT_REJECT_STAGE1_INTEGRATION_PASS "
          "genuine independent REJECT, waiting step cancelled, immutable "
          "replay, APPPROVE/APPLY denied, no Student/Roll/outbox mutation")

    # REJECT late: even an earlier genuine stage-1 APPROVE is insufficient.
    # Stage-2 independent REJECT terminalizes; APPLY must fail closed.
    student,request,version=_setup(container,run_psql,root,"i9r2")
    with closing(_local_connect(psycopg)) as admin:
        with admin.cursor() as cur:
            initial=_original(cur,student)
        admin.rollback()
    with closing(_local_connect(psycopg)) as reviewer:
        first=_review_decision(reviewer,request,version,"APPROVE",
             "db01-p1-i9-partial-first","Authorized first-stage approval")
        _check(first==(request,version+1,"PENDING"),"PARTIAL_APPROVE")
        reviewer.commit()
    with closing(_local_connect(psycopg)) as admin:
        with admin.cursor() as cur:
            _check(_snapshot(cur,request,student)==
                  ("PENDING",version+1,1,1,0,1,1,0,0,0),"PARTIAL_APPROVAL_NO_EFFECT")
            _check(_rows(cur,request)==[(1,"APPROVED"),(2,"OPEN")],
                   "SECOND_REVIEW_STEP_OPEN")
            _assert_no_roll_effect(cur,student,initial)
        admin.rollback()
    reason="Authorized second-stage rejection cancels correction"
    key="db01-p1-i9-reject-second"
    with closing(_local_connect(psycopg)) as reviewer:
        last=_review_decision(reviewer,request,version+1,"REJECT",key,reason)
        _check(last==(request,version+2,"REJECTED"),"LATE_REJECT_RESULT")
        reviewer.commit()
    _rejected_call(psycopg,
        lambda actor:_apply(actor,request,version+2,
                            "db01-p1-i9-forbidden-apply-after-stage2-reject"),
        "LATE_APPLY_AFTER_REJECT")
    with closing(_local_connect(psycopg)) as reviewer:
        replay=_review_decision(reviewer,request,version+1,"REJECT",key,reason)
        _check(replay==last,"LATE_REJECT_CANONICAL_REPLAY")
        reviewer.commit()
    _review_denied(psycopg,request,version+1,"APPROVE",
       "db01-p1-i9-forbidden-second-approve",
       "Cannot approve after second reviewer rejects",
       "LATE_APPROVE_AFTER_REJECT")
    with closing(_local_connect(psycopg)) as admin:
        with admin.cursor() as cur:
            _rejection_evidence(cur,student,request,version,1)
            _assert_no_roll_effect(cur,student,initial)
            _enrollment_evidence(cur,student)
        admin.rollback()
    print("D1_DB01_P1_FULL_SUBMIT_APPROVE_REJECT_STAGE2_INTEGRATION_PASS "
          "one genuine prior APPROVE then independent terminal REJECT, "
          "no APPLY effect, no duplicate receipts or outbox")
