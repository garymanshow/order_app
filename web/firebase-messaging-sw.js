// web/firebase-messaging-sw.js

// Загружаем Firebase SDK через importScripts (старый способ, но работает в сервис-воркерах)
importScripts('https://www.gstatic.com/firebasejs/10.7.0/firebase-app-compat.js');
importScripts('https://www.gstatic.com/firebasejs/10.7.0/firebase-messaging-compat.js');

// Ваша конфигурация из консоли Firebase
const firebaseConfig = {
  apiKey: "AIzaSyBghNOaDiVnLmLoVNJSvsgSXSV1H27PguE",
  authDomain: "my-push-server-81823.firebaseapp.com",
  projectId: "my-push-server-81823",
  storageBucket: "my-push-server-81823.firebasestorage.app",
  messagingSenderId: "1057035080793",
  appId: "1:1057035080793:web:977b116163df2be80f4d48"
};

// Инициализируем Firebase
firebase.initializeApp(firebaseConfig);

// Получаем экземпляр messaging
const messaging = firebase.messaging();

// Опционально: кастомизируем уведомления
messaging.onBackgroundMessage((payload) => {
  console.log('[firebase-messaging-sw.js] Received background message', payload);
  
  const notificationTitle = payload.notification?.title || 'Новый заказ';
  const notificationOptions = {
    body: payload.notification?.body || 'Поступил новый заказ',
    icon: '/icons/Icon-192.png',
    badge: '/icons/Icon-192.png'
  };
  
  self.registration.showNotification(notificationTitle, notificationOptions);
});
