import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../core/models/models.dart';

class ApiService {
  // Default: permanent ngrok tunnel (works from ANY network)
  static const String _defaultBaseUrl =
      'https://anytime-font-drainable.ngrok-free.dev/api';

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

  /// Call once at app startup to load any saved custom URL
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

  /// Reset back to the default ngrok URL
  static Future<void> resetToDefault() async {
    _serverUrl = _defaultBaseUrl;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('server_ip');
  }

  // Blazing Fast Shared Persistent HTTP Connection Pool
  static final http.Client _client = http.Client();
  static String? currentStoreName;
  static String? currentUserRole;
  static String? currentUsername;

  Map<String, String> _headers([bool withJson = false]) {
    final headers = {
      'Connection': 'keep-alive',
      'Accept': 'application/json',
      'ngrok-skip-browser-warning': 'true',
    };
    if (currentStoreName != null) {
      headers['x-store-name'] = Uri.encodeComponent(currentStoreName!);
    }
    if (currentUserRole != null) {
      headers['x-user-role'] = currentUserRole!;
    }
    if (currentUsername != null) {
      headers['x-username'] = Uri.encodeComponent(currentUsername!);
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
      print('API Error (login): $e');
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
      print('API Error (register): $e');
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
      print('API Error (getActiveShift): $e');
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
      print('API Error (openShift): $e');
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
      print('API Error (closeShift): $e');
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
      print('API Error (getShiftHistory): $e');
      return {'success': false, 'error': e.toString()};
    }
  }

  // ─── PETTY CASH EXPENSE API CALLS ───
  Future<Map<String, dynamic>> recordExpense(double amount, String description) async {
    try {
      final response = await _client.post(
        Uri.parse('$baseUrl/expenses'),
        headers: _headers(true),
        body: json.encode({
          'amount': amount,
          'description': description,
        }),
      );
      return json.decode(response.body);
    } catch (e) {
      print('API Error (recordExpense): $e');
      return {'success': false, 'error': e.toString()};
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
      print('API Error (reportSecurityViolation): $e');
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
      print('API Error (getProductByBarcode): $e');
      return null;
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
      print('API Error (getAllProducts): $e');
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
      print('API Error (addProduct): $e');
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
      print('API Error (updateProduct): $e');
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
      print('API Error (deleteProduct): $e');
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
      print('API Error (updateStock): $e');
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
      print('API Error (checkout): $e');
      return {'success': false, 'error': e.toString()};
    }
  }

  Future<List<dynamic>> getTransactions({int limit = 0}) async {
    try {
      final url = limit > 0
          ? '$baseUrl/transactions?limit=$limit'
          : '$baseUrl/transactions';
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
      print('API Error (getTransactions): $e');
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
      print('API Error (getDashboardSummary): $e');
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
      print('API Error (getWeeklyChart): $e');
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
      print('API Error (getTopProducts): $e');
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
      print('API Error (getSalesByCategory): $e');
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
      print('API Error (getSettings): $e');
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
      print('API Error (saveSettings): $e');
      return false;
    }
  }
}
