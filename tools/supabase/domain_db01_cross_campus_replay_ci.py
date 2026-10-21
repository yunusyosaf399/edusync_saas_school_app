"""DB-01 exact historic DIRECT Roll replay after real protected CAMPUS_TRANSFER.

Disposable D1-only: genuine P0 -> DIRECT R0/R1 -> protected Campus A-to-B
Enrollment MOVE on a strictly later School-local date. No direct Roll or
Enrollment history writes. Exercises current Campus-scoped receipt disclosure.
"""
from contextlib import closing
from datetime import timedelta

from domain_db01_replay_after_move_end_ci import (
    SCHOOL, SOURCE, CLASS, _p0, _correct, _ledger,
)
from domain_student_photo_real_pg_handoff_ci import (
    _actor_connection, _local_connect,
)
from domain_concurrency_ci import settings_sql
from domain_enrollment_end_lock_prefix_ci import CONTAINER

STUDENT = "db1d0000-0000-4000-8000-000000000001"
SOURCE_CAMPUS = "db1b0000-0000-4000-8000-000000000041"
DEST_CAMPUS = "db1d0000-0000-4000-8000-000000000041"
DEST_CLASS = "db1d0000-0000-4000-8000-000000000044"
DEST_SECTION = "db1d0000-0000-4000-8000-000000000045"
KEY = "db01-cross-campus-direct-correction"
MOVE_KEY = "db01-cross-campus-real-protected-transfer"
ACTOR = "55555555-5555-4555-8555-555555555555"
ASSIGNMENT = "ffffffff-ffff-4fff-8fff-ffffffffffff"
ROLE = "aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa"


def _check(ok, code):
    if not ok:
        raise RuntimeError("D1_DB01_CROSS_CAMPUS_HISTORY_" + code)


