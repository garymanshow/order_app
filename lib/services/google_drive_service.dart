// lib/services/google_drive_service.dart
import 'dart:convert';
import 'dart:io';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:googleapis_auth/auth_io.dart' as auth;
import 'env_service.dart';

class GoogleDriveService {
  late drive.DriveApi _driveApi;

  /// Инициализация сервиса с использованием Service Account
  Future<void> init() async {
    final accountJsonBase64 = EnvService.googleDriveImagesFolderID;

    final jsonKey = utf8.decode(base64.decode(accountJsonBase64));
    final credentials = auth.ServiceAccountCredentials.fromJson(
      json.decode(jsonKey),
    );

    // 🔥 ВАЖНО: Изменено с readonly на полный доступ для записи файлов
    final authClient = await auth.clientViaServiceAccount(
      credentials,
      ['https://www.googleapis.com/auth/drive'],
    );
    _driveApi = drive.DriveApi(authClient);
  }

  /// Получает список ID файлов с расширением .webp из папки
  Future<List<String>> getWebPImageFileIds(String folderId) async {
    final query =
        "'$folderId' in parents and mimeType='image/webp' and name contains 'bg' and name contains '.webp'";

    final response = await _driveApi.files.list(
      q: query,
      $fields: 'files(id, name)',
    );

    return response.files?.map((file) => file.id!).toList() ?? [];
  }

  /// Загружает изображение как байты (альтернатива Image.network)
  Future<List<int>> downloadImageBytes(String fileId) async {
    final response = await _driveApi.files.get(
      fileId,
      downloadOptions: drive.DownloadOptions.fullMedia,
    );

    if (response is drive.Media) {
      final List<int> bytes = [];
      await for (final chunk in response.stream) {
        bytes.addAll(chunk);
      }
      return bytes;
    }

    throw Exception('Unexpected response type: ${response.runtimeType}');
  }

  // 🔥 НОВЫЕ МЕТОДЫ ДЛЯ РАБОТЫ С ФАЙЛАМИ

  /// Загружает файл в Google Drive (CREATE)
  Future<String> uploadFile(File file,
      {required String mimeType, required String folderId}) async {
    final filename = '${DateTime.now().millisecondsSinceEpoch}.webp';

    final fileMetadata = drive.File()
      ..name = filename
      ..parents = [folderId]
      ..mimeType = mimeType;

    final media = drive.Media(file.openRead(), file.lengthSync());
    final uploadedFile = await _driveApi.files.create(
      fileMetadata,
      uploadMedia: media,
    );

    return uploadedFile.id!;
  }

  /// Обновляет существующий файл (UPDATE)
  Future<void> updateFile(String fileId, File newFile,
      {required String mimeType}) async {
    final media = drive.Media(newFile.openRead(), newFile.lengthSync());
    await _driveApi.files.update(
      drive.File(),
      fileId,
      uploadMedia: media,
    );
  }

  /// Удаляет файл (DELETE)
  Future<void> deleteFile(String fileId) async {
    await _driveApi.files.delete(fileId);
  }

  /// Получает информацию о файле (READ)
  Future<drive.File> getFile(String fileId) async {
    final result = await _driveApi.files.get(fileId);
    return result as drive.File;
  }

  /// Делает файл доступным по публичной ссылке
  Future<void> makeFilePublic(String fileId) async {
    final permission = drive.Permission()
      ..role = 'reader'
      ..type = 'anyone';

    await _driveApi.permissions.create(permission, fileId);
  }

  /// Генерирует публичную ссылку для скачивания
  String getPublicUrl(String fileId) {
    return 'https://drive.google.com/uc?export=download&id=$fileId';
  }
}
