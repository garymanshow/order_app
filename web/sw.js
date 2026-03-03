// web/sw.js
const CACHE_NAME = 'order-app-v1'; // ← Меняйте v1 → v2 при обновлении
const API_CACHE_NAME = 'order-api-v1';

// Добавьте версию приложения
const APP_VERSION = '1.0.0';

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

self.addEventListener('install', (event) => {
  console.log(`🔄 Установка Service Worker v${APP_VERSION}...`);
  event.waitUntil(
    caches.open(CACHE_NAME).then((cache) => {
      return cache.addAll(STATIC_RESOURCES);
    })
  );
});

self.addEventListener('activate', (event) => {
  console.log(`🔄 Активация Service Worker v${APP_VERSION}...`);
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
    })
  );
});

// Стратегия кэширования для fetch (можно добавить позже)
self.addEventListener('fetch', (event) => {
  event.respondWith(
    caches.match(event.request).then((response) => {
      return response || fetch(event.request);
    })
  );
});
