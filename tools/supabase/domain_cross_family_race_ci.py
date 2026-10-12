"""Two distinct authenticated staff actors contend over one Student in two Families.

Only the disposable D1 local stack is supported. This runs after the existing
thirteen observed-lock races, uses a fresh synthetic Student, and changes no
production migrations or external Auth fixtures.
"""
from __future__ import annotations

import re
import subprocess
import time
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
CONTAINER = "supabase_db_saas_OS_school_app"
STUDENT = "95000000-0000-4000-8000-000000000002"
FAMILY_A = "95000000-0000-4000-8000-000000000003"
FAMILY_B = "95000000-0000-4000-8000-000000000004"
REL_B = "95000000-0000-4000-8000-000000000006"
ACCESS_A = "95000000-0000-4000-8000-000000000007"
ACCESS_B = "95000000-0000-4000-8000-000000000008"
BINDING_A = "64000000-0000-4000-8000-000000000010"
BINDING_B = "95000000-0000-4000-8000-000000000011"
STAFF_A_BINDING = "66666666-6666-4666-8666-666666666666"
STAFF_B_BINDING = "76000000-0000-4000-8000-000000000005"
RESULT = re.compile(r"(?m)^(REVOKE|END)\t([0-9]+)\t([0-9]+)\t([0-9]+)$")


def _sql_actor(email: str, binding: str) -> str:
    if (email, binding) not in (
        ("foundation-rbac-001@example.invalid", STAFF_A_BINDING),
        ("foundation-test-001@example.invalid", STAFF_B_BINDING),
        ("foundation-family-001@example.invalid", BINDING_A),
        ("foundation-own-002@example.invalid", BINDING_B),
    ):
        raise RuntimeError("D1_CROSS_FAMILY_UNKNOWN_AUTH_ACTOR")
    return f"""
SELECT set_config('request.jwt.claim.sub',
 (SELECT id::text FROM auth.users WHERE email='{email}'),true);
SELECT set_config('request.jwt.claims',jsonb_build_object(
 'sub',current_setting('request.jwt.claim.sub'),'role','authenticated',
 'iat',(SELECT extract(epoch FROM tokens_valid_from)::bigint
 FROM app_private.principal_auth_bindings WHERE id='{binding}'),
 'is_anonymous',false)::text,true);
SET ROLE authenticated;
"""


def _worker_sql(kind: str, student_version: int, family_version: int,
                hold: bool = False, key: str | None = None) -> str:
    if kind not in ("a_revoke", "b_end") or not (
        isinstance(student_version, int) and isinstance(family_version, int)
        and student_version >= 1 and family_version >= 1
    ):
        raise RuntimeError("D1_CROSS_FAMILY_INVALID_WORKER_INTENT")
    if kind == "a_revoke":
        actor = _sql_actor("foundation-rbac-001@example.invalid", STAFF_A_BINDING)
        name = "d1-cross-family-a-revoke"
        key = key or "d1-cross-family-a-revoke"
        call = (f"app.d1_change_family_child_access("
                f"'{STUDENT}',{student_version},'{FAMILY_A}',{family_version},"
                f"'REVOKE','{ACCESS_A}',CURRENT_DATE,NULL,"
                f"'A access revoke during Family B relationship END','{key}')")
    else:
        actor = _sql_actor("foundation-test-001@example.invalid", STAFF_B_BINDING)
        name = "d1-cross-family-b-end"
        key = key or "d1-cross-family-b-end-stale"
        call = (f"app.d1_change_family_relationship("
                f"'{STUDENT}',{student_version},'{FAMILY_B}',{family_version},"
                f"'END','{REL_B}',NULL,NULL,NULL,NULL,CURRENT_DATE,"
                f"'B final relationship END during A entitlement revoke',NULL,'{key}')")
    return (
        "BEGIN;\n"
        f"SET LOCAL application_name='{name}';\n"
        + actor
        + "SELECT action||E'\\t'||student_version::text||E'\\t'"
          "||family_version::text||E'\\t'||"
          + ("0::text " if kind == "a_revoke" else "access_closed_count::text ")
          + f"FROM {call};\n"
        + ("SELECT pg_sleep(4);\n" if hold else "")
        + "COMMIT;\n"
    )


def _numbers(raw: str) -> list[str]:
    return re.findall(r"(?m)^([0-9]+)$", raw)


