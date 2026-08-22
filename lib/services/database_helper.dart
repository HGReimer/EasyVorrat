import 'package:path/path.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../models/inventory_item.dart';

class DatabaseHelper {
  DatabaseHelper._internal();
  static final DatabaseHelper instance = DatabaseHelper._internal();

  Database? _db;

  Future<Database> get database async {
    _db ??= await _initDatabase();
    return _db!;
  }

  Future<Database> _initDatabase() async {
    final path = join(await getDatabasesPath(), 'easy_vorrat.db');
    return openDatabase(
      path,
      version: 1,
      onCreate: (db, version) async {
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
      },
    );
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
    return maps.map((m) => InventoryItem.fromMap(m)).toList();
  }

  Future<int> deleteItem(int id) async {
    final db = await database;
    return db.delete('items', where: 'id = ?', whereArgs: [id]);
  }
}
