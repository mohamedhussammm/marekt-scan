import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_mlkit_barcode_scanning/google_mlkit_barcode_scanning.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:vibration/vibration.dart';
import '../core/models/models.dart';
import '../services/db_helper.dart';
import '../services/api_service.dart';

class ScanningController extends ChangeNotifier {
  final BarcodeScanner _scanner = BarcodeScanner(formats: [
    BarcodeFormat.ean13,
    BarcodeFormat.ean8,
    BarcodeFormat.code128,
    BarcodeFormat.code39,
    BarcodeFormat.qrCode,
  ]);
  final DatabaseHelper _db = DatabaseHelper.instance;
  final ApiService _api = ApiService();
  final AudioPlayer _audioPlayer = AudioPlayer();

  List<CartItem> cartItems = [];
  Product? lastScannedProduct;
  String? unknownBarcode;
  Product? unregisteredProduct;
  bool isScanning = false;
  bool isProcessing = false;
  bool pauseScanning = false;
  Timer? _lastScannedTimer;

  // Blazing Fast Optimizations
  final Map<String, Product> _productCache = {};
  bool _hasVibrator = false;
  String? _lastBarcode;
  DateTime? _lastBarcodeTime;

  ScanningController() {
    _initVibrator();
  }

  Future<void> _initVibrator() async {
    try {
      _hasVibrator = await Vibration.hasVibrator() ?? false;
    } catch (_) {}
  }

  double get cartSubtotal =>
      cartItems.fold(0, (sum, item) => sum + (item.product.sellingPrice * item.quantity));

  double get cartTax => cartSubtotal * 0.14; // Example 14% tax
  
  double get totalAmount => cartSubtotal + cartTax;

  Future<void> processImage(InputImage inputImage) async {
    if (isProcessing || pauseScanning || unknownBarcode != null || unregisteredProduct != null) return;
    isProcessing = true; // Lock immediately to prevent frame overlapping
    
    try {
      final barcodes = await _scanner.processImage(inputImage);
      if (barcodes.isNotEmpty) {
        final rawBarcode = barcodes.first.displayValue;
        if (rawBarcode != null) {
          await processBarcode(rawBarcode);
        }
      }
    } catch (e) {
      print("Error in ML Kit: $e");
    } finally {
      isProcessing = false; // Release lock for next frame
    }
  }

  Future<void> processBarcode(String rawBarcode) async {
    if (pauseScanning || unknownBarcode != null || unregisteredProduct != null) return;
    pauseScanning = true;
    notifyListeners();

    // 2.5 second scan cooldown to prevent multiple scans of the same/next product instantly
    Timer(const Duration(milliseconds: 2500), () {
      pauseScanning = false;
      notifyListeners();
    });

    // 1. Debounce matching barcode (allow scanning different barcodes instantly, but prevent same-barcode double scan)
    final now = DateTime.now();
    if (rawBarcode == _lastBarcode && _lastBarcodeTime != null) {
      final diff = now.difference(_lastBarcodeTime!);
      if (diff.inMilliseconds < 1200) {
        return; // Ignore rapid scan of the exact same product
      }
    }
    _lastBarcode = rawBarcode;
    _lastBarcodeTime = now;

    try {
      Product? product;

      // 2. Memory Cache First (O(1) - 0ms response time!)
      if (_productCache.containsKey(rawBarcode)) {
        product = _productCache[rawBarcode];
      }

      // 3. SQLite second (offline-first)
      if (product == null) {
        product = await _db.getProductByBarcode(rawBarcode);
        if (product != null) {
          _productCache[rawBarcode] = product; // Populate memory cache
        }
      }

      // 4. MongoDB via Node.js if not cached
      if (product == null) {
        product = await _api.getProductByBarcode(rawBarcode);
        if (product != null) {
          _productCache[rawBarcode] = product; // Populate memory cache
          await _db.insertProduct(product); // Cache in SQLite
        }
      }

      if (product != null) {
        if (!product.isRegistered) {
          unregisteredProduct = product;
          notifyListeners();
          if (_hasVibrator) {
            Vibration.vibrate(duration: 200);
          }
          return;
        }

        lastScannedProduct = product;
        _addToCart(product);
        notifyListeners();

        // Auto-clear last scanned product after 5 seconds to clear UI visibility
        _lastScannedTimer?.cancel();
        _lastScannedTimer = Timer(const Duration(seconds: 5), () {
          lastScannedProduct = null;
          notifyListeners();
        });

        // ✅ Success: Non-blocking vibrate + beep (runs concurrently)
        if (_hasVibrator) {
          Vibration.vibrate(duration: 80);
        }
        _audioPlayer.play(AssetSource('sounds/beep.wav')).catchError((err) {
          print("Audio Players error: $err");
        });
      } else {
        // ❌ Unknown barcode: long vibrate (no sound)
        unknownBarcode = rawBarcode;
        notifyListeners();
        if (_hasVibrator) {
          Vibration.vibrate(duration: 350);
        }
      }
    } catch (e) {
      print("Error processing barcode: $e");
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
      // Save to backend
      final payload = product.toJson();
      final result = await _api.addProduct(payload);
      if (result) {
        // Save to SQLite
        await _db.insertProduct(product);
        unknownBarcode = null;
        _addToCart(product);
        notifyListeners();
        return true;
      }
      return false;
    } catch (e) {
      print("Error adding product: $e");
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
      final updatedProduct = product.copyWith(
        costPrice: costPrice,
        sellingPrice: sellingPrice,
        stockQuantity: currentStock,
        isRegistered: true,
      );

      final payload = updatedProduct.toJson();
      final success = await _api.updateProduct(product.barcode, payload);
      if (success) {
        // Update database and caches
        await _db.insertProduct(updatedProduct);
        _productCache[product.barcode] = updatedProduct;

        unregisteredProduct = null;
        _addToCart(updatedProduct);
        notifyListeners();
        return true;
      }
      return false;
    } catch (e) {
      print("Error registering store product: $e");
      return false;
    }
  }

  void _addToCart(Product product) {
    final idx = cartItems.indexWhere((i) => i.product.barcode == product.barcode);
    final newList = List<CartItem>.from(cartItems);
    if (idx >= 0) {
      final oldItem = newList[idx];
      newList[idx] = CartItem(product: oldItem.product, quantity: oldItem.quantity + 1, discountPercent: oldItem.discountPercent);
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
        final oldItem = newList[idx];
        newList[idx] = CartItem(product: oldItem.product, quantity: qty, discountPercent: oldItem.discountPercent);
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

    final payload = {
      "items": cartItems.map((i) => {
        "barcodeId": i.product.barcode,
        "name": i.product.name,
        "qty": i.quantity,
        "unitPrice": i.product.sellingPrice,
        "lineTotal": i.product.sellingPrice * i.quantity
      }).toList(),
      "totalAmount": totalAmount,
      "paymentMethod": paymentMethod,
    };

    final result = await _api.checkout(payload);
    
    if (result['success'] == true) {
      clearCart();
    }
    
    return result;
  }

  @override
  void dispose() {
    _lastScannedTimer?.cancel();
    _scanner.close();
    _audioPlayer.dispose();
    super.dispose();
  }
}
