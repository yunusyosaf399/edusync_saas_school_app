"""DB03-only candidate acceptance in an explicitly disposable GitHub CI stack."""
from __future__ import annotations

import argparse
import hashlib
import json
import os
from pathlib import Path
import re
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[2]
DEPENDENCY_SHA = "06c2be2412e1699f3fa8f2804969e9808eb16e09"
CANDIDATE = "supabase/proposals/db03/01_policy_draft_schema.sql.draft"
TEST = "supabase/tests/db03/01_policy_draft_schema.sql"
CERTIFICATE_CANDIDATE = "supabase/proposals/db03/02_required_certificates_grace.sql.draft"
CERTIFICATE_TEST = "supabase/tests/db03/02_required_certificates_grace.sql"
PUBLICATION_TEST = "supabase/tests/db03/03_policy_publication.sql"
PUBLICATION_FIXTURE = "supabase/tests/db03/fixtures/policy_publication_actor.sql"
TABLES = {
    "admission_numbering_profiles", "admission_policy_versions",
    "admission_policy_stages", "admission_policy_document_requirements",
}


def validate_source() -> tuple[str, str]:
    sql = (ROOT / CANDIDATE).read_text()
    test = (ROOT / TEST).read_text()
    declarations = re.findall(r"(?mi)^CREATE TABLE app_private\.([a-z_]+)\s*\(", sql)
    if len(declarations) != 4 or set(declarations) != TABLES:
        raise RuntimeError("DB03_CANDIDATE_TABLE_SCOPE")
    if re.search(r"(?mi)^\s*(?:CREATE ROLE|ALTER ROLE|GRANT\s+.*\s+TO\s+(?:authenticated|anon|service_role)|INSERT INTO)", sql):
        raise RuntimeError("DB03_CANDIDATE_ACTIVATION_OR_SEED")
    if len(re.findall(r"CHECK \(state='DRAFT'\)", sql)) != 2:
        raise RuntimeError("DB03_DRAFT_ONLY_REQUIRED")
    if not test.rstrip().endswith("ROLLBACK;") or re.findall(r"SELECT plan\((\d+)\);", test) != ["40"]:
        raise RuntimeError("DB03_TEST_TRANSACTION_PLAN")
    if len(re.findall(r"(?m)^SELECT (?:is|ok|throws_ok|lives_ok)\(", test)) != 40:
        raise RuntimeError("DB03_TEST_ASSERTION_COUNT")
    print("DB03_S1_SOURCE_PASS tables=4 assertions=40 sha256=" + hashlib.sha256(sql.encode()).hexdigest())
    return sql, test


def validate_certificate_source() -> tuple[str, str]:
    sql = (ROOT / CERTIFICATE_CANDIDATE).read_text()
    test = (ROOT / CERTIFICATE_TEST).read_text()
    names = re.findall(r"(?mi)^CREATE FUNCTION app_private\.([a-z0-9_]+)\(", sql)
    if len(names) != 3 or set(names) != {
        "db03_guard_required_certificates", "db03_required_certificate_roster_valid",
        "db03_certificate_grace_due_on",
    } or re.search(r"(?mi)^\s*(CREATE TABLE|CREATE ROLE|INSERT INTO|GRANT )", sql):
        raise RuntimeError("DB03_CERTIFICATE_SCOPE")
    if not test.rstrip().endswith("ROLLBACK;") or re.findall(r"SELECT plan\((\d+)\);", test) != ["30"]:
        raise RuntimeError("DB03_CERTIFICATE_TEST_PLAN")
    if len(re.findall(r"(?m)^SELECT (?:is|ok|throws_ok|lives_ok)\(", test)) != 30:
        raise RuntimeError("DB03_CERTIFICATE_ASSERTION_COUNT")
    print("DB03_CERTIFICATE_SOURCE_PASS assertions=30 sha256=" + hashlib.sha256(sql.encode()).hexdigest())
    return sql, test


def validate_publication_source() -> tuple[str, str, str]:
    paths = sorted((ROOT / "supabase/proposals/db03").glob("03_*.sql.draft"))
    if len(paths) != 4:
        raise RuntimeError("DB03_PUBLICATION_FRAGMENT_COUNT")
    sql = "\n".join(path.read_text() for path in paths)
    declarations = re.findall(r"(?mi)^CREATE(?: OR REPLACE)? FUNCTION ((?:app|app_private)\.[a-z0-9_]+)\(", sql)
    if len(declarations) != 7 or [name for name in declarations if name.startswith("app.")] != ["app.publish_admission_policy"]:
        raise RuntimeError("DB03_PUBLICATION_FUNCTION_SCOPE")
    # Reject deployment-time data/catalog insertion, ignoring function bodies.
    outside = re.sub(r"\$([a-z_]*)\$.*?\$\1\$", "", sql, flags=re.S)
    if re.search(r"(?mi)^\s*(INSERT INTO|CREATE ROLE|ALTER ROLE|CREATE TABLE)\b", outside):
        raise RuntimeError("DB03_PUBLICATION_SEED_OR_ENTITY_SCOPE")
    test = (ROOT / PUBLICATION_TEST).read_text()
    if re.findall(r"SELECT plan\((\d+)\);", test) != ["40"] or len(re.findall(r"(?m)^SELECT (?:is|ok|throws_ok|lives_ok)\(", test)) != 40:
        raise RuntimeError("DB03_PUBLICATION_ASSERTIONS")
    anchor = "\\ir fixtures/policy_publication_actor.sql"
    if test.count(anchor) != 1 or not test.rstrip().endswith("ROLLBACK;"):
        raise RuntimeError("DB03_PUBLICATION_TEST_BOUNDARY")
    fixture = (ROOT / PUBLICATION_FIXTURE).read_text()
    print("DB03_PUBLICATION_SOURCE_PASS fragments=4 assertions=40 sha256=" + hashlib.sha256(sql.encode()).hexdigest())
    return sql, test.replace(anchor, fixture), fixture



def validate_intake_source() -> tuple[str, str, str]:
    paths = sorted((ROOT / "supabase/proposals/db03").glob("04_*.sql.draft"))
    if len(paths) != 4:
        raise RuntimeError("DB03_INTAKE_FRAGMENT_COUNT")
    sql = "\n".join(path.read_text() for path in paths)
    if re.findall(r"(?mi)^CREATE TABLE app_private\.([a-z_]+)", sql) != [
        "admission_applications", "admission_application_transitions", "admission_certificate_grace_history"]:
        raise RuntimeError("DB03_INTAKE_TABLE_SCOPE")
    if re.findall(r"(?mi)^CREATE FUNCTION app\.([a-z_]+)", sql) != [
        "create_admission_draft", "withdraw_admission_draft", "grant_admission_certificate_grace"]:
        raise RuntimeError("DB03_INTAKE_ENTRY_SCOPE")
    outside = re.sub(r"\$([a-z_]*)\$.*?\$\1\$", "", sql, flags=re.S)
    if re.search(r"(?mi)^\s*(INSERT INTO|CREATE ROLE|ALTER ROLE)\b", outside):
        raise RuntimeError("DB03_INTAKE_SEED_OR_ROLE")
    test = (ROOT / "supabase/tests/db03/04_intake_grace.sql").read_text()
    if re.findall(r"SELECT plan\((\d+)\);", test) != ["50"] or len(re.findall(r"(?m)^SELECT (?:is|ok|throws_ok|lives_ok)\(", test)) != 50 or not test.rstrip().endswith("ROLLBACK;"):
        raise RuntimeError("DB03_INTAKE_TEST_PLAN")
    fixtures = []
    for name in ("policy_publication_actor", "intake_grace_actor"):
        fixture = (ROOT / ("supabase/tests/db03/fixtures/" + name + ".sql")).read_text()
        anchor = "\\ir fixtures/" + name + ".sql"
        if test.count(anchor) != 1:
            raise RuntimeError("DB03_INTAKE_FIXTURE_SCOPE")
        test = test.replace(anchor, fixture)
        fixtures.append(fixture)
    review_anchor = "-- DB03_REVIEWED_ROUTE_FIXTURE"
    if test.count(review_anchor) != 1:
        raise RuntimeError("DB03_INTAKE_REVIEW_FIXTURE_SCOPE")
    test = test.replace(review_anchor, "\n".join(fixtures))
    print("DB03_INTAKE_SOURCE_PASS fragments=4 assertions=50 sha256=" + hashlib.sha256(sql.encode()).hexdigest())
    return sql, test, "\n".join(fixtures)



def validate_identity_source() -> tuple[str, str, str]:
    paths = sorted((ROOT / "supabase/proposals/db03").glob("05_*.sql.draft"))
    if len(paths) != 4:
        raise RuntimeError("DB03_IDENTITY_FRAGMENT_COUNT")
    sql = "\n".join(path.read_text() for path in paths)
    if re.findall(r"(?mi)^CREATE TABLE app_private\.([a-z_]+)", sql) != ["admission_identity_resolutions"] or re.findall(r"(?mi)^CREATE FUNCTION app\.([a-z_]+)", sql) != ["attest_admission_original_identity"]:
        raise RuntimeError("DB03_IDENTITY_OBJECT_SCOPE")
    outside = re.sub(r"\$([a-z_]*)\$.*?\$\1\$", "", sql, flags=re.S)
    if re.search(r"(?mi)^\s*(INSERT INTO|CREATE ROLE|ALTER ROLE)\b", outside):
        raise RuntimeError("DB03_IDENTITY_SEED_OR_ROLE")
    test = (ROOT / "supabase/tests/db03/05_original_identity.sql").read_text()
    if re.findall(r"SELECT plan\((\d+)\);", test) != ["40"] or len(re.findall(r"(?m)^SELECT (?:is|ok|throws_ok|lives_ok)\(", test)) != 40 or not test.rstrip().endswith("ROLLBACK;"):
        raise RuntimeError("DB03_IDENTITY_TEST_PLAN")
    fixtures = []
    for name in ("policy_publication_actor", "intake_grace_actor", "original_identity_actor"):
        fixture = (ROOT / ("supabase/tests/db03/fixtures/" + name + ".sql")).read_text()
        anchor = "\\ir fixtures/" + name + ".sql"
        if test.count(anchor) != 1:
            raise RuntimeError("DB03_IDENTITY_FIXTURE_SCOPE")
        test = test.replace(anchor, fixture)
        fixtures.append(fixture)
    print("DB03_IDENTITY_SOURCE_PASS fragments=4 assertions=40 sha256=" + hashlib.sha256(sql.encode()).hexdigest())
    return sql, test, "\n".join(fixtures)



