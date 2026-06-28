import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart' hide TextDirection;
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_strings.dart';
import '../../core/models/models.dart';
import '../../core/providers/app_provider.dart';
import '../../widgets/glass_widgets.dart';
import '../../widgets/receipt_detail_sheet.dart';

class CustomersScreen extends StatefulWidget {
  const CustomersScreen({super.key});

  @override
  State<CustomersScreen> createState() => _CustomersScreenState();
}

class _CustomersScreenState extends State<CustomersScreen> {
  final TextEditingController _searchCtrl = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      if (mounted) {
        context.read<AppProvider>().loadCustomers();
      }
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  void _showAddEditCustomerDialog(BuildContext context, {Customer? customer}) {
    final nameCtrl = TextEditingController(text: customer?.fullName);
    final phoneCtrl = TextEditingController(text: customer?.phoneNumber);
    final addrCtrl = TextEditingController(text: customer?.address);
    bool isSaving = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          final isEdit = customer != null;
          return AlertDialog(
            backgroundColor: AppColors.background,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: Text(
              isEdit ? 'تعديل بيانات العميل' : 'إضافة عميل جديد',
              style: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold),
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: nameCtrl,
                    decoration: const InputDecoration(
                      labelText: 'الاسم الكامل *',
                      prefixIcon: Icon(Icons.person_outline, color: AppColors.primary),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: phoneCtrl,
                    keyboardType: TextInputType.phone,
                    decoration: const InputDecoration(
                      labelText: 'رقم الهاتف',
                      prefixIcon: Icon(Icons.phone_outlined, color: AppColors.primary),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: addrCtrl,
                    decoration: const InputDecoration(
                      labelText: 'العنوان',
                      prefixIcon: Icon(Icons.location_on_outlined, color: AppColors.primary),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('إلغاء', style: TextStyle(fontFamily: 'Cairo')),
              ),
              ElevatedButton(
                onPressed: isSaving
                    ? null
                    : () async {
                        final name = nameCtrl.text.trim();
                        if (name.isEmpty) {
                          ScaffoldMessenger.of(ctx).showSnackBar(
                            const SnackBar(content: Text('الرجاء إدخال الاسم')),
                          );
                          return;
                        }
                        setDialogState(() => isSaving = true);
                        final appProvider = context.read<AppProvider>();
                        bool success;
                        if (isEdit) {
                          success = await appProvider.editCustomer(
                            Customer(
                              id: customer.id,
                              customerId: customer.customerId,
                              fullName: name,
                              phoneNumber: phoneCtrl.text.trim().isEmpty ? null : phoneCtrl.text.trim(),
                              address: addrCtrl.text.trim().isEmpty ? null : addrCtrl.text.trim(),
                            ),
                          );
                        } else {
                          success = await appProvider.addCustomer(
                            fullName: name,
                            phoneNumber: phoneCtrl.text.trim().isEmpty ? null : phoneCtrl.text.trim(),
                            address: addrCtrl.text.trim().isEmpty ? null : addrCtrl.text.trim(),
                          );
                        }
                        if (ctx.mounted) {
                          Navigator.pop(ctx);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(success ? 'تم الحفظ بنجاح ✓' : 'حدث خطأ أثناء الحفظ'),
                              backgroundColor: success ? Colors.green : Colors.red,
                            ),
                          );
                        }
                      },
                child: isSaving
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : const Text('حفظ', style: TextStyle(fontFamily: 'Cairo')),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showCustomerDetailsSheet(BuildContext context, Customer customer) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return _CustomerDetailsWidget(customer: customer);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();
    final isCashier = provider.userRole == 'cashier';

    final filteredCustomers = provider.customers.where((c) {
      final q = _searchQuery.trim().toLowerCase();
      if (q.isEmpty) return true;
      final nameMatches = c.fullName.toLowerCase().contains(q);
      final phoneMatches = c.phoneNumber?.toLowerCase().contains(q) ?? false;
      return nameMatches || phoneMatches;
    }).toList();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('إدارة العملاء', style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => provider.loadCustomers(),
          ),
        ],
      ),
      floatingActionButton: isCashier
          ? null
          : FloatingActionButton.extended(
              onPressed: () => _showAddEditCustomerDialog(context),
              backgroundColor: AppColors.primary,
              icon: const Icon(Icons.person_add_alt_1_outlined, color: Colors.white),
              label: const Text('إضافة عميل', style: TextStyle(fontFamily: 'Cairo', color: Colors.white, fontWeight: FontWeight.bold)),
            ),
      body: SafeArea(
        child: Column(
          children: [
            // Search Bar Card
            Padding(
              padding: const EdgeInsets.all(16),
              child: GlassPanel(
                borderRadius: 16,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: TextField(
                  controller: _searchCtrl,
                  onChanged: (val) => setState(() => _searchQuery = val),
                  decoration: InputDecoration(
                    hintText: 'البحث عن عميل بالاسم أو رقم الهاتف...',
                    prefixIcon: const Icon(Icons.search, color: AppColors.primary),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear, color: AppColors.textHint),
                            onPressed: () {
                              _searchCtrl.clear();
                              setState(() => _searchQuery = '');
                            },
                          )
                        : null,
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                  ),
                ),
              ),
            ),

            // Customers List
            Expanded(
              child: provider.isLoading && provider.customers.isEmpty
                  ? const Center(child: CircularProgressIndicator())
                  : filteredCustomers.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.people_outline, size: 64, color: AppColors.textHint.withValues(alpha: 0.5)),
                              const SizedBox(height: 16),
                              Text(
                                _searchQuery.isEmpty ? 'لا يوجد عملاء مسجلين بعد' : 'لم يتم العثور على نتائج للبحث',
                                style: const TextStyle(fontFamily: 'Cairo', fontSize: 15, color: AppColors.textSecondary),
                              ),
                            ],
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 80),
                          itemCount: filteredCustomers.length,
                          itemBuilder: (context, idx) {
                            final customer = filteredCustomers[idx];
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: GlassPanel(
                                borderRadius: 16,
                                border: Border.all(color: AppColors.glassBorder),
                                onTap: () => _showCustomerDetailsSheet(context, customer),
                                child: Padding(
                                  padding: const EdgeInsets.all(16),
                                  child: Row(
                                    children: [
                                      // Customer Avatar Icon
                                      Container(
                                        width: 48,
                                        height: 48,
                                        decoration: BoxDecoration(
                                          color: AppColors.primaryContainer.withValues(alpha: 0.35),
                                          shape: BoxShape.circle,
                                        ),
                                        child: const Icon(
                                          Icons.person,
                                          color: AppColors.primary,
                                          size: 26,
                                        ),
                                      ),
                                      const SizedBox(width: 16),
                                      // Customer details
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              customer.fullName,
                                              style: const TextStyle(
                                                fontSize: 16,
                                                fontWeight: FontWeight.bold,
                                                color: AppColors.textPrimary,
                                              ),
                                            ),
                                            const SizedBox(height: 4),
                                            Row(
                                              children: [
                                                const Icon(Icons.phone_outlined, size: 13, color: AppColors.textHint),
                                                const SizedBox(width: 4),
                                                Text(
                                                  customer.phoneNumber ?? 'بدون هاتف',
                                                  style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                                                ),
                                                if (customer.address != null) ...[
                                                  const SizedBox(width: 12),
                                                  const Icon(Icons.location_on_outlined, size: 13, color: AppColors.textHint),
                                                  const SizedBox(width: 4),
                                                  Expanded(
                                                    child: Text(
                                                      customer.address!,
                                                      maxLines: 1,
                                                      overflow: TextOverflow.ellipsis,
                                                      style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                                                    ),
                                                  ),
                                                ],
                                              ],
                                            ),
                                          ],
                                        ),
                                      ),
                                      // Action Options
                                      if (!isCashier)
                                        IconButton(
                                          icon: const Icon(Icons.edit_outlined, color: AppColors.primary, size: 20),
                                          onPressed: () => _showAddEditCustomerDialog(context, customer: customer),
                                        ),
                                      const Icon(Icons.chevron_left, color: AppColors.textHint, size: 20),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CustomerDetailsWidget extends StatefulWidget {
  final Customer customer;
  const _CustomerDetailsWidget({required this.customer});

  @override
  State<_CustomerDetailsWidget> createState() => _CustomerDetailsWidgetState();
}

class _CustomerDetailsWidgetState extends State<_CustomerDetailsWidget> {
  List<Sale>? _history;
  bool _isLoadingHistory = true;

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    final appProvider = context.read<AppProvider>();
    final list = await appProvider.getCustomerHistory(widget.customer.customerId);
    if (mounted) {
      setState(() {
        _history = list;
        _isLoadingHistory = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final double totalSpend = _history == null ? 0.0 : _history!.fold(0.0, (sum, item) => sum + item.total);
    final int ordersCount = _history?.length ?? 0;

    return DraggableScrollableSheet(
      initialChildSize: 0.8,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: AppColors.background,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            children: [
              // Bottom sheet drag indicator
              const SizedBox(height: 12),
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.border,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Header Details
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  children: [
                    Container(
                      width: 56,
                      height: 56,
                      decoration: const BoxDecoration(
                        color: AppColors.primaryContainer,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.person, color: AppColors.primary, size: 30),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.customer.fullName,
                            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, fontFamily: 'Cairo'),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            widget.customer.phoneNumber ?? 'بدون هاتف',
                            style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
                          ),
                          if (widget.customer.address != null) ...[
                            const SizedBox(height: 2),
                            Text(
                              widget.customer.address!,
                              style: const TextStyle(fontSize: 12, color: AppColors.textHint),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Statistics Panels
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  children: [
                    Expanded(
                      child: GlassPanel(
                        borderRadius: 14,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        color: AppColors.primary.withValues(alpha: 0.05),
                        border: Border.all(color: AppColors.primary.withValues(alpha: 0.15)),
                        child: Column(
                          children: [
                            const Text('إجمالي المشتريات', style: TextStyle(fontSize: 12, color: AppColors.textSecondary, fontFamily: 'Cairo')),
                            const SizedBox(height: 6),
                            Text(
                              '${totalSpend.toStringAsFixed(2)} ${AppStrings.currencySymbol}',
                              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: AppColors.primary, fontFamily: 'Cairo'),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: GlassPanel(
                        borderRadius: 14,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        color: AppColors.success.withValues(alpha: 0.05),
                        border: Border.all(color: AppColors.success.withValues(alpha: 0.15)),
                        child: Column(
                          children: [
                            const Text('عدد الفواتير', style: TextStyle(fontSize: 12, color: AppColors.textSecondary, fontFamily: 'Cairo')),
                            const SizedBox(height: 6),
                            Text(
                              '$ordersCount',
                              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: AppColors.success, fontFamily: 'Cairo'),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 20),
                child: Align(
                  alignment: Alignment.centerRight,
                  child: Text(
                    'سجل الفواتير والمعاملات',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, fontFamily: 'Cairo'),
                  ),
                ),
              ),
              const SizedBox(height: 10),

              // Scrollable Invoices History
              Expanded(
                child: _isLoadingHistory
                    ? const Center(child: CircularProgressIndicator())
                    : _history == null || _history!.isEmpty
                        ? const Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.receipt_long_outlined, size: 48, color: AppColors.textHint),
                                SizedBox(height: 12),
                                Text(
                                  'لا توجد عمليات بيع مسجلة لهذا العميل',
                                  style: TextStyle(fontFamily: 'Cairo', fontSize: 13, color: AppColors.textSecondary),
                                ),
                              ],
                            ),
                          )
                        : ListView.separated(
                            controller: scrollController,
                            padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                            itemCount: _history!.length,
                            separatorBuilder: (context, index) => const SizedBox(height: 10),
                            itemBuilder: (context, idx) {
                              final sale = _history![idx];
                              return GlassPanel(
                                borderRadius: 12,
                                border: Border.all(color: AppColors.glassBorder),
                                onTap: () => ReceiptDetailSheet.show(context, sale),
                                child: Padding(
                                  padding: const EdgeInsets.all(12),
                                  child: Row(
                                    children: [
                                      Container(
                                        width: 38,
                                        height: 38,
                                        decoration: BoxDecoration(
                                          color: AppColors.primaryContainer.withValues(alpha: 0.35),
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: const Icon(Icons.receipt_outlined, color: AppColors.primary, size: 18),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              sale.receiptNumber,
                                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                            ),
                                            const SizedBox(height: 2),
                                            Text(
                                              '${sale.items.length} منتجات • ${_formatDate(sale.createdAt)}',
                                              style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                                            ),
                                          ],
                                        ),
                                      ),
                                      Column(
                                        crossAxisAlignment: CrossAxisAlignment.end,
                                        children: [
                                          Text(
                                            '${sale.total.toStringAsFixed(2)} ${AppStrings.currencySymbol}',
                                            style: const TextStyle(fontWeight: FontWeight.w900, color: AppColors.primary, fontSize: 13),
                                          ),
                                          Text(
                                            sale.paymentMethod,
                                            style: const TextStyle(fontSize: 10, color: AppColors.textHint),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(width: 4),
                                      const Icon(Icons.chevron_left, color: AppColors.textHint, size: 18),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
              ),
            ],
          ),
        );
      },
    );
  }

  String _formatDate(DateTime dt) {
    return DateFormat('yyyy/MM/dd - hh:mm a', 'ar').format(dt.toLocal());
  }
}
