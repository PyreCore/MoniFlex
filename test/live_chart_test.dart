import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

import 'package:convertisseur_devises/widgets/live_chart.dart';

void main() {
  test('adresse TradingView pour la paire choisie', () {
    final url = tradingViewUrl('USD', 'XAF', dark: true);
    expect(url.host, 'www.tradingview-widget.com');
    final config =
        jsonDecode(Uri.decodeComponent(url.fragment)) as Map<String, dynamic>;
    expect(config['symbol'], 'FX_IDC:USDXAF');
    expect(config['theme'], 'dark');
    expect(config['locale'], 'fr');
    expect(config['hide_volume'], isTrue);

    final light = tradingViewUrl('EUR', 'USD', dark: false);
    expect(jsonDecode(Uri.decodeComponent(light.fragment))['theme'], 'light');
  });
}
