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

/**
 * Преобразует дату в формат DD.MM.YYYY
 * Поддерживает ISO строку, timestamp, или уже отформатированную дату
 */
function formatDateToDDMMYYYY(dateValue) {
  try {
    if (!dateValue) {
      return '';
    }
    
    // Если уже в правильном формате (содержит точки)
    if (typeof dateValue === 'string' && dateValue.includes('.')) {
      // Проверяем, что это действительно дата в формате DD.MM.YYYY
      const parts = dateValue.split('.');
      if (parts.length === 3 && 
          !isNaN(parts[0]) && !isNaN(parts[1]) && !isNaN(parts[2])) {
        return dateValue; // Уже в правильном формате
      }
    }
    
    // Создаем объект Date
    const date = new Date(dateValue);
    
    // Проверяем валидность даты
    if (isNaN(date.getTime())) {
      console.warn(`Невалидная дата: ${dateValue}`);
      return '';
    }
    
    // Форматируем как DD.MM.YYYY
    const day = String(date.getDate()).padStart(2, '0');
    const month = String(date.getMonth() + 1).padStart(2, '0'); // Месяцы начинаются с 0
    const year = date.getFullYear();
    
    return `${day}.${month}.${year}`;
    
  } catch (error) {
    console.error('Ошибка форматирования даты:', error);
    return '';
  }
}

/**
 * Проверяет права доступа (опционально)
 */
