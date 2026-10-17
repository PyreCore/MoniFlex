import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:convertisseur_devises/services/history_service.dart';

final _now = DateTime.utc(2026, 10, 17, 12);

/// Simule l'API : EUR vaut 0.90 + 0.01 × (jour d'octobre − 10).
http.Response _fakeApi(http.Request req) {
  final m = RegExp(r'currency-api@([\w-]+)/').firstMatch(req.url.toString());
  if (m == null) return http.Response('', 404);
  final version = m[1]!;
  final date = version == 'latest' ? '2026-10-17' : version;
  final day = DateTime.parse(date).day;
  return http.Response(
    jsonEncode({
      'date': date,
      'usd': {
        'usd': 1,
        'eur': 0.90 + 0.01 * (day - 10),
        'xaf': 655.957 * (0.90 + 0.01 * (day - 10)),
        'btc': 0.00001,
        '1inch': 4,
      },
    }),
    200,
  );
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('7 jours : un point par jour, aujourd\'hui inclus', () async {
    final service = HistoryService(
      client: MockClient((r) async => _fakeApi(r)),
      now: () => _now,
    );
    final history = await service.fetch(7);
    final series = history.series('USD', 'EUR');

    expect(series.length, 8);
    expect(series.first.date, DateTime.utc(2026, 10, 10));
    expect(series.last.date, DateTime.utc(2026, 10, 17));
    expect(series.last.value, closeTo(0.97, 1e-9));
    // Codes non ISO écartés.
    expect(history.days.values.first.keys, isNot(contains('1INCH')));
  });

  test('variations en %', () async {
    final service = HistoryService(
      client: MockClient((r) async => _fakeApi(r)),
      now: () => _now,
    );
    final series = (await service.fetch(7)).series('USD', 'EUR');

    expect(
      RateHistory.lastChange(series),
      closeTo((0.97 - 0.96) / 0.96 * 100, 1e-9),
    );
    expect(
      RateHistory.periodChange(series),
      closeTo((0.97 - 0.90) / 0.90 * 100, 1e-9),
    );
    // Parité fixe : EUR → XAF ne bouge pas.
    final peg = (await service.fetch(7)).series('EUR', 'XAF');
    expect(RateHistory.periodChange(peg), closeTo(0, 1e-9));
  });

  test(
    '90 jours : un point tous les 3 jours, dates stables d\'un jour à l\'autre',
    () async {
      final service = HistoryService(
        client: MockClient((r) async => _fakeApi(r)),
        now: () => _now,
      );
      final dates = (await service.fetch(90)).days.keys.toList();
      expect(dates.length, inInclusiveRange(31, 33));
      // La veille et l'avant-veille sont toujours là (variation sur 24 h).
      expect(dates, contains(DateTime.utc(2026, 10, 16)));
      expect(dates, contains(DateTime.utc(2026, 10, 15)));
      for (final d in dates.where(
        (d) => d.isBefore(DateTime.utc(2026, 10, 15)),
      )) {
        expect(
          (d.millisecondsSinceEpoch ~/ Duration.millisecondsPerDay) % 3,
          0,
        );
      }
    },
  );

  test(
    'les jours passés viennent du cache, seul « latest » est retéléchargé',
    () async {
      var calls = 0;
      final client = MockClient((r) async {
        calls++;
        return _fakeApi(r);
      });
      final service = HistoryService(client: client, now: () => _now);
      await service.fetch(7);
      expect(calls, 8);

      calls = 0;
      await service.fetch(7);
      expect(calls, 1);
    },
  );

  test('« depuis la veille » exige deux jours consécutifs', () {
    final s = [
      RatePoint(DateTime.utc(2026, 10, 14), 1.0),
      RatePoint(DateTime.utc(2026, 10, 17), 1.1),
    ];
    expect(RateHistory.lastChange(s), isNull);
    expect(RateHistory.periodChange(s), closeTo(10, 1e-9));
  });

  test(
    'une réponse illisible ne fait pas échouer tout l\'historique',
    () async {
      final service = HistoryService(
        client: MockClient((r) async {
          if (r.url.toString().contains('2026-10-12')) {
            return http.Response('{pas du json', 200);
          }
          return _fakeApi(r);
        }),
        now: () => _now,
      );
      final dates = (await service.fetch(7)).days.keys;
      expect(dates.length, 7);
      expect(dates, isNot(contains(DateTime.utc(2026, 10, 12))));
    },
  );

  test('hors ligne sans cache : erreur', () async {
    final service = HistoryService(
      client: MockClient(
        (_) async => throw const SocketException('hors ligne'),
      ),
      now: () => _now,
    );
    expect(service.fetch(7), throwsException);
  });
}
