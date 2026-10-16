"""Two genuine Student Profile P1 SUBMIT versus approved APPLY row-lock races.

Runs only after accepted PR #76's committed disposable D1 test fixture.
Requester and independent final reviewer use separate authenticated sessions
and distinct current-principal locks; pg_blocking_pids must prove the actual
Student-row tuple/transactionid dependency in BOTH orders. No remote actions.
"""
from __future__ import annotations

import re
from domain_cross_family_race_ci import CONTAINER, _numbers, _probe_worker
from domain_authorization_revocation_race_ci import _process
from domain_student_profile_reviewer_grant_race_ci import (
    STUDENT, _requester, _reviewer, _cleanup,
)
from domain_student_profile_competing_applies_race_ci import _snapshot

UUID = re.compile(r"(?m)^([0-9a-f]{8}(?:-[0-9a-f]{4}){3}-[0-9a-f]{12})$")
APPLY_RESULT = re.compile(r"(?m)^(EXECUTED|INVALIDATED)\t([0-9]+)$")
SUBMIT_RESULT = re.compile(r"(?m)^([0-9a-f]{8}(?:-[0-9a-f]{4}){3}-[0-9a-f]{12})\t([0-9]+)$")
CASES = (
    ("apply-first", "Race Submit Apply First Winner", "Race Submit Stale Denied",
     "profile-submit-apply-first-approved-submit",
     "profile-submit-apply-first-approved-review",
     "profile-submit-apply-first-approved-apply",
     "profile-submit-apply-first-stale-submit",
     "d1-profile-submission-apply-holder",
     "d1-profile-submission-stale-waiter"),
    ("submit-first", "Race Submit Second Apply Winner",
     "Race Submit Pending Then Drift",
     "profile-submit-apply-second-approved-submit",
     "profile-submit-apply-second-approved-review",
     "profile-submit-apply-second-approved-apply",
     "profile-submit-apply-second-pending-submit",
     "d1-profile-submission-pending-holder",
     "d1-profile-submission-apply-waiter"),
)


def _approved_id(container: str, execute_sql, case: str, expected: int) -> str:
    cfg=next((c for c in CASES if c[0]==case),None)
    if cfg is None or not 1<=expected<=100:
        raise RuntimeError("D1_PROFILE_SUBMIT_RACE_APPROVAL_LOOKUP_INVALID")
    sql=f"""
SELECT r.id::text FROM app_private.approval_requests r
 JOIN app_private.command_receipts receipt ON receipt.request_id=r.id
 WHERE r.target_ref='{STUDENT}' AND r.state='APPROVED'
   AND r.expected_target_version={expected} AND r.row_version=4
   AND receipt.command_kind='request.submit' AND receipt.state='SUCCEEDED'
   AND receipt.idempotency_key='{cfg[3]}'
   AND r.operation_id=(SELECT id FROM app_private.operation_contracts
                       WHERE code='student.profile.update');
"""
    values=UUID.findall(execute_sql(container,sql,
        "D1_PROFILE_SUBMIT_RACE_APPROVED_LOOKUP",tuples=True,timeout=35))
    if len(values)!=1:
        raise RuntimeError("D1_PROFILE_SUBMIT_RACE_APPROVAL_NOT_UNIQUE")
    return values[0]


def _create_approved(container: str, execute_sql, cfg, version: int) -> str:
    case,winner,_,submit_key,review_key,*_=cfg
    if not 1<=version<=100 or case not in ("apply-first","submit-first"):
        raise RuntimeError("D1_PROFILE_SUBMIT_RACE_PREPARE_INVALID")
    sql=f"""
BEGIN;
{_requester()}
SELECT * FROM app.d1_submit_student_profile_update(
 '{STUDENT}',NULL,NULL,NULL,NULL,NULL,'{winner}',NULL,{version},
 'Competing approved profile correction {case}','{submit_key}') \\gset prep_
RESET ROLE;
{_reviewer()}
SELECT * FROM app.d1_review_profile_request(
 :'prep_request_id','APPROVE',3,
 'Independent reviewer confirmed {case} winner','{review_key}');
RESET ROLE;
COMMIT;
"""
    execute_sql(container,sql,"D1_PROFILE_SUBMIT_RACE_PREPARE_"+case,timeout=80)
    return _approved_id(container,execute_sql,case,version)


