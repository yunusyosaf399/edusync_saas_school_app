"""Foundation T04 two-session assignment-scope revocation vs D1 Family commands.

This is a disposable local acceptance runner. Two fresh real staff permission
grants remain active; the ONLY authority removed is their exact ALL/DIRECT
assignment_permission_scopes, under exclusive advisory lock (71001,1).
Privileged scope DML is a synthetic OWNER action, not a public admin RPC.
"""
from __future__ import annotations

from domain_cross_family_race_ci import (
    ROOT, CONTAINER, FAMILY_A, FAMILY_B, STAFF_A_BINDING, STAFF_B_BINDING,
    BINDING_A, BINDING_B, _sql_actor, _numbers,
)
from domain_authorization_revocation_race_ci import (
    ARGV, RESULT, _process, _observe,
)

A_STUDENT = "99000000-0000-4000-8000-000000000002"
A_REL = "99000000-0000-4000-8000-000000000003"
A_ACCESS = "99000000-0000-4000-8000-000000000004"
A_GRANT = "99000000-0000-4000-8000-000000000005"
A_SCOPE = "99000000-0000-4000-8000-000000000006"
B_STUDENT = "9a000000-0000-4000-8000-000000000002"
B_REL = "9a000000-0000-4000-8000-000000000003"
B_ACCESS = "9a000000-0000-4000-8000-000000000004"
B_GRANT = "9a000000-0000-4000-8000-000000000005"
B_SCOPE = "9a000000-0000-4000-8000-000000000006"


def _staff_command(which: str, student_version: int, family_version: int,
                   *, hold: bool = False) -> str:
    if not (isinstance(student_version, int) and student_version > 0
            and isinstance(family_version, int) and family_version > 0):
        raise RuntimeError("D1_SCOPE_RACE_INVALID_EXPECTED_VERSIONS")
    if which == "a":
        actor = _sql_actor("foundation-rbac-001@example.invalid", STAFF_A_BINDING)
        application = "d1-scope-a-command-wait"
        call = (f"app.d1_change_family_child_access('{A_STUDENT}',{student_version},"
                f"'{FAMILY_A}',{family_version},'REVOKE','{A_ACCESS}',CURRENT_DATE,NULL,"
                f"'Scope revocation must deny waiting child-access change',"
                f"'d1-scope-a-command-denied')")
        last = "0::text"
    elif which == "b":
        actor = _sql_actor("foundation-test-001@example.invalid", STAFF_B_BINDING)
        application = "d1-scope-b-command-hold"
        call = (f"app.d1_change_family_relationship('{B_STUDENT}',{student_version},"
                f"'{FAMILY_B}',{family_version},'END','{B_REL}',NULL,NULL,NULL,NULL,"
                f"CURRENT_DATE,'Permitted last Family B relationship END before scope loss',"
                f"NULL,'d1-scope-b-command-succeeded')")
        last = "access_closed_count::text"
    else:
        raise RuntimeError("D1_SCOPE_RACE_UNSUPPORTED_STAFF_ACTION")
    return (
        "BEGIN;\n"
        + f"SET LOCAL application_name='{application}';\n"
        + actor
        + "SELECT action||E'\\t'||student_version::text||E'\\t'"
          "||family_version::text||E'\\t'||" + last + f" FROM {call};\n"
        + ("SELECT pg_sleep(4);\n" if hold else "")
        + "COMMIT;\n"
    )


def _owner_scope_revoke(which: str, *, hold: bool = False) -> str:
    if which == "a":
        scope, application = A_SCOPE, "d1-scope-a-revoker-hold"
    elif which == "b":
        scope, application = B_SCOPE, "d1-scope-b-revoker-wait"
    else:
        raise RuntimeError("D1_SCOPE_RACE_UNSUPPORTED_OWNER_SCOPE")
    # Exact Foundation T04 EXCLUSIVE lock; never upgrade SHARED to EXCLUSIVE.
    # Owner-only test fixture revocation preserves staff grant and assignment.
    return (
        "BEGIN;\n"
        + f"SET LOCAL application_name='{application}';\n"
        + "SELECT pg_catalog.pg_advisory_xact_lock(71001,1);\n"
        + _sql_actor("foundation-rbac-001@example.invalid", STAFF_A_BINDING)
        + "RESET ROLE;\nSET ROLE schoolos_schema_owner;\n"
        + "UPDATE app_private.assignment_permission_scopes "
          "SET revoked_at=pg_catalog.clock_timestamp() "
          f"WHERE id='{scope}' AND revoked_at IS NULL;\n"
        + "RESET ROLE;\n"
        + ("SELECT pg_sleep(4);\n" if hold else "")
        + "COMMIT;\n"
    )


