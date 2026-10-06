"""D1 operation acceptance on the disposable local stack only."""
from __future__ import annotations
import re
import subprocess
import tempfile
from pathlib import Path
from foundation_local_ci import parse_tap

ROOT = Path(__file__).resolve().parents[2]
DOMAIN_TESTS = [["01_employee_create.sql",37],["02_academic_class.sql",25],["03_employee_state.sql",22]]

def run_business_tests() -> int:
    total = 0
    for filename, expected in DOMAIN_TESTS:
        path = "supabase/tests/domain/" + filename
        source = (ROOT / path).read_text(encoding="utf-8")
        if not source.startswith("--") or "BEGIN;" not in source or not source.rstrip().endswith("ROLLBACK;"):
            raise RuntimeError("D1_BUSINESS_TRANSACTION_BOUNDARY " + filename)
        # CLI runs SQL in its test container; inline the shared fixture instead
        # of relying on psql include paths inside that container.
        fixture = (ROOT/"supabase/tests/domain/fixtures/command_actor.sql").read_text(encoding="utf-8")
        rendered = source.replace("\\\\ir fixtures/command_actor.sql",fixture)
        with tempfile.TemporaryDirectory(prefix="d1_acceptance_",dir=ROOT/"supabase/tests/database") as directory:
            generated = Path(directory)/filename
            generated.write_text(rendered,encoding="utf-8")
            result = subprocess.run(["supabase","test","db",str(generated.relative_to(ROOT)),"--local"],
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
