// lib/screens/admin_employee_form_screen.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../providers/auth_provider.dart';
import '../services/api_service.dart';
import '../models/employee.dart';
import '../models/client.dart'; // 👈 ДОБАВЛЕНО для приведения типов
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
  final ApiService _apiService = ApiService();

  late TextEditingController _nameController;
  late TextEditingController _phoneController;
  late String _selectedRole;
  late bool _twoFactorAuth;

  List<String> _availableRoles = [];
  bool _isLoadingRoles = false;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();

    _loadAvailableRoles();

    if (widget.employee != null) {
      _nameController =
          TextEditingController(text: widget.employee!.name ?? '');
      _phoneController =
          TextEditingController(text: widget.employee!.phone ?? '');
      _selectedRole = widget.employee!.role ?? '';
      _twoFactorAuth = widget.employee!.twoFactorAuth;
    } else {
      _nameController = TextEditingController();
      _phoneController = TextEditingController();
      _selectedRole = '';
      _twoFactorAuth = false;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  // ЗАГРУЗКА ДОСТУПНЫХ РОЛЕЙ
  Future<void> _loadAvailableRoles() async {
    setState(() => _isLoadingRoles = true);

    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);

      final employees =
          authProvider.clientData?.clients.whereType<Employee>().toList() ?? [];

      final roles = employees
          .map((e) => e.role)
          .where((role) => role != null && role.isNotEmpty)
          .toSet()
          .toList() as List<String>;

      if (roles.isEmpty) {
        roles.addAll([
          'Администратор',
          'Менеджер',
          'Водитель',
          'Разработчик',
          'Кладовщик',
          'Повар',
          'Упаковщик',
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
      print('❌ Ошибка загрузки ролей: $e');
      setState(() {
        _availableRoles = [
          'Администратор',
          'Менеджер',
          'Водитель',
          'Разработчик',
          'Кладовщик',
          'Повар',
          'Упаковщик',
        ];
        if (widget.employee == null && _selectedRole.isEmpty) {
          _selectedRole = 'Менеджер';
        }
      });
    } finally {
      setState(() => _isLoadingRoles = false);
    }
  }

  // СОХРАНЕНИЕ СОТРУДНИКА
  Future<void> _saveEmployee() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    try {
      final normalizedPhone =
          PhoneValidator.normalizePhone(_phoneController.text.trim()) ?? '';

      final employee = Employee(
        name: _nameController.text.trim().isNotEmpty
            ? _nameController.text.trim()
            : null,
        phone: normalizedPhone,
        role: _selectedRole.isNotEmpty ? _selectedRole : null,
        twoFactorAuth: _twoFactorAuth,
        fcm: widget.employee?.fcm,
      );

      final authProvider = Provider.of<AuthProvider>(context, listen: false);

      if (widget.employee != null) {
        // Обновление
        final index = authProvider.clientData!.clients.indexWhere((c) {
          if (c is Employee) {
            return c.phone == widget.employee!.phone;
          }
          return false;
        });

        if (index != -1) {
          // 🔥 ЯВНОЕ ПРИВЕДЕНИЕ К ТИПУ Client
          authProvider.clientData!.clients[index] = employee as Client;
          authProvider.clientData!.buildIndexes();
          await _apiService.updateEmployee(employee);
          print('✅ Сотрудник обновлен: ${employee.name}');
        }
      } else {
        // Создание
        // 🔥 ЯВНОЕ ПРИВЕДЕНИЕ К ТИПУ Client
        authProvider.clientData!.clients.add(employee as Client);
        authProvider.clientData!.buildIndexes();
        await _apiService.createEmployee(employee);
        print('✅ Новый сотрудник создан: ${employee.name}');
      }

      await _saveEmployeesToPrefs(authProvider);

      if (mounted) {
        Navigator.pop(context, true);
        _showSnackBar('Сотрудник успешно сохранен', Colors.green);
      }
    } catch (e) {
      print('❌ Ошибка сохранения сотрудника: $e');
      if (mounted) {
        _showSnackBar('Ошибка сохранения: $e', Colors.red);
      }
    } finally {
      setState(() => _isSaving = false);
    }
  }

  // СОХРАНЕНИЕ В SHAREDPREFERENCES
  Future<void> _saveEmployeesToPrefs(AuthProvider authProvider) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final clientDataJson = authProvider.clientData!.toJson();
      await prefs.setString('client_data', jsonEncode(clientDataJson));
    } catch (e) {
      print('❌ Ошибка сохранения ClientData: $e');
    }
  }

  void _showSnackBar(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.employee != null
            ? 'Редактировать сотрудника'
            : 'Новый сотрудник'),
        backgroundColor: Theme.of(context).primaryColor,
        elevation: 0,
      ),
      body: _isSaving
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(16.0),
              child: Form(
                key: _formKey,
                child: ListView(
                  children: [
                    Card(
                      elevation: 2,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          children: [
                            TextFormField(
                              controller: _nameController,
                              decoration: InputDecoration(
                                labelText: 'Сотрудник *',
                                prefixIcon: const Icon(Icons.person),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                              validator: (value) {
                                if (value == null || value.trim().isEmpty) {
                                  return 'Обязательное поле';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 16),
                            TextFormField(
                              controller: _phoneController,
                              decoration: InputDecoration(
                                labelText: 'Телефон *',
                                hintText: '+7 XXX XXX XX XX',
                                prefixIcon: const Icon(Icons.phone),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                              keyboardType: TextInputType.phone,
                              validator: (value) {
                                if (value == null || value.trim().isEmpty) {
                                  return 'Обязательное поле';
                                }
                                final normalized =
                                    PhoneValidator.normalizePhone(value);
                                if (normalized == null) {
                                  return 'Неверный формат телефона';
                                }
                                return null;
                              },
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Card(
                      elevation: 2,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Роль сотрудника',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 12),
                            if (_isLoadingRoles)
                              const Center(
                                child: Padding(
                                  padding: EdgeInsets.all(16),
                                  child: CircularProgressIndicator(),
                                ),
                              ),
                            if (!_isLoadingRoles)
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: _availableRoles.map((role) {
                                  final isSelected = _selectedRole == role;
                                  return FilterChip(
                                    label: Text(role),
                                    selected: isSelected,
                                    onSelected: (selected) {
                                      setState(() {
                                        _selectedRole = role;
                                      });
                                    },
                                    backgroundColor: Colors.grey[100],
                                    selectedColor: Colors.green.shade100,
                                    checkmarkColor: Colors.green,
                                  );
                                }).toList(),
                              ),
                            if (_selectedRole.isEmpty && !_isLoadingRoles)
                              const Padding(
                                padding: EdgeInsets.only(top: 8),
                                child: Text(
                                  'Выберите роль',
                                  style: TextStyle(
                                      color: Colors.red, fontSize: 12),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Card(
                      elevation: 2,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Безопасность',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 8),
                            SwitchListTile(
                              title: const Text('Двухфакторная аутентификация'),
                              subtitle: const Text(
                                'Требовать подтверждение по SMS при входе',
                                style: TextStyle(fontSize: 12),
                              ),
                              value: _twoFactorAuth,
                              onChanged: (value) {
                                setState(() {
                                  _twoFactorAuth = value;
                                });
                              },
                              secondary: Icon(
                                _twoFactorAuth
                                    ? Icons.security
                                    : Icons.security_outlined,
                                color:
                                    _twoFactorAuth ? Colors.green : Colors.grey,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton.icon(
                      onPressed: _saveEmployee,
                      icon: const Icon(Icons.save),
                      label: Text(
                        widget.employee != null
                            ? 'Сохранить'
                            : 'Добавить сотрудника',
                        style: const TextStyle(fontSize: 16),
                      ),
                      style: ElevatedButton.styleFrom(
                        minimumSize: const Size(double.infinity, 50),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(25),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}
