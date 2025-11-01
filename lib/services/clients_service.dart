// lib/services/clients_service.dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/user.dart';

class ClientsService {
  final String _url =
      'https://docs.google.com/spreadsheets/d/16LQhpJgAduO-g7V5pl9zXNuvPMUzs0vwoHZJlz_FXe8/gviz/tq?tqx=out:csv&gid=303609508';

  String _clean(String s) {
    s = s.trim().replaceAll('\r', '').replaceAll('\n', '');
    if (s.length >= 2 && s.startsWith('"') && s.endsWith('"')) {
      return s.substring(1, s.length - 1);
    }
    return s;
  }

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

  Future<Client?> fetchClientByPhone(String phone) async {
    final response = await http.get(Uri.parse(_url));
    if (response.statusCode != 200) return null;

    final lines = response.body.split('\n');
    for (int i = 1; i < lines.length; i++) {
      final line = lines[i].trim();
      if (line.isEmpty) continue;

      final columns = line.split(',');
      if (columns.length < 12) continue;

      final clientPhone = _clean(columns[3]);
      if (clientPhone != phone) continue;

      final name = _clean(columns[0]);
      final discountRaw = columns.length > 11 ? _clean(columns[11]) : '';
      final discount = _parseDiscount(discountRaw);

      return Client(phone: phone, name: name, discount: discount);
    }
    return null;
  }
}
