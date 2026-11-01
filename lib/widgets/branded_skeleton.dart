import 'package:flutter/material.dart';

import '../core/brand_config.dart';
import '../theme/app_colors.dart';

/// نظام التحميل الموحد للتطبيق — بنفس الهوية (كحلي/برتقالي).
///
/// - [BrandedSkeleton]: شريط shimmer أساسي بحركة انسيابية.
/// - [BrandedSkeletonList]: هيكل بطاقات طلبات يحاكي [OrderListCard].
/// - [DetailsSkeleton]: هيكل صفحة التفاصيل (خريطة + بطاقتين).
/// - [AppLoader]: تحميل ملء الشاشة بشعار نابض + رسالة.
/// - [InlineLoader]: تحميل داخلي صغير (لتحديث الحالة...).

class BrandedSkeleton extends StatefulWidget {
  const BrandedSkeleton({
    super.key,
    this.width,
    this.height = 16,
    this.borderRadius = 8,
    this.brand,
  });

  final double? width;
  final double height;
  final double borderRadius;
  final BrandConfig? brand;

  @override
  State<BrandedSkeleton> createState() => _BrandedSkeletonState();
}

class _BrandedSkeletonState extends State<BrandedSkeleton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        // موجة لمعان تعبر الشريط من اليمين لليسار (RTL)
        final t = _controller.value;
        return Container(
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(widget.borderRadius),
            gradient: LinearGradient(
              begin: Alignment.centerRight,
              end: Alignment.centerLeft,
              stops: [
                0.0,
                (t * 1.6 - 0.6).clamp(0.0, 1.0),
                (t * 1.6 - 0.3).clamp(0.0, 1.0),
                1.0,
              ],
              colors: const [
                Color(0xFFE9EBEE),
                Color(0xFFE9EBEE),
                Color(0xFFF7F8FA),
                Color(0xFFE9EBEE),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// هيكل بطاقة طلب واحدة — يحاكي أبعاد OrderListCard الجديدة.
class _OrderCardSkeleton extends StatelessWidget {
  const _OrderCardSkeleton({this.brand});

  final BrandConfig? brand;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.greyBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              BrandedSkeleton(
                brand: brand,
                width: 44,
                height: 44,
                borderRadius: 14,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    BrandedSkeleton(brand: brand, width: 90, height: 15),
                    const SizedBox(height: 6),
                    BrandedSkeleton(brand: brand, width: 130, height: 12),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              BrandedSkeleton(
                brand: brand,
                width: 72,
                height: 26,
                borderRadius: 10,
              ),
            ],
          ),
          const SizedBox(height: 10),
          BrandedSkeleton(
            brand: brand,
            width: double.infinity,
            height: 12,
          ),
          const SizedBox(height: 10),
          BrandedSkeleton(
            brand: brand,
            width: double.infinity,
            height: 40,
            borderRadius: 12,
          ),
        ],
      ),
    );
  }
}

/// هيكل سطور نصية (لصفحة السياسات والإشعارات الفارغة).
class ParagraphSkeleton extends StatelessWidget {
  const ParagraphSkeleton({super.key, this.brand, this.lines = 8});

  final BrandConfig? brand;
  final int lines;

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      physics: const NeverScrollableScrollPhysics(),
      shrinkWrap: true,
      itemCount: lines,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (_, i) => BrandedSkeleton(
        brand: brand,
        width: i % 3 == 2 ? 220 : double.infinity,
        height: 14,
      ),
    );
  }
}

class BrandedSkeletonList extends StatelessWidget {
  const BrandedSkeletonList({super.key, this.count = 4, this.brand});

  final int count;
  final BrandConfig? brand;

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      physics: const NeverScrollableScrollPhysics(),
      shrinkWrap: true,
      itemCount: count,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (_, __) => _OrderCardSkeleton(brand: brand),
    );
  }
}

