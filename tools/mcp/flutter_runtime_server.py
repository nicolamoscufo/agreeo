from __future__ import annotations

import base64
import json
import os
import re
import shlex
import shutil
import subprocess
import threading
import time
from collections import deque
from dataclasses import dataclass, field
from pathlib import Path
from typing import Any

from mcp.server.fastmcp import FastMCP


PROJECT_NAME = "Flutter Runtime Helper"
DEFAULT_FLUTTER_ROOT = Path(os.environ.get("FLUTTER_ROOT", r"C:\Users\Nicola\tools\flutter"))
DEFAULT_TIMEOUT_SECONDS = 300
DEFAULT_STARTUP_TIMEOUT_SECONDS = 300
DEFAULT_STOP_TIMEOUT_SECONDS = 20
MAX_TRANSCRIPT_LINES = 500

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


def pretty_json(value: Any) -> str:
    return json.dumps(value, ensure_ascii=False, indent=2, sort_keys=True, default=str)


def truncate_text(value: Any, limit: int = 200) -> str:
    text = str(value)
    if len(text) <= limit:
        return text
    return text[: limit - 3] + "..."


def summarize_params(event: str, params: Any) -> str:
    if not isinstance(params, dict):
        return f"[{event}] {truncate_text(params)}"

    if event == "app.log":
        log_value = params.get("log")
        if isinstance(log_value, str):
            return f"[app.log] {truncate_text(log_value)}"

    if event == "app.progress":
        message = params.get("message")
        finished = params.get("finished")
        progress_bits = []
        if message is not None:
            progress_bits.append(f"message={truncate_text(message)}")
        if finished is not None:
            progress_bits.append(f"finished={finished}")
        if progress_bits:
            return f"[app.progress] {', '.join(progress_bits)}"

    if event == "app.start":
        keys = ("appId", "deviceId", "mode", "launchMode", "supportsRestart", "directory")
    elif event == "app.debugPort":
        keys = ("appId", "port", "wsUri", "baseUri")
    elif event == "app.started":
        keys = ("appId",)
    elif event == "app.stop":
        keys = ("appId", "error")
    elif event == "daemon.connected":
        keys = ("version", "pid")
    elif event == "app.webLaunchUrl":
        keys = ("url", "launched")
    else:
        keys = tuple(params.keys())

    bits: list[str] = []
    for key in keys:
        if key in params and params[key] is not None:
            bits.append(f"{key}={truncate_text(params[key])}")

    if bits:
        return f"[{event}] {', '.join(bits)}"

    return f"[{event}] {truncate_text(params)}"


def format_response_value(response: dict[str, Any]) -> str:
    return pretty_json(service_response_payload(response))


def truncate_multiline_text(text: str, limit: int = 20000) -> str:
    if len(text) <= limit:
        return text
    return text[:limit] + "\n... [truncated]"


def service_response_payload(response: dict[str, Any]) -> Any:
    if "error" in response:
        return response["error"]
    if "result" in response:
        return response["result"]
    return response


def bool_string(value: bool) -> str:
    return "true" if value else "false"


def build_vararg_params(values: list[str]) -> dict[str, str]:
    return {f"arg{index}": value for index, value in enumerate(values)}


def sanitize_filename_component(value: str, fallback: str = "object") -> str:
    sanitized = re.sub(r"[^A-Za-z0-9._-]+", "_", value.strip())
    sanitized = sanitized.strip("._-")
    return sanitized or fallback


def get_workspace_session(project_root: str | None, require_app_id: bool = True) -> tuple[Path, FlutterMachineSession] | str:
    working_directory = resolve_working_directory(project_root)
    session = get_session(working_directory)
    if session is None:
        return f"No active Flutter runtime session for {working_directory}. Start one first with flutter_run_start."
    if require_app_id and session.app_id is None:
        return session_error_message("The running app has not reported an appId yet.", session)
    return working_directory, session


def call_flutter_service_extension(
    session: FlutterMachineSession,
    method_name: str,
    params: dict[str, Any] | None = None,
    timeout_seconds: int = 60,
) -> dict[str, Any]:
    if session.app_id is None:
        raise RuntimeError("The running app has not reported an appId yet.")

    payload: dict[str, Any] = {"appId": session.app_id, "methodName": method_name}
    if params is not None:
        payload["params"] = params
    return session.send_request("app.callServiceExtension", payload, timeout_seconds=timeout_seconds)


def format_json_tool_output(
    title: str,
    workspace_root: Path,
    session: FlutterMachineSession,
    payload: Any,
    output_path: str | None = None,
    recent_lines: int = 10,
    max_chars: int = 20000,
) -> str:
    json_text = pretty_json(payload)
    if output_path is not None:
        target_path = Path(output_path).expanduser()
        if not target_path.is_absolute():
            target_path = workspace_root / target_path
        target_path.parent.mkdir(parents=True, exist_ok=True)
        target_path.write_text(json_text, encoding="utf-8")
        body = f"Saved JSON to {target_path}\nBytes written: {len(json_text.encode('utf-8'))}"
    else:
        body = truncate_multiline_text(json_text, max_chars)

    lines = [
        title,
        f"Workspace root: {workspace_root}",
        f"App id: {session.app_id if session.app_id is not None else 'unknown'}",
        "",
        body,
    ]
    recent_output = session.transcript_tail(recent_lines)
    if recent_output:
        lines.extend(["", "Recent output:"])
        lines.extend(recent_output)
    return "\n".join(lines)


def format_text_tool_output(
    title: str,
    workspace_root: Path,
    session: FlutterMachineSession,
    payload: Any,
    output_path: str | None = None,
    recent_lines: int = 10,
    max_chars: int = 20000,
) -> str:
    if isinstance(payload, dict) and set(payload.keys()) == {"data"} and isinstance(payload["data"], str):
        text = payload["data"]
    else:
        text = pretty_json(payload)

    if output_path is not None:
        target_path = Path(output_path).expanduser()
        if not target_path.is_absolute():
            target_path = workspace_root / target_path
        target_path.parent.mkdir(parents=True, exist_ok=True)
        target_path.write_text(text, encoding="utf-8")
        body = f"Saved text to {target_path}\nBytes written: {len(text.encode('utf-8'))}"
    else:
        body = truncate_multiline_text(text, max_chars)

    lines = [
        title,
        f"Workspace root: {workspace_root}",
        f"App id: {session.app_id if session.app_id is not None else 'unknown'}",
        "",
        body,
    ]
    recent_output = session.transcript_tail(recent_lines)
    if recent_output:
        lines.extend(["", "Recent output:"])
        lines.extend(recent_output)
    return "\n".join(lines)


def resolve_screenshot_path(workspace_root: Path, object_id: str, output_path: str | None) -> Path:
    if output_path is not None:
        target_path = Path(output_path).expanduser()
        if not target_path.is_absolute():
            target_path = workspace_root / target_path
    else:
        screenshots_dir = workspace_root / ".mcp" / "flutter_screenshots"
        timestamp = time.strftime("%Y%m%d-%H%M%S")
        safe_id = sanitize_filename_component(object_id)[:48]
        target_path = screenshots_dir / f"{timestamp}-{safe_id}.png"

    target_path.parent.mkdir(parents=True, exist_ok=True)
    return target_path


def format_startup_summary(
    session: "FlutterMachineSession",
    note: str | None = None,
    include_transcript: bool = True,
    transcript_lines: int = 20,
) -> str:
    lines = [
        "Flutter machine session",
        f"Workspace root: {session.workspace_root}",
        f"Device: {session.device_id}",
        f"Target: {session.target}",
        f"Build mode: {session.build_mode}",
        f"Command: {format_command(session.command)}",
        f"Process pid: {session.process.pid}",
        f"Daemon pid: {session.daemon_pid if session.daemon_pid is not None else 'unknown'}",
        f"App id: {session.app_id if session.app_id is not None else 'unknown'}",
        f"VM service uri: {session.vm_service_uri if session.vm_service_uri is not None else 'unknown'}",
        f"Debug port: {session.debug_port if session.debug_port is not None else 'unknown'}",
        f"Started: {'yes' if session.started_event.is_set() else 'no'}",
        f"Running: {'yes' if session.is_running() else 'no'}",
    ]
    if session.last_error:
        lines.append(f"Last error: {session.last_error}")
    if note:
        lines.append(note)
    transcript = session.transcript_tail(transcript_lines) if include_transcript else []
    if transcript:
        lines.append("")
        lines.append("Recent output:")
        lines.extend(transcript)
    return "\n".join(lines)


