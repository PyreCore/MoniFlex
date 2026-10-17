// Graphique de cotation en temps réel (TradingView). Disponible sur la
// version web uniquement ; ailleurs, seul l'historique quotidien est proposé.
import 'dart:convert';

export 'live_chart_stub.dart'
    if (dart.library.js_interop) 'live_chart_web.dart';

/// Adresse du graphique TradingView en bougies pour [from]/[to].
/// FX_IDC couvre aussi les paires exotiques (USD/XAF, USD/NGN…).
Uri tradingViewUrl(String from, String to, {required bool dark}) {
  final config = {
    'symbol': 'FX_IDC:$from$to',
    // Bougies de 15 min ; la dernière évolue en direct. L'intervalle se
    // change dans la barre du graphique.
    'interval': '15',
    'style': '1',
    'theme': dark ? 'dark' : 'light',
    'locale': 'fr',
    // Heure d'Afrique centrale et de l'Ouest (UTC+1), zone du franc CFA.
    'timezone': 'Africa/Lagos',
    // Le volume n'a pas de sens sur le forex et masquerait les bougies.
    'hide_volume': true,
    'hide_side_toolbar': true,
    'allow_symbol_change': false,
    'save_image': false,
    'withdateranges': true,
    'autosize': true,
  };
  return Uri.https(
    'www.tradingview-widget.com',
    '/embed-widget/advanced-chart/',
    {'locale': 'fr'},
  ).replace(fragment: jsonEncode(config));
}
