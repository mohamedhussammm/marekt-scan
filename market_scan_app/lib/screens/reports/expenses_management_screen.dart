import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_strings.dart';
import '../../core/models/models.dart';
import '../../core/providers/app_provider.dart';

class ExpensesManagementScreen extends StatefulWidget {
  const ExpensesManagementScreen({super.key});

  @override
  State<ExpensesManagementScreen> createState() => _ExpensesManagementScreenState();
}

class _ExpensesManagementScreenState extends State<ExpensesManagementScreen> {
  bool _isLoading = true;
  List<PettyExpense> _expenses = [];
  List<Map<String, dynamic>> _categorySummary = [];
  String? _selectedFilterCategory;

  final List<String> _categories = [
    'طاقة / كهرباء وغاز',
    'رواتب',
    'إيجار',
    'بضاعة / مشتريات',
    'صيانة',
    'أخرى',
  ];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    final provider = context.read<AppProvider>();
    try {
      final expensesFuture = provider.fetchAllExpenses(category: _selectedFilterCategory);
      final summaryFuture = provider.fetchExpenseCategorySummary();
      final offlineFuture = provider.getOfflineExpenses();

      final results = await Future.wait([expensesFuture, summaryFuture, offlineFuture]);

      final apiExpenses = results[0] as List<PettyExpense>;
      final rawSummary = results[1] as List<Map<String, dynamic>>;
      final offlineExpenses = results[2] as List<PettyExpense>;

      // Filter offline expenses by category locally if filter category is set
      final filteredOffline = _selectedFilterCategory == null
          ? offlineExpenses
          : offlineExpenses.where((e) => e.category == _selectedFilterCategory).toList();

      final mergedExpenses = [...filteredOffline, ...apiExpenses];
      mergedExpenses.sort((a, b) => b.timestamp.compareTo(a.timestamp));

      // Aggregate offline expenses into the category summary for the Pie Chart
      final Map<String, double> summaryMap = {};
      for (final item in rawSummary) {
        final cat = item['_id'] ?? 'أخرى';
        final val = double.tryParse(item['total']?.toString() ?? '0') ?? 0.0;
        summaryMap[cat] = (summaryMap[cat] ?? 0.0) + val;
      }
      for (final e in offlineExpenses) {
        summaryMap[e.category] = (summaryMap[e.category] ?? 0.0) + e.amount;
      }

      final mergedSummary = summaryMap.entries.map((entry) => {
        '_id': entry.key,
        'total': entry.value,
      }).toList();

      setState(() {
        _expenses = mergedExpenses;
        _categorySummary = mergedSummary;
        _isLoading = false;
      });
    } catch (_) {
      setState(() => _isLoading = false);
    }
  }

  Color _getCategoryColor(String category) {
    switch (category) {
      case 'طاقة / كهرباء وغاز':
        return Colors.orange;
      case 'رواتب':
        return Colors.teal;
      case 'إيجار':
        return Colors.indigo;
      case 'بضاعة / مشتريات':
        return Colors.purple;
      case 'صيانة':
        return Colors.brown;
      default:
        return Colors.blueGrey;
    }
  }

  IconData _getCategoryIcon(String category) {
    switch (category) {
      case 'طاقة / كهرباء وغاز':
        return Icons.bolt;
      case 'رواتب':
        return Icons.people_outline;
      case 'إيجار':
        return Icons.home_work_outlined;
      case 'بضاعة / مشتريات':
        return Icons.shopping_bag_outlined;
      case 'صيانة':
        return Icons.build_outlined;
      default:
        return Icons.category_outlined;
    }
  }

  double get _totalExpensesAmount =>
      _expenses.fold(0.0, (sum, item) => sum + item.amount);

  String _dialogCategory = 'أخرى';

  void _showAddExpenseDialog() {
    final amtCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    _dialogCategory = 'أخرى';
    bool isSubmitting = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: const Text(
              'تسجيل مصروف جديد',
              style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 18),
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<String>(
                    value: _dialogCategory,
                    decoration: const InputDecoration(
                      labelText: 'تصنيف المصروف',
                      labelStyle: TextStyle(fontFamily: 'Cairo'),
                    ),
                    items: _categories
                        .map((c) => DropdownMenuItem(
                              value: c,
                              child: Text(c, style: const TextStyle(fontFamily: 'Cairo', fontSize: 13)),
                            ))
                        .toList(),
                    onChanged: (val) {
                      if (val != null) {
                        setDialogState(() => _dialogCategory = val);
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
                      labelStyle: TextStyle(fontFamily: 'Cairo'),
                      suffixText: 'ج.م',
                      suffixStyle: TextStyle(fontFamily: 'Cairo'),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: descCtrl,
                    decoration: const InputDecoration(
                      labelText: 'الوصف / سبب الصرف',
                      labelStyle: TextStyle(fontFamily: 'Cairo'),
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
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                onPressed: isSubmitting
                    ? null
                    : () async {
                        final amount = double.tryParse(amtCtrl.text) ?? 0.0;
                        final desc = descCtrl.text.trim();
                        if (amount <= 0 || desc.isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('الرجاء إدخال مبلغ صحيح ووصف المصروف')),
                          );
                          return;
                        }
                        setDialogState(() => isSubmitting = true);
                        final res = await context
                            .read<AppProvider>()
                            .recordPettyExpense(amount, desc, category: _dialogCategory);
                        
                        if (ctx.mounted) Navigator.pop(ctx);

                        if (res['success'] == true) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('تم تسجيل المصروف بنجاح!'),
                              backgroundColor: Colors.green,
                            ),
                          );
                          _loadData();
                        } else {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(res['error'] ?? 'فشل تسجيل المصروف'),
                              backgroundColor: Colors.redAccent,
                            ),
                          );
                        }
                      },
                child: isSubmitting
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                      )
                    : const Text('تسجيل', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold)),
              ),
            ],
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('إدارة المصروفات للمسؤول', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold)),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddExpenseDialog,
        backgroundColor: AppColors.primary,
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text('مصروف جديد', style: TextStyle(fontFamily: 'Cairo', color: Colors.white, fontWeight: FontWeight.bold)),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadData,
              // P2 fix: Replace SingleChildScrollView + ListView(shrinkWrap:true)
              // anti-pattern with CustomScrollView + proper Slivers.
              //
              // shrinkWrap:true forces Flutter to measure EVERY item during layout
              // regardless of visibility \u2014 with many expenses this causes a massive
              // layout spike that blocks the UI thread.
              //
              // SliverList.builder only constructs and measures visible items,
              // which is the correct approach for arbitrarily long lists.
              child: CustomScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                slivers: [
                  // \u2500\u2500 KPI Overview Card \u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                      child: _buildOverviewCard(),
                    ),
                  ),

                  // \u2500\u2500 Category Chart (conditional) \u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500
                  if (_categorySummary.isNotEmpty)
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                        child: RepaintBoundary(
                          // RepaintBoundary: isolates PieChart paint region
                          child: _buildCategoryChartCard(),
                        ),
                      ),
                    ),

                  // \u2500\u2500 Filter chips \u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                      child: _buildFilterRow(),
                    ),
                  ),

                  // \u2500\u2500 Section Header \u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                      child: Text(
                        'سجل العمليات الأخير (${_expenses.length})',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          fontFamily: 'Cairo',
                        ),
                      ),
                    ),
                  ),

                  // \u2500\u2500 Expenses List \u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500
                  if (_expenses.isEmpty)
                    SliverToBoxAdapter(
                      child: Center(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 40),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.money_off,
                                  size: 64,
                                  color: AppColors.textHint.withValues(alpha: 0.5)),
                              const SizedBox(height: 12),
                              const Text(
                                'لا توجد مصروفات مسجلة بعد',
                                style: TextStyle(
                                    fontFamily: 'Cairo',
                                    color: AppColors.textSecondary),
                              ),
                            ],
                          ),
                        ),
                      ),
                    )
                  else
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 80),
                      sliver: SliverList.builder(
                        itemCount: _expenses.length,
                        itemBuilder: (context, index) {
                          final item = _expenses[index];
                          final catColor = _getCategoryColor(item.category);
                          final catIcon = _getCategoryIcon(item.category);
                          return Card(
                            margin: const EdgeInsets.only(bottom: 10),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12)),
                            child: ListTile(
                              contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 8),
                              leading: CircleAvatar(
                                backgroundColor: catColor.withValues(alpha: 0.1),
                                child: Icon(catIcon, color: catColor),
                              ),
                              title: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        item.category,
                                        style: TextStyle(
                                          fontFamily: 'Cairo',
                                          fontWeight: FontWeight.bold,
                                          color: catColor,
                                          fontSize: 14,
                                        ),
                                      ),
                                      if (item.isOffline) ...[
                                        const SizedBox(width: 8),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: Colors.amber.shade100,
                                            borderRadius: BorderRadius.circular(6),
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Icon(Icons.sync_problem, size: 12, color: Colors.amber[800]),
                                              const SizedBox(width: 4),
                                              Text(
                                                'في الانتظار',
                                                style: TextStyle(
                                                  fontFamily: 'Cairo',
                                                  fontSize: 10,
                                                  fontWeight: FontWeight.bold,
                                                  color: Colors.amber[800],
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                  Text(
                                    '-${item.amount.toStringAsFixed(2)} ج.م',
                                    style: const TextStyle(
                                      color: Colors.redAccent,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 15,
                                    ),
                                  ),
                                ],
                              ),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const SizedBox(height: 4),
                                  Text(
                                    item.description,
                                    style: const TextStyle(
                                        fontFamily: 'Cairo',
                                        color: AppColors.textPrimary),
                                  ),
                                  const SizedBox(height: 6),
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        'بواسطة: ${item.cashierUsername.isNotEmpty ? item.cashierUsername : context.read<AppProvider>().username}',
                                        style: const TextStyle(
                                            fontFamily: 'Cairo',
                                            fontSize: 11,
                                            color: AppColors.textHint),
                                      ),
                                      Text(
                                        _formatDateTime(item.timestamp),
                                        style: const TextStyle(
                                            fontSize: 11,
                                            color: AppColors.textHint),
                                      ),
                                    ],
                                  ),
                                ],
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

  Widget _buildOverviewCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [AppColors.primary, AppColors.primary.withRed(150)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.3),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.account_balance_outlined, color: Colors.white70, size: 20),
              SizedBox(width: 8),
              Text(
                'إجمالي مصروفات المتجر التراكمية',
                style: TextStyle(fontFamily: 'Cairo', color: Colors.white70, fontSize: 14),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            '${_totalExpensesAmount.toStringAsFixed(2)} ج.م',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 28,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'يتم استقطاع هذه المبالغ تلقائياً من تقرير صافي الأرباح',
            style: TextStyle(fontFamily: 'Cairo', color: Colors.white60, fontSize: 11),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryChartCard() {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'توزيع المصاريف حسب الفئة',
              style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 15),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  flex: 3,
                  child: SizedBox(
                    height: 140,
                    child: PieChart(
                      PieChartData(
                        sectionsSpace: 3,
                        centerSpaceRadius: 35,
                        sections: _categorySummary.asMap().entries.map((entry) {
                          final item = entry.value;
                          final double val = double.tryParse(item['total']?.toString() ?? '0') ?? 0.0;
                          final color = _getCategoryColor(item['_id'] ?? 'أخرى');
                          return PieChartSectionData(
                            value: val,
                            color: color,
                            title: '',
                            radius: 25,
                          );
                        }).toList(),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  flex: 4,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: _categorySummary.map((item) {
                      final name = item['_id'] ?? 'أخرى';
                      final double totalVal = double.tryParse(item['total']?.toString() ?? '0') ?? 0.0;
                      final color = _getCategoryColor(name);
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Row(
                          children: [
                            Container(
                              width: 10,
                              height: 10,
                              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontFamily: 'Cairo', fontSize: 12, color: AppColors.textSecondary),
                              ),
                            ),
                            Text(
                              '${totalVal.toStringAsFixed(0)} ج.م',
                              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterRow() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 8),
            child: ChoiceChip(
              label: const Text('الكل', style: TextStyle(fontFamily: 'Cairo')),
              selected: _selectedFilterCategory == null,
              selectedColor: AppColors.primary,
              labelStyle: TextStyle(
                color: _selectedFilterCategory == null ? Colors.white : AppColors.textSecondary,
                fontWeight: FontWeight.w600,
              ),
              onSelected: (_) {
                setState(() => _selectedFilterCategory = null);
                _loadData();
              },
            ),
          ),
          ..._categories.map((cat) {
            final isSelected = _selectedFilterCategory == cat;
            return Padding(
              padding: const EdgeInsets.only(left: 8),
              child: ChoiceChip(
                label: Text(cat, style: const TextStyle(fontFamily: 'Cairo')),
                selected: isSelected,
                selectedColor: _getCategoryColor(cat),
                labelStyle: TextStyle(
                  color: isSelected ? Colors.white : AppColors.textSecondary,
                  fontWeight: FontWeight.w600,
                ),
                onSelected: (_) {
                  setState(() => _selectedFilterCategory = cat);
                  _loadData();
                },
              ),
            );
          }).toList(),
        ],
      ),
    );
  }

  String _formatDateTime(DateTime dt) {
    final local = dt.toLocal();
    final padMin = local.minute.toString().padLeft(2, '0');
    return '${local.year}/${local.month}/${local.day} ${local.hour}:$padMin';
  }
}