def workspace_key(workspace_root: Path) -> str:
    return str(workspace_root.resolve())


_SESSION_LOCK = threading.RLock()
_SESSIONS: dict[str, "FlutterMachineSession"] = {}


@dataclass
class FlutterMachineSession:
    workspace_root: Path
    device_id: str
    target: str
    build_mode: str
    route: str | None
    no_pub: bool
    extra_args: list[str]
    command: list[str]
    process: subprocess.Popen[str]
    transcript: deque[str] = field(default_factory=lambda: deque(maxlen=MAX_TRANSCRIPT_LINES))
    pending_responses: dict[int, dict[str, Any]] = field(default_factory=dict)
    condition: threading.Condition = field(default_factory=threading.Condition)
    stdin_lock: threading.Lock = field(default_factory=threading.Lock)
    request_counter: int = 0
    app_id: str | None = None
    vm_service_uri: str | None = None
    debug_port: int | None = None
    daemon_pid: int | None = None
    launch_mode: str | None = None
    runtime_mode: str | None = None
    supports_restart: bool | None = None
    last_error: str | None = None
    exit_code: int | None = None
    started_event: threading.Event = field(default_factory=threading.Event)
    finished_event: threading.Event = field(default_factory=threading.Event)

    def start_reader_threads(self) -> None:
        stdout_thread = threading.Thread(target=self._read_stdout, name="flutter-stdout", daemon=True)
        stderr_thread = threading.Thread(target=self._read_stderr, name="flutter-stderr", daemon=True)
        stdout_thread.start()
        stderr_thread.start()

    def is_running(self) -> bool:
        return self.process.poll() is None

    def transcript_tail(self, count: int) -> list[str]:
        if count <= 0:
            return []
        return list(self.transcript)[-count:]

    def _append_transcript(self, prefix: str, text: str) -> None:
        lines = text.splitlines() or [""]
        for line in lines:
            if prefix:
                self.transcript.append(f"[{prefix}] {line}")
            else:
                self.transcript.append(line)

    def _read_stdout(self) -> None:
        try:
            if self.process.stdout is None:
                return
            for raw_line in self.process.stdout:
                line = raw_line.rstrip("\r\n")
                if not line:
                    continue
                self._handle_stdout_line(line)
        finally:
            self.exit_code = self.process.poll()
            self.finished_event.set()
            with self.condition:
                self.condition.notify_all()

    def _read_stderr(self) -> None:
        try:
            if self.process.stderr is None:
                return
            for raw_line in self.process.stderr:
                line = raw_line.rstrip("\r\n")
                if not line:
                    continue
                self._append_transcript("stderr", line)
        finally:
            self.finished_event.set()
            with self.condition:
                self.condition.notify_all()

    def _handle_stdout_line(self, line: str) -> None:
        try:
            payload = json.loads(line)
        except json.JSONDecodeError:
            self._append_transcript("stdout", line)
            return

        if isinstance(payload, dict):
            if "event" in payload:
                event_name = str(payload.get("event"))
                params = payload.get("params")
                self._handle_event(event_name, params)
                return

            if "id" in payload:
                self._handle_response(payload)
                return

        self._append_transcript("stdout", line)

    def _handle_event(self, event_name: str, params: Any) -> None:
        if event_name == "daemon.connected" and isinstance(params, dict):
            version = params.get("version")
            if version is not None:
                self._append_transcript("event", f"daemon.connected version={version} pid={params.get('pid')}")
            else:
                self._append_transcript("event", summarize_params(event_name, params))
            pid_value = params.get("pid")
            if isinstance(pid_value, int):
                self.daemon_pid = pid_value
            elif isinstance(pid_value, str) and pid_value.isdigit():
                self.daemon_pid = int(pid_value)
        else:
            self._append_transcript("event", summarize_params(event_name, params))

        if not isinstance(params, dict):
            return

        if event_name == "app.start":
            app_id = params.get("appId")
            if isinstance(app_id, str):
                self.app_id = app_id
            launch_mode = params.get("launchMode")
            if isinstance(launch_mode, str):
                self.launch_mode = launch_mode
            runtime_mode = params.get("mode")
            if isinstance(runtime_mode, str):
                self.runtime_mode = runtime_mode
            supports_restart = params.get("supportsRestart")
            if isinstance(supports_restart, bool):
                self.supports_restart = supports_restart
        elif event_name == "app.debugPort":
            app_id = params.get("appId")
            if isinstance(app_id, str):
                self.app_id = app_id
            port_value = params.get("port")
            if isinstance(port_value, int):
                self.debug_port = port_value
            elif isinstance(port_value, str) and port_value.isdigit():
                self.debug_port = int(port_value)
            ws_uri = params.get("wsUri")
            if isinstance(ws_uri, str):
                self.vm_service_uri = ws_uri
        elif event_name == "app.started":
            app_id = params.get("appId")
            if isinstance(app_id, str):
                self.app_id = app_id
            self.started_event.set()
            with self.condition:
                self.condition.notify_all()
        elif event_name == "app.stop":
            error_value = params.get("error")
            if error_value is not None:
                self.last_error = str(error_value)
            self.started_event.set()
            with self.condition:
                self.condition.notify_all()
        elif event_name == "app.webLaunchUrl":
            url_value = params.get("url")
            if isinstance(url_value, str):
                self.vm_service_uri = url_value

    def _handle_response(self, payload: dict[str, Any]) -> None:
        request_id = payload.get("id")
        if isinstance(request_id, str) and request_id.isdigit():
            request_id = int(request_id)
        if not isinstance(request_id, int):
            return

        with self.condition:
            self.pending_responses[request_id] = payload
            self.condition.notify_all()

    def _wait_for_response(self, request_id: int, timeout_seconds: int) -> dict[str, Any]:
        deadline = time.monotonic() + timeout_seconds
        while True:
            with self.condition:
                response = self.pending_responses.pop(request_id, None)
                if response is not None:
                    return response

                if self.process.poll() is not None:
                    self.exit_code = self.process.returncode
                    raise RuntimeError(self._process_exit_message())

                remaining = deadline - time.monotonic()
                if remaining <= 0:
                    raise TimeoutError(
                        f"Timed out waiting for response to {request_id} after {timeout_seconds} seconds."
                    )
                self.condition.wait(timeout=min(0.5, remaining))

    def _process_exit_message(self) -> str:
        message_lines = [
            "Flutter process exited unexpectedly.",
            f"Command: {format_command(self.command)}",
            f"Process pid: {self.process.pid}",
            f"Exit code: {self.exit_code if self.exit_code is not None else self.process.returncode}",
        ]
        transcript = self.transcript_tail(25)
        if transcript:
            message_lines.append("Recent output:")
            message_lines.extend(transcript)
        return "\n".join(message_lines)

    def send_request(self, method: str, params: dict[str, Any] | None = None, timeout_seconds: int = 60) -> dict[str, Any]:
        if self.process.poll() is not None:
            self.exit_code = self.process.returncode
            raise RuntimeError(self._process_exit_message())

        with self.condition:
            self.request_counter += 1
            request_id = self.request_counter

        payload: dict[str, Any] = {"id": request_id, "method": method}
        if params is not None:
            payload["params"] = params

        message = json.dumps(payload, ensure_ascii=False, separators=(",", ":"))
        self._append_transcript("request", f"{method} id={request_id}")
        if params is not None:
            self._append_transcript("request", truncate_text(params, 240))

        if self.process.stdin is None:
            raise RuntimeError("Flutter process does not have a writable stdin.")

        with self.stdin_lock:
            self.process.stdin.write(message + "\n")
            self.process.stdin.flush()

        response = self._wait_for_response(request_id, timeout_seconds)
        return response

    def wait_for_started(self, timeout_seconds: int) -> bool:
        deadline = time.monotonic() + timeout_seconds
        while time.monotonic() < deadline:
            if self.started_event.is_set():
                return True
            if self.process.poll() is not None:
                self.exit_code = self.process.returncode
                return False
            time.sleep(0.25)
        return self.started_event.is_set()

    def wait_for_exit(self, timeout_seconds: int) -> bool:
        deadline = time.monotonic() + timeout_seconds
        while time.monotonic() < deadline:
            code = self.process.poll()
            if code is not None:
                self.exit_code = code
                return True
            time.sleep(0.25)
        return self.process.poll() is not None

    def graceful_stop(self, timeout_seconds: int = DEFAULT_STOP_TIMEOUT_SECONDS) -> str:
        if self.process.poll() is not None:
            self.exit_code = self.process.returncode
            return self._process_exit_message()

        if self.app_id:
            try:
                response = self.send_request("app.stop", {"appId": self.app_id}, timeout_seconds=timeout_seconds)
                if "error" in response:
                    self.last_error = truncate_text(response["error"], 240)
            except Exception as error:  # noqa: BLE001
                self.last_error = str(error)

        if not self.wait_for_exit(timeout_seconds):
            self._force_kill_process()
            self.wait_for_exit(5)

        self.exit_code = self.process.poll()
        return self._process_exit_message()

    def detach(self, timeout_seconds: int = DEFAULT_STOP_TIMEOUT_SECONDS) -> str:
        if self.process.poll() is not None:
            self.exit_code = self.process.returncode
            return self._process_exit_message()

        if self.app_id:
            try:
                response = self.send_request("app.detach", {"appId": self.app_id}, timeout_seconds=timeout_seconds)
                if "error" in response:
                    self.last_error = truncate_text(response["error"], 240)
            except Exception as error:  # noqa: BLE001
                self.last_error = str(error)

        if not self.wait_for_exit(timeout_seconds):
            self._force_kill_process()
            self.wait_for_exit(5)

        self.exit_code = self.process.poll()
        return self._process_exit_message()

    def _force_kill_process(self) -> None:
        if os.name == "nt" and self.daemon_pid is not None:
            subprocess.run(
                ["taskkill", "/PID", str(self.daemon_pid), "/T", "/F"],
                capture_output=True,
                text=True,
                encoding="utf-8",
                errors="replace",
                check=False,
            )
            return

        if self.process.poll() is None:
            try:
                self.process.kill()
            except OSError:
                pass


