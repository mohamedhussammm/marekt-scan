import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'db_helper.dart';
import 'api_service.dart';
import '../core/models/models.dart';
import 'package:uuid/uuid.dart';

class SyncEngine extends ChangeNotifier {
  static final SyncEngine instance = SyncEngine._internal();

  final DatabaseHelper _db = DatabaseHelper.instance;
  final ApiService _api = ApiService();
  final Connectivity _connectivity = Connectivity();
  
  int _pendingCount = 0;
  bool _isSyncing = false;
  Timer? _timer;
  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;

  // Backoff retry handling variables
  int _failureCount = 0;
  DateTime? _lastFailureTime;

  int get pendingCount => _pendingCount;
  bool get isSyncing => _isSyncing;

  SyncEngine._internal() {
    _initPendingCount();
  }

  Future<void> _initPendingCount() async {
    _pendingCount = await _db.getPendingCount();
    notifyListeners();
  }

  void startMonitoring() {
    // Poll every 10 seconds for rapid silent background updates
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 10), (_) => flushQueue());
    
    // Also listen to connectivity changes, ensure we cancel existing first
    _connectivitySubscription?.cancel();
    _connectivitySubscription = _connectivity.onConnectivityChanged.listen((List<ConnectivityResult> results) {
      if (!results.contains(ConnectivityResult.none)) {
        flushQueue();
      }
    });
  }

  void stopMonitoring() {
    _timer?.cancel();
    _connectivitySubscription?.cancel();
    _connectivitySubscription = null;
  }

  Future<bool> isOnline() async {
    try {
      final connectivityResult = await _connectivity.checkConnectivity();
      if (connectivityResult.contains(ConnectivityResult.none)) return false;
      
      final host = Uri.parse(ApiService.baseUrl).host;
      if (host.isEmpty) return false;
      
      // Perform actual network lookups to verify real internet connectivity to Vercel
      try {
        final result = await InternetAddress.lookup(host).timeout(const Duration(seconds: 4));
        return result.isNotEmpty && result[0].rawAddress.isNotEmpty;
      } catch (_) {
        // Fall back to true if connectivity is active but lookup fails/timeouts,
        // allowing the actual HTTP requests to attempt connection.
        return true;
      }
    } catch (_) {
      return false;
    }
  }

  Future<void> enqueue(String operation, Map<String, dynamic> payload) async {
    String offlineId;
    if (payload['offline_id'] != null) {
      offlineId = payload['offline_id'].toString();
    } else {
      offlineId = const Uuid().v4();
      payload['offline_id'] = offlineId;
    }
    await _db.insertOfflineOp(offlineId, operation, payload);
    _pendingCount = await _db.getPendingCount();
    notifyListeners();
    // Schedule background flush asynchronously to avoid race conditions with count updates
    Future.microtask(() => flushQueue());
  }

  Future<List<OfflineQueueItem>> getPendingOps() => _db.getPendingOps();

  Future<void> cancelOp(int id) async {
    await _db.deleteOfflineOp(id);
    _pendingCount = await _db.getPendingCount();
    notifyListeners();
  }

  Future<void> flushQueue() async {
    if (_isSyncing) return;

    // Apply exponential backoff check
    if (_failureCount > 0 && _lastFailureTime != null) {
      final backoffSeconds = (10 * (1 << (_failureCount - 1))).clamp(10, 300); // 10s, 20s, 40s, 80s, 160s, 300s
      if (DateTime.now().difference(_lastFailureTime!) < Duration(seconds: backoffSeconds)) {
        return;
      }
    }
    
    final ops = await _db.getPendingOps();
    if (ops.isEmpty) return;

    if (!await isOnline()) return;

    _isSyncing = true;
    notifyListeners();

    try {
      final payload = {
        'operations': ops.map((op) {
          return {
            'id': op.id,
            'type': op.operation,
            'payload': op.payload,
            'retries': op.retries,
          };
        }).toList()
      };

      // Set timeout on batch sync API call
      final result = await _api.syncBatch(payload).timeout(const Duration(seconds: 15));
      
      if (result['success'] == true) {
        final List<dynamic> syncedRaw = result['synced'] ?? [];
        final failed = List<dynamic>.from(result['failed'] ?? []);

        for (final item in syncedRaw) {
          int id;
          String? serverReceiptNumber;
          String? serverCashierName;

          if (item is Map) {
            id = (item['id'] as num).toInt();
            serverReceiptNumber = item['receiptNumber'] as String?;
            serverCashierName = item['cashierName'] as String?;
          } else if (item is num) {
            id = item.toInt();
          } else {
            continue;
          }

          // Resolve actual operation item to cache it locally if checkout
          final matchedOpIndex = ops.indexWhere((o) => o.id == id);
          if (matchedOpIndex >= 0) {
            final matchedOp = ops[matchedOpIndex];
            if (matchedOp.operation == 'checkout') {
              await _cacheSyncedCheckout(
                matchedOp.payload,
                matchedOp.offlineId,
                serverReceiptNumber: serverReceiptNumber,
                serverCashierName: serverCashierName,
              );
            }
            await _db.deleteOfflineOp(id);
          }
        }
        for (final failedOp in failed) {
          await _db.markOpFailed(failedOp['id'] as int, failedOp['retries'] as int);
        }

        // Reset backoff count on successful sync response
        _failureCount = 0;
        _lastFailureTime = null;
      } else {
        _failureCount++;
        _lastFailureTime = DateTime.now();
      }
    } catch (e) {
      _failureCount++;
      _lastFailureTime = DateTime.now();
      debugPrint('SyncEngine error: $e');
    } finally {
      _isSyncing = false;
      _pendingCount = await _db.getPendingCount();
      notifyListeners();
    }
  }

  /// Helper to write offline enqueued items to SQLite transactions when successfully synced
  Future<void> _cacheSyncedCheckout(
    Map<String, dynamic> payload,
    String id, {
    String? serverReceiptNumber,
    String? serverCashierName,
  }) async {
    try {
      final itemsData = payload['items'] as List<dynamic>;
      final receiptNumber = serverReceiptNumber ?? payload['receiptNumber'] ?? 'INV-معلق';
      final cashierName = serverCashierName ?? payload['cashierName'] ?? 'أوفلاين';
      await _db.insertLocalTransaction(
        id: id,
        receiptNumber: receiptNumber,
        totalAmount: (payload['totalAmount'] ?? 0.0).toDouble(),
        amountPaid: payload['amountPaid'] != null ? (payload['amountPaid'] as num).toDouble() : null,
        paymentMethod: payload['paymentMethod'] ?? 'نقداً',
        cashierName: cashierName,
        itemsJson: jsonEncode(itemsData),
        type: 'sale',
        createdAt: DateTime.now(),
        isOffline: false,
        customerId: payload['customerId'] as String?,
        changeReturned: payload['changeReturned'] != null ? (payload['changeReturned'] as num).toDouble() : null,
      );
    } catch (e) {
      debugPrint('Failed to cache synced checkout: $e');
    }
  }
}
