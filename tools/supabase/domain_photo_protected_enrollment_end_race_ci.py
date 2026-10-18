"""Local-only real P1 Enrollment END versus native PostgreSQL photo intent race.

Uses the accepted public app.d1_end_student_enrollment P1 DIRECT route, never
directly changes Student placement/roll in order to fake the command outcome.
The test Principal/JWT and trial token are strictly disposable CI fixtures.
"""
from __future__ import annotations

from concurrent.futures import ThreadPoolExecutor
from contextlib import closing
import time

from domain_photo_postgres_native_intent_ci import (
    CONTAINER, NativeIntentDenied, NativePostgresPhotoIntentTrial,
    _digest, _row, _denied, _check,
)
from domain_student_photo_real_pg_handoff_ci import (
    STUDENT, CAMPUS, _local_connect, _actor_connection,
)

SOURCE_SECTION = "e4000000-0000-4000-8000-000000000045"
GRANT = "ea000000-0000-4000-8000-000000000012"
SCOPE = "ea000000-0000-4000-8000-000000000013"
POLICY = "ea000000-0000-4000-8000-000000000027"
END_KEY = "photo-native-pg-p1-end-first"
WORKER_NAME = "photo-protected-end-intent-waiter"

# Only the already-frozen suite #62 public P1 source Section END permission
# and DIRECT policy are enabled. Reuse PR94's isolated permission-bearing role
# rather than overlap another active role/permission grant. The School is the
# existing singleton; Student/Enrollment were made by the real protected P0.
SETUP_SQL = """
BEGIN;
SELECT set_config('request.jwt.claim.sub',
  (SELECT id::text FROM auth.users
   WHERE email='foundation-rbac-001@example.invalid'),true);
SELECT set_config('request.jwt.claims',jsonb_build_object(
  'sub',current_setting('request.jwt.claim.sub'),'role','authenticated',
  'iat',(SELECT extract(epoch FROM tokens_valid_from)::bigint
   FROM app_private.principal_auth_bindings
   WHERE id='66666666-6666-4666-8666-666666666666'),
  'is_anonymous',false)::text,true);
SET ROLE schoolos_schema_owner;
UPDATE app_private.permissions SET state='ENABLED'
 WHERE code='student.enrollment.end';
UPDATE app_private.operation_contracts SET enabled=true
 WHERE code='student.enrollment.end';
UPDATE app_private.permission_scope_contracts SET enabled=true
 WHERE permission_id=(SELECT id FROM app_private.permissions
   WHERE code='student.enrollment.end')
   AND scope_kind='ALL' AND resolver_key='DIRECT';
INSERT INTO app_private.role_permission_grants(
 id,role_id,role_family_only,permission_id,permission_family_safe,
 valid_from,created_by)
SELECT 'ea000000-0000-4000-8000-000000000012',
 'e9000000-0000-4000-8000-000000000001',false,id,family_safe,
 pg_catalog.statement_timestamp()-interval '1 hour',
 '11111111-1111-4111-8111-111111111111'
 FROM app_private.permissions WHERE code='student.enrollment.end';
INSERT INTO app_private.assignment_permission_scopes(
 id,assignment_id,grant_id,role_id,permission_id,scope_contract_id,
 scope_kind,resolver_key,valid_from,created_by)
SELECT 'ea000000-0000-4000-8000-000000000013',
 'e9000000-0000-4000-8000-000000000002',
 g.id,g.role_id,g.permission_id,c.id,'ALL','DIRECT',
 pg_catalog.statement_timestamp()-interval '1 hour',
 '11111111-1111-4111-8111-111111111111'
 FROM app_private.role_permission_grants g
 JOIN app_private.permission_scope_contracts c ON c.permission_id=g.permission_id
 WHERE g.id='ea000000-0000-4000-8000-000000000012'
 AND c.scope_kind='ALL' AND c.resolver_key='DIRECT';
-- PR94's original photo scope was intentionally revoked by its previous
-- security test. Never resurrect revoked history. Authorize this independent
-- P1 END race with a new disposable Role/assignment and live photo scope.
-- Profile update still belongs to the original test Role with current scope.
INSERT INTO app_private.roles(
 id,code,label,family_only,state,created_by) VALUES
 ('eb000000-0000-4000-8000-000000000001',
  'photo-p1-end-authorization-trial','Local P1 END photo scope test',
  false,'ACTIVE','11111111-1111-4111-8111-111111111111');
INSERT INTO app_private.principal_role_assignments(
 id,principal_id,principal_kind,role_id,role_family_only,
 context_kind,valid_from,created_by) VALUES
 ('eb000000-0000-4000-8000-000000000002',
  '55555555-5555-4555-8555-555555555555','INDIVIDUAL',
  'eb000000-0000-4000-8000-000000000001',false,
  'INDIVIDUAL',pg_catalog.statement_timestamp()-interval '1 hour',
  '11111111-1111-4111-8111-111111111111');
INSERT INTO app_private.role_permission_grants(
 id,role_id,role_family_only,permission_id,permission_family_safe,
 valid_from,created_by)
SELECT 'eb000000-0000-4000-8000-000000000011',
 'eb000000-0000-4000-8000-000000000001',false,id,family_safe,
 pg_catalog.statement_timestamp()-interval '1 hour',
 '11111111-1111-4111-8111-111111111111'
 FROM app_private.permissions WHERE code='student.photo.submit';
INSERT INTO app_private.assignment_permission_scopes(
 id,assignment_id,grant_id,role_id,permission_id,scope_contract_id,
 scope_kind,resolver_key,campus_id,valid_from,created_by)
SELECT 'eb000000-0000-4000-8000-000000000012',
 'eb000000-0000-4000-8000-000000000002',
 g.id,g.role_id,g.permission_id,c.id,'CAMPUS','DIRECT',
 'e4000000-0000-4000-8000-000000000041',
 pg_catalog.statement_timestamp()-interval '1 hour',
 '11111111-1111-4111-8111-111111111111'
 FROM app_private.role_permission_grants g
 JOIN app_private.permission_scope_contracts c ON c.permission_id=g.permission_id
 WHERE g.id='eb000000-0000-4000-8000-000000000011'
 AND c.scope_kind='CAMPUS' AND c.resolver_key='DIRECT';
INSERT INTO app_private.approval_policy_versions(
 id,policy_key,version,operation_id,d1_route_mode,created_by)
SELECT 'ea000000-0000-4000-8000-000000000027',
 'photo-native-pg-end-first-direct-local',1,id,'DIRECT',
 '11111111-1111-4111-8111-111111111111'
 FROM app_private.operation_contracts WHERE code='student.enrollment.end';
UPDATE app_private.approval_policy_versions SET state='ACTIVE',
 effective_from=pg_catalog.statement_timestamp()-interval '1 hour',
 activated_at=pg_catalog.statement_timestamp()
 WHERE id='ea000000-0000-4000-8000-000000000027';
DO $photo_end_policy_guard$
BEGIN
 IF (SELECT count(*) FROM app_private.approval_policy_versions p
     JOIN app_private.operation_contracts c ON c.id=p.operation_id
     WHERE c.code='student.enrollment.end'
       AND c.enabled AND p.state='ACTIVE' AND p.campus_id IS NULL
       AND p.d1_route_mode='DIRECT'
       AND p.effective_from<=pg_catalog.statement_timestamp()
       AND (p.effective_until IS NULL
            OR pg_catalog.statement_timestamp()<p.effective_until))<>1
 THEN RAISE EXCEPTION 'D1_PHOTO_END_DIRECT_POLICY_AMBIGUOUS'; END IF;
END $photo_end_policy_guard$;
RESET ROLE;
COMMIT;
"""