def get_session(workspace_root: Path) -> FlutterMachineSession | None:
    key = workspace_key(workspace_root)
    with _SESSION_LOCK:
        session = _SESSIONS.get(key)

    if session is not None and not session.is_running():
        with _SESSION_LOCK:
            current = _SESSIONS.get(key)
            if current is session:
                _SESSIONS.pop(key, None)
        return None

    return session


def store_session(workspace_root: Path, session: FlutterMachineSession) -> None:
    with _SESSION_LOCK:
        _SESSIONS[workspace_key(workspace_root)] = session


def remove_session(workspace_root: Path, session: FlutterMachineSession | None = None) -> None:
    key = workspace_key(workspace_root)
    with _SESSION_LOCK:
        if session is None:
            _SESSIONS.pop(key, None)
            return
        current = _SESSIONS.get(key)
        if current is session:
            _SESSIONS.pop(key, None)


def build_run_command(
    device_id: str,
    target: str,
    build_mode: str,
    route: str | None,
    no_pub: bool,
    extra_args: list[str] | None,
) -> list[str]:
    command = [resolve_flutter_command(), "run", "--machine", "-d", device_id, "-t", target]

    normalized_mode = build_mode.strip().lower()
    if normalized_mode == "profile":
        command.append("--profile")
    elif normalized_mode == "release":
        command.append("--release")
    elif normalized_mode != "debug":
        raise ValueError("build_mode must be one of: debug, profile, release")

    if route:
        command.extend(["--route", route])
    if no_pub:
        command.append("--no-pub")
    if extra_args:
        command.extend(extra_args)

    return command


def session_error_message(message: str, session: FlutterMachineSession | None = None) -> str:
    lines = [message]
    if session is not None:
        lines.append("")
        lines.append(format_startup_summary(session))
    return "\n".join(lines)


@mcp.tool()
def flutter_list_devices(project_root: str | None = None, timeout_seconds: int = 60) -> str:
    """List available Flutter devices using the Flutter machine interface."""
    working_directory = resolve_working_directory(project_root)
    command = [resolve_flutter_command(), "devices", "--machine"]
    return run_command(command, working_directory, timeout_seconds)


@mcp.tool()
def flutter_run_start(
    device_id: str,
    target: str = "lib/main.dart",
    project_root: str | None = None,
    build_mode: str = "debug",
    route: str | None = None,
    no_pub: bool = False,
    start_paused: bool = False,
    replace_existing: bool = False,
    startup_timeout_seconds: int = DEFAULT_STARTUP_TIMEOUT_SECONDS,
    extra_args: list[str] | None = None,
) -> str:
    """Start flutter run --machine as a persistent runtime session."""
    working_directory = resolve_working_directory(project_root)

    existing = get_session(working_directory)
    if existing is not None and existing.is_running():
        if not replace_existing:
            return session_error_message(
                "A Flutter runtime session is already active for this workspace. Set replace_existing=true or stop the session first.",
                existing,
            )
        existing.graceful_stop()
        remove_session(working_directory, existing)

    command = build_run_command(device_id, target, build_mode, route, no_pub, extra_args)
    if start_paused:
        command.append("--start-paused")

    process = subprocess.Popen(  # noqa: S603
        command,
        cwd=working_directory,
        stdin=subprocess.PIPE,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        text=True,
        encoding="utf-8",
        errors="replace",
        bufsize=1,
    )

    session = FlutterMachineSession(
        workspace_root=working_directory,
        device_id=device_id,
        target=target,
        build_mode=build_mode.strip().lower(),
        route=route,
        no_pub=no_pub,
        extra_args=list(extra_args or []),
        command=command,
        process=process,
    )
    store_session(working_directory, session)
    session.start_reader_threads()

    started = session.wait_for_started(startup_timeout_seconds)
    if not started and session.process.poll() is not None:
        session.exit_code = session.process.returncode
        remove_session(working_directory, session)
        return session_error_message(
            f"Flutter run exited before reporting app.started. Exit code: {session.exit_code}",
            session,
        )

    note = None
    if not started:
        note = f"Startup is still in progress after {startup_timeout_seconds} seconds."

    return format_startup_summary(session, note=note)


@mcp.tool()
def flutter_session_status(project_root: str | None = None, tail_lines: int = 50) -> str:
    """Return the current runtime session status and a recent transcript excerpt."""
    working_directory = resolve_working_directory(project_root)
    session = get_session(working_directory)
    if session is None:
        return f"No active Flutter runtime session for {working_directory}."

    summary = format_startup_summary(session, include_transcript=False)
    if tail_lines > 0:
        transcript = session.transcript_tail(tail_lines)
        if transcript:
            summary += "\n\nRecent output:\n" + "\n".join(transcript)
    return summary


@mcp.tool()
def flutter_hot_reload(
    project_root: str | None = None,
    reason: str = "manual",
    timeout_seconds: int = 60,
) -> str:
    """Send app.restart with a hot reload request to the active Flutter session."""
    working_directory = resolve_working_directory(project_root)
    session = get_session(working_directory)
    if session is None:
        return f"No active Flutter runtime session for {working_directory}. Start one first with flutter_run_start."
    if session.build_mode != "debug":
        return session_error_message(
            f"Hot reload is only supported in debug mode. Current mode: {session.build_mode}",
            session,
        )
    if session.app_id is None:
        return session_error_message("The running app has not reported an appId yet.", session)

    response = session.send_request(
        "app.restart",
        {"appId": session.app_id, "fullRestart": False, "reason": reason, "pause": False},
        timeout_seconds=timeout_seconds,
    )
    result_block = format_response_value(response)
    recent_output = session.transcript_tail(15)
    output = [
        "Hot reload request completed.",
        f"App id: {session.app_id}",
        "",
        f"Response:\n{result_block}",
    ]
    if recent_output:
        output.extend(["", "Recent output:"])
        output.extend(recent_output)
    return "\n".join(output)


