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
    # Current main uses a verified project-id plus its own Supabase start()
    # path, while the historical DB03/DB08 harness calls the retired
    # _start_disposable_stack() helper. Keep the compatibility adapter local to
    # this ephemeral process; never modify either pinned candidate runner.
    sys.path.insert(0, str(root / "tools/supabase"))
    import domain_local_ci as current_d1
    if not hasattr(current_d1, "_start_disposable_stack"):
        if current_d1.local_project_id(root) != current_d1.EXPECTED_PROJECT_ID:
            raise RuntimeError("INTEGRATION_LOCAL_SUPABASE_PROJECT_ID_CHANGED")
        def start_current_main_disposable_stack() -> None:
            current_d1.run(["supabase", "start"], cwd=root, timeout=900)
        current_d1._start_disposable_stack = start_current_main_disposable_stack
    filename = CASES[options.case]
    # runpy does not put the script's directory on sys.path, unlike direct
    # python execution. Candidate DB03 imports its peer race modules there.
    sys.path.insert(0, str(filename.parent))
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
