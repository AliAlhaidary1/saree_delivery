import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'app.dart';
import 'core/app_controller.dart';
import 'core/push_service.dart';
import 'widgets/branded_splash.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // معالج الخلفية يُسجَّل قبل runApp ليستقبل النظام الرسائل والتطبيق مقتول.
  try {
    FirebaseMessaging.onBackgroundMessage(pushBackgroundHandler);
  } catch (_) {}
  // الإشعارات الفورية: تهيئة Firebase + قناة الإشعارات + معالج الخلفية.
  // آمنة دائماً — تعمل فقط بعد تعبئة FirebaseConfig من Firebase Console.
  try {
    await PushService.preInit().timeout(const Duration(seconds: 3));
  } catch (_) {}
  runApp(const Bootstrap());
}

class Bootstrap extends StatefulWidget {
  const Bootstrap({super.key});

  @override
  State<Bootstrap> createState() => _BootstrapState();
}

class _BootstrapState extends State<Bootstrap> {
  GoRouter? router;

  @override
  void initState() {
    super.initState();
    // مدة الأنيميشن المبسط (1400ms) — سريع بدون انتظار زائد
    final splashMin = Future<void>.delayed(const Duration(milliseconds: 1400));
    Future.wait([
      // حد أقصى للإقلاع حتى لا تعلق شاشة البداية عند تعذر الشبكة.
      app
          .bootstrap()
          .timeout(const Duration(seconds: 8))
          .catchError((_) {}),
      splashMin,
    ]).then((_) {
      if (!mounted) return;
      final r = buildRouter();
      // يربط ضغطات الإشعارات بالتنقل (يفتح الطلب أو قائمة الجارية)
      PushService.attachRouter(r);
      setState(() => router = r);
      // طلب إذن الإشعارات بعد ظهور التطبيق (وليس فوق شاشة البداية).
      Future<void>.delayed(const Duration(milliseconds: 900), () {
        if (app.isLoggedIn) {
          PushService.ensureFcm().catchError((_) => false);
        }
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    // انتقال واحد متلاشي: سبلاش -> تطبيق (بدون قفزة بين واجهتين)
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 400),
      transitionBuilder: (child, animation) => FadeTransition(
        opacity: animation,
        child: child,
      ),
      child: _child(),
    );
  }

  Widget _child() {
    if (router == null) {
      return const MaterialApp(
        key: ValueKey('splash'),
        debugShowCheckedModeBanner: false,
        home: BrandedSplash(),
      );
    }
    return DeliveryApp(key: const ValueKey('app'), router: router!);
  }
}
