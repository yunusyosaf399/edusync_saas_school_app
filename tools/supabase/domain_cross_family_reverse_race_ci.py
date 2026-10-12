"""Observed-lock reverse cross-Family race: B final relationship END wins A REVOKE.

Runs only on the same disposable local PostgreSQL stack as the accepted
forward race. Each concurrently executing command uses a DISTINCT real
authenticated INDIVIDUAL staff principal. Does not modify production SQL.
"""
from __future__ import annotations

import re
import subprocess
import time

from domain_cross_family_race_ci import (
    ROOT, CONTAINER, FAMILY_A, FAMILY_B, STAFF_A_BINDING, STAFF_B_BINDING,
    BINDING_A, BINDING_B, _sql_actor, _numbers,
)

STUDENT = "96000000-0000-4000-8000-000000000002"
REL_A = "96000000-0000-4000-8000-000000000003"
REL_B = "96000000-0000-4000-8000-000000000004"
ACCESS_A = "96000000-0000-4000-8000-000000000005"
ACCESS_B = "96000000-0000-4000-8000-000000000006"
B_APP = "d1-cross-reverse-b-end"
A_APP = "d1-cross-reverse-a-revoke"
RESULT = re.compile(r"(?m)^(END|REVOKE)\t([0-9]+)\t([0-9]+)\t([0-9]+)$")
ARGS = ["docker", "exec", "-i", CONTAINER, "psql", "-X", "-q", "-A", "-t",
        "-v", "ON_ERROR_STOP=1", "-U", "postgres", "-d", "postgres"]


def _worker(kind: str, student_version: int, family_version: int,
            *, hold: bool = False, refreshed: bool = False) -> str:
    if kind not in ("b_end", "a_revoke") or (student_version < 1 or family_version < 1):
        raise RuntimeError("D1_CROSS_REVERSE_INVALID_WORKER_INTENT")
    if kind == "b_end":
        if refreshed:
            raise RuntimeError("D1_CROSS_REVERSE_B_REFRESH_NOT_SUPPORTED")
        actor = _sql_actor("foundation-test-001@example.invalid", STAFF_B_BINDING)
        app = B_APP
        call = (f"app.d1_change_family_relationship("
                f"'{STUDENT}',{student_version},'{FAMILY_B}',{family_version},"
                f"'END','{REL_B}',NULL,NULL,NULL,NULL,CURRENT_DATE,"
                f"'B last relationship END wins before Family A REVOKE',NULL,"
                f"'d1-cross-reverse-b-end-winner')")
        last = "access_closed_count::text"
    else:
        actor = _sql_actor("foundation-rbac-001@example.invalid", STAFF_A_BINDING)
        app = A_APP
        key = ("d1-cross-reverse-a-revoke-refreshed" if refreshed
               else "d1-cross-reverse-a-revoke-stale")
        call = (f"app.d1_change_family_child_access("
                f"'{STUDENT}',{student_version},'{FAMILY_A}',{family_version},"
                f"'REVOKE','{ACCESS_A}',CURRENT_DATE,NULL,"
                f"'A entitlement REVOKE after Family B final END','{key}')")
        last = "0::text"
    return (
        "BEGIN;\n" + f"SET LOCAL application_name='{app}';\n"
        + actor
        + f"SELECT action||E'\\t'||student_version::text||E'\\t'"
          f"||family_version::text||E'\\t'||{last} FROM {call};\n"
        + ("SELECT pg_sleep(4);\n" if hold else "")
        + "COMMIT;\n"
    )


