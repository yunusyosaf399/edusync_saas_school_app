"""Two-session D1 command races, restricted to the disposable local database."""
from __future__ import annotations
import re
import subprocess
import time
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
CONTAINER = "supabase_db_saas_OS_school_app"
RESULT_RE = re.compile(r"^([0-9a-f]{8}(?:-[0-9a-f]{4}){3}-[0-9a-f]{12})\t([0-9]+)$")

def parse_result(output: str) -> tuple[str,int]:
    matches = [RESULT_RE.fullmatch(line.strip()) for line in output.splitlines()]
    rows = [match for match in matches if match]
    if len(rows) != 1:
        raise RuntimeError("D1_RACE_RESULT_SHAPE")
    return rows[0].group(1),int(rows[0].group(2))

def worker_args(container: str) -> list[str]:
    if container != CONTAINER:
        raise RuntimeError("D1_RACE_LOCAL_CONTAINER_MISMATCH")
    return ["docker","exec","-i",container,"psql","-X","-q","-A","-t",
        "-v","ON_ERROR_STOP=1","-U","postgres","-d","postgres"]

def settings_sql() -> str:
    return """
SELECT set_config('request.jwt.claim.sub',
 (SELECT id::text FROM auth.users WHERE email='foundation-rbac-001@example.invalid'),true);
SELECT set_config('request.jwt.claims',jsonb_build_object(
 'sub',current_setting('request.jwt.claim.sub'),'role','authenticated',
 'iat',(SELECT extract(epoch FROM tokens_valid_from)::bigint
 FROM app_private.principal_auth_bindings WHERE id='66666666-6666-4666-8666-666666666666'),
 'is_anonymous',false)::text,true);
SET ROLE authenticated;
"""

def command_sql(person: int,code: str,key: str,hold: bool=False) -> str:
    # All values are test-owned constants; no external text is interpolated.
    if person not in (1,2,3,4) or not re.fullmatch(r"[A-Z0-9-]+",code) or not re.fullmatch(r"[a-z0-9-]+",key):
        raise RuntimeError("D1_RACE_INTENT_INVALID")
    return "BEGIN;\n"+settings_sql()+(
        "SELECT employee_id::text||E'\\t'||row_version::text FROM app.d1_create_employee("
        "'10000000-0000-4000-8000-00000000000"+str(person)+"','"+code+"',CURRENT_DATE-10,'"+key+"');\n"
        +("SELECT pg_sleep(2);\n" if hold else "")+"COMMIT;\n")

def run_concurrency_tests(container: str,execute_sql) -> None:
    args = worker_args(container)
    fixture = (ROOT/"supabase/tests/domain/fixtures/command_actor.sql").read_text(encoding="utf-8")
    execute_sql(container,"BEGIN;\n"+fixture+"\nCOMMIT;","D1_RACE_FIXTURE")
    cases = (
        (1,"EMP-RACE-ONE","race-one",1,"EMP-RACE-ONE","race-one",None),
        (2,"EMP-RACE-TWO","race-two",4,"EMP-RACE-CONFLICT","race-two","D1 idempotency key conflicts with prior intent"),
        (3,"EMP-RACE-THREE","race-three-a",3,"EMP-RACE-OTHER","race-three-b","D1 Person already has an Employee"),
    )
    def wait_lock(query: str,process: subprocess.Popen) -> None:
        deadline = time.monotonic()+8
        while time.monotonic()<deadline:
            if process.poll() is not None:
                raise RuntimeError("D1_RACE_WORKER_EXITED_BEFORE_LOCK")
            observed = execute_sql(container,query,"D1_RACE_LOCK",tuples=True,timeout=10).strip()
            if observed == "1":
                return
            time.sleep(0.05)
        raise RuntimeError("D1_RACE_EXPECTED_LOCK_NOT_OBSERVED")

    for first_person,first_code,first_key,second_person,second_code,second_key,error in cases:
        workers = []
        try:
            first = subprocess.Popen(args,cwd=ROOT,stdin=subprocess.PIPE,stdout=subprocess.PIPE,stderr=subprocess.PIPE,text=True)
            workers.append(first)
            first.stdin.write(command_sql(first_person,first_code,first_key,True))
            first.stdin.close()
            first.stdin = None
            wait_lock("SELECT CASE WHEN EXISTS(SELECT 1 FROM pg_catalog.pg_locks WHERE locktype='advisory' AND classid=71002 AND granted) THEN 1 ELSE 0 END;",first)
            second = subprocess.Popen(args,cwd=ROOT,stdin=subprocess.PIPE,stdout=subprocess.PIPE,stderr=subprocess.PIPE,text=True)
            workers.append(second)
            second.stdin.write(command_sql(second_person,second_code,second_key))
            second.stdin.close()
            second.stdin = None
            wait_lock("SELECT CASE WHEN EXISTS(SELECT 1 FROM pg_catalog.pg_locks WHERE NOT granted AND locktype IN ('advisory','transactionid','tuple')) THEN 1 ELSE 0 END;",second)
            first_out,first_err = first.communicate(timeout=20)
            second_out,second_err = second.communicate(timeout=20)
            if first.returncode != 0 or parse_result(first_out)[1] != 1:
                raise RuntimeError("D1_RACE_FIRST_COMMAND_FAIL")
            if error is None:
                if second.returncode != 0 or parse_result(second_out) != parse_result(first_out):
                    raise RuntimeError("D1_RACE_IDENTICAL_REPLAY_MISMATCH")
            elif second.returncode == 0 or error not in second_err:
                raise RuntimeError("D1_RACE_CONFLICT_NOT_REJECTED")
            print("D1_RACE_CASE_PASS "+first_key+" lock_wait_observed=true")
        finally:
            for worker in workers:
                if worker.poll() is None:
                    worker.kill()
                    worker.communicate(timeout=10)

    counts = execute_sql(container,"""
SELECT count(*) FROM app_private.employees;
SELECT count(*) FROM app_private.employment_periods;
SELECT count(*) FROM app_private.command_receipts;
SELECT count(*) FROM app_private.audit_events WHERE event_type='employee.create';
SELECT count(*) FROM app_private.outbox_events WHERE event_type='employee.created';
SELECT count(*) FROM app_private.employees WHERE person_id='10000000-0000-4000-8000-000000000004';
""","D1_RACE_EFFECTS",tuples=True).split()
    if counts != ["3","3","3","3","3","0"]:
        raise RuntimeError("D1_RACE_DUPLICATE_OR_PARTIAL_EFFECT")
    print("D1_RACE_PASS 3 races; one employee/history/receipt/audit/event per successful intent")
    run_family_membership_race(container,execute_sql)


