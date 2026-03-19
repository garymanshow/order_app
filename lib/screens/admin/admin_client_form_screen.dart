// lib/screens/admin_client_form_screen.dart
import 'dart:io' show Platform;
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:contacts_service/contacts_service.dart';
import 'package:flutter/services.dart';
import '../../providers/auth_provider.dart';
import '../../services/api_service.dart';
import '../../models/client.dart';
import '../../utils/phone_validator.dart';

class AdminClientFormScreen extends StatefulWidget {
  final Client? client;

  const AdminClientFormScreen({Key? key, this.client}) : super(key: key);

  @override
  _AdminClientFormScreenState createState() => _AdminClientFormScreenState();
}

class _AdminClientFormScreenState extends State<AdminClientFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final ApiService _apiService = ApiService();

  late TextEditingController _nameController;
  late TextEditingController _firmController;
  late TextEditingController _postalCodeController;
  late TextEditingController _phoneController;
  late TextEditingController _cityController;
  late TextEditingController _deliveryAddressController;
  late TextEditingController _commentController;
  late TextEditingController _discountController;
  late TextEditingController _minOrderAmountController;

  late bool _legalEntityValue;
  late bool _deliveryValue;

  bool _isSaving = false;

  // Список городов для автодополнения
  List<String> _availableCities = [];

  @override
  void initState() {
    super.initState();
    _loadCities();

    if (widget.client != null) {
      _nameController = TextEditingController(text: widget.client!.name ?? '');
      _firmController = TextEditingController(text: widget.client!.firm ?? '');
      _postalCodeController =
          TextEditingController(text: widget.client!.postalCode ?? '');
      _phoneController =
          TextEditingController(text: widget.client!.phone ?? '');
      _cityController = TextEditingController(text: widget.client!.city ?? '');
      _deliveryAddressController =
          TextEditingController(text: widget.client!.deliveryAddress ?? '');
      _commentController =
          TextEditingController(text: widget.client!.comment ?? '');
      _discountController = TextEditingController(
          text: widget.client!.discount?.toString() ?? '');
      _minOrderAmountController = TextEditingController(
          text: widget.client!.minOrderAmount?.toString() ?? '');

      _legalEntityValue = widget.client!.legalEntity ?? false;
      _deliveryValue = widget.client!.delivery ?? false;
    } else {
      _nameController = TextEditingController();
      _firmController = TextEditingController();
      _postalCodeController = TextEditingController();
      _phoneController = TextEditingController();
      _cityController = TextEditingController();
      _deliveryAddressController = TextEditingController();
      _commentController = TextEditingController();
      _discountController = TextEditingController();
      _minOrderAmountController = TextEditingController();

      _legalEntityValue = false;
      _deliveryValue = false;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _firmController.dispose();
    _postalCodeController.dispose();
    _phoneController.dispose();
    _cityController.dispose();
    _deliveryAddressController.dispose();
    _commentController.dispose();
    _discountController.dispose();
    _minOrderAmountController.dispose();
    super.dispose();
  }

  // 🔥 ЗАГРУЗКА ГОРОДОВ ДЛЯ АВТОДОПОЛНЕНИЯ
  void _loadCities() {
    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final conditions = authProvider.clientData?.deliveryConditions ?? [];

      _availableCities = conditions
          .map((c) => c.location)
          .where((city) => city.isNotEmpty)
          .toSet()
          .toList()
        ..sort();
    } catch (e) {
      print('⚠️ Ошибка загрузки городов: $e');
      _availableCities = [];
    }
  }

  // 🔥 ФОРМАТИРОВАНИЕ ТЕЛЕФОНА ПРИ ВВОДЕ
  void _formatPhone(String value) {
    final digits = value.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.isEmpty) return;

    String formatted;
    if (digits.length <= 1) {
      formatted = '+7';
    } else if (digits.length <= 4) {
      formatted = '+7 (${digits.substring(1)}';
    } else if (digits.length <= 7) {
      formatted = '+7 (${digits.substring(1, 4)}) ${digits.substring(4)}';
    } else if (digits.length <= 9) {
      formatted =
          '+7 (${digits.substring(1, 4)}) ${digits.substring(4, 7)}-${digits.substring(7)}';
    } else {
      formatted =
          '+7 (${digits.substring(1, 4)}) ${digits.substring(4, 7)}-${digits.substring(7, 9)}-${digits.substring(9, 11)}';
    }

    if (_phoneController.text != formatted) {
      _phoneController.value = TextEditingValue(
        text: formatted,
        selection: TextSelection.collapsed(offset: formatted.length),
      );
    }
  }

  // 🔥 АВТОЗАПОЛНЕНИЕ ГОРОДА ИЗ АДРЕСА
  void _onAddressChanged(String address) {
    if (_cityController.text.isEmpty && address.contains(',')) {
      final parts = address.split(',');
      if (parts.length > 1) {
        final possibleCity = parts[1].trim();
        if (possibleCity.isNotEmpty) {
          _cityController.text = possibleCity;
        }
      }
    }
  }

  // Валидация телефона
  String? _validatePhone(String? value) {
    if (value == null || value.trim().isEmpty) return null;

    final normalized = PhoneValidator.normalizePhone(value);
    if (normalized == null) return 'Неверный формат телефона';

    final digitsOnly = normalized.replaceAll(RegExp(r'[^0-9]'), '');
    if (digitsOnly.length != 11 || !digitsOnly.startsWith('7')) {
      return 'Телефон должен быть в формате +7 XXX XXX XX XX';
    }

    return null;
  }

  // Получение телефона из буфера обмена
  Future<void> _pastePhoneFromClipboard() async {
    try {
      final clipboardData = await Clipboard.getData('text/plain');
      if (clipboardData?.text != null) {
        final normalized = PhoneValidator.normalizePhone(clipboardData!.text!);
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

  // Проверка, является ли платформа мобильной
  bool get _isMobilePlatform {
    return Platform.isAndroid || Platform.isIOS;
  }

  // Запрос разрешения на контакты
  Future<bool> _requestContactPermission() async {
    var status = await Permission.contacts.status;
    if (status.isDenied) {
      status = await Permission.contacts.request();
    }
    return status.isGranted;
  }

  // Выбор контакта
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

  // Обновление заказов при изменении телефона
  Future<void> _updateOrdersPhone(String oldPhone, String newPhone) async {
    if (oldPhone.isEmpty || oldPhone == newPhone) return;

    try {
      await _apiService.updateOrdersPhone(oldPhone, newPhone);
      print('🔄 Обновление телефона в заказах: $oldPhone -> $newPhone');
    } catch (e) {
      print('❌ Ошибка обновления телефона в заказах: $e');
    }
  }

  // СОХРАНЕНИЕ КЛИЕНТА
  Future<void> _saveClient() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final oldPhone = widget.client?.phone ?? '';
      final newPhone = _phoneController.text.trim().isNotEmpty
          ? PhoneValidator.normalizePhone(_phoneController.text.trim()) ?? ''
          : '';

      final client = Client(
        name: _nameController.text.trim().isNotEmpty
            ? _nameController.text.trim()
            : null,
        firm: _firmController.text.trim().isNotEmpty
            ? _firmController.text.trim()
            : null,
        postalCode: _postalCodeController.text.trim().isNotEmpty
            ? _postalCodeController.text.trim()
            : null,
        phone: newPhone.isNotEmpty ? newPhone : null,
        legalEntity: _legalEntityValue,
        city: _cityController.text.trim().isNotEmpty
            ? _cityController.text.trim()
            : null,
        deliveryAddress: _deliveryAddressController.text.trim().isNotEmpty
            ? _deliveryAddressController.text.trim()
            : null,
        delivery: _deliveryValue,
        comment: _commentController.text.trim().isNotEmpty
            ? _commentController.text.trim()
            : null,
        discount: double.tryParse(_discountController.text.trim()),
        minOrderAmount: double.tryParse(_minOrderAmountController.text.trim()),
      );

      if (widget.client != null) {
        // РЕДАКТИРОВАНИЕ
        final updatedClients = authProvider.clientData!.clients.map((c) {
          if (c.phone == oldPhone) {
            return client;
          }
          return c;
        }).toList();

        authProvider.clientData!.clients = updatedClients;
        authProvider.clientData!.buildIndexes();

        await _apiService.updateClient(client);

        if (oldPhone != newPhone && newPhone.isNotEmpty) {
          await _updateOrdersPhone(oldPhone, newPhone);
        }

        print('✅ Клиент обновлен локально: ${client.name}');
      } else {
        // СОЗДАНИЕ
        final currentClients =
            List<Client>.from(authProvider.clientData!.clients);
        currentClients.add(client);

        authProvider.clientData!.clients = currentClients;
        authProvider.clientData!.buildIndexes();

        await _apiService.createClient(client);

        print('✅ Новый клиент создан локально: ${client.name}');
      }

      await _saveClientDataToPrefs(authProvider);
      Navigator.pop(context, true);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Клиент успешно сохранен'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      print('❌ Ошибка сохранения клиента: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Ошибка сохранения: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() => _isSaving = false);
    }
  }

  // Сохранение данных в SharedPreferences
  Future<void> _saveClientDataToPrefs(AuthProvider authProvider) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final clientDataJson = authProvider.clientData!.toJson();
      await prefs.setString('client_data', jsonEncode(clientDataJson));
    } catch (e) {
      print('❌ Ошибка сохранения ClientData: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.client != null ? 'Редактировать клиента' : 'Новый клиент',
        ),
      ),
      body: _isSaving
          ? Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(16.0),
              child: Form(
                key: _formKey,
                child: ListView(
                  children: [
                    TextFormField(
                      controller: _nameController,
                      decoration: InputDecoration(labelText: 'Клиент *'),
                      validator: (value) =>
                          value!.trim().isEmpty ? 'Обязательное поле' : null,
                    ),
                    TextFormField(
                      controller: _firmController,
                      decoration: InputDecoration(labelText: 'ФИРМА'),
                    ),
                    TextFormField(
                      controller: _postalCodeController,
                      decoration: InputDecoration(labelText: 'Почтовый индекс'),
                    ),

                    // 🔥 ТЕЛЕФОН С ФОРМАТИРОВАНИЕМ
                    TextFormField(
                      controller: _phoneController,
                      decoration: InputDecoration(
                        labelText: 'Телефон',
                        hintText: '+7 XXX XXX XX XX',
                        suffixIcon: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: Icon(Icons.paste),
                              onPressed: _pastePhoneFromClipboard,
                              tooltip: 'Вставить из буфера',
                            ),
                            if (_isMobilePlatform)
                              IconButton(
                                icon: Icon(Icons.contacts),
                                onPressed: _pickContact,
                                tooltip: 'Выбрать из контактов',
                              ),
                          ],
                        ),
                      ),
                      keyboardType: TextInputType.phone,
                      onChanged: _formatPhone, // 👈 ДОБАВЛЕНО
                      validator: _validatePhone,
                    ),

                    CheckboxListTile(
                      title: Text('Юридическое лицо'),
                      value: _legalEntityValue,
                      onChanged: (bool? value) {
                        setState(() {
                          _legalEntityValue = value ?? false;
                        });
                      },
                    ),

                    // 🔥 ГОРОД С АВТОДОПОЛНЕНИЕМ
                    _availableCities.isEmpty
                        ? TextFormField(
                            controller: _cityController,
                            decoration: InputDecoration(labelText: 'Город'),
                          )
                        : Autocomplete<String>(
                            optionsBuilder: (textEditingValue) {
                              if (textEditingValue.text.isEmpty) {
                                return const Iterable<String>.empty();
                              }
                              return _availableCities.where((city) => city
                                  .toLowerCase()
                                  .contains(
                                      textEditingValue.text.toLowerCase()));
                            },
                            fieldViewBuilder: (context, controller, focusNode,
                                onFieldSubmitted) {
                              return TextFormField(
                                controller: _cityController,
                                focusNode: focusNode,
                                decoration: InputDecoration(labelText: 'Город'),
                                onFieldSubmitted: (_) => onFieldSubmitted(),
                              );
                            },
                            onSelected: (selection) {
                              _cityController.text = selection;
                            },
                          ),

                    // 🔥 АДРЕС С АВТОЗАПОЛНЕНИЕМ ГОРОДА
                    TextFormField(
                      controller: _deliveryAddressController,
                      decoration: InputDecoration(labelText: 'Адрес доставки'),
                      onChanged: _onAddressChanged, // 👈 ДОБАВЛЕНО
                    ),

                    CheckboxListTile(
                      title: Text('Доставка'),
                      value: _deliveryValue,
                      onChanged: (bool? value) {
                        setState(() {
                          _deliveryValue = value ?? false;
                        });
                      },
                    ),

                    TextFormField(
                      controller: _commentController,
                      decoration: InputDecoration(labelText: 'Комментарий'),
                      maxLines: 3,
                    ),

                    TextFormField(
                      controller: _discountController,
                      decoration: InputDecoration(labelText: 'Скидка (%)'),
                      keyboardType: TextInputType.number,
                      validator: (value) {
                        if (value!.trim().isEmpty) return null;
                        if (double.tryParse(value) == null)
                          return 'Неверный формат';
                        return null;
                      },
                    ),

                    TextFormField(
                      controller: _minOrderAmountController,
                      decoration:
                          InputDecoration(labelText: 'Сумма миним. заказа'),
                      keyboardType: TextInputType.number,
                      validator: (value) {
                        if (value!.trim().isEmpty) return null;
                        if (double.tryParse(value) == null)
                          return 'Неверный формат';
                        return null;
                      },
                    ),

                    SizedBox(height: 24),

                    ElevatedButton(
                      onPressed: _saveClient,
                      child: Text(
                        widget.client != null ? 'Сохранить' : 'Добавить',
                      ),
                      style: ElevatedButton.styleFrom(
                        minimumSize: Size(double.infinity, 50),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}
