# Flutter Runtime Guidance

When you need to verify a running Flutter app in this workspace:

- Use `flutter_list_devices` to see the available devices before launching.
- Use `flutter_run_start` to create a persistent `flutter run --machine` session.
- Use `flutter_session_status` to inspect the active session and recent output.
- Use `flutter_hot_reload` for small UI or logic changes that should preserve state.
- Use `flutter_hot_restart` when a full restart is needed to pick up broader code changes.
- Use `flutter_call_service_extension` when you need to talk to a Flutter service extension on the live app.
- Use `flutter_widget_root_tree`, `flutter_widget_selected_widget`, and `flutter_widget_screenshot` when you need live UI or layout context.
- Use `flutter_widget_layout_explorer_node` and `flutter_widget_location_id_map` when source location or layout details matter.
- Use `flutter_stop` when the session is no longer needed.
- Use `flutter_detach` only when the app should keep running after the tool session ends.