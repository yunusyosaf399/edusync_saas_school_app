"""DB-01 protected DIRECT immutable replay AFTER genuine protected MOVE and END.

Local-only disposable PostgreSQL. Stage the test School's timezone west/east
to model two ordered School-local business dates without changing system clock.
No production schema change, fake Enrollment mutation or manual Roll edit.
"""
from contextlib import closing
from datetime import timedelta

from domain_db01_roll_correct_race_ci import ACTOR, SCHOOL, _require
from domain_student_photo_real_pg_handoff_ci import _actor_connection, _local_connect
from domain_concurrency_ci import settings_sql
from domain_enrollment_end_lock_prefix_ci import CONTAINER

PREFIX="db1b0000-0000-4000-8000-"
STUDENT_M=PREFIX+"000000000001"
STUDENT_E=PREFIX+"000000000101"
SOURCE=PREFIX+"000000000045"
DEST=PREFIX+"000000000055"
CLASS=PREFIX+"000000000044"
POOL=PREFIX+"000000000050"
KEY_M="db01-after-protected-move-correction"
KEY_E="db01-after-protected-end-correction"
KEY_MOVE="db01-after-correction-real-move"
KEY_END="db01-after-correction-real-end"


def _check(value,code):
    if not value:
        raise RuntimeError("D1_DB01_REPLAY_AFTER_MOVE_END_"+code)


