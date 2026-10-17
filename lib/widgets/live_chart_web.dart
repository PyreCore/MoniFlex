import 'package:flutter/material.dart';
import 'package:web/web.dart' as web;

import 'live_chart.dart' show tradingViewUrl;

const liveChartSupported = true;

/// Intègre le graphique TradingView dans une iframe.
class LiveChart extends StatelessWidget {
  final String from;
  final String to;

  const LiveChart({super.key, required this.from, required this.to});

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final url = tradingViewUrl(from, to, dark: dark).toString();
    return HtmlElementView.fromTagName(
      // Une nouvelle iframe à chaque changement de paire ou de thème.
      key: ValueKey(url),
      tagName: 'iframe',
      onElementCreated: (element) {
        final iframe = element as web.HTMLIFrameElement;
        iframe.src = url;
        iframe.style.border = 'none';
        iframe.style.width = '100%';
        iframe.style.height = '100%';
        iframe.allowFullscreen = true;
      },
    );
  }
}
