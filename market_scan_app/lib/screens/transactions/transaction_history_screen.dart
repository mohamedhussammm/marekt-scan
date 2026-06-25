import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_strings.dart';
import '../../core/providers/app_provider.dart';
import '../../core/models/models.dart';
import '../../services/db_helper.dart';
import '../../widgets/receipt_detail_sheet.dart';

class TransactionHistoryScreen extends StatefulWidget {
  const TransactionHistoryScreen({super.key});

  @override
  State<TransactionHistoryScreen> createState() => _TransactionHistoryScreenState();
}

class _TransactionHistoryScreenState extends State<TransactionHistoryScreen> {
  static final _timeFmt = DateFormat('hh:mm a', 'ar');
  static final _dateFmt = DateFormat('yyyy-MM-dd', 'ar');
  static const int _pageSize = 30;

  final ScrollController _scrollCtrl = ScrollController();
  final TextEditingController _searchCtrl = TextEditingController();

  List<dynamic> _transactions = []; // List of Sale / parsed transactions
  List<dynamic> _pendingTransactions = []; // Offline pending operations (Sales / Expenses)
  
  int _currentPage = 1;
  bool _isInitialLoading = true;
  bool _isLoadingMore = false;
  bool _hasMore = true;
  String? _error;
  Timer? _debounce;
  String _selectedType = 'الكل'; // 'الكل' | 'المبيعات' | 'المصروفات'

  @override
  void initState() {
    super.initState();
    _scrollCtrl.addListener(_onScroll);
    _loadInitialData();
  }

