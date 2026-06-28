import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_strings.dart';
import '../../core/providers/app_provider.dart';
import '../../services/api_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  @override
  Widget build(BuildContext context) {
    final provider = context.read<AppProvider>();
    final isCashier = provider.userRole == 'cashier';

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text(AppStrings.settingsTitle),
        automaticallyImplyLeading: false,
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Profile header
            Selector<AppProvider, List<String>>(
              selector: (_, p) => [p.storeName, p.storeEmail, p.userRole, p.username],
              builder: (context, data, __) {
                final storeName = data[0];
                final storeEmail = data[1];
                final role = data[2];
                final username = data[3];
                final isUserCashier = role == 'cashier';
                return Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(24),
                  decoration: const BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.only(
                      bottomLeft: Radius.circular(30),
                      bottomRight: Radius.circular(30),
                    ),
                  ),
                  child: Column(
                    children: [
                      Container(
                        width: 72,
                        height: 72,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.15),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.store,
                            color: Colors.white, size: 36),
                      ),
                      const SizedBox(height: 12),
                      Text(storeName,
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.w700)),
                      const SizedBox(height: 4),
                      Text(isUserCashier ? 'اسم المستخدم: $username (كاشير)' : storeEmail,
                          style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.7),
                              fontSize: 13)),
                    ],
                  ),
                );
              },
            ),
            const SizedBox(height: 16),

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                children: [
                  if (!isCashier) ...[
                    // Store settings
                    _SettingsGroup(
                      title: AppStrings.storeSettings,
                      children: [
                        Selector<AppProvider, String>(
                          selector: (_, p) => p.storeName,
                          builder: (context, storeName, __) => _SettingsTile(
                            icon: Icons.store_outlined,
                            title: 'اسم المتجر',
                            subtitle: storeName,
                            onTap: () => _showEditStoreDialog(context, provider),
                          ),
                        ),
                        Selector<AppProvider, String>(
                          selector: (_, p) => p.storeAddress,
                          builder: (context, storeAddress, __) => _SettingsTile(
                            icon: Icons.location_on_outlined,
                            title: 'العنوان',
                            subtitle: storeAddress,
                            onTap: () =>
                                _showEditAddressDialog(context, provider),
                          ),
                        ),
                        Selector<AppProvider, String>(
                          selector: (_, p) => p.storePhone,
                          builder: (context, storePhone, __) => _SettingsTile(
                            icon: Icons.phone_outlined,
                            title: 'رقم الهاتف',
                            subtitle: storePhone,
                            onTap: () => _showEditPhoneDialog(context, provider),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // Financial settings
                    _SettingsGroup(
                      title: 'الإعدادات المالية',
                      children: [
                        Selector<AppProvider, double>(
                          selector: (_, p) => p.taxRate,
                          builder: (context, taxRate, __) => _SettingsTile(
                            icon: Icons.percent,
                            title: AppStrings.taxSettings,
                            subtitle:
                                'ضريبة القيمة المضافة: ${taxRate.toStringAsFixed(0)}%',
                            onTap: () => _showEditTaxDialog(context, provider),
                          ),
                        ),
                        _SettingsTile(
                          icon: Icons.currency_exchange,
                          title: AppStrings.currency,
                          subtitle:
                              '${AppStrings.egp} (${AppStrings.currencySymbol})',
                          onTap: () {},
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // App settings
                    _SettingsGroup(
                      title: 'إعدادات التطبيق',
                      children: [
                        _SettingsTile(
                          icon: Icons.people_outline,
                          title: 'إدارة العملاء',
                          subtitle: 'قائمة العملاء وسجل المشتريات والمدفوعات',
                          onTap: () => Navigator.pushNamed(context, '/customers'),
                        ),
                        Selector<AppProvider, bool>(
                          selector: (_, p) => p.notificationsEnabled,
                          builder: (context, notificationsEnabled, __) =>
                              _SettingsTileSwitch(
                            icon: Icons.notifications_outlined,
                            title: AppStrings.notifications,
                            subtitle: 'تنبيهات المخزون وغيرها',
                            value: notificationsEnabled,
                            onChanged: (v) async {
                              await provider.updateStoreSettings(
                                name: provider.storeName,
                                address: provider.storeAddress,
                                phone: provider.storePhone,
                                email: provider.storeEmail,
                                tax: provider.taxRate,
                                notifications: v,
                                darkMode: provider.darkModeEnabled,
                              );
                            },
                          ),
                        ),
                        Selector<AppProvider, bool>(
                          selector: (_, p) => p.darkModeEnabled,
                          builder: (context, darkModeEnabled, __) =>
                              _SettingsTileSwitch(
                            icon: Icons.dark_mode_outlined,
                            title: AppStrings.darkMode,
                            subtitle: 'الوضع الليلي',
                            value: darkModeEnabled,
                            onChanged: (v) async {
                              await provider.updateStoreSettings(
                                name: provider.storeName,
                                address: provider.storeAddress,
                                phone: provider.storePhone,
                                email: provider.storeEmail,
                                tax: provider.taxRate,
                                notifications: provider.notificationsEnabled,
                                darkMode: v,
                              );
                            },
                          ),
                        ),
                        _SettingsTile(
                          icon: Icons.language_outlined,
                          title: AppStrings.language,
                          subtitle: AppStrings.arabicLanguage,
                          onTap: () {},
                        ),
                        _SettingsTile(
                          icon: Icons.print_outlined,
                          title: AppStrings.printerSettings,
                          subtitle: 'إعداد الطابعة الحرارية',
                          onTap: () {},
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // Network / API
                    _SettingsGroup(
                      title: 'الشبكة والاتصال',
                      children: [
                        _SettingsTile(
                          icon: Icons.cloud_outlined,
                          title: 'عنوان خادم الـ API',
                          subtitle: ApiService.baseUrl,
                          onTap: () => _showEditServerUrlDialog(context, provider),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // System
                    _SettingsGroup(
                      title: 'النظام',
                      children: [
                        _SettingsTile(
                          icon: Icons.backup_outlined,
                          title: AppStrings.backup,
                          subtitle: 'آخر نسخ: اليوم 08:00',
                          onTap: () => ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                  content: Text('جاري النسخ الاحتياطي...'))),
                        ),
                        _SettingsTile(
                          icon: Icons.info_outline,
                          title: AppStrings.aboutApp,
                          subtitle:
                              '${AppStrings.appName} • ${AppStrings.version} 1.0.0',
                          onTap: () {},
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                  ],

                  // Logout
                  ElevatedButton.icon(
                    onPressed: () => _showLogoutDialog(context, provider),
                    icon: const Icon(Icons.logout),
                    label: const Text(AppStrings.logout),
                    style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.error),
                  ),
                  const SizedBox(height: 80),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showEditServerUrlDialog(BuildContext context, AppProvider provider) {
    final ctrl = TextEditingController(text: ApiService.baseUrl);
    bool isSaving = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('عنوان خادم الـ API'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'الرابط الحالي:',
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
              const SizedBox(height: 4),
              GestureDetector(
                onTap: () {
                  Clipboard.setData(ClipboardData(text: ApiService.baseUrl));
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('تم نسخ الرابط')),
                  );
                },
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          ApiService.baseUrl,
                          style: const TextStyle(fontSize: 11, fontFamily: 'monospace'),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const Icon(Icons.copy, size: 14, color: Colors.grey),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: ctrl,
                decoration: const InputDecoration(
                  labelText: 'رابط جديد (اختياري)',
                  hintText: 'https://xxxx.vercel.app/api',
                  helperText: 'اتركه فارغاً للرجوع للافتراضي',
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('إلغاء'),
            ),
            TextButton(
              onPressed: () async {
                await ApiService.resetToDefault();
                if (ctx.mounted) {
                  Navigator.pop(ctx);
                  setState(() {});
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('تم الرجوع للرابط الافتراضي (Vercel)')),
                  );
                  provider.loadDashboardStats();
                }
              },
              child: const Text('إعادة تعيين', style: TextStyle(color: Colors.orange)),
            ),
            ElevatedButton(
              onPressed: isSaving
                  ? null
                  : () async {
                      final newUrl = ctrl.text.trim();
                      if (newUrl.isNotEmpty) {
                        setDialogState(() => isSaving = true);
                        await ApiService.updateServerIp(newUrl);
                        if (ctx.mounted) {
                          Navigator.pop(ctx);
                          setState(() {});
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('تم حفظ: $newUrl')),
                          );
                          provider.loadDashboardStats();
                        }
                      }
                    },
              child: isSaving
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text('حفظ'),
            ),
          ],
        ),
      ),
    );
  }

  void _showEditStoreDialog(BuildContext context, AppProvider provider) {
    final ctrl = TextEditingController(text: provider.storeName);
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('تعديل اسم المتجر'),
        content: TextField(
          controller: ctrl,
          decoration: const InputDecoration(labelText: 'اسم المتجر'),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('إلغاء')),
          ElevatedButton(
            onPressed: () async {
              if (ctrl.text.isNotEmpty) {
                await provider.updateStoreSettings(
                  name: ctrl.text,
                  address: provider.storeAddress,
                  phone: provider.storePhone,
                  email: provider.storeEmail,
                  tax: provider.taxRate,
                  notifications: provider.notificationsEnabled,
                  darkMode: provider.darkModeEnabled,
                );
              }
              if (context.mounted) Navigator.pop(context);
            },
            child: const Text('حفظ'),
          ),
        ],
      ),
    );
  }

  void _showEditAddressDialog(BuildContext context, AppProvider provider) {
    final ctrl = TextEditingController(text: provider.storeAddress);
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('تعديل العنوان'),
        content: TextField(
          controller: ctrl,
          decoration: const InputDecoration(labelText: 'العنوان'),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('إلغاء')),
          ElevatedButton(
            onPressed: () async {
              if (ctrl.text.isNotEmpty) {
                await provider.updateStoreSettings(
                  name: provider.storeName,
                  address: ctrl.text,
                  phone: provider.storePhone,
                  email: provider.storeEmail,
                  tax: provider.taxRate,
                  notifications: provider.notificationsEnabled,
                  darkMode: provider.darkModeEnabled,
                );
              }
              if (context.mounted) Navigator.pop(context);
            },
            child: const Text('حفظ'),
          ),
        ],
      ),
    );
  }

  void _showEditPhoneDialog(BuildContext context, AppProvider provider) {
    final ctrl = TextEditingController(text: provider.storePhone);
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('تعديل رقم الهاتف'),
        content: TextField(
          controller: ctrl,
          decoration: const InputDecoration(labelText: 'رقم الهاتف'),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('إلغاء')),
          ElevatedButton(
            onPressed: () async {
              if (ctrl.text.isNotEmpty) {
                await provider.updateStoreSettings(
                  name: provider.storeName,
                  address: provider.storeAddress,
                  phone: ctrl.text,
                  email: provider.storeEmail,
                  tax: provider.taxRate,
                  notifications: provider.notificationsEnabled,
                  darkMode: provider.darkModeEnabled,
                );
              }
              if (context.mounted) Navigator.pop(context);
            },
            child: const Text('حفظ'),
          ),
        ],
      ),
    );
  }

  void _showEditTaxDialog(BuildContext context, AppProvider provider) {
    final ctrl =
        TextEditingController(text: provider.taxRate.toStringAsFixed(0));
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('تعديل ضريبة القيمة المضافة'),
        content: TextField(
          controller: ctrl,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(labelText: 'نسبة الضريبة (%)'),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('إلغاء')),
          ElevatedButton(
            onPressed: () async {
              if (ctrl.text.isNotEmpty) {
                await provider.updateStoreSettings(
                  name: provider.storeName,
                  address: provider.storeAddress,
                  phone: provider.storePhone,
                  email: provider.storeEmail,
                  tax: double.tryParse(ctrl.text) ?? 14.0,
                  notifications: provider.notificationsEnabled,
                  darkMode: provider.darkModeEnabled,
                );
              }
              if (context.mounted) Navigator.pop(context);
            },
            child: const Text('حفظ'),
          ),
        ],
      ),
    );
  }

  void _showLogoutDialog(BuildContext context, AppProvider provider) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('تسجيل الخروج'),
        content: const Text('هل تريد تسجيل الخروج؟'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('إلغاء')),
          ElevatedButton(
            onPressed: () {
              provider.logout();
              Navigator.pushNamedAndRemoveUntil(
                  context, '/login', (_) => false);
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text('تسجيل الخروج'),
          ),
        ],
      ),
    );
  }
}

