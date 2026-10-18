import 'dart:math' as math;

/// Erreur de calcul affichée telle quelle (« Division par zéro »…).
class CalcError implements Exception {
  final String message;

  const CalcError(this.message);

  @override
  String toString() => message;
}

/// Fonctions proposées par la calculatrice, écrites « nom( » à l'écran.
const calcFunctions = ['sin', 'cos', 'tan', 'ln', 'log'];

/// Évalue une expression telle qu'affichée par la calculatrice :
/// « 2,5 × (3 + √16) − sin(30) », « 5! », « 2^10 », « 50% », « 2π »…
///
/// Priorités : parenthèses, puis postfixes (², !, %), puissance (associative
/// à droite), signe, × ÷ (et multiplication implicite : 2π, 3(4+1)),
/// puis + −. Les parenthèses non fermées le sont automatiquement.
double evaluate(String expression, {bool degrees = true, double ans = 0}) {
  final parser = _Parser(_tokenize(expression), degrees: degrees, ans: ans);
  final value = parser.parse();
  if (value.isNaN) throw const CalcError('Erreur');
  if (value.isInfinite) throw const CalcError('Résultat trop grand');
  // Supprime le bruit des calculs flottants : sin(180°) → 0, 0,1+0,2 → 0,3.
  return double.parse(value.toStringAsPrecision(12));
}

/// Résultat au format français : « 1 234,5 », « 1,5e-12 ».
String formatCalc(double v) {
  if (v == 0) return '0';
  final abs = v.abs();
  if (abs >= 1e15 || abs < 1e-9) {
    final s = v.toStringAsExponential(8);
    final parts = s.split('e');
    final mantissa = parts[0].contains('.')
        ? parts[0].replaceFirst(RegExp(r'\.?0+$'), '')
        : parts[0];
    return '${mantissa.replaceAll('.', ',')}e${parts[1].replaceAll('+', '')}';
  }
  var s = v.toStringAsPrecision(12);
  if (s.contains('e')) s = v.toStringAsFixed(0);
  if (s.contains('.')) s = s.replaceFirst(RegExp(r'\.?0+$'), '');
  final negative = s.startsWith('-');
  if (negative) s = s.substring(1);
  final parts = s.split('.');
  final intPart = parts[0].replaceAllMapped(
    RegExp(r'(\d)(?=(\d{3})+$)'),
    (m) => '${m[1]} ',
  );
  final out = parts.length > 1 ? '$intPart,${parts[1]}' : intPart;
  return negative ? '−$out' : out;
}

enum _T { number, op, lparen, rparen, func, constant, sqrt, postfix }

class _Token {
  final _T type;
  final String text;
  final double value;

  const _Token(this.type, this.text, [this.value = 0]);
}

List<_Token> _tokenize(String input) {
  final s = input.replaceAll(' ', '');
  final tokens = <_Token>[];
  var i = 0;
  while (i < s.length) {
    final c = s[i];
    if (RegExp(r'[0-9,.]').hasMatch(c)) {
      final start = i;
      while (i < s.length && RegExp(r'[0-9,.]').hasMatch(s[i])) {
        i++;
      }
      final text = s.substring(start, i).replaceAll(',', '.');
      final value = double.tryParse(text);
      if (value == null) throw const CalcError('Nombre invalide');
      tokens.add(_Token(_T.number, text, value));
      continue;
    }
    final func = calcFunctions.firstWhere(
      (f) => s.startsWith(f, i),
      orElse: () => '',
    );
    if (func.isNotEmpty) {
      tokens.add(_Token(_T.func, func));
      i += func.length;
      continue;
    }
    if (s.startsWith('Ans', i)) {
      tokens.add(const _Token(_T.constant, 'Ans'));
      i += 3;
      continue;
    }
    switch (c) {
      case '+' || '−' || '-' || '×' || '*' || '÷' || '/' || '^':
        tokens.add(_Token(_T.op, _normalizeOp(c)));
      case '(':
        tokens.add(const _Token(_T.lparen, '('));
      case ')':
        tokens.add(const _Token(_T.rparen, ')'));
      case 'π' || 'e':
        tokens.add(_Token(_T.constant, c));
      case '√':
        tokens.add(const _Token(_T.sqrt, '√'));
      case '!' || '%' || '²':
        tokens.add(_Token(_T.postfix, c));
      default:
        throw CalcError('Caractère inconnu : $c');
    }
    i++;
  }
  return tokens;
}

String _normalizeOp(String c) => switch (c) {
  '-' => '−',
  '*' => '×',
  '/' => '÷',
  _ => c,
};

