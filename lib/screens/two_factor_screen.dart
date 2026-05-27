import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';

// 🔥 УБРАЛИ ЗАВИСИМОСТЬ ОТ EMPLOYEE. Теперь экран универсален!
class TwoFactorScreen extends StatefulWidget {
  final String userName;
  final String requiredEmail;
  final bool isEmployee;

  const TwoFactorScreen({
    super.key,
    required this.userName,
    required this.requiredEmail,
    this.isEmployee = false, // По умолчанию считаем, что это клиент
  });

  @override
  _TwoFactorScreenState createState() => _TwoFactorScreenState();
}

class _TwoFactorScreenState extends State<TwoFactorScreen> {
  bool _isLoading = false;

  Future<void> _signInWithGoogle() async {
    setState(() => _isLoading = true);

    try {
      // ✅ РЕШЕНИЕ ДЛЯ ВЕРСИИ 7.x
      final GoogleSignInAccount googleUser =
          await GoogleSignIn.instance.authenticate();

      if (googleUser != null) {
        final String googleEmail = googleUser.email;

        // Сравниваем email из Google с тем, что пришел из базы/таблицы
        if (googleEmail == widget.requiredEmail) {
          Navigator.pop(context, true);
        } else {
          _showErrorDialog(
            'Неверный аккаунт',
            'Используйте email: ${widget.requiredEmail}',
          );
          await GoogleSignIn.instance.signOut();
        }
      } else {
        Navigator.pop(context, false);
      }
    } catch (e) {
      debugPrint('❌ Ошибка Google Sign-In: $e');
      _showErrorDialog(
          'Ошибка входа', 'Не удалось выполнить вход через Google');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _showErrorDialog(String title, String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Двухфакторная защита'),
        backgroundColor: Theme.of(context).primaryColor,
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.blue.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.security,
                size: 64,
                color: Colors.blue,
              ),
            ),
            const SizedBox(height: 32),
            const Text(
              'Требуется подтверждение',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              // 🔥 ДИНАМИЧЕСКИЙ ТЕКСТ В ЗАВИСИМОСТИ ОТ ТОГО, КТО ВОШЕЛ
              widget.isEmployee
                  ? 'Для защиты вашего аккаунта требуется дополнительная проверка через корпоративный Google аккаунт'
                  : 'Для защиты вашего профиля потребуется подтвердить вашу учетную запись через Google',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 16),
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    ListTile(
                      leading: const Icon(Icons.person),
                      title: Text(widget.userName.isNotEmpty
                          ? widget.userName
                          : 'Пользователь'),
                      // 🔥 ДИНАМИЧЕСКИЙ ПОДЗАГОЛОВОК
                      subtitle:
                          Text(widget.isEmployee ? 'Сотрудник' : 'Клиент'),
                    ),
                    const Divider(),
                    ListTile(
                      leading: const Icon(Icons.email),
                      title: Text(widget.requiredEmail),
                      // 🔥 ДИНАМИЧЕСКИЙ ПОДЗАГОЛОВОК
                      subtitle: Text(widget.isEmployee
                          ? 'Корпоративный email'
                          : 'Email для подтверждения'),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton.icon(
                onPressed: _isLoading ? null : _signInWithGoogle,
                icon: _isLoading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Image.asset(
                        'assets/google_logo.png',
                        height: 24,
                        errorBuilder: (context, error, stackTrace) =>
                            const Icon(Icons.g_mobiledata, color: Colors.blue),
                      ),
                label: Text(
                  _isLoading ? 'Выполняется вход...' : 'Войти через Google',
                  style: const TextStyle(fontSize: 16),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: Colors.black87,
                  elevation: 2,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(25),
                    side: BorderSide(color: Colors.grey[300]!),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Отмена'),
            ),
          ],
        ),
      ),
    );
  }
}
