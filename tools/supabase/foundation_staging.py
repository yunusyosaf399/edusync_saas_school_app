"""Local-only staging contract, target and synthetic drift validation.

No mode in this module connects to a managed project or applies a change.
"""

import argparse
import json
import os
import re
import sys
from pathlib import Path

from foundation_guard import ROOT, GuardError, inspect_local_config, inspect_source, load_contract

STAGING_CONTRACT = ROOT / "supabase/config/foundation_staging_contract.json"
TARGET_MANIFEST = ROOT / "supabase/config/foundation_staging_target.json"
CONTRACT_REL = "supabase/config/foundation_managed_contract.json"
MANIFEST_FIELDS = (
    "environment", "project_ref", "project_name", "organization_id", "region", "foundation_id"
)
DRIFT_CATEGORIES = (
    "SOURCE", "TARGET_IDENTITY", "HEALTH", "POSTGRESQL_VERSION", "MIGRATION_HISTORY",
    "CATALOG", "SECURITY_SMOKE", "DATA_API", "LINT", "FOUNDATION_TESTS",
    "WORKER_ACTIVATION_BOUNDARY",
)
STEPS = (
    "frozen source integrity", "clean exact Git commit", "exact staging target manifest",
    "independent managed target identity", "project and service health", "secret preflight",
    "TLS Supavisor session pooler 5432", "clean-project baseline for first deployment",
    "exact migration dry-run", "explicit migration authorization", "one migration push",
    "exact migration-history verification", "catalog and security drift checks",
    "Data API configuration verification", "database lint", "hosted Foundation test gate",
    "final drift check", "final health", "deployment evidence",
)
SECRET_NAMES = ("SUPABASE_ACCESS_TOKEN", "SCHOOL_OS_STAGING_DB_PASSWORD")
SECRET_PATTERNS = (
    re.compile(r"(?i)postgres(?:ql)?://[^\s`]+:[^\s@`]+@"),
    re.compile(r"sbp_[A-Za-z0-9]{12,}"),
    re.compile(r"sb_secret_[A-Za-z0-9]{12,}"),
    re.compile(r"eyJ[A-Za-z0-9_-]{20,}\.[A-Za-z0-9_-]{20,}\.[A-Za-z0-9_-]{20,}"),
    re.compile(r"(?i)authorization\s*:\s*(?:bearer|basic)\s+\S+"),
)


class StagingError(ValueError):
    """Fixed safe error codes only; never include untrusted values."""


def require(condition, code):
    if not condition:
        raise StagingError(code)


def _fields(value, expected, code):
    require(isinstance(value, dict) and set(value) == set(expected), code)


def _no_embedded_secrets(value):
    if isinstance(value, dict):
        require(not any(re.search(r"(?i)(?:^|_)(?:password|token|secret|key)_value$", str(k))
                        for k in value), "STAGING_CONTRACT_EMBEDDED_SECRET")
        for item in value.values():
            _no_embedded_secrets(item)
    elif isinstance(value, list):
        for item in value:
            _no_embedded_secrets(item)
    elif isinstance(value, str):
        require(not any(pattern.search(value) for pattern in SECRET_PATTERNS),
                "STAGING_CONTRACT_EMBEDDED_SECRET")


