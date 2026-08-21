import 'package:dio/dio.dart';

import 'config.dart';
import 'json_util.dart';

class PanelApi {
  PanelApi({required String baseUrl, String? token}) {
    _dio = Dio(
      BaseOptions(
        baseUrl: _normalize(baseUrl),
        connectTimeout: const Duration(seconds: 25),
        receiveTimeout: const Duration(seconds: 40),
        validateStatus: (code) => code != null && code < 500,
      ),
    );
    setToken(token);
  }

  late final Dio _dio;
  void Function()? onUnauthorized;

  static String _normalize(String url) {
    var root = url.trim();
    if (root.endsWith('/')) root = root.substring(0, root.length - 1);
    return '$root${AppConfig.apiSubUrl}/';
  }

  void setToken(String? token) {
    if (token != null && token.isNotEmpty) {
      _dio.options.headers['Authorization'] = 'Bearer $token';
    } else {
      _dio.options.headers.remove('Authorization');
    }
  }

  void setBaseUrl(String url) => _dio.options.baseUrl = _normalize(url);

  ApiResult _parse(Response response) {
    final data = response.data;
    if (data is Map) return ApiResult(J.map(data));
    return ApiResult({
      'status': 0,
      'message': 'invalid_response',
      'data': data,
    });
  }

  Future<ApiResult> _guard(Future<Response> Function() request) async {
    try {
      final response = await request();
      if (response.statusCode == 401) {
        onUnauthorized?.call();
        return ApiResult({
          'status': 0,
          'message': 'انتهت الجلسة. سجّل الدخول مجدداً.',
        });
      }
      return _parse(response);
    } on DioException catch (error) {
      final offline =
          error.type == DioExceptionType.connectionTimeout ||
          error.type == DioExceptionType.sendTimeout ||
          error.type == DioExceptionType.receiveTimeout ||
          error.type == DioExceptionType.connectionError;
      return ApiResult({
        'status': 0,
        'message': offline
            ? 'تعذر الاتصال بالخادم. تحقق من الإنترنت.'
            : (error.message ?? 'حدث خطأ ما'),
      });
    } catch (error) {
      return ApiResult({'status': 0, 'message': '$error'});
    }
  }

  Future<ApiResult> get(String path, [Map<String, dynamic>? query]) {
    return _guard(() => _dio.get(path, queryParameters: query));
  }

  Future<ApiResult> post(String path, [Map<String, dynamic>? body]) {
    return _guard(() => _dio.post(path, data: body ?? {}));
  }

  Future<ApiResult> postForm(String path, FormData data) {
    return _guard(() => _dio.post(path, data: data));
  }

  Future<ApiResult> login(String email, String password) {
    return post('login', {
      'email': email,
      'password': password,
      'type': AppConfig.loginType,
      'platform': 'android',
    });
  }

  Future<ApiResult> dashboard() => get('delivery_boy/dashboard');
  Future<ApiResult> orders({
    int limit = 40,
    int offset = 0,
    int? statusId,
    int? type,
  }) {
    return get('delivery_boy/orders', {
      'limit': limit,
      'offset': offset,
      if (statusId != null && statusId > 0) 'status': statusId,
      if (type != null) 'type': type,
    });
  }

  Future<ApiResult> orderById(dynamic id) =>
      get('delivery_boy/order_by_id', {'id': id, 'order_id': id});
  Future<ApiResult> orderStatuses() => get('delivery_boy/order_statuses');
  Future<ApiResult> updateStatus({
    required dynamic orderId,
    required dynamic statusId,
    dynamic deliveryBoyId,
  }) {
    return post('delivery_boy/update_status', {
      'order_id': orderId,
      'status_id': statusId,
      if (deliveryBoyId != null) 'delivery_boy_id': deliveryBoyId,
    });
  }

  Future<ApiResult> cashCollection({
    String startDate = '',
    String endDate = '',
  }) {
    return get('delivery_boy/cash_collection', {
      if (startDate.isNotEmpty) 'startDate': startDate,
      if (endDate.isNotEmpty) 'endDate': endDate,
    });
  }

  Future<ApiResult> fundTransfers() => get('delivery_boy/fund_transfers');
  Future<ApiResult> withdrawals() =>
      get('delivery_boy/withdrawal_requests/get');
  Future<ApiResult> addWithdrawal({
    required String amount,
    String message = '',
  }) {
    return post('delivery_boy/withdrawal_requests/add', {
      'amount': amount,
      'message': message,
      'type': 'delivery_boy',
      'device_type': 'android',
    });
  }

  Future<ApiResult> salesReports({
    required String startDate,
    required String endDate,
  }) {
    return get('delivery_boy/sales_reports', {
      'startDate': startDate,
      'endDate': endDate,
    });
  }

  Future<ApiResult> productSalesReports({
    required String startDate,
    required String endDate,
  }) {
    return get('delivery_boy/product_sales_reports', {
      'startDate': startDate,
      'endDate': endDate,
    });
  }

  Future<ApiResult> forgotPasswordOtp(String mobile) {
    return post('forget-password-otp', {
      'mobile': mobile,
      'country_code': AppConfig.countryDialCode,
      'type': AppConfig.loginType,
    });
  }

  Future<ApiResult> resetPasswordOtp({
    required String mobile,
    required String otp,
    required String password,
    required String passwordConfirmation,
  }) {
    return post('reset-password-otp', {
      'mobile': mobile,
      'country_code': AppConfig.countryDialCode,
      'otp': otp,
      'password': password,
      'password_confirmation': passwordConfirmation,
      'type': AppConfig.loginType,
    });
  }

  Future<ApiResult> settings() => get('delivery_boy/settings');
  Future<ApiResult> privacyPolicy() => post('delivery_boy/privacy_policy');
  Future<ApiResult> mailSettings() => get('delivery_boy/mail_settings');
  Future<ApiResult> saveMailSettings(Map<String, dynamic> body) =>
      post('delivery_boy/mail_settings/save', body);
  Future<ApiResult> deleteAccount() =>
      get('delivery_boy/delete_delivery_boy_account');
  Future<ApiResult> cities() => get('delivery_boy/cities');
  Future<ApiResult> updateProfile(FormData data) =>
      postForm('delivery_boys/update', data);
}
