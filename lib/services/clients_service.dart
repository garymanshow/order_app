// lib/services/clients_service.dart
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../models/user.dart';
import './google_sheets_service.dart'; // ← ваш новый сервис

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
      print('  Проверка: "$tablePhone" == "$phone" ? ${tablePhone == phone}');
      return tablePhone == phone;
    }).toList();

    print('✅ Найдено совпадений: ${filtered.length}');

    return filtered.map((row) {
      return Client(
        phone: phone,
        name: row['Клиент']?.toString() ?? '',
        address: row['Адрес доставки']?.toString() ?? '',
        discount: _parseDiscount(row['Скидка']?.toString() ?? ''),
        minOrderAmount:
            double.tryParse(row['Сумма миним.заказа']?.toString() ?? '0') ??
                0.0,
        transportCost: null,
        legalEntity: row['Юридическое лицо']?.toString() ?? '',
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
}