function validateAccess(phone, requiredRole) {
  // Здесь можно добавить проверку роли если нужно
  // Например: проверка что пользователь является сотрудником
  
  return {
    valid: true
  };
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

// Возвращает массив валидных секретных ключей
// В реальном приложении храните секреты в PropertiesService
function getValidSecrets() {
  try {
    // Пробуем получить из Script Properties
    const scriptProps = PropertiesService.getScriptProperties();
    const secrets = scriptProps.getProperty('API_SECRETS');
    
    if (secrets) {
      return secrets.split(',');
    }
    
    // Пробуем из Document Properties
    const manager = new MyApp_DocumentPropertiesManager();
    const secretResult = manager.getData('APP_SECRET_KEY');
    
    if (secretResult.status === 'success' && secretResult.data) {
      return [secretResult.data];
    }
    
    // Возвращаем дефолтный секрет
    return ['s3ivohyRqt7ZZTys3khBkTpsg+sP9tQzC9pyVabQd7Q='];
    
  } catch (error) {
    console.error('Ошибка получения секретов:', error);
    return ['s3ivohyRqt7ZZTys3khBkTpsg+sP9tQzC9pyVabQd7Q='];
  }
}

// нигде не используется !!!
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

/**
 * Обновляет метаданные для листа
 * Структура: A:Лист | B:Последнее обновление | C:Редактор | D:Способ внесения
 */
function updateMetadata_(sheetName, timestamp, editorInfo, changeType = 'API') {
  const ss = SpreadsheetApp.getActiveSpreadsheet();
  const metadataSheet = ss.getSheetByName('Метаданные');
  
  if (!metadataSheet) {
    console.error('❌ Лист "Метаданные" не найден!');
    return;
  }

  // Проверяем, существует ли лист с таким именем
  const sheet = ss.getSheetByName(sheetName);
  if (!sheet) {
    console.warn(`⚠️ Лист "${sheetName}" не существует, пропускаем обновление`);
    return;
  }

  // Получаем все данные из метаданных
  const lastRow = metadataSheet.getLastRow();
  const data = lastRow > 1 ? metadataSheet.getRange(2, 1, lastRow - 1, 1).getValues() : [];
  
  // Ищем строку с нужным именем листа
  let targetRow = -1;
  for (let i = 0; i < data.length; i++) {
    if (data[i][0] === sheetName) {
      targetRow = i + 2;
      break;
    }
  }
  
  // Если лист не найден, добавляем новую строку
  if (targetRow === -1) {
    targetRow = lastRow + 1;
    metadataSheet.getRange(targetRow, 1).setValue(sheetName);
    console.log(`➕ Добавлен новый лист в метаданные: ${sheetName}`);
  }
  
  // Обновляем колонки
  metadataSheet.getRange(targetRow, 2).setValue(timestamp);
  metadataSheet.getRange(targetRow, 3).setValue(editorInfo);
  metadataSheet.getRange(targetRow, 4).setValue(changeType);
  
  console.log(`✅ Метаданные обновлены для листа "${sheetName}"`);
}

/**
 * Ручная синхронизация метаданных с актуальными листами
 * Запустите эту функцию если нужно принудительно обновить метаданные
 */
function syncMetadataManually() {
  console.log('🔄 Ручная синхронизация метаданных');
  
  const ss = SpreadsheetApp.getActiveSpreadsheet();
  const metadataSheet = ss.getSheetByName('Метаданные');
  
  if (!metadataSheet) {
    console.error('❌ Лист "Метаданные" не найден');
    return;
  }
  
  // Получаем все актуальные листы
  const currentSheets = new Set(
    ss.getSheets()
      .map(sheet => sheet.getName())
      .filter(name => name !== 'Метаданные')
  );
  
  console.log('📊 Актуальные листы:', Array.from(currentSheets));
  
  // Получаем существующие записи
  const lastRow = metadataSheet.getLastRow();
  const existingSheets = new Set();
  
  if (lastRow > 1) {
    const names = metadataSheet.getRange(2, 1, lastRow - 1, 1).getValues();
    names.forEach(row => {
      if (row[0]) existingSheets.add(row[0]);
    });
  }
  
  console.log('📊 Записи в метаданных:', Array.from(existingSheets));
  
  const now = new Date().toISOString();
  let added = 0, removed = 0;
  
  // Добавляем новые листы
  let newRow = lastRow + 1;
  currentSheets.forEach(sheetName => {
    if (!existingSheets.has(sheetName)) {
      console.log(`➕ Добавляем: ${sheetName}`);
      metadataSheet.getRange(newRow, 1).setValue(sheetName);
      metadataSheet.getRange(newRow, 2).setValue(now);
      metadataSheet.getRange(newRow, 3).setValue('system (manual)');
      metadataSheet.getRange(newRow, 4).setValue('Синхронизация');
      newRow++;
      added++;
    }
  });
  
  // Удаляем записи о несуществующих листах
  const rowsToDelete = [];
  if (lastRow > 1) {
    const data = metadataSheet.getRange(2, 1, lastRow - 1, 1).getValues();
    for (let i = 0; i < data.length; i++) {
      const sheetName = data[i][0];
      if (sheetName && !currentSheets.has(sheetName)) {
        console.log(`➖ Удаляем запись о: ${sheetName}`);
        rowsToDelete.push(i + 2);
        removed++;
      }
    }
  }
  
  // Удаляем в обратном порядке
  rowsToDelete.sort((a, b) => b - a);
  rowsToDelete.forEach(row => {
    metadataSheet.deleteRow(row);
  });
  
  console.log(`✅ Итог: добавлено ${added}, удалено ${removed}`);
}

/**
 * Функция для поиска индекса столбца по названию в первой строке.
 * @param {Sheet} sheet - Лист Google Sheets.
 * @param {string} columnName - Название столбца для поиска.
 * @returns {number|null} - Индекс столбца (начиная с 1) или null, если столбец не найден.
 */
function findColumnByHeader(sheet, columnName) {
  // Получаем первую строку таблицы
  const headerRow = sheet.getRange(1, 1, 1, sheet.getLastColumn()).getValues()[0];
  // Находим индекс столбца
  const index = headerRow.findIndex(cellValue => cellValue === columnName);
  // Возвращаем индекс (нумерация начинается с 1) или null, если столбец не найден
  return index !== -1 ? index + 1 : null;
}

// массив из элементов строки, исключая указанные колонки
function getRowValuesExceptColumn(sheet, rowIndex, excludeColumnIndex) {
  const range = sheet.getRange(rowIndex, 1, 1, sheet.getLastColumn());
  const values = range.getValues()[0];
  // Удаляем элемент с нужным индексом
  values.splice(excludeColumnIndex - 1, 1);
  return values;
}

// Подсчет количества не пустых элементов массива
function countNonEmptyCellsExceptColumn(sheet, rowIndex, excludeColumnIndex) {
  const values = getRowValuesExceptColumn(sheet, rowIndex, excludeColumnIndex);
  return values.filter(value => {
    if (typeof value !== 'string') return value !== "" && value !== null && value !== undefined;
    return value.trim() !== "";
  }).length;
}

/**
 * Функция для переноса уникальных значений из "Клиенты" в "Условия доставки"
 */
function transferUniqueValues() {
  try {
    const ss = SpreadsheetApp.getActiveSpreadsheet();
    const sheet1 = ss.getSheetByName("Клиенты");
    const sheet2 = ss.getSheetByName("Условия доставки");
    
    if (!sheet1 || !sheet2) {
      throw new Error("Один из листов не найден");
    }
    
    // Получаем все данные из колонки 6 Клиенты
    const lastRow1 = sheet1.getLastRow();
    const sourceRange = sheet1.getRange(1, 6, lastRow1, 1); // Колонка 6 (F)
    const sourceValues = sourceRange.getValues();
    
    // Получаем все существующие значения из колонки 1 Условия доставки
    const lastRow2 = sheet2.getLastRow();
    let targetValues = [];
    
    if (lastRow2 > 0) {
      const targetRange = sheet2.getRange(1, 1, lastRow2, 1); // Колонка 1 (A)
      targetValues = targetRange.getValues();
    }
    
    // Создаем Set для быстрой проверки уникальности
    const existingValues = new Set();
    targetValues.forEach(value => {
      if (value[0] && value[0].toString().trim() !== "") {
        existingValues.add(value[0].toString().trim());
      }
    });
    
    // Собираем уникальные значения из источника
    const uniqueValues = [];
    sourceValues.forEach(value => {
      const trimmedValue = value[0] ? value[0].toString().trim() : "";
      if (trimmedValue !== "" && !existingValues.has(trimmedValue)) {
        uniqueValues.push(trimmedValue);
        existingValues.add(trimmedValue); // Добавляем в Set, чтобы избежать дубликатов в текущей операции
      }
    });
    
    // Добавляем уникальные значения на Условия доставки
    if (uniqueValues.length > 0) {
      // Определяем, с какой строки начинать добавление
      const startRow = lastRow2 > 0 ? lastRow2 + 1 : 1;
      
      // Подготавливаем данные для вставки (массив массивов)
      const valuesToInsert = uniqueValues.map(value => [value]);
      
      // Вставляем значения
      sheet2.getRange(startRow, 1, valuesToInsert.length, 1).setValues(valuesToInsert);
      
      // Сортируем значения на Условия доставки (по алфавиту)
      if (lastRow2 > 0) {
        const fullRange = sheet2.getRange(1, 1, sheet2.getLastRow(), 1);
        fullRange.sort({ column: 1, ascending: true });
      }
      
      Logger.log(`Добавлено ${uniqueValues.length} уникальных значений на Условия доставки`);
    } else {
      Logger.log("Нет новых уникальных значений для добавления");
    }
    
    return { status: "success", message: `Обработано ${uniqueValues.length} уникальных значений` };
  } catch (error) {
    Logger.log(`Ошибка: ${error.message}`);
    return { status: "error", message: error.message };
  }
}

/**
 * Функция для создания триггера на изменение Клиенты
 */
function createTriggerOnEdit() {
  const ss = SpreadsheetApp.getActiveSpreadsheet();
  
  // Удаляем существующие триггеры для этой функции, если они есть
  const triggers = ScriptApp.getProjectTriggers();
  for (const trigger of triggers) {
    if (trigger.getHandlerFunction() === "onEditTrigger") {
      ScriptApp.deleteTrigger(trigger);
    }
  }
  
  // Создаем новый триггер
  ScriptApp.newTrigger("onEditTrigger")
    .forSpreadsheet(ss)
    .onEdit()
    .create();
    
  Logger.log("Триггер создан");
}

/**
 * Создает JSON ответ
 */
function createResponse(statusCode, data) {
  const output = ContentService.createTextOutput();
  output.setMimeType(ContentService.MimeType.JSON);
  output.setContent(JSON.stringify(data));
  
  // В Apps Script нельзя установить status code напрямую
  // Он всегда возвращает 200, но статус указывается в теле ответа
  return output;
}

/**
 * Функция для сброса данных на Условия доставки (для тестирования)
 */
function resetSheet2() {
  const ss = SpreadsheetApp.getActiveSpreadsheet();
  const sheet2 = ss.getSheetByName("Условия доставки");
  
  if (sheet2) {
    sheet2.clearContents();
    sheet2.getRange("A1").setValue("Уникальные значения");
    Logger.log("Условия доставки очищен");
  }
}

/**
 * Получение данных пользователя из листа
 * Маппинг русских названий колонок в английские ключи для JSON
 */
function getUserData(ss, sheetName, phone) {
  try {
    const sheet = ss.getSheetByName(sheetName);
    if (!sheet) return { phone: phone };
    
    const data = sheet.getDataRange().getValues();
    if (data.length < 2) return { phone: phone };
    
    const headers = data[0];
    
    // Маппинг для клиентов
    const columnMapping = {
      'Клиент': 'name',
      'ФИРМА': 'company',
      'Телефон': 'phone',
      'Почтовый индекс': 'postalCode',
      'Юридическое лицо': 'isLegalEntity',
      'Город': 'city',
      'Адрес доставки': 'deliveryAddress',
      'Доставка': 'hasDelivery',
      'Комментарий': 'comment',
      'latitude': 'latitude',
      'longitude': 'longitude',
      'Скидка': 'discount',
      'Сумма миним.заказа': 'minOrderAmount',
      'FCM': 'fcmToken'
    };
    
    // Находим индекс колонки с телефоном
    const phoneColIndex = headers.findIndex(h => 
      h && (h.toString().trim() === 'Телефон')
    );
    
    if (phoneColIndex === -1) {
      console.warn(`⚠️ Колонка "Телефон" не найдена в листе "${sheetName}"`);
      return { phone: phone };
    }
    
    const normalizedPhone = phone.toString().trim();
    
    for (let i = 1; i < data.length; i++) {
      const rowPhone = data[i][phoneColIndex];
      if (rowPhone && rowPhone.toString().trim() === normalizedPhone) {
        const userData = { 
          phone: phone // всегда добавляем phone для совместимости
        };
        
        // Проходим по всем колонкам и маппим значения
        for (let j = 0; j < headers.length; j++) {
          const header = headers[j];
          if (header && header.toString().trim() !== '') {
            const headerStr = header.toString().trim();
            const value = data[i][j];
            
            // Определяем ключ для JSON
            let jsonKey = columnMapping[headerStr] || headerStr;
            
            // 🔥 ОБРАБОТКА РАЗНЫХ ТИПОВ ДАННЫХ
            if (value === null || value === undefined) {
              userData[jsonKey] = null;
            } else if (value instanceof Date) {
              userData[jsonKey] = value.toISOString();
            } else if (typeof value === 'boolean') {
              userData[jsonKey] = value;
            } else if (typeof value === 'number') {
              userData[jsonKey] = value;
            } else {
              // Для строк - проверяем на пустоту
              const strValue = value.toString().trim();
              if (strValue === '') {
                userData[jsonKey] = null; // 🔥 Пустые строки превращаем в null
              } else {
                userData[jsonKey] = strValue;
              }
            }
          }
        }
        
        console.log(`✅ Найден клиент: ${userData.name || userData.company || phone}`);
        return userData;
      }
    }
    
    console.warn(`⚠️ Клиент с телефоном ${phone} не найден в листе "${sheetName}"`);
    return { phone: phone };
    
  } catch (error) {
    console.error(`❌ Ошибка получения данных пользователя из ${sheetName}:`, error);
    return { phone: phone };
  }
}

// Вспомогательная функция для обновления FCM токена
function updateUserFcmToken(ss, userType, phone, fcmToken) {
  try {
    const sheetName = userType === 'employee' ? 'Сотрудники' : 'Клиенты';
    const sheet = ss.getSheetByName(sheetName);
    
    if (!sheet) {
      console.warn(`Лист "${sheetName}" не найден при обновлении FCM токена`);
      return;
    }
    
    const data = sheet.getDataRange().getValues();
    if (data.length < 2) {
      console.warn(`Лист "${sheetName}" пуст при обновлении FCM токена`);
      return;
    }
    
    const headers = data[0];
    const phoneColIndex = headers.indexOf('Телефон');
    const fcmColIndex = headers.indexOf('FCM');
    
    if (phoneColIndex === -1) {
      console.warn(`Колонка "Телефон" не найдена в листе "${sheetName}"`);
      return;
    }
    
    if (fcmColIndex === -1) {
      console.warn(`Колонка "FCM" не найдена в листе "${sheetName}"`);
      return;
    }
    
    let found = false;
    for (let i = 1; i < data.length; i++) {
      if (data[i][phoneColIndex] === phone) {
        // Обновляем только если токен изменился
        if (data[i][fcmColIndex] !== fcmToken) {
          sheet.getRange(i + 1, fcmColIndex + 1).setValue(fcmToken);
          console.log(`✅ FCM токен обновлен для ${userType} ${phone}`);
        } else {
          console.log(`ℹ️ FCM токен не изменился для ${userType} ${phone}`);
        }
        found = true;
        break;
      }
    }
    
    if (!found) {
      console.warn(`Телефон ${phone} не найден в листе "${sheetName}" при обновлении FCM`);
    }
    
  } catch (error) {
    console.error('❌ Ошибка обновления FCM токена:', error);
  }
}

/**
 * Вспомогательная функция для получения метаданных
 * Получает метаданные из листа "Метаданные"
 * Поддерживает структуру: Лист | Последнее обновление | Редактор | Способ внесения
 */
function getMetadataFromSheet(ss) {
  const metadata = {};
  
  try {
    const metadataSheet = ss.getSheetByName('Метаданные');
    
    if (!metadataSheet) {
      console.log('📊 Лист "Метаданные" не найден');
      return metadata;
    }
    
    const lastRow = metadataSheet.getLastRow();
    
    if (lastRow < 2) {
      console.log('📊 Лист "Метаданные" пуст');
      return metadata;
    }
    
    // Получаем заголовки для проверки
    const headers = metadataSheet.getRange(1, 1, 1, 3).getValues()[0];
    console.log('📊 Заголовки метаданных:', headers);
    
    // Просто берем все данные, начиная со 2 строки (пропускаем заголовки)
    // Нас интересуют колонки: A (Лист), B (Последнее обновление), C (Редактор)
    const data = metadataSheet.getRange(2, 1, lastRow - 1, 3).getValues();
    
    console.log(`📊 Найдено строк в метаданных: ${data.length}`);
    
    for (let i = 0; i < data.length; i++) {
      const sheetName = data[i][0];  // Колонка A
      const lastUpdate = data[i][1];  // Колонка B
      const editor = data[i][2] || ''; // Колонка C
      
      // Пропускаем строки с заголовками или пустые
      if (!sheetName || sheetName === 'Лист' || !lastUpdate || lastUpdate === 'Последнее обновление') {
        continue;
      }
      
      if (sheetName && lastUpdate) {
        // Преобразуем дату в строку ISO
        let dateStr;
        if (lastUpdate instanceof Date) {
          dateStr = lastUpdate.toISOString();
        } else if (typeof lastUpdate === 'string') {
          // Проверяем, что строка действительно содержит дату
          try {
            new Date(lastUpdate).toISOString();
            dateStr = lastUpdate;
          } catch (e) {
            console.warn(`⚠️ Неверный формат даты для листа "${sheetName}": ${lastUpdate}`);
            // Если не получается, используем текущую дату
            dateStr = new Date().toISOString();
          }
        } else {
          dateStr = new Date().toISOString();
        }
        
        metadata[sheetName] = {
          lastUpdate: dateStr,
          editor: editor
        };
        
        console.log(`📋 Метаданные для "${sheetName}": обновлено ${dateStr.substring(0, 10)}`);
      }
    }
    
    console.log(`📊 Загружено метаданных: ${Object.keys(metadata).length}`);
    
  } catch (error) {
    console.error('❌ Ошибка в getMetadataFromSheet:', error);
  }
  
  return metadata;
}

// authenticate - Вспомогательная функция проверки телефона в листе
function isPhoneInSheet(ss, sheetName, phone) {
  try {
    const sheet = ss.getSheetByName(sheetName);
    if (!sheet) return false;
    
    const data = sheet.getDataRange().getValues();
    if (data.length < 2) return false;
    
    const headers = data[0];
    const phoneColIndex = headers.findIndex(h => 
      h && (h.toString().toLowerCase().includes('телефон') || 
            h.toString().toLowerCase().includes('phone'))
    );
    
    if (phoneColIndex === -1) return false;
    
    const normalizedPhone = phone.toString().trim();
    
    for (let i = 1; i < data.length; i++) {
      const cellValue = data[i][phoneColIndex];
      if (cellValue && cellValue.toString().trim() === normalizedPhone) {
        return true;
      }
    }
    return false;
  } catch (error) {
    console.error(`Ошибка проверки телефона в ${sheetName}:`, error);
    return false;
  }
}

// authenticate Вспомогательная функция загрузки данных
function getClientData(ss, sheetsToLoad, hasEmployeeAccess, phone) {
  const data = {};
  
  for (const sheetName of sheetsToLoad) {
    const sheet = ss.getSheetByName(sheetName);
    if (!sheet) {
      console.warn(`Лист "${sheetName}" не найден`);
      continue;
    }
    
    const values = sheet.getDataRange().getValues();
    if (values.length === 0) {
      console.warn(`Лист "${sheetName}" пуст`);
      continue;
    }
    
    const headers = values[0];
    const rows = [];
    
    // 🔥 ДЛЯ СОТРУДНИКОВ - загружаем ВСЕ данные без фильтрации
    if (hasEmployeeAccess) {
      console.log(`👤 Сотрудник: загружаем весь лист "${sheetName}"`);
      for (let i = 1; i < values.length; i++) {
        const row = {};
        for (let j = 0; j < headers.length; j++) {
          row[headers[j]] = values[i][j];
        }
        rows.push(row);
      }
      
    // 🔥 ДЛЯ КЛИЕНТОВ - фильтруем ТОЛЬКО ИХ данные
    } else {
      // Фильтрация листа "Клиенты" - ТОЛЬКО записи с телефоном клиента
      if (sheetName === 'Клиенты') {
        const phoneColIndex = headers.indexOf('Телефон');
        
        if (phoneColIndex === -1) {
          console.error(`❌ КРИТИЧЕСКАЯ ОШИБКА: Колонка "Телефон" не найдена в листе "Клиенты"!`);
          throw new Error('Отсутствует обязательная колонка "Телефон" в листе "Клиенты"');
        }
        
        const normalizedPhone = phone.toString().trim();
        console.log(`📞 Фильтрация клиентов по телефону: "${normalizedPhone}"`);
        
        for (let i = 1; i < values.length; i++) {
          const clientPhone = values[i][phoneColIndex]?.toString().trim();
          
          // ✅ ВАЖНО: добавляем только записи с телефоном текущего клиента
          if (clientPhone === normalizedPhone) {
            const row = {};
            for (let j = 0; j < headers.length; j++) {
              row[headers[j]] = values[i][j];
            }
            rows.push(row);
            console.log(`✅ Добавлен клиент: ${row['Клиент'] || 'без имени'} (телефон: ${clientPhone})`);
          } else {
            console.log(`⏭️ Пропущен клиент с телефоном: ${clientPhone}`);
          }
        }
        
        console.log(`📦 Загружено ${rows.length} записей клиента для телефона ${phone}`);
      
      // Фильтрация листа "Заказы" - ТОЛЬКО заказы с телефоном клиента
      } else if (sheetName === 'Заказы') {
        const phoneColIndex = headers.indexOf('Телефон');
        
        if (phoneColIndex === -1) {
          console.error(`❌ КРИТИЧЕСКАЯ ОШИБКА: Колонка "Телефон" не найдена в листе "Заказы"!`);
          throw new Error('Отсутствует обязательная колонка "Телефон" в листе "Заказы"');
        }
        
        const normalizedPhone = phone.toString().trim();
        console.log(`📞 Фильтрация заказов по телефону: "${normalizedPhone}"`);
        
        for (let i = 1; i < values.length; i++) {
          const orderPhone = values[i][phoneColIndex]?.toString().trim();
          
          // ✅ ВАЖНО: добавляем только заказы с телефоном текущего клиента
          if (orderPhone === normalizedPhone) {
            const row = {};
            for (let j = 0; j < headers.length; j++) {
              row[headers[j]] = values[i][j];
            }
            rows.push(row);
          }
        }
        
        console.log(`📦 Загружено ${rows.length} заказов для телефона ${phone}`);
        
      } else {
        // Для остальных листов (Прайс-лист, Состав и т.д.) - загружаем всё
        console.log(`📋 Клиент: загружаем весь лист "${sheetName}"`);
        for (let i = 1; i < values.length; i++) {
          const row = {};
          for (let j = 0; j < headers.length; j++) {
            row[headers[j]] = values[i][j];
          }
          rows.push(row);
        }
      }
    }
    
    // Преобразуем имя листа в ключ
    const key = sheetNameToKey(sheetName);
    data[key] = rows;
  }
  
  return data;
}

// authenticate - Вспомогательная функция преобразования имени листа
function sheetNameToKey(sheetName) {
  const mapping = {
    'Состав': 'compositions',  // обратите внимание: compositions (множественное число)
    'Категории прайса': 'priceCategories', 
    'Начинки': 'fillings',
    'Условия хранения': 'storageConditions',
    'КБЖУ': 'nutritionInfos',  // соответствует названию в ClientData
    'Категории клиентов': 'clientCategories',
    'Условия доставки': 'deliveryConditions', 
    'Поставщики': 'suppliers',
    'Клиенты': 'clients',
    'Сотрудники': 'employees',
    'Заказы': 'orders',
    'Прайс-лист': 'products',  // ← ЭТО КЛЮЧЕВОЕ ОТСУТСТВУЕТ!
    'Операции склада': 'warehouseOperations'
  };
  return mapping[sheetName] || sheetName.toLowerCase().replace(/\s+/g, '');
}

/**
 * Универсальная функция генерации ID для любых листов
 * @param {Sheet} sheet - лист Google Sheets
 * @param {string} idColumnName - имя колонки для ID (по умолчанию "ID")
 */
function handleIdGeneration(sheet, idColumnName = "ID") {
  const lastRow = sheet.getLastRow();
  if (lastRow <= 1) return;
  
  // Находим колонку ID
  const idColumn = findColumnByHeader(sheet, idColumnName);
  if (idColumn === null) return;
  
  // Обрабатываем все строки с данными
  for (let row = 2; row <= lastRow; row++) {
    const idCell = sheet.getRange(row, idColumn);
    if (idCell.getValue() !== "") continue; // ID уже есть
    
    // Проверяем, есть ли данные в других колонках
    const filledCount = countNonEmptyCellsExceptColumn(sheet, row, idColumn);
    if (filledCount > 0) {
      const newId = generateNextId(sheet, idColumn, lastRow);
      idCell.setValue(newId);
    }
  }
}

// Получает все имена листов из метаданных
function getAllSheetNames(ss) {
  const metadata = getMetadataFromSheet(ss);
  return Object.keys(metadata);
}

// Вспомогательная функция для успешных ответов
function createSuccessResponse(data) {
  return createCorsResponse({
    status: 'success',
    ...data
  });
}

// Вспомогательная функция для ответов с ошибкой
function createErrorResponse(message) {
  return createCorsResponse({
    status: 'error',
    message: message
  });
}

/**
 * Обработка OPTIONS запросов (CORS preflight)
 */
function doOptions(e) {
  console.log('🔄 OPTIONS запрос получен (CORS preflight)');
  
  // Создаем ответ и добавляем заголовки через setContent
  const output = ContentService.createTextOutput('');
  output.setMimeType(ContentService.MimeType.TEXT);
  
  // Apps Script автоматически добавляет заголовки при развертывании
  // как веб-приложение. Просто возвращаем пустой ответ.
  return output;
}

/**
 * Вспомогательная функция для создания ответов
 * Google Apps Script сам добавит нужные заголовки
 */
function createCorsResponse(body) {
  return ContentService
    .createTextOutput(JSON.stringify(body))
    .setMimeType(ContentService.MimeType.JSON);
}

// Упрощенный doGet (исправлено: // вместо /)
function doGet(e) {
  console.log('📡 GET запрос получен');
  
  if (e && e.parameter && e.parameter.action === 'test') {
    return createCorsResponse({
      status: 'success',
      message: 'Apps Script сервер работает (GET)',
      timestamp: new Date().toISOString(),
      method: 'GET'
    });
  }
  
  return createCorsResponse({
    message: 'Используйте POST запрос для работы с API',
    endpoints: {
      test: 'GET/POST /?action=test',
      authenticate: 'POST / с JSON {"action":"authenticate","phone":"...","secret":"..."}'
    }
  });
}

// CORS в ответы добавлен
function doPost(e) {
  console.log('🚀 Вход в doPost');
  console.log('📦 e:', JSON.stringify(e));
  
  try {
    // === ШАГ 1: ПАРСИНГ JSON ===
    if (!e || !e.postData || !e.postData.contents) {
      console.log('❌ Нет данных в запросе');
      return createCorsResponse({
        status: 'error',
        message: 'Нет данных в запросе'
      });
    }
    
    console.log('📦 postData.contents:', e.postData.contents);
    
    let body;
    try {
      body = JSON.parse(e.postData.contents);
      console.log('✅ JSON распарсен');
      console.log('📦 body.action:', body.action);
      console.log('📦 body.phone:', body.phone);
      console.log('📦 body.secret:', body.secret ? 'есть' : 'нет');
    } catch (parseError) {
      console.log('❌ Ошибка парсинга JSON:', parseError);
      return createCorsResponse({
        status: 'error',
        message: 'Ошибка парсинга JSON: ' + parseError.message
      });
    }

    // === ШАГ 2: ВАЛИДАЦИЯ СЕКРЕТА ===
    if (!body.secret) {
      console.log('❌ Нет секретного ключа');
      return createCorsResponse({
        status: 'error',
        message: 'Требуется секретный ключ'
      });
    }
    
    console.log('🔑 Получение списка валидных секретов...');
    const validSecrets = getValidSecrets();
    console.log('🔑 validSecrets:', validSecrets);
    
    if (!validSecrets.includes(body.secret)) {
      console.log('❌ Неверный секретный ключ');
      return createCorsResponse({
        status: 'error',
        message: 'Неверный секретный ключ'
      });
    }
    
    console.log('✅ Секретный ключ верный');

    // === ШАГ 3: ОБРАБОТКА ДЕЙСТВИЙ ===
    let result;
    switch (body.action) {
      case 'test':
        console.log('🧪 Тестовый запрос');
        result = {
          status: 'success',
          message: 'Apps Script сервер работает',
          timestamp: new Date().toISOString()
        };
        break;

      case 'authenticate':
        console.log('🔐 Обработка аутентификации');
        
        if (!body.phone) {
          console.log('❌ Нет телефона');
          return createCorsResponse({
            status: 'error',
            message: 'Для аутентификации требуется поле "phone"'
          });
        }
        
        console.log('📞 Телефон:', body.phone);
        result = handleAuthentication(
          body.phone, 
          body.localMetadata || {}, 
          body.fcmToken
        );
        break;
        
      case 'fetchMetadata':
        result = handleFetchMetadata();
        break;
        
      case 'fetchClientData':
        result = handleFetchClientData(body.phone);
        break;
        
      case 'fetchProducts':
        result = handleFetchProducts(body.phone);
        break;

      case 'createOrder':
        result = handleCreateOrder(body.phone, body.data);
        break;

      case 'fetchOrders':
        result = handleFetchOrders(body.phone);
        break;

      case 'updateOrderStatus':
        result = handleUpdateOrderStatus(body.phone, body.orderData, body.newStatus);
        break;
        
      case 'deleteOrder':
        result = handleDeleteOrder(body.phone, body.data);
        break;

      case 'updateOrderStatuses':
        result = handleUpdateOrderStatuses(body.phone, body.updates);
        break;

      case 'importData':
        result = handleImportData(body.phone, body.updates);
        break;

      case 'sendNotification':
        result = handleSendNotification(body.phone, body.targetPhones);
        break;

      case 'updateMetadata':
        result = handleUpdateMetadata(body.phone, body.metadataUpdates);
        break;

      case 'addWarehouseOperation':
        result = handleAddWarehouseOperation(body.phone, body.operationData);
        break;

      default:
        console.log('❌ Неизвестное действие:', body.action);
        return createCorsResponse({
          status: 'error',
          message: `Неизвестное действие: ${body.action}`
        });
    }
    
    // Возвращаем результат с CORS заголовками
    return createCorsResponse(result);
    
  } catch (error) {
    console.error('💥 Критическая ошибка в doPost:', error);
    console.error('📚 Stack:', error.stack);
    return createCorsResponse({
      status: 'error',
      message: 'Внутренняя ошибка сервера: ' + error.message
    });
  }
}

/**
 * Функция-триггер, которая запускается при изменении таблицы
 */
function onEditTrigger(e) {
  const range = e.range;
  const sheet = range.getSheet();
  
  // Проверяем, что изменение произошло в Клиенты и в колонке 6
  if (sheet.getName() === "Клиенты" && range.getColumn() === 6) {
    // Небольшая задержка, чтобы убедиться, что все изменения сохранены
    Utilities.sleep(500);
    
    // Запускаем перенос уникальных значений
    transferUniqueValues();
  }
}

/**
 * Функция для создания меню в таблице
 */
function onOpen() {
  const ui = SpreadsheetApp.getUi();
  const menu = ui.createMenu("Действия");
  
  menu.addItem("Обновить уникальные значения", "transferUniqueValues");
  menu.addItem("Включить автообновление", "createTriggerOnEdit");
  menu.addToUi();
}

/**
 * Обработчик аутентификации
 * Предполагается, что телефон уже проверен в doPost
 */
function handleAuthentication(phone, localMetadata, fcmToken) {
  try {
    console.log(`🔐 Начало аутентификации для: ${phone}`);
    const ss = SpreadsheetApp.getActiveSpreadsheet();
    
    // === ШАГ 1: ПОИСК ПОЛЬЗОВАТЕЛЯ ===
    const isEmployee = isPhoneInSheet(ss, 'Сотрудники', phone);
    const isClient = !isEmployee ? isPhoneInSheet(ss, 'Клиенты', phone) : false;
    
    if (!isEmployee && !isClient) {
      console.log(`❌ Пользователь с телефоном ${phone} не найден`);
      return createErrorResponse('Пользователь не найден. Проверьте правильность введенного номера телефона.');
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
    
    // === ШАГ 3: ОБРАБОТКА FCM ТОКЕНА ===
    if (fcmToken && fcmToken.trim() !== '') {
      updateUserFcmToken(ss, isEmployee ? 'employee' : 'client', phone, fcmToken.trim());
    }
    
    // === ШАГ 4: ПОЛУЧЕНИЕ МЕТАДАННЫХ ===
    // Используем улучшенную функцию, которая создаст метаданные при необходимости
    const currentMetadata = getMetadataFromSheet(ss);
    
    // === ШАГ 5: ПОЛУЧЕНИЕ ВСЕХ ЛИСТОВ ИЗ МЕТАДАННЫХ ===
    const allSheetNames = Object.keys(currentMetadata);
    console.log('📋 Все листы по метаданным:', allSheetNames);
    
    // === ШАГ 6: ОПРЕДЕЛЕНИЕ ЛИСТОВ ДЛЯ ЗАГРУЗКИ ===
    const sheetsToLoad = [];
    let hasUpdates = false;
    
    if (!localMetadata || Object.keys(localMetadata).length === 0) {
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
          sheetsToLoad.push(sheetName);
          hasUpdates = true;
        }
      }
    }
    
    // === ШАГ 7: ФИЛЬТРАЦИЯ ЛИСТОВ ПО ТИПУ ПОЛЬЗОВАТЕЛЯ ===
    if (!isEmployee) {
      // Клиентам не нужны служебные листы
      const excludedSheets = ['Сотрудники', 'Поставщики', 'Складские операции', 'Метаданные'];
      const filteredSheets = sheetsToLoad.filter(sheet => !excludedSheets.includes(sheet));
      sheetsToLoad.length = 0;
      sheetsToLoad.push(...filteredSheets);
      console.log('📋 Для клиента загружаются листы:', sheetsToLoad);
    } else {
      console.log('📋 Для сотрудника загружаются все листы:', sheetsToLoad);
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
    } else {
      console.log('📦 Данные актуальны, обновления не требуются');
      responseData.data = {};
    }
    
    console.log(`✅ Аутентификация успешна для: ${phone} (${isEmployee ? 'сотрудник' : 'клиент'})`);
    return createSuccessResponse(responseData);
    
  } catch (error) {
    console.error('❌ Ошибка авторизации:', error);
    
    if (error.message.includes('Колонка "Телефон" не найдена')) {
      return createErrorResponse('Ошибка структуры данных: отсутствует колонка "Телефон" в листе "Заказы"');
    }
    
    return createErrorResponse('Ошибка при авторизации: ' + error.message);
  }
}

