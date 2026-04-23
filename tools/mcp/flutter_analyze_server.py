from __future__ import annotations

import os
import shlex
import shutil
import subprocess
from pathlib import Path

from mcp.server.fastmcp import FastMCP


PROJECT_NAME = "Flutter Coding Helper"
DEFAULT_FLUTTER_ROOT = Path(os.environ.get("FLUTTER_ROOT", r"C:\Users\Nicola\tools\flutter"))

mcp = FastMCP(PROJECT_NAME)


def resolve_sdk_command(executable_name: str, windows_filename: str) -> str:
    command = shutil.which(executable_name)
    if command:
        return command

    candidates = []
    if os.name == "nt":
        candidates.append(DEFAULT_FLUTTER_ROOT / "bin" / windows_filename)
    else:
        candidates.append(DEFAULT_FLUTTER_ROOT / "bin" / executable_name)

    for candidate in candidates:
        if candidate.exists():
            return str(candidate)

    raise RuntimeError(
        f"Could not find the {executable_name} CLI. Add it to PATH or set FLUTTER_ROOT to the Flutter SDK root."
    )


def resolve_flutter_command() -> str:
    return resolve_sdk_command("flutter", "flutter.bat")


def resolve_dart_command() -> str:
    return resolve_sdk_command("dart", "dart.bat")


def format_command(command: list[str]) -> str:
    if os.name == "nt":
        return subprocess.list2cmdline(command)
    return shlex.join(command)


def run_command(command: list[str], working_directory: Path, timeout_seconds: int) -> str:
    try:
        completed = subprocess.run(
            command,
            cwd=working_directory,
            capture_output=True,
            text=True,
            encoding="utf-8",
            errors="replace",
            timeout=timeout_seconds,
            check=False,
        )
    except subprocess.TimeoutExpired as error:
        stdout = (error.stdout or "").strip()
        stderr = (error.stderr or "").strip()
        details = [
            f"Command: {format_command(command)}",
            f"Working directory: {working_directory}",
            f"Timed out after {timeout_seconds} seconds.",
        ]
        if stdout:
            details.append(f"STDOUT:\n{stdout}")
        if stderr:
            details.append(f"STDERR:\n{stderr}")
        return "\n\n".join(details)

    stdout = completed.stdout.strip()
    stderr = completed.stderr.strip()

    result_parts = [
        f"Command: {format_command(command)}",
        f"Working directory: {working_directory}",
        f"Exit code: {completed.returncode}",
    ]

    if stdout:
        result_parts.append(f"STDOUT:\n{stdout}")
    if stderr:
        result_parts.append(f"STDERR:\n{stderr}")

    if not stdout and not stderr:
        result_parts.append("No output returned by the command.")

    return "\n\n".join(result_parts)


def resolve_working_directory(project_root: str | None) -> Path:
    working_directory = Path(project_root).expanduser().resolve() if project_root else Path.cwd()
    if not working_directory.exists():
        raise FileNotFoundError(f"Project root does not exist: {working_directory}")
    return working_directory


@mcp.tool()
def flutter_analyze(
    target: str | None = None,
    project_root: str | None = None,
    no_pub: bool = False,
    timeout_seconds: int = 300,
) -> str:
    """Run flutter analyze and return the full analyzer output."""
    working_directory = resolve_working_directory(project_root)

    command = [resolve_flutter_command(), "analyze"]
    if no_pub:
        command.append("--no-pub")
    if target:
        command.append(target)

    return run_command(command, working_directory, timeout_seconds)


@mcp.tool()
def flutter_test(
    target: str | None = None,
    project_root: str | None = None,
    no_pub: bool = False,
    timeout_seconds: int = 300,
) -> str:
    """Run flutter test and return the full test output."""
    working_directory = resolve_working_directory(project_root)

    command = [resolve_flutter_command(), "test"]
    if no_pub:
        command.append("--no-pub")
    if target:
        command.append(target)

    return run_command(command, working_directory, timeout_seconds)


@mcp.tool()
def flutter_pub_get(project_root: str | None = None, timeout_seconds: int = 300) -> str:
    """Run flutter pub get and return the full output."""
    working_directory = resolve_working_directory(project_root)
    command = [resolve_flutter_command(), "pub", "get"]
    return run_command(command, working_directory, timeout_seconds)


@mcp.tool()
def dart_format(
    target: str | None = None,
    project_root: str | None = None,
    timeout_seconds: int = 300,
) -> str:
    """Run dart format and return the full formatter output."""
    working_directory = resolve_working_directory(project_root)

    command = [resolve_dart_command(), "format"]
    if target:
        command.append(target)
    else:
        command.append(".")

    return run_command(command, working_directory, timeout_seconds)


if __name__ == "__main__":
    mcp.run()