def _seed(container, run_psql):
    script="""BEGIN;
""" + settings_sql() + """
SET ROLE schoolos_schema_owner;
UPDATE app_private.school_profiles SET timezone='Etc/GMT+12'
 WHERE id='22222222-2222-4222-8222-222222222222';
INSERT INTO app_private.people(id,display_name,created_by) VALUES
 ('db1b0000-0000-4000-8000-000000000090','DB-01 MOVE replay Student Person','11111111-1111-4111-8111-111111111111'),
 ('db1b0000-0000-4000-8000-000000000091','DB-01 END replay Student Person','11111111-1111-4111-8111-111111111111');
INSERT INTO app_private.students(
 id,person_id,school_student_id,admission_number,admission_serial,
 admitted_on,current_status,created_by) VALUES
 ('db1b0000-0000-4000-8000-000000000001',
  'db1b0000-0000-4000-8000-000000000090','DB01-HISTORIC-MOVE-TEST',
  'DB01-HISTORIC-MOVE-ADM',19801,
  pg_catalog.timezone('Etc/GMT+12',clock_timestamp())::date-20,
  'ACTIVE','11111111-1111-4111-8111-111111111111'),
 ('db1b0000-0000-4000-8000-000000000101',
  'db1b0000-0000-4000-8000-000000000091','DB01-HISTORIC-END-TEST',
  'DB01-HISTORIC-END-ADM',19802,
  pg_catalog.timezone('Etc/GMT+12',clock_timestamp())::date-20,
  'ACTIVE','11111111-1111-4111-8111-111111111111');
INSERT INTO app_private.student_status_transitions(
 id,student_id,previous_status,new_status,effective_on,sequence_number,reason,created_by) VALUES
 ('db1b0000-0000-4000-8000-000000000002',
  'db1b0000-0000-4000-8000-000000000001',NULL,'ACTIVE',
  pg_catalog.timezone('Etc/GMT+12',clock_timestamp())::date-20,
  1,'Synthetic real P0 source MOVE','11111111-1111-4111-8111-111111111111'),
 ('db1b0000-0000-4000-8000-000000000102',
  'db1b0000-0000-4000-8000-000000000101',NULL,'ACTIVE',
  pg_catalog.timezone('Etc/GMT+12',clock_timestamp())::date-20,
  1,'Synthetic real P0 source END','11111111-1111-4111-8111-111111111111');
INSERT INTO app.campuses(id,school_id,code,name,state,created_by)
VALUES('db1b0000-0000-4000-8000-000000000041',
 '22222222-2222-4222-8222-222222222222',
 'DB01-HISTORY-CAMPUS','DB-01 historic-replay-only synthetic campus',
 'ACTIVE','11111111-1111-4111-8111-111111111111');
INSERT INTO app.academic_years(
 id,school_id,code,label,starts_on,ends_on,state,created_by)
VALUES('db1b0000-0000-4000-8000-000000000042',
 '22222222-2222-4222-8222-222222222222',
 'DB01-HISTORY-YEAR','DB-01 historic replay year',
 pg_catalog.timezone('Etc/GMT+12',clock_timestamp())::date-180,
 pg_catalog.timezone('Pacific/Kiritimati',clock_timestamp())::date+180,
 'ACTIVE','11111111-1111-4111-8111-111111111111');
INSERT INTO app_private.academic_classes(
 id,school_id,code,label,display_order,created_by)
VALUES('db1b0000-0000-4000-8000-000000000043',
 '22222222-2222-4222-8222-222222222222',
 'DB01-HISTORY-CLASS','DB-01 replay class',98,
 '11111111-1111-4111-8111-111111111111');
INSERT INTO app_private.class_offerings(
 id,school_id,class_id,campus_id,academic_year_id,capacity,state,created_by)
VALUES('db1b0000-0000-4000-8000-000000000044',
 '22222222-2222-4222-8222-222222222222',
 'db1b0000-0000-4000-8000-000000000043',
 'db1b0000-0000-4000-8000-000000000041',
 'db1b0000-0000-4000-8000-000000000042',
 30,'OPEN','11111111-1111-4111-8111-111111111111');
INSERT INTO app_private.section_offerings(
 id,class_offering_id,campus_id,code,label,display_order,capacity,state,created_by)
VALUES
 ('db1b0000-0000-4000-8000-000000000045',
  'db1b0000-0000-4000-8000-000000000044',
  'db1b0000-0000-4000-8000-000000000041',
  'DB01-REPLAY-A','DB-01 replay source Section',1,30,'OPEN',
  '11111111-1111-4111-8111-111111111111'),
 ('db1b0000-0000-4000-8000-000000000055',
  'db1b0000-0000-4000-8000-000000000044',
  'db1b0000-0000-4000-8000-000000000041',
  'DB01-REPLAY-B','DB-01 replay MOVE destination Section',2,30,'OPEN',
  '11111111-1111-4111-8111-111111111111');
INSERT INTO app_private.capacity_revisions(
 id,class_offering_id,section_offering_id,old_capacity,new_capacity,
 effective_on,reason,created_by)
VALUES
 ('db1b0000-0000-4000-8000-000000000047',
  'db1b0000-0000-4000-8000-000000000044',NULL,NULL,30,
  pg_catalog.timezone('Etc/GMT+12',clock_timestamp())::date-20,
  'DB-01 replay class capacity','11111111-1111-4111-8111-111111111111'),
 ('db1b0000-0000-4000-8000-000000000048',NULL,
  'db1b0000-0000-4000-8000-000000000045',NULL,30,
  pg_catalog.timezone('Etc/GMT+12',clock_timestamp())::date-20,
  'DB-01 replay source capacity','11111111-1111-4111-8111-111111111111'),
 ('db1b0000-0000-4000-8000-000000000058',NULL,
  'db1b0000-0000-4000-8000-000000000055',NULL,30,
  pg_catalog.timezone('Etc/GMT+12',clock_timestamp())::date-20,
  'DB-01 replay destination capacity','11111111-1111-4111-8111-111111111111');
-- For ACADEMIC_CONTEXT only, provide the new Class-specific allocator.
-- For PERSISTENT_STUDENT, reuse the existing School policy's global pool.
INSERT INTO app_private.roll_allocator_states(
 id,policy_revision_id,class_offering_id,next_value,created_by)
SELECT 'db1b0000-0000-4000-8000-000000000050',rp.id,
 'db1b0000-0000-4000-8000-000000000044',rp.start_value,
 '11111111-1111-4111-8111-111111111111'
FROM app_private.roll_policy_revisions rp
WHERE rp.school_id='22222222-2222-4222-8222-222222222222'
 AND rp.mode='ACADEMIC_CONTEXT'
 AND rp.effective_from<=pg_catalog.timezone('Etc/GMT+12',clock_timestamp())::date-1
 AND (rp.effective_until IS NULL OR
      pg_catalog.timezone('Etc/GMT+12',clock_timestamp())::date-1<rp.effective_until);
-- Enable only within the disposable test store, never frozen migration/main.
UPDATE app_private.permissions SET state='ENABLED'
 WHERE code IN ('student.roll.correct','student.roll_history.view',
  'student.enrollment.move','student.enrollment.end');
UPDATE app_private.operation_contracts SET enabled=true
 WHERE code IN ('student.roll.correct','student.enrollment.move','student.enrollment.end');
UPDATE app_private.permission_scope_contracts SET enabled=true
 WHERE permission_id IN (
  SELECT id FROM app_private.permissions
  WHERE code IN ('student.roll.correct','student.roll_history.view',
      'student.enrollment.move','student.enrollment.end'))
  AND scope_kind='ALL' AND resolver_key='DIRECT';
-- Reuse active complete ALL grants when the earlier disposable suites already
-- created them. Insert only missing, one per role/permission/assignment.
WITH missing AS (
 SELECT p.* FROM app_private.permissions p
 WHERE p.code IN ('student.roll.correct','student.roll_history.view',
   'student.enrollment.move','student.enrollment.end')
 AND NOT EXISTS (
   SELECT 1 FROM app_private.role_permission_grants g
   WHERE g.role_id='aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa'
     AND g.permission_id=p.id AND g.revoked_at IS NULL
     AND g.valid_from<=pg_catalog.statement_timestamp()
     AND (g.valid_until IS NULL OR g.valid_until>pg_catalog.statement_timestamp()))
)
INSERT INTO app_private.role_permission_grants(
 id,role_id,role_family_only,permission_id,permission_family_safe,
 valid_from,created_by)
SELECT pg_catalog.gen_random_uuid(),'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',
 false,id,family_safe,pg_catalog.statement_timestamp()-interval '1 hour',
 '11111111-1111-4111-8111-111111111111'
FROM missing;
INSERT INTO app_private.assignment_permission_scopes(
 id,assignment_id,grant_id,role_id,permission_id,scope_contract_id,
 scope_kind,resolver_key,valid_from,created_by)
SELECT pg_catalog.gen_random_uuid(),'ffffffff-ffff-4fff-8fff-ffffffffffff',
 g.id,g.role_id,g.permission_id,sc.id,'ALL','DIRECT',
 pg_catalog.statement_timestamp()-interval '1 hour',
 '11111111-1111-4111-8111-111111111111'
FROM app_private.permissions p
JOIN app_private.role_permission_grants g ON g.permission_id=p.id
JOIN app_private.permission_scope_contracts sc ON sc.permission_id=p.id
WHERE p.code IN ('student.roll.correct','student.roll_history.view',
 'student.enrollment.move','student.enrollment.end')
 AND g.role_id='aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa'
 AND g.valid_from<=pg_catalog.statement_timestamp()
 AND (g.valid_until IS NULL OR g.valid_until>pg_catalog.statement_timestamp())
 AND g.revoked_at IS NULL
 AND sc.scope_kind='ALL' AND sc.resolver_key='DIRECT' AND sc.enabled
 AND NOT EXISTS (
   SELECT 1 FROM app_private.assignment_permission_scopes aps
   WHERE aps.assignment_id='ffffffff-ffff-4fff-8fff-ffffffffffff'
     AND aps.permission_id=p.id AND aps.scope_kind='ALL' AND aps.resolver_key='DIRECT'
     AND aps.valid_from<=pg_catalog.statement_timestamp()
     AND (aps.valid_until IS NULL OR aps.valid_until>pg_catalog.statement_timestamp())
     AND aps.revoked_at IS NULL)
ORDER BY g.valid_from DESC;
RESET ROLE;
COMMIT;"""
    run_psql(container,script,"D1_DB01_REPLAY_AFTER_MOVE_END_SEED",timeout=100)


