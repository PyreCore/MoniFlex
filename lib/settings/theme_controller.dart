import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Thème choisi par l'utilisateur (téléphone, clair ou sombre), mémorisé.
class ThemeController extends ValueNotifier<ThemeMode> {
  static const _key = 'themeMode';

  ThemeController() : super(ThemeMode.system);

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_key);
    value = ThemeMode.values.firstWhere(
      (m) => m.name == saved,
      orElse: () => ThemeMode.system,
    );
  }

  Future<void> set(ThemeMode mode) async {
    value = mode;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, mode.name);
  }
}
