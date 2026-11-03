import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'config.dart';
import 'brand_config.dart';
import 'brand_service.dart';
import 'json_util.dart';
import 'panel_api.dart';
import 'push_service.dart';
import 'models/assignment.dart';
import 'token_vault.dart';

class AppController extends ChangeNotifier {
  late SharedPreferences _prefs;
  late PanelApi api;
  late TokenVault _tokenVault;

  String apiUrl = AppConfig.defaultApiUrl;
  String? token;
  Map<String, dynamic>? user;
  Map<String, dynamic> dashboard = {};
  bool dashboardLoaded = false;
  Map<String, dynamic> settings = {};
  bool bootstrapped = false;
  bool isOnline = false;
  Map<String, dynamic>? incomingOrder; // legacy alias
  Map<String, dynamic>? incomingAssignment;
  Map<String, dynamic> workload = {};
  Map<String, dynamic> diagnostics = {};
  Map<String, dynamic> availableOrdersMeta = {};
  WorkloadInfo workloadInfo = WorkloadInfo.empty();
  final Set<String> _seenOrderIds = {};
  final Set<String> _seenAssignmentIds = {};
  Timer? _pollTimer;
  BrandConfig brand = BrandConfig.defaults;

  bool get isLoggedIn => token != null && token!.isNotEmpty;

  // جولة التلميحات — تُعرض مرة واحدة لكل جهاز.
  bool get appTutorialCompleted =>
      _prefs.getBool('first_run_tutorial_v1') ?? false;

  Future<void> completeAppTutorial() =>
      _prefs.setBool('first_run_tutorial_v1', true);

  Map<String, dynamic> get boy =>
      J.map(user?['delivery_boy'] ?? user?['deliveryBoy']);
  int get boyStatus => J.i(boy['status'], 1);
  Color get brandColor => brand.orange;
  Color get navyColor => brand.navy;
  String get name =>
      J.str(boy['name'] ?? user?['username'] ?? user?['name'], 'الموصل');
  String get balance => J.str(dashboard['balance'] ?? boy['balance'], '0');
  dynamic get boyId => boy['id'] ?? user?['delivery_boy_id'];
  dynamic get adminId => boy['admin_id'] ?? user?['id'];

  Future<void> bootstrap() async {
    _prefs = await SharedPreferences.getInstance();
    // لا تمسح عنوان الخادم المخصص في وضع التطوير — اقرأ المخزن أولاً
    _tokenVault = TokenVault(_prefs);
    final storedUrl = _prefs.getString('api_url');
    apiUrl = !kReleaseMode && storedUrl != null && storedUrl.trim().isNotEmpty
        ? storedUrl
        : AppConfig.defaultApiUrl;
    await _prefs.setString('api_url', apiUrl);
    try {
      token = await _tokenVault.read();
    } catch (_) {
      token = null;
    }
    isOnline = _prefs.getBool('is_online') ?? false;
    final stored = _prefs.getString('user_json');
    if (stored != null) {
      try {
        user = J.map(jsonDecode(stored));
      } catch (_) {}
    }
    api = PanelApi(baseUrl: apiUrl, token: token);
    api.onUnauthorized = () {
      if (isLoggedIn) logout(revokeRemote: false);
    };
    try {
      brand = await BrandService().load(apiUrl);
    } catch (_) {}
    if (isLoggedIn) {
      try {
        await refreshSession();
      } catch (_) {}
      // تفعيل FCM (قد تتوفر الشبكة الآن) ثم رفع توكن الدفع المخزّن
      // (يغطي حالة تجدده أثناء الخروج) — يصل حتى والتطبيق مغلق.
      try {
        await PushService.ensureFcm();
      } catch (_) {}
      // رفع توكن الدفع المخزّن (يغطي حالة تجدده أثناء الخروج).
      PushService.onTokenChanged = _uploadPushToken;
      try {
        await _uploadPushToken(await PushService.getStoredToken());
      } catch (_) {}
      // لوحة Vue تعمل دائماً بعد الدخول — نفعّل الاستقبال
      if (!isOnline) {
        await setOnline(true);
      } else {
        startOrderPolling();
      }
    }
    bootstrapped = true;
    notifyListeners();
  }

