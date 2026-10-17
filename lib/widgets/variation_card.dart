import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../services/history_service.dart';
import '../theme.dart';
import '../utils/format.dart';

/// Périodes proposées, en jours.
const historyPeriods = [7, 30, 90];

/// Variation (en %) en dessous de laquelle une paire est dite stable : parité
/// fixe (EUR/XAF) ou simples arrondis de la source.
const _stableThreshold = 0.01;

/// Historique de 1 [from] en [to] sur 7, 30 ou 90 jours.
class VariationCard extends StatelessWidget {
  final String from;
  final String to;
  final RateHistory? history;
  final bool loading;
  final int days;
  final ValueChanged<int> onDaysChanged;

  /// Hauteur du graphique (plus grand sur ordinateur).
  final double chartHeight;

  const VariationCard({
    super.key,
    required this.from,
    required this.to,
    required this.history,
    required this.loading,
    required this.days,
    required this.onDaysChanged,
    this.chartHeight = 220,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    final series = history?.series(from, to) ?? const <RatePoint>[];
    // Période réellement couverte : peut différer de [days] si le chargement
    // de la période choisie a échoué et que l'ancien historique est affiché.
    final span = series.length < 2
        ? 0
        : series.last.date.difference(series.first.date).inDays;

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Évolution',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        '1 $from en $to',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: muted,
                        ),
                      ),
                    ],
                  ),
                ),
                if (loading)
                  const Padding(
                    padding: EdgeInsets.only(right: 12),
                    child: SizedBox.square(
                      dimension: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  )
                else if (series.length >= 2)
                  ChangeBadge(
                    value: RateHistory.periodChange(series)!,
                    suffix: ' $span j',
                  ),
              ],
            ),
            const SizedBox(height: 14),
            SegmentedButton<int>(
              segments: [
                for (final d in historyPeriods)
                  ButtonSegment(value: d, label: Text('$d jours')),
              ],
              selected: {days},
              showSelectedIcon: false,
              onSelectionChanged: (s) => onDaysChanged(s.first),
            ),
            const SizedBox(height: 18),
            SizedBox(
              height: chartHeight,
              child: series.length < 2
                  ? Center(
                      child: Text(
                        loading
                            ? 'Chargement de l\'historique…'
                            : history == null
                            ? 'Historique indisponible (connexion requise).'
                            : 'Pas d\'historique disponible pour cette paire.',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: muted,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    )
                  // Marge à droite pour ne pas couper la dernière date.
                  : Padding(
                      padding: const EdgeInsets.only(right: 16),
                      child: _Chart(series: series, to: to),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Pastille de variation en % avec flèche et signe : jamais la couleur seule.
class ChangeBadge extends StatelessWidget {
  final double value;

  /// Période ajoutée après le pourcentage, ex. « 24 h ».
  final String suffix;

  const ChangeBadge({super.key, required this.value, this.suffix = ''});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;
    final stable = value.abs() < _stableThreshold;
    final up = value > 0;
    final color = stable
        ? theme.colorScheme.onSurfaceVariant
        : up
        ? (dark ? const Color(0xFF3DD13D) : const Color(0xFF006300))
        : (dark ? const Color(0xFFFF8A8A) : const Color(0xFFC62828));
    final icon = stable
        ? Icons.trending_flat
        : (up ? Icons.trending_up : Icons.trending_down);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 4),
          Text(
            '${stable ? 'Stable' : formatPercent(value)}$suffix',
            style: theme.textTheme.labelMedium?.copyWith(
              color: color,
              fontWeight: FontWeight.w700,
              fontFeatures: tabularFigures,
            ),
          ),
        ],
      ),
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
