// lib/services/delivery_conditions_service.dart
import 'package:flutter_dotenv/flutter_dotenv.dart';
import './google_sheets_service.dart';

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
  Future<List<DeliveryCondition>> fetchConditions() async {
    print('DEBUG: Загрузка условий доставки через Google Sheets API...');

    final service = GoogleSheetsService(dotenv.env['SPREADSHEET_ID']!);
    await service.init();

    // Читаем данные из листа "Условия доставки"
    final rawData = await service.read(sheetName: 'Условия доставки');

    final List<DeliveryCondition> conditions = [];

    for (final row in rawData) {
      final city = row['Город']?.toString().trim() ?? '';
      if (city.isEmpty) continue;

      final minOrderStr = row['Мин. заказ']?.toString() ?? '0';
      final transportStr = row['Стоимость доставки']?.toString();

      final minOrder = double.tryParse(minOrderStr) ?? 0.0;
      final transport = transportStr != null && transportStr.isNotEmpty
          ? double.tryParse(transportStr)
          : null;

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