@mcp.tool()
def flutter_hot_restart(
    project_root: str | None = None,
    reason: str = "manual",
    pause: bool = False,
    timeout_seconds: int = 60,
) -> str:
    """Send app.restart with a full restart request to the active Flutter session."""
    working_directory = resolve_working_directory(project_root)
    session = get_session(working_directory)
    if session is None:
        return f"No active Flutter runtime session for {working_directory}. Start one first with flutter_run_start."
    if session.build_mode != "debug":
        return session_error_message(
            f"Hot restart is only supported in debug mode. Current mode: {session.build_mode}",
            session,
        )
    if session.app_id is None:
        return session_error_message("The running app has not reported an appId yet.", session)

    response = session.send_request(
        "app.restart",
        {"appId": session.app_id, "fullRestart": True, "reason": reason, "pause": pause},
        timeout_seconds=timeout_seconds,
    )
    result_block = format_response_value(response)
    recent_output = session.transcript_tail(15)
    output = [
        "Hot restart request completed.",
        f"App id: {session.app_id}",
        "",
        f"Response:\n{result_block}",
    ]
    if recent_output:
        output.extend(["", "Recent output:"])
        output.extend(recent_output)
    return "\n".join(output)


@mcp.tool()
def flutter_call_service_extension(
    method_name: str,
    project_root: str | None = None,
    params_json: str | None = None,
    timeout_seconds: int = 60,
) -> str:
    """Call a Flutter service extension through app.callServiceExtension."""
    session_context = get_workspace_session(project_root)
    if isinstance(session_context, str):
        return session_context

    working_directory, session = session_context

    params: dict[str, Any] | None = None
    if params_json:
        try:
            parsed = json.loads(params_json)
        except json.JSONDecodeError as error:
            return session_error_message(f"params_json is not valid JSON: {error}", session)
        if not isinstance(parsed, dict):
            return session_error_message("params_json must decode to a JSON object.", session)
        params = parsed

        response = call_flutter_service_extension(session, method_name, params, timeout_seconds=timeout_seconds)
        return format_json_tool_output(
            f"Service extension request completed: {method_name}",
            working_directory,
            session,
            service_response_payload(response),
            recent_lines=15,
        )

    response = call_flutter_service_extension(session, method_name, params, timeout_seconds=timeout_seconds)
    return format_json_tool_output(
        f"Service extension request completed: {method_name}",
        working_directory,
        session,
        service_response_payload(response),
        recent_lines=15,
    )


    @mcp.tool()
    def flutter_debug_dump_app(
        project_root: str | None = None,
        timeout_seconds: int = 60,
        output_path: str | None = None,
    ) -> str:
        """Dump the app widget tree using ext.flutter.debugDumpApp."""
        session_context = get_workspace_session(project_root)
        if isinstance(session_context, str):
            return session_context

        working_directory, session = session_context
        response = call_flutter_service_extension(session, "ext.flutter.debugDumpApp", {}, timeout_seconds=timeout_seconds)
        return format_text_tool_output(
            "Flutter debug dump app",
            working_directory,
            session,
            service_response_payload(response),
            output_path=output_path,
            recent_lines=15,
        )


    @mcp.tool()
    def flutter_debug_dump_render_tree(
        project_root: str | None = None,
        timeout_seconds: int = 60,
        output_path: str | None = None,
    ) -> str:
        """Dump the render tree using ext.flutter.debugDumpRenderTree."""
        session_context = get_workspace_session(project_root)
        if isinstance(session_context, str):
            return session_context

        working_directory, session = session_context
        response = call_flutter_service_extension(session, "ext.flutter.debugDumpRenderTree", {}, timeout_seconds=timeout_seconds)
        return format_text_tool_output(
            "Flutter debug dump render tree",
            working_directory,
            session,
            service_response_payload(response),
            output_path=output_path,
            recent_lines=15,
        )


    @mcp.tool()
    def flutter_debug_dump_focus_tree(
        project_root: str | None = None,
        timeout_seconds: int = 60,
        output_path: str | None = None,
    ) -> str:
        """Dump the focus tree using ext.flutter.debugDumpFocusTree."""
        session_context = get_workspace_session(project_root)
        if isinstance(session_context, str):
            return session_context

        working_directory, session = session_context
        response = call_flutter_service_extension(session, "ext.flutter.debugDumpFocusTree", {}, timeout_seconds=timeout_seconds)
        return format_text_tool_output(
            "Flutter debug dump focus tree",
            working_directory,
            session,
            service_response_payload(response),
            output_path=output_path,
            recent_lines=15,
        )


    @mcp.tool()
    def flutter_debug_dump_layer_tree(
        project_root: str | None = None,
        timeout_seconds: int = 60,
        output_path: str | None = None,
    ) -> str:
        """Dump the layer tree using ext.flutter.debugDumpLayerTree."""
        session_context = get_workspace_session(project_root)
        if isinstance(session_context, str):
            return session_context

        working_directory, session = session_context
        response = call_flutter_service_extension(session, "ext.flutter.debugDumpLayerTree", {}, timeout_seconds=timeout_seconds)
        return format_text_tool_output(
            "Flutter debug dump layer tree",
            working_directory,
            session,
            service_response_payload(response),
            output_path=output_path,
            recent_lines=15,
        )


    @mcp.tool()
    def flutter_debug_dump_semantics_tree(
        project_root: str | None = None,
        inverse_hit_test_order: bool = False,
        timeout_seconds: int = 60,
        output_path: str | None = None,
    ) -> str:
        """Dump the semantics tree in traversal or inverse hit test order."""
        session_context = get_workspace_session(project_root)
        if isinstance(session_context, str):
            return session_context

        working_directory, session = session_context
        method_name = (
            "ext.flutter.debugDumpSemanticsTreeInInverseHitTestOrder"
            if inverse_hit_test_order
            else "ext.flutter.debugDumpSemanticsTreeInTraversalOrder"
        )
        response = call_flutter_service_extension(session, method_name, {}, timeout_seconds=timeout_seconds)
        return format_text_tool_output(
            "Flutter debug dump semantics tree",
            working_directory,
            session,
            service_response_payload(response),
            output_path=output_path,
            recent_lines=15,
        )


    @mcp.tool()
    def flutter_widget_creation_tracked(
        project_root: str | None = None,
        timeout_seconds: int = 60,
    ) -> str:
        """Check whether widget creation locations are being tracked."""
        session_context = get_workspace_session(project_root)
        if isinstance(session_context, str):
            return session_context

        working_directory, session = session_context
        response = call_flutter_service_extension(session, "ext.flutter.inspector.isWidgetCreationTracked", {}, timeout_seconds=timeout_seconds)
        return format_json_tool_output(
            "Flutter widget creation tracking status",
            working_directory,
            session,
            service_response_payload(response),
            recent_lines=10,
            max_chars=4000,
        )


    @mcp.tool()
    def flutter_widget_pub_roots_get(
        project_root: str | None = None,
        timeout_seconds: int = 60,
    ) -> str:
        """Read the active pub root directories used by the widget inspector."""
        session_context = get_workspace_session(project_root)
        if isinstance(session_context, str):
            return session_context

        working_directory, session = session_context
        response = call_flutter_service_extension(session, "ext.flutter.inspector.getPubRootDirectories", {}, timeout_seconds=timeout_seconds)
        return format_json_tool_output(
            "Flutter widget inspector pub root directories",
            working_directory,
            session,
            service_response_payload(response),
            recent_lines=10,
            max_chars=12000,
        )


    @mcp.tool()
    def flutter_widget_pub_roots_set(
        directories: list[str],
        project_root: str | None = None,
        timeout_seconds: int = 60,
    ) -> str:
        """Replace the widget inspector pub root directories with the provided list."""
        session_context = get_workspace_session(project_root)
        if isinstance(session_context, str):
            return session_context

        working_directory, session = session_context
        response = call_flutter_service_extension(
            session,
            "ext.flutter.inspector.setPubRootDirectories",
            build_vararg_params(directories),
            timeout_seconds=timeout_seconds,
        )
        return format_json_tool_output(
            "Flutter widget inspector pub root directories updated",
            working_directory,
            session,
            service_response_payload(response),
            recent_lines=10,
            max_chars=4000,
        )


    @mcp.tool()
    def flutter_widget_pub_roots_add(
        directories: list[str],
        project_root: str | None = None,
        timeout_seconds: int = 60,
    ) -> str:
        """Add one or more pub root directories to the widget inspector."""
        session_context = get_workspace_session(project_root)
        if isinstance(session_context, str):
            return session_context

        working_directory, session = session_context
        response = call_flutter_service_extension(
            session,
            "ext.flutter.inspector.addPubRootDirectories",
            build_vararg_params(directories),
            timeout_seconds=timeout_seconds,
        )
        return format_json_tool_output(
            "Flutter widget inspector pub root directories added",
            working_directory,
            session,
            service_response_payload(response),
            recent_lines=10,
            max_chars=4000,
        )


    @mcp.tool()
    def flutter_widget_pub_roots_remove(
        directories: list[str],
        project_root: str | None = None,
        timeout_seconds: int = 60,
    ) -> str:
        """Remove one or more pub root directories from the widget inspector."""
        session_context = get_workspace_session(project_root)
        if isinstance(session_context, str):
            return session_context

        working_directory, session = session_context
        response = call_flutter_service_extension(
            session,
            "ext.flutter.inspector.removePubRootDirectories",
            build_vararg_params(directories),
            timeout_seconds=timeout_seconds,
        )
        return format_json_tool_output(
            "Flutter widget inspector pub root directories removed",
            working_directory,
            session,
            service_response_payload(response),
            recent_lines=10,
            max_chars=4000,
        )


    @mcp.tool()
    def flutter_widget_location_id_map(
        project_root: str | None = None,
        timeout_seconds: int = 60,
        output_path: str | None = None,
    ) -> str:
        """Return the widget creation location to id map used by the inspector."""
        session_context = get_workspace_session(project_root)
        if isinstance(session_context, str):
            return session_context

        working_directory, session = session_context
        response = call_flutter_service_extension(session, "ext.flutter.inspector.widgetLocationIdMap", {}, timeout_seconds=timeout_seconds)
        return format_json_tool_output(
            "Flutter widget location id map",
            working_directory,
            session,
            service_response_payload(response),
            output_path=output_path,
            recent_lines=10,
            max_chars=20000,
        )


    @mcp.tool()
    def flutter_widget_root_tree(
        project_root: str | None = None,
        object_group: str = "cline-inspector",
        summary_tree: bool = True,
        with_previews: bool = True,
        full_details: bool = False,
        timeout_seconds: int = 60,
        output_path: str | None = None,
    ) -> str:
        """Inspect the root widget tree or summary tree for the active app."""
        session_context = get_workspace_session(project_root)
        if isinstance(session_context, str):
            return session_context

        working_directory, session = session_context
        params = {
            "groupName": object_group,
            "isSummaryTree": bool_string(summary_tree),
            "withPreviews": bool_string(with_previews),
            "fullDetails": bool_string(full_details),
        }
        response = call_flutter_service_extension(session, "ext.flutter.inspector.getRootWidgetTree", params, timeout_seconds=timeout_seconds)
        return format_json_tool_output(
            "Flutter widget root tree",
            working_directory,
            session,
            service_response_payload(response),
            output_path=output_path,
            recent_lines=15,
            max_chars=20000,
        )


    @mcp.tool()
    def flutter_widget_selected_widget(
        project_root: str | None = None,
        object_group: str = "cline-inspector",
        summary_tree: bool = False,
        previous_selection_id: str | None = None,
        timeout_seconds: int = 60,
        output_path: str | None = None,
    ) -> str:
        """Inspect the currently selected widget or the nearest summary-tree ancestor."""
        session_context = get_workspace_session(project_root)
        if isinstance(session_context, str):
            return session_context

        working_directory, session = session_context
        method_name = (
            "ext.flutter.inspector.getSelectedSummaryWidget" if summary_tree else "ext.flutter.inspector.getSelectedWidget"
        )
        params: dict[str, Any] = {"objectGroup": object_group}
        if previous_selection_id is not None:
            params["arg"] = previous_selection_id
        response = call_flutter_service_extension(session, method_name, params, timeout_seconds=timeout_seconds)
        return format_json_tool_output(
            "Flutter selected widget",
            working_directory,
            session,
            service_response_payload(response),
            output_path=output_path,
            recent_lines=15,
            max_chars=20000,
        )


    @mcp.tool()
    def flutter_widget_set_selection_by_id(
        object_id: str,
        project_root: str | None = None,
        timeout_seconds: int = 60,
    ) -> str:
        """Set the widget inspector selection to a specific inspector object id."""
        session_context = get_workspace_session(project_root)
        if isinstance(session_context, str):
            return session_context

        working_directory, session = session_context
        response = call_flutter_service_extension(
            session,
            "ext.flutter.inspector.setSelectionById",
            {"arg": object_id},
            timeout_seconds=timeout_seconds,
        )
        return format_json_tool_output(
            "Flutter widget selection updated",
            working_directory,
            session,
            service_response_payload(response),
            recent_lines=10,
            max_chars=4000,
        )


    @mcp.tool()
    def flutter_widget_parent_chain(
        object_id: str,
        project_root: str | None = None,
        object_group: str = "cline-inspector",
        timeout_seconds: int = 60,
        output_path: str | None = None,
    ) -> str:
        """Inspect the parent chain for an inspector object id."""
        session_context = get_workspace_session(project_root)
        if isinstance(session_context, str):
            return session_context

        working_directory, session = session_context
        response = call_flutter_service_extension(
            session,
            "ext.flutter.inspector.getParentChain",
            {"arg": object_id, "objectGroup": object_group},
            timeout_seconds=timeout_seconds,
        )
        return format_json_tool_output(
            "Flutter widget parent chain",
            working_directory,
            session,
            service_response_payload(response),
            output_path=output_path,
            recent_lines=15,
            max_chars=20000,
        )


    @mcp.tool()
    def flutter_widget_properties(
        object_id: str,
        project_root: str | None = None,
        object_group: str = "cline-inspector",
        timeout_seconds: int = 60,
        output_path: str | None = None,
    ) -> str:
        """Inspect the diagnostic properties for an inspector object id."""
        session_context = get_workspace_session(project_root)
        if isinstance(session_context, str):
            return session_context

        working_directory, session = session_context
        response = call_flutter_service_extension(
            session,
            "ext.flutter.inspector.getProperties",
            {"arg": object_id, "objectGroup": object_group},
            timeout_seconds=timeout_seconds,
        )
        return format_json_tool_output(
            "Flutter widget properties",
            working_directory,
            session,
            service_response_payload(response),
            output_path=output_path,
            recent_lines=15,
            max_chars=20000,
        )


    @mcp.tool()
    def flutter_widget_children(
        object_id: str,
        project_root: str | None = None,
        object_group: str = "cline-inspector",
        timeout_seconds: int = 60,
        output_path: str | None = None,
    ) -> str:
        """Inspect the children for an inspector object id."""
        session_context = get_workspace_session(project_root)
        if isinstance(session_context, str):
            return session_context

        working_directory, session = session_context
        response = call_flutter_service_extension(
            session,
            "ext.flutter.inspector.getChildren",
            {"arg": object_id, "objectGroup": object_group},
            timeout_seconds=timeout_seconds,
        )
        return format_json_tool_output(
            "Flutter widget children",
            working_directory,
            session,
            service_response_payload(response),
            output_path=output_path,
            recent_lines=15,
            max_chars=20000,
        )


    @mcp.tool()
    def flutter_widget_children_summary_tree(
        object_id: str,
        project_root: str | None = None,
        object_group: str = "cline-inspector",
        timeout_seconds: int = 60,
        output_path: str | None = None,
    ) -> str:
        """Inspect the summary-tree children for an inspector object id."""
        session_context = get_workspace_session(project_root)
        if isinstance(session_context, str):
            return session_context

        working_directory, session = session_context
        response = call_flutter_service_extension(
            session,
            "ext.flutter.inspector.getChildrenSummaryTree",
            {"arg": object_id, "objectGroup": object_group},
            timeout_seconds=timeout_seconds,
        )
        return format_json_tool_output(
            "Flutter widget children summary tree",
            working_directory,
            session,
            service_response_payload(response),
            output_path=output_path,
            recent_lines=15,
            max_chars=20000,
        )


    @mcp.tool()
    def flutter_widget_children_details_subtree(
        object_id: str,
        project_root: str | None = None,
        object_group: str = "cline-inspector",
        subtree_depth: int = 2,
        timeout_seconds: int = 60,
        output_path: str | None = None,
    ) -> str:
        """Inspect the children details subtree for an inspector object id."""
        session_context = get_workspace_session(project_root)
        if isinstance(session_context, str):
            return session_context

        working_directory, session = session_context
        response = call_flutter_service_extension(
            session,
            "ext.flutter.inspector.getChildrenDetailsSubtree",
            {"arg": object_id, "objectGroup": object_group, "subtreeDepth": str(subtree_depth)},
            timeout_seconds=timeout_seconds,
        )
        return format_json_tool_output(
            "Flutter widget children details subtree",
            working_directory,
            session,
            service_response_payload(response),
            output_path=output_path,
            recent_lines=15,
            max_chars=20000,
        )


    @mcp.tool()
    def flutter_widget_details_subtree(
        object_id: str,
        project_root: str | None = None,
        object_group: str = "cline-inspector",
        subtree_depth: int = 2,
        timeout_seconds: int = 60,
        output_path: str | None = None,
    ) -> str:
        """Inspect the detailed subtree rooted at an inspector object id."""
        session_context = get_workspace_session(project_root)
        if isinstance(session_context, str):
            return session_context

        working_directory, session = session_context
        response = call_flutter_service_extension(
            session,
            "ext.flutter.inspector.getDetailsSubtree",
            {"arg": object_id, "objectGroup": object_group, "subtreeDepth": str(subtree_depth)},
            timeout_seconds=timeout_seconds,
        )
        return format_json_tool_output(
            "Flutter widget details subtree",
            working_directory,
            session,
            service_response_payload(response),
            output_path=output_path,
            recent_lines=15,
            max_chars=20000,
        )


    @mcp.tool()
    def flutter_widget_layout_explorer_node(
        object_id: str,
        project_root: str | None = None,
        object_group: str = "cline-inspector",
        subtree_depth: int = 1,
        timeout_seconds: int = 60,
        output_path: str | None = None,
    ) -> str:
        """Inspect layout explorer data for an inspector object id."""
        session_context = get_workspace_session(project_root)
        if isinstance(session_context, str):
            return session_context

        working_directory, session = session_context
        response = call_flutter_service_extension(
            session,
            "ext.flutter.inspector.getLayoutExplorerNode",
            {"id": object_id, "groupName": object_group, "subtreeDepth": str(subtree_depth)},
            timeout_seconds=timeout_seconds,
        )
        return format_json_tool_output(
            "Flutter widget layout explorer node",
            working_directory,
            session,
            service_response_payload(response),
            output_path=output_path,
            recent_lines=15,
            max_chars=20000,
        )


    @mcp.tool()
    def flutter_widget_screenshot(
        project_root: str | None = None,
        object_id: str | None = None,
        object_group: str = "cline-inspector",
        summary_tree: bool = False,
        width: float = 1080.0,
        height: float = 1920.0,
        margin: float = 0.0,
        max_pixel_ratio: float = 2.0,
        debug_paint: bool = False,
        output_path: str | None = None,
        timeout_seconds: int = 60,
    ) -> str:
        """Capture a PNG screenshot of the selected widget or a specific inspector id."""
        session_context = get_workspace_session(project_root)
        if isinstance(session_context, str):
            return session_context

        working_directory, session = session_context

        resolved_object_id = object_id
        if resolved_object_id is None:
            selection_method = (
                "ext.flutter.inspector.getSelectedSummaryWidget" if summary_tree else "ext.flutter.inspector.getSelectedWidget"
            )
            selection_response = call_flutter_service_extension(
                session,
                selection_method,
                {"objectGroup": object_group},
                timeout_seconds=timeout_seconds,
            )
            selection_payload = service_response_payload(selection_response)
            if not isinstance(selection_payload, dict):
                return format_json_tool_output(
                    "Flutter widget screenshot failed",
                    working_directory,
                    session,
                    selection_payload,
                    recent_lines=15,
                    max_chars=12000,
                )
            maybe_id = selection_payload.get("valueId")
            if not isinstance(maybe_id, str) or not maybe_id:
                return format_json_tool_output(
                    "Flutter widget screenshot failed",
                    working_directory,
                    session,
                    selection_payload,
                    recent_lines=15,
                    max_chars=12000,
                )
            resolved_object_id = maybe_id

        response = call_flutter_service_extension(
            session,
            "ext.flutter.inspector.screenshot",
            {
                "id": resolved_object_id,
                "width": str(width),
                "height": str(height),
                "margin": str(margin),
                "maxPixelRatio": str(max_pixel_ratio),
                "debugPaint": bool_string(debug_paint),
            },
            timeout_seconds=timeout_seconds,
        )
        payload = service_response_payload(response)
        if not isinstance(payload, str):
            return format_json_tool_output(
                "Flutter widget screenshot failed",
                working_directory,
                session,
                payload,
                recent_lines=15,
                max_chars=12000,
            )

        png_bytes = base64.b64decode(payload)
        screenshot_path = resolve_screenshot_path(working_directory, resolved_object_id, output_path)
        screenshot_path.write_bytes(png_bytes)

        lines = [
            "Flutter widget screenshot captured",
            f"Workspace root: {working_directory}",
            f"App id: {session.app_id if session.app_id is not None else 'unknown'}",
            f"Object id: {resolved_object_id}",
            f"Saved to: {screenshot_path}",
            f"PNG bytes: {len(png_bytes)}",
            f"Capture size: {width} x {height}",
            f"Margin: {margin}",
            f"Max pixel ratio: {max_pixel_ratio}",
            f"Debug paint: {'yes' if debug_paint else 'no'}",
        ]
        recent_output = session.transcript_tail(15)
        if recent_output:
            lines.extend(["", "Recent output:"])
            lines.extend(recent_output)
        return "\n".join(lines)


