"""Real local Auth token over the D1-backed Finance SQL commands; rollback-only."""
import json
import secrets
import urllib.request


def run_selection_runtime(local_status, root):
    import psycopg
    from services.admission_documents.adapters import SupabaseAuthenticator, _NoRedirect

    url, admin_key = local_status()
    opener = urllib.request.build_opener(_NoRedirect(), urllib.request.ProxyHandler({}))
    with psycopg.connect(host='127.0.0.1', port=54322, dbname='postgres',
                         user='postgres', password='postgres', autocommit=True) as connection:
        connection.execute('BEGIN')
        try:
            connection.execute((root / 'supabase/tests/db08/fixture_commands.sql').read_text())
            connection.execute((root / 'supabase/tests/db08/fixture_selection.sql').read_text())
            subject = connection.execute(
                "SELECT auth_user_id::text FROM app_private.principal_auth_bindings "
                "WHERE id='08000000-0000-4000-8000-000000000008'").fetchone()[0]
            password = secrets.token_urlsafe(36)
            req = urllib.request.Request(url + '/auth/v1/admin/users/' + subject,
                data=json.dumps({'password': password}).encode(), method='PUT',
                headers={'apikey': admin_key, 'Authorization': 'Bearer ' + admin_key,
                         'Content-Type': 'application/json'})
            with opener.open(req, timeout=20):
                pass
            req = urllib.request.Request(url + '/auth/v1/token?grant_type=password',
                data=json.dumps({'email': 'foundation-rbac-001@example.invalid',
                                 'password': password}).encode(), method='POST',
                headers={'apikey': admin_key, 'Authorization': 'Bearer ' + admin_key,
                         'Content-Type': 'application/json'})
            with opener.open(req, timeout=20) as response:
                token = json.load(response)['access_token']
            password = None
            claims = SupabaseAuthenticator(url, admin_key, allow_local_test=True)(token)
            connection.execute("SELECT set_config('request.jwt.claim.sub',%s,true)",
                               (claims.subject,))
            connection.execute("SELECT set_config('request.jwt.claims',%s,true)",
                               (json.dumps(claims.database_claims()),))
            connection.execute('SET LOCAL ROLE authenticated')

            def fee(rule, amount, key):
                return connection.execute(
                    "SELECT app.configure_finance_fee(%s::uuid,%s::uuid,'TUITION','Tuition',"
                    "%s,'MONTHLY',2,%s::numeric,'2026-01-01'::date,'2026-12-31'::date,"
                    "'Real Auth F5 full price',%s)",
                    ('08000000-0000-4000-8000-000000000003',
                     '08000000-0000-4000-8000-000000000004',
                     rule, amount, key)).fetchone()[0]

            default = fee('AUTH_F5_CLASS', 10000, 'auth-f5-class-rule')
            specific = fee('AUTH_F5_STUDENT', 15000, 'auth-f5-student-rule')
            offering = '08000000-0000-4000-8000-000000000055'
            student = '08000000-0000-4000-8000-000000000059'

            def bind(rule, who, key):
                return connection.execute(
                    "SELECT app.bind_finance_fee(%s::uuid,%s::uuid,%s::uuid,"
                    "'2026-11-01'::date,'2026-12-31'::date,%s)",
                    (rule, offering, who, key)).fetchone()[0]

            class_binding = bind(default['resource_id'], None, 'auth-f5-class-bind')
            student_binding = bind(specific['resource_id'], student, 'auth-f5-student-bind')
            if bind(default['resource_id'], None, 'auth-f5-class-bind') != class_binding:
                raise RuntimeError('DB08_F5_REAL_AUTH_BIND_REPLAY')

            def assess(who, key):
                return connection.execute(
                    "SELECT app.assess_selected_finance_fee(%s::uuid,%s::uuid,"
                    "'TUITION','MONTHLY','2026-11-01'::date,'2026-11-30'::date,"
                    "'2026-12-05'::date,%s::uuid)",
                    (who, offering, key)).fetchone()[0]

            one_key = '08000000-0000-4000-8000-000000000071'
            two_key = '08000000-0000-4000-8000-000000000072'
            selected = assess(student, one_key)
            if assess(student, one_key) != selected:
                raise RuntimeError('DB08_F5_REAL_AUTH_CHARGE_REPLAY')
            other = assess('08000000-0000-4000-8000-000000000060', two_key)
            connection.execute('RESET ROLE')
            rows = connection.execute(
                "SELECT o.id::text,o.gross_amount_minor::bigint,x.applicability_id::text "
                "FROM app_private.finance_fee_obligations o "
                "JOIN app_private.finance_fee_assessment_selections x ON x.obligation_id=o.id "
                "WHERE o.id IN (%s::uuid,%s::uuid)",
                (selected['resource_id'], other['resource_id'])).fetchall()
            observed = {item[0]: (item[1], item[2]) for item in rows}
            if (observed.get(selected['resource_id']) != (15000, student_binding['binding_id'])
                or observed.get(other['resource_id']) != (10000, class_binding['binding_id'])):
                raise RuntimeError('DB08_F5_REAL_AUTH_WRONG_PRICE_SOURCE')
            print('DB08_F5_REAL_AUTH_PASS verified_token=true class_default=true '
                  'student_full_price=true binding_replay=true charge_replay=true', flush=True)
        finally:
            connection.execute('ROLLBACK')
    token = None
    admin_key = None
