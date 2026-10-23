"""Fail-closed, credential-safe image-registry fallback for disposable local Supabase CI.

Supabase CLI 2.98.2 chooses one registry when its override is set. GitHub's
setup-cli action sets GHCR; an unavailable image would otherwise abort both
local database gates before PostgreSQL tests start. Keep CLI/image tags pinned.
"""

import os
import re
import subprocess
import sys

PROJECT_ID = "saas_OS_school_app"
REGISTRIES = ("ghcr.io", "docker.io", "public.ecr.aws")
IMAGE_FAILURE = (
    "manifest unknown", "pull access denied", "failed to pull image",
    "toomanyrequests", "rate limit exceeded", "failed to resolve reference",
    "unexpected status from head request", "429 too many requests",
)
OTHER_FAILURES = (
    ("DOCKER_UNAVAILABLE", ("cannot connect to the docker daemon", "docker daemon is not running", "error during connect")),
    ("PORT_CONFLICT", ("port is already allocated", "address already in use", "ports are not available")),
    ("DISK_EXHAUSTED", ("no space left on device",)),
    ("CONTAINER_UNHEALTHY", ("unhealthy", "is not healthy", "dependency failed to start")),
    ("DATABASE_CRASH", ("database failed to start", "postgres exited", "segmentation fault")),
    ("START_TIMEOUT", ("context deadline exceeded", "timed out", "timeout exceeded")),
    ("DOCKER_ERROR", ("error response from daemon",)),
)


def failure_code(output):
    lower = output.lower()
    if any(marker in lower for marker in IMAGE_FAILURE):
        return "IMAGE_PULL_FAILURE"
    for code, markers in OTHER_FAILURES:
        if any(marker in lower for marker in markers):
            return code
    return "UNCLASSIFIED"


def postgres_state(root, project_id):
    try:
        result = subprocess.run(
            ["docker", "inspect", "--format",
             "{{.State.Status}}|{{.State.ExitCode}}|{{.State.OOMKilled}}",
             "supabase_db_" + project_id],
            cwd=root, text=True, capture_output=True, timeout=10,
        )
    except (OSError, subprocess.TimeoutExpired):
        return "UNAVAILABLE"
    if result.returncode:
        return "ABSENT"
    parts = result.stdout.strip().split("|")
    if len(parts) != 3:
        return "UNAVAILABLE"
    status, exit_code, oom = parts
    if (status not in {"created", "running", "restarting", "removing", "paused", "exited", "dead"}
            or not re.fullmatch(r"[0-9]{1,3}", exit_code)
            or oom not in {"true", "false"}):
        return "UNAVAILABLE"
    return f"{status},exit={exit_code},oom={oom}"


def start_disposable_stack(root, project_id, label):
    """Only retry an image-pull error, using official Supabase registries.

    No SQL, migration, privilege, CLI or PostgreSQL image tag is changed.
    Raw CLI/daemon output is never logged, including on all retry failures.
    """
    if project_id != PROJECT_ID or label not in {"D1C2A", "FOUNDATION"}:
        raise RuntimeError("LOCAL_STACK_TARGET_INVALID")
    initial = os.environ.get("SUPABASE_INTERNAL_IMAGE_REGISTRY", "public.ecr.aws").lower()
    if initial not in REGISTRIES:
        raise RuntimeError("LOCAL_IMAGE_REGISTRY_UNSUPPORTED")
    candidates = list(dict.fromkeys((initial, "docker.io", "public.ecr.aws", "ghcr.io")))
    for number, registry in enumerate(candidates, 1):
        env = dict(os.environ)
        env["SUPABASE_INTERNAL_IMAGE_REGISTRY"] = registry
        try:
            result = subprocess.run(
                ["supabase", "start"], cwd=root, env=env, text=True,
                encoding="utf-8", errors="replace", capture_output=True,
                timeout=900,
            )
        except (OSError, subprocess.TimeoutExpired) as exc:
            print(label + "_START_DIAGNOSTIC code=START_COMMAND_UNAVAILABLE_OR_TIMEOUT"
                  + " pg_state=" + postgres_state(root, project_id), file=sys.stderr)
            raise RuntimeError("supabase start unavailable or timed out") from exc
        if result.returncode == 0:
            # setup-cli exports GHCR globally. Keep the working registry for
            # all subsequent subprocesses (db reset, pgTAP test db, lint).
            # Process-local only: no repository, workflow or hosted setting.
            os.environ["SUPABASE_INTERNAL_IMAGE_REGISTRY"] = registry
            print(label + "_START_REGISTRY_PASS registry=" + registry
                  + " attempt=" + str(number))
            return
        code = failure_code((result.stderr or "") + "\n" + (result.stdout or ""))
        print(label + "_START_DIAGNOSTIC code=" + code
              + " pg_state=" + postgres_state(root, project_id)
              + " registry=" + registry, file=sys.stderr)
        if code != "IMAGE_PULL_FAILURE" or number == len(candidates):
            raise RuntimeError("supabase start (exit nonzero)")
        # A failed start may have created other project-local containers. Stop
        # only the already validated disposable project; never touch hosted DBs.
        try:
            subprocess.run(
                ["supabase", "stop", "--project-id", project_id],
                cwd=root, env=env, text=True, capture_output=True, timeout=180,
            )
        except (OSError, subprocess.TimeoutExpired):
            raise RuntimeError("LOCAL_STACK_RETRY_CLEANUP_UNAVAILABLE") from None
        print(label + "_START_REGISTRY_RETRY next=" + candidates[number], file=sys.stderr)
    raise RuntimeError("LOCAL_STACK_START_EXHAUSTED")
