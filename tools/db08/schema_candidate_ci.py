"""DB08 F1/F2 disposable acceptance; never connects to hosted databases."""
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
DEPENDENCY_SHA = '06c2be2412e1699f3fa8f2804969e9808eb16e09'
TABLES = {'finance_currency_units', 'finance_fee_categories', 'finance_fee_rules',
          'finance_fee_rule_revisions', 'finance_fee_obligations'}
ASSERTIONS = 73


def validate_source():
    paths = sorted((ROOT / 'supabase/proposals/db08').glob('01_*.sql.draft'))
    if len(paths) != 1:
        raise RuntimeError('DB08_FRAGMENT_SCOPE')
    sql = paths[0].read_text()
    if set(re.findall(r'(?m)^CREATE TABLE app_private\.([a-z_]+)', sql)) != TABLES:
        raise RuntimeError('DB08_TABLE_SCOPE')
    outside = re.sub(r'\$([a-z_]*)\$.*?\$\1\$', '', sql, flags=re.S)
    if re.search(r'(?mi)^\s*(CREATE ROLE|ALTER ROLE|INSERT INTO|CREATE FUNCTION app\.)', outside):
        raise RuntimeError('DB08_NO_SEED_OR_BUSINESS_API')
    if len(re.findall(r'FORCE ROW LEVEL SECURITY;', sql)) != 5:
        raise RuntimeError('DB08_FORCED_RLS')
    test = (ROOT / 'supabase/tests/db08/01_fee_obligation_baseline.sql').read_text()
    if re.findall(r'SELECT plan\((\d+)\);', test) != [str(ASSERTIONS)] or len(re.findall(r'(?m)^SELECT (?:is|ok|throws_ok|lives_ok)\(', test)) != ASSERTIONS or not test.rstrip().endswith('ROLLBACK;'):
        raise RuntimeError('DB08_TEST_PLAN')
    if test.count('\\ir fixture.sql') != 1:
        raise RuntimeError('DB08_FIXTURE_SCOPE')
    test = test.replace('\\ir fixture.sql', (ROOT / 'supabase/tests/db08/fixture.sql').read_text())
    print(f'DB08_F1_SOURCE_PASS tables=5 assertions={ASSERTIONS} sha256=' + hashlib.sha256(sql.encode()).hexdigest(), flush=True)
    return sql, test


def validate_workflow_source():
    paths = sorted((ROOT / 'supabase/proposals/db08').glob('02_*.sql.draft'))
    if len(paths) != 3:
        raise RuntimeError('DB08_F2_FRAGMENT_SCOPE')
    sql = '\n'.join(p.read_text() for p in paths)
    if re.findall(r'(?m)^CREATE TABLE app_private\.([a-z_]+)', sql) != ['finance_fee_publications']:
        raise RuntimeError('DB08_F2_TABLE_SCOPE')
    if re.findall(r'(?m)^CREATE FUNCTION app\.([a-z_]+)', sql) != ['configure_finance_fee', 'assess_finance_fee']:
        raise RuntimeError('DB08_F2_PUBLIC_COMMAND_SCOPE')
    outside = re.sub(r'\$([a-z_]*)\$.*?\$\1\$', '', sql, flags=re.S)
    if re.search(r'(?mi)^\s*(CREATE ROLE|ALTER ROLE|INSERT INTO app_private\.permissions)\b', outside):
        raise RuntimeError('DB08_F2_SEED_OR_ROLE_CHANGE')
    test = (ROOT / 'supabase/tests/db08/02_finance_commands.sql').read_text()
    expected = 40
    if re.findall(r'SELECT plan\((\d+)\);', test) != [str(expected)] or len(re.findall(r'(?m)^SELECT (?:is|ok|throws_ok|lives_ok)\(', test)) != expected or not test.rstrip().endswith('ROLLBACK;'):
        raise RuntimeError('DB08_F2_TEST_PLAN')
    if test.count('\\ir fixture_commands.sql') != 1:
        raise RuntimeError('DB08_F2_FIXTURE_SCOPE')
    test = test.replace('\\ir fixture_commands.sql', (ROOT / 'supabase/tests/db08/fixture_commands.sql').read_text())
    print(f'DB08_F2_SOURCE_PASS fragments=3 assertions={expected} sha256=' + hashlib.sha256(sql.encode()).hexdigest(), flush=True)
    return sql, test, expected


def validate_change_source():
    paths = sorted((ROOT / 'supabase/proposals/db08').glob('03_*.sql.draft'))
    if len(paths) != 3:
        raise RuntimeError('DB08_F3_FRAGMENT_SCOPE')
    sql = '\n'.join(path.read_text() for path in paths)
    if re.findall(r'(?m)^CREATE TABLE app_private\.([a-z_]+)', sql) != ['finance_fee_change_intents']:
        raise RuntimeError('DB08_F3_TABLE_SCOPE')
    if re.findall(r'(?m)^CREATE FUNCTION app\.([a-z_]+)', sql) != ['request_finance_fee_change', 'review_finance_fee_change']:
        raise RuntimeError('DB08_F3_PUBLIC_COMMAND_SCOPE')
    test = (ROOT / 'supabase/tests/db08/03_fee_change.sql').read_text()
    expected = 28
    if re.findall(r'SELECT plan\((\d+)\);', test) != [str(expected)] or len(re.findall(r'(?m)^SELECT (?:is|ok|throws_ok)\(', test)) != expected or not test.rstrip().endswith('ROLLBACK;'):
        raise RuntimeError('DB08_F3_TEST_PLAN')
    for name in ('fixture_commands.sql', 'fixture_change.sql'):
        if test.count('\\ir ' + name) != 1:
            raise RuntimeError('DB08_F3_FIXTURE_SCOPE')
        test = test.replace('\\ir ' + name, (ROOT / 'supabase/tests/db08' / name).read_text())
    print(f'DB08_F3_SOURCE_PASS fragments=3 assertions={expected} sha256=' + hashlib.sha256(sql.encode()).hexdigest(), flush=True)
    return sql, test, expected