def _family_checked_reads(container: str, execute_sql, which: str) -> list[str]:
    if which == "a":
        email, binding, student, family, label = (
            "foundation-family-001@example.invalid", BINDING_A,
            A_STUDENT, FAMILY_A, "Cross Family race A")
        other_student = B_STUDENT
    elif which == "b":
        email, binding, student, family, label = (
            "foundation-own-002@example.invalid", BINDING_B,
            B_STUDENT, FAMILY_B, "Cross Family race B")
        other_student = A_STUDENT
    else:
        raise RuntimeError("D1_SCOPE_RACE_UNKNOWN_FAMILY_AUTH")
    sql = ("BEGIN;\n" + _sql_actor(email, binding)
           + f"SELECT count(*) FROM app.d1_read_family_summary_for_student('{student}');\n"
           + f"SELECT count(*) FROM app.d1_read_family_relationships_for_student('{student}');\n"
           + f"SELECT count(*) FROM app.d1_read_family_relationship_history('{student}');\n"
           + f"SELECT count(*) FROM app.d1_read_family_summary_for_student('{student}') "
             f"WHERE family_id='{family}';\n"
           + f"SELECT count(*) FROM app.d1_read_family_relationships_for_student('{student}') "
             f"WHERE family_label<>'{label}';\n"
           + f"SELECT count(*) FROM app.d1_read_family_relationship_history('{student}') "
             f"WHERE family_label<>'{label}';\n"
           + f"SELECT count(*) FROM app.d1_read_family_relationship_history('{other_student}');\n"
           + "RESET ROLE;\nCOMMIT;\n")
    rows = _numbers(execute_sql(container, sql,
                                "D1_SCOPE_RACE_FAMILY_CHECK_"+which,
                                tuples=True, timeout=30))
    if len(rows)!=7:
        raise RuntimeError("D1_SCOPE_RACE_CHECKED_READ_SHAPE")
    return rows


def _state(container: str, execute_sql) -> list[str]:
    sql = f"""
SELECT row_version FROM app_private.students WHERE id='{A_STUDENT}';
SELECT row_version FROM app_private.students WHERE id='{B_STUDENT}';
SELECT row_version FROM app_private.families WHERE id='{FAMILY_A}';
SELECT row_version FROM app_private.families WHERE id='{FAMILY_B}';
SELECT count(*) FROM app_private.assignment_permission_scopes
 WHERE id IN ('{A_SCOPE}','{B_SCOPE}') AND revoked_at IS NULL
   AND scope_kind='ALL' AND resolver_key='DIRECT';
SELECT count(*) FROM app_private.role_permission_grants
 WHERE id IN ('{A_GRANT}','{B_GRANT}') AND revoked_at IS NULL;
SELECT count(*) FROM app_private.principal_role_assignments
 WHERE id IN ('ffffffff-ffff-4fff-8fff-ffffffffffff',
              '76000000-0000-4000-8000-000000000007') AND revoked_at IS NULL;
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
 WHERE idempotency_key='d1-scope-a-command-denied';
SELECT count(*) FROM app_private.command_receipts
 WHERE idempotency_key='d1-scope-b-command-succeeded' AND state='SUCCEEDED';
"""
    result=_numbers(execute_sql(container,sql,"D1_SCOPE_RACE_PRIVATE_STATE",
                                tuples=True,timeout=30))
    if len(result)!=14:
        raise RuntimeError("D1_SCOPE_RACE_PRIVATE_STATE_SHAPE")
    return result


