// lib/screens/auth_phone_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:contacts_service/contacts_service.dart';
import 'package:flutter/services.dart';
import '../services/google_drive_service.dart';
import '../providers/auth_provider.dart';
import '../providers/theme_provider.dart';
import '../utils/phone_validator.dart';
import '../models/client.dart';
import 'role_selection_screen.dart';
import 'client_selection_screen.dart';
import 'dart:math';
import 'dart:io' show Platform;

class AuthPhoneScreen extends StatefulWidget {
  @override
  _AuthPhoneScreenState createState() => _AuthPhoneScreenState();
}

class _AuthPhoneScreenState extends State<AuthPhoneScreen> {
  late Future<Uint8List?> _backgroundImageBytes;
  final TextEditingController _phoneController = TextEditingController();
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _backgroundImageBytes = _loadRandomBackgroundImage();
    // Firebase больше не инициализируется здесь
  }

  Future<Uint8List?> _loadRandomBackgroundImage() async {
    try {
      final driveService = GoogleDriveService();
      await driveService.init();

      final folderId = dotenv.env['GOOGLE_DRIVE_IMAGES_FOLDER_ID']!;
      final imageIds = await driveService.getWebPImageFileIds(folderId);

      if (imageIds.isEmpty) return null;

      final random = Random();
      final randomId = imageIds[random.nextInt(imageIds.length)];

      final bytes = await driveService.downloadImageBytes(randomId);
      return Uint8List.fromList(bytes);
    } catch (e) {
      print('Ошибка загрузки фона: $e');
      return null;
    }
  }

  void _showThemeSelectionDialog(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context, listen: false);

    showModalBottomSheet(
      context: context,
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: Icon(Icons.brightness_auto),
                title: Text('Как в системе'),
                onTap: () {
                  Navigator.pop(context);
                  themeProvider.setThemeMode(ThemeMode.system);
                },
              ),
              ListTile(
                leading: Icon(Icons.light_mode),
                title: Text('Светлая'),
                onTap: () {
                  Navigator.pop(context);
                  themeProvider.setThemeMode(ThemeMode.light);
                },
              ),
              ListTile(
                leading: Icon(Icons.dark_mode),
                title: Text('Тёмная'),
                onTap: () {
                  Navigator.pop(context);
                  themeProvider.setThemeMode(ThemeMode.dark);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _pastePhoneFromClipboard() async {
    try {
      final clipboardData = await Clipboard.getData('text/plain');
      if (clipboardData?.text != null) {
        final normalized = PhoneValidator.normalizePhone(clipboardData!.text);
        if (normalized != null) {
          _phoneController.text = normalized;
        } else {
          _phoneController.text = clipboardData.text!;
        }
      }
    } catch (e) {
      print('Ошибка получения из буфера: $e');
    }
  }

  bool get _isMobilePlatform {
    return Platform.isAndroid || Platform.isIOS;
  }

  Future<bool> _requestContactPermission() async {
    var status = await Permission.contacts.status;
    if (status.isDenied) {
      status = await Permission.contacts.request();
    }
    return status.isGranted;
  }

  Future<void> _pickContact() async {
    if (!_isMobilePlatform) return;

    final hasPermission = await _requestContactPermission();
    if (!hasPermission) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Нужно разрешение на доступ к контактам')),
      );
      return;
    }

    try {
      final contacts = await ContactsService.getContacts();
      final contactsWithPhones = contacts.where((contact) {
        final phones = contact.phones
                ?.map((p) => p.value ?? '')
                .where((p) => p.isNotEmpty)
                .toList() ??
            [];
        return phones.isNotEmpty;
      }).toList();

      if (contactsWithPhones.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('В контактах нет номеров телефонов')),
        );
        return;
      }

      final selectedContact = await showDialog<Contact?>(
        context: context,
        builder: (context) {
          return AlertDialog(
            title: Text('Выберите контакт'),
            content: SizedBox(
              width: double.maxFinite,
              height: 400,
              child: ListView.builder(
                itemCount: contactsWithPhones.length,
                itemBuilder: (context, index) {
                  final contact = contactsWithPhones[index];
                  final phones = contact.phones
                          ?.map((p) => p.value ?? '')
                          .where((p) => p.isNotEmpty)
                          .toList() ??
                      [];
                  return ListTile(
                    title: Text(contact.displayName ?? ''),
                    subtitle: Text(phones.join(', ')),
                    onTap: () {
                      Navigator.pop(context, contact);
                    },
                  );
                },
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, null),
                child: Text('Отмена'),
              ),
            ],
          );
        },
      );

      if (selectedContact != null) {
        final phones = selectedContact.phones
                ?.map((p) => p.value ?? '')
                .where((p) => p.isNotEmpty)
                .toList() ??
            [];
        if (phones.length == 1) {
          final normalized = PhoneValidator.normalizePhone(phones[0]);
          _phoneController.text = normalized ?? phones[0];
        } else if (phones.length > 1) {
          final selectedPhone = await showDialog<String?>(
            context: context,
            builder: (context) {
              return AlertDialog(
                title: Text('Выберите номер'),
                content: SizedBox(
                  width: double.maxFinite,
                  height: 300,
                  child: ListView.builder(
                    itemCount: phones.length,
                    itemBuilder: (context, index) {
                      return ListTile(
                        title: Text(phones[index]),
                        onTap: () {
                          Navigator.pop(context, phones[index]);
                        },
                      );
                    },
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context, null),
                    child: Text('Отмена'),
                  ),
                ],
              );
            },
          );

          if (selectedPhone != null) {
            final normalized = PhoneValidator.normalizePhone(selectedPhone);
            _phoneController.text = normalized ?? selectedPhone;
          }
        }
      }
    } catch (e) {
      print('Ошибка выбора контакта: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Ошибка при выборе контакта')),
      );
    }
  }

  Future<void> _handleLogin() async {
    if (_isLoading) return;

    final phone = _phoneController.text.trim();
    if (phone.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Введите номер телефона')),
      );
      return;
    }

    final error = PhoneValidator.validatePhone(phone);
    if (error != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error)),
      );
      return;
    }

    if (mounted) {
      setState(() {
        _isLoading = true;
      });
    }

    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      // Передаем null вместо FCM токена - AuthProvider сам решит, нужно ли его получать
      await authProvider.login(phone, fcmToken: null);

      if (!mounted) return;

      // Навигация после успешной авторизации
      if (authProvider.hasMultipleRoles) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
              builder: (_) =>
                  RoleSelectionScreen(roles: authProvider.availableRoles!)),
        );
      } else if (authProvider.currentUser is Client &&
          authProvider.clientData!.clients.length > 1) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => ClientSelectionScreen(
              phone: phone,
              clients: authProvider.clientData!.clients,
            ),
          ),
        );
      } else {
        Navigator.pushReplacementNamed(context, '/price');
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка авторизации: $error')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: FutureBuilder<Uint8List?>(
        future: _backgroundImageBytes,
        builder: (context, snapshot) {
          Widget background = Container(color: Colors.blue[50]);

          if (snapshot.connectionState == ConnectionState.waiting) {
            background = Container(
              color: Colors.blue[50],
              child: Center(child: CircularProgressIndicator()),
            );
          } else if (snapshot.hasData && snapshot.data != null) {
            background = Image.memory(
              snapshot.data!,
              fit: BoxFit.cover,
            );
          }

          return Stack(
            children: [
              Positioned.fill(child: background),
              if (snapshot.connectionState != ConnectionState.waiting)
                Positioned.fill(
                  child: Container(
                    color: Color.fromRGBO(0, 0, 0, 0.3),
                  ),
                ),
              Positioned(
                top: 40,
                right: 20,
                child: IconButton(
                  icon: Icon(Icons.palette, color: Colors.white, size: 32),
                  onPressed: () => _showThemeSelectionDialog(context),
                  tooltip: 'Выбрать тему',
                ),
              ),
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
                          hintText: '+7 XXX XXX XX XX',
                          hintStyle: TextStyle(color: Colors.white70),
                          filled: true,
                          fillColor: Color.fromRGBO(255, 255, 255, 0.2),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: Colors.white),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide:
                                BorderSide(color: Colors.white, width: 2),
                          ),
                          suffixIcon: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: Icon(Icons.paste, color: Colors.white),
                                onPressed: _pastePhoneFromClipboard,
                                tooltip: 'Вставить из буфера',
                              ),
                              if (_isMobilePlatform)
                                IconButton(
                                  icon:
                                      Icon(Icons.contacts, color: Colors.white),
                                  onPressed: _pickContact,
                                  tooltip: 'Выбрать из контактов',
                                ),
                            ],
                          ),
                        ),
                        style: TextStyle(color: Colors.white, fontSize: 18),
                        keyboardType: TextInputType.phone,
                        onEditingComplete: () {
                          final phone = _phoneController.text.trim();
                          if (phone.isNotEmpty) {
                            final error = PhoneValidator.validatePhone(phone);
                            if (error != null) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text(error)),
                              );
                            }
                          }
                        },
                      ),
                      SizedBox(height: 24),
                      ElevatedButton(
                        onPressed: _isLoading ? null : _handleLogin,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          minimumSize: Size(200, 50),
                        ),
                        child: _isLoading
                            ? CircularProgressIndicator(color: Colors.white)
                            : Text(
                                'Войти',
                                style: TextStyle(
                                    color: Colors.white, fontSize: 18),
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
