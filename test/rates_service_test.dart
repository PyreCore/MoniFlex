import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:convertisseur_devises/services/rates_service.dart';

String _apiBody(double eur, {int time = 1700000000}) => jsonEncode({
  'result': 'success',
  'base_code': 'USD',
  'time_last_update_unix': time,
  'rates': {'USD': 1, 'EUR': eur, 'XAF': eur * 655.957},
});

final _offline = MockClient(
  (_) async => throw const SocketException('hors ligne'),
);

Future<String> _readAsset(String key) => File(key).readAsString();

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('en ligne : taux téléchargés puis enregistrés', () async {
    final service = RatesService(
      client: MockClient((_) async => http.Response(_apiBody(0.9), 200)),
      loadAsset: _readAsset,
    );
    final rates = await service.fetchRates();
    expect(rates.source, RatesSource.online);
    expect(rates.rates['EUR'], 0.9);

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('rates_cache'), isNotNull);
  });

  test('hors ligne avec cache : derniers taux enregistrés', () async {
    SharedPreferences.setMockInitialValues({'rates_cache': _apiBody(0.8)});
    final service = RatesService(client: _offline, loadAsset: _readAsset);
    final rates = await service.fetchRates();
    expect(rates.source, RatesSource.cache);
    expect(rates.rates['EUR'], 0.8);
  });

  test('hors ligne au premier lancement : taux livrés avec l\'app', () async {
    final service = RatesService(client: _offline, loadAsset: _readAsset);
    final rates = await service.fetchRates();
    expect(rates.source, RatesSource.bundled);
    expect(rates.codes, containsAll(['EUR', 'XAF', 'XOF', 'USD']));
    // Le franc CFA a une parité fixe avec l'euro.
    expect(rates.convert(1, 'EUR', 'XAF'), closeTo(655.957, 0.01));
    expect(rates.convert(1, 'EUR', 'XOF'), closeTo(655.957, 0.01));
  });

  test('erreur serveur sans cache : taux livrés avec l\'app', () async {
    final service = RatesService(
      client: MockClient((_) async => http.Response('oups', 500)),
      loadAsset: _readAsset,
    );
    final rates = await service.fetchRates();
    expect(rates.source, RatesSource.bundled);
  });
}
