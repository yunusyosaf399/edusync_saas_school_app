"""D1 operation acceptance on the disposable local stack only."""
from __future__ import annotations
import re
import subprocess
from pathlib import Path
from foundation_local_ci import parse_tap

ROOT = Path(__file__).resolve().parents[2]
DOMAIN_TESTS = (("01_employee_create.sql",37),)

def run_business_tests() -> int:
    total = 0
    for filename, expected in DOMAIN_TESTS:
        path = "supabase/tests/domain/" + filename
        source = (ROOT / path).read_text(encoding="utf-8")
        if not source.startswith("--") or "BEGIN;" not in source or not source.rstrip().endswith("ROLLBACK;"):
            raise RuntimeError("D1_BUSINESS_TRANSACTION_BOUNDARY " + filename)
        result = subprocess.run(["supabase","test","db",path,"--local"],
            cwd=ROOT,text=True,capture_output=True,timeout=300)
        output = result.stdout + "\n" + result.stderr
        if result.returncode:
            # SQL fixtures are synthetic; include TAP/error diagnostics, never CLI connection output.
            lines = [line for line in output.splitlines()
                if re.search(r"not ok|^\s*#|ERROR:|Failed.*(?:tests|subtests)",line)]
            raise RuntimeError("D1_BUSINESS_TEST_FAIL " + filename + "\n" + "\n".join(lines[-100:]))
        count = parse_tap(output,expected)
        total += count
        print("D1_BUSINESS_TEST_PASS " + filename + " " + str(count) + "/" + str(expected))
    print("D1_BUSINESS_PASS " + str(total) + " assertions; coverage is incremental")
    return total
