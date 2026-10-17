import 'package:flutter_test/flutter_test.dart';

import 'package:convertisseur_devises/data/currencies.dart';
import 'package:convertisseur_devises/utils/format.dart';

void main() {
  test('montants', () {
    expect(formatAmount(0), '0');
    expect(formatAmount(1234567.891), '1 234 567,89');
    expect(formatAmount(0.889517), '0,889517');
    // Très petit montant : plus jamais « 0,000000 ».
    expect(formatAmount(0.0000073123), '0,000007312');
  });

  test('pourcentages signés', () {
    expect(formatPercent(0.4249), '+0,42 %');
    expect(formatPercent(-1.3), '−1,30 %');
    expect(formatPercent(0), '0,00 %');
  });

  test('recherche sans accents', () {
    expect(normalizeSearch('Réal brésilien'), 'real bresilien');
    expect(normalizeSearch('Dông vietnamien'), 'dong vietnamien');
    expect(normalizeSearch('Złoty'), 'złoty');
  });

  test('drapeaux', () {
    expect(currencyFlag('EUR'), '🇪🇺');
    expect(currencyFlag('USD'), '🇺🇸');
    // Devise supranationale sans pays : pas de faux drapeau.
    expect(currencyFlag('XAG'), '🌐');
  });
}
