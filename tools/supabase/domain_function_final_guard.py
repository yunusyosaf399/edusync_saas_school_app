"""Final-state function ownership/ACL audit for the non-executable D1 Migration 10 draft chain."""

from __future__ import annotations

import argparse
import re
import sys
from collections import Counter
from dataclasses import dataclass, field
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
MIGRATIONS = Path("supabase/migrations")
BASE_NAME = "20260928000000_domain_package_01.sql.draft"
PREFIX = "20260928000000_domain_package_01"

ROLE_RE = r"schoolos_[a-z0-9_]+"
FUNC_NAME_RE = r"(?:app|app_private)\.[a-z0-9_]+"

SET_ROLE_RE = re.compile(rf"\bSET\s+ROLE\s+(?P<role>{ROLE_RE})\s*;", re.I)
RESET_ROLE_RE = re.compile(r"\bRESET\s+ROLE\s*;", re.I)
CREATE_RE = re.compile(
    rf"\bCREATE(?P<replace>\s+OR\s+REPLACE)?\s+FUNCTION\s+"
    rf"(?P<name>{FUNC_NAME_RE})\s*\((?P<args>[^;]*?)\)\s*RETURNS\b"
    rf"(?P<header>.*?)(?=\bAS\s+\$[a-z0-9_]*\$)",
    re.I | re.S,
)
OWNER_RE = re.compile(
    rf"\bALTER\s+FUNCTION\s+(?P<name>{FUNC_NAME_RE})\s*\([^;]*?\)\s+"
    rf"OWNER\s+TO\s+(?P<role>[a-z0-9_]+)\s*;",
    re.I | re.S,
)
RENAME_RE = re.compile(
    rf"\bALTER\s+FUNCTION\s+(?P<name>{FUNC_NAME_RE})\s*\([^;]*?\)\s+"
    rf"RENAME\s+TO\s+(?P<new>[a-z0-9_]+)\s*;",
    re.I | re.S,
)
ACL_RE = re.compile(
    rf"\b(?P<verb>GRANT|REVOKE)\s+(?P<priv>EXECUTE|ALL)\s+ON\s+FUNCTION\s+"
    rf"(?P<name>{FUNC_NAME_RE})\s*\([^;]*?\)\s+"
    rf"(?P<direction>TO|FROM)\s+(?P<roles>[^;]+);",
    re.I | re.S,
)
SET_SESSION_RE = re.compile(r"\bSET\s+SESSION\s+AUTHORIZATION\b", re.I)
TRIGGER_RE = re.compile(
    rf"\bCREATE(?:\s+OR\s+REPLACE)?(?:\s+CONSTRAINT)?\s+TRIGGER\s+"
    rf"(?P<trigger>[a-z0-9_]+)\b[^;]*?\bEXECUTE\s+(?:FUNCTION|PROCEDURE)\s+"
    rf"(?P<name>{FUNC_NAME_RE})\s*\(", re.I | re.S,
)
QUALIFIED_CONDITIONAL_RE = re.compile(
    r"\bpg_catalog\s*\.\s*(coalesce|nullif|greatest|least)\s*\(", re.I,
)
BARE_CASE_COMPARISON_RE = re.compile(
    r"\bIS\s+(?:NOT\s+)?DISTINCT\s+FROM\s+CASE\b", re.I,
)
DANGEROUS_EXPOSED = {"public", "anon", "service_role"}


class GuardError(ValueError):
    pass


@dataclass
class FunctionState:
    name: str
    owner: str | None = None
    security_definer: bool = False
    declarations: int = 0
    replace_declarations: int = 0
    execute_roles: set[str] = field(default_factory=set)
    argument_shapes: set[str] = field(default_factory=set)
    last_definition_offset: int = -1
    owner_transfer_count: int = 0
    rename_count: int = 0


def discover_drafts(root: Path) -> list[Path]:
    mig = root / MIGRATIONS
    drafts = sorted(mig.glob(PREFIX + "*.sql.draft"), key=lambda p: p.name)
    if not drafts or drafts[0].name != BASE_NAME:
        raise GuardError("Migration 10 base draft missing or not first in lexical order")
    executable = sorted(p.name for p in mig.glob(PREFIX + "*.sql"))
    if executable:
        raise GuardError("Migration 10 must remain non-executable: " + ",".join(executable))
    return drafts