/// هيكل صفحة تفاصيل الطلب: خريطة + بطاقة عميل + بطاقة عناصر + أزرار.
class DetailsSkeleton extends StatelessWidget {
  const DetailsSkeleton({super.key, this.brand});

  final BrandConfig? brand;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      physics: const NeverScrollableScrollPhysics(),
      shrinkWrap: true,
      children: [
        BrandedSkeleton(brand: brand, height: 220, borderRadius: 20),
        const SizedBox(height: 16),
        BrandedSkeleton(brand: brand, height: 120, borderRadius: 20),
        const SizedBox(height: 16),
        BrandedSkeleton(brand: brand, height: 180, borderRadius: 20),
        const SizedBox(height: 16),
        BrandedSkeleton(brand: brand, height: 54, borderRadius: 16),
        const SizedBox(height: 8),
        BrandedSkeleton(brand: brand, height: 54, borderRadius: 16),
      ],
    );
  }
}

/// تحميل ملء الشاشة: شعار نابض بتوهج برتقالي + مؤشر + رسالة اختيارية.
class AppLoader extends StatefulWidget {
  const AppLoader({super.key, this.message, this.compact = false});

  final String? message;
  final bool compact;

  @override
  State<AppLoader> createState() => _AppLoaderState();
}

class _AppLoaderState extends State<AppLoader>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1300),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedBuilder(
              animation: _pulse,
              builder: (context, child) {
                return Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: AppColors.white,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: AppColors.orange.withValues(
                        alpha: 0.3 + _pulse.value * 0.5,
                      ),
                      width: 2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.orange.withValues(
                          alpha: 0.15 + _pulse.value * 0.25,
                        ),
                        blurRadius: 24 + _pulse.value * 16,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: child,
                );
              },
              child: Image.asset(
                'assets/brand/logo.webp',
                height: widget.compact ? 40 : 56,
                errorBuilder: (_, __, ___) => Icon(
                  Icons.delivery_dining,
                  size: widget.compact ? 36 : 52,
                  color: AppColors.orange,
                ),
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: 32,
              height: 32,
              child: CircularProgressIndicator(
                strokeWidth: 3,
                color: AppColors.orange,
              ),
            ),
            if (widget.message != null) ...[
              const SizedBox(height: 12),
              Text(
                widget.message!,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: AppColors.greyText,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// تحميل داخلي مضمّن: مؤشر + نص بجانبه لسطر واحد (مثال: جاري تحديث الحالة...).
class InlineLoader extends StatelessWidget {
  const InlineLoader({super.key, this.message = 'جاري التحميل...'});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.orange.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: AppColors.orange.withValues(alpha: 0.25),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2.4,
              color: AppColors.orange,
            ),
          ),
          const SizedBox(width: 10),
          Flexible(
            child: Text(
              message,
              style: TextStyle(
                color: AppColors.navy,
                fontWeight: FontWeight.w700,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// أعمدة shimmer لمنطقة الرسم البياني الصغير.
class ChartSkeleton extends StatelessWidget {
  const ChartSkeleton({super.key, this.brand});

  final BrandConfig? brand;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 110,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: List.generate(
          7,
          (i) => Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 3),
              child: BrandedSkeleton(
                brand: brand,
                height: 30 + ((i * 37) % 70),
                borderRadius: 6,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// هيكل صف ListTile (أيقونة دائرية + سطرين + ذيل) — للتحويلات،
/// الإشعارات، عناصر التحصيل، وحالات الإشعارات.
class _TileSkeleton extends StatelessWidget {
  const _TileSkeleton({this.brand, this.tall = false});

  final BrandConfig? brand;
  final bool tall;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.greyBorder),
      ),
      child: Row(
        children: [
          BrandedSkeleton(
            brand: brand,
            width: 40,
            height: 40,
            borderRadius: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                BrandedSkeleton(brand: brand, width: 140, height: 13),
                const SizedBox(height: 7),
                BrandedSkeleton(
                  brand: brand,
                  width: double.infinity,
                  height: 11,
                ),
                if (tall) ...[
                  const SizedBox(height: 7),
                  BrandedSkeleton(brand: brand, width: 180, height: 11),
                ],
              ],
            ),
          ),
          const SizedBox(width: 8),
          BrandedSkeleton(brand: brand, width: 46, height: 14),
        ],
      ),
    );
  }
}

