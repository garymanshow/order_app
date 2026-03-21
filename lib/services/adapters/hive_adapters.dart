// lib/services/adapters/hive_adapters.dart
import 'package:hive/hive.dart';
import '../../models/order_item.dart';
import '../../models/filling.dart';
import '../../models/composition.dart';
import '../../models/product.dart';
import '../../models/price_category.dart';
import '../../models/warehouse_operation.dart';
import '../../models/production_operation.dart';
import '../../models/unit_of_measure_sheet.dart';

void registerHiveAdapters() {
  // Регистрируем адаптеры для всех моделей
  Hive.registerAdapter(OrderItemAdapter());
  Hive.registerAdapter(FillingAdapter());
  Hive.registerAdapter(CompositionAdapter());
  Hive.registerAdapter(ProductAdapter());
  Hive.registerAdapter(PriceCategoryAdapter());
  Hive.registerAdapter(WarehouseOperationAdapter());
  Hive.registerAdapter(ProductionOperationAdapter());
  Hive.registerAdapter(UnitOfMeasureSheetAdapter());

  print('✅ Все Hive адаптеры зарегистрированы');
}

// Адаптер для OrderItem
class OrderItemAdapter extends TypeAdapter<OrderItem> {
  @override
  final int typeId = 0;

  @override
  OrderItem read(BinaryReader reader) {
    return OrderItem(
      status: reader.readString(),
      productName: reader.readString(),
      displayName: reader.readString(),
      quantity: reader.readInt(),
      totalPrice: reader.readDouble(),
      date: reader.readString(),
      clientPhone: reader.readString(),
      clientName: reader.readString(),
      paymentAmount: reader.readDouble(),
      paymentDocument: reader.readString(),
      notificationSent: reader.readBool(),
      priceListId: reader.readString(),
    );
  }

  @override
  void write(BinaryWriter writer, OrderItem obj) {
    writer.writeString(obj.status);
    writer.writeString(obj.productName);
    writer.writeString(obj.displayName);
    writer.writeInt(obj.quantity);
    writer.writeDouble(obj.totalPrice);
    writer.writeString(obj.date);
    writer.writeString(obj.clientPhone);
    writer.writeString(obj.clientName);
    writer.writeDouble(obj.paymentAmount);
    writer.writeString(obj.paymentDocument);
    writer.writeBool(obj.notificationSent);
    writer.writeString(obj.priceListId);
  }
}

// Адаптер для Filling
class FillingAdapter extends TypeAdapter<Filling> {
  @override
  final int typeId = 1;

  @override
  Filling read(BinaryReader reader) {
    return Filling(
      sheetName: reader.readString(),
      entityId: reader.readString(),
      name: reader.readString(),
      quantity: reader.readDouble(),
      unitSymbol: reader.readString(),
      ingredients: reader.readList().cast<Composition>(),
    );
  }

  @override
  void write(BinaryWriter writer, Filling obj) {
    writer.writeString(obj.sheetName);
    writer.writeString(obj.entityId);
    writer.writeString(obj.name);
    writer.writeDouble(obj.quantity);
    writer.writeString(obj.unitSymbol);
    writer.writeList(obj.ingredients);
  }
}

// Адаптер для Composition
class CompositionAdapter extends TypeAdapter<Composition> {
  @override
  final int typeId = 2;

  @override
  Composition read(BinaryReader reader) {
    return Composition(
      id: reader.readString(),
      sheetName: reader.readString(),
      entityId: reader.readString(),
      ingredientName: reader.readString(),
      quantity: reader.readDouble(),
      unitSymbol: reader.readString(),
    );
  }

  @override
  void write(BinaryWriter writer, Composition obj) {
    writer.writeString(obj.id);
    writer.writeString(obj.sheetName);
    writer.writeString(obj.entityId);
    writer.writeString(obj.ingredientName);
    writer.writeDouble(obj.quantity);
    writer.writeString(obj.unitSymbol);
  }
}

// Адаптер для Product
class ProductAdapter extends TypeAdapter<Product> {
  @override
  final int typeId = 3;

  @override
  Product read(BinaryReader reader) {
    return Product(
      id: reader.readString(),
      name: reader.readString(),
      price: reader.readDouble(),
      multiplicity: reader.readInt(),
      categoryId: reader.readString(),
      imageUrl: reader.readString(),
      imageBase64: reader.readString(),
      composition: reader.readString(),
      weight: reader.readString(),
      nutrition: reader.readString(),
      storage: reader.readString(),
      packaging: reader.readString(),
      categoryName: reader.readString(),
      wastePercentage: reader.readInt(),
      displayName: reader.readString(),
    );
  }