def read_chain(drafts: list[Path]) -> str:
    chunks: list[str] = []
    for path in drafts:
        raw = path.read_bytes()
        if not raw:
            raise GuardError("empty D1 draft fragment: " + path.name)
        if b"\r\n" in raw:
            raise GuardError("CRLF D1 draft fragment: " + path.name)
        chunks.append(raw.decode("utf-8"))
    return "\n".join(chunks)


def sanitize_sql(text: str, *, mask_bodies: bool = True) -> str:
    """Mask comments/literals; optionally mask dollar bodies, preserving offsets."""
    chars = list(text)
    n = len(chars)
    i = 0
    while i < n:
        if i + 1 < n and chars[i] == "-" and chars[i + 1] == "-":
            j = i + 2
            while j < n and chars[j] != "\n":
                chars[j] = " "
                j += 1
            chars[i] = chars[i + 1] = " "
            i = j
            continue
        if i + 1 < n and chars[i] == "/" and chars[i + 1] == "*":
            j = i + 2
            while j + 1 < n and not (chars[j] == "*" and chars[j + 1] == "/"):
                if chars[j] != "\n":
                    chars[j] = " "
                j += 1
            if j + 1 < n:
                chars[i] = chars[i + 1] = " "
                chars[j] = chars[j + 1] = " "
                i = j + 2
            else:
                i = n
            continue
        if chars[i] == "'":
            j = i + 1
            while j < n:
                if chars[j] == "'" and j + 1 < n and chars[j + 1] == "'":
                    chars[j] = chars[j + 1] = " "
                    j += 2
                    continue
                if chars[j] == "'":
                    chars[j] = " "
                    break
                if chars[j] != "\n":
                    chars[j] = " "
                j += 1
            chars[i] = " "
            i = min(j + 1, n)
            continue
        if chars[i] == "$":
            match = re.match(r"\$[a-zA-Z0-9_]*\$", "".join(chars[i : min(n, i + 80)]))
            if match:
                delim = match.group(0)
                if not mask_bodies:
                    i += len(delim)
                    continue
                j = text.find(delim, i + len(delim))
                if j >= 0:
                    for k in range(i + len(delim), j):
                        if chars[k] != "\n":
                            chars[k] = " "
                    i = j + len(delim)
                    continue
        i += 1
    return "".join(chars)


def _parse_roles(raw: str) -> set[str]:
    return {piece.strip().lower() for piece in raw.split(",") if piece.strip()}


def _argument_shape(raw: str) -> str:
    return re.sub(r"\s+", " ", raw.strip().lower())


def _events(text: str):
    patterns = [
        ("set_role", SET_ROLE_RE),
        ("reset_role", RESET_ROLE_RE),
        ("create", CREATE_RE),
        ("owner", OWNER_RE),
        ("rename", RENAME_RE),
        ("acl", ACL_RE),
        ("trigger", TRIGGER_RE),
    ]
    events = []
    for kind, pattern in patterns:
        for match in pattern.finditer(text):
            events.append((match.start(), kind, match))
    events.sort(key=lambda item: (item[0], item[1]))
    return events