def _setup(container, run_psql):
    sql = "BEGIN;\n" + settings_sql() + """
SET ROLE schoolos_schema_owner;
-- Business-date progression only in disposable School profile, not host clock.
UPDATE app_private.school_profiles SET timezone='Etc/GMT+12'
 WHERE id='22222222-2222-4222-8222-222222222222';
UPDATE app_private.permissions SET state='ENABLED'
 WHERE code IN ('student.roll.correct','student.roll_history.view',
                'student.enrollment.move');
UPDATE app_private.operation_contracts SET enabled=true
 WHERE code IN ('student.roll.correct','student.enrollment.move');
UPDATE app_private.permission_scope_contracts SET enabled=true
 WHERE permission_id=(SELECT id FROM app_private.permissions
    WHERE code='student.roll_history.view')
 AND scope_kind='CAMPUS' AND resolver_key='DIRECT';
INSERT INTO app_private.people(id,display_name,created_by)
VALUES ('db1d0000-0000-4000-8000-000000000090',
 'DB-01 cross-Campus historical replay Student Person',
 '11111111-1111-4111-8111-111111111111');
INSERT INTO app_private.students(
 id,person_id,school_student_id,admission_number,admission_serial,
 admitted_on,current_status,created_by)
VALUES ('db1d0000-0000-4000-8000-000000000001',
 'db1d0000-0000-4000-8000-000000000090',
 'DB01-CROSS-CAMPUS-HISTORY','DB01-CROSS-CAMPUS-ADM',19961,
 pg_catalog.timezone('Etc/GMT+12',clock_timestamp())::date-21,
 'ACTIVE','11111111-1111-4111-8111-111111111111');
INSERT INTO app_private.student_status_transitions(
 id,student_id,previous_status,new_status,effective_on,
 sequence_number,reason,created_by)
VALUES ('db1d0000-0000-4000-8000-000000000002',
 'db1d0000-0000-4000-8000-000000000001',
 NULL,'ACTIVE',
 pg_catalog.timezone('Etc/GMT+12',clock_timestamp())::date-21,
 1,'DB-01 real protected cross-Campus fixture',
 '11111111-1111-4111-8111-111111111111');
-- Campus B is a genuine second Campus within the retained original School.
INSERT INTO app.campuses(id,school_id,code,name,state,created_by)
VALUES ('db1d0000-0000-4000-8000-000000000041',
 '22222222-2222-4222-8222-222222222222',
 'DB01-HISTORY-B','DB-01 cross-Campus target','ACTIVE',
 '11111111-1111-4111-8111-111111111111');
INSERT INTO app_private.class_offerings(
 id,school_id,class_id,campus_id,academic_year_id,capacity,state,created_by)
VALUES ('db1d0000-0000-4000-8000-000000000044',
 '22222222-2222-4222-8222-222222222222',
 'db1b0000-0000-4000-8000-000000000043',
 'db1d0000-0000-4000-8000-000000000041',
 'db1b0000-0000-4000-8000-000000000042',
 30,'OPEN','11111111-1111-4111-8111-111111111111');
INSERT INTO app_private.section_offerings(
 id,class_offering_id,campus_id,code,label,display_order,capacity,state,created_by)
VALUES ('db1d0000-0000-4000-8000-000000000045',
 'db1d0000-0000-4000-8000-000000000044',
 'db1d0000-0000-4000-8000-000000000041',
 'DB01-TRANSFER-B','DB-01 distinct Campus B Section',1,30,'OPEN',
 '11111111-1111-4111-8111-111111111111');
INSERT INTO app_private.capacity_revisions(
 id,class_offering_id,section_offering_id,old_capacity,new_capacity,
 effective_on,reason,created_by)
VALUES
 ('db1d0000-0000-4000-8000-000000000047',
  'db1d0000-0000-4000-8000-000000000044',NULL,NULL,30,
  pg_catalog.timezone('Etc/GMT+12',clock_timestamp())::date-20,
  'DB-01 second Campus class capacity',
  '11111111-1111-4111-8111-111111111111'),
 ('db1d0000-0000-4000-8000-000000000048',
  NULL,'db1d0000-0000-4000-8000-000000000045',NULL,30,
  pg_catalog.timezone('Etc/GMT+12',clock_timestamp())::date-20,
  'DB-01 second Campus Section capacity',
  '11111111-1111-4111-8111-111111111111');
INSERT INTO app_private.roll_allocator_states(
 id,policy_revision_id,class_offering_id,next_value,created_by)
SELECT 'db1d0000-0000-4000-8000-000000000050',
 rp.id,'db1d0000-0000-4000-8000-000000000044',rp.start_value,
 '11111111-1111-4111-8111-111111111111'
 FROM app_private.roll_policy_revisions rp
 WHERE rp.school_id='22222222-2222-4222-8222-222222222222'
 AND rp.mode='ACADEMIC_CONTEXT'
 AND rp.effective_from<=pg_catalog.timezone('Etc/GMT+12',clock_timestamp())::date-1
 AND (rp.effective_until IS NULL OR
      pg_catalog.timezone('Etc/GMT+12',clock_timestamp())::date-1<rp.effective_until);
-- Both ends of a transfer require valid configured P1 DIRECT.
-- The parent fixture owns Campus A's active MOVE policy; B requires its own.
INSERT INTO app_private.approval_policy_versions(
 id,policy_key,version,operation_id,campus_id,d1_route_mode,created_by)
SELECT 'db1d0000-0000-4000-8000-000000000059',
 'db01-cross-campus-protected-move-direct',1,o.id,
 'db1d0000-0000-4000-8000-000000000041','DIRECT',
 '11111111-1111-4111-8111-111111111111'
 FROM app_private.operation_contracts o
 WHERE o.code='student.enrollment.move';
UPDATE app_private.approval_policy_versions SET state='ACTIVE',
 effective_from=pg_catalog.statement_timestamp()-interval '1 hour',
 activated_at=pg_catalog.statement_timestamp()
 WHERE id='db1d0000-0000-4000-8000-000000000059';
RESET ROLE;
COMMIT;"""
    run_psql(container, sql, "D1_DB01_CROSS_CAMPUS_HISTORY_SETUP", timeout=95)


