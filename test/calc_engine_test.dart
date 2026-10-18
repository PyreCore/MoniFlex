import 'package:flutter_test/flutter_test.dart';

import 'package:convertisseur_devises/calculator/calc_engine.dart';

void main() {
  double ev(String s, {bool degrees = true, double ans = 0}) =>
      evaluate(s, degrees: degrees, ans: ans);

  test('opérations et priorités', () {
    expect(ev('2+3×4'), 14);
    expect(ev('(2+3)×4'), 20);
    expect(ev('10÷4'), 2.5);
    expect(ev('7−10'), -3);
    expect(ev('−3+5'), 2);
    expect(ev('2,5×2'), 5);
    expect(ev('0,1+0,2'), 0.3);
  });

  test('puissances, racines, postfixes', () {
    expect(ev('2^10'), 1024);
    expect(ev('2^3^2'), 512); // associative à droite
    expect(ev('−2^2'), -4);
    expect(ev('3²'), 9);
    expect(ev('√16+1'), 5);
    expect(ev('√(9+16)'), 5);
    expect(ev('5!'), 120);
    expect(ev('50%×200'), 100);
  });

  test('multiplication implicite et parenthèses non fermées', () {
    expect(ev('2π'), closeTo(6.283185307, 1e-9));
    expect(ev('3(4+1)'), 15);
    expect(ev('(1+2)(3+4)'), 21);
    expect(ev('2×(3+4'), 14);
  });

  test('fonctions, degrés et radians', () {
    expect(ev('sin(30)'), 0.5);
    expect(ev('cos(60)'), 0.5);
    expect(ev('sin(180)'), 0);
    expect(ev('tan(45)'), 1);
    expect(ev('sin(π÷2)', degrees: false), 1);
    expect(ev('ln(e)'), 1);
    expect(ev('log(1000)'), 3);
    expect(ev('2sin(30)'), 1);
  });

  test('constantes et Ans', () {
    expect(ev('Ans×2', ans: 21), 42);
    expect(ev('e'), closeTo(2.718281828, 1e-9));
  });

  test('erreurs claires', () {
    expect(() => ev('1÷0'), throwsA(isA<CalcError>()));
    expect(() => ev('√(−4)'), throwsA(isA<CalcError>()));
    expect(() => ev('tan(90)'), throwsA(isA<CalcError>()));
    expect(() => ev('ln(0)'), throwsA(isA<CalcError>()));
    expect(() => ev('2,5!'), throwsA(isA<CalcError>()));
    expect(() => ev('171!'), throwsA(isA<CalcError>()));
    expect(() => ev('2+'), throwsA(isA<CalcError>()));
    expect(() => ev('2)'), throwsA(isA<CalcError>()));
    expect(() => ev(''), throwsA(isA<CalcError>()));
  });

  test('affichage du résultat', () {
    expect(formatCalc(1234567.5), '1 234 567,5');
    expect(formatCalc(-42), '−42');
    expect(formatCalc(0.3), '0,3');
    expect(formatCalc(1e20), '1e20');
    expect(formatCalc(1.5e-12), '1,5e-12');
  });
}
