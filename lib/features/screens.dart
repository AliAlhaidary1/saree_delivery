import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../core/app_controller.dart';
import '../core/config.dart';
import '../core/json_util.dart';
import '../theme/app_colors.dart';
import '../widgets/common.dart';
import '../widgets/driver_ui.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final email = TextEditingController();
  final password = TextEditingController();
  final otp = TextEditingController();
  final newPassword = TextEditingController();
  final confirm = TextEditingController();
  String view = 'login';
  String? error;
  bool busy = false;
  bool hidePassword = true;

  @override
  void dispose() {
    email.dispose();
    password.dispose();
    otp.dispose();
    newPassword.dispose();
    confirm.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.navy,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(24),
                children: [
                  const SizedBox(height: 32),
                  Center(
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.white.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Image.asset(
                        'assets/brand/logo.webp',
                        height: 80,
                        errorBuilder: (_, __, ___) => const Icon(
                          Icons.delivery_dining,
                          size: 64,
                          color: AppColors.orange,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'سريع ماركت',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w800,
                      color: AppColors.white,
                    ),
                  ),
                  Text(
                    view == 'login'
                        ? 'تطبيق سائق التوصيل'
                        : 'استعادة كلمة المرور',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: AppColors.white.withValues(alpha: 0.7),
                    ),
                  ),
                  const SizedBox(height: 32),
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: AppColors.white,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Column(
                      children: [
                        TextField(
                          controller: email,
                          keyboardType: TextInputType.text,
                          textDirection: TextDirection.ltr,
                          decoration: InputDecoration(
                            labelText: 'الجوال أو البريد',
                            prefixText: view == 'login'
                                ? null
                                : '+${AppConfig.countryDialCode} ',
                          ),
                        ),
                        if (view == 'login') ...[
                          const SizedBox(height: 12),
                          TextField(
                            controller: password,
                            obscureText: hidePassword,
                            decoration: InputDecoration(
                              labelText: 'كلمة المرور',
                              suffixIcon: IconButton(
                                onPressed: () => setState(
                                  () => hidePassword = !hidePassword,
                                ),
                                icon: Icon(
                                  hidePassword
                                      ? Icons.visibility_outlined
                                      : Icons.visibility_off_outlined,
                                ),
                              ),
                            ),
                          ),
                        ],
                        if (view == 'forgot')
                          const Padding(
                            padding: EdgeInsets.only(top: 8),
                            child: Text(
                              'سنرسل رمز تحقق إلى واتساب أو الجوال المسجّل.',
                              style: TextStyle(
                                fontSize: 13,
                                color: AppColors.greyText,
                              ),
                            ),
                          ),
                        if (view == 'reset') ...[
                          const SizedBox(height: 12),
                          TextField(
                            controller: otp,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: 'رمز التحقق',
                            ),
                          ),
                          const SizedBox(height: 12),
                          labeledField(
                            newPassword,
                            'كلمة المرور الجديدة',
                            toggleObscure: true,
                          ),
                          labeledField(
                            confirm,
                            'تأكيد كلمة المرور',
                            toggleObscure: true,
                          ),
                        ],
                        if (error != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 12),
                            child: Text(
                              error!,
                              style: const TextStyle(color: AppColors.error),
                            ),
                          ),
                        const SizedBox(height: 20),
                        DriverActionButton(
                          label: view == 'login'
                              ? 'دخول'
                              : view == 'forgot'
                              ? 'إرسال الرمز'
                              : 'تغيير كلمة المرور',
                          loading: busy,
                          onPressed: busy ? null : _submit,
                        ),
                        TextButton(
                          onPressed: busy
                              ? null
                              : () => setState(() {
                                  view = view == 'login' ? 'forgot' : 'login';
                                  error = null;
                                }),
                          child: Text(
                            view == 'login'
                                ? 'نسيت كلمة المرور؟'
                                : 'العودة لتسجيل الدخول',
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  Text(
                    'التسجيل يتم من الإدارة فقط.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: AppColors.white.withValues(alpha: 0.6),
                      fontSize: 12,
                    ),
                  ),
                  TextButton(
                    onPressed: () => context.push('/privacy'),
                    child: Text(
                      'سياسة الخصوصية والشروط',
                      style: TextStyle(
                        color: AppColors.white.withValues(alpha: 0.8),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _submit() async {
    final mobile = email.text.trim();
    if (mobile.isEmpty) {
      setState(() => error = 'أكمل الجوال أو البريد');
      return;
    }
    if (view == 'login' && password.text.isEmpty) {
      setState(() => error = 'أكمل الجوال أو البريد وكلمة المرور');
      return;
    }
    setState(() {
      busy = true;
      error = null;
    });
    try {
      if (view == 'login') {
        final message = await app.login(mobile, password.text);
        if (!mounted) return;
        if (message != null) {
          setState(() => error = message);
        } else {
          context.go('/');
        }
      } else if (view == 'forgot') {
        final result = await app.api.forgotPasswordOtp(mobile);
        if (!mounted) return;
        if (!result.ok) {
          setState(() => error = result.message);
        } else {
          setState(() {
            view = 'reset';
            error = 'أدخل رمز التحقق وكلمة المرور الجديدة';
          });
        }
      } else {
        if (otp.text.trim().isEmpty ||
            newPassword.text.length < 6 ||
            newPassword.text != confirm.text) {
          setState(
            () => error = 'تحقق من الرمز وكلمة المرور (6 أحرف على الأقل)',
          );
        } else {
          final result = await app.api.resetPasswordOtp(
            mobile: mobile,
            otp: otp.text.trim(),
            password: newPassword.text,
            passwordConfirmation: confirm.text,
          );
          if (!mounted) return;
          if (!result.ok) {
            setState(() => error = result.message);
          } else {
            setState(() {
              view = 'login';
              error = 'تم تغيير كلمة المرور. سجّل الدخول الآن';
            });
          }
        }
      }
    } catch (_) {
      if (mounted) {
        setState(() => error = 'تعذر الاتصال بالخادم. تحقق من الإنترنت.');
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  @override
  void initState() {
    super.initState();
    app.refreshDashboard();
    if (app.isOnline) app.startOrderPolling();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: app,
      builder: (context, _) {
        final d = app.dashboard;
        final activeCount = '${d['active_order_count'] ?? 0}';
        final orderCount = '${d['order_count'] ?? 0}';
        final acceptance = formatPercent(
          d['acceptance_rate'] ?? d['acceptance'] ?? '—',
        );

        return Stack(
          children: [
            RefreshIndicator(
              color: AppColors.orange,
              onRefresh: app.refreshDashboard,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                children: [
                  DutyToggle(
                    isOnline: app.isOnline,
                    onChanged: (v) => app.setOnline(v),
                  ),
                  const SizedBox(height: 16),
                  GridView.count(
                    crossAxisCount: 3,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    mainAxisSpacing: 10,
                    crossAxisSpacing: 10,
                    childAspectRatio: 0.85,
                    children: [
                      KpiCard(
                        icon: Icons.payments_outlined,
                        label: 'أرباح اليوم',
                        value: formatEarnings(d),
                      ),
                      KpiCard(
                        icon: Icons.check_circle_outline,
                        label: 'توصيلات مكتملة',
                        value: orderCount,
                        accent: AppColors.navy,
                      ),
                      KpiCard(
                        icon: Icons.trending_up,
                        label: 'نسبة القبول',
                        value: acceptance,
                        accent: AppColors.success,
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  const SectionHeader('اختصارات سريعة'),
                  GridView.count(
                    crossAxisCount: 2,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    mainAxisSpacing: 10,
                    crossAxisSpacing: 10,
                    childAspectRatio: 1.4,
                    children: [
                      QuickActionTile(
                        icon: Icons.local_shipping,
                        label: 'الطلبات الجارية',
                        badge: activeCount != '0' ? activeCount : null,
                        onTap: () => context.go('/orders?type=1'),
                      ),
                      QuickActionTile(
                        icon: Icons.history,
                        label: 'الطلبات السابقة',
                        onTap: () => context.go('/orders?type=0'),
                      ),
                      QuickActionTile(
                        icon: Icons.payments,
                        label: 'تحصيل نقدي',
                        onTap: () => context.push('/cash'),
                      ),
                      QuickActionTile(
                        icon: Icons.account_balance_wallet,
                        label: 'السحب',
                        onTap: () => context.push('/withdrawals'),
                      ),
                      QuickActionTile(
                        icon: Icons.swap_horiz,
                        label: 'تحويلات',
                        onTap: () => context.push('/funds'),
                      ),
                      QuickActionTile(
                        icon: Icons.bar_chart,
                        label: 'التقارير',
                        onTap: () => context.push('/reports'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.greyBorder),
                    ),
                    child: Row(
                      children: [
                        CircleAvatar(
                          backgroundColor: AppColors.orange.withValues(
                            alpha: 0.12,
                          ),
                          child: const Icon(
                            Icons.person,
                            color: AppColors.orange,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                app.name,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.navy,
                                ),
                              ),
                              Text(
                                'الرصيد: ${app.balance}',
                                style: const TextStyle(
                                  color: AppColors.greyText,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                        ),
                        TextButton(
                          onPressed: () => context.go('/account'),
                          child: const Text('حسابي'),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            if (app.incomingOrder != null)
              IncomingOrderOverlay(
                order: app.incomingOrder!,
                onAccept: () {
                  final order = app.incomingOrder!;
                  app.dismissIncomingOrder();
                  final id = '${order['order_id'] ?? order['id']}';
                  context.push('/delivery/$id');
                },
                onDecline: app.dismissIncomingOrder,
              ),
          ],
        );
      },
    );
  }
}

class OrdersScreen extends StatefulWidget {
  const OrdersScreen({super.key, this.type});
  final int? type;

  @override
  State<OrdersScreen> createState() => _OrdersScreenState();
}

class _OrdersScreenState extends State<OrdersScreen> {
  List<Map<String, dynamic>> items = [];
  bool loading = true;
  int? type;

  @override
  void initState() {
    super.initState();
    type = widget.type;
    _load();
  }

  @override
  void didUpdateWidget(covariant OrdersScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.type != widget.type) {
      type = widget.type;
      _load();
    }
  }

  Future<void> _load() async {
    setState(() => loading = true);
    final result = await app.api.orders(type: type);
    if (!mounted) return;
    setState(() {
      items = result.list('orders').isNotEmpty
          ? result.list('orders')
          : result.dataMaps;
      loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        FilterChips(
          selected: type,
          onSelected: (v) {
            setState(() => type = v);
            _load();
          },
        ),
        Expanded(
          child: loading
              ? const Center(
                  child: CircularProgressIndicator(color: AppColors.orange),
                )
              : items.isEmpty
              ? Refreshable(
                  onRefresh: _load,
                  child: EmptyBox(
                    'لا توجد طلبات',
                    icon: Icons.local_shipping_outlined,
                    actionLabel: 'إعادة المحاولة',
                    onAction: _load,
                  ),
                )
              : RefreshIndicator(
                  color: AppColors.orange,
                  onRefresh: _load,
                  child: ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: items.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (_, i) {
                      final order = items[i];
                      final id = '${order['order_id'] ?? order['id']}';
                      return OrderListCard(
                        orderId: id,
                        customerName: J.str(order['user_name']),
                        address: J.str(order['address']),
                        total: J.str(order['final_total']),
                        status: J.str(order['status'] ?? order['order_status']),
                        isActive: type == 1,
                        onTap: () => context.push('/order/$id'),
                      );
                    },
                  ),
                ),
        ),
      ],
    );
  }
}

class OrderDetailsScreen extends StatefulWidget {
  const OrderDetailsScreen({super.key, required this.id});
  final String id;

  @override
  State<OrderDetailsScreen> createState() => _OrderDetailsScreenState();
}

class _OrderDetailsScreenState extends State<OrderDetailsScreen> {
  Map<String, dynamic>? order;
  List<Map<String, dynamic>> statuses = [];
  bool loading = true;
  bool failed = false;
  bool updating = false;
  String? proofPhotoPath;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final result = await app.api.orderById(widget.id);
    final st = await app.api.orderStatuses();
    if (!mounted) return;
    setState(() {
      order = result.dataMaps.isNotEmpty
          ? result.dataMaps.first
          : result.dataMap;
      statuses = st.dataMaps;
      loading = false;
      failed = !result.ok || (order == null || order!.isEmpty);
    });
  }

  Future<void> _updateStatus(Map<String, dynamic> status) async {
    final statusName = J.str(status['status'] ?? status['name']);
    final isDelivered = statusName.contains('تسليم') ||
        statusName.toLowerCase().contains('deliver');

    if (isDelivered && proofPhotoPath == null) {
      await _showProofModal(status);
      return;
    }

    final ok = await confirmAction(
      context,
      title: 'تحديث الحالة',
      body: 'تغيير حالة الطلب إلى $statusName؟',
    );
    if (!ok || !mounted) return;
    await _performStatusUpdate(status);
  }

  Future<void> _showProofModal(Map<String, dynamic> status) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => ProofOfDeliverySheet(
        photoPath: proofPhotoPath,
        onTakePhoto: () async {
          final file = await ImagePicker().pickImage(
            source: ImageSource.camera,
            requestFullMetadata: false,
          );
          if (!ctx.mounted) return;
          if (file != null) {
            setState(() => proofPhotoPath = file.path);
            Navigator.pop(ctx);
            await _performStatusUpdate(status);
          }
        },
        onFromGallery: () async {
          final file = await ImagePicker().pickImage(
            source: ImageSource.gallery,
            requestFullMetadata: false,
          );
          if (!ctx.mounted) return;
          if (file != null) {
            setState(() => proofPhotoPath = file.path);
            Navigator.pop(ctx);
            await _performStatusUpdate(status);
          }
        },
      ),
    );
  }

  Future<void> _performStatusUpdate(Map<String, dynamic> status) async {
    setState(() => updating = true);
    final result = await app.api.updateStatus(
      orderId: widget.id,
      statusId: status['id'],
      deliveryBoyId: app.boyId,
    );
    if (!mounted) return;
    setState(() => updating = false);
    toast(context, result.ok ? 'تم التحديث' : result.message);
    if (result.ok) _load();
  }

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(color: AppColors.orange),
        ),
      );
    }
    if (failed) {
      return Scaffold(
        appBar: AppBar(title: Text('طلب ${widget.id}')),
        body: EmptyBox(
          'تعذر تحميل الطلب',
          icon: Icons.error_outline,
          actionLabel: 'إعادة المحاولة',
          onAction: () {
            setState(() {
              loading = true;
              failed = false;
            });
            _load();
          },
        ),
      );
    }

    final items = J.maps(order?['items'] ?? order?['order_items']);
    final mobile = J.str(order?['mobile']);
    final address = J.str(order?['address']);
    final storeName = J.str(
      order?['store_name'] ?? order?['seller_name'] ?? 'المتجر',
    );
    final currentStatus = J.str(
      order?['status'] ?? order?['order_status'] ?? 'تم القبول',
    );
    final stepIndex = timelineIndexFromStatus(currentStatus, kDeliverySteps);

    return Scaffold(
      backgroundColor: AppColors.greyBg,
      appBar: AppBar(
        title: Text('طلب #${widget.id}'),
        actions: [
          IconButton(
            icon: const Icon(Icons.map_outlined),
            onPressed: () => context.push('/delivery/${widget.id}'),
            tooltip: 'عرض الخريطة',
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          DeliveryMapView(
            pickupLabel: storeName,
            dropoffLabel: address,
            onNavigate: () => openMapsNavigation(address),
          ),
          const SizedBox(height: 16),
          OrderProgressTimeline(
            steps: kDeliverySteps,
            currentIndex: stepIndex,
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.greyBorder),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  J.str(order?['user_name']),
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: AppColors.navy,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  address,
                  style: const TextStyle(color: AppColors.greyText),
                ),
                if (mobile.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  ContactActions(
                    phone: mobile,
                    onCall: () => openTel(mobile),
                    onMessage: () => openSms(mobile),
                    onCopy: () => copyText(context, mobile),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.greyBorder),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'تفاصيل الطلب',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: AppColors.navy,
                  ),
                ),
                const SizedBox(height: 8),
                ...items.map(
                  (item) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            J.str(item['product_name'] ?? item['name']),
                          ),
                        ),
                        Text('x${item['quantity']}'),
                      ],
                    ),
                  ),
                ),
                const Divider(),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('الإجمالي'),
                    Text(
                      J.str(order?['final_total']),
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 18,
                        color: AppColors.orange,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  'رسوم التوصيل: ${order?['delivery_charge'] ?? 0} • ${J.str(order?['payment_method'])}',
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.greyText,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          if (updating)
            const Center(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: CircularProgressIndicator(color: AppColors.orange),
              ),
            )
          else if (statuses.isNotEmpty) ...[
            const SectionHeader('تحديث الحالة'),
            ...statuses.map((s) {
              final name = J.str(s['status'] ?? s['name']);
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: DriverActionButton(
                  label: name,
                  icon: Icons.check_circle_outline,
                  onPressed: () => _updateStatus(s),
                ),
              );
            }),
            const SizedBox(height: 8),
            SlideToConfirm(
              label: 'اسحب لتأكيد الاستلام',
              onConfirmed: () {
                if (statuses.length > 2) _updateStatus(statuses[2]);
              },
            ),
          ],
        ],
      ),
    );
  }
}

/// Full-screen live delivery map with floating status card.
class LiveDeliveryScreen extends StatefulWidget {
  const LiveDeliveryScreen({super.key, required this.id});
  final String id;

  @override
  State<LiveDeliveryScreen> createState() => _LiveDeliveryScreenState();
}

class _LiveDeliveryScreenState extends State<LiveDeliveryScreen> {
  Map<String, dynamic>? order;
  bool loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final result = await app.api.orderById(widget.id);
    if (!mounted) return;
    setState(() {
      order = result.dataMaps.isNotEmpty
          ? result.dataMaps.first
          : result.dataMap;
      loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(color: AppColors.orange),
        ),
      );
    }

    final storeName = J.str(
      order?['store_name'] ?? order?['seller_name'] ?? 'المتجر',
    );
    final address = J.str(order?['address']);
    final earnings = J.str(
      order?['delivery_charge'] ?? order?['final_total'] ?? '—',
    );
    final distance = J.str(
      order?['distance'] ?? order?['delivery_distance'] ?? '—',
    );

    return Scaffold(
      backgroundColor: AppColors.navy,
      body: Stack(
        children: [
          Positioned.fill(
            child: DeliveryMapView(
              pickupLabel: storeName,
              dropoffLabel: address,
              height: MediaQuery.of(context).size.height,
              onNavigate: () => openMapsNavigation(address),
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: IconButton.filled(
                style: IconButton.styleFrom(
                  backgroundColor: AppColors.navy,
                ),
                onPressed: () => context.pop(),
                icon: const Icon(Icons.arrow_forward, color: AppColors.white),
              ),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: DeliveryFloatingCard(
              storeName: storeName,
              orderId: widget.id,
              distance: distance,
              earnings: earnings,
              onNavigate: () => openMapsNavigation(address),
              onViewDetails: () => context.push('/order/${widget.id}'),
            ),
          ),
        ],
      ),
    );
  }
}

class CashScreen extends StatefulWidget {
  const CashScreen({super.key});
  @override
  State<CashScreen> createState() => _CashScreenState();
}

class _CashScreenState extends State<CashScreen> {
  Map<String, dynamic> data = {};
  List<Map<String, dynamic>> items = [];
  bool loading = true;

  Future<void> _load() async {
    final result = await app.api.cashCollection();
    if (!mounted) return;
    setState(() {
      data = result.dataMap;
      items = result.list('transactions').isNotEmpty
          ? result.list('transactions')
          : result.dataMaps;
      loading = false;
    });
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('تحصيل نقدي')),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                children: [
                  Card(
                    child: ListTile(
                      title: Text(
                        'نقداً في اليد: ${data['cash_in_hand'] ?? 0}',
                      ),
                      subtitle: Text(
                        'إجمالي المحصّل: ${data['cash_collected'] ?? 0}',
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  if (items.isEmpty)
                    const Padding(
                      padding: EdgeInsets.only(top: 24),
                      child: Text(
                        'لا توجد عمليات تحصيل',
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ...items.map(
                    (item) => ListTile(
                      title: Text(
                        '#${item['order_id'] ?? '-'} • ${J.str(item['type'])}',
                      ),
                      subtitle: Text(
                        J.str(item['created_at'] ?? item['message']),
                      ),
                      trailing: Text(
                        J.str(
                          item['amount'] ??
                              item['collected_amount'] ??
                              item['final_total'],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}

class FundsScreen extends StatefulWidget {
  const FundsScreen({super.key});
  @override
  State<FundsScreen> createState() => _FundsScreenState();
}

class _FundsScreenState extends State<FundsScreen> {
  List<Map<String, dynamic>> items = [];
  bool loading = true;

  Future<void> _load() async {
    final result = await app.api.fundTransfers();
    if (!mounted) return;
    setState(() {
      items = result.dataMaps;
      loading = false;
    });
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('تحويلات الرصيد')),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : items.isEmpty
          ? Refreshable(
              onRefresh: _load,
              child: const EmptyBox('لا توجد تحويلات'),
            )
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                children: items
                    .map(
                      (item) => ListTile(
                        title: Text(
                          J.str(item['type'] ?? item['message'] ?? item['id']),
                        ),
                        subtitle: Text(
                          J.str(item['created_at'] ?? item['status']),
                        ),
                        trailing: Text(J.str(item['amount'])),
                      ),
                    )
                    .toList(),
              ),
            ),
    );
  }
}

class WithdrawalsScreen extends StatefulWidget {
  const WithdrawalsScreen({super.key});
  @override
  State<WithdrawalsScreen> createState() => _WithdrawalsScreenState();
}

class _WithdrawalsScreenState extends State<WithdrawalsScreen> {
  List<Map<String, dynamic>> items = [];
  bool loading = true;

  Future<void> _load() async {
    final result = await app.api.withdrawals();
    if (!mounted) return;
    setState(() {
      items = result.dataMaps;
      loading = false;
    });
  }

  Future<void> _add() async {
    final amount = TextEditingController();
    final message = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('طلب سحب'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: amount,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'المبلغ'),
            ),
            TextField(
              controller: message,
              decoration: const InputDecoration(labelText: 'ملاحظة'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('إرسال'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    final value = double.tryParse(amount.text.trim());
    if (value == null || value <= 0) {
      toast(context, 'أدخل مبلغاً صحيحاً');
      return;
    }
    final result = await app.api.addWithdrawal(
      amount: amount.text.trim(),
      message: message.text,
    );
    if (!mounted) return;
    toast(context, result.ok ? 'تم إرسال الطلب' : result.message);
    if (result.ok) _load();
  }

  String _status(dynamic value) {
    switch (J.i(value)) {
      case 1:
        return 'مقبول';
      case 2:
        return 'مرفوض';
      default:
        return 'قيد الانتظار';
    }
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('طلبات السحب')),
      floatingActionButton: FloatingActionButton(
        onPressed: _add,
        child: const Icon(Icons.add),
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : items.isEmpty
          ? Refreshable(
              onRefresh: _load,
              child: EmptyBox(
                'لا توجد طلبات سحب',
                actionLabel: 'طلب سحب',
                onAction: _add,
              ),
            )
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                children: items
                    .map(
                      (item) => ListTile(
                        title: Text(J.str(item['amount'])),
                        subtitle: Text(
                          '${_status(item['status'])} • ${J.str(item['message'] ?? item['created_at'])}',
                        ),
                      ),
                    )
                    .toList(),
              ),
            ),
    );
  }
}

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});
  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  late String start;
  late String end;
  List<Map<String, dynamic>> sales = [];
  List<Map<String, dynamic>> products = [];
  bool loading = true;

  String _iso(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    end = _iso(now);
    start = _iso(now.subtract(const Duration(days: 30)));
    _load();
  }

  Future<void> _load() async {
    setState(() => loading = true);
    final a = await app.api.salesReports(startDate: start, endDate: end);
    final b = await app.api.productSalesReports(startDate: start, endDate: end);
    if (!mounted) return;
    setState(() {
      sales = a.list('salesReports').isNotEmpty
          ? a.list('salesReports')
          : a.dataMaps;
      products = b.dataMaps;
      loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('التقارير')),
      body: Column(
        children: [
          ListTile(
            title: Text('من $start إلى $end'),
            trailing: const Icon(Icons.date_range),
            onTap: () async {
              final s = await pickDate(context);
              if (s == null || !context.mounted) return;
              final e = await pickDate(context);
              if (e == null || !context.mounted) return;
              start = s;
              end = e;
              _load();
            },
          ),
          if (loading) const LinearProgressIndicator(),
          Expanded(
            child: ListView(
              children: [
                const ListTile(
                  title: Text(
                    'المبيعات',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                if (sales.isEmpty && products.isEmpty && !loading)
                  const Padding(
                    padding: EdgeInsets.all(24),
                    child: Text(
                      'لا توجد تقارير لهذه الفترة',
                      textAlign: TextAlign.center,
                    ),
                  ),
                ...sales.map(
                  (s) => ListTile(
                    title: Text(J.str(s['product_name'] ?? s['user_name'])),
                    subtitle: Text(J.str(s['added_date'] ?? s['created_at'])),
                    trailing: Text(J.str(s['sub_total'] ?? s['final_total'])),
                  ),
                ),
                const ListTile(
                  title: Text(
                    'حسب المنتج',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                ...products.map(
                  (p) => ListTile(
                    title: Text(J.str(p['product_name'] ?? p['name'])),
                    subtitle: Text('مبيعات ${p['total_sales'] ?? '-'}'),
                    trailing: Text(J.str(p['total_price'] ?? p['sub_total'])),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class MailSettingsScreen extends StatefulWidget {
  const MailSettingsScreen({super.key});
  @override
  State<MailSettingsScreen> createState() => _MailSettingsScreenState();
}

class _MailSettingsScreenState extends State<MailSettingsScreen> {
  List<Map<String, dynamic>> statuses = [];
  final mail = <int, bool>{};
  final mobile = <int, bool>{};
  final sms = <int, bool>{};
  bool loading = true;
  bool busy = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final st = await app.api.orderStatuses();
    final set = await app.api.mailSettings();
    statuses = st.dataMaps;
    final rows = set.dataMaps.isNotEmpty ? set.dataMaps : [set.dataMap];
    for (final status in statuses) {
      final id = J.i(status['id']);
      mail[id] = true;
      mobile[id] = true;
      sms[id] = true;
    }
    for (final row in rows) {
      final id = J.i(row['order_status_id'] ?? row['status_id']);
      if (id == 0) continue;
      mail[id] = J.flag(row['mail_status'] ?? row['mail']);
      mobile[id] = J.flag(row['mobile_status'] ?? row['mobile']);
      sms[id] = J.flag(row['sms_status'] ?? row['sms']);
    }
    if (!mounted) return;
    setState(() => loading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('إشعارات الطلبات')),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : statuses.isEmpty
          ? EmptyBox(
              'لا توجد حالات للضبط',
              actionLabel: 'إعادة المحاولة',
              onAction: () {
                setState(() => loading = true);
                _load();
              },
            )
          : ListView(
              children: [
                ...statuses.map((s) {
                  final id = J.i(s['id']);
                  return ExpansionTile(
                    title: Text(J.str(s['status'] ?? s['name'])),
                    children: [
                      SwitchListTile(
                        title: const Text('بريد'),
                        value: mail[id] ?? true,
                        onChanged: (v) => setState(() => mail[id] = v),
                      ),
                      SwitchListTile(
                        title: const Text('جوال'),
                        value: mobile[id] ?? true,
                        onChanged: (v) => setState(() => mobile[id] = v),
                      ),
                      SwitchListTile(
                        title: const Text('رسالة'),
                        value: sms[id] ?? true,
                        onChanged: (v) => setState(() => sms[id] = v),
                      ),
                    ],
                  );
                }),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: FilledButton(
                    onPressed: busy
                        ? null
                        : () async {
                            setState(() => busy = true);
                            final ids = statuses
                                .map((s) => J.i(s['id']))
                                .toList();
                            final result = await app.api.saveMailSettings({
                              'status_ids': ids.join(','),
                              'mail_statuses': ids
                                  .map((id) => (mail[id] ?? true) ? 1 : 0)
                                  .join(','),
                              'mobile_statuses': ids
                                  .map((id) => (mobile[id] ?? true) ? 1 : 0)
                                  .join(','),
                              'sms_statuses': ids
                                  .map((id) => (sms[id] ?? true) ? 1 : 0)
                                  .join(','),
                            });
                            if (!mounted) return;
                            setState(() => busy = false);
                            toast(
                              context,
                              result.ok ? 'تم الحفظ' : result.message,
                            );
                          },
                    child: busy ? const BusySpinner() : const Text('حفظ'),
                  ),
                ),
              ],
            ),
    );
  }
}

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});
  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final name = TextEditingController();
  final mobile = TextEditingController();
  final address = TextEditingController();
  final password = TextEditingController();
  final confirm = TextEditingController();
  String? cityId;
  String? licensePath;
  String? idPath;
  List<Map<String, dynamic>> cities = [];
  bool busy = false;

  @override
  void initState() {
    super.initState();
    final b = app.boy;
    name.text = J.str(b['name'] ?? app.name);
    mobile.text = J.str(b['mobile']);
    address.text = J.str(b['address']);
    cityId = b['city_id']?.toString();
    app.api.cities().then((res) {
      if (!mounted) return;
      setState(() => cities = res.dataMaps);
    });
  }

  @override
  void dispose() {
    name.dispose();
    mobile.dispose();
    address.dispose();
    password.dispose();
    confirm.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('ملفي')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          labeledField(name, 'الاسم'),
          labeledField(mobile, 'الجوال', type: TextInputType.phone),
          labeledField(address, 'العنوان', maxLines: 2),
          DropdownButtonFormField<String>(
            initialValue: cities.any((c) => '${c['id']}' == cityId)
                ? cityId
                : null,
            items: cities
                .map(
                  (c) => DropdownMenuItem(
                    value: '${c['id']}',
                    child: Text(J.str(c['name'])),
                  ),
                )
                .toList(),
            onChanged: (v) => setState(() => cityId = v),
            decoration: const InputDecoration(
              labelText: 'المدينة',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 10),
          labeledField(
            password,
            'كلمة مرور جديدة (اختياري)',
            toggleObscure: true,
          ),
          labeledField(confirm, 'تأكيد كلمة المرور', toggleObscure: true),
          const Padding(
            padding: EdgeInsets.only(bottom: 8),
            child: Text(
              'الصور اختيارية وتُستخدم فقط لتحديث رخصة القيادة أو الهوية، ولا تُرفع إلا بعد اختيارك الملف.',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ),
          OutlinedButton.icon(
            onPressed: () async {
              final file = await ImagePicker().pickImage(
                source: ImageSource.gallery,
                requestFullMetadata: false,
              );
              if (file != null && mounted)
                setState(() => licensePath = file.path);
            },
            icon: const Icon(Icons.badge_outlined),
            label: Text(
              licensePath == null ? 'رخصة القيادة' : 'تم اختيار الرخصة',
            ),
          ),
          OutlinedButton.icon(
            onPressed: () async {
              final file = await ImagePicker().pickImage(
                source: ImageSource.gallery,
                requestFullMetadata: false,
              );
              if (file != null && mounted) setState(() => idPath = file.path);
            },
            icon: const Icon(Icons.credit_card),
            label: Text(idPath == null ? 'الهوية' : 'تم اختيار الهوية'),
          ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: busy
                ? null
                : () async {
                    if (name.text.trim().isEmpty ||
                        mobile.text.trim().isEmpty) {
                      toast(context, 'أكمل الاسم والجوال');
                      return;
                    }
                    if (password.text.isNotEmpty &&
                        (password.text.length < 6 ||
                            password.text != confirm.text)) {
                      toast(
                        context,
                        'كلمة المرور 6 أحرف على الأقل ويجب أن تتطابق',
                      );
                      return;
                    }
                    setState(() => busy = true);
                    final map = <String, dynamic>{
                      'id': app.boyId,
                      'admin_id': app.adminId,
                      'name': name.text,
                      'mobile': mobile.text,
                      'address': address.text,
                      'city_id': cityId ?? app.boy['city_id'],
                      'status': app.boyStatus,
                      'bonus_type': app.boy['bonus_type'] ?? 0,
                      'bonus_percentage': app.boy['bonus_percentage'] ?? 0,
                      if (password.text.isNotEmpty) 'password': password.text,
                      if (password.text.isNotEmpty)
                        'confirm_password': confirm.text,
                    };
                    if (licensePath != null)
                      map['driving_license'] = await MultipartFile.fromFile(
                        licensePath!,
                        filename: 'license.jpg',
                      );
                    if (idPath != null)
                      map['national_identity_card'] =
                          await MultipartFile.fromFile(
                            idPath!,
                            filename: 'id.jpg',
                          );
                    final result = await app.api.updateProfile(
                      FormData.fromMap(map),
                    );
                    if (!mounted) return;
                    setState(() => busy = false);
                    toast(context, result.ok ? 'تم حفظ الملف' : result.message);
                    if (result.ok) {
                      final current = Map<String, dynamic>.from(app.user ?? {});
                      current['deliveryBoy'] = {
                        ...app.boy,
                        'name': name.text,
                        'mobile': mobile.text,
                        'address': address.text,
                        'city_id': cityId,
                      };
                      app.user = current;
                      await app.persistUser();
                    }
                  },
            child: busy ? const BusySpinner() : const Text('حفظ'),
          ),
        ],
      ),
    );
  }
}

class PrivacyScreen extends StatefulWidget {
  const PrivacyScreen({super.key});

  @override
  State<PrivacyScreen> createState() => _PrivacyScreenState();
}

class _PrivacyScreenState extends State<PrivacyScreen> {
  String privacy = '';
  String terms = '';
  bool loading = true;

  static const _privacyFallback =
      'تنطبق سياسة الخصوصية هذه على تطبيق مجمع مأرب موصل في اليمن. نجمع بيانات الحساب اللازمة للعمل: الاسم، رقم الجوال، البريد إن وُجد، العنوان والمدينة، الطلبات المسندة، التحصيل النقدي، التحويلات وطلبات السحب.\n\n'
      'الصور: يمكنك اختيار صورة رخصة القيادة أو الهوية من المعرض لتحديث ملفك. لا نصل إلى المعرض إلا عند اختيارك ذلك.\n\n'
      'لا نبيع بياناتك لمعلنين. قد تظهر بيانات لازمة لتنفيذ التوصيل داخل المنصة. يمكنك حذف الحساب من: حسابي ثم حذف الحساب.\n\n'
      'الخدمة مخصصة لمن يبلغ 18 عاماً فأكثر لأن التوصيل عمل ميداني. آخر تحديث: 15 أغسطس 2026.';

  static const _termsFallback =
      'باستخدام تطبيق مجمع مأرب موصل فإنك توافق على هذه الشروط. الحساب يُنشأ من الإدارة فقط.\n\n'
      'أنت مسؤول عن التعامل مع الطلبات المسندة، تحديث الحالة بدقة، وتسليم التحصيل النقدي حسب تعليمات الإدارة.\n\n'
      'يُمنع إساءة استخدام بيانات العملاء أو مشاركة تفاصيل الطلب خارج العمل. يحق للإدارة إيقاف الحساب عند المخالفة.\n\n'
      'يمكنك حذف حسابك من داخل التطبيق: حسابي ثم حذف الحساب. آخر تحديث: 15 أغسطس 2026.';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    String pick(dynamic source, String key) {
      if (source is Map) return J.plain(source[key]);
      return J.plain(source);
    }

    var p = pick(app.settings, 'privacy_policy_delivery_boy');
    var t = pick(app.settings, 'terms_conditions_delivery_boy');
    if (p.isEmpty || t.isEmpty) {
      final result = await app.api.privacyPolicy();
      final data = result.dataMap.isNotEmpty ? result.dataMap : result.raw;
      if (p.isEmpty) p = pick(data, 'privacy_policy_delivery_boy');
      if (t.isEmpty) t = pick(data, 'terms_conditions_delivery_boy');
    }
    if (!mounted) return;
    setState(() {
      privacy = p.isEmpty ? _privacyFallback : p;
      terms = t.isEmpty ? _termsFallback : t;
      loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('السياسات')),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                const Text(
                  'سياسة الخصوصية',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                ),
                const SizedBox(height: 8),
                Text(privacy),
                const SizedBox(height: 24),
                const Text(
                  'الشروط والأحكام',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                ),
                const SizedBox(height: 8),
                Text(terms),
                const SizedBox(height: 24),
                FilledButton(
                  onPressed: () {
                    setState(() => loading = true);
                    _load();
                  },
                  child: const Text('تحديث'),
                ),
              ],
            ),
    );
  }
}

class AccountScreen extends StatelessWidget {
  const AccountScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.symmetric(vertical: 8),
      children: [
        Container(
          margin: const EdgeInsets.all(16),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [AppColors.navy, AppColors.navyLight],
              begin: Alignment.topRight,
              end: Alignment.bottomLeft,
            ),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            children: [
              CircleAvatar(
                radius: 28,
                backgroundColor: AppColors.orange.withValues(alpha: 0.2),
                child: const Icon(Icons.person, color: AppColors.orange, size: 32),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      app.name,
                      style: const TextStyle(
                        color: AppColors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 18,
                      ),
                    ),
                    Text(
                      'الرصيد: ${app.balance}',
                      style: TextStyle(
                        color: AppColors.white.withValues(alpha: 0.7),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        AccountMenuItem(
          icon: Icons.badge_outlined,
          title: 'ملفي',
          onTap: () => context.push('/profile'),
        ),
        AccountMenuItem(
          icon: Icons.payments_outlined,
          title: 'تحصيل نقدي',
          onTap: () => context.push('/cash'),
        ),
        AccountMenuItem(
          icon: Icons.swap_horiz,
          title: 'تحويلات الرصيد',
          onTap: () => context.push('/funds'),
        ),
        AccountMenuItem(
          icon: Icons.account_balance_wallet_outlined,
          title: 'طلبات السحب',
          onTap: () => context.push('/withdrawals'),
        ),
        AccountMenuItem(
          icon: Icons.bar_chart,
          title: 'التقارير',
          onTap: () => context.push('/reports'),
        ),
        AccountMenuItem(
          icon: Icons.notifications_outlined,
          title: 'إشعارات الطلبات',
          onTap: () => context.push('/mail'),
        ),
        AccountMenuItem(
          icon: Icons.privacy_tip_outlined,
          title: 'السياسات',
          onTap: () => context.push('/privacy'),
        ),
        if (kDebugMode)
          AccountMenuItem(
            icon: Icons.settings,
            title: 'عنوان الخادم',
            subtitle: app.apiUrl,
            onTap: () async {
              final c = TextEditingController(text: app.apiUrl);
              final ok = await showDialog<bool>(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Text('API URL'),
                  content: TextField(controller: c),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(ctx, false),
                      child: const Text('إلغاء'),
                    ),
                    FilledButton(
                      onPressed: () => Navigator.pop(ctx, true),
                      child: const Text('حفظ'),
                    ),
                  ],
                ),
              );
              if (ok == true) await app.setApiUrl(c.text);
            },
          ),
        const Divider(height: 1),
        AccountMenuItem(
          icon: Icons.delete_outline,
          title: 'حذف الحساب',
          destructive: true,
          onTap: () async {
            final ok = await confirmAction(
              context,
              title: 'حذف الحساب',
              body:
                  'سيتم حذف حساب الموصل نهائياً ولا يمكن التراجع. هل أنت متأكد؟',
              confirmLabel: 'حذف',
            );
            if (!ok || !context.mounted) return;
            final result = await app.api.deleteAccount();
            if (!context.mounted) return;
            toast(context, result.ok ? 'تم حذف الحساب' : result.message);
            if (result.ok) {
              await app.logout();
              if (context.mounted) context.go('/login');
            }
          },
        ),
        AccountMenuItem(
          icon: Icons.logout,
          title: 'خروج',
          destructive: true,
          onTap: () async {
            final ok = await confirmAction(
              context,
              title: 'تسجيل الخروج',
              body: 'هل تريد تسجيل الخروج؟',
            );
            if (!ok || !context.mounted) return;
            await app.logout();
            if (context.mounted) context.go('/login');
          },
        ),
      ],
    );
  }
}
