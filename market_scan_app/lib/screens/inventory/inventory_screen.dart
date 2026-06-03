import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:google_mlkit_barcode_scanning/google_mlkit_barcode_scanning.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_strings.dart';
import '../../core/models/models.dart';
import '../../core/providers/app_provider.dart';
import '../../widgets/camera_view.dart';

class InventoryScreen extends StatefulWidget {
  const InventoryScreen({super.key});

  @override
  State<InventoryScreen> createState() => _InventoryScreenState();
}

class _InventoryScreenState extends State<InventoryScreen>
    with AutomaticKeepAliveClientMixin {
  final _searchCtrl = TextEditingController();
  Timer? _debounce;

  @override
  bool get wantKeepAlive => true;

  @override
  void dispose() {
    _searchCtrl.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _onSearchChanged(String val, AppProvider provider) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 200), () {
      provider.setSearchQuery(val);
    });
  }

  void _showAddProductDialog(BuildContext context, {Product? product}) {
    final isEdit = product != null;
    final nameCtrl = TextEditingController(text: product?.name ?? '');
    final barcodeCtrl = TextEditingController(text: product?.barcode ?? '');
    final categoryCtrl = TextEditingController(text: product?.category ?? '');
    final costCtrl = TextEditingController(text: product?.costPrice.toString() ?? '');
    final sellCtrl = TextEditingController(text: product?.sellingPrice.toString() ?? '');
    final stockCtrl = TextEditingController(text: product?.stockQuantity.toString() ?? '');
    final minCtrl = TextEditingController(text: product?.minStockLevel.toString() ?? '');

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => Padding(
        padding: EdgeInsets.fromLTRB(
            20, 20, 20, MediaQuery.of(ctx).viewInsets.bottom + 20),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(child: Container(
                  width: 40, height: 4,
                  decoration: BoxDecoration(color: AppColors.border,
                      borderRadius: BorderRadius.circular(2)))),
              const SizedBox(height: 16),
              Text(isEdit ? AppStrings.editProduct : AppStrings.addProduct,
                  style: Theme.of(context).textTheme.headlineSmall),
              const SizedBox(height: 20),
              _FormField(ctrl: nameCtrl, label: AppStrings.productName, icon: Icons.inventory_2_outlined),
              const SizedBox(height: 12),
              _FormField(
                ctrl: barcodeCtrl,
                label: AppStrings.barcode,
                icon: Icons.qr_code,
                suffixIcon: IconButton(
                  icon: const Icon(Icons.camera_alt_outlined, color: AppColors.primary),
                  onPressed: () async {
                    // Open scan sheet
                    final scanned = await showModalBottomSheet<String>(
                      context: ctx,
                      isScrollControlled: true,
                      backgroundColor: Colors.black,
                      shape: const RoundedRectangleBorder(
                          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
                      builder: (_) => const BarcodeScannerSheet(),
                    );
                    if (scanned != null && scanned.isNotEmpty) {
                      barcodeCtrl.text = scanned;
                    }
                  },
                ),
              ),
              const SizedBox(height: 12),
              _FormField(ctrl: categoryCtrl, label: AppStrings.category, icon: Icons.category_outlined),
              const SizedBox(height: 12),
              Row(children: [
                Expanded(child: _FormField(ctrl: costCtrl, label: AppStrings.costPrice, icon: Icons.money, numeric: true)),
                const SizedBox(width: 12),
                Expanded(child: _FormField(ctrl: sellCtrl, label: AppStrings.sellingPrice, icon: Icons.sell_outlined, numeric: true)),
              ]),
              const SizedBox(height: 12),
              Row(children: [
                Expanded(child: _FormField(ctrl: stockCtrl, label: AppStrings.stockQuantity, icon: Icons.layers_outlined, numeric: true)),
                const SizedBox(width: 12),
                Expanded(child: _FormField(ctrl: minCtrl, label: AppStrings.minStockLevel, icon: Icons.warning_amber_outlined, numeric: true)),
              ]),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: () {
                  final p = Product(
                    id: product?.id ?? DateTime.now().millisecondsSinceEpoch.toString(),
                    name: nameCtrl.text,
                    barcode: barcodeCtrl.text,
                    category: categoryCtrl.text,
                    costPrice: double.tryParse(costCtrl.text) ?? 0,
                    sellingPrice: double.tryParse(sellCtrl.text) ?? 0,
                    stockQuantity: int.tryParse(stockCtrl.text) ?? 0,
                    minStockLevel: int.tryParse(minCtrl.text) ?? 5,
                  );
                  if (isEdit) {
                    context.read<AppProvider>().updateProduct(p);
                  } else {
                    context.read<AppProvider>().addProduct(p);
                  }
                  Navigator.pop(ctx);
                },
                child: Text(AppStrings.save),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showStockInDialog(BuildContext context, Product product) {
    final ctrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('إضافة مخزون - ${product.name}'),
        content: TextField(
          controller: ctrl,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(labelText: 'الكمية المضافة'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text(AppStrings.cancel)),
          ElevatedButton(
            onPressed: () {
              final qty = int.tryParse(ctrl.text) ?? 0;
              if (qty > 0) context.read<AppProvider>().addStock(product.id, qty);
              Navigator.pop(ctx);
            },
            child: const Text(AppStrings.save),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final provider = context.read<AppProvider>();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text(AppStrings.inventoryManagement),
        automaticallyImplyLeading: false,
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddProductDialog(context),
        backgroundColor: AppColors.primary,
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text(AppStrings.addProduct, style: TextStyle(color: Colors.white)),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              controller: _searchCtrl,
              onChanged: (val) => _onSearchChanged(val, provider),
              decoration: InputDecoration(
                hintText: 'بحث في المخزون...',
                prefixIcon: const Icon(Icons.search, color: AppColors.primary),
                suffixIcon: ValueListenableBuilder<TextEditingValue>(
                  valueListenable: _searchCtrl,
                  builder: (context, value, __) {
                    if (value.text.isEmpty) return const SizedBox.shrink();
                    return IconButton(
                      icon: const Icon(Icons.clear, size: 18),
                      onPressed: () {
                        _searchCtrl.clear();
                        provider.setSearchQuery('');
                      },
                    );
                  },
                ),
              ),
            ),
          ),
          // Summary chips
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              children: [
                Selector<AppProvider, int>(
                  selector: (_, p) => p.products.length,
                  builder: (_, count, __) => _SummaryChip('$count منتج', Icons.inventory_2_outlined, AppColors.primary),
                ),
                const SizedBox(width: 8),
                Selector<AppProvider, int>(
                  selector: (_, p) => p.lowStockProducts.length,
                  builder: (_, count, __) => _SummaryChip('$count منخفض', Icons.warning_amber, AppColors.warning),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: RefreshIndicator(
              onRefresh: () => provider.loadProducts(),
              child: Selector<AppProvider, List<Product>>(
                selector: (_, p) => p.filteredProducts,
                builder: (context, filteredProducts, __) {
                  if (filteredProducts.isEmpty) {
                    return const Center(child: Text('لا توجد منتجات مطابقة'));
                  }
                  return ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    itemCount: filteredProducts.length,
                    itemBuilder: (context, i) {
                      final p = filteredProducts[i];
                      return _ProductListTile(
                        product: p,
                        onEdit: () => _showAddProductDialog(context, product: p),
                        onDelete: () {
                          showDialog(
                            context: context,
                            builder: (_) => AlertDialog(
                              title: const Text('حذف منتج'),
                              content: Text('هل تريد حذف ${p.name}؟'),
                              actions: [
                                TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء')),
                                ElevatedButton(
                                  onPressed: () {
                                    context.read<AppProvider>().deleteProduct(p.barcode);
                                    Navigator.pop(context);
                                  },
                                  style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
                                  child: const Text('حذف'),
                                ),
                              ],
                            ),
                          );
                        },
                        onStockIn: () => _showStockInDialog(context, p),
                      );
                    },
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SummaryChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  const _SummaryChip(this.label, this.icon, this.color);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 16),
          const SizedBox(width: 6),
          Text(label, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

class _ProductListTile extends StatelessWidget {
  final Product product;
  final VoidCallback onEdit, onDelete, onStockIn;
  const _ProductListTile({required this.product, required this.onEdit, required this.onDelete, required this.onStockIn});

  @override
  Widget build(BuildContext context) {
    final stockColor = product.stockQuantity <= product.minStockLevel ? AppColors.warning : AppColors.success;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: ListTile(
        leading: Container(
          width: 44, height: 44,
          decoration: BoxDecoration(
            color: AppColors.primary.withOpacity(0.08),
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Icon(Icons.inventory_2_outlined, color: AppColors.primary, size: 22),
        ),
        title: Text(product.name, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${product.category} • ${product.barcode}',
                style: const TextStyle(fontSize: 11, color: AppColors.textHint)),
            const SizedBox(height: 2),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: stockColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text('${product.stockQuantity} ${AppStrings.pieces}',
                      style: TextStyle(
                          fontSize: 11, color: stockColor,
                          fontWeight: FontWeight.w600)),
                ),
                const SizedBox(width: 6),
                Text('بيع: ${product.sellingPrice.toStringAsFixed(0)} ${AppStrings.currencySymbol}',
                    style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
              ],
            ),
          ],
        ),
        trailing: PopupMenuButton<String>(
          icon: const Icon(Icons.more_vert, color: AppColors.textHint),
          onSelected: (v) {
            if (v == 'edit') onEdit();
            if (v == 'delete') onDelete();
            if (v == 'stock') onStockIn();
          },
          itemBuilder: (_) => [
            const PopupMenuItem(value: 'stock', child: Row(children: [
              Icon(Icons.add_box_outlined, size: 18, color: AppColors.success),
              SizedBox(width: 8), Text('إضافة مخزون'),
            ])),
            const PopupMenuItem(value: 'edit', child: Row(children: [
              Icon(Icons.edit_outlined, size: 18, color: AppColors.info),
              SizedBox(width: 8), Text('تعديل'),
            ])),
            const PopupMenuItem(value: 'delete', child: Row(children: [
              Icon(Icons.delete_outline, size: 18, color: AppColors.error),
              SizedBox(width: 8), Text('حذف', style: TextStyle(color: AppColors.error)),
            ])),
          ],
        ),
      ),
    );
  }
}

class _FormField extends StatelessWidget {
  final TextEditingController ctrl;
  final String label;
  final IconData icon;
  final bool numeric;
  final Widget? suffixIcon;
  const _FormField({
    required this.ctrl,
    required this.label,
    required this.icon,
    this.numeric = false,
    this.suffixIcon,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: ctrl,
      keyboardType: numeric ? TextInputType.number : TextInputType.text,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: AppColors.primary, size: 20),
        suffixIcon: suffixIcon,
      ),
    );
  }
}

class BarcodeScannerSheet extends StatefulWidget {
  const BarcodeScannerSheet({super.key});

  @override
  State<BarcodeScannerSheet> createState() => _BarcodeScannerSheetState();
}

class _BarcodeScannerSheetState extends State<BarcodeScannerSheet> {
  final BarcodeScanner _barcodeScanner = BarcodeScanner(formats: [BarcodeFormat.all]);
  bool _isProcessing = false;

  @override
  void dispose() {
    _barcodeScanner.close();
    super.dispose();
  }

  Future<void> _processImage(InputImage inputImage) async {
    if (_isProcessing) return;
    _isProcessing = true;

    try {
      final barcodes = await _barcodeScanner.processImage(inputImage);
      if (barcodes.isNotEmpty) {
        final rawBarcode = barcodes.first.displayValue;
        if (rawBarcode != null && rawBarcode.isNotEmpty) {
          HapticFeedback.vibrate();
          if (mounted) {
            Navigator.pop(context, rawBarcode);
          }
          return;
        }
      }
    } catch (e) {
      print("Error in form ML Kit: $e");
    } finally {
      _isProcessing = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.7,
      color: Colors.black,
      child: Stack(
        children: [
          CameraView(onImage: _processImage),
          Center(
            child: Container(
              width: 250,
              height: 250,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.green, width: 2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const _AnimatedScanningLine(),
            ),
          ),
          Positioned(
            top: 20,
            right: 20,
            child: IconButton(
              icon: const Icon(Icons.close, color: Colors.white, size: 28),
              onPressed: () => Navigator.pop(context),
            ),
          ),
          const Positioned(
            bottom: 40,
            left: 0,
            right: 0,
            child: Text(
              'ضع الباركود داخل المربع للمسح الضوئي',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}

class _AnimatedScanningLine extends StatefulWidget {
  const _AnimatedScanningLine();

  @override
  State<_AnimatedScanningLine> createState() => _AnimatedScanningLineState();
}

class _AnimatedScanningLineState extends State<_AnimatedScanningLine> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
    _animation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Stack(
          children: [
            Positioned(
              top: _animation.value * 248,
              left: 0,
              right: 0,
              child: Container(
                height: 2,
                decoration: const BoxDecoration(
                  color: Colors.green,
                  boxShadow: [
                    BoxShadow(color: Colors.green, blurRadius: 4, spreadRadius: 1),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
