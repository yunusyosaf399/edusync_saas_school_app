"""Real local PostgreSQL-driver -> opaque SQLite intent integration trial.

Run ONLY after the disposable D1C2A stack's frozen business/race suites.
All data, bearer tokens, clocks, Ed25519 keys and privileged database-session
JWT claims are TEST fixtures; a real production auth/session is NOT verified.
The SQL helper and test grants are installed solely in a disposable local stack.
"""
from __future__ import annotations

from concurrent.futures import ThreadPoolExecutor
from contextlib import closing
import json
from pathlib import Path
import sqlite3
import sys
import tempfile
import time

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "tools" / "photo_validation"))
sys.path.insert(0, str(ROOT / "tools" / "photo_validation" / "tests"))

STUDENT = "b1000000-0000-4000-8000-000000000001"
CAMPUS = "b1000000-0000-4000-8000-000000000041"
PRINCIPAL = "55555555-5555-4555-8555-555555555555"
SUBJECT_EMAIL = "foundation-rbac-001@example.invalid"
PHOTO_SCOPE = "d2000000-0000-4000-8000-000000000012"
CONTAINER = "supabase_db_saas_OS_school_app"
PORT = 54322


def _fixture_sql(root: Path) -> str:
    """Extract only reviewed setup SQL from the actual frozen acceptance suites.

    Deliberately do not invent raw Enrollment/roll rows: P0 places the Student.
    Actor+school prerequisites are committed by existing local race harness.
    """
    profile = (root / "supabase/tests/domain/66_student_profile_p1_direct_history_authorization.sql").read_text()
    scope = (root / "supabase/proposals/student_photo_private_actor_scope_resolver_acceptance.sql.draft").read_text()
    resolver = (root / "supabase/proposals/student_photo_private_actor_scope_resolver_trial.sql.draft").read_text()

    def between(src: str, first: str, last: str) -> str:
        if src.count(first) != 1 or src.count(last) != 1:
            raise RuntimeError("D1_PHOTO_REAL_PG_FIXTURE_BOUNDARY_CHANGED")
        return src.split(first, 1)[1].split(last, 1)[0]

    placement_setup = between(profile,
        "SET ROLE schoolos_schema_owner;\nUPDATE app_private.permissions SET state='ENABLED'\n WHERE code='student.enrollment.place';",
        "-- Profile is still disabled in the registered deployment baseline.")
    placement_setup = ("SET ROLE schoolos_schema_owner;\n"
        "UPDATE app_private.permissions SET state='ENABLED'\n"
        " WHERE code='student.enrollment.place';\n" + placement_setup)
    profile_enabled = between(profile,
        "SET ROLE schoolos_schema_owner;\nUPDATE app_private.permissions SET state='ENABLED' WHERE code='student.profile.update';",
        "-- The accepted INITIAL placement is created")
    profile_enabled = ("SET ROLE schoolos_schema_owner;\n"
        "UPDATE app_private.permissions SET state='ENABLED' WHERE code='student.profile.update';\n"
        + profile_enabled)
    placement_call = between(profile,
        "SELECT * FROM app.d1_place_student_enrollment(",
        ") \\gset placed_")
    placement_call = "SELECT * FROM app.d1_place_student_enrollment(" + placement_call + ");\n"
    profile_grant_start = ("INSERT INTO app_private.role_permission_grants(\n"
      " id,role_id,role_family_only,permission_id,permission_family_safe,valid_from,created_by)\n"
      "SELECT 'b6000000-0000-4000-8000-000000000011'")
    grant = between(profile,profile_grant_start,
      "RESET ROLE;\nSET ROLE authenticated;\nSELECT throws_ok(format($q$SELECT * FROM app.d1_change_student_profile(")
    grant = profile_grant_start + grant + "RESET ROLE;\n"
    photo = between(scope,"SET ROLE schoolos_schema_owner;\nUPDATE app_private.permissions SET state='ENABLED'",
                        "DO $scope_is_exact$")
    photo = ("SET ROLE schoolos_schema_owner;\n"
            "UPDATE app_private.permissions SET state='ENABLED'" + photo)
    if "\\ir " in (placement_setup+profile_enabled+grant+photo) or "\\gset" in (placement_setup+profile_enabled+grant+photo):
        raise RuntimeError("D1_PHOTO_REAL_PG_PSQL_METACOMMAND")
    if not resolver.startswith("-- STUDENT_PHOTO_PRIVATE_ACTOR_SCOPE_RESOLVER_LOCAL_ONLY"):
        raise RuntimeError("D1_PHOTO_REAL_PG_RESOLVER_DRIFT")
    claims = """
SELECT set_config('request.jwt.claim.sub',
 (SELECT id::text FROM auth.users WHERE email='foundation-rbac-001@example.invalid'),true);
SELECT set_config('request.jwt.claims',jsonb_build_object(
 'sub',current_setting('request.jwt.claim.sub'),'role','authenticated',
 'iat',(SELECT extract(epoch FROM tokens_valid_from)::bigint
 FROM app_private.principal_auth_bindings WHERE id='66666666-6666-4666-8666-666666666666'),
 'is_anonymous',false)::text,true);
SET ROLE authenticated;
"""
    proof = f"""
DO $real_pg_fixture_proof$
BEGIN
 IF (SELECT count(*) FROM app_private.enrollments
     WHERE student_id='{STUDENT}' AND placement_kind='PRIMARY'
       AND placement_state='ACTIVE')<>1 THEN
   RAISE EXCEPTION 'D1_PHOTO_REAL_PG_P0_PRIMARY_MISSING';
 END IF;
 IF (SELECT count(*) FROM app_private.assignment_permission_scopes
     WHERE id='{PHOTO_SCOPE}' AND scope_kind='CAMPUS'
       AND campus_id='{CAMPUS}' AND revoked_at IS NULL)<>1 THEN
   RAISE EXCEPTION 'D1_PHOTO_REAL_PG_SCOPE_MISSING';
 END IF;
END
$real_pg_fixture_proof$;
"""
    return ("\nBEGIN;\n" + placement_setup + "\n" + profile_enabled
        + "\n" + claims + placement_call + "\nRESET ROLE;\n"
        + "SET ROLE schoolos_schema_owner;\n" + grant + "\n"
        + photo + "\nRESET ROLE;\n" + resolver + "\n" + proof
        + "\nCOMMIT;\n")


