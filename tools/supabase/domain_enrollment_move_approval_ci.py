"""Authenticated MOVE SUBMIT/REVIEW/APPLY lock and immutable replay acceptance.

Run after the DIRECT namespace-union proof. Privileged setup does NOT create
requests, reviews, applications, Enrollment or Roll records. Those use RPCs.
"""
from concurrent.futures import ThreadPoolExecutor
from contextlib import closing
from pathlib import Path

from domain_concurrency_ci import settings_sql
from domain_enrollment_end_lock_prefix_ci import _check, _lock, _observe, CONTAINER
from domain_enrollment_move_roll_union_ci import SOURCE_SECTION, DESTINATION, SOURCE_POOL
from domain_student_photo_real_pg_handoff_ci import _local_connect, _actor_connection

ROOT = Path(__file__).resolve().parents[2]
STUDENT = '620c6f82-2ade-47f0-85c5-000000000001'
SUBMIT_KEY = 'move-union-approval-submit'
REVIEW_KEY = 'move-union-approval-review'
APPLY_KEY = 'move-union-approval-apply'


def _reviewer(psycopg):
    conn = _local_connect(psycopg)
    try:
        with conn.cursor() as cur:
            cur.execute("SELECT set_config('request.jwt.claim.sub',(SELECT id::text FROM auth.users WHERE email='foundation-test-001@example.invalid'),true)")
            cur.execute("""SELECT set_config('request.jwt.claims',jsonb_build_object(
                'sub',current_setting('request.jwt.claim.sub'),'role','authenticated','is_anonymous',false,
                'iat',(SELECT extract(epoch FROM tokens_valid_from)::bigint FROM app_private.principal_auth_bindings
                WHERE id='76000000-0000-4000-8000-000000000005'))::text,true)""")
            cur.execute('SET ROLE authenticated')
        return conn
    except Exception:
        conn.close()
        raise


def _submit(conn, source):
    with conn.cursor() as cur:
        cur.execute("SET LOCAL statement_timeout='15s'")
        cur.execute('SET ROLE authenticated')
        cur.execute('''SELECT request_id,request_version FROM app.d1_submit_student_enrollment_move(
            %s::uuid,1,%s::uuid,%s::uuid,CURRENT_DATE-4,%s::uuid,'CLASS_CHANGE',CURRENT_DATE,
            'MOVE independent approval',NULL,%s)''', (STUDENT, source, SOURCE_SECTION, DESTINATION, SUBMIT_KEY))
        row = cur.fetchone()
        _check(row is not None and row[1] == 3, 'MOVE_APPROVAL_SUBMIT_RESULT')
        return str(row[0]), row[1]


def _review(conn, request):
    with conn.cursor() as cur:
        cur.execute('SET ROLE authenticated')
        cur.execute('''SELECT request_id,request_version,request_state FROM app.d1_review_student_enrollment_move(
            %s::uuid,'APPROVE',3,'Independent verification of MOVE',%s)''', (request, REVIEW_KEY))
        row = cur.fetchone()
        _check(row is not None and str(row[0]) == request and row[1:] == (4, 'APPROVED'), 'MOVE_APPROVAL_REVIEW_RESULT')
        return tuple(map(str,row))


def _apply(conn, request):
    with conn.cursor() as cur:
        cur.execute("SET LOCAL statement_timeout='15s'")
        cur.execute('SET ROLE authenticated')
        cur.execute('''SELECT request_id,request_version,request_state,enrollment_id
            FROM app.d1_apply_student_enrollment_move(%s::uuid,4,%s)''', (request, APPLY_KEY))
        row = cur.fetchone()
        _check(row is not None and str(row[0]) == request and row[1:3] == (5,'EXECUTED') and row[3] is not None,
               'MOVE_APPROVAL_APPLY_RESULT')
        return tuple(map(str,row))


