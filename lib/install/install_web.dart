import 'dart:js_interop';

import 'package:flutter/foundation.dart';

/// Objet `window.moniflexInstall` défini dans web/index.html.
@JS('moniflexInstall')
external _Install? get _install;

extension type _Install(JSObject _) implements JSObject {
  external bool isStandalone();
  external bool isIos();
  external bool canPrompt();
  external bool get installed;
  external JSPromise<JSString> prompt();
  external void onChange(JSFunction callback);
}

/// Dans le navigateur : propose d'installer l'app tant qu'elle ne l'est pas.
class InstallSupport {
  /// Vrai si l'app est ouverte dans un onglet (pas encore installée).
  static bool get available {
    final i = _install;
    return i != null && !i.isStandalone() && !i.installed;
  }

  static bool get isIos => _install?.isIos() ?? false;

  /// Chrome peut-il afficher sa fenêtre d'installation ?
  static bool get canPrompt => _install?.canPrompt() ?? false;

  /// Ouvre la fenêtre d'installation ; vrai si l'utilisateur accepte.
  static Future<bool> prompt() async {
    final i = _install;
    if (i == null) return false;
    final outcome = (await i.prompt().toDart).toDart;
    return outcome == 'accepted';
  }

  static void onChange(VoidCallback callback) =>
      _install?.onChange(callback.toJS);
}