def _wait_for_lock(container: str, execute_sql, process: subprocess.Popen,
                   app: str, blocked_by: str | None) -> None:
    if blocked_by:
        statement = f"""
SELECT CASE WHEN EXISTS (
 SELECT 1 FROM pg_catalog.pg_stat_activity waiting
 WHERE waiting.application_name='{app}' AND waiting.wait_event_type='Lock'
 AND EXISTS (SELECT 1 FROM pg_catalog.pg_locks pending
             WHERE pending.pid=waiting.pid AND NOT pending.granted
             AND pending.locktype IN ('transactionid','tuple'))
 AND EXISTS (
   SELECT 1 FROM pg_catalog.unnest(pg_catalog.pg_blocking_pids(waiting.pid)) AS blocker(pid)
   JOIN pg_catalog.pg_stat_activity holder ON holder.pid=blocker.pid
   WHERE holder.application_name='{blocked_by}'
 )
) THEN 1 ELSE 0 END;
"""
    else:
        statement = f"""
SELECT CASE WHEN EXISTS (
 SELECT 1 FROM pg_catalog.pg_stat_activity holding
 WHERE holding.application_name='{app}' AND holding.wait_event='PgSleep'
 AND EXISTS (SELECT 1 FROM pg_catalog.pg_locks held
             WHERE held.pid=holding.pid AND held.granted
             AND held.locktype='transactionid')
) THEN 1 ELSE 0 END;
"""
    deadline = time.monotonic() + 12
    while time.monotonic() < deadline:
        if process.poll() is not None:
            raise RuntimeError("D1_CROSS_REVERSE_WORKER_FINISHED_BEFORE_LOCK")
        if execute_sql(container, statement, "D1_CROSS_REVERSE_LOCK_OBSERVER",
                       tuples=True, timeout=10).strip() == "1":
            return
        time.sleep(0.05)
    raise RuntimeError("D1_CROSS_REVERSE_LOCK_WAIT_NOT_OBSERVED")


def _family_read(container: str, execute_sql, who: str) -> list[str]:
    if who == "A":
        email, binding, family, label = (
            "foundation-family-001@example.invalid", BINDING_A,
            FAMILY_A, "Cross Family race A")
    elif who == "B":
        email, binding, family, label = (
            "foundation-own-002@example.invalid", BINDING_B,
            FAMILY_B, "Cross Family race B")
    else:
        raise RuntimeError("D1_CROSS_REVERSE_UNKNOWN_FAMILY_ACTOR")
    sql = ("BEGIN;\n" + _sql_actor(email, binding)
           + f"SELECT count(*) FROM app.d1_read_family_summary_for_student('{STUDENT}');\n"
           + f"SELECT count(*) FROM app.d1_read_family_relationships_for_student('{STUDENT}');\n"
           + f"SELECT count(*) FROM app.d1_read_family_relationship_history('{STUDENT}');\n"
           + f"SELECT count(*) FROM app.d1_read_family_summary_for_student('{STUDENT}')"
             f" WHERE family_id='{family}';\n"
           + f"SELECT count(*) FROM app.d1_read_family_relationships_for_student('{STUDENT}')"
             f" WHERE family_label<>'{label}';\n"
           + f"SELECT count(*) FROM app.d1_read_family_relationship_history('{STUDENT}')"
             f" WHERE family_label<>'{label}';\n"
           + "RESET ROLE;\nCOMMIT;\n")
    observed = _numbers(execute_sql(container, sql, "D1_CROSS_REVERSE_PORTAL_" + who,
                                    tuples=True, timeout=30))
    if len(observed) != 6:
        raise RuntimeError("D1_CROSS_REVERSE_PORTAL_RESULT_SHAPE")
    return observed


def _state(container: str, execute_sql, label: str) -> list[str]:
    sql = f"""
SELECT row_version FROM app_private.students WHERE id='{STUDENT}';
SELECT row_version FROM app_private.families WHERE id='{FAMILY_A}';
SELECT row_version FROM app_private.families WHERE id='{FAMILY_B}';
SELECT count(*) FROM app_private.family_relationships
 WHERE student_id='{STUDENT}';
SELECT count(*) FROM app_private.family_student_access
 WHERE student_id='{STUDENT}';
SELECT count(*) FROM app_private.family_relationships
 WHERE id='{REL_A}' AND effective_until IS NULL;
SELECT count(*) FROM app_private.family_relationships
 WHERE id='{REL_B}' AND effective_until IS NULL;
SELECT count(*) FROM app_private.family_student_access
 WHERE id='{ACCESS_A}' AND effective_until IS NULL;
SELECT count(*) FROM app_private.family_student_access
 WHERE id='{ACCESS_B}' AND effective_until IS NULL;
"""
    out = _numbers(execute_sql(container, sql, label, tuples=True, timeout=30))
    if len(out) != 9:
        raise RuntimeError("D1_CROSS_REVERSE_STATE_RESULT_SHAPE")
    return out


