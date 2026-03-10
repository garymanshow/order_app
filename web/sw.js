// web/sw.js
const CACHE_NAME = 'order-app-v1'; // ← Меняйте v1 → v2 при обновлении
const API_CACHE_NAME = 'order-api-v1';
const APP_VERSION = '1.0.0'; // Добавьте версию приложения

// Ресурсы для кэширования при установке
const STATIC_RESOURCES = [
  '/',
  '/index.html',
  '/main.dart.js',
  '/flutter.js',
  '/flutter_bootstrap.js',
  '/manifest.json',
  '/scripts/push-client.js',
  '/push-sw.js',
  '/assets/AssetManifest.json',
  '/assets/FontManifest.json',
  '/assets/assets/images/products/',
  '/assets/assets/images/auth/',
  '/icons/Icon-192.png',
  '/icons/Icon-512.png'
];

// 🔥 Флаг для предотвращения повторных обновлений
let isUpdating = false;

self.addEventListener('install', (event) => {
  console.log(`🔄 Установка Service Worker v${APP_VERSION}...`);
  // 🔥 Принудительно пропускаем ожидание
  self.skipWaiting();
  event.waitUntil(
    caches.open(CACHE_NAME).then((cache) => {
      return cache.addAll(STATIC_RESOURCES);
    })
  );
});

self.addEventListener('activate', (event) => {
  console.log(`🔄 Активация Service Worker v${APP_VERSION}...`);
  // 🔥 Захватываем контроль сразу
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
      console.log(`✅ Service Worker v${APP_VERSION} активирован`);
      return self.clients.claim(); // 🔥 Важно!
    })
  );
});

self.addEventListener('fetch', (event) => {
  const url = new URL(event.request.url);
  
  // 🔥 API запросы — Network First (не кэшируем)
  if (url.hostname.includes('google') || url.pathname.includes('exec')) {
    event.respondWith(
      fetch(event.request)
        .then(response => response)
        .catch(() => {
          return new Response(
            JSON.stringify({ error: 'offline', message: 'Нет соединения' }),
            { headers: { 'Content-Type': 'application/json' } }
          );
        })
    );
    return;
  }
  
  // Остальное — Cache First
  event.respondWith(
    caches.match(event.request).then((response) => {
      return response || fetch(event.request);
    })
  );
});

// 🔥 Обработка сообщений от клиента
self.addEventListener('message', (event) => {
  if (event.data && event.data.action === 'skipWaiting') {
    if (!isUpdating) {
      isUpdating = true;
      self.skipWaiting();
    }
  }
});
