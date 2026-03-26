/**
 * Обработчик аутентификации старая версия (страшно сразу удалить)
 * Предполагается, что телефон уже проверен в doPost
 */
function handleAuthentication(phone, localMetadata, fcmToken) {
  try {
    console.log(`🔐 Начало аутентификации`);
    const ss = SpreadsheetApp.getActiveSpreadsheet();
    
    // === ШАГ 1: ПОИСК ТИПА ПОЛЬЗОВАТЕЛЯ ===
    if (!phone || phone.trim() === '') {
      const isGuest = true;
      // заведомо старые даты для получения локальных метаданных
      const currentMetadata = {
        "Сотрудники": {
          lastUpdate: "2001-01-01T12:51:08.463Z",
          editor: "gary.manshow@gmail.com"
        },
        "Прайс-лист": {
          lastUpdate: "2001-01-01T09:57:04.239Z",
          editor: "gary.manshow@gmail.com"
        },
      };
      localMetadata = currentMetadata;      
      console.log(`👤 Тип пользователя: ГОСТЬ`);
    } else {
      const isEmployee = isPhoneInSheet(ss, 'Сотрудники', phone);
      const isClient = !isEmployee ? isPhoneInSheet(ss, 'Клиенты', phone) : false;
      
      if (!isEmployee && !isClient) {
        console.log(`❌ Пользователь с телефоном ${phone} не найден`);
        return {
          status: 'error',
          message: 'Пользователь не найден. Проверьте правильность введенного номера телефона.'
        };
      }
      
      console.log(`👤 Тип пользователя: ${isEmployee ? 'СОТРУДНИК' : 'КЛИЕНТ'}`);
      
      // === ШАГ 2: ПОЛУЧЕНИЕ ДАННЫХ ПОЛЬЗОВАТЕЛЯ ===
      let userData = {};
      if (isEmployee) {
        userData = getUserData(ss, 'Сотрудники', phone);
        console.log(`👤 Сотрудник авторизован с ролью: ${userData.role || 'Сотрудник'}`);
      } else {
        userData = getUserData(ss, 'Клиенты', phone);
        console.log(`👤 Клиент авторизован: ${userData.name || userData.company || phone}`);
      }

      // === ШАГ 3: ПОЛУЧЕНИЕ МЕТАДАННЫХ ===
      const currentMetadata = getMetadataFromSheet(ss);

    }
    
    // === ШАГ 4: ПОЛУЧЕНИЕ ВСЕХ ЛИСТОВ ИЗ МЕТАДАННЫХ ===
    const allSheetNames = Object.keys(currentMetadata);
    console.log('📋 Все листы по метаданным:', allSheetNames);
    
    // === ШАГ 5: ОПРЕДЕЛЕНИЕ ЛИСТОВ ДЛЯ ЗАГРУЗКИ ===
    const sheetsToLoad = [];
    let hasUpdates = false;
    
    if (!isGuest && (!localMetadata || Object.keys(localMetadata).length === 0)) {
      // Первый вход - загружаем ВСЕ листы
      sheetsToLoad.push(...allSheetNames);
      hasUpdates = true;
      console.log('📋 Первый вход, загружаем все листы:', allSheetNames);
    } else {
      // Повторный вход - сравниваем слепки
      console.log('📋 Сравнение с локальными метаданными...');
      
      for (const sheetName of allSheetNames) {
        const serverMeta = currentMetadata[sheetName];
        const localMeta = localMetadata[sheetName];
        
        // Если нет локальных метаданных или они устарели
        if (!localMeta) {
          console.log(`📋 Лист "${sheetName}" отсутствует в локальных метаданных - требуется загрузка`);
          sheetsToLoad.push(sheetName);
          hasUpdates = true;
        } else if (new Date(localMeta.lastUpdate) < new Date(serverMeta.lastUpdate)) {
          console.log(`📋 Лист "${sheetName}" устарел - требуется обновление`);
          // TODO решить как обновить данные на сервере
          sheetsToLoad.push(sheetName);
          hasUpdates = true;
        }
      }
    }
    
    // === ШАГ 7: ФИЛЬТРАЦИЯ ЛИСТОВ ПО ТИПУ ПОЛЬЗОВАТЕЛЯ ===
    if (isClient && !isGuest) {
      // Клиентам не нужны служебные листы
      const excludedSheets = ['Сотрудники', 'Поставщики', 'Складские операции', 'Метаданные', 'Категории прайса'];
      const filteredSheets = sheetsToLoad.filter(sheet => !excludedSheets.includes(sheet));
      sheetsToLoad.length = 0;
      sheetsToLoad.push(...filteredSheets);
      console.log('📋 Для клиента загружаются листы:', sheetsToLoad);
    } else {
      if (isEmployee) {
        // 🔥 ДЛЯ СОТРУДНИКОВ - убеждаемся, что "Категории прайса" есть в списке
        if (!sheetsToLoad.includes('Категории прайса')) {
          sheetsToLoad.push('Категории прайса');
          console.log('📋 Добавлен лист "Категории прайса" для сотрудника');
        }
        console.log('📋 Для сотрудника загружаются листы:', sheetsToLoad);
      } else {
        console.log('📋 Для гостя загружаются листы:', sheetsToLoad);
      }
    }

    // === ШАГ 8: ФОРМИРОВАНИЕ ОТВЕТА ===
    const responseData = {
      status: 'success',
      success: true,
      message: 'Аутентификация успешна',
      user: userData,
      metadata: currentMetadata,
      data: {},
      timestamp: new Date().toISOString()
    };
    
    // Загружаем данные только если есть обновления
    if (hasUpdates) {
      console.log('📦 Загрузка данных для листов:', sheetsToLoad);
      const clientData = getClientData(ss, sheetsToLoad, isEmployee, phone);
      responseData.data = clientData;
      
      // 🔥 ЛОГИРОВАНИЕ ДЛЯ ПРОВЕРКИ
      console.log('🔍 Проверка наличия priceCategories:');
      console.log('  - priceCategories в данных:', 
        clientData.priceCategories ? 'есть' : 'нет');
      if (clientData.priceCategories) {
        console.log(`  - количество категорий: ${clientData.priceCategories.length}`);
        if (clientData.priceCategories.length > 0) {
          console.log('  - пример первой категории:', 
            JSON.stringify(clientData.priceCategories[0]).substring(0, 100));
        }
      }
      
    } else {
      console.log('📦 Данные актуальны, обновления не требуются');
      responseData.data = {};
    }
    
    // Логирование для отладки
    console.log('🔍 Проверка responseData:');
    console.log('  - status:', responseData.status);
    console.log('  - success:', responseData.success);
    console.log('  - user:', responseData.user ? 'есть' : 'нет');
    console.log('  - metadata keys:', Object.keys(responseData.metadata).length);
    console.log('  - data keys:', Object.keys(responseData.data).length);
    
    console.log(`✅ Аутентификация успешна для: ${phone}`);
    
    // 🔥 ВОЗВРАЩАЕМ ОБЪЕКТ, НЕ TextOutput
    return responseData;
    
  } catch (error) {
    console.error('❌ Ошибка авторизации:', error);
    
    if (error.message.includes('Колонка "Телефон" не найдена')) {
      return {
        status: 'error',
        message: 'Ошибка структуры данных: отсутствует колонка "Телефон" в листе "Заказы"'
      };
    }
    
    return {
      status: 'error',
      message: 'Ошибка при авторизации: ' + error.message
    };
  }
}