/**
 * Обработчик для действия 'fetchMetadata'
 * Возвращает все метаданные из листа "Метаданные"
 */
function handleFetchMetadata() {
  try {
    console.log('📊 Запрос метаданных');
    const ss = SpreadsheetApp.getActiveSpreadsheet();
    const metadata = getMetadataFromSheet(ss);
    
    console.log(`✅ Возвращаем метаданных: ${Object.keys(metadata).length}`);
    
    // Просто возвращаем объект метаданных
    return createSuccessResponse(metadata);
    
  } catch (error) {
    console.error('❌ Ошибка в handleFetchMetadata:', error);
    return createErrorResponse('Внутренняя ошибка при получении метаданных');
  }
}

/**
 * Обработчик для действия 'fetchClientData'
 * Возвращает полные данные клиента с учетом прав доступа
 */
function handleFetchClientData(phone) {
  try {
    const ss = SpreadsheetApp.getActiveSpreadsheet();
    const hasEmployeeAccess = isPhoneInSheet(ss, 'Сотрудники', phone);
    
    // Получаем все имена листов из метаданных
    const metadata = getMetadataFromSheet(ss);
    const allSheetNames = Object.keys(metadata);
    
    // Загружаем данные
    const clientData = getClientData(ss, allSheetNames, hasEmployeeAccess, phone);
    
    return createSuccessResponse(clientData);
    
  } catch (error) {
    console.error('Ошибка fetchClientData:', error);
    return createResponse(500, {
      status: 'error',
      message: 'Ошибка получения данных клиента'
    });
  }
}

