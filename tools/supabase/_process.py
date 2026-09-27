"""Small subprocess wrapper that never includes captured output in exceptions."""

import subprocess


class CommandFailure(RuntimeError):
    pass


def run(args, *, cwd, timeout=300, env=None):
    try:
        result = subprocess.run(args, cwd=cwd, env=env, text=True, capture_output=True, timeout=timeout)
    except (OSError, subprocess.TimeoutExpired) as exc:
        raise CommandFailure("command unavailable or timed out: " + args[0]) from exc
    if result.returncode:
        raise CommandFailure("command failed: " + " ".join(args[:3]) + " (exit " + str(result.returncode) + ")")
    return result.stdout
