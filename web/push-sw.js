// web/push-sw.js - Service Worker для уведомлений
const CACHE_NAME = 'push-cache-v1';

self.addEventListener('install', (event) => {
  console.log('📬 Push Service Worker устанавливается');
  self.skipWaiting();
});

self.addEventListener('activate', (event) => {
  console.log('📬 Push Service Worker активирован');
  event.waitUntil(clients.claim());
});

// Обработка входящих push-уведомлений
self.addEventListener('push', (event) => {
  console.log('📬 Получено push-уведомление', event);

  if (!event.data) {
    console.log('⚠️ Пустое уведомление');
    return;
  }

  try {
    const data = event.data.json();
    console.log('📦 Данные уведомления:', data);

    const options = {
      body: data.body || 'Новое уведомление',
      icon: data.icon || '/icons/icon-192.png',
      badge: '/icons/icon-192.png',
      vibrate: data.vibrate || [200, 100, 200],
      data: data.data || {},
      actions: data.actions || [],
      tag: data.tag || 'default',
      renotify: data.renotify || false,
      requireInteraction: data.requireInteraction || true,
      silent: data.silent || false
    };

    // Добавляем изображение если есть
    if (data.image) {
      options.image = data.image;
    }

    // Добавляем timestamp
    options.timestamp = data.timestamp || Date.now();

    event.waitUntil(
      self.registration.showNotification(data.title || 'Вкусные моменты', options)
    );
  } catch (error) {
    console.error('❌ Ошибка парсинга уведомления:', error);

    // Fallback для простых текстовых уведомлений
    event.waitUntil(
      self.registration.showNotification('Вкусные моменты', {
        body: event.data.text(),
        icon: '/icons/icon-192.png'
      })
    );
  }
});

// Обработка кликов по уведомлениям
self.addEventListener('notificationclick', (event) => {
  console.log('👆 Клик по уведомлению', event);

  event.notification.close();

  const action = event.action;
  const data = event.notification.data || {};

  console.log('📋 Действие:', action, 'Данные:', data);

  let url = '/';

  // Определяем URL на основе действия
  if (action === 'view_order' && data.orderId) {
    url = `/orders/${data.orderId}`;
  } else if (action === 'start_production' && data.orderId) {
    url = `/admin/orders/${data.orderId}`;
  } else if (action === 'view_all_orders') {
    url = '/admin/orders';
  } else if (action === 'view_all') {
    url = '/';
  } else if (data.url) {
    url = data.url;
  }

  console.log('🔗 Открываем URL:', url);

  // Открываем или фокусируем существующее окно
  event.waitUntil(
    clients.matchAll({ type: 'window', includeUncontrolled: true })
      .then((clientList) => {
        for (let client of clientList) {
          if (client.url === url && 'focus' in client) {
            return client.focus();
          }
        }
        return clients.openWindow(url);
      })
  );
});

// Обработка закрытия уведомления
self.addEventListener('notificationclose', (event) => {
  console.log('❌ Уведомление закрыто', event);
});
