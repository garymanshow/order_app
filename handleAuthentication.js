/**
 * Обработчик аутентификации с загрузкой витрины
 */
function handleAuthentication(phone, localMetadata, fcmToken) {
  let isGuest = false;
  let isEmployee = false;
  let isClient = false;
  let userData = {}; // Вынесли инициализацию user data

  try {
    console.log(`🔐 Начало аутентификации`);
    const ss = SpreadsheetApp.getActiveSpreadsheet();

    // === ШАГ 1: ПОИСК ТИПА ПОЛЬЗОВАТЕЛЯ ===
    if (!phone || phone.trim() === '') {
      isGuest = true;
      console.log(`👤 Тип пользователя: ГОСТЬ`);
      // Для гостя userData остается пустым объектом {}

    } else {
      isEmployee = isPhoneInSheet(ss, 'Сотрудники', phone);
      isClient = !isEmployee ? isPhoneInSheet(ss, 'Клиенты', phone) : false;

      if (!isEmployee && !isClient) {
        console.log(`❌ Пользователь с телефоном ${phone} не найден`);
        return {
          status: 'error',
          message: 'Пользователь не найден. Проверьте правильность введенного номера телефона.'
        };
      }

      console.log(`👤 Тип пользователя: ${isEmployee ? 'СОТРУДНИК' : 'КЛИЕНТ'}`);

      // === ШАГ 2: ПОЛУЧЕНИЕ ДАННЫХ ПОЛЬЗОВАТЕЛЯ (ТОЛЬКО ДЛЯ АВТОРИЗОВАННЫХ) ===
      if (isEmployee) {
        userData = getUserData(ss, 'Сотрудники', phone);
        console.log(`👤 Сотрудник авторизован с ролью: ${userData.role || 'Сотрудник'}`);
      } else {
        userData = getUserData(ss, 'Клиенты', phone);
        console.log(`👤 Клиент авторизован: ${userData.name || userData.company || phone}`);
      }
    }

    // === ШАГ 3: ПОЛУЧЕНИЕ МЕТАДАННЫХ (ОБЩЕЕ ДЛЯ ВСЕХ) ===
    // ✅ Вынесено за пределы условий, так как нужно всем типам пользователей
    const currentMetadata = getMetadataFromSheet(ss);

    // Инициализация localMetadata, если она не передана
    if (!localMetadata) localMetadata = {};

    // === ШАГ 4: ПОЛУЧЕНИЕ ВСЕХ ЛИСТОВ ИЗ МЕТАДАННЫХ ===
    const allSheetNames = Object.keys(currentMetadata);
    console.log('📋 Все листы по метаданным:', allSheetNames);

    // === ШАГ 5: ОПРЕДЕЛЕНИЕ ЛИСТОВ ДЛЯ ЗАГРУЗКИ ===
    const sheetsToLoad = [];
    let hasUpdates = false;

    if (Object.keys(localMetadata).length === 0) {
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

        if (!localMeta) {
          sheetsToLoad.push(sheetName);
          hasUpdates = true;
        } else if (new Date(localMeta.lastUpdate) < new Date(serverMeta.lastUpdate)) {
          sheetsToLoad.push(sheetName);
          hasUpdates = true;
        }
      }
    }

    // === ШАГ 7: ФИЛЬТРАЦИЯ ЛИСТОВ ПО ТИПУ ПОЛЬЗОВАТЕЛЯ ===
    if (isClient) {
      const excludedSheets = ['Сотрудники', 'Поставщики', 'Складские операции', 'Метаданные', 'Категории прайса', 'Ед.измерения'];
      const filteredSheets = sheetsToLoad.filter(sheet => !excludedSheets.includes(sheet));
      sheetsToLoad.length = 0;
      sheetsToLoad.push(...filteredSheets);
      console.log('📋 Для клиента загружаются листы:', sheetsToLoad);
    } else if (isEmployee) {
      // Сотрудникам нужны категории, добавляем если вдруг нет в списке на обновление
      if (hasUpdates && !sheetsToLoad.includes('Категории прайса') && allSheetNames.includes('Категории прайса')) {
        sheetsToLoad.push('Категории прайса');
      }
      console.log('📋 Для сотрудника загружаются листы:', sheetsToLoad);
    } else {
      // === ГОСТЬ ===
      // Гостям нужны только конкретные листы для отображения витрины
      const allowedSheets = ['Сотрудники', 'Прайс-лист', 'Категории прайса'];
      const filteredSheets = sheetsToLoad.filter(sheet => allowedSheets.includes(sheet));

      // Обновляем список к загрузке
      sheetsToLoad.length = 0;
      sheetsToLoad.push(...filteredSheets);

      console.log('📋 Для гостя загружаются листы:', sheetsToLoad);
    }

    // === ШАГ 8: ФОРМИРОВАНИЕ ОТВЕТА ===
    const responseData = {
      status: 'success',
      success: true,
      message: 'Аутентификация успешна',
      user: userData, // Для гостя будет пустой объект
      metadata: currentMetadata,
      data: {},
      timestamp: new Date().toISOString()
    };

    if (hasUpdates) {
      console.log('📦 Загрузка данных для листов:', sheetsToLoad);
      const clientData = getClientData(ss, sheetsToLoad, isEmployee, phone);
      responseData.data = clientData;
    } else {
      console.log('📦 Данные актуальны, обновления не требуются');
    }

    console.log(`✅ Аутентификация успешна для: ${phone || 'Гость'}`);
    return responseData;

  } catch (error) {
    console.error('❌ Ошибка авторизации:', error);
    return {
      status: 'error',
      message: 'Ошибка при авторизации: ' + error.message
    };
  }
}
