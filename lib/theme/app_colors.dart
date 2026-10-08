import 'package:flutter/material.dart';

import '../core/brand_config.dart';

/// Dynamic brand colors — defaults are offline fallbacks only.
abstract final class AppColors {
  static Color navy = BrandConfig.defaults.navy;
  static Color orange = BrandConfig.defaults.orange;
  static Color white = BrandConfig.defaults.white;
  static Color greyBg = BrandConfig.defaults.greyBg;
  static const greyText = Color(0xFF6B7280);
  static const greyBorder = Color(0xFFE5E7EB);
  static Color success = BrandConfig.defaults.success;
  static Color error = BrandConfig.defaults.error;
  static Color navyLight = BrandConfig.defaults.navy;
  // مشتقات بنفس الهوية (تُحسب من ألوان البراند — لا تغيّر الهوية)
  static Color orangeDark = const Color(0xFFE05E00);
  static Color navySoft = const Color(0xFF14365C);
  static Color star = const Color(0xFFF59E0B);

  static void apply(BrandConfig brand) {
    navy = brand.navy;
    orange = brand.orange;
    white = brand.white;
    greyBg = brand.greyBg;
    success = brand.success;
    error = brand.error;
    navyLight = Color.lerp(brand.navy, Colors.white, 0.12) ?? brand.navy;
    // مشتق داكن من لون البراند نفسه للحفاظ على التدرجات بنفس الهوية
    orangeDark = _darken(brand.orange, 0.12);
    navySoft = Color.lerp(brand.navy, Colors.white, 0.08) ?? brand.navy;
  }

  static Color _darken(Color c, double amount) {
    final hsl = HSLColor.fromColor(c);
    return hsl
        .withLightness((hsl.lightness - amount).clamp(0.0, 1.0))
        .toColor();
  }

  /// ظل موحد ناعم لبطاقات التطبيق
  static List<BoxShadow> get cardShadow => [
        BoxShadow(
          color: navy.withValues(alpha: 0.06),
          blurRadius: 16,
          offset: const Offset(0, 6),
        ),
      ];

  static LinearGradient get orangeGradient => LinearGradient(
        colors: [orange, orangeDark],
        begin: Alignment.topRight,
        end: Alignment.bottomLeft,
      );

  static LinearGradient get navyGradient => LinearGradient(
        colors: [navy, navySoft],
        begin: Alignment.topRight,
        end: Alignment.bottomLeft,
      );
}
