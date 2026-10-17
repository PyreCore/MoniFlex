import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../services/history_service.dart';
import '../utils/format.dart';
import 'live_chart.dart';

/// Périodes proposées, en jours.
const historyPeriods = [7, 30, 90];

/// Variation (en %) en dessous de laquelle une paire est dite stable : parité
/// fixe (EUR/XAF) ou simples arrondis de la source.
const _stableThreshold = 0.01;

/// Variation récente et courbe d'évolution de 1 [from] en [to].
class VariationCard extends StatelessWidget {
  final String from;
  final String to;
  final RateHistory? history;
  final bool loading;
  final int days;
  final ValueChanged<int> onDaysChanged;

  /// Graphique de cotation en temps réel plutôt que l'historique quotidien.
  final bool live;
  final ValueChanged<bool> onLiveChanged;

  const VariationCard({
    super.key,
    required this.from,
    required this.to,
    required this.history,
    required this.loading,
    required this.days,
    required this.onDaysChanged,
    required this.live,
    required this.onLiveChanged,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final series = history?.series(from, to) ?? const <RatePoint>[];
    final daily = RateHistory.lastChange(series);
    // Période réellement couverte : peut différer de [days] si le chargement
    // de la période choisie a échoué et que l'ancien historique est affiché.
    final span = series.length < 2
        ? 0
        : series.last.date.difference(series.first.date).inDays;

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Évolution 1 $from → $to',
                    style: theme.textTheme.titleMedium,
                  ),
                ),
                if (loading)
                  const SizedBox.square(
                    dimension: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
              ],
            ),
            if (liveChartSupported) ...[
              const SizedBox(height: 12),
              SegmentedButton<bool>(
                segments: const [
                  ButtonSegment(
                    value: true,
                    label: Text('Temps réel'),
                    icon: Icon(Icons.candlestick_chart),
                  ),
                  ButtonSegment(
                    value: false,
                    label: Text('Historique'),
                    icon: Icon(Icons.show_chart),
                  ),
                ],
                selected: {live},
                showSelectedIcon: false,
                onSelectionChanged: (s) => onLiveChanged(s.first),
              ),
            ],
            if (liveChartSupported && live) ...[
              if (daily != null) ...[
                const SizedBox(height: 16),
                _Change(label: 'Depuis la veille', value: daily),
              ],
              const SizedBox(height: 16),
              if (from == to)
                const SizedBox(
                  height: 160,
                  child: Center(
                    child: Text('Choisis deux devises différentes.'),
                  ),
                )
              else
                // Bougies 1 min par défaut ; l'intervalle se change dans la
                // barre du graphique.
                SizedBox(
                  height: 420,
                  child: LiveChart(from: from, to: to),
                ),
              const SizedBox(height: 8),
              Text(
                'Cours en direct fournis par TradingView. Sans connexion, '
                'utilise l\'onglet Historique.',
                style: theme.textTheme.bodySmall,
              ),
            ] else ...[
              const SizedBox(height: 12),
              SegmentedButton<int>(
                segments: [
                  for (final d in historyPeriods)
                    ButtonSegment(value: d, label: Text('$d j')),
                ],
                selected: {days},
                showSelectedIcon: false,
                onSelectionChanged: (s) => onDaysChanged(s.first),
              ),
              const SizedBox(height: 16),
              if (series.length < 2)
                SizedBox(
                  height: 160,
                  child: Center(
                    child: Text(
                      loading
                          ? 'Chargement de l\'historique…'
                          : history == null
                          ? 'Historique indisponible (connexion requise).'
                          : 'Pas d\'historique disponible pour cette paire.',
                      style: theme.textTheme.bodyMedium,
                      textAlign: TextAlign.center,
                    ),
                  ),
                )
              else ...[
                Wrap(
                  spacing: 24,
                  runSpacing: 8,
                  children: [
                    if (daily != null)
                      _Change(label: 'Depuis la veille', value: daily),
                    _Change(
                      label: 'Sur $span jour${span > 1 ? 's' : ''}',
                      value: RateHistory.periodChange(series)!,
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                SizedBox(
                  height: 180,
                  // Marge à droite pour ne pas couper la dernière date.
                  child: Padding(
                    padding: const EdgeInsets.only(right: 16),
                    child: _Chart(series: series, to: to),
                  ),
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }
}

/// Variation en % avec flèche et signe : jamais la couleur seule.
class _Change extends StatelessWidget {
  final String label;
  final double value;

  const _Change({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;
    final stable = value.abs() < _stableThreshold;
    final up = value > 0;
    final color = stable
        ? theme.colorScheme.onSurfaceVariant
        : up
        ? (dark ? const Color(0xFF0CA30C) : const Color(0xFF006300))
        : (dark ? const Color(0xFFE66767) : const Color(0xFFD03B3B));
    final icon = stable
        ? Icons.trending_flat
        : (up ? Icons.trending_up : Icons.trending_down);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: theme.textTheme.bodySmall),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 20, color: color),
            const SizedBox(width: 4),
            Text(
              stable ? 'Stable' : formatPercent(value),
              style: theme.textTheme.titleMedium?.copyWith(
                color: color,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _Chart extends StatelessWidget {
  final List<RatePoint> series;
  final String to;

  const _Chart({required this.series, required this.to});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final line = theme.colorScheme.primary;
    final muted = theme.colorScheme.onSurfaceVariant;

    var values = series.map((p) => p.value).toList();
    var minY = values.reduce(math.min);
    var maxY = values.reduce(math.max);
    final mean = (minY + maxY) / 2;
    // Paire stable : ligne plate, sinon de simples arrondis seraient étirés
    // sur toute la hauteur.
    if ((maxY - minY) / mean * 100 < _stableThreshold) {
      values = List.filled(values.length, mean);
      minY = mean * 0.99;
      maxY = mean * 1.01;
    } else {
      final pad = (maxY - minY) * 0.15;
      minY -= pad;
      maxY += pad;
    }
    final interval = (maxY - minY) / 3;
    // Assez de décimales pour que les libellés de l'axe soient distincts.
    final decimals = (1 - (math.log(interval) / math.ln10).floor()).clamp(0, 8);

    // Abscisse = jours écoulés depuis le premier point : les écarts entre
    // dates (1 ou 3 jours, jour manquant) sont respectés.
    final first = series.first.date;
    double x(RatePoint p) => p.date.difference(first).inDays.toDouble();
    final lastX = x(series.last);
    final labelStyle = theme.textTheme.labelSmall?.copyWith(color: muted);

    return LineChart(
      LineChartData(
        minX: 0,
        maxX: lastX,
        minY: minY,
        maxY: maxY,
        borderData: FlBorderData(show: false),
        gridData: FlGridData(
          drawVerticalLine: false,
          horizontalInterval: interval,
          getDrawingHorizontalLine: (_) => FlLine(
            color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
            strokeWidth: 1,
          ),
        ),
        titlesData: FlTitlesData(
          topTitles: const AxisTitles(),
          rightTitles: const AxisTitles(),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 56,
              interval: interval,
              getTitlesWidget: (v, meta) {
                if (v == meta.min || v == meta.max) {
                  return const SizedBox.shrink();
                }
                return Text(
                  v.toStringAsFixed(decimals).replaceAll('.', ','),
                  style: labelStyle,
                );
              },
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 24,
              // Début, milieu et fin de la période.
              interval: lastX / 2,
              getTitlesWidget: (v, meta) => SideTitleWidget(
                meta: meta,
                child: Text(
                  formatShortDate(first.add(Duration(days: v.round()))),
                  style: labelStyle,
                ),
              ),
            ),
          ),
        ),
        lineTouchData: LineTouchData(
          getTouchedSpotIndicator: (_, indexes) => [
            for (final _ in indexes)
              TouchedSpotIndicatorData(
                FlLine(color: muted, strokeWidth: 1, dashArray: [4, 4]),
                FlDotData(
                  getDotPainter: (_, _, _, _) => FlDotCirclePainter(
                    radius: 5,
                    color: line,
                    strokeWidth: 2,
                    strokeColor: theme.colorScheme.surface,
                  ),
                ),
              ),
          ],
          touchTooltipData: LineTouchTooltipData(
            getTooltipColor: (_) => theme.colorScheme.inverseSurface,
            fitInsideHorizontally: true,
            fitInsideVertically: true,
            getTooltipItems: (spots) => [
              for (final s in spots)
                LineTooltipItem(
                  '${formatShortDate(series[s.spotIndex].date)}\n',
                  TextStyle(
                    color: theme.colorScheme.onInverseSurface,
                    fontSize: 12,
                  ),
                  children: [
                    TextSpan(
                      text: '${formatAmount(s.y)} $to',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
            ],
          ),
        ),
        lineBarsData: [
          LineChartBarData(
            spots: [
              for (var i = 0; i < series.length; i++)
                FlSpot(x(series[i]), values[i]),
            ],
            color: line,
            barWidth: 2,
            isStrokeCapRound: true,
            dotData: const FlDotData(show: false),
            belowBarData: BarAreaData(
              show: true,
              color: line.withValues(alpha: 0.12),
            ),
          ),
        ],
      ),
    );
  }
}
