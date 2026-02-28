// web/scripts/push-client.js
// Клиент для работы с push-уведомлениями
window.typeofPushManager = typeof PushManager;
window.PushManager = {
  vapidPublicKey: null,
  registration: null,
  
  // Инициализация
  init: async function(vapidKey) {
    console.log('📱 Инициализация Push-клиента');
    this.vapidPublicKey = vapidKey;
    
    if (!('serviceWorker' in navigator)) {
      console.error('❌ Service Worker не поддерживается');
      return false;
    }
    
    if (!('PushManager' in window)) {
      console.error('❌ PushManager не поддерживается');
      return false;
    }
    
    try {
      // Регистрируем push service worker
      this.registration = await navigator.serviceWorker.register('/push-sw.js');
      console.log('✅ Push Service Worker зарегистрирован', this.registration.scope);
      
      return true;
    } catch (error) {
      console.error('❌ Ошибка инициализации:', error);
      return false;
    }
  },
  
  // Проверка разрешений
  checkPermission: async function() {
    if (Notification.permission === 'granted') return 'granted';
    
    if (Notification.permission !== 'denied') {
      const permission = await Notification.requestPermission();
      return permission;
    }
    
    return Notification.permission;
  },
  
  // Запрос разрешений
  requestPermission: async function() {
    const permission = await Notification.requestPermission();
    console.log('📱 Разрешение:', permission);
    return permission;
  },
  
  // Получение текущей подписки
  getSubscription: async function() {
    if (!this.registration) {
      await this.init(this.vapidPublicKey);
    }
    return await this.registration.pushManager.getSubscription();
  },
  
  // Подписка на уведомления
  subscribe: async function(userId) {
    console.log('📱 Подписка на уведомления для пользователя:', userId);
    
    try {
      if (!this.registration) {
        await this.init(this.vapidPublicKey);
      }
      
      // Проверяем разрешения
      const permission = await this.checkPermission();
      if (permission !== 'granted') {
        console.log('⚠️ Нет разрешения на уведомления');
        return false;
      }
      
      // Удаляем старую подписку если есть
      const oldSubscription = await this.registration.pushManager.getSubscription();
      if (oldSubscription) {
        await oldSubscription.unsubscribe();
        console.log('🗑️ Старая подписка удалена');
      }
      
      // Создаем новую подписку
      const subscription = await this.registration.pushManager.subscribe({
        userVisibleOnly: true,
        applicationServerKey: this.urlBase64ToUint8Array(this.vapidPublicKey)
      });
      
      console.log('✅ Подписка создана:', subscription);
      
      return true;
    } catch (error) {
      console.error('❌ Ошибка подписки:', error);
      return false;
    }
  },
  
  // Получение данных подписки для отправки на сервер
  getSubscriptionData: async function() {
    const subscription = await this.getSubscription();
    if (!subscription) return null;
    
    return {
      endpoint: subscription.endpoint,
      keys: subscription.toJSON().keys
    };
  },
  
  // Вспомогательная функция для конвертации ключа
  urlBase64ToUint8Array: function(base64String) {
    const padding = '='.repeat((4 - base64String.length % 4) % 4);
    const base64 = (base64String + padding).replace(/-/g, '+').replace(/_/g, '/');
    const rawData = window.atob(base64);
    const outputArray = new Uint8Array(rawData.length);
    for (let i = 0; i < rawData.length; ++i) {
      outputArray[i] = rawData.charCodeAt(i);
    }
    return outputArray;
  }
};
