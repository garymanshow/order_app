// lib/models/user.dart
class User {
  final String? phone;
  final String? name;
  final double? discount;
  final double? minOrderAmount;

  User({
    this.phone,
    this.name,
    this.discount,
    this.minOrderAmount,
  });

  // 🔥 ДОБАВЬТЕ МЕТОД fromJson
  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      phone: json['phone'] as String?,
      name: json['name'] as String?,
      discount: json['discount'] as double?,
      minOrderAmount: json['minOrderAmount'] as double?,
    );
  }

  // 🔥 ДОБАВЬТЕ МЕТОД toJson
  Map<String, dynamic> toJson() {
    return {
      'phone': phone,
      'name': name,
      'discount': discount,
      'minOrderAmount': minOrderAmount,
    };
  }
}
