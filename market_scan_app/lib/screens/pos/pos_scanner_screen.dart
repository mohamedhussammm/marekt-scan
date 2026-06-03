import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_strings.dart';
import '../../core/models/models.dart';
import '../../core/providers/app_provider.dart';
import '../../controllers/scanning_controller.dart';
import '../../widgets/camera_view.dart';

class PosScannerScreen extends StatefulWidget {
  const PosScannerScreen({super.key});

  @override
  State<PosScannerScreen> createState() => _PosScannerScreenState();
}

class _PosScannerScreenState extends State<PosScannerScreen>
    with SingleTickerProviderStateMixin, AutomaticKeepAliveClientMixin {
  final _amountCtrl = TextEditingController();
  late TabController _tabController;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ScanningController>().addListener(_onScannerUpdate);
    });
  }

  void _onScannerUpdate() {
    final scanner = context.read<ScanningController>();
    final provider = context.read<AppProvider>();
    
    // Enforce role constraints for product creation/pricing
    if (provider.userRole == 'cashier') {
      if (scanner.unknownBarcode != null) {
        final barcode = scanner.unknownBarcode!;
        scanner.clearUnknownBarcode();
        // Log security violation to DB
        provider.logSecurityViolation(
          'unauthorized_product_creation',
          'حاول الكاشير إضافة منتج جديد غير موجود بالباركود: $barcode'
        );
        _showSecurityAlertSnackBar('غير مسموح لك بإضافة منتجات جديدة. تم إرسال تنبيه للمدير.');
      } else if (scanner.unregisteredProduct != null) {
        final barcode = scanner.unregisteredProduct!.barcode;
        scanner.clearUnregisteredProduct();
        // Log security violation to DB
        provider.logSecurityViolation(
          'unauthorized_product_pricing',
          'حاول الكاشير تسعير منتج غير مسجل بالباركود: $barcode'
        );
        _showSecurityAlertSnackBar('غير مسموح لك بتسعير منتجات للمتجر. تم إرسال تنبيه للمدير.');
      }
      return;
    }

    if (scanner.unknownBarcode != null && !_isShowingAddSheet) {
      _isShowingAddSheet = true;
      _showAddProductDialog(context, scanner.unknownBarcode!);
    } else if (scanner.unregisteredProduct != null && !_isShowingRegisterSheet) {
      _isShowingRegisterSheet = true;
      _showRegisterProductDialog(context, scanner.unregisteredProduct!);
    }
  }

  void _showSecurityAlertSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.warning_amber_rounded, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        backgroundColor: Colors.redAccent,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        duration: const Duration(seconds: 4),
      ),
    );
  }

  bool _isShowingAddSheet = false;
  bool _isShowingRegisterSheet = false;

  @override
  void dispose() {
    _amountCtrl.dispose();
    _tabController.dispose();
    // In a real app we'd removeListener, but this is a long-lived screen.
    super.dispose();
  }

  void _showAddProductDialog(BuildContext context, String barcode) {
    final nameCtrl = TextEditingController();
    final catCtrl = TextEditingController();
    final costCtrl = TextEditingController();
    final sellCtrl = TextEditingController();
    final stockCtrl = TextEditingController();

    bool isSaving = false;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      isDismissible: false,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) {
          return Padding(
            padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.of(ctx).viewInsets.bottom + 20),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
              Text('إضافة منتج جديد', style: Theme.of(context).textTheme.headlineSmall),
              const SizedBox(height: 12),
              Text('الباركود: ${barcode}', style: const TextStyle(color: AppColors.textSecondary)),
              const SizedBox(height: 20),
              TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'اسم المنتج')),
              const SizedBox(height: 12),
              TextField(controller: catCtrl, decoration: const InputDecoration(labelText: 'الفئة')),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(child: TextField(controller: costCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'سعر التكلفة'))),
                  const SizedBox(width: 12),
                  Expanded(child: TextField(controller: sellCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'سعر البيع'))),
                ],
              ),
              const SizedBox(height: 12),
              TextField(controller: stockCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'الكمية الحالية')),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () {
                        context.read<ScanningController>().clearUnknownBarcode();
                        _isShowingAddSheet = false;
                        Navigator.pop(ctx);
                      },
                      child: const Text('إلغاء'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: isSaving ? null : () async {
                            print("ElevatedButton - Pressed! Name: '${nameCtrl.text}'");
                            if (nameCtrl.text.trim().isEmpty) {
                              print("Validation failed: name is empty");
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('من فضلك أدخل اسم المنتج')));
                              return;
                            }
                            setSheetState(() => isSaving = true);
                            final product = Product(
                              id: barcode,
                              barcode: barcode,
                              name: nameCtrl.text.trim(),
                              category: catCtrl.text.trim().isEmpty ? 'عام' : catCtrl.text.trim(),
                              costPrice: double.tryParse(costCtrl.text) ?? 0,
                              sellingPrice: double.tryParse(sellCtrl.text) ?? 0,
                              stockQuantity: int.tryParse(stockCtrl.text) ?? 0,
                              minStockLevel: 10,
                            );
                            // Capture before await to avoid unmounted context
                            final scanCtrl = context.read<ScanningController>();
                            final scaffoldMsg = ScaffoldMessenger.of(context);
                            final success = await scanCtrl.addNewProduct(product);
                            if (!ctx.mounted) return;
                            setSheetState(() => isSaving = false);
                            if (success) {
                              _isShowingAddSheet = false;
                              Navigator.pop(ctx);
                              scaffoldMsg.showSnackBar(const SnackBar(
                                content: Text('✅ تم إضافة المنتج بنجاح!'),
                                backgroundColor: Colors.green,
                              ));
                            } else {
                              scaffoldMsg.showSnackBar(const SnackBar(
                                content: Text('❌ فشل الحفظ — تحقق من اتصال الخادم'),
                                backgroundColor: Colors.red,
                              ));
                            }
                          },
                          child: isSaving
                              ? const SizedBox(width: 18, height: 18,
                                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                              : const Text('حفظ'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  void _showRegisterProductDialog(BuildContext context, Product product) {
    final costCtrl = TextEditingController();
    final sellCtrl = TextEditingController();
    final stockCtrl = TextEditingController();

    bool isSaving = false;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      isDismissible: false,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) {
          return Padding(
            padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.of(ctx).viewInsets.bottom + 20),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('تسعير منتج للمتجر', style: Theme.of(context).textTheme.headlineSmall),
                  const SizedBox(height: 12),
                  Text('اسم المنتج: ${product.name}', style: const TextStyle(fontWeight: FontWeight.bold)),
                  Text('الباركود: ${product.barcode}', style: const TextStyle(color: AppColors.textSecondary)),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(child: TextField(controller: costCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'سعر التكلفة'))),
                      const SizedBox(width: 12),
                      Expanded(child: TextField(controller: sellCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'سعر البيع'))),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextField(controller: stockCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'الكمية الحالية للمخزن')),
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () {
                            context.read<ScanningController>().clearUnregisteredProduct();
                            _isShowingRegisterSheet = false;
                            Navigator.pop(ctx);
                          },
                          child: const Text('إلغاء'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: isSaving ? null : () async {
                            final cost = double.tryParse(costCtrl.text) ?? 0;
                            final sell = double.tryParse(sellCtrl.text) ?? 0;
                            final stock = int.tryParse(stockCtrl.text) ?? 0;
                            
                            if (sell <= 0) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('من فضلك أدخل سعر البيع')));
                              return;
                            }
                            
                            setSheetState(() => isSaving = true);
                            
                            final scanCtrl = context.read<ScanningController>();
                            final scaffoldMsg = ScaffoldMessenger.of(context);
                            
                            final success = await scanCtrl.registerStoreProduct(
                              product: product,
                              costPrice: cost,
                              sellingPrice: sell,
                              currentStock: stock,
                            );
                            
                            if (!ctx.mounted) return;
                            setSheetState(() => isSaving = false);
                            
                            if (success) {
                              _isShowingRegisterSheet = false;
                              Navigator.pop(ctx);
                              scaffoldMsg.showSnackBar(const SnackBar(
                                content: Text('✅ تم تسعير وتسجيل المنتج بنجاح!'),
                                backgroundColor: Colors.green,
                              ));
                            } else {
                              scaffoldMsg.showSnackBar(const SnackBar(
                                content: Text('❌ فشل الحفظ — تحقق من اتصال الخادم'),
                                backgroundColor: Colors.red,
                              ));
                            }
                          },
                          child: isSaving
                              ? const SizedBox(width: 18, height: 18,
                                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                              : const Text('حفظ'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  void _showCheckoutDialog(BuildContext context, ScanningController scanner) {
    String paymentMethod = 'نقداً';
    _amountCtrl.text = scanner.totalAmount.toStringAsFixed(2);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) {
        bool isCheckingOut = false;
        return StatefulBuilder(
          builder: (ctx, setModalState) => Padding(
            padding: EdgeInsets.fromLTRB(
                24, 24, 24, MediaQuery.of(ctx).viewInsets.bottom + 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                      width: 40, height: 4,
                      decoration: BoxDecoration(
                          color: AppColors.border,
                          borderRadius: BorderRadius.circular(2))),
                ),
                const SizedBox(height: 20),
                Text('إتمام عملية البيع',
                    style: Theme.of(context).textTheme.headlineSmall),
                const SizedBox(height: 20),
                _SummaryRow('المجموع الفرعي',
                    '${scanner.cartSubtotal.toStringAsFixed(2)} ${AppStrings.currencySymbol}'),
                _SummaryRow('ضريبة القيمة المضافة (14%)',
                    '${scanner.cartTax.toStringAsFixed(2)} ${AppStrings.currencySymbol}'),
                const Divider(height: 20),
                _SummaryRow('الإجمالي',
                    '${scanner.totalAmount.toStringAsFixed(2)} ${AppStrings.currencySymbol}',
                    bold: true, color: AppColors.primary),
                const SizedBox(height: 16),
                Text('طريقة الدفع',
                    style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 8),
                Row(
                  children: ['نقداً', 'بطاقة', 'تحويل'].map((method) =>
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          child: ChoiceChip(
                            label: Text(method),
                            selected: paymentMethod == method,
                            onSelected: (_) =>
                                setModalState(() => paymentMethod = method),
                            selectedColor: AppColors.primaryContainer,
                            labelStyle: TextStyle(
                                color: paymentMethod == method
                                    ? AppColors.primary : AppColors.textSecondary),
                          ),
                        ),
                      ),
                  ).toList(),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _amountCtrl,
                  keyboardType: TextInputType.number,
                  textDirection: TextDirection.ltr,
                  decoration: const InputDecoration(
                    labelText: 'المبلغ المدفوع',
                    prefixIcon: Icon(Icons.payments_outlined, color: AppColors.primary),
                  ),
                ),
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: isCheckingOut
                      ? null
                      : () async {
                          setModalState(() {
                            isCheckingOut = true;
                          });
                          try {
                            final result = await scanner.checkout(paymentMethod);
                            if (!ctx.mounted) return;
                            Navigator.pop(ctx);
                            if (result['success'] == true) {
                              if (context.mounted) {
                                context.read<AppProvider>().loadDashboardStats();
                              }
                              ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('تمت العملية بنجاح!')));
                            } else {
                              ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text("خطأ: ${result['error']}")));
                              setModalState(() {
                                isCheckingOut = false;
                              });
                            }
                          } catch (e) {
                            if (ctx.mounted) {
                              setModalState(() {
                                isCheckingOut = false;
                              });
                            }
                          }
                        },
                  child: isCheckingOut
                      ? const SizedBox(
                          height: 20, width: 20,
                          child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.white)),
                        )
                      : const Text(AppStrings.checkout),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final provider = context.watch<AppProvider>();
    final isCashier = provider.userRole == 'cashier';
    final activeShift = provider.activeShift;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text(AppStrings.posScanner),
        automaticallyImplyLeading: false,
        actions: [
          Selector<ScanningController, bool>(
            selector: (_, s) => s.cartItems.isNotEmpty,
            builder: (context, hasItems, _) {
              if (!hasItems) return const SizedBox.shrink();
              return TextButton.icon(
                onPressed: () => context.read<ScanningController>().clearCart(),
                icon: const Icon(Icons.delete_outline, color: Colors.white, size: 18),
                label: const Text(AppStrings.clearCart,
                    style: TextStyle(color: Colors.white, fontSize: 12)),
              );
            },
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.tune_outlined, color: Colors.white),
            onSelected: (val) {
              if (val == 'expense') {
                _showRecordExpenseDialog(context);
              } else if (val == 'open_shift') {
                _showOpenRegisterDialog(context);
              } else if (val == 'close_shift') {
                _showCloseRegisterDialog(context);
              }
            },
            itemBuilder: (ctx) {
              return [
                if (activeShift != null)
                  const PopupMenuItem(
                    value: 'expense',
                    child: Row(
                      children: [
                        Icon(Icons.money_off_outlined, color: Colors.redAccent),
                        SizedBox(width: 8),
                        Text('تسجيل مصروف', style: TextStyle(fontFamily: 'Cairo', fontSize: 13)),
                      ],
                    ),
                  ),
                if (activeShift == null)
                  const PopupMenuItem(
                    value: 'open_shift',
                    child: Row(
                      children: [
                        Icon(Icons.door_sliding_outlined, color: Colors.green),
                        SizedBox(width: 8),
                        Text('فتح الوردية', style: TextStyle(fontFamily: 'Cairo', fontSize: 13)),
                      ],
                    ),
                  ),
                if (activeShift != null)
                  const PopupMenuItem(
                    value: 'close_shift',
                    child: Row(
                      children: [
                        Icon(Icons.no_meeting_room_outlined, color: Colors.orange),
                        SizedBox(width: 8),
                        Text('إغلاق الوردية', style: TextStyle(fontFamily: 'Cairo', fontSize: 13)),
                      ],
                    ),
                  ),
              ];
            },
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white60,
          tabs: const [
            Tab(text: 'الكاميرا', icon: Icon(Icons.qr_code_scanner, size: 18)),
            Tab(text: AppStrings.cart, icon: Icon(Icons.shopping_cart_outlined, size: 18)),
          ],
        ),
      ),
      body: Stack(
        children: [
          TabBarView(
            controller: _tabController,
            children: [
              // ── Camera Scanner Tab ──────────────────────────────────────────────
              Stack(
                children: [
                  const _CameraTabBody(),
                  
                  // Target box overlay
                  const Center(
                    child: _AnimatedScannerOverlay(),
                  ),

                  // Last scanned item popup - Only rebuilds if lastScannedProduct changes
                  Selector<ScanningController, Product?>(
                    selector: (_, s) => s.lastScannedProduct,
                    builder: (context, lastProduct, _) {
                      if (lastProduct == null) return const SizedBox.shrink();
                      return Positioned(
                        bottom: 24,
                        left: 24,
                        right: 24,
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 10)],
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.check_circle, color: AppColors.success, size: 32),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(lastProduct.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                    Text('${lastProduct.sellingPrice} ${AppStrings.currencySymbol}', style: const TextStyle(color: AppColors.primary)),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ),

              // ── Cart Tab ──────────────────────────────────────────────────
              Selector<ScanningController, List<CartItem>>(
                selector: (_, s) => s.cartItems,
                builder: (context, cartItems, _) {
                  final scanner = context.read<ScanningController>();
                  return Column(
                    children: [
                      Expanded(
                        child: cartItems.isEmpty
                            ? Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.shopping_cart_outlined,
                                  size: 64, color: AppColors.border),
                              const SizedBox(height: 12),
                              Text('السلة فارغة',
                                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: AppColors.border)),
                            ],
                          ),
                        )
                            : ListView.builder(
                          padding: const EdgeInsets.all(12),
                          itemCount: cartItems.length,
                          itemBuilder: (_, i) {
                            final item = cartItems[i];
                            return _CartItemTile(
                              item: item,
                              onRemove: () => scanner.updateQuantity(item.product.barcode, 0),
                              onQtyChange: (q) => scanner.updateQuantity(item.product.barcode, q),
                            );
                          },
                        ),
                      ),
                      if (cartItems.isNotEmpty)
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: const BoxDecoration(
                            color: Colors.white,
                            boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 8, offset: Offset(0, -2))],
                          ),
                          child: Column(
                            children: [
                              _SummaryRow('المجموع الفرعي',
                                  '${scanner.cartSubtotal.toStringAsFixed(2)} ${AppStrings.currencySymbol}'),
                              _SummaryRow('ضريبة (${provider.taxRate.toStringAsFixed(0)}%)',
                                  '${scanner.cartTax.toStringAsFixed(2)} ${AppStrings.currencySymbol}'),
                              const Divider(),
                              _SummaryRow('الإجمالي',
                                  '${scanner.totalAmount.toStringAsFixed(2)} ${AppStrings.currencySymbol}',
                                  bold: true, color: AppColors.primary),
                              const SizedBox(height: 12),
                              ElevatedButton.icon(
                                onPressed: () => _showCheckoutDialog(context, scanner),
                                icon: const Icon(Icons.check_circle_outline),
                                label: Text(
                                    '${AppStrings.checkout} • ${scanner.totalAmount.toStringAsFixed(2)} ${AppStrings.currencySymbol}'),
                              ),
                            ],
                          ),
                        ),
                    ],
                  );
                },
              ),
            ],
          ),

          // Cashier Block Overlay if Shift is not active
          if (isCashier && activeShift == null)
            Positioned.fill(
              child: Container(
                color: Colors.black.withOpacity(0.88),
                child: Center(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            color: Colors.red.withOpacity(0.08),
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.redAccent.withOpacity(0.2), width: 2),
                          ),
                          child: const Icon(
                            Icons.door_sliding_outlined,
                            size: 64,
                            color: Colors.redAccent,
                          ),
                        ),
                        const SizedBox(height: 24),
                        const Text(
                          'الوردية مغلقة',
                          style: TextStyle(
                            fontFamily: 'Cairo',
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          'الرجاء فتح الوردية لبدء عمليات البيع ومسح المنتجات.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontFamily: 'Cairo',
                            fontSize: 14,
                            color: Colors.white70,
                            height: 1.6,
                          ),
                        ),
                        const SizedBox(height: 32),
                        ElevatedButton.icon(
                          onPressed: () => _showOpenRegisterDialog(context),
                          icon: const Icon(Icons.add_card_outlined),
                          label: const Text('فتح الوردية الآن'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  // ─── SHIFT & EXPENSE DIALOGS ───
  void _showOpenRegisterDialog(BuildContext context) {
    final cashCtrl = TextEditingController();
    bool isSubmitting = false;
    
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          return AlertDialog(
            title: const Text('فتح الوردية الجديدة', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold)),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('أدخل المبلغ المالي الابتدائي في درج الكاشير:', style: TextStyle(fontFamily: 'Cairo', fontSize: 13)),
                const SizedBox(height: 16),
                TextField(
                  controller: cashCtrl,
                  keyboardType: TextInputType.number,
                  textDirection: TextDirection.ltr,
                  decoration: const InputDecoration(
                    labelText: 'النقود الابتدائية',
                    suffixText: 'ج.م',
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('إلغاء', style: TextStyle(fontFamily: 'Cairo')),
              ),
              ElevatedButton(
                onPressed: isSubmitting ? null : () async {
                  final amount = double.tryParse(cashCtrl.text) ?? 0.0;
                  setDialogState(() => isSubmitting = true);
                  final res = await context.read<AppProvider>().openRegister(amount);
                  if (ctx.mounted) {
                    Navigator.pop(ctx);
                  }
                  if (res['success'] == true) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('تم فتح الوردية بنجاح!'), backgroundColor: Colors.green),
                    );
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(res['error'] ?? 'فشل فتح الوردية'), backgroundColor: Colors.redAccent),
                    );
                  }
                },
                child: isSubmitting
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : const Text('فتح الوردية', style: TextStyle(fontFamily: 'Cairo')),
              ),
            ],
          );
        }
      ),
    );
  }

  void _showCloseRegisterDialog(BuildContext context) {
    final cashCtrl = TextEditingController();
    bool isSubmitting = false;
    
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          return AlertDialog(
            title: const Text('إغلاق الوردية الحالية', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold)),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('أدخل المبلغ المالي الفعلي الموجود حالياً في الدرج:', style: TextStyle(fontFamily: 'Cairo', fontSize: 13)),
                const SizedBox(height: 16),
                TextField(
                  controller: cashCtrl,
                  keyboardType: TextInputType.number,
                  textDirection: TextDirection.ltr,
                  decoration: const InputDecoration(
                    labelText: 'النقود الفعلية عند الإغلاق',
                    suffixText: 'ج.م',
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('إلغاء', style: TextStyle(fontFamily: 'Cairo')),
              ),
              ElevatedButton(
                onPressed: isSubmitting ? null : () async {
                  final amount = double.tryParse(cashCtrl.text) ?? 0.0;
                  setDialogState(() => isSubmitting = true);
                  final res = await context.read<AppProvider>().closeRegister(amount);
                  if (ctx.mounted) {
                    Navigator.pop(ctx);
                  }
                  if (res['success'] == true) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('تم إغلاق الوردية وحفظ التقرير بنجاح!'), backgroundColor: Colors.green),
                    );
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(res['error'] ?? 'فشل إغلاق الوردية'), backgroundColor: Colors.redAccent),
                    );
                  }
                },
                child: isSubmitting
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : const Text('إغلاق الوردية', style: TextStyle(fontFamily: 'Cairo')),
              ),
            ],
          );
        }
      ),
    );
  }

  void _showRecordExpenseDialog(BuildContext context) {
    final amtCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    bool isSubmitting = false;
    
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          return AlertDialog(
            title: const Text('تسجيل مصروفات نقدية', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold)),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('أدخل تفاصيل المصروف النقدي من الخزينة:', style: TextStyle(fontFamily: 'Cairo', fontSize: 13)),
                const SizedBox(height: 16),
                TextField(
                  controller: amtCtrl,
                  keyboardType: TextInputType.number,
                  textDirection: TextDirection.ltr,
                  decoration: const InputDecoration(
                    labelText: 'المبلغ المستقطع',
                    suffixText: 'ج.م',
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: descCtrl,
                  decoration: const InputDecoration(
                    labelText: 'الوصف / سبب الصرف',
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('إلغاء', style: TextStyle(fontFamily: 'Cairo')),
              ),
              ElevatedButton(
                onPressed: isSubmitting ? null : () async {
                  final amount = double.tryParse(amtCtrl.text) ?? 0.0;
                  final desc = descCtrl.text.trim();
                  if (amount <= 0 || desc.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('الرجاء إدخال مبلغ صحيح ووصف المصروف')),
                    );
                    return;
                  }
                  setDialogState(() => isSubmitting = true);
                  final res = await context.read<AppProvider>().recordPettyExpense(amount, desc);
                  if (ctx.mounted) {
                    Navigator.pop(ctx);
                  }
                  if (res['success'] == true) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('تم تسجيل المصروف النقدي بنجاح!'), backgroundColor: Colors.green),
                    );
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(res['error'] ?? 'فشل تسجيل المصروف'), backgroundColor: Colors.redAccent),
                    );
                  }
                },
                child: isSubmitting
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : const Text('حفظ المصروف', style: TextStyle(fontFamily: 'Cairo')),
              ),
            ],
          );
        }
      ),
    );
  }
}

