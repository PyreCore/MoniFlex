import 'dart:async';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'calculator/calculator_page.dart';
import 'data/currencies.dart';
import 'services/history_service.dart';
import 'services/rates_service.dart';
import 'settings/settings_page.dart';
import 'settings/theme_controller.dart';
import 'theme.dart';
import 'utils/format.dart';
import 'widgets/converter_card.dart';
import 'widgets/developed_by.dart';
import 'widgets/live_clock.dart';
import 'widgets/variation_card.dart';

void main() => runApp(const ConvertisseurApp());

class ConvertisseurApp extends StatefulWidget {
  const ConvertisseurApp({super.key});

  @override
  State<ConvertisseurApp> createState() => _ConvertisseurAppState();
}

class _ConvertisseurAppState extends State<ConvertisseurApp> {
  final _theme = ThemeController();

  @override
  void initState() {
    super.initState();
    _theme.load();
  }

  @override
  void dispose() {
    _theme.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder(
      valueListenable: _theme,
      builder: (context, mode, _) => MaterialApp(
        title: 'MoniFlex',
        debugShowCheckedModeBanner: false,
        themeMode: mode,
        theme: buildTheme(Brightness.light),
        darkTheme: buildTheme(Brightness.dark),
        home: ConverterPage(theme: _theme),
      ),
    );
  }
}

class ConverterPage extends StatefulWidget {
  final ThemeController theme;

  const ConverterPage({super.key, required this.theme});

  @override
  State<ConverterPage> createState() => _ConverterPageState();
}

class _ConverterPageState extends State<ConverterPage> {
  /// Fréquence d'actualisation automatique pendant que l'app est ouverte.
  static const _autoRefresh = Duration(minutes: 15);

  final _service = RatesService();
  final _historyService = HistoryService();
  final _amountController = TextEditingController(text: '1');
  Timer? _timer;

  ExchangeRates? _rates;
  String? _error;
  bool _loading = true;
  String _from = 'EUR';
  String _to = 'XAF';

  RateHistory? _history;
  bool _historyLoading = false;
  int _historyDays = historyPeriods.first;

  @override
  void initState() {
    super.initState();
    _loadPrefs();
    _refresh();
    _timer = Timer.periodic(_autoRefresh, (_) => _refresh());
    _amountController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _timer?.cancel();
    _amountController.dispose();
    super.dispose();
  }

  Future<void> _refresh() => Future.wait([_loadRates(), _loadHistory()]);

  Future<void> _loadHistory() async {
    final days = _historyDays;
    setState(() => _historyLoading = true);
    try {
      final history = await _historyService.fetch(days);
      // Ignore une réponse arrivée après un changement de période.
      if (!mounted || days != _historyDays) return;
      setState(() => _history = history);
    } catch (_) {
      // Hors ligne : on garde l'historique déjà affiché, s'il y en a un.
    } finally {
      if (mounted && days == _historyDays) {
        setState(() => _historyLoading = false);
      }
    }
  }

  void _setHistoryDays(int days) {
    setState(() => _historyDays = days);
    _loadHistory();
  }

