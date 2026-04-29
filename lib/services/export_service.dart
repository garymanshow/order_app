// lib/services/export_service.dart
import 'dart:io';
import 'dart:html' as html;
import 'dart:typed_data';
import 'dart:convert';
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

class ExportService {
  String format = 'pdf';
  bool includeBasic = true;
  bool includeComposition = true;
  bool includeNutrition = true;
  bool includeStorage = true;
  bool includePhotos = true;

  // Наценка и скидка
  double markupPercent = 0;
  double discountPercent = 0;
  int roundToNearest = 0;

  static pw.Font? _cachedFont;
  static pw.MemoryImage? _cachedLogo;
  static final Map<String, pw.MemoryImage> _cachedProductImages = {};

  static final _colorPrimary = PdfColor.fromHex('#5D4037');
  static final _colorSecondary = PdfColor.fromHex('#8D6E63');
  static final _colorBackground = PdfColor.fromHex('#EFEBE9');
  static final _colorText = PdfColors.brown900;
  static final _colorAccent = PdfColors.green700;

  Future<pw.Font> _loadFont() async {
    if (_cachedFont != null) {
      return _cachedFont!;
    }
    try {
      final fontData = await rootBundle.load('assets/fonts/Lora-Regular.ttf');
      _cachedFont = pw.Font.ttf(fontData);
      return _cachedFont!;
    } catch (e) {
      return pw.Font.helvetica();
    }
  }

