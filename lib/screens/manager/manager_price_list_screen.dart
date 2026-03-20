// lib/screens/manager/manager_price_list_screen.dart
import 'package:flutter/material.dart';
import '../price_list_management_screen.dart';

class ManagerPriceListScreen extends StatelessWidget {
  const ManagerPriceListScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return const PriceListManagementScreen(
      title: 'Прайс-лист',
    );
  }
}
