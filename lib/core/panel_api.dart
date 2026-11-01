import 'package:dio/dio.dart';

import 'config.dart';
import 'json_util.dart';
import 'api_errors.dart';

class PanelApi {
  PanelApi({required String baseUrl, String? token}) {
    _dio = Dio(
      BaseOptions(
        baseUrl: _normalize(baseUrl),
        connectTimeout: const Duration(seconds: 25),
        receiveTimeout: const Duration(seconds: 40),
        headers: const {'Accept': 'application/json', 'platform': 'android'},
        validateStatus: (code) => code != null && code < 600,
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

  Future<ApiResult> _guard(
    Future<Response> Function() request, {
    String path = '',
  }) async {
    final release = ApiErrorPolicy.current.release;
    final kind = inferRequestKind(path);
    var attempt = 0;
    while (true) {
      try {
        final response = await request();
        if (response.statusCode == 401) {
          onUnauthorized?.call();
        }
        if (response.statusCode == 401 ||
            (response.statusCode != null && response.statusCode! >= 500) ||
            looksLikeLaravelException(response.data)) {
          final classified = classifyDio(
            DioException(
              requestOptions: response.requestOptions,
              response: response,
              type: DioExceptionType.badResponse,
            ),
            release: release,
          );
          logApiFailure(classified, path: path);
          return ApiResult(classified.toResultMap());
        }
        return _parse(response);
      } on DioException catch (error) {
        final classified = classifyDio(error, release: release);
        logApiFailure(classified, path: path);
        if (shouldRetryApi(
          error: classified,
          attempt: attempt,
          kind: kind,
          release: release,
        )) {
          attempt += 1;
          await Future<void>.delayed(const Duration(milliseconds: 250));
          continue;
        }
        return ApiResult(classified.toResultMap());
      } catch (error) {
        final classified = classifyUnknown(error, release: release);
        logApiFailure(classified, path: path);
        return ApiResult(classified.toResultMap());
      }
    }
  }

  Future<ApiResult> get(String path, [Map<String, dynamic>? query]) {
    return _guard(() => _dio.get(path, queryParameters: query), path: path);
  }

  Future<ApiResult> post(String path, [Map<String, dynamic>? body]) {
    return _guard(() => _dio.post(path, data: body ?? {}), path: path);
  }

  Future<ApiResult> postForm(String path, FormData data) {
    return _guard(() => _dio.post(path, data: data), path: path);
  }

  Future<ApiResult> logout() => post('logout');

  Future<ApiResult> delete(String path, [Map<String, dynamic>? query]) {
    return _guard(() => _dio.delete(path, queryParameters: query), path: path);
  }

  // الباك اند (AdminAuth@login) يخزّن fcm_token في UserToken{type: Delivery Boy}
  // ليصل إشعار الإسناد للجهاز حتى والتطبيق مغلق.
  Future<ApiResult> login(String email, String password, {String? fcmToken}) {
    return post('login', {
      'email': email,
      'password': password,
      'type': AppConfig.loginType,
      'platform': 'android',
      if (fcmToken != null && fcmToken.isNotEmpty) 'fcm_token': fcmToken,
    });
  }

  Future<ApiResult> dashboard() => get('delivery_boy/dashboard');

  // تحديث توكن الدفع بعد تجدده أو عند الإقلاع.
  // المسار الأساسي delivery_boy/save_fcm_token يخزّن في UserToken{type:Delivery Boy}
  // (الذي يقرأ منه الباكند عند إشعار الإسناد) — والقديم احتياطي.
  Future<ApiResult> saveFcmToken(String token) =>
      post('save_fcm_token', {'token': token});

  Future<ApiResult> saveDeliveryFcmToken(String token) => post(
    'delivery_boy/save_fcm_token',
    {'token': token, 'fcm_token': token, 'platform': 'android'},
  );

  // ========= Modern Assignment APIs - طبق الأصل من DeliveryBoyAssignmentApiController =========
  // Backend: listAssignments تدعم status/startDate/endDate/search/page (paginate 20)
  Future<ApiResult> assignments({
    int page = 1,
    String? status,
    String? startDate,
    String? endDate,
    String? search,
  }) {
    return get('delivery_boy/assignments', {
      'page': page,
      if (status != null && status.isNotEmpty) 'status': status,
      if (startDate != null && startDate.isNotEmpty) 'startDate': startDate,
      if (endDate != null && endDate.isNotEmpty) 'endDate': endDate,
      if (search != null && search.isNotEmpty) 'search': search,
    });
  }

  Future<ApiResult> assignmentById(dynamic id) =>
      get('delivery_boy/assignments/$id');
  Future<ApiResult> acceptAssignment(dynamic id) =>
      post('delivery_boy/assignments/$id/accept');
  Future<ApiResult> updateAssignmentStatus({
    required dynamic id,
    required String status,
    String? failureReason,
    num? codCollected,
  }) {
    return post('delivery_boy/assignments/$id/status', {
      'status': status,
      if (failureReason != null && failureReason.trim().isNotEmpty)
        'failure_reason': failureReason.trim(),
      if (codCollected != null) 'cod_collected': codCollected,
    });
  }

  Future<ApiResult> returnRejectedBySeller({
    required dynamic id,
    required String reason,
  }) => post('delivery_boy/assignments/$id/return-rejected', {
    'reason': reason.trim(),
  });

  // Backend workload(): active_assignment_count/max_capacity/remaining_capacity/assignments/cod_liability
  // ملاحظة: لا يحتوي claim_setting_on — مصدرها settings + diagnostics + available-orders
  Future<ApiResult> workload() => get('delivery_boy/workload');

  // Backend diagnostics(): courier_id/name/status/is_available/max_capacity/
  // remaining_capacity/my_assignments_by_status/my_assignments_total/claim_setting_on/claimable_groups
  Future<ApiResult> diagnostics() => get('delivery_boy/diagnostics');

  // Unassigned pool: visible only when admin enables courier_can_claim_orders.
  // Backend returns claim_setting_on inside workload; claim itself is guarded server-side too.
  // sort: oldest (default, FIFO) | newest
  Future<ApiResult> availableOrders({String sort = 'oldest'}) =>
      get('delivery_boy/available-orders', {'sort': sort});
  Future<ApiResult> claimAvailableOrder(dynamic id) =>
      post('delivery_boy/available-orders/$id/claim');

  // ========= Legacy - يبقى للتوافق فقط =========
  /// طبق الأصل DeliveryBoyController::getOrders:
  /// limit/offset/status/type/startDate/endDate/startDeliveryDate/endDeliveryDate
  Future<ApiResult> orders({
    int limit = 40,
    int offset = 0,
    int? statusId,
    int? type,
    String? startDate,
    String? endDate,
    String? startDeliveryDate,
    String? endDeliveryDate,
  }) {
    return get('delivery_boy/orders', {
      'limit': limit,
      'offset': offset,
      if (statusId != null && statusId > 0) 'status': statusId,
      if (type != null) 'type': type,
      if (startDate != null && startDate.isNotEmpty) 'startDate': startDate,
      if (endDate != null && endDate.isNotEmpty) 'endDate': endDate,
      if (startDeliveryDate != null && startDeliveryDate.isNotEmpty)
        'startDeliveryDate': startDeliveryDate,
      if (endDeliveryDate != null && endDeliveryDate.isNotEmpty)
        'endDeliveryDate': endDeliveryDate,
    });
  }

  /// الرصيد المتاح بعد خصم المعلق — Backend WithdrawalRequestsApiController::getBalance
  /// (عام auth: withdrawal_requests/get_balance — يعمل للموصل role_id=4)
  Future<ApiResult> withdrawalBalance() =>
      get('withdrawal_requests/get_balance');

  /// مدينة واحدة — Backend delivery_boy/city (BasicApiController::getCity)
  Future<ApiResult> city() => get('delivery_boy/city');

  /// فاتورة الطلب — Backend OrdersApiController@generateOrderInvoice/downloadOrderInvoice
  /// تُستخدم من تفاصيل الطلب لعرض/تحميل الفاتورة بنفس بيانات السيرفر.
  Future<ApiResult> orderInvoice(dynamic id) =>
      get('orders/invoice', {'order_id': id, 'id': id});
  Future<ApiResult> orderInvoiceDownload(dynamic id) =>
      post('orders/invoice_download', {'order_id': '$id', 'id': '$id'});

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

  // ===== Courier Collection (Home.vue / Orders.vue / MyOrder.vue / Wallet.vue) =====
  // Home.vue: GET collection/home -> {todays_deliveries, cash_to_collect, amount_to_return, your_earnings}
  Future<ApiResult> collectionHome() => get('delivery_boy/collection/home');
  // Orders.vue: GET collection/orders?tab=new|in_delivery|completed&sort=oldest|newest -> {tab, orders[]}
  // order = {id,status,assignment_type,is_return_pickup,customer,area,seller_count,
  // payment_method,amount_to_collect,checkout_group_id,order_item_id,return_product,...}
  // akhdimni rows: {source:'akhdimni', akhdimni_order_id, status, ...}
  Future<ApiResult> collectionOrders({
    String tab = 'new',
    String sort = 'oldest',
  }) => get('delivery_boy/collection/orders', {'tab': tab, 'sort': sort});

  // ===== Akhdimni (اخدمني) courier tasks — طبق الأصل DeliveryBoyAkhdimniPurchaseController =====
  // sort: oldest (default, FIFO) | newest
  // item = {id,name,quantity,unit_price,total,store_name,seller?,image_url?,notes?}
  Future<ApiResult> akhOrders({String sort = 'oldest'}) =>
      get('delivery_boy/akhdimni/orders', {'sort': sort});
  Future<ApiResult> akhOrder(dynamic id) =>
      get('delivery_boy/akhdimni/orders/$id');
  Future<ApiResult> akhSearchSellers(String q) =>
      get('delivery_boy/akhdimni/sellers/search', {'q': q});
  // Add item: name* + unit_price* (+quantity, seller_id?, store_name?, notes?, image?)
  // Duplicate names rejected server-side (804 shows message).
  Future<ApiResult> akhAddItem({
    required dynamic id,
    required String name,
    required num unitPrice,
    num quantity = 1,
    dynamic sellerId,
    String? storeName,
    String? notes,
    MultipartFile? image,
  }) {
    if (image == null) {
      return post('delivery_boy/akhdimni/orders/$id/items', {
        'name': name,
        'quantity': quantity,
        'unit_price': unitPrice,
        if (sellerId != null) 'seller_id': sellerId,
        if (storeName != null && storeName.trim().isNotEmpty)
          'store_name': storeName.trim(),
        if (notes != null && notes.trim().isNotEmpty) 'notes': notes.trim(),
      });
    }
    return postForm(
      'delivery_boy/akhdimni/orders/$id/items',
      FormData.fromMap({
        'name': name,
        'quantity': quantity,
        'unit_price': unitPrice,
        if (sellerId != null) 'seller_id': sellerId,
        if (storeName != null && storeName.trim().isNotEmpty)
          'store_name': storeName.trim(),
        if (notes != null && notes.trim().isNotEmpty) 'notes': notes.trim(),
        'image': image,
      }),
    );
  }

  // Update item: any of name/quantity/unit_price/seller_id/store_name/notes (+image)
  Future<ApiResult> akhUpdateItem({
    required dynamic id,
    required dynamic itemId,
    String? name,
    num? quantity,
    num? unitPrice,
    dynamic sellerId,
    String? storeName,
    String? notes,
    MultipartFile? image,
  }) {
    if (image == null) {
      return post('delivery_boy/akhdimni/orders/$id/items/$itemId', {
        if (name != null) 'name': name,
        if (quantity != null) 'quantity': quantity,
        if (unitPrice != null) 'unit_price': unitPrice,
        if (sellerId != null) 'seller_id': sellerId,
        if (storeName != null) 'store_name': storeName,
        if (notes != null) 'notes': notes,
      });
    }
    return postForm(
      'delivery_boy/akhdimni/orders/$id/items/$itemId',
      FormData.fromMap({
        if (name != null) 'name': name,
        if (quantity != null) 'quantity': quantity,
        if (unitPrice != null) 'unit_price': unitPrice,
        if (sellerId != null) 'seller_id': sellerId,
        if (storeName != null) 'store_name': storeName,
        if (notes != null) 'notes': notes,
        'image': image,
      }),
    );
  }

  Future<ApiResult> akhDeleteItem({
    required dynamic id,
    required dynamic itemId,
  }) => delete('delivery_boy/akhdimni/orders/$id/items/$itemId');

  // Smart split: turns customer free text into ready draft items (price 0).
  Future<ApiResult> akhAutoSplit({required dynamic id, String? text}) => post(
    'delivery_boy/akhdimni/orders/$id/auto-split',
    {if (text != null && text.isNotEmpty) 'text': text},
  );

  // Manual total fallback (only when no priced items exist server-side).
  Future<ApiResult> akhRecordPurchase({
    required dynamic id,
    required num purchaseAmount,
  }) => post('delivery_boy/akhdimni/orders/$id/record-purchase', {
    'purchase_amount': purchaseAmount,
  });

  Future<ApiResult> akhUploadReceipt({
    required dynamic id,
    required MultipartFile receipt,
  }) => postForm(
    'delivery_boy/akhdimni/orders/$id/upload-receipt',
    FormData.fromMap({'receipt': receipt}),
  );

  // status: picked_up | out_for_delivery | delivered | cancelled (+note?)
  Future<ApiResult> akhUpdateStatus({
    required dynamic id,
    required String status,
    String? note,
  }) => post('delivery_boy/akhdimni/orders/$id/update-status', {
    'status': status,
    if (note != null && note.trim().isNotEmpty) 'note': note.trim(),
  });
  // MyOrder.vue: GET collection/orders/{id} -> {assignment, customer, sellers[],
  // pickup_checklist, collection, courier_money, settlement_preview, seller_cash_guard,
  // amount_to_collect, cod_to_collect, cod_collected, cash_variance_tolerance, ...}
  Future<ApiResult> collectionOrderShow(dynamic id) =>
      get('delivery_boy/collection/orders/$id');
  // MyOrder.vue confirmPaid: POST collection/orders/{id}/confirm-paid
  // {cash_received, collection_method: cash|transfer, proof_path?, note?, idempotency_key?}
  Future<ApiResult> collectionConfirmPaid({
    required dynamic id,
    required num cashReceived,
    String collectionMethod = 'cash',
    String? proofPath,
    String? note,
    String? idempotencyKey,
  }) {
    return post('delivery_boy/collection/orders/$id/confirm-paid', {
      'cash_received': cashReceived,
      'collection_method': collectionMethod,
      if (proofPath != null && proofPath.isNotEmpty) 'proof_path': proofPath,
      if (note != null && note.isNotEmpty) 'note': note,
      if (idempotencyKey != null && idempotencyKey.isNotEmpty)
        'idempotency_key': idempotencyKey,
    });
  }

  // MyOrder.vue seller-cash: POST collection/orders/{id}/seller-cash
  // {seller_order_id, amount_handed, pay_method: cash|unpaid, note?, idempotency_key?}
  Future<ApiResult> collectionSellerCash({
    required dynamic id,
    required dynamic sellerOrderId,
    required num amountHanded,
    String payMethod = 'cash',
    String? note,
    String? idempotencyKey,
  }) {
    return post('delivery_boy/collection/orders/$id/seller-cash', {
      'seller_order_id': sellerOrderId,
      'amount_handed': amountHanded,
      'pay_method': payMethod,
      if (note != null && note.isNotEmpty) 'note': note,
      if (idempotencyKey != null && idempotencyKey.isNotEmpty)
        'idempotency_key': idempotencyKey,
    });
  }

  // Wallet.vue: GET collection/settlement ->
  // {cash_you_need_to_return, amount_owed_to_you, cash_currently_held, cod_collected,
  // cash_already_handed_over, approved_personal_payments, float_received, ...}
  Future<ApiResult> collectionSettlement() =>
      get('delivery_boy/collection/settlement');
  // Wallet.vue details: GET collection/settlement/details -> {entries[{date,type,amount,order,status}]}
  Future<ApiResult> collectionSettlementDetails() =>
      get('delivery_boy/collection/settlement/details');
  // Wallet.vue handover: POST collection/handover {amount, collection_method, receipt_image?, idempotency_key?}
  Future<ApiResult> collectionHandover({
    required num amount,
    required String idempotencyKey,
    String collectionMethod = 'cash',
    String? receiptImage,
  }) {
    return post('delivery_boy/collection/handover', {
      'amount': amount,
      'collection_method': collectionMethod,
      if (receiptImage != null && receiptImage.isNotEmpty)
        'receipt_image': receiptImage,
      'idempotency_key': idempotencyKey,
    });
  }

  // collection/account -> {name, phone, vehicle, account_status, average_rating,
  // rating_count, balance, city, zones[]}
  Future<ApiResult> collectionAccount() =>
      get('delivery_boy/collection/account');
  // liabilities for CashCollection.vue: GET finance/liabilities?open_only=1
  Future<ApiResult> financeLiabilities({bool openOnly = true}) => get(
    'delivery_boy/finance/liabilities',
    openOnly ? {'open_only': 1} : null,
  );
  // finance/pay-seller with receipt_image (CashCollection.vue declaration flow)
  Future<ApiResult> financePaySellerDeclare({
    required dynamic assignmentId,
    required num amount,
    String paidFrom = 'self',
    String? receiptImage,
  }) {
    return post('delivery_boy/finance/pay-seller', {
      'assignment_id': assignmentId,
      'amount': amount,
      'paid_from': paidFrom,
      if (receiptImage != null && receiptImage.isNotEmpty)
        'receipt_image': receiptImage,
    });
  }

  Future<ApiResult> fundTransfers() => get('delivery_boy/fund_transfers');

  /// الملخص المالي الموحد — Backend CourierFinanceApiController::summary
  /// يرجع {float_balance, cash_in_hand, earnings_balance, cod_liability,
  /// net_to_remit, pending_self_claim, over_cash_limit, ...}
  Future<ApiResult> financeSummary() => get('delivery_boy/finance/summary');

  /// تسجيل دفع للمتجر — Backend CourierFinanceApiController::paySeller
  /// paidFrom: float (من العهدة) | self (من جيبي)
  Future<ApiResult> paySeller({
    required dynamic assignmentId,
    required String amount,
    String paidFrom = 'self',
    String? receipt,
  }) {
    return post('delivery_boy/finance/pay-seller', {
      'assignment_id': assignmentId,
      'amount': amount,
      'paid_from': paidFrom,
      if (receipt != null && receipt.isNotEmpty) 'receipt': receipt,
    });
  }

  // Backend getWithdrawalRequests: limit/offset/search/type/status
  // ويرجع {withdraw_requests[], balance} — لاحظ الاسم withdraw_requests (بدون al)
  Future<ApiResult> withdrawals({
    int? limit,
    int? offset,
    String? search,
    String? status,
    String? type,
  }) {
    return get('delivery_boy/withdrawal_requests/get', {
      if (limit != null) 'limit': limit,
      if (offset != null) 'offset': offset,
      if (search != null && search.isNotEmpty) 'search': search,
      if (status != null && status.isNotEmpty) 'status': status,
      if (type != null && type.isNotEmpty) 'type': type,
    });
  }

  // قائمة طلبات السحب الخاصة بالموصل (index) — مفلترة تلقائياً role_id=4
  Future<ApiResult> withdrawalIndex() =>
      get('delivery_boy/withdrawal_requests/');
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

  /// طبق الأصل DeliveryBoyController::getSalesReport:
  /// startDate/endDate + category (اختياري) — يرجع {categories[], salesReports[]}
  Future<ApiResult> salesReports({
    required String startDate,
    required String endDate,
    String? category,
  }) {
    return get('delivery_boy/sales_reports', {
      'startDate': startDate,
      'endDate': endDate,
      if (category != null && category.isNotEmpty) 'category': category,
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

  // DeliverySettings.vue: GET delivery_boy/profile -> full courier profile
  // {name,mobile,status,is_available,average_rating,rating_count,balance,city,zones,
  // shift_start,shift_end,max_capacity,...}
  Future<ApiResult> deliveryProfile() => get('delivery_boy/profile');
  // DeliverySettings.vue: POST system_users/change_password {username,current_password,password,confirm_password}
  Future<ApiResult> changeUsernamePassword({
    required String username,
    required String currentPassword,
    required String password,
    required String confirmPassword,
  }) {
    return post('system_users/change_password', {
      'username': username,
      'current_password': currentPassword,
      'password': password,
      'confirm_password': confirmPassword,
    });
  }

  Future<ApiResult> settings() => get('delivery_boy/settings');
  Future<ApiResult> privacyPolicy() => post('delivery_boy/privacy_policy');
  Future<ApiResult> mailSettings() => get('delivery_boy/mail_settings');
  Future<ApiResult> saveMailSettings(Map<String, dynamic> body) =>
      post('delivery_boy/mail_settings/save', body);
  // Backend routes/api.php: POST delivery_boy/delete_delivery_boy_account
  // يتطلب confirmation='DELETE' + password (confirmAccountDeletion).
  Future<ApiResult> deleteAccount({
    required String password,
    String confirmation = 'DELETE',
  }) => post('delivery_boy/delete_delivery_boy_account', {
    'confirmation': confirmation,
    'password': password,
  });
  Future<ApiResult> cities() => get('delivery_boy/cities');
  // إشعارات اللوحة: GET get_top_notifications (عام auth) — {unread, notifications}
  Future<ApiResult> topNotifications() => get('get_top_notifications');
  Future<ApiResult> markNotificationRead({dynamic id, bool all = false}) =>
      get('notification_read', {if (id != null) 'id': id, if (all) 'all': 1});
  // تقييمات الموصل (واجهة الزبون — تعرض متوسط تقييمك): GET /customer/delivery_boy_rating
  // ملاحظة: تتطلب توكن زبون غالباً؛ نعرضها إن نجحت وإلا نعتمد بيانات البروفايل
  Future<ApiResult> myRatings({int limit = 10, int offset = 0}) =>
      get('delivery_boy_ratings', {'limit': limit, 'offset': offset});
  Future<ApiResult> updateProfile(FormData data) =>
      postForm('delivery_boys/update', data);
}
