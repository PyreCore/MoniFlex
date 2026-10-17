/// Montant au format français : espace pour les milliers, virgule décimale.
String formatAmount(double value) {
  if (value == 0) return '0';
  final decimals = value.abs() >= 1 ? 2 : 6;
  final parts = value.toStringAsFixed(decimals).split('.');
  final intPart = parts[0].replaceAllMapped(
    RegExp(r'(\d)(?=(\d{3})+$)'),
    (m) => '${m[1]} ',
  );
  return parts.length > 1 ? '$intPart,${parts[1]}' : intPart;
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
