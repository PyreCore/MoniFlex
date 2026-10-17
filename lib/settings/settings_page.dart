import 'package:flutter/material.dart';

import '../widgets/developed_by.dart';
import 'theme_controller.dart';

/// Version affichée : numéro de l'app et commit, fournis au build
/// (--dart-define) par le déploiement automatique.
const appVersion = String.fromEnvironment('APP_VERSION', defaultValue: '1.1.0');
const appCommit = String.fromEnvironment('APP_COMMIT', defaultValue: 'dev');

class SettingsPage extends StatelessWidget {
  final ThemeController theme;

  const SettingsPage({super.key, required this.theme});

  static const _themes = [
    (ThemeMode.system, 'Comme le téléphone', Icons.brightness_auto),
    (ThemeMode.light, 'Clair', Icons.light_mode),
    (ThemeMode.dark, 'Sombre', Icons.dark_mode),
  ];

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Paramètres')),
      body: ListView(
        children: [
          const _Section('Apparence'),
          ValueListenableBuilder(
            valueListenable: theme,
            builder: (context, mode, _) => RadioGroup<ThemeMode>(
              groupValue: mode,
              onChanged: (m) => theme.set(m!),
              child: Column(
                children: [
                  for (final (value, label, icon) in _themes)
                    RadioListTile<ThemeMode>(
                      value: value,
                      title: Text(label),
                      secondary: Icon(icon),
                    ),
                ],
              ),
            ),
          ),
          const Divider(),
          const _Section('À propos'),
          const ListTile(
            leading: Icon(Icons.currency_exchange),
            title: Text('MoniFlex'),
            subtitle: Text('Version $appVersion ($appCommit)'),
          ),
          const ListTile(leading: Icon(Icons.code), title: DevelopedBy()),
          ListTile(
            leading: const Icon(Icons.info_outline),
            title: const Text('Sources des taux'),
            subtitle: Text(
              'Taux du jour : open.er-api.com\n'
              'Historique : fawazahmed0/exchange-api',
              style: t.textTheme.bodySmall,
            ),
            isThreeLine: true,
          ),
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  final String title;

  const _Section(this.title);

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 4),
      child: Text(
        title,
        style: t.textTheme.titleSmall?.copyWith(color: t.colorScheme.primary),
      ),
    );
  }
}
