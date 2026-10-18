import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'install_support.dart';

/// Lance l'installation : fenêtre de Chrome si elle est disponible,
/// sinon les étapes à suivre (toujours le cas sur iPhone).
Future<void> startInstall(BuildContext context) async {
  // Sur iPhone, toujours les étapes : le navigateur n'y propose jamais de
  // fenêtre d'installation.
  if (!InstallSupport.isIos && InstallSupport.canPrompt) {
    await InstallSupport.prompt();
    return;
  }
  await showInstallHelp(context, ios: InstallSupport.isIos);
}

/// Étapes pour ajouter MoniFlex à l'écran d'accueil.
Future<void> showInstallHelp(BuildContext context, {required bool ios}) {
  final steps = ios
      ? const [
          (
            Icons.ios_share,
            'Appuie sur Partager',
            'Dans Chrome : en haut à droite, dans la barre d\'adresse. '
                'Dans Safari : en bas de l\'écran.',
          ),
          (
            Icons.add_box_outlined,
            'Choisis « Sur l\'écran d\'accueil »',
            'Fais défiler le menu vers le bas si tu ne le vois pas.',
          ),
          (
            Icons.check_circle_outline,
            'Appuie sur « Ajouter »',
            'L\'icône MoniFlex apparaît sur ton écran d\'accueil.',
          ),
        ]
      : const [
          (
            Icons.more_vert,
            'Ouvre le menu du navigateur',
            'Sur téléphone : ⋮ en haut à droite. Sur ordinateur : l\'icône '
                '⊕ dans la barre d\'adresse.',
          ),
          (
            Icons.install_mobile,
            'Choisis « Installer l\'application »',
            'Ou « Ajouter à l\'écran d\'accueil » selon le navigateur.',
          ),
          (
            Icons.check_circle_outline,
            'Confirme avec « Installer »',
            'MoniFlex s\'ouvre ensuite comme une application.',
          ),
        ];

  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    useSafeArea: true,
    // Hauteur selon le contenu ; défile si l'écran est trop petit
    // (téléphone à l'horizontale…).
    isScrollControlled: true,
    builder: (context) {
      final theme = Theme.of(context);
      return SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Installer MoniFlex',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              ios
                  ? 'Sur iPhone, l\'installation se fait depuis le menu '
                        'Partager (Apple ne permet pas de bouton direct).'
                  : 'En 3 étapes depuis ton navigateur :',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),
            for (final (i, (icon, title, detail)) in steps.indexed)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: CircleAvatar(
                  backgroundColor: theme.colorScheme.primaryContainer,
                  foregroundColor: theme.colorScheme.onPrimaryContainer,
                  child: Icon(icon, size: 20),
                ),
                title: Text('${i + 1}. $title'),
                subtitle: Text(detail),
              ),
            const SizedBox(height: 8),
            Text(
              'Une fois installée, MoniFlex s\'ouvre en plein écran et '
              'fonctionne même sans connexion.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      );
    },
  );
}

/// Bandeau « Installer MoniFlex », affiché dans le navigateur tant que l'app
/// n'est pas installée et que l'utilisateur ne l'a pas fermé.
class InstallBanner extends StatefulWidget {
  const InstallBanner({super.key});

  @override
  State<InstallBanner> createState() => _InstallBannerState();
}

class _InstallBannerState extends State<InstallBanner> {
  static const _dismissedKey = 'installBannerDismissed';

  bool _dismissed = true;

  @override
  void initState() {
    super.initState();
    if (!InstallSupport.available) return;
    SharedPreferences.getInstance().then((prefs) {
      if (mounted) {
        setState(() => _dismissed = prefs.getBool(_dismissedKey) ?? false);
      }
    });
    // Chrome peut signaler l'installation possible (ou terminée) plus tard.
    InstallSupport.onChange(() {
      if (mounted) setState(() {});
    });
  }

  Future<void> _dismiss() async {
    setState(() => _dismissed = true);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_dismissedKey, true);
  }

  @override
  Widget build(BuildContext context) {
    if (_dismissed || !InstallSupport.available) return const SizedBox.shrink();
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: scheme.primaryContainer,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 8, 4, 8),
          child: Row(
            children: [
              Icon(Icons.install_mobile, color: scheme.onPrimaryContainer),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Installer MoniFlex',
                      style: theme.textTheme.titleSmall?.copyWith(
                        color: scheme.onPrimaryContainer,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      'Sur ton écran d\'accueil, même hors connexion',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: scheme.onPrimaryContainer,
                      ),
                    ),
                  ],
                ),
              ),
              FilledButton(
                onPressed: () => startInstall(context),
                child: const Text('Installer'),
              ),
              IconButton(
                tooltip: 'Masquer',
                onPressed: _dismiss,
                icon: Icon(Icons.close, color: scheme.onPrimaryContainer),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
