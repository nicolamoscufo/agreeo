from __future__ import annotations

import os
import re
import shlex
import shutil
import subprocess
from pathlib import Path

from mcp.server.fastmcp import FastMCP


PROJECT_NAME = "Workspace and Git Helper"
DEFAULT_WORKSPACE_ROOT = Path(__file__).resolve().parents[2]
IGNORED_PARTS = {
    ".dart_tool",
    ".git",
    ".idea",
    ".venv",
    "Pods",
    "build",
    "node_modules",
}

mcp = FastMCP(PROJECT_NAME)


def resolve_git_command() -> str:
    command = shutil.which("git")
    if command:
        return command
    raise RuntimeError("Could not find the git CLI. Add git to PATH.")


def format_command(command: list[str]) -> str:
    if os.name == "nt":
        return subprocess.list2cmdline(command)
    return shlex.join(command)


def resolve_workspace_root(project_root: str | None) -> Path:
    workspace_root = Path(project_root).expanduser().resolve() if project_root else DEFAULT_WORKSPACE_ROOT
    if not workspace_root.exists():
        raise FileNotFoundError(f"Project root does not exist: {workspace_root}")
    return workspace_root


def resolve_workspace_path(path_value: str, workspace_root: Path) -> Path:
    path = Path(path_value)
    if not path.is_absolute():
        path = workspace_root / path
    resolved = path.resolve()
    try:
        resolved.relative_to(workspace_root)
    except ValueError as error:
        raise ValueError(f"Path is outside the workspace: {path_value}") from error
    return resolved


def is_ignored_path(path: Path) -> bool:
    return any(part in IGNORED_PARTS for part in path.parts)


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


def ensure_git_repo(workspace_root: Path) -> Path:
    command = [resolve_git_command(), "rev-parse", "--show-toplevel"]
    completed = subprocess.run(
        command,
        cwd=workspace_root,
        capture_output=True,
        text=True,
        encoding="utf-8",
        errors="replace",
        check=False,
    )
    if completed.returncode != 0:
        raise RuntimeError(f"Not inside a git repository: {workspace_root}")

    git_root = Path(completed.stdout.strip()).resolve()
    return git_root


def has_git_commit(git_root: Path) -> bool:
    command = [resolve_git_command(), "rev-parse", "--verify", "HEAD"]
    completed = subprocess.run(
        command,
        cwd=git_root,
        capture_output=True,
        text=True,
        encoding="utf-8",
        errors="replace",
        check=False,
    )
    return completed.returncode == 0


def map_path_to_git_path(path_value: str, workspace_root: Path, git_root: Path) -> str:
    path = Path(path_value)
    if not path.is_absolute():
        path = workspace_root / path

    resolved = path.resolve()
    if resolved.is_relative_to(workspace_root):
        relative_to_workspace = resolved.relative_to(workspace_root)
        try:
            workspace_prefix = workspace_root.relative_to(git_root)
        except ValueError:
            workspace_prefix = Path(".")
        return str((workspace_prefix / relative_to_workspace).as_posix())

    if resolved.is_relative_to(git_root):
        return str(resolved.relative_to(git_root).as_posix())

    raise ValueError(f"Path is outside the git repository: {path_value}")


@mcp.tool()
def workspace_find_files(
    pattern: str = "**/*.dart",
    project_root: str | None = None,
    max_results: int = 200,
) -> str:
    """Find files in the workspace using a glob pattern."""
    workspace_root = resolve_workspace_root(project_root)

    matches: list[str] = []
    for candidate in sorted(workspace_root.glob(pattern)):
        if not candidate.is_file():
            continue
        try:
            relative_path = candidate.relative_to(workspace_root)
        except ValueError:
            continue
        if is_ignored_path(relative_path):
            continue
        matches.append(str(relative_path).replace("\\", "/"))
        if len(matches) >= max_results:
            break

    result_parts = [
        f"Pattern: {pattern}",
        f"Workspace root: {workspace_root}",
        f"Matches: {len(matches)}",
    ]
    result_parts.extend(matches or ["No files matched."])
    if len(matches) >= max_results:
        result_parts.append(f"Truncated at {max_results} results.")

    return "\n".join(result_parts)


@mcp.tool()
def workspace_read_file(
    file_path: str,
    project_root: str | None = None,
    start_line: int = 1,
    end_line: int = 200,
) -> str:
    """Read a text file from the workspace with line numbers."""
    workspace_root = resolve_workspace_root(project_root)
    resolved_path = resolve_workspace_path(file_path, workspace_root)

    if not resolved_path.exists():
        raise FileNotFoundError(f"File does not exist: {resolved_path}")
    if resolved_path.is_dir():
        raise IsADirectoryError(f"Expected a file but got a directory: {resolved_path}")

    all_lines = resolved_path.read_text(encoding="utf-8", errors="replace").splitlines()
    if start_line < 1:
        start_line = 1
    if end_line < start_line:
        end_line = start_line

    start_index = start_line - 1
    end_index = min(end_line, len(all_lines))
    selected_lines = all_lines[start_index:end_index]

    result_lines = [
        f"File: {resolved_path.relative_to(workspace_root)}",
        f"Line range: {start_line}-{end_line}",
    ]
    for line_number, line_content in enumerate(selected_lines, start=start_line):
        result_lines.append(f"{line_number}: {line_content}")

    if not selected_lines:
        result_lines.append("No content in the requested line range.")

    return "\n".join(result_lines)