@mcp.tool()
def flutter_stop(
    project_root: str | None = None,
    timeout_seconds: int = DEFAULT_STOP_TIMEOUT_SECONDS,
) -> str:
    """Stop the active Flutter runtime session and the running app."""
    working_directory = resolve_working_directory(project_root)
    session = get_session(working_directory)
    if session is None:
        return f"No active Flutter runtime session for {working_directory}."

    summary = session.graceful_stop(timeout_seconds=timeout_seconds)
    remove_session(working_directory, session)
    return summary


@mcp.tool()
def flutter_detach(
    project_root: str | None = None,
    timeout_seconds: int = DEFAULT_STOP_TIMEOUT_SECONDS,
) -> str:
    """Detach from the running app without stopping it."""
    working_directory = resolve_working_directory(project_root)
    session = get_session(working_directory)
    if session is None:
        return f"No active Flutter runtime session for {working_directory}."

    summary = session.detach(timeout_seconds=timeout_seconds)
    remove_session(working_directory, session)
    return summary


def invoke_json_service_extension(
    project_root: str | None,
    method_name: str,
    params: dict[str, Any] | None,
    title: str,
    timeout_seconds: int = 60,
    output_path: str | None = None,
    recent_lines: int = 15,
    max_chars: int = 20000,
) -> str:
    session_context = get_workspace_session(project_root)
    if isinstance(session_context, str):
        return session_context

    working_directory, session = session_context
    response = call_flutter_service_extension(session, method_name, params, timeout_seconds=timeout_seconds)
    return format_json_tool_output(
        title,
        working_directory,
        session,
        service_response_payload(response),
        output_path=output_path,
        recent_lines=recent_lines,
        max_chars=max_chars,
    )