def _tagged_actor(psycopg):
    conn=_actor_connection(psycopg)
    try:
        with closing(conn.cursor()) as cur:
            cur.execute("SELECT pg_catalog.set_config('application_name',%s,true)",
                        (WORKER_NAME,))
        return conn
    except Exception:
        conn.close()
        raise


def _observe_end_blocked_consumers(psycopg, end_pid, *, count=2, seconds=12):
    """Confirm two actual consumer sessions wait on the Student row holder."""
    deadline=time.monotonic()+seconds
    with closing(_local_connect(psycopg)) as observer:
        while time.monotonic()<deadline:
            with closing(observer.cursor()) as cur:
                cur.execute("""
                    SELECT count(DISTINCT a.pid)
                    FROM pg_catalog.pg_stat_activity a
                    JOIN pg_catalog.pg_locks l ON l.pid=a.pid
                    WHERE a.application_name=%s AND NOT l.granted
                    AND l.locktype IN ('transactionid','tuple')
                    AND %s=ANY(pg_catalog.pg_blocking_pids(a.pid))
                """,(WORKER_NAME,end_pid))
                blocked=cur.fetchone()[0]
            observer.rollback()
            if blocked>=count:
                return
            time.sleep(.05)
    raise RuntimeError("D1_PHOTO_END_SHARED_STUDENT_LOCK_WAIT_NOT_OBSERVED")


def _source_primary(psycopg):
    with closing(_local_connect(psycopg)) as con:
        with closing(con.cursor()) as cur:
            cur.execute("""
                SELECT id,section_offering_id,effective_from
                FROM app_private.enrollments
                WHERE student_id=%s::uuid AND placement_kind='PRIMARY'
                  AND placement_state='ACTIVE'
                  AND effective_from<=CURRENT_DATE
                  AND (effective_until IS NULL OR CURRENT_DATE<effective_until)
            """,(STUDENT,))
            rows=cur.fetchall()
        con.rollback()
    _check(len(rows)==1,"SOURCE_PRIMARY_COUNT")
    _check(str(rows[0][1])==SOURCE_SECTION,"SOURCE_SECTION_CHANGED")
    return rows[0]


