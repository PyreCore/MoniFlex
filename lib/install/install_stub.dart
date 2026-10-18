import 'package:flutter/foundation.dart';

/// Hors navigateur : l'app est déjà installée, rien n'est proposé.
class InstallSupport {
  static bool get available => false;
  static bool get isIos => false;
  static bool get canPrompt => false;
  static Future<bool> prompt() async => false;
  static void onChange(VoidCallback callback) {}
}