class _CameraTabBody extends StatelessWidget {
  const _CameraTabBody();

  @override
  Widget build(BuildContext context) {
    return CameraView(
      onImage: (img) => context.read<ScanningController>().processImage(img),
    );
  }
}

class _CartItemTile extends StatelessWidget {
  final CartItem item;
  final VoidCallback onRemove;
  final ValueChanged<int> onQtyChange;
  const _CartItemTile({required this.item, required this.onRemove, required this.onQtyChange});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Container(
            width: 44, height: 44,
            decoration: BoxDecoration(
              color: AppColors.surfaceVariant,
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.inventory_2_outlined, color: AppColors.primary, size: 22),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item.product.name,
                    maxLines: 1, overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                Text('${item.product.sellingPrice.toStringAsFixed(2)} ${AppStrings.currencySymbol}',
                    style: const TextStyle(color: AppColors.textHint, fontSize: 12)),
              ],
            ),
          ),
          Row(
            children: [
              _QtyBtn(icon: Icons.remove, onTap: () => onQtyChange(item.quantity - 1)),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                child: Text('${item.quantity}',
                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
              ),
              _QtyBtn(icon: Icons.add, onTap: () => onQtyChange(item.quantity + 1)),
              const SizedBox(width: 6),
              IconButton(
                onPressed: onRemove,
                icon: const Icon(Icons.delete_outline, color: AppColors.error, size: 20),
                padding: EdgeInsets.zero, constraints: const BoxConstraints(),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _QtyBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _QtyBtn({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 28, height: 28,
        decoration: BoxDecoration(
          color: AppColors.surfaceVariant,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppColors.border),
        ),
        child: Icon(icon, size: 16, color: AppColors.primary),
      ),
    );
  }
}

