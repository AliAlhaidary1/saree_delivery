import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/app_controller.dart';
import '../core/brand_config.dart';
import '../core/config.dart';
import '../theme/app_colors.dart';
import 'branded_skeleton.dart';

/// تنسيق موحّد للأرقام المالية مع فاصل الآلاف وخانتين عشريتين.
String formatAmount(dynamic value, {int decimals = 2}) {
  final raw = '$value'.replaceAll(',', '').trim();
  final number = value is num ? value.toDouble() : double.tryParse(raw);
  if (number == null || !number.isFinite) {
    return value == null ? '0' : '$value';
  }
  final fixed = number.toStringAsFixed(decimals);
  final parts = fixed.split('.');
  final grouped = parts.first.replaceAllMapped(
    RegExp(r'(\d)(?=(\d{3})+(?!\d))'),
    (m) => '${m[1]},',
  );
  return parts.length > 1 ? '$grouped.${parts[1]}' : grouped;
}

/// رمز العملة من هوية العلامة (قد يكون فارغاً إذا لم تحدده الإدارة).
String brandCurrency() => app.brand.identity['currency']?.trim() ?? '';

/// مبلغ منسّق مع العملة إن توفرت.
String formatMoney(dynamic value, {String? currency, int decimals = 2}) {
  final amount = formatAmount(value, decimals: decimals);
  final symbol = (currency ?? brandCurrency()).trim();
  return symbol.isEmpty ? amount : '$amount $symbol';
}

String formatCount(dynamic value) {
  final raw = '$value'.replaceAll(',', '').trim();
  final number = value is num ? value.toDouble() : double.tryParse(raw);
  if (number == null || !number.isFinite) return value == null ? '0' : '$value';
  return formatAmount(number, decimals: 0);
}

String formatDate(dynamic value) {
  final text = '$value'.trim();
  if (text.isEmpty || text == 'null') return '-';
  final parsed = DateTime.tryParse(text);
  if (parsed == null) return text.length >= 10 ? text.substring(0, 10) : text;
  final local = parsed.isUtc ? parsed.toLocal() : parsed;
  return '${local.year.toString().padLeft(4, '0')}-'
      '${local.month.toString().padLeft(2, '0')}-'
      '${local.day.toString().padLeft(2, '0')}';
}

String formatDateTime(dynamic value) {
  final text = '$value'.trim();
  if (text.isEmpty || text == 'null') return '-';
  final parsed = DateTime.tryParse(text);
  if (parsed == null) {
    return text.length >= 16
        ? text.substring(0, 16).replaceAll('T', ' ')
        : text;
  }
  final local = parsed.isUtc ? parsed.toLocal() : parsed;
  final date =
      '${local.year.toString().padLeft(4, '0')}-'
      '${local.month.toString().padLeft(2, '0')}-'
      '${local.day.toString().padLeft(2, '0')}';
  final time =
      '${local.hour.toString().padLeft(2, '0')}:'
      '${local.minute.toString().padLeft(2, '0')}';
  return '$date $time';
}

const _arabicMonths = [
  'يناير',
  'فبراير',
  'مارس',
  'أبريل',
  'مايو',
  'يونيو',
  'يوليو',
  'أغسطس',
  'سبتمبر',
  'أكتوبر',
  'نوفمبر',
  'ديسمبر',
];

/// تاريخ مقروء بالعربية: 23 أكتوبر 2026
String formatDateAr(dynamic value, {bool withTime = false}) {
  final text = '$value'.trim();
  if (text.isEmpty || text == 'null') return '-';
  final parsed = DateTime.tryParse(text);
  if (parsed == null) return text;
  final local = parsed.isUtc ? parsed.toLocal() : parsed;
  final base = '${local.day} ${_arabicMonths[local.month - 1]} ${local.year}';
  if (!withTime) return base;
  final h = local.hour % 12 == 0 ? 12 : local.hour % 12;
  final period = local.hour < 12 ? 'ص' : 'م';
  return '$base - $h:${local.minute.toString().padLeft(2, '0')} $period';
}

