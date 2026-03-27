/**
 * Фильтрация Прайс-листа данных для витрины
 */
function filterUniqueCategories(jsonObj, sheetKey = "Прайс-лист") {
  // Проверяем, существует ли ключ "Прайс-лист" и является ли он массивом
  if (!jsonObj[sheetKey] || !Array.isArray(jsonObj[sheetKey])) {
    console.log("Ключ 'Прайс-лист' не найден или данные не являются массивом.");
    return jsonObj;
  }

  const rows = jsonObj[sheetKey];
  const uniquerows = [];
  const seenCategories = new Set(); // Используем Set для отслеживания уже добавленных категорий

  // Проходим по всем элементам массива
  for (let i = 0; i < rows.length; i++) {
    const row = rows[i];
    // Получаем ID категории. Если значение null или undefined, приводим к пустой строке для единообразия
    const categoryId = row["ID Категории прайса"];

    // Set.has корректно работает с числами, null и строками.
    // Если категория еще не встречалась
    if (!seenCategories.has(categoryId)) {
      seenCategories.add(categoryId); // Запоминаем категорию
      uniquerows.push(row);         // Добавляем товар в новый массив
    }
  }

  // Обновляем объект
  jsonObj["Прайс-лист"] = uniquerows;

  return jsonObj;
}

function testFilter() {
  // Исходный объект
  let data = {
    "Прайс-лист": [
      { "ID": 1, "ID Категории прайса": 7, "Название": "Баба ин Банка апероль-малина" },
      { "ID": 2, "ID Категории прайса": 7, "Название": "Баба ин Банка красный апельсин" }, // Дубликат категории 7
      { "ID": 5, "ID Категории прайса": 5, "Название": "Вупи-Пай" },
      { "ID": 6, "ID Категории прайса": null, "Название": "Десерт Брауни в форме круглая" },
      { "ID": 7, "ID Категории прайса": null, "Название": "Десерт Брауни в форме овальная" } // Дубликат null
    ]
  };

  // Вызов функции фильтрации
  let filteredData = filterUniqueCategories(data);

  // Вывод результата
  console.log(JSON.stringify(filteredData, null, 2));
}

/**
 * Обезличивание данных для витрины
 */
function anonymizeEmployeesData(jsonObj, sheetKey = "Сотрудники") {

  // Проверяем наличие ключа
  if (!jsonObj[sheetKey] || !Array.isArray(jsonObj[sheetKey])) {
    return jsonObj;
  }

  const rows = jsonObj[sheetKey];
  const result = [];

  // Проходим по массиву
  for (let i = 0; i < rows.length; i++) {
    const row = rows[i];

    // 1. Ищем "Администратор"
    if (row["Роль"] === "Администратор") {
      // 2. Оставляем только нужные поля
      result.push({
        "Роль": row["Роль"],
        "Email": row["Email"]
      });

      // 3. Прерываем цикл, так как нужна только первая запись
      break;
    }
  }

  // Обновляем объект
  jsonObj[sheetKey] = result;
  return jsonObj;
}