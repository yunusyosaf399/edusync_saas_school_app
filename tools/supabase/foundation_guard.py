"""Offline integrity gate for the frozen School OS Foundation baseline."""

import argparse
import ast
import hashlib
import json
import re
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
CONTRACT = ROOT / "supabase/config/foundation_managed_contract.json"
VERSION_RE = re.compile(r"^[0-9]{14}_[a-z0-9_]+\.sql$")
SHA_RE = re.compile(r"^[0-9a-f]{64}$")
BLOB_RE = re.compile(r"^[0-9a-f]{40}$")


class GuardError(ValueError):
    pass


def load_contract(path=CONTRACT):
    try:
        data = json.loads(Path(path).read_text(encoding="utf-8"))
        baseline = data["frozen_foundation"]
        migrations, tests = baseline["migrations"], baseline["database_tests"]
        if data["format_version"] != 1 or not isinstance(migrations, list) or not isinstance(tests, list):
            raise GuardError("unsupported or malformed contract")
        if len(migrations) != 9 or len(tests) != 9 or baseline["expected_tap_assertions"] != 220:
            raise GuardError("frozen baseline count mismatch")
        if [x["version"] for x in migrations] != sorted({x["version"] for x in migrations}):
            raise GuardError("migration versions must be unique and ordered")
        if sum(x["assertions"] for x in tests) != 220:
            raise GuardError("TAP plan mismatch")
        for section in (migrations, tests):
            names = [x["file"] for x in section]
            if len(names) != len(set(names)):
                raise GuardError("duplicate frozen filename")
            for item in section:
                name = item["file"]
                if Path(name).name != name or not name.endswith(".sql"):
                    raise GuardError("unsafe frozen filename")
                if not SHA_RE.fullmatch(item["sha256"]) or not BLOB_RE.fullmatch(item["git_blob"]):
                    raise GuardError("invalid frozen digest")
        for item in migrations:
            if not VERSION_RE.fullmatch(item["file"]) or item["version"] != item["file"][:14]:
                raise GuardError("migration name/version mismatch")
        exposed = data["data_api"]
        if set(exposed["required_exposed_schemas"]) != {"public", "graphql_public", "app"}:
            raise GuardError("required API schema contract changed")
        if "app_private" not in exposed["forbidden_exposed_schemas"]:
            raise GuardError("private API schema missing from forbidden list")
        return data
    except (OSError, KeyError, TypeError, json.JSONDecodeError) as exc:
        raise GuardError("malformed or unreadable deployment contract") from exc


def _git_blob(root, rel):
    result = subprocess.run(["git", "show", "HEAD:" + rel.as_posix()], cwd=root, capture_output=True)
    if result.returncode:
        raise GuardError("frozen file absent from Git HEAD: " + rel.as_posix())
    return result.stdout


def inspect_source(root, contract, *, require_lf=False, future="fail", check_git=True):
    root = Path(root)
    errors, notices = [], []
    attrs = root / ".gitattributes"
    expected_attrs = {".gitattributes text eol=lf", "supabase/migrations/*.sql text eol=lf", "supabase/tests/database/*.sql text eol=lf"}
    if not attrs.exists() or not expected_attrs.issubset(set(attrs.read_text(encoding="utf-8").splitlines())):
        errors.append("LF Git attributes missing")
    frozen = contract["frozen_foundation"]
    for directory, rows in (("migrations", frozen["migrations"]), ("tests/database", frozen["database_tests"])):
        for item in rows:
            rel = Path("supabase") / directory / item["file"]
            path = root / rel
            if not path.is_file():
                errors.append("missing " + rel.as_posix())
                continue
            raw = path.read_bytes()
            normalized = raw.replace(b"\r\n", b"\n")
            if hashlib.sha256(normalized).hexdigest() != item["sha256"]:
                errors.append("frozen SHA-256 mismatch: " + rel.as_posix())
            if b"\r\n" in raw:
                message = "CRLF materialization: " + rel.as_posix()
                (errors if require_lf else notices).append(message)
            if check_git:
                try:
                    blob = _git_blob(root, rel)
                    blob_id = subprocess.check_output(["git", "hash-object", "--stdin"], input=blob, cwd=root).decode().strip()
                    if blob_id != item["git_blob"] or hashlib.sha256(blob).hexdigest() != item["sha256"] or normalized != blob:
                        errors.append("canonical Git blob mismatch: " + rel.as_posix())
                except (GuardError, subprocess.CalledProcessError) as exc:
                    errors.append(str(exc))
    known = {x["file"] for x in frozen["migrations"]}
    extras = sorted(p.name for p in (root / "supabase/migrations").glob("*.sql") if p.name not in known)
    if extras:
        notices.append("FUTURE_MIGRATIONS_PRESENT " + ",".join(extras))
        if future == "fail":
            errors.append("additional migrations require separate review")
    return errors, notices, extras


def inspect_local_config(root, contract):
    path = Path(root) / "supabase/config.toml"
    try:
        text = path.read_text(encoding="utf-8")
        api_section = re.search(r"(?ms)^\[api\]\s*$([\s\S]*?)(?=^\[|\Z)", text)
        if not api_section:
            raise GuardError("local [api] section missing")
        settings = re.findall(r"(?m)^\s*schemas\s*=\s*(\[[^\n]*\])\s*(?:#.*)?$", api_section.group(1))
        if len(settings) != 1:
            raise GuardError("local API schemas setting missing or duplicated")
        schemas = ast.literal_eval(settings[0])
    except (OSError, ValueError, KeyError, TypeError) as exc:
        raise GuardError("missing or invalid local Supabase config") from exc
    if not isinstance(schemas, list) or any(not isinstance(x, str) for x in schemas):
        raise GuardError("invalid local API schema list")
    required = set(contract["data_api"]["required_exposed_schemas"])
    forbidden = set(contract["data_api"]["forbidden_exposed_schemas"])
    if len(schemas) != len(set(schemas)) or set(schemas) != required or forbidden.intersection(schemas):
        raise GuardError("local API schema exposure differs from contract")
    return schemas


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--require-lf", action="store_true", help="fail on CRLF filesystem materialization")
    parser.add_argument("--future", choices=("fail", "report"), default="fail")
    parser.add_argument("--verbose", action="store_true")
    args = parser.parse_args(argv)
    try:
        contract = load_contract()
        errors, notices, _ = inspect_source(ROOT, contract, require_lf=args.require_lf, future=args.future)
        if errors:
            for error in errors:
                print("FOUNDATION_SOURCE_FAIL " + error)
        else:
            print("FOUNDATION_SOURCE_PASS 9 migrations + 9 tests")
        for notice in notices:
            if args.verbose or notice.startswith("FUTURE_"):
                print(notice)
        try:
            inspect_local_config(ROOT, contract)
            print("LOCAL_CONFIG_PASS")
        except GuardError as exc:
            errors.append(str(exc))
            print("LOCAL_CONFIG_FAIL " + str(exc))
        return 1 if errors else 0
    except GuardError as exc:
        print("FOUNDATION_SOURCE_FAIL " + str(exc))
        return 1


if __name__ == "__main__":
    sys.exit(main())
