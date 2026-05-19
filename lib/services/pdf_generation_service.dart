import 'package:flutter/foundation.dart' show kIsWeb;
import '../models/nutrition_info.dart';
import '../models/product.dart';
import '../models/storage_condition.dart';
import '../utils/price_engine.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

// ==========================================
// МОДЕЛИ ДЛЯ ПЕРЕДАЧИ ДАННЫХ
// ==========================================
class PdfHeaderData {
  final String companyName;
  final String? adminEmail;
  PdfHeaderData({required this.companyName, this.adminEmail});
}

class PdfProductData {
  final Product product;
  final String categoryDescription;
  final String productDescription;
  final NutritionInfo? nutrition;
  final String compositionText;
  final List<StorageCondition> mergedStylizedStorages;
  final bool showPrice; // Скрывать для Гостя
  final String? priceInfoText; // Подсказка для Менеджера/Админа
  final String formattedPrice; // Готовая строка цены

  PdfProductData({
    required this.product,
    required this.categoryDescription,
    required this.productDescription,
    this.nutrition,
    required this.compositionText,
    required this.mergedStylizedStorages,
    this.showPrice = true,
    this.priceInfoText,
    required this.formattedPrice,
  });
}

// ==========================================
// ГЛАВНЫЙ СЕРВИС ГЕНЕРАЦИИ
// ==========================================
class PdfGenerationService {
  static pw.Font? _cachedFont;
  static pw.MemoryImage? _cachedLogo;
  static final Map<String, pw.MemoryImage> _cachedProductImages = {};

  static final _colorPrimary = PdfColor.fromHex('#5D4037');
  static final _colorSecondary = PdfColor.fromHex('#8D6E63');
  static final _colorBackground = PdfColor.fromHex('#EFEBE9');
  static final _colorText = PdfColors.brown900;
  static final _colorAccent = PdfColor.fromHex('#4CAF50'); // Зеленый для цен

  static Future<pw.Font> _loadFont() async {
    if (_cachedFont != null) return _cachedFont!;
    try {
      final fontData = await rootBundle.load('assets/fonts/Lora-Regular.ttf');
      _cachedFont = pw.Font.ttf(fontData);
      return _cachedFont!;
    } catch (e) {
      return pw.Font.helvetica(); // Фоллбэк для веба, если шрифт не прогрузился
    }
  }

  static Future<pw.MemoryImage?> _loadLogo() async {
    if (_cachedLogo != null) return _cachedLogo!;
    try {
      final logoData = await rootBundle.load('assets/images/auth/logo.webp');
      _cachedLogo = pw.MemoryImage(logoData.buffer.asUint8List());
      return _cachedLogo;
    } catch (e) {
      return null; // Если лого нет, просто не рисуем его
    }
  }

  static Future<pw.MemoryImage?> _loadProductImage(String productId) async {
    if (_cachedProductImages.containsKey(productId)) return _cachedProductImages[productId];
    try {
      final data = await rootBundle.load('assets/images/products/$productId.webp');
      final memoryImage = pw.MemoryImage(data.buffer.asUint8List());
      _cachedProductImages[productId] = memoryImage;
      return memoryImage;
    } catch (e) {
      return null; // Если фото в assets нет, просто пропускаем
    }
  }

