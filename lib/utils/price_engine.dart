// lib/utils/price_engine.dart

class PriceResult {
  final double finalPrice;
  final String formattedPrice;

  PriceResult({required this.finalPrice, required this.formattedPrice});
}

class PriceEngine {
  /// Главный метод расчета цены
  /// [basePrice] - исходная цена из базы
  /// [markupPercent] - наценка (например, 20 для +20%)
  /// [discountPercent] - скидка от итоговой цены (например, 10 для -10%)
  /// [roundToNearest] - шаг округления (0 - без округления, 5 - до 5 рублей, 10 - до десяток)
  static PriceResult calculate({
    required double basePrice,
    double markupPercent = 0,
    double discountPercent = 0,
    int roundToNearest = 0,
  }) {
    if (basePrice <= 0) {
      return PriceResult(finalPrice: 0, formattedPrice: '0 ₽');
    }

    // 1. Применяем наценку
    double currentPrice = basePrice * (1 + markupPercent / 100);

    // 2. Применяем скидку (от суммы С НАЦЕНКОЙ)
    currentPrice = currentPrice * (1 - discountPercent / 100);

    // 3. Хитрое округление ВВЕРХ (кратно шагу)
    if (roundToNearest > 0) {
      currentPrice = _roundUpToNearest(currentPrice, roundToNearest);
    }

    // 4. Защита от отрицательных значений
    if (currentPrice < 0) currentPrice = 0;

    return PriceResult(
      finalPrice: currentPrice,
      formattedPrice: '${currentPrice.toInt()} ₽',
    );
  }

  /// Математика округления ВВЕРХ до ближайшего кратного
  /// Пример: 112 руб с шагом 5 -> 115 руб
  /// Пример: 101 руб с шагом 10 -> 110 руб
  static double _roundUpToNearest(double value, int step) {
    if (step <= 0) return value;
    return (value / step).ceilToDouble() * step;
  }
}