def _scope(container, run_psql, campus, stage):
    # Switch *current* authorization on the same authenticated staff Principal.
    # Source/destination campus literals originate only from this test fixture.
    # No old role assignment or grant is upgraded to an unrestricted wildcard.
    _check(campus in (SOURCE_CAMPUS, DEST_CAMPUS), "BAD_SCOPE_ARGUMENT")
    _check(stage in (1, 2, 3, 4), "BAD_SCOPE_STAGE")
    identifier = f"db1d0000-0000-4000-8000-{100+stage:012d}"
    sql = "BEGIN;\n" + settings_sql() + f"""
SET ROLE schoolos_schema_owner;
UPDATE app_private.assignment_permission_scopes sc
 SET revoked_at=pg_catalog.clock_timestamp()
 FROM app_private.permissions p
 WHERE p.id=sc.permission_id AND p.code='student.roll_history.view'
   AND sc.assignment_id='{ASSIGNMENT}'::uuid
   AND sc.role_id='{ROLE}'::uuid AND sc.revoked_at IS NULL;
INSERT INTO app_private.assignment_permission_scopes(
 id,assignment_id,grant_id,role_id,permission_id,scope_contract_id,
 scope_kind,resolver_key,campus_id,valid_from,created_by)
SELECT '{identifier}'::uuid,'{ASSIGNMENT}'::uuid,
 g.id,g.role_id,g.permission_id,c.id,'CAMPUS','DIRECT',
 '{campus}'::uuid,pg_catalog.statement_timestamp()-interval '1 hour',
 '11111111-1111-4111-8111-111111111111'::uuid
 FROM app_private.role_permission_grants g
 JOIN app_private.permissions p ON p.id=g.permission_id
 JOIN app_private.permission_scope_contracts c ON c.permission_id=p.id
 WHERE p.code='student.roll_history.view'
   AND p.state='ENABLED' AND c.enabled
   AND g.role_id='{ROLE}'::uuid
   AND g.valid_from<=pg_catalog.statement_timestamp()
   AND (g.valid_until IS NULL OR pg_catalog.statement_timestamp()<g.valid_until)
   AND g.revoked_at IS NULL
   AND c.scope_kind='CAMPUS' AND c.resolver_key='DIRECT'
 ORDER BY g.valid_from DESC LIMIT 1;
RESET ROLE;
COMMIT;"""
    run_psql(container,sql,"D1_DB01_CROSS_CAMPUS_SCOPE_"+str(stage),timeout=60)


def _deny(psycopg, original, phase):
    import psycopg as pg
    with closing(_actor_connection(psycopg)) as conn:
        try:
            _correct(conn,STUDENT,*original)
        except pg.errors.RaiseException:
            conn.rollback()
        else:
            conn.rollback()
            raise RuntimeError("D1_DB01_CROSS_CAMPUS_HISTORY_UNAUTHORIZED_"+phase)


def _replay(psycopg, original, expected, phase):
    with closing(_actor_connection(psycopg)) as conn:
        result=_correct(conn,STUDENT,*original)
        _check(result==expected,"ORIGINAL_RECEIPT_CHANGED_"+phase)
        conn.commit()


def _evidence(psycopg,key,expected):
    with closing(_local_connect(psycopg)) as conn:
        with conn.cursor() as cur:
            _check(_ledger(cur,STUDENT,key)==expected,"REPLAY_LEDGER_CHANGED")
            cur.execute("""SELECT
              (SELECT count(*) FROM app_private.enrollments
                WHERE student_id=%s::uuid AND placement_kind='PRIMARY'),
              (SELECT count(*) FROM app_private.roll_allocations
                WHERE student_id=%s::uuid),
              (SELECT count(*) FROM app_private.roll_allocations
                WHERE student_id=%s::uuid AND effective_until IS NULL)
              """,(STUDENT,STUDENT,STUDENT))
            _check(tuple(cur.fetchone())==(2,3,1),"RETAINED_CROSS_CAMPUS_HISTORY")
        conn.rollback()


