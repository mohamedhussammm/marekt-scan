import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_strings.dart';
import '../../core/models/models.dart';
import '../../core/providers/app_provider.dart';
import '../../controllers/scanning_controller.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

class PosScannerScreen extends StatefulWidget {
  const PosScannerScreen({super.key});

  @override
  State<PosScannerScreen> createState() => _PosScannerScreenState();
}

class _PosScannerScreenState extends State<PosScannerScreen> {
  final _amountCtrl = TextEditingController();
  String _dialogCategory = 'أخرى';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<ScanningController>().addListener(_onScannerUpdate);
    });
  }

  void _onScannerUpdate() {
    if (!mounted) return; // Bug #5: never touch context after dispose
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
    // Bug #6: reset sheet guard flags so they don't stay locked
    _isShowingAddSheet = false;
    _isShowingRegisterSheet = false;
    // Bug #3: always remove listener — prevents memory leak + dead-context crash
    try {
      context.read<ScanningController>().removeListener(_onScannerUpdate);
    } catch (_) {}
    _amountCtrl.dispose();
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
              Text('الباركود: $barcode', style: const TextStyle(color: AppColors.textSecondary)),
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
                            if (nameCtrl.text.trim().isEmpty) {
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
    // Bug #6: reset flag on ANY dismiss path (back gesture, tap outside, etc.)
    ).whenComplete(() => _isShowingAddSheet = false);
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
    // Bug #6: reset flag on ANY dismiss path (back gesture, tap outside, etc.)
    ).whenComplete(() => _isShowingRegisterSheet = false);
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
                            final result = await scanner.checkout(
                              paymentMethod,
                              onSaleCreated: (sale) {
                                if (context.mounted) {
                                  context.read<AppProvider>().addLocalSale(sale);
                                }
                              },
                            );
                            if (!ctx.mounted) return;
                            Navigator.pop(ctx);
                            if (result['success'] == true) {
                              if (context.mounted) {
                                context.read<AppProvider>().loadDashboardStats();
                              }
                              final isOffline = result['isOffline'] == true;
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Row(
                                    children: [
                                      Icon(isOffline ? Icons.cloud_off : Icons.check_circle, color: Colors.white),
                                      const SizedBox(width: 8),
                                      Text(
                                        isOffline ? 'تم حفظ البيع محلياً ✓ — سيتم رفعه للسيرفر عند الاتصال' : 'تمت العملية بنجاح!',
                                        style: const TextStyle(fontFamily: 'Cairo'),
                                      ),
                                    ],
                                  ),
                                  backgroundColor: isOffline ? Colors.orange : Colors.green,
                                ),
                              );
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
    // P0 fix: Use context.select for each field independently.
    // context.watch<AppProvider>() was rebuilding this entire 1200+ line screen
    // on EVERY notifyListeners() call — every 15s from the dashboard timer,
    // and every cart mutation from ScanningController.
    final isCashier = context.select<AppProvider, bool>((p) => p.userRole == 'cashier');
    final activeShift = context.select<AppProvider, Shift?>((p) => p.activeShift);
    final taxRate = context.select<AppProvider, double>((p) => p.taxRate);

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
                onPressed: () {
                  context.read<ScanningController>().holdCurrentOrder();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('تم تعليق الطلب بنجاح', style: TextStyle(fontFamily: 'Cairo')),
                      backgroundColor: Colors.green,
                    ),
                  );
                },
                icon: const Icon(Icons.pause_circle_outline, color: Colors.white, size: 18),
                label: const Text('تعليق الطلب',
                    style: TextStyle(color: Colors.white, fontSize: 12, fontFamily: 'Cairo')),
              );
            },
          ),
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
          Selector<ScanningController, int>(
            selector: (_, s) => s.heldOrders.length,
            builder: (context, heldCount, _) {
              if (heldCount == 0) return const SizedBox.shrink();
              return Stack(
                alignment: Alignment.center,
                children: [
                  IconButton(
                    icon: const Icon(Icons.history_toggle_off_outlined, color: Colors.white),
                    onPressed: () => _showHeldOrdersDialog(context),
                    tooltip: 'الطلبات المعلقة',
                  ),
                  Positioned(
                    right: 4,
                    top: 4,
                    child: Container(
                      padding: const EdgeInsets.all(2),
                      decoration: BoxDecoration(
                        color: Colors.red,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      constraints: const BoxConstraints(
                        minWidth: 16,
                        minHeight: 16,
                      ),
                      child: Text(
                        '$heldCount',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,

                      ),
                    ),
                  ),
                ],
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
      ),
      body: Stack(
        children: [
          Column(
            children: [
              // ── Scanner (top 42%) ─────────────────────────────────────────
              SizedBox(
                width: double.infinity,
                height: MediaQuery.of(context).size.height * 0.42,
                // RepaintBoundary: isolates camera paint so cart scroll
                // updates don't force the camera preview to repaint.
                child: RepaintBoundary(
                  child: (isCashier && activeShift == null)
                      ? Container(color: Colors.black)
                      : _ScannerSection(onCheckout: (sc) => _showCheckoutDialog(context, sc)),
                ),
              ),
              // ── Cart panel (remaining space) ──────────────────────────────
              Expanded(
                child: _CartPanel(
                  onCheckout: (sc) => _showCheckoutDialog(context, sc),
                  taxRate: taxRate,
                ),
              ),
            ],
          ),

          // Cashier Block Overlay if Shift is not active
          if (isCashier && activeShift == null)
            Positioned.fill(
              child: Container(
                color: Colors.black.withValues(alpha: 0.88),
                child: Center(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            color: Colors.red.withValues(alpha: 0.08),
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.redAccent.withValues(alpha: 0.2), width: 2),
                          ),
                          child: const Icon(Icons.door_sliding_outlined, size: 64, color: Colors.redAccent),
                        ),
                        const SizedBox(height: 24),
                        const Text('الوردية مغلقة',
                            style: TextStyle(fontFamily: 'Cairo', fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white)),
                        const SizedBox(height: 12),
                        const Text('الرجاء فتح الوردية لبدء عمليات البيع ومسح المنتجات.',
                            textAlign: TextAlign.center,
                            style: TextStyle(fontFamily: 'Cairo', fontSize: 14, color: Colors.white70, height: 1.6)),
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
    _dialogCategory = 'أخرى';
    bool isSubmitting = false;

    final List<String> expenseCategories = [
      'طاقة / كهرباء وغاز',
      'رواتب',
      'إيجار',
      'بضاعة / مشتريات',
      'صيانة',
      'أخرى',
    ];
    
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
                DropdownButtonFormField<String>(
                  value: _dialogCategory,
                  decoration: const InputDecoration(
                    labelText: 'تصنيف المصروف',
                  ),
                  items: expenseCategories.map((c) => DropdownMenuItem(
                    value: c,
                    child: Text(c, style: const TextStyle(fontFamily: 'Cairo', fontSize: 13)),
                  )).toList(),
                  onChanged: (val) {
                    if (val != null) {
                      setDialogState(() {
                        _dialogCategory = val;
                      });
                    }
                  },
                ),
                const SizedBox(height: 12),
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
                  final res = await context.read<AppProvider>().recordPettyExpense(
                    amount, 
                    desc, 
                    category: _dialogCategory,
                  );
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

  void _showHeldOrdersDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'الطلبات المعلقة',
                style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 18),
              ),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.pop(ctx),
              ),
            ],
          ),
          content: SizedBox(
            width: double.maxFinite,
            height: MediaQuery.of(context).size.height * 0.4,
            child: Selector<ScanningController, List<HeldOrder>>(
              selector: (_, s) => s.heldOrders,
              builder: (dialogCtx, heldOrders, _) {
                if (heldOrders.isEmpty) {
                  return const Center(
                    child: Text(
                      'لا توجد طلبات معلقة حالياً',
                      style: TextStyle(fontFamily: 'Cairo', fontSize: 14, color: AppColors.textSecondary),
                    ),
                  );
                }
                return ListView.separated(
                  itemCount: heldOrders.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (itemCtx, index) {
                    final order = heldOrders[index];
                    final dateStr = '${order.timestamp.hour.toString().padLeft(2, '0')}:${order.timestamp.minute.toString().padLeft(2, '0')}';
                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(
                        'طلب #${index + 1} - $dateStr',
                        style: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                      subtitle: Text(
                        '${order.itemCount} قطع - الإجمالي: ${order.total.toStringAsFixed(2)} ${AppStrings.currencySymbol}',
                        style: const TextStyle(fontFamily: 'Cairo', fontSize: 12, color: AppColors.textSecondary),
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                              minimumSize: Size.zero,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                            ),
                            onPressed: () async {
                              final controller = context.read<ScanningController>();
                              if (controller.cartItems.isNotEmpty) {
                                final merge = await showDialog<bool>(
                                  context: context,
                                  builder: (confirmCtx) => AlertDialog(
                                    title: const Text('تنبيه', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold)),
                                    content: const Text(
                                      'سلة المشتريات الحالية ليست فارغة. هل تريد دمج الطلب المعلق مع السلة الحالية أم استبدالها؟',
                                      style: TextStyle(fontFamily: 'Cairo', fontSize: 13),
                                    ),
                                    actions: [
                                      TextButton(
                                        onPressed: () => Navigator.pop(confirmCtx, null),
                                        child: const Text('إلغاء', style: TextStyle(fontFamily: 'Cairo')),
                                      ),
                                      TextButton(
                                        onPressed: () => Navigator.pop(confirmCtx, false),
                                        child: const Text('استبدال', style: TextStyle(fontFamily: 'Cairo', color: Colors.red)),
                                      ),
                                      ElevatedButton(
                                        onPressed: () => Navigator.pop(confirmCtx, true),
                                        child: const Text('دمج', style: TextStyle(fontFamily: 'Cairo')),
                                      ),
                                    ],
                                  ),
                                );
                                if (merge == null) return;
                                controller.restoreHeldOrder(order.id, merge: merge);
                              } else {
                                controller.restoreHeldOrder(order.id, merge: false);
                              }
                              if (ctx.mounted) Navigator.pop(ctx);
                            },
                            child: const Text('استرجاع', style: TextStyle(fontFamily: 'Cairo', fontSize: 12)),
                          ),
                          const SizedBox(width: 8),
                          IconButton(
                            icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                            onPressed: () {
                              context.read<ScanningController>().deleteHeldOrder(order.id);
                            },
                          ),
                        ],
                      ),
                    );
                  },
                );
              },
            ),
          ),
        );
      },
    );
  }
}


