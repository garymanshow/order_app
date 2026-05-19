import 'dart:io';
import 'dart:typed_data';
import 'dart:convert';
import 'dart:html' as html;

import 'package:charset_converter/charset_converter.dart';
import 'package:flutter/foundation.dart' show kIsWeb, debugPrint;
import 'package:flutter/services.dart' show rootBundle;
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import '../models/price_category.dart';
import '../models/product.dart';
import '../models/nutrition_info.dart';
import '../models/storage_condition.dart';
import '../utils/price_engine.dart';

// ==========================================
// МОДЕЛИ ДЛЯ ПЕРЕДАЧИ СТРУКТУРЫ
// ==========================================
class ExportProductData {
  final Product product;
  final String categoryDescription;
  final String productDescription;
  final NutritionInfo? nutrition;
  final String compositionText;
  final List<StorageCondition> mergedStorages;
  ExportProductData({
    required this.product,
    required this.categoryDescription,
    required this.productDescription,
    this.nutrition,
    required this.compositionText,
    required this.mergedStorages,
  });
}

class ExportService {
  String format = 'pdf';
  bool includeBasic = true;
  bool includeComposition = true;
  bool includeNutrition = true;
  bool includeStorage = true;
  bool includePhotos = true;

  double markupPercent = 0;
  double discountPercent = 0;
  int roundToNearest = 0;

  final Map<String, pw.MemoryImage> _cachedProductImages = {};
  static pw.Font? _cachedFont;
  static pw.MemoryImage? _cachedLogo;

  static final _colorPrimary = PdfColor.fromHex('#5D4037');
  static final _colorSecondary = PdfColor.fromHex('#8D6E63');
  static final _colorBackground = PdfColor.fromHex('#EFEBE9');
  static final _colorText = PdfColors.brown900;
  static final _colorAccent = PdfColors.green700;

  Future<pw.Font> _loadFont() async {
    if (_cachedFont != null) return _cachedFont!;
    try {
      final fontData = await rootBundle.load('assets/fonts/Lora-Regular.ttf');
      _cachedFont = pw.Font.ttf(fontData);
      return _cachedFont!;
    } catch (e) {
      return pw.Font.helvetica();
    }
  }

  Future<pw.MemoryImage?> _loadLogo() async {
    if (_cachedLogo != null) return _cachedLogo!;
    try {
      final logoData = await rootBundle.load('assets/images/auth/logo.webp');
      _cachedLogo = pw.MemoryImage(logoData.buffer.asUint8List());
      return _cachedLogo;
    } catch (e) {
      return null;
    }
  }

  Future<pw.MemoryImage?> _loadProductImage(String productId) async {
    if (_cachedProductImages.containsKey(productId))
      return _cachedProductImages[productId];
    try {
      final data =
          await rootBundle.load('assets/images/products/$productId.webp');
      final memoryImage = pw.MemoryImage(data.buffer.asUint8List());
      _cachedProductImages[productId] = memoryImage;
      return memoryImage;
    } catch (e) {
      return null;
    }
  }

  Future<dynamic> generateStructuredPriceList({
    required List<ExportProductData> productsData,
    required String clientName,
    required String clientPhone,
    required List<PriceCategory> categories,
  }) async {
    try {
      final font = await _loadFont();
      final logo = await _loadLogo();

      final Map<String, pw.MemoryImage?> productImages = {};
      for (var prodData in productsData) {
        if (includePhotos) {
          productImages[prodData.product.id] =
              await _loadProductImage(prodData.product.id);
        }
      }

      final Map<String, PriceCategory> categoriesMap = {
        for (var cat in categories) cat.id.toString(): cat
      };

      if (kIsWeb) {
        return await _generatePdfBytes(productsData, clientName, clientPhone,
            font, logo, productImages, categoriesMap);
      } else {
        final directory = await getApplicationDocumentsDirectory();
        final timestamp = DateTime.now().millisecondsSinceEpoch;
        final pdfBytes = await _generatePdfBytes(productsData, clientName,
            clientPhone, font, logo, productImages, categoriesMap);
        final filePath = '${directory.path}/price_list_$timestamp.pdf';
        await File(filePath).writeAsBytes(pdfBytes);
        return File(filePath);
      }
    } catch (e) {
      debugPrint('❌ Ошибка генерации прайс-листа: $e');
      return null;
    }
  }

