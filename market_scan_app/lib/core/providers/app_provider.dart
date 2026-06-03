import 'package:flutter/material.dart';
import '../models/models.dart';
import '../../services/api_service.dart';
import '../../services/db_helper.dart';

class AppProvider extends ChangeNotifier {
  final ApiService _api = ApiService();
  final DatabaseHelper _db = DatabaseHelper.instance;

  final List<Product> _products = [];
  final List<Sale> _sales = [];
  final List<CartItem> _cart = [];

  // Cached filters for blazing fast list rendering
  List<Product> _filteredProductsCache = [];
  List<Product> _lowStockProductsCache = [];
  List<String> _categoriesCache = ['الكل'];

  String _selectedCategory = 'الكل';
  String _searchQuery = '';
  bool _isLoggedIn = false;
  bool _isLoading = false;

  // Persistence settings
  String _storeName = 'سوبر ماركت النيل';
  String _storeAddress = 'القاهرة، مصر';
  String _storePhone = '+20 10 0000 0000';
  String _storeEmail = 'admin@marketscan.com';
  double _taxRate = 14.0;
  bool _notificationsEnabled = true;
  bool _darkModeEnabled = false;

  // Dashboard Stats
  double _todaySalesTotal = 0.0;
  int _todayOrdersCount = 0;
  double _allTimeRevenue = 0.0;
  double _netProfit = 0.0;
  int _totalOrdersCount = 0;
  int _lowStockCount = 0;
  List<double> _weeklySales = List.filled(7, 0.0);
  List<dynamic> _topProductsList = [];
  List<dynamic> _categoriesAggregationList = [];

  // Roles and Shifts
  String _userRole = 'cashier';
  String _username = '';
  Shift? _activeShift;
  double _todayExpenses = 0.0;
  double _cashOnHand = 0.0;
  List<Shift> _shiftHistory = [];

  // ─── Getters ─────────────────────────────────────────────────────────────
  List<Product> get products => List.unmodifiable(_products);
  List<Sale> get sales => List.unmodifiable(_sales);
  List<CartItem> get cart => List.unmodifiable(_cart);
  bool get isLoggedIn => _isLoggedIn;
  bool get isLoading => _isLoading;

  String get storeName => _storeName;
  String get storeAddress => _storeAddress;
  String get storePhone => _storePhone;
  String get storeEmail => _storeEmail;
  double get taxRate => _taxRate;
  bool get notificationsEnabled => _notificationsEnabled;
  bool get darkModeEnabled => _darkModeEnabled;

  String get selectedCategory => _selectedCategory;
  String get searchQuery => _searchQuery;

  List<Product> get filteredProducts => _filteredProductsCache;

  List<Product> get lowStockProducts => _lowStockProductsCache;

  List<String> get categories => _categoriesCache;

  void _updateFilterCaches() {
    _filteredProductsCache = _products.where((p) {
      final matchesCategory = _selectedCategory == 'الكل' || p.category == _selectedCategory;
      final matchesSearch = _searchQuery.isEmpty ||
          p.name.contains(_searchQuery) || p.barcode.contains(_searchQuery);
      return matchesCategory && matchesSearch;
    }).toList();

    _lowStockProductsCache = _products.where((p) => p.isLowStock).toList();

    final cats = _products.map((p) => p.category).toSet().toList();
    cats.insert(0, 'الكل');
    _categoriesCache = cats;
  }

  double get cartSubtotal => _cart.fold(0.0, (sum, item) => sum + item.subtotal);
  double get cartTax => cartSubtotal * (_taxRate / 100.0);
  double get cartTotal => cartSubtotal + cartTax;
  int get cartItemCount => _cart.fold(0, (sum, item) => sum + item.quantity);

  // Dashboard Stats
  double get todaySalesTotal => _todaySalesTotal;
  int get todayOrdersCount => _todayOrdersCount;
  double get allTimeRevenue => _allTimeRevenue;
  double get netProfit => _netProfit;
  int get totalOrdersCount => _totalOrdersCount;
  int get lowStockCount => _lowStockCount;
  List<double> get weeklySales => _weeklySales;
  List<dynamic> get topProductsList => _topProductsList;
  List<dynamic> get categoriesAggregationList => _categoriesAggregationList;

