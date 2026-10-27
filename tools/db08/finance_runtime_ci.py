"""Disposable local Auth, Data API and observed-backend Finance acceptance."""
from concurrent.futures import ThreadPoolExecutor
import json
import secrets
import time
import urllib.error
import urllib.request
from uuid import UUID

SCHOOL = '08000000-0000-4000-8000-000000000002'
CAMPUS = '08000000-0000-4000-8000-000000000003'
YEAR = '08000000-0000-4000-8000-000000000004'
PERSON = '08000000-0000-4000-8000-000000000006'
FEE_SCOPE = '08000000-0000-4000-8000-000000000017'
REVIEW_SCOPE = '08000000-0000-4000-8000-000000000032'
CHANGE_POLICY = '08000000-0000-4000-8000-000000000034'
REVIEWER = '08000000-0000-4000-8000-000000000021'
CONFIG_SQL = ('SELECT app.configure_finance_fee(%s::uuid,%s::uuid,%s,%s,%s,%s,'
              '%s::integer,%s::numeric,%s::date,%s::date,%s,%s)')
ASSESS_SQL = ('SELECT app.assess_finance_fee(%s::uuid,%s::uuid,%s::uuid,'
              '%s::date,%s::date,%s::date,%s::uuid)')


def run_finance_runtime(local_status):
    import psycopg
    from services.admission_documents.adapters import SupabaseAuthenticator, _NoRedirect

    def connect():
        return psycopg.connect(host='127.0.0.1', port=54322, dbname='postgres',
                               user='postgres', password='postgres', autocommit=True)

    url, admin_key = local_status()
    opener = urllib.request.build_opener(_NoRedirect(), urllib.request.ProxyHandler({}))

    def http(method, path, payload, key, bearer, *, profile=None):
        headers = {'apikey': key, 'Authorization': 'Bearer ' + bearer,
                   'Content-Type': 'application/json'}
        if profile:
            headers['Content-Profile'] = profile
            headers['Accept-Profile'] = profile
        req = urllib.request.Request(url + path, data=json.dumps(payload).encode(),
                                     method=method, headers=headers)
        with opener.open(req, timeout=20) as response:
            return json.load(response)

    with connect() as root:
        subject = root.execute("SELECT auth_user_id::text FROM app_private.principal_auth_bindings WHERE id='08000000-0000-4000-8000-000000000008'").fetchone()[0]
    password = secrets.token_urlsafe(36)
    http('PUT', '/auth/v1/admin/users/' + subject, {'password': password}, admin_key, admin_key)
    token = http('POST', '/auth/v1/token?grant_type=password',
                 {'email': 'foundation-rbac-001@example.invalid', 'password': password},
                 admin_key, admin_key)['access_token']
    password = None
    claims = SupabaseAuthenticator(url, admin_key, allow_local_test=True)(token)

    def check(condition, label):
        if not condition:
            raise RuntimeError('DB08_RUNTIME_CHECK ' + label)

    def configure(rule, key):
        return {'p_campus': CAMPUS, 'p_year': YEAR, 'p_category_code': 'TUITION',
                'p_category_label': 'Tuition', 'p_rule_key': rule, 'p_frequency': 'MONTHLY',
                'p_minor_unit_scale': 2, 'p_gross_minor': 15000,
                'p_valid_from': '2026-01-01', 'p_valid_through': '2026-12-31',
                'p_reason': 'Initial school fee', 'p_key': key}

    def assess(rule, revision, key, start, end):
        return (rule, PERSON, revision, start, end, '2026-05-05', key)

    def actor(conn, identity=None):
        identity = claims if identity is None else identity
        conn.execute('BEGIN')
        conn.execute("SELECT set_config('request.jwt.claim.sub',%s,true)", (identity.subject,))
        conn.execute("SELECT set_config('request.jwt.claims',%s,true)",
                     (json.dumps(identity.database_claims()),))
        conn.execute('SET LOCAL ROLE authenticated')

    def witness(control, blocker, waiter):
        deadline = time.monotonic() + 15
        while time.monotonic() < deadline:
            if control.execute('SELECT %s=ANY(pg_blocking_pids(%s))',
                               (blocker.info.backend_pid, waiter.info.backend_pid)).fetchone()[0]:
                return
            time.sleep(.05)
        raise RuntimeError('DB08_OBSERVED_BLOCK_ABSENT')

    def denied(future, fragment):
        try:
            future.result(timeout=20)
        except psycopg.Error as exc:
            if exc.sqlstate != 'P0001' or fragment not in str(exc):
                raise RuntimeError('DB08_WRONG_RACE_DENIAL ' + fragment) from exc
        else:
            raise RuntimeError('DB08_RACE_DENIAL_ABSENT ' + fragment)

    fee = http('POST', '/rest/v1/rpc/configure_finance_fee',
               configure('SERVICE_FEE', 'service-fee'), admin_key, token, profile='app')
    check(UUID(fee['resource_id']) and UUID(fee['source_id']), 'real Auth Data API fee publication')
    same = http('POST', '/rest/v1/rpc/configure_finance_fee',
                configure('SERVICE_FEE', 'service-fee'), admin_key, token, profile='app')
    check(same == fee, 'HTTP exact retry')
    with connect() as root:
        revision = root.execute('SELECT id::text FROM app_private.finance_fee_rule_revisions WHERE rule_id=%s AND revision=1',
                                (fee['resource_id'],)).fetchone()[0]
    charge_key = '08000000-0000-4000-8000-000000000201'
    charge_payload = {'p_rule': fee['resource_id'], 'p_person': PERSON, 'p_revision': revision,
                      'p_period_start': '2026-02-01', 'p_period_end': '2026-02-28',
                      'p_due_on': '2026-03-05', 'p_key': charge_key}
    charge = http('POST', '/rest/v1/rpc/assess_finance_fee', charge_payload,
                  admin_key, token, profile='app')
    check(UUID(charge['resource_id']) and charge['campus_id'] == CAMPUS,
          'real Auth Data API charge')
    check(http('POST', '/rest/v1/rpc/assess_finance_fee', charge_payload,
               admin_key, token, profile='app') == charge, 'HTTP charge retry')
    try:
        http('POST', '/rest/v1/rpc/configure_finance_fee',
             configure('UNAUTHORIZED', 'service-key'), admin_key, admin_key, profile='app')
    except urllib.error.HTTPError as exc:
        check(exc.code in (401, 403, 404), 'service-role must have no Finance RPC execute')
    else:
        raise RuntimeError('DB08_SERVICE_ROLE_RPC_BYPASS')
    print('DB08_REAL_AUTH_DATA_API_PASS fee=true charge=true exact_replay=true service_role_denied=true', flush=True)

    # Two real backends contend on the global Finance lock. The losing backend
    # must observe the post-commit receipt or reject the new overlapping period.
    a, b, control = connect(), connect(), connect()
    pool = ThreadPoolExecutor(max_workers=1)
    try:
        actor(a)
        first = a.execute(CONFIG_SQL,
                          tuple(configure('RACE_FEE', 'race-fee').values())).fetchone()[0]
        actor(b)
        future = pool.submit(lambda: b.execute(CONFIG_SQL,
                                                tuple(configure('RACE_FEE', 'race-fee').values())).fetchone()[0])
        witness(control, a, b)
        a.execute('COMMIT')
        check(future.result(timeout=20) == first, 'same key after observed wait')
        b.execute('COMMIT')
        print('DB08_FEE_RACE_PASS same_key observed_block=true single_publication=true', flush=True)

        actor(a)
        first_charge = a.execute(ASSESS_SQL,
                                 assess(fee['resource_id'], revision,
                                        '08000000-0000-4000-8000-000000000202',
                                        '2026-04-01', '2026-04-30')).fetchone()[0]
        actor(b)
        future = pool.submit(lambda: b.execute(ASSESS_SQL,
                                                assess(fee['resource_id'], revision,
                                                       '08000000-0000-4000-8000-000000000203',
                                                       '2026-04-15', '2026-05-14')).fetchone()[0])
        witness(control, a, b)
        a.execute('COMMIT')
        denied(future, 'overlapping fee period')
        b.execute('ROLLBACK')
        check(first_charge['resource_id'] is not None, 'winning charge retained')
        print('DB08_FEE_RACE_PASS overlapping_period observed_block=true loser_denied=true', flush=True)

        a.execute('BEGIN')
        a.execute('SELECT pg_advisory_xact_lock(71001,1)')
        a.execute('SET LOCAL ROLE schoolos_schema_owner')
        a.execute('UPDATE app_private.assignment_permission_scopes SET revoked_at=clock_timestamp() WHERE id=%s',
                  (FEE_SCOPE,))
        actor(b)
        future = pool.submit(lambda: b.execute(CONFIG_SQL,
                                                tuple(configure('REVOKED_FEE', 'race-revoke').values())).fetchone()[0])
        witness(control, a, b)
        a.execute('COMMIT')
        denied(future, 'authority denied')
        b.execute('ROLLBACK')
        print('DB08_FEE_RACE_PASS revocation_first observed_block=true denied=true', flush=True)
    finally:
        a.close(); b.close(); control.close()
        pool.shutdown(wait=True, cancel_futures=True)

    with connect() as root:
        check(root.execute("SELECT count(*) FROM app_private.finance_fee_publications").fetchone()[0] == 2,
              'only two real publications')
        check(root.execute("SELECT count(*) FROM app_private.finance_fee_obligations").fetchone()[0] == 2,
              'only two real charges')
        check(root.execute("SELECT count(*) FROM app_private.command_receipts WHERE command_kind LIKE 'finance.%'").fetchone()[0] == 4,
              'four exact receipts')
    print('DB08_REAL_AUTH_RACES_PASS three observed backend schedules; receipts=4; no_overlap=true', flush=True)

    with connect() as root:
        reviewer_subject = root.execute("SELECT auth_user_id::text FROM app_private.principal_auth_bindings WHERE id='08000000-0000-4000-8000-000000000022'").fetchone()[0]
    reviewer_password = secrets.token_urlsafe(36)
    http('PUT', '/auth/v1/admin/users/' + reviewer_subject, {'password': reviewer_password}, admin_key, admin_key)
    reviewer_token = http('POST', '/auth/v1/token?grant_type=password',
                          {'email': 'foundation-own-001@example.invalid', 'password': reviewer_password},
                          admin_key, admin_key)['access_token']
    reviewer_password = None
    reviewer_claims = SupabaseAuthenticator(url, admin_key, allow_local_test=True)(reviewer_token)

    def change_payload(previous, amount, effective, key):
        return {'p_rule': fee['resource_id'], 'p_previous_revision': previous,
                'p_gross_minor': amount, 'p_valid_from': effective,
                'p_valid_through': '2026-12-31', 'p_policy': CHANGE_POLICY,
                'p_reviewer': REVIEWER, 'p_reason': 'Reviewed future tuition price', 'p_key': key}

    def review_payload(request, decision, key):
        return {'p_request': request['request_id'], 'p_decision': decision,
                'p_expected_version': request['request_version'],
                'p_note': 'Independent financial review', 'p_key': key}

    pending = http('POST', '/rest/v1/rpc/request_finance_fee_change',
                   change_payload(revision, 17500, '2026-11-01', 'real-f3-request'),
                   admin_key, token, profile='app')
    check(pending['state'] == 'PENDING', 'real Auth price request pending')
    check(http('POST', '/rest/v1/rpc/request_finance_fee_change',
               change_payload(revision, 17500, '2026-11-01', 'real-f3-request'),
               admin_key, token, profile='app') == pending, 'real request replay')
    with connect() as root:
        check(root.execute('SELECT count(*) FROM app_private.finance_fee_rule_revisions WHERE rule_id=%s',
                           (fee['resource_id'],)).fetchone()[0] == 1,
              'pending review does not publish')
    approved = http('POST', '/rest/v1/rpc/review_finance_fee_change',
                    review_payload(pending, 'APPROVE', 'real-f3-approve'),
                    admin_key, reviewer_token, profile='app')
    check(approved['state'] == 'EXECUTED' and UUID(approved['publication_id']),
          'real independent Auth reviewer publishes')
    check(http('POST', '/rest/v1/rpc/review_finance_fee_change',
               review_payload(pending, 'APPROVE', 'real-f3-approve'),
               admin_key, reviewer_token, profile='app') == approved, 'real review replay')
    with connect() as root:
        new_revision = root.execute('SELECT id::text FROM app_private.finance_fee_rule_revisions WHERE rule_id=%s AND revision=2 AND gross_amount_minor=17500',
                                    (fee['resource_id'],)).fetchone()[0]
        check(root.execute('SELECT gross_amount_minor FROM app_private.finance_fee_obligations WHERE id=%s',
                           (first_charge['resource_id'],)).fetchone()[0] == 15000,
              'existing charge retains original price')
    november = {'p_rule': fee['resource_id'], 'p_person': PERSON, 'p_revision': new_revision,
                'p_period_start': '2026-11-01', 'p_period_end': '2026-11-30',
                'p_due_on': '2026-12-05', 'p_key': '08000000-0000-4000-8000-000000000204'}
    check(UUID(http('POST', '/rest/v1/rpc/assess_finance_fee', november,
                    admin_key, token, profile='app')['resource_id']),
          'new effective price assessed through real Auth')
    rejected = http('POST', '/rest/v1/rpc/request_finance_fee_change',
                    change_payload(new_revision, 18500, '2026-12-15', 'real-f3-reject'),
                    admin_key, token, profile='app')
    decision = http('POST', '/rest/v1/rpc/review_finance_fee_change',
                    review_payload(rejected, 'REJECT', 'real-f3-reject-review'),
                    admin_key, reviewer_token, profile='app')
    check(decision['state'] == 'REJECTED' and 'publication_id' not in decision,
          'rejection creates no price publication')
    print('DB08_F3_REAL_AUTH_PASS pending=true independent_approval=true replay=true rejected_no_price=true', flush=True)

    race_request = http('POST', '/rest/v1/rpc/request_finance_fee_change',
                        change_payload(new_revision, 19000, '2026-12-20', 'real-f3-race'),
                        admin_key, token, profile='app')
    a, b, control = connect(), connect(), connect()
    pool = ThreadPoolExecutor(max_workers=1)
    try:
        a.execute('BEGIN')
        a.execute('SELECT pg_advisory_xact_lock(71001,1)')
        a.execute('SET LOCAL ROLE schoolos_schema_owner')
        a.execute('UPDATE app_private.assignment_permission_scopes SET revoked_at=clock_timestamp() WHERE id=%s',
                  (REVIEW_SCOPE,))
        actor(b, reviewer_claims)
        future = pool.submit(lambda: b.execute('SELECT app.review_finance_fee_change(%s::uuid,%s,%s::bigint,%s,%s)',
                                                (race_request['request_id'], 'APPROVE',
                                                 race_request['request_version'], 'Review after revocation',
                                                 'real-f3-race-review')).fetchone())
        witness(control, a, b)
        a.execute('COMMIT')
        denied(future, 'authority denied')
        b.execute('ROLLBACK')
    finally:
        a.close(); b.close(); control.close()
        pool.shutdown(wait=True, cancel_futures=True)
    with connect() as root:
        check(root.execute('SELECT state FROM app_private.approval_requests WHERE id=%s',
                           (race_request['request_id'],)).fetchone()[0] == 'PENDING',
              'revoked reviewer left request pending')
        check(root.execute('SELECT count(*) FROM app_private.finance_fee_rule_revisions WHERE rule_id=%s',
                           (fee['resource_id'],)).fetchone()[0] == 2,
              'revoked reviewer produced no successor')
    token = None; reviewer_token = None; admin_key = None
    print('DB08_F3_REVIEW_RACE_PASS revocation_first observed_block=true pending_retained=true', flush=True)
