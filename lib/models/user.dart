// lib/models/user.dart
import '../utils/parsing_utils.dart';

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

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      phone: json['phone']?.toString(),
      name: json['name']?.toString(),
      discount: ParsingUtils.parseDouble(json['discount']),
      minOrderAmount: ParsingUtils.parseDouble(json['minOrderAmount']) ?? 0.0,
    );
  }

  // 🔥 toJson должен быть виртуальным для переопределения
  Map<String, dynamic> toJson() {
    return {
      'phone': phone,
      'name': name,
      'discount': discount,
      'minOrderAmount': minOrderAmount,
    };
  }
}
