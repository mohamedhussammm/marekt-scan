import 'dart:async';
import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_strings.dart';
import '../../core/providers/app_provider.dart';
import '../../widgets/glass_widgets.dart';
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
  int _offlineSkipCount = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadData());
    _refreshTimer = Timer.periodic(const Duration(seconds: 15), (_) async {
      if (!mounted) return;
      if (_offlineSkipCount > 0) { _offlineSkipCount--; return; }
      if (_isRefreshing) return;
      _loadData();
    });
  }

  Future<void> _loadData() async {
    if (!mounted) return;
    setState(() => _isRefreshing = true);
    try {
      await context.read<AppProvider>().loadDashboardStats(rethrowNetworkErrors: true);
      _offlineSkipCount = 0;
    } catch (e) {
      final isNetworkError = e is SocketException ||
          e.toString().contains('SocketException') ||
          e.toString().contains('Connection failed');
      if (isNetworkError) _offlineSkipCount = 4;
    } finally {
      if (mounted) setState(() => _isRefreshing = false);
    }
  }

  @override
  void dispose() { _refreshTimer?.cancel(); super.dispose(); }

  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final provider = context.read<AppProvider>();
    final isCashier = context.select<AppProvider, bool>((p) => p.userRole == 'cashier');
    final double screenWidth = MediaQuery.of(context).size.width;
    // Dynamic aspect ratio based on screen width to give more vertical breathing room on narrow devices
    final double childAspectRatio = screenWidth < 360 ? 1.3 : (screenWidth < 400 ? 1.45 : 1.55);

    return Scaffold(
      backgroundColor: AppColors.background,
      extendBodyBehindAppBar: true,
      body: RefreshIndicator(
        onRefresh: () async {
          await provider.loadProducts();
          await provider.loadDashboardStats();
        },
        child: CustomScrollView(
          slivers: [
            // ── Luminous Glass App Bar ──────────────────────────────────
            SliverAppBar(
              expandedHeight: 150,
              pinned: true,
              backgroundColor: Colors.transparent,
              elevation: 0,
              flexibleSpace: FlexibleSpaceBar(
                collapseMode: CollapseMode.pin,
                background: Stack(
                  fit: StackFit.expand,
                  children: [
                    // Gradient header background
                    Container(
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          colors: [AppColors.primary, Color(0xFF009BB8)],
                          begin: Alignment.topRight,
                          end: Alignment.bottomLeft,
                        ),
                      ),
                    ),
                    // Subtle geometric pattern overlay
                    Positioned(
                      right: -30, top: -30,
                      child: Container(
                        width: 160, height: 160,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppColors.accentGlow.withValues(alpha: 0.12),
                        ),
                      ),
                    ),
                    Positioned(
                      left: -20, bottom: -20,
                      child: Container(
                        width: 100, height: 100,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white.withValues(alpha: 0.06),
                        ),
                      ),
                    ),
                    // Content
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 60, 20, 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Text(
                            'مرحباً بك 👋',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.75),
                              fontSize: 13,
                              fontFamily: 'Cairo',
                            ),
                          ),
                          const SizedBox(height: 2),
                          Selector<AppProvider, String>(
                            selector: (_, p) => p.storeName,
                            builder: (_, storeName, __) => Text(
                              storeName,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 22,
                                fontWeight: FontWeight.w700,
                                fontFamily: 'Cairo',
                                letterSpacing: -0.3,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                if (!isCashier)
                  Padding(
                    padding: const EdgeInsets.only(right: 12),
                    child: GestureDetector(
                      onTap: () => Navigator.pushNamed(context, '/alerts'),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: BackdropFilter(
                          filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.25), width: 1),
                            ),
                            child: Stack(
                              children: [
                                const Icon(Icons.notifications_outlined,
                                    color: Colors.white, size: 22),
                                Selector<AppProvider, bool>(
                                  selector: (_, p) => p.lowStockProducts.isNotEmpty,
                                  builder: (_, hasLowStock, __) {
                                    if (!hasLowStock) return const SizedBox.shrink();
                                    return Positioned(
                                      top: 0, right: 0,
                                      child: Container(
                                        width: 8, height: 8,
                                        decoration: const BoxDecoration(
                                          color: AppColors.accentGlow,
                                          shape: BoxShape.circle,
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),

            // ── KPI Stat Cards ──────────────────────────────────────────
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              sliver: SliverGrid(
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  childAspectRatio: childAspectRatio,
                ),
                delegate: SliverChildListDelegate([
                  Selector<AppProvider, double>(
                    selector: (_, p) => p.todaySalesTotal,
                    builder: (context, v, __) => _GlassStatCard(
                      title: AppStrings.todaySales,
                      value: '${_currencyFmt.format(v)} ${AppStrings.currencySymbol}',
                      icon: Icons.trending_up,
                      color: AppColors.primary,
                      accentColor: AppColors.accentGlow,
                      onTap: isCashier ? null : () => Navigator.pushNamed(context, '/reports'),
                      isDimmed: isCashier,
                    ),
                  ),
                  Selector<AppProvider, int>(
                    selector: (_, p) => p.totalOrdersCount,
                    builder: (context, v, __) => _GlassStatCard(
                      title: AppStrings.totalOrders,
                      value: '$v',
                      icon: Icons.receipt_long_outlined,
                      color: AppColors.info,
                      accentColor: const Color(0xFF3CD7FF),
                      onTap: isCashier ? null : () => Navigator.pushNamed(context, '/reports'),
                      isDimmed: isCashier,
                    ),
                  ),
                  Selector<AppProvider, int>(
                    selector: (_, p) => p.totalProductsCount,
                    builder: (context, v, __) => _GlassStatCard(
                      title: AppStrings.totalProducts,
                      value: '$v',
                      icon: Icons.inventory_2_outlined,
                      color: AppColors.success,
                      accentColor: const Color(0xFF2DCA72),
                      onTap: isCashier ? null : () => Navigator.pushNamed(context, '/inventory'),
                      isDimmed: isCashier,
                    ),
                  ),
                  Selector<AppProvider, int>(
                    selector: (_, p) => p.lowStockCount,
                    builder: (context, v, __) => _GlassStatCard(
                      title: AppStrings.lowStockAlerts,
                      value: '$v',
                      icon: Icons.warning_amber_outlined,
                      color: v == 0 ? AppColors.success : AppColors.warning,
                      accentColor: v == 0 ? const Color(0xFF2DCA72) : const Color(0xFFFFAA00),
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
                      const SizedBox(height: 16),

                      // ── Quick Actions ─────────────────────────────────
                      Text(AppStrings.quickActions,
                          style: Theme.of(context).textTheme.titleLarge),
                      const SizedBox(height: 12),
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        physics: const BouncingScrollPhysics(),
                        child: Row(
                          children: [
                            _GlassQuickAction(
                              icon: Icons.point_of_sale,
                              label: AppStrings.pos,
                              color: AppColors.primary,
                              onTap: () => Navigator.pushNamed(context, '/pos'),
                            ),
                            const SizedBox(width: 10),
                            _GlassQuickAction(
                              icon: Icons.people_outline,
                              label: 'العملاء',
                              color: AppColors.accentGlow,
                              onTap: () => Navigator.pushNamed(context, '/customers'),
                            ),
                            const SizedBox(width: 10),
                            _GlassQuickAction(
                              icon: Icons.add_box_outlined,
                              label: AppStrings.stockIn,
                              color: AppColors.success,
                              onTap: () => Navigator.pushNamed(context, '/inventory'),
                            ),
                            const SizedBox(width: 10),
                            _GlassQuickAction(
                              icon: Icons.bar_chart,
                              label: AppStrings.reports,
                              color: AppColors.info,
                              onTap: () => Navigator.pushNamed(context, '/reports'),
                            ),
                            const SizedBox(width: 10),
                            _GlassQuickAction(
                              icon: Icons.notification_important_outlined,
                              label: 'التنبيهات',
                              color: AppColors.warning,
                              onTap: () => Navigator.pushNamed(context, '/alerts'),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),

                      // ── Weekly Sales Chart ──────────────────────────
                      Selector<AppProvider, List<double>>(
                        selector: (_, p) => p.weeklySales,
                        builder: (context, weeklySales, __) => GlassPanel(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(AppStrings.salesChart,
                                      style: Theme.of(context).textTheme.titleLarge),
                                  GlassChip(
                                    label: 'هذا الأسبوع',
                                    color: AppColors.primary,
                                  ),
                                ],
                              ),
                              const SizedBox(height: 20),
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
                      const SizedBox(height: 20),
                    ],

                    // ── Recent Transactions ─────────────────────────────
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
                                GestureDetector(
                                  onTap: () => Navigator.pushNamed(
                                      context, '/transactions-history'),
                                  child: const GlassChip(
                                    label: AppStrings.viewAll,
                                    color: AppColors.primary,
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          if (sales.isEmpty)
                            GlassPanel(
                              padding: const EdgeInsets.all(32),
                              child: Center(
                                child: Column(
                                  children: [
                                    Icon(Icons.receipt_long_outlined,
                                        size: 40,
                                        color: AppColors.textHint.withValues(alpha: 0.5)),
                                    const SizedBox(height: 8),
                                    Text('لا توجد معاملات بعد',
                                        style: Theme.of(context).textTheme.bodyMedium),
                                  ],
                                ),
                              ),
                            )
                          else
                            ListView.builder(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: sales.take(5).length,
                              addAutomaticKeepAlives: false,
                              addRepaintBoundaries: false,
                              itemBuilder: (context, i) =>
                                  _GlassTransactionTile(sale: sales[i]),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 100), // space for floating nav
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

// ── Glass KPI Stat Card ────────────────────────────────────────────────────
class _GlassStatCard extends StatelessWidget {
  final String title, value;
  final IconData icon;
  final Color color, accentColor;
  final VoidCallback? onTap;
  final bool isDimmed;

  const _GlassStatCard({
    required this.title, required this.value,
    required this.icon, required this.color, required this.accentColor,
    this.onTap, this.isDimmed = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Opacity(
        opacity: isDimmed ? 0.45 : 1.0,
        child: GlassPanel(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: color, size: 18),
              ),
              const SizedBox(height: 4),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: AlignmentDirectional.centerStart,
                      child: Text(
                        value,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: color,
                          fontFamily: 'Cairo',
                          letterSpacing: -0.3,
                        ),
                      ),
                    ),
                    const SizedBox(height: 2),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: AlignmentDirectional.centerStart,
                      child: Text(
                        title,
                        style: const TextStyle(
                          fontSize: 10,
                          color: AppColors.textSecondary,
                          fontFamily: 'Cairo',
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Glass Quick Action ─────────────────────────────────────────────────────
class _GlassQuickAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _GlassQuickAction({
    required this.icon, required this.label,
    required this.color, required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 82,
      child: GestureDetector(
        onTap: onTap,
        child: GlassPanel(
          padding: const EdgeInsets.symmetric(vertical: 12),
          borderRadius: 14,
          border: Border.all(color: color.withValues(alpha: 0.20), width: 1),
          color: color.withValues(alpha: 0.06),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: color, size: 24),
              const SizedBox(height: 5),
              Text(
                label,
                style: TextStyle(
                  fontSize: 10, color: color,
                  fontWeight: FontWeight.w600, fontFamily: 'Cairo'),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Weekly Chart ───────────────────────────────────────────────────────────
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
        barGroups: List.generate(data.length, (i) => BarChartGroupData(
          x: i,
          barRods: [
            BarChartRodData(
              toY: data[i],
              gradient: i == data.length - 1
                  ? const LinearGradient(
                      colors: [AppColors.primary, AppColors.accentGlow],
                      begin: Alignment.bottomCenter,
                      end: Alignment.topCenter,
                    )
                  : null,
              color: i == data.length - 1
                  ? null
                  : AppColors.primary.withValues(alpha: 0.20),
              width: 20,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
            ),
          ],
        )),
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
        gridData: FlGridData(
          show: true,
          getDrawingHorizontalLine: (_) => const FlLine(
            color: AppColors.divider, strokeWidth: 1),
          drawVerticalLine: false,
        ),
      ),
    );
  }
}

// ── Glass Transaction Tile ─────────────────────────────────────────────────
class _GlassTransactionTile extends StatelessWidget {
  final dynamic sale;
  const _GlassTransactionTile({required this.sale});

  static final _timeFmt = DateFormat('hh:mm a', 'ar');

  @override
  Widget build(BuildContext context) {
    final isExpense = sale.type == 'expense';

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: GlassPanel(
        borderRadius: 12,
        border: Border.all(
          color: isExpense
              ? AppColors.error.withValues(alpha: 0.20)
              : AppColors.glassBorder,
          width: 1,
        ),
        onTap: isExpense
            ? () => showDialog(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    backgroundColor: AppColors.glassCard,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                      side: const BorderSide(color: AppColors.glassBorder),
                    ),
                    title: const Text('تفاصيل المصروف النقدي',
                        style: TextStyle(
                            fontFamily: 'Cairo', fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary)),
                    content: Text(
                      'الوصف: ${sale.items.isNotEmpty ? sale.items.first.product.name : "-"}\n'
                      'المبلغ: ${sale.total.toStringAsFixed(2)} ${AppStrings.currencySymbol}\n'
                      'الوقت: ${DateFormat('yyyy-MM-dd hh:mm a', 'ar').format(sale.createdAt)}',
                      style: const TextStyle(fontFamily: 'Cairo', height: 1.6,
                          color: AppColors.textSecondary),
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(ctx),
                        child: const Text('إغلاق',
                            style: TextStyle(fontFamily: 'Cairo',
                                color: AppColors.primary)),
                      ),
                    ],
                  ),
                )
            : () => ReceiptDetailSheet.show(context, sale),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Container(
                width: 42, height: 42,
                decoration: BoxDecoration(
                  color: isExpense
                      ? AppColors.error.withValues(alpha: 0.08)
                      : AppColors.primaryContainer.withValues(alpha: 0.35),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  isExpense ? Icons.money_off_outlined : Icons.receipt_outlined,
                  color: isExpense ? AppColors.error : AppColors.primary,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      sale.receiptNumber,
                      style: const TextStyle(
                          fontWeight: FontWeight.w600, fontSize: 13,
                          fontFamily: 'Cairo', color: AppColors.textPrimary),
                    ),
                    Text(
                      isExpense
                          ? 'مصروفات: ${sale.items.isNotEmpty ? sale.items.first.product.name : "-"}'
                          : '${sale.items.length} منتجات • ${sale.paymentMethod}${sale.cashierName != null && sale.cashierName!.isNotEmpty ? " • بواسطة: ${sale.cashierName}" : ""}',
                      maxLines: 1, overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: isExpense
                            ? AppColors.error.withValues(alpha: 0.80)
                            : AppColors.textSecondary,
                        fontSize: 11, fontFamily: 'Cairo',
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
                      color: isExpense ? AppColors.error : AppColors.primary,
                      fontSize: 13, fontFamily: 'Cairo',
                    ),
                  ),
                  Text(
                    _timeFmt.format(sale.createdAt),
                    style: const TextStyle(
                        color: AppColors.textHint, fontSize: 10, fontFamily: 'Cairo'),
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