def validate_person_source() -> tuple[str, str, str]:
    paths = sorted((ROOT / "supabase/proposals/db03").glob("06_*.sql.draft"))
    if len(paths) != 4:
        raise RuntimeError("DB03_PERSON_FRAGMENT_COUNT")
    sql = "\n".join(path.read_text() for path in paths)
    if re.findall(r"(?mi)^CREATE TABLE app_private\.([a-z_]+)", sql) != ["admission_person_checks", "admission_person_creations"] or re.findall(r"(?mi)^CREATE FUNCTION app\.([a-z_]+)", sql) != ["check_admission_person_candidates", "create_admission_person"]:
        raise RuntimeError("DB03_PERSON_OBJECT_SCOPE")
    outside = re.sub(r"\$([a-z_]*)\$.*?\$\1\$", "", sql, flags=re.S)
    if re.search(r"(?mi)^\s*(INSERT INTO|CREATE ROLE|ALTER ROLE)\b", outside):
        raise RuntimeError("DB03_PERSON_SEED_OR_ROLE")
    test = (ROOT / "supabase/tests/db03/06_person_creation.sql").read_text()
    if re.findall(r"SELECT plan\((\d+)\);", test) != ["50"] or len(re.findall(r"(?m)^SELECT (?:is|ok|throws_ok|lives_ok)\(", test)) != 50 or not test.rstrip().endswith("ROLLBACK;"):
        raise RuntimeError("DB03_PERSON_TEST_PLAN")
    fixtures = []
    for name in ("policy_publication_actor", "intake_grace_actor", "original_identity_actor", "person_creation_actor"):
        fixture = (ROOT / ("supabase/tests/db03/fixtures/" + name + ".sql")).read_text()
        anchor = "\\ir fixtures/" + name + ".sql"
        if test.count(anchor) != 1:
            raise RuntimeError("DB03_PERSON_FIXTURE_SCOPE")
        test = test.replace(anchor, fixture)
        fixtures.append(fixture)
    print("DB03_PERSON_SOURCE_PASS fragments=4 assertions=50 sha256=" + hashlib.sha256(sql.encode()).hexdigest())
    return sql, test, "\n".join(fixtures)



def validate_principal_source() -> str:
    test = (ROOT / "supabase/tests/db03/07_principal_admission_authority.sql").read_text()
    if re.findall(r"SELECT plan\((\d+)\);", test) != ["27"] or len(re.findall(r"(?m)^SELECT (?:is|ok|throws_ok|lives_ok)\(", test)) != 27 or not test.rstrip().endswith("ROLLBACK;"):
        raise RuntimeError("DB03_PRINCIPAL_TEST_PLAN")
    for name in ("policy_publication_actor", "intake_grace_actor", "original_identity_actor", "person_creation_actor"):
        anchor = "\\ir fixtures/" + name + ".sql"
        if test.count(anchor) != 1:
            raise RuntimeError("DB03_PRINCIPAL_FIXTURE_SCOPE")
        test = test.replace(anchor, (ROOT / ("supabase/tests/db03/fixtures/" + name + ".sql")).read_text())
    for name in ("05_02_original_identity_authority.sql.draft", "06_02_person_creation_authority.sql.draft"):
        sql = (ROOT / "supabase/proposals/db03" / name).read_text()
        if "AND r.code='PRINCIPAL' AND NOT r.family_only" not in sql:
            raise RuntimeError("DB03_PRINCIPAL_SAME_CHAIN_REQUIRED")
    print("DB03_PRINCIPAL_SOURCE_PASS assertions=27 immutable_role_code=PRINCIPAL same_chain=true")
    return test



def validate_document_source() -> tuple[str, str, str]:
    paths = sorted((ROOT / "supabase/proposals/db03").glob("07_*.sql.draft"))
    if len(paths) != 5:
        raise RuntimeError("DB03_DOCUMENT_FRAGMENT_COUNT")
    sql = "\n".join(p.read_text() for p in paths)
    if set(re.findall(r"(?mi)^CREATE TABLE app_private\.([a-z_]+)", sql)) != {
        "admission_document_intakes", "admission_document_upload_intents", "admission_document_links", "admission_document_forwards"}:
        raise RuntimeError("DB03_DOCUMENT_TABLE_SCOPE")
    if re.findall(r"(?mi)^CREATE FUNCTION app\.([a-z_]+)", sql) != ["prepare_admission_documents", "forward_admission_to_principal", "read_admission_document_queue", "list_admission_principal_queue"]:
        raise RuntimeError("DB03_DOCUMENT_PUBLIC_SCOPE")
    outside = re.sub(r"\$([a-z_]*)\$.*?\$\1\$", "", sql, flags=re.S)
    if re.search(r"(?mi)^\s*(INSERT INTO|CREATE ROLE|ALTER ROLE)\b", outside):
        raise RuntimeError("DB03_DOCUMENT_SEED_OR_ROLE")
    test = (ROOT / "supabase/tests/db03/08_document_collection.sql").read_text()
    if re.findall(r"SELECT plan\((\d+)\);", test) != ["28"] or len(re.findall(r"(?m)^SELECT (?:is|ok|throws_ok|lives_ok)\(", test)) != 28 or not test.rstrip().endswith("ROLLBACK;"):
        raise RuntimeError("DB03_DOCUMENT_TEST_PLAN")
    fixtures = []
    for name in ("policy_publication_actor", "intake_grace_actor", "document_collection_actor"):
        fixture = (ROOT / ("supabase/tests/db03/fixtures/" + name + ".sql")).read_text()
        anchor = "\\ir fixtures/" + name + ".sql"
        if test.count(anchor) != 1:
            raise RuntimeError("DB03_DOCUMENT_FIXTURE_SCOPE")
        test = test.replace(anchor, fixture)
        fixtures.append(fixture)
    print("DB03_DOCUMENT_SOURCE_PASS fragments=5 assertions=28 sha256=" + hashlib.sha256(sql.encode()).hexdigest())
    return sql, test, "\n".join(fixtures)



def validate_review_source() -> tuple[str, str]:
    paths = sorted((ROOT / "supabase/proposals/db03").glob("08_*.sql.draft"))
    if len(paths) != 5:
        raise RuntimeError("DB03_REVIEW_FRAGMENT_COUNT")
    sql = "\n".join(p.read_text() for p in paths)
    if set(re.findall(r"(?mi)^CREATE TABLE app_private\.([a-z_]+)", sql)) != {
        "admission_document_accesses", "admission_document_reviews", "admission_document_clearances"}:
        raise RuntimeError("DB03_REVIEW_TABLE_SCOPE")
    if re.findall(r"(?mi)^CREATE FUNCTION app\.([a-z_]+)", sql) != ["review_admission_document", "approve_admission_documents", "read_admission_principal_checklist", "read_admission_document_feedback"]:
        raise RuntimeError("DB03_REVIEW_PUBLIC_SCOPE")
    outside = re.sub(r"\$([a-z_]*)\$.*?\$\1\$", "", sql, flags=re.S)
    if re.search(r"(?mi)^\s*(INSERT INTO|CREATE ROLE|ALTER ROLE)\b", outside):
        raise RuntimeError("DB03_REVIEW_SEED_OR_ROLE")
    fixture = (ROOT / "supabase/tests/db03/fixtures/document_review_actor.sql").read_text()
    print("DB03_REVIEW_SOURCE_PASS fragments=5 sha256=" + hashlib.sha256(sql.encode()).hexdigest())
    return sql, fixture



def validate_deadline_source() -> tuple[str, str]:
    paths = sorted((ROOT / "supabase/proposals/db03").glob("09_*.sql.draft"))
    if len(paths) != 4:
        raise RuntimeError("DB03_DEADLINE_FRAGMENT_COUNT")
    sql = "\n".join(p.read_text() for p in paths)
    if re.findall(r"(?mi)^CREATE TABLE app_private\.([a-z_]+)", sql) != ["admission_deadline_rejections"]:
        raise RuntimeError("DB03_DEADLINE_TABLE_SCOPE")
    if re.findall(r"(?mi)^CREATE FUNCTION app\.([a-z_]+)", sql) != ["read_admission_deadline_rejection"]:
        raise RuntimeError("DB03_DEADLINE_PUBLIC_SCOPE")
    outside = re.sub(r"\$([a-z_]*)\$.*?\$\1\$", "", sql, flags=re.S)
    if re.search(r"(?mi)^\s*(INSERT INTO|CREATE ROLE|ALTER ROLE|CREATE EXTENSION|SELECT cron\.)\b", outside):
        raise RuntimeError("DB03_DEADLINE_ACTIVATION_OR_SEED")
    fixture = (ROOT / "supabase/tests/db03/fixtures/certificate_deadline_actor.sql").read_text()
    print("DB03_DEADLINE_SOURCE_PASS fragments=4 sha256=" + hashlib.sha256(sql.encode()).hexdigest())
    return sql, fixture



def validate_finance_boundary_source() -> tuple[str, str]:
    paths = sorted((ROOT / "supabase/proposals/db03").glob("10_*.sql.draft"))
    if len(paths) != 1:
        raise RuntimeError("DB03_FINANCE_BOUNDARY_FRAGMENT_COUNT")
    sql = paths[0].read_text()
    if re.findall(r"(?mi)^CREATE FUNCTION app\.([a-z_]+)", sql) != ["read_admission_finance_gate"] or re.findall(r"(?mi)^CREATE FUNCTION app_private\.([a-z0-9_]+)", sql) != ["db03_assert_admission_finance_clearance"]:
        raise RuntimeError("DB03_FINANCE_BOUNDARY_FUNCTION_SCOPE")
    outside = re.sub(r"\$([a-z_]*)\$.*?\$\1\$", "", sql, flags=re.S)
    if re.search(r"(?mi)^\s*(INSERT INTO|UPDATE|DELETE FROM|CREATE TABLE|CREATE ROLE|ALTER ROLE|CREATE EXTENSION)\b", outside):
        raise RuntimeError("DB03_FINANCE_BOUNDARY_NO_FAKE_SOURCE")
    test = (ROOT / "supabase/tests/db03/10_finance_gate_boundary.sql").read_text()
    if re.findall(r"SELECT plan\((\d+)\);", test) != ["20"] or len(re.findall(r"(?m)^SELECT (?:is|ok|throws_ok|lives_ok)\(", test)) != 20 or not test.rstrip().endswith("ROLLBACK;"):
        raise RuntimeError("DB03_FINANCE_BOUNDARY_TEST_PLAN")
    for name in ("policy_publication_actor", "intake_grace_actor", "document_collection_actor"):
        anchor = "\\ir fixtures/" + name + ".sql"
        if test.count(anchor) != 1:
            raise RuntimeError("DB03_FINANCE_BOUNDARY_FIXTURE_SCOPE")
        test = test.replace(anchor, (ROOT / ("supabase/tests/db03/fixtures/" + name + ".sql")).read_text())
    print("DB03_FINANCE_BOUNDARY_SOURCE_PASS assertions=20 sha256=" + hashlib.sha256(sql.encode()).hexdigest())
    return sql, test


def validate_applicant_slip_source() -> tuple[str, str]:
    path = ROOT / "supabase/proposals/db03/11_01_applicant_slip_source.sql.draft"
    sql = path.read_text()
    test = (ROOT / "supabase/tests/db03/11_applicant_slip_source.sql").read_text()
    if re.findall(r"(?mi)^CREATE TABLE app_private\.([a-z_]+)", sql) != ["finance_admission_slip_submissions"]:
        raise RuntimeError("DB03_APPLICANT_SLIP_SOURCE_SCOPE")
    outside = re.sub(r"\$([a-z_]*)\$.*?\$\1\$", "", sql, flags=re.S)
    if re.search(r"(?mi)^\s*(INSERT INTO|CREATE ROLE|ALTER ROLE|CREATE EXTENSION|CREATE FUNCTION app\.)\b", outside):
        raise RuntimeError("DB03_APPLICANT_SLIP_NO_ACTIVATION")
    if re.findall(r"SELECT plan\((\d+)\);", test) != ["12"] or len(re.findall(r"(?m)^SELECT (?:is|ok|throws_ok|lives_ok)\(", test)) != 12 or not test.rstrip().endswith("ROLLBACK;"):
        raise RuntimeError("DB03_APPLICANT_SLIP_TEST_PLAN")
    print("DB03_APPLICANT_SLIP_SOURCE_PASS assertions=12 sha256=" + hashlib.sha256(sql.encode()).hexdigest())
    return sql, test