def run_family_assignment_scope_races(container: str, execute_sql) -> None:
    if container!=CONTAINER:
        raise RuntimeError("D1_SCOPE_RACE_DISPOSABLE_LOCAL_CONTAINER_ONLY")
    fixture=(ROOT/"supabase/tests/domain/fixtures/"
             "family_assignment_scope_revoke_race_setup.sql").read_text(encoding="utf-8")
    for marker in (A_STUDENT,B_STUDENT,A_GRANT,B_GRANT,A_SCOPE,B_SCOPE,
                   "request.jwt.claims","SET ROLE schoolos_schema_owner;"):
        if marker not in fixture:
            raise RuntimeError("D1_SCOPE_RACE_FIXTURE_MISSING_BOUNDARY")
    execute_sql(container,"BEGIN;\n"+fixture+"\nCOMMIT;","D1_SCOPE_RACE_FIXTURE")
    baseline=_state(container,execute_sql)
    if baseline[4:]!=["2","2","2","2","2","1","1","1","0","0"]:
        raise RuntimeError("D1_SCOPE_RACE_EXPECTED_TWO_INDEPENDENT_SCOPE_CHAINS "
                           +",".join(baseline))
    allow=["1","1","1","1","0","0","0"]
    deny=["0"]*7
    if (_family_checked_reads(container,execute_sql,"a")!=allow
            or _family_checked_reads(container,execute_sql,"b")!=allow):
        raise RuntimeError("D1_SCOPE_RACE_BOTH_INDEPENDENT_PORTALS_NOT_AUTHORIZED")
    a_s,b_s,a_f,b_f=(int(x) for x in baseline[:4])
    event_base=_numbers(execute_sql(container,"""
SELECT count(*) FROM app_private.outbox_events
 WHERE event_type='family.child_access_changed';
SELECT count(*) FROM app_private.outbox_events
 WHERE event_type='family.relationship_changed';
""","D1_SCOPE_RACE_EVENT_BASE",tuples=True))
    if len(event_base)!=2:
        raise RuntimeError("D1_SCOPE_RACE_EVENT_BASE_SHAPE")

    # Race 18: scope revoker holds Foundation EXCLUSIVE first. Staff A
    # must visibly wait for SHARED before its authorization is resolved.
    workers=[]
    try:
        owner=_process(_owner_scope_revoke("a",hold=True))
        workers.append(owner)
        _observe(container,execute_sql,owner,"d1-scope-a-revoker-hold",None,
                 mode="ExclusiveLock")
        command=_process(_staff_command("a",a_s,a_f))
        workers.append(command)
        _observe(container,execute_sql,command,"d1-scope-a-command-wait",
                 "d1-scope-a-revoker-hold",mode="ShareLock")
        owner_out,owner_err=owner.communicate(timeout=25)
        cmd_out,cmd_err=command.communicate(timeout=25)
        if (owner.returncode!=0 or command.returncode==0 or
                "D1 Family child access authority denied" not in cmd_err):
            raise RuntimeError("D1_SCOPE_RACE_REVOKER_FIRST_DID_NOT_DENY "
                               +owner_err[-250:]+cmd_err[-250:])
    finally:
        for process in workers:
            if process.poll() is None:
                process.kill()
                process.communicate(timeout=10)
    middle=_state(container,execute_sql)
    if middle[:4]!=baseline[:4] or middle[4:]!=[
        "1","2","2","2","2","1","1","1","0","0"]:
        raise RuntimeError("D1_SCOPE_RACE_REVOKER_FIRST_MUTATION_OR_GRANT_LEAK "
                           +",".join(middle))
    if (_family_checked_reads(container,execute_sql,"a")!=allow
            or _family_checked_reads(container,execute_sql,"b")!=allow):
        raise RuntimeError("D1_SCOPE_RACE_REVOKER_FIRST_FAMILY_PORTAL_CHANGED")
    print("D1_ASSIGNMENT_SCOPE_REVOKE_FIRST_RACE_PASS exact EXCLUSIVE (71001,1) "
          "scope revocation commits before blocked authenticated SHARED command; "
          "child REVOKE denied with no receipt/effect; both staff grants and "
          "assignments remain live; both Family portal checked reads unchanged")

    # Race 19: authorized staff B holds Foundation SHARED first. The
    # EXCLUSIVE revoker waits for B's completed domain effect and COMMIT.
    workers=[]
    try:
        command=_process(_staff_command("b",b_s,b_f,hold=True))
        workers.append(command)
        _observe(container,execute_sql,command,"d1-scope-b-command-hold",None,
                 mode="ShareLock")
        owner=_process(_owner_scope_revoke("b"))
        workers.append(owner)
        _observe(container,execute_sql,owner,"d1-scope-b-revoker-wait",
                 "d1-scope-b-command-hold",mode="ExclusiveLock")
        cmd_out,cmd_err=command.communicate(timeout=25)
        owner_out,owner_err=owner.communicate(timeout=25)
        done=RESULT.findall(cmd_out)
        if (command.returncode!=0 or owner.returncode!=0
                or len(done)!=1 or done[0][0]!="END"
                or done[0][3]!="1" or int(done[0][1])!=b_s+1):
            raise RuntimeError("D1_SCOPE_RACE_AUTHORIZED_COMMAND_FIRST_FAILED "
                               +cmd_err[-250:]+owner_err[-250:])
    finally:
        for process in workers:
            if process.poll() is None:
                process.kill()
                process.communicate(timeout=10)
    final=_state(container,execute_sql)
    if (int(final[0])!=a_s or int(final[1])!=b_s+1
            or final[4:]!=["0","2","2","2","2","1","0","0","0","1"]):
        raise RuntimeError("D1_SCOPE_RACE_FINAL_STAFF_GRANTS_OR_HISTORY_WRONG "
                           +",".join(final))
    if (_family_checked_reads(container,execute_sql,"a")!=allow
            or _family_checked_reads(container,execute_sql,"b")!=deny):
        raise RuntimeError("D1_SCOPE_RACE_FINAL_FAMILY_PORTAL_LEAK")

    retained=_numbers(execute_sql(container, f"""
SELECT count(*) FROM app_private.assignment_permission_scopes
 WHERE id IN ('{A_SCOPE}','{B_SCOPE}') AND revoked_at IS NOT NULL;
SELECT count(*) FROM app_private.role_permission_grants
 WHERE id IN ('{A_GRANT}','{B_GRANT}') AND revoked_at IS NULL;
SELECT count(*) FROM app_private.principal_role_assignments
 WHERE id IN ('ffffffff-ffff-4fff-8fff-ffffffffffff',
              '76000000-0000-4000-8000-000000000007') AND revoked_at IS NULL;
SELECT count(*) FROM app_private.family_student_access
 WHERE id='{A_ACCESS}' AND effective_until IS NULL;
SELECT count(*) FROM app_private.family_student_access
 WHERE id='{B_ACCESS}' AND effective_until=CURRENT_DATE AND ended_at IS NOT NULL;
SELECT count(*) FROM app_private.family_relationships
 WHERE id='{B_REL}' AND effective_until=CURRENT_DATE AND ended_at IS NOT NULL;
SELECT count(*) FROM app_private.command_receipts
 WHERE idempotency_key IN ('d1-scope-a-command-denied',
 'd1-scope-b-command-succeeded');
SELECT count(*) FROM app_private.outbox_events
 WHERE event_type='family.child_access_changed';
SELECT count(*) FROM app_private.outbox_events
 WHERE event_type='family.relationship_changed';
""","D1_SCOPE_RACE_RETAINED_HISTORY",tuples=True))
    expected=["2","2","2","1","1","1","1",
              event_base[0],str(int(event_base[1])+1)]
    if retained!=expected:
        raise RuntimeError("D1_SCOPE_RACE_RETAINED_SCOPE_OR_EVENT_MISMATCH "
                           +",".join(retained))
    print("D1_ASSIGNMENT_SCOPE_COMMAND_FIRST_RACE_PASS verified authenticated "
          "Family B END held SHARED (71001,1); separate EXCLUSIVE scope "
          "revocation waited on exact advisory pg_blocking_pids; B END and "
          "dependent child close committed once before scope revocation, "
          "Family A unaffected, Family B checked reads closed, both staff "
          "permission grants and assignments remain active, both scope "
          "intervals retained revoked, and no counterfeit child event")
