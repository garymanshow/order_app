// lib/services/export_service.dart
import 'dart:io';
import 'dart:typed_data';
import 'dart:convert';
import 'package:flutter/foundation.dart' show kIsWeb, debugPrint;
import 'package:flutter/services.dart' show rootBundle;
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import '../models/product.dart';
import '../models/nutrition_info.dart';
import '../models/storage_condition.dart';
import '../models/composition.dart';

class ExportService {
  String format = 'pdf';
  bool includeBasic = true;
  bool includeComposition = true;
  bool includeNutrition = true;
  bool includeStorage = true;
  bool includePhotos = true;

  static pw.Font? _cachedFont;
  static pw.MemoryImage? _cachedLogo;
  static final Map<String, pw.MemoryImage> _cachedProductImages = {};

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

  Future<pw.MemoryImage?> _loadProductImage(
      String productId, String? imageUrl) async {
    if (_cachedProductImages.containsKey(productId))
      return _cachedProductImages[productId];
    try {
      Uint8List? imageBytes;
      if (kIsWeb || imageUrl == null || imageUrl.isEmpty) {
        try {
          final data =
              await rootBundle.load('assets/images/products/$productId.webp');
          imageBytes = data.buffer.asUint8List();
        } catch (_) {}
      }
      if (imageBytes != null) {
        final memoryImage = pw.MemoryImage(imageBytes);
        _cachedProductImages[productId] = memoryImage;
        return memoryImage;
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  Future<dynamic> generatePriceList({
    required List<Product> products,
    required String clientName,
    required String clientPhone,
    Map<String, List<Composition>>? compositionsByProduct,
    Map<String, NutritionInfo>? nutritionByProduct,
    Map<String, StorageCondition>? storageByProduct,
  }) async {
    try {
      final font = await _loadFont();
      final logo = await _loadLogo();

      final Map<String, pw.MemoryImage?> productImages = {};
      for (var product in products) {
        productImages[product.id] =
            await _loadProductImage(product.id, product.imageUrl);
      }

      if (kIsWeb) {
        if (format == 'csv') {
          return utf8.encode(await _generateCsvContent(products));
        } else {
          return await _generatePdfBytes(
              products,
              clientName,
              clientPhone,
              compositionsByProduct,
              nutritionByProduct,
              storageByProduct,
              font,
              logo,
              productImages);
        }
      } else {
        final directory = await getApplicationDocumentsDirectory();
        final timestamp = DateTime.now().millisecondsSinceEpoch;
        if (format == 'csv') {
          final filePath = '${directory.path}/price_list_$timestamp.csv';
          await File(filePath).writeAsString(
              await _generateCsvContent(products),
              encoding: utf8);
          return File(filePath);
        } else {
          final pdfBytes = await _generatePdfBytes(
              products,
              clientName,
              clientPhone,
              compositionsByProduct,
              nutritionByProduct,
              storageByProduct,
              font,
              logo,
              productImages);
          final filePath = '${directory.path}/price_list_$timestamp.pdf';
          await File(filePath).writeAsBytes(pdfBytes);
          return File(filePath);
        }
      }
    } catch (e) {
      debugPrint('❌ Ошибка генерации прайс-листа: $e');
      return null;
    }
  }

  // ==========================================
  // CSV GENERATION
  // ==========================================
  Future<String> _generateCsvContent(List<Product> products) async {
    final rows = <List<String>>[];
    final headers = <String>[];

    if (includeBasic) {
      headers.addAll([
        'ID',
        'Наименование',
        'Цена',
        'Вес',
        'Кратность',
        'Упаковка',
        'Категория'
      ]);
    }
    if (includeComposition) headers.add('Описание');
    if (includeNutrition) headers.add('КБЖУ');
    if (includeStorage) headers.add('Условия хранения');
    rows.add(headers);

    for (var product in products) {
      final row = <String>[];
      if (includeBasic) {
        row.addAll([
          product.id,
          product.name,
          product.price.toString(),
          product.weight,
          product.multiplicity.toString(),
          product.packaging,
          product.categoryName
        ]);
      }
      if (includeComposition) row.add(_escapeCsv(product.composition));
      if (includeNutrition) row.add(_escapeCsv(product.nutrition));
      if (includeStorage) row.add(_escapeCsv(product.storage));
      rows.add(row);
    }
    return rows.map((row) => row.join(';')).join('\r\n');
  }

  String _escapeCsv(String field) {
    if (field.contains(';') || field.contains('"') || field.contains('\n')) {
      return '"${field.replaceAll('"', '""')}"';
    }
    return field;
  }

  // ==========================================
  // PDF GENERATION
  // ==========================================
  Future<Uint8List> _generatePdfBytes(
    List<Product> products,
    String clientName,
    String clientPhone,
    Map<String, List<Composition>>? compositionsByProduct,
    Map<String, NutritionInfo>? nutritionByProduct,
    Map<String, StorageCondition>? storageByProduct,
    pw.Font font,
    pw.MemoryImage? logo,
    Map<String, pw.MemoryImage?> productImages,
  ) async {
    final pdf = pw.Document();
    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (pw.Context context) => [
          _buildHeader(clientName, clientPhone, font, logo),
          ...products.map((product) => _buildProductCard(
                product,
                compositionsByProduct?[product.id] ?? [],
                nutritionByProduct?[product.id],
                storageByProduct?[product.id],
                font,
                productImages[product.id],
              )),
        ],
      ),
    );
    return pdf.save();
  }

  // ==========================================
  // PDF HEADER
  // ==========================================
  pw.Widget _buildHeader(String clientName, String clientPhone, pw.Font font,
      pw.MemoryImage? logo) {
    return pw.Container(
      margin: const pw.EdgeInsets.only(bottom: 24),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Container(
            width: double.infinity,
            padding:
                const pw.EdgeInsets.symmetric(horizontal: 20, vertical: 15),
            decoration: pw.BoxDecoration(
                color: _colorPrimary,
                borderRadius:
                    const pw.BorderRadius.vertical(top: pw.Radius.circular(8))),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.start,
              children: [
                if (logo != null)
                  pw.Container(
                      width: 60,
                      height: 60,
                      margin: const pw.EdgeInsets.only(right: 16),
                      decoration: pw.BoxDecoration(
                          color: PdfColors.white,
                          borderRadius:
                              const pw.BorderRadius.all(pw.Radius.circular(8))),
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
                      pw.Text('Прайс-лист премиум кондитерских изделий',
                          style: pw.TextStyle(
                              fontSize: 12,
                              color: PdfColors.grey400,
                              font: font)),
                    ])),
              ],
            ),
          ),
          pw.Container(
            padding: const pw.EdgeInsets.all(16),
            decoration: pw.BoxDecoration(
                color: _colorBackground,
                borderRadius: const pw.BorderRadius.vertical(
                    bottom: pw.Radius.circular(8))),
            child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text('Клиент: $clientName',
                            style: pw.TextStyle(
                                fontSize: 14,
                                fontWeight: pw.FontWeight.bold,
                                color: _colorText,
                                font: font)),
                        pw.SizedBox(height: 4),
                        pw.Text('Телефон: $clientPhone',
                            style: pw.TextStyle(
                                fontSize: 14,
                                color: _colorSecondary,
                                font: font)),
                      ]),
                  pw.Text(
                      'Дата: ${DateTime.now().toLocal().toString().split(' ')[0]}',
                      style: pw.TextStyle(
                          fontSize: 12, color: _colorSecondary, font: font)),
                ]),
          ),
        ],
      ),
    );
  }

  // ==========================================
  // PDF PRODUCT CARD
  // ==========================================
  pw.Widget _buildProductCard(
      Product product,
      List<Composition> compositions,
      NutritionInfo? nutrition,
      StorageCondition? storage,
      pw.Font font,
      pw.MemoryImage? productImage) {
    final bool hasPhoto = includePhotos && productImage != null;

    final List<String> specs = [];
    if (product.weight.trim().isNotEmpty) {
      specs.add('Вес: ${product.weight.trim()} г');
    }
    if (product.multiplicity > 0) {
      specs.add('Фасовка: ${product.multiplicity} шт');
    }
    if (product.packaging.trim().isNotEmpty) {
      specs.add('Упаковка: ${product.packaging.trim()}');
    }

    return pw.Container(
      margin: const pw.EdgeInsets.only(bottom: 16),
      padding: const pw.EdgeInsets.all(12),
      decoration: pw.BoxDecoration(
          border: pw.Border.all(color: _colorSecondary, width: 0.5),
          borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
          color: PdfColors.white),
      child:
          pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
        pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
          if (hasPhoto)
            pw.Container(
                width: 90,
                height: 90,
                margin: const pw.EdgeInsets.only(right: 16),
                decoration: pw.BoxDecoration(
                    color: _colorBackground,
                    borderRadius:
                        const pw.BorderRadius.all(pw.Radius.circular(8)),
                    border: pw.Border.all(color: _colorSecondary, width: 0.5)),
                child: pw.ClipRRect(
                    child: pw.Image(productImage, fit: pw.BoxFit.cover))),
          pw.Expanded(
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
                if (product.categoryName.trim().isNotEmpty) ...[
                  pw.Text('Категория: ${product.categoryName}',
                      style: pw.TextStyle(
                          fontSize: 11, color: _colorSecondary, font: font)),
                  pw.SizedBox(height: 8),
                ],
                pw.Container(
                    padding: const pw.EdgeInsets.symmetric(
                        horizontal: 12, vertical: 6),
                    decoration: pw.BoxDecoration(
                        color: _colorAccent,
                        borderRadius:
                            const pw.BorderRadius.all(pw.Radius.circular(6))),
                    child: pw.Text('${product.price} ₽',
                        style: pw.TextStyle(
                            fontSize: 18,
                            fontWeight: pw.FontWeight.bold,
                            color: PdfColors.white,
                            font: font))),
              ])),
        ]),
        if (specs.isNotEmpty) ...[
          pw.SizedBox(height: 12),
          pw.Divider(color: _colorBackground, thickness: 1),
          pw.SizedBox(height: 8),
          _buildSpecsRow(specs, font),
        ],
        if (includeComposition && product.composition.trim().isNotEmpty) ...[
          pw.SizedBox(height: 8),
          _buildSectionTitle('Описание', font),
          _buildTextBlock(product.composition.trim(), font),
        ],
        if (includeComposition && compositions.isNotEmpty) ...[
          pw.SizedBox(height: 8),
          _buildSectionTitle('Ингредиенты', font),
          _buildCompositionsBlock(compositions, font),
        ],
        if (includeNutrition &&
            nutrition != null &&
            _hasNutritionData(nutrition)) ...[
          pw.SizedBox(height: 8),
          _buildSectionTitle('Пищевая ценность на 100г', font),
          _buildNutritionBlock(nutrition, font),
        ],
        if (includeStorage &&
            storage != null &&
            storage.storageLocation.trim().isNotEmpty) ...[
          pw.SizedBox(height: 8),
          _buildSectionTitle('Условия хранения', font),
          _buildStorageBlock(storage, font),
        ],
      ]),
    );
  }

  // ==========================================
  // HELPER BLOCKS
  // ==========================================
  pw.Widget _buildSpecsRow(List<String> specs, pw.Font font) {
    return pw.Wrap(
        spacing: 8,
        runSpacing: 8,
        children: specs.map((s) => _buildInfoChip(s, font)).toList());
  }

  double _parseNum(String? val) => double.tryParse(val ?? '') ?? 0.0;

  bool _hasNutritionData(NutritionInfo info) {
    return _parseNum(info.calories) > 0 ||
        _parseNum(info.proteins) > 0 ||
        _parseNum(info.fats) > 0 ||
        _parseNum(info.carbohydrates) > 0;
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
            borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6))),
        child: pw.Text(text,
            style: pw.TextStyle(fontSize: 10, color: _colorText, font: font)));
  }

  pw.Widget _buildCompositionsBlock(List<Composition> comps, pw.Font font) {
    final text = comps.map((c) {
      final name = c.displayName;
      final qty = c.quantity > 0
          ? ' ${c.quantity.toStringAsFixed(c.quantity == c.quantity.roundToDouble() ? 0 : 1)}${c.unitSymbol.trim()}'
          : '';
      return '$name$qty';
    }).join(', ');
    return pw.Container(
        width: double.infinity,
        padding: const pw.EdgeInsets.all(8),
        decoration: pw.BoxDecoration(
            color: _colorBackground,
            borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6))),
        child: pw.Text(text,
            style: pw.TextStyle(fontSize: 10, color: _colorText, font: font)));
  }

  pw.Widget _buildNutritionBlock(NutritionInfo info, pw.Font font) {
    final List<String> nutritionParts = [];
    final cal = _parseNum(info.calories);
    final prot = _parseNum(info.proteins);
    final fats = _parseNum(info.fats);
    final carbs = _parseNum(info.carbohydrates);
    if (cal > 0) nutritionParts.add('Калории: $cal ккал');
    if (prot > 0) nutritionParts.add('Белки: $prot г');
    if (fats > 0) nutritionParts.add('Жиры: $fats г');
    if (carbs > 0) nutritionParts.add('Углеводы: $carbs г');
    return pw.Container(
        width: double.infinity,
        padding: const pw.EdgeInsets.all(8),
        decoration: pw.BoxDecoration(
            color: _colorBackground,
            borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6))),
        child: pw.Wrap(
            spacing: 16,
            children: nutritionParts
                .map((p) => pw.Text(p,
                    style: pw.TextStyle(
                        fontSize: 10, color: _colorText, font: font)))
                .toList()));
  }

  pw.Widget _buildStorageBlock(StorageCondition storage, pw.Font font) {
    final List<String> parts = [];
    if (storage.storageLocation.trim().isNotEmpty)
      parts.add(storage.storageLocation.trim());
    if (storage.temperature.trim().isNotEmpty)
      parts.add('t: ${storage.temperature.trim()}');
    if (storage.shelfLife.trim().isNotEmpty) {
      final unitStr =
          storage.unit.trim().isNotEmpty ? ' ${storage.unit.trim()}' : '';
      parts.add('Срок: ${storage.shelfLife.trim()}$unitStr');
    }
    return pw.Container(
        width: double.infinity,
        padding: const pw.EdgeInsets.all(8),
        decoration: pw.BoxDecoration(
            color: _colorBackground,
            borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6))),
        child: pw.Text(parts.join(' | '),
            style: pw.TextStyle(fontSize: 10, color: _colorText, font: font)));
  }

  pw.Widget _buildInfoChip(String text, pw.Font font) {
    return pw.Container(
        padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: pw.BoxDecoration(
            color: _colorBackground,
            borderRadius: const pw.BorderRadius.all(pw.Radius.circular(12)),
            border: pw.Border.all(color: _colorSecondary, width: 0.5)),
        child: pw.Text(text,
            style: pw.TextStyle(fontSize: 10, color: _colorText, font: font)));
  }
}
