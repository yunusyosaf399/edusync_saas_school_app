"""Source-only integration guard for the non-executable D1 Migration 10 draft chain."""

from __future__ import annotations

import argparse
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
MIGRATIONS = Path("supabase/migrations")
BASE_NAME = "20260928000000_domain_package_01.sql.draft"
PREFIX = "20260928000000_domain_package_01"
EXPECTED_TABLES = (
    "academic_classes", "subjects", "class_offerings", "section_offerings",
    "section_room_assignments", "capacity_revisions", "student_id_allocator_states",
    "roll_policy_revisions", "roll_allocator_states", "roll_allocations", "students",
    "student_identity_details", "student_special_details", "student_status_transitions",
    "enrollments", "enrollment_capacity_overrides", "families", "family_relationships",
    "family_principal_memberships", "family_student_access", "student_primary_family_contexts",
    "student_emergency_contacts", "departments", "designations", "employees",
    "employment_periods", "employee_identity_details", "employee_qualifications",
    "employee_experience_entries", "employee_job_assignments", "employee_campus_affiliations",
    "teacher_capabilities", "class_teacher_assignments", "subject_teacher_assignments",
)
UUID_TUPLE_RE = re.compile(r"\(\s*'([0-9a-f]{8}(?:-[0-9a-f]{4}){3}-[0-9a-f]{12})'\s*,\s*'([^']+)'", re.I)
CREATE_TABLE_RE = re.compile(r"\bCREATE\s+TABLE\s+app_private\.([a-z0-9_]+)\s*\(", re.I)
PUBLIC_TABLE_RE = re.compile(r"\bCREATE\s+TABLE\s+app\.([a-z0-9_]+)\s*\(", re.I)
DEFINER_HEADER_RE = re.compile(
    r"\bCREATE(?:\s+OR\s+REPLACE)?\s+FUNCTION\s+((?:app|app_private)\.[a-z0-9_]+)\s*\([^;]*?\)\s*RETURNS\b(?P<header>.*?)(?=\bAS\s+\$[a-z0-9_]*\$)",
    re.I | re.S,
)


class GuardError(ValueError):
    pass


def discover_drafts(root: Path) -> list[Path]:
    mig = root / MIGRATIONS
    drafts = sorted(mig.glob(PREFIX + "*.sql.draft"), key=lambda p: p.name)
    if not drafts or drafts[0].name != BASE_NAME:
        raise GuardError("Migration 10 base draft missing or not first in lexical order")
    executable = sorted(p.name for p in mig.glob(PREFIX + "*.sql"))
    if executable:
        raise GuardError("Migration 10 must remain non-executable: " + ",".join(executable))
    return drafts


def _read_chain(drafts: list[Path]) -> str:
    chunks: list[str] = []
    for path in drafts:
        raw = path.read_bytes()
        if not raw:
            raise GuardError("empty D1 draft fragment: " + path.name)
        if b"\r\n" in raw:
            raise GuardError("CRLF D1 draft fragment: " + path.name)
        chunks.append(raw.decode("utf-8"))
    return "\n".join(chunks)


def _registrar_body(text: str) -> str:
    start = text.find("CREATE FUNCTION app_private.d1_register_catalog_v1()")
    if start < 0:
        raise GuardError("D1 registrar function missing")
    end = text.find("END $body$;", start)
    if end < 0:
        raise GuardError("D1 registrar function terminator missing")
    return text[start:end + len("END $body$;")]


def _manifest_blocks(registrar: str) -> list[str]:
    marker = "FOR item IN SELECT * FROM (VALUES"
    starts = [m.start() for m in re.finditer(re.escape(marker), registrar)]
    if len(starts) != 3:
        raise GuardError(f"D1 registrar must contain exactly three manifest VALUES blocks, found {len(starts)}")
    blocks: list[str] = []
    for start in starts:
        loop = registrar.find("LOOP", start)
        if loop < 0:
            raise GuardError("unterminated D1 registrar VALUES block")
        blocks.append(registrar[start:loop])
    return blocks


