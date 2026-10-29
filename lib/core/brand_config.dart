import 'package:flutter/material.dart';

class BrandConfig {
  const BrandConfig({
    required this.version,
    required this.identity,
    required this.colors,
    required this.assets,
  });

  final int version;
  final Map<String, String> identity;
  final Map<String, String> colors;
  final Map<String, String?> assets;

  static const defaults = BrandConfig(
    version: 1,
    identity: {'name_ar': 'سريع MART - توصيل', 'name_en': 'SAREE MART - Delivery'},
    colors: {
      'primary': '#0A2540',
      'accent': '#FF6B00',
      'accent_dark': '#E05E00',
      'background': '#FFFFFF',
      'surface': '#F3F4F6',
      'text_primary': '#0A2540',
      'text_secondary': '#6B7280',
      'error': '#EF4444',
      'success': '#10B981',
    },
    assets: {},
  );

  factory BrandConfig.fromJson(Map<String, dynamic> json) {
    final base = defaults;
    final identity = Map<String, String>.from(base.identity);
    final id = json['identity'];
    if (id is Map) id.forEach((k, v) => identity['$k'] = '$v');
    // توصيل: إجبار لاحقة "- توصيل" حتى لو الـ Backend رجع "سريع MART" فقط — مثل فصل البائع
    if (identity['name_ar'] == 'سريع MART') {
      identity['name_ar'] = 'سريع MART - توصيل';
    }
    if (identity['name_en'] == 'SAREE MART') {
      identity['name_en'] = 'SAREE MART - Delivery';
    }

    final colors = Map<String, String>.from(base.colors);
    final c = json['colors'];
    if (c is Map) {
      c.forEach((k, v) {
        if (v != null && '$v'.isNotEmpty) colors['$k'] = '$v';
      });
    }

    final assets = <String, String?>{};
    final a = json['assets'];
    if (a is Map) {
      a.forEach((k, v) {
        final key = '$k';
        if (key.endsWith('_url')) {
          assets[key] = v == null ? null : '$v';
        } else if (v != null && '$v'.isNotEmpty) {
          assets[key] = '$v';
          final url = a['${key}_url'];
          if (url != null) assets['${key}_url'] = '$url';
        }
      });
    }

    return BrandConfig(
      version: int.tryParse('${json['version']}') ?? 1,
      identity: identity,
      colors: colors,
      assets: assets,
    );
  }

  Color get navy => _color('primary', 0xFF0A2540);
  Color get orange => _color('accent', 0xFFFF6B00);
  Color get orangeDark => _color('accent_dark', 0xFFE05E00);
  Color get white => _color('background', 0xFFFFFFFF);
  Color get greyBg => _color('surface', 0xFFF3F4F6);
  Color get greyText => _color('text_secondary', 0xFF6B7280);
  Color get error => _color('error', 0xFFEF4444);
  Color get success => _color('success', 0xFF10B981);
  String? get logoUrl => assets['logo_png_url'] ?? assets['logo_svg_url'];

  String get nameAr {
    final raw = (identity['name_ar'] ?? '').trim();
    return raw.isEmpty ? 'سريع MART - توصيل' : raw;
  }

  String get nameEn {
    final raw = (identity['name_en'] ?? '').trim();
    return raw.isEmpty ? 'SAREE MART - Delivery' : raw;
  }

  /// الاسم الأساسي بدون لاحقة "توصيل" (للاستخدام في الهيدر والسبلاش).
  String get shortNameAr => nameAr
      .replaceAll(RegExp(r'\s*[-–]\s*توصيل\s*$'), '')
      .trim();

  String get shortNameEn => nameEn
      .replaceAll(RegExp(r'\s*[-–]\s*Delivery\s*$', caseSensitive: false), '')
      .trim();

  String currencySymbol() => (identity['currency'] ?? '').trim();

  Color _color(String key, int fallback) {
    final raw = colors[key];
    if (raw == null || raw.isEmpty) return Color(fallback);
    var hex = raw.replaceAll('#', '').trim();
    if (hex.length == 3) {
      hex = hex.split('').map((c) => '$c$c').join();
    }
    if (hex.length == 6) hex = 'FF$hex';
    final value = int.tryParse(hex, radix: 16);
    if (value == null) return Color(fallback);
    return Color(value);
  }
}
