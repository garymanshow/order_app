// lib/services/employees_service.dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/user.dart';

class EmployeesService {
  final String _url =
      'https://docs.google.com/spreadsheets/d/16LQhpJgAduO-g7V5pl9zXNuvPMUzs0vwoHZJlz_FXe8/gviz/tq?tqx=out:csv&gid=709350020';

  String _clean(String s) {
    s = s.trim().replaceAll('\r', '').replaceAll('\n', '');
    if (s.length >= 2 && s.startsWith('"') && s.endsWith('"')) {
      return s.substring(1, s.length - 1);
    }
    return s;
  }

  Future<Employee?> fetchEmployeeByPhone(String phone) async {
    final response = await http.get(Uri.parse(_url));
    if (response.statusCode != 200) return null;

    final lines = response.body.split('\n');
    for (int i = 1; i < lines.length; i++) {
      final line = lines[i].trim();
      if (line.isEmpty) continue;

      final columns = line.split(',');
      if (columns.length < 3) continue;

      final name = _clean(columns[0]);
      final empPhone = _clean(columns[1]);
      final role = _clean(columns[2]);

      if (empPhone == phone) {
        return Employee(phone: phone, name: name, role: role);
      }
    }
    return null;
  }
}
