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
      version: 7,
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
        if (oldVersion < 5) {
          try {
            await db.execute('''
CREATE TABLE transactions (
  id TEXT PRIMARY KEY,
  receipt_number TEXT NOT NULL,
  total_amount REAL NOT NULL,
  payment_method TEXT NOT NULL,
  cashier_name TEXT NOT NULL,
  items_json TEXT NOT NULL,
  type TEXT DEFAULT 'sale',
  created_at TEXT NOT NULL,
  is_offline INTEGER DEFAULT 0
)
''');
          } catch (_) {}
        }
        if (oldVersion < 6) {
          try {
            await db.execute('ALTER TABLE transactions ADD COLUMN amount_paid REAL');
          } catch (_) {}
        }
        if (oldVersion < 7) {
          try {
            await db.execute('''
CREATE TABLE customers (
  id TEXT PRIMARY KEY,
  customerId TEXT NOT NULL,
  fullName TEXT NOT NULL,
  phoneNumber TEXT,
  address TEXT
)
''');
          } catch (_) {}
          try {
            await db.execute('ALTER TABLE transactions ADD COLUMN customer_id TEXT');
          } catch (_) {}
          try {
            await db.execute('ALTER TABLE transactions ADD COLUMN change_returned REAL');
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

    await db.execute('''
CREATE TABLE transactions (
  id TEXT PRIMARY KEY,
  receipt_number TEXT NOT NULL,
  total_amount REAL NOT NULL,
  amount_paid REAL,
  payment_method TEXT NOT NULL,
  cashier_name TEXT NOT NULL,
  items_json TEXT NOT NULL,
  type TEXT DEFAULT 'sale',
  created_at TEXT NOT NULL,
  is_offline INTEGER DEFAULT 0,
  customer_id TEXT,
  change_returned REAL
)
''');

    await db.execute('''
CREATE TABLE customers (
  id TEXT PRIMARY KEY,
  customerId TEXT NOT NULL,
  fullName TEXT NOT NULL,
  phoneNumber TEXT,
  address TEXT
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

  // ─── CUSTOMER HELPER METHODS ─────────────────────────────────────────────

  Future<void> insertCustomer(Customer customer) async {
    final db = await instance.database;
    await db.insert(
      'customers',
      customer.toJson(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> insertCustomersBatch(List<Customer> customers) async {
    final db = await instance.database;
    final batch = db.batch();
    for (final c in customers) {
      batch.insert(
        'customers',
        c.toJson(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    await batch.commit(noResult: true);
  }

  Future<List<Customer>> getAllCustomers() async {
    final db = await instance.database;
    final maps = await db.query('customers', orderBy: 'fullName ASC');
    return maps.map((e) => Customer.fromJson(e)).toList();
  }

  Future<Customer?> getCustomerById(String customerId) async {
    final db = await instance.database;
    final maps = await db.query(
      'customers',
      where: 'customerId = ?',
      whereArgs: [customerId],
      limit: 1,
    );
    if (maps.isEmpty) return null;
    return Customer.fromJson(maps.first);
  }

  Future<void> clearAllCustomers() async {
    final db = await instance.database;
    await db.delete('customers');
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

  Future<void> updateOfflineExpense(String offlineId, double amount, String description, String category) async {
    final db = await instance.database;
    final maps = await db.query(
      'offline_queue',
      where: 'offline_id = ?',
      whereArgs: [offlineId],
    );
    if (maps.isNotEmpty) {
      final payload = Map<String, dynamic>.from(jsonDecode(maps.first['payload'] as String));
      payload['amount'] = amount;
      payload['description'] = description;
      payload['category'] = category;
      await db.update(
        'offline_queue',
        {'payload': jsonEncode(payload)},
        where: 'offline_id = ?',
        whereArgs: [offlineId],
      );
    }
  }

  Future<void> deleteOfflineExpense(String offlineId) async {
    final db = await instance.database;
    await db.delete(
      'offline_queue',
      where: 'offline_id = ?',
      whereArgs: [offlineId],
    );
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

  Future<void> insertLocalTransaction({
    required String id,
    required String receiptNumber,
    required double totalAmount,
    double? amountPaid,
    required String paymentMethod,
    required String cashierName,
    required String itemsJson,
    String type = 'sale',
    required DateTime createdAt,
    required bool isOffline,
    String? customerId,
    double? changeReturned,
  }) async {
    final db = await instance.database;
    await db.insert(
      'transactions',
      {
        'id': id,
        'receipt_number': receiptNumber,
        'total_amount': totalAmount,
        'amount_paid': amountPaid ?? totalAmount,
        'payment_method': paymentMethod,
        'cashier_name': cashierName,
        'items_json': itemsJson,
        'type': type,
        'created_at': createdAt.toIso8601String(),
        'is_offline': isOffline ? 1 : 0,
        'customer_id': customerId,
        'change_returned': changeReturned,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );

    // Limit table size to 500 records
    try {
      await db.execute('''
        DELETE FROM transactions WHERE id NOT IN (
          SELECT id FROM transactions ORDER BY created_at DESC LIMIT 500
        )
      ''');
    } catch (_) {}
  }

  Future<List<Map<String, dynamic>>> getLocalTransactions({int limit = 30, int skip = 0}) async {
    final db = await instance.database;
    return await db.query(
      'transactions',
      orderBy: 'created_at DESC',
      limit: limit,
      offset: skip,
    );
  }

  Future<List<Map<String, dynamic>>> getOfflineTransactions() async {
    final db = await instance.database;
    return await db.query(
      'transactions',
      where: 'is_offline = 1',
      orderBy: 'created_at DESC',
    );
  }

  Future<void> clearAllTransactions() async {
    final db = await instance.database;
    await db.delete('transactions');
  }

  Future<List<Map<String, dynamic>>> getLocalTransactionsForCustomer(String customerId) async {
    final db = await instance.database;
    return await db.query(
      'transactions',
      where: 'customer_id = ?',
      whereArgs: [customerId],
      orderBy: 'created_at DESC',
    );
  }

  Future close() async {
    final db = await instance.database;
    db.close();
  }
}
