"""Check hosted Data API schema drift; apply requires exact explicit target confirmation.

P0 does not execute this against a managed target. Network behavior is unit-tested
with an injected transport. The CLI defaults to a read-only check.
"""

import argparse
import json
import os
import re
import sys
import urllib.error
import urllib.request

from foundation_guard import load_contract

REF_RE = re.compile(r"^[a-z]{20}$")
API = "https://api.supabase.com"


class ManagedConfigError(RuntimeError):
    pass


def http_transport(method, path, token, payload=None):
    body = None if payload is None else json.dumps(payload).encode("utf-8")
    request = urllib.request.Request(API + path, data=body, method=method,
                                     headers={"Authorization": "Bearer " + token,
                                              "Content-Type": "application/json"})
    try:
        with urllib.request.urlopen(request, timeout=30) as response:
            return response.status, json.load(response)
    except (urllib.error.HTTPError, urllib.error.URLError, ValueError) as exc:
        # Never echo response bodies or full exception text; they may contain secrets.
        status = exc.code if isinstance(exc, urllib.error.HTTPError) else "network"
        raise ManagedConfigError("Management API request failed: " + method + " (" + str(status) + ")") from None


def schema_set(config):
    raw = config.get("db_schema") if isinstance(config, dict) else None
    if not isinstance(raw, str):
        raise ManagedConfigError("PostgREST response missing db_schema")
    values = [x.strip() for x in raw.split(",")]
    if not values or any(not x for x in values) or len(values) != len(set(values)):
        raise ManagedConfigError("PostgREST schema list malformed")
    return set(values)


def execute(ref, *, apply=False, confirm_ref=None, expected_name=None, expected_organization=None,
            token=None, transport=http_transport, contract=None):
    contract = contract or load_contract()
    if not REF_RE.fullmatch(ref or ""):
        raise ManagedConfigError("exact project ref required")
    if apply and confirm_ref != ref:
        raise ManagedConfigError("APPLY_CONFIRMATION_MISMATCH")
    if not token:
        raise ManagedConfigError("SUPABASE_ACCESS_TOKEN required in process environment")
    required = set(contract["data_api"]["required_exposed_schemas"])
    forbidden = set(contract["data_api"]["forbidden_exposed_schemas"])
    path = "/v1/projects/" + ref
    status, identity = transport("GET", path, token)
    if status != 200 or not isinstance(identity, dict) or identity.get("id") != ref:
        raise ManagedConfigError("project identity mismatch")
    if expected_name and identity.get("name") != expected_name:
        raise ManagedConfigError("project name mismatch")
    if expected_organization and identity.get("organization_id") != expected_organization:
        raise ManagedConfigError("organization mismatch")
    status, current = transport("GET", path + "/postgrest", token)
    if status != 200:
        raise ManagedConfigError("PostgREST read failed (" + str(status) + ")")
    actual = schema_set(current)
    if forbidden & actual:
        raise ManagedConfigError("FORBIDDEN_SCHEMA_EXPOSED")
    if actual == required:
        return "MANAGED_CONFIG_PASS"
    if not apply:
        raise ManagedConfigError("MANAGED_CONFIG_DRIFT expected " + ",".join(sorted(required)) + " observed " + ",".join(sorted(actual)))
    # Only the reviewed schema field is patched. Other unexpected exposures block apply.
    if actual - required or not {"public", "graphql_public"}.issubset(actual):
        raise ManagedConfigError("UNEXPECTED_SCHEMA_STATE; apply refused")
    status, _ = transport("PATCH", path + "/postgrest", token,
                          {"db_schema": ",".join(contract["data_api"]["required_exposed_schemas"])})
    if status not in (200, 204):
        raise ManagedConfigError("PostgREST update failed (" + str(status) + ")")
    status, reread = transport("GET", path + "/postgrest", token)
    if status != 200 or schema_set(reread) != required:
        raise ManagedConfigError("POST_APPLY_DRIFT")
    return "MANAGED_CONFIG_PASS"


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("mode", nargs="?", choices=("check", "apply"), default="check")
    parser.add_argument("--apply", action="store_true", help="required in addition to apply mode")
    parser.add_argument("--project-ref", required=True)
    parser.add_argument("--confirm-project-ref")
    parser.add_argument("--expected-name")
    parser.add_argument("--expected-organization")
    args = parser.parse_args(argv)
    if args.mode == "apply" and not args.apply:
        print("APPLY_CONFIRMATION_MISMATCH", file=sys.stderr)
        return 1
    if args.mode == "check" and args.apply:
        print("apply flag requires apply mode", file=sys.stderr)
        return 1
    try:
        print(execute(args.project_ref, apply=args.mode == "apply", confirm_ref=args.confirm_project_ref,
                      expected_name=args.expected_name, expected_organization=args.expected_organization,
                      token=os.environ.get("SUPABASE_ACCESS_TOKEN")))
        return 0
    except (ManagedConfigError, ValueError) as exc:
        print("MANAGED_CONFIG_FAIL " + str(exc), file=sys.stderr)
        return 1


if __name__ == "__main__":
    sys.exit(main())
