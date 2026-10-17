import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'data/currencies.dart';
import 'services/rates_service.dart';

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
  final _service = RatesService();
  final _amountController = TextEditingController(text: '1');

  ExchangeRates? _rates;
  String? _error;
  bool _loading = true;
  String _from = 'EUR';
  String _to = 'XAF';

  @override
  void initState() {
    super.initState();
    _loadPrefs();
    _loadRates();
    _amountController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  Future<void> _loadPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _from = prefs.getString('from') ?? _from;
      _to = prefs.getString('to') ?? _to;
    });
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
      setState(() => _rates = rates);
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

  String _format(double value) {
    if (value == 0) return '0';
    final decimals = value.abs() >= 1 ? 2 : 6;
    final parts = value.toStringAsFixed(decimals).split('.');
    final intPart = parts[0].replaceAllMapped(
      RegExp(r'(\d)(?=(\d{3})+$)'),
      (m) => '${m[1]} ',
    );
    return parts.length > 1 ? '$intPart,${parts[1]}' : intPart;
  }

  String _formatDate(DateTime d) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(d.day)}/${two(d.month)}/${d.year} à ${two(d.hour)}h${two(d.minute)}';
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
            onPressed: _loading ? null : _loadRates,
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
              FilledButton(
                onPressed: _loadRates,
                child: const Text('Réessayer'),
              ),
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
      onRefresh: _loadRates,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (rates.source == RatesSource.bundled) ...[
            _FallbackBanner(date: _formatDate(rates.updatedAt)),
            const SizedBox(height: 16),
          ],
          TextField(
            controller: _amountController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
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
                    '${_format(_amount)} $_from =',
                    style: theme.textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  FittedBox(
                    child: Text(
                      '${_format(result)} $_to',
                      style: theme.textTheme.displaySmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text('1 $_from = ${_format(unitRate)} $_to'),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Taux mis à jour le ${_formatDate(rates.updatedAt)}'
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
    final q = _query.toLowerCase();
    final filtered = widget.codes
        .where(
          (c) =>
              c.toLowerCase().contains(q) ||
              currencyName(c).toLowerCase().contains(q),
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
