"""Disposable D1 authority-vs-command serialization on Foundation (71001,1).

Two real PostgreSQL two-session lock waits, testing both commit orderings.
Privileged grant revocation is an OWNER-only synthetic fixture, not an
unimplemented public security-admin command. Domain commands use real JWTs.
"""
from __future__ import annotations

import re
import subprocess
import time

from domain_cross_family_race_ci import (
    ROOT, CONTAINER, FAMILY_A, FAMILY_B, STAFF_A_BINDING, STAFF_B_BINDING,
    BINDING_A, BINDING_B, _sql_actor, _numbers,
)

A_STUDENT = "97000000-0000-4000-8000-000000000002"
A_ACCESS = "97000000-0000-4000-8000-000000000004"
B_STUDENT = "98000000-0000-4000-8000-000000000002"
B_REL = "98000000-0000-4000-8000-000000000003"
B_ACCESS = "98000000-0000-4000-8000-000000000004"
A_GRANT = "95000000-0000-4000-8000-000000000021"
B_GRANT = "95000000-0000-4000-8000-000000000023"
ARGV = ["docker", "exec", "-i", CONTAINER, "psql", "-X", "-q", "-A", "-t",
        "-v", "ON_ERROR_STOP=1", "-U", "postgres", "-d", "postgres"]
RESULT = re.compile(r"(?m)^(END|REVOKE)\t([0-9]+)\t([0-9]+)\t([0-9]+)$")


def _staff_command(which: str, student_v: int, family_v: int,
                   *, hold: bool = False) -> str:
    if which == "a":
        actor = _sql_actor("foundation-rbac-001@example.invalid", STAFF_A_BINDING)
        target = (f"app.d1_change_family_child_access('{A_STUDENT}',{student_v},"
                  f"'{FAMILY_A}',{family_v},'REVOKE','{A_ACCESS}',CURRENT_DATE,NULL,"
                  f"'Concurrent authority revocation must deny stale staff A',"
                  f"'d1-authority-revoke-first-a-denied')")
        name = "d1-authority-command-a-waiting"
        extra = "0::text"
    elif which == "b":
        actor = _sql_actor("foundation-test-001@example.invalid", STAFF_B_BINDING)
        target = (f"app.d1_change_family_relationship('{B_STUDENT}',{student_v},"
                  f"'{FAMILY_B}',{family_v},'END','{B_REL}',NULL,NULL,NULL,NULL,"
                  f"CURRENT_DATE,'Valid B final relationship END before grant revocation',"
                  f"NULL,'d1-authority-command-first-b-end')")
        name = "d1-authority-command-b-holder"
        extra = "access_closed_count::text"
    else:
        raise RuntimeError("D1_AUTH_RACE_UNKNOWN_STAFF_COMMAND")
    return (
        "BEGIN;\n" + f"SET LOCAL application_name='{name}';\n"
        + actor
        + "SELECT action||E'\\t'||student_version::text||E'\\t'"
          "||family_version::text||E'\\t'||" + extra + f" FROM {target};\n"
        + ("SELECT pg_sleep(4);\n" if hold else "")
        + "COMMIT;\n"
    )


def _revoke_grant(grant: str, app: str, *, hold: bool = False) -> str:
    if (grant, app) not in (
        (A_GRANT, "d1-authority-revoke-a-holder"),
        (B_GRANT, "d1-authority-revoke-b-waiting"),
    ):
        raise RuntimeError("D1_AUTH_RACE_UNEXPECTED_OWNER_GRANT")
    return (
        "BEGIN;\n"
        f"SET LOCAL application_name='{app}';\n"
        # Explicit EXCLUSIVE before owner DML: no shared->exclusive upgrade.
        "SELECT pg_catalog.pg_advisory_xact_lock(71001,1);\n"
        + _sql_actor("foundation-rbac-001@example.invalid", STAFF_A_BINDING)
        + "RESET ROLE;\nSET ROLE schoolos_schema_owner;\n"
        + "UPDATE app_private.role_permission_grants "
          "SET revoked_at=pg_catalog.clock_timestamp() "
          f"WHERE id='{grant}' AND revoked_at IS NULL;\n"
        + "RESET ROLE;\n"
        + ("SELECT pg_sleep(4);\n" if hold else "")
        + "COMMIT;\n"
    )