# A real independent two-session race after Employee fixture/races have committed.
# Only test-owned IDs and literal policies are used; this is disposable local SQL.
def family_membership_apply_sql(reason: str, key: str, hold: bool = False) -> str:
    allowed = {
        "D1 simultaneous family membership first": "family-race-first-apply",
        "D1 simultaneous family membership second": "family-race-second-apply",
        "D1 simultaneous family END first": "family-race-end-first-apply",
        "D1 simultaneous family END second": "family-race-end-second-apply",
        "D1 simultaneous family CORRECT first": "family-race-correct-first-apply",
        "D1 simultaneous family CORRECT second": "family-race-correct-second-apply",
    }
    if allowed.get(reason) != key:
        raise RuntimeError("D1_FAMILY_RACE_INTENT_INVALID")
    return (
        "BEGIN;\n"
        "SELECT id::text AS request_id FROM app_private.approval_requests "
        "WHERE reason='" + reason + "' \\gset\n"
        + settings_sql()
        + "SELECT COALESCE(membership_id::text,'00000000-0000-0000-0000-000000000000')"
        "||E'\\t'||request_state||E'\\t'||request_version::text "
        "FROM app.d1_apply_family_principal_membership_change("
        ":'request_id',4,'" + key + "');\n"
        + ("SELECT pg_sleep(3);\n" if hold else "")
        + "COMMIT;\n"
    )


def run_family_membership_race(container: str, execute_sql) -> None:
    args = worker_args(container)
    setup = (ROOT / "supabase/tests/domain/fixtures/family_membership_race_setup.sql").read_text(
        encoding="utf-8"
    )
    if "d1-family-membership-p1-approval" not in setup:
        raise RuntimeError("D1_FAMILY_RACE_FIXTURE_INVALID")
    execute_sql(container, "BEGIN;\n" + setup + "\nCOMMIT;", "D1_FAMILY_RACE_SETUP")
    outputs = []
    workers = []
    try:
        for reason,key,hold in (
            ("D1 simultaneous family membership first","family-race-first-apply",True),
            ("D1 simultaneous family membership second","family-race-second-apply",False),
        ):
            worker = subprocess.Popen(
                args,cwd=ROOT,stdin=subprocess.PIPE,stdout=subprocess.PIPE,
                stderr=subprocess.PIPE,text=True
            )
            workers.append(worker)
            worker.stdin.write(family_membership_apply_sql(reason,key,hold))
            worker.stdin.close()
            worker.stdin = None
            deadline = time.monotonic()+10
            while time.monotonic()<deadline:
                if worker.poll() is not None:
                    raise RuntimeError("D1_FAMILY_RACE_WORKER_EXITED_EARLY")
                lock_sql = (
                    "SELECT CASE WHEN EXISTS(SELECT 1 FROM pg_catalog.pg_locks "
                    "WHERE locktype='advisory' AND classid=71002 AND granted) "
                    "THEN 1 ELSE 0 END;"
                    if hold else
                    "SELECT CASE WHEN EXISTS(SELECT 1 FROM pg_catalog.pg_locks "
                    "WHERE NOT granted AND locktype IN "
                    "('advisory','transactionid','tuple')) THEN 1 ELSE 0 END;"
                )
                if execute_sql(container,lock_sql,"D1_FAMILY_RACE_LOCK",
                               tuples=True,timeout=10).strip()=="1":
                    break
                time.sleep(0.05)
            else:
                raise RuntimeError("D1_FAMILY_RACE_EXPECTED_LOCK_NOT_OBSERVED")
        for worker in workers:
            out,err=worker.communicate(timeout=30)
            if worker.returncode:
                raise RuntimeError("D1_FAMILY_RACE_APPLY_FAILED " +
                    re.sub(r"[^A-Za-z0-9_ .:-]","",err[-600:]))
            match=re.findall(
                r"(?m)^([0-9a-f-]{36})\t(EXECUTED|INVALIDATED)\t([0-9]+)$",out
            )
            if len(match)!=1:
                raise RuntimeError("D1_FAMILY_RACE_RESULT_SHAPE")
            outputs.append(match[0])
        if outputs[0][1:]!=("EXECUTED","5") or outputs[0][0]=="00000000-0000-0000-0000-000000000000":
            raise RuntimeError("D1_FAMILY_RACE_WINNER_INVALID")
        if outputs[1]!=("00000000-0000-0000-0000-000000000000","INVALIDATED","5"):
            raise RuntimeError("D1_FAMILY_RACE_LOSER_NOT_INVALIDATED")
    finally:
        for worker in workers:
            if worker.poll() is None:
                worker.kill()
                worker.communicate(timeout=10)

    # Retained source and workflow evidence must be stable after both commits.
    counts=execute_sql(container,"""
SELECT count(*) FROM app_private.family_principal_memberships;
SELECT count(*) FROM app_private.approval_applications;
SELECT count(*) FROM app_private.approval_requests WHERE state='EXECUTED'
 AND operation_id=(SELECT id FROM app_private.operation_contracts
 WHERE code='family.principal_membership.change');
SELECT count(*) FROM app_private.approval_requests WHERE state='INVALIDATED'
 AND operation_id=(SELECT id FROM app_private.operation_contracts
 WHERE code='family.principal_membership.change');
SELECT count(*) FROM app_private.command_receipts
 WHERE operation_id=(SELECT id FROM app_private.operation_contracts
 WHERE code='family.principal_membership.change');
SELECT count(*) FROM app_private.outbox_events
 WHERE event_type='family.principal_link_changed';
SELECT count(*) FROM app_private.family_student_access;
""","D1_FAMILY_RACE_EFFECTS",tuples=True).split()
    if counts!=["1","1","1","1","6","1","0"]:
        raise RuntimeError("D1_FAMILY_RACE_DUPLICATE_OR_MISSING_EVIDENCE " +
                           ",".join(counts))
    print("D1_FAMILY_MEMBERSHIP_RACE_PASS 1 two-session P1 competing ADD race; "
          "lock_wait_observed=true; one EXECUTED, one INVALIDATED; "
          "one membership/application/outbox event")
    run_family_membership_lineage_races(container, execute_sql)


