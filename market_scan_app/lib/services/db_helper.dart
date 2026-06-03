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
      version: 3,
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
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    await batch.commit(noResult: true);
  }

  Future<void> clearAllProducts() async {
    final db = await instance.database;
    await db.delete('products');
  }

  Future close() async {
    final db = await instance.database;
    db.close();
  }
}
