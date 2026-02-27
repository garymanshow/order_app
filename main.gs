/**
 * Класс для работы с Document Properties Google Apps Script
 * Позволяет сохранять, получать и удалять данные на уровне документа
 */
class MyApp_DocumentPropertiesManager {
  constructor() {
    this.docProperties = PropertiesService.getDocumentProperties();
  }

  /**
   * Сохраняет данные в Document Properties
   * @param {string} key - Ключ для сохранения данных
   * @param {string} value - Значение для сохранения
   * @returns {Object} Объект с результатом операции
   */
  saveData(key, value) {
    try {
      this.docProperties.setProperty(key, value);
      return { status: 'success', message: 'Данные сохранены' };
    } catch (error) {
      return { 
        status: 'error', 
        message: `Ошибка сохранения данных: ${error.message}` 
      };
    }
  }

  /**
   * Получает данные из Document Properties по ключу
   * @param {string} key - Ключ для поиска данных
   * @returns {Object} Объект с результатом операции и данными
   */

    /**
   * Сохраняет объект, предварительно сериализуя его в JSON
   * @param {string} key - Ключ для сохранения
   * @param {Object} obj - Объект для сохранения
   * @returns {Object} Результат операции
   */
  saveObject(key, obj) {
    try {
      const jsonString = JSON.stringify(obj);
      return this.saveData(key, jsonString);
    } catch (error) {
      return { 
        status: 'error', 
        message: `Ошибка сериализации объекта: ${error.message}` 
      };
    }
  }

  /**
   * Удаляет данные из Document Properties по ключу
   * @param {string} key - Ключ для удаления
   * @returns {Object} Объект с результатом операции
   */
  deleteData(key) {
    try {
      this.docProperties.deleteProperty(key);
      return { status: 'success', message: 'Данные удалены' };
    } catch (error) {
      return { 
        status: 'error', 
        message: `Ошибка удаления данных: ${error.message}` 
      };
    }
  }

  /**
   * Удаляет все свойства из Document Properties
   * @returns {Object} Объект с результатом операции
   */
  deleteAllProperties() {
    try {
      this.docProperties.deleteAllProperties();
      return { status: 'success', message: 'Все свойства удалены' };
    } catch (error) {
      return { 
        status: 'error', 
        message: `Ошибка удаления свойств: ${error.message}` 
      };
    }
  }

  /**
   * Проверяет существование ключа в Document Properties
   * @param {string} key - Ключ для проверки
   * @returns {boolean} true если ключ существует, иначе false
   */
  hasKey(key) {
    try {
      return this.docProperties.getProperty(key) !== null;
    } catch (error) {
      return false;
    }
  }

  // Получение ключа
  getData(key) {
    try {
      // Проверяем, что ключ существует
      const value = this.docProperties.getProperty(key);
      
      if (value === null || value === undefined) {
        return { 
          status: 'error', 
          message: 'Ключ не найден',
          data: null
        };
      }
      
      return {
        status: 'success',
        data: value,
        message: 'Данные получены'
      };
    } catch (error) {
      return {
        status: 'error',
        message: `Ошибка получения данных: ${error.message}`,
        data: null
      };
    }
  }

  /**
   * Получает все ключи из Document Properties
   * @returns {Object} Объект с результатом операции и массивом ключей
   */
  getAllKeys() {
    try {
      const keys = this.docProperties.getKeys();
      return { 
        status: 'success', 
        keys: keys,
        message: keys.length > 0 ? 'Ключи получены' : 'Ключи не найдены'
      };
    } catch (error) {
      return { 
        status: 'error', 
        message: `Ошибка получения ключей: ${error.message}` 
      };
    }
  }

  /**
   * Получает все свойства из Document Properties
   * @returns {Object} Объект с результатом операции и объектом свойств
   */
  getAllProperties() {
    try {
      const properties = this.docProperties.getProperties();
      return { 
        status: 'success', 
        properties: properties,
        message: 'Свойства получены'
      };
    } catch (error) {
      return { 
        status: 'error', 
        message: `Ошибка получения свойств: ${error.message}` 
      };
    }
  }

  /**
   * Получает объект, десериализуя его из JSON
   * @param {string} key - Ключ для поиска
   * @returns {Object} Результат операции с объектом
   */

  /**
   * Инкрементирует числовое значение
   * @param {string} key - Ключ
   * @param {number} increment - Значение инкремента
   * @returns {Object} Результат операции
   */
  incrementValue(key, increment = 1) {
    const result = this.getData(key);
    
    if (result.status === 'success') {
      try {
        const currentValue = parseFloat(result.data) || 0;
        const newValue = currentValue + increment;
        return this.saveData(key, newValue.toString());
      } catch (e) {
        return { 
          status: 'error', 
          message: `Ошибка инкрементации значения: ${e.message}` 
        };
      }
    }
    
    return result;
  }
}