/**
 * Обработчик для действия 'fetchProducts'
 * ВСЕГДА возвращает полный прайс-лист (фильтрация выполняется на стороне клиента)
 */
function handleFetchProducts(phone) {
  try {
    const ss = SpreadsheetApp.getActiveSpreadsheet();
    
    // Загружаем прайс-лист
    const productsSheet = ss.getSheetByName('Прайс-лист');
    if (!productsSheet) {
      return createResponse(404, {
        status: 'error',
        message: 'Лист "Прайс-лист" не найден'
      });
    }
    
    const values = productsSheet.getDataRange().getValues();
    if (values.length === 0) {
      return createSuccessResponse([]);
    }
    
    const headers = values[0];
    const products = [];
    
    // Преобразуем все строки в объекты
    for (let i = 1; i < values.length; i++) {
      const product = {};
      for (let j = 0; j < headers.length; j++) {
        product[headers[j]] = values[i][j];
      }
      products.push(product);
    }
    
    // ВСЕГДА возвращаем полный прайс-лист
    // Фильтрация по категориям выполняется на стороне Flutter-приложения
    return createSuccessResponse(products);
    
  } catch (error) {
    console.error('Ошибка fetchProducts:', error);
    return createResponse(500, {
      status: 'error',
      message: 'Ошибка получения прайс-листа'
    });
  }
}

