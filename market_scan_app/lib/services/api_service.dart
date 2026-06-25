import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../core/models/models.dart';
import 'db_helper.dart';

class ApiService {
  // Support build-time overrides via --dart-define=API_URL=...
  // Fallback: permanent ngrok tunnel (works from ANY network)
  static const String _defaultBaseUrl = String.fromEnvironment(
    'API_URL',
    defaultValue: 'https://anytime-font-drainable.ngrok-free.dev/api',
  );

  // Runtime override — set via Settings screen, persisted in SharedPreferences
  static String _serverUrl = _defaultBaseUrl;

  static String get baseUrl => _serverUrl;

  /// Normalize and format the input URL to be a valid HTTP/HTTPS endpoint
  static String? _normalizeUrl(String url) {
    var cleaned = url.trim();
    if (cleaned.isEmpty) return null;

    // If it already has http:// or https://, check if it's relative/corrupted
    if (cleaned.startsWith('http://') || cleaned.startsWith('https://')) {
      try {
        final uri = Uri.parse(cleaned);
        // Ensure it has a host (not a relative path like http://auth/login...)
        if (uri.host.isNotEmpty) {
          return cleaned;
        }
      } catch (_) {}
      return null; // Corrupted
    }

    // If it's a raw IP/domain (e.g. "192.168.1.22:3000" or "anytime-font-drainable.ngrok-free.dev")
    // Prepend http:// to make it a valid URI
    if (!cleaned.contains('/')) {
      return 'http://$cleaned';
    }

    // If it contains slashes but no scheme, try prepending http://
    try {
      final prepended = 'http://$cleaned';
      final uri = Uri.parse(prepended);
      if (uri.host.isNotEmpty) {
        return prepended;
      }
    } catch (_) {}

    return null; // Invalid
  }

