import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../core/models/models.dart';
import '../core/constants/app_colors.dart';
import '../core/constants/app_strings.dart';
import '../core/providers/app_provider.dart';

class ReceiptDetailSheet extends StatelessWidget {
  final Sale sale;

  const ReceiptDetailSheet({super.key, required this.sale});

  static void show(BuildContext context, Sale sale) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => ReceiptDetailSheet(sale: sale),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<AppProvider>(context, listen: false);
    final dateFormatter = DateFormat('yyyy/MM/dd - hh:mm a', 'ar');
    final numberFormat = NumberFormat('#,##0.00', 'ar');

    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: AppColors.background,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            children: [
              // ─── Drag Handle ───────────────────────────────────────────────
              Container(
                margin: const EdgeInsets.symmetric(vertical: 12),
                width: 48,
                height: 5,
                decoration: BoxDecoration(
                  color: AppColors.border.withOpacity(0.8),
                  borderRadius: BorderRadius.circular(2.5),
                ),
              ),

              // ─── Header Navigation ──────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.close, color: AppColors.textPrimary),
                      onPressed: () => Navigator.pop(context),
                    ),
                    const Text(
                      'تفاصيل الفاتورة',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    // Invisible spacer to balance the close button
                    const SizedBox(width: 48),
                  ],
                ),
              ),
              const Divider(color: AppColors.border, height: 1),

              // ─── Scrollable Receipt Body ──────────────────────────────────
              Expanded(
                child: ListView(
                  controller: scrollController,
                  padding: const EdgeInsets.all(16),
                  children: [
                    // Physical Paper Slip Style Container
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.04),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // Top Store Header
                          Padding(
                            padding: const EdgeInsets.all(20),
                            child: Column(
                              children: [
                                Container(
                                  width: 60,
                                  height: 60,
                                  decoration: BoxDecoration(
                                    color: AppColors.primaryContainer,
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.storefront_outlined,
                                    color: AppColors.primary,
                                    size: 32,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  provider.storeName,
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w800,
                                    color: AppColors.primary,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  'عنوان: ${provider.storeAddress}',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: AppColors.textSecondary,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                                Text(
                                  'هاتف: ${provider.storePhone}',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: AppColors.textSecondary,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                                if (provider.storeEmail.isNotEmpty)
                                  Text(
                                    provider.storeEmail,
                                    style: const TextStyle(
                                      fontSize: 11,
                                      color: AppColors.textHint,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                              ],
                            ),
                          ),

                          const DashedDivider(),

                          // Invoice Meta Info
                          Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                _buildMetaRow('رقم الفاتورة:', sale.receiptNumber, isBoldValue: true),
                                const SizedBox(height: 8),
                                _buildMetaRow('التاريخ والوقت:', dateFormatter.format(sale.createdAt)),
                                const SizedBox(height: 8),
                                _buildMetaRow('طريقة الدفع:', sale.paymentMethod == 'cash' || sale.paymentMethod == 'نقداً' ? 'نقداً 💵' : 'بطاقة ائتمان 💳'),
                                const SizedBox(height: 8),
                                _buildMetaRow('حالة الفاتورة:', 'مكتملة ✅', isGreenValue: true),
                                if (sale.cashierName != null && sale.cashierName!.isNotEmpty) ...[
                                  const SizedBox(height: 8),
                                  _buildMetaRow('بواسطة (الكاشير):', sale.cashierName!),
                                ],
                              ],
                            ),
                          ),

                          const DashedDivider(),

                          // Itemized Table Header
                          Container(
                            color: AppColors.surfaceVariant.withOpacity(0.5),
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                            child: const Row(
                              children: [
                                Expanded(
                                  flex: 4,
                                  child: Text(
                                    'المنتج',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 13,
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                                ),
                                Expanded(
                                  flex: 2,
                                  child: Text(
                                    'الكمية',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 13,
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                                ),
                                Expanded(
                                  flex: 2,
                                  child: Text(
                                    'سعر البيع',
                                    textAlign: TextAlign.left,
                                    style: TextStyle(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 13,
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                                ),
                                Expanded(
                                  flex: 3,
                                  child: Text(
                                    'الإجمالي',
                                    textAlign: TextAlign.left,
                                    style: TextStyle(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 13,
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),

                          // Item List Rows
                          ListView.separated(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: sale.items.length,
                            separatorBuilder: (context, index) => const Divider(
                              color: AppColors.divider,
                              height: 1,
                              indent: 16,
                              endIndent: 16,
                            ),
                            itemBuilder: (context, index) {
                              final item = sale.items[index];
                              return Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                child: Row(
                                  children: [
                                    // Product Name
                                    Expanded(
                                      flex: 4,
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            item.product.name,
                                            style: const TextStyle(
                                              fontWeight: FontWeight.w600,
                                              fontSize: 14,
                                              color: AppColors.textPrimary,
                                            ),
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            item.product.barcode,
                                            style: const TextStyle(
                                              fontSize: 11,
                                              color: AppColors.textHint,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    // Quantity
                                    Expanded(
                                      flex: 2,
                                      child: Text(
                                        '${item.quantity}',
                                        textAlign: TextAlign.center,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w600,
                                          fontSize: 14,
                                          color: AppColors.textPrimary,
                                        ),
                                      ),
                                    ),
                                    // Unit Price
                                    Expanded(
                                      flex: 2,
                                      child: Text(
                                        numberFormat.format(item.product.sellingPrice),
                                        textAlign: TextAlign.left,
                                        style: const TextStyle(
                                          fontSize: 13,
                                          color: AppColors.textSecondary,
                                        ),
                                      ),
                                    ),
                                    // Subtotal
                                    Expanded(
                                      flex: 3,
                                      child: Text(
                                        '${numberFormat.format(item.total)} ${AppStrings.currencySymbol}',
                                        textAlign: TextAlign.left,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w700,
                                          fontSize: 14,
                                          color: AppColors.textPrimary,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),

                          const DashedDivider(),

                          // Financial Summary
                          Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              children: [
                                _buildSummaryRow('المجموع الفرعي:', '${numberFormat.format(sale.subtotal)} ${AppStrings.currencySymbol}'),
                                const SizedBox(height: 8),
                                if (sale.discount > 0) ...[
                                  _buildSummaryRow(
                                    'الخصم:',
                                    '- ${numberFormat.format(sale.discount)} ${AppStrings.currencySymbol}',
                                    valueColor: AppColors.warning,
                                  ),
                                  const SizedBox(height: 8),
                                ],
                                _buildSummaryRow('الضريبة (VAT %${provider.taxRate.toInt()}):', '${numberFormat.format(sale.tax)} ${AppStrings.currencySymbol}'),
                                const SizedBox(height: 12),
                                Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: AppColors.primaryContainer.withOpacity(0.5),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      const Text(
                                        'الإجمالي الصافي:',
                                        style: TextStyle(
                                          fontWeight: FontWeight.w800,
                                          fontSize: 16,
                                          color: AppColors.primaryDark,
                                        ),
                                      ),
                                      Text(
                                        '${numberFormat.format(sale.total)} ${AppStrings.currencySymbol}',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w900,
                                          fontSize: 18,
                                          color: AppColors.primary,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 12),
                                _buildSummaryRow('المبلغ المدفوع:', '${numberFormat.format(sale.amountPaid)} ${AppStrings.currencySymbol}'),
                                const SizedBox(height: 8),
                                _buildSummaryRow(
                                  'المتبقي (الباقي):',
                                  '${numberFormat.format(sale.change)} ${AppStrings.currencySymbol}',
                                  valueColor: AppColors.success,
                                  isBoldValue: true,
                                ),
                              ],
                            ),
                          ),

                          // Decorative Bottom Tooth Style
                          Container(
                            height: 8,
                            decoration: BoxDecoration(
                              color: AppColors.border.withOpacity(0.5),
                              borderRadius: const BorderRadius.vertical(bottom: Radius.circular(16)),
                            ),
                            child: ClipPath(
                              clipper: ReceiptTeethClipper(),
                              child: Container(color: Colors.white),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    // ─── Actions Bar ──────────────────────────────────────────
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              elevation: 0,
                            ),
                            onPressed: () {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Row(
                                    children: [
                                      Icon(Icons.print, color: Colors.white),
                                      SizedBox(width: 12),
                                      Text('جاري تهيئة الطابعة وطباعة الفاتورة...'),
                                    ],
                                  ),
                                  behavior: SnackBarBehavior.floating,
                                  backgroundColor: AppColors.primary,
                                ),
                              );
                            },
                            icon: const Icon(Icons.print_outlined),
                            label: const Text(
                              'طباعة الفاتورة',
                              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        IconButton(
                          style: IconButton.styleFrom(
                            backgroundColor: Colors.white,
                            foregroundColor: AppColors.textSecondary,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                              side: const BorderSide(color: AppColors.border),
                            ),
                            padding: const EdgeInsets.all(14),
                          ),
                          onPressed: () {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Row(
                                  children: [
                                    Icon(Icons.share, color: Colors.white),
                                    SizedBox(width: 12),
                                    Text('جاري تحضير ملف الفاتورة للمشاركة...'),
                                  ],
                                ),
                                behavior: SnackBarBehavior.floating,
                                backgroundColor: AppColors.secondary,
                              ),
                            );
                          },
                          icon: const Icon(Icons.share_outlined),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildMetaRow(String label, String value, {bool isBoldValue = false, bool isGreenValue = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 13,
            fontWeight: isBoldValue || isGreenValue ? FontWeight.w700 : FontWeight.w500,
            color: isGreenValue ? AppColors.success : AppColors.textPrimary,
          ),
        ),
      ],
    );
  }

  Widget _buildSummaryRow(String label, String value, {Color? valueColor, bool isBoldValue = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 14, color: AppColors.textSecondary),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 14,
            fontWeight: isBoldValue ? FontWeight.w700 : FontWeight.w600,
            color: valueColor ?? AppColors.textPrimary,
          ),
        ),
      ],
    );
  }
}

class DashedDivider extends StatelessWidget {
  final double height;
  final Color color;
  final double dashWidth;
  final double dashGap;

  const DashedDivider({
    super.key,
    this.height = 1.5,
    this.color = AppColors.border,
    this.dashWidth = 5,
    this.dashGap = 3,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final boxWidth = constraints.constrainWidth();
        final dashCount = (boxWidth / (dashWidth + dashGap)).floor();
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Flex(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            direction: Axis.horizontal,
            children: List.generate(dashCount, (_) {
              return SizedBox(
                width: dashWidth,
                height: height,
                child: DecoratedBox(
                  decoration: BoxDecoration(color: color),
                ),
              );
            }),
          ),
        );
      },
    );
  }
}

class ReceiptTeethClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    final path = Path();
    path.lineTo(0, size.height);

    double x = 0;
    double y = size.height;
    const double toothWidth = 8;
    const double toothHeight = 4;

    while (x < size.width) {
      x += toothWidth;
      y = (y == size.height) ? (size.height - toothHeight) : size.height;
      path.lineTo(x, y);
    }

    path.lineTo(size.width, 0);
    path.close();
    return path;
  }

  @override
  bool shouldReclip(CustomClipper<Path> oldClipper) => false;
}
