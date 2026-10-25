"""Disposable, genuinely concurrent DB-02 INIT/REPLACE School-lock acceptance."""
from __future__ import annotations

import re
import subprocess
import time

from domain_concurrency_ci import ROOT, CONTAINER, worker_args

ACTORS = {
    "a": ("foundation-rbac-001@example.invalid",
          "66666666-6666-4666-8666-666666666666"),
    "b": ("foundation-test-001@example.invalid",
          "b4400000-0000-4000-8000-000000000002"),
}
SCHOOLS = {
    ("INIT", "commit"): "b4410000-0000-4000-8000-000000000001",
    ("INIT", "rollback"): "b4420000-0000-4000-8000-000000000001",
    ("REPLACE", "commit"): "b4430000-0000-4000-8000-000000000001",
    ("REPLACE", "rollback"): "b4440000-0000-4000-8000-000000000001",
}
UUID = re.compile(r"(?m)^([0-9a-f]{8}(?:-[0-9a-f]{4}){3}-[0-9a-f]{12})$")


def _worker_sql(action: str, outcome: str, actor: str, source_from: str | None,
                *, holder: bool) -> str:
    if ((action, outcome) not in SCHOOLS or actor not in ACTORS
            or (action == "REPLACE" and (source_from is None or
                re.fullmatch(r"\d{4}-\d{2}-\d{2}", source_from) is None))
            or (action == "INIT" and source_from is not None)):
        raise RuntimeError("DB02_T04_UNEXPECTED_INTENT")
    school = SCHOOLS[action, outcome]
    email, binding = ACTORS[actor]
    name = f"db02-t04-{action.lower()}-{outcome}-{actor}"
    key = f"db02-t04-{action.lower()}-{outcome}-{actor}"
    source = school[:-1] + "2" if action == "REPLACE" else None
    typed = (f"'{source}'::uuid,1,'PERSISTENT_STUDENT',5000,"
             f"'{source_from}'::date") if source else (
                 "NULL::uuid,NULL::integer,NULL::text,NULL::bigint,NULL::date")
    return f"""BEGIN;
SET LOCAL application_name='{name}';
SELECT set_config('request.jwt.claim.sub',
 (SELECT id::text FROM auth.users WHERE email='{email}'),true);
SELECT set_config('request.jwt.claims',pg_catalog.jsonb_build_object(
 'sub',current_setting('request.jwt.claim.sub'),'role','authenticated',
 'iat',(SELECT extract(epoch FROM tokens_valid_from)::bigint
 FROM app_private.principal_auth_bindings WHERE id='{binding}'),
 'is_anonymous',false)::text,true);
SET ROLE authenticated;
SELECT app.d1_change_student_roll_policy(
 '{school}','{action}',{typed},'PERSISTENT_STUDENT',
 {6100 if actor == 'a' else 6200},'T04 genuine {action} {outcome} {actor}',
 '{key}')::text;
RESET ROLE;
{"SELECT pg_catalog.pg_sleep(5);" if holder else ""}
{"COMMIT" if not holder or outcome == "commit" else "ROLLBACK"};
"""


def _start(sql: str) -> subprocess.Popen:
    process = subprocess.Popen(worker_args(CONTAINER), cwd=ROOT,
                               stdin=subprocess.PIPE, stdout=subprocess.PIPE,
                               stderr=subprocess.PIPE, text=True)
    process.stdin.write(sql)
    process.stdin.close()
    process.stdin = None
    return process


def _observe(container: str, execute_sql, process: subprocess.Popen,
             action: str, outcome: str, *, waiting: bool) -> None:
    holder = f"db02-t04-{action.lower()}-{outcome}-a"
    waiter = f"db02-t04-{action.lower()}-{outcome}-b"
    if waiting:
        # Distinct actors have distinct Principal row locks and receipt keys.
        # The waiting transactionid is blocked by the holder's School row
        # FOR UPDATE, not merely a system-wide non-granted lock elsewhere.
        probe = f"""
SELECT CASE WHEN EXISTS (
 SELECT 1 FROM pg_catalog.pg_stat_activity w
 JOIN pg_catalog.pg_locks pending ON pending.pid=w.pid
 WHERE w.application_name='{waiter}' AND w.wait_event_type='Lock'
   AND pending.locktype IN ('transactionid','tuple') AND NOT pending.granted
   AND EXISTS (
     SELECT 1 FROM pg_catalog.unnest(pg_catalog.pg_blocking_pids(w.pid)) AS b(pid)
     JOIN pg_catalog.pg_stat_activity h ON h.pid=b.pid
     JOIN pg_catalog.pg_locks held ON held.pid=h.pid
     JOIN pg_catalog.pg_class c ON c.oid=held.relation
     JOIN pg_catalog.pg_namespace n ON n.oid=c.relnamespace
     WHERE h.application_name='{holder}' AND h.wait_event='PgSleep'
       AND held.granted AND n.nspname='app_private'
       AND c.relname='school_profiles')
) THEN 1 ELSE 0 END;
"""
    else:
        probe = f"""
SELECT CASE WHEN EXISTS (
 SELECT 1 FROM pg_catalog.pg_stat_activity h
 JOIN pg_catalog.pg_locks held ON held.pid=h.pid
 JOIN pg_catalog.pg_class c ON c.oid=held.relation
 JOIN pg_catalog.pg_namespace n ON n.oid=c.relnamespace
 WHERE h.application_name='{holder}' AND h.wait_event='PgSleep'
   AND held.granted AND n.nspname='app_private'
   AND c.relname='school_profiles') THEN 1 ELSE 0 END;
"""
    deadline = time.monotonic() + 12
    while time.monotonic() < deadline:
        if process.poll() is not None:
            raise RuntimeError("DB02_T04_WORKER_EXITED_BEFORE_OBSERVED_BLOCK")
        if execute_sql(container, probe, "DB02_T04_LOCK_PROBE",
                       tuples=True, timeout=10).strip() == "1":
            return
        time.sleep(0.05)
    raise RuntimeError("DB02_T04_EXACT_SCHOOL_BLOCK_NOT_OBSERVED")