def validate_chain_source():
    paths = sorted((ROOT / 'supabase/proposals/db08').glob('04_*.sql.draft'))
    if len(paths) != 1:
        raise RuntimeError('DB08_F4_FRAGMENT_SCOPE')
    sql = paths[0].read_text()
    if len(re.findall(r'(?m)^CREATE FUNCTION app\.request_finance_fee_change', sql)) != 1 or len(re.findall(r'(?m)^CREATE OR REPLACE FUNCTION app\.review_finance_fee_change', sql)) != 1:
        raise RuntimeError('DB08_F4_COMMAND_SCOPE')
    test = (ROOT / 'supabase/tests/db08/04_fee_chain.sql').read_text()
    expected = 25
    if re.findall(r'SELECT plan\((\d+)\);', test) != [str(expected)] or len(re.findall(r'(?m)^SELECT (?:is|ok|throws_ok)\(', test)) != expected or not test.rstrip().endswith('ROLLBACK;'):
        raise RuntimeError('DB08_F4_TEST_PLAN')
    for name in ('fixture_commands.sql', 'fixture_change.sql', 'fixture_chain.sql'):
        if test.count('\\ir ' + name) != 1:
            raise RuntimeError('DB08_F4_FIXTURE_SCOPE')
        test = test.replace('\\ir ' + name, (ROOT / 'supabase/tests/db08' / name).read_text())
    print(f'DB08_F4_SOURCE_PASS fragments=1 assertions={expected} sha256=' + hashlib.sha256(sql.encode()).hexdigest(), flush=True)
    return sql, test, expected


def validate_selection_source():
    paths = sorted((ROOT / 'supabase/proposals/db08').glob('05_*.sql.draft'))
    if len(paths) != 3:
        raise RuntimeError('DB08_F5_FRAGMENT_SCOPE')
    sql = '\n'.join(path.read_text() for path in paths)
    if re.findall(r'(?m)^CREATE TABLE app_private\.([a-z_]+)', sql) != [
        'finance_fee_applicabilities', 'finance_fee_assessment_selections'
    ]:
        raise RuntimeError('DB08_F5_TABLE_SCOPE')
    if re.findall(r'(?m)^CREATE FUNCTION app\.([a-z_]+)', sql) != [
        'bind_finance_fee', 'assess_selected_finance_fee'
    ]:
        raise RuntimeError('DB08_F5_COMMAND_SCOPE')
    test = (ROOT / 'supabase/tests/db08/05_fee_selection.sql').read_text()
    expected = 24
    if re.findall(r'SELECT plan\((\d+)\);', test) != [str(expected)] or len(re.findall(
        r'(?m)^SELECT (?:is|ok|throws_ok)\(', test)) != expected or not test.rstrip().endswith('ROLLBACK;'):
        raise RuntimeError('DB08_F5_TEST_PLAN')
    for name in ('fixture_commands.sql', 'fixture_selection.sql'):
        if test.count('\\ir ' + name) != 1:
            raise RuntimeError('DB08_F5_FIXTURE_SCOPE')
        test = test.replace('\\ir ' + name, (ROOT / 'supabase/tests/db08' / name).read_text())
    print(f'DB08_F5_SOURCE_PASS fragments=3 assertions={expected} sha256=' +
          hashlib.sha256(sql.encode()).hexdigest(), flush=True)
    return sql, test, expected


def validate_discount_source():
    paths = sorted((ROOT / 'supabase/proposals/db08').glob('06_*.sql.draft'))
    if len(paths) != 5:
        raise RuntimeError('DB08_F6_FRAGMENT_SCOPE')
    sql = '\n'.join(path.read_text() for path in paths)
    if re.findall(r'(?m)^CREATE TABLE app_private\.([a-z_]+)', sql) != [
        'finance_discount_intents', 'finance_discount_adjustments'
    ]:
        raise RuntimeError('DB08_F6_TABLE_SCOPE')
    if re.findall(r'(?m)^CREATE FUNCTION app\.([a-z_]+)', sql) != [
        'request_finance_discount', 'review_finance_discount',
        'apply_finance_discount', 'assess_discounted_finance_fee'
    ]:
        raise RuntimeError('DB08_F6_COMMAND_SCOPE')
    test = (ROOT / 'supabase/tests/db08/06_student_discounts.sql').read_text()
    expected = 33
    if re.findall(r'SELECT plan\((\d+)\);', test) != [str(expected)] or len(re.findall(
        r'(?m)^SELECT (?:is|ok|throws_ok)\(', test)) != expected or not test.rstrip().endswith('ROLLBACK;'):
        raise RuntimeError('DB08_F6_TEST_PLAN')
    for name in ('fixture_commands.sql', 'fixture_change.sql',
                 'fixture_selection.sql', 'fixture_discount.sql'):
        if test.count('\\ir ' + name) != 1:
            raise RuntimeError('DB08_F6_FIXTURE_SCOPE')
        test = test.replace('\\ir ' + name,
                            (ROOT / 'supabase/tests/db08' / name).read_text())
    print(f'DB08_F6_SOURCE_PASS fragments=5 assertions={expected} sha256=' +
          hashlib.sha256(sql.encode()).hexdigest(), flush=True)
    return sql, test, expected


