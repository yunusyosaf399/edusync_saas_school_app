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
