import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:convertisseur_devises/utils/format.dart';
import 'package:convertisseur_devises/widgets/live_clock.dart';

void main() {
  test('date et heure en français', () {
    final d = DateTime(2026, 10, 17, 9, 5, 3);
    expect(formatTime(d), '09:05:03');
    expect(formatLongDate(d), 'Samedi 17 octobre 2026');
    expect(formatLongDate(DateTime(2026, 8, 1)), 'Samedi 1er août 2026');
  });

  testWidgets('l\'heure avance chaque seconde', (tester) async {
    var now = DateTime(2026, 10, 17, 19, 42, 5);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: LiveClock(now: () => now)),
      ),
    );
    expect(find.text('19:42:05'), findsOneWidget);
    expect(find.text('Samedi 17 octobre 2026'), findsOneWidget);

    now = now.add(const Duration(seconds: 1));
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('19:42:06'), findsOneWidget);

    // Le minuteur est arrêté quand l'horloge disparaît.
    await tester.pumpWidget(const SizedBox());
  });
}
