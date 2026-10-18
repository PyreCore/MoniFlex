import 'package:flutter_test/flutter_test.dart';

import 'package:convertisseur_devises/calculator/calc_input.dart';
import 'package:convertisseur_devises/utils/format.dart';

CalcInput typed(List<String> keys) {
  final c = CalcInput();
  for (final k in keys) {
    c.press(k);
  }
  return c;
}

void main() {
  test('saisie, aperçu et résultat', () {
    final c = typed(['1', '2', '+', '3', '×', '2']);
    expect(c.expression, '12+3×2');
    expect(c.preview, 18);
    c.press('=');
    expect(c.expression, '18');
    expect(c.history, '12+3×2 =');
    expect(c.value, 18);
  });

  test('après « = » : un chiffre recommence, un opérateur enchaîne', () {
    final c = typed(['5', '=']);
    c.press('+');
    c.press('1');
    expect(c.expression, '5+1');
    c.press('=');
    c.press('9');
    expect(c.expression, '9');
    expect(c.history, 'Ans = 6');
  });

  test('opérateurs : remplacement et signe négatif', () {
    expect(typed(['5', '+', '×']).expression, '5×');
    expect(typed(['5', '×', '−', '2']).expression, '5×−2');
    expect(typed(['×']).expression, '');
    expect(typed(['−', '3']).expression, '−3');
  });

  test('virgule, ±, effacement, fonctions', () {
    expect(typed([',', '5']).expression, '0,5');
    expect(typed(['1', ',', '2', ',']).expression, '1,2');
    expect(typed(['5', '−', '3', '±']).expression, '5−(−3');
    expect(typed(['5', '−', '3', '±', '±']).expression, '5−3');
    expect(typed(['2', 'sin', '⌫']).expression, '2');
    expect(typed(['sin', '3', '0', ')', '=']).value, 0.5);
    expect(typed(['DEG', 'sin', 'π', '÷', '2', '=']).value, 1);
    expect(typed([')']).expression, '');
  });

  test('erreur affichée, saisie conservée', () {
    final c = typed(['1', '÷', '0', '=']);
    expect(c.error, 'Division par zéro');
    expect(c.expression, '1÷0');
    c.press('AC');
    expect(c.expression, '');
    expect(c.error, isNull);
  });

  test('résultat envoyé au champ Montant', () {
    expect(amountInputText(1234.5), '1234,5');
    expect(amountInputText(100), '100');
    expect(amountInputText(0.1234567), '0,123457');
  });
}
