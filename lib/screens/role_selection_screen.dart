// lib/screens/role_selection_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/employee.dart';
import '../providers/auth_provider.dart';

class RoleSelectionScreen extends StatelessWidget {
  final List<Employee> roles;

  const RoleSelectionScreen({Key? key, required this.roles}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Выберите роль'),
      ),
      body: ListView.builder(
        itemCount: roles.length,
        itemBuilder: (context, index) {
          final role = roles[index];
          return ListTile(
            title: Text(role.name ?? ''),
            subtitle: Text(role.role ?? ''),
            leading: _getRoleIcon(role.role),
            onTap: () {
              final authProvider =
                  Provider.of<AuthProvider>(context, listen: false);
              authProvider.selectRole(role);
              // После выбора роли произойдет перестроение AuthOrHomeRouter
            },
          );
        },
      ),
    );
  }

  Icon _getRoleIcon(String? role) {
    switch (role) {
      case 'Администратор':
        return Icon(Icons.admin_panel_settings);
      case 'Менеджер':
        return Icon(Icons.people);
      case 'Кладовщик':
        return Icon(Icons.warehouse);
      case 'Водитель':
        return Icon(Icons.directions_car);
      default:
        return Icon(Icons.person);
    }
  }
}