def validate_applicant_slip_submission() -> tuple[str, str, str]:
    sql = (ROOT / "supabase/proposals/db03/12_01_applicant_slip_submission.sql.draft").read_text()
    test = (ROOT / "supabase/tests/db03/12_applicant_slip_submission.sql").read_text()
    fixture = (ROOT / "supabase/tests/db03/fixtures/applicant_slip_actor.sql").read_text()
    if re.findall(r"(?mi)^CREATE FUNCTION app_private\.([a-z0-9_]+)\(", sql) != ["db03_applicant_slip_preflight", "db03_submit_applicant_slip"]:
        raise RuntimeError("DB03_APPLICANT_SLIP_COMMAND_SCOPE")
    outside = re.sub(r"\$([a-z_]*)\$.*?\$\1\$", "", sql, flags=re.S)
    if re.search(r"(?mi)^\s*(INSERT INTO|CREATE ROLE|ALTER ROLE|CREATE TABLE|CREATE FUNCTION app\.)\b", outside):
        raise RuntimeError("DB03_APPLICANT_SLIP_COMMAND_NO_SEED")
    if re.findall(r"SELECT plan\((\d+)\);", test) != ["8"] or len(re.findall(r"(?m)^SELECT (?:is|ok|throws_ok|lives_ok)\(", test)) != 8 or not test.rstrip().endswith("ROLLBACK;"):
        raise RuntimeError("DB03_APPLICANT_SLIP_COMMAND_TEST_PLAN")
    print("DB03_APPLICANT_SLIP_COMMAND_SOURCE_PASS assertions=8 sha256=" + hashlib.sha256(sql.encode()).hexdigest())
    return sql, test, fixture


def validate_applicant_slip_review() -> tuple[str, str, str]:
    sql = (ROOT / "supabase/proposals/db03/13_01_applicant_slip_review.sql.draft").read_text()
    test = (ROOT / "supabase/tests/db03/13_applicant_slip_review.sql").read_text()
    fixture = (ROOT / "supabase/tests/db03/fixtures/applicant_review_actor.sql").read_text()
    if re.findall(r"(?mi)^CREATE TABLE app_private\.([a-z_]+)", sql) != ["finance_admission_slip_reviews"]:
        raise RuntimeError("DB03_APPLICANT_REVIEW_TABLE_SCOPE")
    if re.findall(r"(?mi)^CREATE FUNCTION app_private\.([a-z0-9_]+)\(", sql) != [
        "db03_applicant_review_guard", "db03_applicant_review_authority",
        "db03_applicant_review_evidence", "db03_review_applicant_slip"]:
        raise RuntimeError("DB03_APPLICANT_REVIEW_FUNCTION_SCOPE")
    outside = re.sub(r"\$([a-z_]*)\$.*?\$\1\$", "", sql, flags=re.S)
    if re.search(r"(?mi)^\s*(INSERT INTO|CREATE ROLE|ALTER ROLE|CREATE EXTENSION|CREATE FUNCTION app\.)\b", outside):
        raise RuntimeError("DB03_APPLICANT_REVIEW_NO_SEED")
    if re.findall(r"SELECT plan\((\d+)\);", test) != ["12"] or len(re.findall(r"(?m)^SELECT (?:is|ok|throws_ok|lives_ok)\(", test)) != 12 or not test.rstrip().endswith("ROLLBACK;"):
        raise RuntimeError("DB03_APPLICANT_REVIEW_TEST_PLAN")
    print("DB03_APPLICANT_REVIEW_SOURCE_PASS assertions=12 sha256=" + hashlib.sha256(sql.encode()).hexdigest())
    return sql, test, fixture


def validate_applicant_payment() -> tuple[str, str, str]:
    sql = (ROOT / 'supabase/proposals/db03/14_01_applicant_official_payment.sql.draft').read_text()
    test = (ROOT / 'supabase/tests/db03/14_applicant_official_payment.sql').read_text()
    fixture = (ROOT / 'supabase/tests/db03/fixtures/applicant_payment_actor.sql').read_text()
    if re.findall(r'(?mi)^CREATE TABLE app_private\.([a-z_]+)', sql) != ['finance_admission_official_payments']:
        raise RuntimeError('DB03_APPLICANT_PAYMENT_TABLE_SCOPE')
    if re.findall(r'(?mi)^CREATE FUNCTION app_private\.([a-z0-9_]+)\(', sql) != [
        'db03_applicant_payment_guard', 'db03_issue_applicant_payment']:
        raise RuntimeError('DB03_APPLICANT_PAYMENT_FUNCTION_SCOPE')
    outside = re.sub(r'\$([a-z_]*)\$.*?\$\1\$', '', sql, flags=re.S)
    if re.search(r'(?mi)^\s*(INSERT INTO|CREATE ROLE|ALTER ROLE|CREATE EXTENSION|CREATE FUNCTION app\.)\b', outside):
        raise RuntimeError('DB03_APPLICANT_PAYMENT_NO_SEED')
    if re.findall(r'SELECT plan\((\d+)\);', test) != ['12'] or len(re.findall(r'(?m)^SELECT (?:is|ok|throws_ok|lives_ok)\(', test)) != 12 or not test.rstrip().endswith('ROLLBACK;'):
        raise RuntimeError('DB03_APPLICANT_PAYMENT_TEST_PLAN')
    print('DB03_APPLICANT_PAYMENT_SOURCE_PASS assertions=12 sha256=' + hashlib.sha256(sql.encode()).hexdigest())
    return sql, test, fixture


def validate_destination_source() -> tuple[str, str]:
    sql = (ROOT / 'supabase/proposals/db03/15_01_admission_destination_source.sql.draft').read_text()
    test = (ROOT / 'supabase/tests/db03/15_admission_destination_source.sql').read_text()
    if re.findall(r'(?m)^CREATE TABLE app_private\.([a-z_]+)', sql) != ['admission_destination_intents']:
        raise RuntimeError('DB03_DESTINATION_TABLE_SCOPE')
    if re.search(r'(?m)^CREATE FUNCTION app\.', sql) or 'FORCE ROW LEVEL SECURITY;' not in sql:
        raise RuntimeError('DB03_DESTINATION_NO_PUBLIC_COMMAND')
    if re.findall(r'SELECT plan\((\d+)\);', test) != ['15'] or len(re.findall(
        r'(?m)^SELECT (?:extensions\.)?(?:is|ok|throws_ok|lives_ok)\(', test)) != 15 or not test.rstrip().endswith('ROLLBACK;'):
        raise RuntimeError('DB03_DESTINATION_TEST_PLAN')
    for name in ('policy_publication_actor.sql', 'intake_grace_actor.sql'):
        test = test.replace('\\ir fixtures/' + name,
                            (ROOT / 'supabase/tests/db03/fixtures' / name).read_text())
    print('DB03_DESTINATION_SOURCE_PASS assertions=15 sha256=' + hashlib.sha256(sql.encode()).hexdigest())
    return sql, test


def validate_destination_command() -> tuple[str, str, str]:
    sql = (ROOT / 'supabase/proposals/db03/16_02_admission_destination_command.sql.draft').read_text()
    test = (ROOT / 'supabase/tests/db03/16_admission_destination_command.sql').read_text()
    fixture = (ROOT / 'supabase/tests/db03/fixtures/destination_actor.sql').read_text()
    if re.findall(r'(?m)^CREATE FUNCTION app_private\.([a-z0-9_]+)',sql) != [
        'db03_destination_admin','db03_record_admission_destination'] or re.search(
            r'(?m)^CREATE FUNCTION app\.',sql):
        raise RuntimeError('DB03_DESTINATION_COMMAND_SCOPE')
    if re.findall(r'SELECT plan\((\d+)\);',test) != ['10'] or len(re.findall(
        r'(?m)^SELECT (?:is|ok|throws_ok|lives_ok)\(',test)) != 10 or not test.rstrip().endswith('ROLLBACK;'):
        raise RuntimeError('DB03_DESTINATION_COMMAND_TEST_PLAN')
    if 'INSERT INTO app_private.permissions' in sql or 'INSERT INTO app_private.operation_contracts' in sql:
        raise RuntimeError('DB03_DESTINATION_COMMAND_SEED')
    print('DB03_DESTINATION_COMMAND_SOURCE_PASS assertions=10 sha256='+hashlib.sha256(sql.encode()).hexdigest())
    return sql,test,fixture


def validate_applicant_concession_source() -> tuple[str, str]:
    sql = (ROOT / 'supabase/proposals/db03/17_01_applicant_category_concession_source.sql.draft').read_text()
    test = (ROOT / 'supabase/tests/db03/17_applicant_category_concession_source.sql').read_text()
    if re.findall(r'(?m)^CREATE TABLE app_private\.([a-z_]+)', sql) != [
        'admission_category_concessions', 'admission_concession_categories']:
        raise RuntimeError('DB03_CONCESSION_TABLE_SCOPE')
    outside = re.sub(r'\$([a-z_]*)\$.*?\$\1\$', '', sql, flags=re.S)
    if re.search(r'(?mi)^\s*(INSERT INTO|CREATE ROLE|ALTER ROLE|CREATE FUNCTION app\.)\b', outside):
        raise RuntimeError('DB03_CONCESSION_NO_SEED_OR_PUBLIC_COMMAND')
    if re.findall(r'SELECT plan\((\d+)\);', test) != ['15'] or len(re.findall(
        r'(?m)^SELECT (?:extensions\.)?(?:is|ok|throws_ok|lives_ok)\(', test)) != 15 or not test.rstrip().endswith('ROLLBACK;'):
        raise RuntimeError('DB03_CONCESSION_TEST_PLAN')
    for name in ('policy_publication_actor.sql', 'intake_grace_actor.sql'):
        test = test.replace('\\ir fixtures/' + name,
                            (ROOT / 'supabase/tests/db03/fixtures' / name).read_text())
    print('DB03_CONCESSION_SOURCE_PASS assertions=15 sha256=' + hashlib.sha256(sql.encode()).hexdigest())
    return sql, test


def validate_concession_command() -> tuple[str, str]:
    sql = (ROOT / 'supabase/proposals/db03/18_01_applicant_concession_command.sql.draft').read_text()
    test = (ROOT / 'supabase/tests/db03/18_applicant_concession_command.sql').read_text()
    if re.findall(r'(?m)^CREATE FUNCTION app_private\.([a-z0-9_]+)',sql) != [
        'db03_concession_admin','db03_record_applicant_concession'] or re.search(
            r'(?m)^CREATE FUNCTION app\.',sql):
        raise RuntimeError('DB03_CONCESSION_COMMAND_SCOPE')
    if re.findall(r'SELECT plan\((\d+)\);',test) != ['10'] or len(re.findall(
        r'(?m)^SELECT (?:is|ok|throws_ok|lives_ok)\(',test)) != 10 or not test.rstrip().endswith('ROLLBACK;'):
        raise RuntimeError('DB03_CONCESSION_COMMAND_TEST_PLAN')
    if 'INSERT INTO app_private.permissions' in sql or 'INSERT INTO app_private.operation_contracts' in sql:
        raise RuntimeError('DB03_CONCESSION_COMMAND_SEED')
    print('DB03_CONCESSION_COMMAND_SOURCE_PASS assertions=10 sha256='+hashlib.sha256(sql.encode()).hexdigest())
    return sql,test