  String get userRole => _userRole;
  String get username => _username;
  Shift? get activeShift => _activeShift;
  double get todayExpenses => _todayExpenses;
  double get cashOnHand => _cashOnHand;
  List<Shift> get shiftHistory => _shiftHistory;

  // ─── Actions ─────────────────────────────────────────────────────────────

  Future<Map<String, dynamic>> loginUser(String usernameOrEmail, String password) async {
    _isLoading = true;
    notifyListeners();

    try {
      final result = await _api.login(usernameOrEmail, password);
      if (result['success'] == true) {
        _isLoggedIn = true;
        final userData = result['user'];
        _storeName = userData['storeName'] ?? 'سوبر ماركت النيل';
        _storeEmail = userData['email'] ?? 'admin@marketscan.com';
        _userRole = userData['role'] ?? 'cashier';
        _username = userData['username'] ?? '';

        // Set store and user context for API client headers
        ApiService.currentStoreName = _storeName;
        ApiService.currentUserRole = _userRole;
        ApiService.currentUsername = _username;

        // Concurrent parallel load of settings, products, dashboard statistics, and active shift
        await Future.wait([
          loadSettings(),
          loadProducts(),
          loadDashboardStats(),
          loadActiveShift(),
        ]);
        
        // Force bind logged-in user profile attributes
        _storeName = userData['storeName'] ?? _storeName;
        if (userData['email'] != null && userData['email'].toString().isNotEmpty) {
          _storeEmail = userData['email'];
        }

        _isLoading = false;
        notifyListeners();
        return {'success': true};
      }
      
      _isLoading = false;
      notifyListeners();
      return {'success': false, 'error': result['error'] ?? 'اسم المستخدم أو كلمة المرور غير صحيحة'};
    } catch (e) {
      _isLoading = false;
      notifyListeners();
      return {'success': false, 'error': 'خطأ في الاتصال بالخادم: $e'};
    }
  }

  Future<Map<String, dynamic>> registerUser({
    required String username,
    required String email,
    required String storeName,
    required String password,
    required String role,
  }) async {
    _isLoading = true;
    notifyListeners();

    try {
      final result = await _api.register(
        username: username,
        password: password,
        email: email,
        storeName: storeName,
        role: role,
      );

      if (result['success'] == true) {
        _isLoggedIn = true;
        final userData = result['user'];
        _storeName = userData['storeName'] ?? storeName;
        _storeEmail = userData['email'] ?? email;
        _userRole = userData['role'] ?? role;
        _username = userData['username'] ?? username;

        // Set store and user context for API client headers
        ApiService.currentStoreName = _storeName;
        ApiService.currentUserRole = _userRole;
        ApiService.currentUsername = _username;

        // Concurrent parallel load of settings, products, dashboard statistics, and active shift
        await Future.wait([
          loadSettings(),
          loadProducts(),
          loadDashboardStats(),
          loadActiveShift(),
        ]);

        _storeName = userData['storeName'] ?? storeName;
        if (userData['email'] != null && userData['email'].toString().isNotEmpty) {
          _storeEmail = userData['email'];
        }

        _isLoading = false;
        notifyListeners();
        return {'success': true};
      }

      _isLoading = false;
      notifyListeners();
      return {'success': false, 'error': result['error'] ?? 'فشل التسجيل'};
    } catch (e) {
      _isLoading = false;
      notifyListeners();
      return {'success': false, 'error': 'خطأ في الاتصال بالخادم: $e'};
    }
  }

  void logout() {
    _isLoggedIn = false;
    _cart.clear();
    _products.clear();
    _sales.clear();
    _userRole = 'cashier';
    _username = '';
    _activeShift = null;
    _todayExpenses = 0.0;
    _cashOnHand = 0.0;
    _shiftHistory = [];
    ApiService.currentStoreName = null;
    ApiService.currentUserRole = null;
    ApiService.currentUsername = null;
    _db.clearAllProducts(); // Clear SQLite cache to isolate data
    _updateFilterCaches();
    notifyListeners();
  }