  @override
  void write(BinaryWriter writer, Product obj) {
    writer.writeString(obj.id);
    writer.writeString(obj.name);
    writer.writeDouble(obj.price);
    writer.writeInt(obj.multiplicity);
    writer.writeString(obj.categoryId);
    writer.writeString(obj.imageUrl ?? '');
    writer.writeString(obj.imageBase64 ?? '');
    writer.writeString(obj.composition);
    writer.writeString(obj.weight);
    writer.writeString(obj.nutrition);
    writer.writeString(obj.storage);
    writer.writeString(obj.packaging);
    writer.writeString(obj.categoryName);
    writer.writeInt(obj.wastePercentage);
    writer.writeString(obj.displayName);
  }
}

// Адаптер для PriceCategory
class PriceCategoryAdapter extends TypeAdapter<PriceCategory> {
  @override
  final int typeId = 4;

  @override
  PriceCategory read(BinaryReader reader) {
    return PriceCategory(
      id: reader.readString(),
      name: reader.readString(),
      packagingQuantity: reader.readInt(),
      packagingName: reader.readString(),
      weight: reader.readDouble(),
      unit: reader.readString(),
      wastePercentage: reader.readInt(),
    );
  }

  @override
  void write(BinaryWriter writer, PriceCategory obj) {
    writer.writeString(obj.id);
    writer.writeString(obj.name);
    writer.writeInt(obj.packagingQuantity);
    writer.writeString(obj.packagingName);
    writer.writeDouble(obj.weight);
    writer.writeString(obj.unit);
    writer.writeInt(obj.wastePercentage);
  }
}

// Адаптер для WarehouseOperation
class WarehouseOperationAdapter extends TypeAdapter<WarehouseOperation> {
  @override
  final int typeId = 5;

  @override
  WarehouseOperation read(BinaryReader reader) {
    return WarehouseOperation(
      id: reader.readString(),
      name: reader.readString(),
      operation: reader.readString(),
      quantity: reader.readDouble(),
      unit: reader.readString(),
      date: DateTime.parse(reader.readString()),
      expiryDate:
          reader.readBool() ? DateTime.parse(reader.readString()) : null,
      price: reader.readBool() ? reader.readDouble() : null,
      supplier: reader.readBool() ? reader.readString() : null,
      relatedOrderId: reader.readBool() ? reader.readString() : null,
      notes: reader.readBool() ? reader.readString() : null,
    );
  }

  @override
  void write(BinaryWriter writer, WarehouseOperation obj) {
    writer.writeString(obj.id);
    writer.writeString(obj.name);
    writer.writeString(obj.operation);
    writer.writeDouble(obj.quantity);
    writer.writeString(obj.unit);
    writer.writeString(obj.date.toIso8601String());
    writer.writeBool(obj.expiryDate != null);
    if (obj.expiryDate != null)
      writer.writeString(obj.expiryDate!.toIso8601String());
    writer.writeBool(obj.price != null);
    if (obj.price != null) writer.writeDouble(obj.price!);
    writer.writeBool(obj.supplier != null);
    if (obj.supplier != null) writer.writeString(obj.supplier!);
    writer.writeBool(obj.relatedOrderId != null);
    if (obj.relatedOrderId != null) writer.writeString(obj.relatedOrderId!);
    writer.writeBool(obj.notes != null);
    if (obj.notes != null) writer.writeString(obj.notes!);
  }
}

// Адаптер для ProductionOperation
class ProductionOperationAdapter extends TypeAdapter<ProductionOperation> {
  @override
  final int typeId = 6;

  @override
  ProductionOperation read(BinaryReader reader) {
    return ProductionOperation(
      rowId: reader.readBool() ? reader.readInt() : null,
      sheet: reader.readString(),
      entityId: reader.readInt(),
      name: reader.readString(),
      quantity: reader.readDouble(),
      unit: reader.readBool() ? reader.readString() : null,
      date: DateTime.parse(reader.readString()),
    );
  }

  @override
  void write(BinaryWriter writer, ProductionOperation obj) {
    writer.writeBool(obj.rowId != null);
    if (obj.rowId != null) writer.writeInt(obj.rowId!);
    writer.writeString(obj.sheet);
    writer.writeInt(obj.entityId);
    writer.writeString(obj.name);
    writer.writeDouble(obj.quantity);
    writer.writeBool(obj.unit != null);
    if (obj.unit != null) writer.writeString(obj.unit!);
    writer.writeString(obj.date.toIso8601String());
  }
}

// Адаптер для UnitOfMeasureSheet
class UnitOfMeasureSheetAdapter extends TypeAdapter<UnitOfMeasureSheet> {
  @override
  final int typeId = 7;

  @override
  UnitOfMeasureSheet read(BinaryReader reader) {
    return UnitOfMeasureSheet(
      code: reader.readString(),
      symbol: reader.readString(),
      name: reader.readString(),
      category: reader.readString(),
      toBase: reader.readDouble(),
      baseUnit: reader.readString(),
    );
  }

  @override
  void write(BinaryWriter writer, UnitOfMeasureSheet obj) {
    writer.writeString(obj.code);
    writer.writeString(obj.symbol);
    writer.writeString(obj.name);
    writer.writeString(obj.category);
    writer.writeDouble(obj.toBase);
    writer.writeString(obj.baseUnit);
  }
}
