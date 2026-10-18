import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:convertisseur_devises/install/install_support.dart';
import 'package:convertisseur_devises/install/install_ui.dart';

Future<void> openHelp(WidgetTester tester, {required bool ios}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Builder(
        builder: (context) => TextButton(
          onPressed: () => showInstallHelp(context, ios: ios),
          child: const Text('ouvrir'),
        ),
      ),
    ),
  );
  await tester.tap(find.text('ouvrir'));
  await tester.pumpAndSettle();
}

void main() {
  test('hors navigateur, rien n\'est proposé', () {
    expect(InstallSupport.available, isFalse);
  });

  testWidgets('bandeau masqué hors navigateur', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: InstallBanner())),
    );
    expect(find.text('Installer MoniFlex'), findsNothing);
  });

  testWidgets('étapes iPhone : menu Partager', (tester) async {
    await openHelp(tester, ios: true);
    expect(find.text('1. Appuie sur Partager'), findsOneWidget);
    expect(find.text('2. Choisis « Sur l\'écran d\'accueil »'), findsOneWidget);
  });

  testWidgets('étapes Android / ordinateur : menu du navigateur', (
    tester,
  ) async {
    await openHelp(tester, ios: false);
    expect(
      find.text('2. Choisis « Installer l\'application »'),
      findsOneWidget,
    );
  });
}