def validate_payment_baseline_source():
    paths = sorted((ROOT / 'supabase/proposals/db08').glob('07_*.sql.draft'))
    if len(paths) != 1:
        raise RuntimeError('DB08_F7_FRAGMENT_SCOPE')
    sql = paths[0].read_text()
    if re.findall(r'(?m)^CREATE TABLE app_private\.([a-z_]+)', sql) != [
        'finance_payment_submissions', 'finance_payment_reviews',
        'finance_official_payments'
    ] or re.search(r'(?m)^CREATE FUNCTION app\.', sql):
        raise RuntimeError('DB08_F7_STORAGE_SCOPE')
    if len(re.findall(r'FORCE ROW LEVEL SECURITY;', sql)) != 3:
        raise RuntimeError('DB08_F7_FORCED_RLS')
    test = (ROOT / 'supabase/tests/db08/07_payment_evidence_baseline.sql').read_text()
    expected = 27
    if re.findall(r'SELECT plan\((\d+)\);', test) != [str(expected)] or len(re.findall(
        r'(?m)^SELECT (?:is|ok|throws_ok|lives_ok)\(', test)) != expected or not test.rstrip().endswith('ROLLBACK;'):
        raise RuntimeError('DB08_F7_TEST_PLAN')
    for name in ('fixture_commands.sql', 'fixture_change.sql',
                 'fixture_selection.sql', 'fixture_payment.sql'):
        if test.count('\\ir ' + name) != 1:
            raise RuntimeError('DB08_F7_FIXTURE_SCOPE')
        test = test.replace('\\ir ' + name,
                            (ROOT / 'supabase/tests/db08' / name).read_text())
    print(f'DB08_F7_SOURCE_PASS fragments=1 assertions={expected} sha256=' +
          hashlib.sha256(sql.encode()).hexdigest(), flush=True)
    return sql, test, expected


def validate_bank_slip_source():
    paths = sorted((ROOT / 'supabase/proposals/db08').glob('08_*.sql.draft'))
    if len(paths) != 1:
        raise RuntimeError('DB08_F8_FRAGMENT_SCOPE')
    sql = paths[0].read_text()
    if re.findall(r'(?m)^CREATE FUNCTION app_private\.([a-z0-9_]+)', sql) != [
        'db08_submit_bank_slip', 'db08_bank_slip_preflight'
    ] or re.search(r'(?m)^CREATE FUNCTION app\.', sql):
        raise RuntimeError('DB08_F8_WORKER_ONLY_SCOPE')
    test = (ROOT / 'supabase/tests/db08/08_bank_slip_submission.sql').read_text()
    expected = 8
    if re.findall(r'SELECT plan\((\d+)\);', test) != [str(expected)] or len(re.findall(
        r'(?m)^SELECT (?:is|ok|throws_ok|lives_ok)\(', test)) != expected or not test.rstrip().endswith('ROLLBACK;'):
        raise RuntimeError('DB08_F8_TEST_PLAN')
    for name in ('fixture_commands.sql', 'fixture_change.sql',
                 'fixture_selection.sql', 'fixture_bank_slip.sql'):
        if test.count('\\ir ' + name) != 1:
            raise RuntimeError('DB08_F8_FIXTURE_SCOPE')
        test = test.replace('\\ir ' + name,
                            (ROOT / 'supabase/tests/db08' / name).read_text())
    print(f'DB08_F8_SOURCE_PASS fragments=1 assertions={expected} sha256=' +
          hashlib.sha256(sql.encode()).hexdigest(), flush=True)
    return sql, test, expected


