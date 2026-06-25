import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_strings.dart';
import '../../core/models/models.dart';
import '../../core/providers/app_provider.dart';
import '../../services/api_service.dart';

/// Low Stock Alerts Screen — Senior Flutter pattern:
///
/// ✅ StatefulWidget with its own isolated data source
/// ✅ Calls the dedicated /low-stock backend endpoint (MongoDB filters on server)
/// ✅ Infinite scroll with ListView.builder (lazy — only visible tiles are built)
/// ✅ Uses context.read once at initState — never context.watch, so NO rebuilds
///    from unrelated provider state changes (cart, category, etc.)
/// ✅ Pagination: loads 30 items at a time, fetches more as user scrolls
/// ✅ Never loads all 3200 products into memory
class LowStockAlertsScreen extends StatefulWidget {
  const LowStockAlertsScreen({super.key});

  @override
  State<LowStockAlertsScreen> createState() => _LowStockAlertsScreenState();
}

class _LowStockAlertsScreenState extends State<LowStockAlertsScreen> {
  static const int _pageSize = 30;

  final List<Product> _items = [];
  final ScrollController _scrollController = ScrollController();

  // Pagination state
  int _currentPage = 1;
  int _totalCount = 0;
  bool _hasMore = false;

  // UI state
  bool _isInitialLoading = true;
  bool _isLoadingMore = false;
  String? _error;

  // Cached from provider (read once — not watched)
  late ApiService _api;

  @override
  void initState() {
    super.initState();
    // Read the ApiService once — we use it directly for this screen's own
    // paginated data. We do NOT watch the provider so that cart changes,
    // search queries, etc. never cause this screen to rebuild.
    _api = context.read<AppProvider>().api;
    _scrollController.addListener(_onScroll);
    _fetchPage(1);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      _loadMoreIfNeeded();
    }
  }

  void _loadMoreIfNeeded() {
    if (_hasMore && !_isLoadingMore && !_isInitialLoading) {
      _fetchPage(_currentPage + 1);
    }
  }

  Future<void> _fetchPage(int page) async {
    if (page == 1) {
      setState(() {
        _isInitialLoading = true;
        _error = null;
      });
    } else {
      if (_isLoadingMore) return;
      setState(() => _isLoadingMore = true);
    }

    try {
      final result = await _api.getLowStockProducts(
        page: page,
        limit: _pageSize,
      );

      final List<Product> newItems = result['products'] as List<Product>;
      final bool hasMore = result['hasMore'] as bool;
      final int total = result['total'] as int;

      if (!mounted) return;
      setState(() {
        if (page == 1) {
          _items
            ..clear()
            ..addAll(newItems);
        } else {
          _items.addAll(newItems);
        }
        _currentPage = page;
        _hasMore = hasMore;
        _totalCount = total;
        _isInitialLoading = false;
        _isLoadingMore = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _isInitialLoading = false;
        _isLoadingMore = false;
      });
    }
  }

  Future<void> _refresh() => _fetchPage(1);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text(AppStrings.lowStockAlertsTitle),
        actions: [
          if (!_isInitialLoading && _totalCount > 0)
            Padding(
              padding: const EdgeInsets.only(right: 16),
              child: Center(
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.warning.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '$_totalCount',
                    style: const TextStyle(
                      color: AppColors.warning,
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    // ── Initial loading spinner ──────────────────────────────────────────────
    if (_isInitialLoading) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(color: AppColors.warning),
            SizedBox(height: 16),
            Text(
              'جاري تحميل التنبيهات...',
              style: TextStyle(color: AppColors.textSecondary),
            ),
          ],
        ),
      );
    }

    // ── Error state ──────────────────────────────────────────────────────────
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.cloud_off_rounded,
                  size: 64, color: AppColors.textHint),
              const SizedBox(height: 16),
              const Text('تعذّر تحميل التنبيهات',
                  style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary)),
              const SizedBox(height: 8),
              Text(_error!,
                  style: const TextStyle(
                      fontSize: 12, color: AppColors.textSecondary),
                  textAlign: TextAlign.center),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                onPressed: _refresh,
                icon: const Icon(Icons.refresh),
                label: const Text('إعادة المحاولة'),
              ),
            ],
          ),
        ),
      );
    }

    // ── Empty state ──────────────────────────────────────────────────────────
    if (_items.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.check_circle_outline,
                size: 72, color: AppColors.success),
            const SizedBox(height: 16),
            const Text(
              'المخزون في مستوى جيد',
              style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: AppColors.success),
            ),
            const SizedBox(height: 8),
            const Text(
              'لا توجد منتجات تحتاج لإعادة تزويد',
              style: TextStyle(color: AppColors.textSecondary),
            ),
          ],
        ),
      );
    }

    // ── Data: lazy list with infinite scroll ─────────────────────────────────
    // Items are pre-sorted by the backend (currentStock ASC = most critical first)
    final criticalCount = _items.where((p) => p.isCriticalStock).length;
    final lowCount = _items.where((p) => !p.isCriticalStock).length;

    return RefreshIndicator(
      onRefresh: _refresh,
      color: AppColors.warning,
      child: CustomScrollView(
        controller: _scrollController,
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          // Summary banner
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.warning.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                      color: AppColors.warning.withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.warning_amber_rounded,
                        color: AppColors.warning, size: 32),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '$_totalCount منتج يحتاج تزويد',
                          style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              color: AppColors.warning,
                              fontSize: 15),
                        ),
                        Text(
                          '${_items.where((p) => p.isCriticalStock).length} حرج • ${_items.where((p) => !p.isCriticalStock).length} منخفض (معروض حالياً)',
                          style: const TextStyle(
                              color: AppColors.textSecondary, fontSize: 12),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),

          const SliverToBoxAdapter(child: SizedBox(height: 12)),

          // Lazy list — only builds tiles that are on screen
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            sliver: SliverList.builder(
              itemCount: _items.length + (_hasMore ? 1 : 0),
              itemBuilder: (context, index) {
                // The last item is a load-more indicator
                if (index == _items.length) {
                  return const Padding(
                    padding: EdgeInsets.symmetric(vertical: 20),
                    child: Center(
                      child: SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                            strokeWidth: 2.5, color: AppColors.warning),
                      ),
                    ),
                  );
                }

                final product = _items[index];

                // Section header: insert before the first low (non-critical) item
                // Critical items are at the top (sorted by backend), low items follow
                final isCritical = product.isCriticalStock;
                final prevIsCritical =
                    index > 0 ? _items[index - 1].isCriticalStock : true;
                final isFirstOfSection =
                    index == 0 || isCritical != prevIsCritical;

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (isFirstOfSection && isCritical && criticalCount > 0)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: _SectionHeader(
                          title: AppStrings.criticalStock,
                          icon: Icons.error_outline,
                          color: AppColors.criticalStock,
                        ),
                      ),
                    if (isFirstOfSection && !isCritical && lowCount > 0)
                      Padding(
                        padding: const EdgeInsets.only(top: 8, bottom: 8),
                        child: _SectionHeader(
                          title: AppStrings.warningStock,
                          icon: Icons.warning_amber_outlined,
                          color: AppColors.lowStock,
                        ),
                      ),
                    _AlertTile(
                      product: product,
                      isCritical: isCritical,
                      onReorder: () =>
                          Navigator.pushNamed(context, '/inventory'),
                    ),
                  ],
                );
              },
            ),
          ),

          const SliverToBoxAdapter(child: SizedBox(height: 80)),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Section header widget — built once per section, not per item
