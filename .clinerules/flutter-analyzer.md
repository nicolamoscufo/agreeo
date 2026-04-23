# Flutter Coding Guidance

When working in this workspace:

- Use the `flutter_analyze` MCP tool before assuming Flutter pages are clean.
- Re-run the analyzer after editing Dart or Flutter UI files.
- Use `flutter_test` for behavior or UI changes that should be verified end to end.
- Use `dart_format` on changed Dart files before you finish.
- Prefer analyzer output, test output, and VS Code Problems over guessing from source alone.
- If analyzer or test output shows errors, fix those first and verify again.