  Future<void> loadProducts() async {
    _isLoading = true;
    notifyListeners();

    // 1. Try to fetch from Backend
    List<Product> fetched = await _api.getAllProducts();
    if (fetched.isNotEmpty) {
      _products.clear();
      _products.addAll(fetched);

      // Sync local SQLite with remote via optimized BATCH transaction
      await _db.insertProductsBatch(fetched);
    } else {
      // Offline fallback: load from SQLite
      final List<Product> cached = await _db.getAllProducts();
      _products.clear();
      _products.addAll(cached);
    }

    _updateFilterCaches();
    _isLoading = false;
    notifyListeners();
  }

  Future<void> loadDashboardStats() async {
    try {
      final results = await Future.wait([
        _api.getDashboardSummary(),
        _api.getWeeklyChart(),
        _api.getTopProducts(),
        _api.getSalesByCategory(),
        _api.getTransactions(limit: 10),
      ]);

      final summary = results[0] as Map<String, dynamic>;
      final chart = results[1] as List<double>;
      final topProds = results[2] as List<dynamic>;
      final catAgg = results[3] as List<dynamic>;
      final txsList = results[4] as List<dynamic>;

      if (summary['success'] == true) {
        _todaySalesTotal = double.tryParse(summary['todayRevenue'].toString()) ?? 0.0;
        _todayOrdersCount = int.tryParse(summary['todayOrdersCount'].toString()) ?? 0;
        _allTimeRevenue = double.tryParse(summary['totalRevenue'].toString()) ?? 0.0;
        _netProfit = double.tryParse(summary['netProfit'].toString()) ?? 0.0;
        _totalOrdersCount = int.tryParse(summary['totalOrders'].toString()) ?? 0;
        _lowStockCount = int.tryParse(summary['lowStockCount'].toString()) ?? 0;
        _todayExpenses = double.tryParse((summary['todayExpenses'] ?? 0).toString()) ?? 0.0;
        _cashOnHand = double.tryParse((summary['cashOnHand'] ?? 0).toString()) ?? 0.0;
      }

      _weeklySales = chart;
      _topProductsList = topProds;
      _categoriesAggregationList = catAgg;

      _sales.clear();
      for (final tx in txsList) {
        try {
          final List<dynamic> itemsData = tx['items'] ?? [];
          final items = itemsData.map((it) {
            final prod = findByBarcode(it['barcodeId']) ?? Product(
              id: it['barcodeId'],
              barcode: it['barcodeId'],
              name: it['name'],
              category: 'عام',
              costPrice: it['unitPrice'] * 0.7,
              sellingPrice: it['unitPrice'],
              stockQuantity: 100,
              minStockLevel: 10,
            );
            return CartItem(product: prod, quantity: it['qty']);
          }).toList();

          _sales.add(Sale(
            id: tx['_id'],
            receiptNumber: tx['receiptNumber'] ?? 'REC-000',
            items: items,
            subtotal: double.tryParse(tx['totalAmount'].toString()) ?? 0.0,
            discount: 0,
            tax: 0,
            total: double.tryParse(tx['totalAmount'].toString()) ?? 0.0,
            amountPaid: double.tryParse(tx['totalAmount'].toString()) ?? 0.0,
            paymentMethod: tx['paymentMethod'] ?? 'نقداً',
            createdAt: DateTime.parse(tx['createdAt']),
            type: tx['type'] ?? 'sale',
            cashierName: tx['cashierName'],
          ));
        } catch (err) {
          print("Error mapping sale: $err");
        }
      }
    } catch (e) {
      print("Error loading dashboard stats: $e");
    }

    notifyListeners();
  }

  Future<void> loadSettings() async {
    final settingsMap = await _api.getSettings();
    if (settingsMap.isNotEmpty) {
      _storeName = settingsMap['storeName'] ?? 'سوبر ماركت النيل';
      _storeAddress = settingsMap['address'] ?? 'القاهرة، مصر';
      _storePhone = settingsMap['phone'] ?? '+20 10 0000 0000';
      _storeEmail = settingsMap['email'] ?? 'admin@marketscan.com';
      _taxRate = double.tryParse(settingsMap['taxRate'].toString()) ?? 14.0;
      _notificationsEnabled = settingsMap['notifications'] ?? true;
      _darkModeEnabled = settingsMap['darkMode'] ?? false;
      notifyListeners();
    }
  }

