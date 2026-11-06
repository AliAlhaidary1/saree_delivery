import 'package:firebase_core/firebase_core.dart';

/// إعدادات Firebase لمشروع saree-market.
///
/// القيم المعبأة مشروع-عامة من إعدادات السيرفر:
/// projectId = saree-market ، messagingSenderId = 615854672127.
///
/// تطبيق Android مسجل للحزمة com.sreamart.sreamart_delivery، والتهيئة
/// برمجية ولا تعتمد على google-services.json.
class FirebaseConfig {
  /// مفتاح الويب من إعدادات السيرفر — يُستخدم لتهيئة العميل.
  static const String apiKey = 'AIzaSyCk-izCfnQbJvzteb2Uw8twDAylfe0m2JI';

  /// Web appId (للباكند/الويب — لا يعمل على أندرويد).
  static const String appId = '1:615854672127:web:596f455d7a2b93c2b824ca';

  /// Android appId المسجل لتطبيق المندوب.
  static const String androidAppId = '1:615854672127:android:e046d1a56ca12e41b824ca';

  static const String messagingSenderId = '615854672127';
  static const String projectId = 'saree-market';
  static const String storageBucket = 'saree-market.firebasestorage.app';
  static const String authDomain = 'saree-market.firebaseapp.com';

  /// الـ appId الفعّال على أندرويد: الخاص بالأندرويد إن وُجد.
  static String get effectiveAppId =>
      androidAppId.isNotEmpty ? androidAppId : '';

  static bool get isConfigured =>
      apiKey.isNotEmpty &&
      effectiveAppId.isNotEmpty &&
      messagingSenderId.isNotEmpty &&
      projectId.isNotEmpty;

  static FirebaseOptions get options => FirebaseOptions(
        apiKey: apiKey,
        appId: effectiveAppId,
        messagingSenderId: messagingSenderId,
        projectId: projectId,
        storageBucket: storageBucket,
        authDomain: authDomain,
      );

  static Map<String, String> toCacheMap() => {
        'apiKey': apiKey,
        'appId': effectiveAppId,
        'messagingSenderId': messagingSenderId,
        'projectId': projectId,
        'storageBucket': storageBucket,
        'authDomain': authDomain,
      };
}