def _snapshot(cur):
    cur.execute('''SELECT
        (SELECT count(*) FROM app_private.enrollments WHERE student_id=%s::uuid),
        (SELECT count(*) FROM app_private.roll_allocations WHERE student_id=%s::uuid),
        (SELECT count(*) FROM app_private.approval_requests WHERE target_ref=%s::uuid),
        (SELECT count(*) FROM app_private.approval_applications a JOIN app_private.approval_requests q ON q.id=a.request_id WHERE q.target_ref=%s::uuid),
        (SELECT count(*) FROM app_private.command_receipts WHERE idempotency_key IN (%s,%s,%s)),
        (SELECT count(*) FROM app_private.outbox_events e JOIN app_private.command_receipts r ON r.id=e.command_receipt_id WHERE r.idempotency_key=%s AND e.event_type='enrollment.moved')''',
        (STUDENT,STUDENT,STUDENT,STUDENT,SUBMIT_KEY,REVIEW_KEY,APPLY_KEY,APPLY_KEY))
    return cur.fetchone()


def _blocked_call(psycopg, factory, command, value, *, commit):
    with closing(_local_connect(psycopg)) as holder, closing(factory(psycopg)) as worker, closing(_local_connect(psycopg)) as observer:
        with holder.cursor() as cur:
            _lock(cur,'allocator',SOURCE_POOL)
        with ThreadPoolExecutor(max_workers=1) as pool:
            future = pool.submit(command,worker,value)
            try:
                with observer.cursor() as cur:
                    _observe(cur,worker.info.backend_pid,holder.info.backend_pid,future)
                    _lock(cur,'student',STUDENT,nowait=True)
                observer.rollback()
            finally:
                holder.rollback()
            result = future.result(timeout=18)
            if commit:
                worker.commit()
            else:
                worker.rollback()
            return result


