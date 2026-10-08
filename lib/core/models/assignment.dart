import '../json_util.dart';

/// حالات الموصل طبق الأصل من app/Enums/DeliveryAssignmentStatus.php:6
enum AssignmentStatus {
  assigned,
  accepted,
  pickingUp,
  pickedUp,
  outForDelivery,
  delivered,
  failed,
  cancelled;

  static AssignmentStatus? fromString(String? v) {
    if (v == null) return null;
    final s = v.trim().toLowerCase();
    for (final e in values) {
      if (e.apiValue == s) return e;
    }
    return null;
  }

  String get apiValue {
    switch (this) {
      case AssignmentStatus.assigned:
        return 'assigned';
      case AssignmentStatus.accepted:
        return 'accepted';
      case AssignmentStatus.pickingUp:
        return 'picking_up';
      case AssignmentStatus.pickedUp:
        return 'picked_up';
      case AssignmentStatus.outForDelivery:
        return 'out_for_delivery';
      case AssignmentStatus.delivered:
        return 'delivered';
      case AssignmentStatus.failed:
        return 'failed';
      case AssignmentStatus.cancelled:
        return 'cancelled';
    }
  }

  String get labelAr {
    switch (this) {
      case AssignmentStatus.assigned:
        return 'تم التعيين';
      case AssignmentStatus.accepted:
        return 'تم القبول';
      case AssignmentStatus.pickingUp:
        return 'في الطريق للاستلام';
      case AssignmentStatus.pickedUp:
        return 'تم الاستلام';
      case AssignmentStatus.outForDelivery:
        return 'في الطريق للعميل';
      case AssignmentStatus.delivered:
        return 'تم التسليم';
      case AssignmentStatus.failed:
        return 'فشل التوصيل';
      case AssignmentStatus.cancelled:
        return 'ملغي';
    }
  }

  /// نسخة طبق الأصل من DeliveryAssignmentStatus::canTransitionTo() في PHP
  /// Backend (app/Enums/DeliveryAssignmentStatus.php):
  /// Assigned => Accepted, Cancelled
  /// Accepted => OutForDelivery, PickedUp, Failed, Cancelled
  /// PickingUp => OutForDelivery, PickedUp, Failed, Cancelled
  /// PickedUp => OutForDelivery, Failed, Cancelled
  /// OutForDelivery => Delivered, Failed, Cancelled
  /// Failed => Assigned, Cancelled
  bool canTransitionTo(AssignmentStatus next) {
    switch (this) {
      case AssignmentStatus.assigned:
        return next == AssignmentStatus.accepted ||
            next == AssignmentStatus.cancelled;
      case AssignmentStatus.accepted:
        return next == AssignmentStatus.outForDelivery ||
            next == AssignmentStatus.pickedUp ||
            next == AssignmentStatus.failed ||
            next == AssignmentStatus.cancelled;
      case AssignmentStatus.pickingUp:
        return next == AssignmentStatus.outForDelivery ||
            next == AssignmentStatus.pickedUp ||
            next == AssignmentStatus.failed ||
            next == AssignmentStatus.cancelled;
      case AssignmentStatus.pickedUp:
        return next == AssignmentStatus.outForDelivery ||
            next == AssignmentStatus.failed ||
            next == AssignmentStatus.cancelled;
      case AssignmentStatus.outForDelivery:
        return next == AssignmentStatus.delivered ||
            next == AssignmentStatus.failed ||
            next == AssignmentStatus.cancelled;
      case AssignmentStatus.failed:
        return next == AssignmentStatus.assigned ||
            next == AssignmentStatus.cancelled;
      case AssignmentStatus.delivered:
      case AssignmentStatus.cancelled:
        return false;
    }
  }

  /// طبق الأصل courierPrimaryNext() في PHP:
  /// Assigned => Accepted, Accepted/PickingUp/PickedUp => OutForDelivery,
  /// OutForDelivery => Delivered
  AssignmentStatus? courierPrimaryNext() {
    switch (this) {
      case AssignmentStatus.assigned:
        return AssignmentStatus.accepted;
      case AssignmentStatus.accepted:
      case AssignmentStatus.pickingUp:
      case AssignmentStatus.pickedUp:
        return AssignmentStatus.outForDelivery;
      case AssignmentStatus.outForDelivery:
        return AssignmentStatus.delivered;
      case AssignmentStatus.failed:
      case AssignmentStatus.delivered:
      case AssignmentStatus.cancelled:
        return null;
    }
  }