// Google Apps Script - универсальная функция обновления метаданных
function updateMetadata_(sheetName, timestamp, editorInfo, changeType = 'API') {
  const ss = SpreadsheetApp.getActiveSpreadsheet();
  const metadataSheet = ss.getSheetByName('Метаданные');
  
  if (!metadataSheet) {
    throw new Error('Лист "Метаданные" не найден!');
  }

  // Получаем все данные из метаданных
  const metadataRange = metadataSheet.getDataRange();
  const metadataValues = metadataRange.getValues();
  
  // Ищем строку с нужным именем листа
  let targetRow = -1;
  for (let i = 0; i < metadataValues.length; i++) {
    if (metadataValues[i][0] === sheetName) {
      targetRow = i + 1;
      break;
    }
  }
  
  // Если лист не найден, добавляем новую строку
  if (targetRow === -1) {
    targetRow = metadataValues.length + 1;
    metadataSheet.getRange(targetRow, 1).setValue(sheetName);
  }
  
  // Обновляем все колонки
  metadataSheet.getRange(targetRow, 2).setValue(timestamp);
  metadataSheet.getRange(targetRow, 3).setValue(editorInfo);
  metadataSheet.getRange(targetRow, 4).setValue(changeType);
  
  console.log(`✅ Метаданные обновлены для листа "${sheetName}": ${timestamp} пользователем: ${editorInfo} (${changeType})`);
}

/**
 * Основная функция-обработчик для всех POST-запросов.
 * @param {Object} e - Объект события, содержащий данные запроса.
 * @return {TextOutput} JSON-ответ.
 */
function doPost(e) {
  console.log('🚀 Вход в doPost');
  
  try {
    // Проверяем, есть ли данные
    if (!e || !e.postData || !e.postData.contents) {
      return createErrorResponse('Нет данных в запросе');
    }
    
    // Парсим тело запроса
    let body;
    try {
      body = JSON.parse(e.postData.contents);
      console.log('📦 Получено тело запроса:', JSON.stringify(body).substring(0, 200));
    } catch (parseError) {
      return createErrorResponse('Ошибка парсинга JSON: ' + parseError.message);
    }
    
    // Обработка разных действий
    if (body.action === 'test') {
      // Тестовый запрос для проверки соединения
      return createSuccessResponse({
        message: 'Apps Script сервер работает',
        timestamp: new Date().toISOString(),
        action: 'test'
      });
    }
    
    if (body.action === 'authenticate') {
      console.log('🔐 Обработка аутентификации');
      
      if (!body.phone) {
        return createErrorResponse('Для аутентификации требуется поле "phone"');
      }
      
      // Обрабатываем аутентификацию
      return handleAuthentication(body.phone, body.secret, body.sheetName);
    }
    
    // Для других действий требуется полная валидация
    if (body.action === 'create' || body.action === 'read' || body.action === 'update' || body.action === 'delete') {
      const validation = validateRequest(body);
      
      if (validation.status === 'error') {
        return createErrorResponse(validation.message);
      }
      
      // Выполняем действие
      switch(body.action) {
        case 'create':
          return handleCreate(validation.sheet, validation.headers, validation.headersMap, body.data);
        case 'read':
          return handleRead(validation.sheet, validation.headers, validation.headersMap, body);
        case 'update':
          return handleUpdate(validation.sheet, validation.headers, validation.headersMap, body);
        case 'delete':
          return handleDelete(validation.sheet, validation.headers, validation.headersMap, body);
        default:
          return createErrorResponse(`Неизвестное действие: ${body.action}`);
      }
    }
    
    // Если действие не распознано
    return createErrorResponse(`Неизвестное действие: ${body.action}`);
    
  } catch (error) {
    console.error('💥 Критическая ошибка в doPost:', error);
    return createErrorResponse('Внутренняя ошибка сервера: ' + error.message);
  }
}

// Также нужна функция doGet для проверки работоспособности
function doGet(e) {
  console.log('📡 GET запрос получен');
  
  if (e && e.parameter && e.parameter.action === 'test') {
    return createSuccessResponse({
      message: 'Apps Script сервер работает (GET)',
      timestamp: new Date().toISOString(),
      method: 'GET'
    });
  }
  
  return createSuccessResponse({
    message: 'Используйте POST запрос для работы с API',
    endpoints: {
      test: 'GET/POST /?action=test',
      authenticate: 'POST / с JSON {"action":"authenticate","phone":"...","secret":"..."}',
      create: 'POST / с JSON {"action":"create","sheetName":"...","secret":"...","data":{...}}'
    }
  });
}

function onEdit(e) {
  const range = e.range;
  const sheet = range.getSheet();
  const sheetName = sheet.getName();
  const rowIndex = range.getRow();
  
  // Заполнение метаданных при изменении на Листах
  if (sheetName !== 'Метаданные') {
    const userEmail = Session.getActiveUser().getEmail() || 'Неизвестный пользователь';
    updateMetadata_(sheetName, new Date().toISOString(), userEmail, 'Ручное');
  }

  // Автоматическое заполнение столбца ID на любых листах, при заполнении значениями ячеек в других столбцах
    if (e && e.range) {
    handleIdGeneration(e.range.getSheet());
  }
}

/**
 * Изменениях через API (- работает с API вызовами)
 */
function onChange(e) {
  
  //  генерации ID для любых листов
  if (e.changeType === 'EDIT') {
    handleIdGeneration(SpreadsheetApp.getActiveSheet());
  }
}

function createResponse(statusCode, data) {
  return ContentService
    .createTextOutput(JSON.stringify(data))
    .setMimeType(ContentService.MimeType.JSON);
}

function createErrorResponse(message) {
  // Создаем объект ответа
  const output = ContentService.createTextOutput();
  output.setMimeType(ContentService.MimeType.JSON);
  output.setContent(JSON.stringify({
    status: 'error',
    message: message,
    timestamp: new Date().toISOString()
  }));
  
  // В Google Apps Script заголовки устанавливаются по-другому
  // Используем setHeaders для CORS
  return output;
}