def invoke_text_service_extension(
    project_root: str | None,
    method_name: str,
    params: dict[str, Any] | None,
    title: str,
    timeout_seconds: int = 60,
    output_path: str | None = None,
    recent_lines: int = 15,
    max_chars: int = 20000,
) -> str:
    session_context = get_workspace_session(project_root)
    if isinstance(session_context, str):
        return session_context

    working_directory, session = session_context
    response = call_flutter_service_extension(session, method_name, params, timeout_seconds=timeout_seconds)
    return format_text_tool_output(
        title,
        working_directory,
        session,
        service_response_payload(response),
        output_path=output_path,
        recent_lines=recent_lines,
        max_chars=max_chars,
    )


def resolve_selected_widget_value_id(
    session: FlutterMachineSession,
    object_group: str,
    summary_tree: bool,
    timeout_seconds: int,
) -> tuple[str | None, Any]:
    method_name = (
        "ext.flutter.inspector.getSelectedSummaryWidget" if summary_tree else "ext.flutter.inspector.getSelectedWidget"
    )
    response = call_flutter_service_extension(
        session,
        method_name,
        {"objectGroup": object_group},
        timeout_seconds=timeout_seconds,
    )
    payload = service_response_payload(response)
    if isinstance(payload, dict):
        value_id = payload.get("valueId")
        if isinstance(value_id, str) and value_id:
            return value_id, payload
    return None, payload


