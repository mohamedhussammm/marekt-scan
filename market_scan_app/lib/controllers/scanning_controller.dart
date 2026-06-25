import 'dart:async';
import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:vibration/vibration.dart';
import '../core/models/models.dart';
import '../core/utils/barcode_validator.dart';
import '../services/db_helper.dart';
import '../services/api_service.dart';
import '../services/sync_engine.dart';
import 'package:uuid/uuid.dart';

/// ScanningController — business logic for the POS barcode scanner.
///
/// Scanning engine is now [mobile_scanner] (ML Kit on Android, Apple Vision
/// on iOS) so camera and detection are handled entirely by the MobileScanner
/// widget in the UI layer.  This controller only deals with:
///   • debouncing / cooldown
///   • 3-tier product lookup (memory cache → SQLite → MongoDB)
///   • cart state
///   • checkout
class ScanningController extends ChangeNotifier {
  final DatabaseHelper _db = DatabaseHelper.instance;
  final ApiService _api = ApiService();
  final SyncEngine _syncEngine = SyncEngine.instance;
  final AudioPlayer _audioPlayer = AudioPlayer();

  List<CartItem> cartItems = [];
  List<HeldOrder> heldOrders = [];
  Product? lastScannedProduct;

  String? unknownBarcode;
  Product? unregisteredProduct;
  bool isScanning = false;
  bool pauseScanning = false;
  Timer? _lastScannedTimer;

  // ── Performance: 3-tier lookup ──────────────────────────────────────────
  final Map<String, Product> _productCache = {};
  bool _hasVibrator = false;
  String? _lastBarcode;
  DateTime? _lastBarcodeTime;

  ScanningController() {
    _initVibrator();
  }

  Future<void> _initVibrator() async {
    try {
      _hasVibrator = await Vibration.hasVibrator();
    } catch (_) {}
  }

  double _taxRate = 14.0;

  void updateTaxRate(double newRate) {
    if (_taxRate != newRate) {
      _taxRate = newRate;
      notifyListeners();
    }
  }

  double get cartSubtotal =>
      cartItems.fold(0, (sum, item) => sum + (item.product.sellingPrice * item.quantity));

  double get cartTax => cartSubtotal * (_taxRate / 100);

  double get totalAmount => cartSubtotal + cartTax;

  /// Called directly by the MobileScanner widget's onDetect callback.
  Future<void> processBarcode(String rawBarcode) async {
    if (pauseScanning || unknownBarcode != null || unregisteredProduct != null) return;

    // ── Validation check to filter out misreads and wrong numbers ──
    if (!BarcodeValidator.isValid(rawBarcode)) return;

    // ── Debounce: ignore the same barcode scanned within 1.2 s ──────────
    final now = DateTime.now();
    if (rawBarcode == _lastBarcode && _lastBarcodeTime != null) {
      if (now.difference(_lastBarcodeTime!).inMilliseconds < 1200) return;
    }
    _lastBarcode = rawBarcode;
    _lastBarcodeTime = now;

    // ── Scan cooldown: prevent camera from flooding with new codes ───────
    // Bug #9 fix: timer is in finally so it fires even when the lookup throws
    // (e.g. network timeout). Without finally, a crash leaves pauseScanning=true
    // for 2.5 s with no user feedback — scanner feels dead.
    pauseScanning = true;
    try {
      Product? product;

      // 1. Memory cache — O(1), ~0 ms
      product = _productCache[rawBarcode];

      // 2. SQLite — offline-first, ~1–5 ms
      if (product == null) {
        product = await _db.getProductByBarcode(rawBarcode);
        if (product != null) _productCache[rawBarcode] = product;
      }

      // 3. Backend (MongoDB via Node.js)
      if (product == null) {
        product = await _api.getProductByBarcode(rawBarcode);
        if (product != null) {
          _productCache[rawBarcode] = product;
          await _db.insertProduct(product);
        }
      }

      if (product != null) {
        if (!product.isRegistered) {
          unregisteredProduct = product;
          notifyListeners();
          if (_hasVibrator) Vibration.vibrate(duration: 200);
          return;
        }

        lastScannedProduct = product;
        _addToCart(product);
        notifyListeners();

        // Auto-clear the scan result banner after 5 s
        _lastScannedTimer?.cancel();
        _lastScannedTimer = Timer(const Duration(seconds: 5), () {
          lastScannedProduct = null;
          notifyListeners();
        });

        // Non-blocking feedback (runs concurrently with UI update)
        if (_hasVibrator) Vibration.vibrate(duration: 80);
        _audioPlayer.play(AssetSource('sounds/beep.wav')).catchError((_) {});
      } else {
        unknownBarcode = rawBarcode;
        notifyListeners();
        if (_hasVibrator) Vibration.vibrate(duration: 350);
      }
    } catch (e) {
      debugPrint('ScanningController.processBarcode error: $e');
    } finally {
      // Always schedule the cooldown reset, regardless of success or failure
      Timer(const Duration(milliseconds: 2500), () {
        pauseScanning = false;
      });
    }
  }

