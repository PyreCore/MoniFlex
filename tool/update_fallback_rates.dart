// Met à jour les taux de référence livrés avec l'application.
// À lancer avant chaque version : dart run tool/update_fallback_rates.dart
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

Future<void> main() async {
  final response = await http.get(
    Uri.parse('https://open.er-api.com/v6/latest/USD'),
  );
  final json = jsonDecode(response.body) as Map<String, dynamic>;
  if (response.statusCode != 200 || json['result'] != 'success') {
    stderr.writeln('Échec : HTTP ${response.statusCode}');
    exit(1);
  }
  await File('assets/fallback_rates.json').writeAsString(response.body);
  final count = (json['rates'] as Map).length;
  stdout.writeln('$count taux enregistrés (${json['time_last_update_utc']}).');
}
