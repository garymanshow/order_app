// lib/services/delivery_conditions_service.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../providers/auth_provider.dart';
import '../models/delivery_condition.dart';
import '../models/client.dart';

class DeliveryConditionsService {
  // 🔥 ПОЛУЧЕНИЕ УСЛОВИЙ ДОСТАВКИ ИЗ ЛОКАЛЬНЫХ ДАННЫХ
  Future<List<DeliveryCondition>> fetchConditions(BuildContext context) async {
    print('📦 Загрузка условий доставки из локальных данных...');

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final deliveryConditions =
        authProvider.clientData?.deliveryConditions ?? [];

    print('📋 Всего загружено условий доставки: ${deliveryConditions.length}');

    for (final condition in deliveryConditions) {
      print('📋 Условие — Пункт: "${condition.location}", '
          'Мин.сумма заказа: ${condition.deliveryAmount}, '
          'Наценка: ${condition.hiddenMarkup ?? 0}%');
    }

    return deliveryConditions;
  }

  // 🔥 ПОЛУЧЕНИЕ УСЛОВИЙ ДЛЯ КОНКРЕТНОГО ПУНКТА
  DeliveryCondition? getConditionForLocation(
      String location, BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final deliveryConditions =
        authProvider.clientData?.deliveryConditions ?? [];

    try {
      return deliveryConditions.firstWhere(
        (condition) =>
            condition.location.toLowerCase() == location.toLowerCase(),
      );
    } catch (e) {
      return null;
    }
  }

  // 🔥 ПОЛУЧЕНИЕ МИНИМАЛЬНОЙ СУММЫ ЗАКАЗА ДЛЯ ГОРОДА
  double getMinOrderAmount(String city, BuildContext context) {
    if (city.isEmpty) return 0.0;

    final condition = getConditionForLocation(city, context);
    return condition?.deliveryAmount ?? 0.0;
  }

  // 🔥 ПОЛУЧЕНИЕ НАЦЕНКИ ДЛЯ ГОРОДА
  double getMarkupForCity(String city, BuildContext context) {
    if (city.isEmpty) return 0.0;

    final condition = getConditionForLocation(city, context);
    return condition?.hiddenMarkup ?? 0.0;
  }

  // 🔥 ПОЛУЧЕНИЕ УСЛОВИЙ ДЛЯ КОНКРЕТНОГО ГОРОДА (алиас)
  DeliveryCondition? getConditionForCity(String city, BuildContext context) {
    return getConditionForLocation(city, context);
  }

  // 🔥 РАСЧЕТ ИТОГОВОЙ ЦЕНЫ С УЧЕТОМ НАЦЕНКИ И СКИДКИ
  double calculateFinalPrice(
    double basePrice,
    String? city,
    double? clientDiscount,
    BuildContext context,
  ) {
    double markup = 0.0;

    if (city != null && city.isNotEmpty) {
      markup = getMarkupForCity(city, context);
    }

    final discount = clientDiscount ?? 0.0;
    final multiplier = 1 + (markup - discount) / 100;

    return basePrice * multiplier;
  }

  // 🔥 ПРОВЕРКА МИНИМАЛЬНОЙ СУММЫ ЗАКАЗА
  bool meetsMinOrderAmount(
      String city, double orderAmount, BuildContext context) {
    if (city.isEmpty) return true;

    final minAmount = getMinOrderAmount(city, context);
    return orderAmount >= minAmount;
  }

  // 🔥 ПОЛУЧЕНИЕ СПИСКА ПУНКТОВ ДОСТАВКИ
  List<String> getAvailableLocations(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final deliveryConditions =
        authProvider.clientData?.deliveryConditions ?? [];

    return deliveryConditions
        .map((c) => c.location)
        .where((location) => location.isNotEmpty)
        .toList()
      ..sort();
  }

  // 🔥 ПОЛУЧЕНИЕ СПИСКА ГОРОДОВ (алиас)
  List<String> getAvailableCities(BuildContext context) {
    return getAvailableLocations(context);
  }

  // 🔥 ДОБАВЛЕНИЕ НОВОГО УСЛОВИЯ ДОСТАВКИ
  Future<bool> addDeliveryCondition(
      DeliveryCondition condition, BuildContext context) async {
    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);

      final existing = authProvider.clientData!.deliveryConditions.any(
          (c) => c.location.toLowerCase() == condition.location.toLowerCase());