def _assert_ended(psycopg, source_id):
    with closing(_local_connect(psycopg)) as con:
        with closing(con.cursor()) as cur:
            cur.execute("""
              SELECT placement_state,effective_until<=CURRENT_DATE,
                     end_reason IS NOT NULL
              FROM app_private.enrollments WHERE id=%s::uuid
            """,(source_id,))
            row=cur.fetchone()
            cur.execute("""
              SELECT count(*) FROM app_private.enrollments
              WHERE student_id=%s::uuid AND placement_kind='PRIMARY'
                AND placement_state='ACTIVE'
                AND effective_from<=CURRENT_DATE
                AND (effective_until IS NULL OR CURRENT_DATE<effective_until)
            """,(STUDENT,))
            active_count=cur.fetchone()[0]
        con.rollback()
    _check(row is not None and row[1] is True and row[2] is True,
           "PROTECTED_END_SOURCE_NOT_BOUNDED")
    _check(active_count==0,"STALE_PRIMARY_STILL_CURRENT")


def run_photo_protected_enrollment_end_race(
    psycopg, *, container: str, run_psql
) -> None:
    if container!=CONTAINER:
        raise RuntimeError("D1_PHOTO_PROTECTED_END_DISPOSABLE_ONLY")
    # Native schema and PR94 P0-authenticated Student fixture must exist.
    run_psql(container,SETUP_SQL,"D1_PHOTO_PROTECTED_END_P1_AUTH_SETUP",timeout=90)
    source_id, source_section, source_start = _source_primary(psycopg)
    store=NativePostgresPhotoIntentTrial(
        db_connect=lambda:_actor_connection(psycopg),
        student_id=STUDENT,campus_id=CAMPUS)
    # One token at ISSUE stage, another already CONSUMED and awaiting
    # FINALIZE_TRIAL. Neither may advance after the P1 source END commits.
    pending=store.issue()
    earlier=store.issue()
    _check(store.transition(earlier,action="CONSUME")=="CONSUMED",
           "PRE_END_CONSUME")
    pending_digest=_digest(pending)
    consumed_digest=_digest(earlier)

    # This is the genuine authenticated *public* accepted P1 END command.
    # Do not synthesize an Enrollment UPDATE or roll revision as a substitute.
    end_con=_actor_connection(psycopg)
    try:
        with closing(end_con.cursor()) as cur:
            cur.execute("RESET ROLE")
            cur.execute("SET ROLE authenticated")
            cur.execute("SELECT pg_catalog.pg_backend_pid()")
            end_pid=cur.fetchone()[0]
            cur.execute("""
              SELECT * FROM app.d1_end_student_enrollment(
                %s::uuid,1,%s::uuid,%s::uuid,%s::date,CURRENT_DATE,
                'Disposable private photo intent enrollment END',
                %s::text)
            """,(STUDENT,source_id,source_section,source_start,END_KEY))
            result=cur.fetchone()
            _check(result is not None,"NO_PROTECTED_END_RECEIPT")
        # The P1 END transaction holds its Student FOR UPDATE lock until
        # commit. Both genuine no-login worker sessions block on the SAME
        # Student row before rechecking current Campus/PRIMARY authority.
        with ThreadPoolExecutor(max_workers=2) as pool:
            tagged_store=NativePostgresPhotoIntentTrial(
                db_connect=lambda:_tagged_actor(psycopg),
                student_id=STUDENT,campus_id=CAMPUS)
            futures=(
                pool.submit(tagged_store.transition,pending,action="CONSUME"),
                pool.submit(tagged_store.transition,earlier,action="FINALIZE_TRIAL"),
            )
            try:
                _observe_end_blocked_consumers(psycopg,end_pid)
            finally:
                end_con.commit()
            for fut in futures:
                _denied(lambda f=fut:f.result(timeout=15))
    finally:
        end_con.rollback()
        end_con.close()

    _assert_ended(psycopg,source_id)
    _check(_row(psycopg,pending_digest)==("ISSUED",False,False,False),
           "STALE_CONSUME_CHANGED_TOKEN")
    _check(_row(psycopg,consumed_digest)==("CONSUMED",True,False,False),
           "STALE_FINALIZE_CHANGED_TOKEN")
    _denied(lambda:store.transition(pending,action="CONSUME"))
    _denied(lambda:store.transition(earlier,action="FINALIZE_TRIAL"))
    _denied(lambda:store.issue())
    print("D1_STUDENT_PHOTO_PROTECTED_END_INTENT_RACE_PASS "
          "genuine authenticated P1 END held Student lock; two live "
          "PostgreSQL consumers observably blocked, then current PRIMARY "
          "recheck denied stale CONSUME and FINALIZE_TRIAL without effect; "
          "no file and no photo SET; DISPOSABLE ONLY")