class _Parser {
  final List<_Token> tokens;
  final bool degrees;
  final double ans;
  int pos = 0;

  _Parser(this.tokens, {required this.degrees, required this.ans});

  _Token? get _peek => pos < tokens.length ? tokens[pos] : null;

  bool _isOp(String op) => _peek?.type == _T.op && _peek!.text == op;

  double parse() {
    if (tokens.isEmpty) throw const CalcError('Expression vide');
    final v = _expr();
    // Parenthèses fermantes en trop : erreur ; ouvrantes en trop : fermées
    // implicitement (déjà géré dans _primary).
    if (pos < tokens.length) throw const CalcError('Expression invalide');
    return v;
  }

  double _expr() {
    var v = _term();
    while (_isOp('+') || _isOp('−')) {
      final op = tokens[pos++].text;
      final r = _term();
      v = op == '+' ? v + r : v - r;
    }
    return v;
  }

  /// Le prochain jeton commence-t-il une valeur (multiplication implicite) ?
  bool get _startsValue {
    final t = _peek;
    return t != null &&
        (t.type == _T.number ||
            t.type == _T.lparen ||
            t.type == _T.func ||
            t.type == _T.constant ||
            t.type == _T.sqrt);
  }

  double _term() {
    var v = _unary();
    while (true) {
      if (_isOp('×')) {
        pos++;
        v *= _unary();
      } else if (_isOp('÷')) {
        pos++;
        final r = _unary();
        if (r == 0) throw const CalcError('Division par zéro');
        v /= r;
      } else if (_startsValue) {
        v *= _unary();
      } else {
        return v;
      }
    }
  }

  double _unary() {
    if (_isOp('−')) {
      pos++;
      return -_unary();
    }
    if (_isOp('+')) {
      pos++;
      return _unary();
    }
    return _power();
  }

  double _power() {
    final base = _postfix();
    if (_isOp('^')) {
      pos++;
      final exp = _unary(); // associative à droite : 2^3^2 = 2^9
      final v = math.pow(base, exp).toDouble();
      if (v.isNaN) throw const CalcError('Puissance impossible');
      return v;
    }
    return base;
  }

  double _postfix() {
    var v = _primary();
    while (_peek?.type == _T.postfix) {
      switch (tokens[pos++].text) {
        case '!':
          v = _factorial(v);
        case '%':
          v /= 100;
        case '²':
          v *= v;
      }
    }
    return v;
  }

  double _primary() {
    final t = _peek;
    if (t == null) throw const CalcError('Expression incomplète');
    pos++;
    switch (t.type) {
      case _T.number:
        return t.value;
      case _T.constant:
        return switch (t.text) {
          'π' => math.pi,
          'e' => math.e,
          _ => ans,
        };
      case _T.lparen:
        final v = _expr();
        if (_peek?.type == _T.rparen) pos++;
        return v;
      case _T.sqrt:
        final v = _postfix();
        if (v < 0) throw const CalcError('Racine d\'un nombre négatif');
        return math.sqrt(v);
      case _T.func:
        if (_peek?.type != _T.lparen) {
          throw const CalcError('Parenthèse attendue');
        }
        final x = _primary(); // consomme « ( … ) »
        return _apply(t.text, x);
      default:
        throw const CalcError('Expression invalide');
    }
  }

  double _apply(String f, double x) {
    final angle = degrees ? x * math.pi / 180 : x;
    // Résidu flottant des fonctions trigonométriques : sin(180°) → 0.
    double clean(double v) => v.abs() < 1e-12 ? 0 : v;
    switch (f) {
      case 'sin':
        return clean(math.sin(angle));
      case 'cos':
        return clean(math.cos(angle));
      case 'tan':
        // tan(90°), tan(270°)… : indéfinie.
        if (math.cos(angle).abs() < 1e-12) {
          throw const CalcError('Tangente indéfinie');
        }
        return clean(math.tan(angle));
      case 'ln':
        if (x <= 0) throw const CalcError('ln d\'un nombre ≤ 0');
        return math.log(x);
      case 'log':
        if (x <= 0) throw const CalcError('log d\'un nombre ≤ 0');
        return math.log(x) / math.ln10;
    }
    throw CalcError('Fonction inconnue : $f');
  }

  static double _factorial(double n) {
    if (n < 0 || n != n.roundToDouble()) {
      throw const CalcError('n! : entier positif requis');
    }
    if (n > 170) throw const CalcError('Résultat trop grand');
    var r = 1.0;
    for (var i = 2; i <= n; i++) {
      r *= i;
    }
    return r;
  }
}
