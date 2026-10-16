"""Genuine two-session P1 Student Profile apply versus reviewer-grant revocation.

Disposable pinned D1 stack only. This runner executes after the frozen D1
business suites and prior observed-lock Family races. No hosted commands.
An independent privileged fixture acquires Foundation EXCLUSIVE (71001,1);
the authenticated requester's public apply uses the existing SHARED lock.
Both explicit PostgreSQL pg_blocking_pids edges must be observed.
"""
from __future__ import annotations

import re
from domain_cross_family_race_ci import (
    ROOT, CONTAINER, STAFF_A_BINDING, STAFF_B_BINDING, _sql_actor, _numbers,
)
from domain_authorization_revocation_race_ci import _process, _observe

STUDENT = "b1000000-0000-4000-8000-000000000001"
OLD_GRANT = "b7000000-0000-4000-8000-000000000013"
NEW_GRANT = "b7000000-0000-4000-8000-000000000023"
NEW_SCOPE = "b7000000-0000-4000-8000-000000000024"
OWNER = "11111111-1111-4111-8111-111111111111"
RESULT = re.compile(r"(?m)^(EXECUTED|INVALIDATED)\t([0-9]+)$")


def _requester() -> str:
    return _sql_actor("foundation-rbac-001@example.invalid", STAFF_A_BINDING)


def _reviewer() -> str:
    return _sql_actor("foundation-test-001@example.invalid", STAFF_B_BINDING)


def _apply(request_id: str, key: str, name: str, *, hold: bool = False) -> str:
    if not re.fullmatch(r"[0-9a-f-]{36}", request_id):
        raise RuntimeError("D1_PROFILE_RACE_REQUEST_ID_INVALID")
    if (key, name) not in (
        ("profile-race-apply-success", "d1-profile-race-apply-holder"),
        ("profile-race-apply-revoked", "d1-profile-race-apply-waiting"),
    ):
        raise RuntimeError("D1_PROFILE_RACE_UNEXPECTED_APPLY_INTENT")
    return (
        "BEGIN;\n" + f"SET LOCAL application_name='{name}';\n"
        + _requester()
        + "SELECT request_state||E'\\t'||request_version::text FROM "
          f"app.d1_apply_profile_request('{request_id}',4,'{key}');\n"
        + ("SELECT pg_sleep(4);\n" if hold else "")
        + "COMMIT;\n"
    )


def _revoke(grant: str, name: str, *, hold: bool = False) -> str:
    if (grant, name) not in (
        (OLD_GRANT, "d1-profile-race-revoker-waiting"),
        (NEW_GRANT, "d1-profile-race-revoker-holder"),
    ):
        raise RuntimeError("D1_PROFILE_RACE_UNEXPECTED_GRANT")
    return (
        "BEGIN;\n" + f"SET LOCAL application_name='{name}';\n"
        + "SELECT pg_catalog.pg_advisory_xact_lock(71001,1);\n"
        + _requester()
        + "RESET ROLE;\nSET ROLE schoolos_schema_owner;\n"
        + "UPDATE app_private.role_permission_grants "
          "SET revoked_at=pg_catalog.clock_timestamp() "
          f"WHERE id='{grant}' AND revoked_at IS NULL;\n"
        + "RESET ROLE;\n"
        + ("SELECT pg_sleep(4);\n" if hold else "")
        + "COMMIT;\n"
    )


def _request_id(container: str, execute_sql, key: str) -> str:
    if key not in ("profile-race-submit-1", "profile-race-submit-2"):
        raise RuntimeError("D1_PROFILE_RACE_UNKNOWN_REQUEST_KEY")
    sql=f"""
SELECT r.id::text FROM app_private.approval_requests r
 JOIN app_private.command_receipts receipt ON receipt.request_id=r.id
 WHERE receipt.idempotency_key='{key}' AND receipt.command_kind='request.submit'
   AND receipt.state='SUCCEEDED' AND r.state='APPROVED'
   AND r.target_ref='{STUDENT}'
   AND r.operation_id=(SELECT id FROM app_private.operation_contracts
                       WHERE code='student.profile.update');
"""
    rows=re.findall(r"(?m)^([0-9a-f]{8}(?:-[0-9a-f]{4}){{3}}-[0-9a-f]{12})$",
                    execute_sql(container,sql,"D1_PROFILE_RACE_REQUEST_LOOKUP",tuples=True))
    if len(rows)!=1:
        raise RuntimeError("D1_PROFILE_RACE_APPROVED_REQUEST_NOT_UNIQUE")
    return rows[0]