def _checked_read(container: str, execute_sql, principal: str) -> list[str]:
    if principal == "A":
        email, binding = "foundation-family-001@example.invalid", BINDING_A
    elif principal == "B":
        email, binding = "foundation-own-002@example.invalid", BINDING_B
    else:
        raise RuntimeError("D1_CROSS_FAMILY_UNKNOWN_PORTAL")
    body = ("BEGIN;\n" + _sql_actor(email, binding)
            + f"SELECT count(*) FROM app.d1_read_family_summary_for_student('{STUDENT}');\n"
            + f"SELECT count(*) FROM app.d1_read_family_relationships_for_student('{STUDENT}');\n"
            + f"SELECT count(*) FROM app.d1_read_family_relationship_history('{STUDENT}');\n"
            + "RESET ROLE;\nCOMMIT;\n")
    return _numbers(execute_sql(container, body, "D1_CROSS_FAMILY_READ_" + principal,
                                tuples=True, timeout=30))[-3:]


def _probe_worker(container: str, execute_sql, worker: subprocess.Popen,
                  app: str, blocked_by: str | None) -> None:
    if blocked_by:
        query = f"""
SELECT CASE WHEN EXISTS (
 SELECT 1 FROM pg_catalog.pg_stat_activity waiting
 WHERE waiting.application_name='{app}'
   AND waiting.wait_event_type='Lock'
   AND EXISTS (SELECT 1 FROM pg_catalog.pg_locks requested
               WHERE requested.pid=waiting.pid AND NOT requested.granted
                 AND requested.locktype IN ('transactionid','tuple'))
   AND EXISTS (
      SELECT 1 FROM pg_catalog.unnest(pg_catalog.pg_blocking_pids(waiting.pid)) AS p(pid)
      JOIN pg_catalog.pg_stat_activity holding ON holding.pid=p.pid
      WHERE holding.application_name='{blocked_by}'
   )
) THEN 1 ELSE 0 END;
"""
    else:
        query = f"""
SELECT CASE WHEN EXISTS (
 SELECT 1 FROM pg_catalog.pg_stat_activity a
 WHERE a.application_name='{app}' AND a.wait_event='PgSleep'
   AND EXISTS (SELECT 1 FROM pg_catalog.pg_locks l
               WHERE l.pid=a.pid AND l.granted
                 AND l.locktype='transactionid')
) THEN 1 ELSE 0 END;
"""
    deadline = time.monotonic() + 12
    while time.monotonic() < deadline:
        if worker.poll() is not None:
            raise RuntimeError("D1_CROSS_FAMILY_WORKER_FINISHED_BEFORE_LOCK")
        if execute_sql(container, query, "D1_CROSS_FAMILY_LOCK_OBSERVER",
                       tuples=True, timeout=10).strip() == "1":
            return
        time.sleep(0.05)
    raise RuntimeError("D1_CROSS_FAMILY_REAL_LOCK_WAIT_NOT_OBSERVED")