/**
 * Обработчик для действия 'createOrder'
 * Создает новый заказ в листе "Заказы"
 */
function handleCreateOrder(phone, orderData) {
  try {
    const ss = SpreadsheetApp.getActiveSpreadsheet();
    const ordersSheet = ss.getSheetByName('Заказы');
    
    if (!ordersSheet) {
      return createResponse(404, {
        status: 'error',
        message: 'Лист "Заказы" не найден'
      });
    }
    
    const lastColumn = ordersSheet.getLastColumn();
    const headers = ordersSheet.getRange(1, 1, 1, lastColumn).getValues()[0];
    
    const rowData = [];
    for (let i = 0; i < headers.length; i++) {
      const header = headers[i];
      if (header && header.toString().trim() !== '') {
        const headerKey = header.toString().trim();
        
        if (orderData.hasOwnProperty(headerKey)) {
          let value = orderData[headerKey];
          
          // Специальная обработка для поля "Дата"
          if (headerKey === 'Дата' || headerKey === 'Date') {
            // Преобразуем ISO дату в DD.MM.YYYY
            value = formatDateToDDMMYYYY(value);
          }
          
          rowData.push(value);
        } else {
          rowData.push('');
        }
      } else {
        rowData.push('');
      }
    }
    
    ordersSheet.appendRow(rowData);
    
    updateMetadata_('Заказы', new Date().toISOString(), 
      phone || 'Мобильное приложение', 'API');
    
    return createSuccessResponse({
      message: 'Заказ успешно создан'
    });
    
  } catch (error) {
    console.error('Ошибка createOrder:', error);
    return createResponse(500, {
      status: 'error',
      message: 'Ошибка создания заказа'
    });
  }
}

/**
 * Обработчик для действия 'fetchOrders'
 * Возвращает заказы с учетом прав доступа пользователя
 */