function createSuccessResponse(data) {
  const output = ContentService.createTextOutput();
  output.setMimeType(ContentService.MimeType.JSON);
  
  const responseData = {
    status: 'success',
    timestamp: new Date().toISOString(),
    ...data
  };
  
  output.setContent(JSON.stringify(responseData));
  return output;
}


function handleAuthentication(phone, secret, sheetName = 'Клиенты') {
  console.log(`🔐 Аутентификация пользователя: ${phone}`);
  
  try {
    const ss = SpreadsheetApp.getActiveSpreadsheet();
    
    // Проверяем секретный ключ
    const manager = new MyApp_DocumentPropertiesManager();
    const secretResult = manager.getData('APP_SECRET_KEY');
    
    if (secretResult.status !== 'success' || !secretResult.data) {
      console.error('❌ Секретный ключ не настроен');
      return createErrorResponse('Секретный ключ не настроен. Выполните initializeSecurity()');
    }
    
    console.log('🔐 Получен секрет из хранилища:', secretResult.data.substring(0, 10) + '...');
    console.log('🔐 Переданный секрет:', secret ? secret.substring(0, 10) + '...' : 'не указан');
    
    if (secret !== secretResult.data) {
      console.error('❌ Неверный ключ доступа');
      return createErrorResponse('Неверный ключ доступа');
    }
    
    console.log('✅ Секретный ключ валиден');
    
    // Ищем пользователя в разных листах
    let user = null;
    let sheetNames = ['Сотрудники', 'Клиенты'];
    
    for (const sName of sheetNames) {
      const sheet = ss.getSheetByName(sName);
      if (!sheet) {
        console.log(`📋 Лист "${sName}" не найден, пропускаем`);
        continue;
      }
      
      const lastRow = sheet.getLastRow();
      const lastColumn = sheet.getLastColumn();
      
      if (lastRow < 2) {
        console.log(`📋 Лист "${sName}" пуст, пропускаем`);
        continue;
      }
      
      console.log(`📋 Поиск в листе "${sName}" (строк: ${lastRow}, столбцов: ${lastColumn})`);
      
      const data = sheet.getRange(1, 1, lastRow, lastColumn).getValues();
      const headers = data[0];
      
      // Находим индекс столбца с телефоном
      const phoneIndex = headers.findIndex(h => 
        h && (h.toString().toLowerCase().includes('телефон') || 
              h.toString().toLowerCase().includes('phone'))
      );
      
      if (phoneIndex === -1) {
        console.log(`📋 В листе "${sName}" нет столбца с телефоном`);
        continue;
      }
      
      console.log(`📋 Столбец с телефоном найден в позиции ${phoneIndex + 1}`);
      
      // Ищем пользователя по номеру телефона
      for (let i = 1; i < data.length; i++) {
        const row = data[i];
        const rowPhone = row[phoneIndex];
        
        if (rowPhone && rowPhone.toString().trim() === phone.trim()) {
          console.log(`✅ Пользователь найден в строке ${i + 1} листа "${sName}"`);
          
          user = {
            phone: phone,
            sheet: sName,
            role: sName === 'Сотрудники' ? 'employee' : 'client'
          };
          
          // Собираем все данные строки
          headers.forEach((header, index) => {
            if (header && header.toString().trim() !== '') {
              const key = header.toString().trim();
              const value = row[index];
              
              // Преобразуем даты в строки
              if (value instanceof Date) {
                user[key] = value.toISOString();
              } else {
                user[key] = value;
              }
            }
          });
          
          break;
        }
      }
      
      if (user) break;
    }
    
    if (!user) {
      console.error('❌ Пользователь не найден');
      return createErrorResponse('Пользователь не найден. Проверьте номер телефона');
    }
    
    // Получаем метаданные всех листов
    const metadata = getAllSheetsMetadata(ss);
    
    // Формируем успешный ответ
    const response = {
      message: 'Аутентификация успешна',
      success: true,
      user: user,
      metadata: metadata
    };
    
    console.log('✅ Аутентификация успешна для:', phone);
    
    return createSuccessResponse(response);
    
  } catch (error) {
    console.error('❌ Ошибка аутентификации:', error);
    return createErrorResponse('Ошибка аутентификации: ' + error.message);
  }
}

function debugSheets() {
  console.log('📊 ========== ДИАГНОСТИКА ТАБЛИЦЫ ==========');
  
  const ss = SpreadsheetApp.getActiveSpreadsheet();
  const sheets = ss.getSheets();
  
  console.log('📋 Всего листов: ' + sheets.length);
  
  sheets.forEach((sheet, index) => {
    console.log(`\n${index + 1}. Лист: "${sheet.getName()}"`);
    console.log('   Строк: ' + sheet.getLastRow());
    console.log('   Столбцов: ' + sheet.getLastColumn());
    
    if (sheet.getLastRow() > 0) {
      const headers = sheet.getRange(1, 1, 1, sheet.getLastColumn()).getValues()[0];
      console.log('   Заголовки:');
      headers.forEach((header, i) => {
        console.log(`     ${i + 1}. ${header || '(пусто)'}`);
      });
      
      // Покажем первые 3 строки данных
      if (sheet.getLastRow() > 1) {
        const sampleRows = Math.min(3, sheet.getLastRow() - 1);
        const data = sheet.getRange(2, 1, sampleRows, sheet.getLastColumn()).getValues();
        console.log('   Пример данных:');
        data.forEach((row, rowIndex) => {
          console.log(`     Строка ${rowIndex + 2}:`);
          row.forEach((cell, cellIndex) => {
            if (headers[cellIndex]) {
              console.log(`       ${headers[cellIndex]}: ${cell}`);
            }
          });
        });
      }
    }
  });
  
  console.log('\n==========================================');
  return 'Диагностика завершена';
}

