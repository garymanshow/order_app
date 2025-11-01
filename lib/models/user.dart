// lib/models/user.dart
abstract class User {
  final String phone;
  final String name;
  User({required this.phone, required this.name});
}

class Employee extends User {
  final String role;
  Employee({required super.phone, required super.name, required this.role});
}

class Client extends User {
  final int? discount;
  Client({required super.phone, required super.name, this.discount});
}