      if (existing) {
        print('⚠️ Условие для пункта ${condition.location} уже существует');
        return false;
      }

      authProvider.clientData!.deliveryConditions.add(condition);
      authProvider.clientData!.buildIndexes();

      await _saveToPrefs(authProvider);

      print('✅ Условие доставки добавлено для пункта: ${condition.location}');
      return true;
    } catch (e) {
      print('❌ Ошибка добавления условия доставки: $e');
      return false;
    }
  }

  // 🔥 ОБНОВЛЕНИЕ УСЛОВИЯ ДОСТАВКИ (С АВТОМАТИЧЕСКИМ ОБНОВЛЕНИЕМ КЛИЕНТОВ)
  Future<bool> updateDeliveryCondition(
      DeliveryCondition condition, BuildContext context) async {
    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);

      final index = authProvider.clientData!.deliveryConditions.indexWhere(
          (c) => c.location.toLowerCase() == condition.location.toLowerCase());

      if (index != -1) {
        // Запоминаем старое значение для сравнения
        final oldAmount =
            authProvider.clientData!.deliveryConditions[index].deliveryAmount;

        // Обновляем условие доставки
        authProvider.clientData!.deliveryConditions[index] = condition;

        // 🔥 Если изменилась минимальная сумма заказа, обновляем всех клиентов этого города
        if (oldAmount != condition.deliveryAmount) {
          await _updateClientsMinOrderAmount(
            condition.location,
            condition.deliveryAmount,
            authProvider,
          );
        }

        authProvider.clientData!.buildIndexes();
        await _saveToPrefs(authProvider);

        print('✅ Условие доставки обновлено для пункта: ${condition.location}');
        print(
            '   Мин.сумма: ${condition.deliveryAmount}₽, Наценка: ${condition.hiddenMarkup}%');
        return true;
      }

      return false;
    } catch (e) {
      print('❌ Ошибка обновления условия доставки: $e');
      return false;
    }
  }

  // 🔥 ОБНОВЛЕНИЕ ВСЕХ КЛИЕНТОВ УКАЗАННОГО ГОРОДА
  Future<void> _updateClientsMinOrderAmount(
    String location,
    double newMinAmount,
    AuthProvider authProvider,
  ) async {
    int updatedCount = 0;

    for (int i = 0; i < authProvider.clientData!.clients.length; i++) {
      final client = authProvider.clientData!.clients[i];

      if (client.city?.toLowerCase() == location.toLowerCase()) {
        // Создаем обновленного клиента с новой минимальной суммой
        final updatedClient = Client(
          name: client.name,
          phone: client.phone,
          firm: client.firm,
          postalCode: client.postalCode,
          legalEntity: client.legalEntity,
          city: client.city,
          deliveryAddress: client.deliveryAddress,
          delivery: client.delivery,
          comment: client.comment,
          discount: client.discount,
          minOrderAmount: newMinAmount, // 👈 ОБНОВЛЯЕМ
        );

        authProvider.clientData!.clients[i] = updatedClient;
        updatedCount++;
      }
    }

    print('📊 Обновлено клиентов в городе "$location": $updatedCount');
    print('   Новая минимальная сумма заказа: $newMinAmount₽');
  }

  // 🔥 УДАЛЕНИЕ УСЛОВИЯ ДОСТАВКИ
  Future<bool> deleteDeliveryCondition(
      String location, BuildContext context) async {
    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);

      final beforeCount = authProvider.clientData!.deliveryConditions.length;

      authProvider.clientData!.deliveryConditions.removeWhere(
          (c) => c.location.toLowerCase() == location.toLowerCase());

      final afterCount = authProvider.clientData!.deliveryConditions.length;
      final removedCount = beforeCount - afterCount;

      if (removedCount > 0) {
        authProvider.clientData!.buildIndexes();
        await _saveToPrefs(authProvider);
        print('✅ Условие доставки удалено для пункта: $location');
        return true;
      }

      return false;
    } catch (e) {
      print('❌ Ошибка удаления условия доставки: $e');
      return false;
    }
  }

  // 🔥 СОХРАНЕНИЕ В SHAREDPREFERENCES
  Future<void> _saveToPrefs(AuthProvider authProvider) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final clientDataJson = authProvider.clientData!.toJson();
      await prefs.setString('client_data', jsonEncode(clientDataJson));
      print('✅ ClientData сохранен в SharedPreferences');
    } catch (e) {
      print('❌ Ошибка сохранения ClientData: $e');
    }
  }
}