def inspect(root: Path) -> tuple[list[str], dict[str, object], dict[str, FunctionState]]:
    root = Path(root)
    errors: list[str] = []
    try:
        drafts = discover_drafts(root)
        raw = read_chain(drafts)
    except (OSError, UnicodeDecodeError, GuardError) as exc:
        return [str(exc)], {}, {}

    text = sanitize_sql(raw)
    body_code = sanitize_sql(raw, mask_bodies=False)
    for match in QUALIFIED_CONDITIONAL_RE.finditer(body_code):
        line = raw.count("\n", 0, match.start()) + 1
        errors.append(f"schema-qualified SQL conditional expression: {match.group(1)} at chain line {line}")
    for match in BARE_CASE_COMPARISON_RE.finditer(body_code):
        line = raw.count("\n", 0, match.start()) + 1
        errors.append(f"CASE comparison operand requires parentheses in draft SQL: chain line {line}")
    if SET_SESSION_RE.search(text):
        errors.append("D1 draft uses SET SESSION AUTHORIZATION")

    states: dict[str, FunctionState] = {}
    current_role: str | None = None
    possible_name_collisions = 0
    rename_events = 0

    for _, kind, match in _events(text):
        if kind == "set_role":
            current_role = match.group("role").lower()
            continue
        if kind == "reset_role":
            current_role = None
            continue
        if kind == "trigger":
            name = match.group("name").lower()
            state = states.get(name)
            # Frozen Foundation helpers are defined before this draft chain.
            # Their ownership/ACLs are validated by Foundation runtime tests.
            if state is None and not name.split(".", 1)[1].startswith("d1_"):
                continue
            if state is None or not state.declarations:
                errors.append(f"trigger function unresolved: {match.group('trigger')}->{name}")
            elif current_role is not None and current_role != state.owner and current_role not in state.execute_roles:
                errors.append(
                    f"trigger creator lacks explicit EXECUTE: {match.group('trigger')} "
                    f"role={current_role} function={name} owner={state.owner}"
                )
            continue
        if kind == "create":
            name = match.group("name").lower()
            replacing = bool(match.group("replace"))
            header = match.group("header")
            is_definer = bool(re.search(r"\bSECURITY\s+DEFINER\b", header, re.I))
            state = states.get(name)
            if state is None:
                state = FunctionState(name=name, owner=current_role)
                states[name] = state
            elif not replacing:
                possible_name_collisions += 1
            state.declarations += 1
            if replacing:
                state.replace_declarations += 1
            state.argument_shapes.add(_argument_shape(match.group("args")))
            state.security_definer = is_definer
            state.last_definition_offset = match.start()
            continue
        if kind == "owner":
            name = match.group("name").lower()
            role = match.group("role").lower()
            state = states.setdefault(name, FunctionState(name=name))
            if current_role is not None and state.owner is not None and current_role != state.owner:
                errors.append(f"function ownership packaging role mismatch: {name} role={current_role} owner={state.owner}")
            state.owner = role
            state.owner_transfer_count += 1
            continue
        if kind == "rename":
            old_name = match.group("name").lower()
            schema = old_name.split(".", 1)[0]
            new_name = f"{schema}.{match.group('new').lower()}"
            state = states.pop(old_name, None)
            if state is None or not state.declarations:
                errors.append(f"function rename source unresolved: {old_name}->{new_name}")
                state = FunctionState(name=new_name)
            if new_name in states and states[new_name].declarations:
                errors.append(f"function rename target already exists: {new_name}")
            state.name = new_name
            state.rename_count += 1
            states[new_name] = state
            rename_events += 1
            continue
        if kind == "acl":
            name = match.group("name").lower()
            roles = _parse_roles(match.group("roles"))
            state = states.setdefault(name, FunctionState(name=name))
            if match.group("verb").upper() == "GRANT":
                state.execute_roles.update(roles)
            else:
                state.execute_roles.difference_update(roles)

    if current_role is not None:
        errors.append(f"D1 draft leaves SET ROLE active at end of lexical chain: {current_role}")
    if possible_name_collisions:
        errors.append(f"unresolved bare CREATE function-name collisions: {possible_name_collisions}")

    signature_shape_drift = sorted(
        name for name, state in states.items()
        if state.declarations > 1 and len(state.argument_shapes) > 1
    )
    if signature_shape_drift:
        errors.append(
            "function declaration argument-shape drift requires signature audit: "
            + ",".join(signature_shape_drift[:20])
            + ("..." if len(signature_shape_drift) > 20 else "")
        )

    unknown_owner_definers = sorted(
        name for name, state in states.items()
        if state.declarations and state.security_definer and state.owner is None
    )
    if unknown_owner_definers:
        errors.append(
            "final SECURITY DEFINER owner unresolved: "
            + ",".join(unknown_owner_definers[:20])
            + ("..." if len(unknown_owner_definers) > 20 else "")
        )

    non_schoolos_definers = sorted(
        f"{name}:{state.owner}" for name, state in states.items()
        if state.declarations and state.security_definer and state.owner is not None
        and not state.owner.startswith("schoolos_")
    )
    if non_schoolos_definers:
        errors.append(
            "final SECURITY DEFINER owned outside schoolos roles: "
            + ",".join(non_schoolos_definers[:20])
            + ("..." if len(non_schoolos_definers) > 20 else "")
        )

    dangerous_acl = sorted(
        f"{name}:{','.join(sorted(state.execute_roles & DANGEROUS_EXPOSED))}"
        for name, state in states.items()
        if state.execute_roles & DANGEROUS_EXPOSED
    )
    if dangerous_acl:
        errors.append(
            "final exposed EXECUTE remains for dangerous role: "
            + ",".join(dangerous_acl[:20])
            + ("..." if len(dangerous_acl) > 20 else "")
        )

    private_authenticated = sorted(
        name for name, state in states.items()
        if name.startswith("app_private.") and "authenticated" in state.execute_roles
    )
    if private_authenticated:
        errors.append(
            "authenticated retains EXECUTE on app_private function: "
            + ",".join(private_authenticated[:20])
            + ("..." if len(private_authenticated) > 20 else "")
        )

    redefined = sorted(name for name, state in states.items() if state.declarations > 1)
    unresolved_redefined = [name for name in redefined if states[name].owner is None]
    if unresolved_redefined:
        errors.append(
            "redefined function owner unresolved: "
            + ",".join(unresolved_redefined[:20])
            + ("..." if len(unresolved_redefined) > 20 else "")
        )

    owners = Counter(
        state.owner or "<unknown>"
        for state in states.values()
        if state.declarations
    )
    public_app = [state for name, state in states.items() if name.startswith("app.") and state.declarations]
    private_app = [state for name, state in states.items() if name.startswith("app_private.") and state.declarations]
    auth_public = [state for state in public_app if "authenticated" in state.execute_roles]
    schema_owner_public = sorted(
        state.name for state in public_app if state.owner == "schoolos_schema_owner"
    )
    renamed_final = sorted(
        state.name for state in states.values() if state.declarations and state.rename_count
    )

    metrics: dict[str, object] = {
        "draft_fragments": len(drafts),
        "final_functions": sum(1 for state in states.values() if state.declarations),
        "redefined_names": len(redefined),
        "replace_declarations": sum(state.replace_declarations for state in states.values()),
        "owner_transfers": sum(state.owner_transfer_count for state in states.values()),
        "renames": rename_events,
        "renamed_final_names": renamed_final,
        "signature_shape_drift_names": signature_shape_drift,
        "final_security_definers": sum(
            1 for state in states.values() if state.declarations and state.security_definer
        ),
        "public_app_functions": len(public_app),
        "private_functions": len(private_app),
        "authenticated_public_functions": len(auth_public),
        "authenticated_private_functions": len(private_authenticated),
        "unknown_owner_functions": owners.get("<unknown>", 0),
        "owner_distribution": dict(sorted(owners.items())),
        "schema_owner_public_names": schema_owner_public,
        "possible_name_collisions": possible_name_collisions,
    }
    return errors, metrics, states


