// lib/services/employees_service.dart
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../models/employee.dart';
import 'google_sheets_service.dart___';

class EmployeesService {
  Future<Employee?> fetchEmployeeByPhone(String phone) async {
    print('📞 Поиск сотрудника по телефону: $phone');

    final service = GoogleSheetsService(dotenv.env['SPREADSHEET_ID']!);
    await service.init();

    // Читаем всех сотрудников из листа "Сотрудники"
    final allEmployees = await service.read(sheetName: 'Сотрудники');
    print('📋 Всего сотрудников в таблице: ${allEmployees.length}');

    // Ищем по телефону (точное совпадение)
    for (final row in allEmployees) {
      final tablePhone = row['Телефон']?.toString().trim() ?? '';
      //print('  Проверка: "$tablePhone" == "$phone" ? ${tablePhone == phone}');

      if (tablePhone == phone) {
        final name = row['Сотрудник']?.toString() ?? 'Сотрудник';
        final role = row['Роль']?.toString() ?? 'Employee';

        print('✅ Найден сотрудник: $name ($role)');
        return Employee(phone: phone, name: name, role: role);
      }
    }

    print('❌ Сотрудник не найден');
    return null;
  }
}