function getAllSheetsMetadata(ss) {
  console.log('📊 Получение метаданных всех листов');
  
  const metadataSheet = ss.getSheetByName('Метаданные');
  const metadata = {};
  
  if (!metadataSheet) {
    console.log('📊 Лист "Метаданные" не найден, создаем базовые метаданные');
    
    // Создаем базовые метаданные для всех листов
    const sheets = ss.getSheets();
    sheets.forEach(sheet => {
      const sheetName = sheet.getName();
      if (sheetName !== 'Метаданные') {
        metadata[sheetName] = {
          lastUpdate: new Date().toISOString(),
          editor: 'system',
          rows: sheet.getLastRow(),
          columns: sheet.getLastColumn(),
          sheetId: sheet.getSheetId()
        };
      }
    });
    
    return metadata;
  }
  
  const metadataRange = metadataSheet.getDataRange();
  const metadataValues = metadataRange.getValues();
  
  for (let i = 0; i < metadataValues.length; i++) {
    const sheetName = metadataValues[i][0];
    const lastUpdate = metadataValues[i][1];
    const editor = metadataValues[i][2];
    
    if (sheetName) {
      metadata[sheetName] = {
        lastUpdate: lastUpdate instanceof Date ? lastUpdate.toISOString() : lastUpdate,
        editor: editor || '',
        rowIndex: i + 1
      };
    }
  }
  
  console.log('📊 Получено метаданных для листов:', Object.keys(metadata).length);
  return metadata;
}

// Просмотр всех листов таблицы
function testCurrentSpreadsheet() {
  console.log('🧪 ТЕСТИРОВАНИЕ ТАБЛИЦЫ');
  
  const ss = SpreadsheetApp.getActiveSpreadsheet();
  console.log('📁 Название таблицы:', ss.getName());
  console.log('📁 ID таблицы:', ss.getId());
  console.log('📁 URL таблицы:', ss.getUrl());
  
  // ИЗМЕНЕНИЕ ЗДЕСЬ:
  // Получаем массив ВСЕХ существующих листов, а не жестко заданный список
  const allSheets = ss.getSheets();
  
  console.log(`🔍 Всего найдено листов: ${allSheets.length}`);
  console.log('---');
  
  // Проходимся по каждому реальному объекту листа
  allSheets.forEach(sheet => {
    console.log(`✅ Лист: "${sheet.getName()}"`);
    console.log(`   Строк: ${sheet.getLastRow()}, Столбцов: ${sheet.getLastColumn()}`);
    
    // Проверяем, есть ли данные на листе (чтобы не было ошибки при чтении заголовков)
    if (sheet.getLastRow() > 0 && sheet.getLastColumn() > 0) {
      // Получаем заголовки (1-я строка)
      const headers = sheet.getRange(1, 1, 1, sheet.getLastColumn()).getValues()[0];
      console.log(`   Заголовки: ${headers.join(', ')}`);
    } else {
      console.log(`   (Лист пуст или нет данных в первой строке)`);
    }
    
    console.log('---'); // Разделитель для удобства чтения
  });
  
  return 'Тестирование завершено';
}


function createResponse(statusCode, data) {
  return ContentService
    .createTextOutput(JSON.stringify(data))
    .setMimeType(ContentService.MimeType.JSON)
    .setStatusCode(statusCode);
}

function getValidSecrets() {
  // Возвращает массив валидных секретных ключей
  // В реальном приложении храните секреты в PropertiesService
  return PropertiesService.getScriptProperties().getProperty('API_SECRETS').split(',');
}

// ==================== ФУНКЦИЯ ВАЛИДАЦИИ ====================

/**
 * Выполняет комплексную проверку входящего запроса.
 * @param {Object} body - Распарсенное тело запроса.
 * @return {Object} - Объект с ошибкой или с валидированными данными.
 */
function validateRequest(body) {
  console.log('🔐 Валидация запроса для действия:', body.action);
  
  // Проверяем обязательные поля
  if (!body.sheetName) {
    return { status: 'error', message: 'Отсутствует обязательное поле: sheetName' };
  }
  
  if (!body.secret) {
    return { status: 'error', message: 'Отсутствует обязательное поле: secret' };
  }
  
  if (!body.action) {
    return { status: 'error', message: 'Отсутствует обязательное поле: action' };
  }
  
  // Проверяем секретный ключ
  const manager = new MyApp_DocumentPropertiesManager();
  const secretResult = manager.getData('APP_SECRET_KEY');
  
  if (secretResult.status !== 'success' || !secretResult.data) {
    return { status: 'error', message: 'Секретный ключ не настроен' };
  }
  
  if (body.secret !== secretResult.data) {
    return { status: 'error', message: 'Неверный ключ доступа' };
  }
  
  // Получаем лист
  const ss = SpreadsheetApp.getActiveSpreadsheet();
  const sheet = ss.getSheetByName(body.sheetName);
  
  if (!sheet) {
    return { status: 'error', message: `Лист "${body.sheetName}" не найден` };
  }
  
  // Получаем заголовки
  const lastColumn = sheet.getLastColumn();
  const headers = sheet.getRange(1, 1, 1, lastColumn).getValues()[0];
  const headersMap = {};
  
  headers.forEach((header, index) => {
    if (header && header.toString().trim() !== '') {
      headersMap[header.toString().trim()] = index;
    }
  });
  
  return {
    status: 'success',
    sheet: sheet,
    headers: headers,
    headersMap: headersMap,
    body: body
  };
}

