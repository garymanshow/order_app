// lib/services/clients_service.dart
import 'package:http/http.dart' as http;
import '../models/user.dart';
// ← зависимость от нового сервиса

class ClientsService {
  final String _clientsUrl =
      'https://docs.google.com/spreadsheets/d/16LQhpJgAduO-g7V5pl9zXNuvPMUzs0vwoHZJlz_FXe8/gviz/tq?tqx=out:csv&gid=303609508';

  String _clean(String s) {
    s = s.trim().replaceAll('\r', '').replaceAll('\n', '');
    if (s.length >= 2 && s.startsWith('"') && s.endsWith('"')) {
      return s.substring(1, s.length - 1);
    }
    return s;
  }

  // Извлекает число из строки вида "10,00%" или "5%"
  int? _parseDiscount(String raw) {
    if (raw.isEmpty) return null;
    final cleaned = raw.replaceAll(RegExp(r'[^\d,]'), '');
    if (cleaned.isEmpty) return null;
    final normalized = cleaned.replaceAll(',', '.');
    try {
      return double.parse(normalized).toInt();
    } catch (e) {
      return null;
    }
  }

  // умный парсер с учетом кавычек
  List<String> _parseCsvLine(String line) {
    List<String> fields = [];
    bool inQuotes = false;
    StringBuffer current = StringBuffer();

    for (int i = 0; i < line.length; i++) {
      String char = line[i];
      String nextChar = i + 1 < line.length ? line[i + 1] : '';

      if (char == '"' && !inQuotes) {
        inQuotes = true;
      } else if (char == '"' && inQuotes && nextChar == '"') {
        // Экранированная кавычка (не используется в Google Sheets, но для надёжности)
        current.write('"');
        i++; // пропустить следующую кавычку
      } else if (char == '"' && inQuotes) {
        inQuotes = false;
      } else if (char == ',' && !inQuotes) {
        fields.add(current.toString());
        current.clear();
      } else {
        current.write(char);
      }
    }
    fields.add(current.toString());
    return fields.map((f) => f.trim()).toList();
  }

  Future<List<Client>> fetchClientsByPhone(String phone) async {
    final response = await http.get(Uri.parse(_clientsUrl));
    if (response.statusCode != 200) return [];

    final lines = response.body.split('\n');
    final List<Client> clients = [];

    for (int i = 1; i < lines.length; i++) {
      final line = lines[i].trim();
      if (line.isEmpty) continue;

      final columns = _parseCsvLine(line);
      if (columns.length < 13) continue;

      final clientPhone = _clean(columns[3]);
      if (clientPhone != phone) continue;

      final name = _clean(columns[0]);
      final city = _clean(columns[5]);
      final address = _clean(columns[6]); // Адрес доставки
      final legalEntity = _clean(columns[4]); // Юридическое лицо
      final discountRaw = _clean(columns[11]);
      final minOrderStr = _clean(columns[12]);

      final discount = _parseDiscount(discountRaw);
      final minOrder = double.tryParse(minOrderStr.replaceAll(' ', '')) ?? 0.0;

      clients.add(Client(
        phone: phone,
        name: name,
        discount: discount,
        minOrderAmount: minOrder,
        address: address,
        legalEntity: legalEntity,
      ));
    }
    return clients;
  }
}
