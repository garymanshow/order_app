// lib/models/price_item.dart
class PriceItem {
  final String id;
  final String name;
  final double price;
  final int multiplicity;
  final String? photoUrl;
  final String? description;
  final String? photoSource; // 'url' или 'drive'

  PriceItem({
    required this.id,
    required this.name,
    required this.price,
    required this.multiplicity,
    this.photoUrl,
    this.description,
    this.photoSource,
  });

  // Создание из данных Google Sheets
  factory PriceItem.fromMap(Map<String, dynamic> map) {
    return PriceItem(
      id: map['ID']?.toString() ?? '',
      name: map['Название']?.toString() ?? '',
      price: double.tryParse(map['Цена']?.toString() ?? '0') ?? 0.0,
      multiplicity: int.tryParse(map['Кратность']?.toString() ?? '1') ?? 1,
      photoUrl: map['Фото']?.toString().isNotEmpty == true
          ? map['Фото']?.toString()
          : null,
      description: map['Описание']?.toString().isNotEmpty == true
          ? map['Описание']?.toString()
          : null,
      photoSource: _detectPhotoSource(map['Фото']?.toString()),
    );
  }

  static String? _detectPhotoSource(String? url) {
    if (url == null || url.isEmpty) return null;
    return url.contains('drive.google.com') ? 'drive' : 'url';
  }

  // Преобразование в данные для Google Sheets
  Map<String, dynamic> toMap() {
    return {
      'ID': id,
      'Название': name,
      'Цена': price.toString(),
      'Кратность': multiplicity.toString(),
      'Фото': photoUrl ?? '',
      'Описание': description ?? '',
    };
  }
}
