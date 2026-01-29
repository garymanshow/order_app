// lib/services/clients_service.dart
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../models/client.dart';
import './google_sheets_service.dart';

class ClientsService {
  Future<List<Client>> fetchClientsByPhone(String phone) async {
    print('📞 Запрос клиентов для телефона: $phone');

    final service = GoogleSheetsService(dotenv.env['SPREADSHEET_ID']!);
    await service.init();

    // Читаем всех клиентов из листа "Клиенты"
    final allClients = await service.read(sheetName: 'Клиенты');
    print('📋 Всего клиентов в таблице: ${allClients.length}');

    // Фильтруем по телефону (точное совпадение)
    final filtered = allClients.where((row) {
      final tablePhone = row['Телефон']?.toString().trim() ?? '';
      return tablePhone == phone;
    }).toList();

    return filtered.map((row) {
      // Гарантируем, что телефон начинается с '+'
      String normalizedPhone = phone.startsWith('+') ? phone : '+$phone';

      // 🔥 Исправление: используем правильные параметры из модели Client
      return Client(
        phone: normalizedPhone,
        name: row['Клиент']?.toString() ?? '',
        client: row['Клиент']?.toString(), // ← правильное поле
        firm: row['ФИРМА']?.toString(),
        postalCode: row['Почтовый индекс']?.toString(),
        // 🔥 Исправление: парсим boolean значение
        legalEntity: _parseBool(row['Юридическое лицо']?.toString()),
        city: row['Город']?.toString(),
        // 🔥 Исправление: deliveryAddress вместо address
        deliveryAddress: row['Адрес доставки']?.toString(),
        delivery: _parseBool(row['Доставка']?.toString()),
        comment: row['Комментарий']?.toString(),
        latitude: _parseDouble(row['latitude']?.toString()),
        longitude: _parseDouble(row['longitude']?.toString()),
        // 🔥 Исправление: конвертируем int? в double?
        discount: _parseDiscount(row['Скидка']?.toString() ?? '')?.toDouble(),
        minOrderAmount:
            double.tryParse(row['Сумма миним.заказа']?.toString() ?? '0') ??
                0.0,
        // transportCost убран - его нет в модели
      );
    }).toList();
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

  // 🔥 Добавьте недостающие вспомогательные методы
  static double? _parseDouble(String? value) {
    if (value == null || value.isEmpty) return null;
    return double.tryParse(value);
  }

  static bool? _parseBool(String? value) {
    if (value == null) return null;
    final str = value.toLowerCase().trim();
    return str == 'true' || str == '1' || str == 'да' || str == 'yes';
  }
}
