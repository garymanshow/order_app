// lib/models/user.dart

// 1. User — обычный абстрактный класс с конструктором
abstract class User {
  final String phone;
  final String name;

  // 2. Обязательно: конструктор с параметрами
  User({
    required this.phone,
    required this.name,
  });
}

// 3. Client — наследуется от User и вызывает super(...)
class Client extends User {
  final int? discount;
  final double minOrderAmount;
  final double? transportCost;
  final String address; // Адрес доставки (столбец 6)
  final String legalEntity; // Юридическое лицо (столбец 4)

  Client({
    required String phone, // ← явно указываем тип
    required String name, // ← явно указываем тип
    this.discount,
    this.minOrderAmount = 0.0,
    this.transportCost,
    this.address = '',
    this.legalEntity = '',
  }) : super(phone: phone, name: name); // ← вызываем конструктор super

  factory Client.empty() => Client(
        phone: '',
        name: 'Гость',
        discount: null,
        address: '',
        legalEntity: '',
      );
}

// Если есть Employee — сделайте аналогично:
class Employee extends User {
  final String role;

  Employee({
    required String phone,
    required String name,
    required this.role,
  }) : super(phone: phone, name: name);
}
