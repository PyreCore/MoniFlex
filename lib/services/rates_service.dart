import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

/// Taux de change exprimés par rapport à une devise de base (USD).
class ExchangeRates {
  final String base;
  final Map<String, double> rates;
  final DateTime updatedAt;
  final bool fromCache;

  ExchangeRates({
    required this.base,
    required this.rates,
    required this.updatedAt,
    this.fromCache = false,
  });

  /// Convertit [amount] de la devise [from] vers [to].
  double convert(double amount, String from, String to) {
    final fromRate = rates[from];
    final toRate = rates[to];
    if (fromRate == null || toRate == null) return 0;
    return amount / fromRate * toRate;
  }

  List<String> get codes => rates.keys.toList()..sort();
}

class RatesService {
  static const _url = 'https://open.er-api.com/v6/latest/USD';
  static const _cacheKey = 'rates_cache';

  /// Récupère les taux en ligne ; en cas d'échec, utilise le cache local.
  Future<ExchangeRates> fetchRates() async {
    final prefs = await SharedPreferences.getInstance();
    try {
      final response =
          await http.get(Uri.parse(_url)).timeout(const Duration(seconds: 10));
      if (response.statusCode != 200) {
        throw Exception('Erreur HTTP ${response.statusCode}');
      }
      final rates = _parse(response.body);
      await prefs.setString(_cacheKey, response.body);
      return rates;
    } catch (e) {
      final cached = prefs.getString(_cacheKey);
      if (cached != null) {
        final rates = _parse(cached);
        return ExchangeRates(
          base: rates.base,
          rates: rates.rates,
          updatedAt: rates.updatedAt,
          fromCache: true,
        );
      }
      rethrow;
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