def _p0(conn, student, when, key):
    with conn.cursor() as cur:
        cur.execute("SET ROLE authenticated")
        cur.execute("SET LOCAL statement_timeout='15s'")
        cur.execute("""SELECT enrollment_id,roll_allocation_id,numeric_value,student_version
        FROM app.d1_place_student_enrollment(
           %s::uuid,1,%s::uuid,'INITIAL',%s::date,NULL,
           'DB-01 protected history source',NULL,%s)""",
           (student,SOURCE,when,key))
        row=cur.fetchone()
        _check(row is not None and row[3]==1,"REAL_P0")
        return str(row[0]),str(row[1]),int(row[2])


def _correct(conn, student, enrollment, roll, policy, old_number,
             from_date, new_number, key):
    with conn.cursor() as cur:
        cur.execute("SET ROLE authenticated")
        cur.execute("SET LOCAL statement_timeout='15s'")
        cur.execute("""SELECT corrected_roll_allocation_id,
          corrected_numeric_value,correction_effective_from,student_version
          FROM app.d1_correct_student_roll(
            %s::uuid,1,%s::uuid,%s::uuid,%s::date,
            %s::uuid,%s::date,%s::uuid,%s,%s,%s,%s)""",
          (student,enrollment,SOURCE,from_date,roll,from_date,policy,old_number,
           new_number,"DB-01 original exact historical correction",key))
        r=cur.fetchone()
        _check(r is not None and r[1]==new_number and r[3]==2,"REAL_CORRECTION")
        return str(r[0]),int(r[1]),r[2],int(r[3])