/**
 * Валидация параметров для действия 'read' с расширенной проверкой.
 */
function validateReadParams(body, headersMap) {
  // Валидация фильтра
  if (body.filter) {
    const filterValidation = validateFilter(body.filter, headersMap);
    if (filterValidation.status === "error") return filterValidation;
  }
  // Валидация сортировки (orderBy)
  if (body.orderBy) {
    if (typeof body.orderBy !== 'object' || Array.isArray(body.orderBy) || body.orderBy === null) {
      return { status: "error", message: "Параметр 'orderBy' должен быть объектом, например: {column: 'Имя', direction: 'asc'}." };
    }
    if (!body.orderBy.column) {
      return { status: "error", message: "В 'orderBy' отсутствует обязательное поле 'column'." };
    }
    if (!headersMap.hasOwnProperty(body.orderBy.column)) {
      return { status: "error", message: `Столбец для сортировки '${body.orderBy.column}' не найден.` };
    }
    if (body.orderBy.direction && !['asc', 'desc'].includes(String(body.orderBy.direction).toLowerCase())) {
      return { status: "error", message: "Направление сортировки 'direction' должно быть 'asc' или 'desc'." };
    }
  }
  // Валидация пагинации (limit, offset) с более точными сообщениями
  if (body.limit) {
    const limitVal = Number(body.limit);
    if (!Number.isInteger(limitVal)) {
      return { status: "error", message: "Параметр 'limit' должен быть целым числом." };
    }
    if (limitVal <= 0) {
      return { status: "error", message: "Параметр 'limit' должен быть больше 0." };
    }
  }
  if (body.offset) {
    const offsetVal = Number(body.offset);
    if (!Number.isInteger(offsetVal)) {
      return { status: "error", message: "Параметр 'offset' должен быть целым числом." };
    }
    if (offsetVal < 0) {
      return { status: "error", message: "Параметр 'offset' должен быть 0 или больше." };
    }
  }
  return { status: "success" };
}

/**
 * Валидация параметров для действия 'update'.
 */
function validateUpdateParams(body, headersMap) {
  if (!body.filter) {
    return { status: "error", message: "Для действия 'update' необходимо передать поле 'filter' для поиска записи." };
  }
  if (!body.data) {
    return { status: "error", message: "Для действия 'update' необходимо передать поле 'data' с новыми значениями." };
  }
  return validateFilter(body.filter, headersMap);
}

/**
 * Валидация параметров для действия 'delete'.
 */
function validateDeleteParams(body, headersMap) {
  if (!body.filter) {
    return { status: "error", message: "Для действия 'delete' необходимо передать поле 'filter' для поиска записи." };
  }
  return validateFilter(body.filter, headersMap);
}

/**
 * Универсальная и строгая валидация фильтра.
 */
function validateFilter(filter, headersMap) {
  const ALLOWED_OPERATORS = ['equals', 'greater_than', 'less_than', 'contains', 'startsWith'];

  if (!Array.isArray(filter)) {
    return { status: "error", message: "Поле 'filter' должно быть массивом условий." };
  }
  for (const condition of filter) {
    if (!condition.column || condition.value === undefined || condition.value === null) {
      return { status: "error", message: "Каждое условие в 'filter' должно содержать 'column' и 'value'." };
    }
    if (!headersMap.hasOwnProperty(condition.column)) {
      return { status: "error", message: `Столбец для фильтра '${condition.column}' не найден.` };
    }
    const operator = condition.operator || 'equals';
    if (!ALLOWED_OPERATORS.includes(operator)) {
      return { status: "error", message: `Неподдерживаемый оператор '${operator}'. Допустимые: ${ALLOWED_OPERATORS.join(', ')}.` };
    }
    if (['greater_than', 'less_than'].includes(operator) && isNaN(Number(condition.value))) {
      return { status: "error", message: `Значение для оператора '${operator}' в столбце '${condition.column}' должно быть числом.` };
    }
  }
  return { status: "success" };
}