# Exercise two distinct write conflicts after the previously verified P1 ADD race.
# The first approved END closes its original membership. Two approved CORRECT
# requests then contend for one predecessor; only one may append its successor.
# All setup uses public typed RPCs and an independently verified reviewer.
_FAMILY_RACE_ID = "64000000-0000-4000-8000-000000000001"
_FAMILY_RACE_PRINCIPAL = "64000000-0000-4000-8000-000000000005"
_FAMILY_RACE_UUID = re.compile(r"[0-9a-f]{8}(?:-[0-9a-f]{4}){3}-[0-9a-f]{12}")


def family_lineage_setup_sql(action: str, source_id: str) -> str:
    if action not in ("END", "CORRECT") or _FAMILY_RACE_UUID.fullmatch(source_id) is None:
        raise RuntimeError("D1_FAMILY_LINEAGE_RACE_INTENT_INVALID")
    # A fixed historical boundary is valid for both END and the correction
    # following that END. Identity never changes through CORRECT.
    return fr"""BEGIN;
{settings_sql()}
SELECT * FROM app.d1_submit_family_principal_membership_change(
 '{_FAMILY_RACE_ID}',1,'{_FAMILY_RACE_PRINCIPAL}',1,
 '{action}','{source_id}'::uuid,CURRENT_DATE-3,
 'D1 simultaneous family {action} first','family-race-{action.lower()}-first-submit')
 \gset first_
SELECT * FROM app.d1_submit_family_principal_membership_change(
 '{_FAMILY_RACE_ID}',1,'{_FAMILY_RACE_PRINCIPAL}',1,
 '{action}','{source_id}'::uuid,CURRENT_DATE-3,
 'D1 simultaneous family {action} second','family-race-{action.lower()}-second-submit')
 \gset second_
RESET ROLE;
SELECT set_config('request.jwt.claim.sub',
 (SELECT id::text FROM auth.users WHERE email='foundation-test-001@example.invalid'),true);
SELECT set_config('request.jwt.claims',jsonb_build_object(
 'sub',current_setting('request.jwt.claim.sub'),'role','authenticated',
 'iat',(SELECT extract(epoch FROM tokens_valid_from)::bigint
 FROM app_private.principal_auth_bindings
 WHERE id='76000000-0000-4000-8000-000000000005'),
 'is_anonymous',false)::text,true);
SET ROLE authenticated;
SELECT * FROM app.d1_review_family_principal_membership_change(
 :'first_request_id','APPROVE',3,'Independent historical {action} review first',
 'family-race-{action.lower()}-first-review') \gset first_review_
SELECT * FROM app.d1_review_family_principal_membership_change(
 :'second_request_id','APPROVE',3,'Independent historical {action} review second',
 'family-race-{action.lower()}-second-review') \gset second_review_
RESET ROLE;
COMMIT;
"""