def _move(conn, enrollment, old_from, east_day):
    with conn.cursor() as cur:
        cur.execute("SET ROLE authenticated")
        cur.execute("SET LOCAL statement_timeout='15s'")
        cur.execute("""SELECT enrollment_id,roll_allocation_id,numeric_value,
          roll_mode,student_version FROM app.d1_move_student_enrollment(
           %s::uuid,2,%s::uuid,%s::uuid,%s::date,%s::uuid,
           'SECTION_CHANGE',%s::date,'DB-01 protected move after correction',
           NULL,%s)""",
          (STUDENT_M,enrollment,SOURCE,old_from,DEST,east_day,KEY_MOVE))
        r=cur.fetchone()
        _check(r is not None and str(r[0])!=enrollment and r[4]==2,"REAL_MOVE_RESULT")
        return str(r[0]),str(r[1])


def _end(conn, enrollment, old_from, east_day):
    with conn.cursor() as cur:
        cur.execute("SET ROLE authenticated")
        cur.execute("SET LOCAL statement_timeout='15s'")
        cur.execute("""SELECT enrollment_id,roll_allocation_id,
           student_version,effective_until FROM app.d1_end_student_enrollment(
            %s::uuid,2,%s::uuid,%s::uuid,%s::date,%s::date,
            'DB-01 protected end after correction',%s)""",
          (STUDENT_E,enrollment,SOURCE,old_from,east_day,KEY_END))
        r=cur.fetchone()
        _check(r is not None and str(r[0])==enrollment and r[2]==2
               and r[3]==east_day,"REAL_END_RESULT")
        return str(r[1])


def _ledger(cur, student, key):
    cur.execute("""SELECT
      (SELECT count(*) FROM app_private.command_receipts
       WHERE command_kind='student.roll.correct' AND idempotency_key=%s
         AND state='SUCCEEDED'),
      (SELECT count(*) FROM app_private.outbox_events o
       JOIN app_private.command_receipts r ON r.id=o.command_receipt_id
       WHERE r.idempotency_key=%s AND r.command_kind='student.roll.correct'),
      (SELECT count(*) FROM app_private.audit_events a
       JOIN app_private.command_receipts r ON r.id=a.command_receipt_id
       WHERE r.idempotency_key=%s AND r.command_kind='student.roll.correct'),
      (SELECT count(*) FROM app_private.roll_allocations WHERE student_id=%s::uuid),
      (SELECT row_version FROM app_private.students WHERE id=%s::uuid)""",
      (key,key,key,student,student))
    return tuple(cur.fetchone())


def _verify_replay(psycopg, student, original, expected):
    with closing(_actor_connection(psycopg)) as c:
        result=_correct(c,student,*original)
        _check(result==expected,"HISTORIC_REPLAY_CHANGED_"+student)
        c.commit()


