"""True P1 Student Profile competing approved-APPLY races on one Student.

Accepted PR #75 must run first. Reuse its committed local-only Student and
independent genuine requester/reviewer identities. Both requests of a round
are independently submitted and APPROVED at the SAME Student row version.
Two separate authenticated psql sessions then genuinely compete for the
typed Student row FOR UPDATE, proven by pg_blocking_pids and a waiting
transactionid/tuple lock. No migration or hosted database is modified.
"""
from __future__ import annotations

import re
from domain_cross_family_race_ci import ROOT, CONTAINER, _numbers, _probe_worker
from domain_authorization_revocation_race_ci import _process
from domain_student_profile_reviewer_grant_race_ci import (
    STUDENT, OWNER, _requester, _reviewer, _cleanup,
)

THIRD_GRANT = "b7000000-0000-4000-8000-000000000033"
THIRD_SCOPE = "b7000000-0000-4000-8000-000000000034"
RESULT = re.compile(r"(?m)^(EXECUTED|INVALIDATED)\t([0-9]+)$")
ID = re.compile(r"(?m)^([0-9a-f]{8}(?:-[0-9a-f]{4}){3}-[0-9a-f]{12})$")

# Distinct, bounded identities and payloads; no dynamically-supplied SQL text.
CASES = (
    ("one", "Race Same Student A1", "Race Same Student B1",
     "d1-profile-same-one-requester-hold", "d1-profile-same-one-reviewer-wait",
     "profile-same-one-left-apply", "profile-same-one-right-apply",
     "requester"),
    ("two", "Race Same Student A2", "Race Same Student B2",
     "d1-profile-same-two-reviewer-hold", "d1-profile-same-two-requester-wait",
     "profile-same-two-right-apply", "profile-same-two-left-apply",
     "reviewer"),
)


def _grant(container: str, execute_sql) -> None:
    # Earlier PR #75 genuinely retired both reviewer grants. This grant is
    # strictly later than those history intervals, not artificially backdated.
    sql=f"""
BEGIN;
{_requester()}
RESET ROLE;
SET ROLE schoolos_schema_owner;
INSERT INTO app_private.role_permission_grants(
 id,role_id,role_family_only,permission_id,permission_family_safe,
 valid_from,created_by)
SELECT '{THIRD_GRANT}','b7000000-0000-4000-8000-000000000003',
 false,p.id,p.family_safe,statement_timestamp(),'{OWNER}'
FROM app_private.permissions p WHERE p.code='student.profile.approve';
INSERT INTO app_private.assignment_permission_scopes(
 id,assignment_id,grant_id,role_id,permission_id,scope_contract_id,
 scope_kind,resolver_key,valid_from,created_by)
SELECT '{THIRD_SCOPE}','b7000000-0000-4000-8000-000000000004',
 g.id,g.role_id,g.permission_id,c.id,'ALL','DIRECT',
 statement_timestamp(),'{OWNER}'
FROM app_private.role_permission_grants g
JOIN app_private.permission_scope_contracts c ON c.permission_id=g.permission_id
WHERE g.id='{THIRD_GRANT}' AND c.scope_kind='ALL' AND c.resolver_key='DIRECT';
RESET ROLE;
COMMIT;
"""
    execute_sql(container,sql,"D1_PROFILE_SAME_STUDENT_FRESH_REVIEWER_GRANT",timeout=40)
    counts=_numbers(execute_sql(container,f"""
SELECT count(*) FROM app_private.role_permission_grants
 WHERE id='{THIRD_GRANT}' AND revoked_at IS NULL;
SELECT count(*) FROM app_private.assignment_permission_scopes
 WHERE id='{THIRD_SCOPE}' AND revoked_at IS NULL;
SELECT count(*) FROM app_private.role_permission_grants
 WHERE id IN ('b7000000-0000-4000-8000-000000000013',
              'b7000000-0000-4000-8000-000000000023')
 AND revoked_at IS NOT NULL;
""","D1_PROFILE_SAME_STUDENT_GRANT_HISTORY",tuples=True))
    if counts!=["1","1","2"]:
        raise RuntimeError("D1_PROFILE_SAME_STUDENT_GRANT_HISTORY_INVALID "+",".join(counts))