def _process(sql: str) -> subprocess.Popen:
    process = subprocess.Popen(ARGV, cwd=ROOT, stdin=subprocess.PIPE,
                               stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
    process.stdin.write(sql)
    process.stdin.close()
    process.stdin = None
    return process


def _observe(container: str, execute_sql, process: subprocess.Popen,
             application: str, blocker: str | None, *, mode: str) -> None:
    if mode not in ("ExclusiveLock", "ShareLock"):
        raise RuntimeError("D1_AUTH_RACE_INVALID_LOCK_MODE")
    if blocker is None:
        statement = f"""
SELECT CASE WHEN EXISTS (
 SELECT 1 FROM pg_catalog.pg_stat_activity a
 JOIN pg_catalog.pg_locks l ON l.pid=a.pid
 WHERE a.application_name='{application}' AND a.wait_event='PgSleep'
   AND l.locktype='advisory' AND l.granted AND l.mode='{mode}'
) THEN 1 ELSE 0 END;
"""
    else:
        statement = f"""
SELECT CASE WHEN EXISTS (
 SELECT 1 FROM pg_catalog.pg_stat_activity waiting
 JOIN pg_catalog.pg_locks pending ON pending.pid=waiting.pid
 WHERE waiting.application_name='{application}'
   AND waiting.wait_event_type='Lock'
   AND pending.locktype='advisory' AND NOT pending.granted
   AND pending.mode='{mode}'
   AND EXISTS (
     SELECT 1 FROM pg_catalog.unnest(pg_catalog.pg_blocking_pids(waiting.pid)) AS b(pid)
     JOIN pg_catalog.pg_stat_activity holder ON holder.pid=b.pid
     JOIN pg_catalog.pg_locks granted ON granted.pid=holder.pid
     WHERE holder.application_name='{blocker}'
       AND granted.locktype='advisory' AND granted.granted
       AND granted.mode=CASE WHEN pending.mode='ShareLock'
                             THEN 'ExclusiveLock' ELSE 'ShareLock' END
   )
) THEN 1 ELSE 0 END;
"""
    deadline=time.monotonic()+12
    while time.monotonic()<deadline:
        if process.poll() is not None:
            raise RuntimeError("D1_AUTH_RACE_WORKER_EXITED_BEFORE_LOCK_OBSERVED")
        if execute_sql(container, statement, "D1_AUTH_RACE_LOCK_PROBE",
                       tuples=True, timeout=10).strip()=="1":
            return
        time.sleep(0.05)
    raise RuntimeError("D1_AUTH_RACE_EXACT_ADVISORY_BLOCKING_NOT_OBSERVED")


def _one_family_read(container: str, execute_sql, which: str) -> list[str]:
    if which=="a":
        email, binding, student, family = (
            "foundation-family-001@example.invalid", BINDING_A, A_STUDENT, FAMILY_A)
    elif which=="b":
        email, binding, student, family = (
            "foundation-own-002@example.invalid", BINDING_B, B_STUDENT, FAMILY_B)
    else:
        raise RuntimeError("D1_AUTH_RACE_UNKNOWN_FAMILY")
    query=("BEGIN;\n"+_sql_actor(email,binding)
           +f"SELECT count(*) FROM app.d1_read_family_summary_for_student('{student}');\n"
           +f"SELECT count(*) FROM app.d1_read_family_relationships_for_student('{student}');\n"
           +f"SELECT count(*) FROM app.d1_read_family_relationship_history('{student}');\n"
           +f"SELECT count(*) FROM app.d1_read_family_summary_for_student('{student}') "
            f"WHERE family_id='{family}';\n"
           +"RESET ROLE;\nCOMMIT;\n")
    actual=_numbers(execute_sql(container,query,"D1_AUTH_RACE_FAMILY_READ_"+which,
                                tuples=True,timeout=30))
    if len(actual)!=4:
        raise RuntimeError("D1_AUTH_RACE_PORTAL_READ_SHAPE")
    return actual


def _evidence(container: str, execute_sql) -> list[str]:
    return _numbers(execute_sql(container, f"""
SELECT row_version FROM app_private.students WHERE id='{A_STUDENT}';
SELECT row_version FROM app_private.students WHERE id='{B_STUDENT}';
SELECT row_version FROM app_private.families WHERE id='{FAMILY_A}';
SELECT row_version FROM app_private.families WHERE id='{FAMILY_B}';
SELECT count(*) FROM app_private.role_permission_grants
 WHERE id IN ('{A_GRANT}','{B_GRANT}') AND revoked_at IS NULL;
SELECT count(*) FROM app_private.family_relationships
 WHERE student_id IN ('{A_STUDENT}','{B_STUDENT}');
SELECT count(*) FROM app_private.family_student_access
 WHERE student_id IN ('{A_STUDENT}','{B_STUDENT}');
SELECT count(*) FROM app_private.family_student_access
 WHERE id='{A_ACCESS}' AND effective_until IS NULL;
SELECT count(*) FROM app_private.family_student_access
 WHERE id='{B_ACCESS}' AND effective_until IS NULL;
SELECT count(*) FROM app_private.family_relationships
 WHERE id='{B_REL}' AND effective_until IS NULL;
SELECT count(*) FROM app_private.command_receipts
 WHERE idempotency_key='d1-authority-revoke-first-a-denied';
SELECT count(*) FROM app_private.command_receipts
 WHERE idempotency_key='d1-authority-command-first-b-end' AND state='SUCCEEDED';
""", "D1_AUTH_RACE_STATE", tuples=True, timeout=30))


def run_family_authority_revocation_races(container: str, execute_sql) -> None:
    if container!=CONTAINER:
        raise RuntimeError("D1_AUTH_RACE_DISPOSABLE_CONTAINER_REQUIRED")
    fixture=(ROOT/"supabase/tests/domain/fixtures/"
             "family_authority_revoke_race_setup.sql").read_text(encoding="utf-8")
    for needle in (A_STUDENT,B_STUDENT,"request.jwt.claims",
                   "SET ROLE schoolos_schema_owner;"):
        if needle not in fixture:
            raise RuntimeError("D1_AUTH_RACE_FIXTURE_INVALID")
    execute_sql(container,"BEGIN;\n"+fixture+"\nCOMMIT;","D1_AUTH_RACE_FIXTURE")
    before=_evidence(container,execute_sql)
    if len(before)!=12 or before[4:]!=["2","2","2","1","1","1","0","0"]:
        raise RuntimeError("D1_AUTH_RACE_INVALID_INITIAL_STATE "+",".join(before))
    if (_one_family_read(container,execute_sql,"a")!=["1"]*4
            or _one_family_read(container,execute_sql,"b")!=["1"]*4):
        raise RuntimeError("D1_AUTH_RACE_INITIAL_PORTAL_ACCESS_FAILED")
    a_student,b_student,a_family,b_family=map(int,before[:4])
    events=_numbers(execute_sql(container, """
SELECT count(*) FROM app_private.outbox_events
 WHERE event_type='family.child_access_changed';
SELECT count(*) FROM app_private.outbox_events
 WHERE event_type='family.relationship_changed';
""","D1_AUTH_RACE_EVENT_BASE",tuples=True))
    if len(events)!=2:
        raise RuntimeError("D1_AUTH_RACE_EVENT_BASE_INVALID")

    # Race 16: admin's EXCLUSIVE authorization change obtains the lock first.
    workers=[]
    try:
        revoker=_process(_revoke_grant(A_GRANT,"d1-authority-revoke-a-holder",hold=True))
        workers.append(revoker)
        _observe(container,execute_sql,revoker,"d1-authority-revoke-a-holder",None,
                 mode="ExclusiveLock")
        command=_process(_staff_command("a",a_student,a_family))
        workers.append(command)
        _observe(container,execute_sql,command,"d1-authority-command-a-waiting",
                 "d1-authority-revoke-a-holder",mode="ShareLock")
        out_revoke,err_revoke=revoker.communicate(timeout=25)
        out_cmd,err_cmd=command.communicate(timeout=25)
        if revoker.returncode!=0 or command.returncode==0 or (
           "D1 Family child access authority denied" not in err_cmd):
            raise RuntimeError("D1_AUTH_RACE_REVOKER_FIRST_DID_NOT_DENY "
                               +re.sub(r"[^A-Za-z0-9 .:_-]","",err_revoke[-200:]+err_cmd[-300:]))
    finally:
        for w in workers:
            if w.poll() is None:
                w.kill()
                w.communicate(timeout=10)
    after_a=_evidence(container,execute_sql)
    if after_a[:4]!=before[:4] or after_a[4:]!=[
        "1","2","2","1","1","1","0","0"]:
        raise RuntimeError("D1_AUTH_RACE_REVOKED_A_MUTATION_LEAK "+",".join(after_a))
    if (_one_family_read(container,execute_sql,"a")!=["1"]*4
            or _one_family_read(container,execute_sql,"b")!=["1"]*4):
        raise RuntimeError("D1_AUTH_RACE_A_GRANT_REMOVAL_CHANGED_FAMILY_READS")
    print("D1_AUTHORIZATION_REVOKE_FIRST_RACE_PASS exclusive school lock acquired first; "
          "verified staff command blocked on shared advisory lock, freshly denied; "
          "zero child-access mutation/receipt; independent FAMILY reads unchanged")

    # Race 17: legitimate command already holds SHARED. Revocation waits
    # EXCLUSIVE, then may commit only after the protected effect commits.
    workers=[]
    try:
        command=_process(_staff_command("b",b_student,b_family,hold=True))
        workers.append(command)
        _observe(container,execute_sql,command,"d1-authority-command-b-holder",None,
                 mode="ShareLock")
        revoker=_process(_revoke_grant(B_GRANT,"d1-authority-revoke-b-waiting"))
        workers.append(revoker)
        _observe(container,execute_sql,revoker,"d1-authority-revoke-b-waiting",
                 "d1-authority-command-b-holder",mode="ExclusiveLock")
        out_cmd,err_cmd=command.communicate(timeout=25)
        out_revoke,err_revoke=revoker.communicate(timeout=25)
        received=RESULT.findall(out_cmd)
        if (command.returncode!=0 or revoker.returncode!=0
                or len(received)!=1 or received[0][0]!="END"
                or received[0][3]!="1" or int(received[0][1])!=b_student+1):
            raise RuntimeError("D1_AUTH_RACE_VALID_COMMAND_FIRST_MUST_COMMIT "
                               +re.sub(r"[^A-Za-z0-9 .:_-]","",err_cmd[-250:]+err_revoke[-250:]))
    finally:
        for w in workers:
            if w.poll() is None:
                w.kill()
                w.communicate(timeout=10)

    after_b=_evidence(container,execute_sql)
    if (int(after_b[0])!=a_student or int(after_b[1])!=b_student+1
            or after_b[4:]!=["0","2","2","1","0","0","0","1"]):
        raise RuntimeError("D1_AUTH_RACE_COMMAND_FIRST_WRONG_EFFECTS "+",".join(after_b))
    if (_one_family_read(container,execute_sql,"a")!=["1"]*4
            or _one_family_read(container,execute_sql,"b")!=["0"]*4):
        raise RuntimeError("D1_AUTH_RACE_WRONG_INDEPENDENT_FAMILY_VISIBILITY")

    last=_numbers(execute_sql(container, f"""
SELECT count(*) FROM app_private.role_permission_grants
 WHERE id IN ('{A_GRANT}','{B_GRANT}') AND revoked_at IS NOT NULL;
SELECT count(*) FROM app_private.family_student_access
 WHERE id='{A_ACCESS}' AND effective_until IS NULL;
SELECT count(*) FROM app_private.family_student_access
 WHERE id='{B_ACCESS}' AND effective_until=CURRENT_DATE AND ended_at IS NOT NULL;
SELECT count(*) FROM app_private.family_relationships
 WHERE id='{B_REL}' AND effective_until=CURRENT_DATE AND ended_at IS NOT NULL;
SELECT count(*) FROM app_private.command_receipts
 WHERE idempotency_key IN ('d1-authority-revoke-first-a-denied',
  'd1-authority-command-first-b-end');
SELECT count(*) FROM app_private.outbox_events
 WHERE event_type='family.child_access_changed';
SELECT count(*) FROM app_private.outbox_events
 WHERE event_type='family.relationship_changed';
""","D1_AUTH_RACE_FINAL",tuples=True))
    wanted=["2","1","1","1","1",events[0],str(int(events[1])+1)]
    if last!=wanted:
        raise RuntimeError("D1_AUTH_RACE_EVENTS_OR_HISTORY_INCORRECT "+",".join(last))
    print("D1_AUTHORIZATION_COMMAND_FIRST_RACE_PASS authenticated Family B END held "
          "shared school authorization lock; independent exclusive grant revocation "
          "waited on exact pg_blocking_pids advisory dependency; B END committed once "
          "before revocation, retained B relationship/dependent access history, "
          "one relationship event; Family A protected portal reads remained live")
