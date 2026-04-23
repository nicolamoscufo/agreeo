# Workspace and Git Guidance

When working in this workspace:

- Use `workspace_find_files` before asking for file paths or guessing where code lives.
- Use `workspace_search_text` when you need to locate symbols, strings, or patterns in the repo.
- Use `workspace_read_file` for exact file inspection when the current editor context is not enough.
- Use `git_status` before review work, `git_diff` after edits, and `git_log` when you need commit context.
- Use `git_blame` when ownership or historical context matters for a specific line.
- Use the Flutter runtime MCP tools to verify live app behavior: `flutter_list_devices`, `flutter_run_start`, `flutter_session_status`, `flutter_hot_reload`, `flutter_hot_restart`, `flutter_call_service_extension`, `flutter_stop`, and `flutter_detach`.
- When a Flutter issue depends on live widget state, use the inspector tools instead of guessing from source alone.
- Prefer a live runtime session over guessing when a change affects widget state, navigation, state restoration, or platform behavior.
- Use the browser MCP tools for live internet pages, search results, and interactive navigation when the answer depends on current web content.
- Prefer these tools over guessing from memory alone.