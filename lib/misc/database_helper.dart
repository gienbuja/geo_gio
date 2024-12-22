import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class DatabaseHelper {
  static final DatabaseHelper _instance = DatabaseHelper._internal();
  factory DatabaseHelper() => _instance;
  static Database? _database;

  DatabaseHelper._internal();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'geo_gio.db');

    return await openDatabase(
      path,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE locations (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            latitude REAL,
            longitude REAL,
            datetime TEXT,
            manual INTEGER
          )
        ''');
        await db.execute('''
          CREATE TABLE zones (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            latitude REAL,
            longitude REAL,
            name TEXT,
            radius REAL,
            description TEXT,
            color TEXT
          )
        ''');
      },
    );
  }

  Future<void> insertLocation(Map<String, dynamic> location) async {
    final db = await database;
    await db.insert('locations', location);
  }

  Future<void> insertZone(Map<String, dynamic> zone) async {
    final db = await database;
    await db.insert('zones', zone);
  }

  Future<List<Map<String, dynamic>>> getUnsyncedLocations() async {
    final db = await database;
    return await db.query('locations');
  }

  Future<List<Map<String, dynamic>>> getUnsyncedZones() async {
    final db = await database;
    return await db.query('zones');
  }

  Future<void> deleteLocation(int id) async {
    final db = await database;
    await db.delete('locations', where: 'id = ?', whereArgs: [id]);
  }

  Future<void> deleteZone(int id) async {
    final db = await database;
    await db.delete('zones', where: 'id = ?', whereArgs: [id]);
  }
}