// ==================== ОБРАБОТЧИКИ ДЕЙСТВИЙ CRUD (Create Read Update Delete) ====================
function handleRead(sheet, headers, headersMap, params) {
  const { filter, orderBy, limit, offset } = params;
  let data = sheet.getDataRange().getValues();
  let filteredRows = data.slice(1);

  // Применение фильтров с поддержкой операторов
  if (filter && filter.length > 0) {
    filteredRows = filteredRows.filter(row => {
      return filter.every(condition => {
        const columnIndex = headersMap[condition.column];
        const cellValue = row[columnIndex];
        const operator = condition.operator || 'equals';
        const conditionValue = condition.value;

        switch (operator) {
          case 'greater_than':
            return Number(cellValue) > Number(conditionValue);
          case 'less_than':
            return Number(cellValue) < Number(conditionValue);
          case 'contains':
            return String(cellValue).includes(String(conditionValue));
          case 'startsWith':
            return String(cellValue).startsWith(String(conditionValue));
          case 'equals': // по умолчанию
          default:
            return String(cellValue) == String(conditionValue);
        }
      });
    });
  }

  // Применение сортировки
  if (orderBy) {
    const columnIndex = headersMap[orderBy.column];
    filteredRows.sort((a, b) => {
      const valA = a[columnIndex];
      const valB = b[columnIndex];
      if (orderBy.direction.toLowerCase() === 'desc') {
        if (valA > valB) return -1;
        if (valA < valB) return 1;
        return 0;
      }
      if (valA > valB) return 1;
      if (valA < valB) return -1;
      return 0;
    });
  }

  // Применение пагинации
  const startIndex = offset ? Number(offset) : 0;
  const endIndex = limit ? startIndex + Number(limit) : filteredRows.length;
  const paginatedRows = filteredRows.slice(startIndex, endIndex);

  // Преобразование в массив объектов
  const resultObjects = paginatedRows.map(row => {
    let obj = {};
    headers.forEach((header, index) => { obj[header] = row[index]; });
    return obj;
  });
  return createSuccessResponse(resultObjects, "Данные успешно получены.");
}

// ==================== ОБРАБОТЧИКИ ДЕЙСТВИЙ CRUD (Create Read Update Delete) ====================
function handleCreate(sheet, rowData) {
  try {
    sheet.appendRow(rowData);
    console.log('✅ Строка успешно добавлена');
    return createResponse(200, {
      status: 'success',
      message: 'Данные успешно добавлены'
    });
  } catch (error) {
    console.error('❌ Ошибка при добавлении строки:', error);
    return createResponse(500, {
      status: 'error',
      message: `Ошибка при добавлении данных: ${error.message}`
    });
  }
}
// Функция для отладки всех таблиц
function debugAllSheets() {
  console.log('📊 ========== ДИАГНОСТИКА ВСЕХ ТАБЛИЦ ==========');
  
  const ss = SpreadsheetApp.getActiveSpreadsheet();
  const sheets = ss.getSheets();
  
  console.log('📋 Всего листов: ' + sheets.length);
  
  sheets.forEach((sheet, index) => {
    console.log(`\n${index + 1}. Лист: "${sheet.getName()}"`);
    console.log('   Строк: ' + sheet.getLastRow());
    console.log('   Столбцов: ' + sheet.getLastColumn());
    
    if (sheet.getLastRow() > 0) {
      const headers = sheet.getRange(1, 1, 1, sheet.getLastColumn()).getValues()[0];
      console.log('   Заголовки: ' + JSON.stringify(headers));
    }
  });
  
  console.log('\n==========================================');
}

// Тест создания с неправильными данными
function testCreateWithWrongData() {
  console.log('🧪 ========== ТЕСТ С ОШИБОЧНЫМИ ДАННЫМИ ==========');
  
  // Тест 1: Неправильный ключ
  const testData1 = {
    action: "create",
    sheetName: "Заказы",
    secret: "НЕПРАВИЛЬНЫЙ_КЛЮЧ",
    data: {
      "Статус": "тест"
    }
  };
  
  // Тест 2: Лишние столбцы
  const testData2 = {
    action: "create",
    sheetName: "Заказы",
    secret: "s3ivohyRqt7ZZTys3khBkTpsg+sP9tQzC9pyVabQd7Q=",
    data: {
      "Статус": "тест",
      "Название": "товар",
      "Количество": "1",
      "Итоговая цена": "100",
      "Дата": new Date().toISOString(),
      "Телефон": "+79000000000",
      "Клиент": "клиент",
      "Оплата": "0",
      "ЛИШНИЙ_СТОЛБЕЦ": "ошибка" // Этого столбца нет в таблице
    }
  };
  
  // Тест 3: Отсутствующие столбцы
  const testData3 = {
    action: "create",
    sheetName: "Заказы",
    secret: "s3ivohyRqt7ZZTys3khBkTpsg+sP9tQzC9pyVabQd7Q=",
    data: {
      "Статус": "тест",
      "Название": "товар"
      // Остальные столбцы отсутствуют
    }
  };
  
  [testData1, testData2, testData3].forEach((testData, index) => {
    console.log(`\n🧪 Тест ${index + 1}:`);
    console.log('   Данные: ' + JSON.stringify(testData));
    
    const mockEvent = {
      postData: {
        contents: JSON.stringify(testData),
        type: 'application/json'
      }
    };
    
    try {
      const result = doPost(mockEvent);
      console.log('   Результат: ' + result.getContent());
    } catch (error) {
      console.error('   Ошибка: ' + error.message);
    }
  });
  
  console.log('==========================================');
}