/// تحويل الأرقام العربية/الفارسية إلى أرقام لاتينية قبل الإرسال أو الحساب.
String normalizeDigits(String input) {
  const arabic = '٠١٢٣٤٥٦٧٨٩';
  const persian = '۰۱۲۳۴۵۶۷۸۹';
  final buffer = StringBuffer();
  for (final rune in input.runes) {
    final ch = String.fromCharCode(rune);
    final ai = arabic.indexOf(ch);
    final pi = persian.indexOf(ch);
    if (ai >= 0) {
      buffer.write(ai);
    } else if (pi >= 0) {
      buffer.write(pi);
    } else {
      buffer.write(ch);
    }
  }
  return buffer.toString();
}

double? parseNumber(dynamic value) {
  if (value is num) return value.toDouble();
  final text = normalizeDigits(
    '$value',
  ).replaceAll(',', '').replaceAll('٬', '').replaceAll(' ', '').trim();
  if (text.isEmpty || text == 'null') return null;
  return double.tryParse(text);
}

/// رقم هاتف جاهز للاتصال (يحافظ على الأرقام العربية ويحوّلها).
String cleanPhone(String raw) {
  final normalized = normalizeDigits(raw);
  var phone = normalized.replaceAll(RegExp(r'[^0-9+]'), '');
  if (phone.startsWith('00')) phone = phone.substring(2);
  return phone;
}

String formatPercent(dynamic value) {
  final number = parseNumber(value);
  if (number == null) return '-';
  final pct = number > 0 && number <= 1 ? number * 100 : number;
  final fixed = pct == pct.roundToDouble()
      ? pct.toStringAsFixed(0)
      : pct.toStringAsFixed(1);
  return '$fixed%';
}

/// عدد أعمدة مناسب للشبكات حسب عرض الشاشة (بدل 2 ثابتة على التابلت).
int responsiveColumns(
  BuildContext context, {
  int min = 2,
  int max = 4,
  double tileWidth = 170,
}) {
  final width = MediaQuery.sizeOf(context).width - 32;
  final count = (width / tileWidth).floor();
  return count.clamp(min, max);
}

enum ToastKind { success, error, info }

void toast(
  BuildContext context,
  String message, {
  ToastKind kind = ToastKind.info,
}) {
  final safe = message.trim();
  if (safe.isEmpty) return;
  final (icon, color) = switch (kind) {
    ToastKind.success => (Icons.check_circle_outline, AppColors.success),
    ToastKind.error => (Icons.error_outline, AppColors.error),
    ToastKind.info => (Icons.info_outline, AppColors.orange),
  };
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              safe,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
      backgroundColor: AppColors.navy,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      margin: const EdgeInsets.all(16),
    ),
  );
}

void toastError(BuildContext context, String message) {
  toast(
    context,
    message.isEmpty ? 'تعذر إتمام الطلب' : message,
    kind: ToastKind.error,
  );
}

void toastSuccess(BuildContext context, String message) {
  toast(context, message, kind: ToastKind.success);
}

class BusySpinner extends StatelessWidget {
  const BusySpinner({super.key, this.color, this.brand});
  final Color? color;
  final BrandConfig? brand;

  @override
  Widget build(BuildContext context) {
    final c = color ?? (brand ?? app.brand).orange;
    return SizedBox(
      width: 22,
      height: 22,
      child: CircularProgressIndicator(strokeWidth: 2.4, color: c),
    );
  }
}

Future<bool> confirmAction(
  BuildContext context, {
  required String title,
  String? body,
  String confirmLabel = 'تأكيد',
  String cancelLabel = 'إلغاء',
  bool destructive = false,
}) async {
  final accent = destructive ? AppColors.error : AppColors.orange;
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      scrollable: true,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              destructive ? Icons.warning_amber_rounded : Icons.help_outline,
              color: accent,
              size: 22,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(child: Text(title)),
        ],
      ),
      content: body == null ? null : Text(body),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: Text(cancelLabel),
        ),
        FilledButton(
          style: destructive
              ? FilledButton.styleFrom(
                  backgroundColor: AppColors.error,
                  foregroundColor: Colors.white,
                )
              : null,
          onPressed: () => Navigator.pop(ctx, true),
          child: Text(confirmLabel),
        ),
      ],
    ),
  );
  return ok == true;
}