def _local_connect(psycopg):
    # Explicit exact local-only address, fixed local Supabase CLI test credential.
    # This MUST NOT be exposed in an app, published secret, or output log.
    return psycopg.connect(host="127.0.0.1", port=PORT, dbname="postgres",
                           user="postgres", password="postgres",
                           connect_timeout=5, autocommit=False)


def _actor_connection(psycopg):
    conn = _local_connect(psycopg)
    try:
        with conn.cursor() as cur:
            cur.execute("""
                SELECT set_config('request.jwt.claim.sub',
                (SELECT id::text FROM auth.users WHERE email=%s),true)
            """, (SUBJECT_EMAIL,))
            cur.execute("""
                SELECT set_config('request.jwt.claims',jsonb_build_object(
                'sub',current_setting('request.jwt.claim.sub'),
                'role','authenticated',
                'iat',(SELECT extract(epoch FROM tokens_valid_from)::bigint
                    FROM app_private.principal_auth_bindings
                    WHERE id='66666666-6666-4666-8666-666666666666'),
                'is_anonymous',false)::text,true)
            """)
            cur.execute("SET ROLE schoolos_student_executor")
        return conn
    except Exception:
        conn.close()
        raise


def _state(sqlite_path: str):
    with closing(sqlite3.connect(sqlite_path)) as db:
        rows = db.execute(
            "SELECT status,consumed_revision FROM photo_private_trial_intents ORDER BY rowid"
        ).fetchall()
        events = db.execute(
            "SELECT kind FROM photo_private_trial_events ORDER BY rowid"
        ).fetchall()
    return rows, events


def _assert_denied(action, cls) -> None:
    try:
        action()
    except cls:
        return
    raise RuntimeError("D1_PHOTO_REAL_PG_STALE_AUTHORIZATION_ACCEPTED")


def _observe_wait(psycopg, deadline_seconds: float = 10) -> None:
    cutoff = time.monotonic() + deadline_seconds
    with closing(_local_connect(psycopg)) as obs:
        while time.monotonic() < cutoff:
            with obs.cursor() as cur:
                cur.execute("""SELECT count(*) FROM pg_catalog.pg_locks
                    WHERE locktype='advisory' AND classid=71001
                    AND objid=1 AND NOT granted""")
                n = cur.fetchone()[0]
            obs.rollback()
            if n:
                return
            time.sleep(0.05)
    raise RuntimeError("D1_PHOTO_REAL_PG_SHARED_AUTH_LOCK_WAIT_NOT_OBSERVED")