@mcp.tool()
def flutter_debug_dump_app(
    project_root: str | None = None,
    timeout_seconds: int = 60,
    output_path: str | None = None,
) -> str:
    """Dump the app widget tree using ext.flutter.debugDumpApp."""
    return invoke_text_service_extension(
        project_root,
        "ext.flutter.debugDumpApp",
        {},
        "Flutter debug dump app",
        timeout_seconds=timeout_seconds,
        output_path=output_path,
    )


@mcp.tool()
def flutter_debug_dump_render_tree(
    project_root: str | None = None,
    timeout_seconds: int = 60,
    output_path: str | None = None,
) -> str:
    """Dump the render tree using ext.flutter.debugDumpRenderTree."""
    return invoke_text_service_extension(
        project_root,
        "ext.flutter.debugDumpRenderTree",
        {},
        "Flutter debug dump render tree",
        timeout_seconds=timeout_seconds,
        output_path=output_path,
    )


@mcp.tool()
def flutter_debug_dump_focus_tree(
    project_root: str | None = None,
    timeout_seconds: int = 60,
    output_path: str | None = None,
) -> str:
    """Dump the focus tree using ext.flutter.debugDumpFocusTree."""
    return invoke_text_service_extension(
        project_root,
        "ext.flutter.debugDumpFocusTree",
        {},
        "Flutter debug dump focus tree",
        timeout_seconds=timeout_seconds,
        output_path=output_path,
    )


@mcp.tool()
def flutter_debug_dump_layer_tree(
    project_root: str | None = None,
    timeout_seconds: int = 60,
    output_path: str | None = None,
) -> str:
    """Dump the layer tree using ext.flutter.debugDumpLayerTree."""
    return invoke_text_service_extension(
        project_root,
        "ext.flutter.debugDumpLayerTree",
        {},
        "Flutter debug dump layer tree",
        timeout_seconds=timeout_seconds,
        output_path=output_path,
    )


@mcp.tool()
def flutter_debug_dump_semantics_tree(
    project_root: str | None = None,
    inverse_hit_test_order: bool = False,
    timeout_seconds: int = 60,
    output_path: str | None = None,
) -> str:
    """Dump the semantics tree in traversal or inverse hit test order."""
    method_name = (
        "ext.flutter.debugDumpSemanticsTreeInInverseHitTestOrder"
        if inverse_hit_test_order
        else "ext.flutter.debugDumpSemanticsTreeInTraversalOrder"
    )
    return invoke_text_service_extension(
        project_root,
        method_name,
        {},
        "Flutter debug dump semantics tree",
        timeout_seconds=timeout_seconds,
        output_path=output_path,
    )


@mcp.tool()
def flutter_widget_creation_tracked(
    project_root: str | None = None,
    timeout_seconds: int = 60,
) -> str:
    """Check whether widget creation locations are being tracked."""
    return invoke_json_service_extension(
        project_root,
        "ext.flutter.inspector.isWidgetCreationTracked",
        {},
        "Flutter widget creation tracking status",
        timeout_seconds=timeout_seconds,
        max_chars=4000,
        recent_lines=10,
    )


@mcp.tool()
def flutter_widget_pub_roots_get(
    project_root: str | None = None,
    timeout_seconds: int = 60,
) -> str:
    """Read the active pub root directories used by the widget inspector."""
    return invoke_json_service_extension(
        project_root,
        "ext.flutter.inspector.getPubRootDirectories",
        {},
        "Flutter widget inspector pub root directories",
        timeout_seconds=timeout_seconds,
        max_chars=12000,
        recent_lines=10,
    )


@mcp.tool()
def flutter_widget_pub_roots_set(
    directories: list[str],
    project_root: str | None = None,
    timeout_seconds: int = 60,
) -> str:
    """Replace the widget inspector pub root directories with the provided list."""
    return invoke_json_service_extension(
        project_root,
        "ext.flutter.inspector.setPubRootDirectories",
        build_vararg_params(directories),
        "Flutter widget inspector pub root directories updated",
        timeout_seconds=timeout_seconds,
        max_chars=4000,
        recent_lines=10,
    )


@mcp.tool()
def flutter_widget_pub_roots_add(
    directories: list[str],
    project_root: str | None = None,
    timeout_seconds: int = 60,
) -> str:
    """Add one or more pub root directories to the widget inspector."""
    return invoke_json_service_extension(
        project_root,
        "ext.flutter.inspector.addPubRootDirectories",
        build_vararg_params(directories),
        "Flutter widget inspector pub root directories added",
        timeout_seconds=timeout_seconds,
        max_chars=4000,
        recent_lines=10,
    )


@mcp.tool()
def flutter_widget_pub_roots_remove(
    directories: list[str],
    project_root: str | None = None,
    timeout_seconds: int = 60,
) -> str:
    """Remove one or more pub root directories from the widget inspector."""
    return invoke_json_service_extension(
        project_root,
        "ext.flutter.inspector.removePubRootDirectories",
        build_vararg_params(directories),
        "Flutter widget inspector pub root directories removed",
        timeout_seconds=timeout_seconds,
        max_chars=4000,
        recent_lines=10,
    )


@mcp.tool()
def flutter_widget_location_id_map(
    project_root: str | None = None,
    timeout_seconds: int = 60,
    output_path: str | None = None,
) -> str:
    """Return the widget creation location to id map used by the inspector."""
    return invoke_json_service_extension(
        project_root,
        "ext.flutter.inspector.widgetLocationIdMap",
        {},
        "Flutter widget location id map",
        timeout_seconds=timeout_seconds,
        output_path=output_path,
        recent_lines=10,
        max_chars=20000,
    )


@mcp.tool()
def flutter_widget_root_tree(
    project_root: str | None = None,
    object_group: str = "cline-inspector",
    summary_tree: bool = True,
    with_previews: bool = True,
    full_details: bool = False,
    timeout_seconds: int = 60,
    output_path: str | None = None,
) -> str:
    """Inspect the root widget tree or summary tree for the active app."""
    params = {
        "groupName": object_group,
        "isSummaryTree": bool_string(summary_tree),
        "withPreviews": bool_string(with_previews),
        "fullDetails": bool_string(full_details),
    }
    return invoke_json_service_extension(
        project_root,
        "ext.flutter.inspector.getRootWidgetTree",
        params,
        "Flutter widget root tree",
        timeout_seconds=timeout_seconds,
        output_path=output_path,
        recent_lines=15,
        max_chars=20000,
    )


@mcp.tool()
def flutter_widget_selected_widget(
    project_root: str | None = None,
    object_group: str = "cline-inspector",
    summary_tree: bool = False,
    previous_selection_id: str | None = None,
    timeout_seconds: int = 60,
    output_path: str | None = None,
) -> str:
    """Inspect the currently selected widget or the nearest summary-tree ancestor."""
    session_context = get_workspace_session(project_root)
    if isinstance(session_context, str):
        return session_context

    working_directory, session = session_context
    selected_method = (
        "ext.flutter.inspector.getSelectedSummaryWidget" if summary_tree else "ext.flutter.inspector.getSelectedWidget"
    )
    params: dict[str, Any] = {"objectGroup": object_group}
    if previous_selection_id is not None:
        params["arg"] = previous_selection_id
    response = call_flutter_service_extension(session, selected_method, params, timeout_seconds=timeout_seconds)
    return format_json_tool_output(
        "Flutter selected widget",
        working_directory,
        session,
        service_response_payload(response),
        output_path=output_path,
        recent_lines=15,
        max_chars=20000,
    )


