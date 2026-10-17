import 'dart:async';

import 'package:flutter/material.dart';

import '../theme.dart';
import '../utils/format.dart';

/// Date du jour et heure qui défile en temps réel (heure du téléphone).
/// Seul ce widget se redessine chaque seconde, pas tout l'écran.
class LiveClock extends StatefulWidget {
  /// Source de l'heure, remplaçable dans les tests.
  final DateTime Function() now;

  const LiveClock({super.key, this.now = DateTime.now});

  @override
  State<LiveClock> createState() => _LiveClockState();
}

class _LiveClockState extends State<LiveClock> {
  late DateTime _now = widget.now();
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _scheduleTick();
  }

  /// Se cale sur le début de chaque seconde, pour que l'affichage change
  /// en même temps que l'horloge du téléphone.
  void _scheduleTick() {
    final delay = Duration(milliseconds: 1000 - _now.millisecond);
    _timer = Timer(delay, () {
      if (!mounted) return;
      setState(() => _now = widget.now());
      _scheduleTick();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Row(
        children: [
          Icon(Icons.calendar_today_outlined, size: 16, color: muted),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              formatLongDate(_now),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodyMedium?.copyWith(color: muted),
            ),
          ),
          const SizedBox(width: 12),
          Icon(Icons.schedule, size: 16, color: theme.colorScheme.primary),
          const SizedBox(width: 6),
          Text(
            formatTime(_now),
            semanticsLabel: 'Il est ${formatTime(_now)}',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
              color: theme.colorScheme.primary,
              fontFeatures: tabularFigures,
            ),
          ),
        ],
      ),
    );
  }
}
