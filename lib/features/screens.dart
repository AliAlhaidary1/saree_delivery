import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../core/app_controller.dart';
import '../core/config.dart';
import '../core/json_util.dart';
import '../core/models/assignment.dart';
import '../core/otp_resend.dart';
import '../core/push_service.dart';
import '../theme/app_colors.dart';
import '../widgets/common.dart';
import '../widgets/driver_ui.dart';
import '../widgets/branded_skeleton.dart';

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
  final _otpGate = OtpResendGate();
  String? _otpSuccess;
  bool _resendBusy = false;
  bool _editingPhone = false;

  @override
  void dispose() {
    _otpGate.dispose();
    email.dispose();
    password.dispose();
    otp.dispose();
    newPassword.dispose();
    confirm.dispose();
    super.dispose();
  }

  void _onGateUnlock() {
    if (mounted) setState(() {});
  }

  void _showOtpGreenSuccess() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text(kOtpSuccessMessage),
        backgroundColor: AppColors.success,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _scheduleOtpBackground(int retryAfter) {
    if (!_otpGate.canBackground) return;
    final secs = retryAfter > 0 ? retryAfter.clamp(1, 600) : 60;
    _otpGate.scheduleBackground(Duration(seconds: secs), () async {
      if (!mounted) return;
      final mobileNow = email.text.trim();
      if (mobileNow.isEmpty) return;
      ApiResult result;
      try {
        result = await app.api.forgotPasswordOtp(mobileNow);
      } catch (_) {
        return;
      }
      if (!mounted) return;
      if (result.ok) {
        _otpGate.lock(0, _onGateUnlock);
        _showOtpGreenSuccess();
        setState(() {
          _otpSuccess = kOtpSuccessMessage;
          error = null;
        });
        return;
      }
      final kind = classifyOtpResult(result.raw);
      final msg = extractOtpMessage(result.raw);
      final retry = extractOtpRetryAfter(result.raw, msg);
      if (kind == OtpSendKind.cooldown) {
        _otpGate.lock(retry, _onGateUnlock);
        _showOtpGreenSuccess();
        setState(() {
          _otpSuccess = kOtpSuccessMessage;
          error = null;
        });
        _scheduleOtpBackground(retry);
      } else if (kind == OtpSendKind.hardLimit) {
        _otpGate.lock(retry, _onGateUnlock);
        final honest = msg.isNotEmpty ? msg : kOtpHardLimitFallback;
        setState(() {
          error = honest;
        });
      } else {
        setState(() => error = result.message);
      }
    });
  }

  Future<void> _resendOtp() async {
    if (!_otpGate.canSend || _resendBusy || busy) return;
    final mobileNow = email.text.trim();
    if (mobileNow.isEmpty) {
      setState(() => error = 'أكمل الجوال أو البريد');
      return;
    }
    setState(() => _resendBusy = true);
    try {
      final result = await app.api.forgotPasswordOtp(mobileNow);
      if (!mounted) return;
      if (result.ok) {
        _otpGate.cancelBackground();
        _otpGate.lock(0, _onGateUnlock);
        _showOtpGreenSuccess();
        setState(() {
          _otpSuccess = kOtpSuccessMessage;
          error = null;
        });
        return;
      }
      final kind = classifyOtpResult(result.raw);
      final msg = extractOtpMessage(result.raw);
      final retry = extractOtpRetryAfter(result.raw, msg);
      if (kind == OtpSendKind.cooldown) {
        _otpGate.lock(retry, _onGateUnlock);
        _showOtpGreenSuccess();
        setState(() {
          _otpSuccess = kOtpSuccessMessage;
          error = null;
        });
        _scheduleOtpBackground(retry);
      } else if (kind == OtpSendKind.hardLimit) {
        _otpGate.lock(retry, _onGateUnlock);
        _otpGate.cancelBackground();
        final honest = msg.isNotEmpty ? msg : kOtpHardLimitFallback;
        setState(() {
          error = honest;
          _otpSuccess = null;
        });
      } else {
        setState(() => error = result.message);
      }
    } catch (_) {
      if (mounted) {
        setState(() => error = 'تعذر الاتصال بالخادم. تحقق من الإنترنت.');
      }
    } finally {
      if (mounted) setState(() => _resendBusy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(gradient: AppColors.navyGradient),
        child: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(24),
                children: [
                  SizedBox(height: 32),
                  Center(
                    child: Container(
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: AppColors.white.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(28),
                        border: Border.all(
                          color: AppColors.orange.withValues(alpha: 0.45),
                          width: 1.5,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.orange.withValues(alpha: 0.25),
                            blurRadius: 28,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                      child: Image.asset(
                        'assets/brand/logo.webp',
                        height: 84,
                        errorBuilder: (_, __, ___) => Icon(
                          Icons.delivery_dining,
                          size: 64,
                          color: AppColors.orange,
                        ),
                      ),
                    ),
                  ),
                  SizedBox(height: 16),
                  Text(
                    app.brand.identity['name_ar'] ?? 'سريع مارت - توصيل',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w800,
                      color: AppColors.white,
                    ),
                  ),
                  Text(
                    view == 'login'
                        ? 'توصيل'
                        : 'استعادة كلمة المرور',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: AppColors.white.withValues(alpha: 0.7),
                    ),
                  ),
                  SizedBox(height: 32),
                  Container(
                    padding: const EdgeInsets.all(22),
                    decoration: BoxDecoration(
                      color: AppColors.white,
                      borderRadius: BorderRadius.circular(28),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.25),
                          blurRadius: 32,
                          offset: const Offset(0, 12),
                        ),
                      ],
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
                          SizedBox(height: 12),
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
                          SizedBox(height: 12),
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: AppColors.greyBg,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Column(
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        email.text.trim().isEmpty
                                            ? 'الرقم الحالي غير محدد'
                                            : email.text.trim(),
                                        textDirection: TextDirection.ltr,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ),
                                    TextButton(
                                      onPressed: () => setState(
                                        () => _editingPhone = !_editingPhone,
                                      ),
                                      child: Text(
                                        _editingPhone ? 'تم' : 'تعديل',
                                      ),
                                    ),
                                  ],
                                ),
                                if (_editingPhone)
                                  TextField(
                                    controller: email,
                                    keyboardType: TextInputType.text,
                                    textDirection: TextDirection.ltr,
                                    decoration: InputDecoration(
                                      labelText: 'الجوال أو البريد',
                                      prefixText:
                                          '+${AppConfig.countryDialCode} ',
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          SizedBox(height: 12),
                          TextField(
                            controller: otp,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: 'رمز التحقق',
                            ),
                          ),
                          SizedBox(height: 12),
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
                          SizedBox(height: 8),
                          TextButton(
                            onPressed:
                                (!_otpGate.canSend || _resendBusy || busy)
                                ? null
                                : _resendOtp,
                            child: Text(kOtpResendLabel),
                          ),
                        ],
                        if (_otpSuccess != null && view != 'login')
                          Container(
                            width: double.infinity,
                            margin: const EdgeInsets.only(top: 12),
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: AppColors.success.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: AppColors.success.withValues(alpha: 0.4),
                              ),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.check_circle,
                                  color: AppColors.success,
                                ),
                                SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    _otpSuccess!,
                                    style: TextStyle(
                                      color: AppColors.success,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        if (_otpSuccess != null && view != 'login')
                          const Padding(
                            padding: EdgeInsets.only(top: 8),
                            child: Text(
                              kOtpReassureHint,
                              style: TextStyle(
                                fontSize: 12,
                                color: AppColors.greyText,
                              ),
                            ),
                          ),
                        if (error != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 12),
                            child: Text(
                              error!,
                              style: TextStyle(color: AppColors.error),
                            ),
                          ),
                        SizedBox(height: 20),
                        DriverActionButton(
                          label: view == 'login'
                              ? 'دخول'
                              : view == 'forgot'
                              ? 'إرسال الرمز'
                              : 'تغيير كلمة المرور',
                          loading: busy,
                          onPressed: busy
                              ? null
                              : (view == 'forgot' && !_otpGate.canSend)
                              ? null
                              : _submit,
                        ),
                        if (view != 'reset')
                          TextButton(
                            onPressed: busy
                                ? null
                                : () => setState(() {
                                    view = view == 'login' ? 'forgot' : 'login';
                                    error = null;
                                    _otpSuccess = null;
                                    _editingPhone = false;
                                    if (view == 'login') {
                                      _otpGate.cancelBackground();
                                    }
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
        if (!_otpGate.canSend) return;
        final result = await app.api.forgotPasswordOtp(mobile);
        if (!mounted) return;
        if (result.ok) {
          _otpGate.cancelBackground();
          _otpGate.lock(0, _onGateUnlock);
          _showOtpGreenSuccess();
          setState(() {
            view = 'reset';
            error = null;
            _otpSuccess = kOtpSuccessMessage;
            _editingPhone = false;
          });
        } else {
          final kind = classifyOtpResult(result.raw);
          final backendMsg = extractOtpMessage(result.raw);
          final retry = extractOtpRetryAfter(result.raw, backendMsg);
          if (kind == OtpSendKind.cooldown) {
            _otpGate.lock(retry, _onGateUnlock);
            _showOtpGreenSuccess();
            setState(() {
              view = 'reset';
              error = null;
              _otpSuccess = kOtpSuccessMessage;
              _editingPhone = false;
            });
            _scheduleOtpBackground(retry);
          } else if (kind == OtpSendKind.hardLimit) {
            _otpGate.lock(retry, _onGateUnlock);
            _otpGate.cancelBackground();
            final honest = backendMsg.isNotEmpty
                ? backendMsg
                : kOtpHardLimitFallback;
            setState(() {
              error = honest;
              _otpSuccess = null;
            });
          } else {
            setState(() => error = result.message);
          }
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
            _otpGate.cancelBackground();
            setState(() {
              view = 'login';
              error = 'تم تغيير كلمة المرور. سجّل الدخول الآن';
              _otpSuccess = null;
              _editingPhone = false;
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

/// مبيعات/أرباح آخر 7 أيام — مقابل weekly_sales في لوحة التاجر
/// (SellerController@index). تُبنى من sales_reports لنفس الفترة.
class WeeklyEarningsCard extends StatefulWidget {
  const WeeklyEarningsCard({super.key});

  @override
  State<WeeklyEarningsCard> createState() => _WeeklyEarningsCardState();
}

class _WeeklyEarningsCardState extends State<WeeklyEarningsCard> {
  List<double> values = [];
  List<String> labels = [];
  bool loading = true;

  String _iso(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final now = DateTime.now();
    final end = _iso(now);
    final start = _iso(now.subtract(const Duration(days: 6)));
    try {
      final res = await app.api.salesReports(startDate: start, endDate: end);
      if (!mounted) return;
      final rows = res.list('salesReports').isNotEmpty
          ? res.list('salesReports')
          : res.dataMaps;
      // تجميع حسب اليوم
      final totals = <String, double>{};
      for (var i = 6; i >= 0; i--) {
        totals[_iso(now.subtract(Duration(days: i)))] = 0;
      }
      // الباك يرسل added_date بصيغة DD-MM-YYYY — نوحّدها إلى YYYY-MM-DD
      String normDay(String raw) {
        final s = raw.trim();
        if (s.isEmpty) return '';
        if (RegExp(r'^\d{4}-\d{2}-\d{2}').hasMatch(s)) {
          return s.substring(0, 10);
        }
        final m = RegExp(r'^(\d{2})-(\d{2})-(\d{4})').firstMatch(s);
        if (m != null) return '${m.group(3)}-${m.group(2)}-${m.group(1)}';
        try {
          final d = DateTime.parse(s);
          return _iso(d);
        } catch (_) {
          return s.length >= 10 ? s.substring(0, 10) : s;
        }
      }

      for (final r in rows) {
        final day = normDay(
          J.str(r['order_date'] ?? r['added_date'] ?? r['created_at']),
        );
        final v = J.d(r['total_sale'] ?? r['sub_total'] ?? r['final_total']);
        if (totals.containsKey(day)) {
          totals[day] = (totals[day] ?? 0) + v;
        } else if (day.isNotEmpty) {
          totals[day] = (totals[day] ?? 0) + v;
        }
      }
      final keys = totals.keys.toList()..sort();
      final last7 = keys.length > 7 ? keys.sublist(keys.length - 7) : keys;
      setState(() {
        labels = last7.map((k) => k.substring(5)).toList();
        values = last7.map((k) => totals[k] ?? 0).toList();
        loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final maxV = values.isEmpty
        ? 0.0
        : values.reduce((a, b) => a > b ? a : b);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.greyBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.show_chart, size: 18, color: AppColors.navy),
              SizedBox(width: 8),
              Text(
                'نشاط آخر 7 أيام',
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  color: AppColors.navy,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (loading) const ChartSkeleton()
          else if (values.isEmpty || maxV <= 0)
            const Text(
              'لا توجد مبيعات مسجلة لهذا الأسبوع.',
              style: TextStyle(fontSize: 12, color: AppColors.greyText),
            )
          else
            SizedBox(
              height: 110,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: List.generate(values.length, (i) {
                  final h = maxV > 0 ? (values[i] / maxV).clamp(0.05, 1.0) : 0.05;
                  return Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 3),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Text(
                            values[i] > 0
                                ? values[i].toStringAsFixed(0)
                                : '',
                            style: const TextStyle(
                              fontSize: 9,
                              color: AppColors.greyText,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Container(
                            height: 64 * h,
                            decoration: BoxDecoration(
                              color: AppColors.orange.withValues(
                                alpha: i == values.length - 1 ? 1 : 0.45,
                              ),
                              borderRadius: BorderRadius.circular(6),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            labels[i],
                            style: const TextStyle(
                              fontSize: 8,
                              color: AppColors.greyText,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }),
              ),
            ),
        ],
      ),
    );
  }
}

class _HomeScreenState extends State<HomeScreen> {
  // ===== Home.vue حرفياً =====
  // GET collection/home -> todays_deliveries, cash_to_collect,
  // amount_to_return, amount_owed_to_you, your_earnings, over_cash_limit
  // fallback: GET workload
  Map<String, dynamic> home = {
    'todays_deliveries': 0,
    'cash_to_collect': 0,
    'amount_to_return': 0,
    'amount_owed_to_you': 0,
    'your_earnings': 0,
  };
  bool overLimit = false;
  bool homeLoading = false;

  @override
  void initState() {
    super.initState();
    app.refreshWorkload();
    _loadHome();
    if (app.isOnline) app.startOrderPolling();
  }

  Future<void> _loadHome() async {
    setState(() => homeLoading = true);
    final res = await app.api.collectionHome();
    if (!mounted) return;
    if (res.ok) {
      final d = res.dataMap;
      setState(() {
        home = {
          'todays_deliveries': d['todays_deliveries'] ?? 0,
          'cash_to_collect': d['cash_to_collect'] ?? 0,
          'amount_to_return': d['amount_to_return'] ?? 0,
          'amount_owed_to_you': d['amount_owed_to_you'] ?? 0,
          'your_earnings': d['your_earnings'] ?? 0,
        };
        overLimit = d['over_cash_limit'] == true ||
            d['over_cash_limit'] == 1 ||
            d['over_cash_limit'] == '1';
        homeLoading = false;
      });
      return;
    }
    // fallback: workload — نفس Home.vue catch
    try {
      final w = await app.api.workload();
      if (!mounted) return;
      final wd = w.dataMap;
      final f = J.map(wd['finance']);
      final net = J.d(f['net_to_remit']);
      setState(() {
        home = {
          'todays_deliveries': wd['active_assignment_count'] ?? 0,
          'cash_to_collect': wd['cod_liability'] ?? 0,
          'amount_to_return': net > 0 ? net : 0,
          'amount_owed_to_you': net < 0 ? -net : 0,
          'your_earnings': f['earnings_balance'] ?? 0,
        };
        overLimit = f['over_cash_limit'] == true ||
            f['over_cash_limit'] == 1 ||
            f['over_cash_limit'] == '1';
        homeLoading = false;
      });
    } catch (_) {
      if (mounted) setState(() => homeLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: app,
      builder: (context, _) {
        final cur = app.brand.identity['currency'] ?? '';
        String money(dynamic v) => cur.isNotEmpty ? '$cur $v' : '$v';
        final owed = J.d(home['amount_owed_to_you']);
        final toReturn = J.d(home['amount_to_return']);
        // Home.vue cards(): إن وُجد مستحق لك → بطاقة "مستحق لك" وإلا "مطلوب توريده"
        final settlementLabel = owed > 0 ? 'مستحق لك' : 'مطلوب توريده';
        final settlementValue = owed > 0 ? owed : toReturn;
        final settlementAccent = owed > 0 ? AppColors.success : Colors.red;

        return Stack(
          children: [
            RefreshIndicator(
              color: AppColors.orange,
              onRefresh: _loadHome,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                children: [
                  const Text(
                    'الرئيسية',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
                  ),
                  if (overLimit)
                    Container(
                      margin: const EdgeInsets.only(top: 12),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.red.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: Colors.red.withValues(alpha: 0.4),
                        ),
                      ),
                      child: const Text(
                        'تجاوزت سقف النقدية — لن تُسند لك مهام جديدة حتى تورّد النقدية من صفحة محفظتي.',
                        style: TextStyle(
                          color: Colors.red,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  const SizedBox(height: 16),
                  LayoutBuilder(builder: (context, constraints) {
                    final isTablet = constraints.maxWidth > 600;
                    return GridView.count(
                      crossAxisCount: isTablet ? 4 : 2,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      mainAxisSpacing: 10,
                      crossAxisSpacing: 10,
                      childAspectRatio: isTablet ? 1.1 : 0.95,
                      children: [
                        KpiCard(
                          icon: Icons.shopping_cart_outlined,
                          label: 'طلبات اليوم',
                          value: '${home['todays_deliveries'] ?? 0}',
                          onTap: () => context.go('/orders'),
                        ),
                        KpiCard(
                          icon: Icons.payments_outlined,
                          label: 'متبقي للتحصيل',
                          value: money(home['cash_to_collect'] ?? 0),
                          accent: AppColors.success,
                          onTap: () => context.go('/orders'),
                        ),
                        KpiCard(
                          icon: Icons.handshake_outlined,
                          label: settlementLabel,
                          value: money(settlementValue),
                          accent: settlementAccent,
                          onTap: () => context.go('/wallet'),
                        ),
                        KpiCard(
                          icon: Icons.star_outline,
                          label: 'أرباحي',
                          value: money(home['your_earnings'] ?? 0),
                          accent: Colors.purple,
                          onTap: () => context.go('/wallet'),
                        ),
                      ],
                    );
                  }),
                  const SizedBox(height: 12),
                  DriverActionButton(
                    label: 'عرض الطلبات',
                    icon: Icons.shopping_cart,
                    onPressed: () => context.go('/orders'),
                  ),
                  if (homeLoading)
                    const Padding(
                      padding: EdgeInsets.only(top: 12),
                      child: Center(
                        child: SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            if (app.incomingAssignment != null || app.incomingOrder != null)
              Builder(builder: (context) {
                final raw = app.incomingAssignment ?? app.incomingOrder!;
                final isAssignment = app.incomingAssignment != null;
                final overlayOrder = isAssignment
                    ? {
                        'id': raw['id'],
                        'store_name': AssignmentHelper.storeName(raw),
                        'address': AssignmentHelper.addressOf(raw),
                        'distance': raw['distance'] ?? '—',
                        'delivery_charge':
                            raw['cod_to_collect'] ?? raw['delivery_charge'] ?? '—',
                      }
                    : raw;
                return IncomingOrderOverlay(
                  order: overlayOrder,
                  onAccept: () async {
                    final id = '${raw['id']}';
                    app.dismissIncomingOrder();
                    if (isAssignment) {
                      final res = await app.api.acceptAssignment(id);
                      if (!context.mounted) return;
                      if (!res.ok) {
                        toast(
                          context,
                          res.message.isEmpty
                              ? 'فشل قبول الطلب'
                              : res.message,
                        );
                        return;
                      }
                    }
                    if (!context.mounted) return;
                    // بعد القبول → تفاصيل التحصيل (MyOrder.vue)
                    context.push('/order/$id');
                  },
                  onDecline: app.dismissIncomingOrder,
                );
              }),
          ],
        );
      },
    );
  }
}

/// بطاقة عدّاد مصغرة لشريط ملخص الطلبات — بنفس الهوية.
class _SummaryStat extends StatelessWidget {
  const _SummaryStat({
    required this.label,
    required this.count,
    required this.icon,
    required this.active,
    required this.onTap,
    this.accent,
  });

  final String label;
  final int count;
  final IconData icon;
  final bool active;
  final VoidCallback onTap;
  final Color? accent;

  @override
  Widget build(BuildContext context) {
    final c = accent ?? AppColors.orange;
    return Expanded(
      child: Material(
        color: active ? AppColors.navy : AppColors.white,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: active ? AppColors.navy : AppColors.greyBorder,
              ),
              boxShadow: AppColors.cardShadow,
            ),
            child: Column(
              children: [
                Icon(
                  icon,
                  size: 18,
                  color: active ? AppColors.orange : c,
                ),
                const SizedBox(height: 4),
                Text(
                  '$count',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: active ? AppColors.white : AppColors.navy,
                  ),
                ),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11,
                    color: active
                        ? AppColors.white.withValues(alpha: 0.75)
                        : AppColors.greyText,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class OrdersScreen extends StatefulWidget {
  const OrdersScreen({super.key, this.type, this.returnsOnly = false});
  final int? type;
  final bool returnsOnly;

  @override
  State<OrdersScreen> createState() => _OrdersScreenState();
}

class _OrdersScreenState extends State<OrdersScreen> {
  List<Map<String, dynamic>> items = [];
  List<Map<String, dynamic>> filtered = [];
  bool loading = true;
  String? error;
  String? quickBusyId;
  int? type;
  // فلاتر السيرفر (listAssignments): status/startDate/endDate/search
  // طبق الأصل DeliveryBoyAssignmentApiController::listAssignments
  String search = '';
  String statusFilter = '';
  String startDate = '';
  String endDate = '';
  // مرتجعات للاستلام — مقابل return_requests عند التاجر
  bool returnsOnly = false;
  final _searchCtrl = TextEditingController();
  Timer? _searchDebounce;

  bool _isActiveItem(Map<String, dynamic> m) {
    if (m['_legacy'] == true) return type == 1;
    final st = J.str(m['status']).toLowerCase();
    return st != 'delivered' && st != 'cancelled' && st != 'failed';
  }

  int get _countAll => items.length;
  int get _countActive => items.where(_isActiveItem).length;
  int get _countDone => items.length - _countActive;
  int get _countReturns =>
      items.where((m) => AssignmentHelper.isReturnPickup(m)).length;

  @override
  void initState() {
    super.initState();
    type = widget.type;
    returnsOnly = widget.returnsOnly;
    _load();
  }

  @override
  void didUpdateWidget(covariant OrdersScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.type != widget.type) {
      type = widget.type;
      _applyFilter();
    }
    if (oldWidget.returnsOnly != widget.returnsOnly) {
      returnsOnly = widget.returnsOnly;
      _applyFilter();
    }
  }

  Future<void> _load() async {
    setState(() {
      loading = true;
      error = null;
    });
    // Modern: assignments paginated (DeliveryBoyAssignmentApiController::listAssignments)
    // يدعم status/startDate/endDate/search/page — نمررها للسيرفر بدل الفلترة المحلية فقط
    final result = await app.api.assignments(
      page: 1,
      status: statusFilter.isNotEmpty ? statusFilter : null,
      startDate: startDate.isNotEmpty ? startDate : null,
      endDate: endDate.isNotEmpty ? endDate : null,
      search: search.isNotEmpty ? search : null,
    );
    if (!mounted) return;
    List<Map<String, dynamic>> all = [];
    if (result.dataMap.containsKey('data') && result.dataMap['data'] is List) {
      all = J.maps(result.dataMap['data']);
    } else {
      all = result.dataMaps.isNotEmpty ? result.dataMaps : result.list('data');
    }
    // fallback legacy if modern empty
    if (all.isEmpty && result.ok) {
      final legacy = await app.api.orders(type: type);
      if (!mounted) return;
      all = legacy.list('orders').isNotEmpty ? legacy.list('orders') : legacy.dataMaps;
      // tag legacy
      for (final m in all) {
        m['_legacy'] = true;
      }
    }
    if (!mounted) return;
    setState(() {
      items = all;
      loading = false;
      if (!result.ok) error = result.failMessage;
    });
    _applyFilter();
  }

  void _applyFilter() {
    var base = List<Map<String, dynamic>>.from(items);
    // مرتجعات أولاً (is_return_pickup / assignment_type=return_pickup)
    if (returnsOnly) {
      base = base
          .where((m) => AssignmentHelper.isReturnPickup(m))
          .toList();
    }
    if (type == null) {
      filtered = base;
    } else if (type == 1) {
      // جارية: not delivered/cancelled/failed (Workload definition)
      filtered = base.where((m) {
        if (m['_legacy'] == true) return true; // legacy already filtered by type=1
        final st = J.str(m['status']).toLowerCase();
        return st != 'delivered' && st != 'cancelled' && st != 'failed';
      }).toList();
    } else {
      // سابقة
      filtered = base.where((m) {
        if (m['_legacy'] == true) return true;
        final st = J.str(m['status']).toLowerCase();
        return st == 'delivered' || st == 'cancelled' || st == 'failed';
      }).toList();
    }
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchCtrl.dispose();
    super.dispose();
  }

  void _onSearchChanged(String v) {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 600), () {
      final q = v.trim();
      if (q == search) return;
      search = q;
      _load();
    });
  }

  void _clearSearch() {
    _searchDebounce?.cancel();
    _searchCtrl.clear();
    if (search.isEmpty) return;
    search = '';
    _load();
  }

  /// تقدم سريع من البطاقة — مثل زر Next في صفحة courier (بلا حوارات).
  Future<void> _quickAdvance(String id, String status) async {
    if (quickBusyId != null) return;
    setState(() => quickBusyId = id);
    final ApiResult res;
    if (status == AssignmentStatus.accepted.apiValue) {
      res = await app.api.acceptAssignment(id);
    } else {
      res = await app.api.updateAssignmentStatus(id: id, status: status);
    }
    if (!mounted) return;
    setState(() => quickBusyId = null);
    if (!res.ok) {
      toast(context, res.message);
      return;
    }
    toast(context, 'تم التحديث');
    _load();
  }

  @override
  Widget build(BuildContext context) {
    final display = filtered;
    const serverStatuses = [
      '',
      'assigned',
      'accepted',
      'picking_up',
      'picked_up',
      'out_for_delivery',
      'delivered',
      'failed',
      'cancelled',
    ];
    return Column(
      children: [
        // شريط ملخص سريع — وصول بلمسة واحدة لكل مجموعة
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: Row(
            children: [
              _SummaryStat(
                label: 'الكل',
                count: _countAll,
                icon: Icons.apps_outlined,
                active: type == null && !returnsOnly,
                onTap: () {
                  setState(() {
                    type = null;
                    returnsOnly = false;
                  });
                  _applyFilter();
                },
              ),
              const SizedBox(width: 8),
              _SummaryStat(
                label: 'جارية',
                count: _countActive,
                icon: Icons.local_shipping_outlined,
                accent: AppColors.orange,
                active: type == 1 && !returnsOnly,
                onTap: () {
                  setState(() {
                    type = 1;
                    returnsOnly = false;
                  });
                  _applyFilter();
                },
              ),
              const SizedBox(width: 8),
              _SummaryStat(
                label: 'سابقة',
                count: _countDone,
                icon: Icons.history_outlined,
                accent: AppColors.navy,
                active: type == 0 && !returnsOnly,
                onTap: () {
                  setState(() {
                    type = 0;
                    returnsOnly = false;
                  });
                  _applyFilter();
                },
              ),
              const SizedBox(width: 8),
              _SummaryStat(
                label: 'مرتجعات',
                count: _countReturns,
                icon: Icons.assignment_return_outlined,
                accent: AppColors.navy,
                active: returnsOnly,
                onTap: () {
                  setState(() => returnsOnly = !returnsOnly);
                  _applyFilter();
                },
              ),
            ],
          ),
        ),
        FilterChips(
          selected: type,
          counts: {null: _countAll, 1: _countActive, 0: _countDone},
          onSelected: (v) {
            setState(() => type = v);
            _applyFilter();
          },
        ),
        // بحث + فلترة حالة + فلترة تاريخ من السيرفر (id/group_id/public_id/mobile)
        // طبق الأصل listAssignments: status/startDate/endDate/search
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: Row(
            children: [
              Expanded(
                child: ValueListenableBuilder<TextEditingValue>(
                  valueListenable: _searchCtrl,
                  builder: (context, value, _) {
                    return TextField(
                      controller: _searchCtrl,
                      decoration: InputDecoration(
                        hintText: 'بحث برقم الطلب أو الجوال...',
                        prefixIcon: const Icon(Icons.search, size: 18),
                        suffixIcon: value.text.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear, size: 18),
                                onPressed: _clearSearch,
                              )
                            : null,
                        isDense: true,
                      ),
                      textInputAction: TextInputAction.search,
                      onChanged: _onSearchChanged,
                      onSubmitted: (v) {
                        _searchDebounce?.cancel();
                        search = v.trim();
                        _load();
                      },
                    );
                  },
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                decoration: BoxDecoration(
                  color: AppColors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.greyBorder),
                ),
                child: DropdownButton<String>(
                  value: statusFilter,
                  hint: const Text('الحالة', style: TextStyle(fontSize: 12)),
                  underline: const SizedBox.shrink(),
                  items: serverStatuses
                      .map((s) => DropdownMenuItem(
                            value: s,
                            child: Text(
                                s.isEmpty ? 'الكل' : (AssignmentStatus.fromString(s)?.labelAr ?? s),
                                style: const TextStyle(fontSize: 12)),
                          ))
                      .toList(),
                  onChanged: (v) {
                    setState(() => statusFilter = v ?? '');
                    _load();
                  },
                ),
              ),
            ],
          ),
        ),
        // فلتر التاريخ — مثل getOrders في الباك اند (startDate/endDate)
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: InkWell(
            onTap: () async {
              final s = await pickDate(context);
              if (s == null || !context.mounted) return;
              final e = await pickDate(context, initial: DateTime.now());
              if (e == null || !context.mounted) return;
              setState(() {
                startDate = s;
                endDate = e;
              });
              _load();
            },
            borderRadius: BorderRadius.circular(14),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: AppColors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.greyBorder),
              ),
              child: Row(
                children: [
                  const Icon(Icons.date_range, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      (startDate.isEmpty || endDate.isEmpty)
                          ? 'كل الفترات'
                          : 'من $startDate إلى $endDate',
                      style: const TextStyle(fontSize: 12),
                    ),
                  ),
                  if (startDate.isNotEmpty)
                    InkWell(
                      onTap: () {
                        setState(() {
                          startDate = '';
                          endDate = '';
                        });
                        _load();
                      },
                      child: const Icon(Icons.clear, size: 18),
                    ),
                ],
              ),
            ),
          ),
        ),
        Expanded(
          child: FetchBody(
            loading: loading,
            onRefresh: _load,
            isEmpty: display.isEmpty,
            error: error,
            emptyText: 'لا توجد طلبات',
            emptyIcon: Icons.local_shipping_outlined,
            emptyActionLabel: 'إعادة المحاولة',
            onEmptyAction: _load,
            child: ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: display.length,
              separatorBuilder: (_, __) => SizedBox(height: 10),
              itemBuilder: (_, i) {
                final raw = display[i];
                final isLegacy = raw['_legacy'] == true;
                final id = '${raw['id']}';
                final statusStr = J.str(raw['status'] ?? raw['order_status']);
                final customerName = isLegacy
                    ? J.str(raw['user_name'])
                    : AssignmentHelper.customerNameOf(raw);
                final address = isLegacy
                    ? J.str(raw['address'])
                    : AssignmentHelper.addressOf(raw);
                final total = isLegacy
                    ? J.str(raw['final_total'])
                    : '${AssignmentHelper.finalTotalOf(raw).toStringAsFixed(2)}';
                final statusLabel = isLegacy
                    ? statusStr
                    : AssignmentStatus.fromString(statusStr)?.labelAr ?? statusStr;
                final isActive = isLegacy
                    ? type == 1
                    : (AssignmentStatus.fromString(statusStr)?.isActive ?? type == 1);
                // حقول صفحة courier: public_id + المتبقي + الإلغاء + primary
                final publicId = isLegacy
                    ? ''
                    : AssignmentHelper.orderPublicId(raw);
                final remaining = isLegacy
                    ? 0.0
                    : AssignmentHelper.defaultCodCollected(raw);
                final cancelled = !isLegacy &&
                    AssignmentHelper.orderCancelled(raw);
                final primary = isLegacy
                    ? null
                    : AssignmentHelper.primaryNext(raw);
                final st = isLegacy
                    ? null
                    : AssignmentStatus.fromString(primary ?? '');
                // التقدم السريع المباشر فقط للحالات بلا حوارات (مثل الويب)؛
                // failed/cancelled/delivered (مع متبقي) تُفتح في التفاصيل.
                final needsDialog = st == null ||
                    st == AssignmentStatus.failed ||
                    st == AssignmentStatus.cancelled ||
                    (st == AssignmentStatus.delivered && remaining > 0);
                final quickLabel = (!isLegacy &&
                        primary != null &&
                        !cancelled &&
                        st != null)
                    ? 'التالي: ${st.labelAr}'
                    : null;
                return OrderListCard(
                  orderId: id,
                  customerName: customerName,
                  address: address,
                  total: total,
                  status: statusLabel,
                  isActive: isActive,
                  isReturn: !isLegacy &&
                      AssignmentHelper.isReturnPickup(raw),
                  publicId: publicId,
                  remainingCod: remaining > 0
                      ? remaining.toStringAsFixed(2)
                      : null,
                  cancelled: cancelled,
                  quickLabel: quickLabel,
                  quickBusy: quickBusyId == id,
                  onQuickAdvance: quickLabel == null
                      ? null
                      : () {
                          if (needsDialog) {
                            context.push('/order/$id');
                          } else {
                            _quickAdvance(id, primary!);
                          }
                        },
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
  Map<String, dynamic>? assignment;
  bool isLegacy = false;
  // الحالات من السيرفر (allowed_next_statuses) — المصدر الوحيد الموثوق
  List<String> allowedNext = [];
  String? primaryNext;
  bool requiresAccept = false;
  bool canCancel = false;
  bool orderCancelled = false;
  List<String> nextStatuses = [];
  bool loading = true;
  bool failed = false;
  bool updating = false;
  String? proofPhotoPath;

  List<AssignmentStatus> get _nextParsed => allowedNext
      .map((s) => AssignmentStatus.fromString(s))
      .whereType<AssignmentStatus>()
      .toList();

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    // Modern: assignmentById (DeliveryBoyAssignmentApiController::show)
    var result = await app.api.assignmentById(widget.id);    Map<String, dynamic>? data = result.dataMaps.isNotEmpty
        ? result.dataMaps.first
        : result.dataMap;
    // fallback legacy
    if (data.isEmpty || !result.ok) {
      final legacy = await app.api.orderById(widget.id);
      data = legacy.dataMaps.isNotEmpty ? legacy.dataMaps.first : legacy.dataMap;
      isLegacy = true;
      if (!mounted) return;
      setState(() {
        assignment = data;
        allowedNext = [];
        primaryNext = null;
        requiresAccept = false;
        canCancel = false;
        orderCancelled = false;
        nextStatuses = [];
        loading = false;
        failed = !legacy.ok || (assignment == null || assignment!.isEmpty);
      });
      return;
    }
    isLegacy = false;
    // طبق الأصل withStatusMeta: allowed_next_statuses / primary_next_status /
    // requires_accept / can_cancel / order_cancelled
    final Map<String, dynamic> m = data;
    final allowed = AssignmentHelper.allowedNext(m);
    if (!mounted) return;
    setState(() {
      assignment = m;
      allowedNext = allowed;
      primaryNext = AssignmentHelper.primaryNext(m);
      requiresAccept = AssignmentHelper.requiresAccept(m);
      canCancel = AssignmentHelper.canCancel(m);
      orderCancelled = AssignmentHelper.orderCancelled(m);
      nextStatuses = [];
      loading = false;
      failed = !result.ok || assignment!.isEmpty;
    });
  }

  Future<void> _handleStatusTap(AssignmentStatus target) async {
    if (target == AssignmentStatus.delivered && proofPhotoPath == null) {
      await _showProofModal(target);
      return;
    }
    if (target == AssignmentStatus.failed || target == AssignmentStatus.cancelled) {
      await _showFailureReasonDialog(target);
      return;
    }
    if (target == AssignmentStatus.delivered) {
      await _showCodDialog(target);
      return;
    }
    final ok = await confirmAction(
      context,
      title: 'تحديث الحالة',
      body: 'تغيير الحالة إلى ${target.labelAr}؟',
    );
    if (!ok || !mounted) return;
    await _performAssignmentUpdate(target);
  }

  // إثبات التسليم اختياري — الصورة محلية للتأكيد فقط ولا تُرفع للسيرفر
  // (الباك يقبل status/cod_collected فقط)، لذلك يوجد زر تخطي دائماً.
  Future<void> _showProofModal(AssignmentStatus target) async {
    final action = await showModalBottomSheet<String>(
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
            if (mounted) setState(() => proofPhotoPath = file.path);
            Navigator.pop(ctx, 'photo');
          }
        },
        onFromGallery: () async {
          final file = await ImagePicker().pickImage(
            source: ImageSource.gallery,
            requestFullMetadata: false,
          );
          if (!ctx.mounted) return;
          if (file != null) {
            if (mounted) setState(() => proofPhotoPath = file.path);
            Navigator.pop(ctx, 'photo');
          }
        },
        onSkip: () => Navigator.pop(ctx, 'skip'),
      ),
    );
    if (!mounted) return;
    if (action == 'photo' || action == 'skip') {
      await _showCodDialog(target);
    }
  }

  Future<void> _showPaySellerDialog() async {
    final a = assignment ?? {};
    final suggest = AssignmentHelper.codToCollect(a) > 0
        ? AssignmentHelper.codToCollect(a)
        : AssignmentHelper.finalTotalOf(a);
    final ctrl = TextEditingController(
        text: suggest > 0 ? suggest.toStringAsFixed(2) : '');
    String paidFrom = 'self';
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setD) => AlertDialog(
          title: const Text('دفعت للمتجر'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: ctrl,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  labelText: 'المبلغ المدفوع للمتجر',
                  hintText: '0.00',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              SegmentedButton<String>(
                segments: const [
                  ButtonSegment(value: 'self', label: Text('من جيبي'), icon: Icon(Icons.wallet_outlined)),
                  ButtonSegment(value: 'float', label: Text('من العهدة'), icon: Icon(Icons.account_balance_outlined)),
                ],
                selected: {paidFrom},
                onSelectionChanged: (s) => setD(() => paidFrom = s.first),
              ),
              const SizedBox(height: 8),
              const Text(
                'من العهدة: يُخصم من رصيد المنصة لديك. من جيبي: يُسجل ذمة لك تُخصم عند التوريد.',
                style: TextStyle(fontSize: 11, color: AppColors.greyText),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء')),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('تسجيل')),
          ],
        ),
      ),
    );
    final text = ctrl.text.trim();
    ctrl.dispose();
    if (ok != true || !context.mounted) return;
    final val = double.tryParse(text);
    if (val == null || val <= 0) {
      if (context.mounted) toast(context, 'المبلغ غير صحيح');
      return;
    }
    setState(() => updating = true);
    final res = await app.api.paySeller(
      assignmentId: a['id'] ?? widget.id,
      amount: val.toStringAsFixed(2),
      paidFrom: paidFrom,
    );
    if (!mounted) return;
    setState(() => updating = false);
    if (!context.mounted) return;
    toast(context, res.ok ? 'تم تسجيل الدفع للمتجر' : res.message);
    if (res.ok) _load();
  }

  Future<void> _showCodDialog(AssignmentStatus target) async {
    // الباك اند: default_cod_collected = المتبقي (to_collect - collected)
    // وإن لم يُرسل cod_collected مع delivered يعبّئ المتبقي تلقائياً،
    // لكن مع COD مستحق يجب تسجيل المبلغ قبل التسليم وإلا يرجع خطأ.
    final serverDefault = assignment != null
        ? AssignmentHelper.defaultCodCollected(assignment!)
        : 0;
    final liability = assignment != null
        ? AssignmentHelper.codLiability(assignment!)
        : 0;
    final prefill = serverDefault > 0
        ? serverDefault
        : (liability > 0 ? liability : 0);
    final ctrl = TextEditingController(
        text: prefill > 0 ? prefill.toStringAsFixed(2) : '');
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('المبلغ المحصّل'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('المطلوب تحصيله: ${liability.toStringAsFixed(2)}'),
            SizedBox(height: 12),
            TextField(
              controller: ctrl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(labelText: 'المبلغ المحصّل (COD)', hintText: '0.00'),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text('إلغاء')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: Text('تأكيد')),
        ],
      ),
    );
    final isGone = !context.mounted;
    final text = ctrl.text.trim();
    ctrl.dispose();
    if (ok != true || isGone) return;
    final val = double.tryParse(text);
    if (val != null && val < 0) {
      if (context.mounted) toast(context, 'المبلغ غير صحيح');
      return;
    }
    // confirm
    final confirm = await confirmAction(
      context,
      title: 'تحديث الحالة',
      body: 'تغيير الحالة إلى ${target.labelAr}؟',
    );
    if (!confirm || !context.mounted) return;
    await _performAssignmentUpdate(target, codCollected: val);
  }

  Future<void> _showFailureReasonDialog(AssignmentStatus target) async {
    final ctrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(target == AssignmentStatus.failed ? 'سبب الفشل' : 'سبب الإلغاء'),
        content: TextField(
          controller: ctrl,
          maxLines: 3,
          maxLength: 500,
          decoration: const InputDecoration(hintText: 'اكتب السبب...', border: OutlineInputBorder()),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text('إلغاء')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: Text('إرسال')),
        ],
      ),
    );
    final reason = ctrl.text.trim();
    ctrl.dispose();
    if (ok != true || !context.mounted) return;
    if (reason.isEmpty) {
      toast(context, 'السبب مطلوب');
      return;
    }
    await _performAssignmentUpdate(target, failureReason: reason);
  }

  Future<void> _performAssignmentUpdate(AssignmentStatus target, {String? failureReason, double? codCollected}) async {
    setState(() => updating = true);
    ApiResult result;
    if (target == AssignmentStatus.accepted) {
      result = await app.api.acceptAssignment(widget.id);
      // مهام الأدمن ترجع نجاحاً مباشرة، والمهام المقبولة مسبقاً تفشل —
      // نحاول status API كبديل لأي فشل قبول
      if (!result.ok) {
        result = await app.api.updateAssignmentStatus(id: widget.id, status: target.apiValue, failureReason: failureReason, codCollected: codCollected);
      }
    } else {
      result = await app.api.updateAssignmentStatus(
        id: widget.id,
        status: target.apiValue,
        failureReason: failureReason,
        codCollected: codCollected,
      );
    }
    if (!mounted) return;
    setState(() => updating = false);
    if (!context.mounted) return;
    toast(context, result.ok ? 'تم التحديث' : result.message);
    if (result.ok) _load();
  }

  Future<void> _reload() async {
    setState(() {
      loading = true;
      failed = false;
    });
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return Scaffold(
        appBar: AppBar(title: Text('طلب #${widget.id}')),
        body: const DetailsSkeleton(),
      );
    }
    if (failed) {      return Scaffold(
        appBar: AppBar(title: Text('طلب ${widget.id}')),
        body: Refreshable(
          onRefresh: _reload,
          child: EmptyBox(
            'تعذر تحميل الطلب',
            icon: Icons.error_outline,
            actionLabel: 'إعادة المحاولة',
            onAction: _reload,
          ),
        ),
      );
    }

    final a = assignment ?? {};
    final items = isLegacy
        ? J.maps(a['items'] ?? a['order_items'])
        : AssignmentHelper.itemsOf(a);
    final mobile = isLegacy ? J.str(a['mobile']) : AssignmentHelper.mobileOf(a);
    final address = isLegacy ? J.str(a['address']) : AssignmentHelper.addressOf(a);
    final storeName = isLegacy
        ? J.str(a['store_name'] ?? a['seller_name'] ?? 'المتجر')
        : AssignmentHelper.storeName(a);
    final currentStatusStr = J.str(a['status'] ?? a['order_status'] ?? 'assigned');
    final currentStatus = AssignmentStatus.fromString(currentStatusStr);
    // طبق الأصل withStatusMeta: full_timeline + timeline_labels من السيرفر أولاً،
    // ثم courierVisibleTimeline، ثم الثابت المحلي للتوافق.
    List<String> serverTimeline = AssignmentHelper.fullTimeline(a);
    Map<String, String> serverLabels = AssignmentHelper.timelineLabels(a);
    List<String> steps;
    int stepIndex;
    if (!isLegacy && serverTimeline.isNotEmpty) {
      steps = serverTimeline
          .map((s) =>
              serverLabels[s]?.isNotEmpty == true
                  ? serverLabels[s]!
                  : (AssignmentStatus.fromString(s)?.labelAr ?? s))
          .toList();
      final idx = serverTimeline.indexWhere(
          (s) => s.toLowerCase() == currentStatusStr.toLowerCase());
      stepIndex = idx >= 0 ? idx : steps.length - 1;
      // المرتجع له 5 خطوات بدون picking_up — نعرضها كما يرسلها السيرفر تماماً.
    } else if (!isLegacy && currentStatus != null) {
      final visible =
          AssignmentStatus.courierVisibleTimeline(currentStatus);
      steps = visible.map((e) => e.labelAr).toList();
      final idx = visible.indexOf(currentStatus);
      stepIndex = idx >= 0 ? idx : 0;
    } else {
      steps = kAssignmentSteps;
      stepIndex = currentStatus != null
          ? timelineIndexFromAssignmentStatus(
              currentStatus.apiValue, kAssignmentSteps)
          : timelineIndexFromStatus(currentStatusStr, kAssignmentSteps);
    }
    final codToCollect = isLegacy ? 0.0 : AssignmentHelper.codToCollect(a);
    final codCollected = isLegacy ? 0.0 : AssignmentHelper.codCollected(a);
    final codLiability = (codToCollect - codCollected).clamp(0, double.infinity);

    return Scaffold(
      backgroundColor: AppColors.greyBg,
      appBar: AppBar(
        title: Text('طلب #${widget.id}'),
        actions: [
          IconButton(
            icon: Icon(Icons.map_outlined),
            onPressed: () => context.push('/delivery/${widget.id}'),
            tooltip: 'عرض الخريطة',
          ),
        ],
      ),
      body: RefreshIndicator(
        color: AppColors.orange,
        onRefresh: _load,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
        children: [
          DeliveryMapView(
            pickupLabel: storeName,
            dropoffLabel: address,
            onNavigate: () => openMapsNavigation(address),
          ),
          SizedBox(height: 16),
          OrderProgressTimeline(
            steps: steps,
            currentIndex: stepIndex,
          ),
          SizedBox(height: 16),
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
                  isLegacy ? J.str(a['user_name']) : AssignmentHelper.customerNameOf(a),
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: AppColors.navy,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  address,
                  style: const TextStyle(color: AppColors.greyText),
                ),
                if (!isLegacy) ...[
                  SizedBox(height: 8),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.orange.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          isLegacy
                              ? (currentStatus?.labelAr ?? currentStatusStr)
                              : AssignmentHelper.statusLabel(
                                  a, currentStatus ?? AssignmentStatus.assigned),
                          style: TextStyle(fontSize: 12, color: AppColors.orange, fontWeight: FontWeight.w700),
                        ),
                      ),
                      SizedBox(width: 8),
                      Text('ID: ${a['id']}', style: const TextStyle(fontSize: 12, color: AppColors.greyText)),
                    ],
                  ),
                  if (codToCollect > 0) ...[
                    SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(color: AppColors.greyBg, borderRadius: BorderRadius.circular(12)),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('المطلوب تحصيله', style: TextStyle(fontSize: 12, color: AppColors.greyText)),
                          Text('${codLiability.toStringAsFixed(2)} / ${codToCollect.toStringAsFixed(2)}', style: TextStyle(fontWeight: FontWeight.w800, color: AppColors.navy)),
                        ],
                      ),
                    ),
                  ],
                  // بطاقة الدفع المسبق للمتجر (جديد): تعرض ما دُفع + زر التسجيل.
                  if (!isLegacy) ...[
                    SizedBox(height: 8),
                    Builder(builder: (_) {
                      final paid = AssignmentHelper.paidToSeller(a);
                      final from = AssignmentHelper.paidFrom(a);
                      final payer = AssignmentHelper.payerMode(a);
                      final isClosed = currentStatus?.isTerminal ?? false;
                      final platformPaid = paid > 0 && from == 'platform';
                      return Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: paid > 0
                              ? AppColors.success.withValues(alpha: 0.08)
                              : AppColors.orange.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: paid > 0 ? AppColors.success : AppColors.orange,
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Text(
                                    platformPaid
                                        ? 'المنصة دفعت للمتجر: ${paid.toStringAsFixed(2)} — لا تدفع شيئاً'
                                        : paid > 0
                                            ? 'مدفوع للمتجر: ${paid.toStringAsFixed(2)} (${from == 'float' ? 'من العهدة' : 'من جيبي'})'
                                            : payer == 'platform'
                                                ? 'الدفع للمتجر على المنصة — لا تدفع من جيبك'
                                                : payer == 'float'
                                                    ? 'المطلوب: ادفع للمتجر من العهدة (${codToCollect.toStringAsFixed(2)})'
                                                    : 'لم تدفع للمتجر بعد — المطلوب نحو ${codToCollect.toStringAsFixed(2)}',
                                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                                  ),
                                ),
                                if (paid > 0)
                                  Icon(Icons.check_circle, color: AppColors.success, size: 18),
                              ],
                            ),
                            if (paid <= 0 && payer != 'platform' && !isClosed && !orderCancelled) ...[
                              const SizedBox(height: 8),
                              SizedBox(
                                width: double.infinity,
                                child: OutlinedButton.icon(
                                  icon: const Icon(Icons.store_outlined, size: 18),
                                  label: const Text('دفعت للمتجر — تسجيل المبلغ'),
                                  onPressed: () => _showPaySellerDialog(),
                                ),
                              ),
                              const Text(
                                'سجّل ما دفعته مقدماً لصاحب المتجر ليُخصم من تسويتك ولا تُطالب بتوريده.',
                                style: TextStyle(fontSize: 11, color: AppColors.greyText),
                              ),
                            ],
                          ],
                        ),
                      );
                    }),
                  ],
                ],
                if (mobile.isNotEmpty) ...[
                  SizedBox(height: 12),
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
          // بطاقة المرتجع (assignment_type=return_pickup) — طبق الأصل الباك اند
          if (!isLegacy && AssignmentHelper.isReturnPickup(a)) ...[
            Builder(builder: (_) {
              final ri = AssignmentHelper.returnItem(a);
              return Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.orange),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('استلام مرتجع',
                        style: TextStyle(fontWeight: FontWeight.w800)),
                    const SizedBox(height: 8),
                    Text(
                        'المنتج: ${J.str(ri['product_name'] ?? ri['variant_name'] ?? '—')}'),
                    Text(
                        'المبلغ المسترد: ${ri['refund_amount'] ?? '—'}'),
                    Text(
                        'حالة المرتجع: ${J.str(ri['return_status'] ?? '')}'),
                    if (J.str(ri['return_rejection_reason']).isNotEmpty)
                      Text(
                          'سبب الرفض: ${ri['return_rejection_reason']}'),
                  ],
                ),
              );
            }),
            SizedBox(height: 16),
          ],
          // سجل الأحداث events من السيرفر
          if (!isLegacy && AssignmentHelper.events(a).isNotEmpty) ...[
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
                  const Text('سجل التتبع',
                      style: TextStyle(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 8),
                  ...AssignmentHelper.events(a).take(10).map((e) => Padding(
                        padding: const EdgeInsets.symmetric(vertical: 2),
                        child: Text(
                          '${J.str(e['to_status'] ?? e['status'] ?? '')} — ${J.str(e['created_at'] ?? '')}',
                          style: const TextStyle(
                              fontSize: 12, color: AppColors.greyText),
                        ),
                      )),
                ],
              ),
            ),
            SizedBox(height: 16),
          ],
          SizedBox(height: 16),
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
                  !isLegacy && AssignmentHelper.orderPublicId(a).isNotEmpty
                      ? 'تفاصيل الطلب ${AssignmentHelper.orderPublicId(a)}'
                      : 'تفاصيل الطلب',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: AppColors.navy,
                  ),
                ),
                SizedBox(height: 8),
                if (items.isEmpty)
                  Text('لا توجد عناصر', style: TextStyle(color: AppColors.greyText)),
                ...items.map(
                  (item) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            J.str(item['product_name'] ?? item['name'] ?? item['title']),
                          ),
                        ),
                        Text('x${item['quantity'] ?? 1}'),
                        SizedBox(width: 8),
                        Text(J.str(item['price'] ?? item['sub_total'] ?? ''), style: const TextStyle(color: AppColors.greyText, fontSize: 12)),
                      ],
                    ),
                  ),
                ),
                const Divider(),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('الإجمالي'),
                    Text(
                      isLegacy ? J.str(a['final_total']) : '${AssignmentHelper.finalTotalOf(a).toStringAsFixed(2)}',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 18,
                        color: AppColors.orange,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 4),
                Text(
                  isLegacy
                      ? 'رسوم التوصيل: ${a['delivery_charge'] ?? 0} • ${J.str(a['payment_method'])}'
                      : 'COD: ${codToCollect.toStringAsFixed(2)} • محصّل: ${codCollected.toStringAsFixed(2)}',
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.greyText,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: 16),
          // البائعون — مثل قسم Sellers في صفحة courier.
          if (!isLegacy &&
              AssignmentHelper.sellersOf(a).isNotEmpty) ...[
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
                    'البائعون (${AssignmentHelper.sellersOf(a).length}) — مندوب واحد للكل',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: AppColors.navy,
                    ),
                  ),
                  SizedBox(height: 8),
                  ...AssignmentHelper.sellersOf(a).map((s) => Padding(
                        padding:
                            const EdgeInsets.symmetric(vertical: 4),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                '${s['name']}',
                                style: const TextStyle(
                                    fontWeight: FontWeight.w600),
                              ),
                            ),
                            Text(
                              'تحضير: ${s['fulfillment']} | توصيل: ${s['delivery']} | أصناف: ${s['items']}',
                              style: const TextStyle(
                                fontSize: 11,
                                color: AppColors.greyText,
                              ),
                            ),
                          ],
                        ),
                      )),
                ],
              ),
            ),
            SizedBox(height: 16),
          ],
          // سبب الفشل الأخير — مثل Last reason في الويب.
          if (!isLegacy &&
              AssignmentHelper.failureReasonOf(a).isNotEmpty) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.error.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: AppColors.error.withValues(alpha: 0.25),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.info_outline,
                    size: 16,
                    color: AppColors.error,
                  ),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'آخر سبب: ${AssignmentHelper.failureReasonOf(a)}',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.error,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: 16),
          ],
          if (updating)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: InlineLoader(message: 'جاري تحديث الحالة...'),
            )
          else if (isLegacy)
            const Padding(
              padding: EdgeInsets.all(8),
              child: Text('الوضع القديم: يرجى تحديث الخادم لدعم الحالات الحديثة', textAlign: TextAlign.center, style: TextStyle(color: AppColors.greyText, fontSize: 12)),
            )
          else if (orderCancelled) ...[
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                  color: AppColors.error.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12)),
              child: Row(
                children: [
                  Icon(Icons.cancel_outlined, color: AppColors.error),
                  SizedBox(width: 8),
                  Expanded(
                      child: Text('الطلب ملغي من المصدر — لا توجد إجراءات متاحة',
                          style: TextStyle(
                              color: AppColors.error,
                              fontWeight: FontWeight.w700))),
                ],
              ),
            ),
          ] else if (_nextParsed.isNotEmpty) ...[
            const SectionHeader('تحديث الحالة - مطابقة للـ Backend'),
            if (requiresAccept)
              Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                    color: AppColors.orange.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12)),
                child: const Text(
                    'مطلوب القبول أولاً (requires_accept من السيرفر)',
                    style: TextStyle(fontWeight: FontWeight.w700)),
              ),
            ..._nextParsed.map((st) {
              // إخفاء الإلغاء عندما يمنعه السيرفر (مهام الأدمن adminAssigned)
              if (st == AssignmentStatus.cancelled && !canCancel) {
                return const SizedBox.shrink();
              }
              final isDelivered = st == AssignmentStatus.delivered;
              final isFailed = st == AssignmentStatus.failed;
              final isPrimary = primaryNext == st.apiValue;
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: DriverActionButton(
                  label: isPrimary ? '${st.labelAr} • التالي' : st.labelAr,
                  icon: isDelivered
                      ? Icons.check_circle
                      : isFailed
                          ? Icons.error_outline
                          : Icons.local_shipping,
                  onPressed: () => _handleStatusTap(st),
                ),
              );
            }),
            if (_nextParsed.contains(AssignmentStatus.pickedUp)) ...[
              SizedBox(height: 8),
              SlideToConfirm(
                label: 'اسحب لتأكيد الاستلام',
                onConfirmed: () => _handleStatusTap(AssignmentStatus.pickedUp),
              ),
            ],
          ] else if (currentStatus?.isTerminal ?? false) ...[
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: AppColors.success.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)),
              child: Row(
                children: [
                  Icon(Icons.check_circle, color: AppColors.success),
                  SizedBox(width: 8),
                  Text('انتهى: ${currentStatus?.labelAr ?? ''}', style: TextStyle(color: AppColors.success, fontWeight: FontWeight.w700)),
                ],
              ),
            ),
          ],
        ],
        ),
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
  Map<String, dynamic>? assignment;
  bool loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    var result = await app.api.assignmentById(widget.id);
    Map<String, dynamic>? data = result.dataMaps.isNotEmpty ? result.dataMaps.first : result.dataMap;
    if (data.isEmpty || !result.ok) {
      final legacy = await app.api.orderById(widget.id);
      data = legacy.dataMaps.isNotEmpty ? legacy.dataMaps.first : legacy.dataMap;
    }
    if (!mounted) return;
    setState(() {
      assignment = data;
      loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return Scaffold(
        backgroundColor: AppColors.navy,
        body: Stack(
          children: [
            const SafeArea(child: MapSkeleton()),
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: IconButton.filled(
                  style: IconButton.styleFrom(
                    backgroundColor: AppColors.navy,
                  ),
                  onPressed: () => context.pop(),
                  icon: Icon(Icons.arrow_forward, color: AppColors.white),
                ),
              ),
            ),
          ],
        ),
      );
    }

    final a = assignment ?? {};
    final isLegacy = a.containsKey('order_id') || a['_legacy'] == true;
    final storeName = isLegacy ? J.str(a['store_name'] ?? a['seller_name'] ?? 'المتجر') : AssignmentHelper.storeName(a);
    final address = isLegacy ? J.str(a['address']) : AssignmentHelper.addressOf(a);
    final earnings = isLegacy
        ? J.str(a['delivery_charge'] ?? a['final_total'] ?? '—')
        : '${AssignmentHelper.codToCollect(a).toStringAsFixed(2)}';
    final distance = J.str(
      a['distance'] ?? a['delivery_distance'] ?? '—',
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
                icon: Icon(Icons.arrow_forward, color: AppColors.white),
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
  String? error;
  String startDate = '';
  String endDate = '';
  // ===== CashCollection.vue extras: finance + liabilities + pay-seller =====
  Map<String, dynamic> finance = {};
  List<Map<String, dynamic>> liabilities = [];
  final payAssignmentCtrl = TextEditingController();
  final payAmountCtrl = TextEditingController();
  String payFrom = 'self';
  String payReceipt = '';
  String payReceiptName = '';
  bool paying = false;

  Future<void> _load() async {
    setState(() {
      loading = true;
      error = null;
    });
    final result = await app.api.cashCollection(
      startDate: startDate,
      endDate: endDate,
    );
    if (!mounted) return;
    setState(() {
      data = result.dataMap;
      items = result.list('transactions').isNotEmpty
          ? result.list('transactions')
          : result.dataMaps;
      final f = result.dataMap['finance'];
      if (f is Map) finance = J.map(f);
      loading = false;
      if (!result.ok) error = result.failMessage;
    });
    getLiabilities();
  }

  Future<void> getLiabilities() async {
    final res = await app.api.financeLiabilities(openOnly: true);
    if (!mounted || !res.ok) return;
    setState(() {
      liabilities = J.maps(res.dataMap['liabilities']);
      final s = res.dataMap['summary'];
      if (s is Map) finance = {...finance, ...J.map(s)};
    });
  }

  Future<void> pickPayReceipt() async {
    final file = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      requestFullMetadata: false,
    );
    if (file == null || !mounted) return;
    try {
      final bytes = await file.readAsBytes();
      if (bytes.length > 5 * 1024 * 1024) {
        toast(context, 'حجم الصورة يتجاوز 5MB');
        return;
      }
      // Data URI بنفس صيغة Vue FileReader (إجباري لإقرار الدفع)
      const chars =
          'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/';
      var out = '';
      var i = 0;
      while (i < bytes.length) {
        final b0 = bytes[i++];
        final b1 = i < bytes.length ? bytes[i++] : -1;
        final b2 = i < bytes.length ? bytes[i++] : -1;
        final n = (b0 << 16) | ((b1 >= 0 ? b1 : 0) << 8) | (b2 >= 0 ? b2 : 0);
        out += chars[(n >> 18) & 63] +
            chars[(n >> 12) & 63] +
            (b1 >= 0 ? chars[(n >> 6) & 63] : '=') +
            (b2 >= 0 ? chars[n & 63] : '=');
      }
      final ext =
          file.path.toLowerCase().endsWith('.png') ? 'png' : 'jpeg';
      setState(() {
        payReceipt = 'data:image/$ext;base64,$out';
        payReceiptName = file.path.split('/').last;
      });
    } catch (_) {
      toast(context, 'تعذر قراءة الصورة');
    }
  }

  Future<void> recordSellerPayment() async {
    final assignmentId = int.tryParse(payAssignmentCtrl.text.trim());
    final amount = double.tryParse(payAmountCtrl.text.trim());
    if (assignmentId == null || assignmentId <= 0 || amount == null || amount <= 0) {
      toast(context, 'أدخل رقم المهمة ومبلغاً صحيحاً');
      return;
    }
    if (payReceipt.isEmpty) {
      toast(context, 'صورة إيصال المتجر إجبارية — أرفقها قبل الإرسال');
      return;
    }
    setState(() => paying = true);
    final res = await app.api.financePaySellerDeclare(
      assignmentId: assignmentId,
      amount: amount,
      paidFrom: payFrom,
      receiptImage: payReceipt,
    );
    if (!mounted) return;
    setState(() => paying = false);
    if (res.ok) {
      toast(context, 'تم إرسال الإقرار للمراجعة');
      payAssignmentCtrl.clear();
      payAmountCtrl.clear();
      setState(() {
        payReceipt = '';
        payReceiptName = '';
      });
      _load();
    } else {
      toast(context, res.message);
    }
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    payAssignmentCtrl.dispose();
    payAmountCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('تحصيل نقدي')),
      body: FetchBody(
        loading: loading,
        onRefresh: _load,
        isEmpty: items.isEmpty,
        error: error,
        emptyText: 'لا توجد عمليات تحصيل',
        emptyIcon: Icons.payments_outlined,
        skeleton: const SummarySkeleton(tiles: 4),
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          children: [
            // فلتر التاريخ — مثل شاشة المحاسبة/التقارير عند التاجر
            Card(
              child: ListTile(
                leading: const Icon(Icons.date_range),
                title: Text(
                  (startDate.isEmpty || endDate.isEmpty)
                      ? 'كل الفترات'
                      : 'من $startDate إلى $endDate',
                ),
                trailing: startDate.isEmpty
                    ? null
                    : IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          setState(() {
                            startDate = '';
                            endDate = '';
                          });
                          _load();
                        },
                      ),
                onTap: () async {
                  final s = await pickDate(context);
                  if (s == null || !context.mounted) return;
                  final e = await pickDate(
                    context,
                    initial: DateTime.now(),
                  );
                  if (e == null || !context.mounted) return;
                  setState(() {
                    startDate = s;
                    endDate = e;
                  });
                  _load();
                },
              ),
            ),
            const SizedBox(height: 8),
            // بطاقات CashCollection.vue: cash_in_hand / cash_received +
            // العهدة التشغيلية + صافي التوريد + تنبيه تجاوز السقف
            Card(
              child: ListTile(
                title: Text(
                  'نقداً في اليد: ${data['cash_in_hand'] ?? finance['cash_in_hand'] ?? 0}',
                ),
                subtitle: Text(
                  'إجمالي المحصّل: ${data['cash_collected'] ?? 0}',
                ),
              ),
            ),
            if (finance.isNotEmpty) ...[
              const SizedBox(height: 8),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'العهدة التشغيلية: ${finance['float_balance'] ?? 0}',
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      Text(
                        'صافي التوريد للأدمن: ${finance['net_to_remit'] ?? 0}',
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          color: J.d(finance['net_to_remit']) > 0
                              ? Colors.red
                              : AppColors.success,
                        ),
                      ),
                      if (J.d(finance['pending_self_claim']) > 0)
                        Text(
                          'منها ذمة لك (دفعت من جيبك): ${finance['pending_self_claim']}',
                          style: const TextStyle(fontSize: 12),
                        ),
                      Text(
                        'متبقٍّ تحصيله: ${finance['cod_liability'] ?? 0}',
                        style: const TextStyle(fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ),
              if (finance['over_cash_limit'] == true ||
                  finance['over_cash_limit'] == 1 ||
                  finance['over_cash_limit'] == '1')
                Container(
                  margin: const EdgeInsets.only(top: 8),
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.red.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: Colors.red.withValues(alpha: 0.4),
                    ),
                  ),
                  child: Text(
                    'تجاوزت سقف النقدية (${finance['max_cash_in_hand'] ?? ''}) — لن تُسند لك مهام جديدة حتى التوريد.',
                    style: const TextStyle(
                      color: Colors.red,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
            ],
            const SizedBox(height: 8),
            // إقرار دفع للمتجر — طبق الأصل CashCollection.vue declaration
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'دفعت للمتجر مقدماً؟ سجّله هنا',
                      style: TextStyle(fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'نظام الإقرارات: أنت تُقرّ بالمبلغ وترفق صورة إيصال المتجر، والإدارة تعتمد المبلغ بعد التحقق — لا تُحتسب لك ذمة قبل الاعتماد.',
                      style: TextStyle(fontSize: 11),
                    ),
                    if (liabilities.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      ...liabilities.map(
                        (job) => ListTile(
                          dense: true,
                          title: Text(
                            '#${job['id']} • ${job['status'] ?? ''} • المتبقي ${job['remaining_cod'] ?? ''}',
                            style: const TextStyle(fontSize: 12),
                          ),
                          subtitle: Text(
                            job['payer_mode'] == 'platform'
                                ? 'المنصة تدفع — لا تدفع'
                                : (job['payer_mode'] == 'float'
                                    ? 'ادفع من العهدة'
                                    : 'ادفع من جيبك'),
                            style: const TextStyle(fontSize: 11),
                          ),
                          trailing: (J.d(job['paid_to_seller']) > 0)
                              ? const Text('✓ معتمد')
                              : (J.d(job['pending_pay_amount']) > 0
                                  ? Text(
                                      'قيد المراجعة: ${job['pending_pay_amount']}',
                                    )
                                  : TextButton(
                                      onPressed: () => setState(
                                        () => payAssignmentCtrl.text =
                                            '${job['id']}',
                                      ),
                                      child: const Text('اختيار'),
                                    )),
                        ),
                      ),
                    ],
                    const SizedBox(height: 8),
                    TextField(
                      controller: payAssignmentCtrl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'رقم المهمة (Assignment ID)',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: payAmountCtrl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'المبلغ المدفوع',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                    ),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<String>(
                      initialValue: payFrom,
                      items: const [
                        DropdownMenuItem(
                          value: 'self',
                          child: Text('من جيبي الخاص'),
                        ),
                        DropdownMenuItem(
                          value: 'float',
                          child: Text('من العهدة التشغيلية'),
                        ),
                      ],
                      onChanged: (v) =>
                          setState(() => payFrom = v ?? 'self'),
                      decoration: const InputDecoration(
                        labelText: 'الدفع من',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                    ),
                    const SizedBox(height: 8),
                    OutlinedButton.icon(
                      onPressed: pickPayReceipt,
                      icon: const Icon(Icons.upload),
                      label: Text(
                        payReceiptName.isEmpty
                            ? 'صورة إيصال المتجر (إجباري)'
                            : '$payReceiptName ✓',
                      ),
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed:
                            paying ? null : recordSellerPayment,
                        child: paying
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Text('إرسال الإقرار للمراجعة'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            SizedBox(height: 8),
            // طبق الأصل getCashCollection: COD vs delivery_boy_cash_collection
            ...items.map((item) {
              final rawType = J.str(item['type']);
              final isCollection = rawType == 'Delivery Boy Cash Collection' ||
                  rawType == 'delivery_boy_cash_collection';
              final typeAr = isCollection ? 'تحصيل نقدي' : 'COD عند التسليم';
              final orderLabel = J.str(item['order_id']).isEmpty ||
                      J.str(item['order_id']) == '-'
                  ? '—'
                  : '#${item['order_id']}';
              final amount = isCollection
                  ? J.str(item['collected_amount'] ?? item['amount'] ?? '0')
                  : J.str(item['amount'] ?? item['final_total'] ?? '0');
              return Card(
                child: ListTile(
                  leading: Icon(
                    isCollection
                        ? Icons.handshake_outlined
                        : Icons.payments_outlined,
                    color: AppColors.orange,
                  ),
                  title: Text('$orderLabel • $typeAr'),
                  subtitle: Text(
                    J.str(item['created_at'] ?? item['message'] ?? ''),
                  ),
                  trailing: Text(
                    amount,
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
              );
            }),
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
  String? error;
  // ===== FundTransfers.vue: الملخص المالي الموحد =====
  Map<String, dynamic> finance = {};

  Future<void> _load() async {
    setState(() {
      loading = true;
      error = null;
    });
    final result = await app.api.fundTransfers();
    if (!mounted) return;
    setState(() {
      items = result.dataMaps;
      loading = false;
      if (!result.ok) error = result.failMessage;
    });
    getFinance();
  }

  Future<void> getFinance() async {
    final res = await app.api.financeSummary();
    if (!mounted || !res.ok) return;
    setState(() => finance = res.dataMap);
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('تحويلات الرصيد')),
      body: FetchBody(
        loading: loading,
        onRefresh: _load,
        isEmpty: items.isEmpty && finance.isEmpty,
        error: error,
        emptyText: 'لا توجد تحويلات',
        skeleton: const TileSkeletonList(count: 5),
        child: ListView(
          padding: const EdgeInsets.all(12),
          children: [
            // الملخص المالي الموحد — طبق الأصل FundTransfers.vue
            if (finance.isNotEmpty) ...[
              GridView.count(
                crossAxisCount: 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 8,
                crossAxisSpacing: 8,
                childAspectRatio: 1.7,
                children: [
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(10),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Text(
                            'رصيد الأرباح',
                            style: TextStyle(fontSize: 11),
                          ),
                          Text(
                            '${finance['earnings_balance'] ?? 0}',
                            style: const TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(10),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Text(
                            'العهدة التشغيلية',
                            style: TextStyle(fontSize: 11),
                          ),
                          Text(
                            '${finance['float_balance'] ?? 0}',
                            style: const TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(10),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Text(
                            'النقد بيدي / صافي التوريد',
                            style: TextStyle(fontSize: 11),
                          ),
                          Text(
                            '${finance['cash_in_hand'] ?? 0} / ${finance['net_to_remit'] ?? 0}',
                            style: const TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(10),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Text(
                            'دفعت من جيبك (ذمة لك)',
                            style: TextStyle(fontSize: 11),
                          ),
                          Text(
                            '${finance['pending_self_claim'] ?? 0}',
                            style: const TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
            ],
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              padding: EdgeInsets.zero,
              itemCount: items.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (_, i) {
                final item = items[i];
                // Backend FundTransfer: delivery_boy_id/amount/type(debit/credit)/message/created_at
                final t = J.str(item['type']).toLowerCase();
                final typeAr = t == 'credit'
                    ? 'إيداع'
                    : t == 'debit'
                        ? 'خصم'
                        : J.str(item['type'] ?? 'تحويل');
                final msg =
                    J.str(item['message'] ?? item['remark'] ?? '');
                return Card(
                  child: ListTile(
                    leading: Icon(
                      t == 'credit'
                          ? Icons.arrow_downward
                          : Icons.arrow_upward,
                      color: t == 'credit'
                          ? AppColors.success
                          : AppColors.orange,
                    ),
                    title: Text(
                      msg.isNotEmpty
                          ? '$typeAr • $msg'
                          : '$typeAr #${item['id'] ?? ''}',
                    ),
                    subtitle: Text(
                      J.str(item['created_at'] ?? item['status'] ?? ''),
                    ),
                    trailing: Text(
                      J.str(item['amount']),
                      style:
                          const TextStyle(fontWeight: FontWeight.w800),
                    ),
                  ),
                );
              },
            ),
          ],
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
  String? error;
  // Backend getWithdrawalRequests يرجع {withdraw_requests[], balance, finance}
  // يدعم limit/offset/search/type/status — نمرر search مثل الباك اند
  // WithdrawalRequests.vue يعرض أيضاً finance: float/cash/net/cod
  String balance = '';
  Map<String, dynamic> finance = {};
  String statusFilter = '';
  String search = '';
  final _searchCtrl = TextEditingController();

  Future<void> _load() async {
    setState(() {
      loading = true;
      error = null;
    });
    final result = await app.api.withdrawals(
      limit: 50,
      offset: 0,
      status: statusFilter.isNotEmpty ? statusFilter : null,
      search: search.isNotEmpty ? search : null,
    );
    if (!mounted) return;
    // المفتاح withdraw_requests (بدون al) + بدائل للتوافق
    var list = J.maps(result.dataMap['withdraw_requests'] ??
        result.dataMap['withdrawal_requests'] ??
        result.dataMap['withdrawals']);
    if (list.isEmpty) list = result.dataMaps;
    // fallback: القائمة الكاملة index (مثل التاجر) إن كانت get فارغة
    if (list.isEmpty && result.ok) {
      try {
        final idx = await app.api.withdrawalIndex();
        if (mounted && idx.ok) {
          final alt = J.maps(idx.dataMap['withdraw_requests'] ??
              idx.dataMap['withdrawal_requests'] ??
              idx.dataMap['data']);
          if (alt.isEmpty) {
            final alt2 = idx.dataMaps;
            if (alt2.isNotEmpty) list = alt2;
          } else {
            list = alt;
          }
        }
      } catch (_) {}
    }
    if (!mounted) return;
    setState(() {
      items = statusFilter.isEmpty
          ? list
          : list
              .where((m) => '${J.i(m['status'])}' == statusFilter)
              .toList();
      balance = J.str(result.dataMap['balance']);
      final f = result.dataMap['finance'];
      if (f is Map) finance = J.map(f);
      loading = false;
      if (!result.ok) error = result.failMessage;
    });
    // finance منفصل إن لم يأتِ مع الطلبات (طبق الأصل WithdrawalRequests.vue)
    try {
      final fs = await app.api.financeSummary();
      if (mounted && fs.ok) setState(() => finance = fs.dataMap);
    } catch (_) {}
  }

  Future<void> _add() async {
    final amount = TextEditingController();
    final message = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('طلب سحب'),
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
            child: Text('إلغاء'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('إرسال'),
          ),
        ],
      ),
    );
    final amountText = amount.text.trim();
    final messageText = message.text;
    amount.dispose();
    message.dispose();
    if (ok != true || !context.mounted) return;
    final value = double.tryParse(amountText);
    // طبق الأصل Edit.vue: validateAmount >=0.01 + checkAmount <= balance
    if (value == null || value < 0.01) {
      toast(context, 'المبلغ يجب أن يكون 0.01 على الأقل');
      return;
    }
    final bal = double.tryParse(balance) ?? double.infinity;
    if (value > bal) {
      toast(
        context,
        'المبلغ المطلوب يجب ألا يتجاوز الرصيد المتاح ($balance)',
      );
      return;
    }
    final result = await app.api.addWithdrawal(
      amount: amountText,
      message: messageText,
    );
    if (!context.mounted) return;
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
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('طلبات السحب')),
      floatingActionButton: FloatingActionButton(
        onPressed: _add,
        child: Icon(Icons.add),
      ),
      body: Column(
        children: [
          // الرصيد المتاح + finance — طبق الأصل WithdrawalRequests.vue
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              children: [
                if (finance.isNotEmpty)
                  GridView.count(
                    crossAxisCount: 2,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    mainAxisSpacing: 8,
                    crossAxisSpacing: 8,
                    childAspectRatio: 1.8,
                    children: [
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(10),
                          child: Column(
                            crossAxisAlignment:
                                CrossAxisAlignment.start,
                            mainAxisAlignment:
                                MainAxisAlignment.center,
                            children: [
                              const Text(
                                'الرصيد المتاح للسحب',
                                style: TextStyle(fontSize: 11),
                              ),
                              Text(
                                balance.isNotEmpty
                                    ? balance
                                    : '${app.balance}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(10),
                          child: Column(
                            crossAxisAlignment:
                                CrossAxisAlignment.start,
                            mainAxisAlignment:
                                MainAxisAlignment.center,
                            children: [
                              const Text(
                                'العهدة التشغيلية',
                                style: TextStyle(fontSize: 11),
                              ),
                              Text(
                                '${finance['float_balance'] ?? 0}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(10),
                          child: Column(
                            crossAxisAlignment:
                                CrossAxisAlignment.start,
                            mainAxisAlignment:
                                MainAxisAlignment.center,
                            children: [
                              const Text(
                                'النقد بيدي / صافي التوريد',
                                style: TextStyle(fontSize: 11),
                              ),
                              Text(
                                '${finance['cash_in_hand'] ?? 0} / ${finance['net_to_remit'] ?? 0}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(10),
                          child: Column(
                            crossAxisAlignment:
                                CrossAxisAlignment.start,
                            mainAxisAlignment:
                                MainAxisAlignment.center,
                            children: [
                              const Text(
                                'متبقٍّ تحصيله (COD)',
                                style: TextStyle(fontSize: 11),
                              ),
                              Text(
                                '${finance['cod_liability'] ?? 0}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                Row(
                  children: [
                    Expanded(
                      child: Card(
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Text(
                            balance.isNotEmpty
                                ? 'الرصيد المتاح: $balance'
                                : 'الرصيد: ${app.balance}',
                            style: const TextStyle(fontWeight: FontWeight.w800),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    DropdownButton<String>(
                      value: statusFilter,
                      hint: const Text('الحالة', style: TextStyle(fontSize: 12)),
                      items: const [
                        DropdownMenuItem(value: '', child: Text('الكل')),
                        DropdownMenuItem(value: '0', child: Text('قيد الانتظار')),
                        DropdownMenuItem(value: '1', child: Text('مقبول')),
                        DropdownMenuItem(value: '2', child: Text('مرفوض')),
                      ],
                      onChanged: (v) {
                        setState(() => statusFilter = v ?? '');
                        _load();
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _searchCtrl,
                  decoration: InputDecoration(
                    hintText: 'بحث بالمبلغ أو الملاحظة...',
                    prefixIcon: const Icon(Icons.search, size: 18),
                    suffixIcon: search.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear, size: 18),
                            onPressed: () {
                              setState(() {
                                search = '';
                                _searchCtrl.clear();
                              });
                              _load();
                            },
                          )
                        : null,
                    isDense: true,
                    border: const OutlineInputBorder(),
                  ),
                  textInputAction: TextInputAction.search,
                  onSubmitted: (v) {
                    setState(() => search = v.trim());
                    _load();
                  },
                ),
              ],
            ),
          ),
          Expanded(
            child: FetchBody(
              loading: loading,
              onRefresh: _load,
              isEmpty: items.isEmpty,
              error: error,
              emptyText: 'لا توجد طلبات سحب',
              emptyActionLabel: 'طلب سحب',
              onEmptyAction: _add,
              skeleton: const TileSkeletonList(count: 4),
              child: ListView.separated(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                itemCount: items.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (_, i) {
                  final item = items[i];
                  final st = J.i(item['status']);
                  final stColor = st == 1
                      ? AppColors.success
                      : st == 2
                          ? AppColors.error
                          : AppColors.orange;
                  return Card(
                    child: ListTile(
                      leading: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: stColor.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(
                          st == 1
                              ? Icons.check_circle_outline
                              : st == 2
                                  ? Icons.cancel_outlined
                                  : Icons.pending_outlined,
                          color: stColor,
                        ),
                      ),
                      title: Text(
                        J.str(item['amount']),
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                      subtitle: Text(
                        '${_status(item['status'])} • ${J.str(item['message'] ?? item['remark'] ?? item['created_at'])}',
                      ),
                      trailing: Text(
                        J.str(item['created_at'] ?? '').length >= 10
                            ? J.str(item['created_at']).substring(0, 10)
                            : '',
                        style: const TextStyle(
                            fontSize: 10, color: AppColors.greyText),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ],
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
  List<Map<String, dynamic>> categories = [];
  String categoryFilter = '';
  bool loading = true;
  String? error;

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
    setState(() {
      loading = true;
      error = null;
    });
    // طبق الأصل getSalesReport: يدعم category — يرجع {categories[], salesReports[]}
    final a = await app.api.salesReports(
      startDate: start,
      endDate: end,
      category: categoryFilter.isNotEmpty ? categoryFilter : null,
    );
    final b = await app.api.productSalesReports(startDate: start, endDate: end);
    if (!mounted) return;
    setState(() {
      sales = a.list('salesReports').isNotEmpty
          ? a.list('salesReports')
          : a.dataMaps;
      categories = a.list('categories');
      products = b.dataMaps;
      loading = false;
      if (!a.ok || !b.ok) {
        error = a.ok ? b.failMessage : a.failMessage;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('التقارير')),
      body: Column(
        children: [
          ListTile(
            title: Text('من $start إلى $end'),
            trailing: Icon(Icons.date_range),
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
          // فلتر التصنيف — طبق الأصل getSalesReport?category=
          if (categories.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: DropdownButtonFormField<String>(
                key: ValueKey('cat-$categoryFilter-${categories.length}'),
                initialValue:
                    categoryFilter.isEmpty ? null : categoryFilter,
                hint: const Text('كل التصنيفات'),
                items: [
                  const DropdownMenuItem(value: '', child: Text('كل التصنيفات')),
                  ...categories.map((c) => DropdownMenuItem(
                        value: '${c['id']}',
                        child: Text(J.str(c['name'] ?? c['title'])),
                      )),
                ],
                onChanged: (v) {
                  setState(() => categoryFilter = v ?? '');
                  _load();
                },
                decoration: const InputDecoration(
                  labelText: 'التصنيف',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
              ),
            ),
          Expanded(
            child: FetchBody(
              loading: loading,
              onRefresh: _load,
              isEmpty: sales.isEmpty && products.isEmpty,
              error: error,
              emptyText: 'لا توجد تقارير لهذه الفترة',
              emptyIcon: Icons.bar_chart_outlined,
              skeleton: const TileSkeletonList(count: 5),
              child: ListView(
                padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
                children: [
                  const SectionHeader('المبيعات'),
                  ...sales.map(
                    (s) => Card(
                      child: ListTile(
                        title: Text(J.str(s['product_name'] ?? s['user_name'])),
                        subtitle:
                            Text(J.str(s['added_date'] ?? s['created_at'])),
                        trailing: Text(
                          J.str(s['sub_total'] ?? s['final_total']),
                          style: const TextStyle(fontWeight: FontWeight.w800),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  const SectionHeader('حسب المنتج'),
                  ...products.map(
                    (p) => Card(
                      child: ListTile(
                        leading: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: AppColors.orange.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(Icons.inventory_2_outlined,
                              color: AppColors.orange, size: 20),
                        ),
                        title: Text(J.str(p['product_name'] ?? p['name'])),
                        subtitle:
                            Text('مبيعات ${p['total_sales'] ?? '-'}'),
                        trailing: Text(
                          J.str(p['total_price'] ?? p['sub_total']),
                          style: const TextStyle(fontWeight: FontWeight.w800),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
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
  String? error;
  bool busy = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      loading = true;
      error = null;
    });
    final st = await app.api.orderStatuses();
    final set = await app.api.mailSettings();
    if (!mounted) return;
    if (!st.ok && !set.ok) {
      // فشل الجلب نفسه — لا نعرض "لا توجد حالات" المضللة
      setState(() {
        loading = false;
        error = st.failMessage;
      });
      return;
    }
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
    setState(() => loading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('إشعارات الطلبات')),
      body: FetchBody(
        loading: loading,
        onRefresh: _load,
        isEmpty: statuses.isEmpty,
        error: error,
        emptyText: 'لا توجد حالات للضبط',
        emptyActionLabel: 'إعادة المحاولة',
        onEmptyAction: () {
          setState(() => loading = true);
          _load();
        },
        skeleton: const TileSkeletonList(count: 4, tall: true),
        child: ListView(
          children: [
                ...statuses.map((s) {
                  final id = J.i(s['id']);
                  return ExpansionTile(
                    title: Text(J.str(s['status'] ?? s['name'])),
                    children: [
                      SwitchListTile(
                        title: Text('بريد'),
                        value: mail[id] ?? true,
                        onChanged: (v) => setState(() => mail[id] = v),
                      ),
                      SwitchListTile(
                        title: Text('جوال'),
                        value: mobile[id] ?? true,
                        onChanged: (v) => setState(() => mobile[id] = v),
                      ),
                      SwitchListTile(
                        title: Text('رسالة'),
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
                            if (!context.mounted) return;
                            setState(() => busy = false);
                            toast(
                              context,
                              result.ok ? 'تم الحفظ' : result.message,
                            );
                          },
                    child: busy ? const BusySpinner() : Text('حفظ'),
                  ),
                ),
              ],
            ),
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
  bool citiesLoading = true;
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
      setState(() {
        cities = res.dataMaps;
        citiesLoading = false;
      });
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
    final b = app.boy;
    final avg = b['average_rating'] ?? b['avg_rating'];
    final count = b['rating_count'] ?? b['ratings_count'];
    final bonusType = J.i(b['bonus_type']);
    final bonusPct = J.str(b['bonus_percentage'] ?? '0');
    return Scaffold(
      appBar: AppBar(title: Text('ملفي')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // تقييمي (من الباك اند DeliveryBoyRating::summary — يظهر إن وجد في البروفايل)
          if (avg != null || count != null)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    const Icon(Icons.star, color: Colors.amber),
                    const SizedBox(width: 8),
                    Text('تقييمي: $avg',
                        style:
                            const TextStyle(fontWeight: FontWeight.w800)),
                    const SizedBox(width: 8),
                    Text('($count تقييم)',
                        style: const TextStyle(fontSize: 12)),
                  ],
                ),
              ),
            ),
          // معلومات العمولة (قراءة فقط — تحددها الإدارة)
          // طبق الأصل DeliveryBoy::$bonusFixed=0 ثابت، $bonusCommission=1 عمولة، $bonusBoth=2 راتب+عمولة
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Text(
                bonusType == 1
                    ? 'العمولة: $bonusPct% (تحددها الإدارة)'
                    : bonusType == 2
                        ? 'راتب + عمولة $bonusPct% (تحددها الإدارة)'
                        : 'العمولة: مبلغ ثابت (تحدده الإدارة)',
                style: const TextStyle(fontSize: 12),
              ),
            ),
          ),
          const SizedBox(height: 8),
          labeledField(name, 'الاسم'),
          labeledField(mobile, 'الجوال', type: TextInputType.phone),
          labeledField(address, 'العنوان', maxLines: 2),
          DropdownButtonFormField<String>(
            initialValue: dropdownId(cityId, cities),
            items: cities
                .map(
                  (c) => DropdownMenuItem(
                    value: '${c['id']}',
                    child: Text(J.str(c['name'])),
                  ),
                )
                .toList(),
            onChanged: citiesLoading ? null : (v) => setState(() => cityId = v),
            decoration: InputDecoration(
              labelText: 'المدينة',
              hintText:
                  citiesLoading ? 'جاري تحميل المدن...' : 'اختر المدينة',
              border: OutlineInputBorder(),
              suffixIcon: citiesLoading
                  ? const Padding(
                      padding: EdgeInsets.all(12),
                      child: SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    )
                  : null,
            ),
          ),
          SizedBox(height: 10),
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
              // نفس خطوات التاجر (pickStoreImage): تأكيد قبل الوصول للمعرض
              final ok = await confirmAction(
                context,
                title: 'اختيار صورة الرخصة',
                body:
                    'سيتم فتح المعرض لاختيار صورة رخصة القيادة فقط.',
                confirmLabel: 'متابعة',
              );
              if (!ok || !context.mounted) return;
              final file = await ImagePicker().pickImage(
                source: ImageSource.gallery,
                requestFullMetadata: false,
              );
              if (file != null && mounted)
                setState(() => licensePath = file.path);
            },
            icon: Icon(Icons.badge_outlined),
            label: Text(
              licensePath == null ? 'رخصة القيادة' : 'تم اختيار الرخصة',
            ),
          ),
          OutlinedButton.icon(
            onPressed: () async {
              final ok = await confirmAction(
                context,
                title: 'اختيار صورة الهوية',
                body: 'سيتم فتح المعرض لاختيار صورة الهوية فقط.',
                confirmLabel: 'متابعة',
              );
              if (!ok || !context.mounted) return;
              final file = await ImagePicker().pickImage(
                source: ImageSource.gallery,
                requestFullMetadata: false,
              );
              if (file != null && mounted) setState(() => idPath = file.path);
            },
            icon: Icon(Icons.credit_card),
            label: Text(idPath == null ? 'الهوية' : 'تم اختيار الهوية'),
          ),
          SizedBox(height: 16),
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
                    if (!context.mounted) return;
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
            child: busy ? const BusySpinner() : Text('حفظ'),
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
      'تنطبق سياسة الخصوصية هذه على تطبيق سريع مارت موصل في اليمن. نجمع بيانات الحساب اللازمة للعمل: الاسم، رقم الجوال، البريد إن وُجد، العنوان والمدينة، الطلبات المسندة، التحصيل النقدي، التحويلات وطلبات السحب.\n\n'
      'الصور: يمكنك اختيار صورة رخصة القيادة أو الهوية من المعرض لتحديث ملفك. لا نصل إلى المعرض إلا عند اختيارك ذلك.\n\n'
      'لا نبيع بياناتك لمعلنين. قد تظهر بيانات لازمة لتنفيذ التوصيل داخل المنصة. يمكنك حذف الحساب من: حسابي ثم حذف الحساب.\n\n'
      'الخدمة مخصصة لمن يبلغ 18 عاماً فأكثر لأن التوصيل عمل ميداني. آخر تحديث: 15 أغسطس 2026.';

  static const _termsFallback =
      'باستخدام تطبيق سريع مارت موصل فإنك توافق على هذه الشروط. الحساب يُنشأ من الإدارة فقط.\n\n'
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
      appBar: AppBar(title: Text('السياسات')),
      body: FetchBody(
        loading: loading,
        onRefresh: _load,
        isEmpty: false,
        skeleton: const ParagraphSkeleton(lines: 14),
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(
              'سياسة الخصوصية',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
            SizedBox(height: 8),
            Text(privacy),
            SizedBox(height: 24),
            Text(
              'الشروط والأحكام',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
            SizedBox(height: 8),
            Text(terms),
            SizedBox(height: 24),
            FilledButton(
              onPressed: () {
                setState(() => loading = true);
                _load();
              },
              child: Text('تحديث'),
            ),
          ],
        ),
      ),
    );
  }
}

/// صندوق الإشعارات — طبق الأصل GET get_top_notifications -> {unread, notifications}
class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});
  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  List<Map<String, dynamic>> items = [];
  int unread = 0;
  bool loading = true;
  String? error;
  bool markingAll = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { loading = true; error = null; });
    final res = await app.api.topNotifications();
    if (!mounted) return;
    if (!res.ok) {
      setState(() { loading = false; error = res.failMessage; });
      return;
    }
    setState(() {
      unread = J.i(res.dataMap['unread']);
      items = J.maps(res.dataMap['notifications']);
      loading = false;
    });
  }

  Future<void> _markAllRead() async {
    if (markingAll || unread == 0) return;
    setState(() => markingAll = true);
    final res = await app.api.markNotificationRead(all: true);
    if (!mounted) return;
    setState(() => markingAll = false);
    if (res.ok) {
      setState(() {
        unread = 0;
        for (final n in items) {
          n['read_at'] = n['read_at'] ?? 'read';
        }
      });
      toast(context, 'تم تحديد الكل كمقروء');
    } else {
      toast(context, res.message);
    }
  }

  Future<void> _markOneRead(int index) async {
    final n = items[index];
    final isUnread =
        J.str(n['read_at']).isEmpty && (n['read_at'] == null);
    if (!isUnread) return;
    // تحديث متفائل فوري + تأكيد بالسيرفر
    setState(() {
      n['read_at'] = 'read';
      if (unread > 0) unread -= 1;
    });
    final res = await app.api.markNotificationRead(id: n['id']);
    if (!mounted) return;
    if (!res.ok) {
      // رجوع هادئ عند الفشل
      setState(() {
        n['read_at'] = null;
        unread += 1;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(unread > 0 ? 'الإشعارات ($unread غير مقروء)' : 'الإشعارات'),
        actions: [
          if (unread > 0)
            markingAll
                ? const Padding(
                    padding: EdgeInsets.all(14),
                    child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2.4),
                    ),
                  )
                : TextButton(
                    onPressed: _markAllRead,
                    child: Text(
                      'تحديد الكل كمقروء',
                      style: TextStyle(
                        color: AppColors.white.withValues(alpha: 0.9),
                      ),
                    ),
                  ),
        ],
      ),
      body: FetchBody(
        loading: loading,
        onRefresh: _load,
        isEmpty: items.isEmpty,
        error: error,
        emptyText: 'لا توجد إشعارات',
        emptyIcon: Icons.notifications_outlined,
        skeleton: const TileSkeletonList(count: 5),
        child: ListView.separated(
          padding: const EdgeInsets.all(12),
          itemCount: items.length,
          separatorBuilder: (_, __) => const SizedBox(height: 8),
          itemBuilder: (_, i) {
            final n = items[i];
            final isUnread = J.str(n['read_at']).isEmpty &&
                (n['read_at'] == null);
            return Card(
              child: ListTile(
                leading: Icon(
                  isUnread
                      ? Icons.markunread_outlined
                      : Icons.drafts_outlined,
                  color: AppColors.orange,
                ),
                title: Text(J.str(
                    n['title'] ?? n['subject'] ?? 'إشعار')),
                subtitle: Text(J.str(n['message'] ??
                    n['body'] ??
                    n['description'] ??
                    '')),
                trailing: Text(
                    J.str(n['created_at'] ?? ''),
                    style: const TextStyle(fontSize: 10)),
                onTap: () => _markOneRead(i),
              ),
            );
          },
        ),
      ),
    );
  }
}

/// حالة إشعارات الجهاز الفورية (FCM) — تصل حتى والتطبيق مغلق.
/// الضغط عليها يعيد طلب الإذن إن كان معطلاً من الجهاز.
class _PushStatusTile extends StatefulWidget {
  const _PushStatusTile();

  @override
  State<_PushStatusTile> createState() => _PushStatusTileState();
}

class _PushStatusTileState extends State<_PushStatusTile> {
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    final ok = PushService.supported && PushService.permissionGranted;
    return AccountMenuItem(
      icon: ok
          ? Icons.notifications_active_outlined
          : Icons.notifications_off_outlined,
      title: 'إشعارات الجهاز الفورية',
      subtitle: _busy ? 'جاري الطلب...' : PushService.statusText,
      onTap: _busy
          ? () {}
          : () async {
              setState(() => _busy = true);
              final granted = await PushService.requestPermission();
              if (!context.mounted) return;
              setState(() => _busy = false);
              toast(
                context,
                granted
                    ? 'تم تفعيل الإشعارات الفورية'
                    : 'تعذّر التفعيل — تحقق من إعدادات الجهاز وFirebase',
              );
            },
    );
  }
}

// ===========================================================================
// حسابي — طبق الأصل EditDeliveryBoy.vue (وضع Delivery Boy)
// ملخص الملف + تعديل الاسم/الجوال/العنوان + روابط محفظتي/الاعدادات/خروج
// ===========================================================================
class AccountScreen extends StatefulWidget {
  const AccountScreen({super.key});
  @override
  State<AccountScreen> createState() => _AccountScreenState();
}

class _AccountScreenState extends State<AccountScreen> {
  bool loading = true;
  bool busy = false;
  Map<String, dynamic> record = {};
  final name = TextEditingController();
  final mobile = TextEditingController();
  final address = TextEditingController();
  final dob = TextEditingController();
  final email = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    name.dispose();
    mobile.dispose();
    address.dispose();
    dob.dispose();
    email.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => loading = true);
    final res = await app.api.deliveryProfile();
    if (!mounted) return;
    final d = res.ok ? res.dataMap : Map<String, dynamic>.from(app.boy);
    setState(() {
      record = d;
      name.text = J.str(d['name'] ?? app.name);
      mobile.text = J.str(d['mobile']);
      address.text = J.str(d['address']);
      dob.text = J.str(d['dob']);
      final admin = J.map(d['admin']);
      email.text = J.str(
        admin['email'] ?? d['email'] ?? app.user?['email'] ?? '',
      );
      loading = false;
    });
  }

  String _statusText(dynamic s) {
    final v = J.i(s, -1);
    if (v == 1) return 'نشط';
    if (v == 2) return 'غير معتمد';
    if (v == 3) return 'موقوف';
    return 'مسجل';
  }

  String get _cityName {
    final c = record['city'];
    if (c is Map) return J.str(c['name'], '-');
    return '-';
  }

  List<String> get _zoneNames {
    final zones = record['zones'];
    if (zones is! List) return [];
    return zones
        .map((z) {
          if (z is Map) return J.str(z['name'] ?? z['code']);
          return '$z';
        })
        .where((n) => n.isNotEmpty)
        .toList();
  }

  Future<void> _save() async {
    if (name.text.trim().isEmpty || mobile.text.trim().isEmpty) {
      toast(context, 'أكمل الاسم والجوال');
      return;
    }
    setState(() => busy = true);
    final map = <String, dynamic>{
      'id': app.boyId ?? record['id'],
      'admin_id': app.adminId ?? record['admin_id'],
      'name': name.text.trim(),
      'mobile': mobile.text.trim(),
      'address': address.text.trim(),
      'dob': dob.text.trim().isEmpty ? null : dob.text.trim(),
      'city_id': record['city_id'] ?? app.boy['city_id'],
      'status': record['status'] ?? app.boyStatus,
      'bonus_type': record['bonus_type'] ?? app.boy['bonus_type'] ?? 0,
      'bonus_percentage':
          record['bonus_percentage'] ?? app.boy['bonus_percentage'] ?? 0,
    };
    final result = await app.api.updateProfile(FormData.fromMap(map));
    if (!mounted) return;
    setState(() => busy = false);
    toast(context, result.ok ? 'تم حفظ الملف' : result.message);
    if (result.ok) {
      final current = Map<String, dynamic>.from(app.user ?? {});
      current['deliveryBoy'] = {
        ...app.boy,
        'name': name.text.trim(),
        'mobile': mobile.text.trim(),
        'address': address.text.trim(),
        'dob': dob.text.trim(),
      };
      current['delivery_boy'] = current['deliveryBoy'];
      app.user = current;
      await app.persistUser();
      _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Center(child: CircularProgressIndicator());
    }
    final avg = J.d(record['average_rating']);
    final ratingCount = record['rating_count'] ?? 0;
    final isAvailable = record['is_available'] == 1 ||
        record['is_available'] == true ||
        record['is_available'] == '1';
    final statusOk = J.i(record['status']) == 1;

    return RefreshIndicator(
      color: AppColors.orange,
      onRefresh: _load,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            'حسابي',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 12),
          // ملخص الملف — EditDeliveryBoy.vue courier card
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 28,
                        backgroundColor:
                            AppColors.orange.withValues(alpha: 0.15),
                        child: Icon(
                          Icons.person,
                          color: AppColors.orange,
                          size: 32,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              J.str(record['name'], app.name),
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 17,
                              ),
                            ),
                            Text(
                              J.str(record['mobile']),
                              style: const TextStyle(
                                color: AppColors.greyText,
                                fontSize: 13,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Wrap(
                              spacing: 6,
                              runSpacing: 4,
                              children: [
                                Chip(
                                  label: Text(_statusText(record['status'])),
                                  backgroundColor: statusOk
                                      ? AppColors.success
                                          .withValues(alpha: 0.15)
                                      : Colors.red.withValues(alpha: 0.12),
                                  labelStyle: TextStyle(
                                    fontSize: 11,
                                    color: statusOk
                                        ? AppColors.success
                                        : Colors.red,
                                  ),
                                  visualDensity: VisualDensity.compact,
                                ),
                                if (isAvailable)
                                  Chip(
                                    label: const Text('متاح'),
                                    backgroundColor: Colors.blue
                                        .withValues(alpha: 0.12),
                                    labelStyle: const TextStyle(
                                      fontSize: 11,
                                      color: Colors.blue,
                                    ),
                                    visualDensity: VisualDensity.compact,
                                  ),
                                Chip(
                                  label: Text(
                                    avg > 0
                                        ? '★ ${avg.toStringAsFixed(1)} ($ratingCount)'
                                        : 'لا تقييم بعد',
                                  ),
                                  backgroundColor: avg > 0
                                      ? Colors.amber.withValues(alpha: 0.2)
                                      : AppColors.greyBorder,
                                  labelStyle: const TextStyle(fontSize: 11),
                                  visualDensity: VisualDensity.compact,
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      _AccountStat(
                        label: 'الرصيد',
                        value: '${record['balance'] ?? app.balance}',
                      ),
                      _AccountStat(label: 'المدينة', value: _cityName),
                      _AccountStat(
                        label: 'المناطق',
                        value: '${_zoneNames.length}',
                      ),
                      _AccountStat(
                        label: 'السعة',
                        value: '${record['max_capacity'] ?? '-'}',
                      ),
                    ],
                  ),
                  if (_zoneNames.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      children: _zoneNames
                          .map(
                            (z) => Chip(
                              label: Text(z),
                              visualDensity: VisualDensity.compact,
                              labelStyle: const TextStyle(fontSize: 11),
                            ),
                          )
                          .toList(),
                    ),
                  ],
                  const Divider(height: 24),
                  _infoRow('تاريخ الميلاد', J.str(record['dob'], '-')),
                  _infoRow('البريد', email.text.isEmpty ? '-' : email.text),
                  _infoRow('العنوان', J.str(record['address'], '-')),
                  _infoRow(
                    'الوردية',
                    '${J.str(record['shift_start'], '-')} - ${J.str(record['shift_end'], '-')}',
                  ),
                  _infoRow(
                    'نسبة العمولة',
                    '${record['bonus_percentage'] ?? 0}%',
                  ),
                  Row(
                    children: [
                      const Text(
                        'المستندات: ',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.greyText,
                        ),
                      ),
                      Chip(
                        label: const Text('رخصة'),
                        backgroundColor: record['driving_license'] != null
                            ? AppColors.success.withValues(alpha: 0.15)
                            : AppColors.greyBorder,
                        visualDensity: VisualDensity.compact,
                        labelStyle: const TextStyle(fontSize: 10),
                      ),
                      const SizedBox(width: 4),
                      Chip(
                        label: const Text('هوية'),
                        backgroundColor:
                            record['national_identity_card'] != null
                                ? AppColors.success.withValues(alpha: 0.15)
                                : AppColors.greyBorder,
                        visualDensity: VisualDensity.compact,
                        labelStyle: const TextStyle(fontSize: 10),
                      ),
                    ],
                  ),
                  if (J.str(record['bank_name']).isNotEmpty ||
                      J.str(record['bank_account_number']).isNotEmpty)
                    _infoRow(
                      'البنك',
                      '${J.str(record['bank_name'], '-')} / ${J.str(record['bank_account_number'], '-')} / ${J.str(record['account_name'], '-')}',
                    ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      OutlinedButton(
                        onPressed: () => context.go('/wallet'),
                        child: const Text('محفظتي'),
                      ),
                      const SizedBox(width: 8),
                      OutlinedButton(
                        onPressed: () => context.push('/settings'),
                        child: const Text('الاعدادات'),
                      ),
                      const Spacer(),
                      TextButton(
                        onPressed: () async {
                          final ok = await confirmAction(
                            context,
                            title: 'تسجيل الخروج',
                            body: 'هل تريد تسجيل الخروج؟',
                          );
                          if (!ok || !context.mounted) return;
                          await app.logout();
                          if (context.mounted) context.go('/login');
                        },
                        child: const Text(
                          'خروج',
                          style: TextStyle(color: Colors.red),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          // نموذج التعديل — الحقول المسموحة للموصل
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'تعديل بياناتي',
                    style: TextStyle(fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 12),
                  labeledField(name, 'الاسم *'),
                  labeledField(mobile, 'الجوال *', type: TextInputType.phone),
                  labeledField(dob, 'تاريخ الميلاد (اختياري)'),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: TextField(
                      controller: email,
                      readOnly: true,
                      decoration: const InputDecoration(
                        labelText: 'البريد (للقراءة فقط)',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                  labeledField(address, 'العنوان', maxLines: 2),
                  // Duty / استقبال العمل — ضروري للجوال (polling)
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('استقبال الطلبات'),
                    subtitle: Text(
                      app.isOnline
                          ? 'متصل — تستقبل المهام الجديدة'
                          : 'متوقف — لن تصلك مهام جديدة',
                      style: const TextStyle(fontSize: 12),
                    ),
                    value: app.isOnline,
                    onChanged: (v) => app.setOnline(v),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: busy ? null : _save,
                      child: busy
                          ? const BusySpinner(color: Colors.white)
                          : const Text('حفظ'),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          // صفحات ثانوية موجودة في Vue كمسارات legacy (ليست في الشريط الجانبي)
          Card(
            child: Column(
              children: [
                AccountMenuItem(
                  icon: Icons.notifications_outlined,
                  title: 'الإشعارات',
                  onTap: () => context.push('/notifications'),
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
                AccountMenuItem(
                  icon: Icons.delete_outline,
                  title: 'حذف الحساب',
                  destructive: true,
                  onTap: () async {
                    final passwordCtrl = TextEditingController();
                    var dlgBusy = false;
                    final ok = await showDialog<bool>(
                      context: context,
                      builder: (ctx) => StatefulBuilder(
                        builder: (ctx, setDlg) => AlertDialog(
                          title: const Text('حذف الحساب'),
                          content: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Text(
                                'سيتم حذف حساب الموصل نهائياً. أدخل كلمة المرور للتأكيد.',
                              ),
                              const SizedBox(height: 12),
                              TextField(
                                controller: passwordCtrl,
                                obscureText: true,
                                decoration: const InputDecoration(
                                  labelText: 'كلمة المرور',
                                  border: OutlineInputBorder(),
                                ),
                              ),
                            ],
                          ),
                          actions: [
                            TextButton(
                              onPressed: dlgBusy
                                  ? null
                                  : () => Navigator.pop(ctx, false),
                              child: const Text('تراجع'),
                            ),
                            FilledButton(
                              onPressed: dlgBusy
                                  ? null
                                  : () async {
                                      if (passwordCtrl.text.isEmpty) {
                                        toast(context, 'أدخل كلمة المرور');
                                        return;
                                      }
                                      setDlg(() => dlgBusy = true);
                                      final result = await app.api
                                          .deleteAccount(
                                        password: passwordCtrl.text,
                                      );
                                      if (!ctx.mounted) return;
                                      setDlg(() => dlgBusy = false);
                                      if (!result.ok) {
                                        toast(context, result.message);
                                        return;
                                      }
                                      Navigator.pop(ctx, true);
                                    },
                              child: dlgBusy
                                  ? const BusySpinner(color: Colors.white)
                                  : const Text('حذف نهائي'),
                            ),
                          ],
                        ),
                      ),
                    );
                    passwordCtrl.dispose();
                    if (!context.mounted) return;
                    if (ok == true) {
                      toast(context, 'تم حذف الحساب');
                      await app.logout();
                      if (context.mounted) context.go('/login');
                    }
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(
              label,
              style: const TextStyle(fontSize: 12, color: AppColors.greyText),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AccountStat extends StatelessWidget {
  const _AccountStat({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Text(
            label,
            style: const TextStyle(fontSize: 11, color: AppColors.greyText),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
          ),
        ],
      ),
    );
  }
}

/// Unassigned pool gated by admin switch courier_can_claim_orders.
/// Backend also guards claim(); when disabled this screen explains why.
class ClaimOrdersScreen extends StatefulWidget {
  const ClaimOrdersScreen({super.key});
  @override
  State<ClaimOrdersScreen> createState() => _ClaimOrdersScreenState();
}

class _ClaimOrdersScreenState extends State<ClaimOrdersScreen> {
  List<Map<String, dynamic>> items = [];
  bool loading = true;
  String? error;
  dynamic claimingId;

  @override
  void initState() {
    super.initState();
    _load();
  }

  // Backend availableOrders يرجع {can_claim_enabled, can_claim, orders[], diagnostics{}}
  // orders[]: {id, public_id, user_name, mobile, address, payment_method, final_total,
  // delivery_time, created_at, score, score_breakdown}
  // diagnostics.reason: setting_off | none_eligible | courier_blocked | ok
  Map<String, dynamic> meta = {};
  Map<String, dynamic> diag = {};

  String _reasonText(String? reason) {
    switch (reason) {
      case 'setting_off':
        return 'الالتقاط الذاتي معطّل حالياً من الإدارة.';
      case 'none_eligible':
        return 'لا توجد طلبات متاحة حالياً للالتقاط.';
      case 'courier_blocked':
        return 'لا يمكنك الالتقاط الآن (غير متاح أو وصلت للحد الأقصى للسعة).';
      case 'ok':
        return 'لا توجد طلبات متاحة حالياً.';
      default:
        return 'لا توجد طلبات متاحة حالياً.';
    }
  }

  Future<void> _load() async {
    setState(() { loading = true; error = null; });
    await app.refreshWorkload();
    try {
      final res = await app.api.availableOrders();
      if (!mounted) return;
      if (!res.ok) {
        setState(() { loading = false; error = res.message; });
        return;
      }
      final d = res.dataMap;
      meta = J.map(d);
      diag = J.map(d['diagnostics']);
      app.availableOrdersMeta
        ..clear()
        ..addAll(meta);
      // البوابة الحقيقية: can_claim_enabled من هذا الرد (وليس workload)
      if (meta['can_claim_enabled'] == false ||
          meta['can_claim_enabled'] == 0 ||
          meta['can_claim_enabled'] == '0') {
        setState(() { items = []; loading = false; });
        return;
      }
      final orders = J.maps(d['orders']);
      setState(() {
        items = orders;
        loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() { loading = false; error = '$e'; });
    }
  }

  Future<void> _claim(dynamic id) async {
    if (claimingId != null) return;
    setState(() => claimingId = id);
    final res = await app.api.claimAvailableOrder(id);
    if (!mounted) return;
    setState(() => claimingId = null);
    toast(context, res.ok ? 'تم الالتقاط بنجاح' : res.message);
    if (res.ok) {
      await app.refreshWorkload();
      _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: app,
      builder: (context, _) {
        final enabled = meta.isEmpty
            ? app.canClaimOrders
            : (meta['can_claim_enabled'] == true ||
                meta['can_claim_enabled'] == 1 ||
                meta['can_claim_enabled'] == '1');
        if (!enabled && !loading) {
          return Scaffold(
            appBar: AppBar(title: const Text('طلبات متاحة للالتقاط')),
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  _reasonText(J.str(diag['reason'], 'setting_off')),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          );
        }
        final canNow = meta['can_claim'] == true ||
            meta['can_claim'] == 1 ||
            meta['can_claim'] == '1';
        return Scaffold(
          appBar: AppBar(title: const Text('طلبات متاحة للالتقاط')),
          body: FetchBody(
            loading: loading,
            onRefresh: _load,
            isEmpty: items.isEmpty,
            error: error,
            emptyText: _reasonText(J.str(diag['reason'])),
            emptyIcon: Icons.add_task_outlined,
            child: ListView.separated(
              padding: const EdgeInsets.all(12),
              itemCount: items.length + 1,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (_, i) {
                if (i == 0) {
                  // شريط التشخيص من السيرفر + حالة القدرة الاستيعابية
                  return Card(
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            canNow
                                ? 'يمكنك الالتقاط الآن'
                                : 'الالتقاط متوقف مؤقتاً (السعة ممتلئة أو غير متاح)',
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'السعة: ${app.workloadInfo.activeCount}/${app.workloadInfo.maxCapacity} — المتبقي ${app.workloadInfo.remainingCapacity}',
                            style: const TextStyle(fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                  );
                }
                final g = items[i - 1];
                final score = g['score'];
                return Card(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                'مجموعة #${g['public_id'] ?? g['id']}',
                                style: const TextStyle(fontWeight: FontWeight.w800),
                              ),
                            ),
                            if (score != null)
                              Chip(label: Text('نقاط $score')),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(J.str(
                          g['user_name'] ??
                              g['address'] ??
                              '',
                        )),
                        Text(
                          '${J.str(g['payment_method'] ?? '')} — الإجمالي ${g['final_total'] ?? ''}',
                          style: const TextStyle(fontSize: 12),
                        ),
                        if (J.str(g['mobile']).isNotEmpty)
                          Text('الجوال: ${g['mobile']}',
                              style: const TextStyle(fontSize: 12)),
                        const SizedBox(height: 8),
                        Align(
                          alignment: AlignmentDirectional.centerEnd,
                          child: FilledButton(
                            onPressed: canNow && claimingId == null
                                ? () => _claim(g['id'])
                                : null,
                            child: claimingId == g['id']
                                ? const BusySpinner(color: Colors.white)
                                : const Text('التقاط'),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        );
      },
    );
  }
}

// ===========================================================================
// طلباتي — طبق الأصل Orders.vue (الموصل)
// tabs: new/جديدة, in_delivery/قيد التوصيل, completed/مكتملة, available/متاحة
// available: GET available-orders + POST available-orders/{id}/claim
// others: GET collection/orders?tab= -> orders[{id,customer,area,seller_count,
// payment_method,amount_to_collect,is_return_pickup,return_product,...}]
// ===========================================================================
class VueOrdersScreen extends StatefulWidget {
  const VueOrdersScreen({super.key});
  @override
  State<VueOrdersScreen> createState() => _VueOrdersScreenState();
}

class _VueOrdersScreenState extends State<VueOrdersScreen> {
  String tab = 'new';
  final tabs = const [
    {'key': 'new', 'label': 'جديدة'},
    {'key': 'in_delivery', 'label': 'قيد التوصيل'},
    {'key': 'completed', 'label': 'مكتملة'},
    {'key': 'available', 'label': 'متاحة للاستلام'},
  ];
  List<Map<String, dynamic>> orders = [];
  Map<String, dynamic> counts = {};
  bool isLoading = false;
  dynamic claiming;
  String sort = 'oldest';

  @override
  void initState() {
    super.initState();
    getOrders();
  }

  Future<void> getOrders() async {
    setState(() => isLoading = true);
    if (tab == 'available') {
      final res = await app.api.availableOrders(sort: sort);
      if (!mounted) return;
      setState(() => isLoading = false);
      if (!res.ok) {
        toast(context, res.message);
        return;
      }
      final d = res.dataMap;
      final list = J.maps(d['orders']);
      setState(() {
        orders = list
            .map((g) => {
                  'key': 'g${g['id']}',
                  'group_id': g['id'],
                  'customer': J.str(g['user_name'], 'عميل'),
                  'area': J.str(g['address']),
                  'seller_count': '-',
                  'payment_method': J.str(g['payment_method']),
                  'amount_to_collect': J.d(g['final_total']),
                })
            .toList();
      });
      return;
    }
    final res = await app.api.collectionOrders(tab: tab, sort: sort);
    if (!mounted) return;
    setState(() => isLoading = false);
    if (!res.ok) {
      setState(() => orders = []);
      return;
    }
    final d = res.dataMap;
    final list = J.maps(d['orders']);
    setState(() {
      orders = list
          .map((o) => {
                ...o,
                'key':
                    '${o['is_return_pickup'] == true ? 'r' : 'a'}${o['id']}',
              })
          .toList();
    });
  }

  Future<void> claim(Map<String, dynamic> o) async {
    setState(() => claiming = o['group_id']);
    final res = await app.api.claimAvailableOrder(o['group_id']);
    if (!mounted) return;
    setState(() => claiming = null);
    if (res.ok) {
      toast(context, 'تم استلام الطلب');
      setState(() => tab = 'new');
      getOrders();
    } else {
      toast(context, res.message.isEmpty ? 'تعذر الاستلام' : res.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      color: AppColors.orange,
      onRefresh: getOrders,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            'طلباتي',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: tabs.map((t) {
              final active = tab == t['key'];
              final count = counts[t['key']];
              return ChoiceChip(
                label: Text(
                  count != null ? '${t['label']} ($count)' : '${t['label']}',
                ),
                selected: active,
                onSelected: (_) {
                  setState(() => tab = '${t['key']}');
                  getOrders();
                },
              );
            }).toList(),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => context.push('/akhdimni'),
                  icon: const Icon(Icons.bolt_outlined),
                  label: const Text('مهام أخدمني'),
                ),
              ),
              const SizedBox(width: 8),
              ChoiceChip(
                label: const Text('الأقدم'),
                selected: sort == 'oldest',
                onSelected: (_) {
                  setState(() => sort = 'oldest');
                  getOrders();
                },
              ),
              const SizedBox(width: 4),
              ChoiceChip(
                label: const Text('الأحدث'),
                selected: sort == 'newest',
                onSelected: (_) {
                  setState(() => sort = 'newest');
                  getOrders();
                },
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (isLoading)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: CircularProgressIndicator(),
              ),
            )
          else if (orders.isEmpty)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.greyBorder),
              ),
              child: Column(
                children: [
                  const Text('لا توجد طلبات هنا.'),
                  if (tab == 'available')
                    TextButton(
                      onPressed: getOrders,
                      child: const Text('تحديث'),
                    ),
                ],
              ),
            )
          else
            ...orders.map((o) {
              final isReturn = o['is_return_pickup'] == true;
              final isAkh = o['source'] == 'akhdimni';
              final pay = J.str(o['payment_method']);
              final isCod = pay.toUpperCase() == 'COD';
              final due = J.d(o['amount_to_collect']);
              return Card(
                margin: const EdgeInsets.only(bottom: 10),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(
                    color: isReturn ? Colors.amber : AppColors.orange,
                    width: isReturn ? 2 : 1,
                  ),
                ),
                color: isReturn ? const Color(0xFFFFFDF5) : AppColors.white,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  J.str(o['customer'], 'عميل'),
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w800,
                                    fontSize: 15,
                                  ),
                                ),
                                if (isReturn)
                                  Container(
                                    margin: const EdgeInsets.only(top: 4),
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 3,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.amber,
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      'مرتجع: ${J.str(o['status_label'], 'استلام مرتجع')}',
                                      style: const TextStyle(fontSize: 11),
                                    ),
                                  ),
                                if (isAkh && !isReturn)
                                  Container(
                                    margin: const EdgeInsets.only(top: 4),
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 3,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.teal.withValues(alpha: 0.15),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      'أخدمني — ${J.str(o['status_label'])}',
                                      style: const TextStyle(fontSize: 11),
                                    ),
                                  ),
                                if (isReturn &&
                                    J.str(o['return_product']).isNotEmpty)
                                  Text(
                                    J.str(o['return_product']),
                                    style: const TextStyle(fontSize: 12),
                                  ),
                                if (J.str(o['area']).isNotEmpty)
                                  Text(
                                    J.str(o['area']),
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: AppColors.greyText,
                                    ),
                                  ),
                                if (!isReturn && !isAkh)
                                  Text(
                                    'المتاجر: ${o['seller_count'] ?? '-'}',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: AppColors.greyText,
                                    ),
                                  ),
                                if (isAkh && !isReturn)
                                  Text(
                                    J.str(o['assignment_type']) ==
                                            'point_to_point'
                                        ? 'من نقطة إلى نقطة'
                                        : 'شراء وتوصيل',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: AppColors.greyText,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: isCod
                                      ? Colors.amber
                                      : AppColors.success.withValues(
                                          alpha: 0.15,
                                        ),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  isCod
                                      ? 'عند الاستلام'
                                      : (pay.isNotEmpty ? pay : 'مدفوع'),
                                  style: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 4),
                              if (due > 0)
                                Text(
                                  due.toStringAsFixed(2),
                                  style: const TextStyle(
                                    color: Colors.red,
                                    fontWeight: FontWeight.w800,
                                    fontSize: 16,
                                  ),
                                )
                              else
                                Text(
                                  'لا يوجد تحصيل',
                                  style: TextStyle(
                                    color: AppColors.success,
                                    fontSize: 12,
                                  ),
                                ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      SizedBox(
                        width: double.infinity,
                        child: tab != 'available'
                            ? FilledButton(
                                onPressed: () {
                                  if (isAkh &&
                                      J.str(o['akhdimni_order_id'])
                                          .isNotEmpty) {
                                    context.push(
                                        '/akhdimni/${o['akhdimni_order_id']}');
                                  } else {
                                    context.push('/order/${o['id']}');
                                  }
                                },
                                child: const Text('فتح الطلب'),
                              )
                            : FilledButton(
                                style: FilledButton.styleFrom(
                                  backgroundColor: AppColors.success,
                                ),
                                onPressed: claiming == o['group_id']
                                    ? null
                                    : () => claim(o),
                                child: claiming == o['group_id']
                                    ? const SizedBox(
                                        width: 18,
                                        height: 18,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: Colors.white,
                                        ),
                                      )
                                    : const Text('استلام هذا الطلب'),
                              ),
                      ),
                    ],
                  ),
                ),
              );
            }),
        ],
      ),
    );
  }
}

// ===========================================================================
// محفظتي — طبق الأصل Wallet.vue
// GET collection/settlement -> 7 بطاقات + توريد + كشف حساب
// POST collection/handover {amount, collection_method, receipt_image?}
// GET collection/settlement/details -> entries[{date,type,amount,order,status}]
// ===========================================================================
class WalletScreen extends StatefulWidget {
  const WalletScreen({super.key});
  @override
  State<WalletScreen> createState() => _WalletScreenState();
}

class _WalletScreenState extends State<WalletScreen> {
  bool busy = false;
  Map<String, dynamic> sum = {
    'cash_you_need_to_return': 0,
    'amount_owed_to_you': 0,
    'cash_currently_held': 0,
    'cod_collected': 0,
    'cash_already_handed_over': 0,
    'approved_personal_payments': 0,
    'float_received': 0,
  };
  final amountCtrl = TextEditingController();
  String handoverMsg = '';
  String handoverMethod = 'cash';
  String handoverReceipt = '';
  bool showDetails = false;
  bool loadingDetails = false;
  List<Map<String, dynamic>> details = [];

  @override
  void initState() {
    super.initState();
    load();
  }

  @override
  void dispose() {
    amountCtrl.dispose();
    super.dispose();
  }

  Future<void> load() async {
    final res = await app.api.collectionSettlement();
    if (!mounted || !res.ok) return;
    setState(() => sum = {...sum, ...res.dataMap});
  }

  Future<void> loadDetails() async {
    setState(() => loadingDetails = true);
    final res = await app.api.collectionSettlementDetails();
    if (!mounted) return;
    setState(() {
      loadingDetails = false;
      details = J.maps(res.dataMap['entries']);
    });
  }

  Future<void> pickReceipt() async {
    final file = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      requestFullMetadata: false,
    );
    if (file == null || !mounted) return;
    try {
      final bytes = await file.readAsBytes();
      if (bytes.length > 5 * 1024 * 1024) {
        toast(context, 'حجم الصورة يتجاوز 5MB');
        return;
      }
      final ext = file.path.toLowerCase().endsWith('.png') ? 'png' : 'jpeg';
      // ignore: unused_import — base64 via dart:convert is available transitively;
      // نبني Data URI يدوياً بنفس صيغة Vue FileReader
      const chars =
          'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/';
      var out = '';
      var i = 0;
      while (i < bytes.length) {
        final b0 = bytes[i++];
        final b1 = i < bytes.length ? bytes[i++] : -1;
        final b2 = i < bytes.length ? bytes[i++] : -1;
        final n = (b0 << 16) | ((b1 >= 0 ? b1 : 0) << 8) | (b2 >= 0 ? b2 : 0);
        out += chars[(n >> 18) & 63] +
            chars[(n >> 12) & 63] +
            (b1 >= 0 ? chars[(n >> 6) & 63] : '=') +
            (b2 >= 0 ? chars[n & 63] : '=');
      }
      setState(
        () => handoverReceipt = 'data:image/$ext;base64,$out',
      );
    } catch (_) {
      toast(context, 'تعذر قراءة الصورة');
    }
  }

  Future<void> declareHandover() async {
    final amount = double.tryParse(amountCtrl.text.trim());
    if (amount == null || amount <= 0) {
      toast(context, 'أدخل المبلغ الذي سلّمته');
      return;
    }
    if (handoverMethod == 'transfer' && handoverReceipt.isEmpty) {
      toast(context, 'صورة إشعار الحوالة إجبارية للتحويل');
      return;
    }
    setState(() => busy = true);
    final res = await app.api.collectionHandover(
      amount: amount,
      collectionMethod: handoverMethod,
      receiptImage: handoverMethod == 'transfer' ? handoverReceipt : null,
    );
    if (!mounted) return;
    setState(() => busy = false);
    if (res.ok) {
      setState(() {
        handoverMsg = handoverMethod == 'transfer'
            ? 'تم إعلان التوريد البنكي مع الإشعار، بانتظار تأكيد الإدارة.'
            : 'تم إعلان التوريد، بانتظار تأكيد الإدارة.';
        amountCtrl.clear();
        handoverReceipt = '';
      });
      load();
    } else {
      toast(context, res.message);
    }
  }

  String typeLabel(dynamic t) {
    const m = {
      'CASH_COLLECTED_FROM_CUSTOMER': 'تحصيل من عميل',
      'CASH_GIVEN_TO_PLATFORM': 'توريد للإدارة',
      'CASH_ADVANCE_FROM_PLATFORM': 'عهدة من الإدارة',
      'COURIER_PERSONAL_PAYMENT': 'دفع من الجيب',
      'COURIER_REIMBURSEMENT': 'تعويض',
      'CASH_SHORTAGE': 'عجز',
      'CASH_SURPLUS': 'زيادة',
      'collected': 'تحصيل',
    };
    return m['$t'] ?? '$t';
  }

  String fmtDate(dynamic v) {
    final s = '$v';
    if (s.length >= 16) return s.substring(0, 16).replaceAll('T', ' ');
    return s.isEmpty ? '-' : s;
  }

  @override
  Widget build(BuildContext context) {
    final cards = [
      {'label': 'مطلوب توريده', 'k': 'cash_you_need_to_return'},
      {'label': 'مستحق لك', 'k': 'amount_owed_to_you'},
      {
        'label': 'صافي التحصيل (قبل خصم المصاريف)',
        'k': 'cash_currently_held',
      },
      {'label': 'حصّلته من العملاء', 'k': 'cod_collected'},
      {'label': 'ورّدته سابقاً', 'k': 'cash_already_handed_over'},
      {'label': 'عهدة مستلمة من الإدارة', 'k': 'float_received'},
      {'label': 'مصاريف محسومة لك', 'k': 'approved_personal_payments'},
    ];
    return RefreshIndicator(
      color: AppColors.orange,
      onRefresh: load,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            'محفظتي',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 12),
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            childAspectRatio: 1.35,
            children: cards
                .map(
                  (c) => Card(
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            '${c['label']}',
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.greyText,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${sum[c['k']] ?? 0}',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: c['k'] == 'cash_you_need_to_return'
                                  ? Colors.red
                                  : c['k'] == 'amount_owed_to_you'
                                      ? AppColors.success
                                      : AppColors.navy,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                )
                .toList(),
          ),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'توريد نقدية للإدارة',
                    style: TextStyle(fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: amountCtrl,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'المبلغ الذي سلّمته',
                            border: OutlineInputBorder(),
                            isDense: true,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      DropdownButton<String>(
                        value: handoverMethod,
                        items: const [
                          DropdownMenuItem(
                            value: 'cash',
                            child: Text('نقداً'),
                          ),
                          DropdownMenuItem(
                            value: 'transfer',
                            child: Text('تحويل بنكي'),
                          ),
                        ],
                        onChanged: (v) =>
                            setState(() => handoverMethod = v ?? 'cash'),
                      ),
                    ],
                  ),
                  if (handoverMethod == 'transfer') ...[
                    const SizedBox(height: 8),
                    const Text(
                      'صورة إشعار الحوالة (إجبارية للتحويل)',
                      style: TextStyle(fontSize: 12),
                    ),
                    const SizedBox(height: 4),
                    OutlinedButton.icon(
                      onPressed: pickReceipt,
                      icon: const Icon(Icons.upload),
                      label: Text(
                        handoverReceipt.isEmpty
                            ? 'اختيار الصورة'
                            : 'تم اختيار الإشعار',
                      ),
                    ),
                  ],
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: busy ||
                              amountCtrl.text.trim().isEmpty ||
                              (handoverMethod == 'transfer' &&
                                  handoverReceipt.isEmpty)
                          ? null
                          : declareHandover,
                      child: busy
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Text('إعلان التوريد'),
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'أنت تُعلن، وموظف الإدارة يؤكد الاستلام بعد مراجعة الإشعار. أي فرق يظهر كملاحظة للمراجعة.',
                    style:
                        TextStyle(fontSize: 11, color: AppColors.greyText),
                  ),
                  if (handoverMsg.isNotEmpty)
                    Container(
                      margin: const EdgeInsets.only(top: 8),
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.blue.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(handoverMsg),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: Column(
              children: [
                ListTile(
                  title: const Text(
                    'كشف الحساب',
                    style: TextStyle(fontWeight: FontWeight.w800),
                  ),
                  trailing: TextButton(
                    onPressed: () {
                      setState(() => showDetails = !showDetails);
                      if (showDetails && details.isEmpty) loadDetails();
                    },
                    child: Text(
                      showDetails ? 'إخفاء التفاصيل' : 'عرض التفاصيل',
                    ),
                  ),
                ),
                if (showDetails)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                    child: loadingDetails
                        ? const Center(
                            child: CircularProgressIndicator(),
                          )
                        : Column(
                            children: details
                                .map(
                                  (r) => ListTile(
                                    dense: true,
                                    title: Text(
                                      '${typeLabel(r['type'])} • ${r['amount']}',
                                    ),
                                    subtitle: Text(
                                      '${fmtDate(r['date'])} • طلب ${r['order'] ?? '-'}',
                                      style: const TextStyle(fontSize: 11),
                                    ),
                                    trailing: Text(
                                      r['status'] == 'settled'
                                          ? 'مسوّى'
                                          : 'مفتوح',
                                      style: const TextStyle(fontSize: 11),
                                    ),
                                  ),
                                )
                                .toList(),
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

// ===========================================================================
// الإعدادات — طبق الأصل DeliverySettings.vue
// GET delivery_boy/profile + POST system_users/change_password
// ===========================================================================
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});
  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool isLoading = false;
  bool profileLoading = false;
  Map<String, dynamic> profile = {};
  final username = TextEditingController();
  final currentPassword = TextEditingController();
  final password = TextEditingController();
  final confirmPassword = TextEditingController();
  bool hideCurrent = true;
  bool hideNew = true;
  bool hideConfirm = true;

  @override
  void initState() {
    super.initState();
    username.text = J.str(
      app.user?['username'] ?? app.user?['email'] ?? '',
    );
    getProfile();
  }

  @override
  void dispose() {
    username.dispose();
    currentPassword.dispose();
    password.dispose();
    confirmPassword.dispose();
    super.dispose();
  }

  Future<void> getProfile() async {
    setState(() => profileLoading = true);
    final res = await app.api.deliveryProfile();
    if (!mounted) return;
    setState(() => profileLoading = false);
    if (res.ok) setState(() => profile = res.dataMap);
  }

  String get statusText {
    final s = J.i(profile['status'], -1);
    if (s == 1) return 'نشط';
    if (s == 2) return 'غير معتمد';
    if (s == 3) return 'موقوف';
    return 'مسجل';
  }

  String get cityName {
    final c = profile['city'];
    if (c is Map) return J.str(c['name'], '-');
    return J.str(c, '-');
  }

  String get shiftText {
    final s = J.str(profile['shift_start']);
    final e = J.str(profile['shift_end']);
    if (s.isNotEmpty || e.isNotEmpty) {
      String cut(String v) => v.length >= 5 ? v.substring(0, 5) : v;
      return '${cut(s.isEmpty ? '--:--' : s)} - ${cut(e.isEmpty ? '--:--' : e)}';
    }
    return 'دوام المنصة';
  }

  List<String> get zoneNames {
    final z = profile['zones'];
    if (z is List) {
      return z
          .map((e) => e is Map
              ? J.str(e['name'].toString().isEmpty ? e['code'] : e['name'])
              : '$e')
          .where((e) => e.isNotEmpty)
          .toList();
    }
    return [];
  }

  Future<void> savePassword() async {
    if (username.text.trim().isEmpty ||
        currentPassword.text.isEmpty ||
        password.text.isEmpty ||
        confirmPassword.text.isEmpty) {
      toast(context, 'أكمل جميع الحقول');
      return;
    }
    setState(() => isLoading = true);
    final res = await app.api.changeUsernamePassword(
      username: username.text.trim(),
      currentPassword: currentPassword.text,
      password: password.text,
      confirmPassword: confirmPassword.text,
    );
    if (!mounted) return;
    setState(() => isLoading = false);
    toast(
      context,
      res.ok ? 'تم الحفظ' : (res.message.isEmpty ? 'تعذر الحفظ' : res.message),
    );
    if (res.ok && context.mounted) context.go('/');
  }

  @override
  Widget build(BuildContext context) {
    final avg = J.d(profile['average_rating']);
    final rc = J.i(profile['rating_count']);
    return Scaffold(
      appBar: AppBar(title: const Text('الإعدادات')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'ملفي',
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 8),
                  if (profileLoading)
                    const Center(child: CircularProgressIndicator())
                  else
                    Column(
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.account_circle,
                              size: 48,
                              color: AppColors.navy,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    J.str(profile['name'], '-'),
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w800,
                                      fontSize: 16,
                                    ),
                                  ),
                                  Text(
                                    J.str(profile['mobile']),
                                    style: const TextStyle(
                                      color: AppColors.greyText,
                                    ),
                                  ),
                                  Wrap(
                                    spacing: 6,
                                    children: [
                                      Chip(label: Text(statusText)),
                                      if (avg > 0)
                                        Chip(
                                          label: Text('★ $avg ($rc)'),
                                        )
                                      else
                                        const Chip(
                                          label: Text('لا يوجد تقييم بعد'),
                                        ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const Divider(),
                        ListTile(
                          dense: true,
                          title: const Text('الرصيد'),
                          trailing:
                              Text('${profile['balance'] ?? 0}'),
                        ),
                        ListTile(
                          dense: true,
                          title: const Text('المدينة'),
                          trailing: Text(cityName),
                        ),
                        ListTile(
                          dense: true,
                          title: const Text('الدوام'),
                          trailing: Text(shiftText),
                        ),
                        if (zoneNames.isNotEmpty)
                          Wrap(
                            spacing: 6,
                            children: zoneNames
                                .map((z) => Chip(label: Text(z)))
                                .toList(),
                          ),
                        Align(
                          alignment:
                              AlignmentDirectional.centerStart,
                          child: TextButton(
                            onPressed: () =>
                                context.push('/account'),
                            child: const Text('ملفي'),
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'تغيير اسم المستخدم وكلمة المرور',
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: username,
                    decoration: const InputDecoration(
                      labelText: 'اسم المستخدم',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: currentPassword,
                    obscureText: hideCurrent,
                    decoration: InputDecoration(
                      labelText: 'كلمة المرور الحالية',
                      border: const OutlineInputBorder(),
                      isDense: true,
                      suffixIcon: IconButton(
                        icon: Icon(
                          hideCurrent
                              ? Icons.visibility_outlined
                              : Icons.visibility_off_outlined,
                        ),
                        onPressed: () => setState(
                          () => hideCurrent = !hideCurrent,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: password,
                    obscureText: hideNew,
                    decoration: InputDecoration(
                      labelText: 'كلمة المرور',
                      border: const OutlineInputBorder(),
                      isDense: true,
                      suffixIcon: IconButton(
                        icon: Icon(
                          hideNew
                              ? Icons.visibility_outlined
                              : Icons.visibility_off_outlined,
                        ),
                        onPressed: () =>
                            setState(() => hideNew = !hideNew),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: confirmPassword,
                    obscureText: hideConfirm,
                    decoration: InputDecoration(
                      labelText: 'تأكيد كلمة المرور',
                      border: const OutlineInputBorder(),
                      isDense: true,
                      suffixIcon: IconButton(
                        icon: Icon(
                          hideConfirm
                              ? Icons.visibility_outlined
                              : Icons.visibility_off_outlined,
                        ),
                        onPressed: () => setState(
                          () => hideConfirm = !hideConfirm,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: FilledButton(
                          onPressed:
                              isLoading ? null : savePassword,
                          child: isLoading
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child:
                                      CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Text('حفظ'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      OutlinedButton(
                        onPressed: () => context.pop(),
                        child: const Text('رجوع'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ===========================================================================
// تفاصيل الطلب — طبق الأصل MyOrder.vue (collection flow)
// GET collection/orders/{id} -> assignment/customer/sellers/checklist/...
// POST assignments/{id}/accept | POST assignments/{id}/status
// POST collection/orders/{id}/confirm-paid | POST .../seller-cash
// tolerance ±100 — transfer يتطلب proof_path — note اختيارية دائماً
// ===========================================================================
class CollectionOrderScreen extends StatefulWidget {
  const CollectionOrderScreen({super.key, required this.id});
  final String id;
  @override
  State<CollectionOrderScreen> createState() => _CollectionOrderScreenState();
}

class _CollectionOrderScreenState extends State<CollectionOrderScreen> {
  bool isLoading = true;
  bool busy = false;
  Map<String, dynamic> assignment = {};
  Map<String, dynamic> detail = {};
  double due = 0;
  double codTotal = 0;
  double codCollected = 0;
  double tolerance = 100;
  double? cashReceived;
  String collectionMethod = 'cash';
  String proofPath = '';
  String note = '';
  String collectMsg = '';
  bool collectOk = false;
  String? collectKey;
  bool showFail = false;
  String failReason = '';
  final cashCtrl = TextEditingController();
  final noteCtrl = TextEditingController();
  final proofCtrl = TextEditingController();
  final failCtrl = TextEditingController();

  final cashCtrl2 = TextEditingController();
  final noteCtrl2 = TextEditingController();
  final proofCtrl2 = TextEditingController();

  Map<String, dynamic>? dialogSeller;
  double? dialogAmount;
  String dialogPayMethod = 'cash';
  String dialogNote = '';
  bool dialogBusy = false;
  final dialogAmountCtrl = TextEditingController();
  final dialogNoteCtrl = TextEditingController();

  bool bulkShow = false;
  bool bulkBusy = false;
  Map<dynamic, double?> bulkAmounts = {};
  bool deliverShow = false;
  bool deliverBusy = false;

  @override
  void initState() {
    super.initState();
    load();
  }

  @override
  void dispose() {
    cashCtrl.dispose();
    noteCtrl.dispose();
    proofCtrl.dispose();
    failCtrl.dispose();
    cashCtrl2.dispose();
    noteCtrl2.dispose();
    proofCtrl2.dispose();
    dialogAmountCtrl.dispose();
    dialogNoteCtrl.dispose();
    super.dispose();
  }

  String get orderNo {
    final g = J.map(assignment['checkout_group']);
    final v = J.str(
      assignment['order_public_id'].toString().isEmpty
          ? g['public_id']
          : assignment['order_public_id'],
    );
    if (v.isEmpty || v == 'null') return '#${assignment['id'] ?? widget.id}';
    return '$v';
  }

  String get status => J.str(assignment['status']);
  String get statusLabel {
    const m = {
      'assigned': 'جديد',
      'accepted': 'مقبول',
      'picking_up': 'قيد الجمع',
      'picked_up': 'مستلم',
      'out_for_delivery': 'بالطريق',
      'delivered': 'تم التسليم',
      'failed': 'تعذر',
      'cancelled': 'ملغي',
    };
    return m[status] ?? status;
  }

  int get stepIndex {
    const m = {
      'assigned': 0,
      'accepted': 1,
      'picking_up': 1,
      'picked_up': 2,
      'out_for_delivery': 2,
      'delivered': 3,
    };
    return m[status] ?? 0;
  }

  List<String> get steps =>
      ['استلام الطلب', 'جمع الأصناف', 'في الطريق', 'تسليم + تحصيل'];
  bool get canAccept =>
      status == 'assigned' || assignment['requires_accept'] == true;
  bool get canPickup => ['accepted', 'picking_up'].contains(status);
  bool get canDeliver => ['picked_up', 'out_for_delivery'].contains(status);
  bool get isDone => ['delivered', 'failed', 'cancelled'].contains(status);
  bool get isPickupPhase => canAccept || canPickup;
  double get collected =>
      codCollected > 0 ? codCollected : J.d(assignment['cod_collected']);
  double get remaining =>
      (due - collected) > 0 ? (due - collected) : 0;
  bool get showCollection => canDeliver || status == 'delivered';
  Map<String, dynamic> get customerObj => J.map(detail['customer']);
  String get customerMobile =>
      J.str(customerObj['mobile'].toString().isEmpty ? detail['mobile'] : customerObj['mobile']);

  List<Map<String, dynamic>> get sellersList {
    final s = detail['sellers'];
    if (s is List && s.isNotEmpty) return J.maps(s);
    return [];
  }

  Map<String, dynamic>? get checklist {
    final c = detail['pickup_checklist'];
    return c is Map ? J.map(c) : null;
  }

  bool get collectionRecorded {
    if (due <= 0) return true;
    final c = detail['collection'];
    if (c is Map && c['recorded'] == true) return true;
    return collected > 0;
  }

  String get payerMode {
    final m = J.str(assignment['payer_mode']);
    if (m == 'platform') return 'platform';
    if (m == 'both') return 'both';
    return 'courier';
  }

  Map<String, dynamic> get settlementPreview =>
      J.map(detail['settlement_preview']);
  Map<String, dynamic> get courierMoney => J.map(detail['courier_money']);

  double sellerQty(Map<String, dynamic> s) {
    double n = 0;
    for (final it in J.maps(s['items'])) {
      n += J.d(it['quantity']);
    }
    return n;
  }

  double sellerAmount(Map<String, dynamic> s) {
    double n = 0;
    for (final it in J.maps(s['items'])) {
      n += J.d(it['sub_total']);
    }
    return n;
  }

  List<Map<String, dynamic>> get allItems {
    final out = <Map<String, dynamic>>[];
    for (final s in sellersList) {
      for (final it in J.maps(s['items'])) {
        out.add({...it, 'store_name': J.str(s['store_name'])});
      }
    }
    return out;
  }

  Future<void> load([void Function()? cb]) async {
    setState(() => isLoading = true);
    final res = await app.api.collectionOrderShow(widget.id);
    if (!mounted) return;
    setState(() => isLoading = false);
    if (!res.ok) {
      toast(context, res.message.isEmpty ? 'غير موجود' : res.message);
      return;
    }
    final d = res.dataMap;
    // MyOrder.vue: المرتجعات لها واجهة ViewOrder منفصلة
    final a = J.map(d['assignment']);
    final isReturn = d['is_return_pickup'] == true ||
        a['is_return_pickup'] == true ||
        J.str(a['assignment_type']) == 'return_pickup';
    if (isReturn) {
      if (!mounted) return;
      context.replace('/assignment/${widget.id}');
      return;
    }
    setState(() {
      assignment = a;
      detail = d;
      due = J.d(d['amount_to_collect']);
      codTotal = J.d(d['cod_to_collect'] ?? d['amount_to_collect']);
      codCollected = J.d(
        d['cod_collected'] ?? assignment['cod_collected'] ?? 0,
      );
      tolerance = J.d(d['cash_variance_tolerance'], 100);
      if (tolerance <= 0) tolerance = 100;
      if (cashReceived == null) {
        cashReceived = due;
        cashCtrl.text = due > 0 ? due.toStringAsFixed(2) : '';
        cashCtrl2.text = cashCtrl.text;
      }
      collectKey = 'collect-${widget.id}-$due';
    });
    if (cb != null) cb();
  }

  Future<void> accept() async {
    setState(() => busy = true);
    final res = await app.api.acceptAssignment(widget.id);
    if (!mounted) return;
    setState(() => busy = false);
    if (res.ok) {
      toast(context, 'تم الاستلام');
      load();
    } else {
      toast(context, res.message);
    }
  }

  Future<void> goStatus(String st, [String? reason]) async {
    setState(() => busy = true);
    final res = await app.api.updateAssignmentStatus(
      id: widget.id,
      status: st,
      failureReason: reason,
    );
    if (!mounted) return;
    setState(() => busy = false);
    if (res.ok) {
      toast(context, 'تم');
      load();
    } else {
      toast(context, res.message);
    }
  }

  double get _cashVal =>
      double.tryParse(cashCtrl.text.trim()) ??
      double.tryParse(cashCtrl2.text.trim()) ??
      -1;

  Future<void> confirmPaid({bool fromDeliver = false}) async {
    final v = fromDeliver
        ? double.tryParse(cashCtrl2.text.trim())
        : double.tryParse(cashCtrl.text.trim());
    if (v == null || v < 0) {
      toast(context, 'أدخل المبلغ المستلم');
      return;
    }
    if (due > 0 && (v - due).abs() - 100 > 0.009) {
      toast(context, 'المبلغ يجب أن يكون ضمن ±100 من المطلوب ($due)');
      return;
    }
    final method = collectionMethod;
    final proof = (fromDeliver ? proofCtrl2.text : proofCtrl.text).trim();
    final noteV = (fromDeliver ? noteCtrl2.text : noteCtrl.text).trim();
    if (method == 'transfer' && proof.isEmpty) {
      toast(context, 'أرفق إشعار الحوالة أولاً');
      return;
    }
    setState(() => fromDeliver ? deliverBusy = true : busy = true);
    final res = await app.api.collectionConfirmPaid(
      id: widget.id,
      cashReceived: v,
      collectionMethod: method,
      proofPath: proof.isEmpty ? null : proof,
      note: noteV.isEmpty ? null : noteV,
      idempotencyKey: collectKey,
    );
    if (!mounted) return;
    setState(() => fromDeliver ? deliverBusy = false : busy = false);
    if (res.ok) {
      final d = res.dataMap;
      setState(() {
        collectOk = true;
        collectMsg = d['status'] == 'SHORTAGE_RECORDED'
            ? 'عجز ${d['shortage']} مسجّل — لا يؤثر على المحتسب'
            : (d['status'] == 'OVERPAID_CHANGE_DUE'
                ? 'الباقي للعميل: ${d['customer_change']}'
                : 'تم التحصيل كاملاً');
        deliverShow = false;
      });
      if (fromDeliver) {
        // MyOrder.vue confirmDeliver: بعد التحصيل → status delivered
        if (Navigator.of(context).canPop()) Navigator.of(context).pop();
        await goStatus('delivered');
      } else {
        toast(context, 'تم تسجيل التحصيل');
        load();
      }
    } else {
      setState(() {
        collectOk = false;
        collectMsg = res.message;
      });
      toast(context, res.message);
    }
  }

  Future<void> confirmDeliver() async => confirmPaid(fromDeliver: true);

  void openDeliverDialog() {
    if (due <= 0) {
      goStatus('delivered');
      return;
    }
    if (cashCtrl2.text.trim().isEmpty) {
      cashCtrl2.text = due.toStringAsFixed(2);
    }
    setState(() {
      deliverBusy = false;
      deliverShow = true;
    });
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setD) => AlertDialog(
          title: const Text('تأكيد التسليم وتحصيل المبلغ'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('المطلوب بالنظام: $due'),
                const Text(
                  'حدد المبلغ الذي استلمته فعلاً — ضمن ±100 فقط.',
                  style: TextStyle(fontSize: 11, color: AppColors.greyText),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: cashCtrl2,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'المبلغ المستلم فعلاً',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  onChanged: (_) => setD(() {}),
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  initialValue: collectionMethod,
                  items: const [
                    DropdownMenuItem(value: 'cash', child: Text('نقدي')),
                    DropdownMenuItem(
                      value: 'transfer',
                      child: Text('حوالة / تحويل'),
                    ),
                  ],
                  onChanged: (v) {
                    setState(
                      () => collectionMethod = v ?? 'cash',
                    );
                    setD(() {});
                  },
                  decoration: const InputDecoration(
                    labelText: 'طريقة التحصيل',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                ),
                if (collectionMethod == 'transfer') ...[
                  const SizedBox(height: 8),
                  TextField(
                    controller: proofCtrl2,
                    decoration: const InputDecoration(
                      labelText: 'مسار إشعار الحوالة (مطلوب)',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                ],
                const SizedBox(height: 8),
                TextField(
                  controller: noteCtrl2,
                  decoration: const InputDecoration(
                    labelText: 'ملاحظة (اختيارية)',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('إلغاء'),
            ),
            FilledButton(
              onPressed: deliverBusy ? null : () => confirmDeliver(),
              child: deliverBusy
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text('تأكيد التسليم والتحصيل'),
            ),
          ],
        ),
      ),
    ).then((_) => setState(() => deliverShow = false));
  }

  void pickupAll() {
    final unrec = sellersList
        .where((x) => x['pay_method'] == null || '${x['pay_method']}'.isEmpty)
        .toList();
    if (unrec.isEmpty) {
      goStatus('picked_up', 'تأكيد الاستلام من المتجر');
      return;
    }
    for (final s in unrec) {
      bulkAmounts.putIfAbsent(
        s['seller_order_id'],
        () => J.d(s['expected_amount']),
      );
    }
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setD) => AlertDialog(
          title: const Text('تأكيد الاستلام من المتاجر'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  payerMode == 'platform'
                      ? 'المنصة تسدد لتجار هذه المهمة — سيُسجَّل "لم أدفع":'
                      : 'سجّل الاستلام والدفع نقداً — ضمن ±100 من المتوقع:',
                  style: const TextStyle(fontSize: 12),
                ),
                const SizedBox(height: 8),
                ...unrec.map((s) {
                  if (payerMode == 'platform') {
                    return Text(
                      '• ${s['store_name']} — ${s['expected_amount']}',
                      style: const TextStyle(fontSize: 12),
                    );
                  }
                  final ctrl = TextEditingController(
                    text: (bulkAmounts[s['seller_order_id']] ?? 0)
                        .toStringAsFixed(2),
                  );
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: TextField(
                      controller: ctrl,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: '${s['store_name']}',
                        helperText:
                            'المتوقع ${s['expected_amount']} — مسموح ±100',
                        border: const OutlineInputBorder(),
                        isDense: true,
                      ),
                      onChanged: (v) => bulkAmounts[s['seller_order_id']] =
                          double.tryParse(v),
                    ),
                  );
                }),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('إلغاء'),
            ),
            FilledButton(
              onPressed: bulkBusy
                  ? null
                  : () async {
                      setD(() => bulkBusy = true);
                      await _confirmBulkPickup(unrec);
                      if (ctx.mounted) Navigator.pop(ctx);
                      setD(() => bulkBusy = false);
                    },
              child: const Text('تأكيد الاستلام'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmBulkPickup(
    List<Map<String, dynamic>> unrec,
  ) async {
    final payMethod = payerMode == 'platform' ? 'unpaid' : 'cash';
    if (payMethod == 'cash') {
      for (final s in unrec) {
        final v = bulkAmounts[s['seller_order_id']];
        if (v == null || v < 0) {
          toast(context, 'أدخل مبلغاً صحيحاً لـ ${s['store_name']}');
          return;
        }
        if ((v - J.d(s['expected_amount'])).abs() - 100 > 0.009) {
          toast(
            context,
            '${s['store_name']}: المبلغ يجب أن يكون ضمن ±100',
          );
          return;
        }
      }
    }
    setState(() => bulkBusy = true);
    final failed = <String>[];
    for (final s in unrec) {
      final res = await app.api.collectionSellerCash(
        id: widget.id,
        sellerOrderId: s['seller_order_id'],
        amountHanded:
            payMethod == 'cash' ? (bulkAmounts[s['seller_order_id']] ?? 0) : 0,
        payMethod: payMethod,
        idempotencyKey:
            'seller-cash-${widget.id}-${s['seller_order_id']}',
      );
      if (!res.ok) failed.add('${s['store_name']}: ${res.message}');
    }
    if (!mounted) return;
    setState(() => bulkBusy = false);
    await load();
    if (failed.isNotEmpty) {
      toast(context, 'تعذر تسجيل: ${failed.join(' ؛ ')}');
    } else {
      goStatus('picked_up', 'تأكيد الاستلام من المتجر');
    }
  }

  void openSellerDialog(Map<String, dynamic> s) {
    setState(() => dialogSeller = s);
    if (payerMode == 'platform') {
      dialogPayMethod = 'unpaid';
    } else if (payerMode == 'courier') {
      dialogPayMethod = 'cash';
    } else {
      dialogPayMethod =
          s['pay_method'] == 'unpaid' ? 'unpaid' : 'cash';
    }
    final prev = s['cash_handed'];
    dialogAmountCtrl.text = (s['pay_method'] == 'cash' && prev != null)
        ? '$prev'
        : '${s['expected_amount'] ?? 0}';
    dialogNoteCtrl.text = J.str(s['cash_note']);
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setD) => AlertDialog(
          title: Text('استلام من: ${s['store_name']}'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'المستحق للتاجر (منتجات فقط) ${s['expected_amount']}',
                  style: const TextStyle(fontSize: 12),
                ),
                if (J.str(s['delivery_share']).isNotEmpty &&
                    J.str(s['delivery_share']) != '0')
                  Text(
                    'التوصيل (${s['delivery_share']}) للمنصة وليس للتاجر',
                    style: const TextStyle(fontSize: 11),
                  ),
                const SizedBox(height: 8),
                TextField(
                  controller: dialogAmountCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'المبلغ',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                ),
                if (payerMode == 'both') ...[
                  Row(
                    children: [
                      Radio<String>(
                        value: 'cash',
                        groupValue: dialogPayMethod,
                        onChanged: (v) =>
                            setD(() => dialogPayMethod = v ?? 'cash'),
                      ),
                      const Text('دفعت نقداً'),
                      Radio<String>(
                        value: 'unpaid',
                        groupValue: dialogPayMethod,
                        onChanged: (v) =>
                            setD(() => dialogPayMethod = v ?? 'cash'),
                      ),
                      const Text('لم أدفع — على المنصة'),
                    ],
                  ),
                ],
                TextField(
                  controller: dialogNoteCtrl,
                  decoration: const InputDecoration(
                    labelText: 'ملاحظة (اختيارية)',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('إلغاء'),
            ),
            FilledButton(
              onPressed: dialogBusy
                  ? null
                  : () async {
                      setD(() => dialogBusy = true);
                      await _saveSellerDialog();
                      if (ctx.mounted) Navigator.pop(ctx);
                      setD(() => dialogBusy = false);
                    },
              child: const Text('حفظ'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _saveSellerDialog() async {
    final s = dialogSeller;
    if (s == null) return;
    final v = double.tryParse(dialogAmountCtrl.text.trim());
    if (dialogPayMethod == 'cash' && (v == null || v < 0)) {
      toast(context, 'أدخل المبلغ المدفوع للتاجر');
      return;
    }
    if (dialogPayMethod == 'cash' &&
        (v! - J.d(s['expected_amount'])).abs() - 100 > 0.009) {
      toast(context, 'المبلغ يجب أن يكون ضمن ±100');
      return;
    }
    setState(() => dialogBusy = true);
    final res = await app.api.collectionSellerCash(
      id: widget.id,
      sellerOrderId: s['seller_order_id'],
      amountHanded: dialogPayMethod == 'cash' ? (v ?? 0) : 0,
      payMethod: dialogPayMethod,
      note: dialogNoteCtrl.text.trim().isEmpty
          ? null
          : dialogNoteCtrl.text.trim(),
      idempotencyKey:
          'seller-cash-${widget.id}-${s['seller_order_id']}',
    );
    if (!mounted) return;
    setState(() => dialogBusy = false);
    if (res.ok) {
      toast(context, 'تم حفظ التاجر');
      await load();
      final nxt = sellersList
          .where(
            (x) =>
                (x['pay_method'] == null ||
                    '${x['pay_method']}'.isEmpty) &&
                x['seller_order_id'] != s['seller_order_id'],
          )
          .toList();
      if (nxt.isNotEmpty && !isDone && mounted) {
        openSellerDialog(nxt.first);
      }
    } else {
      toast(context, res.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return Scaffold(
        appBar: AppBar(title: Text('تفاصيل الطلب ${widget.id}')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    if (assignment.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: Text('طلب ${widget.id}')),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text('تعذر تحميل الطلب'),
              TextButton(onPressed: () => load(), child: const Text('إعادة المحاولة')),
            ],
          ),
        ),
      );
    }
    final payMethod = J.str(
      customerObj['payment_method'].toString().isEmpty
          ? J.map(assignment['checkout_group'])['payment_method']
          : customerObj['payment_method'],
    );
    final paymentLabel = due > 0
        ? (payMethod == 'COD' ? 'عند الاستلام (كاش)' : 'مطلوب تحصيل: $payMethod')
        : 'مدفوع';
    return Scaffold(
      appBar: AppBar(title: Text('تفاصيل الطلب $orderNo')),
      body: RefreshIndicator(
        color: AppColors.orange,
        onRefresh: () => load(),
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        ...steps.asMap().entries.map((e) {
                          final color = e.key < stepIndex
                              ? AppColors.success
                              : (e.key == stepIndex
                                  ? AppColors.orange
                                  : AppColors.greyBorder);
                          return Chip(
                            label: Text(
                              e.value,
                              style: TextStyle(
                                fontSize: 11,
                                color: e.key <= stepIndex
                                    ? Colors.white
                                    : AppColors.greyText,
                              ),
                            ),
                            backgroundColor: color,
                          );
                        }),
                        Chip(
                          label: Text(
                            due > 0 ? 'تحصيل: $due' : 'مدفوع',
                            style: const TextStyle(fontSize: 11),
                          ),
                        ),
                      ],
                    ),
                    if (checklist != null)
                      Wrap(
                        spacing: 6,
                        children: [
                          Chip(
                            label: Text(
                              'المتاجر: ${checklist!['sellers_recorded']}/${checklist!['sellers_total']} مسجّل',
                            ),
                          ),
                          Chip(
                            label: Text(
                              'التحصيل: ${collectionRecorded ? 'مسجّل' : (due > 0 ? 'متبقي' : 'لا يوجد')}',
                            ),
                          ),
                        ],
                      ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      children: [
                        if (canAccept)
                          FilledButton(
                            onPressed: busy ? null : accept,
                            child: const Text('استلام الطلب'),
                          )
                        else if (canPickup)
                          FilledButton(
                            onPressed: busy ? null : pickupAll,
                            child: const Text('تم الاستلام من المتاجر'),
                          )
                        else if (canDeliver)
                          FilledButton(
                            style: FilledButton.styleFrom(
                              backgroundColor: AppColors.success,
                            ),
                            onPressed: busy ? null : openDeliverDialog,
                            child: const Text('تم التسليم للعميل'),
                          )
                        else if (isDone)
                          Chip(label: Text(statusLabel)),
                        if (!isDone)
                          OutlinedButton(
                            onPressed: () =>
                                setState(() => showFail = !showFail),
                            child: const Text('تعذر التسليم'),
                          ),
                      ],
                    ),
                    if (showFail && !isDone) ...[
                      const SizedBox(height: 8),
                      const Text('سبب التعذر *'),
                      TextField(
                        controller: failCtrl,
                        maxLines: 2,
                        decoration: const InputDecoration(
                          hintText: 'سبب التعذر',
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                        onChanged: (v) => failReason = v,
                      ),
                      const SizedBox(height: 4),
                      FilledButton(
                        style: FilledButton.styleFrom(
                          backgroundColor: Colors.red,
                        ),
                        onPressed: busy || failCtrl.text.trim().isEmpty
                            ? null
                            : () => goStatus(
                                  'failed',
                                  failCtrl.text.trim(),
                                ),
                        child: const Text('تسجيل تعذر'),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'بيانات الطلب والعميل',
                      style: TextStyle(fontWeight: FontWeight.w800),
                    ),
                    Text('رقم الطلب: $orderNo'),
                    Text('الحالة: $statusLabel'),
                    Text(
                      'العميل: ${J.str(customerObj['name'], '-')}',
                    ),
                    Text(
                      'جوال العميل: ${customerMobile.isEmpty ? '-' : customerMobile}',
                    ),
                    Text(
                      'عنوان العميل: ${J.str(customerObj['address'], '-')}',
                    ),
                    if (J.str(customerObj['delivery_time']).isNotEmpty)
                      Text('وقت التوصيل: ${customerObj['delivery_time']}'),
                    if (J.str(customerObj['order_note']).isNotEmpty)
                      Text('ملاحظة العميل: ${customerObj['order_note']}'),
                    Text('طريقة الدفع: $paymentLabel'),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'التحصيل من العميل',
                      style: TextStyle(fontWeight: FontWeight.w800),
                    ),
                    Text('المطلوب (النظام): $codTotal'),
                    Text('المحصّل حتى الآن: $collected'),
                    Text('المتبقي: $remaining'),
                    if (settlementPreview.isNotEmpty)
                      Container(
                        margin: const EdgeInsets.only(top: 8),
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.blue.withValues(alpha: 0.06),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          'دفعت للتجار ${settlementPreview['sellers_paid_total']} • حصلت من العميل ${settlementPreview['cod_collected']} • المتبقي ${settlementPreview['cod_due']}',
                          style: const TextStyle(fontSize: 11),
                        ),
                      ),
                    if (showCollection && due > 0) ...[
                      const SizedBox(height: 8),
                      TextField(
                        controller: cashCtrl,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'المبلغ المستلم فعلاً من العميل',
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                      ),
                      const SizedBox(height: 8),
                      DropdownButtonFormField<String>(
                        initialValue: collectionMethod,
                        items: const [
                          DropdownMenuItem(
                            value: 'cash',
                            child: Text('نقدي'),
                          ),
                          DropdownMenuItem(
                            value: 'transfer',
                            child: Text('حوالة / تحويل'),
                          ),
                        ],
                        onChanged: (v) => setState(
                          () => collectionMethod = v ?? 'cash',
                        ),
                        decoration: const InputDecoration(
                          labelText: 'طريقة التحصيل',
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                      ),
                      if (collectionMethod == 'transfer')
                        TextField(
                          controller: proofCtrl,
                          decoration: const InputDecoration(
                            labelText: 'مسار إشعار الحوالة (مطلوب)',
                            border: OutlineInputBorder(),
                            isDense: true,
                          ),
                        ),
                      TextField(
                        controller: noteCtrl,
                        decoration: const InputDecoration(
                          labelText: 'ملاحظة (اختيارية)',
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                      ),
                      const SizedBox(height: 8),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton(
                          style: FilledButton.styleFrom(
                            backgroundColor: AppColors.success,
                          ),
                          onPressed: busy ? null : () => confirmPaid(),
                          child: const Text('تأكيد استلام المبلغ'),
                        ),
                      ),
                      if (collectMsg.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Text(
                            collectMsg,
                            style: TextStyle(
                              fontSize: 12,
                              color: collectOk
                                  ? AppColors.success
                                  : Colors.orange,
                            ),
                          ),
                        ),
                    ] else if (due > 0)
                      const Text(
                        'التحصيل يظهر هنا فقط في خطوة التسليم.',
                        style: TextStyle(fontSize: 12),
                      )
                    else
                      const Text(
                        'مدفوع مسبقاً — لا يوجد تحصيل.',
                        style: TextStyle(fontSize: 12),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'كل الأصناف (${allItems.length} صنف • ${sellersList.length} متاجر)',
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                    ...allItems.asMap().entries.map(
                          (e) => ListTile(
                            dense: true,
                            leading: Text('${e.key + 1}'),
                            title: Text(
                              J.str(e.value['product_name']),
                            ),
                            subtitle: Text(
                              '${J.str(e.value['store_name'])}${J.str(e.value['variant_name']).isNotEmpty ? ' • ${e.value['variant_name']}' : ''}',
                              style: const TextStyle(fontSize: 11),
                            ),
                            trailing: Text(
                              '× ${e.value['quantity']} • ${e.value['sub_total']}',
                              style: const TextStyle(fontSize: 12),
                            ),
                          ),
                        ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'الاستلام من المتاجر',
                      style: TextStyle(fontWeight: FontWeight.w800),
                    ),
                    ...sellersList.map(
                      (s) => Card(
                        margin: const EdgeInsets.only(top: 8),
                        child: Padding(
                          padding: const EdgeInsets.all(10),
                          child: Column(
                            crossAxisAlignment:
                                CrossAxisAlignment.start,
                            children: [
                              Text(
                                J.str(s['store_name']),
                                style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              Text(
                                'المستحق للتاجر (منتجات فقط): ${s['expected_amount']}',
                                style: const TextStyle(fontSize: 12),
                              ),
                              if (J.str(s['mobile']).isNotEmpty)
                                Text(
                                  'جوال المتجر: ${s['mobile']}',
                                  style: const TextStyle(fontSize: 12),
                                ),
                              if (J.str(s['address']).isNotEmpty)
                                Text(
                                  'عنوان المتجر: ${s['address']}',
                                  style: const TextStyle(fontSize: 12),
                                ),
                              Text(
                                'الأصناف: ${J.maps(s['items']).length} • الكمية × ${sellerQty(s).toStringAsFixed(0)} • ${sellerAmount(s).toStringAsFixed(2)}',
                                style: const TextStyle(fontSize: 11),
                              ),
                              const SizedBox(height: 6),
                              if (s['pay_method'] == null ||
                                  '${s['pay_method']}'.isEmpty)
                                FilledButton(
                                  onPressed: busy
                                      ? null
                                      : () => openSellerDialog(s),
                                  child: const Text(
                                    'استلام من هذا التاجر وتسجيل الدفع',
                                  ),
                                )
                              else
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        s['pay_method'] == 'cash'
                                            ? 'دفعت: ${s['cash_handed']} (${s['paid_from'] == 'float' ? 'من العهدة' : 'من جيبك — ذمة لك'})'
                                            : 'لم تدفع — على المنصة',
                                        style: const TextStyle(
                                          fontSize: 12,
                                        ),
                                      ),
                                    ),
                                    TextButton(
                                      onPressed: () =>
                                          openSellerDialog(s),
                                      child: const Text('تعديل'),
                                    ),
                                  ],
                                ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'عنوان العميل وموقعه',
                      style: TextStyle(fontWeight: FontWeight.w800),
                    ),
                    Text(J.str(customerObj['address'], '-')),
                    const SizedBox(height: 8),
                    if (!isPickupPhase &&
                        J.str(customerObj['latitude']).isNotEmpty)
                      OutlinedButton.icon(
                        onPressed: () => openMapsNavigation(
                          J.str(customerObj['address']),
                        ),
                        icon: const Icon(Icons.map_outlined),
                        label: const Text('الاتجاهات داخل الموقع'),
                      )
                    else
                      const Text(
                        'الخريطة التفصيلية للعميل ستظهر هنا بعد الاستلام من المتاجر.',
                        style: TextStyle(fontSize: 11),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