  Future<void> _loadPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _from = prefs.getString('from') ?? _from;
      _to = prefs.getString('to') ?? _to;
      _ensureKnownCurrencies();
    });
  }

  /// Une devise mémorisée qui n'existe plus dans les taux (retirée par
  /// l'API) donnerait une conversion à 0 : on revient aux devises par défaut.
  void _ensureKnownCurrencies() {
    final rates = _rates?.rates;
    if (rates == null) return;
    String pick(String code, String fallback) => rates.containsKey(code)
        ? code
        : (rates.containsKey(fallback) ? fallback : rates.keys.first);
    _from = pick(_from, 'EUR');
    _to = pick(_to, 'XAF');
  }

  Future<void> _savePrefs() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('from', _from);
    await prefs.setString('to', _to);
  }

  Future<void> _loadRates() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final rates = await _service.fetchRates();
      if (!mounted) return;
      setState(() {
        _rates = rates;
        _ensureKnownCurrencies();
      });
    } catch (e) {
      if (!mounted) return;
      setState(
        () => _error =
            'Impossible de récupérer les taux. Vérifie ta connexion internet.',
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  /// Ouvre la calculatrice ; si l'utilisateur choisit « Convertir ce
  /// montant », le résultat devient le montant à convertir.
  Future<void> _openCalculator() async {
    final value = await Navigator.push<double>(
      context,
      MaterialPageRoute(builder: (_) => const CalculatorPage()),
    );
    if (value == null || !mounted) return;
    _amountController.text = amountInputText(value);
  }

  double get _amount =>
      double.tryParse(_amountController.text.replaceAll(',', '.')) ?? 0;

  void _swap() {
    setState(() {
      final tmp = _from;
      _from = _to;
      _to = tmp;
    });
    _savePrefs();
  }

  Future<void> _pickCurrency(bool isFrom) async {
    final rates = _rates;
    if (rates == null) return;
    final selected = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) =>
          CurrencyPicker(codes: rates.codes, selected: isFrom ? _from : _to),
    );
    if (selected == null) return;
    setState(() => isFrom ? _from = selected : _to = selected);
    _savePrefs();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        titleSpacing: 16,
        title: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: theme.colorScheme.primary,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                Icons.currency_exchange,
                size: 18,
                color: theme.colorScheme.onPrimary,
              ),
            ),
            const SizedBox(width: 10),
            Text(
              'MoniFlex',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w800,
                letterSpacing: -0.3,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.calculate_outlined),
            tooltip: 'Calculatrice',
            onPressed: _openCalculator,
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Actualiser les taux',
            onPressed: _loading ? null : _refresh,
          ),
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            tooltip: 'Paramètres',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute<void>(
                builder: (_) => SettingsPage(theme: widget.theme),
              ),
            ),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loading && _rates == null) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_rates == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.wifi_off, size: 64),
              const SizedBox(height: 16),
              Text(_error ?? 'Erreur inconnue', textAlign: TextAlign.center),
              const SizedBox(height: 16),
              FilledButton(onPressed: _refresh, child: const Text('Réessayer')),
            ],
          ),
        ),
      );
    }

    final rates = _rates!;
    final theme = Theme.of(context);
    final muted = theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );

    final converter = ConverterCard(
      amountController: _amountController,
      from: _from,
      to: _to,
      result: rates.convert(_amount, _from, _to),
      unitRate: rates.convert(1, _from, _to),
      dailyChange: RateHistory.lastChange(
        _history?.series(_from, _to) ?? const [],
      ),
      onPickFrom: () => _pickCurrency(true),
      onPickTo: () => _pickCurrency(false),
      onSwap: _swap,
    );

    VariationCard variation({double chartHeight = 220}) => VariationCard(
      from: _from,
      to: _to,
      history: _history,
      loading: _historyLoading,
      days: _historyDays,
      onDaysChanged: _setHistoryDays,
      chartHeight: chartHeight,
    );

    final footer = Column(
      children: [
        Text(
          'Taux du ${formatDate(rates.updatedAt)}'
          '${rates.source == RatesSource.cache ? ' (hors ligne)' : ''}'
          ' · ${rates.codes.length} devises',
          textAlign: TextAlign.center,
          style: muted,
        ),
        const SizedBox(height: 4),
        DevelopedBy(
          textAlign: TextAlign.center,
          style: muted?.copyWith(fontWeight: FontWeight.w600),
        ),
      ],
    );

    final banner = rates.source == RatesSource.bundled
        ? _FallbackBanner(date: formatDate(rates.updatedAt))
        : null;

    return RefreshIndicator(
      onRefresh: _refresh,
      child: LayoutBuilder(
        builder: (context, constraints) {
          // Ordinateur / tablette : convertisseur à gauche, graphique à droite.
          if (constraints.maxWidth >= 900) {
            return ListView(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
              children: [
                Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 1180),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(
                          width: 400,
                          child: Column(
                            children: [
                              const LiveClock(),
                              const SizedBox(height: 12),
                              if (banner != null) ...[
                                banner,
                                const SizedBox(height: 16),
                              ],
                              converter,
                              const SizedBox(height: 20),
                              footer,
                            ],
                          ),
                        ),
                        const SizedBox(width: 24),
                        Expanded(child: variation(chartHeight: 300)),
                      ],
                    ),
                  ),
                ),
              ],
            );
          }
          // Téléphone : une colonne centrée, largeur de lecture confortable.
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
            children: [
              Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 560),
                  child: Column(
                    children: [
                      const LiveClock(),
                      const SizedBox(height: 12),
                      if (banner != null) ...[
                        banner,
                        const SizedBox(height: 16),
                      ],
                      converter,
                      const SizedBox(height: 16),
                      variation(),
                      const SizedBox(height: 20),
                      footer,
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// Avertit que les taux affichés sont ceux livrés avec l'application.
class _FallbackBanner extends StatelessWidget {
  final String date;

  const _FallbackBanner({required this.date});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final fg = isDark ? Colors.orange.shade200 : Colors.orange.shade900;
    return Card(
      color: isDark
          ? Colors.orange.shade900.withValues(alpha: 0.4)
          : Colors.orange.shade50,
      child: ListTile(
        leading: Icon(Icons.warning_amber_rounded, color: fg),
        title: Text(
          'Taux de référence du $date',
          style: TextStyle(color: fg, fontWeight: FontWeight.bold),
        ),
        subtitle: Text(
          'Pas de connexion : ces taux peuvent être dépassés. '
          'Connecte-toi pour les mettre à jour.',
          style: TextStyle(color: fg),
        ),
      ),
    );
  }
}

/// Liste des devises avec barre de recherche (code ou nom).
class CurrencyPicker extends StatefulWidget {
  final List<String> codes;
  final String selected;

  const CurrencyPicker({
    super.key,
    required this.codes,
    required this.selected,
  });

  @override
  State<CurrencyPicker> createState() => _CurrencyPickerState();
}

class _CurrencyPickerState extends State<CurrencyPicker> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final q = normalizeSearch(_query.trim());
    final filtered = widget.codes
        .where(
          (c) =>
              c.toLowerCase().contains(q) ||
              normalizeSearch(currencyName(c)).contains(q),
        )
        .toList();

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: TextField(
            autofocus: true,
            decoration: const InputDecoration(
              hintText: 'Rechercher une devise (ex : euro, XAF, yen)',
              prefixIcon: Icon(Icons.search),
              border: OutlineInputBorder(),
            ),
            onChanged: (v) => setState(() => _query = v),
          ),
        ),
        if (filtered.isEmpty)
          const Padding(
            padding: EdgeInsets.all(24),
            child: Text('Aucune devise trouvée.'),
          ),
        Expanded(
          child: ListView.builder(
            itemCount: filtered.length,
            itemBuilder: (_, i) {
              final code = filtered[i];
              return ListTile(
                leading: Text(
                  currencyFlag(code),
                  style: const TextStyle(fontSize: 28),
                ),
                title: Text(code),
                subtitle: Text(currencyName(code)),
                selected: code == widget.selected,
                trailing: code == widget.selected
                    ? const Icon(Icons.check)
                    : null,
                onTap: () => Navigator.pop(context, code),
              );
            },
          ),
        ),
      ],
    );
  }
}
