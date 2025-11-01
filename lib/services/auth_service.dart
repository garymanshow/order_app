// lib/services/auth_service.dart
import '../models/user.dart';
import './employees_service.dart';
import './clients_service.dart';

class AuthService {
  Future<User?> authenticate(String phone) async {
    final employee = await EmployeesService().fetchEmployeeByPhone(phone);
    if (employee != null) return employee;

    final client = await ClientsService().fetchClientByPhone(phone);
    return client;
  }
}
