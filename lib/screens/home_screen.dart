// lib/screens/home_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/user.dart';
import '../providers/product_provider.dart';
import '../providers/auth_provider.dart'; // ← оставить
import 'price_list_screen.dart';

class HomeScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    // 🔹 Используем AuthProvider вместо ClientsProvider
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final productsProvider =
        Provider.of<ProductsProvider>(context, listen: false);

    // Загружаем товары один раз
    if (productsProvider.products.isEmpty && !productsProvider.isLoading) {
      productsProvider.loadProducts();
    }

    // Получаем клиента из AuthProvider
    final client = authProvider.currentUser as Client;

    return Scaffold(
      appBar: AppBar(
        title: Text('Добро пожаловать'),
        actions: [
          IconButton(
            icon: Icon(Icons.logout),
            onPressed: () {
              // 🔹 Вызываем logout у AuthProvider
              authProvider.logout();
            },
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'Привет, ${client.name}!',
              style: TextStyle(fontSize: 24),
            ),
            SizedBox(height: 20),
            if (client.discount != null)
              Text(
                'Ваша персональная скидка: ${client.discount}%',
                style: TextStyle(
                  fontSize: 18,
                  color: Colors.green,
                  fontWeight: FontWeight.bold,
                ),
              )
            else
              SizedBox(height: 30), // или закомментируйте, если не нужно
            ElevatedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => PriceListScreen()),
                );
              },
              child: Text('Перейти к прайс-листу'),
            ),
          ],
        ),
      ),
    );
  }
}
