import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

/// Provenance des taux affichés.
enum RatesSource {
  /// Téléchargés à l'instant.
  online,

  /// Derniers taux téléchargés, enregistrés sur l'appareil.
  cache,

  /// Taux de référence livrés avec l'application (premier lancement
  /// hors ligne).
  bundled,
}

/// Taux de change exprimés par rapport à une devise de base (USD).
class ExchangeRates {
  final String base;
  final Map<String, double> rates;
  final DateTime updatedAt;
  final RatesSource source;

  ExchangeRates({
    required this.base,
    required this.rates,
    required this.updatedAt,
    this.source = RatesSource.online,
  });

  /// Convertit [amount] de la devise [from] vers [to].
  double convert(double amount, String from, String to) {
    final fromRate = rates[from];
    final toRate = rates[to];
    if (fromRate == null || toRate == null) return 0;
    return amount / fromRate * toRate;
  }

  List<String> get codes => rates.keys.toList()..sort();

  ExchangeRates withSource(RatesSource source) => ExchangeRates(
    base: base,
    rates: rates,
    updatedAt: updatedAt,
    source: source,
  );
}

class RatesService {
  static const _url = 'https://open.er-api.com/v6/latest/USD';
  static const _cacheKey = 'rates_cache';
  static const fallbackAsset = 'assets/fallback_rates.json';

  final http.Client _client;
  final Future<String> Function(String key) _loadAsset;

  RatesService({
    http.Client? client,
    Future<String> Function(String key)? loadAsset,
  }) : _client = client ?? http.Client(),
       _loadAsset = loadAsset ?? rootBundle.loadString;

  /// Récupère les taux en ligne ; en cas d'échec, utilise le cache local,
  /// puis en dernier recours les taux de référence livrés avec l'app.
  Future<ExchangeRates> fetchRates() async {
    final prefs = await SharedPreferences.getInstance();
    try {
      final response = await _client
          .get(Uri.parse(_url))
          .timeout(const Duration(seconds: 10));
      if (response.statusCode != 200) {
        throw Exception('Erreur HTTP ${response.statusCode}');
      }
      final rates = _parse(response.body);
      await prefs.setString(_cacheKey, response.body);
      return rates;
    } catch (_) {
      final cached = prefs.getString(_cacheKey);
      if (cached != null) {
        return _parse(cached).withSource(RatesSource.cache);
      }
      final bundled = await _loadAsset(fallbackAsset);
      return _parse(bundled).withSource(RatesSource.bundled);
    }
  }

  ExchangeRates _parse(String body) {
    final json = jsonDecode(body) as Map<String, dynamic>;
    if (json['result'] != 'success') {
      throw Exception('Réponse invalide de l\'API');
    }
    final rawRates = json['rates'] as Map<String, dynamic>;
    return ExchangeRates(
      base: json['base_code'] as String,
      rates: rawRates.map((k, v) => MapEntry(k, (v as num).toDouble())),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(
        (json['time_last_update_unix'] as int) * 1000,
      ),
    );
  }
}
