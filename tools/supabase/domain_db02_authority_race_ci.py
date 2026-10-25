"""DB-02 T06: real Foundation authorization-lock races (local only)."""
from __future__ import annotations

import re
import subprocess
import time

from domain_concurrency_ci import CONTAINER, ROOT
from domain_db02_policy_race_ci import ACTORS, SCHOOL, SOURCE, _worker_sql, _start

DIRECT = ('grant', 'scope', 'role', 'route', 'command_first')
APPLY = ('reviewer_grant', 'reviewer_role', 'approval_version')
UUID = re.compile(r'^[0-9a-f]{8}(?:-[0-9a-f]{4}){3}-[0-9a-f]{12}$')


def _check(ok: bool, code: str) -> None:
    if not ok:
        raise RuntimeError('DB02_T06_' + code)


def _auth(actor: str) -> str:
    email, binding = ACTORS[actor]
    return f"""SELECT set_config('request.jwt.claim.sub',
 (SELECT id::text FROM auth.users WHERE email='{email}'),true);
SELECT set_config('request.jwt.claims',pg_catalog.jsonb_build_object(
 'sub',current_setting('request.jwt.claim.sub'),'role','authenticated',
 'iat',(SELECT extract(epoch FROM tokens_valid_from)::bigint
 FROM app_private.principal_auth_bindings WHERE id='{binding}'),
 'is_anonymous',false)::text,true);
SET ROLE authenticated;
"""


def _mutation(kind: str) -> str:
    if kind in ('grant', 'command_first'):
        return """UPDATE app_private.role_permission_grants
 SET revoked_at=pg_catalog.clock_timestamp()
 WHERE id='b4400000-0000-4000-8000-000000000004';"""
    if kind == 'scope':
        return """UPDATE app_private.assignment_permission_scopes
 SET revoked_at=pg_catalog.clock_timestamp()
 WHERE id='b4400000-0000-4000-8000-000000000005';"""
    if kind == 'role':
        return """UPDATE app_private.roles SET state='RETIRED'
 WHERE id='aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa';"""
    if kind in ('route', 'approval_version'):
        old = ('b4400000-0000-4000-8000-000000000007' if kind == 'route'
               else 'b6600000-0000-4000-8000-000000000005')
        successor = ('b6700000-0000-4000-8000-000000000007' if kind == 'route'
                     else 'b6700000-0000-4000-8000-000000000008')
        step = ('b6700000-0000-4000-8000-000000000009' if kind == 'route'
                else 'b6700000-0000-4000-8000-00000000000a')
        reviewer = ('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa' if kind == 'route'
                    else 'b6600000-0000-4000-8000-000000000001')
        return f"""UPDATE app_private.approval_policy_versions SET state='RETIRED'
 WHERE id='{old}';
INSERT INTO app_private.approval_policy_versions(id,policy_key,version,
 operation_id,d1_route_mode,created_by)
SELECT '{successor}','t06-successor-{kind}',1,id,'APPROVAL',
 '11111111-1111-4111-8111-111111111111'
FROM app_private.operation_contracts WHERE code='student.roll_policy.change';
INSERT INTO app_private.approval_step_templates(id,policy_id,step_number,
 reviewer_role_id,required_reviews,selection_resolver_key,created_by)
VALUES ('{step}','{successor}',1,'{reviewer}',1,
 'D1_REVIEWER_ROLE_SCOPE','11111111-1111-4111-8111-111111111111');
UPDATE app_private.approval_policy_versions SET state='ACTIVE',
 effective_from=pg_catalog.statement_timestamp()-interval '1 hour',
 activated_at=pg_catalog.statement_timestamp() WHERE id='{successor}';"""
    if kind == 'reviewer_grant':
        return """UPDATE app_private.role_permission_grants
 SET revoked_at=pg_catalog.clock_timestamp()
 WHERE id='b6600000-0000-4000-8000-000000000003';"""
    if kind == 'reviewer_role':
        return """UPDATE app_private.roles SET state='RETIRED'
 WHERE id='b6600000-0000-4000-8000-000000000001';"""
    raise RuntimeError('DB02_T06_UNKNOWN_MUTATION')


def _revoke(kind: str, *, hold: bool) -> str:
    name = 'db02-t06-owner-' + kind
    return (f"BEGIN;\nSET LOCAL application_name='{name}';\n"
            'SELECT pg_catalog.pg_advisory_xact_lock(71001,1);\n'
            'SET ROLE schoolos_schema_owner;\n' + _mutation(kind) +
            '\nRESET ROLE;\n' +
            ('SELECT pg_catalog.pg_sleep(5);\n' if hold else '') +
            'COMMIT;\n')