  Future<bool> updateStoreSettings({
    required String name,
    required String address,
    required String phone,
    required String email,
    required double tax,
    required bool notifications,
    required bool darkMode,
  }) async {
    final Map<String, dynamic> payload = {
      'storeName': name,
      'address': address,
      'phone': phone,
      'email': email,
      'taxRate': tax,
      'notifications': notifications,
      'darkMode': darkMode,
    };

    final result = await _api.saveSettings(payload);
    if (result) {
      _storeName = name;
      _storeAddress = address;
      _storePhone = phone;
      _storeEmail = email;
      _taxRate = tax;
      _notificationsEnabled = notifications;
      _darkModeEnabled = darkMode;
      notifyListeners();
      return true;
    }
    return false;
  }

  void setCategory(String category) {
    _selectedCategory = category;
    _updateFilterCaches();
    notifyListeners();
  }

  void setSearchQuery(String query) {
    _searchQuery = query;
    _updateFilterCaches();
    notifyListeners();
  }

  void addToCart(Product product) {
    final index = _cart.indexWhere((item) => item.product.id == product.id);
    if (index >= 0) {
      _cart[index].quantity++;
    } else {
      _cart.add(CartItem(product: product));
    }
    notifyListeners();
  }

  void removeFromCart(String productId) {
    _cart.removeWhere((item) => item.product.id == productId);
    notifyListeners();
  }

  void updateCartQuantity(String productId, int quantity) {
    final index = _cart.indexWhere((item) => item.product.id == productId);
    if (index >= 0) {
      if (quantity <= 0) {
        _cart.removeAt(index);
      } else {
        _cart[index].quantity = quantity;
      }
    }
    notifyListeners();
  }

  void clearCart() {
    _cart.clear();
    notifyListeners();
  }

  Future<Sale?> completeSale(String paymentMethod, double amountPaid) async {
    if (_cart.isEmpty) return null;

    final receiptNumber = 'INV-${(_sales.length + 1).toString().padLeft(3, '0')}';
    final itemsPayload = _cart.map((i) => {
      'barcodeId': i.product.barcode,
      'name': i.product.name,
      'qty': i.quantity,
      'unitPrice': i.product.sellingPrice,
      'lineTotal': i.subtotal,
    }).toList();

    final payload = {
      'items': itemsPayload,
      'totalAmount': cartTotal,
      'paymentMethod': paymentMethod,
    };

    final response = await _api.checkout(payload);
    if (response['success'] == true) {
      final sale = Sale(
        id: response['transactionId'] ?? DateTime.now().millisecondsSinceEpoch.toString(),
        receiptNumber: response['receiptNumber'] ?? receiptNumber,
        items: List.from(_cart),
        subtotal: cartSubtotal,
        discount: 0,
        tax: cartTax,
        total: cartTotal,
        amountPaid: amountPaid,
        paymentMethod: paymentMethod,
        createdAt: DateTime.now(),
      );

      // Decrement stock levels locally
      for (final item in _cart) {
        final pIndex = _products.indexWhere((p) => p.barcode == item.product.barcode);
        if (pIndex >= 0) {
          _products[pIndex].stockQuantity -= item.quantity;
          if (_products[pIndex].stockQuantity < 0) {
            _products[pIndex].stockQuantity = 0;
          }
          await _db.insertProduct(_products[pIndex]); // Sync SQLite
        }
      }

      _sales.add(sale);
      _cart.clear();
      _updateFilterCaches();
      notifyListeners(); // Notify listeners immediately to clear UI block
      loadDashboardStats(); // Refresh dashboard data in the background (unawaited)
      return sale;
    }
    return null;
  }

