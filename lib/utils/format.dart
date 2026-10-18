import 'dart:math' as math;

/// Montant au format français : espace pour les milliers, virgule décimale.
String formatAmount(double value) {
  if (value == 0) return '0';
  // Sous 1 : au moins 4 chiffres significatifs (ex. 0,000007312).
  final decimals = value.abs() >= 1
      ? 2
      : (3 - (math.log(value.abs()) / math.ln10).floor()).clamp(6, 12);
  final parts = value.toStringAsFixed(decimals).split('.');
  final intPart = parts[0].replaceAllMapped(
    RegExp(r'(\d)(?=(\d{3})+$)'),
    (m) => '${m[1]} ',
  );
  return parts.length > 1 ? '$intPart,${parts[1]}' : intPart;
}

/// Montant tel qu'on le taperait dans le champ « Montant » : sans espaces,
/// virgule décimale, 6 décimales au plus (« 1234,5 »).
String amountInputText(double value) {
  var s = value.toStringAsFixed(6);
  if (s.contains('.')) s = s.replaceFirst(RegExp(r'\.?0+$'), '');
  return s.replaceAll('.', ',');
}

/// Pourcentage signé : « +0,42 % », « −1,30 % ».
String formatPercent(double value) {
  final sign = value > 0 ? '+' : (value < 0 ? '−' : '');
  return '$sign${value.abs().toStringAsFixed(2).replaceAll('.', ',')} %';
}

String _two(int n) => n.toString().padLeft(2, '0');

String formatDate(DateTime d) =>
    '${_two(d.day)}/${_two(d.month)}/${d.year} à ${_two(d.hour)}h${_two(d.minute)}';

String formatShortDate(DateTime d) => '${_two(d.day)}/${_two(d.month)}';

/// Heure avec secondes : « 19:42:05 ».
String formatTime(DateTime d) =>
    '${_two(d.hour)}:${_two(d.minute)}:${_two(d.second)}';

const _weekdays = [
  'lundi',
  'mardi',
  'mercredi',
  'jeudi',
  'vendredi',
  'samedi',
  'dimanche',
];
const _months = [
  'janvier',
  'février',
  'mars',
  'avril',
  'mai',
  'juin',
  'juillet',
  'août',
  'septembre',
  'octobre',
  'novembre',
  'décembre',
];

/// Date en toutes lettres : « Samedi 17 octobre 2026 ».
String formatLongDate(DateTime d) {
  final day = _weekdays[d.weekday - 1];
  return '${day[0].toUpperCase()}${day.substring(1)} '
      '${d.day == 1 ? '1er' : d.day} ${_months[d.month - 1]} ${d.year}';
}

/// Texte en minuscules sans accents, pour la recherche (« Réal » → « real »).
String normalizeSearch(String s) {
  const from = 'àâäáãåçéèêëíìîïñóòôöõúùûüýÿ';
  const to = 'aaaaaaceeeeiiiinooooouuuuyy';
  final buffer = StringBuffer();
  for (final ch in s.toLowerCase().split('')) {
    if (ch == 'œ') {
      buffer.write('oe');
    } else if (ch == 'æ') {
      buffer.write('ae');
    } else {
      final i = from.indexOf(ch);
      buffer.write(i >= 0 ? to[i] : ch);
    }
  }
  return buffer.toString();
}