  /// Call once at app startup to load any saved custom URL and JWT token
  static Future<void> initServerIp() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString('server_ip');
    if (saved != null && saved.isNotEmpty) {
      final normalized = _normalizeUrl(saved);
      if (normalized != null) {
        _serverUrl = normalized;
      } else {
        // Automatically discard corrupted setting and fallback to default
        _serverUrl = _defaultBaseUrl;
        await prefs.remove('server_ip');
      }
    }
    _authToken = prefs.getString('jwt_token');
  }

  /// Called from Settings screen when user saves a new URL
  static Future<void> updateServerIp(String newUrl) async {
    final normalized = _normalizeUrl(newUrl);
    final prefs = await SharedPreferences.getInstance();
    if (normalized != null) {
      _serverUrl = normalized;
      await prefs.setString('server_ip', _serverUrl);
    } else {
      // If invalid, fallback to default
      _serverUrl = _defaultBaseUrl;
      await prefs.remove('server_ip');
    }
  }

  /// Reset back to the default URL
  static Future<void> resetToDefault() async {
    _serverUrl = _defaultBaseUrl;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('server_ip');
  }

  // Blazing Fast Shared Persistent HTTP Connection Pool
  static final http.Client _client = http.Client();
  static String? _authToken;

  static String? get token => _authToken;

  static Future<void> saveToken(String token) async {
    _authToken = token;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('jwt_token', token);
  }

  static Future<void> clearToken() async {
    _authToken = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('jwt_token');
  }

  Map<String, String> _headers([bool withJson = false]) {
    final headers = {
      'Connection': 'keep-alive',
      'Accept': 'application/json',
      'ngrok-skip-browser-warning': 'true',
    };
    if (_authToken != null) {
      headers['Authorization'] = 'Bearer $_authToken';
    }
    if (withJson) {
      headers['Content-Type'] = 'application/json';
    }
    return headers;
  }

  Future<Map<String, dynamic>> login(String username, String password) async {
    try {
      final response = await _client.post(
        Uri.parse('$baseUrl/auth/login'),
        headers: _headers(true),
        body: json.encode({
          'username': username,
          'password': password,
        }),
      );
      return json.decode(response.body);
    } catch (e) {
      debugPrint('API Error (login): $e');
      return {'success': false, 'error': e.toString()};
    }
  }

  Future<Map<String, dynamic>> register({
    required String username,
    required String password,
    required String email,
    required String storeName,
    required String role,
  }) async {
    try {
      final response = await _client.post(
        Uri.parse('$baseUrl/auth/register'),
        headers: _headers(true),
        body: json.encode({
          'username': username,
          'password': password,
          'email': email,
          'storeName': storeName,
          'role': role,
        }),
      );
      return json.decode(response.body);
    } catch (e) {
      debugPrint('API Error (register): $e');
      return {'success': false, 'error': e.toString()};
    }
  }

  // ─── SHIFT MANAGEMENT API CALLS ───
  Future<Map<String, dynamic>> getActiveShift() async {
    try {
      final response = await _client.get(
        Uri.parse('$baseUrl/shifts/active'),
        headers: _headers(),
      );
      return json.decode(response.body);
    } catch (e) {
      debugPrint('API Error (getActiveShift): $e');
      return {'success': false, 'error': e.toString()};
    }
  }

  Future<Map<String, dynamic>> openShift(double startingCash) async {
    try {
      final response = await _client.post(
        Uri.parse('$baseUrl/shifts/open'),
        headers: _headers(true),
        body: json.encode({'startingCash': startingCash}),
      );
      return json.decode(response.body);
    } catch (e) {
      debugPrint('API Error (openShift): $e');
      return {'success': false, 'error': e.toString()};
    }
  }

  Future<Map<String, dynamic>> closeShift(double endingCash) async {
    try {
      final response = await _client.post(
        Uri.parse('$baseUrl/shifts/close'),
        headers: _headers(true),
        body: json.encode({'endingCash': endingCash}),
      );
      return json.decode(response.body);
    } catch (e) {
      debugPrint('API Error (closeShift): $e');
      return {'success': false, 'error': e.toString()};
    }
  }

  Future<Map<String, dynamic>> getShiftHistory() async {
    try {
      final response = await _client.get(
        Uri.parse('$baseUrl/shifts/history'),
        headers: _headers(),
      );
      return json.decode(response.body);
    } catch (e) {
      debugPrint('API Error (getShiftHistory): $e');
      return {'success': false, 'error': e.toString()};
    }
  }

  // ─── PETTY CASH EXPENSE API CALLS ───
  Future<Map<String, dynamic>> recordExpense(double amount, String description, {String category = 'أخرى'}) async {
    try {
      final response = await _client.post(
        Uri.parse('$baseUrl/expenses'),
        headers: _headers(true),
        body: json.encode({
          'amount': amount,
          'description': description,
          'category': category,
        }),
      );
      return json.decode(response.body);
    } catch (e) {
      debugPrint('API Error (recordExpense): $e');
      return {'success': false, 'error': e.toString()};
    }
  }

  Future<List<PettyExpense>> getExpenses({bool all = false, String? category}) async {
    try {
      String url = '$baseUrl/expenses?all=$all';
      if (category != null) {
        url += '&category=${Uri.encodeComponent(category)}';
      }
      final response = await _client.get(
        Uri.parse(url),
        headers: _headers(true),
      );
      final data = json.decode(response.body);
      if (data['success'] == true) {
        final List<dynamic> list = data['expenses'] ?? [];
        return list.map((item) => PettyExpense.fromJson(item)).toList();
      }
      return [];
    } catch (e) {
      debugPrint('API Error (getExpenses): $e');
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> getExpenseCategorySummary() async {
    try {
      final response = await _client.get(
        Uri.parse('$baseUrl/expenses/category-summary'),
        headers: _headers(true),
      );
      final data = json.decode(response.body);
      if (data['success'] == true) {
        final List<dynamic> list = data['summary'] ?? [];
        return list.map((item) => Map<String, dynamic>.from(item)).toList();
      }
      return [];
    } catch (e) {
      debugPrint('API Error (getExpenseCategorySummary): $e');
      return [];
    }
  }

  // ─── SECURITY AUDITING API CALLS ───
  Future<void> reportSecurityViolation(String action, String details) async {
    try {
      await _client.post(
        Uri.parse('$baseUrl/logs/restricted'),
        headers: _headers(true),
        body: json.encode({
          'action': action,
          'details': details,
        }),
      );
    } catch (e) {
      debugPrint('API Error (reportSecurityViolation): $e');
    }
  }

  Future<Product?> getProductByBarcode(String barcode) async {
    try {
      final response = await _client.get(
        Uri.parse('$baseUrl/products/$barcode'),
        headers: _headers(),
      );
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return Product.fromJson(data['product']);
      }
      return null;
    } catch (e) {
      debugPrint('API Error (getProductByBarcode): $e');
      return null;
    }
  }

  /// Fetches only low-stock products from the server — paginated.
  /// The backend does the filtering with MongoDB ($lte currentStock minThreshold),
  /// so we never load all 3200 products into memory.
  /// Returns a map with keys: 'products' (List<Product>), 'total' (int), 'hasMore' (bool).
  Future<Map<String, dynamic>> getLowStockProducts({
    int page = 1,
    int limit = 30,
  }) async {
    try {
      final response = await _client.get(
        Uri.parse('$baseUrl/products/low-stock?page=$page&limit=$limit'),
        headers: _headers(),
      );
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final List<dynamic> rawList = data['products'] ?? [];
        final pagination = data['pagination'] ?? {};
        return {
          'products': rawList.map((j) => Product.fromJson(j)).toList(),
          'total': (pagination['total'] ?? 0) as int,
          'hasMore': (pagination['hasMore'] ?? false) as bool,
        };
      }
      return {'products': <Product>[], 'total': 0, 'hasMore': false};
    } catch (e) {
      debugPrint('API Error (getLowStockProducts): $e');
      rethrow; // Let the screen's catch block show the error state
    }
  }

  /// Paginated product fetch for the inventory screen.
  /// Search and category filtering is done on the server (MongoDB regex) —
  /// no 3200-product payload, no client-side filter loop.
  Future<Map<String, dynamic>> getProductsPaginated({
    int page = 1,
    int limit = 40,
    String search = '',
    String category = '',
  }) async {
    try {
      final params = <String, String>{
        'page': '$page',
        'limit': '$limit',
        if (search.isNotEmpty) 'search': search,
        if (category.isNotEmpty && category != 'الكل') 'category': category,
      };
      final uri = Uri.parse('$baseUrl/products').replace(queryParameters: params);
      final response = await _client.get(uri, headers: _headers()).timeout(const Duration(seconds: 8));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final List<dynamic> rawList = data['products'] ?? [];
        final pagination = data['pagination'] ?? {};
        return {
          'products': rawList.map((j) => Product.fromJson(j)).toList(),
          'total':   (pagination['total']   ?? 0) as int,
          'hasMore': (pagination['hasMore'] ?? false) as bool,
          'fromCache': false,
        };
      }
      return {'products': <Product>[], 'total': 0, 'hasMore': false, 'fromCache': false};
    } catch (_) {
      // ── OFFLINE FALLBACK: serve from SQLite ────────────────────────
      final DatabaseHelper db = DatabaseHelper.instance;
      final allCached = await db.getAllProducts();

      // Apply search and category filter locally
      final filtered = allCached.where((p) {
        final matchSearch = search.isEmpty ||
            p.name.toLowerCase().contains(search.toLowerCase()) ||
            p.barcode.toLowerCase().contains(search.toLowerCase());
        final matchCategory = category.isEmpty || category == 'الكل' || p.category == category;
        return matchSearch && matchCategory;
      }).toList();

      // Paginate locally
      final start = (page - 1) * limit;
      final end = (start + limit).clamp(0, filtered.length);
      final pageItems = start < filtered.length ? filtered.sublist(start, end) : <Product>[];

      return {
        'products': pageItems,
        'total': filtered.length,
        'hasMore': end < filtered.length,
        'fromCache': true,
      };
    }
  }

  Future<List<Product>> getAllProducts() async {
    try {
      final response = await _client.get(
        Uri.parse('$baseUrl/products'),
        headers: _headers(),
      );
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final List<dynamic> list = data['products'] ?? [];
        return list.map((json) => Product.fromJson(json)).toList();
      }
      return [];
    } catch (e) {
      debugPrint('API Error (getAllProducts): $e');
      return [];
    }
  }


  Future<bool> addProduct(Map<String, dynamic> payload) async {
    try {
      final response = await _client.post(
        Uri.parse('$baseUrl/products'),
        headers: _headers(true),
        body: json.encode(payload),
      );
      return response.statusCode == 201;
    } catch (e) {
      debugPrint('API Error (addProduct): $e');
      return false;
    }
  }

  Future<bool> updateProduct(
      String barcode, Map<String, dynamic> payload) async {
    try {
      final response = await _client.put(
        Uri.parse('$baseUrl/products/$barcode'),
        headers: _headers(true),
        body: json.encode(payload),
      );
      return response.statusCode == 200;
    } catch (e) {
      debugPrint('API Error (updateProduct): $e');
      return false;
    }
  }

  Future<bool> deleteProduct(String barcode) async {
    try {
      final response = await _client.delete(
        Uri.parse('$baseUrl/products/$barcode'),
        headers: _headers(),
      );
      return response.statusCode == 200;
    } catch (e) {
      debugPrint('API Error (deleteProduct): $e');
      return false;
    }
  }

  Future<bool> updateStock(String barcode, int quantity) async {
    try {
      final response = await _client.put(
        Uri.parse('$baseUrl/products/$barcode/stock'),
        headers: _headers(true),
        body: json.encode({'quantity': quantity}),
      );
      return response.statusCode == 200;
    } catch (e) {
      debugPrint('API Error (updateStock): $e');
      return false;
    }
  }

  Future<Map<String, dynamic>> checkout(Map<String, dynamic> payload) async {
    try {
      final response = await _client.post(
        Uri.parse('$baseUrl/transactions'),
        headers: _headers(true),
        body: json.encode(payload),
      );
      return json.decode(response.body);
    } catch (e) {
      debugPrint('API Error (checkout): $e');
      return {'success': false, 'error': e.toString()};
    }
  }

  Future<List<dynamic>> getTransactions({int limit = 0, int skip = 0}) async {
    try {
      String url = '$baseUrl/transactions';
      final queryParams = <String>[];
      if (limit > 0) queryParams.add('limit=$limit');
      if (skip > 0) queryParams.add('skip=$skip');
      if (queryParams.isNotEmpty) {
        url += '?${queryParams.join('&')}';
      }

      final response = await _client.get(
        Uri.parse(url),
        headers: _headers(),
      );
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data['transactions'] ?? [];
      }
      return [];
    } catch (e) {
      debugPrint('API Error (getTransactions): $e');
      return [];
    }
  }

  Future<Map<String, dynamic>> getDashboardSummary() async {
    try {
      final response = await _client.get(
        Uri.parse('$baseUrl/reports/summary'),
        headers: _headers(),
      );
      if (response.statusCode == 200) {
        return json.decode(response.body);
      }
      return {'success': false};
    } catch (e) {
      debugPrint('API Error (getDashboardSummary): $e');
      return {'success': false};
    }
  }

  Future<List<double>> getWeeklyChart() async {
    try {
      final response = await _client.get(
        Uri.parse('$baseUrl/reports/weekly-chart'),
        headers: _headers(),
      );
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final List<dynamic> list = data['data'] ?? [];
        return list
            .map((val) => double.tryParse(val.toString()) ?? 0.0)
            .toList();
      }
      return List.filled(7, 0.0);
    } catch (e) {
      debugPrint('API Error (getWeeklyChart): $e');
      return List.filled(7, 0.0);
    }
  }

  Future<List<dynamic>> getTopProducts() async {
    try {
      final response = await _client.get(
        Uri.parse('$baseUrl/reports/top-products'),
        headers: _headers(),
      );
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data['topProducts'] ?? [];
      }
      return [];
    } catch (e) {
      debugPrint('API Error (getTopProducts): $e');
      return [];
    }
  }

  Future<List<dynamic>> getSalesByCategory() async {
    try {
      final response = await _client.get(
        Uri.parse('$baseUrl/reports/by-category'),
        headers: _headers(),
      );
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data['categories'] ?? [];
      }
      return [];
    } catch (e) {
      debugPrint('API Error (getSalesByCategory): $e');
      return [];
    }
  }

  Future<Map<String, dynamic>> getSettings() async {
    try {
      final response = await _client.get(
        Uri.parse('$baseUrl/settings'),
        headers: _headers(),
      );
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data['settings'] ?? {};
      }
      return {};
    } catch (e) {
      debugPrint('API Error (getSettings): $e');
      return {};
    }
  }

  Future<bool> saveSettings(Map<String, dynamic> payload) async {
    try {
      final response = await _client.put(
        Uri.parse('$baseUrl/settings'),
        headers: _headers(true),
        body: json.encode(payload),
      );
      return response.statusCode == 200;
    } catch (e) {
      debugPrint('API Error (saveSettings): $e');
      return false;
    }
  }
  Future<Map<String, dynamic>> syncBatch(Map<String, dynamic> payload) async {
    try {
      final response = await _client.post(
        Uri.parse('$baseUrl/sync/batch'),
        headers: _headers(true),
        body: json.encode(payload),
      );
      return json.decode(response.body);
    } catch (e) {
      debugPrint('API Error (syncBatch): $e');
      return {'success': false, 'error': e.toString()};
    }
  }
}
