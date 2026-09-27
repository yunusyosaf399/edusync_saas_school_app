"""Offline Foundation managed deployment plan. Remote apply is disabled in P0."""

import argparse
import sys

from foundation_guard import ROOT, inspect_local_config, inspect_source, load_contract

STEPS = (
    "source integrity",
    "exact target identity and organization",
    "database, Auth, REST service health",
    "TLS Supavisor session-pooler port 5432; passwordless --db-url and temporary PGPASSWORD",
    "clean School OS role/schema/history/Auth baseline for a new school project",
    "nine Foundation migration dry-run",
    "exact pending migration list and order review",
    "separately authorized migration push",
    "exact migration-history verification",
    "roles/schemas/RLS/Auth FK/helper-owner security smoke",
    "managed Data API configuration check and separately confirmed apply",
    "post-configuration exposed-schema drift check",
    "final service health",
)


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("mode", choices=("plan", "apply"))
    args = parser.parse_args(argv)
    if args.mode == "apply":
        print("REMOTE_APPLY_NOT_AUTHORIZED_IN_P0", file=sys.stderr)
        return 2
    contract = load_contract()
    errors, _, extras = inspect_source(ROOT, contract, future="fail")
    inspect_local_config(ROOT, contract)
    if errors:
        print("PLAN_BLOCKED " + "; ".join(errors), file=sys.stderr)
        return 1
    print("FOUNDATION_DEPLOYMENT_PLAN; remote execution disabled")
    for number, step in enumerate(STEPS, 1):
        print(str(number) + ". " + step)
    print("Frozen baseline: " + str(len(contract["frozen_foundation"]["migrations"])) + " migrations; future migrations: " + str(len(extras)))
    return 0


if __name__ == "__main__":
    sys.exit(main())
