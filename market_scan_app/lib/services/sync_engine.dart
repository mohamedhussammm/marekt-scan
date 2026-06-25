import 'dart:async';
import 'package:flutter/material.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'db_helper.dart';
import 'api_service.dart';
import '../core/models/models.dart';

class SyncEngine extends ChangeNotifier {
  static final SyncEngine instance = SyncEngine._internal();

  final DatabaseHelper _db = DatabaseHelper.instance;
  final ApiService _api = ApiService();
  final Connectivity _connectivity = Connectivity();
  
  int _pendingCount = 0;
  bool _isSyncing = false;
  Timer? _timer;

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
    
    // Also listen to connectivity changes
    _connectivity.onConnectivityChanged.listen((List<ConnectivityResult> results) {
      if (!results.contains(ConnectivityResult.none)) {
        flushQueue();
      }
    });
  }

  void stopMonitoring() {
    _timer?.cancel();
  }

  Future<bool> isOnline() async {
    final connectivityResult = await _connectivity.checkConnectivity();
    return !connectivityResult.contains(ConnectivityResult.none);
  }

  Future<void> enqueue(String operation, Map<String, dynamic> payload) async {
    final offlineId = payload['offline_id'] as String;
    await _db.insertOfflineOp(offlineId, operation, payload);
    _pendingCount = await _db.getPendingCount();
    notifyListeners();
    // Attempt immediate background sync if online
    flushQueue();
  }

  Future<List<OfflineQueueItem>> getPendingOps() => _db.getPendingOps();

  Future<void> cancelOp(int id) async {
    await _db.deleteOfflineOp(id);
    _pendingCount = await _db.getPendingCount();
    notifyListeners();
  }

  Future<void> flushQueue() async {
    if (_isSyncing) return;
    
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

      final result = await _api.syncBatch(payload);
      
      if (result['success'] == true) {
        final synced = List<int>.from(result['synced'] ?? []);
        final failed = List<dynamic>.from(result['failed'] ?? []);

        for (final id in synced) {
          await _db.deleteOfflineOp(id);
        }
        for (final failedOp in failed) {
          await _db.markOpFailed(failedOp['id'] as int, failedOp['retries'] as int);
        }
      }
    } catch (e) {
      debugPrint('SyncEngine error: $e');
    } finally {
      _isSyncing = false;
      _pendingCount = await _db.getPendingCount();
      notifyListeners();
    }
  }
}
