// lib/services/export_service.dart
import 'dart:io';
import 'dart:typed_data';
import 'dart:convert';
import 'package:flutter/foundation.dart' show kIsWeb;
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
  bool includePhotos = true; // 🔥 Включаем фото по умолчанию

  // 🔥 КЭШ ЗАГРУЖЕННЫХ РЕСУРСОВ
  static pw.Font? _cachedFont;
  static pw.MemoryImage? _cachedLogo;
  static final Map<String, pw.MemoryImage> _cachedProductImages = {};

  // 🔥 ЦВЕТОВАЯ СХЕМА (тёмно-коричневая)
  static final _colorPrimary = PdfColor.fromHex('#5D4037');
  static final _colorSecondary = PdfColor.fromHex('#8D6E63');
  static final _colorBackground = PdfColor.fromHex('#EFEBE9');
  static final _colorText = PdfColors.brown900;
  static final _colorAccent = PdfColors.green700;

  // 🔥 ЗАГРУЗКА ШРИФТА С КИРИЛЛИЦЕЙ
  Future<pw.Font> _loadFont() async {
    if (_cachedFont != null) return _cachedFont!;

    try {
      final fontData = await rootBundle.load('assets/fonts/Lora-Regular.ttf');
      _cachedFont = pw.Font.ttf(fontData);
      print('✅ Шрифт Lora загружен для PDF');
      return _cachedFont!;
    } catch (e) {
      print('⚠️ Не удалось загрузить шрифт: $e');
      return pw.Font.helvetica();
    }
  }

  // 🔥 ЗАГРУЗКА ЛОГОТИПА
  Future<pw.MemoryImage?> _loadLogo() async {
    if (_cachedLogo != null) return _cachedLogo!;

    try {
      // Загружаем logo.webp из assets
      final logoData = await rootBundle.load('assets/images/auth/logo.webp');
      final logoBytes = logoData.buffer.asUint8List();

      // Конвертируем WebP в формат для PDF
      final memoryImage = pw.MemoryImage(logoBytes);
      _cachedLogo = memoryImage;
      print('✅ Логотип загружен');
      return memoryImage;
    } catch (e) {
      print('⚠️ Не удалось загрузить логотип: $e');
      return null;
    }
  }

  // 🔥 ЗАГРУЗКА ФОТО ТОВАРА
  Future<pw.MemoryImage?> _loadProductImage(
      String productId, String? imageUrl) async {
    // Проверяем кэш
    if (_cachedProductImages.containsKey(productId)) {
      return _cachedProductImages[productId];
    }

    try {
      Uint8List? imageBytes;

      if (kIsWeb) {
        // Для веба: пробуем загрузить из assets, затем по URL
        try {
          final assetPath = 'assets/images/products/$productId.webp';
          final data = await rootBundle.load(assetPath);
          imageBytes = data.buffer.asUint8List();
          print('✅ Фото товара $productId загружено из assets');
        } catch (_) {
          // Если нет в assets, пробуем по URL
          if (imageUrl != null && imageUrl.isNotEmpty) {
            // Для веба нужна HTTP загрузка (требуется пакет http)
            print(
                '⚠️ Фото $productId не найдено в assets, используется заглушка');
          }
        }
      } else {
        // Для мобильных: загрузка по URL или из файлов
        if (imageUrl != null && imageUrl.isNotEmpty) {
          // Здесь можно добавить загрузку по URL через http пакет
          print('⚠️ Загрузка по URL требует дополнительной настройки');
        }
      }

      if (imageBytes != null) {
        final memoryImage = pw.MemoryImage(imageBytes);
        _cachedProductImages[productId] = memoryImage;
        return memoryImage;
      }

      return null;
    } catch (e) {
      print('⚠️ Ошибка загрузки фото товара $productId: $e');
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

      if (kIsWeb) {
        if (format == 'csv') {
          final csvContent = await _generateCsvContent(products);
          return utf8.encode(csvContent);
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
          );
          return pdfBytes;
        }
      } else {
        final directory = await getApplicationDocumentsDirectory();
        final timestamp = DateTime.now().millisecondsSinceEpoch;

        if (format == 'csv') {
          return await _generateCsvFile(products, directory, timestamp);
        } else {
          return await _generatePdfFile(
            products,
            clientName,
            clientPhone,
            directory,
            timestamp,
            compositionsByProduct,
            nutritionByProduct,
            storageByProduct,
            font,
            logo,
          );
        }
      }
    } catch (e) {
      print('❌ Ошибка генерации прайс-листа: $e');
      return null;
    }
  }

  Future<String> _generateCsvContent(List<Product> products) async {
    final rows = <List<String>>[];
    final headers = <String>[];

    if (includeBasic) {
      headers.addAll(['ID', 'Наименование', 'Цена', 'Категория']);
    }
    if (includeComposition) headers.add('Состав');
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
          product.categoryName,
        ]);
      }
      if (includeComposition) row.add(_escapeCsv(product.composition));
      if (includeNutrition) row.add(_escapeCsv(product.nutrition));
      if (includeStorage) row.add(_escapeCsv(product.storage));
      rows.add(row);
    }

    return rows.map((row) => row.join(';')).join('\r\n');
  }

  Future<Uint8List> _generatePdfBytes(
    List<Product> products,
    String clientName,
    String clientPhone,
    Map<String, List<Composition>>? compositionsByProduct,
    Map<String, NutritionInfo>? nutritionByProduct,
    Map<String, StorageCondition>? storageByProduct,
    pw.Font font,
    pw.MemoryImage? logo,
  ) async {
    final pdf = pw.Document();

    // 🔥 ПРЕДЗАГРУЗКА ВСЕХ ИЗОБРАЖЕНИЙ ПЕРЕД ГЕНЕРАЦИЕЙ
    final Map<String, pw.MemoryImage?> productImages = {};
    for (var product in products) {
      productImages[product.id] =
          await _loadProductImage(product.id, product.imageUrl);
    }

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        build: (pw.Context context) => [
          _buildHeader(clientName, clientPhone, font, logo),
          ...products.map((product) => _buildProductCard(
                product,
                compositionsByProduct?[product.id] ?? [],
                nutritionByProduct?[product.id],
                storageByProduct?[product.id],
                font,
                productImages[product.id], // 👈 Передаём загруженное фото
              )),
        ],
      ),
    );

    return await pdf.save();
  }

  Future<File> _generateCsvFile(
      List<Product> products, Directory directory, int timestamp) async {
    final filePath = '${directory.path}/price_list_$timestamp.csv';
    final file = File(filePath);
    final csvContent = await _generateCsvContent(products);
    await file.writeAsString(csvContent, encoding: utf8);
    return file;
  }

  Future<File> _generatePdfFile(
    List<Product> products,
    String clientName,
    String clientPhone,
    Directory directory,
    int timestamp, [
    Map<String, List<Composition>>? compositionsByProduct,
    Map<String, NutritionInfo>? nutritionByProduct,
    Map<String, StorageCondition>? storageByProduct,
    pw.Font? font,
    pw.MemoryImage? logo,
  ]) async {
    final actualFont = font ?? await _loadFont();
    final actualLogo = logo ?? await _loadLogo();

    final pdfBytes = await _generatePdfBytes(
      products,
      clientName,
      clientPhone,
      compositionsByProduct,
      nutritionByProduct,
      storageByProduct,
      actualFont,
      actualLogo,
    );

    final filePath = '${directory.path}/price_list_$timestamp.pdf';
    final file = File(filePath);
    await file.writeAsBytes(pdfBytes);
    return file;
  }

  // 🔥 ЗАГОЛОВОК С ЛОГОТИПОМ
  pw.Widget _buildHeader(String clientName, String clientPhone, pw.Font font,
      pw.MemoryImage? logo) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        // Верхняя полоса с логотипом и названием
        pw.Container(
          width: double.infinity,
          padding: const pw.EdgeInsets.symmetric(horizontal: 20, vertical: 15),
          decoration: pw.BoxDecoration(
            color: _colorPrimary,
            borderRadius: const pw.BorderRadius.vertical(
              top: pw.Radius.circular(8),
            ),
          ),
          child: pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.start,
            children: [
              // 🔥 ЛОГОТИП СЛЕВА
              if (logo != null)
                pw.Container(
                  width: 60,
                  height: 60,
                  margin: const pw.EdgeInsets.only(right: 16),
                  decoration: pw.BoxDecoration(
                    color: PdfColors.white,
                    borderRadius:
                        const pw.BorderRadius.all(pw.Radius.circular(8)),
                  ),
                  child: pw.ClipRRect(
                    child: pw.Image(
                      logo,
                      fit: pw.BoxFit.contain,
                    ),
                  ),
                ),

              // Название компании
              pw.Expanded(
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      'Вкусные моменты',
                      style: pw.TextStyle(
                        fontSize: 24,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.white,
                        font: font,
                      ),
                    ),
                    pw.SizedBox(height: 4),
                    pw.Text(
                      'Прайс-лист премиум кондитерских изделий',
                      style: pw.TextStyle(
                        fontSize: 12,
                        color: PdfColors.grey400,
                        font: font,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        // Информация о клиенте
        pw.Container(
          padding: const pw.EdgeInsets.all(16),
          decoration: pw.BoxDecoration(
            color: _colorBackground,
            borderRadius: const pw.BorderRadius.vertical(
              bottom: pw.Radius.circular(8),
            ),
          ),
          child: pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    'Клиент: $clientName',
                    style: pw.TextStyle(
                      fontSize: 14,
                      fontWeight: pw.FontWeight.bold,
                      color: _colorText,
                      font: font,
                    ),
                  ),
                  pw.SizedBox(height: 4),
                  pw.Text(
                    'Телефон: $clientPhone',
                    style: pw.TextStyle(
                      fontSize: 14,
                      color: _colorSecondary,
                      font: font,
                    ),
                  ),
                ],
              ),
              pw.Text(
                'Дата: ${DateTime.now().toLocal().toString().split(' ')[0]}',
                style: pw.TextStyle(
                  fontSize: 12,
                  color: _colorSecondary,
                  font: font,
                ),
              ),
            ],
          ),
        ),

        pw.SizedBox(height: 20),
        pw.Divider(color: _colorSecondary),
        pw.SizedBox(height: 20),
      ],
    );
  }

