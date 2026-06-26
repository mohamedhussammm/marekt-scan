import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/constants/app_colors.dart';
import '../core/constants/app_strings.dart';
import '../screens/dashboard/dashboard_screen.dart';
import '../screens/pos/pos_scanner_screen.dart';
import '../screens/inventory/inventory_screen.dart';
import '../screens/reports/reports_screen.dart';
import '../screens/settings/settings_screen.dart';
import '../core/providers/app_provider.dart';
import 'permission_denied_widget.dart';

class MainNavigation extends StatefulWidget {
  const MainNavigation({super.key});

  @override
  State<MainNavigation> createState() => _MainNavigationState();
}

class _MainNavigationState extends State<MainNavigation> {
  int _currentIndex = 0;
  late final PageController _pageController;

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
      backgroundColor: AppColors.background,
      body: SafeArea(child: PermissionDeniedWidget()),
    ),
    Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(child: PermissionDeniedWidget()),
    ),
    SettingsScreen(),
  ];

  static const _navItems = [
    _NavItem(Icons.dashboard_outlined, Icons.dashboard, AppStrings.dashboard),
    _NavItem(Icons.point_of_sale_outlined, Icons.point_of_sale, AppStrings.pos),
    _NavItem(Icons.inventory_2_outlined, Icons.inventory_2, AppStrings.inventory),
    _NavItem(Icons.bar_chart_outlined, Icons.bar_chart, AppStrings.reports),
    _NavItem(Icons.settings_outlined, Icons.settings, AppStrings.settings),
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
    final isCashier = context.select<AppProvider, bool>((p) => p.userRole == 'cashier');
    final cartCount = context.select<AppProvider, int>((p) => p.cartItemCount);

    return Scaffold(
      backgroundColor: AppColors.background,
      extendBody: true, // allows body to go behind transparent nav bar
      body: PageView(
        controller: _pageController,
        physics: const NeverScrollableScrollPhysics(),
        onPageChanged: (index) => setState(() => _currentIndex = index),
        children: isCashier ? _cashierScreens : _adminScreens,
      ),
      bottomNavigationBar: _GlassNavBar(
        currentIndex: _currentIndex,
        cartCount: cartCount,
        items: _navItems,
        onTap: (i) {
          _pageController.jumpToPage(i);
          setState(() => _currentIndex = i);
        },
      ),
    );
  }
}

class _NavItem {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  const _NavItem(this.icon, this.activeIcon, this.label);
}

class _GlassNavBar extends StatelessWidget {
  final int currentIndex;
  final int cartCount;
  final List<_NavItem> items;
  final ValueChanged<int> onTap;

  const _GlassNavBar({
    required this.currentIndex,
    required this.cartCount,
    required this.items,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
      child: RepaintBoundary(
        child: ClipRRect(
          borderRadius: BorderRadius.circular(28),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
            child: Container(
              height: 64,
              decoration: BoxDecoration(
                color: const Color(0xEEFFFFFF), // 93% white frosted
                borderRadius: BorderRadius.circular(28),
                border: Border.all(color: AppColors.glassBorder, width: 1),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.10),
                    blurRadius: 20,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                children: items.asMap().entries.map((entry) {
                  final i = entry.key;
                  final item = entry.value;
                  final isActive = i == currentIndex;
                  final showBadge = i == 1 && cartCount > 0;

                  return Expanded(
                    child: GestureDetector(
                      onTap: () => onTap(i),
                      behavior: HitTestBehavior.opaque,
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        curve: Curves.easeOut,
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Stack(
                              clipBehavior: Clip.none,
                              children: [
                                AnimatedContainer(
                                  duration: const Duration(milliseconds: 200),
                                  padding: const EdgeInsets.all(6),
                                  decoration: isActive
                                      ? BoxDecoration(
                                          color: AppColors.accentGlow.withValues(alpha: 0.15),
                                          borderRadius: BorderRadius.circular(12),
                                        )
                                      : null,
                                  child: Icon(
                                    isActive ? item.activeIcon : item.icon,
                                    size: 22,
                                    color: isActive
                                        ? AppColors.primary
                                        : AppColors.textHint,
                                  ),
                                ),
                                if (showBadge)
                                  Positioned(
                                    top: -2,
                                    right: -2,
                                    child: Container(
                                      padding: const EdgeInsets.all(3),
                                      decoration: const BoxDecoration(
                                        color: AppColors.accentGlow,
                                        shape: BoxShape.circle,
                                      ),
                                      constraints: const BoxConstraints(
                                        minWidth: 16, minHeight: 16),
                                      child: Text(
                                        '$cartCount',
                                        textAlign: TextAlign.center,
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 9,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 2),
                            AnimatedDefaultTextStyle(
                              duration: const Duration(milliseconds: 200),
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                                color: isActive ? AppColors.primary : AppColors.textHint,
                                fontFamily: 'Cairo',
                              ),
                              child: Text(item.label),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