  Future<Uint8List> _generatePdfBytes(
    List<ExportProductData> productsData,
    String clientName,
    String clientPhone,
    pw.Font font,
    pw.MemoryImage? logo,
    Map<String, pw.MemoryImage?> productImages,
    Map<String, PriceCategory> categoriesMap,
  ) async {
    final pdf = pw.Document();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (pw.Context context) {
          final widgets = <pw.Widget>[];
          widgets.add(_buildHeader(clientName, clientPhone, font, logo));

          String? lastCategoryId;

          for (int i = 0; i < productsData.length; i++) {
            final data = productsData[i];
            final product = data.product;
            final category = categoriesMap[product.categoryId];

            if (product.categoryId != lastCategoryId) {
              if (lastCategoryId != null) widgets.add(pw.SizedBox(height: 32));
              if (category != null) {
                widgets.add(_buildCategoryHeader(category, font));
              }
              lastCategoryId = product.categoryId;
            }

            widgets.add(
              _buildProductCard(
                data,
                category,
                font,
                includePhotos ? productImages[product.id] : null,
              ),
            );
          }
          return widgets;
        },
      ),
    );
    return await pdf.save();
  }

  // ==========================================
  // ЗАГОЛОВОК КАТЕГОРИИ
  // ==========================================
  pw.Widget _buildCategoryHeader(PriceCategory category, pw.Font font) {
    final specList = <String>[];
    if (category.weight > 0) {
      final unit = category.unit.trim().isNotEmpty ? category.unit.trim() : 'г';
      specList.add(
          'Вес: ${category.weight.toStringAsFixed(category.weight == category.weight.roundToDouble() ? 0 : 1)} $unit');
    }
    if (category.packagingQuantity > 0) {
      final packInfo = category.packagingName.trim().isNotEmpty
          ? ' (${category.packagingName.trim()})'
          : '';
      specList.add('Фасовка: ${category.packagingQuantity} шт$packInfo');
    }

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Container(
          width: double.infinity,
          padding: const pw.EdgeInsets.symmetric(vertical: 16, horizontal: 24),
          decoration: pw.BoxDecoration(
              color: _colorPrimary,
              borderRadius: pw.BorderRadius.all(pw.Radius.circular(8))),
          child: pw.Text(category.name.toUpperCase(),
              style: pw.TextStyle(
                  fontSize: 24,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.white,
                  font: font)),
        ),
        if (specList.isNotEmpty) ...[
          pw.SizedBox(height: 12),
          _buildSpecsRow(specList, font),
        ],
        pw.SizedBox(height: 16),
        pw.Divider(color: _colorSecondary, thickness: 1),
      ],
    );
  }

  // ==========================================
  // КАРТОЧКА ТОВАРА (Компоновка 1/3 и 2/3)
  // ==========================================
  pw.Widget _buildProductCard(
    ExportProductData data,
    PriceCategory? category,
    pw.Font font,
    pw.MemoryImage? productImage,
  ) {
    final product = data.product;
    final hasPhoto = includePhotos && productImage != null;
    final weightStr = category != null && category.weight > 0
        ? 'Вес: ${category.weight.toStringAsFixed(category.weight == category.weight.roundToDouble() ? 0 : 1)} ${category.unit.trim().isEmpty ? 'г' : category.unit.trim()}'
        : null;

    return pw.Container(
      margin: const pw.EdgeInsets.only(bottom: 16),
      padding: const pw.EdgeInsets.all(12),
      decoration: pw.BoxDecoration(
          border: pw.Border.all(color: _colorSecondary, width: 0.5),
          borderRadius: pw.BorderRadius.all(pw.Radius.circular(8)),
          color: PdfColors.white),
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
                  shape: pw.BoxShape
                      .rectangle, // Прямоугольник (можно поменять на circle)
                  image: productImage != null
                      ? pw.DecorationImage(
                          image: productImage!, fit: pw.BoxFit.cover)
                      : null,
                ),
              ),
            ),

          if (hasPhoto) pw.SizedBox(width: 16),

          // ПРАВАЯ ЧАСТЬ (2/3) - ИНФОРМАЦИЯ
          pw.Expanded(
            flex: 2,
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(product.displayName,
                    style: pw.TextStyle(
                        fontSize: 16,
                        fontWeight: pw.FontWeight.bold,
                        color: _colorPrimary,
                        font: font)),
                pw.SizedBox(height: 8),
                pw.Container(
                  padding: const pw.EdgeInsets.symmetric(
                      horizontal: 12, vertical: 6),
                  decoration: pw.BoxDecoration(
                      color: _colorAccent,
                      borderRadius: pw.BorderRadius.all(pw.Radius.circular(6))),
                  child: pw.Text(
                      PriceEngine.calculate(
                              basePrice: product.price,
                              markupPercent: markupPercent,
                              discountPercent: discountPercent,
                              roundToNearest: roundToNearest)
                          .formattedPrice,
                      style: pw.TextStyle(
                          fontSize: 18,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColors.white,
                          font: font)),
                ),

                if (weightStr != null) ...[
                  pw.SizedBox(height: 8),
                  pw.Text(weightStr,
                      style: pw.TextStyle(
                          fontSize: 11, color: _colorText, font: font)),
                ],

                // Описание (Категория + Товар)
                if (_buildDescriptionText(
                        data.categoryDescription, data.productDescription)
                    .isNotEmpty) ...[
                  pw.SizedBox(height: 12),
                  _buildTextBlock(
                      _buildDescriptionText(
                          data.categoryDescription, data.productDescription),
                      font),
                ],

                // КБЖУ
                if (includeNutrition && data.nutrition != null) ...[
                  pw.SizedBox(height: 12),
                  _buildSectionTitle('Пищевая ценность на 100г', font),
                  _buildNutritionBlock(data.nutrition!, font),
                ],

                // Условия хранения (Слитные)
                if (includeStorage && data.mergedStorages.isNotEmpty) ...[
                  pw.SizedBox(height: 12),
                  _buildSectionTitle('Условия хранения', font),
                  _buildMergedStorageBlock(data.mergedStorages, font),
                ],

                // Состав
                if (includeComposition && data.compositionText.isNotEmpty) ...[
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
  // ЛОГИКА СЛИЯНИЯ И ФОРМАТИРОВАНИЯ ТЕКСТА
  // ==========================================

  String _buildDescriptionText(String catDesc, String prodDesc) {
    final parts = <String>[];
    if (catDesc.trim().isNotEmpty) parts.add(_normalizePdfText(catDesc));
    if (prodDesc.trim().isNotEmpty) parts.add(_normalizePdfText(prodDesc));
    return parts.join(' ');
  }

  String _normalizePdfText(String input) {
    if (input.trim().isEmpty) return '';
    String text = input.trim();
    text = text[0].toUpperCase() + text.substring(1);
    while (text.endsWith('.') || text.endsWith('!') || text.endsWith('?')) {
      text = text.substring(0, text.length - 1).trim();
    }
    return '$text.';
  }

  pw.Widget _buildMergedStorageBlock(
      List<StorageCondition> storages, pw.Font font) {
    // Собираем уникальные строки условий, склеивая температуру, влажность и срок
    final lines = <String>[];
    for (var s in storages) {
      final loc = s.storageLocation.trim().isEmpty
          ? 'Хранение'
          : s.storageLocation.trim();
      String details = '';
      if (s.temperature.trim().isNotEmpty)
        details += 'при температуре ${s.temperature.trim()}°C';
      if (s.humidity.trim().isNotEmpty)
        details += ', влажность ${s.humidity.trim()}%';
      if (s.shelfLife.trim().isNotEmpty)
        details +=
            ', срок: ${s.shelfLife.trim()} ${s.unit.trim().isEmpty ? '' : s.unit.trim()}';

      lines.add('$loc, $details.');
    }
    if (lines.isEmpty) return pw.SizedBox();
    return _buildTextBlock(lines.join(' '), font);
  }

  // ==========================================
  // ВСПОМОГАТЕЛЬНЫЕ БЛОКИ
  // ==========================================
  pw.Widget _buildHeader(String clientName, String clientPhone, pw.Font font,
      pw.MemoryImage? logo) {
    final currentDate = DateTime.now().toLocal().toString().split(' ')[0];
    return pw.Container(
        margin: const pw.EdgeInsets.only(bottom: 24),
        decoration: pw.BoxDecoration(
            borderRadius: pw.BorderRadius.all(pw.Radius.circular(8)),
            color: _colorPrimary),
        child: pw.Container(
            width: double.infinity,
            padding:
                const pw.EdgeInsets.symmetric(horizontal: 20, vertical: 15),
            child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.start,
                children: [
                  if (logo != null)
                    pw.Container(
                        width: 60,
                        height: 60,
                        margin: const pw.EdgeInsets.only(right: 16),
                        decoration: const pw.BoxDecoration(
                            color: PdfColors.white,
                            borderRadius:
                                pw.BorderRadius.all(pw.Radius.circular(8))),
                        child: pw.ClipRRect(
                            child: pw.Image(logo, fit: pw.BoxFit.contain))),
                  pw.Expanded(
                      child: pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.start,
                          children: [
                        pw.Text('Вкусные моменты',
                            style: pw.TextStyle(
                                fontSize: 24,
                                fontWeight: pw.FontWeight.bold,
                                color: PdfColors.white,
                                font: font)),
                        pw.SizedBox(height: 4),
                        pw.Text(
                            'Прайс-лист премиум кондитерских изделий на $currentDate',
                            style: pw.TextStyle(
                                fontSize: 12,
                                color: PdfColors.grey400,
                                font: font)),
                      ])),
                ])));
  }

  pw.Widget _buildSpecsRow(List<String> specs, pw.Font font) {
    return pw.Wrap(
        spacing: 8,
        runSpacing: 8,
        children: specs.map((s) => _buildInfoChip(s, font)).toList());
  }

  pw.Widget _buildSectionTitle(String title, pw.Font font) {
    return pw.Text(title,
        style: pw.TextStyle(
            fontSize: 12,
            fontWeight: pw.FontWeight.bold,
            color: _colorPrimary,
            font: font));
  }

  pw.Widget _buildTextBlock(String text, pw.Font font) {
    return pw.Container(
        width: double.infinity,
        padding: const pw.EdgeInsets.all(8),
        decoration: pw.BoxDecoration(
            color: _colorBackground,
            borderRadius: pw.BorderRadius.all(pw.Radius.circular(6))),
        child: pw.Text(text,
            style: pw.TextStyle(fontSize: 10, color: _colorText, font: font)));
  }

  double _parseNum(String? val) => double.tryParse(val ?? '') ?? 0.0;

  pw.Widget _buildNutritionBlock(NutritionInfo info, pw.Font font) {
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
    return _buildTextBlock(_normalizePdfText(parts.join(', ')), font);
  }

  pw.Widget _buildInfoChip(String text, pw.Font font) {
    return pw.Container(
        padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: pw.BoxDecoration(
            color: _colorBackground,
            borderRadius: pw.BorderRadius.all(pw.Radius.circular(12)),
            border: pw.Border.all(color: _colorSecondary, width: 0.5)),
        child: pw.Text(text,
            style: pw.TextStyle(fontSize: 10, color: _colorText, font: font)));
  }
}
