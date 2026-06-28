import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/providers/app_provider.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_strings.dart';
import '../../core/models/models.dart';

class SaleConfirmationScreen extends StatelessWidget {
  const SaleConfirmationScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final sale = ModalRoute.of(context)!.settings.arguments as Sale?;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              const Spacer(),
              // Success animation circle
              TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: 1),
                duration: const Duration(milliseconds: 600),
                curve: Curves.elasticOut,
                builder: (_, v, child) => Transform.scale(scale: v, child: child),
                child: Container(
                  width: 100, height: 100,
                  decoration: const BoxDecoration(
                    color: AppColors.primaryContainer,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.check_circle,
                    color: AppColors.primary,
                    size: 60,
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Text(
                AppStrings.saleConfirmed,
                style: Theme.of(context).textTheme.headlineMedium
                    ?.copyWith(color: AppColors.primary),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                AppStrings.saleConfirmedSub,
                style: Theme.of(context).textTheme.bodyMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),

              // Receipt card
              if (sale != null) ...[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: AppColors.border),
                  ),
                   child: Column(
                    children: [
                      _ReceiptRow(AppStrings.receiptNumber, sale.receiptNumber),
                      if (sale.customerId != null) ...[
                        const Divider(height: 16),
                        FutureBuilder<Customer?>(
                          future: context.read<AppProvider>().getCustomerById(sale.customerId!),
                          builder: (context, snapshot) {
                            final customerName = snapshot.data?.fullName ?? 'تحميل...';
                            return _ReceiptRow('العميل', customerName);
                          },
                        ),
                      ],
                      const Divider(height: 16),
                      ...sale.items.map((item) => _ReceiptRow(
                          '${item.product.name} × ${item.quantity}',
                          '${item.total.toStringAsFixed(2)} ${AppStrings.currencySymbol}')),
                      const Divider(height: 16),
                      _ReceiptRow('ضريبة (14%)',
                          '${sale.tax.toStringAsFixed(2)} ${AppStrings.currencySymbol}'),
                      const SizedBox(height: 4),
                      _ReceiptRow(AppStrings.total,
                          '${sale.total.toStringAsFixed(2)} ${AppStrings.currencySymbol}',
                          bold: true, color: AppColors.primary),
                      const Divider(height: 16),
                      _ReceiptRow(AppStrings.paymentMethod, sale.paymentMethod),
                      _ReceiptRow(AppStrings.amountPaid,
                          '${sale.amountPaid.toStringAsFixed(2)} ${AppStrings.currencySymbol}'),
                      if (sale.change > 0)
                        _ReceiptRow(AppStrings.change,
                            '${sale.change.toStringAsFixed(2)} ${AppStrings.currencySymbol}',
                            color: AppColors.success),
                    ],
                  ),
                ),
              ],

              const Spacer(),

              // Actions
              ElevatedButton.icon(
                onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('جاري الطباعة...'))),
                icon: const Icon(Icons.print_outlined),
                label: const Text(AppStrings.printReceipt),
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: () => Navigator.pushNamedAndRemoveUntil(
                    context, '/home', (r) => false),
                icon: const Icon(Icons.add_circle_outline),
                label: const Text(AppStrings.newSale),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.primary,
                  side: const BorderSide(color: AppColors.primary),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ReceiptRow extends StatelessWidget {
  final String label;
  final String value;
  final bool bold;
  final Color? color;
  const _ReceiptRow(this.label, this.value, {this.bold = false, this.color});

  @override
  Widget build(BuildContext context) {
    final style = TextStyle(
      fontSize: bold ? 16 : 13,
      fontWeight: bold ? FontWeight.w700 : FontWeight.w400,
      color: color ?? AppColors.textPrimary,
    );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: style.copyWith(
              color: color ?? AppColors.textSecondary,
              fontWeight: FontWeight.w400)),
          Text(value, style: style),
        ],
      ),
    );
  }
}