def validate_scholarship_approval() -> tuple[str, str]:
    paths = ['19_01_applicant_scholarship_approval_source.sql.draft',
             '19_02_applicant_scholarship_approval_commands.sql.draft']
    sql = '\n'.join((ROOT / 'supabase/proposals/db03' / p).read_text() for p in paths)
    test = (ROOT / 'supabase/tests/db03/19_applicant_scholarship_approval.sql').read_text()
    if re.findall(r'(?m)^CREATE TABLE app_private\.([a-z_]+)',sql) != ['admission_concession_approval_bindings']:
        raise RuntimeError('DB03_SCHOLARSHIP_APPROVAL_TABLE_SCOPE')
    if re.search(r'(?m)^CREATE FUNCTION app\.',sql):
        raise RuntimeError('DB03_SCHOLARSHIP_APPROVAL_NO_PUBLIC_COMMAND')
    if 'INSERT INTO app_private.permissions' in sql or 'INSERT INTO app_private.operation_contracts' in sql:
        raise RuntimeError('DB03_SCHOLARSHIP_APPROVAL_NO_SEED')
    if re.findall(r'SELECT plan\((\d+)\);',test) != ['16'] or len(re.findall(
        r'(?m)^SELECT (?:is|ok|throws_ok|lives_ok)\(',test)) != 16 or not test.rstrip().endswith('ROLLBACK;'):
        raise RuntimeError('DB03_SCHOLARSHIP_APPROVAL_TEST_PLAN')
    print('DB03_SCHOLARSHIP_APPROVAL_SOURCE_PASS assertions=16 sha256='+hashlib.sha256(sql.encode()).hexdigest())
    return sql,test


def validate_approved_scholarship_read() -> tuple[str, str]:
    sql = (ROOT / 'supabase/proposals/db03/20_01_approved_scholarship_pre_admission.sql.draft').read_text()
    test = (ROOT / 'supabase/tests/db03/20_approved_scholarship_pre_admission.sql').read_text()
    if re.findall(r'(?m)^CREATE FUNCTION app_private\.([a-z0-9_]+)', sql) != [
            'db03_pre_admission_approved_concession'] or re.search(r'(?m)^CREATE (?:TABLE|FUNCTION app\.)', sql):
        raise RuntimeError('DB03_APPROVED_SCHOLARSHIP_READ_SCOPE')
    if re.findall(r'SELECT plan\((\d+)\);', test) != ['8'] or len(re.findall(
            r'(?m)^SELECT (?:is|ok|throws_ok|lives_ok)\(', test)) != 8 or not test.rstrip().endswith('ROLLBACK;'):
        raise RuntimeError('DB03_APPROVED_SCHOLARSHIP_READ_TEST_PLAN')
    print('DB03_APPROVED_SCHOLARSHIP_READ_SOURCE_PASS assertions=8 sha256='+hashlib.sha256(sql.encode()).hexdigest())
    return sql,test