def run_family_membership_lineage_races(container: str, execute_sql) -> None:
    args = worker_args(container)
    source_id = execute_sql(
        container,
        "SELECT id::text FROM app_private.family_principal_memberships "
        "WHERE family_id='" + _FAMILY_RACE_ID + "' "
        "AND principal_id='" + _FAMILY_RACE_PRINCIPAL + "' "
        "AND supersedes_id IS NULL AND effective_until IS NULL;",
        "D1_FAMILY_LINEAGE_SOURCE", tuples=True,
    ).strip()
    if _FAMILY_RACE_UUID.fullmatch(source_id) is None:
        raise RuntimeError("D1_FAMILY_LINEAGE_SOURCE_INVALID")
    missing = "00000000-0000-0000-0000-000000000000"

    for phase_index, action in enumerate(("END", "CORRECT"), start=1):
        setup = family_lineage_setup_sql(action, source_id)
        execute_sql(container, setup, "D1_FAMILY_LINEAGE_" + action + "_SETUP")
        workers = []
        outcomes = []
        try:
            for position, hold in (("first", True), ("second", False)):
                reason = "D1 simultaneous family " + action + " " + position
                key = "family-race-" + action.lower() + "-" + position + "-apply"
                worker = subprocess.Popen(
                    args, cwd=ROOT, stdin=subprocess.PIPE,
                    stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True,
                )
                workers.append(worker)
                worker.stdin.write(family_membership_apply_sql(reason, key, hold))
                worker.stdin.close()
                worker.stdin = None
                deadline = time.monotonic() + 10
                # Observe an actual held transaction lock and then a pending
                # second-session lock; two sequential calls do not qualify.
                lock_sql = (
                    "SELECT CASE WHEN EXISTS(SELECT 1 FROM pg_catalog.pg_locks "
                    "WHERE locktype='advisory' AND classid=71002 AND granted) "
                    "THEN 1 ELSE 0 END;"
                    if hold else
                    "SELECT CASE WHEN EXISTS(SELECT 1 FROM pg_catalog.pg_locks "
                    "WHERE NOT granted AND locktype IN "
                    "('advisory','transactionid','tuple')) THEN 1 ELSE 0 END;"
                )
                while time.monotonic() < deadline:
                    if worker.poll() is not None:
                        raise RuntimeError("D1_FAMILY_LINEAGE_WORKER_EXITED_EARLY")
                    if execute_sql(
                        container, lock_sql, "D1_FAMILY_LINEAGE_LOCK",
                        tuples=True, timeout=10,
                    ).strip() == "1":
                        break
                    time.sleep(0.05)
                else:
                    raise RuntimeError("D1_FAMILY_LINEAGE_LOCK_NOT_OBSERVED")

            for worker in workers:
                output, stderr = worker.communicate(timeout=30)
                if worker.returncode:
                    # Do not include credentials or SQL text in logs.
                    raise RuntimeError(
                        "D1_FAMILY_LINEAGE_" + action + "_APPLY_FAILED "
                        + re.sub(r"[^A-Za-z0-9_ .:-]", "", stderr[-400:])
                    )
                matches = re.findall(
                    r"(?m)^([0-9a-f-]{36})\t(EXECUTED|INVALIDATED)\t([0-9]+)$",
                    output,
                )
                if len(matches) != 1:
                    raise RuntimeError("D1_FAMILY_LINEAGE_RESULT_SHAPE")
                outcomes.append(matches[0])

            winning_id, winning_state, winning_version = outcomes[0]
            if (winning_state, winning_version) != ("EXECUTED", "5"):
                raise RuntimeError("D1_FAMILY_LINEAGE_WINNER_NOT_EXECUTED")
            if outcomes[1] != (missing, "INVALIDATED", "5"):
                raise RuntimeError("D1_FAMILY_LINEAGE_LOSER_NOT_INVALIDATED")
            if action == "END" and winning_id != source_id:
                raise RuntimeError("D1_FAMILY_LINEAGE_END_CHANGED_ID")
            if action == "CORRECT" and (winning_id == source_id or winning_id == missing):
                raise RuntimeError("D1_FAMILY_LINEAGE_CORRECT_NOT_SUCCESSOR")
        finally:
            for worker in workers:
                if worker.poll() is None:
                    worker.kill()
                    worker.communicate(timeout=10)

        # Each accepted operation writes one application/outbox event. A loser
        # retains its INVALIDATED workflow receipt but no domain effect.
        counts = execute_sql(container, f"""
SELECT count(*) FROM app_private.family_principal_memberships;
SELECT count(*) FROM app_private.approval_applications;
SELECT count(*) FROM app_private.approval_requests
 WHERE state='EXECUTED'
 AND operation_id=(SELECT id FROM app_private.operation_contracts
 WHERE code='family.principal_membership.change');
SELECT count(*) FROM app_private.approval_requests
 WHERE state='INVALIDATED'
 AND operation_id=(SELECT id FROM app_private.operation_contracts
 WHERE code='family.principal_membership.change');
SELECT count(*) FROM app_private.command_receipts
 WHERE operation_id=(SELECT id FROM app_private.operation_contracts
 WHERE code='family.principal_membership.change');
SELECT count(*) FROM app_private.outbox_events
 WHERE event_type='family.principal_link_changed';
SELECT count(*) FROM app_private.family_relationships
 WHERE family_id='{_FAMILY_RACE_ID}';
SELECT count(*) FROM app_private.family_student_access;
SELECT count(*) FROM app_private.family_principal_memberships
 WHERE id='{source_id}' AND family_id='{_FAMILY_RACE_ID}'
 AND principal_id='{_FAMILY_RACE_PRINCIPAL}'
 AND supersedes_id IS NULL AND effective_from=CURRENT_DATE-10
 AND effective_until=CURRENT_DATE-3 AND ended_at IS NOT NULL AND ended_by IS NOT NULL;
""", "D1_FAMILY_LINEAGE_" + action + "_EFFECTS", tuples=True).split()
        expected = [str(phase_index), str(phase_index+1),
                    str(phase_index+1), str(phase_index+1),
                    str(6 * (phase_index+1)), str(phase_index+1),
                    "1", "0", "1"]
        # END retains the original row (one total); CORRECT appends one
        # successor (two total). The other metrics increase once per phase.
        expected[0] = "1" if action == "END" else "2"
        if counts != expected:
            raise RuntimeError("D1_FAMILY_LINEAGE_" + action +
                               "_EVIDENCE_MISMATCH " + ",".join(counts))

        if action == "CORRECT":
            successor_count = execute_sql(container, f"""
SELECT count(*) FROM app_private.family_principal_memberships
 WHERE id='{winning_id}' AND supersedes_id='{source_id}'
 AND family_id='{_FAMILY_RACE_ID}' AND principal_id='{_FAMILY_RACE_PRINCIPAL}'
 AND effective_from=CURRENT_DATE-3 AND effective_until IS NULL;
""", "D1_FAMILY_LINEAGE_SUCCESSOR", tuples=True).strip()
            if successor_count != "1":
                raise RuntimeError("D1_FAMILY_LINEAGE_SUCCESSOR_NOT_RETAINED")
        print("D1_FAMILY_MEMBERSHIP_" + action + "_RACE_PASS "
              "two-session P1 race; lock_wait_observed=true; "
              "one EXECUTED, one INVALIDATED; retained membership lineage")
    print("D1_FAMILY_MEMBERSHIP_LINEAGE_RACES_PASS 2 END/CORRECT races")
    run_family_relationship_end_race(container, execute_sql)


