import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:convertisseur_devises/settings/settings_page.dart';
import 'package:convertisseur_devises/settings/theme_controller.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('choisir « Sombre » change et mémorise le thème', (tester) async {
    final theme = ThemeController();
    await tester.pumpWidget(MaterialApp(home: SettingsPage(theme: theme)));

    expect(find.text('Comme le téléphone'), findsOneWidget);
    expect(find.text('Application développée par PyreCore'), findsOneWidget);

    await tester.tap(find.text('Sombre'));
    await tester.pumpAndSettle();
    expect(theme.value, ThemeMode.dark);

    final reloaded = ThemeController();
    await reloaded.load();
    expect(reloaded.value, ThemeMode.dark);
  });
}
