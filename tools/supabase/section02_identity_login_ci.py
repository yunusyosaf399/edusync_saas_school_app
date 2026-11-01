"""Real password/Auth + PostgreSQL acceptance, disposable loopback stack only."""
from __future__ import annotations

import json
import secrets
import subprocess
import sys
import time
from pathlib import Path
from uuid import UUID

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT))
from services.school_identity.login import (
    LoginDenied, PostgresLoginStore, SchoolLogin, SupabasePasswordAuth,
)
from _process import run
from foundation_local_ci import ensure_local_auth_route
from prepare_local_auth_fixtures import local_status, prepare
from foundation_guard import load_contract
from domain_local_ci import EXPECTED_PROJECT_ID, run_psql, run_foundation_regression, local_postgres_image_pin

SCHOOL = UUID('22222222-2222-4222-8222-222222222222')
FAMILY = UUID('44444444-4444-4444-8444-444444444444')
STAFF = UUID('55555555-5555-4555-8555-555555555555')
SYSTEM = UUID('11111111-1111-4111-8111-111111111111')
checks = 0


def check(value, label):
    global checks
    if not value:
        raise RuntimeError('IDENTITY_ACCEPTANCE_FAILED ' + label)
    checks += 1
    print('SECTION02_CHECK_PASS '+label,flush=True)


def denied(callback, label):
    try:
        callback()
    except LoginDenied as error:
        check(str(error) == 'Unable to sign in', label)
    else:
        raise RuntimeError('IDENTITY_EXPECTED_DENIAL ' + label)


