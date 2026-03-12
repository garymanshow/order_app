// lib/screens/admin_employees_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../providers/auth_provider.dart';
import '../services/api_service.dart';
import '../models/employee.dart';
import 'admin_employee_form_screen.dart';

class AdminEmployeesScreen extends StatefulWidget {
  @override
  _AdminEmployeesScreenState createState() => _AdminEmployeesScreenState();
}

class _AdminEmployeesScreenState extends State<AdminEmployeesScreen> {
  List<Employee> _filteredEmployees = [];
  String _searchQuery = '';
  String? _selectedRole;
  List<String> _roles = [];
  bool _isLoading = false;
  final ApiService _apiService = ApiService();

  // Цвета для ролей
  final Map<String, Color> _roleColors = {
    'Администратор': Colors.red,
    'Менеджер': Colors.blue,
    'Водитель': Colors.orange,
    'Разработчик': Colors.purple,
    'Кладовщик': Colors.brown,
    'Повар': Colors.teal,
    'Упаковщик': Colors.indigo,
  };

  @override
  void initState() {
    super.initState();
    _loadEmployees();
  }

  // ЗАГРУЗКА СОТРУДНИКОВ ИЗ ЛОКАЛЬНЫХ ДАННЫХ
  void _loadEmployees() {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);

    // Получаем только сотрудников из clients
    final employees =
        authProvider.clientData?.clients.whereType<Employee>().toList() ?? [];

    // Получаем уникальные роли
    final roles = employees
        .map((e) => e.role)
        .where((role) => role != null && role.isNotEmpty)
        .toSet()
        .toList() as List<String>;

    roles.sort();

    setState(() {
      _filteredEmployees = employees;
      _roles = roles;
    });