Widget labeledField(
  TextEditingController controller,
  String label, {
  int maxLines = 1,
  TextInputType? type,
  bool obscure = false,
  bool toggleObscure = false,
  TextInputAction? textInputAction,
  Iterable<String>? autofillHints,
}) {
  if (toggleObscure) {
    return _ObscureField(
      controller: controller,
      label: label,
      textInputAction: textInputAction,
    );
  }
  final ltr =
      type == TextInputType.phone ||
      type == TextInputType.emailAddress ||
      type == TextInputType.number ||
      type == TextInputType.url;
  return Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: TextField(
      controller: controller,
      maxLines: maxLines,
      obscureText: obscure,
      keyboardType: type,
      textInputAction: textInputAction,
      autofillHints: autofillHints,
      textDirection: ltr ? TextDirection.ltr : null,
      textAlign: ltr ? TextAlign.left : TextAlign.start,
      decoration: InputDecoration(labelText: label),
    ),
  );
}

class _ObscureField extends StatefulWidget {
  const _ObscureField({
    required this.controller,
    required this.label,
    this.textInputAction,
  });
  final TextEditingController controller;
  final String label;
  final TextInputAction? textInputAction;

  @override
  State<_ObscureField> createState() => _ObscureFieldState();
}

class _ObscureFieldState extends State<_ObscureField> {
  bool hidden = true;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: TextField(
        controller: widget.controller,
        obscureText: hidden,
        textInputAction: widget.textInputAction,
        autocorrect: false,
        enableSuggestions: false,
        autofillHints: const [AutofillHints.password],
        decoration: InputDecoration(
          labelText: widget.label,
          suffixIcon: IconButton(
            tooltip: hidden ? 'إظهار كلمة المرور' : 'إخفاء كلمة المرور',
            onPressed: () => setState(() => hidden = !hidden),
            icon: Icon(
              hidden
                  ? Icons.visibility_outlined
                  : Icons.visibility_off_outlined,
            ),
          ),
        ),
      ),
    );
  }
}

class Refreshable extends StatelessWidget {
  const Refreshable({super.key, required this.onRefresh, required this.child});
  final Future<void> Function() onRefresh;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: onRefresh,
      color: AppColors.orangeText,
      child: LayoutBuilder(
        builder: (context, constraints) => SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minHeight: constraints.maxHeight.isFinite
                  ? constraints.maxHeight
                  : 0,
            ),
            child: IntrinsicHeight(child: child),
          ),
        ),
      ),
    );
  }
}

Future<void> copyText(
  BuildContext context,
  String value, [
  String ok = 'تم النسخ',
]) async {
  if (value.trim().isEmpty) return;
  await Clipboard.setData(ClipboardData(text: value));
  if (context.mounted) toast(context, ok);
}

Future<void> openTel(String raw) async {
  final phone = cleanPhone(raw);
  if (phone.isEmpty) return;
  try {
    final uri = Uri.parse('tel:$phone');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  } catch (_) {}
}

Future<void> openSms(String raw) async {
  final phone = cleanPhone(raw);
  if (phone.isEmpty) return;
  try {
    final uri = Uri.parse('sms:$phone');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  } catch (_) {}
}

Future<void> openMail(String raw) async {
  final email = raw.trim();
  if (email.isEmpty) return;
  try {
    await launchUrl(Uri.parse('mailto:$email'));
  } catch (_) {}
}

Future<void> openWhatsApp(String raw, {String? text}) async {
  var phone = cleanPhone(raw);
  if (phone.isEmpty) return;
  if (phone.startsWith('00')) phone = phone.substring(2);
  if (phone.startsWith('0')) {
    phone = '${AppConfig.countryDialCode}${phone.substring(1)}';
  } else if (phone.length <= 9) {
    phone = '${AppConfig.countryDialCode}$phone';
  }
  final query = text == null || text.trim().isEmpty
      ? ''
      : '?text=${Uri.encodeComponent(text.trim())}';
  try {
    await launchUrl(
      Uri.parse('https://wa.me/$phone$query'),
      mode: LaunchMode.externalApplication,
    );
  } catch (_) {}
}

String? dropdownId(String? id, List<Map<String, dynamic>> items) {
  if (id == null || id.isEmpty) return null;
  return items.any((item) => '${item['id']}' == id) ? id : null;
}