@mcp.tool()
def workspace_search_text(
    query: str,
    project_root: str | None = None,
    include_pattern: str = "**/*",
    case_sensitive: bool = False,
    regex: bool = False,
    max_results: int = 50,
    max_file_size_kb: int = 512,
) -> str:
    """Search text across workspace files and return matching lines."""
    workspace_root = resolve_workspace_root(project_root)

    if regex:
        flags = 0 if case_sensitive else re.IGNORECASE
        matcher = re.compile(query, flags)
    else:
        normalized_query = query if case_sensitive else query.casefold()
        matcher = None

    matches: list[str] = []
    inspected_files = 0
    size_limit_bytes = max_file_size_kb * 1024

    for candidate in sorted(workspace_root.glob(include_pattern)):
        if not candidate.is_file():
            continue

        try:
            relative_path = candidate.relative_to(workspace_root)
        except ValueError:
            continue

        if is_ignored_path(relative_path):
            continue

        if candidate.stat().st_size > size_limit_bytes:
            continue

        inspected_files += 1
        try:
            with candidate.open("r", encoding="utf-8", errors="replace") as handle:
                for line_number, line_content in enumerate(handle, start=1):
                    line_text = line_content.rstrip("\n")
                    if regex:
                        matched = matcher.search(line_text) is not None
                    else:
                        haystack = line_text if case_sensitive else line_text.casefold()
                        matched = normalized_query in haystack

                    if matched:
                        matches.append(
                            f"{str(relative_path).replace('\\', '/') }:{line_number}: {line_text}"
                        )
                        if len(matches) >= max_results:
                            break
        except (OSError, UnicodeError):
            continue

        if len(matches) >= max_results:
            break

    result_lines = [
        f"Query: {query}",
        f"Include pattern: {include_pattern}",
        f"Workspace root: {workspace_root}",
        f"Files inspected: {inspected_files}",
        f"Matches: {len(matches)}",
    ]
    result_lines.extend(matches or ["No matches found."])
    if len(matches) >= max_results:
        result_lines.append(f"Truncated at {max_results} results.")

    return "\n".join(result_lines)


@mcp.tool()
def git_status(project_root: str | None = None, timeout_seconds: int = 30) -> str:
    """Return the current git status for the workspace."""
    workspace_root = resolve_workspace_root(project_root)
    git_root = ensure_git_repo(workspace_root)
    command = [resolve_git_command(), "status", "--short", "--branch", "--untracked-files=all"]
    return run_command(command, git_root, timeout_seconds)


@mcp.tool()
def git_diff(
    project_root: str | None = None,
    path: str | None = None,
    cached: bool = False,
    stat_only: bool = False,
    timeout_seconds: int = 60,
) -> str:
    """Return the git diff for the workspace or a specific path."""
    workspace_root = resolve_workspace_root(project_root)
    git_root = ensure_git_repo(workspace_root)

    if not has_git_commit(git_root):
        status_command = [resolve_git_command(), "status", "--short", "--branch", "--untracked-files=all"]
        if path:
            relative_path = map_path_to_git_path(path, workspace_root, git_root)
            status_command.extend(["--", relative_path])
        status_output = run_command(status_command, git_root, timeout_seconds)
        return "No commits yet in this repository.\n\n" + status_output

    command = [resolve_git_command(), "diff", "--no-ext-diff", "--unified=3"]
    if cached:
        command.append("--cached")
    if stat_only:
        command.extend(["--stat", "--summary"])
    if path:
        relative_path = map_path_to_git_path(path, workspace_root, git_root)
        command.extend(["--", relative_path])

    return run_command(command, git_root, timeout_seconds)


@mcp.tool()
def git_log(
    project_root: str | None = None,
    max_count: int = 20,
    timeout_seconds: int = 30,
) -> str:
    """Return a compact recent git log."""
    workspace_root = resolve_workspace_root(project_root)
    git_root = ensure_git_repo(workspace_root)

    if not has_git_commit(git_root):
        return f"Working directory: {git_root}\n\nNo commits yet in this repository."

    bounded_count = max(1, min(max_count, 200))
    command = [
        resolve_git_command(),
        "log",
        f"-n{bounded_count}",
        "--date=short",
        "--pretty=format:%h %ad %an %s",
    ]
    return run_command(command, git_root, timeout_seconds)


@mcp.tool()
def git_blame(
    file_path: str,
    project_root: str | None = None,
    line: int | None = None,
    timeout_seconds: int = 30,
) -> str:
    """Return git blame for a file or a single line."""
    workspace_root = resolve_workspace_root(project_root)
    git_root = ensure_git_repo(workspace_root)

    if not has_git_commit(git_root):
        return "No commits yet in this repository. Git blame is unavailable until the first commit exists."

    relative_path = map_path_to_git_path(file_path, workspace_root, git_root)

    command = [resolve_git_command(), "blame"]
    if line is not None:
        line_number = max(1, line)
        command.extend(["-L", f"{line_number},{line_number}"])
    command.extend(["--", relative_path])

    return run_command(command, git_root, timeout_seconds)


if __name__ == "__main__":
    mcp.run()