def run_cross_family_race(container: str, execute_sql) -> None:
    if container != CONTAINER:
        raise RuntimeError("D1_CROSS_FAMILY_LOCAL_CONTAINER_REQUIRED")
    fixture = (ROOT / "supabase/tests/domain/fixtures/"
               "family_cross_operation_race_setup.sql").read_text(encoding="utf-8")
    for required in (
        "foundation-own-002@example.invalid",
        "family.relationship.change",
        "family.child_access.change",
        "d1-cross-family-race-direct-relationship",
        "d1-cross-family-race-direct-child",
    ):
        if required not in fixture:
            raise RuntimeError("D1_CROSS_FAMILY_FIXTURE_INVALID")
    execute_sql(container, "BEGIN;\n" + fixture + "\nCOMMIT;",
                "D1_CROSS_FAMILY_FIXTURE")
    evidence = _numbers(execute_sql(container, f"""
SELECT row_version FROM app_private.students WHERE id='{STUDENT}';
SELECT row_version FROM app_private.families WHERE id='{FAMILY_A}';
SELECT row_version FROM app_private.families WHERE id='{FAMILY_B}';
SELECT count(*) FROM app_private.family_relationships
 WHERE student_id='{STUDENT}' AND effective_until IS NULL;
SELECT count(*) FROM app_private.family_student_access
 WHERE student_id='{STUDENT}' AND effective_until IS NULL;
SELECT count(*) FROM app_private.principal_auth_bindings
 WHERE principal_id IN ('64000000-0000-4000-8000-000000000005',
                        '95000000-0000-4000-8000-000000000010');
SELECT count(DISTINCT auth_user_id) FROM app_private.principal_auth_bindings
 WHERE principal_id IN ('64000000-0000-4000-8000-000000000005',
                        '95000000-0000-4000-8000-000000000010');
""", "D1_CROSS_FAMILY_BASELINE", tuples=True))
    if len(evidence) != 7 or evidence[3:] != ["2", "2", "2", "2"]:
        raise RuntimeError("D1_CROSS_FAMILY_BASELINE_INVALID " + ",".join(evidence))
    student_v, family_a_v, family_b_v = (int(x) for x in evidence[:3])
    if (_checked_read(container, execute_sql, "A") != ["1", "1", "1"]
            or _checked_read(container, execute_sql, "B") != ["1", "1", "1"]):
        raise RuntimeError("D1_CROSS_FAMILY_BOTH_PORTALS_NOT_LIVE")

    event_before = _numbers(execute_sql(container, """
SELECT count(*) FROM app_private.outbox_events
 WHERE event_type='family.child_access_changed';
SELECT count(*) FROM app_private.outbox_events
 WHERE event_type='family.relationship_changed';
""", "D1_CROSS_FAMILY_EVENT_BASE", tuples=True))
    if len(event_before) != 2:
        raise RuntimeError("D1_CROSS_FAMILY_EVENT_BASELINE_INVALID")
    args = ["docker", "exec", "-i", CONTAINER, "psql", "-X", "-q", "-A", "-t",
            "-v", "ON_ERROR_STOP=1", "-U", "postgres", "-d", "postgres"]
    workers: list[subprocess.Popen] = []
    try:
        first = subprocess.Popen(args, cwd=ROOT, stdin=subprocess.PIPE,
                                 stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
        workers.append(first)
        first.stdin.write(_worker_sql("a_revoke", student_v, family_a_v, True))
        first.stdin.close()
        first.stdin = None
        _probe_worker(container, execute_sql, first, "d1-cross-family-a-revoke", None)
        second = subprocess.Popen(args, cwd=ROOT, stdin=subprocess.PIPE,
                                  stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
        workers.append(second)
        second.stdin.write(_worker_sql("b_end", student_v, family_b_v))
        second.stdin.close()
        second.stdin = None
        _probe_worker(container, execute_sql, second, "d1-cross-family-b-end",
                      "d1-cross-family-a-revoke")
        first_out, first_err = first.communicate(timeout=25)
        second_out, second_err = second.communicate(timeout=25)
        if first.returncode != 0:
            raise RuntimeError("D1_CROSS_FAMILY_REVOKE_FAILED "
                               + re.sub(r"[^a-zA-Z0-9 _.:]", "", first_err[-300:]))
        won = RESULT.findall(first_out)
        if len(won) != 1 or won[0][0] != "REVOKE" or int(won[0][1]) != student_v + 1:
            raise RuntimeError("D1_CROSS_FAMILY_REVOKE_RESULT_INVALID")
        if second.returncode == 0 or (
            "D1 Family relationship target version changed" not in second_err
        ):
            raise RuntimeError("D1_CROSS_FAMILY_STALE_B_END_NOT_REJECTED")
    finally:
        for worker in workers:
            if worker.poll() is None:
                worker.kill()
                worker.communicate(timeout=10)

    state = _numbers(execute_sql(container, f"""
SELECT count(*) FROM app_private.family_student_access
 WHERE id='{ACCESS_A}' AND family_id='{FAMILY_A}'
 AND effective_until=CURRENT_DATE AND ended_at IS NOT NULL;
SELECT count(*) FROM app_private.family_student_access
 WHERE id='{ACCESS_B}' AND family_id='{FAMILY_B}' AND effective_until IS NULL;
SELECT count(*) FROM app_private.family_relationships
 WHERE id='{REL_B}' AND family_id='{FAMILY_B}' AND effective_until IS NULL;
SELECT count(*) FROM app_private.command_receipts
 WHERE idempotency_key='d1-cross-family-a-revoke' AND state='SUCCEEDED';
SELECT count(*) FROM app_private.command_receipts
 WHERE idempotency_key='d1-cross-family-b-end-stale';
""", "D1_CROSS_FAMILY_AFTER_CONTENTION", tuples=True))
    if state != ["1", "1", "1", "1", "0"]:
        raise RuntimeError("D1_CROSS_FAMILY_WRONG_RACE_EFFECTS " + ",".join(state))
    if (_checked_read(container, execute_sql, "A") != ["0", "0", "0"]
            or _checked_read(container, execute_sql, "B") != ["1", "1", "1"]):
        raise RuntimeError("D1_CROSS_FAMILY_PORTAL_ISOLATION_AFTER_CONTENTION")

    # B's aborted intent can be retried with a refreshed shared Student
    # version; it is not silently replayed or applied from a failed attempt.
    version = _numbers(execute_sql(container, f"""
SELECT row_version FROM app_private.students WHERE id='{STUDENT}';
SELECT row_version FROM app_private.families WHERE id='{FAMILY_B}';
""", "D1_CROSS_FAMILY_RETRY_VERSIONS", tuples=True))
    if len(version) != 2 or int(version[0]) != student_v + 1:
        raise RuntimeError("D1_CROSS_FAMILY_STALE_VERSION_NOT_ADVANCED")
    retry = subprocess.run(args, cwd=ROOT, input=_worker_sql(
        "b_end", int(version[0]), int(version[1]), key="d1-cross-family-b-end-refreshed"),
        capture_output=True, text=True, timeout=30)
    rows = RESULT.findall(retry.stdout)
    if retry.returncode != 0 or len(rows) != 1 or rows[0][0] != "END" or rows[0][3] != "1":
        raise RuntimeError("D1_CROSS_FAMILY_REFRESHED_B_END_FAILED "
                           + re.sub(r"[^a-zA-Z0-9 _.:]", "", retry.stderr[-300:]))
    if (_checked_read(container, execute_sql, "A") != ["0", "0", "0"]
            or _checked_read(container, execute_sql, "B") != ["0", "0", "0"]):
        raise RuntimeError("D1_CROSS_FAMILY_B_FINAL_ACCESS_NOT_CLOSED")

    final = _numbers(execute_sql(container, f"""
SELECT count(*) FROM app_private.family_student_access
 WHERE id IN ('{ACCESS_A}','{ACCESS_B}') AND effective_until=CURRENT_DATE
 AND ended_at IS NOT NULL;
SELECT count(*) FROM app_private.family_relationships
 WHERE id='{REL_B}' AND effective_until=CURRENT_DATE AND ended_at IS NOT NULL;
SELECT count(*) FROM app_private.family_relationships
 WHERE family_id='{FAMILY_A}' AND student_id='{STUDENT}'
 AND effective_until IS NULL;
SELECT count(*) FROM app_private.family_relationships
 WHERE student_id='{STUDENT}';
SELECT count(*) FROM app_private.family_student_access
 WHERE student_id='{STUDENT}';
SELECT count(*) FROM app_private.command_receipts
 WHERE idempotency_key IN ('d1-cross-family-a-revoke',
 'd1-cross-family-b-end-refreshed') AND state='SUCCEEDED';
SELECT count(*) FROM app_private.command_receipts
 WHERE idempotency_key='d1-cross-family-b-end-stale';
SELECT count(*) FROM app_private.outbox_events
 WHERE event_type='family.child_access_changed';
SELECT count(*) FROM app_private.outbox_events
 WHERE event_type='family.relationship_changed';
""", "D1_CROSS_FAMILY_FINAL_EVIDENCE", tuples=True))
    expected = ["2", "1", "1", "2", "2", "2", "0",
                str(int(event_before[0]) + 1), str(int(event_before[1]) + 1)]
    if final != expected:
        raise RuntimeError("D1_CROSS_FAMILY_HISTORY_OR_DUPLICATE_MISMATCH "
                           + ",".join(final))
    print("D1_CROSS_FAMILY_OPERATION_RACE_PASS "
          "two independently authenticated staff actors; exact PostgreSQL blocker "
          "observed; A entitlement REVOKE EXECUTED, stale B relationship END "
          "denied without receipt/effect; B retained its portal access until "
          "fresh-version END closed only its own dependent entitlement; "
          "two original relationships and two closed entitlements retained")
