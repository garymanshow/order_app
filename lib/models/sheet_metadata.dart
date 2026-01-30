// lib/models/sheet_metadata.dart
class SheetMetadata {
  final DateTime lastUpdate;
  final String editor;

  SheetMetadata({required this.lastUpdate, required this.editor});

  factory SheetMetadata.fromJson(Map<String, dynamic> json) {
    return SheetMetadata(
      lastUpdate: DateTime.parse(json['lastUpdate']),
      editor: json['editor'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'lastUpdate': lastUpdate.toIso8601String(),
      'editor': editor,
    };
  }
}