  @override
  void dispose() {
    _scrollCtrl.dispose();
    _searchCtrl.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _onScroll() {
    if (!_hasMore || _isLoadingMore || _isInitialLoading) return;
    if (_scrollCtrl.position.pixels >= _scrollCtrl.position.maxScrollExtent - 400) {
      _loadMoreData();
    }
  }

  void _onSearchChanged(String val) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () {
      _loadInitialData();
    });
  }

  Future<void> _loadInitialData() async {
    if (!mounted) return;
    setState(() {
      _isInitialLoading = true;
      _error = null;
      _currentPage = 1;
      _hasMore = true;
    });

    try {
      // 1. Load offline pending transactions and expenses
      final db = DatabaseHelper.instance;
      final pendingOps = await db.getPendingOps();
      final pendingExpenses = await db.getOfflineExpenses();

      final List<dynamic> localPending = [];

      // Map pending sales
      for (final op in pendingOps) {
        if (op.operation == 'checkout') {
          try {
            final payload = op.payload;
            final List<dynamic> itemsData = payload['items'] ?? [];
            final items = itemsData.map((it) {
              final double price = (it['unitPrice'] ?? 0).toDouble();
              final int qty = (it['qty'] ?? 1).toInt();
              return CartItem(
                product: Product(
                  id: it['barcodeId'],
                  barcode: it['barcodeId'],
                  name: it['name'],
                  category: 'عام',
                  costPrice: price * 0.7,
                  sellingPrice: price,
                  stockQuantity: 100,
                  minStockLevel: 10,
                ),
                quantity: qty,
              );
            }).toList();

            localPending.add(Sale(
              id: op.offlineId,
              receiptNumber: 'INV-معلق',
              items: items,
              subtotal: (payload['totalAmount'] ?? 0.0).toDouble(),
              discount: 0,
              tax: 0,
              total: (payload['totalAmount'] ?? 0.0).toDouble(),
              amountPaid: (payload['totalAmount'] ?? 0.0).toDouble(),
              paymentMethod: payload['paymentMethod'] ?? 'نقداً',
              createdAt: op.createdAt,
              isOffline: true,
              type: 'sale',
              cashierName: 'أوفلاين',
            ));
          } catch (_) {}
        }
      }

      // Map pending expenses
      for (final exp in pendingExpenses) {
        localPending.add(Sale(
          id: exp.id,
          receiptNumber: 'EXP-معلق',
          items: [
            CartItem(
              product: Product(
                id: 'EXPENSE',
                barcode: 'EXPENSE',
                name: exp.description,
                category: exp.category,
                costPrice: exp.amount,
                sellingPrice: exp.amount,
                stockQuantity: 1,
                minStockLevel: 0,
              ),
              quantity: 1,
            )
          ],
          subtotal: exp.amount,
          discount: 0,
          tax: 0,
          total: exp.amount,
          amountPaid: exp.amount,
          paymentMethod: 'نقداً',
          createdAt: exp.timestamp,
          isOffline: true,
          type: 'expense',
          cashierName: 'أوفلاين',
        ));
      }

      // Sort pending items descending by date
      localPending.sort((a, b) => b.createdAt.compareTo(a.createdAt));

      // 2. Fetch first page from API
      final api = context.read<AppProvider>().api;
      final skip = 0;
      final serverList = await api.getTransactions(limit: _pageSize, skip: skip);

      final List<dynamic> mappedServer = [];
      for (final tx in serverList) {
        try {
          final isExp = tx['type'] == 'expense';
          final List<dynamic> itemsData = tx['items'] ?? [];
          final items = itemsData.map((it) {
            final double price = (it['unitPrice'] ?? 0.0).toDouble();
            final int qty = (it['qty'] ?? 1).toInt();
            return CartItem(
              product: Product(
                id: it['barcodeId'] ?? 'item',
                barcode: it['barcodeId'] ?? 'item',
                name: it['name'] ?? '',
                category: isExp ? 'مصروفات' : 'عام',
                costPrice: price * 0.7,
                sellingPrice: price,
                stockQuantity: 100,
                minStockLevel: 10,
              ),
              quantity: qty,
            );
          }).toList();

          mappedServer.add(Sale(
            id: tx['_id'],
            receiptNumber: tx['receiptNumber'] ?? 'REC-000',
            items: items,
            subtotal: double.tryParse(tx['totalAmount'].toString()) ?? 0.0,
            discount: 0,
            tax: 0,
            total: double.tryParse(tx['totalAmount'].toString()) ?? 0.0,
            amountPaid: double.tryParse(tx['totalAmount'].toString()) ?? 0.0,
            paymentMethod: tx['paymentMethod'] ?? 'نقداً',
            createdAt: DateTime.parse(tx['createdAt']),
            type: tx['type'] ?? 'sale',
            cashierName: tx['cashierName'] ?? '',
          ));
        } catch (_) {}
      }

      if (!mounted) return;
      setState(() {
        _pendingTransactions = localPending;
        _transactions = mappedServer;
        _isInitialLoading = false;
        _hasMore = serverList.length >= _pageSize;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isInitialLoading = false;
        _error = 'تعذر تحميل سجل المعاملات. تأكد من اتصالك بالشبكة.';
      });
    }
  }

  Future<void> _loadMoreData() async {
    if (_isLoadingMore) return;
    setState(() => _isLoadingMore = true);

    try {
      final api = context.read<AppProvider>().api;
      final skip = _transactions.length;
      final serverList = await api.getTransactions(limit: _pageSize, skip: skip);

      final List<dynamic> mappedServer = [];
      for (final tx in serverList) {
        try {
          final isExp = tx['type'] == 'expense';
          final List<dynamic> itemsData = tx['items'] ?? [];
          final items = itemsData.map((it) {
            final double price = (it['unitPrice'] ?? 0.0).toDouble();
            final int qty = (it['qty'] ?? 1).toInt();
            return CartItem(
              product: Product(
                id: it['barcodeId'] ?? 'item',
                barcode: it['barcodeId'] ?? 'item',
                name: it['name'] ?? '',
                category: isExp ? 'مصروفات' : 'عام',
                costPrice: price * 0.7,
                sellingPrice: price,
                stockQuantity: 100,
                minStockLevel: 10,
              ),
              quantity: qty,
            );
          }).toList();

          mappedServer.add(Sale(
            id: tx['_id'],
            receiptNumber: tx['receiptNumber'] ?? 'REC-000',
            items: items,
            subtotal: double.tryParse(tx['totalAmount'].toString()) ?? 0.0,
            discount: 0,
            tax: 0,
            total: double.tryParse(tx['totalAmount'].toString()) ?? 0.0,
            amountPaid: double.tryParse(tx['totalAmount'].toString()) ?? 0.0,
            paymentMethod: tx['paymentMethod'] ?? 'نقداً',
            createdAt: DateTime.parse(tx['createdAt']),
            type: tx['type'] ?? 'sale',
            cashierName: tx['cashierName'] ?? '',
          ));
        } catch (_) {}
      }

      if (!mounted) return;
      setState(() {
        _transactions.addAll(mappedServer);
        _isLoadingMore = false;
        _currentPage++;
        _hasMore = serverList.length >= _pageSize;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isLoadingMore = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('خطأ أثناء تحميل المزيد من البيانات.')),
      );
    }
  }

  List<dynamic> _getFilteredTransactions() {
    final query = _searchCtrl.text.toLowerCase().trim();
    
    // Helper to match filter criteria
    bool matchesFilter(dynamic item) {
      // 1. Type Filter
      if (_selectedType == 'المبيعات' && item.type != 'sale') return false;
      if (_selectedType == 'المصروفات' && item.type != 'expense') return false;

      // 2. Search query filter
      if (query.isNotEmpty) {
        final matchesReceipt = item.receiptNumber.toLowerCase().contains(query);
        final matchesCashier = (item.cashierName ?? '').toLowerCase().contains(query);
        final matchesItemNames = item.items.any((CartItem it) => it.product.name.toLowerCase().contains(query));
        return matchesReceipt || matchesCashier || matchesItemNames;
      }
      return true;
    }

    // Combine pending (if not in search or matches filter) and historical transactions
    final combined = [..._pendingTransactions, ..._transactions];
    return combined.where(matchesFilter).toList();
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _getFilteredTransactions();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('سجل المعاملات المالي', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold)),
        elevation: 0,
      ),
      body: Column(
        children: [
          // 1. Search Box
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: TextField(
              controller: _searchCtrl,
              onChanged: _onSearchChanged,
              decoration: InputDecoration(
                hintText: 'ابحث برقم الفاتورة، اسم الكاشير، أو المنتج...',
                hintStyle: const TextStyle(fontSize: 13, fontFamily: 'Cairo'),
                prefixIcon: const Icon(Icons.search, color: AppColors.primary),
                suffixIcon: _searchCtrl.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, size: 20),
                        onPressed: () {
                          _searchCtrl.clear();
                          _loadInitialData();
                        },
                      )
                    : null,
                filled: true,
                fillColor: Colors.white,
                contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 16),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppColors.border),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
                ),
              ),
            ),
          ),

          // 2. Filter Chips
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Row(
              children: ['الكل', 'المبيعات', 'المصروفات'].map((type) {
                final isSelected = _selectedType == type;
                return Padding(
                  padding: const EdgeInsets.only(left: 8),
                  child: ChoiceChip(
                    label: Text(type, style: TextStyle(fontFamily: 'Cairo', fontSize: 13, color: isSelected ? Colors.white : AppColors.textSecondary)),
                    selected: isSelected,
                    selectedColor: AppColors.primary,
                    backgroundColor: Colors.white,
                    side: BorderSide(color: isSelected ? AppColors.primary : AppColors.border),
                    onSelected: (val) {
                      if (val) {
                        setState(() => _selectedType = type);
                      }
                    },
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 8),

          // 3. Transactions list or state message
          Expanded(
            child: RefreshIndicator(
              onRefresh: _loadInitialData,
              child: _buildMainContent(filtered),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMainContent(List<dynamic> filtered) {
    if (_isInitialLoading) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.primary),
      );
    }

    if (_error != null && filtered.isEmpty) {
      return SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: Container(
          height: 400,
          alignment: Alignment.center,
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 60, color: Colors.redAccent),
              const SizedBox(height: 16),
              Text(
                _error!,
                textAlign: TextAlign.center,
                style: const TextStyle(fontFamily: 'Cairo', color: AppColors.textSecondary),
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: _loadInitialData,
                icon: const Icon(Icons.refresh),
                label: const Text('إعادة المحاولة', style: TextStyle(fontFamily: 'Cairo')),
              )
            ],
          ),
        ),
      );
    }

    if (filtered.isEmpty) {
      return SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: Container(
          height: 400,
          alignment: Alignment.center,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.receipt_long_outlined, size: 64, color: AppColors.textHint.withValues(alpha: 0.5)),
              const SizedBox(height: 16),
              const Text(
                'لا توجد معاملات مطابقة للبحث.',
                style: TextStyle(fontFamily: 'Cairo', color: AppColors.textSecondary),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      controller: _scrollCtrl,
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      itemCount: filtered.length + (_isLoadingMore ? 1 : 0),
      addAutomaticKeepAlives: false,
      addRepaintBoundaries: true,
      itemBuilder: (context, index) {
        if (index == filtered.length) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Center(
              child: SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary),
              ),
            ),
          );
        }

        final item = filtered[index];
        return RepaintBoundary(
          child: _TransactionHistoryTile(
            item: item,
            timeFmt: _timeFmt,
            dateFmt: _dateFmt,
          ),
        );
      },
    );
  }
}

