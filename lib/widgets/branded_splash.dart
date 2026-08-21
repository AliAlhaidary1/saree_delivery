import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Branded splash shown during app bootstrap.
class BrandedSplash extends StatelessWidget {
  const BrandedSplash({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.navy,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.asset(
              'assets/brand/logo.webp',
              height: 80,
              errorBuilder: (_, __, ___) => const Icon(
                Icons.delivery_dining,
                size: 64,
                color: AppColors.orange,
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'سريع ماركت',
              style: TextStyle(
                color: AppColors.white,
                fontSize: 24,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'تطبيق سائق التوصيل',
              style: TextStyle(
                color: AppColors.white.withValues(alpha: 0.7),
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 40),
            const SizedBox(
              width: 28,
              height: 28,
              child: CircularProgressIndicator(
                strokeWidth: 2.5,
                color: AppColors.orange,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
