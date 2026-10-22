"""DB01-02 real two-backend P1 REVIEW and reviewer-grant revocation races.

Disposable D1 PostgreSQL only. Genuine authenticated REVIEW RPCs and separate
owner-only grant revocation use observed pg_blocking_pids/pg_locks, never sleeps
or mocked SQL return values as concurrency evidence. Never enable hosted D1.
"""
from __future__ import annotations

from concurrent.futures import ThreadPoolExecutor
from contextlib import closing
from pathlib import Path

from domain_concurrency_ci import settings_sql
from domain_db01_protected_direct_race_ci import _wait_for_block
from domain_enrollment_end_lock_prefix_ci import CONTAINER
from domain_student_photo_real_pg_handoff_ci import _local_connect

ROOT = Path(__file__).resolve().parents[2]
STUDENT = "d1020000-0000-4000-8000-000000000001"
GRANT = "d1920000-0000-4000-8000-000000000003"
REVIEWER = "foundation-own-001@example.invalid"
REQUEST_KEY = "db01-p1-review-race-submit"
FIRST_KEY = "db01-review-pg-first-winner"
LOSER_KEY = "db01-review-pg-first-stale"
REVOKED_KEY = "db01-review-pg-second-revoked"
REVIEW_REASON = "Genuine independent PostgreSQL stage one review"
REVOKED_REASON = "Genuine PostgreSQL stage two denied after grant revocation"


def _must(condition: bool, code: str) -> None:
    if not condition:
        raise RuntimeError("D1_DB01_P1_REVIEW_RACE_" + code)


def _reviewer_identity(cur) -> None:
    # The fixed seeded Auth account is already bound to a distinct genuine
    # INDIVIDUAL Person. All public review calls use that actor's JWT.
    cur.execute("""SELECT pg_catalog.set_config('request.jwt.claim.sub',
      (SELECT u.id::text FROM auth.users u WHERE u.email=%s),true)""", (REVIEWER,))
    cur.execute("""SELECT pg_catalog.set_config('request.jwt.claims',
      (SELECT pg_catalog.jsonb_build_object(
        'sub',u.id::text,'role','authenticated',
        'iat',pg_catalog.floor(pg_catalog.extract(epoch FROM b.tokens_valid_from))::bigint,
        'is_anonymous',false)::text
       FROM auth.users u
       JOIN app_private.principal_auth_bindings b ON b.auth_user_id=u.id
       JOIN app_private.principals p ON p.id=b.principal_id
       WHERE u.email=%s AND p.kind='INDIVIDUAL' AND p.person_id IS NOT NULL
         AND p.state='ACTIVE'),true)""", (REVIEWER,))
    cur.execute("SET ROLE authenticated")
    cur.execute("SET LOCAL statement_timeout='15s'")


def _review(conn, request: str, version: int, key: str, reason: str):
    with conn.cursor() as cur:
        _reviewer_identity(cur)
        cur.execute("""SELECT request_id,request_version,request_state
          FROM app.d1_review_student_roll_correction(
            %s::uuid,'APPROVE',%s::bigint,%s,%s)""",
            (request, version, reason, key))
        result = cur.fetchone()
        _must(result is not None, "NO_RESULT")
        return str(result[0]), int(result[1]), result[2]


def _denied(conn, psycopg, request: str, version: int, key: str,
            reason: str) -> str:
    try:
        _review(conn, request, version, key, reason)
    except psycopg.errors.RaiseException as exc:
        conn.rollback()
        _must(exc.sqlstate == "P0001", "DENIAL_SQLSTATE")
        return "DENIED"
    conn.rollback()
    return "ACCEPTED"


def _request(cur):
    cur.execute("""SELECT q.id,q.row_version
      FROM app_private.approval_requests q
      JOIN app_private.command_receipts rc ON rc.request_id=q.id
      WHERE rc.idempotency_key=%s AND rc.command_kind='request.submit'
        AND rc.state='SUCCEEDED'
        AND q.target_ref=%s::uuid""", (REQUEST_KEY, STUDENT))
    rows = cur.fetchall()
    _must(len(rows) == 1, "REQUEST_NOT_UNIQUE")
    return str(rows[0][0]), int(rows[0][1])