Future<String?> pickDate(
  BuildContext context, {
  DateTime? initial,
  bool withTime = false,
  DateTime? firstDate,
  DateTime? lastDate,
}) async {
  final first = firstDate ?? DateTime(2020);
  final last = lastDate ?? DateTime(2035, 12, 31);
  final rawInitial = initial ?? DateTime.now();
  final safeInitial = rawInitial.isBefore(first)
      ? first
      : (rawInitial.isAfter(last) ? last : rawInitial);
  final date = await showDatePicker(
    context: context,
    initialDate: safeInitial,
    firstDate: first,
    lastDate: last,
    locale: const Locale('ar'),
  );
  if (date == null) return null;
  final day =
      '${date.year.toString().padLeft(4, '0')}-'
      '${date.month.toString().padLeft(2, '0')}-'
      '${date.day.toString().padLeft(2, '0')}';
  if (!withTime) return day;
  if (!context.mounted) return null;
  final time = await showTimePicker(
    context: context,
    initialTime: TimeOfDay.fromDateTime(safeInitial),
  );
  if (time == null) return null;
  return '$day '
      '${time.hour.toString().padLeft(2, '0')}:'
      '${time.minute.toString().padLeft(2, '0')}:00';
}

class EmptyBox extends StatelessWidget {
  const EmptyBox(
    this.text, {
    super.key,
    this.icon = Icons.inbox_outlined,
    this.actionLabel,
    this.onAction,
  });
  final String text;
  final IconData icon;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final scale = MediaQuery.textScalerOf(context).scale(16) / 16;
    final iconSize = scale > 1.3 ? 76.0 : 96.0;
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: iconSize,
              height: iconSize,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    AppColors.orange.withValues(alpha: 0.14),
                    AppColors.navy.withValues(alpha: 0.06),
                  ],
                  begin: Alignment.topRight,
                  end: Alignment.bottomLeft,
                ),
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                size: iconSize * 0.46,
                color: AppColors.orangeText,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              text,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: AppColors.navy,
              ),
            ),
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: 18),
              FilledButton(onPressed: onAction, child: Text(actionLabel!)),
            ],
          ],
        ),
      ),
    );
  }
}

/// حالة الجلب الموحدة — نسخة طبق الأصل من تطبيق التاجر (FetchBody)
/// loading / error / empty + Refreshable + retry — تُستخدم في كل شاشات القوائم.
///
/// التحميل يعرض shimmer يحاكي شكل البطاقات + انتقال ناعم للمحتوى.
class FetchBody extends StatelessWidget {
  const FetchBody({
    super.key,
    required this.loading,
    required this.onRefresh,
    required this.isEmpty,
    required this.child,
    this.error,
    this.emptyText = 'لا توجد بيانات',
    this.emptyIcon = Icons.inbox_outlined,
    this.emptyActionLabel,
    this.onEmptyAction,
    this.skeleton,
    this.skeletonCount = 4,
  });

  final bool loading;
  final Future<void> Function() onRefresh;
  final bool isEmpty;
  final Widget child;
  final String? error;
  final String emptyText;
  final IconData emptyIcon;
  final String? emptyActionLabel;
  final VoidCallback? onEmptyAction;
  final Widget? skeleton;
  final int skeletonCount;

  @override
  Widget build(BuildContext context) {
    final stateKey = loading
        ? 'loading'
        : (error != null && error!.isNotEmpty)
        ? 'error'
        : isEmpty
        ? 'empty'
        : 'content';
    final Widget body;
    if (loading) {
      body =
          skeleton ??
          BrandedSkeletonList(brand: app.brand, count: skeletonCount);
    } else if (error != null && error!.isNotEmpty) {
      body = Refreshable(
        onRefresh: onRefresh,
        child: EmptyBox(
          error!,
          icon: Icons.error_outline,
          actionLabel: 'إعادة المحاولة',
          onAction: () async {
            await onRefresh();
          },
        ),
      );
    } else if (isEmpty) {
      body = Refreshable(
        onRefresh: onRefresh,
        child: EmptyBox(
          emptyText,
          icon: emptyIcon,
          actionLabel: emptyActionLabel,
          onAction: onEmptyAction,
        ),
      );
    } else {
      body = RefreshIndicator(
        onRefresh: onRefresh,
        color: AppColors.orangeText,
        child: child,
      );
    }
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 250),
      child: KeyedSubtree(key: ValueKey(stateKey), child: body),
    );
  }
}