class _SettingsGroup extends StatelessWidget {
  final String title;
  final List<Widget> children;
  const _SettingsGroup({required this.title, required this.children});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(right: 4, bottom: 8),
          child: Text(title,
              style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary)),
        ),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            children: children.map((child) {
              final isLast = child == children.last;
              return Column(
                children: [
                  child,
                  if (!isLast) const Divider(height: 1, indent: 56),
                ],
              );
            }).toList(),
          ),
        ),
      ],
    );
  }
}

class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final String title, subtitle;
  final VoidCallback onTap;
  const _SettingsTile(
      {required this.icon,
      required this.title,
      required this.subtitle,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: onTap,
      leading: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: AppColors.primaryContainer,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, color: AppColors.primary, size: 20),
      ),
      title: Text(title,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
      subtitle: Text(subtitle,
          style: const TextStyle(fontSize: 12, color: AppColors.textHint)),
      trailing:
          const Icon(Icons.chevron_left, color: AppColors.textHint, size: 20),
    );
  }
}

class _SettingsTileSwitch extends StatelessWidget {
  final IconData icon;
  final String title, subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;
  const _SettingsTileSwitch(
      {required this.icon,
      required this.title,
      required this.subtitle,
      required this.value,
      required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: AppColors.primaryContainer,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, color: AppColors.primary, size: 20),
      ),
      title: Text(title,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
      subtitle: Text(subtitle,
          style: const TextStyle(fontSize: 12, color: AppColors.textHint)),
      trailing: Switch(
        value: value,
        onChanged: onChanged,
        activeColor: AppColors.primary,
      ),
    );
  }
}