def _snapshot(cur, request: str):
    cur.execute("""SELECT q.state,q.row_version,
     (SELECT s.state FROM app_private.approval_request_steps s
       WHERE s.request_id=q.id AND s.step_number=1),
     (SELECT s.state FROM app_private.approval_request_steps s
       WHERE s.request_id=q.id AND s.step_number=2),
     (SELECT count(*) FROM app_private.approval_reviews review
       JOIN app_private.approval_request_steps s ON s.id=review.step_id
       WHERE s.request_id=q.id),
     (SELECT count(*) FROM app_private.command_receipts rc
       WHERE rc.request_id=q.id AND rc.command_kind='request.review'
         AND rc.state='SUCCEEDED'),
     (SELECT count(*) FROM app_private.audit_events a
       WHERE a.approval_request_id=q.id
         AND a.authority_evidence->>'phase'='REVIEW'),
     (SELECT count(*) FROM app_private.roll_allocations ra
       WHERE ra.student_id=q.target_ref),
     (SELECT row_version FROM app_private.students st WHERE st.id=q.target_ref),
     (SELECT count(*) FROM app_private.outbox_events o
       JOIN app_private.command_receipts rc ON rc.id=o.command_receipt_id
       WHERE rc.request_id=q.id),
     (SELECT a.next_value FROM app_private.roll_allocator_states a
       JOIN app_private.roll_allocations ra ON ra.policy_revision_id=a.policy_revision_id
       JOIN app_private.enrollments en ON en.id=ra.enrollment_id
       WHERE ra.student_id=q.target_ref AND
         (a.class_offering_id IS NULL OR a.class_offering_id=en.class_offering_id)
       LIMIT 1)
    FROM app_private.approval_requests q WHERE q.id=%s::uuid""", (request,))
    rows = cur.fetchall()
    _must(len(rows) == 1, "SNAPSHOT_MISSING")
    return rows[0]


def _owner_revoke(cur) -> None:
    # A separate privileged fixture serializes against the reviewer's
    # Foundation SHARED authorization lock; no client can mutate this table.
    cur.execute("""SELECT pg_catalog.set_config('request.jwt.claim.sub',
      (SELECT id::text FROM auth.users WHERE email='foundation-rbac-001@example.invalid'),true)""")
    cur.execute("""SELECT pg_catalog.set_config('request.jwt.claims',
      pg_catalog.jsonb_build_object(
        'sub',current_setting('request.jwt.claim.sub'),'role','authenticated',
        'iat',(SELECT pg_catalog.extract(epoch FROM tokens_valid_from)::bigint
               FROM app_private.principal_auth_bindings
              WHERE id='66666666-6666-4666-8666-666666666666'),
        'is_anonymous',false)::text,true)""")
    cur.execute("SELECT pg_catalog.pg_advisory_xact_lock(71001,1)")
    cur.execute("SET ROLE schoolos_schema_owner")
    cur.execute("""UPDATE app_private.role_permission_grants
       SET revoked_at=pg_catalog.clock_timestamp()
       WHERE id=%s::uuid AND revoked_at IS NULL""", (GRANT,))
    _must(cur.rowcount == 1, "GRANT_NOT_REVOKED")


