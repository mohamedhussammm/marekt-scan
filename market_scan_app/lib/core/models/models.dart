class Product {
  final String id;
  final String name;
  final String barcode;
  final String category;
  final double costPrice;
  final double sellingPrice;
  int stockQuantity;
  final int minStockLevel;
  final String unit;
  final String? imageUrl;
  final bool isRegistered;

  Product({
    required this.id,
    required this.name,
    required this.barcode,
    required this.category,
    required this.costPrice,
    required this.sellingPrice,
    required this.stockQuantity,
    required this.minStockLevel,
    this.unit = 'قطعة',
    this.imageUrl,
    this.isRegistered = true,
  });

  bool get isLowStock => stockQuantity <= minStockLevel;
  bool get isCriticalStock => stockQuantity <= (minStockLevel * 0.5).ceil();
  double get profitMargin => sellingPrice - costPrice;

  Product copyWith({
    String? id, String? name, String? barcode, String? category,
    double? costPrice, double? sellingPrice, int? stockQuantity,
    int? minStockLevel, String? unit, String? imageUrl, bool? isRegistered,
  }) {
    return Product(
      id: id ?? this.id, name: name ?? this.name, barcode: barcode ?? this.barcode,
      category: category ?? this.category, costPrice: costPrice ?? this.costPrice,
      sellingPrice: sellingPrice ?? this.sellingPrice,
      stockQuantity: stockQuantity ?? this.stockQuantity,
      minStockLevel: minStockLevel ?? this.minStockLevel,
      unit: unit ?? this.unit, imageUrl: imageUrl ?? this.imageUrl,
      isRegistered: isRegistered ?? this.isRegistered,
    );
  }

  factory Product.fromJson(Map<String, dynamic> json) {
    // If the json['isRegistered'] comes from SQLite as int (0/1) or mongo as bool, handle both
    final regVal = json['isRegistered'] ?? json['is_registered'];
    bool registered = true;
    if (regVal is bool) {
      registered = regVal;
    } else if (regVal is int) {
      registered = regVal == 1;
    }

    return Product(
      id: json['_id'] ?? json['id'] ?? json['barcodeId'] ?? '',
      name: json['name'] ?? '',
      barcode: json['barcodeId'] ?? json['barcode'] ?? '',
      category: json['category'] ?? '',
      costPrice: (json['costPrice'] ?? 0).toDouble(),
      sellingPrice: (json['sellingPrice'] ?? 0).toDouble(),
      stockQuantity: json['currentStock'] ?? json['stockQuantity'] ?? 0,
      minStockLevel: json['minThreshold'] ?? json['minStockLevel'] ?? 10,
      unit: json['unit'] ?? 'قطعة',
      imageUrl: json['imageUrl'],
      isRegistered: registered,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'barcodeId': barcode,
      'name': name,
      'category': category,
      'costPrice': costPrice,
      'sellingPrice': sellingPrice,
      'currentStock': stockQuantity,
      'minThreshold': minStockLevel,
      'unit': unit,
      'imageUrl': imageUrl,
      'isRegistered': isRegistered ? 1 : 0,
    };
  }
}

class CartItem {
  final Product product;
  int quantity;
  double? discountPercent;

  CartItem({required this.product, this.quantity = 1, this.discountPercent});

  double get subtotal => product.sellingPrice * quantity;
  double get discountAmount => discountPercent != null
      ? subtotal * (discountPercent! / 100) : 0;
  double get total => subtotal - discountAmount;
}

class Sale {
  final String id;
  final String receiptNumber;
  final List<CartItem> items;
  final double subtotal;
  final double discount;
  final double tax;
  final double total;
  final double amountPaid;
  final String paymentMethod;
  final DateTime createdAt;
  final String type; // 'sale' or 'expense'
  final String? cashierName;

  Sale({
    required this.id,
    required this.receiptNumber,
    required this.items,
    required this.subtotal,
    required this.discount,
    required this.tax,
    required this.total,
    required this.amountPaid,
    required this.paymentMethod,
    required this.createdAt,
    this.type = 'sale',
    this.cashierName,
  });

  double get change => amountPaid - total;
}

class SalesSummary {
  final double totalRevenue;
  final double totalProfit;
  final int totalOrders;
  final int totalItemsSold;
  final DateTime date;

  const SalesSummary({
    required this.totalRevenue,
    required this.totalProfit,
    required this.totalOrders,
    required this.totalItemsSold,
    required this.date,
  });
}

class Shift {
  final String id;
  final String storeName;
  final String cashierUsername;
  final DateTime startTime;
  final DateTime? endTime;
  final String status; // 'open' | 'closed'
  final double startingCash;
  final double? endingCash;
  final double totalSales;
  final double cashSales;
  final double cardSales;

  Shift({
    required this.id,
    required this.storeName,
    required this.cashierUsername,
    required this.startTime,
    this.endTime,
    required this.status,
    required this.startingCash,
    this.endingCash,
    required this.totalSales,
    required this.cashSales,
    required this.cardSales,
  });

  factory Shift.fromJson(Map<String, dynamic> json) {
    final breakdown = json['paymentMethodsBreakdown'] ?? {};
    return Shift(
      id: json['_id'] ?? json['id'] ?? '',
      storeName: json['storeName'] ?? '',
      cashierUsername: json['cashierUsername'] ?? '',
      startTime: DateTime.parse(json['startTime'] ?? json['createdAt']),
      endTime: json['endTime'] != null ? DateTime.parse(json['endTime']) : null,
      status: json['status'] ?? 'open',
      startingCash: (json['startingCash'] ?? 0).toDouble(),
      endingCash: json['endingCash'] != null ? (json['endingCash']).toDouble() : null,
      totalSales: (json['totalSales'] ?? 0).toDouble(),
      cashSales: (breakdown['cash'] ?? 0).toDouble(),
      cardSales: (breakdown['card'] ?? 0).toDouble(),
    );
  }
}

class PettyExpense {
  final String id;
  final String storeName;
  final String cashierUsername;
  final String? shiftId;
  final double amount;
  final String description;
  final DateTime timestamp;

  PettyExpense({
    required this.id,
    required this.storeName,
    required this.cashierUsername,
    this.shiftId,
    required this.amount,
    required this.description,
    required this.timestamp,
  });

  factory PettyExpense.fromJson(Map<String, dynamic> json) {
    return PettyExpense(
      id: json['_id'] ?? json['id'] ?? '',
      storeName: json['storeName'] ?? '',
      cashierUsername: json['cashierUsername'] ?? '',
      shiftId: json['shiftId'],
      amount: (json['amount'] ?? 0).toDouble(),
      description: json['description'] ?? '',
      timestamp: DateTime.parse(json['timestamp'] ?? json['createdAt']),
    );
  }
}
