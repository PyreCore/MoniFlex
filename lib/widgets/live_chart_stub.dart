import 'package:flutter/widgets.dart';

const liveChartSupported = false;

class LiveChart extends StatelessWidget {
  final String from;
  final String to;

  const LiveChart({super.key, required this.from, required this.to});

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}