def validate_staging_contract(staging, foundation):
    """Validate policy shape and its relationship to the frozen managed contract."""
    _no_embedded_secrets(staging)
    _fields(staging, ("format_version", "environment", "foundation_contract", "foundation_id",
                      "project_policy", "source_policy", "migration_policy", "data_api_policy",
                      "secret_policy", "drift_policy", "destructive_action_policy", "worker_activation"),
            "STAGING_CONTRACT_SHAPE")
    require(type(staging["format_version"]) is int and staging["format_version"] == 1 and
            staging["environment"] == "staging" and staging["foundation_contract"] == CONTRACT_REL and
            staging["foundation_id"] == foundation["foundation_id"], "STAGING_CONTRACT_IDENTITY")
    project = staging["project_policy"]
    _fields(project, ("dedicated_project_required", "customer_project_forbidden", "required_name_prefix",
                      "allowed_regions", "manifest_fields"), "STAGING_CONTRACT_PROJECT_POLICY")
    require(project["dedicated_project_required"] is True and project["customer_project_forbidden"] is True and
            project["required_name_prefix"] == "schoolos-staging-" and
            project["allowed_regions"] == ["ap-northeast-2"] and
            project["manifest_fields"] == list(MANIFEST_FIELDS), "STAGING_CONTRACT_PROJECT_POLICY")
    required_true = {
        "source_policy": ("clean_worktree_required", "full_commit_sha_required", "foundation_guard_required",
                          "unreviewed_future_migrations_forbidden", "record_exact_commit_in_evidence"),
        "migration_policy": ("foundation_only", "exact_history_required", "explicit_push_authorization_required",
                             "session_pooler_required"),
        "data_api_policy": ("use_foundation_contract", "unexpected_exposure_blocks", "automatic_patch_forbidden"),
        "drift_policy": ("fail_closed", "read_only_audit", "automatic_repair_forbidden"),
        "destructive_action_policy": ("automatic_project_delete_forbidden", "automatic_database_reset_forbidden",
                                      "migration_history_edits_forbidden", "destructive_repair_forbidden",
                                      "production_promotion_forbidden", "customer_data_copying_forbidden"),
    }
    for section, names in required_true.items():
        row = staging[section]
        _fields(row, names, "STAGING_CONTRACT_POLICY")
        require(all(row[name] is True for name in names), "STAGING_CONTRACT_POLICY")
    secrets = staging["secret_policy"]
    _fields(secrets, ("management_token_env", "staging_db_password_env", "values_in_repository_forbidden",
                      "values_in_logs_forbidden", "values_in_cli_arguments_forbidden",
                      "service_admin_key_memory_only_when_authorized", "public_client_key_is_not_authorization"),
            "STAGING_CONTRACT_SECRET_POLICY")
    require(secrets["management_token_env"] == SECRET_NAMES[0] and
            secrets["staging_db_password_env"] == SECRET_NAMES[1] and
            all(secrets[name] is True for name in secrets if name not in
                ("management_token_env", "staging_db_password_env")), "STAGING_CONTRACT_SECRET_POLICY")
    require(staging["worker_activation"] == foundation["worker_activation"] == "deferred" and
            foundation["migration_connection"]["port"] == 5432 and
            foundation["postgresql"]["minimum_major"] >= 15,
            "STAGING_CONTRACT_FOUNDATION_RELATIONSHIP")
    return staging


def load_staging_contract(path=STAGING_CONTRACT, foundation=None):
    try:
        data = json.loads(Path(path).read_text(encoding="utf-8"))
    except (OSError, ValueError) as exc:
        raise StagingError("STAGING_CONTRACT_UNREADABLE") from None
    return validate_staging_contract(data, foundation or load_contract())


def validate_target_manifest(manifest, staging):
    """Pure future-target check; no project lookup or manifest file creation."""
    _fields(manifest, MANIFEST_FIELDS, "TARGET_MANIFEST_SHAPE")
    project = staging["project_policy"]
    require(manifest["environment"] == "staging", "TARGET_ENVIRONMENT")
    require(isinstance(manifest["project_ref"], str) and
            re.fullmatch(r"[a-z]{20}", manifest["project_ref"]) is not None, "TARGET_REF")
    name = manifest["project_name"]
    require(isinstance(name, str) and not name.startswith("schoolos-foundation-productization-p1-") and
            name.startswith(project["required_name_prefix"]) and len(name) > len(project["required_name_prefix"]),
            "TARGET_NAME")
    require(isinstance(manifest["organization_id"], str) and bool(manifest["organization_id"].strip()),
            "TARGET_ORGANIZATION")
    require(manifest["region"] in project["allowed_regions"], "TARGET_REGION")
    require(manifest["foundation_id"] == staging["foundation_id"], "TARGET_FOUNDATION_ID")
    return "TARGET_MANIFEST_PASS"


def secret_presence(environ=None):
    """Read only key membership, never the associated environment values."""
    env = os.environ if environ is None else environ
    return {name: "present" if name in env else "missing" for name in SECRET_NAMES}


