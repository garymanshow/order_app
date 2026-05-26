// lib/models/sheet_metadata.dart
import 'package:flutter/foundation.dart';

class SheetMetadata {
  final DateTime lastUpdate;
  final String editor;

  SheetMetadata({required this.lastUpdate, required this.editor});

  factory SheetMetadata.fromJson(Map<String, dynamic> json) {
    debugPrint('📄 SheetMetadata.fromJson:');
    debugPrint('   - json keys: ${json.keys}');
    debugPrint(
        '   - lastUpdate raw: ${json['lastUpdate']} (${json['lastUpdate'].runtimeType})');
    debugPrint(
        '   - editor raw: ${json['editor']} (${json['editor'].runtimeType})');

    DateTime parseLastUpdate(dynamic value) {
      if (value == null) return DateTime.now();

      if (value is DateTime) return value;

      if (value is String) {
        try {
          return DateTime.parse(value);
        } catch (e) {
          debugPrint('   ⚠️ Ошибка парсинга даты: $e');
          return DateTime.now();
        }
      }

      return DateTime.now();
    }

    final metadata = SheetMetadata(
      lastUpdate: parseLastUpdate(json['lastUpdate']),
      editor: json['editor']?.toString() ?? '',
    );

    debugPrint('   ✅ Создан SheetMetadata: lastUpdate=${metadata.lastUpdate}');
    return metadata;
  }

  Map<String, dynamic> toJson() {
    return {
      'lastUpdate': lastUpdate.toIso8601String(),
      'editor': editor ?? '',
    };
  }
}