def _snapshot(container: str, execute_sql, action: str, outcome: str,
              winner: str, loser: str) -> list[str]:
    school = SCHOOLS[action, outcome]
    source = school[:-1] + "2" if action == "REPLACE" else "00000000-0000-0000-0000-000000000000"
    query = f"""
SELECT count(*) FROM app_private.roll_policy_revisions WHERE school_id='{school}';
SELECT count(*) FROM app_private.roll_policy_revisions WHERE id='{winner}'
 AND school_id='{school}' AND revision={2 if action == 'REPLACE' else 1}
 AND supersedes_id IS NOT DISTINCT FROM {"'"+source+"'::uuid" if action == 'REPLACE' else 'NULL::uuid'};
SELECT count(*) FROM app_private.roll_policy_revisions WHERE id='{loser}';
SELECT count(*) FROM app_private.roll_allocator_states WHERE policy_revision_id='{winner}';
SELECT count(*) FROM app_private.command_receipts
 WHERE operation_id=(SELECT id FROM app_private.operation_contracts
 WHERE code='student.roll_policy.change')
 AND idempotency_key LIKE 'db02-t04-{action.lower()}-{outcome}-%'
 AND state='SUCCEEDED' AND result_ref='{winner}';
SELECT count(*) FROM app_private.audit_events a
 JOIN app_private.command_receipts r ON r.id=a.command_receipt_id
 WHERE r.result_ref='{winner}';
SELECT count(*) FROM app_private.outbox_events e
 JOIN app_private.command_receipts r ON r.id=e.command_receipt_id
 WHERE r.result_ref='{winner}' AND e.event_type='student.roll_policy_changed';
SELECT count(*) FROM app_private.command_receipts
 WHERE idempotency_key='db02-t04-{action.lower()}-{outcome}-{'b' if outcome == 'commit' else 'a'}';
SELECT count(*) FROM app_private.roll_policy_revisions WHERE id='{source}'
 AND effective_until IS {"NOT NULL" if action == 'REPLACE' else 'NULL'};
"""
    return execute_sql(container, query, "DB02_T04_POST_RACE",
                       tuples=True, timeout=30).split()


def run_db02_policy_races(container: str, execute_sql) -> None:
    if container != CONTAINER:
        raise RuntimeError("DB02_T04_DISPOSABLE_CONTAINER_REQUIRED")
    fixture = (ROOT / "supabase/tests/domain/fixtures/"
               "db02_t04_two_backend_race_setup.sql").read_text(encoding="utf-8")
    execute_sql(container, "BEGIN;\n" + fixture + "\nCOMMIT;",
                "DB02_T04_SETUP", timeout=60)
    for action in ("INIT", "REPLACE"):
        for outcome in ("commit", "rollback"):
            source_from = None
            if action == "REPLACE":
                school = SCHOOLS[action, outcome]
                source_from = execute_sql(container, f"""
SELECT effective_from::text FROM app_private.roll_policy_revisions
 WHERE id='{school[:-1]}2' AND school_id='{school}';
""", "DB02_T04_FROZEN_SOURCE_DATE", tuples=True).strip()
                if re.fullmatch(r"\d{4}-\d{2}-\d{2}", source_from) is None:
                    raise RuntimeError("DB02_T04_SOURCE_DATE_INVALID")
            workers = []
            try:
                first = _start(_worker_sql(action, outcome, "a", source_from,
                                           holder=True))
                workers.append(first)
                _observe(container, execute_sql, first, action, outcome, waiting=False)
                second = _start(_worker_sql(action, outcome, "b", source_from,
                                            holder=False))
                workers.append(second)
                _observe(container, execute_sql, second, action, outcome, waiting=True)
                first_out, first_err = first.communicate(timeout=20)
                second_out, second_err = second.communicate(timeout=20)
                ids = UUID.findall(first_out)
                second_ids = UUID.findall(second_out)
                if first.returncode or len(ids) != 1:
                    raise RuntimeError("DB02_T04_HOLDER_FAILED " + first_err[-400:])
                if outcome == "commit":
                    if second.returncode == 0 or "D1 Roll Policy transition preflight invalid" not in second_err:
                        raise RuntimeError("DB02_T04_COMMITTED_LOSER_NOT_DENIED " + second_err[-400:])
                    winner, loser = ids[0], "00000000-0000-0000-0000-000000000000"
                else:
                    if second.returncode or len(second_ids) != 1 or second_ids[0] == ids[0]:
                        raise RuntimeError("DB02_T04_ROLLBACK_WINNER_INVALID " + second_err[-400:])
                    winner, loser = second_ids[0], ids[0]
                actual = _snapshot(container, execute_sql, action, outcome, winner, loser)
                expected = ["2" if action == "REPLACE" else "1", "1", "0",
                            "1", "1", "1", "1", "0",
                            "1" if action == "REPLACE" else "0"]
                if actual != expected:
                    raise RuntimeError("DB02_T04_EFFECT_MISMATCH " +
                                       action + "_" + outcome + " " + ",".join(actual))
                print("DB02_T04_RACE_PASS " + action + "_" + outcome +
                      " school_wait_observed=true winner_effect_once=true")
            finally:
                for worker in workers:
                    if worker.poll() is None:
                        worker.kill()
                        worker.communicate(timeout=10)
    print("DB02_T04_PASS 4 two-backend School races; 4 exact blocking waits; "
          "winner/loser and rollback effects verified")
