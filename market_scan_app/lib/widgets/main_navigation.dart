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
