"""Five real-backend publication/edit/authority races, disposable loopback only."""
from __future__ import annotations

from concurrent.futures import ThreadPoolExecutor
import json
import time

POLICY = "55555555-5555-4555-8555-555555555555"
CALL = "SELECT * FROM app.publish_admission_policy(%s,%s,NULL,%s)"


def run_publication_races(local, fresh_database, fixture):
    import psycopg

    def connect():
        # Standard disposable Supabase CLI port/password, never an external DSN.
        return psycopg.connect(host="127.0.0.1", port=54322, dbname="postgres",
                               user="postgres", password="postgres", autocommit=True)

    def actor(conn):
        conn.execute("BEGIN")
        subject, cutoff = conn.execute("SELECT b.auth_user_id::text,extract(epoch FROM b.tokens_valid_from)::bigint FROM app_private.principal_auth_bindings b WHERE b.id='cccccccc-cccc-4ccc-8ccc-cccccccccccc'").fetchone()
        conn.execute("SELECT set_config('request.jwt.claim.sub',%s,true)", (subject,))
        conn.execute("SELECT set_config('request.jwt.claims',%s,true)",
                     (json.dumps({"sub": subject, "role": "authenticated", "iat": cutoff, "is_anonymous": False}),))
        conn.execute("SET LOCAL ROLE authenticated")

    def wait_blocked(control, waiter, blocker):
        deadline = time.monotonic() + 15
        while time.monotonic() < deadline:
            blocked = control.execute("SELECT %s=ANY(pg_catalog.pg_blocking_pids(%s))", (blocker, waiter)).fetchone()[0]
            if blocked:
                return
            time.sleep(0.1)
        raise RuntimeError("DB03_PUBLICATION_RACE_EXPECTED_BLOCK_ABSENT")

    def error_from(future, expected):
        try:
            future.result(timeout=15)
        except psycopg.Error as exc:
            if exc.sqlstate != "P0001" or expected not in str(exc):
                raise RuntimeError("DB03_PUBLICATION_RACE_WRONG_FAILURE " + str(exc)) from exc
        else:
            raise RuntimeError("DB03_PUBLICATION_RACE_EXPECTED_DENIAL_ABSENT")

    for case in ("publish_first_edit", "edit_first_publish", "revocation_first", "publish_first_revoke", "expiry_after_wait"):
        fresh_database()
        local.run_psql("supabase_db_" + local.EXPECTED_PROJECT_ID,
                       "BEGIN;\n" + fixture + "\nUPDATE app_private.operation_contracts SET enabled=true WHERE code='admission.policy.publish';\nCOMMIT;",
                       "DB03_PUBLICATION_RACE_FIXTURE")
        a, b, control = connect(), connect(), connect()
        pool = ThreadPoolExecutor(max_workers=1)
        try:
            expected = control.execute("SELECT row_version FROM app_private.admission_policy_versions WHERE id=%s", (POLICY,)).fetchone()[0]
            if case.startswith("publish_first"):
                actor(a)
                a.execute(CALL, (POLICY, expected, case)).fetchone()
                b.execute("BEGIN")
                b.execute("SET LOCAL ROLE schoolos_schema_owner")
                if case == "publish_first_edit":
                    def edit():
                        b.execute("SELECT app_private.db03_lock_policy_configuration(%s)", (POLICY,))
                        b.execute("UPDATE app_private.admission_policy_document_requirements SET requirement='REQUIRED' WHERE document_kind='TRANSCRIPT' AND policy_stage_id='77777777-7777-4777-8777-777777777777'")
                    future = pool.submit(edit)
                else:
                    future = pool.submit(b.execute, "UPDATE app_private.role_permission_grants SET revoked_at=clock_timestamp()")
                wait_blocked(control, b.info.backend_pid, a.info.backend_pid)
                a.execute("COMMIT")
                if case == "publish_first_edit":
                    error_from(future, "published policy children are immutable")
                    b.execute("ROLLBACK")
                else:
                    future.result(timeout=15)
                    b.execute("COMMIT")
                    actor(a)
                    try:
                        a.execute(CALL, (POLICY, expected, case))
                    except psycopg.Error as exc:
                        if exc.sqlstate != "P0001" or "authority denied" not in str(exc):
                            raise
                    else:
                        raise RuntimeError("DB03_PUBLICATION_REVOKED_REPLAY_ALLOWED")
                    a.execute("ROLLBACK")
                state, receipts = control.execute("SELECT state,(SELECT count(*) FROM app_private.command_receipts WHERE command_kind='admission.policy.publish') FROM app_private.admission_policy_versions WHERE id=%s", (POLICY,)).fetchone()
                if state != "PUBLISHED" or receipts != 1:
                    raise RuntimeError("DB03_PUBLICATION_RACE_WINNER_EVIDENCE")
            else:
                if case == "expiry_after_wait":
                    expiry = control.execute("UPDATE app_private.role_permission_grants SET valid_until=clock_timestamp()+interval '5 seconds' RETURNING valid_until").fetchone()[0]
                a.execute("BEGIN")
                a.execute("SET LOCAL ROLE schoolos_schema_owner")
                if case == "revocation_first":
                    a.execute("UPDATE app_private.role_permission_grants SET revoked_at=clock_timestamp()")
                else:
                    a.execute("SELECT app_private.db03_lock_policy_configuration(%s)", (POLICY,))
                    if case == "edit_first_publish":
                        a.execute("UPDATE app_private.admission_policy_document_requirements SET requirement='REQUIRED' WHERE document_kind='TRANSCRIPT' AND policy_stage_id='77777777-7777-4777-8777-777777777777'")
                actor(b)
                future = pool.submit(lambda: b.execute(CALL, (POLICY, expected, case)).fetchone())
                wait_blocked(control, b.info.backend_pid, a.info.backend_pid)
                if case == "expiry_after_wait":
                    deadline = time.monotonic() + 8
                    while not control.execute("SELECT clock_timestamp()>%s", (expiry,)).fetchone()[0]:
                        if time.monotonic() > deadline:
                            raise RuntimeError("DB03_EXPIRY_CLOCK_BOUND")
                        time.sleep(0.1)
                a.execute("COMMIT")
                error_from(future, "draft version stale" if case == "edit_first_publish" else "authority denied")
                b.execute("ROLLBACK")
                state, receipts = control.execute("SELECT state,(SELECT count(*) FROM app_private.command_receipts WHERE command_kind='admission.policy.publish') FROM app_private.admission_policy_versions WHERE id=%s", (POLICY,)).fetchone()
                if state != "DRAFT" or receipts != 0:
                    raise RuntimeError("DB03_PUBLICATION_RACE_LOSER_EFFECT")
            print("DB03_PUBLICATION_RACE_PASS " + case + " observed_block=true exact_effect=true")
        finally:
            # Release blockers before joining workers, including on assertion failure.
            a.close()
            b.close()
            control.close()
            pool.shutdown(wait=True, cancel_futures=True)
    print("DB03_PUBLICATION_RACES_PASS 5 genuine PostgreSQL backend schedules")
