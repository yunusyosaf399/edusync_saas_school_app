"""Temporary PR102-only current-main composition acceptance launcher.

Do not change the pin or accepted standalone DB03/DB08 source. Rebind the
dependency SHA in memory ONLY for this dedicated, fully disposable integration
workflow and only after checking both Git histories. The actual candidate
runner, all Foundation hash guards and rollback/ACL checks still execute.
"""
from __future__ import annotations

import argparse
from pathlib import Path
import runpy
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[2]
CURRENT_MAIN = "5dd07728684736b42c1fa7ee4b7f7b62f843c37f"
CASES = {
    "db03": ROOT / "tools/db03/schema_candidate_ci.py",
    "db08": ROOT / "tools/db08/schema_candidate_ci.py",
}


def git(*args: str, cwd: Path) -> str:
    return subprocess.check_output(["git", *args], cwd=cwd, text=True).strip()


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("case", choices=CASES)
    parser.add_argument("--current-main-root", type=Path, required=True)
    options = parser.parse_args()
    root = options.current_main_root.resolve()
    if git("rev-parse", "HEAD", cwd=root) != CURRENT_MAIN:
        raise RuntimeError("INTEGRATION_MAIN_PIN_MISMATCH")
    if subprocess.run(
        ["git", "merge-base", "--is-ancestor", CURRENT_MAIN, "HEAD"],
        cwd=ROOT, capture_output=True,
    ).returncode != 0:
        raise RuntimeError("INTEGRATION_BRANCH_DOES_NOT_CONTAIN_MAIN")
    filename = CASES[options.case]
    module = runpy.run_path(str(filename), run_name="pr102_current_main_test")
    entry = module["main"]
    if entry.__globals__.get("DEPENDENCY_SHA") != (
        "06c2be2412e1699f3fa8f2804969e9808eb16e09"
    ):
        raise RuntimeError("ORIGINAL_DEPENDENCY_PIN_CHANGED")
    entry.__globals__["DEPENDENCY_SHA"] = CURRENT_MAIN
    print(f"PR102_COMPOSED_{options.case.upper()}_PIN_PASS main={CURRENT_MAIN}",
          flush=True)
    sys.argv = [str(filename), "--foundation-root", str(root)]
    result = entry()
    return result if isinstance(result, int) else 0


if __name__ == "__main__":
    raise SystemExit(main())
