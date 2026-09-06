import 'package:path/path.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../models/inventory_item.dart';
import '../models/storage_location.dart';

class DatabaseHelper {
  DatabaseHelper._internal();

  static final DatabaseHelper instance = DatabaseHelper._internal();

  static const List<StorageLocation> _defaultLocations = [
    StorageLocation(name: 'Kühlschrank', iconName: 'kitchen'),
    StorageLocation(name: 'Speisekammer', iconName: 'shelves'),
    StorageLocation(name: 'Keller', iconName: 'warehouse'),
    StorageLocation(name: 'Gefrierschrank', iconName: 'freezer'),
  ];

  Database? _db;

  Future<Database> get database async {
    _db ??= await _initDatabase();
    return _db!;
  }

  Future<Database> _initDatabase() async {
    final path = join(await getDatabasesPath(), 'easy_vorrat.db');

    return openDatabase(
      path,
      version: 4,
      onCreate: (db, version) async {
        await _createItemsTable(db);
        await _createLocationsTable(db);
        await _insertDefaultLocations(db);
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await _createLocationsTable(db);
          await _insertDefaultLocations(db);
          await _importLocationsFromItems(db);
        }

        if (oldVersion < 3) {
          await db.execute('ALTER TABLE items ADD COLUMN minimumQuantity TEXT');
          await db.execute(
            'ALTER TABLE items ADD COLUMN autoShoppingList '
            'INTEGER NOT NULL DEFAULT 0',
          );
          await db.execute(
            'ALTER TABLE items ADD COLUMN isOnShoppingList '
            'INTEGER NOT NULL DEFAULT 0',
          );
        }

        if (oldVersion < 4) {
          await db.execute(
            'ALTER TABLE items ADD COLUMN shoppingQuantity TEXT',
          );
          await db.execute('ALTER TABLE items ADD COLUMN defaultLocation TEXT');
          await db.execute(
            'UPDATE items SET defaultLocation = location '
            'WHERE defaultLocation IS NULL',
          );
        }
      },
    );
  }

  Future<void> _createItemsTable(DatabaseExecutor db) async {
    await db.execute('''
      CREATE TABLE items (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        quantity TEXT,
        unit TEXT,
        location TEXT NOT NULL,
        expiryDate INTEGER,
        minimumQuantity TEXT,
        shoppingQuantity TEXT,
        autoShoppingList INTEGER NOT NULL DEFAULT 0,
        isOnShoppingList INTEGER NOT NULL DEFAULT 0,
        defaultLocation TEXT
      )
    ''');
  }

  Future<void> _createLocationsTable(DatabaseExecutor db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS locations (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL UNIQUE,
        iconName TEXT NOT NULL
      )
    ''');
  }

  Future<void> _insertDefaultLocations(DatabaseExecutor db) async {
    for (final location in _defaultLocations) {
      final map = location.toMap()..remove('id');
      await db.insert(
        'locations',
        map,
        conflictAlgorithm: ConflictAlgorithm.ignore,
      );
    }
  }

  Future<void> _importLocationsFromItems(DatabaseExecutor db) async {
    final rows = await db.rawQuery(
      'SELECT DISTINCT location FROM items ORDER BY location',
    );

    for (final row in rows) {
      final name = row['location'] as String?;
      if (name == null || name.trim().isEmpty) {
        continue;
      }

      await db.insert('locations', {
        'name': name.trim(),
        'iconName': 'storage',
      }, conflictAlgorithm: ConflictAlgorithm.ignore);
    }
  }

  Future<List<StorageLocation>> getLocations() async {
    final db = await database;
    final maps = await db.query('locations', orderBy: 'id ASC');
    return maps.map(StorageLocation.fromMap).toList();
  }

  Future<int> insertLocation(StorageLocation location) async {
    final db = await database;
    final map = location.toMap()..remove('id');
    return db.insert('locations', map);
  }

  Future<void> renameLocation({
    required StorageLocation location,
    required String newName,
  }) async {
    final id = location.id;
    if (id == null) {
      return;
    }

    final db = await database;
    await db.transaction((transaction) async {
      await transaction.update(
        'locations',
        {'name': newName},
        where: 'id = ?',
        whereArgs: [id],
      );
      await transaction.update(
        'items',
        {'location': newName},
        where: 'location = ?',
        whereArgs: [location.name],
      );
    });
  }

  Future<bool> deleteLocationIfEmpty(StorageLocation location) async {
    final id = location.id;
    if (id == null) {
      return false;
    }

    final db = await database;

    return db.transaction((transaction) async {
      final rows = await transaction.rawQuery(
        'SELECT COUNT(*) AS itemCount FROM items WHERE location = ?',
        [location.name],
      );
      final itemCount = rows.first['itemCount'] as int? ?? 0;

      if (itemCount > 0) {
        return false;
      }

      await transaction.delete('locations', where: 'id = ?', whereArgs: [id]);
      return true;
    });
  }

  Future<Map<String, int>> getInventoryOverview() async {
    final db = await database;
    final soonLimit = DateTime.now()
        .add(const Duration(days: 3))
        .millisecondsSinceEpoch;

    final totalRows = await db.rawQuery('SELECT COUNT(*) AS total FROM items');
    final expiringRows = await db.rawQuery(
      '''
      SELECT COUNT(*) AS expiring
      FROM items
      WHERE expiryDate IS NOT NULL AND expiryDate <= ?
      ''',
      [soonLimit],
    );

    return {
      'total': totalRows.first['total'] as int? ?? 0,
      'expiring': expiringRows.first['expiring'] as int? ?? 0,
    };
  }

  Future<int> insertItem(InventoryItem item) async {
    final db = await database;
    final itemToInsert = item.autoShoppingList && item.hasReachedMinimum
        ? item.copyWith(isOnShoppingList: true)
        : item;
    final map = itemToInsert.toMap()..remove('id');
    return db.insert('items', map);
  }

  Future<List<InventoryItem>> getAllInventoryItems() async {
    final db = await database;

    final maps = await db.query(
      'items',
      where: '''
        NOT (
          isOnShoppingList = 1
          AND autoShoppingList = 0
          AND CAST(REPLACE(quantity, ',', '.') AS REAL) <= 0
        )
      ''',
      orderBy: 'location COLLATE NOCASE ASC, name COLLATE NOCASE ASC',
    );

    return maps.map(InventoryItem.fromMap).toList();
  }

  Future<List<InventoryItem>> getItemsForLocation(String location) async {
    final db = await database;
    final maps = await db.query(
      'items',
      where: 'location = ?',
      whereArgs: [location],
      orderBy: 'id DESC',
    );
    return maps.map(InventoryItem.fromMap).toList();
  }

  Future<List<InventoryItem>> getShoppingListItems() async {
    final db = await database;

    final maps = await db.query(
      'items',
      where: 'isOnShoppingList = ?',
      whereArgs: [1],
      orderBy: 'name COLLATE NOCASE ASC',
    );

    return maps.map(InventoryItem.fromMap).toList();
  }

  Future<int> deleteItem(int id) async {
    final db = await database;
    return db.delete('items', where: 'id = ?', whereArgs: [id]);
  }

  Future<int> updateItem(InventoryItem item) async {
    final id = item.id;

    if (id == null) {
      throw ArgumentError('Artikel besitzt keine ID.');
    }

    final db = await database;
    final map = item.toMap()..remove('id');

    return db.update('items', map, where: 'id = ?', whereArgs: [id]);
  }

  Future<void> consumeItem({
    required InventoryItem item,
    required double amount,
  }) async {
    final currentQuantity = item.quantityValue;

    if (currentQuantity == null) {
      throw ArgumentError('Die vorhandene Menge ist keine gültige Zahl.');
    }

    if (amount <= 0) {
      throw ArgumentError('Die Verbrauchsmenge muss größer als 0 sein.');
    }

    if (amount > currentQuantity) {
      throw ArgumentError('Die Verbrauchsmenge ist größer als der Bestand.');
    }

    final remaining = currentQuantity - amount;

    if (remaining <= 0) {
      final id = item.id;

      if (id == null) {
        throw ArgumentError('Artikel besitzt keine ID.');
      }

      if (item.autoShoppingList) {
        await updateItem(item.copyWith(quantity: '0', isOnShoppingList: true));
      } else {
        await deleteItem(id);
      }

      return;
    }

    final minimum = item.minimumQuantityValue;

    final shouldAddToShoppingList =
        item.autoShoppingList && minimum != null && remaining <= minimum;

    await updateItem(
      item.copyWith(
        quantity: _formatQuantity(remaining),
        isOnShoppingList: shouldAddToShoppingList || item.isOnShoppingList,
      ),
    );
  }

  Future<void> moveItem({
    required InventoryItem item,
    required String newLocation,
    double? amount,
  }) async {
    final currentQuantity = item.quantityValue;

    if (amount == null) {
      await updateItem(item.copyWith(location: newLocation));
      return;
    }

    if (currentQuantity == null) {
      throw ArgumentError('Die vorhandene Menge ist keine gültige Zahl.');
    }

    if (amount <= 0 || amount > currentQuantity) {
      throw ArgumentError('Ungültige Umlagerungsmenge.');
    }

    if (amount == currentQuantity) {
      await updateItem(item.copyWith(location: newLocation));
      return;
    }

    final remaining = currentQuantity - amount;

    final db = await database;

    await db.transaction((transaction) async {
      final sourceMap =
          item.copyWith(quantity: _formatQuantity(remaining)).toMap()
            ..remove('id');

      await transaction.update(
        'items',
        sourceMap,
        where: 'id = ?',
        whereArgs: [item.id],
      );

      final movedItem = item.copyWith(
        id: null,
        quantity: _formatQuantity(amount),
        location: newLocation,
      );

      final targetMap = movedItem.toMap()..remove('id');

      await transaction.insert('items', targetMap);
    });
  }

  Future<void> markItemAsPurchased(InventoryItem item) async {
    final current = item.quantityValue ?? 0;
    final purchased = item.shoppingQuantityValue;

    if (purchased == null || purchased <= 0) {
      throw ArgumentError(
        'Für diesen Artikel ist keine gültige Einkaufsmenge hinterlegt.',
      );
    }

    final newQuantity = current + purchased;

    await updateItem(
      item.copyWith(
        quantity: _formatQuantity(newQuantity),
        location: item.defaultLocation,
        isOnShoppingList: false,
      ),
    );
  }

  String _formatQuantity(double value) {
    if (value == value.roundToDouble()) {
      return value.toInt().toString();
    }

    return value
        .toStringAsFixed(3)
        .replaceFirst(RegExp(r'0+$'), '')
        .replaceFirst(RegExp(r'\.$'), '');
  }
}