def _observe(container: str, execute_sql, process: subprocess.Popen,
             waiter: str, holder: str | None, mode: str) -> None:
    _check(mode in ('ShareLock','ExclusiveLock'), 'BAD_LOCK_MODE')
    if holder is None:
        probe = f"""SELECT CASE WHEN EXISTS (
 SELECT 1 FROM pg_catalog.pg_stat_activity a
 JOIN pg_catalog.pg_locks l ON l.pid=a.pid
 WHERE a.application_name='{waiter}' AND a.wait_event='PgSleep'
   AND l.locktype='advisory' AND l.classid=71001 AND l.objid=1
   AND l.granted AND l.mode='{mode}') THEN 1 ELSE 0 END;"""
    else:
        reverse = 'ExclusiveLock' if mode == 'ShareLock' else 'ShareLock'
        probe = f"""SELECT CASE WHEN EXISTS (
 SELECT 1 FROM pg_catalog.pg_stat_activity a
 JOIN pg_catalog.pg_locks l ON l.pid=a.pid
 WHERE a.application_name='{waiter}' AND a.wait_event_type='Lock'
   AND l.locktype='advisory' AND l.classid=71001 AND l.objid=1
   AND NOT l.granted AND l.mode='{mode}'
   AND EXISTS (SELECT 1 FROM pg_catalog.unnest(pg_catalog.pg_blocking_pids(a.pid)) b(pid)
     JOIN pg_catalog.pg_stat_activity h ON h.pid=b.pid
     JOIN pg_catalog.pg_locks granted ON granted.pid=h.pid
     WHERE h.application_name='{holder}' AND granted.granted
       AND granted.locktype='advisory' AND granted.classid=71001
       AND granted.objid=1 AND granted.mode='{reverse}'))
 THEN 1 ELSE 0 END;"""
    deadline=time.monotonic()+12
    while time.monotonic()<deadline:
        if process.poll() is not None:
            out,err=process.communicate(timeout=5)
            raise RuntimeError('DB02_T06_WORKER_EXITED_BEFORE_WAIT '+waiter+
                               ' rc='+str(process.returncode)+' out='+repr(out[-250:])+
                               ' err='+repr(err[-450:]))
        if execute_sql(container,probe,'DB02_T06_ADVISORY_PROBE',
                       tuples=True,timeout=10).strip()=='1':
            return
        time.sleep(.05)
    raise RuntimeError('DB02_T06_EXACT_ADVISORY_WAIT_MISSING '+waiter)


def _finish(process: subprocess.Popen, name: str) -> tuple[int,str,str]:
    out,err=process.communicate(timeout=25)
    return process.returncode,out,err


def _direct_evidence(container: str, execute_sql, *, success: bool,
                     key: str) -> None:
    q=f"""SELECT count(*) FROM app_private.roll_policy_revisions WHERE school_id='{SCHOOL}';
SELECT count(*) FROM app_private.roll_policy_revisions WHERE id='{SOURCE}'
 AND effective_until IS {'NOT NULL' if success else 'NULL'};
SELECT count(*) FROM app_private.roll_allocator_states;
SELECT count(*) FROM app_private.command_receipts WHERE idempotency_key='{key}';
SELECT count(*) FROM app_private.outbox_events WHERE event_type='student.roll_policy_changed';
"""
    got=execute_sql(container,q,'DB02_T06_DIRECT_EVIDENCE',tuples=True).split()
    want=['2','1','2','1','1'] if success else ['1','1','1','0','0']
    _check(got==want,'DIRECT_EFFECT_MISMATCH '+','.join(got))


def _setup(container: str, execute_sql, fresh_database, *, approval: bool) -> str:
    fresh_database()
    fixture=ROOT/'supabase/tests/domain/fixtures'
    actor=(fixture/'command_actor.sql').read_text()
    t04=(fixture/'db02_t04_two_backend_race_setup.sql').read_text()
    extra=(fixture/'db02_t06_approval_setup.sql').read_text() if approval else ''
    execute_sql(container,"BEGIN;\nSELECT set_config('schoolos_test.t04_action','REPLACE',true);\n"+
                actor+'\n'+t04+'\n'+extra+'\nCOMMIT;',
                'DB02_T06_SETUP',timeout=90)
    date=execute_sql(container,f"SELECT effective_from::text FROM app_private.roll_policy_revisions WHERE id='{SOURCE}';",
                     'DB02_T06_SOURCE_DATE',tuples=True).strip()
    _check(re.fullmatch(r'\d{4}-\d{2}-\d{2}',date) is not None,'SOURCE_DATE')
    return date


def _approved_request(container: str, execute_sql, date: str) -> str:
    setup=("BEGIN;\n"+_auth('b')+f"""SELECT request_id::text FROM app.d1_submit_student_roll_policy_change(
 '{SCHOOL}','REPLACE','{SOURCE}',1,'PERSISTENT_STUDENT',5000,
 '{date}'::date,'PERSISTENT_STUDENT',6200,
 'T06 independent approved request','db02-t06-submit');
RESET ROLE;\nCOMMIT;""")
    out=execute_sql(container,setup,'DB02_T06_SUBMIT',tuples=True,timeout=60)
    ids=[line for line in out.splitlines() if UUID.fullmatch(line)]
    _check(len(ids)>=1,'SUBMIT_RESULT '+repr(out[-250:]))
    request=ids[-1]
    review=("BEGIN;\n"+_auth('a')+f"""SELECT request_state::text FROM app.d1_review_student_roll_policy_change(
 '{request}','APPROVE',3,'T06 independent review','db02-t06-review');
RESET ROLE;\nCOMMIT;""")
    out=execute_sql(container,review,'DB02_T06_REVIEW',tuples=True,timeout=60)
    _check('APPROVED' in out.splitlines(),'REVIEW_RESULT '+repr(out[-250:]))
    return request