// ─────────────────────────────────────────────────────────────────────────────
class _SectionHeader extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color color;
  const _SectionHeader(
      {required this.title, required this.icon, required this.color});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(width: 6),
        Text(title,
            style: TextStyle(
                fontSize: 16, fontWeight: FontWeight.w700, color: color)),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Alert tile — StatelessWidget, built lazily by ListView.builder
// ─────────────────────────────────────────────────────────────────────────────
class _AlertTile extends StatelessWidget {
  final Product product;
  final bool isCritical;
  final VoidCallback onReorder;
  const _AlertTile(
      {required this.product,
      required this.isCritical,
      required this.onReorder});

  Future<void> _launchWhatsApp(String productName) async {
    final message = 'مرحباً، نحتاج إلى طلب كمية إضافية من $productName';
    final url =
        Uri.parse('https://wa.me/?text=${Uri.encodeComponent(message)}');
    if (await canLaunchUrl(url)) {
      await launchUrl(url);
    }
  }

  @override
  Widget build(BuildContext context) {
    final borderColor = isCritical
        ? AppColors.criticalStock.withValues(alpha: 0.3)
        : AppColors.lowStock.withValues(alpha: 0.3);
    final bgColor = isCritical
        ? AppColors.criticalStock.withValues(alpha: 0.04)
        : AppColors.lowStock.withValues(alpha: 0.04);
    final accentColor =
        isCritical ? AppColors.criticalStock : AppColors.lowStock;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: accentColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(Icons.inventory_2_outlined,
                color: accentColor, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(product.name,
                    style: const TextStyle(
                        fontWeight: FontWeight.w600, fontSize: 14)),
                const SizedBox(height: 2),
                Wrap(
                  spacing: 4,
                  runSpacing: 2,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text('${AppStrings.currentStock}: ',
                        style: const TextStyle(
                            fontSize: 11, color: AppColors.textHint)),
                    Text(
                        '${product.stockQuantity} ${AppStrings.pieces}',
                        style: TextStyle(
                            fontSize: 11,
                            color: accentColor,
                            fontWeight: FontWeight.w700)),
                    Text(
                        ' • ${AppStrings.minLevel}: ${product.minStockLevel}',
                        style: const TextStyle(
                            fontSize: 11, color: AppColors.textHint)),
                  ],
                ),
                const SizedBox(height: 4),
                LinearProgressIndicator(
                  value: (product.stockQuantity /
                          (product.minStockLevel * 2).clamp(1, double.infinity))
                      .clamp(0.0, 1.0),
                  backgroundColor: accentColor.withValues(alpha: 0.1),
                  valueColor: AlwaysStoppedAnimation<Color>(accentColor),
                  minHeight: 4,
                  borderRadius: BorderRadius.circular(2),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          ElevatedButton.icon(
            onPressed: () => _launchWhatsApp(product.name),
            icon: const Icon(Icons.send, size: 12, color: Colors.white),
            style: ElevatedButton.styleFrom(
              backgroundColor: accentColor,
              minimumSize: const Size(70, 34),
              padding: const EdgeInsets.symmetric(horizontal: 10),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
            ),
            label: const Text('طلب WhatsApp',
                style: TextStyle(fontSize: 10, color: Colors.white)),
          ),
        ],
      ),
    );
  }
}
