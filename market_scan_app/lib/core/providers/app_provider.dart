import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import '../models/models.dart';
import '../../services/api_service.dart';
import '../../services/db_helper.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'dart:async';
import 'package:uuid/uuid.dart';
import '../../services/sync_engine.dart';

class AppProvider extends ChangeNotifier {
  final ApiService _api = ApiService();
  final DatabaseHelper _db = DatabaseHelper.instance;
  final SyncEngine _syncEngine = SyncEngine.instance;
  
  SyncEngine get syncEngine => _syncEngine;

  /// Expose the ApiService so screens can make their own isolated API calls
  /// (e.g. paginated low-stock fetch) without triggering full provider rebuilds.
  ApiService get api => _api;

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
  int _totalProductsCount = 0;
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
  int get totalProductsCount => _totalProductsCount;
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

        // Save JWT token
        if (result['token'] != null) {
          await ApiService.saveToken(result['token']);
        }

        // Parallel load settings, dashboard stats, active shift in the background
        // to prevent blocking the login completion flow (making the login response instant).
        Future.wait([
          loadSettings(),
          loadDashboardStats(),
          loadActiveShift(),
        ]).catchError((err) {
          debugPrint('Background login loading error: $err');
          return <void>[];
        });
        
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

        // Save JWT token
        if (result['token'] != null) {
          await ApiService.saveToken(result['token']);
        }

