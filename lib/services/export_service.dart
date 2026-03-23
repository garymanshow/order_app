// lib/services/export_service.dart
import 'dart:io';
import 'dart:typed_data'; // 👈 ДОБАВЛЯЕМ ДЛЯ Uint8List
import 'dart:convert';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import '../models/product.dart';
import '../models/nutrition_info.dart';
import '../models/storage_condition.dart';
import '../models/composition.dart';

// 🔥 УСЛОВНЫЙ ИМПОРТ ДЛЯ WEB (только в браузере)
// В Dart 3+ используем условную компиляцию
// ignore: undefined_prefixed_name

class ExportService {
  String format = 'pdf'; // 'pdf' или 'csv'
  bool includeBasic = true;
  bool includeComposition = true;
  bool includeNutrition = true;
  bool includeStorage = true;
  bool includePhotos = false;

  Future<dynamic> generatePriceList({
    required List<Product> products,
    required String clientName,
    required String clientPhone,
    Map<String, List<Composition>>? compositionsByProduct,
    Map<String, NutritionInfo>? nutritionByProduct,
    Map<String, StorageCondition>? storageByProduct,
  }) async {
    try {
      if (kIsWeb) {
        // 🔥 ДЛЯ WEB — возвращаем Uint8List для скачивания
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
          );
          return pdfBytes;
        }
      } else {
        // 🔥 ДЛЯ МОБИЛЬНЫХ/ДЕСКТОП — сохраняем в файл
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
    } catch (e) {
      print('❌ Ошибка генерации прайс-листа: $e');
      return null;
    }
  }

  // 🔥 ДЛЯ WEB — генерация CSV как строка
  Future<String> _generateCsvContent(List<Product> products) async {
    final rows = <List<String>>[];

    // Заголовки
    final headers = <String>[];
    if (includeBasic) {
      headers.addAll(['ID', 'Наименование', 'Цена', 'Категория']);
    }
    if (includeComposition) {
      headers.add('Состав');
    }
    if (includeNutrition) {
      headers.add('КБЖУ');
    }
    if (includeStorage) {
      headers.add('Условия хранения');
    }
    rows.add(headers);

    // Данные
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
      if (includeComposition) {
        row.add(_escapeCsv(product.composition));
      }
      if (includeNutrition) {
        row.add(_escapeCsv(product.nutrition));
      }
      if (includeStorage) {
        row.add(_escapeCsv(product.storage));
      }
      rows.add(row);
    }

    return rows.map((row) => row.join(';')).join('\r\n');
  }

  // 🔥 ДЛЯ WEB — генерация PDF как Uint8List
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

  // 🔥 ДЛЯ МОБИЛЬНЫХ — сохранение CSV в файл
  Future<File> _generateCsvFile(
      List<Product> products, Directory directory, int timestamp) async {
    final filePath = '${directory.path}/price_list_$timestamp.csv';
    final file = File(filePath);
    final csvContent = await _generateCsvContent(products);
    await file.writeAsString(csvContent, encoding: utf8);
    return file;
  }

  // 🔥 ДЛЯ МОБИЛЬНЫХ — сохранение PDF в файл
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

  // Заголовок PDF (без контекста)
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
                    fontSize: 24,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.SizedBox(height: 8),
                pw.Text(
                  'Клиент: $clientName',
                  style: const pw.TextStyle(fontSize: 14),
                ),
                pw.Text(
                  'Телефон: $clientPhone',
                  style: const pw.TextStyle(fontSize: 14),
                ),
              ],
            ),
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.end,
              children: [
                pw.Text(
                  'Дата: ${DateTime.now().toLocal().toString().split(' ')[0]}',
                  style: const pw.TextStyle(fontSize: 12),
                ),
                pw.SizedBox(height: 4),
                pw.Container(
                  padding: const pw.EdgeInsets.all(8),
                  decoration: pw.BoxDecoration(
                    color: PdfColors.grey200,
                    borderRadius:
                        const pw.BorderRadius.all(pw.Radius.circular(4)),
                  ),
                  child: pw.Text(
                    'Пароль: ${_generateRandomPassword()}',
                    style: pw.TextStyle(
                      fontSize: 12,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColors.blue700,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
        pw.SizedBox(height: 20),
        pw.Divider(),
        pw.SizedBox(height: 20),
      ],
    );
  }

  // Карточка товара в PDF
  pw.Widget _buildProductCard(
    Product product,
    List<Composition> compositions,
    NutritionInfo? nutrition,
    StorageCondition? storage,
  ) {
    return pw.Container(
      margin: const pw.EdgeInsets.only(bottom: 20),
      padding: const pw.EdgeInsets.all(15),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey300),
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text(
                product.displayName,
                style: pw.TextStyle(
                  fontSize: 18,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.blue700,
                ),
              ),
              pw.Text(
                '${product.price} ₽',
                style: pw.TextStyle(
                  fontSize: 18,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.green700,
                ),
              ),
            ],
          ),
          pw.SizedBox(height: 8),
          if (includeComposition && compositions.isNotEmpty) ...[
            pw.Text(
              'Состав:',
              style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold),
            ),
            pw.SizedBox(height: 4),
            ...compositions.map((comp) => pw.Padding(
                  padding: const pw.EdgeInsets.only(left: 8),
                  child: pw.Text(
                    '• ${comp.ingredientName} — ${comp.quantity} ${comp.unitSymbol}',
                    style: const pw.TextStyle(fontSize: 12),
                  ),
                )),
            pw.SizedBox(height: 8),
          ],
          if (includeNutrition && nutrition != null) ...[
            pw.Text(
              'КБЖУ:',
              style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold),
            ),
            pw.SizedBox(height: 4),
            pw.Row(
              children: [
                if (nutrition.calories?.isNotEmpty == true)
                  _buildInfoChip('${nutrition.calories} ккал'),
                if (nutrition.proteins?.isNotEmpty == true)
                  pw.Padding(
                    padding: const pw.EdgeInsets.only(left: 8),
                    child: _buildInfoChip('б: ${nutrition.proteins}г'),
                  ),
                if (nutrition.fats?.isNotEmpty == true)
                  pw.Padding(
                    padding: const pw.EdgeInsets.only(left: 8),
                    child: _buildInfoChip('ж: ${nutrition.fats}г'),
                  ),
                if (nutrition.carbohydrates?.isNotEmpty == true)
                  pw.Padding(
                    padding: const pw.EdgeInsets.only(left: 8),
                    child: _buildInfoChip('у: ${nutrition.carbohydrates}г'),
                  ),
              ],
            ),
            pw.SizedBox(height: 8),
          ],
          if (includeStorage && storage != null) ...[
            pw.Text(
              'Условия хранения:',
              style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold),
            ),
            pw.SizedBox(height: 4),
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                if (storage.storageLocation.isNotEmpty)
                  pw.Text('• Место: ${storage.storageLocation}'),
                if (storage.temperature.isNotEmpty)
                  pw.Text('• Температура: ${storage.temperature}°C'),
                if (storage.humidity.isNotEmpty)
                  pw.Text('• Влажность: ${storage.humidity}%'),
                if (storage.shelfLife.isNotEmpty)
                  pw.Text(
                      '• Срок хранения: ${storage.shelfLife} ${storage.unit}'),
              ]
                  .map((t) => pw.Padding(
                        padding: const pw.EdgeInsets.only(left: 8, bottom: 2),
                        child: t,
                      ))
                  .toList(),
            ),
          ],
        ],
      ),
    );
  }

  pw.Widget _buildInfoChip(String text) {
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: pw.BoxDecoration(
        color: PdfColors.grey200,
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(12)),
      ),
      child: pw.Text(
        text,
        style: const pw.TextStyle(fontSize: 10),
      ),
    );
  }

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
}
