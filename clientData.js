/**
 * authenticate - Вспомогательная функция загрузки данных
 */
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
    if (hasEmployeeAccess && (!phone || phone.trim() === '')) {
      console.log(`👤 Сотрудник: загружаем весь лист "${sheetName}"`);
      for (let i = 1; i < values.length; i++) {
        const row = {};
        for (let j = 0; j < headers.length; j++) {
          let value = values[i][j];

          // 🔥 ПАРСИМ ЧИСЛА ДЛЯ ЕДИНИЦ ИЗМЕРЕНИЯ
          if (sheetName === 'Ед.измерения' && headers[j] === 'Коэффициент к базовой') {
            value = parseRussianNumber(value);
          }

          row[headers[j]] = value;
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

          if (orderPhone === normalizedPhone) {
            const row = {};
            for (let j = 0; j < headers.length; j++) {
              row[headers[j]] = values[i][j];
            }
            rows.push(row);
          }
        }

        console.log(`📦 Загружено ${rows.length} заказов для телефона ${phone}`);

      } else if (sheetName === 'Категории прайса') {
        // 🔥 КЛИЕНТАМ НЕ ПОКАЗЫВАЕМ КАТЕГОРИИ!
        // console.log('👤 Клиент: пропускаем лист "Категории прайса"');
        // continue;

      } else if (sheetName === 'Ед.измерения') {
        // 🔥 КЛИЕНТАМ НЕ ПОКАЗЫВАЕМ ЕДИНИЦЫ ИЗМЕРЕНИЯ!
        console.log('👤 Клиент: пропускаем лист "Ед.измерения"');
        continue;

      } else if (!phone || phone.trim() === '') {

        console.log(`📋 Гость: загружаем лист "${sheetName}"`)
        if (sheetName === 'Сотрудники') {

          for (let i = 1; i < values.length; i++) {
            const row = {};
            for (let j = 0; j < headers.length; j++) {
              if (headers[j] === 'Роль' || headers[j] === 'Email') {
                // Оставляем только нужные поля
                row[headers[j]] = values[i][j];
              }
            }
            // Ищем "Администратор"
            if (row['Роль'] == "Администратор") {
              rows.push(row);
              // Прерываем цикл, так как нужна только первая запись
              break;
            }
          }

        } else if (sheetName === 'Прайс-лист') {
          // Используем Set для отслеживания уже добавленных категорий
          const seenCategories = new Set();
          for (let i = 1; i < values.length; i++) {
            const row = {};
            let categoryId = null; // Инициализируем переменную для текущей строки

            for (let j = 0; j < headers.length; j++) {
              row[headers[j]] = values[i][j];
              // если это колонка "ID Категории прайса", запоминаем значение
              if (headers[j] === 'ID Категории прайса') {
                categoryId = values[i][j];
              }
            }

            // Если категория еще не встречалась
            if (!seenCategories.has(categoryId)) {
              seenCategories.add(categoryId); // Запоминаем категорию
              rows.push(row);
            }
          }
        } else if (sheetName === 'Категории прайса') {
          // Нет условий
          for (let i = 1; i < values.length; i++) {
            const row = {};
            for (let j = 0; j < headers.length; j++) {
              row[headers[j]] = values[i][j];
            }
            rows.push(row);
          }
        }

      } else {
        // Для остальных листов (Прайс-лист, Состав и т.д.) - загружаем всё
        console.log(`📋 Клиент: загружаем весь лист "${sheetName}"`)
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
