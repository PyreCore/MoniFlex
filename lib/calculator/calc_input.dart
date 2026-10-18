import 'calc_engine.dart';

/// État de la calculatrice et effet de chaque touche, sans interface
/// (testable seul).
class CalcInput {
  String expression = '';

  /// Ligne du dessus après « = » : « 2+3 = ».
  String history = '';

  /// Message d'erreur du dernier « = », s'il a échoué.
  String? error;
  bool degrees = true;

  /// Dernier résultat (touche Ans).
  double ans = 0;
  bool _justEvaluated = false;

  static const _binaryOps = '+−×÷^';
  // Caractères après lesquels une valeur est complète (on peut enchaîner
  // un opérateur ou un postfixe).
  static final _endsValue = RegExp(r'[0-9)πe²!%s]$');

  bool get justEvaluated => _justEvaluated;

  /// Aperçu pendant la saisie (null si l'expression est incomplète).
  double? get preview {
    if (expression.isEmpty || _justEvaluated) return null;
    try {
      return evaluate(expression, degrees: degrees, ans: ans);
    } on CalcError {
      return null;
    }
  }

  /// Valeur à envoyer au convertisseur : le résultat affiché.
  double? get value => _justEvaluated ? ans : preview;

  void press(String key) {
    error = null;
    switch (key) {
      case 'AC':
        expression = '';
        history = '';
        _justEvaluated = false;
      case '⌫':
        _backspace();
      case '=':
        _equals();
      case 'DEG':
        degrees = !degrees;
      case '±':
        _toggleSign();
      case ',':
        _comma();
      case '+' || '−' || '×' || '÷' || '^':
        _operator(key);
      case '²' || '!' || '%':
        _continue();
        if (_endsValue.hasMatch(expression)) expression += key;
      case ')':
        _continue();
        if (_openParens > 0 && _endsValue.hasMatch(expression)) {
          expression += ')';
        }
      case 'sin' || 'cos' || 'tan' || 'ln' || 'log':
        _startNew();
        expression += '$key(';
      default: // chiffres, (, √, π, e, Ans
        _startNew();
        expression += key;
    }
  }

  int get _openParens =>
      '('.allMatches(expression).length - ')'.allMatches(expression).length;

  /// Après « = », une nouvelle valeur démarre un nouveau calcul…
  void _startNew() {
    if (_justEvaluated) {
      history = 'Ans = ${formatCalc(ans)}';
      expression = '';
      _justEvaluated = false;
    }
  }

  /// … alors qu'un opérateur continue à partir du résultat.
  void _continue() => _justEvaluated = false;

  void _operator(String op) {
    _continue();
    if (expression.isEmpty) {
      if (op == '−') expression = '−';
      return;
    }
    final last = expression[expression.length - 1];
    if (_binaryOps.contains(last)) {
      // « 5×− » : signe négatif après ×, ÷ ou ^ ; sinon on remplace.
      if (op == '−' && '×÷^'.contains(last)) {
        expression += op;
      } else if (expression.length > 1) {
        expression = expression.substring(0, expression.length - 1) + op;
      }
      return;
    }
    if (last == '(' && op != '−') return;
    expression += op;
  }

  void _comma() {
    _startNew();
    final lastNumber = RegExp(r'[0-9,]*$').stringMatch(expression) ?? '';
    if (lastNumber.contains(',')) return;
    expression += lastNumber.isEmpty ? '0,' : ',';
  }

  void _backspace() {
    if (_justEvaluated) {
      expression = '';
      _justEvaluated = false;
      return;
    }
    if (expression.isEmpty) return;
    for (final token in [...calcFunctions.map((f) => '$f('), 'Ans']) {
      if (expression.endsWith(token)) {
        expression = expression.substring(0, expression.length - token.length);
        return;
      }
    }
    expression = expression.substring(0, expression.length - 1);
  }

  /// Change le signe du dernier nombre : « 5−3 » → « 5−(−3 ».
  void _toggleSign() {
    _continue();
    final match = RegExp(r'[0-9,]+$').firstMatch(expression);
    if (match == null) {
      if (expression.isEmpty) expression = '−';
      return;
    }
    final before = expression.substring(0, match.start);
    if (before.endsWith('(−')) {
      expression = before.substring(0, before.length - 2) + match.group(0)!;
    } else {
      expression = '$before(−${match.group(0)}';
    }
  }

  void _equals() {
    if (expression.isEmpty || _justEvaluated) return;
    try {
      final v = evaluate(expression, degrees: degrees, ans: ans);
      history = '$expression =';
      ans = v;
      final shown = formatCalc(v);
      // Le résultat devient l'expression, pour enchaîner un calcul ; en
      // notation scientifique, on passe par Ans (« 1e20 » serait relu
      // comme 1 × e × 20).
      expression = shown.contains('e') ? 'Ans' : shown;
      _justEvaluated = true;
    } on CalcError catch (e) {
      error = e.message;
    }
  }
}