function handleFetchOrders(phone) {
  try {
    const ss = SpreadsheetApp.getActiveSpreadsheet();
    const ordersSheet = ss.getSheetByName('Заказы');
    
    if (!ordersSheet) {
      return createResponse(404, {
        status: 'error',
        message: 'Лист "Заказы" не найден'
      });
    }
    
    const values = ordersSheet.getDataRange().getValues();
    if (values.length === 0) {
      return createSuccessResponse([]);
    }
    
    const headers = values[0];
    const orders = [];
    
    // Определяем тип пользователя
    const hasEmployeeAccess = isPhoneInSheet(ss, 'Сотрудники', phone);
    
    // Проходим по всем строкам (начиная с 1, пропуская заголовки)
    for (let i = 1; i < values.length; i++) {
      const row = values[i];
      
      // Для клиентов фильтруем только свои заказы
      if (!hasEmployeeAccess) {
        const phoneColIndex = headers.indexOf('Телефон');
        if (phoneColIndex !== -1 && row[phoneColIndex] !== phone) {
          continue; // Пропускаем чужие заказы
        }
      }
      
      // Преобразуем строку в объект
      const order = {};
      for (let j = 0; j < headers.length; j++) {
        order[headers[j]] = row[j];
      }
      orders.push(order);
    }
    
    return createSuccessResponse(orders);
    
  } catch (error) {
    console.error('Ошибка fetchOrders:', error);
    return createResponse(500, {
      status: 'error',
      message: 'Ошибка получения заказов'
    });
  }
}

/**
 * Обработчик для действия 'updateOrderStatus'
 * Обновляет статус одного заказа
 */
function handleUpdateOrderStatus(phone, orderData, newStatus) {
  try {
    const ss = SpreadsheetApp.getActiveSpreadsheet();
    const ordersSheet = ss.getSheetByName('Заказы');
    
    if (!ordersSheet) {
      return createResponse(404, {
        status: 'error',
        message: 'Лист "Заказы" не найден'
      });
    }
    
    const values = ordersSheet.getDataRange().getValues();
    if (values.length < 2) {
      return createResponse(404, {
        status: 'error',
        message: 'Заказы не найдены'
      });
    }
    
    const headers = values[0];
    const statusColIndex = headers.indexOf('Статус');
    const phoneColIndex = headers.indexOf('Телефон');
    const clientColIndex = headers.indexOf('Клиент');
    const productColIndex = headers.indexOf('Название');
    const dateColIndex = headers.indexOf('Дата');
    const priceListIdColIndex = headers.indexOf('ID Прайс-лист');
    
    // Проверяем наличие необходимых колонок
    if (statusColIndex === -1 || phoneColIndex === -1 || clientColIndex === -1) {
      return createResponse(500, {
        status: 'error',
        message: 'Неверная структура листа "Заказы": отсутствуют необходимые колонки'
      });
    }
    
    // Определяем тип пользователя (сотрудник или клиент)
    const isEmployee = isPhoneInSheet(ss, 'Сотрудники', phone);
    
    let ordersUpdated = 0;
    let targetRows = [];
    
    // 🔥 ПОИСК ПО КОМБИНАЦИИ ПОЛЕЙ
    for (let i = 1; i < values.length; i++) {
      let match = true;
      
      // Проверяем телефон (обязательно)
      if (values[i][phoneColIndex] !== phone) {
        match = false;
      }
      
      // Если передан clientName, проверяем его
      if (match && orderData.clientName && values[i][clientColIndex] !== orderData.clientName) {
        match = false;
      }
      
      // Если передан productName, проверяем его
      if (match && orderData.productName && values[i][productColIndex] !== orderData.productName) {
        match = false;
      }
      
      // Если передана date, проверяем её
      if (match && orderData.date && values[i][dateColIndex] !== orderData.date) {
        match = false;
      }
      
      // Если передан priceListId, проверяем его
      if (match && orderData.priceListId && values[i][priceListIdColIndex]?.toString() !== orderData.priceListId) {
        match = false;
      }
      
      if (match) {
        // Проверяем права доступа для клиентов
        if (!isEmployee) {
          // Клиент может обновлять только свои заказы (телефон уже совпадает)
          // Дополнительно можно проверить статус (например, только 'оформлен')
          const currentStatus = values[i][statusColIndex];
          if (currentStatus !== 'оформлен') {
            console.log(`⚠️ Клиент ${phone} пытается обновить заказ со статусом ${currentStatus}`);
            continue; // Пропускаем, не обновляем
          }
        }
        
        targetRows.push({
          row: i + 1, // +1 для Sheets API
          currentStatus: values[i][statusColIndex]
        });
      }
    }
    
    if (targetRows.length === 0) {
      return createResponse(404, {
        status: 'error',
        message: 'Заказы не найдены по указанным критериям'
      });
    }
    
    // Обновляем найденные заказы
    for (let target of targetRows) {
      ordersSheet.getRange(target.row, statusColIndex + 1).setValue(newStatus);
      ordersUpdated++;
      console.log(`📝 Заказ в строке ${target.row}: статус ${target.currentStatus} → ${newStatus}`);
    }
    
    // Обновляем метаданные
    updateMetadata_('Заказы', new Date().toISOString(), 
      phone || 'Мобильное приложение', 'API');
    
    console.log(`✅ Обновлено заказов: ${ordersUpdated} для клиента ${phone}`);
    
    return createSuccessResponse({
      message: `Статус заказов успешно обновлен`,
      updatedCount: ordersUpdated,
      newStatus: newStatus
    });
    
  } catch (error) {
    console.error('Ошибка updateOrderStatus:', error);
    return createResponse(500, {
      status: 'error',
      message: 'Ошибка обновления статуса заказа: ' + error.message
    });
  }
}

/**
 * Обработчик для действия 'updateOrderStatuses'
 * Массово обновляет статусы заказов с указанием oldStatus
 * Каждое обновление: {client, phone, oldStatus, newStatus}
 * Находит строки: client + phone + status=oldStatus
 * Заменяет status на newStatus
 */
function handleUpdateOrderStatuses(phone, updates) {
  try {
    const ss = SpreadsheetApp.getActiveSpreadsheet();
    const ordersSheet = ss.getSheetByName('Заказы');
    
    if (!ordersSheet) {
      return createResponse(404, {
        status: 'error',
        message: 'Лист "Заказы" не найден'
      });
    }
    
    const values = ordersSheet.getDataRange().getValues();
    if (values.length < 2) {
      return createResponse(404, {
        status: 'error',
        message: 'Заказы не найдены'
      });
    }
    
    const headers = values[0];
    const statusColIndex = headers.indexOf('Статус');
    const phoneColIndex = headers.indexOf('Телефон');
    const clientColIndex = headers.indexOf('Клиент');
    
    if (statusColIndex === -1 || phoneColIndex === -1 || clientColIndex === -1) {
      return createResponse(500, {
        status: 'error',
        message: 'Неверная структура листа "Заказы": отсутствуют обязательные колонки'
      });
    }
    
    let anyUpdates = false;
    let totalUpdated = 0;
    
    // Обрабатываем каждый элемент из массива updates
    for (const update of updates) {
      const clientName = update.client;
      const clientPhone = update.phone;
      const oldStatus = update.oldStatus;
      const newStatus = update.newStatus;
      
      // Проверяем обязательные поля
      if (!clientName || !clientPhone || oldStatus === undefined || newStatus === undefined) {
        console.warn(`Пропущено обновление: отсутствуют данные ${JSON.stringify(update)}`);
        continue;
      }
      
      // Ищем и обновляем ВСЕ соответствующие строки
      let updatedCount = 0;
      
      for (let i = 1; i < values.length; i++) {
        const row = values[i];
        const rowClient = row[clientColIndex];
        const rowPhone = row[phoneColIndex];
        const rowStatus = row[statusColIndex];
        
        // Проверяем совпадение по всем четырем полям
        if (rowClient === clientName && 
            rowPhone === clientPhone && 
            rowStatus === oldStatus) {
          
          // Обновляем статус на новый
          const targetRow = i + 1;
          ordersSheet.getRange(targetRow, statusColIndex + 1).setValue(newStatus);
          updatedCount++;
          anyUpdates = true;
        }
      }
      
      if (updatedCount > 0) {
        totalUpdated += updatedCount;
        console.log(`✅ Обновлено ${updatedCount} позиций: ${clientName} (${clientPhone}) "${oldStatus}" -> "${newStatus}"`);
      }
    }
    
    // Обновляем метаданные если были изменения
    if (anyUpdates) {
      updateMetadata_('Заказы', new Date().toISOString(), 
        phone || 'Мобильное приложение', 'API');
    }
    
    return createSuccessResponse({
      message: `Успешно обновлено ${totalUpdated} позиций заказа`,
      updatedCount: totalUpdated
    });
    
  } catch (error) {
    console.error('Ошибка updateOrderStatuses:', error);
    return createResponse(500, {
      status: 'error',
      message: 'Ошибка массового обновления статусов'
    });
  }
}

/**
 * Обработчик для действия 'importData'
 * Импортирует данные из платежной системы:
 * - Платежные документы (Этап 1)
 * - Информация об оплате (Этап 2)
 * 
 * Каждая запись содержит составной ключ для поиска заказа:
 * Статус="доставлен" + Название + Количество + Итоговая цена + Дата + Телефон + Клиент
 */