  static Future<Uint8List> generatePdf({
    required List<PdfProductData> productsData,
    required PdfHeaderData headerData,
  }) async {
    final font = await _loadFont();
    final logo = await _loadLogo();

    final Map<String, pw.MemoryImage?> productImages = {};
    for (var prodData in productsData) {
      if (prodData.product.imageUrl != null && prodData.product.imageUrl!.isNotEmpty && _cachedProductImages[prodData.product.imageUrl!] != null) {
        productImages[prodData.product.imageUrl!] = await _loadProductImage(prodData.product.id);
      }
    }

    final pdf = pw.Document(theme: pw.ThemeData(font: font));

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (pw.Context context) {
          final widgets = <pw.Widget>[];
          widgets.add(_buildHeader(headerData, font, logo));
          
          String? lastCategoryId;
          for (int i = 0; i < productsData.length; i++) {
            final data = productsData[i];
            if (data.product.categoryId != lastCategoryId) {
              lastCategoryId = data.product.categoryId;
            }
            widgets.add(_buildProductCard(data, font, productImages[data.product.imageUrl]));
          }
          return widgets;
        },
      ),
    );

    return await pdf.save();
  }

  // ==========================================
  // ШАПКА
  // ==========================================
  static pw.Widget _buildHeader(PdfHeaderData data, pw.Font font, pw.MemoryImage? logo) {
    final currentDate = DateTime.now().toLocal().toString().split(' ')[0];
    return pw.Container(
      margin: const pw.EdgeInsets.only(bottom: 24),
      decoration: pw.BoxDecoration(borderRadius: pw.BorderRadius.all(pw.Radius.circular(8)), color: _colorPrimary),
      child: pw.Container(
        width: double.infinity,
        padding: const pw.EdgeInsets.symmetric(horizontal: 20, vertical: 15),
        child: pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.start,
          children: [
            if (logo != null)
              pw.Container(
                width: 60,
                height: 60,
                margin: const pw. EdgeInsets.only(right: 16),
                decoration: const pw.BoxDecoration(color: PdfColors.white, borderRadius: pw.BorderRadius.all(pw.Radius.circular(8))),
                child: pw.ClipRRect(child: pw.Image(logo, fit: pw.BoxFit.contain)),
              ),
            pw.Expanded(
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    data.companyName,
                    style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold, color: PdfColors.white, font: font)
                  ),
                  pw.SizedBox(height: 4),
                  pw.Text(
                    'Прайс-лист на $currentDate',
                    style: pw.TextStyle(fontSize: 12, color: PdfColors.grey400, font: font)
                  ),
                  // Выводим email ТОЛЬКО если он передан (не Гость)
                  if (data.adminEmail != null && data.adminEmail!.isNotEmpty)
                    pw.Text(
                      data.adminEmail!,
                      style: pw.TextStyle(fontSize: 11, color: PdfColors.grey300, font: font)
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ==========================================
  // КАРТОЧКА ТОВАРА (Компоновка 1/3 и 2/3)
  // ==========================================
  static pw.Widget _buildProductCard(
    PdfProductData data,
    pw.Font font,
    pw.MemoryImage? productImage,
  ) {
    final product = data.product;
    final hasPhoto = productImage != null;
    final weightStr = product.weight.isNotEmpty 
        ? 'Вес: ${product.weight} ${product.multiplicity > 1 ? '× ${product.multiplicity} шт' : '/ шт'}'
        : null;

    return pw.Container(
      margin: const pw.Margin.only(bottom: 16),
      padding: const pw.padding = const pw.EdgeInsets.all(12),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: _colorSecondary, width: 0.5),
        borderRadius: pw.BorderRadius.all(pw.Radius.circular(8)),
        color: PdfColors.white,
      ),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          // ЛЕВАЯ ЧАСТЬ (1/3) - ФОТО
          if (hasPhoto)
            pw.Expanded(
              flex: 1,
              child: pw.Container(
                height: 140,
                decoration: pw.BoxDecoration(
                  color: _colorBackground,
                  border: pw.Border.all(color: _colorSecondary, width: 0.5),
                ),
                child: pw.Image(productImage!, fit: pw.BoxFit.cover),
              ),
            ),

          if (hasPhoto) pw.SizedBox(width: 16),

          // ПРАВАЯ ЧАСТЬ (2/3) - ИНФОРМАЦИЯ
          pw.Expanded(
            flex: 2,
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                // Название
                pw.Text(
                  product.displayName,
                  style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold, color: _colorPrimary, font: font)
                ),
                pw.SizedBox(height: 8),

                // БЛОК ЦЕНЫ (Логика скрытия для Гостя / подсказки для Менеджера и Админа)
                if (data.showPrice) ...[
                  pw.Container(
                    padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: pw.BoxDecoration(
                      color: _colorAccent,
                      borderRadius: pw.BorderRadius.all(pw.Radius.circular(6)),
                    ),
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text(
                          data.formattedPrice,
                          style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold, color: PdfColors.white, font: font)
                        ),
                        // Если есть текстовая подсказка - рисуем её серым цветом под ценой
                        if (data.priceInfoText != null) ...[
                          pw.SizedBox(height: 4),
                          pw.Text(
                            data.priceInfoText,
                            style: pw.TextStyle(fontSize: 10, color: PdfColors.white70, font: font)
                          ),
                        ],
                      ],
                    ),
                  ),
                  pw.SizedBox(height: 8),
                ] else ...[
                  // Для Гостя: серая плашка "По запросу"
                  pw.Container(
                    padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: pw.BoxDecoration(
                      color: Colors.grey.shade400,
                      borderRadius: pw.BorderRadius.all(pw.Radius.circular(6)),
                    child: pw.Text(
                      'По запросу',
                      style: pw.TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: PdfColors.white, font: font)
                    ),
                  ),
                  pw.SizedBox(height: 8),
                ],

                // Вес
                if (weightStr != null) ...[
                  pw.SizedBox(height: 8),
                  pw.Text(weightStr, style: pw.TextStyle(fontSize: 11, color: _colorText, font: font)),
                ],

                // Описание (Категория + Товар)
                if (data.categoryDescription.isNotEmpty || data.productDescription.isNotEmpty) ...[
                  pw.SizedBox(height: 12),
                  _buildTextBlock(_joinDescriptions(data.categoryDescription, data.productDescription), font),
                ],

                // КБЖУ
                if (data.nutrition != null) ...[
                  pw.SizedBox(height: 12),
                  _buildSectionTitle('Пищевая ценность на 100г', font),
                  _buildNutritionBlock(data.nutrition!, font),
                ],

                // Условия хранения (Каждая строка с новой строки)
                if (data.mergedStorages.isNotEmpty) ...[
                  pw.SizedBox(height: 12),
                  _buildStorageBlock(data.mergedStorages, font),
                ],

                // Состав
                if (data.compositionText.isNotEmpty) ...[
                  pw.SizedBox(height: 12),
                  _buildSectionTitle('Состав', font),
                  _buildTextBlock(data.compositionText, font),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================
  // ВСПОМОГАТЕЛЬНЫЕ БЛОКИ
  // ==========================================
  static pw.Widget _joinDescriptions(String catDesc, String prodDesc) {
    final parts = <String>[];
    if (catDesc.isNotEmpty) parts.add(_normalizeText(catDesc));
    if (prodDesc.isNotEmpty) parts.add(_normalizeText(prodDesc));
    return parts.join(' ');
  }

  static String _normalizeText(String input) {
    if (input.trim().isEmpty) return '';
    String text = input.trim();
    text = text[0].toUpperCase() + text.substring(1);
    while (text.endsWith('.')) text = text.substring(0, text.length - 1).trim();
    return '$text.';
  }

  static pw.Widget _buildSectionTitle(String title, pw.Font font) {
    return pw.Text(title, style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold, color: _colorPrimary, font: font));
  }

  static pw.Widget _buildTextBlock(String text, pw.Font font) {
    return pw.Container(
      width: double.infinity,
      padding: const pw.EdgeInsets.all(8),
      decoration: pw.BoxDecoration(color: _colorBackground, _borderRadius: pw.BorderRadius.all(pw.Radius.circular(6))),
      child: pw.Text(text, style: pw.TextStyle(fontSize: 10, color: _colorText, font: font)),
    );
  }

  static double _parseNum(String? val) => double.tryParse(val ?? '') ?? 0.0;

  static pw.Widget _buildNutritionBlock(NutritionInfo info, pw.Font font) {
    final parts = <String>[];
    final cal = _parseNum(info.calories);
    final prot = _parseNum(info.proteins);
    final fats = _parseNum(info.fats);
    final carbs = _parseNum(info.carbohydrates);
    if (cal > 0) parts.add('Калории: $cal ккал');
    if (prot > 0) parts.add('Белки: $prot г');
    if (fats > 0) parts.add('Жиры: $fats г');
    if (carbs > 0) parts.add('Углеводы: $carbs г');
    if (parts.isEmpty) return pw.SizedBox();
    return _buildTextBlock(_normalizeText(parts.join(', ')), font);
  }

  static pw.Widget _buildStorageBlock(List<StorageCondition> storages, pw.Font font) {
    final lines = <pw.Widget>[];
    for (var s in storages) {
      final loc = s.storageLocation.trim().isEmpty ? 'Хранение' : s.storageLocation.trim();
      String details = '';
      if (s.temperature.trim().isNotEmpty) details += 'при температуре ${s.temperature.trim()}°C';
      if (s.humidity.trim().isNotEmpty) details += ', влажность ${s.humidity.trim()}%';
      if (s.shelfLife.trim().isNotEmpty) details += ", срок: ${s.shelfLife.trim()} ${s.unit.trim().isEmpty ? '' : s.unit.trim()}";
      
      lines.add(
        pw.Container(
          width: double.infinity,
          padding: const pw.EdgeInsets.symmetric(vertical: 2, horizontal: 8),
          color: lines.isEmpty ? _colorBackground : PdfColors.white,
          child: pw.Text('$loc, $details.', style: pw.TextStyle(fontSize: 10, color: _colorText, font: font)),
        ),
      );
    }
    if (lines.isEmpty) return pw.SizedBox();
    return pw.Container(
      width: double.infinity,
      padding: const pw.EdgeInsets.all(8),
      decoration: pw.BoxDecoration(color: _colorBackground, borderRadius: pw.BorderRadius.all(pw.Radius.circular(6))),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: lines,
      ),
    );
  }
}