def inspect(root: Path) -> tuple[list[str], dict[str, int]]:
    root = Path(root)
    errors: list[str] = []
    try:
        drafts = discover_drafts(root)
        text = _read_chain(drafts)
    except (OSError, UnicodeDecodeError, GuardError) as exc:
        return [str(exc)], {}

    tables = CREATE_TABLE_RE.findall(text)
    if len(tables) != len(set(tables)):
        errors.append("D1 base relation CREATE TABLE is duplicated")
    if set(tables) != set(EXPECTED_TABLES):
        missing = sorted(set(EXPECTED_TABLES) - set(tables))
        extra = sorted(set(tables) - set(EXPECTED_TABLES))
        errors.append(f"D1 relation catalog mismatch missing={missing} extra={extra}")
    public_tables = PUBLIC_TABLE_RE.findall(text)
    if public_tables:
        errors.append("D1 base table created in app schema: " + ",".join(sorted(set(public_tables))))

    if re.search(r"\bALTER\s+TABLE\s+app_private\.[a-z0-9_]+\s+DISABLE\s+ROW\s+LEVEL\s+SECURITY\b", text, re.I):
        errors.append("D1 draft contains DISABLE ROW LEVEL SECURITY")
    for table in EXPECTED_TABLES:
        esc = re.escape(table)
        if not re.search(rf"\bALTER\s+TABLE\s+app_private\.{esc}\s+ENABLE\s+ROW\s+LEVEL\s+SECURITY\b", text, re.I):
            errors.append(f"RLS ENABLE missing for app_private.{table}")
        if not re.search(rf"\bALTER\s+TABLE\s+app_private\.{esc}\s+FORCE\s+ROW\s+LEVEL\s+SECURITY\b", text, re.I):
            errors.append(f"RLS FORCE missing for app_private.{table}")

    metrics = {"draft_fragments": len(drafts), "relations": len(set(tables))}
    try:
        registrar = _registrar_body(text)
        blocks = _manifest_blocks(registrar)
        counts = [len(UUID_TUPLE_RE.findall(block)) for block in blocks]
        metrics.update(permissions=counts[0], scope_alternatives=counts[1], operations=counts[2])
        if counts != [97, 322, 36]:
            errors.append(f"D1 manifest count mismatch: {counts} != [97, 322, 36]")
        operation_codes = [code for _, code in UUID_TUPLE_RE.findall(blocks[2])]
        if operation_codes.count("student.create") != 1:
            errors.append("student.create must appear exactly once in the 36-operation registrar")
    except GuardError as exc:
        errors.append(str(exc))

    if 'registrar' not in locals():
        registrar = ''
    if "INSERT INTO app_private.operation_contracts" not in registrar or not re.search(
        r"INSERT\s+INTO\s+app_private\.operation_contracts\s*\([^;]*?enabled[^;]*?\)\s*VALUES\s*\([^;]*?false", registrar, re.I | re.S
    ):
        errors.append("operation registrar does not visibly seed enabled=false")
    if re.search(r"(?mi)^\s*(?:SELECT|PERFORM)\s+app_private\.d1_register_catalog_v1\s*\(", text):
        errors.append("Migration 10 invokes the deployment-owned registrar")

    if re.search(
        r"\bCREATE(?:\s+OR\s+REPLACE)?\s+FUNCTION\s+app\.d1_[a-z0-9_]*(?:student[a-z0-9_]*create|create[a-z0-9_]*student)[a-z0-9_]*\b",
        text, re.I,
    ):
        errors.append("student.create public command exists before Admissions handoff integration")

    definers = 0
    for match in DEFINER_HEADER_RE.finditer(text):
        header = match.group("header")
        if not re.search(r"\bSECURITY\s+DEFINER\b", header, re.I):
            continue
        definers += 1
        normalized = re.sub(r"\s+", "", header.lower())
        if "setsearch_path=pg_catalog,pg_temp" not in normalized:
            errors.append("SECURITY DEFINER search_path not pinned: " + match.group(1))
    metrics["security_definers"] = definers

    if re.search(
        r"\bGRANT\s+EXECUTE\s+ON\s+FUNCTION\s+(?:app|app_private)\.d1_[^;]+?\s+TO\s+[^;]*(?:PUBLIC|\banon\b|\bservice_role\b)",
        text, re.I | re.S,
    ):
        errors.append("broad D1 EXECUTE grant to PUBLIC/anon/service_role")

    metrics["shared_auth_lock_calls"] = len(re.findall(r"pg_catalog\.pg_advisory_xact_lock_shared\s*\(\s*71001\s*,\s*1\s*\)", text, re.I))
    metrics["exclusive_auth_lock_calls"] = len(re.findall(r"pg_catalog\.pg_advisory_xact_lock\s*\(\s*71001\s*,\s*1\s*\)", text, re.I))
    if metrics["shared_auth_lock_calls"] == 0:
        errors.append("shared Foundation authorization lock call missing")
    if metrics["exclusive_auth_lock_calls"] == 0:
        errors.append("exclusive bootstrap/authorization lock call missing")

    return errors, metrics


def main(argv=None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--root", type=Path, default=ROOT)
    args = parser.parse_args(argv)
    errors, metrics = inspect(args.root)
    if errors:
        for error in errors:
            print("D1_DRAFT_STATIC_FAIL " + error)
        return 1
    print(
        "D1_DRAFT_STATIC_PASS "
        f"{metrics['draft_fragments']} fragments; {metrics['relations']} relations; "
        f"{metrics['permissions']} permissions; {metrics['scope_alternatives']} scope alternatives; "
        f"{metrics['operations']} operations; {metrics['security_definers']} SECURITY DEFINER routines; "
        f"auth-lock calls shared={metrics['shared_auth_lock_calls']} exclusive={metrics['exclusive_auth_lock_calls']}"
    )
    return 0


if __name__ == "__main__":
    sys.exit(main())
