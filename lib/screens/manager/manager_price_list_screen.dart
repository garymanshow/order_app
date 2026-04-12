// lib/screens/manager/manager_price_list_screen.dart
import 'package:flutter/material.dart';
import '../price_list_management_screen.dart';

class ManagerPriceListScreen extends StatelessWidget {
  const ManagerPriceListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const PriceListManagementScreen(
      title: 'Прайс-лист',
    );
  }
}
