import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeModeController extends StateNotifier<ThemeMode> {
  ThemeModeController() : super(ThemeMode.system) {
    _load();
  }

  static const String _storageKey = 'agreeo.themeMode';

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final storedValue = prefs.getString(_storageKey);
    final parsedMode = ThemeMode.values.firstWhere(
      (mode) => mode.name == storedValue,
      orElse: () => ThemeMode.system,
    );
    state = parsedMode;
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    state = mode;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_storageKey, mode.name);
  }
}

final themeModeProvider = StateNotifierProvider<ThemeModeController, ThemeMode>(
  (ref) {
    return ThemeModeController();
  },
);
