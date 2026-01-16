import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../models/user.dart';
import './google_sheets_service.dart'; // ← новый сервис

class AuthService {
  /// Аутентификация по телефону:
  /// 1. Сначала ищем в листе "Сотрудники"
  /// 2. Если не найдено — ищем в листе "Клиенты"
  Future<User?> authenticate(String phone) async {
    final service = GoogleSheetsService(dotenv.env['SPREADSHEET_ID']!);
    await service.init();

    // 🔍 1. Поиск в "Сотрудники"
    try {
      final employees = await service.read(
        sheetName: 'Сотрудники',
        filters: [
          {'column': 'Телефон', 'value': phone}
        ],
      );

      if (employees.isNotEmpty) {
        final row = employees.first;
        return Employee(
          phone: row['Телефон']?.toString() ?? phone,
          name: row['Сотрудник']?.toString() ?? 'Сотрудник',
          role: row['Роль']?.toString() ?? 'Employee',
        );
      }
    } catch (e) {
      print('Ошибка поиска сотрудника: $e');
      // Продолжаем поиск в "Клиентах"
    }

    // 🔍 2. Поиск в "Клиенты"
    try {
      final clients = await service.read(
        sheetName: 'Клиенты',
        filters: [
          {'column': 'Телефон', 'value': phone}
        ],
      );

      if (clients.isNotEmpty) {
        final row = clients.first;
        return Client(
          phone: row['Телефон']?.toString() ?? phone,
          name: row['Клиент']?.toString() ?? 'Клиент',
          address: row['Адрес доставки']?.toString() ?? '',
          discount: _parseDiscount(row['Скидка']?.toString() ?? ''),
          minOrderAmount:
              double.tryParse(row['Сумма миним.заказа']?.toString() ?? '0') ??
                  0.0,
          transportCost: null,
        );
      }
    } catch (e) {
      print('Ошибка поиска клиента: $e');
    }

    return null;
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
