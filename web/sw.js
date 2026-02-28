// web/sw.js
const CACHE_NAME = 'order-app-v1';
const API_CACHE_NAME = 'order-api-v1';

// Ресурсы для кэширования при установке
const STATIC_RESOURCES = [
  '/',
  '/index.html',
  '/main.dart.js',
  '/flutter.js',
  '/assets/AssetManifest.json',
  '/assets/FontManifest.json',
  '/assets/assets/images/products/',
  '/assets/assets/images/auth/'
];

// Установка Service Worker
self.addEventListener('install', (event) => {
  console.log('🔄 Service Worker устанавливается...');
  
  event.waitUntil(
    caches.open(CACHE_NAME).then((cache) => {
      return cache.addAll(STATIC_RESOURCES).then(() => {
        console.log('✅ Ресурсы закэшированы');
        return self.skipWaiting();
      });
    })
  );
});

// Активация и очистка старых кэшей
self.addEventListener('activate', (event) => {
  console.log('🔄 Service Worker активируется...');
  
  event.waitUntil(
    caches.keys().then((keys) => {
      return Promise.all(
        keys.map((key) => {
          if (key !== CACHE_NAME && key !== API_CACHE_NAME) {
            console.log('🗑️ Удаляем старый кэш:', key);
            return caches.delete(key);
          }
        })
      );
    }).then(() => {
      console.log('✅ Service Worker активирован');
      return self.clients.claim();
    })
  );
});

// Стратегия кэширования
self.addEventListener('fetch', (event) => {
  const url = new URL(event.request.url);
  
  // Для API запросов (динамические данные)
  if (url.pathname.includes('/exec')) {
    event.respondWith(
      fetch(event.request)
        .then((response) => {
          // Кэшируем успешные ответы от API
          if (response.status === 200) {
            const responseClone = response.clone();
            caches.open(API_CACHE_NAME).then((cache) => {
              cache.put(event.request, responseClone);
            });
          }
          return response;
        })
        .catch(() => {
          // Если сеть недоступна, пробуем получить из кэша
          return caches.match(event.request).then((response) => {
            if (response) {
              console.log('📦 Ответ из кэша (API):', url.pathname);
              return response;
            }
            // Если ничего нет в кэше, возвращаем заглушку
            return new Response(
              JSON.stringify({ 
                offline: true, 
                message: 'Вы находитесь в офлайн-режиме' 
              }),
              { headers: { 'Content-Type': 'application/json' } }
            );
          });
        })
    );
    return;
  }

  // Для статических ресурсов (изображения, скрипты)
  event.respondWith(
    caches.match(event.request).then((response) => {
      if (response) {
        console.log('📦 Из кэша:', url.pathname);
        return response;
      }
      
      console.log('🌐 Загружаем из сети:', url.pathname);
      return fetch(event.request).then((response) => {
        // Кэшируем только успешные ответы
        if (response.status === 200) {
          const responseClone = response.clone();
          caches.open(CACHE_NAME).then((cache) => {
            cache.put(event.request, responseClone);
          });
        }
        return response;
      });
    })
  );
});

// Обработка фоновой синхронизации (для будущего)
self.addEventListener('sync', (event) => {
  if (event.tag === 'sync-orders') {
    console.log('🔄 Фоновая синхронизация заказов...');
    // Здесь будет логика отправки отложенных заказов
  }
});

// Обработка push-уведомлений (для будущего)
self.addEventListener('push', (event) => {
  const options = {
    body: event.data.text(),
    icon: '/icons/Icon-192.png',
    badge: '/icons/Icon-192.png',
    vibrate: [200, 100, 200],
    data: {
      dateOfArrival: Date.now(),
      primaryKey: 1
    },
    actions: [
      { action: 'open', title: 'Открыть' },
      { action: 'close', title: 'Закрыть' }
    ]
  };

  event.waitUntil(
    self.registration.showNotification('Вкусные моменты', options)
  );
});