def run_db01_cross_campus_roll_history_replay(container,run_psql):
    _check(container==CONTAINER,"DISPOSABLE_ONLY")
    import psycopg
    _setup(container,run_psql)
    with closing(_local_connect(psycopg)) as observer:
        with observer.cursor() as cur:
            cur.execute("SELECT app_private.d1_roll_business_date(%s::uuid)",(SCHOOL,))
            west_day=cur.fetchone()[0]
            cur.execute("""SELECT pg_catalog.timezone(
                  'Pacific/Kiritimati',pg_catalog.clock_timestamp())::date""")
            east_day=cur.fetchone()[0]
            _check(west_day<east_day,"SOURCE_DESTINATION_DAY_NOT_ORDERED")
            p0_date=west_day-timedelta(days=1)
            cur.execute("""SELECT rp.id,rp.mode FROM app_private.roll_policy_revisions rp
                  WHERE rp.school_id=%s::uuid AND rp.effective_from<=%s::date
                    AND (rp.effective_until IS NULL OR %s::date<rp.effective_until)""",
                        (SCHOOL,p0_date,p0_date))
            revisions=cur.fetchall()
            _check(len(revisions)==1,"STORED_POLICY_UNRESOLVED")
            policy,mode=revisions[0]
            _check(mode in ("PERSISTENT_STUDENT","ACADEMIC_CONTEXT"),"STORED_POLICY_MODE")
            cur.execute("""SELECT route_mode FROM app_private.d1_enrollment_move_policy(
                         %s::uuid,%s::uuid)""",(SOURCE,DEST_SECTION))
            _check(cur.fetchone()==("DIRECT",),"SOURCE_AND_TARGET_P1_NOT_DIRECT")
        observer.rollback()

    with closing(_actor_connection(psycopg)) as actor:
        enrollment,roll,old=_p0(actor,STUDENT,p0_date,"db01-xcampus-source-p0")
        actor.commit()
    with closing(_local_connect(psycopg)) as observer:
        with observer.cursor() as cur:
            cur.execute("""SELECT next_value FROM app_private.roll_allocator_states
                WHERE policy_revision_id=%s::uuid AND
                  class_offering_id IS NOT DISTINCT FROM %s::uuid""",
                (policy,CLASS if mode=="ACADEMIC_CONTEXT" else None))
            value=cur.fetchone()
            _check(value is not None,"SOURCE_ALLOCATOR_UNRESOLVED")
            proposal=int(value[0])+20
        observer.rollback()
    original=(enrollment,roll,str(policy),old,p0_date,proposal,KEY)
    with closing(_actor_connection(psycopg)) as actor:
        corrected=_correct(actor,STUDENT,*original)
        _check(corrected[2]==west_day,"ORIGINAL_SCHOOL_LOCAL_CORRECTION_DATE")
        actor.commit()
    _check(corrected[3]==2,"ORIGINAL_OPTIMISTIC_VERSION")
    with closing(_local_connect(psycopg)) as observer:
        with observer.cursor() as cur:
            _check(_ledger(cur,STUDENT,KEY)==(1,1,1,2,2),"ORIGINAL_EVIDENCE")
        observer.rollback()

    # Before transfer, Campus A is current: A grant authorizes; B alone denies.
    _scope(container,run_psql,SOURCE_CAMPUS,1)
    _replay(psycopg,original,corrected,"SOURCE_CAMPUS_BEFORE_TRANSFER")
    _scope(container,run_psql,DEST_CAMPUS,2)
    _deny(psycopg,original,"DEST_CAMPUS_BEFORE_TRANSFER")

    # Transfer after genuine R1 starts; never manufacture zero-length history.
    _scope(container,run_psql,SOURCE_CAMPUS,3)
    run_psql(container,"""BEGIN;
SET ROLE schoolos_schema_owner;
UPDATE app_private.school_profiles SET timezone='Pacific/Kiritimati'
 WHERE id='22222222-2222-4222-8222-222222222222';
RESET ROLE;
COMMIT;""","D1_DB01_CROSS_CAMPUS_NEXT_SCHOOL_DAY",timeout=60)
    with closing(_local_connect(psycopg)) as observer:
        with observer.cursor() as cur:
            cur.execute("SELECT app_private.d1_roll_business_date(%s::uuid)",(SCHOOL,))
            _check(cur.fetchone()[0]==east_day,"ADVANCED_SCHOOL_LOCAL_DAY")
            cur.execute("SELECT route_mode FROM app_private.d1_enrollment_move_policy(%s::uuid,%s::uuid)",
                        (SOURCE,DEST_SECTION))
            _check(cur.fetchone()==("DIRECT",),"P1_ROUTE_CHANGED")
        observer.rollback()

    with closing(_actor_connection(psycopg)) as actor:
        with actor.cursor() as cur:
            cur.execute("SET ROLE authenticated")
            cur.execute("SET LOCAL statement_timeout='18s'")
            cur.execute("""SELECT enrollment_id,roll_allocation_id,
                 numeric_value,roll_mode,student_version
                 FROM app.d1_move_student_enrollment(
                  %s::uuid,2,%s::uuid,%s::uuid,%s::date,%s::uuid,
                  'CAMPUS_TRANSFER',%s::date,
                  'DB-01 real protected second Campus transfer',NULL,%s)""",
                  (STUDENT,enrollment,SOURCE,p0_date,DEST_SECTION,east_day,MOVE_KEY))
            result=cur.fetchone()
            _check(result is not None and result[4]==2
                   and str(result[0])!=enrollment,
                   "PROTECTED_CAMPUS_TRANSFER_FAILED")
        actor.commit()

    with closing(_local_connect(psycopg)) as observer:
        with observer.cursor() as cur:
            cur.execute("""SELECT count(*) FROM app_private.enrollments e
              JOIN app_private.section_offerings s ON s.id=e.section_offering_id
              JOIN app_private.class_offerings co ON co.id=s.class_offering_id
              WHERE e.student_id=%s::uuid AND e.placement_kind='PRIMARY'
                AND e.effective_from<=%s::date
                AND (e.effective_until IS NULL OR %s::date<e.effective_until)
                AND co.campus_id=%s::uuid AND s.id=%s::uuid""",
                (STUDENT,east_day,east_day,DEST_CAMPUS,DEST_SECTION))
            _check(cur.fetchone()==(1,),"CURRENT_PRIMARY_NOT_ON_CAMPUS_B")
            cur.execute("SELECT effective_until FROM app_private.roll_allocations WHERE id=%s::uuid",
                        (corrected[0],))
            _check(cur.fetchone()==(east_day,),"SOURCE_CORRECTION_NOT_CLOSED")
            cur.execute("""SELECT count(*) FROM app_private.enrollments
               WHERE student_id=%s::uuid AND section_offering_id=%s::uuid
                 AND effective_from=%s::date""",(STUDENT,DEST_SECTION,east_day))
            _check(cur.fetchone()==(1,),"DESTINATION_ENROLLMENT_NOT_RETAINED")
        observer.rollback()

    # The retained source Roll is Campus A history, but read authority follows
    # the Student's *current* Campus B placement; receipt identity is not ACL.
    _deny(psycopg,original,"OLD_CAMPUS_SCOPE_AFTER_TRANSFER")
    _scope(container,run_psql,DEST_CAMPUS,4)
    _replay(psycopg,original,corrected,"CURRENT_CAMPUS_B_AFTER_TRANSFER")
    _evidence(psycopg,KEY,(1,1,1,3,2))
    print("D1_DB01_REAL_CROSS_CAMPUS_REPLAY_PASS "
          "real P0+DIRECT then protected CAMPUS_TRANSFER A->B on a later School-local day; "
          "A-only current history access denied, B-only current scope replays immutable R1")

    run_psql(container,"""BEGIN;
SET ROLE schoolos_schema_owner;
UPDATE app_private.permissions SET state='DISABLED'
 WHERE code='student.roll_history.view';
RESET ROLE;
COMMIT;""","D1_DB01_CROSS_CAMPUS_HISTORY_REVOKED",timeout=60)
    _deny(psycopg,original,"CURRENT_HISTORY_PERMISSION_REVOKED")
    _evidence(psycopg,KEY,(1,1,1,3,2))
    print("D1_DB01_CROSS_CAMPUS_HISTORY_REVOKED_PASS "
          "revoking live Roll-history permission prevents both cross-Campus "
          "historical disclosures without changing the correction receipt or Roll ledger")
