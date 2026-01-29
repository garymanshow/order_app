// lib/screens/admin_employees_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../services/google_sheets_service.dart';
import '../models/employee.dart';
import 'admin_employee_form_screen.dart';

class AdminEmployeesScreen extends StatefulWidget {
  @override
  _AdminEmployeesScreenState createState() => _AdminEmployeesScreenState();
}

class _AdminEmployeesScreenState extends State<AdminEmployeesScreen> {
  List<Employee> _employees = [];
  bool _isLoading = false;
  final GoogleSheetsService _service =
      GoogleSheetsService(dotenv.env['SPREADSHEET_ID']!);

  @override
  void initState() {
    super.initState();
    _loadEmployees();
  }

  Future<void> _loadEmployees() async {
    setState(() {
      _isLoading = true;
    });
    try {
      await _service.init();
      final data = await _service.read(sheetName: 'Сотрудники');
      final employees = data.map((row) => Employee.fromMap(row)).toList();
      setState(() {
        _employees = employees;
        _isLoading = false;
      });
    } catch (e) {
      print('Ошибка загрузки сотрудников: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _updateEmployeeInList(Employee updatedEmployee) {
    setState(() {
      final index = _employees
          .indexWhere((employee) => employee.phone == updatedEmployee.phone);
      if (index != -1) {
        _employees[index] = updatedEmployee;
      }
    });
  }

  Future<void> _deleteEmployee(Employee employee) async {
    await _service.delete(
      sheetName: 'Сотрудники',
      filters: [
        {'column': 'Телефон', 'value': employee.phone ?? ''},
      ],
    );
    _loadEmployees();
  }

  void _showDeleteConfirmation(Employee employee) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Удалить сотрудника?'),
        content: Text(
            'Вы уверены, что хотите удалить "${employee.getDisplayName}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Отмена'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _deleteEmployee(employee);
            },
            child: Text('Удалить', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Сотрудники'),
        actions: [
          IconButton(
            icon: Icon(Icons.add),
            onPressed: () async {
              final result = await Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => AdminEmployeeFormScreen()),
              );
              if (result == true || result is Employee) {
                _loadEmployees();
              }
            },
            tooltip: 'Добавить сотрудника',
          ),
        ],
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : _employees.isEmpty
              ? Center(child: Text('Список сотрудников пуст'))
              : ListView.builder(
                  itemCount: _employees.length,
                  itemBuilder: (context, index) {
                    final employee = _employees[index];
                    return Card(
                      margin: EdgeInsets.all(8),
                      child: ListTile(
                        title: Text(employee.name ?? ''),
                        subtitle: Text(employee.role ?? ''),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: Icon(Icons.edit),
                              onPressed: () async {
                                final result = await Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => AdminEmployeeFormScreen(
                                        employee: employee),
                                  ),
                                );
                                if (result is Employee) {
                                  _updateEmployeeInList(result);
                                } else if (result == true) {
                                  _loadEmployees();
                                }
                              },
                            ),
                            IconButton(
                              icon: Icon(Icons.delete, color: Colors.red),
                              onPressed: () =>
                                  _showDeleteConfirmation(employee),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}