  /// طبق الأصل courierVisibleTimeline() في PHP:
  /// [assigned, accepted, out_for_delivery, delivered]
  /// مع إدخال picking_up/picked_up فقط عندما تكون الحالة الحالية هي إحداهما.
  static List<AssignmentStatus> courierVisibleTimeline(
      AssignmentStatus? current) {
    final steps = <AssignmentStatus>[
      AssignmentStatus.assigned,
      AssignmentStatus.accepted,
      AssignmentStatus.outForDelivery,
      AssignmentStatus.delivered,
    ];
    if (current == AssignmentStatus.pickingUp ||
        current == AssignmentStatus.pickedUp) {
      steps.insert(2, current!);
    }
    return steps;
  }

  bool get isTerminal =>
      this == AssignmentStatus.delivered ||
      this == AssignmentStatus.cancelled;
  bool get isActive =>
      this != AssignmentStatus.delivered &&
      this != AssignmentStatus.cancelled &&
      this != AssignmentStatus.failed;
}

class AssignmentHelper {
  static AssignmentStatus statusOf(Map<String, dynamic> m) {
    return AssignmentStatus.fromString(J.str(m['status'])) ??
        AssignmentStatus.assigned;
  }

  static bool isCheckoutGroupAssignment(Map<String, dynamic> m) {
    final cg = m['checkout_group_id'];
    return cg != null && '${cg}'.isNotEmpty && '${cg}' != '0';
  }

  static double codToCollect(Map<String, dynamic> m) {
    final v = m['cod_to_collect'];
    if (v is num) return v.toDouble();
    return double.tryParse('${v ?? 0}') ?? 0;
  }

  static double codCollected(Map<String, dynamic> m) {
    final v = m['cod_collected'];
    if (v is num) return v.toDouble();
    return double.tryParse('${v ?? 0}') ?? 0;
  }

  static double codLiability(Map<String, dynamic> m) {
    return (codToCollect(m) - codCollected(m)).clamp(0, double.infinity);
  }

  /// المبلغ المدفوع للمتجر مقدماً (جديد: paid_to_seller من الباك اند).
  static double paidToSeller(Map<String, dynamic> m) {
    final v = m['paid_to_seller'];
    if (v is num) return v.toDouble();
    return double.tryParse('${v ?? 0}') ?? 0;
  }

  static String paidFrom(Map<String, dynamic> m) =>
      J.str(m['paid_from'] ?? '', '');

  /// من المتوقع أن يدفع للبائع: self | float | platform (يُضبط عند الإسناد).
  static String payerMode(Map<String, dynamic> m) {
    final v = J.str(m['payer_mode'] ?? '', '');
    if (v == 'float' || v == 'platform' || v == 'self') return v;
    return 'self';
  }

  static String storeName(Map<String, dynamic> a) {
    // Modern: checkoutGroup.sellerOrders[0].seller.name
    final cg = J.map(a['checkoutGroup'] ?? a['checkout_group']);
    final so = J.map(a['sellerOrder'] ?? a['seller_order']);
    // checkoutGroup case: try sellerOrders array
    final sellerOrders = cg['sellerOrders'] ?? cg['seller_orders'];
    if (sellerOrders is List && sellerOrders.isNotEmpty) {
      final first = J.map(sellerOrders.first);
      final seller = J.map(first['seller']);
      final n = J.str(seller['name'] ?? first['seller_name']);
      if (n.isNotEmpty) return n;
    }
    // legacy sellerOrder.seller
    final seller = J.map(so['seller']);
    final n = J.str(seller['name'] ?? so['seller_name']);
    if (n.isNotEmpty) return n;
    return J.str(
      a['store_name'] ?? a['seller_name'] ?? so['store_name'] ?? 'المتجر',
    );
  }

  static String addressOf(Map<String, dynamic> a) {
    final cg = J.map(a['checkoutGroup'] ?? a['checkout_group']);
    final so = J.map(a['sellerOrder'] ?? a['seller_order']);
    final checkoutGroupAddress = J.str(
      cg['shipping_address'] ?? cg['address'] ?? cg['formatted_address'],
    );
    if (checkoutGroupAddress.isNotEmpty) return checkoutGroupAddress;
    // sellerOrder.checkoutGroup
    final soCg = J.map(so['checkoutGroup'] ?? so['checkout_group']);
    final soCgAddr = J.str(
      soCg['shipping_address'] ?? soCg['address'] ?? soCg['formatted_address'],
    );
    if (soCgAddr.isNotEmpty) return soCgAddr;
    return J.str(a['address'] ?? so['address'] ?? so['shipping_address'] ?? '—');
  }

