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
      version: 2,
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
        expiryDate INTEGER
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
    final map = item.toMap()..remove('id');
    return db.insert('items', map);
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

  Future<int> deleteItem(int id) async {
    final db = await database;
    return db.delete('items', where: 'id = ?', whereArgs: [id]);
  }
}