// Также добавим диагностику в validateRequest для create
// Обновленная функция validateCreateParams
function validateCreateParams(body, headersMap) {
  console.log('🔍 ========== ВАЛИДАЦИЯ create ==========');
  console.log('📋 Полученные данные: ' + JSON.stringify(body.data));
  console.log('📋 Заголовки таблицы: ' + JSON.stringify(Object.keys(headersMap)));
  
  if (!body.data) {
    console.error('❌ Отсутствует поле data');
    return { status: "error", message: "Для действия 'create' необходимо передать поле 'data'." };
  }
  
  // Проверяем, что все необходимые поля есть
  const missingColumns = [];
  const extraColumns = [];
  
  for (const column in body.data) {
    if (!headersMap.hasOwnProperty(column)) {
      extraColumns.push(column);
      console.warn(`⚠️ Лишний столбец: ${column}`);
    }
  }
  
  // Проверяем обязательные поля (можно настроить под конкретные таблицы)
  const requiredColumns = [];
  for (const column of requiredColumns) {
    if (!body.data.hasOwnProperty(column)) {
      missingColumns.push(column);
    }
  }
  
  if (missingColumns.length > 0) {
    console.error('❌ Отсутствуют обязательные поля: ' + missingColumns.join(', '));
    return { 
      status: "error", 
      message: `Отсутствуют обязательные поля: ${missingColumns.join(', ')}` 
    };
  }
  
  if (extraColumns.length > 0) {
    console.warn(`⚠️ Лишние поля будут проигнорированы: ${extraColumns.join(', ')}`);
  }
  
  console.log('✅ Валидация create пройдена');
  return { status: "success" };
}

// Обновленная функция validateRequest
function validateRequest(body) {
  console.log('🔐 ========== НАЧАЛО ВАЛИДАЦИИ ==========');
  console.log('📦 Получено тело: ' + JSON.stringify(body).substring(0, 500) + '...');
  
  // 🔐 Получаем секрет из DocumentProperties
  const manager = new MyApp_DocumentPropertiesManager();
  const secretResult = manager.getData('APP_SECRET_KEY');
  console.log("Получен секрет из DocumentProperties: " + secretResult.data);
  
  if (secretResult.status !== 'success' || !secretResult.data) {
    console.error('❌ Секретный ключ не настроен');
    return { status: "error", message: "Секретный ключ не настроен на стороне сервера. Выполните там initializeSecurity()." };
  }
  
  if (body.secret !== secretResult.data) {
    console.error('❌ Неверный ключ доступа');
    return { status: "error", message: "Неверный ключ доступа." };
  }
  
  if (!body.sheetName) {
    console.error('❌ Отсутствует sheetName');
    return { status: "error", message: "Отсутствует обязательное поле: sheetName." };
  }
  
  if (!body.action) {
    console.error('❌ Отсутствует action');
    return { status: "error", message: "Отсутствует обязательное поле: action." };
  }
  
  const ss = SpreadsheetApp.getActiveSpreadsheet();
  if (!ss) {
    console.error('❌ Таблица не найдена');
    return { status: "error", message: "Таблица не найдена или нет доступа." };
  }
  
  const sheet = ss.getSheetByName(body.sheetName);
  if (!sheet) {
    console.error(`❌ Лист '${body.sheetName}' не найден`);
    return { status: "error", message: `Лист с названием '${body.sheetName}' не найден.` };
  }
  
  const headers = sheet.getRange(1, 1, 1, sheet.getLastColumn()).getValues()[0];
  const headersMap = headers.reduce((map, header, index) => {
    map[header] = index;
    return map;
  }, {});
  
  console.log('📋 Заголовки листа: ' + JSON.stringify(headers));
  console.log('📋 headersMap: ' + JSON.stringify(headersMap));
  
  let validation;
  switch (body.action) {
    case "read":
      console.log('📖 Валидация read');
      validation = validateReadParams(body, headersMap);
      if (validation.status === "error") return validation;
      break;
    case "create":
      console.log('➕ Валидация create');
      validation = validateCreateParams(body, headersMap);
      if (validation.status === "error") return validation;
      break;
    case "update":
      console.log('✏️ Валидация update');
      validation = validateUpdateParams(body, headersMap);
      if (validation.status === "error") return validation;
      break;
    case "delete":
      console.log('🗑️ Валидация delete');
      validation = validateDeleteParams(body, headersMap);
      if (validation.status === "error") return validation;
      break;
    default:
      console.error('❌ Неизвестное действие: ' + body.action);
      return { status: "error", message: `Неизвестное действие: '${body.action}'.` };
  }
  
  console.log('✅ Валидация успешно пройдена');
  return {
    status: "success",
    sheet: sheet,
    headers: headers,
    headersMap: headersMap,
    body: body
  };
}

// Обновим функцию validateRequest для вызова новой валидации
function validateRequest(body) {
  console.log('🔐 ========== НАЧАЛО ВАЛИДАЦИИ ==========');
  console.log('📦 Получено тело: ' + JSON.stringify(body).substring(0, 500) + '...');
  
  // ... существующий код валидации ...
  
  switch (body.action) {
    case "read":
      const readValidation = validateReadParams(body, headersMap);
      if (readValidation.status === "error") return readValidation;
      break;
    case "create":
      const createValidation = validateCreateParams(body, headersMap); // Новая валидация
      if (createValidation.status === "error") return createValidation;
      break;
    case "update":
      const updateValidation = validateUpdateParams(body, headersMap);
      if (updateValidation.status === "error") return updateValidation;
      break;
    case "delete":
      const deleteValidation = validateDeleteParams(body, headersMap);
      if (deleteValidation.status === "error") return deleteValidation;
      break;
    default:
      console.error('❌ Неизвестное действие: ' + body.action);
      return { status: "error", message: `Неизвестное действие: '${body.action}'.` };
  }
  
  console.log('✅ Валидация успешно пройдена');
  return {
    status: "success",
    sheet: sheet,
    headers: headers,
    headersMap: headersMap,
    body: body
  };
}