def _snapshot(container: str, execute_sql) -> list[int]:
    results=_numbers(execute_sql(container,f"""
SELECT row_version FROM app_private.students WHERE id='{STUDENT}';
SELECT count(*) FROM app_private.approval_requests
 WHERE target_ref='{STUDENT}' AND state='EXECUTED';
SELECT count(*) FROM app_private.approval_requests
 WHERE target_ref='{STUDENT}' AND state='INVALIDATED';
SELECT count(*) FROM app_private.approval_requests
 WHERE target_ref='{STUDENT}' AND state='APPROVED';
SELECT count(*) FROM app_private.approval_applications a
 JOIN app_private.approval_requests r ON r.id=a.request_id
 WHERE r.target_ref='{STUDENT}';
SELECT count(*) FROM app_private.outbox_events
 WHERE event_type='student.profile_changed';
SELECT count(*) FROM app_private.command_receipts
 WHERE command_kind='request.apply' AND state='SUCCEEDED'
 AND operation_id=(SELECT id FROM app_private.operation_contracts
                   WHERE code='student.profile.update');
SELECT count(*) FROM app_private.command_receipts
 WHERE command_kind='request.apply' AND state='REJECTED'
 AND operation_id=(SELECT id FROM app_private.operation_contracts
                   WHERE code='student.profile.update');
SELECT count(*) FROM app_private.approval_reviews v
 JOIN app_private.approval_request_steps s ON s.id=v.step_id
 JOIN app_private.approval_requests r ON r.id=s.request_id
 WHERE r.target_ref='{STUDENT}' AND v.decision='APPROVE';
SELECT count(*) FROM app_private.command_receipts
 WHERE command_kind='request.submit'
 AND operation_id=(SELECT id FROM app_private.operation_contracts
                   WHERE code='student.profile.update');
SELECT count(*) FROM app_private.command_receipts
 WHERE command_kind='request.review'
 AND operation_id=(SELECT id FROM app_private.operation_contracts
                   WHERE code='student.profile.update');
SELECT count(*) FROM app_private.approval_transitions t
 JOIN app_private.approval_requests r ON r.id=t.request_id
 WHERE r.target_ref='{STUDENT}';
""","D1_PROFILE_SAME_STUDENT_EVIDENCE",tuples=True,timeout=40))
    if len(results)!=12:
        raise RuntimeError("D1_PROFILE_SAME_STUDENT_EVIDENCE_SHAPE "+",".join(results))
    return [int(x) for x in results]


def _prepare_pair(container: str, execute_sql, case: str,
                  expected: int, school_left: str, school_right: str) -> None:
    if case not in ("one","two") or not (1 <= expected <= 100):
        raise RuntimeError("D1_PROFILE_SAME_STUDENT_INVALID_PREPARE")
    # Use typed genuine protected calls, no direct APPROVED row fabrication.
    # They intentionally pin the SAME target version, but different content.
    sql=f"""
BEGIN;
{_requester()}
SELECT * FROM app.d1_submit_student_profile_update(
 '{STUDENT}',NULL,NULL,NULL,NULL,NULL,'{school_left}',NULL,{expected},
 'Competing verified change one {case}',
 'profile-same-{case}-left-submit') \\gset left_
SELECT * FROM app.d1_submit_student_profile_update(
 '{STUDENT}',NULL,NULL,NULL,NULL,NULL,'{school_right}',NULL,{expected},
 'Competing verified change two {case}',
 'profile-same-{case}-right-submit') \\gset right_
RESET ROLE;
{_reviewer()}
SELECT * FROM app.d1_review_profile_request(
 :'left_request_id','APPROVE',3,
 'Independent verification of competing left request {case}',
 'profile-same-{case}-left-review');
SELECT * FROM app.d1_review_profile_request(
 :'right_request_id','APPROVE',3,
 'Independent verification of competing right request {case}',
 'profile-same-{case}-right-review');
RESET ROLE;
COMMIT;
"""
    execute_sql(container,sql,"D1_PROFILE_SAME_STUDENT_TWO_REAL_APPROVALS_"+case,timeout=90)


def _request_id(container: str, execute_sql, case: str, side: str,
                expected: int) -> str:
    if case not in ("one","two") or side not in ("left","right"):
        raise RuntimeError("D1_PROFILE_SAME_STUDENT_LOOKUP_INVALID")
    key=f"profile-same-{case}-{side}-submit"
    sql=f"""
SELECT r.id::text FROM app_private.approval_requests r
 JOIN app_private.command_receipts receipt ON receipt.request_id=r.id
 WHERE receipt.idempotency_key='{key}'
   AND receipt.command_kind='request.submit' AND receipt.state='SUCCEEDED'
   AND r.target_ref='{STUDENT}' AND r.state='APPROVED'
   AND r.row_version=4 AND r.expected_target_version={expected}
   AND r.operation_id=(SELECT id FROM app_private.operation_contracts
                       WHERE code='student.profile.update');
"""
    values=ID.findall(execute_sql(
        container,sql,"D1_PROFILE_SAME_STUDENT_APPROVAL_LOOKUP",tuples=True))
    if len(values)!=1:
        raise RuntimeError("D1_PROFILE_SAME_STUDENT_APPROVAL_NOT_UNIQUE")
    return values[0]