def _checks(container: str, execute_sql) -> list[str]:
    return _numbers(execute_sql(container, f"""
SELECT row_version FROM app_private.students WHERE id='{STUDENT}';
SELECT count(*) FROM app_private.approval_requests r
 JOIN app_private.operation_contracts o ON o.id=r.operation_id
 WHERE o.code='student.profile.update' AND r.state='EXECUTED';
SELECT count(*) FROM app_private.approval_requests r
 JOIN app_private.operation_contracts o ON o.id=r.operation_id
 WHERE o.code='student.profile.update' AND r.state='INVALIDATED';
SELECT count(*) FROM app_private.approval_applications a
 JOIN app_private.approval_requests r ON r.id=a.request_id
 WHERE r.target_ref='{STUDENT}';
SELECT count(*) FROM app_private.outbox_events
 WHERE event_type='student.profile_changed';
SELECT count(*) FROM app_private.command_receipts
 WHERE idempotency_key='profile-race-apply-success' AND state='SUCCEEDED';
SELECT count(*) FROM app_private.command_receipts
 WHERE idempotency_key='profile-race-apply-revoked' AND state='REJECTED';
SELECT count(*) FROM app_private.role_permission_grants
 WHERE id IN ('{OLD_GRANT}','{NEW_GRANT}') AND revoked_at IS NOT NULL;
SELECT count(*) FROM app_private.approval_reviews review
 JOIN app_private.approval_request_steps step ON step.id=review.step_id
 JOIN app_private.approval_requests req ON req.id=step.request_id
 WHERE req.target_ref='{STUDENT}' AND review.decision='APPROVE';
SELECT count(*) FROM app_private.command_receipts receipt
 JOIN app_private.operation_contracts o ON o.id=receipt.operation_id
 WHERE o.code='student.profile.update' AND receipt.command_kind='request.apply';
""","D1_PROFILE_RACE_EVIDENCE",tuples=True,timeout=30))


def _second_request(container: str, execute_sql, expected: int) -> None:
    script=f"""
BEGIN;
{_requester()}
RESET ROLE;
SET ROLE schoolos_schema_owner;
INSERT INTO app_private.role_permission_grants(
 id,role_id,role_family_only,permission_id,permission_family_safe,valid_from,created_by)
SELECT '{NEW_GRANT}','b7000000-0000-4000-8000-000000000003',false,
 p.id,p.family_safe,statement_timestamp()-interval '1 hour','{OWNER}'
FROM app_private.permissions p WHERE p.code='student.profile.approve';
INSERT INTO app_private.assignment_permission_scopes(
 id,assignment_id,grant_id,role_id,permission_id,scope_contract_id,
 scope_kind,resolver_key,valid_from,created_by)
SELECT '{NEW_SCOPE}','b7000000-0000-4000-8000-000000000004',
 g.id,g.role_id,g.permission_id,c.id,'ALL','DIRECT',
 statement_timestamp()-interval '1 hour','{OWNER}'
FROM app_private.role_permission_grants g
JOIN app_private.permission_scope_contracts c ON c.permission_id=g.permission_id
WHERE g.id='{NEW_GRANT}' AND c.scope_kind='ALL' AND c.resolver_key='DIRECT';
RESET ROLE;
SET ROLE authenticated;
SELECT * FROM app.d1_submit_student_profile_update(
 '{STUDENT}',NULL,NULL,NULL,NULL,NULL,
 'Race Approved School Second',NULL,{expected},
 'Second distinct approved proposal','profile-race-submit-2') \\gset profile_
RESET ROLE;
{_reviewer()}
SELECT * FROM app.d1_review_profile_request(
 :'profile_request_id','APPROVE',3,
 'Independent reviewer confirms second proposal',
 'profile-race-review-2');
RESET ROLE;
COMMIT;
"""
    execute_sql(container,script,"D1_PROFILE_RACE_SECOND_REAL_APPROVAL",timeout=90)