  static String customerNameOf(Map<String, dynamic> a) {
    final so = J.map(a['sellerOrder'] ?? a['seller_order']);
    final cg = J.map(a['checkoutGroup'] ?? a['checkout_group']);
    return J.str(
      so['user_name'] ??
          so['customer_name'] ??
          cg['customer_name'] ??
          a['user_name'] ??
          a['customer_name'] ??
          'العميل',
    );
  }

  static String mobileOf(Map<String, dynamic> a) {
    final so = J.map(a['sellerOrder'] ?? a['seller_order']);
    final cg = J.map(a['checkoutGroup'] ?? a['checkout_group']);
    return J.str(
      so['mobile'] ??
          cg['mobile'] ??
          a['mobile'] ??
          so['customer_mobile'] ??
          cg['customer_mobile'] ??
          '',
    );
  }

  static List<Map<String, dynamic>> itemsOf(Map<String, dynamic> a) {
    // Modern: items عبر sellerOrder.items أو checkoutGroup.sellerOrders[].items
    final so = J.map(a['sellerOrder'] ?? a['seller_order']);
    final cg = J.map(a['checkoutGroup'] ?? a['checkout_group']);
    var items = J.maps(so['items']);
    if (items.isNotEmpty) return items;
    items = J.maps(a['items'] ?? a['order_items']);
    if (items.isNotEmpty) return items;
    // جمع من sellerOrders
    final sellerOrders = cg['sellerOrders'] ?? cg['seller_orders'];
    if (sellerOrders is List) {
      final all = <Map<String, dynamic>>[];
      for (final o in sellerOrders) {
        all.addAll(J.maps(J.map(o)['items']));
      }
      if (all.isNotEmpty) return all;
    }
    final soCg = J.map(so['checkoutGroup'] ?? so['checkout_group']);
    final soSellerOrders = soCg['sellerOrders'] ?? soCg['seller_orders'];
    if (soSellerOrders is List) {
      final all = <Map<String, dynamic>>[];
      for (final o in soSellerOrders) {
        all.addAll(J.maps(J.map(o)['items']));
      }
      if (all.isNotEmpty) return all;
    }
    return [];
  }

  static double finalTotalOf(Map<String, dynamic> a) {
    final so = J.map(a['sellerOrder'] ?? a['seller_order']);
    final cg = J.map(a['checkoutGroup'] ?? a['checkout_group']);
    final v = so['final_total'] ?? cg['final_total'] ?? a['final_total'] ?? a['cod_to_collect'];
    if (v is num) return v.toDouble();
    return double.tryParse('$v') ?? 0;
  }

  static List<AssignmentStatus> nextValidStatuses(AssignmentStatus current) {
    return AssignmentStatus.values.where(current.canTransitionTo).toList();
  }

  // ===== حقول withStatusMeta من الباك اند (DeliveryBoyAssignmentApiController) =====
  /// allowed_next_statuses من السيرفر — المصدر الوحيد الموثوق للأزرار
  static List<String> allowedNext(Map<String, dynamic> m) {
    final v = m['allowed_next_statuses'];
    if (v is List) return v.map((e) => '$e').toList();
    return [];
  }

  static String? primaryNext(Map<String, dynamic> m) {
    final v = m['primary_next_status'];
    if (v == null || '$v'.isEmpty || '$v' == 'null') return null;
    return '$v';
  }

  static bool requiresAccept(Map<String, dynamic> m) =>
      J.flag(m['requires_accept']);

  /// can_cancel من السيرفر (false للمهام المعينة من الأدمن adminAssigned)
  static bool canCancel(Map<String, dynamic> m) => J.flag(m['can_cancel']);

  static bool orderCancelled(Map<String, dynamic> m) =>
      J.flag(m['order_cancelled']);

  static double defaultCodCollected(Map<String, dynamic> m) {
    final v = m['default_cod_collected'];
    if (v is num) return v.toDouble();
    return double.tryParse('${v ?? 0}') ?? 0;
  }

  static bool isReturnPickup(Map<String, dynamic> m) {
    if (J.flag(m['is_return_pickup'])) return true;
    return J.str(m['assignment_type']).toLowerCase() == 'return_pickup';
  }

  static Map<String, dynamic> returnItem(Map<String, dynamic> m) =>
      J.map(m['return_item']);

