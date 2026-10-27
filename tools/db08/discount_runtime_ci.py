"""Real local Auth requester/reviewer on F6, inside a rollback-only SQL transaction."""
import json
import secrets
import urllib.request


def run_discount_runtime(local_status, root):
    import psycopg
    from services.admission_documents.adapters import SupabaseAuthenticator, _NoRedirect

    url, admin_key = local_status()
    opener = urllib.request.build_opener(_NoRedirect(), urllib.request.ProxyHandler({}))
    with psycopg.connect(host='127.0.0.1', port=54322, dbname='postgres',
                         user='postgres', password='postgres', autocommit=True) as connection:
        connection.execute('BEGIN')
        try:
            for fixture in ('fixture_commands.sql', 'fixture_change.sql',
                            'fixture_selection.sql', 'fixture_discount.sql'):
                connection.execute((root / 'supabase/tests/db08' / fixture).read_text())
            verified = []
            for email, binding in (
                    ('foundation-rbac-001@example.invalid', '08000000-0000-4000-8000-000000000008'),
                    ('foundation-own-001@example.invalid', '08000000-0000-4000-8000-000000000022')):
                subject = connection.execute(
                    "SELECT auth_user_id::text FROM app_private.principal_auth_bindings WHERE id=%s::uuid",
                    (binding,)).fetchone()[0]
                password = secrets.token_urlsafe(36)
                req = urllib.request.Request(url + '/auth/v1/admin/users/' + subject,
                    data=json.dumps({'password': password}).encode(), method='PUT',
                    headers={'apikey': admin_key, 'Authorization': 'Bearer ' + admin_key,
                             'Content-Type': 'application/json'})
                with opener.open(req, timeout=20):
                    pass
                req = urllib.request.Request(url + '/auth/v1/token?grant_type=password',
                    data=json.dumps({'email': email, 'password': password}).encode(),
                    method='POST', headers={'apikey': admin_key,
                    'Authorization': 'Bearer ' + admin_key, 'Content-Type': 'application/json'})
                with opener.open(req, timeout=20) as response:
                    token = json.load(response)['access_token']
                password = None
                verified.append(SupabaseAuthenticator(url, admin_key, allow_local_test=True)(token))
                token = None

            def call_as(index, query, params=()):
                claims = verified[index]
                connection.execute("SELECT set_config('request.jwt.claim.sub',%s,true)",
                                   (claims.subject,))
                connection.execute("SELECT set_config('request.jwt.claims',%s,true)",
                                   (json.dumps(claims.database_claims()),))
                connection.execute('SET LOCAL ROLE authenticated')
                try:
                    return connection.execute(query, params).fetchone()[0]
                finally:
                    connection.execute('RESET ROLE')

            campus = '08000000-0000-4000-8000-000000000003'
            year = '08000000-0000-4000-8000-000000000004'
            offering = '08000000-0000-4000-8000-000000000055'
            student = '08000000-0000-4000-8000-000000000060'
            policy = '08000000-0000-4000-8000-000000000090'
            reviewer = '08000000-0000-4000-8000-000000000021'
            rule = call_as(0, "SELECT app.configure_finance_fee(%s::uuid,%s::uuid,"
                           "'TUITION','Tuition','AUTH_F6_CLASS','MONTHLY',2,9999,"
                           "'2026-01-01'::date,'2026-12-31'::date,'Real Auth full fee','auth-f6-fee')",
                           (campus, year))
            call_as(0, "SELECT app.bind_finance_fee(%s::uuid,%s::uuid,NULL,"
                    "'2026-11-01'::date,'2026-12-31'::date,'auth-f6-bind')",
                    (rule['resource_id'], offering))
            def request():
                return call_as(0, "SELECT app.request_finance_discount(%s::uuid,%s::uuid,"
                    "'MONTHLY_TUITION','PERCENT',10,'2026-11-01'::date,'2026-12-31'::date,"
                    "NULL,%s::uuid,%s::uuid,'Real Auth monthly tuition','auth-f6-request')",
                    (student, campus, policy, reviewer))
            pending = request()
            if request() != pending or pending['state'] != 'PENDING':
                raise RuntimeError('DB08_F6_REAL_AUTH_REQUEST_REPLAY')
            def review():
                return call_as(1, "SELECT app.review_finance_discount(%s::uuid,'APPROVE',"
                    "%s::bigint,'Independent real Auth review','auth-f6-review')",
                    (pending['request_id'], pending['request_version']))
            approved = review()
            if review() != approved or approved['state'] != 'EXECUTED':
                raise RuntimeError('DB08_F6_REAL_AUTH_REVIEW_REPLAY')
            key = '08000000-0000-4000-8000-000000000094'
            def assess():
                return call_as(0, "SELECT app.assess_discounted_finance_fee(%s::uuid,%s::uuid,"
                    "'TUITION','MONTHLY','2026-11-01'::date,'2026-11-30'::date,"
                    "'2026-12-05'::date,%s::uuid)", (student, offering, key))
            selected = assess()
            if (assess() != selected
                or selected['discount']['discount_minor'] != 1000
                or selected['discount']['net_minor'] != 8999):
                raise RuntimeError('DB08_F6_REAL_AUTH_DISCOUNT_REPLAY')
            retained = connection.execute(
                "SELECT o.gross_amount_minor::bigint,a.discount_minor::bigint,a.net_minor::bigint "
                "FROM app_private.finance_fee_obligations o "
                "JOIN app_private.finance_discount_adjustments a ON a.obligation_id=o.id "
                "WHERE o.id=%s::uuid", (selected['charge']['resource_id'],)).fetchone()
            if retained != (9999, 1000, 8999):
                raise RuntimeError('DB08_F6_REAL_AUTH_RETAINED_FACTS')
            print('DB08_F6_REAL_AUTH_PASS requester_verified=true reviewer_verified=true '
                  'independent_approval=true two_decimal_rounding=true replays=true', flush=True)
        finally:
            connection.execute('ROLLBACK')
    verified = None
    admin_key = None