def _apply_worker(req_id: str, case: str, *, hold: bool) -> str:
    cfg=next((c for c in CASES if c[0]==case),None)
    if cfg is None or not UUID.fullmatch(req_id):
        raise RuntimeError("D1_PROFILE_SUBMIT_RACE_APPLY_INTENT_INVALID")
    _,_,_,_,_,key,_,holder,waiter=cfg
    name=holder if case=="apply-first" else waiter
    return (
        "BEGIN;\n"+f"SET LOCAL application_name='{name}';\n"+_reviewer()
        +f"SELECT request_state||E'\\t'||request_version::text "
         f"FROM app.d1_apply_profile_request('{req_id}',4,'{key}');\n"
        +("SELECT pg_sleep(4);\n" if hold else "")
        +"COMMIT;\n"
    )


def _submit_worker(case: str, expected: int, *, hold: bool) -> str:
    cfg=next((c for c in CASES if c[0]==case),None)
    if cfg is None or not 1<=expected<=100:
        raise RuntimeError("D1_PROFILE_SUBMIT_RACE_SUBMIT_INTENT_INVALID")
    _,_,proposed,_,_,_,key,holder,waiter=cfg
    name=waiter if case=="apply-first" else holder
    return (
        "BEGIN;\n"+f"SET LOCAL application_name='{name}';\n"+_requester()
        +f"SELECT request_id::text||E'\\t'||request_version::text "
         f"FROM app.d1_submit_student_profile_update("
         f"'{STUDENT}',NULL,NULL,NULL,NULL,NULL,'{proposed}',NULL,{expected},"
         f"'Profile submission raced an approved apply {case}','{key}');\n"
        +("SELECT pg_sleep(4);\n" if hold else "")
        +"COMMIT;\n"
    )


def _key_counts(container: str, execute_sql, key: str) -> list[str]:
    if key not in (CASES[0][6],CASES[1][6]):
        raise RuntimeError("D1_PROFILE_SUBMIT_RACE_KEY_INVALID")
    return _numbers(execute_sql(container,f"""
SELECT count(*) FROM app_private.command_receipts
 WHERE idempotency_key='{key}' AND command_kind='request.submit';
SELECT count(*) FROM app_private.approval_requests r
 WHERE r.id IN (SELECT receipt.request_id FROM app_private.command_receipts receipt
                WHERE receipt.idempotency_key='{key}'
                  AND receipt.command_kind='request.submit');
""","D1_PROFILE_SUBMIT_RACE_SUBMISSION_EFFECT",tuples=True,timeout=30))


def _pending_id(container: str, execute_sql, expected: int) -> str:
    key=CASES[1][6]
    rows=UUID.findall(execute_sql(container,f"""
SELECT r.id::text FROM app_private.approval_requests r
 JOIN app_private.command_receipts receipt ON receipt.request_id=r.id
 WHERE r.target_ref='{STUDENT}' AND r.state='PENDING' AND r.row_version=3
   AND r.expected_target_version={expected}
   AND receipt.idempotency_key='{key}'
   AND receipt.command_kind='request.submit' AND receipt.state='SUCCEEDED'
   AND r.requested_payload->>'previous_school'='{CASES[1][2]}';
""","D1_PROFILE_SUBMIT_RACE_PENDING_LOOKUP",tuples=True,timeout=30))
    if len(rows)!=1:
        raise RuntimeError("D1_PROFILE_SUBMIT_RACE_PENDING_REQUEST_NOT_RETAINED")
    return rows[0]


def _field_evidence(container: str, execute_sql, winner: str, loser: str) -> list[str]:
    allowed={x for c in CASES for x in c[1:3]}
    if winner not in allowed or loser not in allowed:
        raise RuntimeError("D1_PROFILE_SUBMIT_RACE_FIELD_INTENT_INVALID")
    return _numbers(execute_sql(container,f"""
SELECT count(*) FROM app_private.students
 WHERE id='{STUDENT}' AND previous_school='{winner}';
SELECT count(*) FROM app_private.students
 WHERE id='{STUDENT}' AND previous_school='{loser}';
SELECT count(*) FROM app_private.outbox_events
 WHERE event_type='student.profile_changed'
   AND payload::text LIKE '%Race Submit%';
SELECT count(*) FROM app_private.student_identity_details
 WHERE student_id='{STUDENT}';
SELECT count(*) FROM app_private.student_special_details
 WHERE student_id='{STUDENT}';
""","D1_PROFILE_SUBMIT_RACE_FIELDS_AND_PRIVACY",tuples=True,timeout=30))


