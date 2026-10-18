import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme.dart';
import 'calc_engine.dart';
import 'calc_input.dart';

/// Calculatrice scientifique plein écran, sans défilement : les touches se
/// partagent la hauteur disponible. Renvoie le résultat si l'utilisateur
/// appuie sur « Convertir ce montant ».
class CalculatorPage extends StatefulWidget {
  const CalculatorPage({super.key});

  @override
  State<CalculatorPage> createState() => _CalculatorPageState();
}

enum _Kind { digit, op, sci, clear, equals }

class _Key {
  final String label;

  /// Touche envoyée à [CalcInput.press] (par défaut : le libellé).
  final String? input;
  final _Kind kind;

  const _Key(this.label, this.kind, [this.input]);

  String get key => input ?? label;
}

const _rows = [
  [
    _Key('sin', _Kind.sci),
    _Key('cos', _Kind.sci),
    _Key('tan', _Kind.sci),
    _Key('DEG', _Kind.sci),
    _Key('π', _Kind.sci),
  ],
  [
    _Key('ln', _Kind.sci),
    _Key('log', _Kind.sci),
    _Key('√', _Kind.sci),
    _Key('x²', _Kind.sci, '²'),
    _Key('xʸ', _Kind.sci, '^'),
  ],
  [
    _Key('(', _Kind.sci),
    _Key(')', _Kind.sci),
    _Key('%', _Kind.sci),
    _Key('n!', _Kind.sci, '!'),
    _Key('e', _Kind.sci),
  ],
  [
    _Key('7', _Kind.digit),
    _Key('8', _Kind.digit),
    _Key('9', _Kind.digit),
    _Key('÷', _Kind.op),
    _Key('AC', _Kind.clear),
  ],
  [
    _Key('4', _Kind.digit),
    _Key('5', _Kind.digit),
    _Key('6', _Kind.digit),
    _Key('×', _Kind.op),
    _Key('⌫', _Kind.op),
  ],
  [
    _Key('1', _Kind.digit),
    _Key('2', _Kind.digit),
    _Key('3', _Kind.digit),
    _Key('−', _Kind.op),
    _Key('Ans', _Kind.op),
  ],
  [
    _Key('±', _Kind.digit),
    _Key('0', _Kind.digit),
    _Key(',', _Kind.digit),
    _Key('+', _Kind.op),
    _Key('=', _Kind.equals),
  ],
];

class _CalculatorPageState extends State<CalculatorPage> {
  final _calc = CalcInput();

  void _press(String key) {
    HapticFeedback.selectionClick();
    setState(() => _calc.press(key));
  }

  /// Clavier physique (ordinateur) : chiffres, opérateurs, Entrée, Retour
  /// arrière, Échap.
  KeyEventResult _onKey(FocusNode _, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }
    final k = event.logicalKey;
    String? key;
    if (k == LogicalKeyboardKey.enter || k == LogicalKeyboardKey.numpadEnter) {
      key = '=';
    } else if (k == LogicalKeyboardKey.backspace) {
      key = '⌫';
    } else if (k == LogicalKeyboardKey.escape ||
        k == LogicalKeyboardKey.delete) {
      key = 'AC';
    } else {
      key = switch (event.character) {
        final c? when RegExp(r'^[0-9()!%^]$').hasMatch(c) => c,
        ',' || '.' => ',',
        '+' => '+',
        '-' => '−',
        '*' => '×',
        '/' => '÷',
        '=' => '=',
        _ => null,
      };
    }
    if (key == null) return KeyEventResult.ignored;
    _press(key);
    return KeyEventResult.handled;
  }

  @override
  Widget build(BuildContext context) {
    final value = _calc.value;
    final canConvert = value != null && value > 0 && value < 1e15;

    return Scaffold(
      appBar: AppBar(title: const Text('Calculatrice')),
      body: Focus(
        autofocus: true,
        onKeyEvent: _onKey,
        child: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
                child: Column(
                  children: [
                    Expanded(flex: 3, child: _Display(calc: _calc)),
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: SizedBox(
                        width: double.infinity,
                        child: FilledButton.tonalIcon(
                          onPressed: canConvert
                              ? () => Navigator.pop(context, value)
                              : null,
                          icon: const Icon(Icons.currency_exchange),
                          label: const Text('Convertir ce montant'),
                        ),
                      ),
                    ),
                    Expanded(
                      flex: 7,
                      child: Column(
                        children: [
                          for (final row in _rows)
                            Expanded(
                              child: Row(
                                children: [
                                  for (final k in row)
                                    Expanded(
                                      child: _KeyButton(
                                        k: k,
                                        label: k.label == 'DEG'
                                            ? (_calc.degrees ? 'DEG' : 'RAD')
                                            : k.label,
                                        onTap: () => _press(k.key),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Écran de la calculatrice : calcul précédent, saisie, aperçu ou erreur.
class _Display extends StatelessWidget {
  final CalcInput calc;

  const _Display({required this.calc});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final muted = scheme.onSurfaceVariant;
    final preview = calc.preview;

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: scheme.primary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    calc.degrees ? 'DEG' : 'RAD',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: scheme.primary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    calc.history,
                    textAlign: TextAlign.end,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyMedium?.copyWith(color: muted),
                  ),
                ),
              ],
            ),
            const Spacer(),
            // Saisie : défile horizontalement si elle est longue, la fin
            // (ce que l'on tape) restant visible.
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              reverse: true,
              child: Text(
                calc.expression.isEmpty ? '0' : calc.expression,
                maxLines: 1,
                style: theme.textTheme.displaySmall?.copyWith(
                  fontWeight: FontWeight.w600,
                  fontFeatures: tabularFigures,
                  color: calc.justEvaluated ? scheme.primary : scheme.onSurface,
                ),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              calc.error ?? (preview == null ? '' : '= ${formatCalc(preview)}'),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.titleMedium?.copyWith(
                color: calc.error != null ? scheme.error : muted,
                fontFeatures: tabularFigures,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _KeyButton extends StatelessWidget {
  final _Key k;
  final String label;
  final VoidCallback onTap;

  const _KeyButton({required this.k, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final s = theme.colorScheme;
    final (bg, fg) = switch (k.kind) {
      _Kind.digit => (cardBackground(s), s.onSurface),
      _Kind.op => (s.secondaryContainer, s.onSecondaryContainer),
      _Kind.sci => (s.surfaceContainerHigh, s.onSurfaceVariant),
      _Kind.clear => (s.errorContainer, s.onErrorContainer),
      _Kind.equals => (s.primary, s.onPrimary),
    };
    // Chiffres, = et opérateurs d'un caractère (÷ × − +) en grand.
    final big =
        k.kind == _Kind.digit ||
        k.kind == _Kind.equals ||
        (k.kind == _Kind.op && k.label.length == 1);

    return Padding(
      padding: const EdgeInsets.all(3),
      child: Material(
        color: bg,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Center(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Padding(
                padding: const EdgeInsets.all(4),
                child: Text(
                  label,
                  style:
                      (big
                              ? theme.textTheme.headlineSmall
                              : theme.textTheme.titleMedium)
                          ?.copyWith(color: fg, fontWeight: FontWeight.w600),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
