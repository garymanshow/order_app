import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../../providers/auth_provider.dart';
import '../../services/api_service.dart';
import 'admin_employee_form_screen.dart';

class AdminEmployeesScreen extends StatefulWidget {
  const AdminEmployeesScreen({super.key});

  @override
  State<AdminEmployeesScreen> createState() => _AdminEmployeesScreenState();
}

class _AdminEmployeesScreenState extends State<AdminEmployeesScreen> {
  // Работаем с dynamic, так как сотрудники лежат в общем массиве с клиентами
  List<dynamic> _filteredEmployees = [];
  String _searchQuery = '';
  String? _selectedRole;
  List<String> _roles = [];
  bool _isLoading = false;
  bool _showOnly2FA = false;
  final ApiService _apiService = ApiService();

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

  // ЗАГРУЗКА СОТРУДНИКОВ
  void _loadEmployees() {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final allClients = authProvider.clientData?.clients ?? [];

    final employees = allClients.where((c) {
      try {
        final role = (c as dynamic).role as String?;
        return role != null &&
            role.isNotEmpty &&
            role.toLowerCase() != 'клиент';
      } catch (e) {
        return false; // Игнорируем ошибки
      }
    }).toList();

    final Set<String> tempRoles = {};
    for (var e in employees) {
      try {
        final role = (e as dynamic).role as String?;
        if (role != null && role.isNotEmpty) {
          tempRoles.add(role);
        }
      } catch (e) {/* ignore */}
    }
    final roles = tempRoles.toList()..sort();

    setState(() {
      _filteredEmployees = employees;
      _roles = roles;
    });
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
    final allClients = authProvider.clientData?.clients ?? [];

    _filteredEmployees = allClients.where((c) {
      try {
        final dynamic emp = c;
        bool matches = true;

        final role = emp.role as String?;
        if (role == null || role.isEmpty || role.toLowerCase() == 'клиент')
          return false;

        if (_searchQuery.isNotEmpty) {
          final name = (emp.name as String?)?.toLowerCase() ?? '';
          final phone = (emp.phone as String?)?.toLowerCase() ?? '';
          final email = (emp.email as String?)?.toLowerCase() ?? '';

          matches = name.contains(_searchQuery) ||
              phone.contains(_searchQuery) ||
              role.toLowerCase().contains(_searchQuery) ||
              email.contains(_searchQuery);
        }

        if (_selectedRole != null) {
          matches = matches && role == _selectedRole;
        }

        if (_showOnly2FA) {
          matches = matches && (emp.twoFactorAuth == true);
        }

        return matches;
      } catch (e) {
        return false;
      }
    }).toList();
  }

  // УДАЛЕНИЕ СОТРУДНИКА
  Future<void> _deleteEmployee(dynamic employee) async {
    setState(() => _isLoading = true);

    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final phone = (employee.phone as String?) ?? '';

      if (phone.isEmpty) {
        _showSnackBar('Ошибка: у сотрудника нет телефона', Colors.red);
        return;
      }

      authProvider.clientData!.clients.removeWhere((c) => c.phone == phone);
      authProvider.clientData!.buildIndexes();

      await _saveToPrefs(authProvider);
      await _apiService.deleteEmployee(phone);

      _loadEmployees();
      _showSnackBar('Сотрудник удален', Colors.green);
    } catch (e) {
      _showSnackBar('Ошибка удаления', Colors.red);
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _saveToPrefs(AuthProvider authProvider) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final clientDataJson = authProvider.clientData!.toJson();
      await prefs.setString('client_data', jsonEncode(clientDataJson));
    } catch (e) {/* ignore */}
  }

  void _showDeleteConfirmation(dynamic employee) {
    final name = (employee.name as String?) ?? 'Сотрудник';
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Удалить сотрудника?'),
        content: Text('Вы уверены, что хотите удалить "$name"?'),
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
            child: const Text('Удалить', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void _showSnackBar(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
          content: Text(message),
          backgroundColor: color,
          duration: const Duration(seconds: 2)),
    );
  }

  Color _getRoleColor(String? role) {
    if (role == null) return Colors.grey;
    return _roleColors[role] ?? Colors.grey;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Сотрудники'),
        actions: [
          IconButton(
            icon: Icon(_showOnly2FA ? Icons.security : Icons.security_outlined),
            onPressed: () {
              setState(() {
                _showOnly2FA = !_showOnly2FA;
                _applyFilters();
              });
            },
            tooltip: _showOnly2FA ? 'Показать всех' : 'Только с 2FA',
          ),
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
                MaterialPageRoute(
                    builder: (_) => const AdminEmployeeFormScreen()),
              );
              if (result == true) _loadEmployees();
            },
            tooltip: 'Добавить сотрудника',
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(100),
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
                                  _getRoleColor(role).withValues(alpha: 0.2),
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
                    return _buildEmployeeCard(_filteredEmployees[index]);
                  },
                ),
    );
  }

  // КАРТОЧКА СОТРУДНИКА
  Widget _buildEmployeeCard(dynamic employee) {
    final String name = (employee.name as String?) ?? 'Без имени';
    final String phone = (employee.phone as String?) ?? 'Нет телефона';
    final String? email = employee.email as String?;
    final String role = (employee.role as String?) ?? 'Без роли';
    final bool twoFactorAuth = employee.twoFactorAuth == true;
    final roleColor = _getRoleColor(role);

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
          if (result == true) _loadEmployees();
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              CircleAvatar(
                radius: 24,
                backgroundColor: roleColor.withValues(alpha: 0.2),
                child: Text(
                  name.substring(0, 1).toUpperCase(),
                  style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: roleColor),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name,
                        style: const TextStyle(
                            fontSize: 16, fontWeight: FontWeight.bold)),
                    if (email != null && email.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          const Icon(Icons.email, size: 14, color: Colors.grey),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(email,
                                style: const TextStyle(
                                    fontSize: 12, color: Colors.grey),
                                overflow: TextOverflow.ellipsis),
                          ),
                        ],
                      ),
                    ],
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                              color: roleColor.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(12)),
                          child: Text(role,
                              style: TextStyle(
                                  fontSize: 11,
                                  color: roleColor,
                                  fontWeight: FontWeight.w500)),
                        ),
                        const SizedBox(width: 8),
                        if (twoFactorAuth)
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                                color: Colors.green.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(12)),
                            child: const Text('2FA',
                                style: TextStyle(
                                    fontSize: 11,
                                    color: Colors.green,
                                    fontWeight: FontWeight.w500)),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(Icons.phone, size: 14, color: Colors.grey),
                        const SizedBox(width: 4),
                        Text(phone,
                            style: const TextStyle(
                                fontSize: 12, color: Colors.grey)),
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
                                AdminEmployeeFormScreen(employee: employee)),
                      );
                      if (result == true) _loadEmployees();
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

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.people_outline, size: 80, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text(
            _searchQuery.isNotEmpty || _selectedRole != null || _showOnly2FA
                ? 'Ничего не найдено'
                : 'Нет сотрудников',
            style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.grey[600]),
          ),
          const SizedBox(height: 8),
          Text(
            _searchQuery.isNotEmpty || _selectedRole != null || _showOnly2FA
                ? 'Попробуйте изменить параметры поиска'
                : 'Нажмите + чтобы добавить сотрудника',
            style: TextStyle(color: Colors.grey[500]),
          ),
        ],
      ),
    );
  }
}