def _worker(request_id: str, actor: str, key: str, name: str, *,
            hold: bool=False) -> str:
    allowed={(r[3],"requester",r[5]) for r in CASES if r[7]=="requester"}
    allowed|={(r[4],"reviewer",r[6]) for r in CASES if r[7]=="requester"}
    allowed|={(r[3],"reviewer",r[5]) for r in CASES if r[7]=="reviewer"}
    allowed|={(r[4],"requester",r[6]) for r in CASES if r[7]=="reviewer"}
    if (name,actor,key) not in allowed or not ID.fullmatch(request_id):
        raise RuntimeError("D1_PROFILE_SAME_STUDENT_UNEXPECTED_WORKER")
    settings=_requester() if actor=="requester" else _reviewer()
    return (
        "BEGIN;\n"+f"SET LOCAL application_name='{name}';\n"+settings
        +f"SELECT request_state||E'\\t'||request_version::text "
         f"FROM app.d1_apply_profile_request('{request_id}',4,'{key}');\n"
        +("SELECT pg_sleep(4);\n" if hold else "")
        +"COMMIT;\n"
    )


def _field_count(container: str, execute_sql, school: str) -> list[str]:
    if school not in ("Race Same Student A1", "Race Same Student B1",
                      "Race Same Student A2", "Race Same Student B2"):
        raise RuntimeError("D1_PROFILE_SAME_STUDENT_FIELD_INTENT_INVALID")
    return _numbers(execute_sql(container,f"""
SELECT count(*) FROM app_private.students
 WHERE id='{STUDENT}' AND previous_school='{school}';
SELECT count(*) FROM app_private.outbox_events
 WHERE event_type='student.profile_changed'
   AND payload::text LIKE '%Race Same Student%';
SELECT count(*) FROM app_private.student_identity_details
 WHERE student_id='{STUDENT}';
SELECT count(*) FROM app_private.student_special_details
 WHERE student_id='{STUDENT}';
""","D1_PROFILE_SAME_STUDENT_FIELDS",tuples=True))


def _replay(container: str, execute_sql,
            request_left: str, request_right: str,
            key_left: str, key_right: str,
            first_actor: str, second_actor: str,
            first_expected: str, second_expected: str) -> None:
    # Exact receipt keys and their original authenticated actors; a winning
    # request must remain EXECUTED and loser INVALIDATED even after target
    # version changes and the other round later completes.
    if not (ID.fullmatch(request_left) and ID.fullmatch(request_right)):
        raise RuntimeError("D1_PROFILE_SAME_STUDENT_REPLAY_REQUEST_INVALID")
    jobs=(
        (request_left,key_left,first_actor,first_expected),
        (request_right,key_right,second_actor,second_expected),
    )
    for request,key,actor,expected in jobs:
        settings=_requester() if actor=="requester" else _reviewer()
        got=RESULT.findall(execute_sql(container,
            "BEGIN;\n"+settings
            +f"SELECT request_state||E'\\t'||request_version::text "
             f"FROM app.d1_apply_profile_request('{request}',4,'{key}');\n"
            +"COMMIT;\n",
            "D1_PROFILE_SAME_STUDENT_RECEIPT_REPLAY",tuples=True,timeout=35))
        if got!=[(expected,"5")]:
            raise RuntimeError("D1_PROFILE_SAME_STUDENT_REPLAY_DRIFT")


