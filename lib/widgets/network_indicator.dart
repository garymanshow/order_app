// lib/widgets/network_indicator.dart
import 'package:flutter/material.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

class NetworkIndicator extends StatefulWidget {
  final Widget child;

  const NetworkIndicator({super.key, required this.child});

  @override
  State<NetworkIndicator> createState() => _NetworkIndicatorState();
}

class _NetworkIndicatorState extends State<NetworkIndicator> {
  bool _isOnline = true;
  bool _showBanner = false;

  @override
  void initState() {
    super.initState();
    _checkConnectivity();
    _listenToConnectivity();
  }

  void _checkConnectivity() async {
    final results = await Connectivity().checkConnectivity();
    _updateStatus(results);
  }

  void _listenToConnectivity() {
    Connectivity().onConnectivityChanged.listen((results) {
      _updateStatus(results);
    });
  }

  // 🔥 ИСПРАВЛЕНО: принимаем список ConnectivityResult
  void _updateStatus(List<ConnectivityResult> results) {
    // Если хотя бы одно соединение доступно - считаем онлайн
    final isOnline =
        results.isNotEmpty && !results.contains(ConnectivityResult.none);

    setState(() {
      if (_isOnline && !isOnline) {
        // Только что потеряли соединение
        _showBanner = true;
      } else if (!_isOnline && isOnline) {
        // Только что восстановили соединение
        _showBanner = true;
        // Скрываем баннер через 3 секунды
        Future.delayed(const Duration(seconds: 3), () {
          if (mounted) {
            setState(() => _showBanner = false);
          }
        });
      }
      _isOnline = isOnline;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        if (_showBanner)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
            color: _isOnline ? Colors.green : Colors.orange,
            child: Row(
              children: [
                Icon(
                  _isOnline ? Icons.wifi : Icons.wifi_off,
                  color: Colors.white,
                  size: 16,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _isOnline
                        ? '✅ Соединение восстановлено'
                        : '🌐 Офлайн-режим. Данные могут быть устаревшими',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                    ),
                  ),
                ),
                if (_isOnline)
                  IconButton(
                    icon:
                        const Icon(Icons.close, color: Colors.white, size: 16),
                    onPressed: () {
                      setState(() => _showBanner = false);
                    },
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
              ],
            ),
          ),
        Expanded(child: widget.child),
      ],
    );
  }
}