        // Parallel load: settings, dashboard stats, active shift.
        // Products are NO longer bulk-loaded here — the inventory screen
        // fetches its own paginated data (Bug #4 fix: no 3200-item payload on login).
        await Future.wait([
          loadSettings(),
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
    ApiService.clearToken();
    _db.clearAllProducts(); // Clear SQLite cache to isolate data
    _db.clearAllTransactions(); // Clear local transactions cache on logout for privacy/isolation
    _updateFilterCaches();
    notifyListeners();
  }

  Future<void> loadProducts() async {
    // P1 fix: removed notifyListeners() at start with _isLoading=true.
    // That was triggering a full rebuild BEFORE data was ready — pointless.
    // One notification at the end is enough.
    _isLoading = true;

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
    notifyListeners(); // Single notification with final state
  }

  Future<void> loadDashboardStats({bool rethrowNetworkErrors = false}) async {
    try {
      final results = await Future.wait([
        _api.getDashboardSummary(),
        _api.getWeeklyChart(),
        _api.getTopProducts(),
        _api.getSalesByCategory(),
      ]);

      final summary = results[0] as Map<String, dynamic>;
      final chart = results[1] as List<double>;
      final topProds = results[2] as List<dynamic>;
      final catAgg = results[3] as List<dynamic>;

      if (summary['success'] == true) {
        _todaySalesTotal = double.tryParse(summary['todayRevenue'].toString()) ?? 0.0;
        _todayOrdersCount = int.tryParse(summary['todayOrdersCount'].toString()) ?? 0;
        _allTimeRevenue = double.tryParse(summary['totalRevenue'].toString()) ?? 0.0;
        _netProfit = double.tryParse(summary['netProfit'].toString()) ?? 0.0;
        _totalOrdersCount = int.tryParse(summary['totalOrders'].toString()) ?? 0;
        _lowStockCount = int.tryParse(summary['lowStockCount'].toString()) ?? 0;
        _totalProductsCount = int.tryParse(summary['totalProductsCount'].toString()) ?? 0;
        _todayExpenses = double.tryParse((summary['todayExpenses'] ?? 0).toString()) ?? 0.0;
        _cashOnHand = double.tryParse((summary['cashOnHand'] ?? 0).toString()) ?? 0.0;

        // Persist counts to shared_preferences for robust offline dashboard loading
        SharedPreferences.getInstance().then((prefs) {
          prefs.setInt('cached_total_products', _totalProductsCount);
          prefs.setInt('cached_low_stock', _lowStockCount);
        }).catchError((_) {});
      }

      _weeklySales = chart;
      _topProductsList = topProds;
      _categoriesAggregationList = catAgg;

      // Fetch transactions separately so a failure here doesn't crash the other dashboard cards
      try {
        final List<Sale> tempSales = [];

        // 1. First, load offline transactions from the local database
        final localTxList = await _db.getLocalTransactions(limit: 10, skip: 0);
        for (final tx in localTxList) {
          if (tx['is_offline'] == 1) {
            try {
              final List<dynamic> itemsData = jsonDecode(tx['items_json'] as String);
              final items = itemsData.map((it) {
                final double price = (it['unitPrice'] ?? 0.0).toDouble();
                final int qty = (it['qty'] ?? 1).toInt();
                return CartItem(
                  product: findByBarcode(it['barcodeId']) ?? Product(
                    id: it['barcodeId'] ?? 'item',
                    barcode: it['barcodeId'] ?? 'item',
                    name: it['name'] ?? '',
                    category: 'عام',
                    costPrice: price * 0.7,
                    sellingPrice: price,
                    stockQuantity: 100,
                    minStockLevel: 10,
                  ),
                  quantity: qty,
                );
              }).toList();

              tempSales.add(Sale(
                id: tx['id'],
                receiptNumber: tx['receipt_number'] ?? 'INV-معلق',
                items: items,
                subtotal: (tx['total_amount'] ?? 0.0).toDouble(),
                discount: 0,
                tax: 0,
                total: (tx['total_amount'] ?? 0.0).toDouble(),
                amountPaid: (tx['total_amount'] ?? 0.0).toDouble(),
                paymentMethod: tx['payment_method'] ?? 'نقداً',
                createdAt: DateTime.parse(tx['created_at']),
                type: tx['type'] ?? 'sale',
                cashierName: tx['cashier_name'] ?? 'أوفلاين',
                isOffline: true,
              ));
            } catch (_) {}
          }
        }

        // 2. Fetch server transactions and merge them (skipping duplicates)
        final txsList = await _api.getTransactions(limit: 10).timeout(const Duration(seconds: 8));
        for (final tx in txsList) {
          try {
            final offlineId = tx['offline_id'] ?? tx['offlineId'];
            
            // Remove any pending local/offline transaction in tempSales that matches this server transaction
            tempSales.removeWhere((s) {
              if (s.id == tx['_id']) {
                return true;
              }
              if (offlineId != null && s.id == offlineId) {
                return true;
              }
              if (tx['receiptNumber'] != null &&
                  tx['receiptNumber'] != 'INV-معلق' &&
                  tx['receiptNumber'] != 'REC-000' &&
                  s.receiptNumber == tx['receiptNumber']) {
                return true;
              }
              return false;
            });

            // Skip if it's already in tempSales (double-guard)
            final isDuplicate = tempSales.any((s) {
              if (s.id == tx['_id']) {
                return true;
              }
              if (offlineId != null && s.id == offlineId) {
                return true;
              }
              if (tx['receiptNumber'] != null &&
                  tx['receiptNumber'] != 'INV-معلق' &&
                  tx['receiptNumber'] != 'REC-000' &&
                  s.receiptNumber == tx['receiptNumber']) {
                return true;
              }
              return false;
            });

            if (isDuplicate) {
              continue;
            }

            final List<dynamic> itemsData = tx['items'] ?? [];
            final items = itemsData.map((it) {
              final double price = (it['unitPrice'] ?? 0).toDouble();
              final int qty = (it['qty'] ?? 1).toInt();
              final prod = findByBarcode(it['barcodeId']) ?? Product(
                id: it['barcodeId'],
                barcode: it['barcodeId'],
                name: it['name'],
                category: 'عام',
                costPrice: price * 0.7,
                sellingPrice: price,
                stockQuantity: 100,
                minStockLevel: 10,
              );
              return CartItem(product: prod, quantity: qty);
            }).toList();

            tempSales.add(Sale(
              id: offlineId ?? tx['_id'],
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
            debugPrint("Error mapping sale: $err");
          }
        }

        // 3. Retain any optimistic sales currently in _sales that have not yet loaded from server/DB
        for (final sale in _sales) {
          final isAlreadyLoaded = tempSales.any((s) {
            if (s.id == sale.id) {
              return true;
            }
            if (sale.receiptNumber != 'INV-معلق' &&
                sale.receiptNumber != 'REC-000' &&
                s.receiptNumber == sale.receiptNumber) {
              return true;
            }
            return false;
          });
          if (!isAlreadyLoaded) {
            tempSales.add(sale);
          }
        }

        // Sort by createdAt descending
        tempSales.sort((a, b) => b.createdAt.compareTo(a.createdAt));
        _sales.clear();
        _sales.addAll(tempSales.take(10));
      } catch (txError) {
        debugPrint("Failed to fetch online transactions for dashboard, trying local cache: $txError");
        await _loadSalesFromLocalCache();
      }
    } catch (e) {
      // Offline fallback: load count metrics from cached shared preferences or SQLite
      try {
        final prefs = await SharedPreferences.getInstance();
        _totalProductsCount = prefs.getInt('cached_total_products') ?? await _db.getProductCount();
        _lowStockCount = prefs.getInt('cached_low_stock') ?? await _db.getLowStockCount();
      } catch (dbErr) {
        debugPrint('Failed to load offline counts: $dbErr');
      }

      // Also fall back to local SQLite transactions cache for recent sales
      await _loadSalesFromLocalCache();

      // Rethrow network-level errors only if requested, so callers (e.g. dashboard timer) can
      // detect offline state and apply backoff. Otherwise, swallow/log to prevent unhandled async crashes.
      final errStr = e.toString();
      final isNetworkError = e is SocketException || errStr.contains('SocketException') || errStr.contains('Connection failed') || errStr.contains('timeout') || errStr.contains('TimeoutException');
      if (rethrowNetworkErrors && isNetworkError) {
        rethrow;
      }
      debugPrint('loadDashboardStats error: $e');
    }

    notifyListeners();
  }

  void addLocalSale(Sale sale) {
    _sales.insert(0, sale);
    if (_sales.length > 10) {
      _sales.removeLast();
    }
    _totalOrdersCount++;
    _todayOrdersCount++;
    _todaySalesTotal += sale.total;
    notifyListeners();
  }

  Future<void> _loadSalesFromLocalCache() async {
    try {
      final localTxList = await _db.getLocalTransactions(limit: 10, skip: 0);
      final List<Sale> cachedSales = [];
      for (final tx in localTxList) {
        try {
          final List<dynamic> itemsData = jsonDecode(tx['items_json'] as String);
          final items = itemsData.map((it) {
            final double price = (it['unitPrice'] ?? 0.0).toDouble();
            final int qty = (it['qty'] ?? 1).toInt();
            return CartItem(
              product: findByBarcode(it['barcodeId']) ?? Product(
                id: it['barcodeId'] ?? 'item',
                barcode: it['barcodeId'] ?? 'item',
                name: it['name'] ?? '',
                category: 'عام',
                costPrice: price * 0.7,
                sellingPrice: price,
                stockQuantity: 100,
                minStockLevel: 10,
              ),
              quantity: qty,
            );
          }).toList();

          cachedSales.add(Sale(
            id: tx['id'],
            receiptNumber: tx['receipt_number'],
            items: items,
            subtotal: (tx['total_amount'] ?? 0.0).toDouble(),
            discount: 0,
            tax: 0,
            total: (tx['total_amount'] ?? 0.0).toDouble(),
            amountPaid: (tx['total_amount'] ?? 0.0).toDouble(),
            paymentMethod: tx['payment_method'] ?? 'نقداً',
            createdAt: DateTime.parse(tx['created_at']),
            type: tx['type'] ?? 'sale',
            cashierName: tx['cashier_name'] ?? 'أوفلاين',
            isOffline: tx['is_offline'] == 1,
          ));
        } catch (_) {}
      }
      _sales.clear();
      _sales.addAll(cachedSales);
    } catch (e) {
      debugPrint('Failed to load sales from local cache: $e');
    }
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

    final receiptNumber = 'INV-${DateTime.now().millisecondsSinceEpoch.toString().substring(5)}';
    final offlineId = const Uuid().v4();
    
    final itemsPayload = _cart.map((i) {
      return {
        'barcodeId': i.product.barcode,
        'name': i.product.name,
        'qty': i.quantity,
        'unitPrice': i.product.sellingPrice,
        'lineTotal': i.subtotal,
      };
    }).toList();

    final payload = {
      'offline_id': offlineId,
      'items': itemsPayload,
      'totalAmount': cartTotal,
      'paymentMethod': paymentMethod,
    };

    final sale = Sale(
      id: offlineId,
      receiptNumber: receiptNumber,
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

    try {
      final response = await _api.checkout(payload).timeout(const Duration(seconds: 8));
      if (response['success'] == true) {
        sale.isOffline = false;
        // Optionally update the sale ID if server returned one
        loadDashboardStats(); // Refresh dashboard data in the background
      } else {
        sale.isOffline = true;
        await _syncEngine.enqueue('checkout', payload);
      }
    } on SocketException catch (_) {
      sale.isOffline = true;
      await _syncEngine.enqueue('checkout', payload);
    } on TimeoutException catch (_) {
      sale.isOffline = true;
      await _syncEngine.enqueue('checkout', payload);
    } catch (_) {
      sale.isOffline = true;
      await _syncEngine.enqueue('checkout', payload);
    }

    return sale;
  }

  Future<bool> addProduct(Product product) async {
    _isLoading = true;

    final offlineId = const Uuid().v4();
    final payload = product.toJson();
    payload['offline_id'] = offlineId;

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

    try {
      final success = await _api.addProduct(payload).timeout(const Duration(seconds: 8));
      if (!success) {
        await _syncEngine.enqueue('add_product', payload);
      } else {
        loadDashboardStats(); // Run in the background (unawaited)
      }
    } catch (_) {
      await _syncEngine.enqueue('add_product', payload);
    }
    
    return true;
  }

  Future<bool> updateProduct(Product product) async {
    _isLoading = true;

    final offlineId = const Uuid().v4();
    final payload = product.toJson();
    payload['offline_id'] = offlineId;

    await _db.insertProduct(product);
    final idx = _products.indexWhere((p) => p.barcode == product.barcode);
    if (idx >= 0) {
      _products[idx] = product;
    }
    _updateFilterCaches();
    _isLoading = false;
    notifyListeners();

    try {
      final success = await _api.updateProduct(product.barcode, payload).timeout(const Duration(seconds: 8));
      if (!success) {
        await _syncEngine.enqueue('update_product', payload);
      } else {
        loadDashboardStats(); // Run in the background (unawaited)
      }
    } catch (_) {
      await _syncEngine.enqueue('update_product', payload);
    }

    return true;
  }

  Future<bool> deleteProduct(String barcode) async {
    _isLoading = true;
    
    final offlineId = const Uuid().v4();
    final payload = {'barcodeId': barcode, 'offline_id': offlineId};

    await _db.deleteProduct(barcode);
    _products.removeWhere((p) => p.barcode == barcode);
    _updateFilterCaches();
    _isLoading = false;
    notifyListeners();

    try {
      final success = await _api.deleteProduct(barcode).timeout(const Duration(seconds: 8));
      if (!success) {
        await _syncEngine.enqueue('delete_product', payload);
      } else {
        loadDashboardStats(); // Run in the background (unawaited)
      }
    } catch (_) {
      await _syncEngine.enqueue('delete_product', payload);
    }

    return true;
  }

  Future<void> addStock(String productId, int quantity) async {
    final index = _products.indexWhere((p) => p.id == productId);
    if (index >= 0) {
      final barcode = _products[index].barcode;
      final offlineId = const Uuid().v4();
      final payload = {'barcodeId': barcode, 'quantity': quantity, 'offline_id': offlineId};

      _products[index].stockQuantity += quantity;
      await _db.insertProduct(_products[index]);
      notifyListeners(); // Notify listeners immediately

      try {
        final success = await _api.updateStock(barcode, quantity).timeout(const Duration(seconds: 8));
        if (!success) {
          await _syncEngine.enqueue('update_stock', payload);
        } else {
          loadDashboardStats(); // Run in the background (unawaited)
        }
      } catch (_) {
        await _syncEngine.enqueue('update_stock', payload);
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
      debugPrint("Error loading active shift: $e");
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

  Future<Map<String, dynamic>> recordPettyExpense(double amount, String description, {String category = 'أخرى'}) async {
    final offlineId = const Uuid().v4();
    final payload = {
      'amount': amount,
      'description': description,
      'category': category,
      'offline_id': offlineId,
    };

    // Optimistically assume it works (no local state for expenses beyond dashboard stats)
    
    try {
      final res = await _api.recordExpense(amount, description, category: category).timeout(const Duration(seconds: 8));
      if (res['success'] == true) {
        loadDashboardStats();
        notifyListeners();
        return {'success': true, 'isOffline': false};
      } else {
        await _syncEngine.enqueue('add_expense', payload);
        return {'success': true, 'isOffline': true};
      }
    } catch (e) {
      await _syncEngine.enqueue('add_expense', payload);
      return {'success': true, 'isOffline': true};
    }
  }

  Future<List<PettyExpense>> fetchAllExpenses({String? category}) async {
    return await _api.getExpenses(all: true, category: category);
  }

  Future<List<PettyExpense>> getOfflineExpenses() async {
    return await _db.getOfflineExpenses();
  }

  Future<List<Map<String, dynamic>>> fetchExpenseCategorySummary() async {
    return await _api.getExpenseCategorySummary();
  }

  Future<void> fetchShiftHistory() async {
    try {
      final res = await _api.getShiftHistory();
      if (res['success'] == true) {
        final List<dynamic> list = res['shifts'] ?? [];
        _shiftHistory = list.map((x) => Shift.fromJson(x)).toList();
      }
    } catch (e) {
      debugPrint("Error fetching shift history: $e");
    }
    notifyListeners();
  }

  Future<void> logSecurityViolation(String action, String details) async {
    await _api.reportSecurityViolation(action, details);
  }
}
