// Installation de l'app web (PWA) depuis le navigateur. Sur les autres
// plateformes (Android, iOS natifs…), l'app est déjà installée : rien à faire.
export 'install_stub.dart' if (dart.library.js_interop) 'install_web.dart';
