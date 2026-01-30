// lib/screens/admin_client_form_screen.dart
import 'dart:io' show Platform;
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:contacts_service/contacts_service.dart';
import 'package:flutter/services.dart';
import '../services/google_sheets_service.dart';
import '../models/client.dart';
import '../utils/phone_validator.dart'; // ← добавьте импорт

class AdminClientFormScreen extends StatefulWidget {
  final Client? client;

  const AdminClientFormScreen({Key? key, this.client}) : super(key: key);

  @override
  _AdminClientFormScreenState createState() => _AdminClientFormScreenState();
}

class _AdminClientFormScreenState extends State<AdminClientFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _service = GoogleSheetsService(dotenv.env['SPREADSHEET_ID']!);

  late TextEditingController _nameController; // ← изменено с _clientController
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

  @override
  void initState() {
    super.initState();

    if (widget.client != null) {
      _nameController = TextEditingController(
          text: widget.client!.name ?? ''); // ← name вместо client
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
    _nameController.dispose(); // ← изменено
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

  // 🔥 Валидация телефона - используем PhoneValidator
  String? _validatePhone(String? value) {
    if (value == null || value.trim().isEmpty) return null;

    final normalized = PhoneValidator.normalizePhone(value);
    if (normalized == null) return 'Неверный формат телефона';

    // Проверка российского формата
    final digitsOnly = normalized.replaceAll(RegExp(r'[^0-9]'), '');
    if (digitsOnly.length != 11 || !digitsOnly.startsWith('7')) {
      return 'Телефон должен быть в формате +7 XXX XXX XX XX';
    }

    return null;
  }

  // 🔥 Получение телефона из буфера обмена
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

  // 🔥 Проверка, является ли платформа мобильной
  bool get _isMobilePlatform {
    return Platform.isAndroid || Platform.isIOS;
  }

  // 🔥 Запрос разрешения на контакты
  Future<bool> _requestContactPermission() async {
    var status = await Permission.contacts.status;
    if (status.isDenied) {
      status = await Permission.contacts.request();
    }
    return status.isGranted;
  }

  // 🔥 Выбор контакта
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

  // 🔥 Обновление заказов при изменении телефона
  Future<void> _updateOrdersPhone(String oldPhone, String newPhone) async {
    if ((oldPhone.isEmpty || oldPhone == '') && newPhone.isNotEmpty) {
      return;
    }

    final ordersService = GoogleSheetsService(dotenv.env['SPREADSHEET_ID']!);
    await ordersService.init();

    await ordersService.update(
      sheetName: 'Заказы',
      filters: [
        {'column': 'Телефон', 'value': oldPhone},
      ],
      data: {'Телефон': newPhone},
    );
  }

  Future<void> _saveClient() async {
    if (!_formKey.currentState!.validate()) return;

    final oldPhone = widget.client?.phone ?? '';
    final newPhone = _phoneController.text.trim().isNotEmpty
        ? PhoneValidator.normalizePhone(_phoneController.text.trim()) ?? ''
        : '';

    // 🔥 ИСПРАВЛЕНО: используем name вместо client
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

    try {
      await _service.init();

      if (widget.client != null) {
        final updates = <String, dynamic>{};

        if (client.name != widget.client!.name) {
          // ← name вместо client
          updates['Клиент'] = client.name ?? '';
        }
        if (client.firm != widget.client!.firm) {
          updates['ФИРМА'] = client.firm ?? '';
        }
        if (client.postalCode != widget.client!.postalCode) {
          updates['Почтовый индекс'] = client.postalCode ?? '';
        }
        if (client.phone != widget.client!.phone) {
          updates['Телефон'] = client.phone ?? '';
        }
        if (client.legalEntity != widget.client!.legalEntity) {
          updates['Юридическое лицо'] = client.legalEntity.toString();
        }
        if (client.city != widget.client!.city) {
          updates['Город'] = client.city ?? '';
        }
        if (client.deliveryAddress != widget.client!.deliveryAddress) {
          updates['Адрес доставки'] = client.deliveryAddress ?? '';
        }
        if (client.delivery != widget.client!.delivery) {
          updates['Доставка'] = client.delivery.toString();
        }
        if (client.comment != widget.client!.comment) {
          updates['Комментарий'] = client.comment ?? '';
        }
        if (client.discount != widget.client!.discount) {
          updates['Скидка'] = client.discount?.toString() ?? '';
        }
        if (client.minOrderAmount != widget.client!.minOrderAmount) {
          updates['Сумма миним.заказа'] =
              client.minOrderAmount?.toString() ?? '';
        }

        if (updates.isNotEmpty) {
          final filters = [
            {'column': 'Клиент', 'value': widget.client!.name ?? ''}, // ← name
            {'column': 'ФИРМА', 'value': widget.client!.firm ?? ''},
            {'column': 'Телефон', 'value': widget.client!.phone ?? ''},
            {'column': 'Город', 'value': widget.client!.city ?? ''},
            {
              'column': 'Адрес доставки',
              'value': widget.client!.deliveryAddress ?? ''
            },
          ];

          await _service.update(
            sheetName: 'Клиенты',
            filters: filters,
            data: updates,
          );

          if (updates.containsKey('Телефон') && oldPhone != newPhone) {
            await _updateOrdersPhone(oldPhone, newPhone);
          }
        }

        Navigator.pop(context, client);
      } else {
        // Создание нового клиента
        final record = [
          client.name ?? '', // ← name вместо client
          client.firm ?? '',
          client.postalCode ?? '',
          client.phone ?? '',
          client.legalEntity.toString(),
          client.city ?? '',
          client.deliveryAddress ?? '',
          client.delivery.toString(),
          client.comment ?? '',
          '', // latitude
          '', // longitude
          client.discount?.toString() ?? '',
          client.minOrderAmount?.toString() ?? '',
          '', // fcm
        ];

        await _service.create(
          sheetName: 'Клиенты',
          records: [record],
        );

        Navigator.pop(context, true);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Сохранено успешно!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка сохранения: $e')),
        );
      }
      print('Ошибка сохранения: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
            widget.client != null ? 'Редактировать клиента' : 'Новый клиент'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              TextFormField(
                controller: _nameController, // ← name вместо client
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
                tristate: false,
              ),
              TextFormField(
                controller: _cityController,
                decoration: InputDecoration(labelText: 'Город'),
              ),
              TextFormField(
                controller: _deliveryAddressController,
                decoration: InputDecoration(labelText: 'Адрес доставки'),
              ),
              CheckboxListTile(
                title: Text('Доставка'),
                value: _deliveryValue,
                onChanged: (bool? value) {
                  setState(() {
                    _deliveryValue = value ?? false;
                  });
                },
                tristate: false,
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
                  if (double.tryParse(value) == null) return 'Неверный формат';
                  return null;
                },
              ),
              TextFormField(
                controller: _minOrderAmountController,
                decoration: InputDecoration(labelText: 'Сумма миним. заказа'),
                keyboardType: TextInputType.number,
                validator: (value) {
                  if (value!.trim().isEmpty) return null;
                  if (double.tryParse(value) == null) return 'Неверный формат';
                  return null;
                },
              ),
              SizedBox(height: 24),
              ElevatedButton(
                onPressed: _saveClient,
                child: Text(widget.client != null ? 'Сохранить' : 'Добавить'),
                style: ElevatedButton.styleFrom(
                    minimumSize: Size(double.infinity, 50)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
