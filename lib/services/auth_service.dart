// lib/services/auth_service.dart
import '../models/user.dart';
import './employees_service.dart';
import './clients_service.dart';

class AuthService {
  Future<User?> authenticate(String phone) async {
    // Сначала проверяем сотрудников
    final employee = await EmployeesService().fetchEmployeeByPhone(phone);
    if (employee != null) return employee;

    // Затем клиентов — берём первую запись (если есть)
    final clients = await ClientsService().fetchClientsByPhone(phone);
    return clients.isNotEmpty ? clients.first : null;
  }
}
