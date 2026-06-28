import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_strings.dart';
import '../../core/providers/app_provider.dart';
import '../../widgets/glass_widgets.dart';
import 'expenses_management_screen.dart';

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen>
    with AutomaticKeepAliveClientMixin {
  int _periodIndex = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AppProvider>().loadDashboardStats();
    });
  }

  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final provider = context.read<AppProvider>();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text(AppStrings.reportsTitle),
        automaticallyImplyLeading: false,
      ),
      body: RefreshIndicator(
        onRefresh: () async => provider.loadDashboardStats(),
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Period filter — glass pills
              Row(
                children: ['اليوم', 'الأسبوع', 'الشهر'].asMap().entries.map((e) =>
                  Expanded(
                    child: Padding(
                      padding: EdgeInsets.only(left: e.key < 2 ? 8 : 0),
                      child: GestureDetector(
                        onTap: () => setState(() => _periodIndex = e.key),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          decoration: BoxDecoration(
                            color: _periodIndex == e.key
                                ? AppColors.primary
                                : AppColors.glassCard,
                            borderRadius: BorderRadius.circular(100),
                            border: Border.all(
                              color: _periodIndex == e.key
                                  ? AppColors.primary
                                  : AppColors.glassBorder,
                              width: 1,
                            ),
                          ),
                          child: Center(
                            child: Text(
                              e.value,
                              style: TextStyle(
                                fontFamily: 'Cairo',
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: _periodIndex == e.key
                                    ? Colors.white
                                    : AppColors.textSecondary,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ).toList(),
              ),
              const SizedBox(height: 16),
  
              // KPI Cards
              Row(
                children: [
                  Expanded(
                    child: Selector<AppProvider, double>(
                      selector: (_, p) {
                        if (_periodIndex == 0) return p.todaySalesTotal - p.todayExpenses;
                        if (_periodIndex == 1) return p.weeklySales.fold(0.0, (sum, val) => sum + val) - p.weeklyExpenses;
                        return p.allTimeRevenue - p.totalExpenses;
                      },
                      builder: (context, revenue, __) => _KpiCard(
                          title: AppStrings.totalRevenue,
                          value: '${revenue.toStringAsFixed(0)} ${AppStrings.currencySymbol}',
                          icon: Icons.trending_up,
                          color: AppColors.primary),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Selector<AppProvider, double>(
                      selector: (_, p) {
                         if (_periodIndex == 0) return (p.todaySalesTotal * 0.22) - p.todayExpenses;
                         if (_periodIndex == 1) return (p.weeklySales.fold(0.0, (sum, val) => sum + val) * 0.22) - p.weeklyExpenses;
                         return p.netProfit;
                      },
                      builder: (context, profit, __) => _KpiCard(
                          title: AppStrings.netProfit,
                          value: '${profit.toStringAsFixed(0)} ${AppStrings.currencySymbol}',
                          icon: Icons.account_balance_wallet_outlined,
                          color: AppColors.success),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: Selector<AppProvider, int>(
                      selector: (_, p) {
                         if (_periodIndex == 0) return p.todayOrdersCount;
                         if (_periodIndex == 1) {
                            final weekAgo = DateTime.now().subtract(const Duration(days: 7));
                            return p.sales.where((s) => s.createdAt.isAfter(weekAgo)).length;
                         }
                         return p.totalOrdersCount;
                      },
                      builder: (context, orders, __) => _KpiCard(
                          title: AppStrings.totalOrders,
                          value: '$orders',
                          icon: Icons.receipt_long_outlined,
                          color: AppColors.info),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Selector<AppProvider, List<dynamic>>(
                      selector: (_, p) {
                        double rev = 0;
                        int cnt = 0;
                        if (_periodIndex == 0) {
                          rev = p.todaySalesTotal;
                          cnt = p.todayOrdersCount;
                        } else if (_periodIndex == 1) {
                          rev = p.weeklySales.fold(0.0, (sum, val) => sum + val);
                          final weekAgo = DateTime.now().subtract(const Duration(days: 7));
                          cnt = p.sales.where((s) => s.createdAt.isAfter(weekAgo)).length;
                        } else {
                          rev = p.allTimeRevenue;
                          cnt = p.totalOrdersCount;
                        }
                        return [rev, cnt];
                      },
                      builder: (context, data, __) {
                        final double rev = data[0];
                        final int cnt = data[1];
                        final avg = cnt == 0 ? 0.0 : (rev / cnt);
                        return _KpiCard(
                            title: 'متوسط الفاتورة',
                            value: '${avg.toStringAsFixed(0)} ${AppStrings.currencySymbol}',
                            icon: Icons.calculate_outlined,
                            color: AppColors.warning);
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
  
              // Expenses Management Card
              GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const ExpensesManagementScreen()),
                  );
                },
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.redAccent.withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.account_balance_wallet, color: Colors.redAccent),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'إدارة ومراقبة المصروفات',
                              style: TextStyle(
                                fontFamily: 'Cairo',
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            Text(
                              'تنظيم وتصنيف مصاريف المتجر (طاقة، رواتب، إيجار، إلخ)',
                              style: TextStyle(
                                fontFamily: 'Cairo',
                                fontSize: 11,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Icon(Icons.arrow_forward_ios, size: 16, color: AppColors.textHint),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Revenue chart
              Selector<AppProvider, List<double>>(
                selector: (_, p) => p.weeklySales,
                builder: (context, weeklySales, __) => GlassPanel(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('مخطط الإيرادات الأسبوعية',
                          style: Theme.of(context).textTheme.titleLarge),
                      const SizedBox(height: 16),
                      SizedBox(
                        height: 180,
                        child: LineChart(LineChartData(
                          lineBarsData: [
                            LineChartBarData(
                              spots: weeklySales.asMap().entries
                                  .map((e) => FlSpot(e.key.toDouble(), e.value))
                                  .toList(),
                              isCurved: true,
                              gradient: const LinearGradient(
                                colors: [AppColors.primary, AppColors.accentGlow],
                              ),
                              barWidth: 3,
                              belowBarData: BarAreaData(
                                show: true,
                                gradient: LinearGradient(
                                  colors: [
                                    AppColors.accentGlow.withValues(alpha: 0.15),
                                    AppColors.accentGlow.withValues(alpha: 0.0),
                                  ],
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                ),
                              ),
                              dotData: const FlDotData(show: false),
                            ),
                          ],
                          titlesData: FlTitlesData(
                            bottomTitles: AxisTitles(
                              sideTitles: SideTitles(
                                showTitles: true,
                                getTitlesWidget: (v, _) {
                                  const days = ['أ', 'إ', 'ث', 'أر', 'خ', 'ج', 'س'];
                                  return Text(days[v.toInt() % 7],
                                      style: const TextStyle(fontSize: 10, color: AppColors.textHint));
                                },
                              ),
                            ),
                            leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                          ),
                          gridData: FlGridData(
                            show: true,
                            getDrawingHorizontalLine: (_) =>
                                const FlLine(color: AppColors.divider, strokeWidth: 1),
                            drawVerticalLine: false,
                          ),
                          borderData: FlBorderData(show: false),
                        )),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
  
              // Category pie chart
              Selector<AppProvider, List<dynamic>>(
                selector: (_, p) => p.categoriesAggregationList,
                builder: (context, catAggList, __) => GlassPanel(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(AppStrings.salesByCategory,
                          style: Theme.of(context).textTheme.titleLarge),
                      const SizedBox(height: 16),
                      SizedBox(
                        height: 180,
                        child: Row(
                          children: [
                            Expanded(
                              child: catAggList.isEmpty
                                  ? const Center(child: Text('لا توجد بيانات للفئات'))
                                  : PieChart(PieChartData(
                                      sections: _buildPieSections(catAggList),
                                      sectionsSpace: 2,
                                      centerSpaceRadius: 40,
                                    )),
                            ),
                            const SizedBox(width: 8),
                            Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: _buildPieLegends(catAggList),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
  
              // Top products
              Selector<AppProvider, List<dynamic>>(
                selector: (_, p) => p.topProductsList,
                builder: (context, topProdsList, __) => GlassPanel(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(AppStrings.topProducts,
                          style: Theme.of(context).textTheme.titleLarge),
                      const SizedBox(height: 12),
                      if (topProdsList.isEmpty)
                        const Center(child: Text('لا توجد معاملات مبيعات بعد'))
                      else
                        ...topProdsList.map((tp) {
                          final double maxQty = double.tryParse(topProdsList[0]['qtySold'].toString()) ?? 1.0;
                          final double qty = double.tryParse(tp['qtySold'].toString()) ?? 0.0;
                          final double percent = (qty / maxQty).clamp(0.0, 1.0);
                          return _TopProductRow(
                            name: tp['name'] ?? 'منتج غير معروف',
                            sales: '${tp['totalSales']} ${AppStrings.currencySymbol} (${tp['qtySold']} قطعة)',
                            percent: percent,
                          );
                        }),
                    ],
                  ),
                ),
              ),
  
              const SizedBox(height: 80),
            ],
          ),
        ),
      ),
    );
  }

  List<PieChartSectionData> _buildPieSections(List<dynamic> catAggList) {
    final colors = [AppColors.chart1, AppColors.chart2, AppColors.chart3, AppColors.chart4, AppColors.chart5];
    return catAggList.asMap().entries.map((e) {
      final double val = double.tryParse(e.value['count']?.toString() ?? '1.0') ?? 1.0;
      return PieChartSectionData(
        value: val,
        color: colors[e.key % colors.length],
        showTitle: false,
        radius: 30,
      );
    }).toList();
  }

  List<Widget> _buildPieLegends(List<dynamic> catAggList) {
    final colors = [AppColors.chart1, AppColors.chart2, AppColors.chart3, AppColors.chart4, AppColors.chart5];
    if (catAggList.isEmpty) {
      return [const _Legend('لا يوجد', AppColors.chart1)];
    }
    return catAggList.asMap().entries.take(5).map((e) {
      final name = e.value['_id'] ?? 'عام';
      return _Legend(name, colors[e.key % colors.length]);
    }).toList();
  }
}

class _KpiCard extends StatelessWidget {
  final String title, value;
  final IconData icon;
  final Color color;
  const _KpiCard({required this.title, required this.value, required this.icon, required this.color});

  @override
  Widget build(BuildContext context) {
    return GlassPanel(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(height: 8),
          Text(value,
              style: TextStyle(
                  fontSize: 17, fontWeight: FontWeight.w700, color: color,
                  fontFamily: 'Cairo', letterSpacing: -0.3)),
          Text(title,
              style: const TextStyle(
                  fontSize: 10, color: AppColors.textSecondary, fontFamily: 'Cairo'),
              maxLines: 1, overflow: TextOverflow.ellipsis),
        ],
      ),
    );
  }
}

class _Legend extends StatelessWidget {
  final String label;
  final Color color;
  const _Legend(this.label, this.color);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Container(width: 10, height: 10,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
          const SizedBox(width: 6),
          Text(label, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
        ],
      ),
    );
  }
}

class _TopProductRow extends StatelessWidget {
  final String name, sales;
  final double percent;
  const _TopProductRow({required this.name, required this.sales, required this.percent});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(child: Text(name,
                  maxLines: 1, overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 13))),
              Text(sales, style: const TextStyle(
                  fontWeight: FontWeight.w600, fontSize: 13, color: AppColors.primary)),
            ],
          ),
          const SizedBox(height: 4),
          LinearProgressIndicator(
            value: percent.clamp(0.0, 1.0),
            backgroundColor: AppColors.divider,
            valueColor: const AlwaysStoppedAnimation<Color>(AppColors.primary),
            minHeight: 6,
            borderRadius: BorderRadius.circular(3),
          ),
        ],
      ),
    );
  }
}
