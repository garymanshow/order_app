// lib/screens/auth_phone_screen.dart
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/google_drive_service.dart';
import '../providers/auth_provider.dart';
import 'dart:math';

class AuthPhoneScreen extends StatefulWidget {
  @override
  _AuthPhoneScreenState createState() => _AuthPhoneScreenState();
}

class _AuthPhoneScreenState extends State<AuthPhoneScreen> {
  late Future<String?> _backgroundImageUrl;
  final TextEditingController _phoneController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _backgroundImageUrl = _loadRandomBackgroundImage();
  }

  Future<String?> _loadRandomBackgroundImage() async {
    try {
      final driveService = GoogleDriveService();
      await driveService.init();

      // Замените на ID вашей папки в Google Drive
      final folderId = dotenv.env['GOOGLE_DRIVE_IMAGES_FOLDER_ID']!;
      final imageIds = await driveService.getWebPImageFileIds(folderId);

      if (imageIds.isEmpty) return null;

      final random = Random();
      final randomId = imageIds[random.nextInt(imageIds.length)];
      return driveService.getDownloadUrl(randomId);
    } catch (e) {
      print('Ошибка загрузки фона: $e');
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: FutureBuilder<String?>(
        future: _backgroundImageUrl,
        builder: (context, snapshot) {
          Widget background = Container(color: Colors.blue[50]); // fallback

          if (snapshot.hasData && snapshot.data != null) {
            background = Image.network(
              snapshot.data!,
              fit: BoxFit.cover,
              loadingBuilder: (context, child, loadingProgress) {
                if (loadingProgress == null) return child;
                return Container(color: Colors.blue[50]);
              },
              errorBuilder: (context, error, stackTrace) {
                return Container(color: Colors.blue[50]);
              },
            );
          }

          return Stack(
            children: [
              // Фоновое изображение
              Positioned.fill(child: background),

              // Полупрозрачный оверлей для читаемости текста
              Positioned.fill(
                child: Container(
                  color: Colors.black.withOpacity(0.3),
                ),
              ),

              // Основной контент
              Center(
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'Добро пожаловать!',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 32),
                      TextField(
                        controller: _phoneController,
                        decoration: InputDecoration(
                          hintText: '+79123456789',
                          hintStyle: TextStyle(color: Colors.white70),
                          filled: true,
                          fillColor: Colors.white.withOpacity(0.2),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: Colors.white),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide:
                                BorderSide(color: Colors.white, width: 2),
                          ),
                        ),
                        style: TextStyle(color: Colors.white, fontSize: 18),
                        keyboardType: TextInputType.phone,
                      ),
                      SizedBox(height: 24),
                      ElevatedButton(
                        onPressed: () {
                          final phone = _phoneController.text.trim();
                          if (phone.isNotEmpty) {
                            Provider.of<AuthProvider>(context, listen: false)
                                .login(phone);
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          minimumSize: Size(200, 50),
                        ),
                        child: Text(
                          'Войти',
                          style: TextStyle(color: Colors.white, fontSize: 18),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