def validate_principal_final_source() -> tuple[str, str]:
    sql = (ROOT / 'supabase/proposals/db03/21_01_principal_final_source_snapshot.sql.draft').read_text()
    test = (ROOT / 'supabase/tests/db03/21_principal_final_source_snapshot.sql').read_text()
    if re.findall(r'(?m)^CREATE FUNCTION app_private\.([a-z0-9_]+)', sql) != [
            'db03_principal_final_source_snapshot'] or re.search(r'(?m)^CREATE (?:TABLE|FUNCTION app\.)', sql):
        raise RuntimeError('DB03_PRINCIPAL_FINAL_SOURCE_SCOPE')
    if re.findall(r'SELECT plan\((\d+)\);', test) != ['10'] or len(re.findall(
            r'(?m)^SELECT (?:is|ok|throws_ok|lives_ok)\(', test)) != 10 or not test.rstrip().endswith('ROLLBACK;'):
        raise RuntimeError('DB03_PRINCIPAL_FINAL_SOURCE_TEST_PLAN')
    print('DB03_PRINCIPAL_FINAL_SOURCE_PASS assertions=10 sha256='+hashlib.sha256(sql.encode()).hexdigest())
    return sql,test


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--foundation-root", type=Path)
    parser.add_argument("--source-only", action="store_true")
    args = parser.parse_args()
    sql, test = validate_source()
    certificate_sql, certificate_test = validate_certificate_source()
    publication_sql, publication_test, publication_fixture = validate_publication_source()
    intake_sql, intake_test, intake_fixture = validate_intake_source()
    identity_sql, identity_test, identity_fixture = validate_identity_source()
    person_sql, person_test, person_fixture = validate_person_source()
    principal_test = validate_principal_source()
    document_sql, document_test, document_fixture = validate_document_source()
    review_sql, review_fixture = validate_review_source()
    deadline_sql, deadline_fixture = validate_deadline_source()
    finance_boundary_sql, finance_boundary_test = validate_finance_boundary_source()
    applicant_slip_sql, applicant_slip_test = validate_applicant_slip_source()
    applicant_command_sql, applicant_command_test, applicant_fixture = validate_applicant_slip_submission()
    applicant_review_sql, applicant_review_test, applicant_review_fixture = validate_applicant_slip_review()
    applicant_payment_sql, applicant_payment_test, applicant_payment_fixture = validate_applicant_payment()
    destination_sql, destination_test = validate_destination_source()
    destination_command_sql, destination_command_test, destination_command_fixture = validate_destination_command()
    concession_sql, concession_test = validate_applicant_concession_source()
    concession_command_sql, concession_command_test = validate_concession_command()
    scholarship_approval_sql, scholarship_approval_test = validate_scholarship_approval()
    approved_scholarship_read_sql, approved_scholarship_read_test = validate_approved_scholarship_read()
    principal_final_sql, principal_final_test = validate_principal_final_source()
    subprocess.run([sys.executable, "-m", "unittest", "discover", "-s", "services/admission_documents/tests", "-q"], cwd=ROOT, check=True)
    if args.source_only:
        return 0
    # This runner never connects to a hosted service or reuses a user's stack.
    if os.environ.get("GITHUB_ACTIONS") != "true" or args.foundation_root is None:
        raise RuntimeError("DB03_DISPOSABLE_GITHUB_CI_REQUIRED")
    foundation_root = args.foundation_root.resolve()
    head = subprocess.check_output(["git", "-C", str(foundation_root), "rev-parse", "HEAD"], text=True).strip()
    if head != DEPENDENCY_SHA:
        raise RuntimeError("DB03_FOUNDATION_SOURCE_PIN_MISMATCH")
    source_contract = json.loads((ROOT / "supabase/config/foundation_managed_contract.json").read_text())
    for item in source_contract["frozen_foundation"]["migrations"]:
        path = foundation_root / "supabase/migrations" / item["file"]
        if hashlib.sha256(path.read_bytes()).hexdigest() != item["sha256"]:
            raise RuntimeError("DB03_FROZEN_FOUNDATION_HASH")
    sys.path.insert(0, str(foundation_root / "tools/supabase"))
    import domain_local_ci as local
    from _process import run
    from foundation_guard import inspect_local_config, inspect_source, load_contract
    from foundation_local_ci import cli_version, parse_tap

    contract = load_contract()
    errors, _, _ = inspect_source(foundation_root, contract, require_lf=True, future="fail")
    if errors:
        raise RuntimeError("DB03_FOUNDATION_SOURCE_FAIL")
    inspect_local_config(foundation_root, contract)
    cli_version(contract)
    if run(["docker", "info", "--format", "{{.OSType}}"], cwd=foundation_root, timeout=40).strip() != "linux":
        raise RuntimeError("DB03_DOCKER_LINUX_REQUIRED")
    if local._stack_running():
        raise RuntimeError("DB03_REFUSE_EXISTING_STACK")
    started = False
    container = "supabase_db_" + local.EXPECTED_PROJECT_ID
    try:
        with local.local_postgres_image_pin():
            started = True
            local._start_disposable_stack()
            image = run(["docker", "inspect", "--format", "{{.Config.Image}}", container], cwd=foundation_root, timeout=20).strip()
            if image not in {prefix + local.EXPECTED_POSTGRES_TAG for prefix in (
                "supabase/postgres:", "ghcr.io/supabase/postgres:", "public.ecr.aws/supabase/postgres:") }:
                raise RuntimeError("DB03_LOCAL_POSTGRES_IMAGE_PIN_MISMATCH")
            run(["supabase", "db", "reset", "--local", "--no-seed"], cwd=foundation_root, timeout=900)
            baseline = local.run_foundation_regression(contract, catalog_only=True)
            if baseline != 44:
                raise RuntimeError("DB03_FOUNDATION_BASELINE_COUNT")
            # A deliberately failed candidate install must leave no candidate
            # table or trigger function behind after the connection terminates.
            try:
                local.run_psql(container, "BEGIN;\n" + sql + "\nDO $failure$ BEGIN RAISE EXCEPTION 'DB03_INJECTED_DDL_FAILURE'; END $failure$;\nCOMMIT;", "DB03_FAILURE_REHEARSAL")
            except local.DomainLocalCIError as exc:
                if "DB03_INJECTED_DDL_FAILURE" not in str(exc):
                    raise
            else:
                raise RuntimeError("DB03_EXPECTED_DDL_FAILURE_ABSENT")
            absence = local.run_psql(container, "SELECT count(*) FROM pg_catalog.pg_class WHERE relnamespace='app_private'::regnamespace AND relname LIKE 'admission_%';", "DB03_ROLLBACK_TABLE_PROBE", tuples=True).strip()
            function_absence = local.run_psql(container, "SELECT count(*) FROM pg_catalog.pg_proc WHERE pronamespace='app_private'::regnamespace AND proname='db03_guard_draft_configuration';", "DB03_ROLLBACK_FUNCTION_PROBE", tuples=True).strip()
            if absence != "0" or function_absence != "0":
                raise RuntimeError("DB03_CANDIDATE_ROLLBACK_LEFT_OBJECTS")
            print("DB03_S1_FAILED_INSTALL_ROLLBACK_PASS tables=0 functions=0")
            local.run_psql(container, "BEGIN;\n" + sql + "\nCOMMIT;", "DB03_CANDIDATE_INSTALL")
            output = local.run_psql(container, test, "DB03_CANDIDATE_TEST")
            parse_tap(output, 40)
            remaining = local.run_psql(container, "SELECT (SELECT count(*) FROM app_private.school_profiles)+(SELECT count(*) FROM app_private.principals)+(SELECT count(*) FROM app_private.operation_contracts)+(SELECT count(*) FROM app_private.command_receipts);", "DB03_FIXTURE_CLEANUP", tuples=True).strip()
            if remaining != "0":
                raise RuntimeError("DB03_FIXTURE_ROLLBACK_INCOMPLETE")
            print("DB03_S1_DATABASE_PASS 40/40; frozen_Foundation_catalog=44/44; fixtures_rolled_back=true; publication=unavailable")
            try:
                local.run_psql(container, "BEGIN;\n" + certificate_sql + "\nDO $failure$ BEGIN RAISE EXCEPTION 'DB03_INJECTED_CERTIFICATE_FAILURE'; END $failure$;\nCOMMIT;", "DB03_CERTIFICATE_FAILURE_REHEARSAL")
            except local.DomainLocalCIError as exc:
                if "DB03_INJECTED_CERTIFICATE_FAILURE" not in str(exc):
                    raise
            else:
                raise RuntimeError("DB03_EXPECTED_CERTIFICATE_FAILURE_ABSENT")
            alteration_absence = local.run_psql(container, "SELECT (SELECT count(*) FROM pg_catalog.pg_attribute WHERE attrelid='app_private.admission_policy_document_requirements'::regclass AND attname='applicability' AND NOT attisdropped)+(SELECT count(*) FROM pg_catalog.pg_proc WHERE pronamespace='app_private'::regnamespace AND proname IN ('db03_guard_required_certificates','db03_required_certificate_roster_valid','db03_certificate_grace_due_on'));", "DB03_CERTIFICATE_ROLLBACK_PROBE", tuples=True).strip()
            if alteration_absence != "0":
                raise RuntimeError("DB03_CERTIFICATE_ROLLBACK_LEFT_OBJECTS")
            print("DB03_CERTIFICATE_FAILED_INSTALL_ROLLBACK_PASS columns=0 functions=0")
            local.run_psql(container, "BEGIN;\n" + certificate_sql + "\nCOMMIT;", "DB03_CERTIFICATE_INSTALL")
            parse_tap(local.run_psql(container, certificate_test, "DB03_CERTIFICATE_TEST"), 30)
            remaining = local.run_psql(container, "SELECT (SELECT count(*) FROM app_private.school_profiles)+(SELECT count(*) FROM app_private.principals)+(SELECT count(*) FROM app_private.operation_contracts)+(SELECT count(*) FROM app_private.command_receipts);", "DB03_CERTIFICATE_FIXTURE_CLEANUP", tuples=True).strip()
            if remaining != "0":
                raise RuntimeError("DB03_CERTIFICATE_FIXTURE_ROLLBACK_INCOMPLETE")
            print("DB03_CERTIFICATE_DATABASE_PASS 30/30; total_DB03=70/70; fixtures_rolled_back=true; admission_completion=unavailable")
            before_guard = local.run_psql(container, "SELECT md5(pg_catalog.pg_get_functiondef('app_private.db03_guard_draft_configuration()'::regprocedure));", "DB03_BEFORE_PUBLICATION_GUARD", tuples=True).strip()
            try:
                local.run_psql(container, "BEGIN;\n" + publication_sql + "\nDO $failure$ BEGIN RAISE EXCEPTION 'DB03_INJECTED_PUBLICATION_FAILURE'; END $failure$;\nCOMMIT;", "DB03_PUBLICATION_FAILURE_REHEARSAL")
            except local.DomainLocalCIError as exc:
                if "DB03_INJECTED_PUBLICATION_FAILURE" not in str(exc):
                    raise
            else:
                raise RuntimeError("DB03_EXPECTED_PUBLICATION_FAILURE_ABSENT")
            after_guard = local.run_psql(container, "SELECT md5(pg_catalog.pg_get_functiondef('app_private.db03_guard_draft_configuration()'::regprocedure));", "DB03_AFTER_PUBLICATION_GUARD", tuples=True).strip()
            absent = local.run_psql(container, "SELECT (SELECT count(*) FROM pg_catalog.pg_attribute WHERE attrelid='app_private.admission_policy_versions'::regclass AND attname='published_at' AND NOT attisdropped)+(SELECT count(*) FROM pg_catalog.pg_proc WHERE pronamespace='app'::regnamespace AND proname='publish_admission_policy')+(SELECT count(*) FROM pg_catalog.pg_trigger WHERE tgname='a0_db03_publication_auth_fence');", "DB03_PUBLICATION_ROLLBACK_PROBE", tuples=True).strip()
            if before_guard != after_guard or absent != "0":
                raise RuntimeError("DB03_PUBLICATION_ROLLBACK_INCOMPLETE")
            print("DB03_PUBLICATION_DDL_ROLLBACK_PASS original_guard_restored=true new_columns_entries_fences=0")
            local.run_psql(container, "BEGIN;\n" + publication_sql + "\nCOMMIT;", "DB03_PUBLICATION_INSTALL")
            try:
                local.run_psql(container, "BEGIN;\n" + intake_sql + "\nDO $failure$ BEGIN RAISE EXCEPTION 'DB03_INJECTED_INTAKE_FAILURE'; END $failure$;\nCOMMIT;", "DB03_INTAKE_DDL_REHEARSAL")
            except local.DomainLocalCIError as exc:
                if "DB03_INJECTED_INTAKE_FAILURE" not in str(exc):
                    raise
            else:
                raise RuntimeError("DB03_EXPECTED_INTAKE_DDL_FAILURE_ABSENT")
            absent = local.run_psql(container, "SELECT count(*) FROM pg_catalog.pg_class WHERE relnamespace='app_private'::regnamespace AND relname IN('admission_applications','admission_application_transitions','admission_certificate_grace_history','admission_certificate_grace_current');", "DB03_INTAKE_DDL_ROLLBACK", tuples=True).strip()
            entry_absent = local.run_psql(container, "SELECT count(*) FROM pg_catalog.pg_proc WHERE pronamespace='app'::regnamespace AND proname IN('create_admission_draft','withdraw_admission_draft','grant_admission_certificate_grace');", "DB03_INTAKE_ENTRY_ROLLBACK", tuples=True).strip()
            if absent != "0" or entry_absent != "0":
                raise RuntimeError("DB03_INTAKE_DDL_ROLLBACK_INCOMPLETE")
            print("DB03_INTAKE_DDL_ROLLBACK_PASS tables_view_entries=0")
            local.run_psql(container, "BEGIN;\n" + intake_sql + "\nCOMMIT;", "DB03_INTAKE_INSTALL")
            identity_before_guard = local.run_psql(container, "SELECT md5(pg_get_functiondef('app_private.db03_guard_intake()'::regprocedure));", "DB03_IDENTITY_BEFORE_GUARD", tuples=True).strip()
            try:
                local.run_psql(container, "BEGIN;\n" + identity_sql + "\nDO $failure$ BEGIN RAISE EXCEPTION 'DB03_INJECTED_IDENTITY_FAILURE'; END $failure$;\nCOMMIT;", "DB03_IDENTITY_DDL_REHEARSAL")
            except local.DomainLocalCIError as exc:
                if "DB03_INJECTED_IDENTITY_FAILURE" not in str(exc):
                    raise
            else:
                raise RuntimeError("DB03_EXPECTED_IDENTITY_DDL_FAILURE_ABSENT")
            identity_after_guard = local.run_psql(container, "SELECT md5(pg_get_functiondef('app_private.db03_guard_intake()'::regprocedure));", "DB03_IDENTITY_AFTER_GUARD", tuples=True).strip()
            absent = local.run_psql(container, "SELECT (SELECT count(*) FROM pg_class WHERE relnamespace='app_private'::regnamespace AND relname IN('admission_identity_resolutions','admission_identity_current'))+(SELECT count(*) FROM pg_proc WHERE pronamespace='app'::regnamespace AND proname='attest_admission_original_identity')+(SELECT count(*) FROM pg_attribute WHERE attrelid='app_private.admission_applications'::regclass AND attname='stage_epoch' AND NOT attisdropped);", "DB03_IDENTITY_ROLLBACK_PROBE", tuples=True).strip()
            if absent != "0" or identity_before_guard != identity_after_guard:
                raise RuntimeError("DB03_IDENTITY_DDL_ROLLBACK_INCOMPLETE")
            print("DB03_IDENTITY_DDL_ROLLBACK_PASS tables_view_entry_epoch=0 prior_guard_restored=true")
            local.run_psql(container, "BEGIN;\n" + identity_sql + "\nCOMMIT;", "DB03_IDENTITY_INSTALL")
            try:
                local.run_psql(container, "BEGIN;\n" + person_sql + "\nDO $failure$ BEGIN RAISE EXCEPTION 'DB03_INJECTED_PERSON_FAILURE'; END $failure$;\nCOMMIT;", "DB03_PERSON_DDL_REHEARSAL")
            except local.DomainLocalCIError as exc:
                if "DB03_INJECTED_PERSON_FAILURE" not in str(exc):
                    raise
            else:
                raise RuntimeError("DB03_EXPECTED_PERSON_DDL_FAILURE_ABSENT")
            absent = local.run_psql(container, "SELECT (SELECT count(*) FROM pg_class WHERE relnamespace='app_private'::regnamespace AND relname IN('admission_person_checks','admission_person_creations'))+(SELECT count(*) FROM pg_proc WHERE pronamespace='app'::regnamespace AND proname IN('check_admission_person_candidates','create_admission_person'))+(SELECT count(*) FROM pg_trigger WHERE tgname='a0_db03_person_catalog_fence');", "DB03_PERSON_ROLLBACK_PROBE", tuples=True).strip()
            if absent != "0":
                raise RuntimeError("DB03_PERSON_DDL_ROLLBACK_INCOMPLETE")
            print("DB03_PERSON_DDL_ROLLBACK_PASS tables_entries_catalog_fence=0")
            local.run_psql(container, "BEGIN;\n" + person_sql + "\nCOMMIT;", "DB03_PERSON_INSTALL")
            document_guard_before = local.run_psql(container, "SELECT md5(pg_get_functiondef('app_private.db03_guard_intake()'::regprocedure));", "DB03_DOCUMENT_GUARD_BEFORE", tuples=True).strip()
            try:
                local.run_psql(container, "BEGIN;\n" + document_sql + "\nDO $failure$ BEGIN RAISE EXCEPTION 'DB03_INJECTED_DOCUMENT_FAILURE'; END $failure$;\nCOMMIT;", "DB03_DOCUMENT_DDL_REHEARSAL")
            except local.DomainLocalCIError as exc:
                if "DB03_INJECTED_DOCUMENT_FAILURE" not in str(exc):
                    raise
            else:
                raise RuntimeError("DB03_EXPECTED_DOCUMENT_DDL_FAILURE_ABSENT")
            document_guard_after = local.run_psql(container, "SELECT md5(pg_get_functiondef('app_private.db03_guard_intake()'::regprocedure));", "DB03_DOCUMENT_GUARD_AFTER", tuples=True).strip()
            absent = local.run_psql(container, "SELECT (SELECT count(*) FROM pg_class WHERE relnamespace='app_private'::regnamespace AND relname IN('admission_document_intakes','admission_document_upload_intents','admission_document_links','admission_document_forwards'))+(SELECT count(*) FROM pg_proc WHERE pronamespace='app'::regnamespace AND proname IN('prepare_admission_documents','forward_admission_to_principal','read_admission_document_queue','list_admission_principal_queue'))+(SELECT count(*) FROM pg_trigger WHERE tgname IN('a0_db03_document_file_fence','a1_db03_retain_admission_file','a1_db03_retain_file_catalog'));", "DB03_DOCUMENT_DDL_ABSENT", tuples=True).strip()
            if absent != "0" or document_guard_before != document_guard_after:
                raise RuntimeError("DB03_DOCUMENT_DDL_ROLLBACK_INCOMPLETE")
            print("DB03_DOCUMENT_DDL_ROLLBACK_PASS sources_entries_file_fences=0 prior_guard_restored=true")
            local.run_psql(container, "BEGIN;\n" + document_sql + "\nCOMMIT;", "DB03_DOCUMENT_INSTALL")
            review_before = local.run_psql(container, "SELECT md5(pg_get_functiondef('app_private.db03_document_snapshot(uuid)'::regprocedure));", "DB03_REVIEW_BEFORE", tuples=True).strip()
            try:
                local.run_psql(container, "BEGIN;\n" + review_sql + "\nDO $failure$ BEGIN RAISE EXCEPTION 'DB03_INJECTED_REVIEW_FAILURE'; END $failure$;\nCOMMIT;", "DB03_REVIEW_DDL_REHEARSAL")
            except local.DomainLocalCIError as exc:
                if "DB03_INJECTED_REVIEW_FAILURE" not in str(exc):
                    raise
            else:
                raise RuntimeError("DB03_EXPECTED_REVIEW_DDL_FAILURE_ABSENT")
            review_after = local.run_psql(container, "SELECT md5(pg_get_functiondef('app_private.db03_document_snapshot(uuid)'::regprocedure));", "DB03_REVIEW_AFTER", tuples=True).strip()
            absent = local.run_psql(container, "SELECT count(*) FROM pg_class WHERE relnamespace='app_private'::regnamespace AND relname IN('admission_document_accesses','admission_document_reviews','admission_document_clearances');", "DB03_REVIEW_ABSENT", tuples=True).strip()
            if review_before != review_after or absent != "0":
                raise RuntimeError("DB03_REVIEW_DDL_ROLLBACK_INCOMPLETE")
            print("DB03_REVIEW_DDL_ROLLBACK_PASS sources=0 prior_snapshot_restored=true")
            local.run_psql(container, "BEGIN;\n" + review_sql + "\nCOMMIT;", "DB03_REVIEW_INSTALL")
            deadline_probe = "SELECT md5(pg_get_functiondef('app_private.db03_guard_intake()'::regprocedure)||pg_get_functiondef('app.read_admission_document_queue(uuid)'::regprocedure)||pg_get_viewdef('app_private.admission_certificate_grace_current'::regclass));"
            deadline_before = local.run_psql(container, deadline_probe, "DB03_DEADLINE_BEFORE", tuples=True).strip()
            try:
                local.run_psql(container, "BEGIN;\n" + deadline_sql + "\nDO $failure$ BEGIN RAISE EXCEPTION 'DB03_INJECTED_DEADLINE_FAILURE'; END $failure$;\nCOMMIT;", "DB03_DEADLINE_DDL_REHEARSAL")
            except local.DomainLocalCIError as exc:
                if "DB03_INJECTED_DEADLINE_FAILURE" not in str(exc):
                    raise
            else:
                raise RuntimeError("DB03_EXPECTED_DEADLINE_DDL_FAILURE_ABSENT")
            deadline_after = local.run_psql(container, deadline_probe, "DB03_DEADLINE_AFTER", tuples=True).strip()
            absent = local.run_psql(container, "SELECT count(*) FROM pg_class WHERE relnamespace='app_private'::regnamespace AND relname='admission_deadline_rejections';", "DB03_DEADLINE_ABSENT", tuples=True).strip()
            if deadline_before != deadline_after or absent != "0":
                raise RuntimeError("DB03_DEADLINE_DDL_ROLLBACK_INCOMPLETE")
            print("DB03_DEADLINE_DDL_ROLLBACK_PASS source=0 prior_guard_queue_view_restored=true")
            local.run_psql(container, "BEGIN;\n" + deadline_sql + "\nCOMMIT;", "DB03_DEADLINE_INSTALL")
            try:
                local.run_psql(container, "BEGIN;\n" + finance_boundary_sql + "\nDO $failure$ BEGIN RAISE EXCEPTION 'DB03_INJECTED_FINANCE_BOUNDARY_FAILURE'; END $failure$;\nCOMMIT;", "DB03_FINANCE_BOUNDARY_DDL_REHEARSAL")
            except local.DomainLocalCIError as exc:
                if "DB03_INJECTED_FINANCE_BOUNDARY_FAILURE" not in str(exc):
                    raise
            else:
                raise RuntimeError("DB03_EXPECTED_FINANCE_BOUNDARY_DDL_FAILURE_ABSENT")
            absent = local.run_psql(container, "SELECT count(*) FROM pg_proc WHERE proname IN('read_admission_finance_gate','db03_assert_admission_finance_clearance') AND pronamespace IN('app'::regnamespace,'app_private'::regnamespace);", "DB03_FINANCE_BOUNDARY_ABSENT", tuples=True).strip()
            if absent != "0":
                raise RuntimeError("DB03_FINANCE_BOUNDARY_ROLLBACK_INCOMPLETE")
            print("DB03_FINANCE_BOUNDARY_DDL_ROLLBACK_PASS functions=0 no_Finance_source=true")
            local.run_psql(container, "BEGIN;\n" + finance_boundary_sql + "\nCOMMIT;", "DB03_FINANCE_BOUNDARY_INSTALL")
            try:
                local.run_psql(container, "BEGIN;\n" + applicant_slip_sql + "\nDO $failure$ BEGIN RAISE EXCEPTION 'DB03_INJECTED_APPLICANT_SLIP_FAILURE'; END $failure$;\nCOMMIT;", "DB03_APPLICANT_SLIP_DDL_REHEARSAL")
            except local.DomainLocalCIError as exc:
                if "DB03_INJECTED_APPLICANT_SLIP_FAILURE" not in str(exc):
                    raise
            else:
                raise RuntimeError("DB03_EXPECTED_APPLICANT_SLIP_DDL_FAILURE_ABSENT")
            absent = local.run_psql(container, "SELECT count(*) FROM pg_class WHERE relnamespace='app_private'::regnamespace AND relname='finance_admission_slip_submissions';", "DB03_APPLICANT_SLIP_ABSENT", tuples=True).strip()
            if absent != "0":
                raise RuntimeError("DB03_APPLICANT_SLIP_DDL_ROLLBACK_INCOMPLETE")
            print("DB03_APPLICANT_SLIP_DDL_ROLLBACK_PASS sources=0")
            local.run_psql(container, "BEGIN;\n" + applicant_slip_sql + "\nCOMMIT;", "DB03_APPLICANT_SLIP_INSTALL")
            try:
                local.run_psql(container, "BEGIN;\n" + applicant_command_sql + "\nDO $failure$ BEGIN RAISE EXCEPTION 'DB03_INJECTED_APPLICANT_COMMAND_FAILURE'; END $failure$;\nCOMMIT;", "DB03_APPLICANT_COMMAND_DDL_REHEARSAL")
            except local.DomainLocalCIError as exc:
                if "DB03_INJECTED_APPLICANT_COMMAND_FAILURE" not in str(exc):
                    raise
            else:
                raise RuntimeError("DB03_EXPECTED_APPLICANT_COMMAND_DDL_FAILURE_ABSENT")
            absent = local.run_psql(container, "SELECT count(*) FROM pg_proc WHERE pronamespace='app_private'::regnamespace AND proname IN('db03_applicant_slip_preflight','db03_submit_applicant_slip');", "DB03_APPLICANT_COMMAND_ABSENT", tuples=True).strip()
            if absent != "0":
                raise RuntimeError("DB03_APPLICANT_COMMAND_ROLLBACK_INCOMPLETE")
            print("DB03_APPLICANT_COMMAND_DDL_ROLLBACK_PASS functions=0")
            local.run_psql(container, "BEGIN;\n" + applicant_command_sql + "\nCOMMIT;", "DB03_APPLICANT_COMMAND_INSTALL")
            try:
                local.run_psql(container, "BEGIN;\n" + applicant_review_sql + "\nDO $failure$ BEGIN RAISE EXCEPTION 'DB03_INJECTED_APPLICANT_REVIEW_FAILURE'; END $failure$;\nCOMMIT;", "DB03_APPLICANT_REVIEW_DDL_REHEARSAL")
            except local.DomainLocalCIError as exc:
                if "DB03_INJECTED_APPLICANT_REVIEW_FAILURE" not in str(exc):
                    raise
            else:
                raise RuntimeError("DB03_EXPECTED_APPLICANT_REVIEW_DDL_FAILURE_ABSENT")
            absent = local.run_psql(container, "SELECT count(*) FROM pg_class WHERE relnamespace='app_private'::regnamespace AND relname='finance_admission_slip_reviews';", "DB03_APPLICANT_REVIEW_ABSENT", tuples=True).strip()
            if absent != "0":
                raise RuntimeError("DB03_APPLICANT_REVIEW_DDL_ROLLBACK_INCOMPLETE")
            print("DB03_APPLICANT_REVIEW_DDL_ROLLBACK_PASS sources=0")
            local.run_psql(container, "BEGIN;\n" + applicant_review_sql + "\nCOMMIT;", "DB03_APPLICANT_REVIEW_INSTALL")
            try:
                local.run_psql(container, "BEGIN;\n" + applicant_payment_sql + "\nDO $failure$ BEGIN RAISE EXCEPTION 'DB03_INJECTED_APPLICANT_PAYMENT_FAILURE'; END $failure$;\nCOMMIT;", "DB03_APPLICANT_PAYMENT_DDL_REHEARSAL")
            except local.DomainLocalCIError as exc:
                if 'DB03_INJECTED_APPLICANT_PAYMENT_FAILURE' not in str(exc):
                    raise
            else:
                raise RuntimeError('DB03_EXPECTED_APPLICANT_PAYMENT_DDL_FAILURE_ABSENT')
            absent = local.run_psql(container, "SELECT count(*) FROM pg_class WHERE relnamespace='app_private'::regnamespace AND relname='finance_admission_official_payments';", 'DB03_APPLICANT_PAYMENT_ABSENT', tuples=True).strip()
            if absent != '0':
                raise RuntimeError('DB03_APPLICANT_PAYMENT_DDL_ROLLBACK_INCOMPLETE')
            print('DB03_APPLICANT_PAYMENT_DDL_ROLLBACK_PASS sources=0')
            local.run_psql(container, "BEGIN;\n" + applicant_payment_sql + "\nCOMMIT;", 'DB03_APPLICANT_PAYMENT_INSTALL')
            from foundation_local_ci import ensure_local_auth_route
            from prepare_local_auth_fixtures import local_status, prepare
            def prepare_auth():
                url, key = local_status()
                ensure_local_auth_route(url)
                try:
                    if len(prepare(url, key)) != 5:
                        raise RuntimeError("DB03_PUBLICATION_AUTH_FIXTURES")
                finally:
                    key = None
            prepare_auth()
            total_foundation = baseline + local.run_foundation_regression(contract)
            if total_foundation != 220:
                raise RuntimeError("DB03_PUBLICATION_FOUNDATION_REGRESSION_COUNT")
            try:
                publication_output = local.run_psql(container, publication_test, "DB03_PUBLICATION_TEST")
            except local.DomainLocalCIError:
                # The pinned harness tails stderr+stdout together. A long TAP
                # stdout can hide the real SQL error. Rehearse the rollback-only
                # transaction silently so stderr remains visible on failure.
                local.run_psql(container, "\\o /dev/null\n" + publication_test, "DB03_PUBLICATION_SQL_DIAGNOSTIC")
                raise
            parse_tap(publication_output, 40)
            remaining = local.run_psql(container, "SELECT (SELECT count(*) FROM app_private.school_profiles)+(SELECT count(*) FROM app_private.principals)+(SELECT count(*) FROM app_private.operation_contracts)+(SELECT count(*) FROM app_private.command_receipts);", "DB03_PUBLICATION_FIXTURE_CLEANUP", tuples=True).strip()
            if remaining != "0":
                raise RuntimeError("DB03_PUBLICATION_FIXTURE_ROLLBACK_INCOMPLETE")
            print("DB03_PUBLICATION_DATABASE_PASS 40/40; total_DB03=110/110; Foundation=220/220; SQL_fixtures_rolled_back=true")
            try:
                intake_output = local.run_psql(container, intake_test, "DB03_INTAKE_TEST")
            except local.DomainLocalCIError:
                local.run_psql(container, "\\o /dev/null\n" + intake_test, "DB03_INTAKE_SQL_DIAGNOSTIC")
                raise
            if re.search(r"(?m)^\s*not ok\b", intake_output):
                # Preserve failed TAP and its diagnostics, without successful
                # fixture/JWT configuration output or private domain rows.
                lines = intake_output.splitlines()
                for i, line in enumerate(lines):
                    if re.match(r"\s*not ok\b", line):
                        print("DB03_INTAKE_ASSERTION_DETAIL " + "\n".join(lines[max(0,i-1):i+12]))
            parse_tap(intake_output, 50)
            remaining = local.run_psql(container, "SELECT (SELECT count(*) FROM app_private.admission_applications)+(SELECT count(*) FROM app_private.admission_application_transitions)+(SELECT count(*) FROM app_private.admission_certificate_grace_history)+(SELECT count(*) FROM app_private.command_receipts)+(SELECT count(*) FROM app_private.school_profiles);", "DB03_INTAKE_FIXTURE_CLEANUP", tuples=True).strip()
            if remaining != "0":
                raise RuntimeError("DB03_INTAKE_FIXTURE_ROLLBACK_INCOMPLETE")
            print("DB03_INTAKE_DATABASE_PASS 50/50; total_DB03=160/160; Foundation=220/220; fixtures_rolled_back=true")
            try:
                identity_output = local.run_psql(container, identity_test, "DB03_IDENTITY_TEST")
            except local.DomainLocalCIError:
                local.run_psql(container, "\\o /dev/null\n" + identity_test, "DB03_IDENTITY_SQL_DIAGNOSTIC")
                raise
            lines = identity_output.splitlines()
            for i, line in enumerate(lines):
                if re.match(r"\s*not ok\b", line):
                    print("DB03_IDENTITY_ASSERTION_DETAIL " + "\n".join(lines[max(0,i-1):i+12]))
            parse_tap(identity_output, 40)
            remaining = local.run_psql(container, "SELECT (SELECT count(*) FROM app_private.admission_identity_resolutions)+(SELECT count(*) FROM app_private.admission_applications)+(SELECT count(*) FROM app_private.command_receipts)+(SELECT count(*) FROM app_private.school_profiles);", "DB03_IDENTITY_FIXTURE_CLEANUP", tuples=True).strip()
            if remaining != "0":
                raise RuntimeError("DB03_IDENTITY_FIXTURE_ROLLBACK_INCOMPLETE")
            print("DB03_IDENTITY_DATABASE_PASS 40/40; total_DB03=200/200; Foundation=220/220; fixtures_rolled_back=true")
            try:
                person_output = local.run_psql(container, person_test, "DB03_PERSON_TEST")
            except local.DomainLocalCIError:
                local.run_psql(container, "\\o /dev/null\n" + person_test, "DB03_PERSON_SQL_DIAGNOSTIC")
                raise
            lines = person_output.splitlines()
            for i, line in enumerate(lines):
                if re.match(r"\s*not ok\b", line):
                    print("DB03_PERSON_ASSERTION_DETAIL " + "\n".join(lines[max(0,i-1):i+12]))
            parse_tap(person_output, 50)
            remaining = local.run_psql(container, "SELECT (SELECT count(*) FROM app_private.admission_person_checks)+(SELECT count(*) FROM app_private.admission_person_creations)+(SELECT count(*) FROM app_private.people)+(SELECT count(*) FROM app_private.admission_applications)+(SELECT count(*) FROM app_private.command_receipts);", "DB03_PERSON_FIXTURE_CLEANUP", tuples=True).strip()
            if remaining != "0":
                raise RuntimeError("DB03_PERSON_FIXTURE_ROLLBACK_INCOMPLETE")
            print("DB03_PERSON_DATABASE_PASS 50/50; total_DB03=250/250; Foundation=220/220; fixtures_rolled_back=true")
            try:
                principal_output = local.run_psql(container, principal_test, "DB03_PRINCIPAL_TEST")
            except local.DomainLocalCIError:
                local.run_psql(container, "\\o /dev/null\n" + principal_test, "DB03_PRINCIPAL_SQL_DIAGNOSTIC")
                raise
            lines = principal_output.splitlines()
            for i, line in enumerate(lines):
                if re.match(r"\s*not ok\b", line):
                    print("DB03_PRINCIPAL_ASSERTION_DETAIL " + "\n".join(lines[max(0,i-1):i+12]))
            parse_tap(principal_output, 27)
            remaining = local.run_psql(container, "SELECT (SELECT count(*) FROM app_private.admission_applications)+(SELECT count(*) FROM app_private.people)+(SELECT count(*) FROM app_private.roles)+(SELECT count(*) FROM app_private.command_receipts);", "DB03_PRINCIPAL_FIXTURE_CLEANUP", tuples=True).strip()
            if remaining != "0":
                raise RuntimeError("DB03_PRINCIPAL_FIXTURE_ROLLBACK_INCOMPLETE")
            print("DB03_PRINCIPAL_DATABASE_PASS 27/27; total_DB03=277/277; Foundation=220/220; fixtures_rolled_back=true")
            try:
                document_output = local.run_psql(container, document_test, "DB03_DOCUMENT_TEST")
            except local.DomainLocalCIError:
                local.run_psql(container, "\\o /dev/null\n" + document_test, "DB03_DOCUMENT_SQL_DIAGNOSTIC")
                raise
            lines = document_output.splitlines()
            for i, line in enumerate(lines):
                if re.match(r"\s*not ok\b", line):
                    print("DB03_DOCUMENT_ASSERTION_DETAIL " + "\n".join(lines[max(0,i-1):i+12]))
            parse_tap(document_output, 28)
            remaining = local.run_psql(container, "SELECT (SELECT count(*) FROM app_private.admission_document_intakes)+(SELECT count(*) FROM app_private.admission_document_forwards)+(SELECT count(*) FROM app_private.principals)+(SELECT count(*) FROM app_private.command_receipts);", "DB03_DOCUMENT_FIXTURE_CLEANUP", tuples=True).strip()
            if remaining != "0":
                raise RuntimeError("DB03_DOCUMENT_FIXTURE_ROLLBACK_INCOMPLETE")
            print("DB03_DOCUMENT_DATABASE_PASS 28/28; total_DB03=305/305; Foundation=220/220; fixtures_rolled_back=true")
            try:
                finance_output = local.run_psql(container, finance_boundary_test, "DB03_FINANCE_BOUNDARY_TEST")
            except local.DomainLocalCIError:
                local.run_psql(container, "\\o /dev/null\n" + finance_boundary_test, "DB03_FINANCE_BOUNDARY_SQL_DIAGNOSTIC")
                raise
            lines = finance_output.splitlines()
            for i, line in enumerate(lines):
                if re.match(r"\s*not ok\b", line):
                    print("DB03_FINANCE_BOUNDARY_ASSERTION_DETAIL " + "\n".join(lines[max(0,i-1):i+12]))
            parse_tap(finance_output, 20)
            remaining = local.run_psql(container, "SELECT (SELECT count(*) FROM app_private.admission_applications)+(SELECT count(*) FROM app_private.command_receipts)+(SELECT count(*) FROM app_private.principals);", "DB03_FINANCE_BOUNDARY_CLEANUP", tuples=True).strip()
            if remaining != "0":
                raise RuntimeError("DB03_FINANCE_BOUNDARY_FIXTURE_ROLLBACK_INCOMPLETE")
            print("DB03_FINANCE_BOUNDARY_DATABASE_PASS 20/20; total_DB03=325/325; Foundation=220/220; positive_Finance_clearance=unimplemented")
            applicant_output = local.run_psql(container, applicant_slip_test, "DB03_APPLICANT_SLIP_TEST")
            lines = applicant_output.splitlines()
            for i, line in enumerate(lines):
                if re.match(r"\s*not ok\b", line):
                    print("DB03_APPLICANT_SLIP_ASSERTION_DETAIL " + "\n".join(lines[max(0,i-1):i+12]))
            parse_tap(applicant_output, 12)
            print("DB03_APPLICANT_SLIP_DATABASE_PASS 12/12; no_submission_or_clearance_enabled=true")
            command_output = local.run_psql(container, applicant_command_test, "DB03_APPLICANT_COMMAND_TEST")
            parse_tap(command_output, 8)
            print("DB03_APPLICANT_COMMAND_DATABASE_PASS 8/8; no_Finance_payment_or_clearance=true")
            review_output = local.run_psql(container, applicant_review_test, "DB03_APPLICANT_REVIEW_TEST")
            parse_tap(review_output, 12)
            print("DB03_APPLICANT_REVIEW_DATABASE_PASS 12/12; approved_evidence_is_not_payment=true")
            payment_output = local.run_psql(container, applicant_payment_test, 'DB03_APPLICANT_PAYMENT_TEST')
            payment_lines = payment_output.splitlines()
            for i, line in enumerate(payment_lines):
                if re.match(r'\s*not ok\b', line):
                    print('DB03_APPLICANT_PAYMENT_ASSERTION_DETAIL ' + '\n'.join(payment_lines[max(0,i-1):i+12]))
            parse_tap(payment_output, 12)
            print('DB03_APPLICANT_PAYMENT_DATABASE_PASS 12/12; clearance=false')
            def fresh_publication_database():
                run(["supabase", "db", "reset", "--local", "--no-seed"], cwd=foundation_root, timeout=900)
                local.run_psql(container, "BEGIN;\n" + sql + "\n" + certificate_sql + "\n" + publication_sql + "\n" + intake_sql + "\n" + identity_sql + "\n" + person_sql + "\n" + document_sql + "\n" + review_sql + "\n" + deadline_sql + "\n" + finance_boundary_sql + "\n" + applicant_slip_sql + "\n" + applicant_command_sql + "\n" + applicant_review_sql + "\n" + applicant_payment_sql + "\nCOMMIT;", "DB03_PUBLICATION_RACE_INSTALL")
                prepare_auth()
            from policy_publication_races_ci import run_publication_races
            run_publication_races(local, fresh_publication_database, publication_fixture)
            from intake_grace_races_ci import run_intake_races
            run_intake_races(local, fresh_publication_database, intake_fixture)
            from original_identity_races_ci import run_identity_races
            run_identity_races(local, fresh_publication_database, identity_fixture)
            from person_creation_races_ci import run_person_races
            run_person_races(local, fresh_publication_database, person_fixture)
            sys.path.insert(0, str(ROOT))
            from document_collection_ci import run_document_service
            run_document_service(local, fresh_publication_database, document_fixture)
            from document_review_ci import run_document_review
            run_document_review(local, fresh_publication_database, document_fixture + "\n" + review_fixture)
            from certificate_deadline_ci import run_certificate_deadline
            run_certificate_deadline(local, fresh_publication_database, document_fixture + "\n" + review_fixture + "\n" + deadline_fixture)
            from finance_boundary_ci import run_finance_boundary
            run_finance_boundary(local, fresh_publication_database, document_fixture + "\n" + review_fixture)
            from applicant_slip_ci import run_applicant_slip
            run_applicant_slip(local, fresh_publication_database,
                               document_fixture + "\n" + review_fixture + "\n" + applicant_fixture + "\n" + applicant_review_fixture + "\n" + applicant_payment_fixture)
            # S15 is the first D1-dependent Admissions increment. Install the
            # pinned D1 draft only after earlier DB03 acceptance/race fixtures.
            fresh_publication_database()
            from domain_local_ci import assemble_draft_chain
            _, d1_sql = assemble_draft_chain(ROOT)
            local.run_psql(container, d1_sql, 'DB03_DESTINATION_D1_INSTALL', timeout=1200)
            try:
                local.run_psql(container, "BEGIN;\n" + destination_sql + "\nDO $failure$ BEGIN RAISE EXCEPTION 'DB03_INJECTED_DESTINATION_FAILURE'; END $failure$;\nCOMMIT;", 'DB03_DESTINATION_DDL_REHEARSAL')
            except local.DomainLocalCIError as exc:
                if 'DB03_INJECTED_DESTINATION_FAILURE' not in str(exc):
                    raise
            else:
                raise RuntimeError('DB03_DESTINATION_EXPECTED_FAILURE_ABSENT')
            absent = local.run_psql(container, "SELECT count(*) FROM pg_class WHERE relnamespace='app_private'::regnamespace AND relname='admission_destination_intents';", 'DB03_DESTINATION_ABSENT', tuples=True).strip()
            if absent != '0':
                raise RuntimeError('DB03_DESTINATION_ROLLBACK_INCOMPLETE')
            local.run_psql(container, 'BEGIN;\n' + destination_sql + '\nCOMMIT;', 'DB03_DESTINATION_INSTALL')
            try:
                output = local.run_psql(container, destination_test, 'DB03_DESTINATION_TEST')
            except local.DomainLocalCIError:
                # Suppress the successful TAP rows so the runner's bounded
                # error tail includes the failing SQLSTATE and statement.
                local.run_psql(container, '\\o /dev/null\n' + destination_test,
                               'DB03_DESTINATION_SQL_DIAGNOSTIC')
                raise
            parse_tap(output, 15)
            print('DB03_DESTINATION_DATABASE_PASS 15/15; D1_typed_grade=true; no_applicant_writer=true')
            try:
                local.run_psql(container, "BEGIN;\n" + destination_command_sql +
                    "\nDO $failure$ BEGIN RAISE EXCEPTION 'DB03_INJECTED_DESTINATION_COMMAND_FAILURE'; END $failure$;\nCOMMIT;",
                    'DB03_DESTINATION_COMMAND_DDL_REHEARSAL')
            except local.DomainLocalCIError as exc:
                if 'DB03_INJECTED_DESTINATION_COMMAND_FAILURE' not in str(exc):
                    raise
            else:
                raise RuntimeError('DB03_DESTINATION_COMMAND_EXPECTED_FAILURE_ABSENT')
            absent = local.run_psql(container,
                "SELECT count(*) FROM pg_proc WHERE pronamespace='app_private'::regnamespace AND proname IN('db03_destination_admin','db03_record_admission_destination');",
                'DB03_DESTINATION_COMMAND_ABSENT',tuples=True).strip()
            if absent != '0':
                raise RuntimeError('DB03_DESTINATION_COMMAND_ROLLBACK_INCOMPLETE')
            local.run_psql(container,'BEGIN;\n'+destination_command_sql+'\nCOMMIT;',
                           'DB03_DESTINATION_COMMAND_INSTALL')
            output=local.run_psql(container,destination_command_test,
                                  'DB03_DESTINATION_COMMAND_TEST')
            parse_tap(output,10)
            print('DB03_DESTINATION_COMMAND_DATABASE_PASS 10/10; no_production_seed=true')
            # DB08 owns category identity; this disposable catalog install does
            # not activate a school fee rule or a Finance discount.
            fee_catalog_sql = (ROOT / 'supabase/proposals/db08/01_fee_obligation_baseline.sql.draft').read_text()
            local.run_psql(container,'BEGIN;\n'+fee_catalog_sql+'\nCOMMIT;',
                           'DB03_CONCESSION_FEE_CATALOG_INSTALL')
            try:
                local.run_psql(container,'BEGIN;\n'+concession_sql+
                    "\nDO $failure$ BEGIN RAISE EXCEPTION 'DB03_INJECTED_CONCESSION_FAILURE'; END $failure$;\nCOMMIT;",
                    'DB03_CONCESSION_DDL_REHEARSAL')
            except local.DomainLocalCIError as exc:
                if 'DB03_INJECTED_CONCESSION_FAILURE' not in str(exc):
                    raise
            else:
                raise RuntimeError('DB03_CONCESSION_EXPECTED_FAILURE_ABSENT')
            absent = local.run_psql(container,
                "SELECT count(*) FROM pg_class WHERE relnamespace='app_private'::regnamespace AND relname IN ('admission_category_concessions','admission_concession_categories');",
                'DB03_CONCESSION_ROLLBACK_PROBE',tuples=True).strip()
            if absent != '0':
                raise RuntimeError('DB03_CONCESSION_ROLLBACK_INCOMPLETE')
            local.run_psql(container,'BEGIN;\n'+concession_sql+'\nCOMMIT;',
                           'DB03_CONCESSION_INSTALL')
            output=local.run_psql(container,concession_test,'DB03_CONCESSION_TEST')
            try:
                parse_tap(output,15)
            except RuntimeError:
                print('DB03_CONCESSION_TAP_DIAGNOSTIC\n' + output[-10000:], flush=True)
                raise
            print('DB03_CONCESSION_DATABASE_PASS 15/15; typed_category=true; no_writer=true')
            try:
                local.run_psql(container,'BEGIN;\n'+concession_command_sql+
                    "\nDO $failure$ BEGIN RAISE EXCEPTION 'DB03_INJECTED_CONCESSION_COMMAND_FAILURE'; END $failure$;\nCOMMIT;",
                    'DB03_CONCESSION_COMMAND_DDL_REHEARSAL')
            except local.DomainLocalCIError as exc:
                if 'DB03_INJECTED_CONCESSION_COMMAND_FAILURE' not in str(exc):
                    raise
            else:
                raise RuntimeError('DB03_CONCESSION_COMMAND_EXPECTED_FAILURE_ABSENT')
            absent=local.run_psql(container,
                "SELECT count(*) FROM pg_proc WHERE pronamespace='app_private'::regnamespace AND proname IN('db03_concession_admin','db03_record_applicant_concession');",
                'DB03_CONCESSION_COMMAND_ABSENT',tuples=True).strip()
            if absent != '0':
                raise RuntimeError('DB03_CONCESSION_COMMAND_ROLLBACK_INCOMPLETE')
            local.run_psql(container,'BEGIN;\n'+concession_command_sql+'\nCOMMIT;',
                           'DB03_CONCESSION_COMMAND_INSTALL')
            output=local.run_psql(container,concession_command_test,'DB03_CONCESSION_COMMAND_TEST')
            parse_tap(output,10)
            print('DB03_CONCESSION_COMMAND_DATABASE_PASS 10/10; no_production_seed=true')
            try:
                local.run_psql(container,'BEGIN;\n'+scholarship_approval_sql+
                    "\nDO $failure$ BEGIN RAISE EXCEPTION 'DB03_INJECTED_SCHOLARSHIP_APPROVAL_FAILURE'; END $failure$;\nCOMMIT;",
                    'DB03_SCHOLARSHIP_APPROVAL_DDL_REHEARSAL')
            except local.DomainLocalCIError as exc:
                if 'DB03_INJECTED_SCHOLARSHIP_APPROVAL_FAILURE' not in str(exc):
                    raise
            else:
                raise RuntimeError('DB03_SCHOLARSHIP_APPROVAL_EXPECTED_FAILURE_ABSENT')
            absent=local.run_psql(container,
                "SELECT (SELECT count(*) FROM pg_class WHERE relnamespace='app_private'::regnamespace AND relname='admission_concession_approval_bindings')+(SELECT count(*) FROM pg_proc WHERE pronamespace='app_private'::regnamespace AND (proname LIKE 'db03_%concession%approval%' OR proname IN('db03_concession_binding_guard','db03_concession_record_receipt')));",
                'DB03_SCHOLARSHIP_APPROVAL_ABSENT',tuples=True).strip()
            if absent != '0':
                raise RuntimeError('DB03_SCHOLARSHIP_APPROVAL_ROLLBACK_INCOMPLETE')
            local.run_psql(container,'BEGIN;\n'+scholarship_approval_sql+'\nCOMMIT;',
                           'DB03_SCHOLARSHIP_APPROVAL_INSTALL')
            output=local.run_psql(container,scholarship_approval_test,'DB03_SCHOLARSHIP_APPROVAL_TEST')
            parse_tap(output,16)
            print('DB03_SCHOLARSHIP_APPROVAL_DATABASE_PASS 16/16; no_production_seed=true')
            try:
                local.run_psql(container,'BEGIN;\n'+approved_scholarship_read_sql+
                    "\nDO $failure$ BEGIN RAISE EXCEPTION 'DB03_INJECTED_APPROVED_SCHOLARSHIP_READ_FAILURE'; END $failure$;\nCOMMIT;",
                    'DB03_APPROVED_SCHOLARSHIP_READ_DDL_REHEARSAL')
            except local.DomainLocalCIError as exc:
                if 'DB03_INJECTED_APPROVED_SCHOLARSHIP_READ_FAILURE' not in str(exc):
                    raise
            else:
                raise RuntimeError('DB03_APPROVED_SCHOLARSHIP_READ_EXPECTED_FAILURE_ABSENT')
            absent=local.run_psql(container,
                "SELECT count(*) FROM pg_proc WHERE pronamespace='app_private'::regnamespace AND proname='db03_pre_admission_approved_concession';",
                'DB03_APPROVED_SCHOLARSHIP_READ_ABSENT',tuples=True).strip()
            if absent != '0':
                raise RuntimeError('DB03_APPROVED_SCHOLARSHIP_READ_ROLLBACK_INCOMPLETE')
            local.run_psql(container,'BEGIN;\n'+approved_scholarship_read_sql+'\nCOMMIT;',
                           'DB03_APPROVED_SCHOLARSHIP_READ_INSTALL')
            output=local.run_psql(container,approved_scholarship_read_test,'DB03_APPROVED_SCHOLARSHIP_READ_TEST')
            parse_tap(output,8)
            print('DB03_APPROVED_SCHOLARSHIP_READ_DATABASE_PASS 8/8; no_production_seed=true')
            try:
                local.run_psql(container,'BEGIN;\n'+principal_final_sql+
                    "\nDO $failure$ BEGIN RAISE EXCEPTION 'DB03_INJECTED_PRINCIPAL_FINAL_SOURCE_FAILURE'; END $failure$;\nCOMMIT;",
                    'DB03_PRINCIPAL_FINAL_SOURCE_DDL_REHEARSAL')
            except local.DomainLocalCIError as exc:
                if 'DB03_INJECTED_PRINCIPAL_FINAL_SOURCE_FAILURE' not in str(exc):
                    raise
            else:
                raise RuntimeError('DB03_PRINCIPAL_FINAL_SOURCE_EXPECTED_FAILURE_ABSENT')
            absent=local.run_psql(container,
                "SELECT count(*) FROM pg_proc WHERE pronamespace='app_private'::regnamespace AND proname='db03_principal_final_source_snapshot';",
                'DB03_PRINCIPAL_FINAL_SOURCE_ABSENT',tuples=True).strip()
            if absent != '0':
                raise RuntimeError('DB03_PRINCIPAL_FINAL_SOURCE_ROLLBACK_INCOMPLETE')
            local.run_psql(container,'BEGIN;\n'+principal_final_sql+'\nCOMMIT;',
                           'DB03_PRINCIPAL_FINAL_SOURCE_INSTALL')
            output=local.run_psql(container,principal_final_test,'DB03_PRINCIPAL_FINAL_SOURCE_TEST')
            parse_tap(output,10)
            print('DB03_PRINCIPAL_FINAL_SOURCE_DATABASE_PASS 10/10; can_finalize=false')
            from destination_command_ci import run_destination_command
            run_destination_command(local,container,
                intake_fixture+'\n'+destination_command_fixture)
            return 0
    finally:
        if started:
            run(["supabase", "stop", "--project-id", local.EXPECTED_PROJECT_ID], cwd=foundation_root, timeout=300)
            print("DB03_S1_DISPOSABLE_STACK_STOPPED")


if __name__ == "__main__":
    try:
        sys.exit(main())
    except (RuntimeError, ValueError, OSError, subprocess.SubprocessError) as exc:
        print("DB03_S1_FAIL " + str(exc), file=sys.stderr)
        sys.exit(1)
