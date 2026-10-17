import 'package:flutter_test/flutter_test.dart';

import 'package:convertisseur_devises/services/rates_service.dart';

void main() {
  test('conversion via la devise de base', () {
    final rates = ExchangeRates(
      base: 'USD',
      rates: {'USD': 1, 'EUR': 0.5, 'XAF': 328},
      updatedAt: DateTime(2026),
    );
    expect(rates.convert(10, 'USD', 'EUR'), 5);
    expect(rates.convert(1, 'EUR', 'XAF'), closeTo(656, 0.001));
    expect(rates.convert(1, 'EUR', 'ABC'), 0);
  });
}
