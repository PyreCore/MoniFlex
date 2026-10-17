import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'data/currencies.dart';
import 'services/history_service.dart';
import 'services/rates_service.dart';
import 'utils/format.dart';
import 'widgets/variation_card.dart';

void main() => runApp(const ConvertisseurApp());

class ConvertisseurApp extends StatelessWidget {
  const ConvertisseurApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Convertisseur de devises',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(colorSchemeSeed: Colors.teal, useMaterial3: true),
      darkTheme: ThemeData(
        colorSchemeSeed: Colors.teal,
        brightness: Brightness.dark,
        useMaterial3: true,
      ),
      home: const ConverterPage(),
    );
  }
}

class ConverterPage extends StatefulWidget {
  const ConverterPage({super.key});

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
    return Scaffold(
      appBar: AppBar(
        title: const Text('Convertisseur de devises'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Actualiser les taux',
            onPressed: _loading ? null : _refresh,
          ),
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
    final result = rates.convert(_amount, _from, _to);
    final unitRate = rates.convert(1, _from, _to);
    final theme = Theme.of(context);

    return RefreshIndicator(
      onRefresh: _refresh,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (rates.source == RatesSource.bundled) ...[
            _FallbackBanner(date: formatDate(rates.updatedAt)),
            const SizedBox(height: 16),
          ],
          TextField(
            controller: _amountController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [
              // Chiffres et un seul séparateur décimal (« 1,5,3 » refusé).
              TextInputFormatter.withFunction(
                (old, value) =>
                    RegExp(r'^\d*[.,]?\d*$').hasMatch(value.text) ? value : old,
              ),
              LengthLimitingTextInputFormatter(15),
            ],
            style: theme.textTheme.headlineSmall,
            decoration: const InputDecoration(
              labelText: 'Montant',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          _CurrencyTile(
            label: 'De',
            code: _from,
            onTap: () => _pickCurrency(true),
          ),
          Center(
            child: IconButton.filledTonal(
              icon: const Icon(Icons.swap_vert),
              tooltip: 'Inverser',
              onPressed: _swap,
            ),
          ),
          _CurrencyTile(
            label: 'Vers',
            code: _to,
            onTap: () => _pickCurrency(false),
          ),
          const SizedBox(height: 24),
          Card(
            color: theme.colorScheme.primaryContainer,
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  Text(
                    '${formatAmount(_amount)} $_from =',
                    style: theme.textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  FittedBox(
                    child: Text(
                      '${formatAmount(result)} $_to',
                      style: theme.textTheme.displaySmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text('1 $_from = ${formatAmount(unitRate)} $_to'),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          VariationCard(
            from: _from,
            to: _to,
            history: _history,
            loading: _historyLoading,
            days: _historyDays,
            onDaysChanged: _setHistoryDays,
          ),
          const SizedBox(height: 16),
          Text(
            'Taux mis à jour le ${formatDate(rates.updatedAt)}'
            '${rates.source == RatesSource.cache ? ' (hors ligne)' : ''}',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall,
          ),
          Text(
            '${rates.codes.length} devises disponibles',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall,
          ),
        ],
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

class _CurrencyTile extends StatelessWidget {
  final String label;
  final String code;
  final VoidCallback onTap;

  const _CurrencyTile({
    required this.label,
    required this.code,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        onTap: onTap,
        leading: Text(currencyFlag(code), style: const TextStyle(fontSize: 32)),
        title: Text('$label : $code'),
        subtitle: Text(currencyName(code)),
        trailing: const Icon(Icons.arrow_drop_down),
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