  void clearUnregisteredProduct() {
    unregisteredProduct = null;
    notifyListeners();
  }

  void clearUnknownBarcode() {
    unknownBarcode = null;
    notifyListeners();
  }

  Future<bool> addNewProduct(Product product) async {
    try {
      final result = await _api.addProduct(product.toJson());
      if (result) {
        await _db.insertProduct(product);
        unknownBarcode = null;
        _addToCart(product);
        notifyListeners();
        return true;
      }
      return false;
    } catch (e) {
      debugPrint('addNewProduct error: $e');
      return false;
    }
  }

  Future<bool> registerStoreProduct({
    required Product product,
    required double costPrice,
    required double sellingPrice,
    required int currentStock,
  }) async {
    try {
      final updated = product.copyWith(
        costPrice: costPrice,
        sellingPrice: sellingPrice,
        stockQuantity: currentStock,
        isRegistered: true,
      );
      final success = await _api.updateProduct(product.barcode, updated.toJson());
      if (success) {
        await _db.insertProduct(updated);
        _productCache[product.barcode] = updated;
        unregisteredProduct = null;
        _addToCart(updated);
        notifyListeners();
        return true;
      }
      return false;
    } catch (e) {
      debugPrint('registerStoreProduct error: $e');
      return false;
    }
  }

  void _addToCart(Product product) {
    final idx = cartItems.indexWhere((i) => i.product.barcode == product.barcode);
    final newList = List<CartItem>.from(cartItems);
    if (idx >= 0) {
      final old = newList[idx];
      newList[idx] = CartItem(product: old.product, quantity: old.quantity + 1, discountPercent: old.discountPercent);
    } else {
      newList.add(CartItem(product: product, quantity: 1));
    }
    cartItems = newList;
  }

  void updateQuantity(String barcode, int qty) {
    final idx = cartItems.indexWhere((i) => i.product.barcode == barcode);
    if (idx >= 0) {
      final newList = List<CartItem>.from(cartItems);
      if (qty <= 0) {
        newList.removeAt(idx);
      } else {
        final old = newList[idx];
        newList[idx] = CartItem(product: old.product, quantity: qty, discountPercent: old.discountPercent);
      }
      cartItems = newList;
      notifyListeners();
    }
  }

  void clearCart() {
    cartItems = [];
    lastScannedProduct = null;
    _lastScannedTimer?.cancel();
    notifyListeners();
  }

  Future<Map<String, dynamic>> checkout(String paymentMethod) async {
    if (cartItems.isEmpty) return {'success': false, 'error': 'Cart is empty'};

    final offlineId = const Uuid().v4();
    final payload = {
      'offline_id': offlineId,
      'items': cartItems
          .map((i) {
            return {
              'barcodeId': i.product.barcode,
              'name': i.product.name,
              'qty': i.quantity,
              'unitPrice': i.product.sellingPrice,
              'lineTotal': i.product.sellingPrice * i.quantity,
            };
          })
          .toList(),
      'totalAmount': totalAmount,
      'paymentMethod': paymentMethod,
    };

    // Optimistically clear cart
    clearCart();

    try {
      final result = await _api.checkout(payload).timeout(const Duration(seconds: 8));
      if (result['success'] == true) {
        result['isOffline'] = false;
        return result;
      } else {
        await _syncEngine.enqueue('checkout', payload);
        return {'success': true, 'isOffline': true};
      }
    } catch (_) {
      await _syncEngine.enqueue('checkout', payload);
      return {'success': true, 'isOffline': true};
    }
  }

  void holdCurrentOrder() {
    if (cartItems.isEmpty) return;
    final newHeld = HeldOrder(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      items: List<CartItem>.from(cartItems),
      timestamp: DateTime.now(),
    );
    heldOrders.add(newHeld);
    clearCart();
    notifyListeners();
  }

  void restoreHeldOrder(String id, {bool merge = false}) {
    final idx = heldOrders.indexWhere((o) => o.id == id);
    if (idx >= 0) {
      final restored = heldOrders.removeAt(idx);
      if (merge) {
        final newList = List<CartItem>.from(cartItems);
        for (final item in restored.items) {
          final existIdx = newList.indexWhere((i) => i.product.barcode == item.product.barcode);
          if (existIdx >= 0) {
            final old = newList[existIdx];
            newList[existIdx] = CartItem(
              product: old.product,
              quantity: old.quantity + item.quantity,
              discountPercent: old.discountPercent,
            );
          } else {
            newList.add(item);
          }
        }
        cartItems = newList;
      } else {
        cartItems = restored.items;
      }
      notifyListeners();
    }
  }


  void deleteHeldOrder(String id) {
    heldOrders.removeWhere((o) => o.id == id);
    notifyListeners();
  }

  @override

  void dispose() {
    _lastScannedTimer?.cancel();
    _audioPlayer.dispose();
    super.dispose();
  }
}
