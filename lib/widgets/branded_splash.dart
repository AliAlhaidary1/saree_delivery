import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/app_controller.dart';

/// شاشة بداية واحدة فقط — خلفية كحلية سادة (نفس لون الـ Native)
/// أنيميشن بسيط وسريع: خطوط سرعة + ومضة برق + ظهور اسم سريع MART.
class BrandedSplash extends StatefulWidget {
  const BrandedSplash({super.key});

  @override
  State<BrandedSplash> createState() => _BrandedSplashState();
}

class _BrandedSplashState extends State<BrandedSplash>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;

  late final Animation<double> _lines; // خطوط السرعة تنزلق من اليسار
  late final Animation<double> _brandFade; // الاسم يظهر
  late final Animation<double> _brandSlide; // الاسم ينزلق للأعلى قليلاً
  late final Animation<double> _lineGrow; // الخط البرتقالي يتمدد
  late final Animation<double> _bolt1; // ومضة البرق الأولى
  late final Animation<double> _bolt2; // ومضة البرق الثانية

  @override
  void initState() {
    super.initState();
    _c = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );

    _lines = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _c,
        curve: const Interval(0.0, 0.30, curve: Curves.easeOutCubic),
      ),
    );
    _brandFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _c,
        curve: const Interval(0.15, 0.50, curve: Curves.easeOut),
      ),
    );
    _brandSlide = Tween<double>(begin: 18.0, end: 0.0).animate(
      CurvedAnimation(
        parent: _c,
        curve: const Interval(0.15, 0.50, curve: Curves.easeOutCubic),
      ),
    );
    // البرق يومض مرتين: 0.35-0.50 و 0.60-0.75
    _bolt1 = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _c,
        curve: const Interval(0.35, 0.50, curve: Curves.easeInOut),
      ),
    );
    _bolt2 = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _c,
        curve: const Interval(0.60, 0.75, curve: Curves.easeInOut),
      ),
    );
    _lineGrow = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _c,
        curve: const Interval(0.45, 0.70, curve: Curves.easeOutCubic),
      ),
    );

    _c.forward();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: app,
      builder: (context, _) {
        final navy = app.brand.navy;
        final orange = app.brand.orange;
        final short = app.brand.shortNameAr;
        final parts = short.split(' ').where((p) => p.isNotEmpty).toList();
        final first = parts.isNotEmpty ? parts.first : short;
        final second = parts.length > 1 ? parts.sublist(1).join(' ') : '';
        return AnnotatedRegion<SystemUiOverlayStyle>(
          value: const SystemUiOverlayStyle(
            statusBarColor: Colors.transparent,
            statusBarIconBrightness: Brightness.light,
            systemNavigationBarColor: Color(0xFF0A2540),
          ),
          child: Directionality(
            textDirection: TextDirection.rtl,
            child: Scaffold(
              backgroundColor: navy,
              body: SafeArea(
                child: Center(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: AnimatedBuilder(
                      animation: _c,
                      builder: (context, _) {
                        // شدة البرق = max الومضتين (يومض مرتين ثم يثبت)
                        final bolt =
                            (_bolt1.value > _bolt2.value
                                    ? _bolt1.value
                                    : _bolt2.value)
                                .clamp(0.0, 1.0);
                        return Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  // خطوط السرعة
                                  Opacity(
                                    opacity: _lines.value.clamp(0.0, 1.0),
                                    child: Transform.translate(
                                      offset: Offset(
                                        -30 *
                                            (1 - _lines.value.clamp(0.0, 1.0)),
                                        0,
                                      ),
                                      child: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          _bar(30, 0.9, orange),
                                          const SizedBox(height: 5),
                                          _bar(42, 1.0, orange),
                                          const SizedBox(height: 5),
                                          _bar(24, 0.7, orange),
                                        ],
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  // الاسم الأول بالأبيض
                                  Opacity(
                                    opacity: _brandFade.value.clamp(0.0, 1.0),
                                    child: Transform.translate(
                                      offset: Offset(0, _brandSlide.value),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Text(
                                            first,
                                            style: TextStyle(
                                              color: app.brand.white,
                                              fontSize: 46,
                                              fontWeight: FontWeight.w800,
                                              height: 1.1,
                                            ),
                                          ),
                                          const SizedBox(width: 6),
                                          // البرق بجانب الاسم يومض
                                          Icon(
                                            Icons.bolt_rounded,
                                            size: 30,
                                            color: orange.withValues(
                                              alpha: 0.25 + 0.75 * bolt,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            if (second.isNotEmpty) ...[
                              const SizedBox(height: 2),
                              FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Opacity(
                                  opacity: _brandFade.value.clamp(0.0, 1.0),
                                  child: Transform.translate(
                                    offset: Offset(0, _brandSlide.value),
                                    child: Text(
                                      second,
                                      style: TextStyle(
                                        color: orange,
                                        fontSize: 34,
                                        fontWeight: FontWeight.w900,
                                        letterSpacing: 6.0,
                                        height: 1.1,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                            const SizedBox(height: 10),
                            // الخط المتمدد تحت الاسم
                            Opacity(
                              opacity: _brandFade.value.clamp(0.0, 1.0),
                              child: Transform.scale(
                                scaleX: _lineGrow.value.clamp(0.001, 1.0),
                                alignment: Alignment.center,
                                child: Container(
                                  width: 200,
                                  height: 4,
                                  decoration: BoxDecoration(
                                    color: orange,
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 12),
                            Opacity(
                              opacity: _brandFade.value.clamp(0.0, 1.0),
                              child: Text(
                                app.brand.identity['tagline_ar'] ??
                                    'تطبيق مندوب التوصيل',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: app.brand.white.withValues(alpha: 0.7),
                                  fontSize: 14,
                                ),
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _bar(double width, double opacity, Color color) {
    return Container(
      width: width * _lines.value.clamp(0.0, 1.0),
      height: 5,
      decoration: BoxDecoration(
        color: color.withValues(alpha: opacity),
        borderRadius: BorderRadius.circular(3),
      ),
    );
  }
}