def validate_bank_review_source():
    paths = sorted((ROOT / 'supabase/proposals/db08').glob('09_*.sql.draft'))
    if len(paths) != 1:
        raise RuntimeError('DB08_F9_FRAGMENT_SCOPE')
    sql = paths[0].read_text()
    if re.findall(r'(?m)^CREATE FUNCTION app_private\.([a-z0-9_]+)', sql) != [
        'db08_review_slip_authority', 'db08_review_slip_evidence',
        'db08_review_bank_slip'
    ] or re.search(r'(?m)^CREATE FUNCTION app\.', sql):
        raise RuntimeError('DB08_F9_WORKER_ONLY_SCOPE')
    test = (ROOT / 'supabase/tests/db08/09_bank_slip_review.sql').read_text()
    expected = 8
    if re.findall(r'SELECT plan\((\d+)\);', test) != [str(expected)] or len(re.findall(
        r'(?m)^SELECT (?:is|ok|throws_ok|lives_ok)\(', test)) != expected or not test.rstrip().endswith('ROLLBACK;'):
        raise RuntimeError('DB08_F9_TEST_PLAN')
    for name in ('fixture_commands.sql', 'fixture_change.sql',
                 'fixture_selection.sql', 'fixture_bank_slip.sql',
                 'fixture_bank_review.sql'):
        if test.count('\\ir ' + name) != 1:
            raise RuntimeError('DB08_F9_FIXTURE_SCOPE')
        test = test.replace('\\ir ' + name,
                            (ROOT / 'supabase/tests/db08' / name).read_text())
    print(f'DB08_F9_SOURCE_PASS fragments=1 assertions={expected} sha256=' +
          hashlib.sha256(sql.encode()).hexdigest(), flush=True)
    return sql, test, expected


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--foundation-root', type=Path)
    parser.add_argument('--source-only', action='store_true')
    args = parser.parse_args()
    sql, test = validate_source()
    workflow_sql, workflow_test, workflow_assertions = validate_workflow_source()
    change_sql, change_test, change_assertions = validate_change_source()
    chain_sql, chain_test, chain_assertions = validate_chain_source()
    selection_sql, selection_test, selection_assertions = validate_selection_source()
    discount_sql, discount_test, discount_assertions = validate_discount_source()
    payment_sql, payment_test, payment_assertions = validate_payment_baseline_source()
    bank_sql, bank_test, bank_assertions = validate_bank_slip_source()
    review_sql, review_test, review_assertions = validate_bank_review_source()
    if args.source_only:
        return 0
    if os.environ.get('GITHUB_ACTIONS') != 'true' or args.foundation_root is None:
        raise RuntimeError('DB08_DISPOSABLE_GITHUB_CI_REQUIRED')
    subprocess.run([sys.executable, '-m', 'unittest',
                    'services.payment_evidence.tests.test_service', '-v'],
                   cwd=ROOT, check=True)
    foundation = args.foundation_root.resolve()
    if subprocess.check_output(['git', '-C', str(foundation), 'rev-parse', 'HEAD'], text=True).strip() != DEPENDENCY_SHA:
        raise RuntimeError('DB08_FOUNDATION_PIN_MISMATCH')
    source = json.loads((ROOT / 'supabase/config/foundation_managed_contract.json').read_text())
    for item in source['frozen_foundation']['migrations']:
        if hashlib.sha256((foundation / 'supabase/migrations' / item['file']).read_bytes()).hexdigest() != item['sha256']:
            raise RuntimeError('DB08_FOUNDATION_HASH_MISMATCH')
    sys.path.insert(0, str(foundation / 'tools/supabase'))
    import domain_local_ci as local
    from _process import run
    from foundation_guard import inspect_local_config, inspect_source, load_contract
    from foundation_local_ci import cli_version, parse_tap, ensure_local_auth_route
    from prepare_local_auth_fixtures import local_status, prepare
    contract = load_contract()
    errors, _, _ = inspect_source(foundation, contract, require_lf=True, future='fail')
    if errors:
        raise RuntimeError('DB08_FOUNDATION_SOURCE_FAIL')
    inspect_local_config(foundation, contract)
    cli_version(contract)
    if run(['docker', 'info', '--format', '{{.OSType}}'], cwd=foundation, timeout=40).strip() != 'linux' or local._stack_running():
        raise RuntimeError('DB08_REQUIRES_FRESH_LINUX_STACK')
    started = False
    container = 'supabase_db_' + local.EXPECTED_PROJECT_ID
    try:
        with local.local_postgres_image_pin():
            started = True
            local._start_disposable_stack()
            image = run(['docker', 'inspect', '--format', '{{.Config.Image}}', container], cwd=foundation, timeout=20).strip()
            if image not in {p + local.EXPECTED_POSTGRES_TAG for p in ('supabase/postgres:', 'ghcr.io/supabase/postgres:', 'public.ecr.aws/supabase/postgres:')}:
                raise RuntimeError('DB08_POSTGRES_PIN_MISMATCH')
            run(['supabase', 'db', 'reset', '--local', '--no-seed'], cwd=foundation, timeout=900)
            baseline = local.run_foundation_regression(contract, catalog_only=True)
            try:
                local.run_psql(container, 'BEGIN;\n' + sql + "\nDO $failure$ BEGIN RAISE EXCEPTION 'DB08_INJECTED_DDL_FAILURE'; END $failure$;\nCOMMIT;", 'DB08_FAILED_INSTALL')
            except local.DomainLocalCIError as exc:
                if 'DB08_INJECTED_DDL_FAILURE' not in str(exc):
                    raise
            else:
                raise RuntimeError('DB08_MISSING_EXPECTED_FAILURE')
            absent = local.run_psql(container, "SELECT (SELECT count(*) FROM pg_class WHERE relnamespace='app_private'::regnamespace AND relname LIKE 'finance_%')+(SELECT count(*) FROM pg_proc WHERE pronamespace='app_private'::regnamespace AND proname LIKE 'db08_%');", 'DB08_ROLLBACK_ABSENCE', tuples=True).strip()
            if absent != '0':
                raise RuntimeError('DB08_PARTIAL_INSTALL_SURVIVED')
            print('DB08_F1_DDL_ROLLBACK_PASS tables=0 functions=0', flush=True)
            local.run_psql(container, 'BEGIN;\n' + sql + '\nCOMMIT;', 'DB08_INSTALL')
            try:
                output = local.run_psql(container, test, 'DB08_STRUCTURE_TEST')
                print(output, flush=True)
                parse_tap(output, ASSERTIONS)
            except local.DomainLocalCIError:
                local.run_psql(container, '\\o /dev/null\n' + test, 'DB08_STRUCTURE_SQL_DIAGNOSTIC')
                raise
            remaining = local.run_psql(container, "SELECT (SELECT count(*) FROM app_private.finance_fee_obligations)+(SELECT count(*) FROM app_private.finance_fee_rules)+(SELECT count(*) FROM app_private.finance_fee_rule_revisions)+(SELECT count(*) FROM app_private.finance_fee_categories)+(SELECT count(*) FROM app_private.finance_currency_units)+(SELECT count(*) FROM app_private.school_profiles)+(SELECT count(*) FROM app_private.people)+(SELECT count(*) FROM app_private.principals);", 'DB08_FIXTURE_CLEANUP', tuples=True).strip()
            if remaining != '0':
                raise RuntimeError('DB08_FIXTURE_ROLLBACK_INCOMPLETE')
            url, key = local_status()
            ensure_local_auth_route(url)
            try:
                if len(prepare(url, key)) != 5:
                    raise RuntimeError('DB08_AUTH_FIXTURES')
            finally:
                key = None
            total = baseline + local.run_foundation_regression(contract)
            if total != 220:
                raise RuntimeError('DB08_FOUNDATION_ASSERTION_COUNT')
            print(f'DB08_F1_DATABASE_PASS {ASSERTIONS}/{ASSERTIONS}; frozen_Foundation=220/220; fixtures_rolled_back=true; business_APIs=0; clearance_issuance=false', flush=True)
            try:
                local.run_psql(container, 'BEGIN;\n' + workflow_sql + "\nDO $failure$ BEGIN RAISE EXCEPTION 'DB08_INJECTED_F2_FAILURE'; END $failure$;\nCOMMIT;", 'DB08_F2_FAILED_INSTALL')
            except local.DomainLocalCIError as exc:
                if 'DB08_INJECTED_F2_FAILURE' not in str(exc):
                    raise
            else:
                raise RuntimeError('DB08_F2_EXPECTED_FAILURE_ABSENT')
            absent = local.run_psql(container, "SELECT (SELECT count(*) FROM pg_class WHERE relnamespace='app_private'::regnamespace AND relname='finance_fee_publications')+(SELECT count(*) FROM pg_proc WHERE proname IN('db08_fee_actor','db08_fee_receipt','configure_finance_fee','assess_finance_fee') AND pronamespace IN('app_private'::regnamespace,'app'::regnamespace));", 'DB08_F2_ROLLBACK_ABSENCE', tuples=True).strip()
            if absent != '0':
                raise RuntimeError('DB08_F2_PARTIAL_INSTALL_SURVIVED')
            print('DB08_F2_DDL_ROLLBACK_PASS publication=0 functions=0', flush=True)
            local.run_psql(container, 'BEGIN;\n' + workflow_sql + '\nCOMMIT;', 'DB08_F2_INSTALL')
            try:
                output = local.run_psql(container, workflow_test, 'DB08_F2_COMMAND_TEST')
                print(output, flush=True)
                parse_tap(output, workflow_assertions)
            except local.DomainLocalCIError:
                local.run_psql(container, '\\o /dev/null\n' + workflow_test, 'DB08_F2_SQL_DIAGNOSTIC')
                raise
            remaining = local.run_psql(container, "SELECT (SELECT count(*) FROM app_private.finance_fee_publications)+(SELECT count(*) FROM app_private.finance_fee_obligations)+(SELECT count(*) FROM app_private.finance_fee_rules)+(SELECT count(*) FROM app_private.command_receipts)+(SELECT count(*) FROM app_private.audit_events)+(SELECT count(*) FROM app_private.outbox_events)+(SELECT count(*) FROM app_private.school_profiles)+(SELECT count(*) FROM app_private.principals);", 'DB08_F2_FIXTURE_CLEANUP', tuples=True).strip()
            if remaining != '0':
                raise RuntimeError('DB08_F2_FIXTURE_ROLLBACK_INCOMPLETE')
            print(f'DB08_F2_DATABASE_PASS {workflow_assertions}/{workflow_assertions}; frozen_Foundation=220/220; fixtures_rolled_back=true; financial_clearance=false', flush=True)
            try:
                local.run_psql(container, 'BEGIN;\n' + change_sql + "\nDO $failure$ BEGIN RAISE EXCEPTION 'DB08_INJECTED_F3_FAILURE'; END $failure$;\nCOMMIT;", 'DB08_F3_FAILED_INSTALL')
            except local.DomainLocalCIError as exc:
                if 'DB08_INJECTED_F3_FAILURE' not in str(exc):
                    raise
            else:
                raise RuntimeError('DB08_F3_EXPECTED_FAILURE_ABSENT')
            absent = local.run_psql(container, "SELECT (SELECT count(*) FROM pg_class WHERE relnamespace='app_private'::regnamespace AND relname='finance_fee_change_intents')+(SELECT count(*) FROM pg_proc WHERE proname IN('db08_change_actor','db08_change_reviewer_candidate','db08_change_receipt','request_finance_fee_change','review_finance_fee_change') AND pronamespace IN('app_private'::regnamespace,'app'::regnamespace));", 'DB08_F3_ROLLBACK_ABSENCE', tuples=True).strip()
            if absent != '0':
                raise RuntimeError('DB08_F3_PARTIAL_INSTALL_SURVIVED')
            print('DB08_F3_DDL_ROLLBACK_PASS intent=0 functions=0', flush=True)
            local.run_psql(container, 'BEGIN;\n' + change_sql + '\nCOMMIT;', 'DB08_F3_INSTALL')
            try:
                output = local.run_psql(container, change_test, 'DB08_F3_COMMAND_TEST')
                print(output, flush=True)
                parse_tap(output, change_assertions)
            except local.DomainLocalCIError:
                local.run_psql(container, '\\o /dev/null\n' + change_test, 'DB08_F3_SQL_DIAGNOSTIC')
                raise
            remaining = local.run_psql(container, "SELECT (SELECT count(*) FROM app_private.finance_fee_change_intents)+(SELECT count(*) FROM app_private.finance_fee_publications)+(SELECT count(*) FROM app_private.approval_requests)+(SELECT count(*) FROM app_private.approval_reviews)+(SELECT count(*) FROM app_private.finance_fee_obligations)+(SELECT count(*) FROM app_private.command_receipts);", 'DB08_F3_FIXTURE_CLEANUP', tuples=True).strip()
            if remaining != '0':
                raise RuntimeError('DB08_F3_FIXTURE_ROLLBACK_INCOMPLETE')
            print(f'DB08_F3_DATABASE_PASS {change_assertions}/{change_assertions}; fixtures_rolled_back=true; financial_clearance=false', flush=True)
            try:
                local.run_psql(container, 'BEGIN;\n' + chain_sql + "\nDO $failure$ BEGIN RAISE EXCEPTION 'DB08_INJECTED_F4_FAILURE'; END $failure$;\nCOMMIT;", 'DB08_F4_FAILED_INSTALL')
            except local.DomainLocalCIError as exc:
                if 'DB08_INJECTED_F4_FAILURE' not in str(exc):
                    raise
            else:
                raise RuntimeError('DB08_F4_EXPECTED_FAILURE_ABSENT')
            absent = local.run_psql(container, "SELECT count(*) FROM pg_proc WHERE pronamespace='app'::regnamespace AND proname='request_finance_fee_change' AND oidvectortypes(proargtypes) LIKE '%uuid[]%';", 'DB08_F4_ROLLBACK_ABSENCE', tuples=True).strip()
            if absent != '0':
                raise RuntimeError('DB08_F4_PARTIAL_INSTALL_SURVIVED')
            print('DB08_F4_DDL_ROLLBACK_PASS chain_rpc=0', flush=True)
            local.run_psql(container, 'BEGIN;\n' + chain_sql + '\nCOMMIT;', 'DB08_F4_INSTALL')
            try:
                output = local.run_psql(container, chain_test, 'DB08_F4_COMMAND_TEST')
                print(output, flush=True)
                parse_tap(output, chain_assertions)
            except local.DomainLocalCIError:
                local.run_psql(container, '\\o /dev/null\n' + chain_test, 'DB08_F4_SQL_DIAGNOSTIC')
                raise
            remaining = local.run_psql(container, "SELECT (SELECT count(*) FROM app_private.finance_fee_change_intents)+(SELECT count(*) FROM app_private.finance_fee_publications)+(SELECT count(*) FROM app_private.approval_requests)+(SELECT count(*) FROM app_private.approval_reviews)+(SELECT count(*) FROM app_private.finance_fee_obligations)+(SELECT count(*) FROM app_private.command_receipts);", 'DB08_F4_FIXTURE_CLEANUP', tuples=True).strip()
            if remaining != '0':
                raise RuntimeError('DB08_F4_FIXTURE_ROLLBACK_INCOMPLETE')
            print(f'DB08_F4_DATABASE_PASS {chain_assertions}/{chain_assertions}; fixtures_rolled_back=true; financial_clearance=false', flush=True)
            # Persist only in the disposable stack to exercise real Auth/Data API
            # and independent PostgreSQL backends with observable blocking.
            fixture = (ROOT / 'supabase/tests/db08/fixture_commands.sql').read_text()
            change_fixture = (ROOT / 'supabase/tests/db08/fixture_change.sql').read_text()
            chain_fixture = (ROOT / 'supabase/tests/db08/fixture_chain.sql').read_text()
            local.run_psql(container, 'BEGIN;\n' + fixture + '\n' + change_fixture + '\n' + chain_fixture + '\nCOMMIT;', 'DB08_REAL_AUTH_FIXTURE')
            sys.path.insert(0, str(ROOT))
            from tools.db08.finance_runtime_ci import run_finance_runtime
            run_finance_runtime(local_status)
            # The earlier real Auth actors intentionally commit in their
            # disposable stack. Reset before F5 so its transaction-scoped
            # Foundation/D1/Finance fixtures cannot collide with those IDs.
            run(['supabase', 'db', 'reset', '--local', '--no-seed'], cwd=foundation, timeout=900)
            url, key = local_status()
            if len(prepare(url, key)) != 5:
                raise RuntimeError('DB08_F5_AUTH_FIXTURES')
            key = None
            local.run_psql(container, 'BEGIN;\n' + sql + '\n' + workflow_sql +
                '\n' + change_sql + '\n' + chain_sql + '\nCOMMIT;', 'DB08_F5_PREREQUISITES')
            # F5 reads the actual D1 class, Student and Enrollment identities.
            # Apply the immutable D1 draft chain only inside this disposable stack.
            sys.path.insert(0, str(ROOT / 'tools/supabase'))
            from domain_local_ci import assemble_draft_chain
            d1_files, d1_sql = assemble_draft_chain(ROOT)
            local.run_psql(container, d1_sql, 'DB08_F5_D1_INSTALL', timeout=1200)
            print(f'DB08_F5_D1_DEPENDENCY_PASS fragments={len(d1_files)}', flush=True)
            try:
                local.run_psql(container, 'BEGIN;\n' + selection_sql +
                    "\nDO $failure$ BEGIN RAISE EXCEPTION 'DB08_INJECTED_F5_FAILURE'; END $failure$;\nCOMMIT;",
                    'DB08_F5_FAILED_INSTALL')
            except local.DomainLocalCIError as exc:
                if 'DB08_INJECTED_F5_FAILURE' not in str(exc):
                    raise
            else:
                raise RuntimeError('DB08_F5_EXPECTED_FAILURE_ABSENT')
            absent = local.run_psql(container, "SELECT count(*) FROM pg_class WHERE relnamespace='app_private'::regnamespace AND relname IN('finance_fee_applicabilities','finance_fee_assessment_selections');", 'DB08_F5_ROLLBACK_ABSENCE', tuples=True).strip()
            if absent != '0':
                raise RuntimeError('DB08_F5_PARTIAL_INSTALL_SURVIVED')
            print('DB08_F5_DDL_ROLLBACK_PASS tables=0', flush=True)
            local.run_psql(container, 'BEGIN;\n' + selection_sql + '\nCOMMIT;', 'DB08_F5_INSTALL')
            try:
                output = local.run_psql(container, selection_test, 'DB08_F5_SELECTION_TEST')
                print(output, flush=True)
                parse_tap(output, selection_assertions)
            except local.DomainLocalCIError:
                # Suppress pgtap/stdout so psql's actual SQLSTATE and context
                # survive the runner's bounded diagnostic tail.
                local.run_psql(container, '\\o /dev/null\n' + selection_test,
                               'DB08_F5_SQL_DIAGNOSTIC')
                raise
            remaining = local.run_psql(container, "SELECT (SELECT count(*) FROM app_private.finance_fee_applicabilities)+(SELECT count(*) FROM app_private.finance_fee_assessment_selections)+(SELECT count(*) FROM app_private.finance_fee_obligations)+(SELECT count(*) FROM app_private.students)+(SELECT count(*) FROM app_private.enrollments)+(SELECT count(*) FROM app_private.command_receipts)+(SELECT count(*) FROM app_private.school_profiles);", 'DB08_F5_FIXTURE_CLEANUP', tuples=True).strip()
            if remaining != '0':
                raise RuntimeError('DB08_F5_FIXTURE_ROLLBACK_INCOMPLETE')
            print(f'DB08_F5_DATABASE_PASS {selection_assertions}/{selection_assertions}; fixtures_rolled_back=true; discounts=false', flush=True)
            from tools.db08.selection_runtime_ci import run_selection_runtime
            run_selection_runtime(local_status, ROOT)
            remaining = local.run_psql(container, "SELECT (SELECT count(*) FROM app_private.finance_fee_applicabilities)+(SELECT count(*) FROM app_private.finance_fee_assessment_selections)+(SELECT count(*) FROM app_private.finance_fee_obligations)+(SELECT count(*) FROM app_private.students)+(SELECT count(*) FROM app_private.enrollments)+(SELECT count(*) FROM app_private.school_profiles);", 'DB08_F5_REAL_AUTH_CLEANUP', tuples=True).strip()
            if remaining != '0':
                raise RuntimeError('DB08_F5_REAL_AUTH_ROLLBACK_INCOMPLETE')
            try:
                local.run_psql(container, 'BEGIN;\n' + discount_sql +
                    "\nDO $failure$ BEGIN RAISE EXCEPTION 'DB08_INJECTED_F6_FAILURE'; END $failure$;\nCOMMIT;",
                    'DB08_F6_FAILED_INSTALL')
            except local.DomainLocalCIError as exc:
                if 'DB08_INJECTED_F6_FAILURE' not in str(exc):
                    raise
            else:
                raise RuntimeError('DB08_F6_EXPECTED_FAILURE_ABSENT')
            absent = local.run_psql(container, "SELECT count(*) FROM pg_class WHERE relnamespace='app_private'::regnamespace AND relname IN('finance_discount_intents','finance_discount_adjustments');", 'DB08_F6_ROLLBACK_ABSENCE', tuples=True).strip()
            if absent != '0':
                raise RuntimeError('DB08_F6_PARTIAL_INSTALL_SURVIVED')
            print('DB08_F6_DDL_ROLLBACK_PASS tables=0', flush=True)
            local.run_psql(container, 'BEGIN;\n' + discount_sql + '\nCOMMIT;', 'DB08_F6_INSTALL')
            try:
                output = local.run_psql(container, discount_test, 'DB08_F6_DISCOUNT_TEST')
                print(output, flush=True)
                parse_tap(output, discount_assertions)
            except local.DomainLocalCIError:
                local.run_psql(container, '\\o /dev/null\n' + discount_test,
                               'DB08_F6_SQL_DIAGNOSTIC')
                raise
            remaining = local.run_psql(container, "SELECT (SELECT count(*) FROM app_private.finance_discount_intents)+(SELECT count(*) FROM app_private.finance_discount_adjustments)+(SELECT count(*) FROM app_private.finance_fee_obligations)+(SELECT count(*) FROM app_private.command_receipts)+(SELECT count(*) FROM app_private.school_profiles);", 'DB08_F6_FIXTURE_CLEANUP', tuples=True).strip()
            if remaining != '0':
                raise RuntimeError('DB08_F6_FIXTURE_ROLLBACK_INCOMPLETE')
            print(f'DB08_F6_DATABASE_PASS {discount_assertions}/{discount_assertions}; fixtures_rolled_back=true; money_scale=2; independent_review=true', flush=True)
            from tools.db08.discount_runtime_ci import run_discount_runtime
            run_discount_runtime(local_status, ROOT)
            remaining = local.run_psql(container, "SELECT (SELECT count(*) FROM app_private.finance_discount_intents)+(SELECT count(*) FROM app_private.finance_discount_adjustments)+(SELECT count(*) FROM app_private.finance_fee_obligations)+(SELECT count(*) FROM app_private.students)+(SELECT count(*) FROM app_private.school_profiles);", 'DB08_F6_REAL_AUTH_CLEANUP', tuples=True).strip()
            if remaining != '0':
                raise RuntimeError('DB08_F6_REAL_AUTH_ROLLBACK_INCOMPLETE')
            try:
                local.run_psql(container, 'BEGIN;\n' + payment_sql +
                    "\nDO $failure$ BEGIN RAISE EXCEPTION 'DB08_INJECTED_F7_FAILURE'; END $failure$;\nCOMMIT;",
                    'DB08_F7_FAILED_INSTALL')
            except local.DomainLocalCIError as exc:
                if 'DB08_INJECTED_F7_FAILURE' not in str(exc):
                    raise
            else:
                raise RuntimeError('DB08_F7_EXPECTED_FAILURE_ABSENT')
            absent = local.run_psql(container, "SELECT count(*) FROM pg_class WHERE relnamespace='app_private'::regnamespace AND relname IN('finance_payment_submissions','finance_payment_reviews','finance_official_payments');", 'DB08_F7_ROLLBACK_ABSENCE', tuples=True).strip()
            if absent != '0':
                raise RuntimeError('DB08_F7_PARTIAL_INSTALL_SURVIVED')
            print('DB08_F7_DDL_ROLLBACK_PASS tables=0', flush=True)
            local.run_psql(container, 'BEGIN;\n' + payment_sql + '\nCOMMIT;', 'DB08_F7_INSTALL')
            try:
                output = local.run_psql(container, payment_test, 'DB08_F7_STORAGE_TEST')
                print(output, flush=True)
                parse_tap(output, payment_assertions)
            except local.DomainLocalCIError:
                local.run_psql(container, '\\o /dev/null\n' + payment_test,
                               'DB08_F7_SQL_DIAGNOSTIC')
                raise
            remaining = local.run_psql(container, "SELECT (SELECT count(*) FROM app_private.finance_payment_submissions)+(SELECT count(*) FROM app_private.finance_payment_reviews)+(SELECT count(*) FROM app_private.finance_official_payments)+(SELECT count(*) FROM app_private.file_objects)+(SELECT count(*) FROM app_private.students)+(SELECT count(*) FROM app_private.school_profiles);", 'DB08_F7_FIXTURE_CLEANUP', tuples=True).strip()
            if remaining != '0':
                raise RuntimeError('DB08_F7_FIXTURE_ROLLBACK_INCOMPLETE')
            print(f'DB08_F7_DATABASE_PASS {payment_assertions}/{payment_assertions}; fixtures_rolled_back=true; client_payment_rpc=false', flush=True)
            try:
                local.run_psql(container, 'BEGIN;\n' + bank_sql +
                    "\nDO $failure$ BEGIN RAISE EXCEPTION 'DB08_INJECTED_F8_FAILURE'; END $failure$;\nCOMMIT;",
                    'DB08_F8_FAILED_INSTALL')
            except local.DomainLocalCIError as exc:
                if 'DB08_INJECTED_F8_FAILURE' not in str(exc):
                    raise
            else:
                raise RuntimeError('DB08_F8_EXPECTED_FAILURE_ABSENT')
            absent = local.run_psql(container,
                "SELECT count(*) FROM pg_proc WHERE pronamespace='app_private'::regnamespace AND proname IN('db08_submit_bank_slip','db08_bank_slip_preflight');",
                'DB08_F8_ROLLBACK_ABSENCE', tuples=True).strip()
            if absent != '0':
                raise RuntimeError('DB08_F8_PARTIAL_INSTALL_SURVIVED')
            local.run_psql(container, 'BEGIN;\n' + bank_sql + '\nCOMMIT;', 'DB08_F8_INSTALL')
            try:
                output = local.run_psql(container, bank_test, 'DB08_F8_SUBMISSION_TEST')
                print(output, flush=True)
                parse_tap(output, bank_assertions)
            except local.DomainLocalCIError:
                local.run_psql(container, '\\o /dev/null\n' + bank_test,
                               'DB08_F8_SQL_DIAGNOSTIC')
                raise
            remaining = local.run_psql(container,
                "SELECT (SELECT count(*) FROM app_private.finance_payment_submissions)+(SELECT count(*) FROM app_private.finance_official_payments)+(SELECT count(*) FROM app_private.file_objects)+(SELECT count(*) FROM app_private.students)+(SELECT count(*) FROM app_private.school_profiles);",
                'DB08_F8_FIXTURE_CLEANUP', tuples=True).strip()
            if remaining != '0':
                raise RuntimeError('DB08_F8_FIXTURE_ROLLBACK_INCOMPLETE')
            print(f'DB08_F8_DATABASE_PASS {bank_assertions}/{bank_assertions}; fixtures_rolled_back=true; official_payment=false', flush=True)
            try:
                local.run_psql(container, 'BEGIN;\n' + review_sql +
                    "\nDO $failure$ BEGIN RAISE EXCEPTION 'DB08_INJECTED_F9_FAILURE'; END $failure$;\nCOMMIT;",
                    'DB08_F9_FAILED_INSTALL')
            except local.DomainLocalCIError as exc:
                if 'DB08_INJECTED_F9_FAILURE' not in str(exc):
                    raise
            else:
                raise RuntimeError('DB08_F9_EXPECTED_FAILURE_ABSENT')
            absent = local.run_psql(container,
                "SELECT count(*) FROM pg_proc WHERE pronamespace='app_private'::regnamespace AND proname IN('db08_review_slip_authority','db08_review_slip_evidence','db08_review_bank_slip');",
                'DB08_F9_ROLLBACK_ABSENCE', tuples=True).strip()
            if absent != '0':
                raise RuntimeError('DB08_F9_PARTIAL_INSTALL_SURVIVED')
            local.run_psql(container, 'BEGIN;\n' + review_sql + '\nCOMMIT;', 'DB08_F9_INSTALL')
            output = local.run_psql(container, review_test, 'DB08_F9_REVIEW_TEST')
            print(output, flush=True)
            parse_tap(output, review_assertions)
            print(f'DB08_F9_DATABASE_PASS {review_assertions}/{review_assertions}; fixtures_rolled_back=true', flush=True)
            from tools.db08.payment_runtime_ci import run_payment_runtime
            run_payment_runtime(local_status, ROOT)
            # Real worker and Auth checks commit only in the disposable stack.
            run(['supabase', 'db', 'reset', '--local', '--no-seed'], cwd=foundation, timeout=900)
            remaining = local.run_psql(container,
                "SELECT count(*) FROM app_private.school_profiles;",
                'DB08_F8_REAL_AUTH_RESET', tuples=True).strip()
            if remaining != '0':
                raise RuntimeError('DB08_F8_REAL_AUTH_CLEANUP')
            return 0
    finally:
        if started:
            run(['supabase', 'stop', '--project-id', local.EXPECTED_PROJECT_ID], cwd=foundation, timeout=300)
            print('DB08_DISPOSABLE_STACK_STOPPED', flush=True)


if __name__ == '__main__':
    raise SystemExit(main())
