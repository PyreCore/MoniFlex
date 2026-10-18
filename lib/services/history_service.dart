import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

/// Valeur de 1 unité d'une devise dans une autre, à une date donnée.
class RatePoint {
  final DateTime date;
  final double value;

  const RatePoint(this.date, this.value);
}

/// Taux quotidiens (base USD) sur une période, du plus ancien au plus récent.
class RateHistory {
  final Map<DateTime, Map<String, double>> days;

  RateHistory(Map<DateTime, Map<String, double>> days)
    : days = Map.fromEntries(
        days.entries.toList()..sort((a, b) => a.key.compareTo(b.key)),
      );

  /// Évolution de 1 [from] exprimé en [to].
  List<RatePoint> series(String from, String to) => [
    for (final e in days.entries)
      if (e.value[from] != null && e.value[to] != null)
        RatePoint(e.key, e.value[to]! / e.value[from]!),
  ];

  /// Variation en % depuis la veille : null si les deux derniers points ne
  /// sont pas des jours consécutifs (jour manquant).
  static double? lastChange(List<RatePoint> s) {
    if (s.length < 2) return null;
    final prev = s[s.length - 2];
    if (s.last.date.difference(prev.date).inDays != 1) return null;
    return _percent(prev.value, s.last.value);
  }

  /// Variation en % entre le premier et le dernier point.
  static double? periodChange(List<RatePoint> s) =>
      s.length < 2 ? null : _percent(s.first.value, s.last.value);

  static double _percent(double a, double b) => (b - a) / a * 100;
}

/// Historique gratuit et sans clé : https://github.com/fawazahmed0/exchange-api
class HistoryService {
  static const _cachePrefix = 'history_';
  static const _maxCacheAge = Duration(days: 100);

  final http.Client _client;
  final DateTime Function() _now;

  HistoryService({http.Client? client, DateTime Function()? now})
    : _client = client ?? http.Client(),
      _now = now ?? DateTime.now;

  /// Taux des [days] derniers jours. Au-delà de 30 jours, un point tous les
  /// 3 jours (plus les 2 derniers jours, pour la variation depuis la veille).
  /// Les jours passés sont mis en cache (ils ne changent plus) ; seul le jour
  /// courant est retéléchargé.
  Future<RateHistory> fetch(int days) async {
    final prefs = await SharedPreferences.getInstance();
    final now = _now().toUtc();
    final today = DateTime.utc(now.year, now.month, now.day);
    final step = days <= 30 ? 1 : 3;

    // Un jour de plus que demandé : tôt le matin, les taux du jour ne sont
    // pas encore publiés et la période s'arrête la veille ; on recoupe
    // ensuite sur [days] jours à partir du dernier point disponible.
    final dates = <DateTime>[
      for (var i = days + 1; i > 0; i--)
        if (i <= 2 || _epochDay(today.subtract(Duration(days: i))) % step == 0)
          today.subtract(Duration(days: i)),
    ];

    final results = await Future.wait([
      for (final d in dates) _pastDay(prefs, d),
      _latest(),
    ]);

    final history = <DateTime, Map<String, double>>{};
    for (final r in results) {
      if (r != null) history[r.$1] = r.$2;
    }
    if (history.isEmpty) throw Exception('Historique indisponible');
    final latest = history.keys.reduce((a, b) => a.isAfter(b) ? a : b);
    final start = latest.subtract(Duration(days: days));
    history.removeWhere((date, _) => date.isBefore(start));

    _pruneCache(prefs, today);
    return RateHistory(history);
  }

  Future<(DateTime, Map<String, double>)?> _pastDay(
    SharedPreferences prefs,
    DateTime date,
  ) async {
    final key = '$_cachePrefix${_iso(date)}';
    final cached = prefs.getString(key);
    if (cached != null) return (date, _decodeCache(cached));

    final parsed = _tryParse(await _get(_iso(date)));
    if (parsed == null) return null;
    await prefs.setString(key, jsonEncode(parsed.$2));
    return (date, parsed.$2);
  }

  Future<(DateTime, Map<String, double>)?> _latest() async =>
      _tryParse(await _get('latest'));

  /// Une réponse illisible compte comme un jour manquant, sans faire échouer
  /// tout l'historique.
  (DateTime, Map<String, double>)? _tryParse(String? body) {
    if (body == null) return null;
    try {
      return _parse(body);
    } catch (_) {
      return null;
    }
  }

  /// Essaie le CDN principal puis le miroir.
  Future<String?> _get(String version) async {
    final urls = [
      'https://cdn.jsdelivr.net/npm/@fawazahmed0/currency-api@$version/v1/currencies/usd.min.json',
      'https://$version.currency-api.pages.dev/v1/currencies/usd.min.json',
    ];
    for (final url in urls) {
      try {
        final response = await _client
            .get(Uri.parse(url))
            .timeout(const Duration(seconds: 10));
        if (response.statusCode == 200) return response.body;
      } catch (_) {
        // On tente l'URL suivante.
      }
    }
    return null;
  }

  (DateTime, Map<String, double>) _parse(String body) {
    final json = jsonDecode(body) as Map<String, dynamic>;
    final date = DateTime.parse('${json['date']}T00:00:00Z');
    final raw = json['usd'] as Map<String, dynamic>;
    final rates = <String, double>{
      for (final e in raw.entries)
        // On ne garde que les codes ISO à 3 lettres (pas les cryptos, etc.).
        if (RegExp(r'^[a-z]{3}$').hasMatch(e.key) && e.value is num)
          e.key.toUpperCase(): (e.value as num).toDouble(),
    };
    return (date, rates);
  }

  Map<String, double> _decodeCache(String s) => (jsonDecode(s) as Map).map(
    (k, v) => MapEntry(k as String, (v as num).toDouble()),
  );

  void _pruneCache(SharedPreferences prefs, DateTime today) {
    final limit = _iso(today.subtract(_maxCacheAge));
    for (final key in prefs.getKeys()) {
      if (key.startsWith(_cachePrefix) &&
          key.substring(_cachePrefix.length).compareTo(limit) < 0) {
        prefs.remove(key);
      }
    }
  }

  static int _epochDay(DateTime d) =>
      d.millisecondsSinceEpoch ~/ Duration.millisecondsPerDay;

  static String _iso(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';
}