  /// يرفع توكن FCM للسيرفر ليستمر وصول الإشعارات للجهاز والتطبيق مغلق.
  /// المسار الأساسي delivery_boy/save_fcm_token (UserToken type=Delivery Boy —
  /// الذي يقرأ منه مرسل إشعار الإسناد)، مع fallback للمسار القديم.
  Future<void> _uploadPushToken(String? token) async {
    if (token == null || token.isEmpty || !isLoggedIn) return;
    try {
      final r = await api.saveDeliveryFcmToken(token);
      if (!r.ok) await api.saveFcmToken(token);
    } catch (_) {
      try {
        await api.saveFcmToken(token);
      } catch (_) {}
    }
  }

  Future<String?> login(String email, String password) async {
    // رمز الإشعارات الفورية — يُخزّن في السيرفر ليصل الإسناد حتى والتطبيق مغلق
    String? fcmToken;
    try {
      fcmToken = await PushService.getStoredToken();
    } catch (_) {}
    final result = await api.login(email.trim(), password, fcmToken: fcmToken);
    if (!result.ok) {
      return result.message.isEmpty
          ? 'بيانات الدخول غير صحيحة'
          : result.message;
    }
    token = result.token;
    if (token == null || token!.isEmpty) {
      return 'تعذر إكمال تسجيل الدخول';
    }
    user = result.user.isNotEmpty ? result.user : result.dataMap;
    api.setToken(token);
    try {
      await _tokenVault.write(token!);
    } catch (_) {
      token = null;
      user = null;
      api.setToken(null);
      return 'تعذر حفظ الجلسة بأمان على الجهاز';
    }
    await _prefs.setString('user_json', jsonEncode(user));
    // الرفع الفوري + عند أي تجدد لاحق — يضمن وصول الإشعارات والتطبيق مغلق.
    PushService.onTokenChanged = _uploadPushToken;
    try {
      await PushService.ensureFcm();
    } catch (_) {}
    await refreshSession();
    try {
      await _uploadPushToken(await PushService.getStoredToken());
    } catch (_) {}
    // لوحة الموصل في Vue تعمل دائماً بعد الدخول — نفعّل الاستقبال افتراضياً
    if (!isOnline) {
      await setOnline(true);
    } else {
      startOrderPolling();
    }
    notifyListeners();
    return null;
  }

  Future<void> refreshSession() async {
    final set = await api.settings();
    if (set.ok) settings = set.dataMap;
    await refreshDashboard();
  }

  Future<void> logout({bool revokeRemote = true}) async {
    if (revokeRemote && token != null) {
      try {
        await api.logout();
      } catch (_) {}
    }
    stopOrderPolling();
    token = null;
    user = null;
    dashboard = {};
    dashboardLoaded = false;
    settings = {};
    workload = {};
    diagnostics = {};
    availableOrdersMeta = {};
    workloadInfo = WorkloadInfo.empty();
    incomingOrder = null;
    incomingAssignment = null;
    _seenOrderIds.clear();
    _seenAssignmentIds.clear();
    api.setToken(null);
    await _tokenVault.clear();
    await _prefs.remove('user_json');
    notifyListeners();
  }

  Future<void> setOnline(bool value) async {
    isOnline = value;
    await _prefs.setBool('is_online', value);
    if (value) {
      startOrderPolling();
    } else {
      stopOrderPolling();
      incomingOrder = null;
      incomingAssignment = null;
    }
    notifyListeners();
  }

  void dismissIncomingOrder() {
    if (incomingAssignment != null) {
      final id = '${incomingAssignment!['id']}';
      _seenAssignmentIds.add(id);
    } else if (incomingOrder != null) {
      final id = '${incomingOrder!['order_id'] ?? incomingOrder!['id']}';
      _seenOrderIds.add(id);
    }
    incomingOrder = null;
    incomingAssignment = null;
    notifyListeners();
  }

  void dismissIncomingAssignment() => dismissIncomingOrder();

  void startOrderPolling() {
    stopOrderPolling();
    if (!isOnline || !isLoggedIn) return;
    _pollTimer = Timer.periodic(const Duration(seconds: 20), (_) {
      _checkForNewOrders();
    });
    _checkForNewOrders();
  }

  void stopOrderPolling() {
    _pollTimer?.cancel();
    _pollTimer = null;
  }