# Effect30 P1: two distinct preapproved END intents for the same retained
# Student relationship. Require a real WAITING PostgreSQL lock, not sequential
# executions, before accepting one winner and one terminal INVALIDATED loser.
_REL_END_SOURCE = "64000000-0000-4000-8000-000000000004"
_REL_END_STUDENT = "64000000-0000-4000-8000-000000000002"
_REL_END_FAMILY = "64000000-0000-4000-8000-000000000001"
_REL_END_MISSING = "00000000-0000-0000-0000-000000000000"


def family_relationship_end_apply_sql(position: str, hold: bool = False) -> str:
    if position not in ("first", "second") or type(hold) is not bool:
        raise RuntimeError("D1_RELATIONSHIP_END_RACE_INTENT_INVALID")
    reason = "D1 competing relationship END " + position
    key = "family-relationship-end-" + position + "-apply"
    return (
        "BEGIN;\n"
        "SET LOCAL application_name='d1-relationship-end-" + position + "';\n"
        "SELECT id::text AS request_id FROM app_private.approval_requests "
        "WHERE reason='" + reason + "' \\gset\n"
        + settings_sql()
        + "SELECT COALESCE(relationship_id::text,'" + _REL_END_MISSING + "')"
        "||E'\\t'||request_state||E'\\t'||request_version::text "
        "FROM app.d1_apply_family_relationship_change("
        ":'request_id'::uuid,4,'" + key + "');\n"
        + ("SELECT pg_sleep(3);\n" if hold else "")
        + "COMMIT;\n"
    )