    print('📊 Загружено сотрудников: ${employees.length}');
  }

  // ПОИСК СОТРУДНИКОВ
  void _filterEmployees(String query) {
    setState(() {
      _searchQuery = query.toLowerCase();
      _applyFilters();
    });
  }

  // ФИЛЬТР ПО РОЛИ
  void _filterByRole(String? role) {
    setState(() {
      _selectedRole = role;
      _applyFilters();
    });
  }

  // ПРИМЕНЕНИЕ ФИЛЬТРОВ
  void _applyFilters() {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final allEmployees =
        authProvider.clientData?.clients.whereType<Employee>().toList() ?? [];

    _filteredEmployees = allEmployees.where((employee) {
      final matchesSearch = _searchQuery.isEmpty ||
          employee.name?.toLowerCase().contains(_searchQuery) == true ||
          employee.phone?.toLowerCase().contains(_searchQuery) == true ||
          employee.role?.toLowerCase().contains(_searchQuery) == true;

      final matchesRole =
          _selectedRole == null || employee.role == _selectedRole;

      return matchesSearch && matchesRole;
    }).toList();
  }

  // УДАЛЕНИЕ СОТРУДНИКА
  Future<void> _deleteEmployee(Employee employee) async {
    setState(() => _isLoading = true);

    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);

      // 🔥 ИСПРАВЛЕНО: правильная проверка на null
      if (employee.phone == null || employee.phone!.isEmpty) {
        _showSnackBar('Ошибка: у сотрудника нет телефона', Colors.red);
        return;
      }

      // Удаляем из локального списка
      authProvider.clientData!.clients.removeWhere((c) {
        if (c is Employee) {
          return c.phone == employee.phone;
        }
        return false;
      });

      // Перестраиваем индексы
      authProvider.clientData!.buildIndexes();

      // Сохраняем в SharedPreferences
      await _saveToPrefs(authProvider);

      // 🔥 ИСПРАВЛЕНО: используем ! после проверки
      await _apiService.deleteEmployee(employee.phone!);

      // Обновляем отображение
      _loadEmployees();

      _showSnackBar('Сотрудник удален', Colors.green);
    } catch (e) {
      print('❌ Ошибка удаления сотрудника: $e');
      _showSnackBar('Ошибка удаления: $e', Colors.red);
    } finally {
      setState(() => _isLoading = false);
    }
  }

  // СОХРАНЕНИЕ В SHAREDPREFERENCES
  Future<void> _saveToPrefs(AuthProvider authProvider) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final clientDataJson = authProvider.clientData!.toJson();
      await prefs.setString('client_data', jsonEncode(clientDataJson));
    } catch (e) {
      print('❌ Ошибка сохранения ClientData: $e');
    }
  }

  // ДИАЛОГ ПОДТВЕРЖДЕНИЯ УДАЛЕНИЯ
  void _showDeleteConfirmation(Employee employee) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Удалить сотрудника?'),
        content: Text(
            'Вы уверены, что хотите удалить "${employee.getDisplayName}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Отмена'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _deleteEmployee(employee);
            },
            child: const Text(
              'Удалить',
              style: TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );
  }

  // ПОКАЗ SNACKBAR
  void _showSnackBar(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  // ПОЛУЧЕНИЕ ЦВЕТА ДЛЯ РОЛИ
  Color _getRoleColor(String? role) {
    if (role == null) return Colors.grey;
    return _roleColors[role] ?? Colors.grey;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Сотрудники'),
        backgroundColor: Theme.of(context).primaryColor,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadEmployees,
            tooltip: 'Обновить',
          ),
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () async {
              final result = await Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => AdminEmployeeFormScreen()),
              );
              if (result == true) {
                _loadEmployees();
              }
            },
            tooltip: 'Добавить сотрудника',
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(110),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: TextField(
                  decoration: InputDecoration(
                    hintText: 'Поиск сотрудников...',
                    prefixIcon: const Icon(Icons.search),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide.none,
                    ),
                    filled: true,
                    fillColor: Colors.white,
                    contentPadding: const EdgeInsets.symmetric(vertical: 0),
                  ),
                  onChanged: _filterEmployees,
                ),
              ),
              if (_roles.isNotEmpty)
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  child: Row(
                    children: [
                      FilterChip(
                        label: const Text('Все'),
                        selected: _selectedRole == null,
                        onSelected: (_) => _filterByRole(null),
                        backgroundColor: Colors.grey[100],
                        selectedColor: Colors.green.shade100,
                      ),
                      const SizedBox(width: 8),
                      ..._roles.map((role) => Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: FilterChip(
                              label: Text(role),
                              selected: _selectedRole == role,
                              onSelected: (_) => _filterByRole(role),
                              backgroundColor: Colors.grey[100],
                              selectedColor:
                                  _getRoleColor(role).withOpacity(0.2),
                              checkmarkColor: _getRoleColor(role),
                            ),
                          )),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _filteredEmployees.isEmpty
              ? _buildEmptyState()
              : ListView.builder(
                  padding: const EdgeInsets.all(8),
                  itemCount: _filteredEmployees.length,
                  itemBuilder: (context, index) {
                    final employee = _filteredEmployees[index];
                    return _buildEmployeeCard(employee);
                  },
                ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          final result = await Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => AdminEmployeeFormScreen()),
          );
          if (result == true) {
            _loadEmployees();
          }
        },
        child: const Icon(Icons.add),
      ),
    );
  }

  // КАРТОЧКА СОТРУДНИКА
  Widget _buildEmployeeCard(Employee employee) {
    final roleColor = _getRoleColor(employee.role);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: () async {
          final result = await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => AdminEmployeeFormScreen(employee: employee),
            ),
          );
          if (result == true) {
            _loadEmployees();
          }
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              CircleAvatar(
                radius: 24,
                backgroundColor: roleColor.withOpacity(0.2),
                child: Text(
                  employee.name?.substring(0, 1).toUpperCase() ?? '?',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: roleColor,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      employee.name ?? 'Без имени',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: roleColor.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            employee.role ?? 'Без роли',
                            style: TextStyle(
                              fontSize: 11,
                              color: roleColor,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        if (employee.twoFactorAuth)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.green.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Text(
                              '2FA',
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.green,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(Icons.phone, size: 14, color: Colors.grey),
                        const SizedBox(width: 4),
                        Text(
                          employee.phone ?? 'Нет телефона',
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.grey,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.edit, color: Colors.blue),
                    onPressed: () async {
                      final result = await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) =>
                              AdminEmployeeFormScreen(employee: employee),
                        ),
                      );
                      if (result == true) {
                        _loadEmployees();
                      }
                    },
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete, color: Colors.red),
                    onPressed: () => _showDeleteConfirmation(employee),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ПУСТОЕ СОСТОЯНИЕ
  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.people_outline,
            size: 80,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            _searchQuery.isNotEmpty || _selectedRole != null
                ? 'Ничего не найдено'
                : 'Нет сотрудников',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _searchQuery.isNotEmpty || _selectedRole != null
                ? 'Попробуйте изменить параметры поиска'
                : 'Нажмите + чтобы добавить сотрудника',
            style: TextStyle(color: Colors.grey[500]),
          ),
        ],
      ),
    );
  }
}