def acceptance():
    import psycopg
    from psycopg import sql as compose
    worker_password=secrets.token_urlsafe(36)
    # Never accept a DSN/URL/role from CLI, env, client or a hosted project.
    def connection(role=None):
        c = psycopg.connect(host='127.0.0.1',port=54322,dbname='postgres',
            user='schoolos_identity_login' if role=='schoolos_identity_login' else 'postgres',
            password=worker_password if role=='schoolos_identity_login' else 'postgres')
        if role and role!='schoolos_identity_login':
            with c.cursor() as q:
                if role not in ('schoolos_identity_login', 'authenticated', 'anon', 'service_role'):
                    raise RuntimeError('LOCAL_ROLE_REQUIRED')
                q.execute('SET LOCAL ROLE ' + role)
        return c

    def sql(statement, parameters=()):
        with connection() as c, c.cursor() as q:
            q.execute(statement, parameters)
            return q.fetchall() if q.description else None

    with connection() as c,c.cursor() as q:
        q.execute(compose.SQL('ALTER ROLE schoolos_identity_login PASSWORD {}').format(compose.Literal(worker_password)))

    url, admin_key = local_status()
    ensure_local_auth_route(url)
    status = json.loads(run(['supabase', 'status', '-o', 'json'], cwd=ROOT, timeout=45))
    anon_key = status.get('ANON_KEY') or status.get('anon_key')
    if not anon_key:
        raise RuntimeError('LOCAL_ANON_KEY_REQUIRED')
    admin = SupabasePasswordAuth(url, admin_key, local_test=True)
    password = secrets.token_urlsafe(36)
    users = []
    for email in ('identity-family@example.invalid', 'identity-staff@example.invalid'):
        users.append(UUID(admin._request('POST', '/admin/users', payload={
            'email': email, 'password': password, 'email_confirm': True},token=admin_key)['id']))
    # Auth admin create returns 200 in the pinned local Auth version.
    sql("INSERT INTO app_private.principals(id,kind,label,system_purpose,state,created_by) VALUES(%s,'SYSTEM','Synthetic identity reconciliation','identity-reconciliation','ACTIVE',%s)", (SYSTEM,SYSTEM))
    sql("INSERT INTO app_private.school_profiles(id,code,name,timezone,currency_code,locale,state,created_by) VALUES(%s,'IDENTITY-TEST','Synthetic school','UTC','USD','en','ACTIVE',%s)", (SCHOOL,SYSTEM))
    sql("INSERT INTO app_private.people(id,display_name,created_by) VALUES(%s,'Synthetic staff',%s)", (STAFF,SYSTEM))
    sql("INSERT INTO app_private.principals(id,kind,person_id,label,state,created_by) VALUES(%s,'FAMILY',NULL,'Family','ACTIVE',%s),(%s,'INDIVIDUAL',%s,'Staff','ACTIVE',%s)", (FAMILY,SYSTEM,STAFF,STAFF,SYSTEM))
    for principal, kind, subject, alias in ((FAMILY,'FAMILY',users[0],'parent.one'),(STAFF,'INDIVIDUAL',users[1],'teacher.one')):
        sql("INSERT INTO app_private.principal_auth_bindings(principal_id,principal_kind,auth_user_id,bound_at,tokens_valid_from,created_by) VALUES(%s,%s,%s,clock_timestamp(),to_timestamp(floor(extract(epoch FROM clock_timestamp()))-2),%s)", (principal,kind,subject,SYSTEM))
        sql("INSERT INTO app_private.login_aliases(principal_id,normalized_alias,state,created_by) VALUES(%s,%s,'ACTIVE',%s)", (principal,alias,SYSTEM))
    # Disposable deployment catalog: absent in the candidate and in every real school.
    grant = sql("""WITH p AS (INSERT INTO app_private.permissions(code,state,created_by)
                 VALUES('identity.credential.suspend','ENABLED',%s) RETURNING id),
      r AS (INSERT INTO app_private.roles(code,label,state,created_by)
                 VALUES('identity-security-test','Synthetic security','ACTIVE',%s) RETURNING id),
      o AS (INSERT INTO app_private.operation_contracts(code,handler_key,request_permission_id,enabled,created_by)
                 SELECT 'identity.credential.suspend','SECTION02_SUSPEND_V1',p.id,true,%s FROM p)
      SELECT p.id,r.id FROM p,r""",(SYSTEM,SYSTEM,SYSTEM))[0]
    perm,role=grant
    sql("INSERT INTO app_private.permission_scope_contracts(permission_id,scope_kind,resolver_key,enabled,created_by) VALUES(%s,'ALL','DIRECT',true,%s)",(perm,SYSTEM))
    sql("INSERT INTO app_private.role_permission_grants(role_id,role_family_only,permission_id,permission_family_safe,valid_from,created_by) VALUES(%s,false,%s,false,clock_timestamp()-interval '1 minute',%s)",(role,perm,SYSTEM))
    sql("INSERT INTO app_private.principal_role_assignments(principal_id,principal_kind,role_id,role_family_only,context_kind,valid_from,created_by) VALUES(%s,'INDIVIDUAL',%s,false,'INDIVIDUAL',clock_timestamp()-interval '1 minute',%s)",(STAFF,role,SYSTEM))
    sql("""INSERT INTO app_private.assignment_permission_scopes
      (assignment_id,grant_id,role_id,permission_id,scope_contract_id,scope_kind,resolver_key,valid_from,created_by)
      SELECT a.id,g.id,%s,%s,c.id,'ALL','DIRECT',clock_timestamp()-interval '1 minute',%s
      FROM app_private.principal_role_assignments a,app_private.role_permission_grants g,
           app_private.permission_scope_contracts c WHERE a.principal_id=%s AND g.role_id=%s
           AND c.permission_id=%s""",(role,perm,SYSTEM,STAFF,role,perm))
    store = PostgresLoginStore(lambda: connection('schoolos_identity_login'))
    auth = SupabasePasswordAuth(url, anon_key, admin_key=admin_key, local_test=True)
    login = SchoolLogin(SCHOOL, store, auth, secrets.token_bytes(32))

    def sign(identifier='parent.one', source=None, secret=None):
        return login.sign_in(identifier, password if secret is None else secret,
                             trusted_source=source or secrets.token_hex(10))

    check(store.resolve(SCHOOL,'ALIAS','parent.one').principal_id == FAMILY,'private_alias_resolution')
    check(store.resolve(STAFF,'ALIAS','parent.one') is None,'wrong_school_denied')
    check(store.resolve(SCHOOL,'UNKNOWN','parent.one') is None,'unknown_identifier_kind')
    check(store.resolve(SCHOOL,'ALIAS','PARENT.ONE') is None,'unnormalized_private_alias_denied')
    check(sql("SELECT count(*) FROM app_private.identity_resolve_login(%s,'ALIAS','parent.one')",(SCHOOL,))[0][0] == 0,
          'postgres_cannot_impersonate_worker_session')
    check(not store.admit(['a'*64]),'missing_rate_policy_denies')
    for isolation in ('REPEATABLE READ','SERIALIZABLE'):
        with connection('schoolos_identity_login') as c,c.cursor() as q:
            q.execute('SET TRANSACTION ISOLATION LEVEL '+isolation)
            q.execute("SELECT count(*) FROM app_private.identity_resolve_login(%s,'ALIAS','parent.one')",(SCHOOL,))
            check(q.fetchone()[0]==0,'unsupported_isolation_lookup_'+isolation.replace(' ','_'))
            q.execute('SELECT app_private.identity_login_admit(%s::text[])',(['a'*64],))
            check(q.fetchone()[0] is False,'unsupported_isolation_meter_'+isolation.replace(' ','_'))
    sql('INSERT INTO app_private.identity_login_limits(max_attempts,window_seconds) VALUES(100,3600)')
    check(sign(' PARENT.ONE ').principal_id == FAMILY,'real_alias_password_auth')
    check(sign('IDENTITY-FAMILY@EXAMPLE.INVALID').principal_id == FAMILY,'real_email_password_auth')
    staff = sign('teacher.one')
    check(staff.principal_id == STAFF and staff.principal_kind == 'INDIVIDUAL','staff_family_isolated')
    denied(lambda: sign(secret='wrong-password'),'wrong_password')
    denied(lambda: sign('missing.alias'),'unknown_alias')
    denied(lambda: sign("x';SELECT"),'invalid_alias')
    sql("UPDATE app_private.principals SET state='SUSPENDED' WHERE id=%s",(FAMILY,))
    denied(lambda: sign(),'suspended_family')
    sql("UPDATE app_private.principals SET state='ACTIVE' WHERE id=%s",(FAMILY,))
    sql("UPDATE app_private.login_aliases SET state='RETIRED' WHERE principal_id=%s",(FAMILY,))
    denied(lambda: sign(),'retired_alias')
    check(sign('identity-family@example.invalid').principal_id == FAMILY,'retired_alias_does_not_retire_account')
    sql("UPDATE app_private.login_aliases SET state='ACTIVE' WHERE principal_id=%s",(FAMILY,))
    sql("UPDATE app_private.people SET state='INACTIVE' WHERE id=%s",(STAFF,))
    denied(lambda: sign('teacher.one'),'inactive_person')
    sql("UPDATE app_private.people SET state='ACTIVE' WHERE id=%s",(STAFF,))
    sql("UPDATE app_private.principals SET state='SUSPENDED' WHERE id=%s",(SYSTEM,))
    check(store.resolve(SCHOOL,'ALIAS','parent.one') is None,'disabled_worker_purpose_denies')
    check(not store.admit(['d'*64]),'disabled_worker_purpose_blocks_meter')
    sql("UPDATE app_private.principals SET state='ACTIVE' WHERE id=%s",(SYSTEM,))
    sql("UPDATE app_private.school_profiles SET state='INACTIVE' WHERE id=%s",(SCHOOL,))
    denied(lambda: sign(),'inactive_school')
    sql("UPDATE app_private.school_profiles SET state='ACTIVE' WHERE id=%s",(SCHOOL,))

    class SuspendDuringAuth:
        def email_for_subject(self,subject):
            return auth.email_for_subject(subject)
        def authenticate(self,email,secret):
            session=auth.authenticate(email,secret)
            sql("UPDATE app_private.principals SET state='SUSPENDED' WHERE id=%s",(FAMILY,))
            return session
    race=SchoolLogin(SCHOOL,store,SuspendDuringAuth(),secrets.token_bytes(32))
    denied(lambda:race.sign_in('parent.one',password,trusted_source='race'),'live_post_password_suspension')
    sql("UPDATE app_private.principals SET state='ACTIVE' WHERE id=%s",(FAMILY,))
    def suspend(subject,target=FAMILY,expected=1,key='suspend-1',reason='Account recovery hold'):
        with connection() as c,c.cursor() as q:
            q.execute("SELECT set_config('request.jwt.claim.sub',%s,true)",(str(subject),))
            q.execute("SELECT set_config('request.jwt.claims',jsonb_build_object('sub',%s::text,'role','authenticated','is_anonymous',false,'iat',floor(extract(epoch FROM clock_timestamp()))::bigint)::text,true)",(str(subject),))
            q.execute('SET LOCAL ROLE authenticated')
            q.execute('SELECT app.section02_suspend_credential(%s,%s,%s,%s)',(target,expected,reason,key))
            return q.fetchone()[0]
    def rejected(callback,label):
        try: callback()
        except psycopg.Error: check(True,label)
        else: raise RuntimeError('IDENTITY_EXPECTED_COMMAND_DENIAL '+label)
    family_version=sql('SELECT row_version FROM app_private.principals WHERE id=%s',(FAMILY,))[0][0]
    check(sql("SELECT has_table_privilege('schoolos_identity_executor','auth.users','SELECT')")[0][0] is False,
          'identity_executor_no_managed_auth_read')
    check(sql("SELECT has_function_privilege('anon','app.section02_suspend_credential(uuid,bigint,text,text)','EXECUTE')")[0][0] is False,
          'anonymous_cannot_suspend')
    check(sql("SELECT has_function_privilege('authenticated','app_private.section02_suspension_evidence(uuid,uuid,uuid,bigint,text,text,bytea,uuid)','EXECUTE')")[0][0] is False,
          'client_cannot_write_evidence')
    rejected(lambda:suspend(users[0],expected=family_version,key='family-attempt'),'family_cannot_suspend')
    rejected(lambda:suspend(users[1],target=STAFF,expected=1,key='self-attempt'),'self_cannot_suspend')
    rejected(lambda:suspend(users[1],expected=family_version-1,key='stale-attempt'),'stale_target_denied')
    sql("UPDATE app_private.permissions SET state='DISABLED' WHERE id=%s",(perm,))
    rejected(lambda:suspend(users[1],expected=family_version,key='disabled-grant'),'disabled_permission_denied')
    sql("UPDATE app_private.permissions SET state='ENABLED' WHERE id=%s",(perm,))
    receipt=suspend(users[1],expected=family_version)
    check(receipt==suspend(users[1],expected=family_version),'suspend_idempotent_replay')
    check(sql("SELECT state FROM app_private.principals WHERE id=%s",(FAMILY,))[0][0]=='SUSPENDED','protected_suspension_live')
    denied(lambda:sign('identity-family@example.invalid'),'suspended_email_denied')
    check(sql('SELECT count(*) FROM app_private.audit_events WHERE command_receipt_id=%s',(receipt,))[0][0]==1,'suspend_one_audit')
    check(sql('SELECT count(*) FROM app_private.outbox_events WHERE command_receipt_id=%s',(receipt,))[0][0]==1,'suspend_one_outbox')
    rejected(lambda:suspend(users[1],expected=family_version,key='suspend-1',reason='Different reason'),'changed_intent_denied')
    rejected(lambda:suspend(users[1],expected=family_version,key='second-key'),'repeat_effect_denied')
    sql("UPDATE app_private.principals SET state='ACTIVE' WHERE id=%s",(FAMILY,))
    sql("UPDATE app_private.principal_auth_bindings SET auth_user_id=NULL WHERE principal_id=%s",(FAMILY,))
    denied(lambda:sign(),'unbound_credential')
    check(sql('SELECT count(*) FROM app_private.principal_binding_events WHERE principal_id=%s',(FAMILY,))[0][0] == 2,'binding_history_retained')
    # No alias lookup, throttle manipulation or private mapping reads by clients.
    for role in ('authenticated','anon','service_role'):
        for signature in ('app_private.identity_resolve_login(uuid,text,text)',
                          'app_private.identity_login_admit(text[])'):
            check(sql('SELECT has_function_privilege(%s,%s,\'EXECUTE\')',(role,signature))[0][0] is False,
                  'no_client_execute_grant_'+role)
    for role in ('authenticated','anon','service_role'):
        for statement in ("SELECT * FROM app_private.identity_resolve_login('22222222-2222-4222-8222-222222222222','ALIAS','parent.one')",
                          "SELECT app_private.identity_login_admit(ARRAY[repeat('a',64)])",
                          'SELECT * FROM app_private.login_aliases'):
            try:
                with connection(role) as c,c.cursor() as q:
                    q.execute('SELECT current_user')
                    check(q.fetchone()[0]==role,'client_role_fixture_'+role)
                    q.execute(statement)
            except psycopg.errors.InsufficientPrivilege:
                check(True,'client_privilege_denial_'+role)
            else:
                raise RuntimeError('IDENTITY_CLIENT_PRIVILEGE_LEAK')
    sql('UPDATE app_private.identity_login_limits SET max_attempts=2')
    check(store.admit(['b'*64]),'rate_first_attempt')
    check(store.admit(['b'*64]),'rate_second_attempt')
    check(not store.admit(['b'*64]),'rate_third_denied')
    check(not store.admit(['b'*64]),'denied_rate_charge_persists')
    check(not store.admit([]),'empty_rate_keys')
    check(not store.admit(['invalid']),'invalid_rate_keys')
    check(sql('SELECT count(*) FROM app_private.identity_login_attempts WHERE key_digest=%s',('b'*64,))[0][0] == 1,'one_bucket_per_digest')
    # Real two-session counter contention: exactly one remaining admission.
    from concurrent.futures import ThreadPoolExecutor
    check(store.admit(['c'*64]),'race_seed_first_attempt')
    with ThreadPoolExecutor(max_workers=2) as pool:
        outcomes=list(pool.map(lambda _:store.admit(['c'*64]),range(2)))
    check(sorted(outcomes)==[False,True],'atomic_multisession_rate_fence')
    print('SECTION02_IDENTITY_LOGIN_PASS '+str(checks)+' real Auth/PostgreSQL assertions; no hosted access')