def run_cross_family_reverse_race(container: str, execute_sql) -> None:
    if container != CONTAINER:
        raise RuntimeError("D1_CROSS_REVERSE_LOCAL_STACK_ONLY")
    fixture = (ROOT / "supabase/tests/domain/fixtures/"
               "family_cross_operation_reverse_race_setup.sql").read_text("utf-8")
    for needle in (STUDENT, REL_B, ACCESS_A, ACCESS_B, "schoolos_schema_owner"):
        if needle not in fixture:
            raise RuntimeError("D1_CROSS_REVERSE_FIXTURE_INVALID")
    execute_sql(container, "BEGIN;\n" + fixture + "\nCOMMIT;",
                "D1_CROSS_REVERSE_FIXTURE")
    before = _state(container, execute_sql, "D1_CROSS_REVERSE_BEFORE")
    if before[3:] != ["2", "2", "1", "1", "1", "1"]:
        raise RuntimeError("D1_CROSS_REVERSE_BAD_INITIAL_HISTORY " + ",".join(before))
    if (_family_read(container, execute_sql, "A") != ["1", "1", "1", "1", "0", "0"]
            or _family_read(container, execute_sql, "B") != ["1", "1", "1", "1", "0", "0"]):
        raise RuntimeError("D1_CROSS_REVERSE_INITIAL_FAMILY_AUTH_INVALID")
    student_v, family_a_v, family_b_v = (int(x) for x in before[:3])
    events_before = _numbers(execute_sql(container, """
SELECT count(*) FROM app_private.outbox_events
 WHERE event_type='family.child_access_changed';
SELECT count(*) FROM app_private.outbox_events
 WHERE event_type='family.relationship_changed';
""", "D1_CROSS_REVERSE_EVENT_BASE", tuples=True))
    if len(events_before) != 2:
        raise RuntimeError("D1_CROSS_REVERSE_EVENT_COUNT_SHAPE")

    workers: list[subprocess.Popen] = []
    try:
        first = subprocess.Popen(ARGS, cwd=ROOT, stdin=subprocess.PIPE,
                                 stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
        workers.append(first)
        first.stdin.write(_worker("b_end", student_v, family_b_v, hold=True))
        first.stdin.close()
        first.stdin = None
        _wait_for_lock(container, execute_sql, first, B_APP, None)
        second = subprocess.Popen(ARGS, cwd=ROOT, stdin=subprocess.PIPE,
                                  stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
        workers.append(second)
        second.stdin.write(_worker("a_revoke", student_v, family_a_v))
        second.stdin.close()
        second.stdin = None
        _wait_for_lock(container, execute_sql, second, A_APP, B_APP)
        first_out, first_err = first.communicate(timeout=25)
        second_out, second_err = second.communicate(timeout=25)
        won = RESULT.findall(first_out)
        if first.returncode != 0 or len(won) != 1 or won[0][0] != "END" or (
            won[0][3] != "1" or int(won[0][1]) != student_v + 1
        ):
            raise RuntimeError("D1_CROSS_REVERSE_B_END_WINNER_INVALID "
                               + re.sub(r"[^A-Za-z0-9_ .:-]", "", first_err[-350:]))
        if (second.returncode == 0 or
                "D1 Family child access target version changed" not in second_err):
            raise RuntimeError("D1_CROSS_REVERSE_STALE_A_REVOKE_NOT_REJECTED")
    finally:
        for worker in workers:
            if worker.poll() is None:
                worker.kill()
                worker.communicate(timeout=10)

    after = _state(container, execute_sql, "D1_CROSS_REVERSE_AFTER_CONTENTION")
    if (int(after[0]) != student_v + 1
            or int(after[1]) != family_a_v
            or after[3:] != ["2", "2", "1", "0", "1", "0"]):
        raise RuntimeError("D1_CROSS_REVERSE_PARTIAL_OR_CROSS_FAMILY_EFFECT "
                           + ",".join(after))
    receipts = _numbers(execute_sql(container, """
SELECT count(*) FROM app_private.command_receipts
 WHERE idempotency_key='d1-cross-reverse-b-end-winner' AND state='SUCCEEDED';
SELECT count(*) FROM app_private.command_receipts
 WHERE idempotency_key='d1-cross-reverse-a-revoke-stale';
""", "D1_CROSS_REVERSE_NO_STALE_RECEIPT", tuples=True))
    if receipts != ["1", "0"]:
        raise RuntimeError("D1_CROSS_REVERSE_UNEXPECTED_STALE_RECEIPT")
    if (_family_read(container, execute_sql, "A") != ["1", "1", "1", "1", "0", "0"]
            or _family_read(container, execute_sql, "B") != ["0", "0", "0", "0", "0", "0"]):
        raise RuntimeError("D1_CROSS_REVERSE_A_AUTH_MUST_SURVIVE_B_END")

    # A receives no stale retry privilege. The caller must reload both
    # exact aggregate versions and submit a new explicit idempotency key.
    new_a_v = _numbers(execute_sql(container, f"""
SELECT row_version FROM app_private.students WHERE id='{STUDENT}';
SELECT row_version FROM app_private.families WHERE id='{FAMILY_A}';
""", "D1_CROSS_REVERSE_REFRESH", tuples=True))
    if (len(new_a_v) != 2 or int(new_a_v[0]) != student_v + 1
            or int(new_a_v[1]) != family_a_v):
        raise RuntimeError("D1_CROSS_REVERSE_NEW_A_VERSIONS_INVALID")
    retry = subprocess.run(
        ARGS, cwd=ROOT, input=_worker("a_revoke", int(new_a_v[0]), int(new_a_v[1]),
                                     refreshed=True),
        capture_output=True, text=True, timeout=30)
    retried = RESULT.findall(retry.stdout)
    if retry.returncode != 0 or len(retried) != 1 or retried[0][0] != "REVOKE" or (
        int(retried[0][1]) != student_v + 2
    ):
        raise RuntimeError("D1_CROSS_REVERSE_REFRESHED_A_REVOKE_FAILED "
                           + re.sub(r"[^A-Za-z0-9_ .:-]", "", retry.stderr[-350:]))
    if (_family_read(container, execute_sql, "A") != ["0", "0", "0", "0", "0", "0"]
            or _family_read(container, execute_sql, "B") != ["0", "0", "0", "0", "0", "0"]):
        raise RuntimeError("D1_CROSS_REVERSE_FINAL_FAMILY_ACCESS_INVALID")

    final = _state(container, execute_sql, "D1_CROSS_REVERSE_FINAL_STATE")
    if (int(final[0]) != student_v + 2 or final[3:] != ["2", "2", "1", "0", "0", "0"]):
        raise RuntimeError("D1_CROSS_REVERSE_HISTORY_CHANGED_OR_DUPLICATED "
                           + ",".join(final))
    effects = _numbers(execute_sql(container, f"""
SELECT count(*) FROM app_private.family_student_access
 WHERE id IN ('{ACCESS_A}','{ACCESS_B}') AND effective_until=CURRENT_DATE
 AND ended_at IS NOT NULL;
SELECT count(*) FROM app_private.family_relationships
 WHERE id='{REL_B}' AND effective_until=CURRENT_DATE AND ended_at IS NOT NULL;
SELECT count(*) FROM app_private.command_receipts
 WHERE idempotency_key IN ('d1-cross-reverse-b-end-winner',
 'd1-cross-reverse-a-revoke-refreshed') AND state='SUCCEEDED';
SELECT count(*) FROM app_private.command_receipts
 WHERE idempotency_key='d1-cross-reverse-a-revoke-stale';
SELECT count(*) FROM app_private.outbox_events
 WHERE event_type='family.child_access_changed';
SELECT count(*) FROM app_private.outbox_events
 WHERE event_type='family.relationship_changed';
""", "D1_CROSS_REVERSE_EXACT_EVIDENCE", tuples=True))
    expected = ["2", "1", "2", "0", str(int(events_before[0]) + 1),
                str(int(events_before[1]) + 1)]
    if effects != expected:
        raise RuntimeError("D1_CROSS_REVERSE_EVENT_OR_RECEIPT_MISMATCH "
                           + ",".join(effects))
    print("D1_CROSS_FAMILY_REVERSE_RACE_PASS B relationship END EXECUTED first "
          "after exact true two-session PostgreSQL blocking lock observation; "
          "A stale child REVOKE denied without receipt or partial Family A effect; "
          "Family A current summary/relationship/history stayed authorized while "
          "B lost access, fresh-version A REVOKE then closed only A; "
          "two retained relationships and two closed child entitlement intervals, "
          "one new relationship event and one explicit child access event")