class _TransactionHistoryTile extends StatelessWidget {
  final dynamic item;
  final DateFormat timeFmt;
  final DateFormat dateFmt;

  const _TransactionHistoryTile({
    required this.item,
    required this.timeFmt,
    required this.dateFmt,
  });

  @override
  Widget build(BuildContext context) {
    final isExpense = item.type == 'expense';
    final isOffline = item.isOffline == true;

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(
          color: isOffline ? Colors.orange.withValues(alpha: 0.3) : AppColors.border,
          width: isOffline ? 1.2 : 1,
        ),
      ),
      color: isOffline
          ? Colors.orange.withValues(alpha: 0.02)
          : isExpense
              ? Colors.red.withValues(alpha: 0.01)
              : Colors.white,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: isExpense
            ? () {
                showDialog(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    title: const Text('تفاصيل المصروف النقدي', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold)),
                    content: Text(
                      'الوصف: ${item.items.isNotEmpty ? item.items.first.product.name : "-"}\nالمبلغ: ${item.total.toStringAsFixed(2)} ${AppStrings.currencySymbol}\nالوقت: ${dateFmt.format(item.createdAt)} ${timeFmt.format(item.createdAt)}\nالحالة: ${isOffline ? "معلق (أوفلاين)" : "تمت المزامنة"}',
                      style: const TextStyle(fontFamily: 'Cairo', height: 1.7, fontSize: 14),
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(ctx),
                        child: const Text('إغلاق', style: TextStyle(fontFamily: 'Cairo')),
                      ),
                    ],
                  ),
                );
              }
            : () => ReceiptDetailSheet.show(context, item),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              // Icon Badge
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: isOffline
                      ? Colors.orange.withValues(alpha: 0.08)
                      : isExpense
                          ? Colors.red.withValues(alpha: 0.08)
                          : AppColors.primaryContainer,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  isOffline
                      ? Icons.cloud_off_outlined
                      : isExpense
                          ? Icons.money_off_outlined
                          : Icons.receipt_outlined,
                  color: isOffline
                      ? Colors.orange
                      : isExpense
                          ? Colors.redAccent
                          : AppColors.primary,
                  size: 24,
                ),
              ),
              const SizedBox(width: 14),

              // Title and Subtitle
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          item.receiptNumber,
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, fontFamily: 'Cairo'),
                        ),
                        if (isOffline) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.orange.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.access_time, size: 10, color: Colors.orange),
                                SizedBox(width: 3),
                                Text(
                                  'معلق أوفلاين',
                                  style: TextStyle(color: Colors.orange, fontSize: 9, fontFamily: 'Cairo', fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                          ),
                        ]
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${dateFmt.format(item.createdAt)}  •  ${timeFmt.format(item.createdAt)}',
                      style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                    ),
                  ],
                ),
              ),

              // Right-aligned Price / Payment details
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '${isExpense ? "-" : "+"}${item.total.toStringAsFixed(2)} ${AppStrings.currencySymbol}',
                    style: TextStyle(
                      fontFamily: 'Cairo',
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                      color: isExpense ? Colors.redAccent : AppColors.primary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    item.paymentMethod,
                    style: const TextStyle(fontSize: 10, color: AppColors.textHint, fontFamily: 'Cairo'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