def run_family_relationship_end_race(container: str, execute_sql) -> None:
    args = worker_args(container)
    setup = (ROOT / "supabase/tests/domain/fixtures/family_relationship_end_race_setup.sql").read_text(
        encoding="utf-8"
    )
    if ("d1-family-relationship-end-race-p1" not in setup
        or setup.count("app.d1_submit_family_relationship_change(") != 2
        or setup.count("app.d1_review_family_relationship_change(") != 2):
        raise RuntimeError("D1_RELATIONSHIP_END_RACE_FIXTURE_INVALID")
    # Prior membership races leave the original relationship intact; this gate
    # fails closed if any earlier step unexpectedly touched the source.
    before = execute_sql(container, """
SELECT count(*) FROM app_private.family_relationships
 WHERE id='64000000-0000-4000-8000-000000000004'
 AND student_id='64000000-0000-4000-8000-000000000002'
 AND family_id='64000000-0000-4000-8000-000000000001'
 AND effective_from=CURRENT_DATE-20 AND effective_until IS NULL
 AND supersedes_id IS NULL;
SELECT count(*) FROM app_private.student_primary_family_contexts
 WHERE student_id='64000000-0000-4000-8000-000000000002';
SELECT count(*) FROM app_private.family_student_access
 WHERE student_id='64000000-0000-4000-8000-000000000002';
""", "D1_RELATIONSHIP_END_RACE_PRECONDITION", tuples=True).split()
    if before != ["1", "0", "0"]:
        raise RuntimeError("D1_RELATIONSHIP_END_RACE_SOURCE_CHANGED")
    execute_sql(container, "BEGIN;\n"+setup+"\nCOMMIT;",
                "D1_RELATIONSHIP_END_RACE_SETUP")
    approved = execute_sql(container, """
SELECT count(*) FROM app_private.approval_requests
 WHERE state='APPROVED' AND reason LIKE 'D1 competing relationship END %'
 AND operation_id=(SELECT id FROM app_private.operation_contracts
 WHERE code='family.relationship.change');
SELECT count(*) FROM app_private.approval_reviews v
 JOIN app_private.approval_request_steps s ON s.id=v.step_id
 JOIN app_private.approval_requests r ON r.id=s.request_id
 WHERE r.reason LIKE 'D1 competing relationship END %'
 AND r.operation_id=(SELECT id FROM app_private.operation_contracts
 WHERE code='family.relationship.change');
""", "D1_RELATIONSHIP_END_RACE_APPROVED", tuples=True).split()
    if approved != ["2", "2"]:
        raise RuntimeError("D1_RELATIONSHIP_END_RACE_PREAPPROVAL_INVALID")
    workers = []
    outcomes = []
    try:
        for position, hold in (("first", True), ("second", False)):
            worker = subprocess.Popen(
                args,cwd=ROOT,stdin=subprocess.PIPE,stdout=subprocess.PIPE,
                stderr=subprocess.PIPE,text=True,
            )
            workers.append(worker)
            worker.stdin.write(family_relationship_end_apply_sql(position, hold))
            worker.stdin.close()
            worker.stdin = None
            deadline = time.monotonic()+10
            # Follow the precise worker by application_name; unrelated stack
            # background locks cannot satisfy the contention observation.
            lock_sql = (
                "SELECT CASE WHEN EXISTS(SELECT 1 FROM pg_catalog.pg_locks l "
                "JOIN pg_catalog.pg_stat_activity a ON a.pid=l.pid "
                "WHERE a.application_name='d1-relationship-end-first' "
                "AND l.granted AND l.locktype='advisory' AND l.classid=71001) "
                "THEN 1 ELSE 0 END;"
                if hold else
                "SELECT CASE WHEN EXISTS(SELECT 1 FROM pg_catalog.pg_locks l "
                "JOIN pg_catalog.pg_stat_activity a ON a.pid=l.pid "
                "WHERE a.application_name='d1-relationship-end-second' "
                "AND NOT l.granted AND l.locktype IN "
                "('advisory','transactionid','tuple')) THEN 1 ELSE 0 END;"
            )
            while time.monotonic() < deadline:
                if worker.poll() is not None:
                    raise RuntimeError("D1_RELATIONSHIP_END_RACE_WORKER_EXITED_EARLY")
                if execute_sql(container,lock_sql,"D1_RELATIONSHIP_END_RACE_LOCK",
                               tuples=True,timeout=10).strip()=="1":
                    break
                time.sleep(0.05)
            else:
                raise RuntimeError("D1_RELATIONSHIP_END_RACE_LOCK_NOT_OBSERVED")
        for worker in workers:
            output, stderr = worker.communicate(timeout=30)
            if worker.returncode:
                raise RuntimeError("D1_RELATIONSHIP_END_RACE_APPLY_FAILED "
                    + re.sub(r"[^A-Za-z0-9_ .:-]","",stderr[-400:]))
            rows = re.findall(
                r"(?m)^([0-9a-f-]{36})\t(EXECUTED|INVALIDATED)\t([0-9]+)$",
                output,
            )
            if len(rows) != 1:
                raise RuntimeError("D1_RELATIONSHIP_END_RACE_RESULT_SHAPE")
            outcomes.append(rows[0])
        if outcomes[0] != (_REL_END_SOURCE, "EXECUTED", "5"):
            raise RuntimeError("D1_RELATIONSHIP_END_RACE_WINNER_INVALID")
        if outcomes[1] != (_REL_END_MISSING, "INVALIDATED", "5"):
            raise RuntimeError("D1_RELATIONSHIP_END_RACE_LOSER_NOT_INVALIDATED")
    finally:
        for worker in workers:
            if worker.poll() is None:
                worker.kill()
                worker.communicate(timeout=10)
    # The winner alone changes the original source. No new relationship or
    # child-access grant may appear, and only one approved request can APPLY.
    counts = execute_sql(container, """
SELECT count(*) FROM app_private.family_relationships
 WHERE id='64000000-0000-4000-8000-000000000004'
 AND student_id='64000000-0000-4000-8000-000000000002'
 AND family_id='64000000-0000-4000-8000-000000000001'
 AND effective_from=CURRENT_DATE-20 AND effective_until=CURRENT_DATE-3
 AND supersedes_id IS NULL AND ended_at IS NOT NULL AND ended_by IS NOT NULL;
SELECT count(*) FROM app_private.family_relationships
 WHERE student_id='64000000-0000-4000-8000-000000000002';
SELECT count(*) FROM app_private.student_primary_family_contexts
 WHERE student_id='64000000-0000-4000-8000-000000000002';
SELECT count(*) FROM app_private.family_student_access
 WHERE student_id='64000000-0000-4000-8000-000000000002';
SELECT count(*) FROM app_private.approval_requests
 WHERE state='EXECUTED' AND operation_id=(SELECT id
 FROM app_private.operation_contracts WHERE code='family.relationship.change');
SELECT count(*) FROM app_private.approval_requests
 WHERE state='INVALIDATED' AND operation_id=(SELECT id
 FROM app_private.operation_contracts WHERE code='family.relationship.change');
SELECT count(*) FROM app_private.approval_applications
 WHERE operation_id=(SELECT id FROM app_private.operation_contracts
 WHERE code='family.relationship.change');
SELECT count(*) FROM app_private.command_receipts
 WHERE operation_id=(SELECT id FROM app_private.operation_contracts
 WHERE code='family.relationship.change');
SELECT count(*) FROM app_private.outbox_events
 WHERE event_type='family.relationship_changed';
SELECT count(*) FROM app_private.approval_reviews v
 JOIN app_private.approval_request_steps s ON s.id=v.step_id
 JOIN app_private.approval_requests r ON r.id=s.request_id
 WHERE r.operation_id=(SELECT id FROM app_private.operation_contracts
 WHERE code='family.relationship.change');
""", "D1_RELATIONSHIP_END_RACE_EVIDENCE", tuples=True).split()
    if counts != ["1","1","0","0","1","1","1","6","1","2"]:
        raise RuntimeError("D1_RELATIONSHIP_END_RACE_EVIDENCE_MISMATCH "
                           + ",".join(counts))
    print("D1_FAMILY_RELATIONSHIP_END_RACE_PASS 1 two-session Effect30 P1 "
          "competing END race; lock_wait_observed=true; one EXECUTED, "
          "one INVALIDATED; one retained closed source/application/event")
    run_family_relationship_correct_race(container, execute_sql)


# Effect30 P1 Family relationship CORRECT competition. The previous P1 END
# race has closed its source, so this distinct, selected guardian is a
# disposable, pre-existing fixture, not a CORRECT of an already ended source.
_REL_CORRECT_SOURCE = "81000000-0000-4000-8000-000000000010"
_REL_CORRECT_CONTEXT = "81000000-0000-4000-8000-000000000011"


def family_relationship_correct_apply_sql(position: str, hold: bool = False) -> str:
    if position not in ("first", "second") or type(hold) is not bool:
        raise RuntimeError("D1_RELATIONSHIP_CORRECT_RACE_INTENT_INVALID")
    reason = "D1 competing relationship CORRECT " + position
    key = "family-relationship-correct-" + position + "-apply"
    return (
        "BEGIN;\n"
        "SET LOCAL application_name='d1-relationship-correct-" + position + "';\n"
        "SELECT id::text AS request_id FROM app_private.approval_requests "
        "WHERE reason='" + reason + "' \\gset\n"
        + settings_sql()
        + "SELECT COALESCE(relationship_id::text,'" + _REL_END_MISSING + "')"
        "||E'\\t'||request_state||E'\\t'||request_version::text "
        "FROM app.d1_apply_family_relationship_change("
        ":'request_id'::uuid,4,'" + key + "');\n"
        + ("SELECT pg_sleep(3);\n" if hold else "")
        + "COMMIT;\n"
    )


