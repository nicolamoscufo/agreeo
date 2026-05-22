from __future__ import annotations

import os
import shlex
import shutil
import subprocess
from pathlib import Path

from mcp.server.fastmcp import FastMCP


PROJECT_NAME = "Graphify Helper"
DEFAULT_WORKSPACE_ROOT = Path(__file__).resolve().parents[2]

mcp = FastMCP(PROJECT_NAME)


def resolve_workspace_root(project_root: str | None) -> Path:
    workspace_root = Path(project_root).expanduser().resolve() if project_root else DEFAULT_WORKSPACE_ROOT
    if not workspace_root.exists():
        raise FileNotFoundError(f"Project root does not exist: {workspace_root}")
    return workspace_root


def resolve_graphify_command() -> list[str]:
    command = shutil.which("nodesify-graphify")
    if command:
        return [command]

    npx = shutil.which("npx")
    if npx:
        return [npx, "-y", "@nodesify/graphify"]

    raise RuntimeError("Could not find nodesify-graphify or npx. Install @nodesify/graphify or add it to PATH.")


def format_command(command: list[str]) -> str:
    if os.name == "nt":
        return subprocess.list2cmdline(command)
    return shlex.join(command)


def run_graphify_command(command_args: list[str], working_directory: Path, timeout_seconds: int) -> str:
    command = resolve_graphify_command() + command_args

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


@mcp.tool()
def graphify_run(project_root: str | None = None, timeout_seconds: int = 1200) -> str:
    """Run a full Graphify build for the workspace."""
    workspace_root = resolve_workspace_root(project_root)
    return run_graphify_command(["run", str(workspace_root)], workspace_root, timeout_seconds)


@mcp.tool()
def graphify_update(project_root: str | None = None, timeout_seconds: int = 1200) -> str:
    """Run an incremental Graphify rebuild for the workspace."""
    workspace_root = resolve_workspace_root(project_root)
    return run_graphify_command(["update", str(workspace_root)], workspace_root, timeout_seconds)


@mcp.tool()
def graphify_query(
    question: str,
    project_root: str | None = None,
    depth: int = 2,
    budget: int = 2000,
    dfs: bool = False,
    timeout_seconds: int = 1200,
) -> str:
    """Query the graph with a natural-language question."""
    workspace_root = resolve_workspace_root(project_root)
    command_args = ["query", question, "--depth", str(depth), "--budget", str(budget), "--graph", str(workspace_root)]
    if dfs:
        command_args.insert(2, "--dfs")
    return run_graphify_command(command_args, workspace_root, timeout_seconds)


@mcp.tool()
def graphify_explain(node: str, project_root: str | None = None, timeout_seconds: int = 1200) -> str:
    """Explain a graph node and its connections."""
    workspace_root = resolve_workspace_root(project_root)
    return run_graphify_command(["explain", node, "--graph", str(workspace_root)], workspace_root, timeout_seconds)


@mcp.tool()
def graphify_path(
    source: str,
    target: str,
    project_root: str | None = None,
    timeout_seconds: int = 1200,
) -> str:
    """Find the shortest path between two graph nodes."""
    workspace_root = resolve_workspace_root(project_root)
    return run_graphify_command(["path", source, target, "--graph", str(workspace_root)], workspace_root, timeout_seconds)


@mcp.tool()
def graphify_stats(project_root: str | None = None, timeout_seconds: int = 1200) -> str:
    """Show graph statistics for the workspace."""
    workspace_root = resolve_workspace_root(project_root)
    return run_graphify_command(["stats", "--graph", str(workspace_root)], workspace_root, timeout_seconds)


@mcp.tool()
def graphify_export(
    project_root: str | None = None,
    out: str | None = None,
    timeout_seconds: int = 1200,
) -> str:
    """Export the graph to JSON, HTML, or GraphML."""
    workspace_root = resolve_workspace_root(project_root)
    command_args = ["export", "--graph", str(workspace_root)]
    if out:
        command_args.extend(["--out", out])
    return run_graphify_command(command_args, workspace_root, timeout_seconds)


if __name__ == "__main__":
    mcp.run()