function handleImportData(phone, updates) {
  try {
    const ss = SpreadsheetApp.getActiveSpreadsheet();
    
    // Проверяем, что пользователь - сотрудник
    const isEmployee = isPhoneInSheet(ss, 'Сотрудники', phone);
    if (!isEmployee) {
      return createResponse(403, {
        status: 'error',
        message: 'Импорт данных доступен только сотрудникам'
      });
    }
    
    const ordersSheet = ss.getSheetByName('Заказы');
    if (!ordersSheet) {
      return createResponse(404, {
        status: 'error',
        message: 'Лист "Заказы" не найден'
      });
    }
    
    const values = ordersSheet.getDataRange().getValues();
    if (values.length < 2) {
      return createResponse(404, {
        status: 'error',
        message: 'Заказы не найдены'
      });
    }
    
    const headers = values[0];
    const statusColIndex = headers.indexOf('Статус');
    const nameColIndex = headers.indexOf('Название');
    const quantityColIndex = headers.indexOf('Количество');
    const totalPriceColIndex = headers.indexOf('Итоговая цена');
    const dateColIndex = headers.indexOf('Дата');
    const phoneColIndex = headers.indexOf('Телефон');
    const clientColIndex = headers.indexOf('Клиент');
    const paymentDocColIndex = headers.indexOf('Платежный документ');
    const paymentAmountColIndex = headers.indexOf('Оплата');
    
    // Проверяем обязательные колонки для поиска
    const requiredCols = [
      {name: 'Статус', index: statusColIndex},
      {name: 'Название', index: nameColIndex},
      {name: 'Количество', index: quantityColIndex},
      {name: 'Итоговая цена', index: totalPriceColIndex},
      {name: 'Дата', index: dateColIndex},
      {name: 'Телефон', index: phoneColIndex},
      {name: 'Клиент', index: clientColIndex}
    ];
    
    for (const col of requiredCols) {
      if (col.index === -1) {
        return createResponse(500, {
          status: 'error',
          message: `Неверная структура листа "Заказы": отсутствует колонка "${col.name}"`
        });
      }
    }
    
    let anyUpdates = false;
    let totalUpdated = 0;
    let notFoundCount = 0;
    
    // Обрабатываем каждый элемент из массива updates
    for (const update of updates) {
      const {
        client,
        phone: clientPhone,
        productName,
        quantity,
        totalPrice,
        orderDate,
        paymentDocument,
        paymentAmount
      } = update;
      
      // Проверяем обязательные поля для поиска
      if (!client || !clientPhone || !productName || 
          quantity === undefined || totalPrice === undefined || !orderDate) {
        console.warn(`Пропущено обновление: отсутствуют обязательные поля ${JSON.stringify(update)}`);
        continue;
      }
      
      // Ищем заказ по полному составному ключу
      let targetRow = -1;
      
      for (let i = 1; i < values.length; i++) {
        const row = values[i];
        
        const matches = 
          row[statusColIndex] === 'доставлен' &&
          row[nameColIndex] === productName &&
          String(row[quantityColIndex]) === String(quantity) &&
          String(row[totalPriceColIndex]) === String(totalPrice) &&
          row[dateColIndex] === orderDate &&
          row[phoneColIndex] === clientPhone &&
          row[clientColIndex] === client;
        
        if (matches) {
          targetRow = i + 1; // +1 для Google Sheets
          break;
        }
      }
      
      if (targetRow === -1) {
        notFoundCount++;
        console.warn(`Не найден заказ для импорта: ${client} (${clientPhone}) - ${productName}`);
        continue;
      }
      
      let updatedFields = [];
      
      // Обновляем "Платежный документ" если есть
      if (paymentDocument !== undefined && paymentDocColIndex !== -1) {
        ordersSheet.getRange(targetRow, paymentDocColIndex + 1).setValue(paymentDocument);
        updatedFields.push('Платежный документ');
      }
      
      // Обновляем "Оплата" если есть
      if (paymentAmount !== undefined && paymentAmountColIndex !== -1) {
        ordersSheet.getRange(targetRow, paymentAmountColIndex + 1).setValue(paymentAmount);
        updatedFields.push('Оплата');
      }
      
      if (updatedFields.length > 0) {
        totalUpdated++;
        anyUpdates = true;
        console.log(`✅ Обновлены поля [${updatedFields.join(', ')}] для заказа: ${client} - ${productName}`);
      }
    }
    
    // Обновляем метаданные если были изменения
    if (anyUpdates) {
      updateMetadata_('Заказы', new Date().toISOString(), 
        phone || 'Мобильное приложение', 'API');
    }
    
    const resultMessage = `Импорт завершен: обновлено ${totalUpdated} позиций`;
    if (notFoundCount > 0) {
      console.warn(`⚠️ Не найдено ${notFoundCount} заказов для импорта`);
    }
    
    return createSuccessResponse({
      message: resultMessage,
      updatedCount: totalUpdated,
      notFoundCount: notFoundCount
    });
    
  } catch (error) {
    console.error('Ошибка importData:', error);
    return createResponse(500, {
      status: 'error',
      message: 'Ошибка импорта данных из платежной системы'
    });
  }
}

/**
 * Обработчик для действия 'sendNotification'
 * Возвращает FCM токены для указанных телефонов
 * Фактическая отправка уведомлений выполняется во Flutter
 */
function handleSendNotification(phone, targetPhones) {
  try {
    const ss = SpreadsheetApp.getActiveSpreadsheet();
    
    // Проверяем, что пользователь - сотрудник (только сотрудники могут отправлять уведомления)
    const isEmployee = isPhoneInSheet(ss, 'Сотрудники', phone);
    if (!isEmployee) {
      return createResponse(403, {
        status: 'error',
        message: 'Отправка уведомлений доступна только сотрудникам'
      });
    }
    
    const tokens = [];
    const notFound = [];
    
    // Ищем FCM токены в обоих листах
    const sheetsToCheck = ['Сотрудники', 'Клиенты'];
    
    for (const targetPhone of targetPhones) {
      let foundToken = false;
      
      for (const sheetName of sheetsToCheck) {
        const sheet = ss.getSheetByName(sheetName);
        if (!sheet) continue;
        
        const data = sheet.getDataRange().getValues();
        if (data.length < 2) continue;
        
        const headers = data[0];
        const phoneColIndex = headers.indexOf('Телефон');
        const fcmColIndex = headers.indexOf('FCM_Token');
        
        if (phoneColIndex === -1 || fcmColIndex === -1) continue;
        
        for (let i = 1; i < data.length; i++) {
          if (data[i][phoneColIndex] === targetPhone) {
            const token = data[i][fcmColIndex];
            if (token) {
              tokens.push({
                phone: targetPhone,
                fcmToken: token,
                userType: sheetName === 'Сотрудники' ? 'employee' : 'client'
              });
              foundToken = true;
              break;
            }
          }
        }
        
        if (foundToken) break;
      }
      
      if (!foundToken) {
        notFound.push(targetPhone);
      }
    }
    
    console.log(`✅ Найдено ${tokens.length} FCM токенов, не найдено: ${notFound.length}`);
    
    return createSuccessResponse({
      tokens: tokens,
      notFound: notFound
    });
    
  } catch (error) {
    console.error('Ошибка sendNotification:', error);
    return createResponse(500, {
      status: 'error',
      message: 'Ошибка получения FCM токенов'
    });
  }
}

/**
 * Обработчик для действия 'updateMetadata'
 * Обновляет метаданные для указанных листов
 * Используется для синхронизации после офлайн-изменений
 */
function handleUpdateMetadata(phone, metadataUpdates) {
  try {
    const ss = SpreadsheetApp.getActiveSpreadsheet();
    
    // Проверяем, что пользователь - сотрудник (только сотрудники могут обновлять метаданные)
    const isEmployee = isPhoneInSheet(ss, 'Сотрудники', phone);
    if (!isEmployee) {
      return createResponse(403, {
        status: 'error',
        message: 'Обновление метаданных доступно только сотрудникам'
      });
    }
    
    const metadataSheet = ss.getSheetByName('Метаданные');
    if (!metadataSheet) {
      return createResponse(404, {
        status: 'error',
        message: 'Лист "Метаданные" не найден'
      });
    }
    
    const metadataValues = metadataSheet.getDataRange().getValues();
    let updatedCount = 0;
    
    // Обрабатываем каждое обновление метаданных
    for (const update of metadataUpdates) {
      const { sheetName, lastUpdate } = update;
      
      if (!sheetName || !lastUpdate) {
        console.warn(`Пропущено обновление метаданных: отсутствуют данные ${JSON.stringify(update)}`);
        continue;
      }
      
      // Ищем существующую запись или добавляем новую
      let targetRow = -1;
      
      for (let i = 0; i < metadataValues.length; i++) {
        if (metadataValues[i][0] === sheetName) {
          targetRow = i + 1;
          break;
        }
      }
      
      if (targetRow === -1) {
        targetRow = metadataValues.length + 1;
        metadataSheet.getRange(targetRow, 1).setValue(sheet); // Лист
      }
      
      // Обновляем метаданные
      metadataSheet.getRange(targetRow, 2).setValue(lastUpdate); // lastUpdate
      metadataSheet.getRange(targetRow, 3).setValue(phone); // editor
      
      updatedCount++;
    }
    
    console.log(`✅ Обновлено ${updatedCount} записей метаданных`);
    
    return createSuccessResponse({
      message: `Успешно обновлено ${updatedCount} метаданных`,
      updatedCount: updatedCount
    });
    
  } catch (error) {
    console.error('Ошибка updateMetadata:', error);
    return createResponse(500, {
      status: 'error',
      message: 'Ошибка обновления метаданных'
    });
  }
}