  static String statusLabel(Map<String, dynamic> m, AssignmentStatus fallback) {
    final l = J.str(m['status_label']);
    return l.isNotEmpty ? l : fallback.labelAr;
  }

  /// timeline_labels للمرتجعات أو full_timeline من السيرفر
  static List<String> fullTimeline(Map<String, dynamic> m) {
    final v = m['full_timeline'];
    if (v is List && v.isNotEmpty) return v.map((e) => '$e').toList();
    return [];
  }

  static Map<String, String> timelineLabels(Map<String, dynamic> m) {
    final v = m['timeline_labels'];
    if (v is Map) return v.map((k, val) => MapEntry('$k', '$val'));
    return {};
  }

  static List<Map<String, dynamic>> events(Map<String, dynamic> m) =>
      J.maps(m['events']);

  static String orderPublicId(Map<String, dynamic> m) =>
      J.str(m['order_public_id'] ?? m['public_id']);

  static String orderRef(Map<String, dynamic> m) =>
      J.str(m['order_ref'] ?? m['checkout_group_id'] ?? m['id']);

  /// سبب الفشل/الإلغاء الأخير — تعرضه صفحة التفاصيل (مثل الويب Last reason).
  static String failureReasonOf(Map<String, dynamic> m) =>
      J.str(m['failure_reason'] ?? m['cancel_reason'] ?? '');

  /// البائعون في المهمة — مثل قسم Sellers في صفحة courier.
  static List<Map<String, dynamic>> sellersOf(Map<String, dynamic> a) {
    final cg = J.map(a['checkoutGroup'] ?? a['checkout_group']);
    final so = J.map(a['sellerOrder'] ?? a['seller_order']);
    final sellerOrders = cg['sellerOrders'] ?? cg['seller_orders'];
    if (sellerOrders is List && sellerOrders.isNotEmpty) {
      return sellerOrders.map((o) {
        final m = J.map(o);
        final seller = J.map(m['seller']);
        return {
          'name': J.str(
              seller['store_name'] ?? seller['name'] ?? m['seller_name'],
              'بائع'),
          'fulfillment': J.str(m['fulfillment_status']),
          'delivery': J.str(m['delivery_status']),
          'items': J.maps(m['items']).length,
        };
      }).toList();
    }
    if (so.isNotEmpty) {
      final seller = J.map(so['seller']);
      return [
        {
          'name': J.str(
              seller['store_name'] ??
                  seller['name'] ??
                  so['seller_name'],
              'بائع'),
          'fulfillment': J.str(so['fulfillment_status']),
          'delivery': J.str(so['delivery_status']),
          'items': J.maps(so['items']).length,
        }
      ];
    }
    return [];
  }
}

/// Workload مطابق لـ DeliveryBoyAssignmentApiController::workload() :115
/// + حقل finance الجديد من CourierFinanceService::summary
class WorkloadInfo {
  final int activeCount;
  final int maxCapacity;
  final int remainingCapacity;
  final double codLiability;
  final List<Map<String, dynamic>> assignments;
  final Map<String, dynamic> finance;

  WorkloadInfo({
    required this.activeCount,
    required this.maxCapacity,
    required this.remainingCapacity,
    required this.codLiability,
    required this.assignments,
    this.finance = const {},
  });

  double get floatBalance => _num(finance['float_balance']);
  double get cashInHand => _num(finance['cash_in_hand']);
  double get netToRemit => _num(finance['net_to_remit']);
  double get pendingSelfClaim => _num(finance['pending_self_claim']);
  bool get overCashLimit => finance['over_cash_limit'] == true;

  static double _num(dynamic v) =>
      (v is num) ? v.toDouble() : double.tryParse('$v') ?? 0;

  factory WorkloadInfo.fromMap(Map<String, dynamic> m) {
    return WorkloadInfo(
      activeCount: J.i(m['active_assignment_count']),
      maxCapacity: J.i(m['max_capacity'], 5),
      remainingCapacity: J.i(m['remaining_capacity']),
      codLiability: (m['cod_liability'] is num)
          ? (m['cod_liability'] as num).toDouble()
          : double.tryParse('${m['cod_liability'] ?? 0}') ?? 0,
      assignments: J.maps(m['assignments']),
      finance: J.map(m['finance']),
    );
  }

  static WorkloadInfo empty() => WorkloadInfo(
        activeCount: 0,
        maxCapacity: 5,
        remainingCapacity: 5,
        codLiability: 0,
        assignments: [],
        finance: {},
      );
}
