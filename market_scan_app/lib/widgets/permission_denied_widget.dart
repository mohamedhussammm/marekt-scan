import 'package:flutter/material.dart';
import '../core/constants/app_colors.dart';

class PermissionDeniedWidget extends StatelessWidget {
  const PermissionDeniedWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32.0, vertical: 48.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Premium Padlock Icon with soft glows
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                color: Colors.red.withValues(alpha: 0.08),
                shape: BoxShape.circle,
                border: Border.all(
                  color: Colors.redAccent.withValues(alpha: 0.2),
                  width: 2,
                ),
              ),
              child: const Center(
                child: Icon(
                  Icons.lock_person_outlined,
                  size: 56,
                  color: Colors.redAccent,
                ),
              ),
            ),
            const SizedBox(height: 32),
            
            // Access Denied Title
            const Text(
              'صلاحيات غير كافية',
              style: TextStyle(
                fontFamily: 'Cairo',
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            
            // Description text
            const Text(
              'عذراً، هذا القسم مخصص لمالك المتجر (المدير) فقط.\nتم إغلاق الوصول تلقائياً لحسابات الموظفين.',
              style: TextStyle(
                fontFamily: 'Cairo',
                fontSize: 14,
                color: AppColors.textHint,
                height: 1.6,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            
            // Informational badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.orange.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.orange.withValues(alpha: 0.3), width: 1),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.shield_outlined, color: Colors.orange, size: 16),
                  SizedBox(width: 8),
                  Text(
                    'نظام حماية الحسابات مُفعّل',
                    style: TextStyle(
                      fontFamily: 'Cairo',
                      color: Colors.orange,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
