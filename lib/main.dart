import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'screens/auth_phone_screen.dart';
import 'screens/employee_orders_screen.dart';
import 'screens/home_screen.dart';

import 'providers/cart_provider.dart';
import 'providers/product_provider.dart';
import 'providers/auth_provider.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => CartProvider()),
        ChangeNotifierProvider(create: (_) => ProductsProvider()),
        ChangeNotifierProvider(create: (context) {
          final provider = AuthProvider();
          provider.init();
          return provider;
        }),
      ],
      child: MaterialApp(
        title: 'Формирование заявки',
        theme: ThemeData(primarySwatch: Colors.blue),
        home: AuthOrHomeRouter(), // новый виджет
      ),
    );
  }
}

class AuthOrHomeRouter extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);

    if (authProvider.isLoading) {
      return Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (!authProvider.isAuthenticated) {
      return AuthPhoneScreen();
    }

    if (authProvider.isEmployee) {
      return EmployeeOrdersScreen();
    } else {
      return HomeScreen(); // для клиентов
    }
  }
}
