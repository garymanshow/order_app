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

// 🔥 УСЛОВНЫЙ ИМПОРТ ДЛЯ WEB
import 'dart:html' as html if (dart.library.html) 'dart:html';

class ExportService {
  String format = 'pdf';
  bool includeBasic = true;
  bool includeComposition = true;
  bool includeNutrition = true;
  bool includeStorage = true;
  bool includePhotos = false;

  // 🔥 КЭШИРУЕМ ШРИФТЫ
  pw.Font? _fontTitle;
  pw.Font? _fontTitleBold;
  pw.Font? _fontBody;
  pw.Font? _fontBodyBold;

  // 🔥 ЗАГРУЗКА ШРИФТОВ
  Future<void> _loadFonts() async {
    if (_fontTitle != null) return;

    final playfairRegular = await rootBundle.load('assets/fonts/PlayfairDisplay-Regular.ttf');
    final playfairBold = await rootBundle.load('assets/fonts/PlayfairDisplay-Bold.ttf');
    final loraRegular = await rootBundle.load('assets/fonts/Lora-Regular.ttf');
    final loraBold = await rootBundle.load('assets/fonts/Lora-Bold.ttf');

    _fontTitle = pw.Font.ttf(playfairRegular);
    _fontTitleBold = pw.Font.ttf(playfairBold);
    _fontBody = pw.Font.ttf(loraRegular);
    _fontBodyBold = pw.Font.ttf(loraBold);
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
      await _loadFonts();

      if (kIsWeb) {
        if (format == 'csv') {
          final csvContent = await _generateCsvContent(products);
          return utf8.encode(csvContent);
        } else {
          return await _generatePdfBytes(
            products,
            clientName,
            clientPhone,
            compositionsByProduct,
            nutritionByProduct,
            storageByProduct,
          );
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
          );
        }
      }
    } catch (e, stack) {
      print('❌ Ошибка генерации прайс-листа: $e');
      print('Stack: $stack');
      return null;
    }
  }

  // 🔥 ГЕНЕРАЦИЯ PDF (общая логика)
  Future<Uint8List> _generatePdfBytes(
    List<Product> products,
    String clientName,
    String clientPhone,
    Map<String, List<Composition>>? compositionsByProduct,
    Map<String, NutritionInfo>? nutritionByProduct,
    Map<String, StorageCondition>? storageByProduct,
  ) async {
    final pdf = pw.Document();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(20),
        build: (pw.Context context) => [
          _buildHeader(clientName, clientPhone),
          ...products.map((product) => _buildProductCard(
                product,
                compositionsByProduct?[product.id] ?? [],
                nutritionByProduct?[product.id],
                storageByProduct?[product.id],
              )),
        ],
      ),
    );

    return await pdf.save();
  }

  // 🔥 ЗАГОЛОВОК
  pw.Widget _buildHeader(String clientName, String clientPhone) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  'Прайс-лист',
                  style: pw.TextStyle(
                    fontSize: 28,
                    font: _fontTitleBold,
                    color: PdfColors.blue900,
                  ),
                ),
                pw.SizedBox(height: 8),
                pw.Text(
                  'Клиент: $clientName',
                  style: pw.TextStyle(
                    fontSize: 13,
                    font: _fontBody,
                    color: PdfColors.grey700,
                  ),
                ),
                pw.Text(
                  'Телефон: $clientPhone',
                  style: pw.TextStyle(
                    fontSize: 13,
                    font: _fontBody,
                    color: PdfColors.grey700,
                  ),
                ),
              ],
            ),
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.end,
              children: [
                pw.Text(
                  'Дата: ${DateTime.now().toLocal().toString().split(' ')[0]}',
                  style: pw.TextStyle(
                    fontSize: 11,
                    font: _fontBody,
                    color: PdfColors.grey600,
                  ),
                ),
                pw.SizedBox(height: 4),
                pw.Container(
                  padding: const pw.EdgeInsets.all(8),
                  decoration: pw.BoxDecoration(
                    color: PdfColors.grey200,
                    borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
                  ),
                  child: pw.Text(
                    'Пароль: ${_generateRandomPassword()}',
                    style: pw.TextStyle(
                      fontSize: 11,
                      font: _fontBodyBold,
                      color: PdfColors.blue700,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
        pw.SizedBox(height: 20),
        pw.Divider(color: PdfColors.grey400),
        pw.SizedBox(height: 20),
      ],
    );
  }

  // 🔥 КАРТОЧКА ТОВАРА
  pw.Widget _buildProductCard(
    Product product,
    List<Composition> compositions,
    NutritionInfo? nutrition,
    StorageCondition? storage,
  ) {
    return pw.Container(
      margin: const pw.EdgeInsets.only(bottom: 16),
      padding: const pw.EdgeInsets.all(12),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey300),
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          // Название и цена
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text(
                product.displayName,
                style: pw.TextStyle(
                  fontSize: 16,
                  font: _fontTitle,
                  color: PdfColors.blue800,
                ),
              ),
              pw.Text(
                '${product.price} ₽',
                style: pw.TextStyle(
                  fontSize: 16,
                  font: _fontBodyBold,
                  color: PdfColors.green700,
                ),
              ),
            ],
          ),
          pw.SizedBox(height: 6),

          // Состав
          if (includeComposition && compositions.isNotEmpty) ...[
            pw.Text(
              'Состав:',
              style: pw.TextStyle(
                fontSize: 12,
                font: _fontBodyBold,
                color: PdfColors.grey800,
              ),
            ),
            pw.SizedBox(height: 3),
            ...compositions.map((comp) => pw.Padding(
                  padding: const pw.EdgeInsets.only(left: 6),
                  child: pw.Text(
                    '• ${comp.ingredientName} — ${comp.quantity} ${comp.unitSymbol}',
                    style: pw.TextStyle(
                      fontSize: 10,
                      font: _fontBody,
                      color: PdfColors.grey700,
                    ),
                  ),
                )),
            pw.SizedBox(height: 6),
          ],

          // КБЖУ
          if (includeNutrition && nutrition != null) ...[
            pw.Text(
              'КБЖУ:',
              style: pw.TextStyle(
                fontSize: 12,
                font: _fontBodyBold,
                color: PdfColors.grey800,
              ),
            ),
            pw.SizedBox(height: 3),
            pw.Wrap(
              spacing: 6,
              runSpacing: 4,
              children: [
                if (nutrition.calories?.isNotEmpty == true)
                  _buildInfoChip('${nutrition.calories} ккал'),
                if (nutrition.proteins?.isNotEmpty == true)
                  _buildInfoChip('б: ${nutrition.proteins}г'),
                if (nutrition.fats?.isNotEmpty == true)
                  _buildInfoChip('ж: ${nutrition.fats}г'),
                if (nutrition.carbohydrates?.isNotEmpty == true)
                  _buildInfoChip('у: ${nutrition.carbohydrates}г'),
              ],
            ),
            pw.SizedBox(height: 6),
          ],

          // 🔥 УСЛОВИЯ ХРАНЕНИЯ (ИСПРАВЛЕНО: без .data)
          if (includeStorage && storage != null) ...[
            pw.Text(
              'Условия хранения:',
              style: pw.TextStyle(
                fontSize: 12,
                font: _fontBodyBold,
                color: PdfColors.grey800,
              ),
            ),
            pw.SizedBox(height: 3),
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                ...[
                  if (storage.storageLocation.isNotEmpty)
                    '• Место: ${storage.storageLocation}',
                  if (storage.temperature.isNotEmpty)
                    '• Температура: ${storage.temperature}°C',
                  if (storage.humidity.isNotEmpty)
                    '• Влажность: ${storage.humidity}%',
                  if (storage.shelfLife.isNotEmpty)
                    '• Срок: ${storage.shelfLife} ${storage.unit}',
                ]
                    .map((textString) => pw.Padding(
                          padding: const pw.EdgeInsets.only(left: 6, bottom: 2),
                          child: pw.Text(
                            textString, // 👈 Просто строка, без .data
                            style: pw.TextStyle(
                              fontSize: 10,
                              font: _fontBody,
                              color: PdfColors.grey700,
                            ),
                          ),
                        ))
                    .toList(),
              ],
            ),
          ],
        ],
      ),
    );
  }

  // 🔥 Чип для КБЖУ
  pw.Widget _buildInfoChip(String text) {
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: pw.BoxDecoration(
        color: PdfColors.grey200,
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(10)),
      ),
      child: pw.Text(
        text,
        style: pw.TextStyle(
          fontSize: 9,
          font: _fontBody,
          color: PdfColors.grey800,
        ),
      ),
    );
  }

  // 🔥 Вспомогательные методы
  String _generateRandomPassword() {
    final random = DateTime.now().microsecondsSinceEpoch;
    final seed = random.toString();
    return seed.substring(seed.length - 6);
  }

  String _escapeCsv(String field) {
    if (field.contains(';') || field.contains('"') || field.contains('\n')) {
      return '"${field.replaceAll('"', '""')}"';
    }
    return field;
  }

  // 🔥 CSV генерация
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
  ]) async {
    final pdfBytes = await _generatePdfBytes(
      products,
      clientName,
      clientPhone,
      compositionsByProduct,
      nutritionByProduct,
      storageByProduct,
    );
    final filePath = '${directory.path}/price_list_$timestamp.pdf';
    final file = File(filePath);
    await file.writeAsBytes(pdfBytes);
    return file;
  }
}