def run_db01_p1_review_live_races(container, run_psql, root=ROOT):
    _must(container == CONTAINER, "DISPOSABLE_CONTAINER_REQUIRED")
    import psycopg

    fixture = (Path(root)/"supabase/tests/domain/fixtures/"
               "db01_p1_review_two_backend_setup.sql").read_text(encoding="utf-8")
    for token in ("d1_place_student_enrollment", "d1_submit_student_roll_correction",
                  "D1_REVIEWER_ROLE_SCOPE", GRANT, "foundation-own-001@example.invalid",
                  "SET ROLE authenticated;", "\\gset submitted_"):
        _must(token in fixture, "INCOMPLETE_FIXTURE")

    # Auth/School principal fixtures were committed earlier by domain_concurrency_ci.
    # P1 policy is campus-exact, taking precedence over the active school-wide DIRECT.
    run_psql(container, "BEGIN;\n"+settings_sql()+"\nRESET ROLE;\n"+fixture+"\nCOMMIT;\n",
             "D1_DB01_P1_REVIEW_RACE_GENUINE_SETUP", timeout=120)

    with closing(_local_connect(psycopg)) as observer:
        with observer.cursor() as cur:
            request, version = _request(cur)
            baseline = _snapshot(cur, request)
            _must(baseline[:10] ==
                  ("PENDING",version,"OPEN","WAITING",0,0,0,1,1,0),
                  "INITIAL_REQUEST_AND_HISTORY")
            _must(baseline[10] is not None, "INITIAL_ALLOCATOR_MISSING")
        observer.rollback()

    # First transaction makes a real authenticated stage-1 APPROVE and keeps
    # it uncommitted. A distinct backend's different-key REVIEW of the SAME
    # request must observably block, then reject the stale request version.
    with closing(_local_connect(psycopg)) as winner, \
         closing(_local_connect(psycopg)) as contender, \
         closing(_local_connect(psycopg)) as observer:
        result = _review(winner, request, version, FIRST_KEY, REVIEW_REASON)
        _must(result == (request,version+1,"PENDING"), "FIRST_STAGE_RESULT")
        with ThreadPoolExecutor(max_workers=1) as pool:
            future = pool.submit(_denied,contender,psycopg,request,version,
                                 LOSER_KEY,"Conflicting stale parallel review")
            try:
                with observer.cursor() as cur:
                    _wait_for_block(cur, contender.info.backend_pid,
                                    winner.info.backend_pid, future)
                    _must(_snapshot(cur,request)==baseline,
                          "UNCOMMITTED_REVIEW_VISIBLE")
            finally:
                winner.commit()
            _must(future.result(timeout=20)=="DENIED",
                  "PARALLEL_STALE_REVIEW_ACCEPTED")
        with observer.cursor() as cur:
            after = _snapshot(cur,request)
            _must(after == ("PENDING",version+1,"APPROVED","OPEN",
                            1,1,1,1,1,0,baseline[10]),
                  "FIRST_STAGE_EVIDENCE_OR_HISTORY")
        observer.rollback()
    print("D1_DB01_P1_REVIEW_REVIEW_REAL_PG_RACE_PASS "
          "two genuine authenticated backends, observed request lock, "
          "one stage APPROVE/receipt/audit and no stale contender evidence")

    # Second transaction revokes the exact authorized reviewer role GRANT
    # while it owns the Foundation EXCLUSIVE lock. A second authenticated
    # reviewer connection must visibly block on its SHARED auth lock, then
    # reject without stage transition or any new immutable evidence.
    with closing(_local_connect(psycopg)) as revoker, \
         closing(_local_connect(psycopg)) as reviewer, \
         closing(_local_connect(psycopg)) as observer:
        with revoker.cursor() as cur:
            _owner_revoke(cur)
        with ThreadPoolExecutor(max_workers=1) as pool:
            future=pool.submit(_denied,reviewer,psycopg,request,version+1,
                               REVOKED_KEY,REVOKED_REASON)
            try:
                with observer.cursor() as cur:
                    _wait_for_block(cur,reviewer.info.backend_pid,
                                    revoker.info.backend_pid,future)
                    _must(_snapshot(cur,request)==after,
                          "UNCOMMITTED_REVOKE_CHANGED_REQUEST")
            finally:
                revoker.commit()
            _must(future.result(timeout=20)=="DENIED",
                  "POST_REVOKE_REVIEW_ACCEPTED")
        with observer.cursor() as cur:
            _must(_snapshot(cur,request)==after,
                  "POST_REVOKE_RECEIPT_AUDIT_OR_ROLL_LEAK")
            cur.execute("""SELECT count(*) FROM app_private.role_permission_grants
                           WHERE id=%s::uuid AND revoked_at IS NOT NULL""", (GRANT,))
            _must(cur.fetchone()==(1,), "REVOKE_NOT_COMMITTED")
        observer.rollback()
    print("D1_DB01_P1_REVIEW_AUTH_REVOCATION_REAL_PG_RACE_PASS "
          "owner EXCLUSIVE Foundation auth lock, authenticated reviewer "
          "SHARED wait observed, revoked reviewer denied and evidence retained")

    # A successful review receipt does not become a backdoor after revocation:
    # even the historical exact-key replay must check live authorization.
    with closing(_local_connect(psycopg)) as reviewer:
        _must(_denied(reviewer,psycopg,request,version,FIRST_KEY,
                      REVIEW_REASON)=="DENIED",
              "HISTORICAL_REPLAY_AUTH_BYPASS")
    with closing(_local_connect(psycopg)) as observer:
        with observer.cursor() as cur:
            _must(_snapshot(cur,request)==after, "HISTORICAL_RECEIPT_MUTATED")
            cur.execute("""SELECT count(*) FROM app_private.command_receipts
              WHERE request_id=%s::uuid AND command_kind='request.review'
                AND idempotency_key IN (%s,%s)""", (request,LOSER_KEY,REVOKED_KEY))
            _must(cur.fetchone()==(0,), "FAILED_RACES_EMITTED_RECEIPTS")
        observer.rollback()
    print("D1_DB01_P1_REVIEW_RACES_PASS "
          "two observed PostgreSQL lock waits, stale parallel review and "
          "revoked grant fail closed, immutable receipt preserved, no Roll effect")