def main(argv=None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--root", type=Path, default=ROOT)
    parser.add_argument("--verbose", action="store_true")
    args = parser.parse_args(argv)
    errors, metrics, states = inspect(args.root)
    if errors:
        for error in errors:
            print("D1_FUNCTION_FINAL_FAIL " + error)
        return 1

    owners = ",".join(
        f"{role}={count}" for role, count in metrics["owner_distribution"].items()
    )
    print(
        "D1_FUNCTION_FINAL_PASS "
        f"{metrics['draft_fragments']} fragments; final_functions={metrics['final_functions']} "
        f"redefined_names={metrics['redefined_names']} replace_declarations={metrics['replace_declarations']} "
        f"owner_transfers={metrics['owner_transfers']} renames={metrics['renames']} "
        f"signature_shape_drift=0 final_security_definers={metrics['final_security_definers']} "
        f"app={metrics['public_app_functions']} app_private={metrics['private_functions']} "
        f"authenticated_app={metrics['authenticated_public_functions']} "
        f"authenticated_app_private={metrics['authenticated_private_functions']} "
        f"unknown_owners={metrics['unknown_owner_functions']} possible_name_collisions={metrics['possible_name_collisions']} "
        f"owners[{owners}]"
    )
    if args.verbose:
        schema_owner_public = metrics["schema_owner_public_names"]
        print(
            "D1_FUNCTION_FINAL_REPORT app_schema_owner="
            + (",".join(schema_owner_public) if schema_owner_public else "<none>")
        )
        renamed = metrics["renamed_final_names"]
        print(
            "D1_FUNCTION_FINAL_REPORT renamed_final="
            + (",".join(renamed) if renamed else "<none>")
        )
        redefined_names = sorted(
            state.name for state in states.values() if state.declarations > 1
        )
        print(
            "D1_FUNCTION_FINAL_REPORT redefined="
            + (",".join(redefined_names) if redefined_names else "<none>")
        )
    return 0


if __name__ == "__main__":
    sys.exit(main())
