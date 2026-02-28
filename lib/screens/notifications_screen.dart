// lib/screens/notifications_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/web_push_service.dart';
import '../providers/auth_provider.dart';
import '../models/employee.dart';
import '../models/user.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  final WebPushService _pushService = WebPushService();
  bool _isLoading = true;
  bool _isSubscribed = false;
  bool _isSupported = true;
  String? _error;
  String? _browserInfo;
  String? _platformInfo;

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
    setState(() => _isLoading = true);

    try {
      // Получаем информацию о браузере
      _getBrowserInfo();

      // Проверяем поддержку уведомлений
      _isSupported = await _checkNotificationSupport();

      if (_isSupported) {
        // Получаем VAPID ключ из окружения
        const vapidKey = String.fromEnvironment('VAPID_PUBLIC_KEY',
            defaultValue:
                'BKGb_cS1YrTr4BjBZzQrFJS_8L7Zqr5l9CTXh_CU5wQvCJk9qJh3YkRxJYt2wA_VJZqFvQZnCk9HwGcCqLjZg1M');

        await _pushService.initialize(vapidKey);
        _isSubscribed = _pushService.isSubscribed;
      }
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _getBrowserInfo() {
    // Определяем браузер
    String browser = 'Unknown';
    String platform = 'Unknown';

    if (kIsWeb) {
      // В веб-версии можно получить информацию из userAgent
      // Для простоты пока оставляем так
      browser = 'Chrome/Edge/Firefox/Safari';
      platform = 'Web';
    } else {
      platform = 'Mobile';
    }

    setState(() {
      _browserInfo = browser;
      _platformInfo = platform;
    });
  }

  Future<bool> _checkNotificationSupport() async {
    if (!kIsWeb) return false;

    try {
      // Проверяем поддержку уведомлений в браузере
      // Убираем неиспользуемую переменную jsCode
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<void> _toggleSubscription() async {
    setState(() => _isLoading = true);

    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final user = authProvider.currentUser;

      if (user == null) {
        _showSnackBar('❌ Пользователь не авторизован');
        return;
      }

      if (!_isSubscribed) {
        // Включаем уведомления
        final success = await _pushService.subscribe();
        if (success) {
          setState(() => _isSubscribed = true);
          _showSnackBar('✅ Уведомления включены');

          // Отправляем статус на сервер
          await _saveSubscriptionStatus(true, user);
        } else {
          _showSnackBar('❌ Не удалось включить уведомления');
        }
      } else {
        // Отключаем уведомления
        final success = await _pushService.unsubscribe();
        if (success) {
          setState(() => _isSubscribed = false);
          _showSnackBar('❌ Уведомления отключены');

          // Отправляем статус на сервер
          await _saveSubscriptionStatus(false, user);
        }
      }
    } catch (e) {
      _showSnackBar('❌ Ошибка: ${e.toString()}');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _saveSubscriptionStatus(bool enabled, User user) async {
    // Сохраняем в SharedPreferences
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('push_notifications_enabled', enabled);

    if (user is Employee) {
      await prefs.setString('push_user_role', user.role ?? 'employee');
    }

    print('📱 Статус уведомлений сохранен: $enabled');
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Уведомления'),
        backgroundColor: Theme.of(context).primaryColor,
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _buildContent(),
    );
  }

  Widget _buildContent() {
    if (!_isSupported) {
      return _buildNotSupported();
    }

    if (_error != null) {
      return _buildError();
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildStatusCard(),
          const SizedBox(height: 16),
          _buildInfoCard(),
          const SizedBox(height: 16),
          _buildPermissionsCard(),
          const SizedBox(height: 16),
          _buildHistoryCard(),
        ],
      ),
    );
  }

  Widget _buildStatusCard() {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Icon(
              _isSubscribed
                  ? Icons.notifications_active
                  : Icons.notifications_off,
              size: 64,
              color: _isSubscribed ? Colors.green : Colors.grey,
            ),
            const SizedBox(height: 16),
            Text(
              _isSubscribed ? 'Уведомления включены' : 'Уведомления отключены',
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _isSubscribed
                  ? 'Вы будете получать уведомления о новых заказах и изменениях статуса'
                  : 'Включите уведомления, чтобы не пропустить важные события',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey[600]),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: _toggleSubscription,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _isSubscribed ? Colors.red : Colors.green,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(25),
                  ),
                ),
                child: Text(
                  _isSubscribed
                      ? 'Отключить уведомления'
                      : 'Включить уведомления',
                  style: const TextStyle(fontSize: 16),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoCard() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Информация о платформе',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const Divider(),
            _buildInfoRow('Платформа', _platformInfo ?? 'Неизвестно'),
            _buildInfoRow('Браузер', _browserInfo ?? 'Неизвестно'),
            _buildInfoRow('Поддержка Push', _isSupported ? '✅ Да' : '❌ Нет'),
            _buildInfoRow(
                'Статус', _isSubscribed ? '✅ Активен' : '❌ Неактивен'),
          ],
        ),
      ),
    );
  }

  Widget _buildPermissionsCard() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Разрешения',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const Divider(),
            const ListTile(
              leading: Icon(Icons.check_circle, color: Colors.green),
              title: Text('Уведомления'),
              subtitle: Text('Разрешены после включения'),
            ),
            const ListTile(
              leading: Icon(Icons.info, color: Colors.blue),
              title: Text('Фоновые уведомления'),
              subtitle: Text('Работают даже когда приложение закрыто'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHistoryCard() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'История уведомлений',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const Divider(),
            Center(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    Icon(
                      Icons.history,
                      size: 48,
                      color: Colors.grey[400],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Здесь будет отображаться история уведомлений',
                      style: TextStyle(color: Colors.grey[600]),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: const TextStyle(
                fontWeight: FontWeight.w500,
                color: Colors.grey,
              ),
            ),
          ),
          Expanded(
            child: Text(value),
          ),
        ],
      ),
    );
  }

  Widget _buildNotSupported() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 80,
              color: Colors.red[300],
            ),
            const SizedBox(height: 16),
            const Text(
              'Уведомления не поддерживаются',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Ваш браузер или платформа не поддерживают push-уведомления.\n'
              'Попробуйте использовать Chrome, Firefox или Edge на десктопе,\n'
              'или установите приложение на Android/iOS.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error,
              size: 80,
              color: Colors.red[300],
            ),
            const SizedBox(height: 16),
            const Text(
              'Ошибка инициализации',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _error ?? 'Неизвестная ошибка',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.red[600]),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _initialize,
              child: const Text('Повторить'),
            ),
          ],
        ),
      ),
    );
  }
}