def _approved_apply_replay(container: str, execute_sql, request: str, case: str) -> None:
    if not UUID.fullmatch(request):
        raise RuntimeError("D1_PROFILE_SUBMIT_RACE_REPLAY_REQUEST_INVALID")
    cfg=next((c for c in CASES if c[0]==case),None)
    if cfg is None:
        raise RuntimeError("D1_PROFILE_SUBMIT_RACE_REPLAY_CASE_INVALID")
    output=execute_sql(container,
        "BEGIN;\n"+_reviewer()
        +f"SELECT request_state||E'\\t'||request_version::text "
         f"FROM app.d1_apply_profile_request('{request}',4,'{cfg[5]}');\n"
         "COMMIT;\n",
         "D1_PROFILE_SUBMIT_RACE_APPLY_REPLAY",tuples=True,timeout=35)
    if APPLY_RESULT.findall(output)!=[("EXECUTED","5")]:
        raise RuntimeError("D1_PROFILE_SUBMIT_RACE_APPLY_REPLAY_CHANGED")


def run_student_profile_submit_vs_approved_apply_races(container: str, execute_sql) -> None:
    if container!=CONTAINER:
        raise RuntimeError("D1_PROFILE_SUBMIT_RACE_DISPOSABLE_CONTAINER_ONLY")
    initial=_snapshot(container,execute_sql)
    if initial[1:8]!=[3,3,0,3,3,3,3]:
        raise RuntimeError("D1_PROFILE_SUBMIT_RACE_REQUIRES_PR76 "+str(initial))
    if _field_evidence(container,execute_sql,CASES[1][1],CASES[1][2])!=[
            "0","0","0","0","0"]:
        raise RuntimeError("D1_PROFILE_SUBMIT_RACE_INITIAL_VALUE_LEAK")

    # Order A: reviewer holds same-Student row inside approved APPLY;
    # requester is actually blocked on that row, then stale submit raises
    # and leaves no approval, audit, receipt, or outbox effect.
    a=CASES[0]
    before=_snapshot(container,execute_sql)
    approved_a=_create_approved(container,execute_sql,a,before[0])
    prepared=_snapshot(container,execute_sql)
    expected=before.copy()
    for index,delta in ((3,1),(8,1),(9,1),(10,1),(11,4)):
        expected[index]+=delta
    if prepared!=expected:
        raise RuntimeError("D1_PROFILE_SUBMIT_RACE_PREAPPROVAL_A_INCORRECT "
                           +str(prepared)+" vs "+str(expected))
    workers=[]
    try:
        holder=_process(_apply_worker(approved_a,"apply-first",hold=True))
        workers.append(holder)
        _probe_worker(container,execute_sql,holder,a[7],None)
        waiter=_process(_submit_worker("apply-first",before[0],hold=False))
        workers.append(waiter)
        _probe_worker(container,execute_sql,waiter,a[8],a[7])
        winner_out,winner_err=holder.communicate(timeout=30)
        stale_out,stale_err=waiter.communicate(timeout=30)
        if (holder.returncode!=0 or APPLY_RESULT.findall(winner_out)!=[("EXECUTED","5")]
            or waiter.returncode==0
            or "D1 profile request target version/state changed" not in stale_err):
            raise RuntimeError("D1_PROFILE_SUBMIT_RACE_APPLY_FIRST_OUTCOME "
                               +re.sub(r"[^A-Za-z0-9 .:_-]","",
                                      winner_err[-240:]+stale_err[-280:]))
    finally:
        _cleanup(workers)
    after=_snapshot(container,execute_sql)
    expected=prepared.copy()
    for index,delta in ((0,1),(1,1),(3,-1),(4,1),(5,1),(6,1),(11,1)):
        expected[index]+=delta
    if after!=expected or _key_counts(container,execute_sql,a[6])!=["0","0"]:
        raise RuntimeError("D1_PROFILE_SUBMIT_RACE_STALE_SUBMISSION_EFFECT "
                           +str(after)+" vs "+str(expected))
    if _field_evidence(container,execute_sql,a[1],a[2])!=["1","0","0","0","0"]:
        raise RuntimeError("D1_PROFILE_SUBMIT_RACE_APPLY_FIRST_OVERWRITE_OR_LEAK")
    _approved_apply_replay(container,execute_sql,approved_a,"apply-first")
    if _snapshot(container,execute_sql)!=expected:
        raise RuntimeError("D1_PROFILE_SUBMIT_RACE_APPLY_FIRST_REPLAY_DUPLICATED")
    print("D1_STUDENT_PROFILE_SUBMIT_APPLY_FIRST_RACE_PASS real independent "
          "reviewer approved APPLY held same-Student row, requester SUBMIT blocked "
          "on observed pg_blocking_pids tuple/transactionid; stale expected-version "
          "submit denied with zero approval/receipt, one protected Student version, "
          "application, event and immutable winner replay")

    # Order B: requester SUBMIT acquires target row first; final approver's
    # existing approved APPLY waits for that exact row and then executes.
    # The already-committed submission remains PENDING, with the *old*
    # Student version; a new approved effect cannot silently overwrite it.
    b=CASES[1]
    before=_snapshot(container,execute_sql)
    approved_b=_create_approved(container,execute_sql,b,before[0])
    prepared=_snapshot(container,execute_sql)
    expected=before.copy()
    for index,delta in ((3,1),(8,1),(9,1),(10,1),(11,4)):
        expected[index]+=delta
    if prepared!=expected:
        raise RuntimeError("D1_PROFILE_SUBMIT_RACE_PREAPPROVAL_B_INCORRECT "
                           +str(prepared)+" vs "+str(expected))
    workers=[]
    try:
        holder=_process(_submit_worker("submit-first",before[0],hold=True))
        workers.append(holder)
        _probe_worker(container,execute_sql,holder,b[7],None)
        waiter=_process(_apply_worker(approved_b,"submit-first",hold=False))
        workers.append(waiter)
        _probe_worker(container,execute_sql,waiter,b[8],b[7])
        submit_out,submit_err=holder.communicate(timeout=30)
        applied_out,applied_err=waiter.communicate(timeout=30)
        submitted=SUBMIT_RESULT.findall(submit_out)
        if (holder.returncode!=0 or len(submitted)!=1 or submitted[0][1]!="3"
            or waiter.returncode!=0
            or APPLY_RESULT.findall(applied_out)!=[("EXECUTED","5")]):
            raise RuntimeError("D1_PROFILE_SUBMIT_RACE_SUBMIT_FIRST_OUTCOME "
                               +re.sub(r"[^A-Za-z0-9 .:_-]","",
                                      submit_err[-240:]+applied_err[-280:]))
    finally:
        _cleanup(workers)
    after=_snapshot(container,execute_sql)
    expected=prepared.copy()
    for index,delta in ((0,1),(1,1),(3,-1),(4,1),(5,1),(6,1),(9,1),(11,4)):
        expected[index]+=delta
    if after!=expected or _key_counts(container,execute_sql,b[6])!=["1","1"]:
        raise RuntimeError("D1_PROFILE_SUBMIT_RACE_SUBMIT_FIRST_EVIDENCE "
                           +str(after)+" vs "+str(expected))
    pending_id=_pending_id(container,execute_sql,before[0])
    if submitted[0][0]!=pending_id:
        raise RuntimeError("D1_PROFILE_SUBMIT_RACE_PENDING_ID_NOT_SAME")
    if _field_evidence(container,execute_sql,b[1],b[2])!=["1","0","0","0","0"]:
        raise RuntimeError("D1_PROFILE_SUBMIT_RACE_PENDING_PROPOSAL_OVERWROTE_STUDENT")
    _approved_apply_replay(container,execute_sql,approved_b,"submit-first")
    # Immutable submit receipt still replays historical PENDING request v3,
    # notwithstanding a newer Student row_version from the winning APPLY.
    replay=execute_sql(container,
        "BEGIN;\n"+_requester()
        +f"SELECT request_id::text||E'\\t'||request_version::text "
         f"FROM app.d1_submit_student_profile_update("
         f"'{STUDENT}',NULL,NULL,NULL,NULL,NULL,'{b[2]}',NULL,{before[0]},"
         f"'Profile submission raced an approved apply submit-first','{b[6]}');\n"
         "COMMIT;\n",
        "D1_PROFILE_SUBMIT_RACE_HISTORICAL_SUBMIT_REPLAY",tuples=True,timeout=35)
    if SUBMIT_RESULT.findall(replay)!=[(pending_id,"3")]:
        raise RuntimeError("D1_PROFILE_SUBMIT_RACE_PENDING_RECEIPT_REPLAY_DRIFT")
    if _snapshot(container,execute_sql)!=expected:
        raise RuntimeError("D1_PROFILE_SUBMIT_RACE_SUBMIT_FIRST_REPLAY_DUPLICATED")
    print("D1_STUDENT_PROFILE_SUBMIT_SUBMIT_FIRST_RACE_PASS real requester SUBMIT "
          "held same-Student row, independent reviewer approved APPLY blocked "
          "on observed pg_blocking_pids tuple/transactionid, then executed once; "
          "new proposal remains PENDING at original now-stale target version, "
          "no unauthorized overwrite, one success event and exact receipt replay")
