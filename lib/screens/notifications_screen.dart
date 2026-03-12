// lib/screens/notifications_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:js' as js; // 👈 ДОБАВЛЕНО
import '../services/web_push_service.dart';
import '../services/env_service.dart';
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
  bool _isSupported = false;
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
      _isSupported = await _pushService.isSupported();

      if (_isSupported) {
        // Получаем VAPID ключ из EnvService
        final vapidKey = EnvService.vapidPublicKey;

        if (vapidKey.isEmpty) {
          print('⚠️ VAPID ключ не найден');
          setState(() {
            _error = 'VAPID ключ не настроен';
            _isLoading = false;
          });
          return;
        }

        // 🔥 ИСПРАВЛЕНО: убрали параметр
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
    if (kIsWeb) {
      try {
        // Пытаемся получить реальную информацию о браузере
        final userAgent = _getUserAgent();

        if (userAgent.contains('Chrome')) {
          _browserInfo = 'Chrome';
        } else if (userAgent.contains('Firefox')) {
          _browserInfo = 'Firefox';
        } else if (userAgent.contains('Safari') &&
            !userAgent.contains('Chrome')) {
          _browserInfo = 'Safari';
        } else if (userAgent.contains('Edg')) {
          _browserInfo = 'Edge';
        } else {
          _browserInfo = 'Другой браузер';
        }

        _platformInfo = 'Web';
      } catch (e) {
        _browserInfo = 'Не удалось определить';
        _platformInfo = 'Web';
      }
    } else {
      _browserInfo = 'Нативное приложение';
      _platformInfo = 'Мобильное устройство';
    }
  }

  // 🔥 Вспомогательный метод для получения User-Agent
  String _getUserAgent() {
    try {
      final navigator = js.context['navigator'];
      final userAgent = navigator['userAgent'];
      return userAgent?.toString() ?? '';
    } catch (e) {
      return '';
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

      bool success;

      if (!_isSubscribed) {
        // Включаем уведомления
        success = await _pushService.subscribe();
        if (success) {
          setState(() => _isSubscribed = true);
          _showSnackBar('✅ Уведомления включены');
          await _saveSubscriptionStatus(true, user);
        } else {
          _showSnackBar('❌ Не удалось включить уведомления');
        }
      } else {
        // Отключаем уведомления
        success = await _pushService.unsubscribe();
        if (success) {
          setState(() => _isSubscribed = false);
          _showSnackBar('❌ Уведомления отключены');
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
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('push_notifications_enabled', enabled);

      if (user is Employee) {
        await prefs.setString('push_user_role', user.role ?? 'employee');
        // 🔥 ИСПРАВЛЕНО: используем phone, который есть у Employee
        if (user.phone != null) {
          await prefs.setString('push_user_id', user.phone!);
        }
      }

      print('📱 Статус уведомлений сохранен: $enabled');
    } catch (e) {
      print('❌ Ошибка сохранения статуса: $e');
    }
  }

  void _showSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
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
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _initialize,
            tooltip: 'Обновить',
          ),
        ],
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
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: _isSubscribed
                ? [Colors.green.shade50, Colors.green.shade100]
                : [Colors.grey.shade50, Colors.grey.shade200],
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              Icon(
                _isSubscribed
                    ? Icons.notifications_active
                    : Icons.notifications_off,
                size: 80,
                color: _isSubscribed ? Colors.green : Colors.grey,
              ),
              const SizedBox(height: 16),
              Text(
                _isSubscribed
                    ? 'Уведомления включены'
                    : 'Уведомления отключены',
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _isSubscribed
                    ? 'Вы будете получать уведомления о новых заказах'
                    : 'Включите уведомления, чтобы быть в курсе событий',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[700],
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton(
                  onPressed: _toggleSubscription,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _isSubscribed ? Colors.red : Colors.green,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(27),
                    ),
                    elevation: 2,
                  ),
                  child: Text(
                    _isSubscribed
                        ? 'ОТКЛЮЧИТЬ УВЕДОМЛЕНИЯ'
                        : 'ВКЛЮЧИТЬ УВЕДОМЛЕНИЯ',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ),
            ],
          ),
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
            const Row(
              children: [
                Icon(Icons.info_outline, size: 20, color: Colors.blue),
                SizedBox(width: 8),
                Text(
                  'Информация о системе',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const Divider(height: 24),
            _buildInfoRow('Платформа', _platformInfo ?? 'Неизвестно'),
            _buildInfoRow('Браузер', _browserInfo ?? 'Неизвестно'),
            _buildInfoRow('Поддержка Push', _isSupported ? '✅ Да' : '❌ Нет'),
            _buildInfoRow(
              'Текущий статус',
              _isSubscribed ? '✅ Активен' : '❌ Неактивен',
              valueColor: _isSubscribed ? Colors.green : Colors.red,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value, {Color? valueColor}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: const TextStyle(
                fontWeight: FontWeight.w500,
                color: Colors.grey,
                fontSize: 14,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: valueColor ?? Colors.black87,
              ),
            ),
          ),
        ],
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
            const Row(
              children: [
                Icon(Icons.security, size: 20, color: Colors.orange),
                SizedBox(width: 8),
                Text(
                  'Разрешения',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const Divider(height: 24),
            _buildPermissionTile(
              icon: Icons.notifications,
              title: 'Уведомления',
              subtitle: _isSubscribed ? 'Разрешены и активны' : 'Не активны',
              color: _isSubscribed ? Colors.green : Colors.grey,
            ),
            _buildPermissionTile(
              icon: Icons.battery_charging_full,
              title: 'Фоновый режим',
              subtitle: _isSubscribed
                  ? 'Уведомления работают в фоне'
                  : 'Не используется',
              color: _isSubscribed ? Colors.blue : Colors.grey,
            ),
            _buildPermissionTile(
              icon: Icons.volume_up,
              title: 'Звук',
              subtitle: 'Включен по умолчанию',
              color: Colors.blue,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPermissionTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 20, color: color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w500,
                    fontSize: 15,
                  ),
                ),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
          Icon(
            Icons.check_circle,
            size: 20,
            color: color == Colors.grey ? Colors.grey[300] : color,
          ),
        ],
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
            const Row(
              children: [
                Icon(Icons.history, size: 20, color: Colors.purple),
                SizedBox(width: 8),
                Text(
                  'Последние уведомления',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const Divider(height: 24),
            if (_isSubscribed)
              ..._buildMockHistory()
            else
              Center(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      Icon(
                        Icons.history_toggle_off,
                        size: 48,
                        color: Colors.grey[400],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Включите уведомления,\nчтобы видеть историю',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 14,
                        ),
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

  List<Widget> _buildMockHistory() {
    return [
      _buildHistoryItem(
        icon: Icons.shopping_cart,
        title: 'Новый заказ #123',
        time: '5 минут назад',
        color: Colors.green,
      ),
      _buildHistoryItem(
        icon: Icons.check_circle,
        title: 'Заказ #122 готов',
        time: '1 час назад',
        color: Colors.blue,
      ),
      _buildHistoryItem(
        icon: Icons.payment,
        title: 'Оплата получена',
        time: '3 часа назад',
        color: Colors.orange,
      ),
    ];
  }

  Widget _buildHistoryItem({
    required IconData icon,
    required String title,
    required String time,
    required Color color,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 20, color: color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w500,
                    fontSize: 15,
                  ),
                ),
                Text(
                  time,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.grey[200],
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Text(
              'Новое',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w500,
                color: Colors.blue,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNotSupported() {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.orange.shade50,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.info_outline,
                size: 64,
                color: Colors.orange[700],
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Уведомления недоступны',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Push-уведомления работают только в веб-версии приложения.\n\n'
              'Чтобы получать уведомления:\n'
              '• Откройте приложение в браузере Chrome\n'
              '• Разрешите уведомления в настройках браузера\n'
              '• Включите уведомления в этом разделе',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[700],
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildError() {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.error_outline,
                size: 64,
                color: Colors.red[700],
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Ошибка инициализации',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                _error ?? 'Неизвестная ошибка',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.red[900],
                ),
              ),
            ),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: _initialize,
              icon: const Icon(Icons.refresh),
              label: const Text('Повторить'),
              style: ElevatedButton.styleFrom(
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