def run_db01_roll_replay_after_move_end(container, run_psql):
    _check(container==CONTAINER,"DISPOSABLE_ONLY")
    import psycopg
    _seed(container,run_psql)
    with closing(_local_connect(psycopg)) as observer:
        with observer.cursor() as cur:
            cur.execute("SELECT app_private.d1_roll_business_date(%s::uuid)",(SCHOOL,))
            west_day=cur.fetchone()[0]
            cur.execute("""SELECT pg_catalog.timezone('Pacific/Kiritimati',
                                 pg_catalog.clock_timestamp())::date""")
            east_day=cur.fetchone()[0]
            _check(west_day<east_day,"BUSINESS_DATES_NOT_ORDERED")
            p0_from=west_day-timedelta(days=1)
            cur.execute("""SELECT rp.id,rp.mode,rp.start_value
                FROM app_private.roll_policy_revisions rp
                WHERE rp.school_id=%s::uuid AND rp.effective_from<=%s::date
                  AND (rp.effective_until IS NULL OR %s::date<rp.effective_until)""",
                  (SCHOOL,p0_from,p0_from))
            effective=cur.fetchall()
            _check(len(effective)==1,"P0_EFFECTIVE_POLICY_AMBIGUOUS")
            policy, mode, start_value=effective[0]
            # A dedicated Class ensures ACADEMIC_CONTEXT number collisions
            # cannot be influenced by earlier test Students in other Classes.
            _check(mode in ("PERSISTENT_STUDENT","ACADEMIC_CONTEXT"),"POLICY_MODE")
        observer.rollback()
    sources={}
    for student,which in ((STUDENT_M,"move"),(STUDENT_E,"end")):
        with closing(_actor_connection(psycopg)) as c:
            sources[which]=_p0(c,student,p0_from,"db01-historic-p0-"+which)
            c.commit()

    # Choose new number above the verified current allocator namespace, not
    # from an untrusted caller or an unrelated policy's high-water marker.
    with closing(_local_connect(psycopg)) as c:
        with c.cursor() as cur:
            cur.execute("""SELECT next_value FROM app_private.roll_allocator_states
                WHERE policy_revision_id=%s::uuid
                  AND class_offering_id IS NOT DISTINCT FROM %s::uuid""",
                (policy,CLASS if mode=="ACADEMIC_CONTEXT" else None))
            next_value=cur.fetchone()
            _check(next_value is not None,"SOURCE_ALLOCATOR_MISSING")
            new_num=int(next_value[0])+20
        c.rollback()
    originals={}
    corrected={}
    for ix,(student,which,key) in enumerate(((STUDENT_M,"move",KEY_M),
                                               (STUDENT_E,"end",KEY_E))):
        enrollment,roll,old=sources[which]
        originals[which]=(enrollment,roll,str(policy),old,p0_from,new_num+ix,key)
        with closing(_actor_connection(psycopg)) as c:
            corrected[which]=_correct(c,student,*originals[which])
            _check(corrected[which][2]==west_day,"CORRECTION_DATE")
            c.commit()
    with closing(_local_connect(psycopg)) as c:
        with c.cursor() as cur:
            _check(_ledger(cur,STUDENT_M,KEY_M)==(1,1,1,2,2),"INITIAL_MOVE_RECEIPT")
            _check(_ledger(cur,STUDENT_E,KEY_E)==(1,1,1,2,2),"INITIAL_END_RECEIPT")
        c.rollback()

    # Only test-local stored zone advances; the server clock is NOT mocked.
    run_psql(container,"""BEGIN;
SET ROLE schoolos_schema_owner;
UPDATE app_private.school_profiles SET timezone='Pacific/Kiritimati'
 WHERE id='22222222-2222-4222-8222-222222222222';
RESET ROLE;
COMMIT;""","D1_DB01_REPLAY_ADVANCE_TEST_SCHOOL_DATE",timeout=60)
    with closing(_local_connect(psycopg)) as c:
        with c.cursor() as cur:
            cur.execute("SELECT app_private.d1_roll_business_date(%s::uuid)",(SCHOOL,))
            _check(cur.fetchone()[0]==east_day,"EAST_DATE_RESOLVER")
        c.rollback()

    with closing(_actor_connection(psycopg)) as c:
        moved=_move(c,originals["move"][0],p0_from,east_day)
        c.commit()
    with closing(_actor_connection(psycopg)) as c:
        ended=_end(c,originals["end"][0],p0_from,east_day)
        _check(ended==corrected["end"][0],"END_CLOSES_SUCCESSOR_R1")
        c.commit()
    with closing(_local_connect(psycopg)) as c:
        with c.cursor() as cur:
            cur.execute("""SELECT count(*) FROM app_private.enrollments
                WHERE student_id=%s::uuid AND placement_kind='PRIMARY'
                  AND effective_from<=%s::date
                  AND (effective_until IS NULL OR %s::date<effective_until)""",
                (STUDENT_M,east_day,east_day))
            _check(cur.fetchone()==(1,),"MOVE_HAS_ONE_CURRENT_PRIMARY")
            cur.execute("""SELECT count(*) FROM app_private.enrollments
                WHERE student_id=%s::uuid AND placement_kind='PRIMARY'
                  AND effective_from<=%s::date
                  AND (effective_until IS NULL OR %s::date<effective_until)""",
                (STUDENT_E,east_day,east_day))
            _check(cur.fetchone()==(0,),"END_HAS_ZERO_CURRENT_PRIMARY")
            cur.execute("""SELECT effective_until FROM app_private.roll_allocations
                WHERE id=%s::uuid""",(corrected["move"][0],))
            _check(cur.fetchone()==(east_day,),"MOVE_CLOSES_SOURCE_SUCCESSOR")
            cur.execute("""SELECT effective_until FROM app_private.roll_allocations
                WHERE id=%s::uuid""",(corrected["end"][0],))
            _check(cur.fetchone()==(east_day,),"END_CLOSES_SOURCE_SUCCESSOR")
        c.rollback()
    for student,which,key in ((STUDENT_M,"move",KEY_M),(STUDENT_E,"end",KEY_E)):
        _verify_replay(psycopg,student,originals[which],corrected[which])
        with closing(_local_connect(psycopg)) as c:
            with c.cursor() as cur:
                expected=(1,1,1,3 if which=="move" else 2,2)
                _check(_ledger(cur,student,key)==expected,
                       "HISTORIC_REPLAY_EVIDENCE_CHANGED_"+which)
            c.rollback()
    print("D1_DB01_REPLAY_AFTER_PROTECTED_MOVE_PASS "
          "real P0+DIRECT then protected Section MOVE on later School-local day; "
          "immutable R1/date/version receipt and single audit/outbox")
    print("D1_DB01_REPLAY_AFTER_PROTECTED_END_PASS "
          "real P0+DIRECT then protected Enrollment END on later School-local day; "
          "zero current PRIMARY, immutable R1/date/version receipt")

    run_psql(container,"""BEGIN;
SET ROLE schoolos_schema_owner;
UPDATE app_private.permissions SET state='DISABLED'
 WHERE code='student.roll_history.view';
RESET ROLE;
COMMIT;""","D1_DB01_REPLAY_AFTER_MOVE_END_REVOKE_HISTORY",timeout=60)
    for student,which in ((STUDENT_M,"move"),(STUDENT_E,"end")):
        with closing(_actor_connection(psycopg)) as c:
            try:
                _correct(c,student,*originals[which])
            except psycopg.errors.RaiseException:
                c.rollback()
            else:
                c.rollback()
                raise RuntimeError("D1_DB01_REPLAY_HISTORY_REVOKED_DISCLOSED_"+which)
    with closing(_local_connect(psycopg)) as c:
        with c.cursor() as cur:
            _check(_ledger(cur,STUDENT_M,KEY_M)==(1,1,1,3,2),
                   "REVOKE_MOVE_LEDGER_CHANGED")
            _check(_ledger(cur,STUDENT_E,KEY_E)==(1,1,1,2,2),
                   "REVOKE_END_LEDGER_CHANGED")
        c.rollback()
    print("D1_DB01_REPLAY_AFTER_MOVE_END_REVOKED_PASS "
          "current history permission removed: both historical replays denied "
          "without altering retained Roll history or evidence")