def run_family_relationship_correct_race(container: str, execute_sql) -> None:
    args = worker_args(container)
    setup = (ROOT / "supabase/tests/domain/fixtures/family_relationship_correct_race_setup.sql").read_text(
        encoding="utf-8"
    )
    if ("Uncorrected retained guardian" not in setup
        or setup.count("app.d1_submit_family_relationship_change(") != 2
        or setup.count("app.d1_review_family_relationship_change(") != 2):
        raise RuntimeError("D1_RELATIONSHIP_CORRECT_RACE_FIXTURE_INVALID")
    # Only one closed source and completed END application must exist before
    # the new fixture; the previous END race is not rerun or altered.
    before = execute_sql(container, """
SELECT count(*) FROM app_private.family_relationships
 WHERE id='64000000-0000-4000-8000-000000000004'
 AND effective_until=CURRENT_DATE-3 AND supersedes_id IS NULL
 AND ended_at IS NOT NULL AND ended_by IS NOT NULL;
SELECT count(*) FROM app_private.family_relationships
 WHERE student_id='64000000-0000-4000-8000-000000000002';
SELECT count(*) FROM app_private.student_primary_family_contexts
 WHERE student_id='64000000-0000-4000-8000-000000000002';
SELECT count(*) FROM app_private.family_student_access
 WHERE student_id='64000000-0000-4000-8000-000000000002';
SELECT count(*) FROM app_private.approval_requests
 WHERE state='EXECUTED' AND operation_id=(
 SELECT id FROM app_private.operation_contracts
 WHERE code='family.relationship.change');
""", "D1_RELATIONSHIP_CORRECT_RACE_PRECONDITION", tuples=True).split()
    if before != ["1", "1", "0", "0", "1"]:
        raise RuntimeError("D1_RELATIONSHIP_CORRECT_RACE_PRECONDITION_MISMATCH "
                           + ",".join(before))
    execute_sql(container, "BEGIN;\n" + setup + "\nCOMMIT;",
                "D1_RELATIONSHIP_CORRECT_RACE_SETUP")
    approved = execute_sql(container, """
SELECT count(*) FROM app_private.approval_requests
 WHERE state='APPROVED'
 AND reason LIKE 'D1 competing relationship CORRECT %'
 AND operation_id=(SELECT id FROM app_private.operation_contracts
 WHERE code='family.relationship.change');
SELECT count(*) FROM app_private.approval_reviews v
 JOIN app_private.approval_request_steps s ON s.id=v.step_id
 JOIN app_private.approval_requests r ON r.id=s.request_id
 WHERE r.reason LIKE 'D1 competing relationship CORRECT %'
 AND r.operation_id=(SELECT id FROM app_private.operation_contracts
 WHERE code='family.relationship.change');
SELECT count(DISTINCT requested_payload->>'display_name')
 FROM app_private.approval_requests
 WHERE reason LIKE 'D1 competing relationship CORRECT %';
SELECT count(*) FROM app_private.student_primary_family_contexts
 WHERE id='81000000-0000-4000-8000-000000000011'
 AND family_relationship_id='81000000-0000-4000-8000-000000000010'
 AND effective_until IS NULL;
""", "D1_RELATIONSHIP_CORRECT_RACE_APPROVED", tuples=True).split()
    if approved != ["2", "2", "2", "1"]:
        raise RuntimeError("D1_RELATIONSHIP_CORRECT_RACE_PREAPPROVAL_INVALID "
                           + ",".join(approved))
    workers = []
    outcomes = []
    try:
        for position, hold in (("first", True), ("second", False)):
            worker = subprocess.Popen(
                args,cwd=ROOT,stdin=subprocess.PIPE,stdout=subprocess.PIPE,
                stderr=subprocess.PIPE,text=True,
            )
            workers.append(worker)
            worker.stdin.write(family_relationship_correct_apply_sql(position, hold))
            worker.stdin.close()
            worker.stdin = None
            deadline = time.monotonic() + 10
            lock_sql = (
                "SELECT CASE WHEN EXISTS(SELECT 1 FROM pg_catalog.pg_locks l "
                "JOIN pg_catalog.pg_stat_activity a ON a.pid=l.pid "
                "WHERE a.application_name='d1-relationship-correct-first' "
                "AND l.granted AND l.locktype='advisory' AND l.classid=71001) "
                "THEN 1 ELSE 0 END;"
                if hold else
                "SELECT CASE WHEN EXISTS(SELECT 1 FROM pg_catalog.pg_locks l "
                "JOIN pg_catalog.pg_stat_activity a ON a.pid=l.pid "
                "WHERE a.application_name='d1-relationship-correct-second' "
                "AND NOT l.granted AND l.locktype IN "
                "('advisory','transactionid','tuple')) THEN 1 ELSE 0 END;"
            )
            while time.monotonic() < deadline:
                if worker.poll() is not None:
                    raise RuntimeError("D1_RELATIONSHIP_CORRECT_RACE_WORKER_EXITED_EARLY")
                if execute_sql(container, lock_sql,
                               "D1_RELATIONSHIP_CORRECT_RACE_LOCK",
                               tuples=True,timeout=10).strip() == "1":
                    break
                time.sleep(0.05)
            else:
                raise RuntimeError("D1_RELATIONSHIP_CORRECT_RACE_LOCK_NOT_OBSERVED")
        for worker in workers:
            output, stderr = worker.communicate(timeout=30)
            if worker.returncode:
                raise RuntimeError("D1_RELATIONSHIP_CORRECT_RACE_APPLY_FAILED "
                    + re.sub(r"[^A-Za-z0-9_ .:-]","",stderr[-400:]))
            rows = re.findall(
                r"(?m)^([0-9a-f-]{36})\t(EXECUTED|INVALIDATED)\t([0-9]+)$",
                output,
            )
            if len(rows) != 1:
                raise RuntimeError("D1_RELATIONSHIP_CORRECT_RACE_RESULT_SHAPE")
            outcomes.append(rows[0])
        winning_id, winning_state, winning_version = outcomes[0]
        if ((winning_state, winning_version) != ("EXECUTED", "5")
            or winning_id in (_REL_CORRECT_SOURCE, _REL_END_MISSING)):
            raise RuntimeError("D1_RELATIONSHIP_CORRECT_RACE_WINNER_INVALID")
        if outcomes[1] != (_REL_END_MISSING, "INVALIDATED", "5"):
            raise RuntimeError("D1_RELATIONSHIP_CORRECT_RACE_LOSER_NOT_INVALIDATED")
    finally:
        for worker in workers:
            if worker.poll() is None:
                worker.kill()
                worker.communicate(timeout=10)
    # One successor, not two: the losing differently-approved payload cannot
    # enter the retained fact chain, even after waiting for the first commit.
    counts = execute_sql(container, f"""
SELECT count(*) FROM app_private.family_relationships
 WHERE id='{_REL_CORRECT_SOURCE}' AND supersedes_id IS NULL
 AND student_id='{_REL_END_STUDENT}' AND family_id='{_REL_END_FAMILY}'
 AND effective_from=CURRENT_DATE-2 AND effective_until=CURRENT_DATE-1
 AND ended_at IS NOT NULL AND ended_by IS NOT NULL;
SELECT count(*) FROM app_private.family_relationships
 WHERE id='{winning_id}' AND supersedes_id='{_REL_CORRECT_SOURCE}'
 AND student_id='{_REL_END_STUDENT}' AND family_id='{_REL_END_FAMILY}'
 AND adult_person_id='10000000-0000-4000-8000-000000000003'
 AND relationship_kind='GUARDIAN'
 AND display_name='Guardian corrected by first approved intent'
 AND effective_from=CURRENT_DATE-1 AND effective_until IS NULL;
SELECT count(*) FROM app_private.family_relationships
 WHERE supersedes_id='{_REL_CORRECT_SOURCE}';
SELECT count(*) FROM app_private.family_relationships
 WHERE supersedes_id='{_REL_CORRECT_SOURCE}'
 AND display_name='Guardian corrected by second approved intent';
SELECT count(*) FROM app_private.family_relationships
 WHERE student_id='{_REL_END_STUDENT}';
SELECT count(*) FROM app_private.student_primary_family_contexts
 WHERE id='{_REL_CORRECT_CONTEXT}'
 AND family_relationship_id='{_REL_CORRECT_SOURCE}'
 AND effective_from=CURRENT_DATE-2 AND effective_until=CURRENT_DATE-1
 AND ended_at IS NOT NULL AND ended_by IS NOT NULL;
SELECT count(*) FROM app_private.student_primary_family_contexts
 WHERE supersedes_id='{_REL_CORRECT_CONTEXT}'
 AND family_relationship_id='{winning_id}'
 AND student_id='{_REL_END_STUDENT}'
 AND effective_from=CURRENT_DATE-1 AND effective_until IS NULL;
SELECT count(*) FROM app_private.student_primary_family_contexts
 WHERE student_id='{_REL_END_STUDENT}' AND effective_until IS NULL;
SELECT count(*) FROM app_private.student_primary_family_contexts
 WHERE student_id='{_REL_END_STUDENT}';
SELECT count(*) FROM app_private.family_student_access
 WHERE student_id='{_REL_END_STUDENT}';
SELECT count(*) FROM app_private.approval_requests
 WHERE state='EXECUTED' AND operation_id=(SELECT id
 FROM app_private.operation_contracts WHERE code='family.relationship.change');
SELECT count(*) FROM app_private.approval_requests
 WHERE state='INVALIDATED' AND operation_id=(SELECT id
 FROM app_private.operation_contracts WHERE code='family.relationship.change');
SELECT count(*) FROM app_private.approval_applications
 WHERE operation_id=(SELECT id FROM app_private.operation_contracts
 WHERE code='family.relationship.change');
SELECT count(*) FROM app_private.command_receipts
 WHERE operation_id=(SELECT id FROM app_private.operation_contracts
 WHERE code='family.relationship.change');
SELECT count(*) FROM app_private.outbox_events
 WHERE event_type='family.relationship_changed';
SELECT count(*) FROM app_private.approval_reviews v
 JOIN app_private.approval_request_steps s ON s.id=v.step_id
 JOIN app_private.approval_requests r ON r.id=s.request_id
 WHERE r.operation_id=(SELECT id FROM app_private.operation_contracts
 WHERE code='family.relationship.change');
""", "D1_RELATIONSHIP_CORRECT_RACE_EVIDENCE",tuples=True).split()
    if counts != ["1","1","1","0","3","1","1","1","2","0",
                  "2","2","2","12","2","4"]:
        raise RuntimeError("D1_RELATIONSHIP_CORRECT_RACE_EVIDENCE_MISMATCH "
                           + ",".join(counts))
    print("D1_FAMILY_RELATIONSHIP_CORRECT_RACE_PASS "
          "1 two-session Effect30 P1 competing CORRECT race; "
          "lock_wait_observed=true; one EXECUTED, one INVALIDATED; "
          "one retained relationship successor and primary-context successor")
