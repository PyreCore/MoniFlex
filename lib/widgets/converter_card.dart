import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../data/currencies.dart';
import '../theme.dart';
import '../utils/format.dart';
import 'variation_card.dart' show ChangeBadge;

/// Carte principale : montant saisi en haut, montant converti en bas,
/// bouton d'inversion entre les deux, taux et variation du jour en pied.
class ConverterCard extends StatelessWidget {
  final TextEditingController amountController;
  final String from;
  final String to;
  final double result;
  final double unitRate;

  /// Variation depuis la veille en %, si l'historique est disponible.
  final double? dailyChange;
  final VoidCallback onPickFrom;
  final VoidCallback onPickTo;
  final VoidCallback onSwap;

  const ConverterCard({
    super.key,
    required this.amountController,
    required this.from,
    required this.to,
    required this.result,
    required this.unitRate,
    required this.dailyChange,
    required this.onPickFrom,
    required this.onPickTo,
    required this.onSwap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final amountStyle = theme.textTheme.headlineMedium?.copyWith(
      fontWeight: FontWeight.w700,
      fontFeatures: tabularFigures,
      color: scheme.onSurface,
    );

    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          // Les deux lignes, avec le bouton ⇅ posé à cheval sur le séparateur.
          Stack(
            alignment: Alignment.center,
            children: [
              Column(
                children: [
                  _Row(
                    label: 'Montant',
                    code: from,
                    onPick: onPickFrom,
                    child: TextField(
                      controller: amountController,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      inputFormatters: [
                        // Chiffres et un seul séparateur décimal.
                        TextInputFormatter.withFunction(
                          (old, value) =>
                              RegExp(r'^\d*[.,]?\d*$').hasMatch(value.text)
                              ? value
                              : old,
                        ),
                        LengthLimitingTextInputFormatter(15),
                      ],
                      style: amountStyle,
                      decoration: const InputDecoration(
                        isCollapsed: true,
                        border: InputBorder.none,
                        hintText: '0',
                      ),
                    ),
                  ),
                  // Zone résultat teintée : on distingue d'un coup d'œil ce
                  // que l'on saisit de ce que l'on obtient.
                  ColoredBox(
                    color: resultTint(scheme),
                    child: _Row(
                      label: 'Converti',
                      code: to,
                      onPick: onPickTo,
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: SelectableText(
                          formatAmount(result),
                          style: amountStyle?.copyWith(color: scheme.primary),
                          maxLines: 1,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              IconButton.filled(
                onPressed: onSwap,
                tooltip: 'Inverser les devises',
                icon: const Icon(Icons.swap_vert),
                style: IconButton.styleFrom(
                  side: BorderSide(color: cardBackground(scheme), width: 4),
                ),
              ),
            ],
          ),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 14),
            decoration: BoxDecoration(
              color: resultTint(scheme),
              border: Border(
                top: BorderSide(color: scheme.primary.withValues(alpha: 0.15)),
              ),
            ),
            child: Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 12,
              runSpacing: 6,
              children: [
                Text(
                  '1 $from = ${formatAmount(unitRate)} $to',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    fontFeatures: tabularFigures,
                  ),
                ),
                if (dailyChange != null)
                  ChangeBadge(value: dailyChange!, suffix: ' 24 h'),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Une ligne : libellé + montant à gauche, devise à droite.
class _Row extends StatelessWidget {
  final String label;
  final String code;
  final VoidCallback onPick;
  final Widget child;

  const _Row({
    required this.label,
    required this.code,
    required this.onPick,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 18, 16, 18),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 6),
                child,
                const SizedBox(height: 4),
                Text(
                  currencyName(code),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          _CurrencyChip(code: code, onTap: onPick),
        ],
      ),
    );
  }
}

class _CurrencyChip extends StatelessWidget {
  final String code;
  final VoidCallback onTap;

  const _CurrencyChip({required this.code, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.surfaceContainerHighest,
      shape: const StadiumBorder(),
      child: InkWell(
        customBorder: const StadiumBorder(),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(10, 8, 6, 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(currencyFlag(code), style: const TextStyle(fontSize: 22)),
              const SizedBox(width: 8),
              Text(
                code,
                style: Theme.of(context).textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.w700),
              ),
              const Icon(Icons.expand_more, size: 20),
            ],
          ),
        ),
      ),
    );
  }
}
