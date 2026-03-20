// lib/screens/admin/admin_price_list_screen.dart
import 'package:flutter/material.dart';
import '../price_list_management_screen.dart';

class AdminPriceListScreen extends StatelessWidget {
  const AdminPriceListScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return const PriceListManagementScreen(
      title: 'Управление прайс-листом',
    );
  }
}
