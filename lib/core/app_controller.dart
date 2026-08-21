import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'config.dart';
import 'json_util.dart';
import 'panel_api.dart';

class AppController extends ChangeNotifier {
  late SharedPreferences _prefs;
  late PanelApi api;

  String apiUrl = AppConfig.defaultApiUrl;
  String? token;
  Map<String, dynamic>? user;
  Map<String, dynamic> dashboard = {};
  Map<String, dynamic> settings = {};
  bool bootstrapped = false;
  bool isOnline = false;
  Map<String, dynamic>? incomingOrder;
  final Set<String> _seenOrderIds = {};
  Timer? _pollTimer;

  bool get isLoggedIn => token != null && token!.isNotEmpty;
  Map<String, dynamic> get boy =>
      J.map(user?['delivery_boy'] ?? user?['deliveryBoy']);
  int get boyStatus => J.i(boy['status'], 1);
  Color get brand => const Color(AppConfig.brand);
  Color get navy => const Color(AppConfig.navy);
  String get name =>
      J.str(boy['name'] ?? user?['username'] ?? user?['name'], 'الموصل');
  String get balance => J.str(dashboard['balance'] ?? boy['balance'], '0');
  dynamic get boyId => boy['id'] ?? user?['delivery_boy_id'];
  dynamic get adminId => boy['admin_id'] ?? user?['id'];

  Future<void> bootstrap() async {
    _prefs = await SharedPreferences.getInstance();
    apiUrl = AppConfig.defaultApiUrl;
    await _prefs.setString('api_url', apiUrl);
    token = _prefs.getString('token');
    isOnline = _prefs.getBool('is_online') ?? false;
    final stored = _prefs.getString('user_json');
    if (stored != null) {
      try {
        user = J.map(jsonDecode(stored));
      } catch (_) {}
    }
    api = PanelApi(baseUrl: apiUrl, token: token);
    api.onUnauthorized = () {
      if (isLoggedIn) logout();
    };
    if (isLoggedIn) {
      try {
        await refreshSession();
      } catch (_) {}
    }
    bootstrapped = true;
    notifyListeners();
  }

  Future<String?> login(String email, String password) async {
    final result = await api.login(email.trim(), password);
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
    await _prefs.setString('token', token ?? '');
    await _prefs.setString('user_json', jsonEncode(user));
    await refreshSession();
    if (isOnline) startOrderPolling();
    notifyListeners();
    return null;
  }

  Future<void> refreshSession() async {
    final set = await api.settings();
    if (set.ok) settings = set.dataMap;
    await refreshDashboard();
  }

  Future<void> logout() async {
    stopOrderPolling();
    token = null;
    user = null;
    dashboard = {};
    settings = {};
    incomingOrder = null;
    _seenOrderIds.clear();
    api.setToken(null);
    await _prefs.remove('token');
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
    }
    notifyListeners();
  }

  void dismissIncomingOrder() {
    if (incomingOrder != null) {
      final id = '${incomingOrder!['order_id'] ?? incomingOrder!['id']}';
      _seenOrderIds.add(id);
    }
    incomingOrder = null;
    notifyListeners();
  }

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
      final result = await api.orders(type: 1, limit: 10);
      final items = result.list('orders').isNotEmpty
          ? result.list('orders')
          : result.dataMaps;
      for (final order in items) {
        final id = '${order['order_id'] ?? order['id']}';
        if (id.isNotEmpty && !_seenOrderIds.contains(id)) {
          incomingOrder = order;
          notifyListeners();
          return;
        }
      }
    } catch (_) {}
  }

  Future<void> setApiUrl(String url) async {
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
    notifyListeners();
  }
}

final app = AppController();
