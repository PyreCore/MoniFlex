import 'package:flutter/material.dart';

/// Couleur de marque MoniFlex.
const brandColor = Color(0xFF00897B);

/// Chiffres de largeur fixe : les montants ne « dansent » pas en tapant.
const tabularFigures = [FontFeature.tabularFigures()];

/// Fond de l'écran : légèrement teinté en clair, très sombre en sombre.
Color pageBackground(ColorScheme s) =>
    s.brightness == Brightness.light ? s.surfaceContainer : s.surface;

/// Fond des cartes : blanc en clair, un cran plus clair que la page en sombre,
/// pour que les blocs se détachent nettement du fond.
Color cardBackground(ColorScheme s) => s.brightness == Brightness.light
    ? s.surfaceContainerLowest
    : s.surfaceContainerHigh;

/// Teinte de marque des zones « résultat ».
Color resultTint(ColorScheme s) => s.brightness == Brightness.light
    ? s.primaryContainer.withValues(alpha: 0.45)
    : s.primary.withValues(alpha: 0.14);

ThemeData buildTheme(Brightness brightness) {
  final scheme = ColorScheme.fromSeed(
    seedColor: brandColor,
    brightness: brightness,
  );
  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: pageBackground(scheme),
    appBarTheme: AppBarTheme(
      backgroundColor: pageBackground(scheme),
      surfaceTintColor: Colors.transparent,
      scrolledUnderElevation: 0,
      centerTitle: false,
    ),
    cardTheme: CardThemeData(
      elevation: 0,
      margin: EdgeInsets.zero,
      color: cardBackground(scheme),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: BorderSide(
          color: scheme.outlineVariant.withValues(
            alpha: brightness == Brightness.light ? 0.6 : 0.3,
          ),
        ),
      ),
    ),
    segmentedButtonTheme: SegmentedButtonThemeData(
      style: ButtonStyle(
        visualDensity: VisualDensity.compact,
        side: WidgetStatePropertyAll(BorderSide(color: scheme.outlineVariant)),
      ),
    ),
  );
}