  Future<pw.MemoryImage?> _loadLogo() async {
    if (_cachedLogo != null) {
      return _cachedLogo!;
    }
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
    if (_cachedProductImages.containsKey(productId)) {
      return _cachedProductImages[productId];
    }
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
    required List<PriceCategory> categories,
    // ИЗМЕНЕНО: Теперь принимаем готовые строки вместо объектов Composition
    Map<String, String>? compositionsByProduct,
    Map<String, NutritionInfo>? nutritionByProduct,
    Map<String, List<StorageCondition>>? storageByProduct,
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
          final csvStr = _generateCsvContent(products);

          // ИСПРАВЛЕНО: На Web нельзя использовать CharsetConverter (вызывает Platform._operatingSystem)
          // Используем встроенные возможности html.Blob для указания кодировки
          final bytes = utf8.encode(csvStr); // Кодируем строку в байты
          final blob = html.Blob([
            bytes
          ], 'text/csv;charset=windows-1251'); // Указываем кодировку для браузера
          return blob; // Возвращаем Blob вместо Uint8List
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
            productImages,
            categories,
          );
        }
      } else {
        final directory = await getApplicationDocumentsDirectory();
        final timestamp = DateTime.now().millisecondsSinceEpoch;
        if (format == 'csv') {
          final filePath = '${directory.path}/price_list_$timestamp.csv';
          final csvStr = _generateCsvContent(products);
          final bytes = await CharsetConverter.encode('windows-1251', csvStr);
          await File(filePath).writeAsBytes(bytes);
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
            productImages,
            categories,
          );
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
  String _generateCsvContent(List<Product> products) {
    final headers = ['Категория', 'Название', 'Цена', 'Описание'];
    final rows = <List<String>>[];

    rows.add(headers);

    for (var product in products) {
      final category = _escapeCsv(product.categoryName.trim());
      final name = _escapeCsv(product.displayName.trim());
      final price = product.price.toStringAsFixed(0);
      final description = _escapeCsv(product.composition.trim());

      rows.add([category, name, price, description]);
    }

    // Собираем CSV строку (разделитель - точка с запятой, стандарт для Excel РФ)
    final csvString = rows.map((row) => row.join(';')).join('\r\n');

    return csvString;
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
    Map<String, String>? compositionsByProduct,
    Map<String, NutritionInfo>? nutritionByProduct,
    Map<String, List<StorageCondition>>? storageByProduct,
    pw.Font font,
    pw.MemoryImage? logo,
    Map<String, pw.MemoryImage?> productImages,
    List<PriceCategory> categories, // ДОБАВЛЕН ПАРАМЕТР
  ) async {
    final pdf = pw.Document();

    // Создаем мапу для быстрого поиска категорий
    final categoriesMap = <String, PriceCategory>{};
    for (var cat in categories) {
      categoriesMap[cat.id.toString()] = cat;
    }

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (pw.Context context) => [
          _buildHeader(clientName, clientPhone, font, logo),
          ...products.map((product) => _buildProductCard(
                product,
                compositionsByProduct?[product.id],
                nutritionByProduct?[product.id],
                storageByProduct?[product.id] ?? [],
                font,
                productImages[product.id],
                categoriesMap[product.categoryId], // ПЕРЕДАЕМ КАТЕГОРИЮ
              )),
        ],
      ),
    );

    final rawPdfBytes = await pdf.save();
    return rawPdfBytes;
  }

  // ==========================================
  // PDF HEADER
  // ==========================================
  pw.Widget _buildHeader(String clientName, String clientPhone, pw.Font font,
      pw.MemoryImage? logo) {
    // Форматируем дату для заголовка
    final currentDate = DateTime.now().toLocal().toString().split(' ')[0];

    return pw.Container(
      margin: const pw.EdgeInsets.only(bottom: 24),
      decoration: pw.BoxDecoration(
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
        color: _colorPrimary,
      ),
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
                  // ИЗМЕНЕНО: Добавили дату прямо в подзаголовок
                  pw.Text(
                      'Прайс-лист премиум кондитерских изделий на $currentDate',
                      style: pw.TextStyle(
                          fontSize: 12, color: PdfColors.grey400, font: font)),
                ])),
          ],
        ),
      ),
    );
  }

  // ==========================================
  // PDF PRODUCT CARD
  // ==========================================
  pw.Widget _buildProductCard(
    Product product,
    String? compositionString,
    NutritionInfo? nutrition,
    List<StorageCondition> storages,
    pw.Font font,
    pw.MemoryImage? productImage,
    PriceCategory? category, // ДОБАВЛЕН ПАРАМЕТР КАТЕГОРИИ
  ) {
    final bool hasPhoto = includePhotos && productImage != null;

    final List<String> specs = [];

    // ИСПРАВЛЕНО: Учитываем случай, когда у товара может не быть категории
    if (category != null) {
      // Данные из категории
      if (category.weight > 0) {
        final unit =
            category.unit.trim().isNotEmpty ? category.unit.trim() : 'г';
        // Убираем лишние нули у веса (120.0 -> 120, 0.5 -> 0.5)
        final weightStr = category.weight == category.weight.roundToDouble()
            ? category.weight.toInt().toString()
            : category.weight.toString();
        specs.add('Вес: $weightStr $unit');
      }
      if (category.packagingQuantity > 0) {
        final packInfo = category.packagingName.trim().isNotEmpty
            ? ' (${category.packagingName.trim()})'
            : '';
        specs.add('Фасовка в таре: ${category.packagingQuantity} шт$packInfo');
      }
    } else {
      // Fallback: Данные из самого товара, если категории нет
      if (product.weight.trim().isNotEmpty) {
        specs.add('Вес: ${product.weight.trim()} г');
      }
      if (product.multiplicity > 0) {
        specs.add('Фасовка: ${product.multiplicity} шт');
      }
    }

    // Упаковка может быть указана в самом товаре, независимо от категории
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
                    // РАСЧЕТ ЦЕНЫ ЧЕРЕЗ ДВИЖОК
                    child: pw.Text(
                        PriceEngine.calculate(
                          basePrice: product.price,
                          markupPercent: markupPercent,
                          discountPercent: discountPercent,
                          roundToNearest: roundToNearest,
                        ).formattedPrice,
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

        // ВЫВОД СОСТАВА ИЗ СТРОКИ
        if (includeComposition &&
            compositionString != null &&
            compositionString.isNotEmpty) ...[
          pw.SizedBox(height: 8),
          _buildSectionTitle('Состав', font),
          _buildTextBlock(compositionString, font),
        ],

        if (includeNutrition &&
            nutrition != null &&
            _hasNutritionData(nutrition)) ...[
          pw.SizedBox(height: 8),
          _buildSectionTitle('Пищевая ценность на 100г', font),
          _buildNutritionBlock(nutrition, font),
        ],

        if (includeStorage && storages.isNotEmpty) ...[
          pw.SizedBox(height: 8),
          _buildSectionTitle('Условия хранения', font),
          _buildStorageBlock(storages, font),
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

  // Функция приведения текста в порядок для PDF
  String _normalizePdfText(String input) {
    if (input.trim().isEmpty) return '';
    String text = input.trim();
    text = text[0].toUpperCase() + text.substring(1);
    while (text.endsWith('.')) {
      text = text.substring(0, text.length - 1).trim();
    }
    return '$text.';
  }

  pw.Widget _buildNutritionBlock(NutritionInfo info, pw.Font font) {
    final parts = <String>[];

    final cal = _parseNum(info.calories);
    final prot = _parseNum(info.proteins);
    final fats = _parseNum(info.fats);
    final carbs = _parseNum(info.carbohydrates);

    if (cal > 0) parts.add('Энергетическая ценность: $cal ккал');
    if (prot > 0) parts.add('Белки: $prot г');
    if (fats > 0) parts.add('Жиры: $fats г');
    if (carbs > 0) parts.add('Углеводы: $carbs г');

    if (parts.isEmpty) return pw.SizedBox();

    // Склеиваем через запятую, делаем первую букву заглавной и точку в конце
    String text = parts.join(', ');
    text = _normalizePdfText(text); // Применяем наше правило типографики

    return pw.Container(
        width: double.infinity,
        padding: const pw.EdgeInsets.all(8),
        decoration: pw.BoxDecoration(
            color: _colorBackground,
            borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6))),
        child: pw.Text(text,
            style: pw.TextStyle(fontSize: 10, color: _colorText, font: font)));
  }

  pw.Widget _buildStorageBlock(List<StorageCondition> storages, pw.Font font) {
    final storageLines = <pw.Widget>[];

    for (var storage in storages) {
      final parts = <String>[];

      // Место хранения с большой буквы
      if (storage.storageLocation.trim().isNotEmpty) {
        String loc = storage.storageLocation.trim();
        loc = loc[0].toUpperCase() + loc.substring(1);
        parts.add(loc);
      }

      // Температура со знаком градуса
      if (storage.temperature.trim().isNotEmpty) {
        parts.add('при температуре ${storage.temperature.trim()}°C');
      }

      // Влажность
      if (storage.humidity.trim().isNotEmpty) {
        parts.add('влажность ${storage.humidity.trim()}%');
      }

      // Срок и единица измерения
      if (storage.shelfLife.trim().isNotEmpty) {
        final unitStr =
            storage.unit.trim().isNotEmpty ? ' ${storage.unit.trim()}' : '';
        parts.add('срок: ${storage.shelfLife.trim()}$unitStr');
      }

      if (parts.isNotEmpty) {
        storageLines.add(pw.Container(
            width: double.infinity,
            padding: const pw.EdgeInsets.symmetric(vertical: 4, horizontal: 8),
            color: storageLines.isEmpty
                ? _colorBackground
                : PdfColors.white, // Чередуем фон
            child: pw.Text(parts.join(', '),
                style: pw.TextStyle(
                    fontSize: 10, color: _colorText, font: font))));
      }
    }

    if (storageLines.isEmpty) return pw.SizedBox();

    return pw.Container(
        width: double.infinity,
        padding: const pw.EdgeInsets.all(8),
        decoration: pw.BoxDecoration(
            color: _colorBackground,
            borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6))),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: storageLines,
        ));
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