def run_real_postgres_photo_handoff(container: str, run_psql, root: Path = ROOT) -> None:
    if container != CONTAINER:
        raise RuntimeError("D1_PHOTO_REAL_PG_DISPOSABLE_CONTAINER_ONLY")
    try:
        import psycopg
        from cryptography.hazmat.primitives import serialization
        from cryptography.hazmat.primitives.asymmetric.ed25519 import Ed25519PrivateKey
        from student_photo_postgres_verified_handoff_candidate import LocalPostgresPhotoHandoffTrial
        from student_photo_durable_intent_candidate import PrivateIntentDenied
        from test_student_photo_durable_intent_candidate import (
            SCHOOL,PROJECT,CONTROL_ISSUER,SERVICE_ISSUER,SERVICE_ID,signed_control,
        )
    except ImportError as exc:
        raise RuntimeError("D1_PHOTO_REAL_PG_DEPENDENCY_MISSING") from exc
    # Only after normal business and concurrency suites have completed.
    run_psql(container,_fixture_sql(Path(root)),
             "D1_PHOTO_REAL_PG_COMMITTED_DISPOSABLE_FIXTURE",timeout=180)
    # Import-time or port/role mismatch MUST fail, never fall back to DB doubles.
    with closing(_actor_connection(psycopg)) as conn:
        with conn.cursor() as c:
            c.execute("SELECT app_private.current_principal_id()")
            if str(c.fetchone()[0]) != PRINCIPAL:
                raise RuntimeError("D1_PHOTO_REAL_PG_AUTH_PRINCIPAL_MISMATCH")
            c.execute("""SELECT app_private.d1_student_photo_private_issue_resolver_trial(
                         %s::uuid,%s::uuid)""", (STUDENT,CAMPUS))
            if c.fetchone() != (True,):
                raise RuntimeError("D1_PHOTO_REAL_PG_LIVE_RESOLVER_DENIED")
        conn.rollback()

    with tempfile.TemporaryDirectory(prefix="edusync-photo-real-pg-") as tmp:
        path = str(Path(tmp)/"intents.sqlite")
        control=Ed25519PrivateKey.generate()
        service=Ed25519PrivateKey.generate()
        def public(priv):
            return priv.public_key().public_bytes(
                encoding=serialization.Encoding.Raw,
                format=serialization.PublicFormat.Raw)
        store=LocalPostgresPhotoHandoffTrial(
            path,
            pinned_issuer=CONTROL_ISSUER,
            pinned_public_keys={"control-key": public(control)},
            service_issuer=SERVICE_ISSUER,service_id=SERVICE_ID,
            service_public_keys={"service-key": public(service)},
            db_connect=lambda: _actor_connection(psycopg),
            signer=service,signing_kid="service-key",
            school_id=SCHOOL,project_id=PROJECT,
            trial_file_upload_enabled=True,trial_module_enabled=True,
            trial_purpose_approved=True)
        store.accept(signed_control(control),school=SCHOOL,project=PROJECT,
                     now_epoch=150)
        token=store.issue_verified_trial(student_id=STUDENT,campus_id=CAMPUS,
                                         now_epoch=150)
        if store.consume_verified_trial(token,student_id=STUDENT,
                                        campus_id=CAMPUS,now_epoch=160)!=7:
            raise RuntimeError("D1_PHOTO_REAL_PG_TEST_CONSUME_REVISION")
        _assert_denied(lambda:store.consume_verified_trial(
            token,student_id=STUDENT,campus_id=CAMPUS,now_epoch=160),
            PrivateIntentDenied)
        if _state(path) != ([("CONSUMED",7)],[("ISSUE",),("CONSUME",)]):
            raise RuntimeError("D1_PHOTO_REAL_PG_FIRST_CONSUME_NOT_ATOMIC")

        token2=store.issue_verified_trial(student_id=STUDENT,campus_id=CAMPUS,
                                          now_epoch=150)
        _assert_denied(lambda:store.consume_verified_trial(
            token2,student_id=STUDENT,
            campus_id="d2000000-0000-4000-8000-000000000041",now_epoch=160),
            PrivateIntentDenied)
        if _state(path)[0][1] != ("ISSUED",None):
            raise RuntimeError("D1_PHOTO_REAL_PG_WRONG_CAMPUS_MUTATED")

        # Two independent genuine PG sessions. The revoker takes the
        # Foundation EXCLUSIVE lock, updates the actual CAMPUS/DIRECT grant,
        # and holds its transaction. CONSUME must wait on the resolver's
        # SHARED lock; once revocation commits, it MUST deny without
        # consuming the already-issued test intent.
        revoker = _local_connect(psycopg)
        try:
            with revoker.cursor() as cur:
                cur.execute("SELECT pg_catalog.pg_advisory_xact_lock(71001,1)")
                cur.execute("SET ROLE schoolos_schema_owner")
                cur.execute("""UPDATE app_private.assignment_permission_scopes
                    SET revoked_at=pg_catalog.clock_timestamp()
                    WHERE id=%s::uuid AND revoked_at IS NULL
                    RETURNING id""",(PHOTO_SCOPE,))
                if cur.fetchone() is None:
                    raise RuntimeError("D1_PHOTO_REAL_PG_NO_ACTIVE_SCOPE_TO_REVOKE")
            with ThreadPoolExecutor(max_workers=1) as pool:
                fut=pool.submit(store.consume_verified_trial,token2,
                                student_id=STUDENT,campus_id=CAMPUS,
                                now_epoch=160)
                try:
                    _observe_wait(psycopg)
                finally:
                    revoker.commit()
                _assert_denied(lambda:fut.result(timeout=12),PrivateIntentDenied)
        finally:
            revoker.rollback()
            revoker.close()
        if _state(path) != ([("CONSUMED",7),("ISSUED",None)],
                            [("ISSUE",),("CONSUME",),("ISSUE",)]):
            raise RuntimeError("D1_PHOTO_REAL_PG_REVOKED_INTENT_CONSUMED")
        _assert_denied(lambda:store.issue_verified_trial(
            student_id=STUDENT,campus_id=CAMPUS,now_epoch=160),
            PrivateIntentDenied)
    print("D1_STUDENT_PHOTO_REAL_PG_HANDOFF_PASS "
          "live psycopg PG session, protected P0 Student PRIMARY, "
          "real Campus grant and observed exclusive/shared revocation race, "
          "opaque SQLite intent consumed once; LOCAL DISPOSABLE ONLY")
