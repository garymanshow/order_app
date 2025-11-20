// lib/services/delivery_conditions_service.dart
import 'package:http/http.dart' as http;

class DeliveryCondition {
  final String city;
  final double minOrderAmount;
  final double? transportCost;

  DeliveryCondition({
    required this.city,
    required this.minOrderAmount,
    this.transportCost,
  });
}

class DeliveryConditionsService {
  final String _deliveryUrl =
      'https://docs.google.com/spreadsheets/d/16LQhpJgAduO-g7V5pl9zXNuvPMUzs0vwoHZJlz_FXe8/gviz/tq?tqx=out:csv&gid=1509336401';

  String _clean(String s) {
    s = s.trim().replaceAll('\r', '').replaceAll('\n', '');
    if (s.length >= 2 && s.startsWith('"') && s.endsWith('"')) {
      return s.substring(1, s.length - 1);
    }
    return s;
  }

  Future<List<DeliveryCondition>> fetchConditions() async {
    print('DEBUG: Запрос условий доставки по URL: $_deliveryUrl');

    final response = await http.get(Uri.parse(_deliveryUrl));
    if (response.statusCode != 200) {
      print('ERROR: Статус ответа: ${response.statusCode}');
      throw Exception('Не удалось загрузить условия доставки');
    }

    print('DEBUG: Ответ от Google Sheets:\n${response.body}');

    final lines = response.body.split('\n');
    print('DEBUG: Всего строк в ответе: ${lines.length}');

    final List<DeliveryCondition> conditions = [];

    for (int i = 1; i < lines.length; i++) {
      final line = lines[i].trim();
      if (line.isEmpty) continue;

      final columns = line.split(',');
      if (columns.length < 2) continue;

      final city = _clean(columns[0]);
      final minOrderStr = _clean(columns[1]);
      final transportStr = columns.length > 2 ? _clean(columns[2]) : '';

      if (city.isEmpty) continue;

      final minOrder = double.tryParse(minOrderStr) ?? 0.0;
      final transport =
          transportStr.isNotEmpty ? double.tryParse(transportStr) : null;

      conditions.add(DeliveryCondition(
        city: city,
        minOrderAmount: minOrder,
        transportCost: transport,
      ));

      print(
          'DEBUG: Добавлено условие — Город: "$city", Мин.заказ: $minOrder, Транспорт: $transport');
    }

    print('DEBUG: Всего загружено условий доставки: ${conditions.length}');
    return conditions;
  }
}