// 🔥 КАРТОЧКА ТОВАРА С ФОТО (исправленная версия)
  pw.Widget _buildProductCard(
    Product product,
    List<Composition> compositions,
    NutritionInfo? nutrition,
    StorageCondition? storage,
    pw.Font font,
    pw.MemoryImage? productImage, // 👈 Передаём как параметр
  ) {
    return pw.Container(
      margin: const pw.EdgeInsets.only(bottom: 16),
      padding: const pw.EdgeInsets.all(16),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: _colorSecondary, width: 0.5),
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
        color: PdfColors.white,
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // 🔥 ФОТО ТОВАРА СЛЕВА
              if (includePhotos && productImage != null)
                pw.Container(
                  width: 100,
                  height: 100,
                  margin: const pw.EdgeInsets.only(right: 16),
                  decoration: pw.BoxDecoration(
                    color: _colorBackground,
                    borderRadius:
                        const pw.BorderRadius.all(pw.Radius.circular(8)),
                    border: pw.Border.all(color: _colorSecondary, width: 0.5),
                  ),
                  child: pw.ClipRRect(
                    child: pw.Image(
                      productImage,
                      fit: pw.BoxFit.cover,
                    ),
                  ),
                ),

              // Информация о товаре
              pw.Expanded(
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      product.displayName,
                      style: pw.TextStyle(
                        fontSize: 16,
                        fontWeight: pw.FontWeight.bold,
                        color: _colorPrimary,
                        font: font,
                      ),
                    ),
                    pw.SizedBox(height: 8),
                    pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      children: [
                        pw.Text(
                          'Категория: ${product.categoryName}',
                          style: pw.TextStyle(
                            fontSize: 12,
                            color: _colorSecondary,
                            font: font,
                          ),
                        ),
                        pw.Text(
                          '${product.price} ₽',
                          style: pw.TextStyle(
                            fontSize: 20,
                            fontWeight: pw.FontWeight.bold,
                            color: _colorAccent,
                            font: font,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),

          // ... остальной код (состав, КБЖУ, хранение) ...
        ],
      ),
    );
  }

  pw.Widget _buildInfoChip(String text, pw.Font font) {
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: pw.BoxDecoration(
        color: _colorBackground,
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(12)),
        border: pw.Border.all(color: _colorSecondary, width: 0.5),
      ),
      child: pw.Text(
        text,
        style: pw.TextStyle(fontSize: 10, color: _colorText, font: font),
      ),
    );
  }

  String _escapeCsv(String field) {
    if (field.contains(';') || field.contains('"') || field.contains('\n')) {
      return '"${field.replaceAll('"', '""')}"';
    }
    return field;
  }
}
