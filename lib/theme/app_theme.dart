import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/brand_config.dart';
import 'app_colors.dart';

abstract final class AppTheme {
  static String? _cacheKey;
  static ThemeData? _cached;

  static ThemeData lightFor(BrandConfig brand) {
    final key =
        '${brand.version}|${brand.colors}|${brand.identity['name_ar']}|'
        '${brand.identity['name_en']}';
    if (_cacheKey == key && _cached != null) return _cached!;
    AppColors.apply(brand);
    final scheme = ColorScheme(
      brightness: Brightness.light,
      primary: AppColors.orange,
      onPrimary: AppColors.onAccent,
      secondary: AppColors.navy,
      onSecondary: AppColors.white,
      surface: AppColors.white,
      onSurface: AppColors.navy,
      error: AppColors.error,
      onError: AppColors.white,
    );

    final theme = ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: AppColors.greyBg,
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.navy,
        foregroundColor: AppColors.white,
        elevation: 0,
        centerTitle: false,
        systemOverlayStyle: SystemUiOverlayStyle(
          statusBarColor: AppColors.navy,
          statusBarIconBrightness: Brightness.light,
        ),
      ),
      textTheme: TextTheme(
        headlineSmall: TextStyle(
          color: AppColors.navy,
          fontWeight: FontWeight.w800,
          fontSize: 24,
        ),
        titleLarge: TextStyle(
          color: AppColors.navy,
          fontWeight: FontWeight.w800,
          fontSize: 20,
        ),
        titleMedium: TextStyle(
          color: AppColors.navy,
          fontWeight: FontWeight.w700,
          fontSize: 16,
        ),
        titleSmall: TextStyle(
          color: AppColors.navy,
          fontWeight: FontWeight.w700,
          fontSize: 14,
        ),
        bodyMedium: TextStyle(color: AppColors.navy, fontSize: 14),
        bodySmall: TextStyle(color: AppColors.greyText, fontSize: 12),
        labelMedium: TextStyle(
          color: AppColors.greyText,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
      cardTheme: CardThemeData(
        color: AppColors.white,
        elevation: 0,
        shadowColor: AppColors.navy.withValues(alpha: 0.08),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: AppColors.greyBorder),
        ),
      ),
      dialogTheme: DialogThemeData(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
        ),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        showDragHandle: true,
      ),
      chipTheme: ChipThemeData(
        backgroundColor: AppColors.white,
        selectedColor: AppColors.orange,
        secondarySelectedColor: AppColors.orange,
        checkmarkColor: AppColors.onAccent,
        labelStyle: TextStyle(color: AppColors.greyText,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
        secondaryLabelStyle: TextStyle(
          color: AppColors.onAccent,
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
        side: BorderSide(color: AppColors.greyBorder),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return AppColors.orange;
          return AppColors.greyText;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return AppColors.orange.withValues(alpha: 0.35);
          }
          return AppColors.navyLight.withValues(alpha: 0.4);
        }),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: AppColors.orange,
      ),
      listTileTheme: ListTileThemeData(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: AppColors.white,
        indicatorColor: AppColors.orange.withValues(alpha: 0.18),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return TextStyle(
              color: AppColors.orangeText,
              fontWeight: FontWeight.w700,
              fontSize: 12,
            );
          }
          return TextStyle(color: AppColors.greyText, fontSize: 12);
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return IconThemeData(color: AppColors.onAccent);
          }
          return IconThemeData(color: AppColors.greyText);
        }),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.orange,
          foregroundColor: AppColors.onAccent,
          minimumSize: const Size(64, 54),
          elevation: 4,
          shadowColor: AppColors.orange.withValues(alpha: 0.35),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          textStyle: const TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: 16,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.navy,
          side: BorderSide(color: AppColors.greyBorder),
          minimumSize: const Size(64, 48),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: AppColors.greyBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: AppColors.greyBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: AppColors.orangeText, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: AppColors.error),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
      dividerTheme: DividerThemeData(color: AppColors.greyBorder),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppColors.navy,
        contentTextStyle: TextStyle(
          color: AppColors.white,
          fontWeight: FontWeight.w600,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(foregroundColor: AppColors.orangeText),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(foregroundColor: AppColors.navy),
      ),
      bannerTheme: MaterialBannerThemeData(
        backgroundColor: AppColors.white,
        contentTextStyle: TextStyle(color: AppColors.navy),
      ),
    );
    _cacheKey = key;
    _cached = theme;
    return theme;
  }

  static ThemeData get light => lightFor(BrandConfig.defaults);
}