  Future<void> _checkForNewOrders() async {
    if (!isOnline || !isLoggedIn) return;
    try {
      // Modern: polling assignments with status == assigned (DispatchService)
      final result = await api.assignments(page: 1);
      List<Map<String, dynamic>> items = [];
      // paginator handling
      if (result.dataMap.containsKey('data') &&
          result.dataMap['data'] is List) {
        items = J.maps(result.dataMap['data']);
      } else if (result.list('data').isNotEmpty) {
        items = result.list('data');
      } else {
        items = result.dataMaps;
      }
      // filter assigned only
      final assigned = items.where((m) {
        final st = J.str(m['status']).toLowerCase();
        return st == 'assigned';
      }).toList();
      // fallback legacy if modern empty
      if (assigned.isEmpty) {
        // try legacy orders as fallback
        try {
          final legacy = await api.orders(type: 1, limit: 10);
          final legacyItems = legacy.list('orders').isNotEmpty
              ? legacy.list('orders')
              : legacy.dataMaps;
          for (final order in legacyItems) {
            final id = '${order['order_id'] ?? order['id']}';
            if (id.isNotEmpty && !_seenOrderIds.contains(id)) {
              incomingOrder = order;
              incomingAssignment = null;
              notifyListeners();
              return;
            }
          }
        } catch (_) {}
        return;
      }
      for (final a in assigned) {
        final id = '${a['id']}';
        if (id.isNotEmpty && !_seenAssignmentIds.contains(id)) {
          incomingAssignment = a;
          incomingOrder = a; // alias for legacy overlay
          notifyListeners();
          return;
        }
      }
      // also refresh workload for badge
      await refreshWorkload();
    } catch (_) {}
  }

  Future<void> refreshWorkload() async {
    try {
      final result = await api.workload();
      if (result.ok) {
        workload = result.dataMap;
        workloadInfo = WorkloadInfo.fromMap(workload);
        notifyListeners();
      }
    } catch (_) {}
    // diagnostics يحمل claim_setting_on الحقيقي (workload لا يحتويه في الباك اند)
    try {
      final d = await api.diagnostics();
      if (d.ok) {
        diagnostics = d.dataMap;
        notifyListeners();
      }
    } catch (_) {}
  }

  /// Admin switch courier_can_claim_orders.
  /// المصادر بالترتيب (طبق الأصل الباك اند):
  /// 1) available-orders.can_claim_enabled 2) diagnostics.claim_setting_on 3) settings.courier_can_claim_orders
  bool get canClaimOrders {
    final v =
        availableOrdersMeta['can_claim_enabled'] ??
        diagnostics['claim_setting_on'] ??
        settings['courier_can_claim_orders'];
    return v == true || v == 1 || v == '1';
  }

  /// هل يستقبل عمل حالياً (isAcceptingWork): is_available != 0 && remainingCapacity > 0
  bool get isAcceptingWork {
    final avail = J.i(diagnostics['is_available'], J.i(boy['is_available'], 1));
    if (avail == 0) return false;
    return workloadInfo.remainingCapacity > 0;
  }

  /// Platform open/closed from admin store settings (informational for couriers).
  bool get platformOpen {
    String o = '${settings['platform_opening_time'] ?? ''}';
    String c = '${settings['platform_closing_time'] ?? ''}';
    if (o.isEmpty && c.isEmpty) return true;
    if (o.isEmpty || c.isEmpty) return true;
    if (o == c) return false;
    int toMin(String t) {
      final p = t.split(':');
      if (p.length < 2) return -1;
      final h = int.tryParse(p[0]) ?? -1;
      final m = int.tryParse(p[1]) ?? -1;
      if (h < 0 || h > 23 || m < 0 || m > 59) return -1;
      return h * 60 + m;
    }

    final om = toMin(o);
    final cm = toMin(c);
    if (om < 0 || cm < 0) return true;
    final now = DateTime.now();
    final cur = now.hour * 60 + now.minute;
    if (om < cm) return cur >= om && cur < cm;
    return cur >= om || cur < cm;
  }

  Future<void> setApiUrl(String url) async {
    if (kReleaseMode) return;
    final value = url.trim();
    apiUrl = value.isEmpty ? AppConfig.defaultApiUrl : value;
    await _prefs.setString('api_url', apiUrl);
    api.setBaseUrl(apiUrl);
    notifyListeners();
  }

  Future<void> persistUser() async {
    if (user != null) {
      await _prefs.setString('user_json', jsonEncode(user));
    }
    notifyListeners();
  }

  Future<void> refreshDashboard() async {
    final result = await api.dashboard();
    if (result.ok) dashboard = result.dataMap;
    dashboardLoaded = true;
    // also refresh workload to get capacity/codLiability like seller workload
    await refreshWorkload();
    notifyListeners();
  }
}

final app = AppController();