class _ScannerSection extends StatefulWidget {
  final Function(ScanningController) onCheckout;
  const _ScannerSection({required this.onCheckout});

  @override
  State<_ScannerSection> createState() => _ScannerSectionState();
}

class _ScannerSectionState extends State<_ScannerSection> {
  // Bug #2: declare late so it is initialized in initState(), not at field-
  // construction time. This guarantees a clean native camera session every time
  // the widget enters the tree, and stop()+dispose() on every exit.
  late MobileScannerController _scannerController;

  @override
  void initState() {
    super.initState();
    _scannerController = MobileScannerController(
      detectionSpeed: DetectionSpeed.normal,
      detectionTimeoutMs: 1000,
      returnImage: false,
      formats: [
        BarcodeFormat.ean13,
        BarcodeFormat.ean8,
        BarcodeFormat.code128,
        BarcodeFormat.code39,
        BarcodeFormat.qrCode,
      ],
    );
  }

  @override
  void dispose() {
    // Bug #2: stop() first — releases the native camera session cleanly
    // before the Dart controller object is garbage collected.
    _scannerController.stop();
    _scannerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scanner = context.read<ScanningController>();
    return Stack(
      fit: StackFit.expand,
      children: [

        Positioned.fill(
          child: MobileScanner(
            key: const ValueKey('pos_scanner_preview_view'),
            controller: _scannerController,
            onDetect: (capture) {
              final barcode = capture.barcodes.firstOrNull;
              final raw = barcode?.rawValue;
              if (raw != null && raw.isNotEmpty) {
                scanner.processBarcode(raw);
              }
            },
          ),
        ),
        // Corner bracket target box
        const Center(
          child: _StaticScannerOverlay(),
        ),
        Positioned(
          top: 12,
          left: 12,
          width: 120,
          child: Selector<ScanningController, bool>(
            selector: (_, s) => s.cartItems.isNotEmpty,
            builder: (context, hasItems, _) {
              if (!hasItems) return const SizedBox.shrink();
              return ElevatedButton.icon(
                onPressed: () => context.read<ScanningController>().clearCart(),
                icon: const Icon(Icons.delete_outline, size: 16),
                label: const Text(
                  'مسح السلة',
                  style: TextStyle(fontFamily: 'Cairo', fontSize: 12, fontWeight: FontWeight.bold),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.black54,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                ),
              );
            },
          ),
        ),
        // Bug #7: torch driven by controller's ValueListenable — syncs with
        // real hardware state after backgrounding, incoming calls, OS resets.
        Positioned(
          bottom: 12,
          right: 12,
          child: ValueListenableBuilder(
            valueListenable: _scannerController,
            builder: (context, state, _) {
              final torchOn = state.torchState == TorchState.on;
              return CircleAvatar(
                backgroundColor: Colors.black54,
                child: IconButton(
                  icon: Icon(
                    torchOn ? Icons.flash_on : Icons.flash_off,
                    color: Colors.white,
                  ),
                  onPressed: () => _scannerController.toggleTorch(),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _StaticScannerOverlay extends StatelessWidget {
  const _StaticScannerOverlay();

  @override
  Widget build(BuildContext context) {
    // Luminous Retail: Electric Cyan corner bracket HUD
    const cyan = AppColors.accentGlow;
    const cornerSize = 28.0;
    const strokeWidth = 3.0;

    Widget corner({
      bool top = true,
      bool left = true,
    }) {
      return Container(
        width: cornerSize,
        height: cornerSize,
        decoration: BoxDecoration(
          border: Border(
            top: top ? const BorderSide(color: cyan, width: strokeWidth) : BorderSide.none,
            bottom: !top ? const BorderSide(color: cyan, width: strokeWidth) : BorderSide.none,
            left: left ? const BorderSide(color: cyan, width: strokeWidth) : BorderSide.none,
            right: !left ? const BorderSide(color: cyan, width: strokeWidth) : BorderSide.none,
          ),
        ),
      );
    }

    return Container(
      width: 240,
      height: 140,
      child: Stack(
        children: [
          // Subtle outer glow behind the frame
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(4),
                border: Border.all(
                  color: cyan.withValues(alpha: 0.08),
                  width: 1,
                ),
              ),
            ),
          ),
          Positioned(left: 0, top: 0, child: corner(top: true, left: true)),
          Positioned(right: 0, top: 0, child: corner(top: true, left: false)),
          Positioned(left: 0, bottom: 0, child: corner(top: false, left: true)),
          Positioned(right: 0, bottom: 0, child: corner(top: false, left: false)),
          Center(
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                border: Border.all(color: cyan.withValues(alpha: 0.50), width: 1.5),
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Icon(
                  Icons.qr_code_scanner_outlined,
                  color: cyan.withValues(alpha: 0.80),
                  size: 20,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CartPanel extends StatelessWidget {
  final Function(ScanningController) onCheckout;
  final double taxRate;
  const _CartPanel({required this.onCheckout, required this.taxRate});

  @override
  Widget build(BuildContext context) {
    return Selector<ScanningController, List<CartItem>>(
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
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: AppColors.surfaceVariant,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.shopping_cart_outlined,
                              size: 40,
                              color: AppColors.textHint,
                            ),
                          ),
                          const SizedBox(height: 12),
                          const Text(
                            'السلة فارغة حالياً',
                            style: TextStyle(
                              fontFamily: 'Cairo',
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textSecondary,
                            ),
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            'ابدأ بمسح باركود المنتجات لإضافتها تلقائياً',
                            style: TextStyle(
                              fontFamily: 'Cairo',
                              fontSize: 11,
                              color: AppColors.textHint,
                            ),
                          ),
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
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                decoration: BoxDecoration(
                  color: AppColors.glassCard,
                  border: const Border(
                    top: BorderSide(color: AppColors.glassBorder, width: 1),
                  ),
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Drag handle pill
                    Center(
                      child: Container(
                        width: 36, height: 4,
                        margin: const EdgeInsets.only(bottom: 12),
                        decoration: BoxDecoration(
                          color: AppColors.glassBorder,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    _SummaryRow('المجموع الفرعي',
                        '${scanner.cartSubtotal.toStringAsFixed(2)} ${AppStrings.currencySymbol}'),
                    _SummaryRow('ضريبة (${taxRate.toStringAsFixed(0)}%)',
                        '${scanner.cartTax.toStringAsFixed(2)} ${AppStrings.currencySymbol}'),
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 6),
                      child: Divider(height: 1, color: AppColors.divider),
                    ),
                    _SummaryRow(
                      'الإجمالي',
                      '${scanner.totalAmount.toStringAsFixed(2)} ${AppStrings.currencySymbol}',
                      bold: true,
                      color: AppColors.primary,
                    ),
                    const SizedBox(height: 14),
                    // Luminous gradient checkout button
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [AppColors.primary, AppColors.accentGlow],
                            begin: Alignment.centerRight,
                            end: Alignment.centerLeft,
                          ),
                          borderRadius: BorderRadius.circular(100),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.primary.withValues(alpha: 0.30),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Material(
                          color: Colors.transparent,
                          borderRadius: BorderRadius.circular(100),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(100),
                            onTap: () => onCheckout(scanner),
                            child: Center(
                              child: Text(
                                '${AppStrings.checkout}  •  ${scanner.totalAmount.toStringAsFixed(2)} ${AppStrings.currencySymbol}',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  fontFamily: 'Cairo',
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        );
      },
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
        color: AppColors.glassCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.glassBorder, width: 1),
      ),
      child: Row(
        children: [
          Container(
            width: 44, height: 44,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.08),
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
          color: AppColors.surfaceContainerLow,
          borderRadius: BorderRadius.circular(100),
          border: Border.all(color: AppColors.glassBorder, width: 1),
        ),
        child: Icon(icon, size: 14, color: AppColors.primary),
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
