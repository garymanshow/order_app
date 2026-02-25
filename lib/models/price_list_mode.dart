// lib/models/price_list_mode.dart
enum PriceListMode { full, byCategory, contractOnly }

extension PriceListModeExtension on PriceListMode {
  String get label {
    switch (this) {
      case PriceListMode.full:
        return 'Полный';
      case PriceListMode.byCategory:
        return 'Категории';
      case PriceListMode.contractOnly:
        return 'Договор';
    }
  }

  static PriceListMode fromString(String value) {
    return PriceListMode.values.firstWhere(
      (e) => e.name == value,
      orElse: () => PriceListMode.full,
    );
  }
}