def run_student_profile_competing_approved_applies(container: str, execute_sql) -> None:
    if container!=CONTAINER:
        raise RuntimeError("D1_PROFILE_SAME_STUDENT_DISPOSABLE_CONTAINER_ONLY")
    base=_snapshot(container,execute_sql)
    if base[1:]!=[1,1,0,1,1,1,1,2,2,2,10]:
        raise RuntimeError("D1_PROFILE_SAME_STUDENT_REQUIRES_PR75 "+str(base))
    if _field_count(container,execute_sql,"Race Same Student A1")!=["0","0","0","0"]:
        raise RuntimeError("D1_PROFILE_SAME_STUDENT_DIRTY_BASELINE")
    _grant(container,execute_sql)

    for case,left_school,right_school,holder_name,waiter_name,holder_key,waiter_key,holder_actor in CASES:
        before=_snapshot(container,execute_sql)
        _prepare_pair(container,execute_sql,case,before[0],left_school,right_school)
        left_id=_request_id(container,execute_sql,case,"left",before[0])
        right_id=_request_id(container,execute_sql,case,"right",before[0])
        prepared=_snapshot(container,execute_sql)
        expectation=before.copy()
        expectation[3]+=2 # both approved, neither terminal
        expectation[8]+=2 # independent actual reviews
        expectation[9]+=2 # submission receipts
        expectation[10]+=2 # reviewer receipts
        expectation[11]+=8 # 3 submit + 1 approved transition for each
        if prepared!=expectation:
            raise RuntimeError("D1_PROFILE_SAME_STUDENT_BOTH_APPROVALS_NOT_RETAINED "
                               +str(prepared)+" versus "+str(expectation))

        # First direction: requester holds one Student, reviewer waits.
        # Reverse: reviewer holds and requester waits. Their current-principal
        # locks are distinct, so the observed wait must be typed target-row.
        if holder_actor=="requester":
            winner_id,loser_id=left_id,right_id
            winner_school,loser_school=left_school,right_school
            loser_actor="reviewer"
        else:
            winner_id,loser_id=right_id,left_id
            winner_school,loser_school=right_school,left_school
            loser_actor="requester"
        workers=[]
        try:
            holder=_process(_worker(winner_id,holder_actor,holder_key,
                                    holder_name,hold=True))
            workers.append(holder)
            _probe_worker(container,execute_sql,holder,holder_name,None)
            waiter=_process(_worker(loser_id,loser_actor,waiter_key,
                                    waiter_name))
            workers.append(waiter)
            _probe_worker(container,execute_sql,waiter,waiter_name,holder_name)
            winner_out,winner_err=holder.communicate(timeout=30)
            loser_out,loser_err=waiter.communicate(timeout=30)
            if (holder.returncode!=0 or waiter.returncode!=0
                or RESULT.findall(winner_out)!=[("EXECUTED","5")]
                or RESULT.findall(loser_out)!=[("INVALIDATED","5")]):
                raise RuntimeError("D1_PROFILE_SAME_STUDENT_RACE_OUTCOME_INVALID "
                                   +re.sub(r"[^A-Za-z0-9 .:_-]","",
                                          winner_err[-180:]+loser_err[-180:]))
        finally:
            _cleanup(workers)

        after=_snapshot(container,execute_sql)
        desired=prepared.copy()
        desired[0]+=1 # exactly one Student version increment
        desired[1]+=1 # winner EXECUTED
        desired[2]+=1 # loser INVALIDATED
        desired[3]-=2 # no approved requests left pending
        desired[4]+=1 # one application proof
        desired[5]+=1 # one success event, no loser event
        desired[6]+=1 # one successful apply receipt
        desired[7]+=1 # one rejected apply receipt
        desired[11]+=2 # one terminal transition on each request
        if after!=desired:
            raise RuntimeError("D1_PROFILE_SAME_STUDENT_DUPLICATE_OR_LOST_EFFECT "
                               +str(after)+" versus "+str(desired))
        if _field_count(container,execute_sql,winner_school)!=["1","0","0","0"]:
            raise RuntimeError("D1_PROFILE_SAME_STUDENT_WINNER_VALUE_OR_DATA_LEAK")
        if _field_count(container,execute_sql,loser_school)!=["0","0","0","0"]:
            raise RuntimeError("D1_PROFILE_SAME_STUDENT_LOSER_OVERWRITE")
        if holder_actor=="requester":
            _replay(container,execute_sql,left_id,right_id,holder_key,waiter_key,
                    "requester","reviewer","EXECUTED","INVALIDATED")
        else:
            _replay(container,execute_sql,left_id,right_id,waiter_key,holder_key,
                    "requester","reviewer","INVALIDATED","EXECUTED")
        if _snapshot(container,execute_sql)!=desired:
            raise RuntimeError("D1_PROFILE_SAME_STUDENT_RECEIPT_REPLAY_DUPLICATED_EFFECT")
        print("D1_STUDENT_PROFILE_SAME_STUDENT_"+case.upper()+"_RACE_PASS "
              "two independently authenticated P1 APPLY sessions; holder="+holder_actor
              +"; pg_blocking_pids confirmed distinct actor blocked by actual "
               "Student-row transaction/tuple lock; one EXECUTED one INVALIDATED, "
               "exactly one Student version, one application/outbox success, "
               "loser overwrite denied and immutable historical receipt replay")

    final=_snapshot(container,execute_sql)
    if final[0]!=base[0]+2 or final[1:8]!=[3,3,0,3,3,3,3]:
        raise RuntimeError("D1_PROFILE_SAME_STUDENT_FINAL_HISTORY_DRIFT "+str(final))
    if _field_count(container,execute_sql,"Race Same Student B2")!=["1","0","0","0"]:
        raise RuntimeError("D1_PROFILE_SAME_STUDENT_REVERSE_WINNER_NOT_CURRENT")
