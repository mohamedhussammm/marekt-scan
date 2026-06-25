import 'dart:convert';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../core/models/models.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;
  
  DatabaseHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('market_scan.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    return await openDatabase(
      path,
      version: 4,
      onCreate: _createDB,
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          try {
            await db.execute('ALTER TABLE products ADD COLUMN isRegistered INTEGER DEFAULT 1');
          } catch (_) {}
        }
        if (oldVersion < 3) {
          try {
            await db.execute('ALTER TABLE products ADD COLUMN unit TEXT DEFAULT "قطعة"');
          } catch (_) {}
          try {
            await db.execute('ALTER TABLE products ADD COLUMN imageUrl TEXT');
          } catch (_) {}
        }
        if (oldVersion < 4) {
          try {
            await db.execute('''
CREATE TABLE offline_queue (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  offline_id TEXT NOT NULL UNIQUE,
  operation TEXT NOT NULL,
  payload TEXT NOT NULL,
  created_at TEXT NOT NULL,
  retries INTEGER DEFAULT 0,
  status TEXT DEFAULT 'pending'
)
''');
          } catch (_) {}
        }
      },
      onConfigure: (db) async {
        try {
          await db.execute('PRAGMA journal_mode=WAL');
          await db.execute('PRAGMA synchronous=NORMAL');
        } catch (_) {}
      },
    );
  }

  Future _createDB(Database db, int version) async {
    const idType = 'TEXT PRIMARY KEY';
    const textType = 'TEXT NOT NULL';
    const realType = 'REAL NOT NULL';
    const integerType = 'INTEGER NOT NULL';

    await db.execute('''
CREATE TABLE products (
  barcodeId $idType,
  name $textType,
  category $textType,
  sellingPrice $realType,
  costPrice $realType,
  currentStock $integerType,
  minThreshold INTEGER DEFAULT 10,
  isRegistered INTEGER DEFAULT 1,
  unit TEXT DEFAULT 'قطعة',
  imageUrl TEXT
  )
''');

    await db.execute('''
CREATE TABLE offline_queue (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  offline_id TEXT NOT NULL UNIQUE,
  operation TEXT NOT NULL,
  payload TEXT NOT NULL,
  created_at TEXT NOT NULL,
  retries INTEGER DEFAULT 0,
  status TEXT DEFAULT 'pending'
)
''');
  }

  Future<Product?> getProductByBarcode(String barcodeId) async {
    final db = await instance.database;

    final maps = await db.query(
      'products',
      columns: ['barcodeId', 'name', 'category', 'sellingPrice', 'costPrice', 'currentStock', 'minThreshold', 'isRegistered', 'unit', 'imageUrl'],
      where: 'barcodeId = ?',
      whereArgs: [barcodeId],
    );

    if (maps.isNotEmpty) {
      return Product.fromJson(maps.first);
    } else {
      return null;
    }
  }

  Future<void> insertProduct(Product product) async {
    final db = await instance.database;
    await db.insert(
      'products',
      product.toJson(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> updateStock(String barcodeId, int quantityAdded) async {
    final db = await instance.database;
    await db.rawUpdate(
      'UPDATE products SET currentStock = currentStock + ? WHERE barcodeId = ?',
      [quantityAdded, barcodeId],
    );
  }

  Future<List<Product>> getAllProducts() async {
    final db = await instance.database;
    final result = await db.query('products');
    return result.map((json) => Product.fromJson(json)).toList();
  }

  Future<void> deleteProduct(String barcodeId) async {
    final db = await instance.database;
    await db.delete(
      'products',
      where: 'barcodeId = ?',
      whereArgs: [barcodeId],
    );
  }

  Future<void> insertProductsBatch(List<Product> products) async {
    final db = await instance.database;
    final batch = db.batch();
    for (final p in products) {
      batch.insert(
        'products',
        p.toJson(),
        // Bug #8 fix: use ignore instead of replace.
        // replace = DELETE + INSERT for every row = 3200 disk writes on every login.
        // ignore = skip rows that already exist = near-zero I/O for unchanged data.
        // Individual insertProduct() calls still use replace for targeted updates.
        conflictAlgorithm: ConflictAlgorithm.ignore,
      );
    }
    await batch.commit(noResult: true);
  }

  Future<void> clearAllProducts() async {
    final db = await instance.database;
    await db.delete('products');
  }

  // ─── OFFLINE QUEUE METHODS ───────────────────────────────────────────────

  Future<void> insertOfflineOp(String offlineId, String operation, Map<String, dynamic> payload) async {
    final db = await instance.database;
    await db.insert('offline_queue', {
      'offline_id': offlineId,
      'operation': operation,
      'payload': jsonEncode(payload),
      'created_at': DateTime.now().toIso8601String(),
      'retries': 0,
      'status': 'pending',
    });
  }

  Future<List<OfflineQueueItem>> getPendingOps() async {
    final db = await instance.database;
    final maps = await db.query('offline_queue', where: 'status = ?', whereArgs: ['pending'], orderBy: 'id ASC');
    return maps.map((e) => OfflineQueueItem(
      id: e['id'] as int,
      offlineId: e['offline_id'] as String,
      operation: e['operation'] as String,
      payload: jsonDecode(e['payload'] as String),
      createdAt: DateTime.parse(e['created_at'] as String),
      retries: e['retries'] as int,
      status: e['status'] as String,
    )).toList();
  }

  Future<List<PettyExpense>> getOfflineExpenses() async {
    final db = await instance.database;
    final maps = await db.query(
      'offline_queue',
      where: 'operation = ? AND status = ?',
      whereArgs: ['add_expense', 'pending'],
      orderBy: 'id ASC',
    );
    final List<PettyExpense> list = [];
    for (final map in maps) {
      try {
        final payload = jsonDecode(map['payload'] as String);
        list.add(PettyExpense(
          id: payload['offline_id'] ?? map['offline_id'] ?? '',
          storeName: '',
          cashierUsername: '',
          amount: (payload['amount'] ?? 0.0).toDouble(),
          category: payload['category'] ?? 'أخرى',
          description: payload['description'] ?? '',
          timestamp: DateTime.parse(map['created_at'] as String),
          isOffline: true,
        ));
      } catch (_) {}
    }
    return list;
  }

  Future<void> deleteOfflineOp(int id) async {
    final db = await instance.database;
    await db.delete('offline_queue', where: 'id = ?', whereArgs: [id]);
  }

  Future<void> markOpFailed(int id, int currentRetries) async {
    final db = await instance.database;
    final nextRetries = currentRetries + 1;
    final status = nextRetries >= 5 ? 'failed' : 'pending';
    await db.update('offline_queue', {'retries': nextRetries, 'status': status}, where: 'id = ?', whereArgs: [id]);
  }

  Future<int> getPendingCount() async {
    final db = await instance.database;
    final count = Sqflite.firstIntValue(await db.rawQuery('SELECT COUNT(*) FROM offline_queue WHERE status = ?', ['pending']));
    return count ?? 0;
  }

  Future<int> getProductCount() async {
    final db = await instance.database;
    final count = Sqflite.firstIntValue(await db.rawQuery('SELECT COUNT(*) FROM products'));
    return count ?? 0;
  }

  Future<int> getLowStockCount() async {
    final db = await instance.database;
    final count = Sqflite.firstIntValue(
        await db.rawQuery('SELECT COUNT(*) FROM products WHERE currentStock <= minThreshold'));
    return count ?? 0;
  }

  Future close() async {
    final db = await instance.database;
    db.close();
  }
}
