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
  await PushService.preInit();
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
    app
        .bootstrap()
        .then((_) {
          if (!mounted) return;
          final r = buildRouter();
          // يربط ضغطات الإشعارات بالتنقل (يفتح الطلب أو قائمة الجارية)
          PushService.attachRouter(r);
          setState(() => router = r);
        })
        .catchError((_) {
          if (!mounted) return;
          final r = buildRouter();
          PushService.attachRouter(r);
          setState(() => router = r);
        });
  }

  @override
  Widget build(BuildContext context) {
    if (router == null) {
      return const MaterialApp(
        debugShowCheckedModeBanner: false,
        home: BrandedSplash(),
      );
    }
    return DeliveryApp(router: router!);
  }
}