// Добавим вспомогательную функцию для отладки структуры таблицы
function debugSheetStructure(sheetName) {
  console.log('📊 ========== ДИАГНОСТИКА СТРУКТУРЫ ЛИСТА ==========');
  console.log('📋 Лист: ' + sheetName);
  
  const ss = SpreadsheetApp.getActiveSpreadsheet();
  const sheet = ss.getSheetByName(sheetName);
  
  if (!sheet) {
    console.error('❌ Лист не найден: ' + sheetName);
    return;
  }
  
  const lastRow = sheet.getLastRow();
  const lastColumn = sheet.getLastColumn();
  
  console.log('📊 Размеры таблицы:');
  console.log('   Строк: ' + lastRow);
  console.log('   Столбцов: ' + lastColumn);
  
  if (lastRow > 0) {
    const headers = sheet.getRange(1, 1, 1, lastColumn).getValues()[0];
    console.log('📋 Заголовки: ' + JSON.stringify(headers));
    
    // Покажем пример данных
    if (lastRow > 1) {
      const sampleData = sheet.getRange(2, 1, Math.min(3, lastRow-1), lastColumn).getValues();
      console.log('📋 Пример данных:');
      for (let i = 0; i < sampleData.length; i++) {
        console.log('   Строка ' + (i+2) + ': ' + JSON.stringify(sampleData[i]));
      }
    }
  }
  
  console.log('==========================================');
}

// Функция для ручного тестирования (можно запустить из редактора)
function testCreateFunction() {
  console.log('🧪 ========== ТЕСТИРОВАНИЕ CREATE ==========');
  
  // Сначала проверим структуру таблицы "Заказы"
  debugSheetStructure("Заказы");
  
  // Тестовые данные для листа "Заказы"
  const testData = {
    action: "create",
    sheetName: "Заказы",
    secret: "s3ivohyRqt7ZZTys3khBkTpsg+sP9tQzC9pyVabQd7Q=",
    data: {
      "Статус": "заказ",
      "Название": "Тестовый товар",
      "Количество": "2",
      "Итоговая цена": "3000",
      "Дата": new Date().toISOString(),
      "Телефон": "+79000000000",
      "Клиент": "Тестовый клиент",
      "Оплата": "0"
    }
  };
  
  console.log('🧪 Тестовые данные: ' + JSON.stringify(testData));
  
  // Проверим данные перед отправкой
  console.log('🔍 Проверка данных перед отправкой:');
  const headers = ["Статус", "Название", "Количество", "Итоговая цена", "Дата", "Телефон", "Клиент", "Оплата"];
  const newRow = headers.map(header => testData.data[header] || "");
  console.log('📝 Сформированная строка: ' + JSON.stringify(newRow));
  
  // Создаем mock объект события
  const mockEvent = {
    postData: {
      contents: JSON.stringify(testData),
      type: 'application/json',
      length: JSON.stringify(testData).length
    }
  };
  
  console.log('🚀 Запускаем doPost...');
  
  // Запускаем doPost
  const result = doPost(mockEvent);
  console.log('📥 Результат: ' + result.getContent());
  
  // Снова проверяем структуру таблицы после создания
  debugSheetStructure("Заказы");
  
  console.log('==========================================');
}

function handleUpdate(sheet, headers, headersMap, params) {
  const rowToUpdate = findRowNumber(sheet, params.filter, headersMap);
  if (rowToUpdate === -1) return createErrorResponse("Запись для обновления не найдена.");

  for (const key in params.data) {
    const columnIndex = headersMap[key];
    if (columnIndex !== undefined) {
      sheet.getRange(rowToUpdate, columnIndex + 1).setValue(params.data[key]);
    }
  }
  return createSuccessResponse(null, `Запись в строке ${rowToUpdate} успешно обновлена.`);
}

function handleDelete(sheet, headers, headersMap, params) {
  const rowToDelete = findRowNumber(sheet, params.filter, headersMap);
  if (rowToDelete === -1) return createErrorResponse("Запись для удаления не найдена.");

  sheet.deleteRow(rowToDelete);
  return createSuccessResponse(null, `Запись в строке ${rowToDelete} успешно удалена.`);
}


// ==================== ВСПОМОГАТЕЛЬНЫЕ ФУНКЦИИ ====================

function findRowNumber(sheet, filter, headersMap) {
  const data = sheet.getDataRange().getValues();
  for (let i = 1; i < data.length; i++) {
    const row = data[i];
    let isMatch = true;
    for (const condition of filter) {
      // Для поиска/удаления используем только точное совпадение
      if (String(row[headersMap[condition.column]]) !== String(condition.value)) {
        isMatch = false;
        break;
      }
    }
    if (isMatch) return i + 1;
  }
  return -1;
}

function createSuccessResponse(data, message) {
  return ContentService.createTextOutput(JSON.stringify({
    status: "success", message: message || "Операция выполнена успешно.", data: data
  })).setMimeType(ContentService.MimeType.JSON); // отправка сообщения в формате JSON во избежание возврата в HTML
}

function createErrorResponse(message) {
  console.error(message);
  return ContentService.createTextOutput(JSON.stringify({
    status: "error", message: message
  })).setMimeType(ContentService.MimeType.JSON); // отправка сообщения в формате JSON во избежание возврата в HTML
}