def evaluate_staging_drift(snapshot, foundation, staging):
    """Pure fail-closed check of a synthetic future read-only audit snapshot."""
    _fields(snapshot, ("source", "target", "health", "postgresql_version", "migration_versions",
                       "catalog", "security_smoke", "data_api_schemas", "lint", "foundation_tests",
                       "worker_activation"), "DRIFT_SNAPSHOT_SHAPE")
    validate_staging_contract(staging, foundation)
    source = snapshot["source"]
    _fields(source, ("commit", "clean", "guard_pass", "future_migrations"), "DRIFT_SOURCE")
    require(isinstance(source["commit"], str) and re.fullmatch(r"[0-9a-f]{40}", source["commit"]) and
            source["clean"] is True and source["guard_pass"] is True and
            type(source["future_migrations"]) is int and source["future_migrations"] == 0, "DRIFT_SOURCE")
    try:
        validate_target_manifest(snapshot["target"], staging)
    except StagingError:
        raise StagingError("DRIFT_TARGET_IDENTITY") from None
    health = snapshot["health"]
    _fields(health, ("project", "database", "auth", "rest"), "DRIFT_HEALTH")
    require(all(health[name] is True for name in health), "DRIFT_HEALTH")
    version = snapshot["postgresql_version"]
    match = re.fullmatch(r"([0-9]+)\.([0-9]+)(?:\.[0-9]+)?", version) if isinstance(version, str) else None
    require(match is not None and int(match.group(1)) >= foundation["postgresql"]["minimum_major"],
            "DRIFT_POSTGRESQL_VERSION")
    expected_versions = [row["version"] for row in foundation["frozen_foundation"]["migrations"]]
    require(snapshot["migration_versions"] == expected_versions, "DRIFT_MIGRATION_HISTORY")
    expected_catalog = foundation["expected_catalog"]
    names = ("roles", "tables", "policies", "rls_enabled", "rls_forced", "security_definer_functions")
    catalog = snapshot["catalog"]
    _fields(catalog, names, "DRIFT_CATALOG")
    require(all(type(catalog[name]) is int and catalog[name] == expected_catalog[name] for name in names),
            "DRIFT_CATALOG")
    smoke = snapshot["security_smoke"]
    _fields(smoke, ("auth_fk_name", "auth_fk_target", "on_update", "on_delete", "helper_owner"),
            "DRIFT_SECURITY_SMOKE")
    require(smoke == {"auth_fk_name": expected_catalog["auth_binding_fk"],
                      "auth_fk_target": "auth.users(id)", "on_update": "RESTRICT",
                      "on_delete": "SET NULL", "helper_owner": expected_catalog["current_principal_owner"]},
            "DRIFT_SECURITY_SMOKE")
    schemas = snapshot["data_api_schemas"]
    require(isinstance(schemas, list) and all(isinstance(name, str) for name in schemas) and
            len(schemas) == len(set(schemas)) and
            set(schemas) == set(foundation["data_api"]["required_exposed_schemas"]) and
            not set(schemas).intersection(foundation["data_api"]["forbidden_exposed_schemas"]),
            "DRIFT_DATA_API")
    lint = snapshot["lint"]
    _fields(lint, ("error", "warning"), "DRIFT_LINT")
    require(lint == {"error": "PASS", "warning": "PASS"}, "DRIFT_LINT")
    require(type(snapshot["foundation_tests"]) is int and
            snapshot["foundation_tests"] == foundation["frozen_foundation"]["expected_tap_assertions"],
            "DRIFT_FOUNDATION_TESTS")
    require(snapshot["worker_activation"] == "deferred", "DRIFT_WORKER_ACTIVATION_BOUNDARY")
    return "STAGING_DRIFT_PASS"


def validate_local(staging=None, foundation=None, *, root=ROOT):
    foundation = foundation or load_contract()
    staging = staging or load_staging_contract(foundation=foundation)
    validate_staging_contract(staging, foundation)
    errors, _, extras = inspect_source(root, foundation, future="fail")
    require(not errors and not extras, "STAGING_SOURCE_GUARD")
    try:
        inspect_local_config(root, foundation)
    except GuardError:
        raise StagingError("STAGING_LOCAL_CONFIG") from None
    require(not list((Path(root) / TARGET_MANIFEST.relative_to(ROOT).parent).glob("*staging*target*.json")),
            "STAGING_TARGET_MANIFEST_PREMATURE")
    return "STAGING_VALIDATE_PASS"


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("mode", nargs="?", choices=("plan", "validate", "secret-preflight", "drift-plan"),
                        default="plan")
    args = parser.parse_args(argv)
    try:
        if args.mode == "secret-preflight":
            for name, state in secret_presence().items():
                print(name + "=" + state)
            return 0
        foundation = load_contract()
        staging = load_staging_contract(foundation=foundation)
        if args.mode == "validate":
            print(validate_local(staging, foundation))
        elif args.mode == "drift-plan":
            print("STAGING_DRIFT_PLAN read-only; fail closed; no automatic repair")
            for category in DRIFT_CATEGORIES:
                print(category)
        else:
            print("STAGING_PLAN local-only; no remote apply path")
            for number, step in enumerate(STEPS, 1):
                print(str(number) + ". " + step)
        return 0
    except (GuardError, StagingError) as exc:
        print("STAGING_FAIL " + str(exc), file=sys.stderr)
        return 1


if __name__ == "__main__":
    sys.exit(main())
