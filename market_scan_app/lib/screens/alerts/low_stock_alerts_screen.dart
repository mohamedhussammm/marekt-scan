import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_strings.dart';
import '../../core/providers/app_provider.dart';

class LowStockAlertsScreen extends StatelessWidget {
  const LowStockAlertsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();
    final critical = provider.lowStockProducts.where((p) => p.isCriticalStock).toList();
    final low = provider.lowStockProducts.where((p) => !p.isCriticalStock).toList();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text(AppStrings.lowStockAlertsTitle)),
      body: provider.lowStockProducts.isEmpty
          ? Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.check_circle_outline, size: 72, color: AppColors.success),
            const SizedBox(height: 16),
            const Text('المخزون في مستوى جيد',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600,
                    color: AppColors.success)),
            const SizedBox(height: 8),
            const Text('لا توجد منتجات تحتاج لإعادة تزويد',
                style: TextStyle(color: AppColors.textSecondary)),
          ],
        ),
      )
          : SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Summary banner
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.warning.withOpacity(0.08),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.warning.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.warning_amber_rounded, color: AppColors.warning, size: 32),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('${provider.lowStockProducts.length} منتجات تحتاج تزويد',
                          style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              color: AppColors.warning, fontSize: 15)),
                      Text('${critical.length} حرج • ${low.length} منخفض',
                          style: const TextStyle(
                              color: AppColors.textSecondary, fontSize: 12)),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            if (critical.isNotEmpty) ...[
              _SectionHeader(
                  title: AppStrings.criticalStock,
                  icon: Icons.error_outline,
                  color: AppColors.criticalStock),
              const SizedBox(height: 8),
              ...critical.map((p) => _AlertTile(product: p, isCritical: true,
                  onReorder: () => Navigator.pushNamed(context, '/inventory'))),
              const SizedBox(height: 16),
            ],

            if (low.isNotEmpty) ...[
              _SectionHeader(
                  title: AppStrings.warningStock,
                  icon: Icons.warning_amber_outlined,
                  color: AppColors.lowStock),
              const SizedBox(height: 8),
              ...low.map((p) => _AlertTile(product: p, isCritical: false,
                  onReorder: () => Navigator.pushNamed(context, '/inventory'))),
            ],

            const SizedBox(height: 80),
          ],
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color color;
  const _SectionHeader({required this.title, required this.icon, required this.color});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(width: 6),
        Text(title,
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: color)),
      ],
    );
  }
}

class _AlertTile extends StatelessWidget {
  final dynamic product;
  final bool isCritical;
  final VoidCallback onReorder;
  const _AlertTile({required this.product, required this.isCritical, required this.onReorder});

  Future<void> _launchWhatsApp(String productName) async {
    final message = "مرحباً، نحتاج إلى طلب كمية إضافية من $productName";
    final url = Uri.parse("https://wa.me/?text=${Uri.encodeComponent(message)}");
    if (await canLaunchUrl(url)) {
      await launchUrl(url);
    }
  }

  @override
  Widget build(BuildContext context) {
    final borderColor = isCritical
        ? AppColors.criticalStock.withOpacity(0.3)
        : AppColors.lowStock.withOpacity(0.3);
    final bgColor = isCritical
        ? AppColors.criticalStock.withOpacity(0.04)
        : AppColors.lowStock.withOpacity(0.04);
    final accentColor = isCritical ? AppColors.criticalStock : AppColors.lowStock;

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
            width: 44, height: 44,
            decoration: BoxDecoration(
              color: accentColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(Icons.inventory_2_outlined, color: accentColor, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(product.name,
                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                const SizedBox(height: 2),
                Wrap(
                  spacing: 4,
                  runSpacing: 2,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text('${AppStrings.currentStock}: ',
                        style: const TextStyle(fontSize: 11, color: AppColors.textHint)),
                    Text('${product.stockQuantity} ${AppStrings.pieces}',
                        style: TextStyle(
                            fontSize: 11, color: accentColor, fontWeight: FontWeight.w700)),
                    Text(' • ${AppStrings.minLevel}: ${product.minStockLevel}',
                        style: const TextStyle(fontSize: 11, color: AppColors.textHint)),
                  ],
                ),
                const SizedBox(height: 4),
                LinearProgressIndicator(
                  value: (product.stockQuantity / (product.minStockLevel * 2)).clamp(0.0, 1.0),
                  backgroundColor: accentColor.withOpacity(0.1),
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
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            label: const Text('طلب WhatsApp',
                style: TextStyle(fontSize: 10, color: Colors.white)),
          ),
        ],
      ),
    );
  }
}