def _main():
    started=False
    stage='start'
    try:
        run(['supabase','start'],cwd=ROOT,timeout=900)
        started=True
        run(['supabase','db','reset','--local','--no-seed'],cwd=ROOT,timeout=900)
        local_status()
        stage='failed_install_rollback'
        candidate=(ROOT/'supabase/proposals/section02_identity_login.sql.draft').read_text()
        container='supabase_db_'+EXPECTED_PROJECT_ID
        # Prove failed installation leaves no worker functions/tables/roles.
        try:
            run_psql(container,'BEGIN;\n'+candidate+"\nSELECT 1/0; COMMIT;",'SECTION02_ROLLBACK')
        except RuntimeError:
            pass
        else:
            raise RuntimeError('INJECTED_INSTALL_FAILURE_MISSING')
        probe=run_psql(container,"SELECT count(*) FROM pg_roles WHERE rolname='schoolos_login_executor';",'SECTION02_ROLLBACK_PROBE',tuples=True)
        if probe.strip()!='0':raise RuntimeError('SECTION02_ROLLBACK_ROLE_LEAK')
        stage='candidate_install'
        run_psql(container,'BEGIN;\n'+candidate+'\nCOMMIT;','SECTION02_INSTALL')
        stage='credential_failed_install_rollback'
        lifecycle=(ROOT/'supabase/proposals/section02_credential_suspend.sql.draft').read_text()
        try:
            run_psql(container,'BEGIN;\n'+lifecycle+'\nSELECT 1/0; COMMIT;','SECTION02_CREDENTIAL_ROLLBACK')
        except RuntimeError:
            pass
        else:raise RuntimeError('CREDENTIAL_INJECTED_FAILURE_MISSING')
        probe=run_psql(container,"SELECT count(*) FROM pg_proc WHERE proname='section02_suspend_credential';",'SECTION02_CREDENTIAL_PROBE',tuples=True)
        if probe.strip()!='0':raise RuntimeError('CREDENTIAL_ROLLBACK_LEAK')
        stage='credential_candidate_install'
        run_psql(container,'BEGIN;\n'+lifecycle+'\nCOMMIT;','SECTION02_CREDENTIAL_INSTALL')
        stage='post_extension_foundation_regression'
        fixture_url, fixture_key=local_status()
        ensure_local_auth_route(fixture_url)
        prepare(fixture_url,fixture_key).clear()
        fixture_key=None
        total=run_foundation_regression(load_contract())
        if total!=176:raise RuntimeError('POST_EXTENSION_FOUNDATION_COUNT')
        print('SECTION02_POST_EXTENSION_FOUNDATION_PASS 176/176',flush=True)
        stage='auth_database_acceptance'
        acceptance()
        return 0
    except Exception as error:
        # The fixture contains transient passwords/keys. Never dump locals,
        # HTTP errors, SQL parameters, driver connection details or traceback.
        print('SECTION02_IDENTITY_LOGIN_FAIL stage='+stage+' checks='+str(checks)
              +' error_class='+type(error).__name__
              +' sqlstate='+str(getattr(error,'sqlstate',None))
              +' constraint='+str(getattr(getattr(error,'diag',None),'constraint_name',None)),file=sys.stderr)
        if isinstance(error, __import__('psycopg').errors.InsufficientPrivilege):
            # PostgreSQL's fixed privilege object name is safe; do not print
            # statements, parameters, driver detail, context or credentials.
            print('SECTION02_PRIVILEGE_OBJECT '+str(error.diag.message_primary),file=sys.stderr)
        if str(error).startswith('IDENTITY_'):
            print(str(error),file=sys.stderr)
        if stage in ('candidate_install','failed_install_rollback','credential_candidate_install','credential_failed_install_rollback'):
            # This stage executes static source only, never secret parameters.
            print(str(error)[-2000:],file=sys.stderr)
        if started:
            # Log engine failure categories only, never SQL/credentials/requests.
            result=subprocess.run(['docker','logs','--tail','120','supabase_db_'+EXPECTED_PROJECT_ID],
                cwd=ROOT,text=True,capture_output=True,timeout=20)
            for line in (result.stdout+'\n'+result.stderr).splitlines():
                if any(marker in line.lower() for marker in
                       ('terminated by signal','segmentation fault','panic:', 'reinitializing')):
                    print('SECTION02_DB_ENGINE_DIAGNOSTIC '+line,file=sys.stderr)
        return 1
    finally:
        if started:run(['supabase','stop','--project-id',EXPECTED_PROJECT_ID],cwd=ROOT,timeout=300)


def main():
    # Use the same reviewed disposable PostgreSQL image as D1 acceptance.
    # Restore any prior CLI cache bytes on success or failure.
    with local_postgres_image_pin():
        return _main()


if __name__=='__main__':sys.exit(main())