def run_enrollment_move_approval(container,run_psql,root=ROOT):
    _check(container == CONTAINER,'MOVE_APPROVAL_DISPOSABLE_ONLY')
    import psycopg
    with closing(_local_connect(psycopg)) as probe:
        with probe.cursor() as cur:
            cur.execute("""SELECT
                has_function_privilege('schoolos_workflow_executor','app_private.d1_enrollment_place_prelock_roll(uuid,date)','EXECUTE'),
                has_function_privilege('authenticated','app_private.d1_enrollment_place_prelock_roll(uuid,date)','EXECUTE'),
                has_function_privilege('anon','app_private.d1_enrollment_place_prelock_roll(uuid,date)','EXECUTE'),
                has_function_privilege('service_role','app_private.d1_enrollment_place_prelock_roll(uuid,date)','EXECUTE')""")
            _check(cur.fetchone() == (True,False,False,False),'MOVE_APPROVAL_PRELOCK_EFFECTIVE_ACL')
            cur.execute("SELECT has_table_privilege('schoolos_authz_reader','app_private.approval_requests','SELECT')")
            _check(cur.fetchone() == (False,),'MOVE_APPROVAL_BROAD_AUTHZ_REQUEST_GRANT')
            cur.execute("""SELECT
                has_table_privilege('schoolos_workflow_executor','app_private.approval_applications','SELECT'),
                has_column_privilege('schoolos_workflow_executor','app_private.approval_applications','request_id','SELECT'),
                has_any_column_privilege('authenticated','app_private.approval_applications','SELECT'),
                has_any_column_privilege('anon','app_private.approval_applications','SELECT'),
                has_any_column_privilege('service_role','app_private.approval_applications','SELECT')""")
            _check(cur.fetchone() == (False,True,False,False,False),'MOVE_APPROVAL_APPLICATION_EFFECTIVE_ACL')
    fixture = (Path(root)/'supabase/tests/domain/fixtures/enrollment_move_approval.sql').read_text()
    run_psql(container,'BEGIN;\n'+settings_sql()+'RESET ROLE;\n'+fixture
        + f"SET ROLE authenticated; SELECT * FROM app.d1_place_student_enrollment('{STUDENT}',1,'{SOURCE_SECTION}',"
          "'INITIAL',CURRENT_DATE-4,NULL,'MOVE approval real P0',NULL,'move-approval-seed'); RESET ROLE; COMMIT;",
        'D1_MOVE_APPROVAL_REAL_P0_FIXTURE',timeout=60)
    with closing(_local_connect(psycopg)) as observer:
        with observer.cursor() as cur:
            cur.execute('''SELECT count(DISTINCT p.person_id),count(DISTINCT b.auth_user_id)
                FROM app_private.principal_auth_bindings b JOIN app_private.principals p ON p.id=b.principal_id
                WHERE b.id IN ('66666666-6666-4666-8666-666666666666','76000000-0000-4000-8000-000000000005')''')
            _check(cur.fetchone() == (2,2),'MOVE_APPROVAL_REAL_DISTINCT_PEOPLE')
            cur.execute('SELECT id FROM app_private.enrollments WHERE student_id=%s::uuid AND effective_until IS NULL',(STUDENT,))
            rows = cur.fetchall()
            _check(len(rows) == 1,'MOVE_APPROVAL_SOURCE_COUNT')
            source = str(rows[0][0])
    _blocked_call(psycopg,_actor_connection,_submit,source,commit=False)
    with closing(_local_connect(psycopg)) as observer:
        with observer.cursor() as cur:
            _check(_snapshot(cur) == (1,1,0,0,0,0),'MOVE_APPROVAL_SUBMIT_ROLLBACK_LEAK')
    request, version = _blocked_call(psycopg,_actor_connection,_submit,source,commit=True)
    # Self approval is denied; the separate real Person supplies the only review.
    with closing(_actor_connection(psycopg)) as self_review:
        try:
            _review(self_review,request)
        except psycopg.errors.RaiseException:
            self_review.rollback()
        else:
            raise RuntimeError('D1_MOVE_APPROVAL_SELF_REVIEW_ACCEPTED')
    with closing(_reviewer(psycopg)) as reviewer:
        reviewed = _review(reviewer,request)
        reviewer.commit()
    _blocked_call(psycopg,_reviewer,_apply,request,commit=False)
    with closing(_local_connect(psycopg)) as observer:
        with observer.cursor() as cur:
            _check(_snapshot(cur) == (1,1,1,0,2,0),'MOVE_APPROVAL_APPLY_ROLLBACK_LEAK')
            cur.execute('SELECT state,row_version FROM app_private.approval_requests WHERE id=%s::uuid',(request,))
            _check(cur.fetchone() == ('APPROVED',4),'MOVE_APPROVAL_ROLLBACK_STATE')
    applied = _blocked_call(psycopg,_reviewer,_apply,request,commit=True)
    with closing(_local_connect(psycopg)) as evidence:
        with evidence.cursor() as cur:
            cur.execute('SET ROLE schoolos_workflow_executor')
            cur.execute('SELECT count(*) FROM app_private.approval_applications WHERE request_id=%s::uuid',(request,))
            _check(cur.fetchone() == (1,),'MOVE_APPROVAL_APPLICATION_RLS_VISIBILITY')
    with closing(_actor_connection(psycopg)) as replay:
        _check(_submit(replay,source) == (request,3),'MOVE_APPROVAL_SUBMIT_REPLAY')
        replay.commit()
    with closing(_reviewer(psycopg)) as replay:
        _check(_review(replay,request) == reviewed,'MOVE_APPROVAL_REVIEW_REPLAY')
        _check(_apply(replay,request) == applied,'MOVE_APPROVAL_APPLY_REPLAY')
        replay.commit()
    with closing(_local_connect(psycopg)) as observer:
        with observer.cursor() as cur:
            _check(_snapshot(cur) == (2,2,1,1,3,1),'MOVE_APPROVAL_COMMIT_REPLAY_EVIDENCE')
            cur.execute('''SELECT count(*) FROM app_private.approval_reviews v JOIN app_private.approval_request_steps s ON s.id=v.step_id
                WHERE s.request_id=%s::uuid AND v.decision='APPROVE' ''',(request,))
            _check(cur.fetchone() == (1,),'MOVE_APPROVAL_REVIEW_CARDINALITY')
    print('D1_ENROLLMENT_MOVE_APPROVAL_PASS genuine independent SUBMIT/REVIEW/APPLY; 4 source-pool waits; Student free upstream; rollback; self-review denied; immutable three-phase replay; one application/event')
