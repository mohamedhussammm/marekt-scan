import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_strings.dart';
import '../../screens/dashboard/dashboard_screen.dart';
import '../../screens/pos/pos_scanner_screen.dart';
import '../../screens/inventory/inventory_screen.dart';
import '../../screens/reports/reports_screen.dart';
import '../../screens/settings/settings_screen.dart';
import '../../core/providers/app_provider.dart';
import '../../core/models/models.dart';
import '../../services/sync_engine.dart';
import 'permission_denied_widget.dart';

class MainNavigation extends StatefulWidget {
  const MainNavigation({super.key});

  @override
  State<MainNavigation> createState() => _MainNavigationState();
}

class _MainNavigationState extends State<MainNavigation> {
  int _currentIndex = 0;
  late final PageController _pageController;

  // ── Cached screen lists — built once, never recreated on rebuild ──────────
  // Building these inside build() creates new widget instances every time
  // context.select fires (every 15s from dashboard timer), which is a huge
  // source of lag. Caching them here means PageView keeps the same children.
  static const List<Widget> _adminScreens = [
    DashboardScreen(),
    PosScannerScreen(),
    InventoryScreen(),
    ReportsScreen(),
    SettingsScreen(),
  ];

  static const List<Widget> _cashierScreens = [
    DashboardScreen(),
    PosScannerScreen(),
    Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(child: PermissionDeniedWidget()),
    ),
    Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(child: PermissionDeniedWidget()),
    ),
    SettingsScreen(),
  ];

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: _currentIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  String _opLabel(String operation) {
    switch (operation) {
      case 'checkout': return 'عملية بيع';
      case 'add_product': return 'إضافة منتج';
      case 'update_product': return 'تعديل منتج';
      case 'delete_product': return 'حذف منتج';
      case 'update_stock': return 'تحديث مخزون';
      case 'add_expense': return 'مصروف جديد';
      default: return operation;
    }
  }

  IconData _opIcon(String operation) {
    switch (operation) {
      case 'checkout': return Icons.shopping_cart_outlined;
      case 'add_product': return Icons.add_box_outlined;
      case 'update_product': return Icons.edit_outlined;
      case 'delete_product': return Icons.delete_outline;
      case 'update_stock': return Icons.inventory_2_outlined;
      case 'add_expense': return Icons.money_off_outlined;
      default: return Icons.pending_outlined;
    }
  }

  void _showSyncBottomSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) {
          return DraggableScrollableSheet(
            initialChildSize: 0.55,
            minChildSize: 0.35,
            maxChildSize: 0.85,
            expand: false,
            builder: (_, scrollCtrl) => Column(
              children: [
                // ── Handle ──
                Container(
                  width: 40, height: 4,
                  margin: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2)),
                ),
                // ── Header ──
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Row(
                    children: [
                      const Icon(Icons.cloud_upload_outlined, color: AppColors.primary, size: 28),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Selector<SyncEngine, int>(
                          selector: (_, s) => s.pendingCount,
                          builder: (_, count, __) => Text(
                            '$count عمليات في انتظار المزامنة',
                            style: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 16),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 4),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 20),
                  child: Text(
                    'هذه العمليات محفوظة محلياً. يمكنك إلغاء أي منها قبل المزامنة.',
                    style: TextStyle(fontFamily: 'Cairo', color: Colors.black54, fontSize: 13),
                  ),
                ),
                const Divider(height: 20),
                // ── Ops list ──
                Expanded(
                  child: FutureBuilder<List<OfflineQueueItem>>(
                    future: SyncEngine.instance.getPendingOps(),
                    builder: (_, snap) {
                      if (!snap.hasData) return const Center(child: CircularProgressIndicator());
                      final ops = snap.data!;
                      if (ops.isEmpty) {
                        return const Center(
                          child: Text('لا توجد عمليات معلقة ✓',
                              style: TextStyle(fontFamily: 'Cairo', color: Colors.green)),
                        );
                      }
                      return ListView.separated(
                        controller: scrollCtrl,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                        itemCount: ops.length,
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemBuilder: (_, i) {
                          final op = ops[i];
                          final label = _opLabel(op.operation);
                          final icon = _opIcon(op.operation);
                          final timeStr = '${op.createdAt.hour.toString().padLeft(2,'0')}:${op.createdAt.minute.toString().padLeft(2,'0')}';
                          return ListTile(
                            contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                            leading: CircleAvatar(
                              backgroundColor: Colors.amber.shade100,
                              child: Icon(icon, color: Colors.amber[800], size: 18),
                            ),
                            title: Text(label, style: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.w600, fontSize: 14)),
                            subtitle: Text(timeStr, style: const TextStyle(fontFamily: 'Cairo', fontSize: 11, color: Colors.black45)),
                            trailing: IconButton(
                              icon: const Icon(Icons.cancel_outlined, color: Colors.redAccent),
                              tooltip: 'إلغاء هذه العملية',
                              onPressed: () async {
                                await SyncEngine.instance.cancelOp(op.id);
                                setSheetState(() {});
                              },
                            ),
                          );
                        },
                      );
                    },
                  ),
                ),
                const Divider(height: 1),
                // ── Action buttons ──
                Padding(
                  padding: EdgeInsets.fromLTRB(16, 12, 16, MediaQuery.of(ctx).viewInsets.bottom + 16),
                  child: Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () async {
                            final ops = await SyncEngine.instance.getPendingOps();
                            for (final op in ops) {
                              await SyncEngine.instance.cancelOp(op.id);
                            }
                            if (ctx.mounted) Navigator.pop(ctx);
                          },
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: Colors.redAccent),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                          child: const Text('إلغاء الكل', style: TextStyle(fontFamily: 'Cairo', color: Colors.redAccent)),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 2,
                        child: Selector<SyncEngine, bool>(
                          selector: (_, s) => s.isSyncing,
                          builder: (context, isSyncing, _) => ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                            onPressed: isSyncing
                                ? null
                                : () async {
                                    await SyncEngine.instance.flushQueue();
                                    if (ctx.mounted && SyncEngine.instance.pendingCount == 0) {
                                      Navigator.pop(ctx);
                                    } else if (ctx.mounted) {
                                      setSheetState(() {});
                                    }
                                  },
                            child: isSyncing
                                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                                : const Text('مزامنة الآن', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 15)),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // P0 fix: context.select only rebuilds when userRole specifically changes,
    // not on every AppProvider.notifyListeners() call (which happens every 15s).
    final isCashier = context.select<AppProvider, bool>((p) => p.userRole == 'cashier');

    return Scaffold(
      body: PageView(
        controller: _pageController,
        physics: const NeverScrollableScrollPhysics(), // tab taps only
        onPageChanged: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        children: isCashier ? _cashierScreens : _adminScreens,
      ),
      floatingActionButton: Selector<SyncEngine, int>(
        selector: (_, s) => s.pendingCount,
        builder: (context, count, child) {
          if (count == 0) return const SizedBox.shrink();
          final isSyncing = context.select<SyncEngine, bool>((s) => s.isSyncing);
          return FloatingActionButton.extended(
            onPressed: isSyncing ? null : () => _showSyncBottomSheet(context),
            backgroundColor: Colors.amber[700],
            icon: isSyncing
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                : const Icon(Icons.sync_problem, color: Colors.white),
            label: Text(
              '$count في الانتظار',
              style: const TextStyle(color: Colors.white, fontFamily: 'Cairo', fontWeight: FontWeight.bold),
            ),
          );
        },
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (i) {
          _pageController.jumpToPage(i);
        },
        selectedItemColor: AppColors.primary,
        unselectedItemColor: AppColors.textHint,
        backgroundColor: Colors.white,
        type: BottomNavigationBarType.fixed,
        elevation: 10,
        items: [
          const BottomNavigationBarItem(
            icon: Icon(Icons.dashboard_outlined),
            activeIcon: Icon(Icons.dashboard),
            label: AppStrings.dashboard,
          ),
          BottomNavigationBarItem(
            icon: Selector<AppProvider, int>(
              selector: (_, p) => p.cartItemCount,
              builder: (context, count, _) => Badge(
                isLabelVisible: count > 0,
                label: Text('$count'),
                child: const Icon(Icons.point_of_sale_outlined),
              ),
            ),
            activeIcon: Selector<AppProvider, int>(
              selector: (_, p) => p.cartItemCount,
              builder: (context, count, _) => Badge(
                isLabelVisible: count > 0,
                label: Text('$count'),
                child: const Icon(Icons.point_of_sale),
              ),
            ),
            label: AppStrings.pos,
          ),
          const BottomNavigationBarItem(
            icon: Icon(Icons.inventory_2_outlined),
            activeIcon: Icon(Icons.inventory_2),
            label: AppStrings.inventory,
          ),
          const BottomNavigationBarItem(
            icon: Icon(Icons.bar_chart_outlined),
            activeIcon: Icon(Icons.bar_chart),
            label: AppStrings.reports,
          ),
          const BottomNavigationBarItem(
            icon: Icon(Icons.settings_outlined),
            activeIcon: Icon(Icons.settings),
            label: AppStrings.settings,
          ),
        ],
      ),
    );
  }
}
