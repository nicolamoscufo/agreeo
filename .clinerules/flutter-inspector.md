# Flutter Inspector Guidance

When debugging live Flutter UI problems:

- Use `flutter_widget_root_tree` first to understand the visible tree.
- Use `flutter_widget_selected_widget` when you already know the widget is selected in the inspector.
- Use `flutter_widget_location_id_map` and `flutter_widget_layout_explorer_node` when you need source or layout detail.
- Use `flutter_widget_pub_roots_get`, `flutter_widget_pub_roots_set`, `flutter_widget_pub_roots_add`, and `flutter_widget_pub_roots_remove` when creation locations are missing or misclassified.
- Use `flutter_widget_screenshot` to capture the selected widget or a specific inspector id.
- Use `flutter_debug_dump_render_tree`, `flutter_debug_dump_layer_tree`, and `flutter_debug_dump_semantics_tree` for lower-level UI debugging.
- Use `flutter_call_service_extension` for any inspector service extension that is not wrapped yet.