/**
 * Обработчик для действия 'deleteOrder'
 * Удаляет заказ (пока не реализовано)
 */
function handleDeleteOrder(phone, orderData) {
  console.log('⚠️ Функция deleteOrder не реализована');
  return createSuccessResponse({
    message: 'Удаление заказов пока не поддерживается',
    warning: 'not_implemented'
  });
}

/**
 * Обработчик для действия 'addWarehouseOperation'
 * Добавляет складскую операцию в лист "Складские операции"
 * Просто записывает полученные данные без генерации ID
 */
function handleAddWarehouseOperation(phone, operationData) {
  try {
    const ss = SpreadsheetApp.getActiveSpreadsheet();
    
    // Проверяем, что пользователь - сотрудник
    const isEmployee = isPhoneInSheet(ss, 'Сотрудники', phone);
    if (!isEmployee) {
      return createResponse(403, {
        status: 'error',
        message: 'Добавление складских операций доступно только сотрудникам'
      });
    }
    
    const warehouseSheet = ss.getSheetByName('Складские операции');
    if (!warehouseSheet) {
      return createResponse(404, {
        status: 'error',
        message: 'Лист "Складские операции" не найден'
      });
    }
    
    // Получаем текущие заголовки из листа
    const lastColumn = warehouseSheet.getLastColumn();
    const headers = warehouseSheet.getRange(1, 1, 1, lastColumn).getValues()[0];
    
    // Подготавливаем строку для записи
    const rowData = [];
    
    for (let i = 0; i < headers.length; i++) {
      const header = headers[i];
      if (header && header.toString().trim() !== '') {
        const headerKey = header.toString().trim();
        
        if (operationData.hasOwnProperty(headerKey)) {
          let value = operationData[headerKey];
          
          // Специальная обработка для дат
          if (headerKey === 'Дата' || headerKey === 'Срок годности') {
            value = formatDateToDDMMYYYY(value);
          }
          
          rowData.push(value);
        } else {
          // Если поле не передано в JSON, оставляем пустым
          rowData.push('');
        }
      } else {
        rowData.push('');
      }
    }
    
    // Добавляем новую строку с полученными данными
    warehouseSheet.appendRow(rowData);
    
    // Обновляем метаданные
    try {
      updateMetadata_('Складские операции', new Date().toISOString(), 
        phone || 'Мобильное приложение', 'API');
    } catch (error) {
      console.warn('Предупреждение: не удалось обновить метаданные:', error.message);
    }
    
    console.log(`✅ Складская операция добавлена: ${JSON.stringify(operationData)}`);
    
    return createSuccessResponse({
      message: 'Складская операция успешно добавлена'
    });
    
  } catch (error) {
    console.error('Ошибка addWarehouseOperation:', error);
    return createResponse(500, {
      status: 'error',
      message: 'Ошибка добавления складской операции'
    });
  }
}

/**
 * Обработка добавления нового листа
 */
function handleSheetInserted(ss) {
  const metadataSheet = ss.getSheetByName('Метаданные');
  if (!metadataSheet) return;
  
  // Получаем все текущие листы
  const allSheets = ss.getSheets();
  
  // Получаем существующие имена из метаданных
  const existingNames = new Set();
  const lastRow = metadataSheet.getLastRow();
  if (lastRow > 1) {
    const names = metadataSheet.getRange(2, 1, lastRow - 1, 1).getValues();
    names.forEach(row => {
      if (row[0]) existingNames.add(row[0]);
    });
  }
  
  // Ищем новые листы
  const now = new Date().toISOString();
  let newRow = lastRow + 1;
  
  allSheets.forEach(sheet => {
    const sheetName = sheet.getName();
    if (sheetName !== 'Метаданные' && !existingNames.has(sheetName)) {
      console.log(`📝 Добавляем новый лист: ${sheetName}`);
      
      metadataSheet.getRange(newRow, 1).setValue(sheetName);
      metadataSheet.getRange(newRow, 2).setValue(now);
      metadataSheet.getRange(newRow, 3).setValue('system (auto)');
      metadataSheet.getRange(newRow, 4).setValue('Автоматически');
      
      newRow++;
    }
  });
}

/**
 * Обработка удаления листа
 */
function handleSheetRemoved(ss) {
  const metadataSheet = ss.getSheetByName('Метаданные');
  if (!metadataSheet) return;
  
  // Получаем текущие имена листов
  const currentSheets = new Set(
    ss.getSheets()
      .map(sheet => sheet.getName())
      .filter(name => name !== 'Метаданные')
  );
  
  // Получаем данные метаданных
  const lastRow = metadataSheet.getLastRow();
  if (lastRow < 2) return;
  
  const data = metadataSheet.getRange(2, 1, lastRow - 1, 1).getValues();
  
  // Ищем строки для удаления (листы, которых больше нет)
  const rowsToDelete = [];
  
  for (let i = 0; i < data.length; i++) {
    const sheetName = data[i][0];
    if (sheetName && !currentSheets.has(sheetName)) {
      console.log(`🗑️ Лист "${sheetName}" удален, удаляем из метаданных`);
      rowsToDelete.push(i + 2); // +2 потому что данные начинаются с 2 строки
    }
  }
  
  // Удаляем строки в обратном порядке
  rowsToDelete.sort((a, b) => b - a);
  rowsToDelete.forEach(row => {
    metadataSheet.deleteRow(row);
  });
  
  if (rowsToDelete.length > 0) {
    console.log(`✅ Удалено записей: ${rowsToDelete.length}`);
  }
}

/**
 * Обработка переименования листа
 */
function handleSheetRenamed(ss) {
  const metadataSheet = ss.getSheetByName('Метаданные');
  if (!metadataSheet) return;
  
  // Получаем все текущие листы с их ID
  const currentSheets = {};
  ss.getSheets().forEach(sheet => {
    if (sheet.getName() !== 'Метаданные') {
      currentSheets[sheet.getSheetId()] = sheet.getName();
    }
  });
  
  // Получаем данные метаданных
  const lastRow = metadataSheet.getLastRow();
  if (lastRow < 2) return;
  
  const data = metadataSheet.getRange(2, 1, lastRow - 1, 4).getValues();
  const now = new Date().toISOString();
  let renamed = 0;
  
  // Проверяем каждую запись в метаданных
  for (let i = 0; i < data.length; i++) {
    const oldName = data[i][0];
    if (!oldName) continue;
    
    // Проверяем, есть ли лист с таким именем сейчас
    let found = false;
    for (const sheetId in currentSheets) {
      if (currentSheets[sheetId] === oldName) {
        found = true;
        break;
      }
    }
    
    // Если не нашли - возможно, лист переименован
    if (!found) {
      // Ищем новый лист, которого нет в метаданных
      for (const sheetId in currentSheets) {
        const newName = currentSheets[sheetId];
        
        // Проверяем, есть ли это имя в метаданных
        let nameExists = false;
        for (let j = 0; j < data.length; j++) {
          if (data[j][0] === newName) {
            nameExists = true;
            break;
          }
        }
        
        if (!nameExists) {
          console.log(`📝 Обновляем имя: "${oldName}" -> "${newName}"`);
          
          const rowNum = i + 2;
          metadataSheet.getRange(rowNum, 1).setValue(newName);
          metadataSheet.getRange(rowNum, 2).setValue(now);
          metadataSheet.getRange(rowNum, 3).setValue('system (rename)');
          metadataSheet.getRange(rowNum, 4).setValue('Автоматически');
          
          renamed++;
          break;
        }
      }
    }
  }
  
  if (renamed > 0) {
    console.log(`✅ Обновлено имен: ${renamed}`);
  }
}
