import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_strings.dart';
import '../../core/providers/app_provider.dart';
import '../../widgets/receipt_detail_sheet.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen>
    with AutomaticKeepAliveClientMixin {
  static final _currencyFmt = NumberFormat('#,##0.00', 'ar');
  Timer? _refreshTimer;
  bool _isRefreshing = false;
  int _offlineSkipCount = 0; // number of remaining ticks to skip after a SocketException

  @override
  void initState() {
    super.initState();
    // Load dashboard stats immediately on startup
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadData();
    });

    // Set up periodic 15-second background updates
    _refreshTimer = Timer.periodic(const Duration(seconds: 15), (_) async {
      if (!mounted) return;

      // Back off silently when we know the device is offline
      if (_offlineSkipCount > 0) {
        _offlineSkipCount--;
        return;
      }

      // Prevent concurrent refreshes
      if (_isRefreshing) return;
      _loadData();
    });
  }

  Future<void> _loadData() async {
    if (!mounted) return;
    setState(() => _isRefreshing = true);

    try {
      await context.read<AppProvider>().loadDashboardStats(rethrowNetworkErrors: true);
      _offlineSkipCount = 0; // reset backoff on success
    } catch (e) {
      final errStr = e.toString();
      final isNetworkError = e is SocketException || errStr.contains('SocketException') || errStr.contains('Connection failed') || errStr.contains('Network is unreachable');
      if (isNetworkError) {
        // Device has no network — back off for 4 ticks (~60 s) and stay quiet
        _offlineSkipCount = 4;
      }
    } finally {
      if (mounted) {
        setState(() => _isRefreshing = false);
      }
    }
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    // P0 fix: context.read for provider actions (no subscription needed).
    // context.select for isCashier — only rebuilds when role changes,
    // not on every 15-second dashboard poll notifyListeners().
    final provider = context.read<AppProvider>();
    final isCashier = context.select<AppProvider, bool>((p) => p.userRole == 'cashier');

    return Scaffold(
      backgroundColor: AppColors.background,
      body: RefreshIndicator(
        onRefresh: () async {
          await provider.loadProducts();
          await provider.loadDashboardStats();
        },
        child: CustomScrollView(
          slivers: [
            // App Bar
            SliverAppBar(
              expandedHeight: 140,
              pinned: true,
              backgroundColor: AppColors.primary,
              flexibleSpace: FlexibleSpaceBar(
                background: Container(
                  color: AppColors.primary,
                  padding: const EdgeInsets.fromLTRB(20, 60, 20, 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Text(
                        'مرحباً بك 👋',
                        style: TextStyle(color: Colors.white.withValues(alpha: 0.8), fontSize: 13),
                      ),
                      const SizedBox(height: 2),
                      Selector<AppProvider, String>(
                        selector: (_, p) => p.storeName,
                        builder: (_, storeName, __) => Text(
                          storeName,
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.w700),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                if (!isCashier)
                  IconButton(
                    icon: Stack(
                      children: [
                        const Icon(Icons.notifications_outlined, color: Colors.white),
                        Selector<AppProvider, bool>(
                          selector: (_, p) => p.lowStockProducts.isNotEmpty,
                          builder: (_, hasLowStock, __) {
                            if (!hasLowStock) return const SizedBox.shrink();
                            return Positioned(
                              top: 0, right: 0,
                              child: Container(
                                width: 8, height: 8,
                                decoration: const BoxDecoration(
                                    color: AppColors.secondary, shape: BoxShape.circle),
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                    onPressed: () => Navigator.pushNamed(context, '/alerts'),
                  ),
              ],
            ),

            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              sliver: SliverGrid(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  childAspectRatio: 1.5,
                ),
                delegate: SliverChildListDelegate([
                  Selector<AppProvider, double>(
                    selector: (_, p) => p.todaySalesTotal,
                    builder: (context, todaySalesTotal, __) => _StatCard(
                      title: AppStrings.todaySales,
                      value: '${_currencyFmt.format(todaySalesTotal)} ${AppStrings.currencySymbol}',
                      icon: Icons.trending_up,
                      color: AppColors.primary,
                      onTap: isCashier ? null : () => Navigator.pushNamed(context, '/reports'),
                      isDimmed: isCashier,
                    ),
                  ),
                  Selector<AppProvider, int>(
                    selector: (_, p) => p.todayOrdersCount,
                    builder: (context, todayOrdersCount, __) => _StatCard(
                      title: AppStrings.totalOrders,
                      value: '$todayOrdersCount',
                      icon: Icons.receipt_long_outlined,
                      color: AppColors.info,
                      onTap: isCashier ? null : () => Navigator.pushNamed(context, '/reports'),
                      isDimmed: isCashier,
                    ),
                  ),
                  Selector<AppProvider, int>(
                    selector: (_, p) => p.totalProductsCount,
                    builder: (context, productsCount, __) => _StatCard(
                      title: AppStrings.totalProducts,
                      value: '$productsCount',
                      icon: Icons.inventory_2_outlined,
                      color: AppColors.success,
                      onTap: isCashier ? null : () => Navigator.pushNamed(context, '/inventory'),
                      isDimmed: isCashier,
                    ),
                  ),
                  Selector<AppProvider, int>(
                    selector: (_, p) => p.lowStockCount,
                    builder: (context, lowStockCount, __) => _StatCard(
                      title: AppStrings.lowStockAlerts,
                      value: '$lowStockCount',
                      icon: Icons.warning_amber_outlined,
                      color: lowStockCount == 0
                          ? AppColors.success
                          : AppColors.warning,
                      onTap: isCashier ? null : () => Navigator.pushNamed(context, '/alerts'),
                      isDimmed: isCashier,
                    ),
                  ),
                ]),
              ),
            ),

            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (!isCashier) ...[
                      const SizedBox(height: 12),
                      // ── Quick Actions ─────────────────────────────────────
                      Text(AppStrings.quickActions,
                          style: Theme.of(context).textTheme.titleLarge),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          _QuickAction(
                            icon: Icons.point_of_sale,
                            label: AppStrings.pos,
                            color: AppColors.primary,
                            onTap: () => Navigator.pushNamed(context, '/pos'),
                          ),
                          const SizedBox(width: 12),
                          _QuickAction(
                            icon: Icons.add_box_outlined,
                            label: AppStrings.stockIn,
                            color: AppColors.success,
                            onTap: () => Navigator.pushNamed(context, '/inventory'),
                          ),
                          const SizedBox(width: 12),
                          _QuickAction(
                            icon: Icons.bar_chart,
                            label: AppStrings.reports,
                            color: AppColors.info,
                            onTap: () => Navigator.pushNamed(context, '/reports'),
                          ),
                          const SizedBox(width: 12),
                          _QuickAction(
                            icon: Icons.notification_important_outlined,
                            label: 'التنبيهات',
                            color: AppColors.warning,
                            onTap: () => Navigator.pushNamed(context, '/alerts'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),

                      // ── Weekly Sales Chart ────────────────────────────────
                      Selector<AppProvider, List<double>>(
                        selector: (_, p) => p.weeklySales,
                        builder: (context, weeklySales, __) => Card(
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(AppStrings.salesChart,
                                        style: Theme.of(context).textTheme.titleLarge),
                                    Text('هذا الأسبوع',
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodySmall
                                            ?.copyWith(color: AppColors.primary)),
                                  ],
                                ),
                                const SizedBox(height: 20),
                                // P4: RepaintBoundary isolates chart paint
                                // region — scroll/rebuild above/below won't
                                // force the heavy BarChart to repaint.
                                SizedBox(
                                  height: 160,
                                  child: RepaintBoundary(
                                    child: _WeeklyChart(data: weeklySales),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                    ],

                    // ── Recent Transactions ───────────────────────────────
                    Selector<AppProvider, List<dynamic>>(
                      selector: (_, p) => p.sales,
                      builder: (context, sales, __) => Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(AppStrings.recentTransactions,
                                  style: Theme.of(context).textTheme.titleLarge),
                              if (!isCashier)
                                TextButton(
                                  onPressed: () => Navigator.pushNamed(context, '/transactions-history'),
                                  child: const Text(AppStrings.viewAll,
                                      style: TextStyle(color: AppColors.primary)),
                                ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          if (sales.isEmpty)
                            Center(
                              child: Padding(
                                padding: const EdgeInsets.all(24),
                                child: Text('لا توجد معاملات بعد',
                                    style: Theme.of(context).textTheme.bodyMedium),
                              ),
                            )
                          else
                            // P2 fix: ListView.builder lazily constructs only
                            // visible tiles vs spread which eagerly builds all.
                            ListView.builder(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: sales.take(5).length,
                              addAutomaticKeepAlives: false,
                              addRepaintBoundaries: false,
                              itemBuilder: (context, i) =>
                                  _TransactionTile(sale: sales[i]),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 80),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;
  final VoidCallback? onTap;
  final bool isDimmed;

  const _StatCard({
    required this.title, required this.value,
    required this.icon, required this.color, this.onTap, this.isDimmed = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Opacity(
        opacity: isDimmed ? 0.5 : 1.0,
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.border),
          ),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: color, size: 22),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(value,
                      style: TextStyle(
                          fontSize: 18, fontWeight: FontWeight.w700, color: color)),
                  Text(title,
                      style: const TextStyle(
                          fontSize: 11, color: AppColors.textSecondary),
                      maxLines: 1, overflow: TextOverflow.ellipsis),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _QuickAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _QuickAction({
    required this.icon, required this.label,
    required this.color, required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: color.withValues(alpha: 0.2)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: color, size: 26),
              const SizedBox(height: 6),
              Text(label,
                  style: TextStyle(
                      fontSize: 10, color: color, fontWeight: FontWeight.w600),
                  textAlign: TextAlign.center),
            ],
          ),
        ),
      ),
    );
  }
}

class _WeeklyChart extends StatelessWidget {
  final List<double> data;
  const _WeeklyChart({required this.data});

  @override
  Widget build(BuildContext context) {
    final days = ['الأح', 'الإث', 'الث', 'الأر', 'الخ', 'الج', 'الس'];
    final maxY = data.isEmpty ? 100.0 : (data.reduce((a, b) => a > b ? a : b) * 1.3);

    return BarChart(
      BarChartData(
        maxY: maxY == 0 ? 100.0 : maxY,
        barGroups: List.generate(
          data.length,
          (i) => BarChartGroupData(
            x: i,
            barRods: [
              BarChartRodData(
                toY: data[i],
                color: i == data.length - 1 ? AppColors.primary : AppColors.primaryLight.withValues(alpha: 0.4),
                width: 20,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
              ),
            ],
          ),
        ),
        titlesData: FlTitlesData(
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (v, _) => Text(
                days[v.toInt() % 7],
                style: const TextStyle(fontSize: 10, color: AppColors.textHint),
              ),
            ),
          ),
          leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        borderData: FlBorderData(show: false),
        gridData: const FlGridData(show: false),
      ),
    );
  }
}

class _TransactionTile extends StatelessWidget {
  final dynamic sale;
  const _TransactionTile({required this.sale});

  // P4 fix: DateFormat is expensive to construct (locale parsing).
  // Caching as static: created once for the whole app lifetime
  // instead of once per build() call per tile (was 5 instances per render).
  static final _timeFmt = DateFormat('hh:mm a', 'ar');

  @override
  Widget build(BuildContext context) {
    final isExpense = sale.type == 'expense';

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: AppColors.border),
      ),
      color: isExpense ? Colors.red.withValues(alpha: 0.02) : Colors.white,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: isExpense
            ? () {
                showDialog(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: const Text('تفاصيل المصروف النقدي', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold)),
                    content: Text(
                      'الوصف: ${sale.items.isNotEmpty ? sale.items.first.product.name : "-"}\nالمبلغ: ${sale.total.toStringAsFixed(2)} ${AppStrings.currencySymbol}\nالوقت: ${DateFormat('yyyy-MM-dd hh:mm a').format(sale.createdAt)}',
                      style: const TextStyle(fontFamily: 'Cairo', height: 1.6),
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
            : () => ReceiptDetailSheet.show(context, sale),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: isExpense ? Colors.red.withValues(alpha: 0.08) : AppColors.primaryContainer,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  isExpense ? Icons.money_off_outlined : Icons.receipt_outlined,
                  color: isExpense ? Colors.redAccent : AppColors.primary,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      sale.receiptNumber,
                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                    ),
                    Text(
                      isExpense
                          ? 'مصروفات: ${sale.items.isNotEmpty ? sale.items.first.product.name : "-"}'
                          : '${sale.items.length} منتجات • ${sale.paymentMethod}${sale.cashierName != null && sale.cashierName!.isNotEmpty ? " • بواسطة: ${sale.cashierName}" : ""}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: isExpense ? Colors.redAccent.withValues(alpha: 0.8) : AppColors.textSecondary,
                        fontSize: 12,
                        fontWeight: isExpense ? FontWeight.w600 : FontWeight.normal,
                      ),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '${isExpense ? '-' : ''}${sale.total.toStringAsFixed(2)} ${AppStrings.currencySymbol}',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: isExpense ? Colors.redAccent : AppColors.primary,
                      fontSize: 14,
                    ),
                  ),
                  Text(
                    _timeFmt.format(sale.createdAt),
                    style: const TextStyle(color: AppColors.textHint, fontSize: 11),
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
