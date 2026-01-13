// lib/services/auth_service.dart
import '../models/user.dart';
import './sheet_all_api_service.dart';

class AuthService {
  final SheetAllApiService _service = SheetAllApiService();

  /// Аутентификация по телефону:
  /// 1. Сначала ищем в листе "Сотрудники"
  /// 2. Если не найдено — ищем в листе "Клиенты"
  Future<User?> authenticate(String phone) async {
    // 🔍 1. Поиск в "Сотрудники"
    try {
      final employees = await _service.read(sheetName: 'Сотрудники', filters: [
        {'column': 'Телефон', 'value': phone}
      ]);

      if (employees.isNotEmpty) {
        final row = employees.first as Map<String, dynamic>;
        return Employee(
          phone: row['Телефон']?.toString() ?? phone,
          name: row['Сотрудник']?.toString() ?? 'Сотрудник',
          role: row['Роль']?.toString() ?? 'Employee',
        );
      }
    } catch (e) {
      // Игнорируем ошибку — возможно, лист "Сотрудники" не существует или нет доступа
      // Но продолжаем поиск в "Клиентах"
    }

    // 🔍 2. Поиск в "Клиенты"
    try {
      final clients = await _service.read(sheetName: 'Клиенты', filters: [
        {'column': 'Телефон', 'value': phone}
      ]);

      if (clients.isNotEmpty) {
        final row = clients.first as Map<String, dynamic>;
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
      // Логируем ошибку, но не прерываем
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