@mcp.tool()
def flutter_widget_set_selection_by_id(
    object_id: str,
    project_root: str | None = None,
    timeout_seconds: int = 60,
) -> str:
    """Set the widget inspector selection to a specific inspector object id."""
    return invoke_json_service_extension(
        project_root,
        "ext.flutter.inspector.setSelectionById",
        {"arg": object_id},
        "Flutter widget selection updated",
        timeout_seconds=timeout_seconds,
        max_chars=4000,
        recent_lines=10,
    )


@mcp.tool()
def flutter_widget_parent_chain(
    object_id: str,
    project_root: str | None = None,
    object_group: str = "cline-inspector",
    timeout_seconds: int = 60,
    output_path: str | None = None,
) -> str:
    """Inspect the parent chain for an inspector object id."""
    return invoke_json_service_extension(
        project_root,
        "ext.flutter.inspector.getParentChain",
        {"arg": object_id, "objectGroup": object_group},
        "Flutter widget parent chain",
        timeout_seconds=timeout_seconds,
        output_path=output_path,
        recent_lines=15,
        max_chars=20000,
    )


@mcp.tool()
def flutter_widget_properties(
    object_id: str,
    project_root: str | None = None,
    object_group: str = "cline-inspector",
    timeout_seconds: int = 60,
    output_path: str | None = None,
) -> str:
    """Inspect the diagnostic properties for an inspector object id."""
    return invoke_json_service_extension(
        project_root,
        "ext.flutter.inspector.getProperties",
        {"arg": object_id, "objectGroup": object_group},
        "Flutter widget properties",
        timeout_seconds=timeout_seconds,
        output_path=output_path,
        recent_lines=15,
        max_chars=20000,
    )


@mcp.tool()
def flutter_widget_children(
    object_id: str,
    project_root: str | None = None,
    object_group: str = "cline-inspector",
    timeout_seconds: int = 60,
    output_path: str | None = None,
) -> str:
    """Inspect the children for an inspector object id."""
    return invoke_json_service_extension(
        project_root,
        "ext.flutter.inspector.getChildren",
        {"arg": object_id, "objectGroup": object_group},
        "Flutter widget children",
        timeout_seconds=timeout_seconds,
        output_path=output_path,
        recent_lines=15,
        max_chars=20000,
    )


@mcp.tool()
def flutter_widget_children_summary_tree(
    object_id: str,
    project_root: str | None = None,
    object_group: str = "cline-inspector",
    timeout_seconds: int = 60,
    output_path: str | None = None,
) -> str:
    """Inspect the summary-tree children for an inspector object id."""
    return invoke_json_service_extension(
        project_root,
        "ext.flutter.inspector.getChildrenSummaryTree",
        {"arg": object_id, "objectGroup": object_group},
        "Flutter widget children summary tree",
        timeout_seconds=timeout_seconds,
        output_path=output_path,
        recent_lines=15,
        max_chars=20000,
    )


@mcp.tool()
def flutter_widget_children_details_subtree(
    object_id: str,
    project_root: str | None = None,
    object_group: str = "cline-inspector",
    subtree_depth: int = 2,
    timeout_seconds: int = 60,
    output_path: str | None = None,
) -> str:
    """Inspect the children details subtree for an inspector object id."""
    return invoke_json_service_extension(
        project_root,
        "ext.flutter.inspector.getChildrenDetailsSubtree",
        {"arg": object_id, "objectGroup": object_group, "subtreeDepth": str(subtree_depth)},
        "Flutter widget children details subtree",
        timeout_seconds=timeout_seconds,
        output_path=output_path,
        recent_lines=15,
        max_chars=20000,
    )


@mcp.tool()
def flutter_widget_details_subtree(
    object_id: str,
    project_root: str | None = None,
    object_group: str = "cline-inspector",
    subtree_depth: int = 2,
    timeout_seconds: int = 60,
    output_path: str | None = None,
) -> str:
    """Inspect the detailed subtree rooted at an inspector object id."""
    return invoke_json_service_extension(
        project_root,
        "ext.flutter.inspector.getDetailsSubtree",
        {"arg": object_id, "objectGroup": object_group, "subtreeDepth": str(subtree_depth)},
        "Flutter widget details subtree",
        timeout_seconds=timeout_seconds,
        output_path=output_path,
        recent_lines=15,
        max_chars=20000,
    )


@mcp.tool()
def flutter_widget_layout_explorer_node(
    object_id: str,
    project_root: str | None = None,
    object_group: str = "cline-inspector",
    subtree_depth: int = 1,
    timeout_seconds: int = 60,
    output_path: str | None = None,
) -> str:
    """Inspect layout explorer data for an inspector object id."""
    return invoke_json_service_extension(
        project_root,
        "ext.flutter.inspector.getLayoutExplorerNode",
        {"id": object_id, "groupName": object_group, "subtreeDepth": str(subtree_depth)},
        "Flutter widget layout explorer node",
        timeout_seconds=timeout_seconds,
        output_path=output_path,
        recent_lines=15,
        max_chars=20000,
    )


@mcp.tool()
def flutter_widget_screenshot(
    project_root: str | None = None,
    object_id: str | None = None,
    object_group: str = "cline-inspector",
    summary_tree: bool = False,
    width: float = 1080.0,
    height: float = 1920.0,
    margin: float = 0.0,
    max_pixel_ratio: float = 2.0,
    debug_paint: bool = False,
    output_path: str | None = None,
    timeout_seconds: int = 60,
) -> str:
    """Capture a PNG screenshot of the selected widget or a specific inspector id."""
    session_context = get_workspace_session(project_root)
    if isinstance(session_context, str):
        return session_context

    working_directory, session = session_context

    resolved_object_id = object_id
    selected_payload: Any = None
    if resolved_object_id is None:
        resolved_object_id, selected_payload = resolve_selected_widget_value_id(
            session,
            object_group=object_group,
            summary_tree=summary_tree,
            timeout_seconds=timeout_seconds,
        )
        if resolved_object_id is None:
            return format_json_tool_output(
                "Flutter widget screenshot failed",
                working_directory,
                session,
                selected_payload,
                recent_lines=15,
                max_chars=12000,
            )

    response = call_flutter_service_extension(
        session,
        "ext.flutter.inspector.screenshot",
        {
            "id": resolved_object_id,
            "width": str(width),
            "height": str(height),
            "margin": str(margin),
            "maxPixelRatio": str(max_pixel_ratio),
            "debugPaint": bool_string(debug_paint),
        },
        timeout_seconds=timeout_seconds,
    )
    payload = service_response_payload(response)
    if not isinstance(payload, str):
        return format_json_tool_output(
            "Flutter widget screenshot failed",
            working_directory,
            session,
            payload,
            recent_lines=15,
            max_chars=12000,
        )

    png_bytes = base64.b64decode(payload)
    screenshot_path = resolve_screenshot_path(working_directory, resolved_object_id, output_path)
    screenshot_path.write_bytes(png_bytes)

    lines = [
        "Flutter widget screenshot captured",
        f"Workspace root: {working_directory}",
        f"App id: {session.app_id if session.app_id is not None else 'unknown'}",
        f"Object id: {resolved_object_id}",
        f"Saved to: {screenshot_path}",
        f"PNG bytes: {len(png_bytes)}",
        f"Capture size: {width} x {height}",
        f"Margin: {margin}",
        f"Max pixel ratio: {max_pixel_ratio}",
        f"Debug paint: {'yes' if debug_paint else 'no'}",
    ]
    recent_output = session.transcript_tail(15)
    if recent_output:
        lines.extend(["", "Recent output:"])
        lines.extend(recent_output)
    return "\n".join(lines)


if __name__ == "__main__":
    mcp.run()