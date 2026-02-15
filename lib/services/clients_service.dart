// lib/services/clients_service.dart
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../models/client.dart';
import './google_sheets_service.dart';
import '../utils/parsing_utils.dart';

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

      // 🔥 ИСПРАВЛЕНО: УДАЛЕН ПАРАМЕТР client
      return Client(
        phone: normalizedPhone,
        name: row['Клиент']?.toString(), // ← имя клиента в параметре name
        firm: row['ФИРМА']?.toString(),
        postalCode: row['Почтовый индекс']?.toString(),
        legalEntity:
            ParsingUtils.parseBool(row['Юридическое лицо']?.toString()),
        city: row['Город']?.toString(),
        deliveryAddress: row['Адрес доставки']?.toString(),
        delivery: ParsingUtils.parseBool(row['Доставка']?.toString()),
        comment: row['Комментарий']?.toString(),
        latitude: ParsingUtils.parseDouble(row['latitude']?.toString()),
        longitude: ParsingUtils.parseDouble(row['longitude']?.toString()),
        discount: ParsingUtils.parseDiscount(row['Скидка']?.toString() ?? ''),
        minOrderAmount:
            double.tryParse(row['Сумма миним.заказа']?.toString() ?? '0') ??
                0.0,
      );
    }).toList();
  }
}