class TileSkeletonList extends StatelessWidget {
  const TileSkeletonList({
    super.key,
    this.count = 5,
    this.brand,
    this.tall = false,
  });

  final int count;
  final BrandConfig? brand;
  final bool tall;

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      physics: const NeverScrollableScrollPhysics(),
      shrinkWrap: true,
      itemCount: count,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (_, __) => _TileSkeleton(brand: brand, tall: tall),
    );
  }
}

/// هيكل شاشة ملخص + قائمة (التحصيل النقدي، السحب): بطاقة ملخص علوية + صفوف.
class SummarySkeleton extends StatelessWidget {
  const SummarySkeleton({super.key, this.brand, this.tiles = 4});

  final BrandConfig? brand;
  final int tiles;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      physics: const NeverScrollableScrollPhysics(),
      shrinkWrap: true,
      children: [
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.greyBorder),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              BrandedSkeleton(brand: brand, width: 150, height: 15),
              const SizedBox(height: 10),
              BrandedSkeleton(
                brand: brand,
                width: double.infinity,
                height: 34,
                borderRadius: 12,
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        ...List.generate(
          tiles,
          (_) => Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _TileSkeleton(brand: brand),
          ),
        ),
      ],
    );
  }
}

/// هيكل شاشة الخريطة المباشرة: منطقة خريطة + بطاقة عائمة سفلية.
class MapSkeleton extends StatelessWidget {
  const MapSkeleton({super.key, this.brand});

  final BrandConfig? brand;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: Container(
            margin: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppColors.greyBorder),
            ),
            child: Stack(
              children: [
                Positioned(
                  top: 16,
                  right: 16,
                  child: BrandedSkeleton(
                    brand: brand,
                    width: 140,
                    height: 34,
                    borderRadius: 12,
                  ),
                ),
                Positioned(
                  bottom: 16,
                  left: 16,
                  child: BrandedSkeleton(
                    brand: brand,
                    width: 170,
                    height: 34,
                    borderRadius: 12,
                  ),
                ),
                Center(
                  child: BrandedSkeleton(
                    brand: brand,
                    width: 56,
                    height: 56,
                    borderRadius: 28,
                  ),
                ),
              ],
            ),
          ),
        ),
        Container(
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.greyBorder),
          ),
          child: Column(
            children: [
              Row(
                children: [
                  BrandedSkeleton(
                    brand: brand,
                    width: 44,
                    height: 44,
                    borderRadius: 12,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        BrandedSkeleton(
                            brand: brand, width: 120, height: 14),
                        const SizedBox(height: 6),
                        BrandedSkeleton(brand: brand, width: 80, height: 11),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              BrandedSkeleton(
                brand: brand,
                width: double.infinity,
                height: 48,
                borderRadius: 14,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// هيكل صف مؤشرات الرئيسية الثلاثة — يمنع وميض الأصفار عند أول فتح.
class KpiSkeleton extends StatelessWidget {
  const KpiSkeleton({super.key, this.brand});

  final BrandConfig? brand;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: List.generate(
        3,
        (_) => Expanded(
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 5),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppColors.greyBorder),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                BrandedSkeleton(
                    brand: brand, width: 36, height: 4, borderRadius: 4),
                const SizedBox(height: 10),
                BrandedSkeleton(
                  brand: brand,
                  width: 38,
                  height: 38,
                  borderRadius: 12,
                ),
                const SizedBox(height: 10),
                BrandedSkeleton(brand: brand, width: 56, height: 18),
                const SizedBox(height: 6),
                BrandedSkeleton(brand: brand, width: 70, height: 11),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