def _cleanup(workers) -> None:
    for worker in workers:
        if worker.poll() is None:
            worker.kill()
            worker.communicate(timeout=10)


def run_student_profile_reviewer_grant_races(container: str, execute_sql) -> None:
    if container != CONTAINER:
        raise RuntimeError("D1_PROFILE_RACE_DISPOSABLE_CONTAINER_ONLY")
    fixture=(ROOT/"supabase/tests/domain/fixtures/"
             "student_profile_reviewer_grant_true_race_setup.sql").read_text(encoding="utf-8")
    for marker in (STUDENT,OLD_GRANT,"d1_place_student_enrollment",
                   "d1_submit_student_profile_update","d1_review_profile_request",
                   "76000000-0000-4000-8000-000000000005"):
        if marker not in fixture:
            raise RuntimeError("D1_PROFILE_RACE_FIXTURE_INCOMPLETE")
    # This fixture commits synthetic roles and one genuine protected P1
    # approved request for use in concurrent independently authenticated calls.
    execute_sql(container,"BEGIN;\n"+fixture+"\nCOMMIT;",
                "D1_PROFILE_RACE_APPROVED_FIXTURE",timeout=120)
    first_id=_request_id(container,execute_sql,"profile-race-submit-1")
    initial=_checks(container,execute_sql)
    if len(initial)!=10 or initial[1:]!=["0"]*9:
        raise RuntimeError("D1_PROFILE_RACE_UNEXPECTED_BASELINE "+",".join(initial))
    version=int(initial[0])

    # Race 1: verified authenticated APPLY holds SHARED; owner EXCLUSIVE
    # revocation is genuinely blocked on the exact advisory key. The valid
    # effect must commit before the reviewer's grant is retired.
    workers=[]
    try:
        command=_process(_apply(first_id,"profile-race-apply-success",
                                "d1-profile-race-apply-holder",hold=True))
        workers.append(command)
        _observe(container,execute_sql,command,"d1-profile-race-apply-holder",
                 None,mode="ShareLock")
        owner=_process(_revoke(OLD_GRANT,"d1-profile-race-revoker-waiting"))
        workers.append(owner)
        _observe(container,execute_sql,owner,"d1-profile-race-revoker-waiting",
                 "d1-profile-race-apply-holder",mode="ExclusiveLock")
        out_command,err_command=command.communicate(timeout=30)
        out_owner,err_owner=owner.communicate(timeout=30)
        if (command.returncode!=0 or owner.returncode!=0
                or RESULT.findall(out_command)!=[("EXECUTED","5")]):
            raise RuntimeError("D1_PROFILE_RACE_COMMAND_FIRST_FAILED "
                               +re.sub(r"[^A-Za-z0-9 .:_-]","",
                                      err_command[-240:]+err_owner[-240:]))
    finally:
        _cleanup(workers)
    middle=_checks(container,execute_sql)
    if middle != [str(version+1),"1","0","1","1","1","0","1","1","1"]:
        raise RuntimeError("D1_PROFILE_RACE_COMMAND_FIRST_EVIDENCE "+",".join(middle))
    profile=execute_sql(container,f"""
SELECT count(*) FROM app_private.students
 WHERE id='{STUDENT}' AND previous_school='Race Approved School First';
""","D1_PROFILE_RACE_FIRST_VALUE",tuples=True).strip()
    if profile!="1":
        raise RuntimeError("D1_PROFILE_RACE_FIRST_VALUE_NOT_APPLIED")
    print("D1_STUDENT_PROFILE_APPLY_FIRST_RACE_PASS shared (71001,1) held by "
          "authenticated approved P1 APPLY, EXCLUSIVE reviewer grant revocation "
          "observably waited; one protected Student mutation, application, "
          "receipt and minimized profile event before permission retirement")

    # Restore reviewer authority only via a *new* test grant and scope,
    # leaving the original revoked record immutable, then use actual RPCs
    # for a second newly approved Student proposal at the advanced version.
    _second_request(container,execute_sql,version+1)
    second_id=_request_id(container,execute_sql,"profile-race-submit-2")
    before_second=_checks(container,execute_sql)
    if before_second!=middle[:7]+middle[7:8]+["2",middle[9]]:
        raise RuntimeError("D1_PROFILE_RACE_SECOND_APPROVAL_EVIDENCE "
                           +",".join(before_second))

    # Race 2: EXCLUSIVE grant revoker commits before blocked SHARED APPLY.
    # Requester still has own student.profile.update grant/scope; the
    # authorization failure must specifically be the stale independent
    # reviewer and produce an INVALIDATED receipt with no Student mutation.
    workers=[]
    try:
        owner=_process(_revoke(NEW_GRANT,"d1-profile-race-revoker-holder",hold=True))
        workers.append(owner)
        _observe(container,execute_sql,owner,"d1-profile-race-revoker-holder",
                 None,mode="ExclusiveLock")
        command=_process(_apply(second_id,"profile-race-apply-revoked",
                                "d1-profile-race-apply-waiting"))
        workers.append(command)
        _observe(container,execute_sql,command,"d1-profile-race-apply-waiting",
                 "d1-profile-race-revoker-holder",mode="ShareLock")
        out_owner,err_owner=owner.communicate(timeout=30)
        out_command,err_command=command.communicate(timeout=30)
        if (owner.returncode!=0 or command.returncode!=0
                or RESULT.findall(out_command)!=[("INVALIDATED","5")]):
            raise RuntimeError("D1_PROFILE_RACE_REVOKE_FIRST_FAILED "
                               +re.sub(r"[^A-Za-z0-9 .:_-]","",
                                      err_command[-240:]+err_owner[-240:]))
    finally:
        _cleanup(workers)
    final=_checks(container,execute_sql)
    expected=[str(version+1),"1","1","1","1","1","1","2","2","2"]
    if final!=expected:
        raise RuntimeError("D1_PROFILE_RACE_REVOKE_FIRST_EVIDENCE "
                           +",".join(final))
    if execute_sql(container,f"""
SELECT count(*) FROM app_private.students
 WHERE id='{STUDENT}' AND previous_school='Race Approved School First';
""","D1_PROFILE_RACE_FINAL_VALUE",tuples=True).strip()!="1":
        raise RuntimeError("D1_PROFILE_RACE_REVOKER_FIRST_PARTIAL_PROFILE_EFFECT")
    replay=execute_sql(container,
        "BEGIN;\n"+_requester()+
        f"SELECT request_state||E'\\t'||request_version::text FROM "
        f"app.d1_apply_profile_request('{first_id}',4,'profile-race-apply-success');\n"
        f"SELECT request_state||E'\\t'||request_version::text FROM "
        f"app.d1_apply_profile_request('{second_id}',4,'profile-race-apply-revoked');\n"
        "COMMIT;\n",
        "D1_PROFILE_RACE_HISTORICAL_RECEIPT_REPLAY",tuples=True,timeout=30)
    results=RESULT.findall(replay)
    if results!=[("EXECUTED","5"),("INVALIDATED","5")]:
        raise RuntimeError("D1_PROFILE_RACE_RECEIPT_REPLAY_NOT_IMMUTABLE")
    if _checks(container,execute_sql)!=expected:
        raise RuntimeError("D1_PROFILE_RACE_REPLAY_DUPLICATED_EFFECT")
    print("D1_STUDENT_PROFILE_REVOKE_FIRST_RACE_PASS exclusive (71001,1) held "
          "by privileged reviewer-grant revocation, authenticated APPLY "
          "observably blocked on SHARED then INVALIDATED after current reviewer "
          "authority recheck; no second Student mutation/event/application; "
          "both historical successful and rejected receipts replay exactly once")