  Future<bool> addProduct(Product product) async {
    _isLoading = true;
    notifyListeners();

    final success = await _api.addProduct(product.toJson());
    if (success) {
      await _db.insertProduct(product);
      final existingIdx = _products.indexWhere((p) => p.barcode == product.barcode);
      if (existingIdx >= 0) {
        _products[existingIdx] = product;
      } else {
        _products.add(product);
      }
      _updateFilterCaches();
      _isLoading = false;
      notifyListeners();
      loadDashboardStats(); // Run in the background (unawaited)
      return true;
    }

    _isLoading = false;
    notifyListeners();
    return false;
  }

  Future<bool> updateProduct(Product product) async {
    _isLoading = true;
    notifyListeners();

    final success = await _api.updateProduct(product.barcode, product.toJson());
    if (success) {
      await _db.insertProduct(product);
      final idx = _products.indexWhere((p) => p.barcode == product.barcode);
      if (idx >= 0) {
        _products[idx] = product;
      }
      _updateFilterCaches();
      _isLoading = false;
      notifyListeners();
      loadDashboardStats(); // Run in the background (unawaited)
      return true;
    }

    _isLoading = false;
    notifyListeners();
    return false;
  }

  Future<bool> deleteProduct(String barcode) async {
    _isLoading = true;
    notifyListeners();

    final success = await _api.deleteProduct(barcode);
    if (success) {
      await _db.deleteProduct(barcode);
      _products.removeWhere((p) => p.barcode == barcode);
      _updateFilterCaches();
      _isLoading = false;
      notifyListeners();
      loadDashboardStats(); // Run in the background (unawaited)
      return true;
    }

    _isLoading = false;
    notifyListeners();
    return false;
  }

  Future<void> addStock(String productId, int quantity) async {
    final index = _products.indexWhere((p) => p.id == productId);
    if (index >= 0) {
      final barcode = _products[index].barcode;
      final success = await _api.updateStock(barcode, quantity);
      
      if (success) {
        _products[index].stockQuantity += quantity;
        await _db.insertProduct(_products[index]);
        notifyListeners(); // Notify listeners immediately
        loadDashboardStats(); // Run in the background (unawaited)
      }
    }
  }

  Product? findByBarcode(String barcode) {
    try {
      return _products.firstWhere((p) => p.barcode == barcode);
    } catch (_) {
      return null;
    }
  }

  // ─── SHIFT & EXPENSE ACTION METHODS ───
  Future<void> loadActiveShift() async {
    try {
      final res = await _api.getActiveShift();
      if (res['success'] == true && res['shift'] != null) {
        _activeShift = Shift.fromJson(res['shift']);
      } else {
        _activeShift = null;
      }
    } catch (e) {
      print("Error loading active shift: $e");
      _activeShift = null;
    }
    notifyListeners();
  }

  Future<Map<String, dynamic>> openRegister(double startingCash) async {
    try {
      final res = await _api.openShift(startingCash);
      if (res['success'] == true) {
        _activeShift = Shift.fromJson(res['shift']);
        await loadDashboardStats();
        notifyListeners();
        return {'success': true};
      }
      return {'success': false, 'error': res['error'] ?? 'فشل فتح الوردية'};
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  Future<Map<String, dynamic>> closeRegister(double endingCash) async {
    try {
      final res = await _api.closeShift(endingCash);
      if (res['success'] == true) {
        _activeShift = null;
        await loadDashboardStats();
        notifyListeners();
        return {'success': true};
      }
      return {'success': false, 'error': res['error'] ?? 'فشل إغلاق الوردية'};
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  Future<Map<String, dynamic>> recordPettyExpense(double amount, String description) async {
    try {
      final res = await _api.recordExpense(amount, description);
      if (res['success'] == true) {
        await loadDashboardStats();
        notifyListeners();
        return {'success': true};
      }
      return {'success': false, 'error': res['error'] ?? 'فشل تسجيل المصروف'};
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  Future<void> fetchShiftHistory() async {
    try {
      final res = await _api.getShiftHistory();
      if (res['success'] == true) {
        final List<dynamic> list = res['shifts'] ?? [];
        _shiftHistory = list.map((x) => Shift.fromJson(x)).toList();
      }
    } catch (e) {
      print("Error fetching shift history: $e");
    }
    notifyListeners();
  }

  Future<void> logSecurityViolation(String action, String details) async {
    await _api.reportSecurityViolation(action, details);
  }
}