class _AnimatedScannerOverlay extends StatefulWidget {
  const _AnimatedScannerOverlay();

  @override
  State<_AnimatedScannerOverlay> createState() => _AnimatedScannerOverlayState();
}

class _AnimatedScannerOverlayState extends State<_AnimatedScannerOverlay> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
    _animation = Tween<double>(begin: 0.0, end: 1.0).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 250,
      height: 250,
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.primary, width: 2),
        borderRadius: BorderRadius.circular(12),
      ),
      child: AnimatedBuilder(
        animation: _animation,
        builder: (context, child) {
          return Stack(
            children: [
              Positioned(
                top: _animation.value * 248, // 250 - 2 (line height)
                left: 0,
                right: 0,
                child: Container(
                  height: 2,
                  decoration: BoxDecoration(
                    color: Colors.red,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.red.withOpacity(0.5),
                        blurRadius: 4,
                        spreadRadius: 2,
                      )
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  final String label;
  final String value;
  final bool bold;
  final Color? color;
  const _SummaryRow(this.label, this.value, {this.bold = false, this.color});

  @override
  Widget build(BuildContext context) {
    final style = TextStyle(
      fontWeight: bold ? FontWeight.w700 : FontWeight.w400,
      fontSize: bold ? 16 : 14,
      color: color ?? AppColors.textPrimary,
    );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: style),
          Text(value, style: style),
        ],
      ),
    );
  }
}
