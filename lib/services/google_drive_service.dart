import 'dart:convert';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:googleapis_auth/auth_io.dart' as auth;
import 'package:flutter_dotenv/flutter_dotenv.dart';

class GoogleDriveService {
  late drive.DriveApi _driveApi;

  /// Инициализация сервиса с использованием Service Account
  Future<void> init() async {
    final accountJsonBase64 = dotenv.env['GOOGLE_SERVICE_ACCOUNT_BASE64'];
    if (accountJsonBase64 == null) {
      throw Exception('GOOGLE_SERVICE_ACCOUNT_BASE64 not found in .env');
    }

    final jsonKey = utf8.decode(base64.decode(accountJsonBase64));
    final credentials = auth.ServiceAccountCredentials.fromJson(
      json.decode(jsonKey),
    );

    final authClient = await auth.clientViaServiceAccount(
      credentials,
      ['https://www.googleapis.com/auth/drive.readonly'],
    );
    _driveApi = drive.DriveApi(authClient);
  }

  /// Получает список ID файлов с расширением .webp из папки
  Future<List<String>> getWebPImageFileIds(String folderId) async {
    // Фильтр: только файлы в папке с MIME-типом image/webp и именем, содержащим '.webp'
    final query =
        "'$folderId' in parents and mimeType='image/webp' and name contains '.webp'";

    final response = await _driveApi.files.list(
      q: query,
      $fields: 'files(id, name)',
    );

    return response.files?.map((file) => file.id!).toList() ?? [];
  }

  /// Генерирует URL для скачивания изображения
  String getDownloadUrl(String fileId) {
    // Добавляем access_token не нужно — URL будет использоваться с авторизацией через HTTP-заголовки
    // Но для простоты мы используем прямой доступ через API (см. ниже)
    return 'https://www.googleapis.com/drive/v3/files/$fileId?alt=media';
  }

  /// Загружает изображение как байты (альтернатива Image.network)
  Future<List<int>> downloadImageBytes(String fileId) async {
    final response = await _driveApi.files.get(
      fileId,
      downloadOptions: drive.DownloadOptions.fullMedia,
    );
    return response as List<int>;
  }
}
