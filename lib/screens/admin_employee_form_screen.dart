// lib/screens/admin_employee_form_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../services/google_sheets_service.dart';
import '../models/employee.dart';
import '../utils/phone_validator.dart';

class AdminEmployeeFormScreen extends StatefulWidget {
  final Employee? employee;

  const AdminEmployeeFormScreen({Key? key, this.employee}) : super(key: key);

  @override
  _AdminEmployeeFormScreenState createState() =>
      _AdminEmployeeFormScreenState();
}

class _AdminEmployeeFormScreenState extends State<AdminEmployeeFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _service = GoogleSheetsService(dotenv.env['SPREADSHEET_ID']!);

  late TextEditingController _nameController;
  late TextEditingController _phoneController;
  late String _selectedRole;

  List<String> _availableRoles = [];
  bool _isLoadingRoles = false;

  @override
  void initState() {
    super.initState();

    // Загружаем доступные роли
    _loadAvailableRoles();

    if (widget.employee != null) {
      _nameController =
          TextEditingController(text: widget.employee!.name ?? '');
      _phoneController =
          TextEditingController(text: widget.employee!.phone ?? '');
      _selectedRole = widget.employee!.role ?? '';
    } else {
      _nameController = TextEditingController();
      _phoneController = TextEditingController();
      _selectedRole = ''; // будет установлено после загрузки ролей
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _loadAvailableRoles() async {
    setState(() {
      _isLoadingRoles = true;
    });

    try {
      await _service.init();
      final data = await _service.read(sheetName: 'Сотрудники');

      final roles = data
          .map((row) => row['Роль']?.toString() ?? '')
          .where((role) => role.isNotEmpty)
          .toSet()
          .toList();

      // Добавляем стандартные роли на русском, если таблица пустая
      if (roles.isEmpty) {
        roles.addAll([
          'Администратор',
          'Менеджер',
          'Водитель',
          'Разработчик',
          'Кладовщик'
        ]);
      }

      roles.sort();
      setState(() {
        _availableRoles = roles;
        if (widget.employee == null &&
            _selectedRole.isEmpty &&
            roles.isNotEmpty) {
          _selectedRole = roles[0];
        }
      });
    } catch (e) {
      print('Ошибка загрузки ролей: $e');
      // Стандартные роли на случай ошибки
      setState(() {
        _availableRoles = [
          'Администратор',
          'Менеджер',
          'Водитель',
          'Разработчик',
          'Кладовщик'
        ];
        if (widget.employee == null && _selectedRole.isEmpty) {
          _selectedRole = 'Администратор';
        }
      });
    } finally {
      setState(() {
        _isLoadingRoles = false;
      });
    }
  }

  Future<void> _saveEmployee() async {
    if (!_formKey.currentState!.validate()) return;

    final employee = Employee(
      name: _nameController.text.trim().isNotEmpty
          ? _nameController.text.trim()
          : null,
      phone: PhoneValidator.normalizePhone(_phoneController.text.trim()) ?? '',
      role: _selectedRole.isNotEmpty ? _selectedRole : null,
      // FCM не редактируется вручную
    );

    try {
      await _service.init();

      if (widget.employee != null) {
        // Обновление существующего сотрудника
        final updates = <String, dynamic>{};

        if (employee.name != widget.employee!.name) {
          updates['Сотрудник'] = employee.name ?? '';
        }
        if (employee.phone != widget.employee!.phone) {
          updates['Телефон'] = employee.phone ?? '';
        }
        if (employee.role != widget.employee!.role) {
          updates['Роль'] = employee.role ?? '';
        }

        if (updates.isNotEmpty) {
          // Безопасная обработка nullable телефона
          final phoneFilter = widget.employee!.phone ?? '';
          await _service.update(
            sheetName: 'Сотрудники',
            filters: [
              {'column': 'Телефон', 'value': phoneFilter},
            ],
            data: updates,
          );
        }

        Navigator.pop(context, employee);
      } else {
        // Создание нового сотрудника
        final record = [
          employee.name ?? '',
          employee.phone ?? '',
          employee.role ?? '',
          employee.fcm ?? '',
        ];

        await _service.create(
          sheetName: 'Сотрудники',
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
        title: Text(widget.employee != null
            ? 'Редактировать сотрудника'
            : 'Новый сотрудник'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              TextFormField(
                controller: _nameController,
                decoration: InputDecoration(labelText: 'Сотрудник *'),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Обязательное поле';
                  }
                  return null;
                },
              ),
              TextFormField(
                controller: _phoneController,
                decoration: InputDecoration(
                  labelText: 'Телефон *',
                  hintText: '+7 XXX XXX XX XX',
                ),
                keyboardType: TextInputType.phone,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Обязательное поле';
                  }
                  return PhoneValidator.validatePhone(value);
                },
              ),

              // Выбор роли из выпадающего списка (русские названия)
              if (_isLoadingRoles)
                ListTile(
                  title: Text('Загрузка ролей...'),
                  leading: CircularProgressIndicator(),
                ),
              if (!_isLoadingRoles)
                DropdownButtonFormField<String>(
                  initialValue: _selectedRole.isEmpty ? null : _selectedRole,
                  decoration: InputDecoration(
                    labelText: 'Роль *',
                    errorText: _selectedRole.isEmpty ? 'Выберите роль' : null,
                  ),
                  items: _availableRoles.map((String role) {
                    return DropdownMenuItem<String>(
                      value: role,
                      child: Text(role),
                    );
                  }).toList(),
                  onChanged: (String? newValue) {
                    setState(() {
                      _selectedRole = newValue ?? '';
                    });
                  },
                  validator: (value) {
                    if (_selectedRole.isEmpty) {
                      return 'Выберите роль';
                    }
                    return null;
                  },
                ),

              SizedBox(height: 24),
              ElevatedButton(
                onPressed: _saveEmployee,
                child: Text(widget.employee != null ? 'Сохранить' : 'Добавить'),
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