def _apply(request: str, kind: str) -> str:
    key='db02-t06-apply-'+kind
    return (f"BEGIN;\nSET LOCAL application_name='db02-t06-apply-{kind}';\n"+
            _auth('b')+f"""SELECT request_state||'|'||request_version::text||'|'||
 COALESCE(policy_revision_id::text,'') FROM app.d1_apply_student_roll_policy_change(
 '{request}',4,'{key}');
RESET ROLE;\nCOMMIT;""")


def _apply_evidence(container: str, execute_sql, request: str, kind: str) -> None:
    key='db02-t06-apply-'+kind
    q=f"""SELECT count(*) FROM app_private.roll_policy_revisions WHERE school_id='{SCHOOL}';
SELECT count(*) FROM app_private.roll_policy_revisions WHERE id='{SOURCE}' AND effective_until IS NULL;
SELECT count(*) FROM app_private.roll_allocator_states;
SELECT count(*) FROM app_private.approval_requests WHERE id='{request}'
 AND state='INVALIDATED' AND row_version=5;
SELECT count(*) FROM app_private.command_receipts WHERE idempotency_key='{key}'
 AND command_kind='request.apply' AND state='REJECTED';
SELECT count(*) FROM app_private.approval_applications WHERE request_id='{request}';
SELECT count(*) FROM app_private.outbox_events WHERE event_type='student.roll_policy_changed';
"""
    got=execute_sql(container,q,'DB02_T06_APPLY_EVIDENCE',tuples=True).split()
    _check(got==['1','1','1','1','1','0','0'],
           'APPLY_EFFECT_MISMATCH '+kind+' '+','.join(got))


def run_db02_authority_races(container: str, execute_sql, fresh_database) -> None:
    _check(container==CONTAINER,'DISPOSABLE_ONLY')
    for kind in DIRECT+APPLY:
        date=_setup(container,execute_sql,fresh_database,approval=kind in APPLY)
        request=_approved_request(container,execute_sql,date) if kind in APPLY else None
        workers=[]
        try:
            if kind=='command_first':
                first=_start(_worker_sql('REPLACE','commit','a',date,holder=True)
                             .replace('db02-t04-replace-commit-a','db02-t06-direct-first'))
                workers.append(first)
                _observe(container,execute_sql,first,'db02-t06-direct-first',None,'ShareLock')
                second=_start(_revoke(kind,hold=False));workers.append(second)
                _observe(container,execute_sql,second,'db02-t06-owner-command_first',
                         'db02-t06-direct-first','ExclusiveLock')
                rc,out,err=_finish(first,'direct-first')
                _check(rc==0 and any(UUID.fullmatch(x) for x in out.splitlines()),
                       'DIRECT_FIRST_FAIL '+repr(err[-400:]))
                rc,out,err=_finish(second,'revoke-after')
                _check(rc==0,'REVOKE_AFTER_FAIL '+repr(err[-400:]))
                _direct_evidence(container,execute_sql,success=True,
                                 key='db02-t06-direct-first')
            else:
                first=_start(_revoke(kind,hold=True));workers.append(first)
                _observe(container,execute_sql,first,'db02-t06-owner-'+kind,None,
                         'ExclusiveLock')
                if kind in APPLY:
                    second=_start(_apply(request,kind))
                    waiter='db02-t06-apply-'+kind
                else:
                    second=_start(_worker_sql('REPLACE','commit','a',date,holder=False)
                                  .replace('db02-t04-replace-commit-a',
                                           'db02-t06-direct-'+kind))
                    waiter='db02-t06-direct-'+kind
                workers.append(second)
                _observe(container,execute_sql,second,waiter,
                         'db02-t06-owner-'+kind,'ShareLock')
                rc,out,err=_finish(first,'owner')
                _check(rc==0,'OWNER_FAIL '+kind+' '+repr(err[-400:]))
                rc,out,err=_finish(second,'blocked-command')
                if kind in APPLY:
                    _check(rc==0 and 'INVALIDATED|5|' in out,
                           'APPLY_NOT_INVALIDATED '+kind+' rc='+str(rc)+
                           ' out='+repr(out[-250:])+' err='+repr(err[-450:]))
                    _apply_evidence(container,execute_sql,request,kind)
                else:
                    _check(rc!=0 and 'D1 Roll Policy' in err,
                           'DIRECT_NOT_DENIED '+kind+' rc='+str(rc)+
                           ' err='+repr(err[-450:]))
                    _direct_evidence(container,execute_sql,success=False,
                                     key='db02-t06-direct-'+kind)
            print('DB02_T06_RACE_PASS '+kind+
                  ' exact_foundation_block=true zero_partial_effect=true')
        finally:
            for p in workers:
                if p.poll() is None:
                    p.kill();p.communicate(timeout=10)
    print('DB02_T06_PASS 8 protected two-backend Foundation authority races')
